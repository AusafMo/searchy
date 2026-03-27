import SwiftUI
import Foundation
import ImageCaptureCore

// MARK: - Watched Directory Model
struct WatchedDirectory: Identifiable, Codable, Equatable {
    var id: UUID
    var path: String
    var filter: String
    var filterType: FilterType

    enum FilterType: String, Codable, CaseIterable {
        case all = "All Files"
        case startsWith = "Starts With"
        case endsWith = "Ends With"
        case contains = "Contains"
        case regex = "Regex"
    }

    init(id: UUID = UUID(), path: String, filter: String = "", filterType: FilterType = .all) {
        self.id = id
        self.path = path
        self.filter = filter
        self.filterType = filterType
    }

    var displayPath: String {
        (path as NSString).abbreviatingWithTildeInPath
    }

    var filterDescription: String? {
        guard !filter.isEmpty && filterType != .all else { return nil }
        return "\(filterType.rawValue): \(filter)"
    }
}

// MARK: - External Volume Management

enum VolumeType: String, Codable {
    case external = "external"      // USB drives, external SSDs
    case network = "network"        // NAS, SMB/AFP shares
    case raid = "raid"              // RAID arrays
    case manual = "manual"          // Manually added paths
}

enum IndexStorageLocation: String, Codable {
    case onVolume = "onVolume"      // Store index on the volume itself (portable)
    case centralized = "centralized" // Store in app's data directory
}

struct ExternalVolume: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var path: String
    var type: VolumeType
    var isEnabled: Bool
    var lastIndexed: Date?
    var imageCount: Int
    var volumeUUID: String?  // macOS volume UUID for reliable identification
    var indexStorage: IndexStorageLocation

    var isOnline: Bool {
        FileManager.default.fileExists(atPath: path)
    }

    /// Get the path where the index should be stored
    var indexPath: String {
        switch indexStorage {
        case .onVolume:
            // Store in a hidden .searchy folder on the volume
            return "\(path)/.searchy"
        case .centralized:
            // Store in app's Application Support with volume ID
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            return appSupport.appendingPathComponent("searchy/volumes/\(id.uuidString)").path
        }
    }

    /// Get the index file path
    var indexFilePath: String {
        return "\(indexPath)/image_index.bin"
    }

    /// Get the thumbnails directory path
    var thumbnailsPath: String {
        return "\(indexPath)/thumbnails"
    }

    init(id: UUID = UUID(), name: String, path: String, type: VolumeType, isEnabled: Bool = true, lastIndexed: Date? = nil, imageCount: Int = 0, volumeUUID: String? = nil, indexStorage: IndexStorageLocation = .centralized) {
        self.id = id
        self.name = name
        self.path = path
        self.type = type
        self.isEnabled = isEnabled
        self.lastIndexed = lastIndexed
        self.imageCount = imageCount
        self.volumeUUID = volumeUUID
        // Default: network volumes use centralized, external use on-volume
        self.indexStorage = type == .network ? .centralized : indexStorage
    }
}

class VolumeManager: ObservableObject {
    static let shared = VolumeManager()

    @Published var volumes: [ExternalVolume] = []
    @Published var isScanning = false

    private let userDefaultsKey = "externalVolumes"
    private var volumeMonitor: DispatchSourceFileSystemObject?
    private let volumesPath = "/Volumes"

    // System volumes to ignore
    private let ignoredVolumes: Set<String> = [
        "Macintosh HD",
        "Macintosh HD - Data",
        "Recovery",
        "Preboot",
        "VM",
        "Update",
        "com.apple.TimeMachine.localsnapshots"
    ]

    // Patterns that indicate DMG/app mounts (not real external drives)
    private let dmgPatterns: [String] = [
        "Install ",           // macOS installers
        "Installer",
        ".app",               // App bundles
        "-Fork",              // Development forks
        "-main",              // Git branches mounted
        "-master",
        "Xcode",              // Xcode disk images
    ]

    private init() {
        loadVolumes()
        startMonitoringVolumes()
        refreshVolumes()
    }

    /// Check if a volume looks like a DMG mount or app bundle
    private func isDiskImageMount(name: String, url: URL) -> Bool {
        // Check name patterns
        for pattern in dmgPatterns {
            if name.contains(pattern) {
                return true
            }
        }

        // Check volume properties
        if let resourceValues = try? url.resourceValues(forKeys: [
            .volumeIsReadOnlyKey,
            .volumeIsEjectableKey,
            .volumeIsRootFileSystemKey,
            .volumeTotalCapacityKey
        ]) {
            let isReadOnly = resourceValues.volumeIsReadOnly ?? false
            let isEjectable = resourceValues.volumeIsEjectable ?? false
            let totalCapacity = resourceValues.volumeTotalCapacity ?? 0

            // DMGs are typically: read-only + ejectable + small capacity (< 10GB usually for app DMGs)
            // Real external drives are usually larger and writable
            if isReadOnly && isEjectable && totalCapacity < 10_000_000_000 {
                return true
            }
        }

        return false
    }

    deinit {
        volumeMonitor?.cancel()
    }

    // MARK: - Persistence

    private func loadVolumes() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let saved = try? JSONDecoder().decode([ExternalVolume].self, from: data) {
            self.volumes = saved
        }
    }

    private func saveVolumes() {
        if let data = try? JSONEncoder().encode(volumes) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    // MARK: - Volume Detection

    func refreshVolumes() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let fileManager = FileManager.default
            guard let contents = try? fileManager.contentsOfDirectory(atPath: self.volumesPath) else { return }

            var detectedVolumes: [ExternalVolume] = []

            for volumeName in contents {
                // Skip ignored system volumes
                if self.ignoredVolumes.contains(volumeName) { continue }

                let volumePath = "\(self.volumesPath)/\(volumeName)"

                // Check if it's a directory and accessible
                var isDir: ObjCBool = false
                guard fileManager.fileExists(atPath: volumePath, isDirectory: &isDir), isDir.boolValue else { continue }

                let volumeURL = URL(fileURLWithPath: volumePath)

                // Skip DMG mounts, app bundles, and disk images
                if self.isDiskImageMount(name: volumeName, url: volumeURL) { continue }

                // Try to get volume UUID
                let volumeUUID = try? volumeURL.resourceValues(forKeys: [.volumeUUIDStringKey]).volumeUUIDString

                // Determine volume type
                let volumeType = self.detectVolumeType(at: volumeURL)

                // Check if we already track this volume
                if let existingIndex = self.volumes.firstIndex(where: { $0.path == volumePath || ($0.volumeUUID != nil && $0.volumeUUID == volumeUUID) }) {
                    // Update existing volume info
                    var updated = self.volumes[existingIndex]
                    updated.path = volumePath
                    updated.name = volumeName
                    detectedVolumes.append(updated)
                } else {
                    // New volume detected
                    let newVolume = ExternalVolume(
                        name: volumeName,
                        path: volumePath,
                        type: volumeType,
                        volumeUUID: volumeUUID
                    )
                    detectedVolumes.append(newVolume)
                }
            }

            // Keep manually added volumes that are offline
            let manualVolumes = self.volumes.filter { $0.type == .manual && !detectedVolumes.contains(where: { $0.path == $0.path }) }

            DispatchQueue.main.async {
                self.volumes = detectedVolumes + manualVolumes
                self.saveVolumes()
            }
        }
    }

    private func detectVolumeType(at url: URL) -> VolumeType {
        guard let resourceValues = try? url.resourceValues(forKeys: [.volumeIsRemovableKey, .volumeIsLocalKey]) else {
            return .external
        }

        // If not local, it's a network volume
        if resourceValues.volumeIsLocal == false {
            return .network
        } else if resourceValues.volumeIsRemovable == true {
            return .external
        } else {
            return .external
        }
    }

    // MARK: - Volume Monitoring

    private func startMonitoringVolumes() {
        let fileDescriptor = open(volumesPath, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        volumeMonitor = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename],
            queue: DispatchQueue.global(qos: .utility)
        )

        volumeMonitor?.setEventHandler { [weak self] in
            // Debounce rapid events
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self?.refreshVolumes()
            }
        }

        volumeMonitor?.setCancelHandler {
            close(fileDescriptor)
        }

        volumeMonitor?.resume()
    }

    // MARK: - Volume Management

    func addManualVolume(name: String, path: String) {
        let volume = ExternalVolume(
            name: name,
            path: path,
            type: .manual
        )
        volumes.append(volume)
        saveVolumes()
    }

    func removeVolume(_ volume: ExternalVolume) {
        volumes.removeAll { $0.id == volume.id }
        saveVolumes()
    }

    func toggleVolume(_ volume: ExternalVolume) {
        if let index = volumes.firstIndex(where: { $0.id == volume.id }) {
            volumes[index].isEnabled.toggle()
            saveVolumes()
        }
    }

    func updateVolumeStats(_ volumeId: UUID, imageCount: Int) {
        if let index = volumes.firstIndex(where: { $0.id == volumeId }) {
            volumes[index].imageCount = imageCount
            volumes[index].lastIndexed = Date()
            saveVolumes()
        }
    }

    /// Get all enabled and online volume paths for indexing
    func getIndexablePaths() -> [String] {
        return volumes
            .filter { $0.isEnabled && $0.isOnline }
            .map { $0.path }
    }

    /// Check if a given image path belongs to an offline volume
    func isPathOffline(_ imagePath: String) -> Bool {
        for volume in volumes {
            if imagePath.hasPrefix(volume.path) {
                return !volume.isOnline
            }
        }
        return false
    }

    /// Get the volume for a given path
    func volumeForPath(_ path: String) -> ExternalVolume? {
        return volumes.first { path.hasPrefix($0.path) }
    }

    // MARK: - Index Storage Management

    /// Change where a volume's index is stored
    func setIndexStorage(_ volume: ExternalVolume, location: IndexStorageLocation) {
        guard let index = volumes.firstIndex(where: { $0.id == volume.id }) else { return }

        let oldPath = volumes[index].indexPath
        volumes[index].indexStorage = location
        let newPath = volumes[index].indexPath

        // Move existing index if it exists
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: oldPath) {
            do {
                try fileManager.createDirectory(atPath: (newPath as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
                try fileManager.moveItem(atPath: oldPath, toPath: newPath)
            } catch {
                print("Failed to move index: \(error)")
            }
        }

        saveVolumes()
    }

    /// Ensure the index directory exists for a volume
    func ensureIndexDirectory(for volume: ExternalVolume) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(atPath: volume.indexPath, withIntermediateDirectories: true)
        try fileManager.createDirectory(atPath: volume.thumbnailsPath, withIntermediateDirectories: true)
    }

    /// Check if a volume has an existing index
    func hasIndex(_ volume: ExternalVolume) -> Bool {
        return FileManager.default.fileExists(atPath: volume.indexFilePath)
    }

    /// Get the total size of a volume's index (index file + thumbnails)
    func indexSize(for volume: ExternalVolume) -> Int64 {
        let fileManager = FileManager.default
        var totalSize: Int64 = 0

        // Index file size
        if let attrs = try? fileManager.attributesOfItem(atPath: volume.indexFilePath),
           let size = attrs[.size] as? Int64 {
            totalSize += size
        }

        // Thumbnails directory size
        if let enumerator = fileManager.enumerator(atPath: volume.thumbnailsPath) {
            while let file = enumerator.nextObject() as? String {
                let filePath = "\(volume.thumbnailsPath)/\(file)"
                if let attrs = try? fileManager.attributesOfItem(atPath: filePath),
                   let size = attrs[.size] as? Int64 {
                    totalSize += size
                }
            }
        }

        return totalSize
    }

    /// Delete a volume's index and thumbnails
    func deleteIndex(for volume: ExternalVolume) {
        let fileManager = FileManager.default
        try? fileManager.removeItem(atPath: volume.indexPath)

        // Reset stats
        if let index = volumes.firstIndex(where: { $0.id == volume.id }) {
            volumes[index].imageCount = 0
            volumes[index].lastIndexed = nil
            saveVolumes()
        }
    }

    /// Format bytes as human-readable string
    func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Mobile Device Manager (ImageCaptureCore)

/// Represents a connected mobile device (iPhone, camera, etc.)
struct MobileDevice: Identifiable {
    let id: String
    let name: String
    let icon: String
}

/// Manages connected mobile devices using ImageCaptureCore
class MobileDeviceManager: NSObject, ObservableObject, ICDeviceBrowserDelegate {
    static let shared = MobileDeviceManager()

    @Published var devices: [MobileDevice] = []
    @Published var isScanning = false

    private var deviceBrowser: ICDeviceBrowser?

    private override init() {
        super.init()
        setupDeviceBrowser()
    }

    private func setupDeviceBrowser() {
        deviceBrowser = ICDeviceBrowser()
        deviceBrowser?.delegate = self
        deviceBrowser?.browsedDeviceTypeMask = ICDeviceTypeMask.camera
    }

    func startScanning() {
        isScanning = true
        deviceBrowser?.start()
    }

    func stopScanning() {
        isScanning = false
        deviceBrowser?.stop()
    }

    // MARK: - ICDeviceBrowserDelegate

    func deviceBrowser(_ browser: ICDeviceBrowser, didAdd device: ICDevice, moreComing: Bool) {
        DispatchQueue.main.async {
            let icon: String
            let name = device.name ?? "Unknown Device"

            if name.lowercased().contains("iphone") {
                icon = "iphone"
            } else if name.lowercased().contains("ipad") {
                icon = "ipad"
            } else if name.lowercased().contains("android") || name.lowercased().contains("samsung") || name.lowercased().contains("pixel") {
                icon = "candybarphone"
            } else {
                icon = "camera.fill"
            }

            let mobileDevice = MobileDevice(
                id: device.uuidString ?? UUID().uuidString,
                name: name,
                icon: icon
            )

            // Avoid duplicates
            if !self.devices.contains(where: { $0.id == mobileDevice.id }) {
                self.devices.append(mobileDevice)
            }
        }
    }

    func deviceBrowser(_ browser: ICDeviceBrowser, didRemove device: ICDevice, moreGoing: Bool) {
        DispatchQueue.main.async {
            let deviceId = device.uuidString ?? ""
            self.devices.removeAll { $0.id == deviceId }
        }
    }

    /// Open the system Image Capture app
    func openImageCapture() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Image Capture.app"))
    }
}

// MARK: - Directory Manager
class DirectoryManager: ObservableObject {
    static let shared = DirectoryManager()

    @Published var watchedDirectories: [WatchedDirectory] {
        didSet { saveDirectories() }
    }

    private let userDefaultsKey = "watchedDirectories"

    private init() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let directories = try? JSONDecoder().decode([WatchedDirectory].self, from: data) {
            self.watchedDirectories = directories
        } else {
            self.watchedDirectories = []
        }
    }

    private func saveDirectories() {
        if let data = try? JSONEncoder().encode(watchedDirectories) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    func addDirectory(_ directory: WatchedDirectory) {
        watchedDirectories.append(directory)
    }

    func removeDirectory(_ directory: WatchedDirectory) {
        watchedDirectories.removeAll { $0.id == directory.id }
    }

    func updateDirectory(_ directory: WatchedDirectory) {
        if let index = watchedDirectories.firstIndex(where: { $0.id == directory.id }) {
            watchedDirectories[index] = directory
        }
    }
}
