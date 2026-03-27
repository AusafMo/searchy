import SwiftUI
import Foundation

// MARK: - Masonry Grid (Bento Layout)
struct MasonryGrid<Content: View, Item: Identifiable>: View {
    let items: [Item]
    let columns: Int
    let spacing: CGFloat
    let content: (Item) -> Content

    init(items: [Item], columns: Int = 4, spacing: CGFloat = 12, @ViewBuilder content: @escaping (Item) -> Content) {
        self.items = items
        self.columns = columns
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        HStack(alignment: .top, spacing: spacing) {
            ForEach(0..<columns, id: \.self) { columnIndex in
                LazyVStack(spacing: spacing) {
                    ForEach(itemsForColumn(columnIndex)) { item in
                        content(item)
                    }
                }
            }
        }
    }

    private func itemsForColumn(_ column: Int) -> [Item] {
        items.enumerated().compactMap { index, item in
            index % columns == column ? item : nil
        }
    }
}

// MARK: - Masonry Image Card (Dynamic Height)
struct MasonryImageCard: View {
    let result: SearchResult
    var showSimilarity: Bool = false
    var onFindSimilar: ((String) -> Void)? = nil
    var onHoverStart: ((SearchResult) -> Void)? = nil
    var onHoverEnd: (() -> Void)? = nil

    @State private var isFavorite: Bool = false
    @State private var isHovered = false
    @State private var showCopied = false
    @State private var thumbnail: NSImage?
    @State private var aspectRatio: CGFloat = 1.0
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject private var volumeManager = VolumeManager.shared

    private let baseWidth: CGFloat = 200

    /// Check if this image is on an offline volume
    private var isOffline: Bool {
        volumeManager.isPathOffline(result.path)
    }

    var body: some View {
        ZStack {
            // Full photo background
            imageContent

            // Bottom gradient with filename
            VStack {
                Spacer()
                filenameOverlay
            }
            .allowsHitTesting(false)

            // Hover overlay
            if isHovered && !showCopied { hoverOverlay }
            if showCopied { copiedFeedback }

            // Top row - favorite button, offline badge, and similarity badge
            VStack {
                HStack {
                    if isHovered {
                        favoriteButton
                    }
                    if isOffline {
                        offlineBadge
                    }
                    Spacer()
                    if showSimilarity {
                        similarityBadge
                    }
                }
                Spacer()
            }

            // Offline overlay when volume unavailable
            if isOffline {
                offlineOverlay
            }
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.08),
            radius: isHovered ? 12 : 6,
            x: 0,
            y: isHovered ? 6 : 3
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                onHoverStart?(result)
            } else {
                onHoverEnd?()
            }
        }
        .onTapGesture(count: 2) { handleCopy() }
        .contextMenu { contextMenuContent }
        .onAppear {
            loadThumbnail()
            isFavorite = FavoritesManager.shared.isFavorite(result.path)
        }
    }

    private var imageContent: some View {
        GeometryReader { geo in
            if let thumb = thumbnail {
                Image(nsImage: thumb)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            } else {
                Rectangle()
                    .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05))
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.6)
                    )
            }
        }
    }

    private var filenameOverlay: some View {
        Text(URL(fileURLWithPath: result.path).lastPathComponent)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.white)
            .lineLimit(1)
            .truncationMode(.middle)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }

    private var favoriteButton: some View {
        Button(action: {
            isFavorite.toggle()
            FavoritesManager.shared.toggleFavorite(result.path)
        }) {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isFavorite ? .red : .white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(isFavorite ? Color.white : Color.black.opacity(0.5)))
        }
        .buttonStyle(PlainButtonStyle())
        .padding(6)
    }

    private var similarityBadge: some View {
        Text("\(Int(result.similarity * 100))%")
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.black.opacity(0.5)))
            .padding(6)
    }

    private var offlineBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "externaldrive.badge.xmark")
                .font(.system(size: 9, weight: .bold))
            Text("Offline")
                .font(.system(size: 10, weight: .bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Capsule().fill(Color.orange))
        .padding(6)
    }

    private var offlineOverlay: some View {
        ZStack {
            // Dim the image
            Color.black.opacity(0.4)

            // Offline indicator
            VStack(spacing: 8) {
                Image(systemName: "externaldrive.badge.xmark")
                    .font(.system(size: 28))
                    .foregroundColor(.white.opacity(0.9))
                Text("Volume Offline")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
            }
        }
    }

    private var hoverOverlay: some View {
        VStack {
            Spacer()
            HStack(spacing: 8) {
                // Quick actions
                Button(action: { openInPreview() }) {
                    Image(systemName: "eye")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.black.opacity(0.5)))
                }
                .buttonStyle(PlainButtonStyle())
                .help("Open in Preview")

                Button(action: { openInFinder() }) {
                    Image(systemName: "folder")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.black.opacity(0.5)))
                }
                .buttonStyle(PlainButtonStyle())
                .help("Show in Finder")

                if onFindSimilar != nil {
                    Button(action: { onFindSimilar?(result.path) }) {
                        Image(systemName: "sparkle.magnifyingglass")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Find Similar")
                }

                Button(action: { handleCopy() }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.black.opacity(0.5)))
                }
                .buttonStyle(PlainButtonStyle())
                .help("Copy")
            }
            .padding(.bottom, 36)
        }
    }

    private var copiedFeedback: some View {
        VStack {
            Spacer()
            HStack {
                Image(systemName: "checkmark.circle.fill")
                Text("Copied")
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.green))
            Spacer()
        }
    }

    @ViewBuilder
    private var contextMenuContent: some View {
        Button(action: { openInPreview() }) {
            Label("Open in Preview", systemImage: "eye")
        }
        Button(action: { handleCopy() }) {
            Label("Copy Image", systemImage: "doc.on.doc")
        }
        Button(action: { openInFinder() }) {
            Label("Show in Finder", systemImage: "folder")
        }
        if let onFindSimilar = onFindSimilar {
            Button(action: { onFindSimilar(result.path) }) {
                Label("Find Similar", systemImage: "sparkle.magnifyingglass")
            }
        }
        Divider()
        Button(action: {
            isFavorite.toggle()
            FavoritesManager.shared.toggleFavorite(result.path)
        }) {
            Label(isFavorite ? "Remove from Favorites" : "Add to Favorites", systemImage: isFavorite ? "heart.slash" : "heart")
        }
    }

    private func loadThumbnail() {
        DispatchQueue.global(qos: .userInitiated).async {
            if let image = loadOptimizedThumbnail(from: result.path, maxSize: 400) {
                let ratio = image.size.width / max(image.size.height, 1)
                DispatchQueue.main.async {
                    self.thumbnail = image
                    self.aspectRatio = max(0.5, min(2.0, ratio)) // Clamp between 0.5 and 2.0
                }
            }
        }
    }

    private func loadOptimizedThumbnail(from path: String, maxSize: Int) -> NSImage? {
        let url = URL(fileURLWithPath: path)
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: maxSize,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    private func handleCopy() {
        guard let image = NSImage(contentsOfFile: result.path) else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])

        showCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showCopied = false
        }
    }

    private func openInFinder() {
        NSWorkspace.shared.selectFile(result.path, inFileViewerRootedAtPath: "")
    }

    private func openInPreview() {
        NSWorkspace.shared.open(
            [URL(fileURLWithPath: result.path)],
            withApplicationAt: URL(fileURLWithPath: "/System/Applications/Preview.app"),
            configuration: NSWorkspace.OpenConfiguration()
        )
    }
}

// MARK: - Preview Panel (Maccy-style)
struct PreviewPanel: View {
    let result: SearchResult
    let onClose: () -> Void

    @State private var fullImage: NSImage?
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image preview
            ZStack {
                if let image = fullImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: 300)
                } else {
                    Rectangle()
                        .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05))
                        .frame(height: 200)
                        .overlay(ProgressView())
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.bottom, 12)

            // Metadata
            VStack(alignment: .leading, spacing: 8) {
                // Filename
                Text(URL(fileURLWithPath: result.path).lastPathComponent)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                    .lineLimit(2)

                Divider()
                    .padding(.vertical, 4)

                // Path
                HStack(spacing: 6) {
                    Image(systemName: "folder")
                        .font(.system(size: 11))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                    Text(URL(fileURLWithPath: result.path).deletingLastPathComponent().path)
                        .font(.system(size: 11))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                // Size
                if let size = result.size {
                    HStack(spacing: 6) {
                        Image(systemName: "doc")
                            .font(.system(size: 11))
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                        Text(formatFileSize(size))
                            .font(.system(size: 11))
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                }

                // Date
                if let dateStr = result.date, let date = ISO8601DateFormatter().date(from: dateStr) {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 11))
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                        Text(date, style: .date)
                            .font(.system(size: 11))
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                }

                // Similarity
                if result.similarity < 1.0 {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 11))
                            .foregroundColor(DesignSystem.Colors.accent)
                        Text("\(Int(result.similarity * 100))% match")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.accent)
                    }
                }

                Divider()
                    .padding(.vertical, 4)

                // Actions hint
                Text("Double-click to copy • ⌘O to open")
                    .font(.system(size: 10))
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
            }

            Spacer()
        }
        .padding(16)
        .frame(width: 280)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(hex: "1a1a1a") : Color(hex: "f5f5f5"))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1), lineWidth: 1)
        )
        .onAppear {
            loadFullImage()
        }
        .onChange(of: result.path) { _ in
            loadFullImage()
        }
    }

    private func loadFullImage() {
        fullImage = nil
        DispatchQueue.global(qos: .userInitiated).async {
            if let image = NSImage(contentsOfFile: result.path) {
                DispatchQueue.main.async {
                    self.fullImage = image
                }
            }
        }
    }

    private func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// MARK: - Resizable Preview Panel (shared between app and widget)
struct ResizablePreviewPanel: View {
    let result: SearchResult
    @Binding var width: CGFloat
    @Binding var isVisible: Bool
    var style: PreviewPanelStyle = .app
    var onFindSimilar: ((String) -> Void)? = nil

    enum PreviewPanelStyle {
        case app      // For main app - solid background
        case widget   // For spotlight widget - translucent
    }

    @State private var fullImage: NSImage?
    @State private var dragStartWidth: CGFloat = 0
    @State private var isFavorite: Bool = false
    @State private var showCopied: Bool = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            // Resize handle (left edge)
            resizeHandle

            // Content
            VStack(alignment: .leading, spacing: 12) {
                // Header with close button
                HStack {
                    Text("Preview")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(style == .widget ? .white.opacity(0.6) : DesignSystem.Colors.secondaryText)
                    Spacer()
                    Button(action: {
                        withAnimation(.easeOut(duration: 0.15)) {
                            isVisible = false
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(style == .widget ? .white.opacity(0.4) : DesignSystem.Colors.tertiaryText)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                // Image preview
                ZStack {
                    if let image = fullImage {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: 280)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(style == .widget ? Color.white.opacity(0.1) : (colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05)))
                            .frame(height: 150)
                            .overlay(ProgressView())
                    }
                }

                // Metadata
                VStack(alignment: .leading, spacing: 6) {
                    Text(URL(fileURLWithPath: result.path).lastPathComponent)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(style == .widget ? .white : DesignSystem.Colors.primaryText)
                        .lineLimit(2)

                    Text(URL(fileURLWithPath: result.path).deletingLastPathComponent().path)
                        .font(.system(size: 10))
                        .foregroundColor(style == .widget ? .white.opacity(0.5) : DesignSystem.Colors.tertiaryText)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    HStack(spacing: 12) {
                        if let size = result.size {
                            Label(formatFileSize(size), systemImage: "doc")
                                .font(.system(size: 10))
                                .foregroundColor(style == .widget ? .white.opacity(0.5) : DesignSystem.Colors.secondaryText)
                        }

                        if result.similarity < 1.0 {
                            Label("\(Int(result.similarity * 100))%", systemImage: "sparkle")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(style == .widget ? .cyan : DesignSystem.Colors.accent)
                        }
                    }
                }

                Divider()
                    .opacity(0.3)

                // Quick actions
                quickActionsSection

                Spacer()
            }
            .padding(12)
        }
        .frame(width: width)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(style == .widget ?
                    AnyShapeStyle(.ultraThinMaterial.opacity(0.6)) :
                    AnyShapeStyle(colorScheme == .dark ? Color(hex: "1a1a1a") : Color(hex: "f5f5f5"))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(style == .widget ? Color.white.opacity(0.1) : (colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1)), lineWidth: 1)
        )
        .onAppear {
            loadFullImage()
            isFavorite = FavoritesManager.shared.isFavorite(result.path)
        }
        .onChange(of: result.path) { _, _ in
            loadFullImage()
            isFavorite = FavoritesManager.shared.isFavorite(result.path)
        }
    }

    private var buttonBackground: Color {
        style == .widget ? Color.white.opacity(0.1) : (colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05))
    }

    private var primaryTextColor: Color {
        style == .widget ? .white.opacity(0.8) : DesignSystem.Colors.primaryText
    }

    @ViewBuilder
    private var quickActionsSection: some View {
        VStack(spacing: 8) {
            if showCopied {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Copied!")
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white)
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(Capsule().fill(Color.green))
            }

            actionButton(icon: "doc.on.doc", title: "Copy Image", action: copyImage)
            actionButton(icon: "eye", title: "Open in Preview", action: openInPreview)
            actionButton(icon: "folder", title: "Show in Finder", action: openInFinder)

            if onFindSimilar != nil {
                actionButton(icon: "sparkle.magnifyingglass", title: "Find Similar", color: style == .widget ? .cyan : DesignSystem.Colors.accent) {
                    onFindSimilar?(result.path)
                }
            }

            actionButton(icon: isFavorite ? "heart.fill" : "heart", title: isFavorite ? "Remove Favorite" : "Add to Favorites", color: isFavorite ? .red : primaryTextColor, action: toggleFavorite)
        }
    }

    private func actionButton(icon: String, title: String, color: Color? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(title)
                Spacer()
            }
            .font(.system(size: 11))
            .foregroundColor(color ?? primaryTextColor)
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(RoundedRectangle(cornerRadius: 6).fill(buttonBackground))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var resizeHandle: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.01)) // Nearly invisible but captures events
            .frame(width: 12)
            .overlay(
                Rectangle()
                    .fill(style == .widget ? Color.white.opacity(0.3) : DesignSystem.Colors.tertiaryText.opacity(0.5))
                    .frame(width: 3, height: 30)
                    .clipShape(Capsule())
            )
            .contentShape(Rectangle())
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { value in
                        if dragStartWidth == 0 {
                            dragStartWidth = width
                        }
                        let newWidth = dragStartWidth - value.translation.width
                        width = max(200, min(450, newWidth))
                    }
                    .onEnded { _ in
                        dragStartWidth = 0
                    }
            )
    }

    private func loadFullImage() {
        fullImage = nil
        DispatchQueue.global(qos: .userInitiated).async {
            if let image = NSImage(contentsOfFile: result.path) {
                DispatchQueue.main.async {
                    self.fullImage = image
                }
            }
        }
    }

    private func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }

    private func openInPreview() {
        NSWorkspace.shared.open(
            [URL(fileURLWithPath: result.path)],
            withApplicationAt: URL(fileURLWithPath: "/System/Applications/Preview.app"),
            configuration: NSWorkspace.OpenConfiguration()
        )
    }

    private func openInFinder() {
        NSWorkspace.shared.selectFile(result.path, inFileViewerRootedAtPath: "")
    }

    private func copyImage() {
        guard let image = NSImage(contentsOfFile: result.path) else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])

        showCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showCopied = false
        }
    }

    private func toggleFavorite() {
        isFavorite.toggle()
        FavoritesManager.shared.toggleFavorite(result.path)
    }
}

// Legacy alias for compatibility
typealias SpotlightPreviewPanel = ResizablePreviewPanel

// MARK: - Spotlight Search View
struct SpotlightSearchView: View {
    @ObservedObject private var searchManager = SearchManager.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var searchText = ""
    @State private var selectedIndex: Int = 0
    @State private var recentImages: [SearchResult] = []
    @State private var hasPerformedSearch = false
    @State private var isLoadingRecent = false
    @State private var searchDebounceTimer: Timer?
    @State private var pastedImage: NSImage? = nil
    @State private var isDropTargeted = false
    @State private var keyMonitor: Any? = nil
    @State private var showPreviewPanel = false
    @State private var previewTimer: Timer? = nil
    @State private var previewPanelWidth: CGFloat = 280
    @State private var isResizingPanel = false
    let previousApp: NSRunningApplication?
    @Environment(\.colorScheme) var colorScheme
    @FocusState private var isSearchFocused: Bool

    init(previousApp: NSRunningApplication? = nil) {
        self.previousApp = previousApp
    }

    private func closeWindow() {
        if let window = NSApp.keyWindow {
            window.orderOut(nil)
        }
    }

    private func loadRecentImages(retryCount: Int = 0) {
        isLoadingRecent = true
        searchManager.loadRecentImages { images in
            if images.isEmpty && retryCount < 3 {
                // Server might not be ready, retry after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.loadRecentImages(retryCount: retryCount + 1)
                }
            } else {
                self.recentImages = images
                self.isLoadingRecent = false
            }
        }
    }

    private func startPreviewTimer() {
        previewTimer?.invalidate()
        previewTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            withAnimation(.easeOut(duration: 0.15)) {
                showPreviewPanel = true
            }
        }
    }

    private var displayResults: [SearchResult] {
        if hasPerformedSearch {
            return searchManager.results
        } else {
            return recentImages
        }
    }

    private var searchBarBackground: some View {
        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xl)
            .fill(.ultraThinMaterial.opacity(0.3))
            .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
    }

    private var resultsBackground: some View {
        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xl)
            .fill(.ultraThinMaterial.opacity(0.3))
            .shadow(color: Color.black.opacity(0.1), radius: 15, x: 0, y: 8)
    }

    var body: some View {
        VStack(spacing: 0) {
                // Compact search bar
                HStack(spacing: DesignSystem.Spacing.sm) {
                    // Show pasted image or search icon
                    if let image = pastedImage {
                        ZStack(alignment: .topTrailing) {
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 28, height: 28)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.white.opacity(0.8), lineWidth: 2)
                                )

                            Button(action: {
                                withAnimation(.easeOut(duration: 0.15)) {
                                    pastedImage = nil
                                    hasPerformedSearch = false
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                                    .background(Circle().fill(Color.black.opacity(0.6)))
                            }
                            .buttonStyle(PlainButtonStyle())
                            .offset(x: 5, y: -5)
                        }

                        Text("Finding similar...")
                            .font(DesignSystem.Typography.title)
                            .foregroundColor(.white.opacity(0.7))

                        Spacer()

                        if searchManager.isSearching {
                            ProgressView()
                                .scaleEffect(1.0)
                        }
                    } else {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color.black.opacity(0.6))

                        TextField("Search images...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(DesignSystem.Typography.title)
                            .foregroundColor(.white)
                            .focused($isSearchFocused)
                            .onSubmit {
                                if !searchManager.isSearching && !searchText.isEmpty {
                                    // Cancel debounce timer and search immediately
                                    searchDebounceTimer?.invalidate()
                                    performSearch()
                                }
                            }
                            .onChange(of: searchText) { oldValue, newValue in
                                selectedIndex = 0

                                // Cancel any existing timer
                                searchDebounceTimer?.invalidate()

                                // If search text is empty, show recent images
                                if newValue.isEmpty {
                                    hasPerformedSearch = false
                                    return
                                }

                                // Debounce: wait 400ms after user stops typing before searching
                                searchDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { _ in
                                    if !searchManager.isSearching && !newValue.isEmpty {
                                        performSearch()
                                    }
                                }
                            }

                        if searchManager.isSearching {
                            ProgressView()
                                .scaleEffect(1.0)
                                .transition(.scale.combined(with: .opacity))
                        } else if !searchText.isEmpty {
                            Button(action: {
                                withAnimation {
                                    searchText = ""
                                    selectedIndex = 0
                                    hasPerformedSearch = false
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(Color.black.opacity(0.4))
                            }
                            .buttonStyle(PlainButtonStyle())
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
                .padding(DesignSystem.Spacing.md)
                .background(searchBarBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xl)
                        .stroke(
                            isDropTargeted ? Color.white : Color.black.opacity(0.1),
                            lineWidth: isDropTargeted ? 2 : 1
                        )
                )
                .onDrop(of: [.image, .fileURL], isTargeted: $isDropTargeted) { providers in
                    handleDroppedImage(providers: providers)
                    return true
                }
                .padding(.horizontal, DesignSystem.Spacing.md)

                // Results area with optional preview panel
                if isLoadingRecent && recentImages.isEmpty && !hasPerformedSearch {
                    // Show loading indicator while waiting for recent images
                    VStack(spacing: DesignSystem.Spacing.md) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading recent images...")
                            .font(DesignSystem.Typography.callout)
                            .foregroundColor(Color.black.opacity(0.5))
                    }
                    .padding(DesignSystem.Spacing.xxl)
                } else if !displayResults.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        // Results list - takes priority in layout
                        ScrollViewReader { proxy in
                            ScrollView(.vertical, showsIndicators: true) {
                                VStack(spacing: DesignSystem.Spacing.sm) {
                                    ForEach(Array(displayResults.enumerated()), id: \.element.id) { index, result in
                                        SpotlightResultRow(
                                            result: result,
                                            isSelected: index == selectedIndex,
                                            onSelect: {
                                                closeWindow()
                                            }
                                        )
                                        .id(index)
                                        .onTapGesture {
                                            selectedIndex = index
                                        }
                                    }
                                }
                                .padding(DesignSystem.Spacing.sm)
                                .animation(nil, value: selectedIndex)
                            }
                            .frame(minWidth: 320, maxHeight: 400)
                            .animation(nil, value: selectedIndex)
                            .background(resultsBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xl)
                                    .stroke(Color.black.opacity(0.1), lineWidth: 1)
                            )
                            .padding(.leading, DesignSystem.Spacing.md)
                            .padding(.top, DesignSystem.Spacing.sm)
                            .onChange(of: selectedIndex) { oldValue, newValue in
                                // Scroll instantly with no animation
                                proxy.scrollTo(newValue, anchor: .center)
                                // Start preview timer
                                startPreviewTimer()
                            }
                        }
                        .layoutPriority(1)

                        // Preview panel (appears after 500ms dwell)
                        if showPreviewPanel && selectedIndex < displayResults.count {
                            ResizablePreviewPanel(
                                result: displayResults[selectedIndex],
                                width: $previewPanelWidth,
                                isVisible: $showPreviewPanel,
                                style: .widget
                            )
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                            .padding(.top, DesignSystem.Spacing.sm)
                            .padding(.trailing, DesignSystem.Spacing.md)
                        }
                    }
                    .padding(.trailing, showPreviewPanel ? 0 : DesignSystem.Spacing.md)
                }

                Spacer()

                // Keyboard hints
                HStack(spacing: DesignSystem.Spacing.md) {
                    KeyboardHint(key: "↑↓", description: "Navigate")
                    KeyboardHint(key: "⏎", description: "Copy & Paste")
                    KeyboardHint(key: "⌘⏎", description: "Open")
                    KeyboardHint(key: "⌃1-9", description: "Copy")
                    KeyboardHint(key: "⌘1-9", description: "Copy & Paste")
                    KeyboardHint(key: "ESC", description: "Close")
                }
                .padding(DesignSystem.Spacing.sm)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial.opacity(0.2))
                )
                .padding(.bottom, DesignSystem.Spacing.sm)
        }
        .frame(minWidth: 500, maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xl)
                .fill(.ultraThinMaterial.opacity(0.4))
                .shadow(color: Color.black.opacity(0.2), radius: 30, x: 0, y: 15)
        )
        .onAppear {
            // Load recent images and focus search field
            loadRecentImages()
            setupPasteMonitor()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isSearchFocused = true
            }
        }
        .onDisappear {
            removePasteMonitor()
        }
        .onChange(of: searchManager.isSearching) { _, _ in
            // Always restore focus on any search state change
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isSearchFocused = true
            }
        }
        .onChange(of: searchManager.results.count) { _, _ in
            // Restore focus after results change
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isSearchFocused = true
            }
        }
        .onChange(of: isSearchFocused) { _, newValue in
            // If focus is lost, restore it
            if !newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isSearchFocused = true
                }
            }
        }
        .onKeyPress(.escape) {
            closeWindow()
            return .handled
        }
        .onKeyPress(.upArrow) {
            if !displayResults.isEmpty {
                selectedIndex = max(0, selectedIndex - 1)
            }
            return .handled
        }
        .onKeyPress(.downArrow) {
            if !displayResults.isEmpty {
                selectedIndex = min(displayResults.count - 1, selectedIndex + 1)
            }
            return .handled
        }
        .onKeyPress { press in
            // Check if this is a Return key press
            guard press.key == .return else { return .ignored }

            // If there are results and we have a valid selection
            if !displayResults.isEmpty && selectedIndex < displayResults.count {
                let selectedResult = displayResults[selectedIndex]

                // Cmd+Enter: Open in Finder
                if press.modifiers.contains(.command) {
                    NSWorkspace.shared.selectFile(selectedResult.path, inFileViewerRootedAtPath: "")
                    closeWindow()
                    return .handled
                }
                // Enter alone: Copy and paste
                else {
                    copyAndPasteImageAtIndex(selectedIndex)
                    return .handled
                }
            }
            // No results selected, perform search if we have text
            else if !searchText.isEmpty && !searchManager.isSearching {
                // Cancel debounce and search immediately
                searchDebounceTimer?.invalidate()
                performSearch()
                return .handled
            }
            return .ignored
        }
        // Ctrl+1 through Ctrl+9 shortcuts to copy images
        .onKeyPress { press in
            // Check if Control key is pressed (but not Command)
            guard press.modifiers.contains(.control) && !press.modifiers.contains(.command) else { return .ignored }

            // Check for number keys 1-9
            if let char = press.characters.first, char.isNumber, let digit = char.wholeNumberValue, digit >= 1, digit <= 9 {
                let index = digit - 1
                if index < displayResults.count {
                    copyImageAtIndex(index)
                    closeWindow()
                    return .handled
                }
            }
            return .ignored
        }
        // Cmd+1 through Cmd+9 shortcuts to copy and paste images
        .onKeyPress { press in
            // Check if Command key is pressed
            guard press.modifiers.contains(.command) else { return .ignored }

            // Check for number keys 1-9
            if let char = press.characters.first, char.isNumber, let digit = char.wholeNumberValue, digit >= 1, digit <= 9 {
                let index = digit - 1
                if index < displayResults.count {
                    copyAndPasteImageAtIndex(index)
                    return .handled
                }
            }
            return .ignored
        }
    }

    private func performSearch() {
        guard !searchText.isEmpty, !searchManager.isSearching else { return }
        selectedIndex = 0
        hasPerformedSearch = true
        searchManager.search(query: searchText, numberOfResults: SearchPreferences.shared.numberOfResults)
    }

    // MARK: - Paste/Drop Handling
    private func setupPasteMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Check for Backspace/Delete to clear pasted image
            if self.pastedImage != nil && (event.keyCode == 51 || event.keyCode == 117) {
                DispatchQueue.main.async {
                    self.pastedImage = nil
                    self.hasPerformedSearch = false
                }
                return nil // Consume the event
            }

            // Check for Cmd+V
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "v" {
                let pasteboard = NSPasteboard.general
                if pasteboard.canReadObject(forClasses: [NSImage.self], options: nil) {
                    if let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil),
                       let image = images.first as? NSImage {
                        DispatchQueue.main.async {
                            self.pastedImage = image
                            self.hasPerformedSearch = true
                            self.saveAndSearchImage(image)
                        }
                        return nil // Consume the event
                    }
                }
            }
            return event
        }
    }

    private func removePasteMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    private func handleDroppedImage(providers: [NSItemProvider]) {
        guard let provider = providers.first else { return }

        if provider.hasItemConformingToTypeIdentifier("public.file-url") {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, error in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil),
                      let image = NSImage(contentsOf: url) else { return }
                DispatchQueue.main.async {
                    self.pastedImage = image
                    self.hasPerformedSearch = true
                    self.searchManager.findSimilar(imagePath: url.path)
                }
            }
        } else if provider.hasItemConformingToTypeIdentifier("public.image") {
            provider.loadDataRepresentation(forTypeIdentifier: "public.image") { data, error in
                guard let data = data, let image = NSImage(data: data) else { return }
                DispatchQueue.main.async {
                    self.pastedImage = image
                    self.hasPerformedSearch = true
                    self.saveAndSearchImage(image)
                }
            }
        }
    }

    private func saveAndSearchImage(_ image: NSImage) {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("searchy_paste_\(UUID().uuidString).png")

        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            return
        }

        do {
            try pngData.write(to: tempFile)
            searchManager.findSimilar(imagePath: tempFile.path)
        } catch {
            print("Failed to save pasted image: \(error)")
        }
    }

    private func copyImageAtIndex(_ index: Int) {
        guard index < displayResults.count else { return }
        let result = displayResults[index]
        if let image = NSImage(contentsOfFile: result.path) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.writeObjects([image])
        }
    }

    private func copyAndPasteImageAtIndex(_ index: Int) {
        guard index < displayResults.count else { return }
        let result = displayResults[index]

        // Check if we have accessibility permissions
        let checkOptPrompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [checkOptPrompt: true] as CFDictionary
        let accessEnabled = AXIsProcessTrustedWithOptions(options)

        if !accessEnabled {
            print("⚠️ Accessibility permission not granted. Please enable in System Settings > Privacy & Security > Accessibility")
        }

        // First copy the image to clipboard
        if let image = NSImage(contentsOfFile: result.path) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.writeObjects([image])

            print("✅ Image copied to clipboard")

            // Use the stored previous app
            let targetApp = previousApp

            // Close the window immediately
            closeWindow()

            // Wait for window to close, then activate target app and paste
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                // Make sure the previous app is activated
                if let app = targetApp {
                    app.activate(options: [.activateIgnoringOtherApps])
                    print("🎯 Activating app: \(app.localizedName ?? "Unknown")")
                } else {
                    print("⚠️ No previous app stored!")
                }

                // Wait for app to be fully active
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    print("📋 Attempting to paste...")

                    // Simulate Cmd+V paste using CGEvent
                    let source = CGEventSource(stateID: .combinedSessionState)

                    // Create key down event for 'v' (virtual key 0x09)
                    if let keyDownEvent = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) {
                        keyDownEvent.flags = .maskCommand
                        keyDownEvent.post(tap: .cghidEventTap)
                        print("⬇️ Posted key down event")
                    }

                    // Small delay between key down and key up
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                        // Create key up event for 'v'
                        if let keyUpEvent = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false) {
                            keyUpEvent.flags = .maskCommand
                            keyUpEvent.post(tap: .cghidEventTap)
                            print("⬆️ Posted key up event")
                        }
                    }
                }
            }
        }
    }
}

struct SpotlightResultRow: View {
    let result: SearchResult
    let isSelected: Bool
    let onSelect: () -> Void
    @State private var isHovered = false
    @State private var showingCopyNotification = false
    @State private var thumbnail: NSImage?
    @Environment(\.colorScheme) var colorScheme

    private let thumbnailSize = 50

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            // Thumbnail
            Group {
                if let image = thumbnail {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                }
            }
            .frame(width: CGFloat(thumbnailSize), height: CGFloat(thumbnailSize))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                    .stroke(isSelected ?
                        DesignSystem.Colors.accent.opacity(0.5) :
                        DesignSystem.Colors.border.opacity(0.3),
                        lineWidth: isSelected ? 1.5 : 1)
            )
            .shadow(color: isSelected ? DesignSystem.Colors.accent.opacity(0.2) : .clear,
                   radius: 4, x: 0, y: 2)
            .onAppear {
                loadThumbnail()
            }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(URL(fileURLWithPath: result.path).lastPathComponent)
                    .font(DesignSystem.Typography.caption.weight(.semibold))
                    .foregroundColor(isSelected ? DesignSystem.Colors.accent : DesignSystem.Colors.primaryText)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: "sparkle")
                        .font(.system(size: 8, weight: .bold))
                    Text("\(Int(result.similarity * 100))%")
                        .font(DesignSystem.Typography.caption2.weight(.semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(similarityColor)
                )
            }

            Spacer()

            // Action buttons
            HStack(spacing: DesignSystem.Spacing.xs) {
                Button(action: {
                    copyImage(path: result.path)
                    showCopyNotification()
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11))
                        .foregroundColor(DesignSystem.Colors.accent)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Copy")

                Button(action: {
                    NSWorkspace.shared.selectFile(result.path, inFileViewerRootedAtPath: "")
                    onSelect()
                }) {
                    Image(systemName: "folder")
                        .font(.system(size: 11))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Reveal in Finder")
            }
            .opacity((isHovered || isSelected) ? 1 : 0.3)
        }
        .padding(DesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(
                    isSelected ?
                        DesignSystem.Colors.accent.opacity(0.1) :
                        (isHovered ? DesignSystem.Colors.accent.opacity(0.05) : Color.clear)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .stroke(
                    isSelected ?
                        DesignSystem.Colors.accent.opacity(0.3) :
                        Color.clear,
                    lineWidth: isSelected ? 1 : 0
                )
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture(count: 2) {
            copyImage(path: result.path)
            showCopyNotification()
        }
        .overlay(
            Group {
                if showingCopyNotification {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(DesignSystem.Colors.success)
                        Text("Copied!")
                            .font(DesignSystem.Typography.callout.weight(.semibold))
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.vertical, DesignSystem.Spacing.md)
                    .background(
                        Capsule()
                            .fill(colorScheme == .dark ?
                                DesignSystem.Colors.darkSecondaryBackground :
                                DesignSystem.Colors.secondaryBackground)
                            .shadow(color: DesignSystem.Shadows.medium(colorScheme), radius: 12, x: 0, y: 6)
                    )
                    .transition(.scale.combined(with: .opacity))
                }
            }
        )
    }

    private var similarityColor: Color {
        let percentage = result.similarity * 100
        if percentage >= 80 {
            return DesignSystem.Colors.success
        } else if percentage >= 60 {
            return DesignSystem.Colors.accent
        } else {
            return DesignSystem.Colors.warning
        }
    }

    private var similarityGradient: [Color] {
        let percentage = result.similarity * 100
        if percentage >= 80 {
            return [Color(hex: "10B981"), Color(hex: "059669")]
        } else if percentage >= 60 {
            return [DesignSystem.Colors.accent, DesignSystem.Colors.accentGradientEnd]
        } else if percentage >= 40 {
            return [Color(hex: "F59E0B"), Color(hex: "D97706")]
        } else {
            return [Color(hex: "EF4444"), Color(hex: "DC2626")]
        }
    }

    private func showCopyNotification() {
        showingCopyNotification = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showingCopyNotification = false
        }
    }

    private func loadThumbnail() {
        let size = thumbnailSize * 2  // 2x for retina
        if let cached = ThumbnailService.shared.cachedThumbnail(for: result.path, size: size) {
            self.thumbnail = cached
            return
        }
        ThumbnailService.shared.loadThumbnail(for: result.path, maxSize: size) { thumb in
            self.thumbnail = thumb
        }
    }

    private func copyImage(path: String) {
        if let image = NSImage(contentsOfFile: path) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.writeObjects([image])
        }
    }
}

struct ResultCardView: View {
    let result: SearchResult
    @State private var showingCopyNotification = false
    @State private var isHovered = false
    @State private var isPressed = false
    @StateObject private var prefs = SearchPreferences.shared
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // Image container with overlay effects
            ZStack(alignment: .topTrailing) {
                DoubleClickImageView(filePath: result.path) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isPressed = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            isPressed = false
                        }
                    }
                    copyImage(path: result.path)
                    showCopyNotification()
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: CGFloat(prefs.imageSize), height: CGFloat(prefs.imageSize))
                .clipped()
                .background(
                    colorScheme == .dark ?
                        DesignSystem.Colors.darkTertiaryBackground :
                        DesignSystem.Colors.tertiaryBackground
                )
                .scaleEffect(isPressed ? 0.95 : 1.0)

                // Hover overlay with icon-only actions
                if isHovered && !showingCopyNotification {
                    Rectangle()
                        .fill(Color.black.opacity(0.4))
                        .overlay(
                            HStack(spacing: 8) {
                                Button(action: {
                                    copyImage(path: result.path)
                                    showCopyNotification()
                                }) {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white)
                                        .frame(width: 28, height: 28)
                                        .background(Circle().fill(Color.black.opacity(0.6)))
                                }
                                .buttonStyle(PlainButtonStyle())
                                .help("Copy")

                                Button(action: {
                                    revealInFinder(path: result.path)
                                }) {
                                    Image(systemName: "folder")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white)
                                        .frame(width: 28, height: 28)
                                        .background(Circle().fill(Color.black.opacity(0.6)))
                                }
                                .buttonStyle(PlainButtonStyle())
                                .help("Reveal in Finder")
                            }
                        )
                        .transition(.opacity)
                }

                // Similarity badge with gradient
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "sparkle")
                        .font(.system(size: 9, weight: .bold))
                    Text("\(Int(result.similarity * 100))%")
                        .font(DesignSystem.Typography.caption2.weight(.bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.xs + 2)
                .background(
                    Capsule()
                        .fill(similarityColor)
                )
                .padding(DesignSystem.Spacing.sm)
                .scaleEffect(isHovered ? 1.08 : 1.0)
                .allowsHitTesting(false)

                // Copy notification overlay
                if showingCopyNotification {
                    CopyNotification(isShowing: $showingCopyNotification)
                        .allowsHitTesting(false)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }

            // Minimal info section - just filename
            Text(URL(fileURLWithPath: result.path).lastPathComponent)
                .lineLimit(1)
                .font(DesignSystem.Typography.caption.weight(.medium))
                .foregroundColor(DesignSystem.Colors.primaryText)
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    colorScheme == .dark ?
                        DesignSystem.Colors.darkSecondaryBackground :
                        DesignSystem.Colors.secondaryBackground
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .stroke(
                    isHovered ? DesignSystem.Colors.accent.opacity(0.5) : DesignSystem.Colors.border,
                    lineWidth: 1
                )
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .onHover { hovering in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            Button(action: {
                copyImage(path: result.path)
                showCopyNotification()
            }) {
                Label("Copy Image", systemImage: "doc.on.doc")
            }

            Button(action: {
                revealInFinder(path: result.path)
            }) {
                Label("Reveal in Finder", systemImage: "folder")
            }

            Divider()

            Button(action: {
                NSWorkspace.shared.open(URL(fileURLWithPath: result.path))
            }) {
                Label("Open in Preview", systemImage: "eye")
            }
        }
    }

    private var similarityColor: Color {
        let percentage = result.similarity * 100
        if percentage >= 80 {
            return DesignSystem.Colors.success
        } else if percentage >= 60 {
            return DesignSystem.Colors.accent
        } else {
            return DesignSystem.Colors.warning
        }
    }

    private var similarityGradient: [Color] {
        let percentage = result.similarity * 100
        if percentage >= 80 {
            return [Color(hex: "10B981"), Color(hex: "059669")]
        } else if percentage >= 60 {
            return [DesignSystem.Colors.accent, DesignSystem.Colors.accentGradientEnd]
        } else if percentage >= 40 {
            return [Color(hex: "F59E0B"), Color(hex: "D97706")]
        } else {
            return [Color(hex: "EF4444"), Color(hex: "DC2626")]
        }
    }

    private func showCopyNotification() {
        showingCopyNotification = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showingCopyNotification = false
        }
    }

    private func copyImage(path: String) {
        if let image = NSImage(contentsOfFile: path) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.writeObjects([image])
        }
    }

    private func revealInFinder(path: String) {
        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
    }
}

// MARK: - Recent Image Card (Craft-style warm, floating card)
struct ImageCard: View {
    let result: SearchResult
    var showSimilarity: Bool = false
    var cardHeight: CGFloat = 200
    var onFindSimilar: ((String) -> Void)? = nil
    @State private var isFavorite: Bool = false

    @State private var isHovered = false
    @State private var showCopied = false
    @State private var thumbnail: NSImage?
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject private var volumeManager = VolumeManager.shared

    /// Check if this image is on an offline volume
    private var isOffline: Bool {
        volumeManager.isPathOffline(result.path)
    }

    var body: some View {
        ZStack {
            // Full photo background
            imageContent

            // Bottom gradient with filename
            VStack {
                Spacer()
                filenameOverlay
            }

            // Hover overlay with action buttons (below top buttons)
            if isHovered && !showCopied { hoverOverlay }
            if showCopied { copiedFeedback }

            // Top row - favorite button (left), offline badge, pending badge, and similarity badge (right) - ON TOP
            VStack {
                HStack {
                    if isHovered {
                        favoriteButton
                    }
                    if isOffline {
                        offlineBadge
                    }
                    if result.isPending {
                        pendingBadge
                    }
                    Spacer()
                    if showSimilarity {
                        similarityBadge
                    }
                }
                Spacer()
            }

            // Offline overlay when volume unavailable
            if isOffline {
                offlineOverlay
            }
        }
        .frame(minHeight: cardHeight, maxHeight: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.08),
            radius: isHovered ? 12 : 6,
            x: 0,
            y: isHovered ? 6 : 3
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .animation(.easeOut(duration: 0.2), value: showCopied)
        .onHover { isHovered = $0 }
        .onTapGesture(count: 2) { handleCopy() }
        .contextMenu { contextMenuContent }
    }

    private var filenameOverlay: some View {
        Text(URL(fileURLWithPath: result.path).lastPathComponent)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.white)
            .lineLimit(1)
            .truncationMode(.middle)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }

    private var favoriteButton: some View {
        Button(action: {
            isFavorite.toggle()
            FavoritesManager.shared.toggleFavorite(result.path)
        }) {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isFavorite ? .red : .white)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(isFavorite ? Color.white : Color.black.opacity(0.5))
                )
        }
        .buttonStyle(PlainButtonStyle())
        .help(isFavorite ? "Remove from favorites" : "Add to favorites")
        .padding(6)
        .onAppear {
            isFavorite = FavoritesManager.shared.isFavorite(result.path)
        }
    }

    private var similarityBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkle")
                .font(.system(size: 9, weight: .bold))
            Text("\(Int(result.similarity * 100))%")
                .font(.system(size: 11, weight: .bold, design: .rounded))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(DesignSystem.Colors.accent)
        )
        .shadow(color: DesignSystem.Colors.accent.opacity(0.3), radius: 4, y: 2)
        .padding(8)
    }

    private var offlineBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "externaldrive.badge.xmark")
                .font(.system(size: 9, weight: .bold))
            Text("Offline")
                .font(.system(size: 10, weight: .bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Capsule().fill(Color.orange))
        .padding(6)
    }

    private var pendingBadge: some View {
        HStack(spacing: 3) {
            ProgressView()
                .scaleEffect(0.5)
                .frame(width: 10, height: 10)
            Text("Indexing")
                .font(.system(size: 10, weight: .bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Capsule().fill(Color.blue.opacity(0.8)))
        .padding(6)
    }

    private var offlineOverlay: some View {
        ZStack {
            // Dim the image
            Color.black.opacity(0.4)

            // Offline indicator
            VStack(spacing: 8) {
                Image(systemName: "externaldrive.badge.xmark")
                    .font(.system(size: 28))
                    .foregroundColor(.white.opacity(0.9))
                Text("Volume Offline")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
            }
        }
    }

    private var imageContent: some View {
        GeometryReader { geo in
            if let image = thumbnail {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            } else {
                Rectangle()
                    .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color(hex: "F8F8F8"))
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.8)
                    )
            }
        }
        .onAppear {
            loadThumbnail()
        }
    }

    private func loadThumbnail() {
        let maxSize = Int(cardHeight * 2)  // 2x for retina

        // Check cache first
        if let cached = ThumbnailService.shared.cachedThumbnail(for: result.path, size: maxSize) {
            self.thumbnail = cached
            return
        }

        // Load efficiently using ThumbnailService
        ThumbnailService.shared.loadThumbnail(for: result.path, maxSize: maxSize) { thumb in
            self.thumbnail = thumb
        }
    }

    private var hoverOverlay: some View {
        ZStack(alignment: .bottom) {
            // Gradient background - non-interactive
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.black.opacity(0.1), Color.black.opacity(0.5)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .allowsHitTesting(false)

            // Buttons - interactive
            hoverButtons
        }
        .transition(.opacity)
    }

    private var hoverButtons: some View {
        HStack(spacing: 6) {
            Button(action: openInPreview) {
                Image(systemName: "eye")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Color.black.opacity(0.5)))
            }
            .buttonStyle(PlainButtonStyle())
            .help("Open in Preview")

            Button(action: handleCopy) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Color.black.opacity(0.5)))
            }
            .buttonStyle(PlainButtonStyle())
            .help("Copy")

            if onFindSimilar != nil {
                Button(action: { onFindSimilar?(result.path) }) {
                    Image(systemName: "sparkle.magnifyingglass")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Color.black.opacity(0.5)))
                }
                .buttonStyle(PlainButtonStyle())
                .help("Find similar")
            }

            Button(action: { NSWorkspace.shared.selectFile(result.path, inFileViewerRootedAtPath: "") }) {
                Image(systemName: "folder")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Color.black.opacity(0.5)))
            }
            .buttonStyle(PlainButtonStyle())
            .help("Reveal in Finder")
        }
        .padding(.bottom, 10)
    }

    private var copiedFeedback: some View {
        Rectangle()
            .fill(Color.black.opacity(0.6))
            .overlay(
                VStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.success)
                    Text("Copied!")
                        .font(DesignSystem.Typography.friendlyLabel)
                        .foregroundColor(.white)
                }
            )
            .transition(.opacity)
    }


    @ViewBuilder
    private var contextMenuContent: some View {
        Button(action: openInPreview) {
            Label("Open in Preview", systemImage: "eye")
        }
        Button(action: { copyImage(path: result.path) }) {
            Label("Copy Image", systemImage: "doc.on.doc")
        }
        Button(action: { NSWorkspace.shared.selectFile(result.path, inFileViewerRootedAtPath: "") }) {
            Label("Reveal in Finder", systemImage: "folder")
        }
        if onFindSimilar != nil {
            Button(action: { onFindSimilar?(result.path) }) {
                Label("Find Similar", systemImage: "sparkle.magnifyingglass")
            }
        }
    }

    private func handleCopy() {
        copyImage(path: result.path)
        withAnimation(.easeOut(duration: 0.15)) { showCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            withAnimation { showCopied = false }
        }
    }

    private func copyImage(path: String) {
        if let image = NSImage(contentsOfFile: path) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.writeObjects([image])
        }
    }

    private func openInPreview() {
        NSWorkspace.shared.open(
            [URL(fileURLWithPath: result.path)],
            withApplicationAt: URL(fileURLWithPath: "/System/Applications/Preview.app"),
            configuration: NSWorkspace.OpenConfiguration()
        )
    }
}

// Backward compatibility alias
typealias RecentImageCard = ImageCard

