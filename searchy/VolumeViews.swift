import SwiftUI
import Foundation

// MARK: - Volume Views

struct VolumeStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    @Environment(\.colorScheme) var colorScheme
    private var pal: AtelierPalette { ThemeManager.shared.palette }

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundColor(pal.ink)
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(pal.ink2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(pal.card)
                .shadow(color: Color.black.opacity(0.06), radius: 12, y: 4)
        )
    }
}

struct VolumeCard: View {
    let volume: ExternalVolume
    @ObservedObject private var volumeManager = VolumeManager.shared
    @State private var showingOptions = false
    @State private var isIndexing = false
    @Environment(\.colorScheme) var colorScheme
    private var pal: AtelierPalette { ThemeManager.shared.palette }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: icon box + name + toggle
            HStack(spacing: 12) {
                Image(systemName: volumeIcon)
                    .font(.system(size: 20))
                    .foregroundColor(pal.accent)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(pal.paper)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(pal.line, lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(volume.name)
                        .font(.system(size: 19, weight: .regular, design: .serif))
                        .italic()
                        .foregroundColor(pal.ink)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        // Online/offline dot
                        Circle()
                            .fill(volume.isOnline ? DesignSystem.Colors.success : pal.ink3)
                            .frame(width: 6, height: 6)
                            .shadow(color: volume.isOnline ? DesignSystem.Colors.success.opacity(0.5) : .clear, radius: 3)

                        Text(volume.isOnline ? "online" : "offline")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(pal.ink3)

                        Text("\u{00B7}")
                            .foregroundColor(pal.ink3)

                        Text(volume.indexStorage == .onVolume ? "portable index" : "centralized")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(pal.ink3)
                    }
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { volume.isEnabled },
                    set: { _ in volumeManager.toggleVolume(volume) }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
                .scaleEffect(0.8)
            }

            // Status row
            HStack(spacing: 10) {
                if volume.imageCount > 0 {
                    Text("\(volume.imageCount.formatted()) photos")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(pal.ink)
                }

                if let lastIndexed = volume.lastIndexed {
                    Text("indexed ")
                        .font(.system(size: 12, weight: .regular, design: .serif))
                        .italic()
                        .foregroundColor(pal.ink3)
                    + Text(lastIndexed, style: .relative)
                        .font(.system(size: 12, weight: .regular, design: .serif))
                        .italic()
                        .foregroundColor(pal.ink3)
                } else if volume.imageCount == 0 {
                    Text("not yet indexed")
                        .font(.system(size: 12, weight: .regular, design: .serif))
                        .italic()
                        .foregroundColor(pal.ink3)
                }

                Spacer()

                // Action buttons
                if isIndexing {
                    Text("indexing\u{2026}")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(pal.accent)
                } else if volume.isOnline {
                    Button(action: { indexVolume() }) {
                        Text(volume.imageCount == 0 ? "Index now" : "Re-index")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(RoundedRectangle(cornerRadius: 6).fill(pal.accent))
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                Button(action: { showingOptions = true }) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 12))
                        .foregroundColor(pal.ink3)
                        .padding(6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(pal.line, lineWidth: 1)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .popover(isPresented: $showingOptions) {
                    VolumeOptionsPopover(volume: volume, isPresented: $showingOptions)
                }

                if volume.type == .manual {
                    Button(action: { volumeManager.removeVolume(volume) }) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundColor(DesignSystem.Colors.error)
                            .padding(6)
                            .background(
                                Circle()
                                    .fill(DesignSystem.Colors.error.opacity(0.1))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(pal.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(pal.line, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 9, x: 0, y: 4)
        .opacity(volume.isOnline ? 1.0 : 0.7)
    }

    private var volumeIcon: String {
        switch volume.type {
        case .external: return "externaldrive.fill"
        case .network: return "server.rack"
        case .raid: return "externaldrive.fill.badge.plus"
        case .manual: return "folder.fill"
        }
    }

    private func indexVolume() {
        guard volume.isOnline else { return }
        isIndexing = true

        // Create request body for volume indexing
        let requestBody: [String: Any] = [
            "volume_path": volume.path,
            "index_path": volume.indexFilePath,
            "fast_indexing": true,
            "max_dimension": 384,
            "batch_size": 64
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody),
              let url = URL(string: "http://127.0.0.1:7860/volume/index") else {
            isIndexing = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let data = data,
                   let result = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let totalImages = result["total_images"] as? Int {
                        // Update volume stats when complete
                        volumeManager.updateVolumeStats(volume.id, imageCount: totalImages)
                    }
                }
                isIndexing = false
            }
        }.resume()
    }
}

struct VolumeOptionsPopover: View {
    let volume: ExternalVolume
    @Binding var isPresented: Bool
    @ObservedObject private var volumeManager = VolumeManager.shared
    @Environment(\.colorScheme) var colorScheme
    private var pal: AtelierPalette { ThemeManager.shared.palette }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "gearshape")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(pal.accent)
                Text("Volume Options")
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .italic()
                    .foregroundColor(pal.ink)
            }

            Divider()

            // Index storage location
            VStack(alignment: .leading, spacing: 8) {
                Text("Index Storage")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(pal.ink2)

                Picker("", selection: Binding(
                    get: { volume.indexStorage },
                    set: { volumeManager.setIndexStorage(volume, location: $0) }
                )) {
                    Text("On Volume (Portable)").tag(IndexStorageLocation.onVolume)
                    Text("Centralized (App Data)").tag(IndexStorageLocation.centralized)
                }
                .pickerStyle(.radioGroup)
                .font(.system(size: 12))
            }

            Divider()

            // Index info
            if volumeManager.hasIndex(volume) {
                let size = volumeManager.indexSize(for: volume)
                HStack {
                    Text("Index Size:")
                        .font(.system(size: 12))
                        .foregroundColor(pal.ink)
                    Spacer()
                    Text(volumeManager.formatBytes(size))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(pal.ink2)
                }

                Button(action: {
                    volumeManager.deleteIndex(for: volume)
                    isPresented = false
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                        Text("Delete Index")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(DesignSystem.Colors.error)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(DesignSystem.Colors.error.opacity(0.1))
                    )
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                Text("No index exists for this volume")
                    .font(.system(size: 12))
                    .foregroundColor(pal.ink3)
            }

            Divider()

            // Reveal in Finder
            Button(action: {
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: volume.path)
                isPresented = false
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "folder")
                        .font(.system(size: 10))
                    Text("Reveal in Finder")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(volume.isOnline ? pal.accent : pal.ink3)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(volume.isOnline ? pal.halo : pal.line.opacity(0.3))
                )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!volume.isOnline)
        }
        .padding(12)
        .frame(width: 260)
    }
}

struct AddVolumeSheet: View {
    @Binding var isPresented: Bool
    @State private var volumeName = ""
    @State private var volumePath = ""
    @State private var indexStorage: IndexStorageLocation = .centralized
    @ObservedObject private var volumeManager = VolumeManager.shared
    @Environment(\.colorScheme) var colorScheme
    private var pal: AtelierPalette { ThemeManager.shared.palette }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ADD VOLUME")
                        .font(.system(size: 9.5, weight: .semibold))
                        .tracking(1.6)
                        .foregroundColor(pal.ink3)
                    Text("Add a volume")
                        .font(.system(size: 22, weight: .regular, design: .serif))
                        .foregroundColor(pal.ink)
                    Text("Index an external drive or network path")
                        .font(.system(size: 13, weight: .regular, design: .serif))
                        .italic()
                        .foregroundColor(pal.ink2)
                }
                Spacer()
                Button(action: { isPresented = false }) {
                    ZStack {
                        Circle()
                            .fill(pal.paper)
                            .overlay(Circle().stroke(pal.line, lineWidth: 1))
                            .frame(width: 28, height: 28)
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(pal.ink3)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }

            Rectangle().fill(pal.line).frame(height: 0.5)

            // Name field
            VStack(alignment: .leading, spacing: 6) {
                Text("Name")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(pal.ink2)
                TextField("My Network Drive", text: $volumeName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(pal.line, lineWidth: 1)
                    )
            }

            // Path field
            VStack(alignment: .leading, spacing: 6) {
                Text("Path")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(pal.ink2)
                HStack(spacing: 8) {
                    TextField("/Volumes/MyDrive or smb://server/share", text: $volumePath)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(pal.line, lineWidth: 1)
                        )

                    Button(action: { browseForFolder() }) {
                        Text("Browse")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(pal.accent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(pal.halo)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            // Index storage option
            VStack(alignment: .leading, spacing: 8) {
                Text("Index Storage")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(pal.ink2)

                Picker("", selection: $indexStorage) {
                    VStack(alignment: .leading) {
                        Text("On Volume")
                            .font(.system(size: 13))
                        Text("Portable - index travels with the drive")
                            .font(.system(size: 12))
                            .foregroundColor(pal.ink3)
                    }.tag(IndexStorageLocation.onVolume)

                    VStack(alignment: .leading) {
                        Text("Centralized")
                            .font(.system(size: 13))
                        Text("Stored in app data folder")
                            .font(.system(size: 12))
                            .foregroundColor(pal.ink3)
                    }.tag(IndexStorageLocation.centralized)
                }
                .pickerStyle(.radioGroup)
            }

            Spacer()

            // Action buttons
            HStack {
                Button(action: { isPresented = false }) {
                    Text("Cancel")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(pal.ink2)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04))
                        )
                }
                .buttonStyle(PlainButtonStyle())

                Spacer()

                Button(action: { addVolume() }) {
                    Text("Add Volume")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(pal.isDark ? .white : .white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(volumeName.isEmpty || volumePath.isEmpty ? pal.ink3 : pal.accent)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(volumeName.isEmpty || volumePath.isEmpty)
            }
        }
        .padding(16)
        .frame(width: 420, height: 380)
    }

    private func browseForFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select a folder to add as a volume"

        if panel.runModal() == .OK, let url = panel.url {
            volumePath = url.path
            if volumeName.isEmpty {
                volumeName = url.lastPathComponent
            }
        }
    }

    private func addVolume() {
        let newVolume = ExternalVolume(
            name: volumeName,
            path: volumePath,
            type: .manual,
            indexStorage: indexStorage
        )
        volumeManager.volumes.append(newVolume)
        isPresented = false
    }
}

// MARK: - Device Card

struct DeviceCard: View {
    let device: MobileDevice
    @Environment(\.colorScheme) var colorScheme
    private var pal: AtelierPalette { ThemeManager.shared.palette }
    @ObservedObject private var deviceManager = MobileDeviceManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: device.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(pal.accent)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(pal.halo)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name)
                        .font(.system(size: 14, weight: .regular, design: .serif))
                    .italic()
                        .foregroundColor(pal.ink)
                        .lineLimit(1)

                    Text("Connected")
                        .font(.system(size: 12))
                        .foregroundColor(DesignSystem.Colors.success)
                }

                Spacer()

                // Connected indicator
                Circle()
                    .fill(DesignSystem.Colors.success)
                    .frame(width: 8, height: 8)
            }

            // Info text
            Text("Use Image Capture to import photos, then add the folder to Searchy for indexing.")
                .font(.system(size: 12))
                .foregroundColor(pal.ink2)
                .fixedSize(horizontal: false, vertical: true)

            // Open Image Capture button
            Button(action: { deviceManager.openImageCapture() }) {
                HStack(spacing: 4) {
                    Image(systemName: "camera.aperture")
                        .font(.system(size: 11, weight: .medium))
                    Text("Open Image Capture")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(pal.accent)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(pal.card)
                .shadow(color: Color.black.opacity(0.06), radius: 12, y: 4)
        )
    }
}
