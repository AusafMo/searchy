import SwiftUI
import Combine

class GalleryManager: ObservableObject {
    static let shared = GalleryManager()

    // MARK: - Published State

    /// All scanned media items, sorted reverse chronological
    @Published private(set) var allItems: [GalleryItem] = []

    /// Grouped for display: ordered array of (groupKey, items)
    @Published private(set) var groupedItems: [(key: String, items: [GalleryItem])] = []

    /// Filtered results when gallery search is active (nil = no filter)
    @Published private(set) var filteredGroupedItems: [(key: String, items: [GalleryItem])]? = nil

    /// Folders
    @Published var folders: [GalleryFolder] = []
    @Published var selectedFolderId: UUID? = nil

    /// Scanning state
    @Published private(set) var isScanning = false
    @Published private(set) var scanProgress: Double = 0
    @Published private(set) var totalItemCount: Int = 0

    /// Gallery sub-view
    @Published var activeSubView: GallerySubView = .photos

    /// Search
    @Published var gallerySearchText: String = ""
    @Published private(set) var isSearchingGallery = false

    /// Video duration cache
    @Published private(set) var durationCache: [String: Double] = [:]

    // MARK: - Private

    private var scanTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    private let favoritesFolderIdKey = "galleryFavoritesFolderId"
    private var favoritesFolderId: UUID {
        if let str = UserDefaults.standard.string(forKey: favoritesFolderIdKey),
           let id = UUID(uuidString: str) {
            return id
        }
        let id = UUID()
        UserDefaults.standard.set(id.uuidString, forKey: favoritesFolderIdKey)
        return id
    }

    private var foldersFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("searchy/gallery_folders.json")
    }

    // MARK: - Init

    private init() {
        loadFolders()
        migrateFromFavorites()
        setupSearchDebounce()
    }

    // MARK: - Search Debounce

    private func setupSearchDebounce() {
        $gallerySearchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                self?.performGallerySearch(query: query)
            }
            .store(in: &cancellables)
    }

    // MARK: - File Scanning

    func scanAllDirectories() {
        guard !isScanning else { return }

        scanTask?.cancel()
        isScanning = true
        scanProgress = 0
        allItems = []
        totalItemCount = 0

        let directories = DirectoryManager.shared.watchedDirectories

        scanTask = Task.detached(priority: .utility) { [weak self] in
            var items: [GalleryItem] = []
            let fm = FileManager.default
            let resourceKeys: Set<URLResourceKey> = [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey]
            let totalDirs = directories.count

            for (dirIndex, dir) in directories.enumerated() {
                if Task.isCancelled { return }

                let dirURL = URL(fileURLWithPath: dir.path)
                guard let enumerator = fm.enumerator(
                    at: dirURL,
                    includingPropertiesForKeys: Array(resourceKeys),
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]
                ) else { continue }

                var batchItems: [GalleryItem] = []

                for case let fileURL as URL in enumerator {
                    if Task.isCancelled { return }

                    let ext = fileURL.pathExtension.lowercased()
                    guard GalleryItem.allExtensions.contains(ext) else { continue }

                    guard let resourceValues = try? fileURL.resourceValues(forKeys: resourceKeys),
                          resourceValues.isRegularFile == true else { continue }

                    let modDate = resourceValues.contentModificationDate ?? Date.distantPast
                    let mediaType: MediaType = GalleryItem.videoExtensions.contains(ext) ? .video : .image

                    let item = GalleryItem(
                        id: fileURL.path,
                        path: fileURL.path,
                        fileName: fileURL.lastPathComponent,
                        fileExtension: ext,
                        size: Int64(resourceValues.fileSize ?? 0),
                        modificationDate: modDate,
                        mediaType: mediaType,
                        duration: nil,
                        dateGroupKey: GalleryItem.dateGroupKey(for: modDate)
                    )
                    batchItems.append(item)

                    if batchItems.count >= 500 {
                        let batch = batchItems
                        batchItems = []
                        await MainActor.run {
                            self?.allItems.append(contentsOf: batch)
                            self?.totalItemCount = self?.allItems.count ?? 0
                        }
                    }
                }

                // Flush remaining batch
                if !batchItems.isEmpty {
                    let batch = batchItems
                    await MainActor.run {
                        self?.allItems.append(contentsOf: batch)
                        self?.totalItemCount = self?.allItems.count ?? 0
                    }
                }

                let progress = Double(dirIndex + 1) / Double(max(totalDirs, 1))
                await MainActor.run {
                    self?.scanProgress = progress
                }
            }

            // Final sort and group
            await MainActor.run {
                self?.allItems.sort { $0.modificationDate > $1.modificationDate }
                self?.totalItemCount = self?.allItems.count ?? 0
                self?.rebuildGroups()
                self?.detectAutoFolders()
                self?.isScanning = false
                self?.scanProgress = 1.0
            }
        }
    }

    // MARK: - Date Grouping

    private func rebuildGroups(from items: [GalleryItem]? = nil) {
        let source = items ?? allItems
        var grouped: [String: [GalleryItem]] = [:]
        var order: [String] = []

        for item in source {
            if grouped[item.dateGroupKey] == nil {
                order.append(item.dateGroupKey)
                grouped[item.dateGroupKey] = []
            }
            grouped[item.dateGroupKey]?.append(item)
        }

        let result = order.map { (key: $0, items: grouped[$0]!) }

        if items != nil {
            filteredGroupedItems = result
        } else {
            groupedItems = result
            filteredGroupedItems = nil
        }
    }

    // MARK: - Gallery Search

    private func performGallerySearch(query: String) {
        searchTask?.cancel()

        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            filteredGroupedItems = nil
            isSearchingGallery = false
            return
        }

        isSearchingGallery = true

        searchTask = Task { @MainActor [weak self] in
            guard let self = self else { return }

            // Call the backend search API
            guard let serverURL = await self.getServerURL() else {
                self.isSearchingGallery = false
                return
            }

            let url = serverURL.appendingPathComponent("search")
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")

            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dataDir = appSupport.appendingPathComponent("searchy").path

            let body: [String: Any] = [
                "query": query,
                "top_k": 200,
                "data_dir": dataDir
            ]

            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
                let (data, _) = try await URLSession.shared.data(for: request)
                let response = try JSONDecoder().decode(SearchResponse.self, from: data)

                if Task.isCancelled { return }

                let matchingPaths = Set(response.results.map { $0.path })
                let filtered = self.allItems.filter { matchingPaths.contains($0.path) }
                self.rebuildGroups(from: filtered)
                self.isSearchingGallery = false
            } catch {
                if !Task.isCancelled {
                    self.isSearchingGallery = false
                }
            }
        }
    }

    private func getServerURL() async -> URL? {
        // Match the pattern from SearchManager — read from AppDelegate's serverURL
        // The port is stored in UserDefaults by AppDelegate
        let port = UserDefaults.standard.integer(forKey: "serverPort")
        if port > 0 {
            return URL(string: "http://127.0.0.1:\(port)")
        }
        // Fallback to default port from AppConfig
        return URL(string: "http://127.0.0.1:\(AppConfig.shared.defaultPort)")
    }

    // MARK: - Video Duration

    func loadDuration(for path: String) {
        guard durationCache[path] == nil else { return }
        Task {
            if let duration = await VideoThumbnailService.shared.videoDuration(for: path) {
                await MainActor.run {
                    self.durationCache[path] = duration
                }
            }
        }
    }

    func formattedDuration(for path: String) -> String? {
        guard let duration = durationCache[path] else { return nil }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Auto-Folder Detection

    private func detectAutoFolders() {
        let patterns: [(FolderKind, [String], String, String)] = [
            (.screenshots, ["/Screenshots", "/Screen Shot"], "Screenshots", "camera.viewfinder"),
            (.whatsapp, ["/WhatsApp Images", "/WhatsApp/Media"], "WhatsApp", "message.fill"),
            (.telegram, ["/Telegram", "/Telegram Desktop"], "Telegram", "paperplane.fill"),
            (.downloads, ["/Downloads"], "Downloads", "arrow.down.circle.fill"),
        ]

        var autoFolders: [GalleryFolder] = []

        for (kind, pathPatterns, name, icon) in patterns {
            let matchingItems = allItems.filter { item in
                pathPatterns.contains(where: { item.path.contains($0) })
            }
            if !matchingItems.isEmpty {
                autoFolders.append(GalleryFolder(
                    id: UUID(),
                    name: name,
                    icon: icon,
                    kind: kind,
                    paths: matchingItems.map(\.path),
                    itemCount: matchingItems.count
                ))
            }
        }

        // Rebuild: favorites + auto + user-created
        let userFolders = folders.filter { $0.kind == .userCreated }
        folders = [buildFavoritesFolder()] + autoFolders + userFolders
        saveFolders()
    }

    private func buildFavoritesFolder() -> GalleryFolder {
        let favPaths = Array(FavoritesManager.shared.favorites)
        return GalleryFolder(
            id: favoritesFolderId,
            name: "Favorites",
            icon: "heart.fill",
            kind: .favorites,
            paths: favPaths,
            itemCount: favPaths.count
        )
    }

    // MARK: - Folder CRUD

    func createFolder(name: String) {
        let folder = GalleryFolder(
            name: name,
            icon: "folder.fill",
            kind: .userCreated
        )
        folders.append(folder)
        saveFolders()
    }

    func renameFolder(id: UUID, name: String) {
        guard let index = folders.firstIndex(where: { $0.id == id }) else { return }
        folders[index].name = name
        saveFolders()
    }

    func deleteFolder(id: UUID) {
        folders.removeAll { $0.id == id }
        if selectedFolderId == id { selectedFolderId = nil }
        saveFolders()
    }

    func addToFolder(id: UUID, paths: [String]) {
        guard let index = folders.firstIndex(where: { $0.id == id }) else { return }
        let existing = Set(folders[index].paths)
        let newPaths = paths.filter { !existing.contains($0) }
        folders[index].paths.append(contentsOf: newPaths)
        folders[index].itemCount = folders[index].paths.count
        saveFolders()
    }

    func removeFromFolder(id: UUID, path: String) {
        guard let index = folders.firstIndex(where: { $0.id == id }) else { return }
        folders[index].paths.removeAll { $0 == path }
        folders[index].itemCount = folders[index].paths.count
        saveFolders()
    }

    func itemsForFolder(_ folder: GalleryFolder) -> [GalleryItem] {
        let pathSet = Set(folder.paths)
        return allItems.filter { pathSet.contains($0.path) }
    }

    // MARK: - Persistence

    private func saveFolders() {
        // Only save user-created folders (auto-detected are rebuilt each scan)
        let toSave = folders.filter { $0.kind == .userCreated || $0.kind == .favorites }
        guard let data = try? JSONEncoder().encode(toSave) else { return }
        try? data.write(to: foldersFileURL)
    }

    private func loadFolders() {
        guard let data = try? Data(contentsOf: foldersFileURL),
              let loaded = try? JSONDecoder().decode([GalleryFolder].self, from: data) else {
            folders = [buildFavoritesFolder()]
            return
        }
        folders = loaded
    }

    // MARK: - Migration

    private func migrateFromFavorites() {
        let migrationKey = "galleryMigrationComplete"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let searchyDir = appSupport.appendingPathComponent("searchy")

        // Migrate collections -> user folders
        let collectionsURL = searchyDir.appendingPathComponent("collections.json")
        if let data = try? Data(contentsOf: collectionsURL),
           let collections = try? JSONDecoder().decode([FavoriteCollection].self, from: data) {
            for collection in collections {
                let folder = GalleryFolder(
                    name: collection.name,
                    icon: collection.icon,
                    kind: .userCreated,
                    paths: collection.paths,
                    itemCount: collection.paths.count
                )
                folders.append(folder)
            }
            saveFolders()
        }

        UserDefaults.standard.set(true, forKey: migrationKey)
    }
}
