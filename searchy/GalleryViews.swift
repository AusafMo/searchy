import SwiftUI
import AVKit

// MARK: - Gallery Tab Content

struct GalleryTabContent: View {
    @ObservedObject private var galleryManager = GalleryManager.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    private var pal: AtelierPalette { themeManager.palette }

    var body: some View {
        VStack(spacing: 0) {
            galleryHeader

            // Scan progress bar
            if galleryManager.isScanning {
                GeometryReader { geo in
                    Rectangle()
                        .fill(pal.accent.opacity(0.6))
                        .frame(width: geo.size.width * galleryManager.scanProgress, height: 2)
                        .animation(.linear(duration: 0.3), value: galleryManager.scanProgress)
                }
                .frame(height: 2)
            }

            // Content
            switch galleryManager.activeSubView {
            case .photos:
                GalleryPhotosView()
            case .folders:
                if let folderId = galleryManager.selectedFolderId,
                   let folder = galleryManager.folders.first(where: { $0.id == folderId }) {
                    GalleryFolderDetailView(folder: folder)
                } else {
                    GalleryFoldersView()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if galleryManager.allItems.isEmpty && !galleryManager.isScanning {
                galleryManager.scanAllDirectories()
            }
        }
    }

    // MARK: - Header

    private var galleryHeader: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Gallery")
                    .font(.system(size: 28, weight: .regular, design: .serif))
                    .foregroundColor(pal.ink)

                Spacer()

                // Stats pill
                if galleryManager.totalItemCount > 0 {
                    galleryStatsPill
                }

                // Refresh
                Button(action: { galleryManager.scanAllDirectories() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(pal.ink3)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(pal.card))
                        .overlay(Circle().stroke(pal.line, lineWidth: 0.5))
                }
                .buttonStyle(PlainButtonStyle())
                .rotationEffect(galleryManager.isScanning ? .degrees(360) : .zero)
                .animation(galleryManager.isScanning ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: galleryManager.isScanning)
            }
            .padding(.horizontal, 28)
            .padding(.top, 20)
            .padding(.bottom, 6)

            // Sub-view tabs
            gallerySubViewPicker
        }
    }

    private var galleryStatsPill: some View {
        let photoCount = galleryManager.allItems.filter { $0.mediaType == .image }.count
        let videoCount = galleryManager.allItems.filter { $0.mediaType == .video }.count
        let totalBytes = galleryManager.allItems.reduce(Int64(0)) { $0 + $1.size }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        let sizeStr = formatter.string(fromByteCount: totalBytes)

        return HStack(spacing: 6) {
            if photoCount > 0 {
                Label("\(photoCount.formatted())", systemImage: "photo")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
            }
            if videoCount > 0 {
                Label("\(videoCount.formatted())", systemImage: "video")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
            }
            Text("·")
                .font(.system(size: 10))
            Text(sizeStr)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
        }
        .foregroundColor(pal.ink3)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Capsule().fill(pal.card))
        .overlay(Capsule().stroke(pal.line, lineWidth: 0.5))
        .padding(.trailing, 8)
    }

    // MARK: - Sub-view Picker

    private var gallerySubViewPicker: some View {
        HStack(spacing: 24) {
            ForEach([GallerySubView.photos, .folders], id: \.self) { subView in
                let isActive = galleryManager.activeSubView == subView
                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        if subView == .photos { galleryManager.selectedFolderId = nil }
                        galleryManager.activeSubView = subView
                    }
                }) {
                    VStack(spacing: 6) {
                        Text(subView == .photos ? "Photos" : "Folders")
                            .font(.system(size: 13, weight: isActive ? .semibold : .medium))
                            .foregroundColor(isActive ? pal.ink : pal.ink3)
                        Rectangle()
                            .fill(isActive ? pal.accent : Color.clear)
                            .frame(height: 2)
                            .cornerRadius(1)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            Spacer()
        }
        .padding(.horizontal, 28)
        .overlay(alignment: .bottom) {
            Rectangle().fill(pal.line).frame(height: 0.5)
        }
    }
}

// MARK: - Photos View

struct GalleryPhotosView: View {
    @ObservedObject private var galleryManager = GalleryManager.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    private var pal: AtelierPalette { themeManager.palette }

    private var displayGroups: [(key: String, items: [GalleryItem])] {
        galleryManager.filteredGroupedItems ?? galleryManager.groupedItems
    }

    private let columns = [GridItem(.adaptive(minimum: 120, maximum: 200), spacing: 2)]

    var body: some View {
        VStack(spacing: 0) {
            gallerySearchBar

            if galleryManager.isScanning && galleryManager.allItems.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Scanning directories...")
                        .font(.system(size: 13, weight: .medium, design: .serif).italic())
                        .foregroundColor(pal.ink3)
                }
                Spacer()
            } else if displayGroups.isEmpty {
                Spacer()
                galleryEmptyState
                Spacer()
            } else {
                ZStack(alignment: .trailing) {
                    // Main scrollable grid
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                                ForEach(displayGroups, id: \.key) { group in
                                    Section(header: dateGroupHeader(group.key, count: group.items.count)) {
                                        LazyVGrid(columns: columns, spacing: 2) {
                                            ForEach(group.items) { item in
                                                GalleryItemTile(item: item)
                                            }
                                        }
                                        .padding(.bottom, 8)
                                    }
                                    .id(group.key)
                                }
                            }
                            .padding(.horizontal, 2)
                        }
                        .onReceive(NotificationCenter.default.publisher(for: .galleryScrollToSection)) { notification in
                            if let sectionKey = notification.object as? String {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    proxy.scrollTo(sectionKey, anchor: .top)
                                }
                            }
                        }
                    }

                    // Timeline scrubber
                    if displayGroups.count > 3 {
                        timelineScrubber
                    }
                }
            }
        }
    }

    // MARK: - Search Bar

    private var gallerySearchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(pal.ink3)

            TextField("Search photos...", text: $galleryManager.gallerySearchText)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 12, weight: .regular, design: .serif))
                .foregroundColor(pal.ink)

            if !galleryManager.gallerySearchText.isEmpty {
                if galleryManager.isSearchingGallery {
                    ProgressView()
                        .scaleEffect(0.4)
                } else {
                    Button(action: { galleryManager.gallerySearchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(pal.ink3)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(pal.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(pal.line, lineWidth: 0.5)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Date Group Header

    private func dateGroupHeader(_ key: String, count: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(key)
                .font(.system(size: 14, weight: .semibold, design: .serif))
                .foregroundColor(pal.ink)
            Text("\(count) items")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(pal.ink3)
            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(
            pal.paper
                .shadow(color: Color.black.opacity(0.03), radius: 4, y: 2)
        )
    }

    // MARK: - Timeline Scrubber

    @State private var scrubberHovered = false
    @State private var scrubberDragLabel: String?

    private var timelineScrubber: some View {
        GeometryReader { geo in
            let labels = displayGroups.map { $0.key }
            let height = geo.size.height
            let itemHeight = max(height / CGFloat(labels.count), 18)

            VStack(spacing: 0) {
                ForEach(Array(labels.enumerated()), id: \.offset) { idx, label in
                    Text(shortLabel(label))
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(scrubberDragLabel == label ? .white : pal.ink3)
                        .frame(height: itemHeight)
                        .frame(width: scrubberHovered ? 44 : 20)
                        .background(
                            scrubberDragLabel == label
                                ? Capsule().fill(pal.accent).frame(height: 18)
                                : nil
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            // ScrollViewReader proxy not accessible here — use notification
                            NotificationCenter.default.post(
                                name: .galleryScrollToSection,
                                object: label
                            )
                        }
                        .onHover { hovering in
                            scrubberDragLabel = hovering ? label : nil
                        }
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.vertical, 8)
        }
        .frame(width: scrubberHovered ? 48 : 24)
        .background(pal.paper.opacity(0.8))
        .onHover { scrubberHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: scrubberHovered)
    }

    private func shortLabel(_ label: String) -> String {
        if label == "Today" { return "Now" }
        if label == "Yesterday" { return "Yest" }
        // "April 2026" -> "Apr 26"
        let parts = label.split(separator: " ")
        if parts.count == 2 {
            let month = String(parts[0].prefix(3))
            let year = String(parts[1].suffix(2))
            return "\(month) \(year)"
        }
        return String(label.prefix(6))
    }

    // MARK: - Empty State

    private var galleryEmptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: galleryManager.gallerySearchText.isEmpty ? "photo.on.rectangle.angled" : "magnifyingglass")
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundColor(pal.ink3)
            Text(galleryManager.gallerySearchText.isEmpty ? "No photos yet" : "No results")
                .font(.system(size: 20, weight: .regular, design: .serif))
                .foregroundColor(pal.ink2)
            Text(galleryManager.gallerySearchText.isEmpty
                 ? "Add watched directories in Settings to see your photos here."
                 : "Try a different search term.")
                .font(.system(size: 13, weight: .regular, design: .serif).italic())
                .foregroundColor(pal.ink3)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
    }
}

// MARK: - Gallery Notifications

extension Notification.Name {
    static let galleryScrollToSection = Notification.Name("galleryScrollToSection")
    static let galleryOpenLightbox = Notification.Name("galleryOpenLightbox")
}

// MARK: - Gallery Item Tile

struct GalleryItemTile: View {
    let item: GalleryItem
    @ObservedObject private var galleryManager = GalleryManager.shared
    @ObservedObject private var favoritesManager = FavoritesManager.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    private var pal: AtelierPalette { themeManager.palette }

    @State private var thumbnail: NSImage?
    @State private var isHovered = false
    @State private var showVideoPlayer = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Thumbnail
            GeometryReader { geo in
                if let image = thumbnail {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(pal.card)
                }
            }
            .aspectRatio(1, contentMode: .fit)

            // Video duration badge (bottom-right)
            if item.mediaType == .video {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        videoDurationBadge
                    }
                }
            }

            // Favorite indicator (top-right, always visible if favorited)
            if favoritesManager.isFavorite(item.path) {
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "heart.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Circle().fill(Color.red.opacity(0.8)))
                            .padding(5)
                    }
                }
            }

            // Hover overlay
            if isHovered {
                hoverOverlay
            }
        }
        .onHover { isHovered = $0 }
        .onAppear { loadThumbnail() }
        .onTapGesture {
            if item.mediaType == .video {
                showVideoPlayer = true
            } else {
                NotificationCenter.default.post(
                    name: .galleryOpenLightbox,
                    object: nil,
                    userInfo: ["path": item.path]
                )
            }
        }
        .sheet(isPresented: $showVideoPlayer) {
            GalleryVideoPlayerSheet(path: item.path, fileName: item.fileName)
        }
        .contextMenu { itemContextMenu }
    }

    // MARK: - Video Badge

    private var videoDurationBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "play.fill")
                .font(.system(size: 6))
            if let duration = galleryManager.formattedDuration(for: item.path) {
                Text(duration)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 5)
        .padding(.vertical, 2.5)
        .background(
            Capsule().fill(Color.black.opacity(0.65))
        )
        .padding(5)
        .onAppear { galleryManager.loadDuration(for: item.path) }
    }

    // MARK: - Hover Overlay

    @ViewBuilder
    private var hoverOverlay: some View {
        ZStack {
            // Subtle border on hover
            Rectangle()
                .stroke(pal.accent.opacity(0.5), lineWidth: 2)

            // Bottom gradient with filename
            VStack {
                Spacer()
                HStack(spacing: 6) {
                    Text(item.fileName)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    // Heart
                    Button(action: { favoritesManager.toggleFavorite(item.path) }) {
                        Image(systemName: favoritesManager.isFavorite(item.path) ? "heart.fill" : "heart")
                            .font(.system(size: 10))
                            .foregroundColor(favoritesManager.isFavorite(item.path) ? .red : .white)
                    }
                    .buttonStyle(PlainButtonStyle())

                    // Finder
                    Button(action: {
                        NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
                    }) {
                        Image(systemName: "folder")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
                .background(
                    LinearGradient(
                        colors: [.clear, Color.black.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var itemContextMenu: some View {
        Button("Reveal in Finder") {
            NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
        }

        if item.mediaType == .image {
            Button("Find Similar") {
                SearchManager.shared.findSimilar(imagePath: item.path, numberOfResults: SearchPreferences.shared.numberOfResults)
            }
        }

        Divider()

        Button(favoritesManager.isFavorite(item.path) ? "Remove from Favorites" : "Add to Favorites") {
            favoritesManager.toggleFavorite(item.path)
        }

        let userFolders = galleryManager.folders.filter { $0.kind == .userCreated }
        if !userFolders.isEmpty {
            Menu("Add to Folder") {
                ForEach(userFolders) { folder in
                    Button(folder.name) {
                        galleryManager.addToFolder(id: folder.id, paths: [item.path])
                    }
                }
            }
        }
    }

    // MARK: - Thumbnail Loading

    private func loadThumbnail() {
        switch item.mediaType {
        case .image:
            ThumbnailService.shared.loadThumbnail(for: item.path, maxSize: 300) { img in
                self.thumbnail = img
            }
        case .video:
            VideoThumbnailService.shared.loadThumbnail(for: item.path, maxSize: 300) { img in
                self.thumbnail = img
            }
        }
    }
}

// MARK: - Folders View

struct GalleryFoldersView: View {
    @ObservedObject private var galleryManager = GalleryManager.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    private var pal: AtelierPalette { themeManager.palette }

    @State private var showNewFolderAlert = false
    @State private var newFolderName = ""

    private var autoFolders: [GalleryFolder] {
        galleryManager.folders.filter { $0.isAutoDetected }
    }
    private var userFolders: [GalleryFolder] {
        galleryManager.folders.filter { $0.kind == .userCreated }
    }
    private var favoritesFolder: GalleryFolder? {
        galleryManager.folders.first { $0.kind == .favorites }
    }

    private let folderColumns = [GridItem(.adaptive(minimum: 180, maximum: 260), spacing: 16)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // Favorites
                if let fav = favoritesFolder, fav.itemCount > 0 {
                    folderSection(title: "FAVORITES", folders: [fav])
                }

                // Auto-detected
                if !autoFolders.isEmpty {
                    folderSection(title: "AUTO-DETECTED", folders: autoFolders)
                }

                // User folders
                VStack(alignment: .leading, spacing: 14) {
                    Text("YOUR FOLDERS")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.6)
                        .foregroundColor(pal.ink3)

                    LazyVGrid(columns: folderColumns, spacing: 16) {
                        ForEach(userFolders) { folder in
                            GalleryFolderCard(folder: folder)
                        }
                        newFolderButton
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
        }
        .alert("New Folder", isPresented: $showNewFolderAlert) {
            TextField("Folder name", text: $newFolderName)
            Button("Cancel", role: .cancel) { newFolderName = "" }
            Button("Create") {
                let name = newFolderName.trimmingCharacters(in: .whitespaces)
                if !name.isEmpty {
                    galleryManager.createFolder(name: name)
                    newFolderName = ""
                }
            }
        }
    }

    private func folderSection(title: String, folders: [GalleryFolder]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.6)
                .foregroundColor(pal.ink3)

            LazyVGrid(columns: folderColumns, spacing: 16) {
                ForEach(folders) { folder in
                    GalleryFolderCard(folder: folder)
                }
            }
        }
    }

    private var newFolderButton: some View {
        Button(action: { showNewFolderAlert = true }) {
            VStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(pal.ink3)
                Text("New Folder")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(pal.ink3)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 150)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(pal.line, style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Folder Card (mosaic cover)

struct GalleryFolderCard: View {
    let folder: GalleryFolder
    @ObservedObject private var galleryManager = GalleryManager.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    private var pal: AtelierPalette { themeManager.palette }

    @State private var coverThumbnails: [NSImage] = []
    @State private var isHovered = false

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                galleryManager.selectedFolderId = folder.id
            }
        }) {
            VStack(alignment: .leading, spacing: 0) {
                // Mosaic cover
                ZStack {
                    if coverThumbnails.isEmpty {
                        Rectangle().fill(pal.card)
                        Image(systemName: folder.icon)
                            .font(.system(size: 24, weight: .light))
                            .foregroundColor(pal.ink3)
                    } else if coverThumbnails.count == 1 {
                        Image(nsImage: coverThumbnails[0])
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        // 2x2 mosaic
                        GeometryReader { geo in
                            let w = geo.size.width / 2
                            let h = geo.size.height / 2
                            VStack(spacing: 1) {
                                HStack(spacing: 1) {
                                    mosaicCell(coverThumbnails[safe: 0], width: w, height: h)
                                    mosaicCell(coverThumbnails[safe: 1], width: w, height: h)
                                }
                                HStack(spacing: 1) {
                                    mosaicCell(coverThumbnails[safe: 2], width: w, height: h)
                                    mosaicCell(coverThumbnails[safe: 3], width: w, height: h)
                                }
                            }
                        }
                    }
                }
                .frame(height: 110)
                .clipped()

                // Label
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Image(systemName: folder.icon)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(pal.accent)
                        Text(folder.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(pal.ink)
                            .lineLimit(1)
                    }
                    Text("\(folder.itemCount) items")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(pal.ink3)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .background(pal.card)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isHovered ? pal.accent.opacity(0.5) : pal.line, lineWidth: isHovered ? 1.5 : 1)
            )
            .shadow(color: Color.black.opacity(isHovered ? 0.1 : 0.04), radius: isHovered ? 12 : 6, y: isHovered ? 4 : 2)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .onAppear { loadCovers() }
        .contextMenu {
            if folder.kind == .userCreated {
                Button("Delete Folder", role: .destructive) {
                    galleryManager.deleteFolder(id: folder.id)
                }
            }
        }
    }

    @ViewBuilder
    private func mosaicCell(_ image: NSImage?, width: CGFloat, height: CGFloat) -> some View {
        if let img = image {
            Image(nsImage: img)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: width, height: height)
                .clipped()
        } else {
            Rectangle()
                .fill(pal.card)
                .frame(width: width, height: height)
        }
    }

    private func loadCovers() {
        let paths = Array(folder.paths.prefix(4))
        guard !paths.isEmpty else { return }

        for path in paths {
            let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
            if GalleryItem.videoExtensions.contains(ext) {
                VideoThumbnailService.shared.loadThumbnail(for: path, maxSize: 200) { img in
                    if let img = img { self.coverThumbnails.append(img) }
                }
            } else {
                ThumbnailService.shared.loadThumbnail(for: path, maxSize: 200) { img in
                    if let img = img { self.coverThumbnails.append(img) }
                }
            }
        }
    }
}

// Safe array subscript
extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Folder Detail View

struct GalleryFolderDetailView: View {
    let folder: GalleryFolder
    @ObservedObject private var galleryManager = GalleryManager.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    private var pal: AtelierPalette { themeManager.palette }

    private var folderItems: [GalleryItem] {
        galleryManager.itemsForFolder(folder)
    }

    private let columns = [GridItem(.adaptive(minimum: 120, maximum: 200), spacing: 2)]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Back + title
            HStack(spacing: 10) {
                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        galleryManager.selectedFolderId = nil
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(pal.accent)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(pal.card))
                }
                .buttonStyle(PlainButtonStyle())

                Image(systemName: folder.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(pal.accent)

                Text(folder.name)
                    .font(.system(size: 20, weight: .regular, design: .serif))
                    .foregroundColor(pal.ink)

                Text("\(folder.itemCount) items")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(pal.ink3)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Rectangle().fill(pal.line).frame(height: 0.5)

            if folderItems.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "folder")
                        .font(.system(size: 36, weight: .ultraLight))
                        .foregroundColor(pal.ink3)
                    Text("This folder is empty")
                        .font(.system(size: 14, weight: .regular, design: .serif).italic())
                        .foregroundColor(pal.ink3)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(folderItems) { item in
                            GalleryItemTile(item: item)
                        }
                    }
                    .padding(2)
                }
            }
        }
    }
}

// MARK: - Video Player Sheet

struct GalleryVideoPlayerSheet: View {
    let path: String
    let fileName: String
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeManager = ThemeManager.shared
    private var pal: AtelierPalette { themeManager.palette }
    @State private var player: AVPlayer?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(fileName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(pal.ink)
                        .lineLimit(1)
                    Text(URL(fileURLWithPath: path).deletingLastPathComponent().lastPathComponent)
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundColor(pal.ink3)
                        .lineLimit(1)
                }
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(pal.ink3)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(pal.card))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(pal.paper)

            // Player
            if let player = player {
                VideoPlayer(player: player)
                    .frame(minWidth: 640, minHeight: 400)
            } else {
                Rectangle()
                    .fill(Color.black)
                    .frame(minWidth: 640, minHeight: 400)
                    .overlay(ProgressView().scaleEffect(1.0))
            }
        }
        .background(Color.black)
        .frame(minWidth: 680, idealWidth: 860, minHeight: 480, idealHeight: 600)
        .onAppear {
            player = AVPlayer(url: URL(fileURLWithPath: path))
            player?.play()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
}
