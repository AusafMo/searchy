import SwiftUI
import Foundation

// MARK: - Volume Views

struct VolumeStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(DesignSystem.Colors.primaryText)
            Text(title)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "2C2C2E") : .white)
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

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Header
            HStack {
                // Volume icon based on type
                Image(systemName: volumeIcon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(volume.isOnline ? DesignSystem.Colors.accent : DesignSystem.Colors.secondaryText)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(DesignSystem.Colors.accentSubtle)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(volume.name)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(DesignSystem.Colors.primaryText)
                            .lineLimit(1)
                        if !volume.isOnline {
                            Text("Offline")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(DesignSystem.Colors.warning)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(DesignSystem.Colors.warning.opacity(0.15))
                                )
                        }
                    }
                    Text(volume.path)
                        .font(DesignSystem.Typography.caption2)
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                        .lineLimit(1)
                }

                Spacer()

                // Enable/Disable toggle
                Toggle("", isOn: Binding(
                    get: { volume.isEnabled },
                    set: { _ in volumeManager.toggleVolume(volume) }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
                .scaleEffect(0.8)
            }

            Divider()
                .background(DesignSystem.Colors.border)

            // Stats row
            HStack(spacing: DesignSystem.Spacing.xl) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(volume.imageCount)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(DesignSystem.Colors.primaryText)
                    Text("Images")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                }

                VStack(alignment: .leading, spacing: 2) {
                    if let lastIndexed = volume.lastIndexed {
                        Text(lastIndexed, style: .relative)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(DesignSystem.Colors.primaryText)
                    } else {
                        Text("Never")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                    }
                    Text("Last Indexed")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                }

                Spacer()

                // Storage location badge
                Text(volume.indexStorage == .onVolume ? "On Volume" : "Centralized")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(volume.indexStorage == .onVolume ? DesignSystem.Colors.success : DesignSystem.Colors.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(volume.indexStorage == .onVolume ? DesignSystem.Colors.success.opacity(0.12) : DesignSystem.Colors.accentSubtle)
                    )
            }

            // Action buttons
            HStack(spacing: DesignSystem.Spacing.sm) {
                Button(action: { indexVolume() }) {
                    HStack(spacing: 4) {
                        Image(systemName: isIndexing ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                            .font(.system(size: 10, weight: .medium))
                        Text(isIndexing ? "Indexing..." : "Index")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(volume.isOnline && !isIndexing ? DesignSystem.Colors.accent : DesignSystem.Colors.tertiaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(volume.isOnline && !isIndexing ? DesignSystem.Colors.accentSubtle : DesignSystem.Colors.border.opacity(0.3))
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!volume.isOnline || isIndexing)

                Button(action: { showingOptions = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 10, weight: .medium))
                        Text("Options")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04))
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .popover(isPresented: $showingOptions) {
                    VolumeOptionsPopover(volume: volume, isPresented: $showingOptions)
                }

                Spacer()

                if volume.type == .manual {
                    Button(action: { volumeManager.removeVolume(volume) }) {
                        Image(systemName: "trash")
                            .font(.system(size: 11, weight: .medium))
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
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "2C2C2E") : .white)
                .shadow(color: Color.black.opacity(0.06), radius: 12, y: 4)
        )
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

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Header
            HStack {
                Image(systemName: "gearshape")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.accent)
                Text("Volume Options")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(DesignSystem.Colors.primaryText)
            }

            Divider()

            // Index storage location
            VStack(alignment: .leading, spacing: 8) {
                Text("Index Storage")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.secondaryText)

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
                        .foregroundColor(DesignSystem.Colors.primaryText)
                    Spacer()
                    Text(volumeManager.formatBytes(size))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
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
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
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
                .foregroundColor(volume.isOnline ? DesignSystem.Colors.accent : DesignSystem.Colors.tertiaryText)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(volume.isOnline ? DesignSystem.Colors.accentSubtle : DesignSystem.Colors.border.opacity(0.3))
                )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!volume.isOnline)
        }
        .padding(DesignSystem.Spacing.md)
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

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "externaldrive.badge.plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.accent)
                    Text("Add Manual Path")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(DesignSystem.Colors.primaryText)
                }
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                }
                .buttonStyle(PlainButtonStyle())
            }

            Divider()

            // Name field
            VStack(alignment: .leading, spacing: 6) {
                Text("Name")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
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
                            .stroke(DesignSystem.Colors.border, lineWidth: 1)
                    )
            }

            // Path field
            VStack(alignment: .leading, spacing: 6) {
                Text("Path")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
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
                                .stroke(DesignSystem.Colors.border, lineWidth: 1)
                        )

                    Button(action: { browseForFolder() }) {
                        Text("Browse")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.accent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(DesignSystem.Colors.accentSubtle)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            // Index storage option
            VStack(alignment: .leading, spacing: 8) {
                Text("Index Storage")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.secondaryText)

                Picker("", selection: $indexStorage) {
                    VStack(alignment: .leading) {
                        Text("On Volume")
                            .font(.system(size: 13))
                        Text("Portable - index travels with the drive")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                    }.tag(IndexStorageLocation.onVolume)

                    VStack(alignment: .leading) {
                        Text("Centralized")
                            .font(.system(size: 13))
                        Text("Stored in app data folder")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
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
                        .foregroundColor(DesignSystem.Colors.secondaryText)
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
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(volumeName.isEmpty || volumePath.isEmpty ? DesignSystem.Colors.tertiaryText : DesignSystem.Colors.accent)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(volumeName.isEmpty || volumePath.isEmpty)
            }
        }
        .padding(DesignSystem.Spacing.lg)
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
    @ObservedObject private var deviceManager = MobileDeviceManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Header
            HStack {
                Image(systemName: device.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.accent)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(DesignSystem.Colors.accentSubtle)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(DesignSystem.Colors.primaryText)
                        .lineLimit(1)

                    Text("Connected")
                        .font(DesignSystem.Typography.caption)
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
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.secondaryText)
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
                        .fill(DesignSystem.Colors.accent)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "2C2C2E") : .white)
                .shadow(color: Color.black.opacity(0.06), radius: 12, y: 4)
        )
    }
}
