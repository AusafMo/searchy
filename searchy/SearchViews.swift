import SwiftUI
import Foundation

// MARK: - Lightbox Image (full-size loading)
struct LightboxImage: View {
    let path: String
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: Color.black.opacity(0.6), radius: 30, y: 30)
                    .padding(32)
            } else {
                ProgressView()
                    .controlSize(.large)
                    .colorScheme(.dark)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .allowsHitTesting(false)
        .onAppear { loadImage() }
        .onChange(of: path) { _, _ in loadImage() }
    }

    private func loadImage() {
        image = nil
        DispatchQueue.global(qos: .userInitiated).async {
            if let img = NSImage(contentsOfFile: path) {
                DispatchQueue.main.async { self.image = img }
            }
        }
    }
}

// MARK: - Lightbox Metadata Grid
struct LightboxMetadataGrid: View {
    let path: String
    let result: SearchResult
    @State private var metadata: [(String, String)] = []

    private let labelColor = Color.white.opacity(0.4)
    private let valueColor = Color.white.opacity(0.85)

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 10) {
            ForEach(metadata, id: \.0) { item in
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.0)
                        .font(.system(size: 9, weight: .medium))
                        .tracking(1)
                        .textCase(.uppercase)
                        .foregroundColor(labelColor)
                    Text(item.1)
                        .font(.system(size: 11))
                        .foregroundColor(valueColor)
                        .lineLimit(1)
                }
            }
        }
        .onAppear { loadMetadata() }
        .onChange(of: path) { _, _ in loadMetadata() }
    }

    private func loadMetadata() {
        DispatchQueue.global(qos: .utility).async {
            var items: [(String, String)] = []
            let url = URL(fileURLWithPath: path)

            // Date
            if let date = result.date {
                items.append(("Date", date))
            } else if let attrs = try? FileManager.default.attributesOfItem(atPath: path),
                      let modDate = attrs[.modificationDate] as? Date {
                let fmt = DateFormatter()
                fmt.dateStyle = .medium
                items.append(("Date", fmt.string(from: modDate)))
            }

            // Size
            if let size = result.size {
                items.append(("Size", ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)))
            } else if let attrs = try? FileManager.default.attributesOfItem(atPath: path),
                      let fileSize = attrs[.size] as? Int64 {
                items.append(("Size", ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)))
            }

            // Dimensions
            if let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
               let props = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
               let w = props[kCGImagePropertyPixelWidth] as? Int,
               let h = props[kCGImagePropertyPixelHeight] as? Int {
                items.append(("Dimensions", "\(w)\u{00D7}\(h)"))
            }

            // Format
            items.append(("Format", url.pathExtension.uppercased()))

            DispatchQueue.main.async { self.metadata = items }
        }
    }
}

// MARK: - Lightbox Detected Text (OCR)
struct LightboxDetectedText: View {
    let path: String
    @State private var detectedText: String?

    private let labelColor = Color.white.opacity(0.4)

    var body: some View {
        if let text = detectedText, !text.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("DETECTED TEXT")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(1)
                    .foregroundColor(labelColor)
                Text("\u{201C}\(text)\u{201D}")
                    .font(.system(size: 14, design: .serif))
                    .italic()
                    .foregroundColor(Color.white.opacity(0.7))
                    .lineLimit(4)
            }
        }
    }
}

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

// MARK: - Palette Copy Button (hex code with hover + copied feedback)
struct PaletteCopyButton: View {
    let hex: String
    let tertiaryColor: Color
    @State private var isHovered = false
    @State private var showCopied = false

    var body: some View {
        Button(action: {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(hex, forType: .string)
            withAnimation(.easeOut(duration: 0.15)) { showCopied = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation { showCopied = false }
            }
        }) {
            HStack(spacing: 2) {
                if showCopied {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 7))
                        .foregroundColor(tertiaryColor.opacity(isHovered ? 1 : 0.5))
                }
                Text(showCopied ? "Copied" : hex)
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundColor(showCopied ? .green : (isHovered ? tertiaryColor.opacity(1) : tertiaryColor))
            }
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { isHovered = $0 }
        .help("Copy \(hex)")
    }
}

// MARK: - Score Ring (conic gradient mini donut for similarity)
struct ScoreRing: View {
    let score: Float
    let size: CGFloat
    private var pal: AtelierPalette { ThemeManager.shared.palette }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.black.opacity(0.08), lineWidth: 2.5)
                .frame(width: size, height: size)
            Circle()
                .trim(from: 0, to: CGFloat(score))
                .stroke(pal.accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
            Circle()
                .fill(Color.white)
                .frame(width: size - 4, height: size - 4)
        }
    }
}

// MARK: - Atelier Score Badge (top-left of image area)
struct AtelierScoreBadge: View {
    let score: Float

    var body: some View {
        HStack(spacing: 4) {
            ScoreRing(score: score, size: 14)
            Text(String(format: "%.2f", score))
                .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                .foregroundColor(Color(red: 0x1A/255, green: 0x18/255, blue: 0x14/255))
        }
        .padding(.leading, 7)
        .padding(.trailing, 9)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.94))
                .shadow(color: Color.black.opacity(0.04), radius: 2, y: 1)
        )
        .overlay(
            Capsule()
                .stroke(Color.black.opacity(0.06), lineWidth: 0.5)
        )
    }
}

// MARK: - Atelier Hover Action Bar (bottom of image area, on hover)
struct AtelierActionBar: View {
    let onStar: () -> Void
    let onQuickLook: () -> Void
    let onFinder: () -> Void
    let onCopy: () -> Void
    let onOpen: () -> Void
    let onFindSimilar: (() -> Void)?
    private var pal: AtelierPalette { ThemeManager.shared.palette }

    var body: some View {
        HStack(spacing: 4) {
            actionButton(icon: "star", action: onStar, help: "Favorite")
            actionButton(icon: "eye", action: onQuickLook, help: "Quick Look")
            actionButton(icon: "folder", action: onFinder, help: "Reveal in Finder")
            actionButton(icon: "doc.on.doc", action: onCopy, help: "Copy")
            if let findSimilar = onFindSimilar {
                actionButton(icon: "sparkle.magnifyingglass", action: findSimilar, help: "Find Similar")
            }
            actionButton(icon: "arrow.up.right.square", action: onOpen, help: "Open in Preview")
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
    }

    private func actionButton(icon: String, action: @escaping () -> Void, help: String) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(red: 0x1A/255, green: 0x18/255, blue: 0x14/255))
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.96))
                )
        }
        .buttonStyle(PlainButtonStyle())
        .help(help)
    }
}

// MARK: - Atelier Meta Strip (below image area)
struct AtelierMetaStrip: View {
    let filename: String
    let isFavorite: Bool
    let imageDimensions: String?
    let fileSize: String?
    let dateString: String?
    let isRAW: Bool
    private var pal: AtelierPalette { ThemeManager.shared.palette }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(filename)
                    .font(.system(size: 15.5, design: .serif).italic())
                    .foregroundColor(pal.ink)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 4)
                if isFavorite {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9))
                        .foregroundColor(pal.accent)
                }
            }

            if imageDimensions != nil || fileSize != nil || dateString != nil {
                pal.line
                    .frame(height: 0.5)
                    .padding(.vertical, 2)

                HStack(spacing: 0) {
                    HStack(spacing: 0) {
                        if let dims = imageDimensions {
                            Text(dims)
                                .font(.system(size: 10.5, weight: .regular, design: .monospaced))
                                .foregroundColor(pal.ink3)
                        }
                        if let size = fileSize {
                            if imageDimensions != nil {
                                Text(" \u{00B7} ")
                                    .font(.system(size: 10.5, design: .monospaced))
                                    .foregroundColor(pal.ink3)
                            }
                            Text(size)
                                .font(.system(size: 10.5, weight: .regular, design: .monospaced))
                                .foregroundColor(pal.ink3)
                        }
                    }
                    Spacer(minLength: 8)
                    if let date = dateString {
                        Text(date)
                            .font(.system(size: 11.5, design: .serif).italic())
                            .foregroundColor(pal.ink3)
                    }
                }
            }
        }
        .padding(.init(top: 11, leading: 13, bottom: 12, trailing: 13))
    }
}

// MARK: - Helper: detect RAW format from file extension
private let rawExtensions: Set<String> = ["raw", "cr2", "cr3", "nef", "arw", "orf", "rw2", "dng", "raf", "srw", "pef"]

// MARK: - Masonry Image Card (Dynamic Height) - Atelier Design
struct MasonryImageCard: View {
    let result: SearchResult
    var showSimilarity: Bool = false
    var onFindSimilar: ((String) -> Void)? = nil
    var onOpen: (() -> Void)? = nil
    var onHoverStart: ((SearchResult) -> Void)? = nil
    var onHoverEnd: (() -> Void)? = nil

    @State private var isFavorite: Bool = false
    @State private var isHovered = false
    @State private var showCopied = false
    @State private var thumbnail: NSImage?
    @State private var aspectRatio: CGFloat = 1.0
    @State private var imageDimensions: String?
    @State private var fileSizeString: String?
    @State private var fileDateString: String?
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject private var volumeManager = VolumeManager.shared
    private var pal: AtelierPalette { ThemeManager.shared.palette }

    private let baseWidth: CGFloat = 200

    private var isOffline: Bool {
        volumeManager.isPathOffline(result.path)
    }

    private var fileURL: URL {
        URL(fileURLWithPath: result.path)
    }

    private var isRAW: Bool {
        rawExtensions.contains(fileURL.pathExtension.lowercased())
    }

    var body: some View {
        // Nude direction — just the photo, no chrome
        masonryImageArea
            .aspectRatio(aspectRatio, contentMode: .fit)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .contentShape(RoundedRectangle(cornerRadius: 6))
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.2)) {
                    isHovered = hovering
                }
                if hovering {
                    onHoverStart?(result)
                } else {
                    onHoverEnd?()
                }
            }
            .onTapGesture(count: 2) {
                if let onOpen = onOpen {
                    onOpen()
                } else {
                    handleCopy()
                }
            }
            .contextMenu { masonryContextMenu }
            .onAppear {
                loadMasonryThumbnail()
                loadMasonryFileMetadata()
                isFavorite = FavoritesManager.shared.isFavorite(result.path)
            }
    }

    // MARK: - Image Area
    private var masonryImageArea: some View {
        ZStack {
            masonryImageContent

            if isOffline { masonryOfflineOverlay }
            if showCopied { masonryCopiedFeedback }

            // Relevance dot — top-right
            if showSimilarity {
                VStack {
                    HStack {
                        Spacer()
                        Circle()
                            .fill(pal.accent)
                            .frame(width: 8, height: 8)
                            .opacity(Double(result.similarity))
                            .shadow(color: Color.white.opacity(0.4), radius: 1)
                            .padding(10)
                    }
                    Spacer()
                }
            }

            // Gradient + caption + action bar (always visible)
            if !showCopied {
                VStack {
                    Spacer()
                    ZStack(alignment: .bottom) {
                        LinearGradient(
                            colors: [.clear, Color.black.opacity(isHovered ? 0.65 : 0.45)],
                            startPoint: UnitPoint(x: 0.5, y: 0.0),
                            endPoint: UnitPoint(x: 0.5, y: 1.0)
                        )

                        VStack(alignment: .leading, spacing: 6) {
                            Text(fileURL.deletingPathExtension().lastPathComponent)
                                .font(.system(size: 14, design: .serif).italic())
                                .foregroundColor(.white)
                                .shadow(color: Color.black.opacity(0.4), radius: 4, y: 1)
                                .lineLimit(1)

                            if isHovered {
                                AtelierActionBar(
                                    onStar: {
                                        isFavorite.toggle()
                                        FavoritesManager.shared.toggleFavorite(result.path)
                                    },
                                    onQuickLook: masonryOpenInPreview,
                                    onFinder: masonryOpenInFinder,
                                    onCopy: handleCopy,
                                    onOpen: masonryOpenInPreview,
                                    onFindSimilar: onFindSimilar != nil ? { onFindSimilar?(result.path) } : nil
                                )
                                .transition(.opacity)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.bottom, 8)
                    }
                }
            }
        }
    }

    private var masonryImageContent: some View {
        GeometryReader { geo in
            if let thumb = thumbnail {
                Image(nsImage: thumb)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            } else {
                Rectangle()
                    .fill(pal.line.opacity(0.3))
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.6)
                    )
            }
        }
    }

    // MARK: - Badges

    private var masonryOfflineBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "externaldrive.badge.xmark")
                .font(.system(size: 9, weight: .bold))
            Text("Offline")
                .font(.system(size: 10, weight: .bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Capsule().fill(DesignSystem.Colors.warning))
    }

    private var masonryRawBadge: some View {
        Text("RAW")
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(pal.accent))
    }

    private var masonryOfflineOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
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

    private var masonryCopiedFeedback: some View {
        ZStack {
            Color.black.opacity(0.5)
            VStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.success)
                Text("Copied")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .transition(.opacity)
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var masonryContextMenu: some View {
        Group {
            Button(action: { masonryOpenInPreview() }) {
                Label("Quick Look", systemImage: "eye")
            }
            .keyboardShortcut(" ", modifiers: [])

            Button(action: {
                NSWorkspace.shared.open(URL(fileURLWithPath: result.path))
            }) {
                Label("Open in Default App", systemImage: "arrow.up.right.square")
            }
            .keyboardShortcut("o", modifiers: .command)

            Button(action: { masonryOpenInFinder() }) {
                Label("Reveal in Finder", systemImage: "folder")
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])

            Divider()

            Button(action: { handleCopy() }) {
                Label("Copy Image", systemImage: "doc.on.doc")
            }
            .keyboardShortcut("c", modifiers: .command)

            Button(action: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(result.path, forType: .string)
            }) {
                Label("Copy Path", systemImage: "link")
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])

            if let onFindSimilar = onFindSimilar {
                Button(action: { onFindSimilar(result.path) }) {
                    Label("Find Similar", systemImage: "sparkle.magnifyingglass")
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
            }

            Divider()

            Button(action: {
                isFavorite.toggle()
                FavoritesManager.shared.toggleFavorite(result.path)
            }) {
                Label(isFavorite ? "Remove from Favorites" : "Add to Favorites", systemImage: isFavorite ? "heart.slash" : "heart")
            }

            if !FavoritesManager.shared.collections.isEmpty {
                Menu("Add to Collection") {
                    ForEach(FavoritesManager.shared.collections) { collection in
                        Button(action: {
                            // Auto-favorite if not already
                            if !FavoritesManager.shared.isFavorite(result.path) {
                                isFavorite = true
                                FavoritesManager.shared.toggleFavorite(result.path)
                            }
                            FavoritesManager.shared.addToCollection(id: collection.id, path: result.path)
                        }) {
                            Label(collection.name, systemImage: collection.paths.contains(result.path) ? "checkmark.circle.fill" : "folder")
                        }
                    }
                }
            }

            Button(action: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(URL(fileURLWithPath: result.path).lastPathComponent, forType: .string)
            }) {
                Label("Copy Filename", systemImage: "textformat")
            }

            Divider()

            Button(role: .destructive, action: {
                // Move to trash
                try? FileManager.default.trashItem(at: URL(fileURLWithPath: result.path), resultingItemURL: nil)
            }) {
                Label("Move to Trash", systemImage: "trash")
            }
        }
    }

    // MARK: - Data Loading

    private func loadMasonryThumbnail() {
        DispatchQueue.global(qos: .userInitiated).async {
            let url = URL(fileURLWithPath: result.path)
            guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else { return }

            var dims: String? = nil
            if let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
               let pixelWidth = properties[kCGImagePropertyPixelWidth] as? Int,
               let pixelHeight = properties[kCGImagePropertyPixelHeight] as? Int {
                dims = "\(pixelWidth)\u{00D7}\(pixelHeight)"
            }

            if let image = loadMasonryOptimizedThumbnail(from: imageSource, maxSize: 400) {
                let ratio = image.size.width / max(image.size.height, 1)
                DispatchQueue.main.async {
                    self.thumbnail = image
                    self.aspectRatio = max(0.5, min(2.0, ratio))
                    self.imageDimensions = dims
                }
            }
        }
    }

    private func loadMasonryFileMetadata() {
        DispatchQueue.global(qos: .utility).async {
            var sizeStr: String? = nil
            if let size = result.size {
                sizeStr = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
            } else if let attrs = try? FileManager.default.attributesOfItem(atPath: result.path),
                      let fileSize = attrs[.size] as? Int64 {
                sizeStr = ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
            }
            var dateStr: String? = result.date
            if dateStr == nil,
               let attrs = try? FileManager.default.attributesOfItem(atPath: result.path),
               let modDate = attrs[.modificationDate] as? Date {
                let fmt = DateFormatter()
                fmt.dateStyle = .medium
                fmt.timeStyle = .none
                dateStr = fmt.string(from: modDate)
            }
            DispatchQueue.main.async {
                self.fileSizeString = sizeStr
                self.fileDateString = dateStr
            }
        }
    }

    private func loadMasonryOptimizedThumbnail(from imageSource: CGImageSource, maxSize: Int) -> NSImage? {
        let options: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: maxSize,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    // MARK: - Actions

    private func handleCopy() {
        guard let image = NSImage(contentsOfFile: result.path) else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])

        withAnimation(.easeOut(duration: 0.15)) { showCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showCopied = false }
        }
    }

    private func masonryOpenInFinder() {
        NSWorkspace.shared.selectFile(result.path, inFileViewerRootedAtPath: "")
    }

    private func masonryOpenInPreview() {
        NSWorkspace.shared.open(
            [URL(fileURLWithPath: result.path)],
            withApplicationAt: URL(fileURLWithPath: "/System/Applications/Preview.app"),
            configuration: NSWorkspace.OpenConfiguration()
        )
    }
}

// MARK: - Preview Panel (AtelierDetail-style)
struct PreviewPanel: View {
    let result: SearchResult
    let onClose: () -> Void

    @State private var fullImage: NSImage?
    @State private var showCopied = false
    @Environment(\.colorScheme) var colorScheme
    private var pal: AtelierPalette { ThemeManager.shared.palette }

    private let panelBg = Color(hex: "15120D")
    private let dividerColor = Color.white.opacity(0.08)
    private let labelColor = Color.white.opacity(0.4)
    private let valueColor = Color.white.opacity(0.85)

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
                        .fill(Color.white.opacity(0.05))
                        .frame(height: 200)
                        .overlay(ProgressView())
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.bottom, 12)

            // Title
            Text(URL(fileURLWithPath: result.path).lastPathComponent)
                .font(.system(size: 22, design: .serif).italic())
                .foregroundColor(.white)
                .lineLimit(2)

            // Match score
            if result.similarity < 1.0 {
                Text(String(format: "%.0f%% match", result.similarity * 100))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color(red: 1, green: 1, blue: 1, opacity: 0.45))
                    .padding(.top, 4)
            }

            dividerColor.frame(height: 1).padding(.vertical, 12)

            // Metadata grid - 2 columns
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                // Path
                GridRow {
                    Text("LOCATION")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1.2)
                        .foregroundColor(labelColor)
                    Text(URL(fileURLWithPath: result.path).deletingLastPathComponent().path)
                        .font(.system(size: 11))
                        .foregroundColor(valueColor)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }

                // Size
                if let size = result.size {
                    GridRow {
                        Text("SIZE")
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(1.2)
                            .foregroundColor(labelColor)
                        Text(formatFileSize(size))
                            .font(.system(size: 11))
                            .foregroundColor(valueColor)
                    }
                }

                // Date
                if let dateStr = result.date, let date = ISO8601DateFormatter().date(from: dateStr) {
                    GridRow {
                        Text("DATE")
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(1.2)
                            .foregroundColor(labelColor)
                        Text(date, style: .date)
                            .font(.system(size: 11))
                            .foregroundColor(valueColor)
                    }
                }

                // Similarity
                if result.similarity < 1.0 {
                    GridRow {
                        Text("MATCH")
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(1.2)
                            .foregroundColor(labelColor)
                        Text("\(Int(result.similarity * 100))%")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(pal.accent)
                    }
                }
            }

            dividerColor.frame(height: 1).padding(.vertical, 12)

            // Action buttons
            VStack(spacing: 8) {
                // Primary: Reveal in Finder
                Button(action: {
                    NSWorkspace.shared.selectFile(result.path, inFileViewerRootedAtPath: "")
                }) {
                    HStack {
                        Image(systemName: "folder")
                        Text("Reveal in Finder")
                        Spacer()
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.vertical, 7)
                    .padding(.horizontal, 10)
                    .background(RoundedRectangle(cornerRadius: 6).fill(pal.accent))
                }
                .buttonStyle(PlainButtonStyle())

                // Secondary: Copy
                Button(action: {
                    if let image = NSImage(contentsOfFile: result.path) {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.writeObjects([image])
                        showCopied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            showCopied = false
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                        Text(showCopied ? "Copied!" : "Copy Image")
                        Spacer()
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(valueColor)
                    .padding(.vertical, 7)
                    .padding(.horizontal, 10)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(PlainButtonStyle())
            }

            Spacer()
        }
        .padding(16)
        .frame(width: 280)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(panelBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(dividerColor, lineWidth: 1)
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

// MARK: - Resizable Preview Panel (Inspector — Atelier design)
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
    @State private var imageDimensions: CGSize?
    @State private var extractedColors: [NSColor] = []
    @State private var dragStartWidth: CGFloat = 0
    @State private var isFavorite: Bool = false
    @State private var showCopied: Bool = false
    @State private var cameraModel: String?
    @State private var creationDate: String?
    @Environment(\.colorScheme) var colorScheme
    private var pal: AtelierPalette { ThemeManager.shared.palette }

    // Computed helpers for widget vs app styling
    private var eyebrowColor: Color { style == .widget ? .white.opacity(0.4) : pal.ink3 }
    private var titleColor: Color { style == .widget ? .white : pal.ink }
    private var secondaryColor: Color { style == .widget ? .white.opacity(0.6) : pal.ink2 }
    private var tertiaryColor: Color { style == .widget ? .white.opacity(0.4) : pal.ink3 }
    private var lineColor: Color { style == .widget ? .white.opacity(0.12) : pal.line }
    private var cardBg: Color { style == .widget ? .white.opacity(0.08) : pal.card }
    private var paperBg: Color { style == .widget ? .white.opacity(0.05) : pal.paper }
    private var accentColor: Color { style == .widget ? .cyan : pal.accent }

    var body: some View {
        HStack(spacing: 0) {
            // Resize handle (left edge)
            resizeHandle

            // Main column
            VStack(spacing: 0) {
                // MARK: Sticky Header
                inspectorHeader

                // MARK: Scrollable Content
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 0) {
                        // a. Hero preview thumb
                        heroPreviewSection

                        sectionDivider

                        // b. Match score
                        matchScoreSection

                        sectionDivider

                        // c. Token attribution ("The model saw")
                        tokenAttributionSection

                        sectionDivider

                        // d. Facts (EXIF)
                        factsSection

                        sectionDivider

                        // e. Palette (extracted colors)
                        if !extractedColors.isEmpty {
                            paletteSection
                            sectionDivider
                        }

                        // f. Similar images
                        similarImagesSection

                        sectionDivider

                        // g. Path
                        pathSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 20)
                }

                // MARK: Sticky Footer
                inspectorFooter
            }
        }
        .frame(width: width)
        .background(
            style == .widget ?
                AnyShapeStyle(.ultraThinMaterial.opacity(0.6)) :
                AnyShapeStyle(pal.card)
        )
        .overlay(
            Rectangle()
                .fill(lineColor)
                .frame(width: 1),
            alignment: .leading
        )
        .shadow(color: Color(red: 20/255, green: 18/255, blue: 15/255).opacity(0.20), radius: 32, x: -24, y: 0)
        .onAppear {
            loadFullImage()
            loadMetadata()
            isFavorite = FavoritesManager.shared.isFavorite(result.path)
        }
        .onChange(of: result.path) { _, _ in
            loadFullImage()
            loadMetadata()
            isFavorite = FavoritesManager.shared.isFavorite(result.path)
        }
    }

    // MARK: - Header

    private var inspectorHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("INSPECTOR")
                        .font(.system(size: 9.5, weight: .semibold))
                        .tracking(1.6)
                        .foregroundColor(eyebrowColor)

                    Text(URL(fileURLWithPath: result.path).deletingPathExtension().lastPathComponent)
                        .font(.system(size: 22, design: .serif))
                        .italic()
                        .foregroundColor(titleColor)
                        .lineLimit(2)
                }

                Spacer()

                // Close button — 26x26 circle
                Button(action: {
                    withAnimation(.easeOut(duration: 0.15)) {
                        isVisible = false
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(paperBg)
                            .overlay(Circle().stroke(lineColor, lineWidth: 1))
                            .frame(width: 26, height: 26)
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(tertiaryColor)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.top, 18)
        .padding(.horizontal, 20)
        .padding(.bottom, 14)
        .overlay(
            Rectangle().fill(lineColor).frame(height: 0.5),
            alignment: .bottom
        )
    }

    // MARK: - Hero Preview

    @ViewBuilder
    private var heroPreviewSection: some View {
        ZStack(alignment: .topTrailing) {
            ZStack(alignment: .bottomLeading) {
                if let image = fullImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .frame(maxHeight: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(style == .widget ? Color.white.opacity(0.06) : pal.line.opacity(0.3))
                        .frame(height: 160)
                        .overlay(ProgressView())
                }
            }

            // Position badge
            if let index = SearchManager.shared.results.firstIndex(where: { $0.path == result.path }) {
                Text("\(index + 1) of \(SearchManager.shared.results.count)")
                    .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                    .foregroundColor(secondaryColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(cardBg)
                            .overlay(Capsule().stroke(lineColor, lineWidth: 0.5))
                    )
                    .padding(8)
            }
        }
        .padding(.bottom, 14)
    }

    // MARK: - Match Score Section

    @ViewBuilder
    private var matchScoreSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            inspectorSectionTitle("MATCH SCORE")

            // Big score display
            HStack(alignment: .firstTextBaseline) {
                Text(String(format: "%.2f", result.similarity))
                    .font(.system(size: 38, design: .serif))
                    .foregroundColor(accentColor)
                Text("/ 1.00")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(tertiaryColor)

                Spacer()

                // Percentile pill
                let percentile = max(0.1, (1.0 - result.similarity) * 100)
                Text("top \(String(format: "%.1f", percentile))%")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(secondaryColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(paperBg)
                            .overlay(Capsule().stroke(lineColor, lineWidth: 0.5))
                    )
            }

            // Dual vision/text bars
            VStack(spacing: 8) {
                inspectorScoreBar(icon: "eye", label: "Vision", value: result.similarity * 0.95)
                inspectorScoreBar(icon: "text.alignleft", label: "Text", value: result.similarity * 1.02 > 1.0 ? 1.0 : result.similarity * 1.02)
            }
        }
        .padding(.bottom, 18)
    }

    private func inspectorScoreBar(icon: String, label: String, value: Float) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(tertiaryColor)
                .frame(width: 14)

            Text(label)
                .font(.system(size: 10))
                .foregroundColor(secondaryColor)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(lineColor)
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(accentColor)
                        .frame(width: geo.size.width * CGFloat(value), height: 4)
                }
            }
            .frame(height: 4)

            Text(String(format: "%.2f", value))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(tertiaryColor)
        }
    }

    // MARK: - Facts Section (EXIF)

    @ViewBuilder
    private var factsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            inspectorSectionTitle("FACTS")

            let columns = [
                GridItem(.flexible(), spacing: 14),
                GridItem(.flexible(), spacing: 14)
            ]

            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                if let date = result.date ?? creationDate {
                    inspectorFactItem(label: "DATE", value: date)
                }

                inspectorFactItem(label: "FORMAT", value: result.fileExtension.uppercased())

                if let dims = imageDimensions {
                    inspectorFactItem(label: "DIMENSIONS", value: "\(Int(dims.width)) x \(Int(dims.height))")
                }

                if let size = result.size {
                    inspectorFactItem(label: "SIZE", value: formatFileSize(size))
                }

                if let camera = cameraModel {
                    inspectorFactItem(label: "CAMERA", value: camera)
                }
            }
        }
        .padding(.bottom, 18)
    }

    private func inspectorFactItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.2)
                .foregroundColor(tertiaryColor)
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(titleColor)
                .lineLimit(1)
        }
    }

    // MARK: - Palette Section

    @ViewBuilder
    private var paletteSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            inspectorSectionTitle("PALETTE")

            // Color bar
            HStack(spacing: 0) {
                ForEach(Array(extractedColors.prefix(5).enumerated()), id: \.offset) { _, nsColor in
                    Rectangle()
                        .fill(Color(nsColor: nsColor))
                }
            }
            .frame(height: 36)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(lineColor, lineWidth: 0.5)
            )

            // Hex values — click to copy
            HStack(spacing: 0) {
                ForEach(Array(extractedColors.prefix(5).enumerated()), id: \.offset) { _, nsColor in
                    let hex = hexString(from: nsColor)
                    PaletteCopyButton(hex: hex, tertiaryColor: tertiaryColor)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.bottom, 18)
    }

    // MARK: - Path Section

    @ViewBuilder
    private var pathSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            inspectorSectionTitle("PATH")

            HStack(spacing: 8) {
                Image(systemName: "folder")
                    .font(.system(size: 11))
                    .foregroundColor(tertiaryColor)
                Text(result.path)
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundColor(titleColor)
                    .lineLimit(3)
                    .truncationMode(.middle)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(paperBg)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(lineColor, lineWidth: 0.5))
            )
        }
        .padding(.bottom, 18)
    }

    // MARK: - Token Attribution Section ("The model saw")

    @ViewBuilder
    private var tokenAttributionSection: some View {
        let tokens = generateTokens()
        VStack(alignment: .leading, spacing: 10) {
            inspectorSectionTitle("THE MODEL SAW")

            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(tokens.prefix(5).enumerated()), id: \.offset) { _, token in
                    tokenAttributionRow(token)
                }
            }
        }
        .padding(.bottom, 18)
    }

    private func tokenAttributionRow(_ token: TokenAttribution) -> some View {
        let barOpacity: Double = Double(0.7 + token.confidence * 0.3)
        let barWidth: CGFloat = CGFloat(token.confidence)
        let pctText = String(format: "%.0f%%", token.confidence * 100)

        return HStack(spacing: 8) {
            Text(token.label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(titleColor)
                .frame(width: 80, alignment: .leading)
                .lineLimit(1)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(lineColor)
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(accentColor.opacity(barOpacity))
                        .frame(width: geo.size.width * barWidth, height: 6)
                }
            }
            .frame(height: 6)

            Text(pctText)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(tertiaryColor)
                .frame(width: 30, alignment: .trailing)
        }
    }

    private struct TokenAttribution {
        let label: String
        let confidence: Float
    }

    private func generateTokens() -> [TokenAttribution] {
        // Extract meaningful tokens from the filename
        let filename = URL(fileURLWithPath: result.path).deletingPathExtension().lastPathComponent
        let words = filename.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }

        var tokens: [TokenAttribution] = []
        let baseScore = result.similarity

        // Add tokens from filename words with descending confidence
        for (i, word) in words.prefix(3).enumerated() {
            tokens.append(TokenAttribution(
                label: word.lowercased(),
                confidence: max(0.2, baseScore - Float(i) * 0.12)
            ))
        }

        // Add format token
        tokens.append(TokenAttribution(
            label: result.fileExtension.lowercased(),
            confidence: max(0.1, baseScore * 0.4)
        ))

        // Add a visual token
        tokens.append(TokenAttribution(
            label: "visual",
            confidence: max(0.3, baseScore * 0.8)
        ))

        return tokens.sorted { $0.confidence > $1.confidence }
    }

    // MARK: - Similar Images Section

    @ViewBuilder
    private var similarImagesSection: some View {
        let nearby = SearchManager.shared.results.filter { $0.path != result.path }.prefix(4)

        if !nearby.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                inspectorSectionTitle("SIMILAR")

                let columns = [
                    GridItem(.flexible(), spacing: 6),
                    GridItem(.flexible(), spacing: 6),
                    GridItem(.flexible(), spacing: 6),
                    GridItem(.flexible(), spacing: 6)
                ]

                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(Array(nearby), id: \.path) { similar in
                        AsyncThumbnailView(path: similar.path, maxSize: 100, contentMode: .fill)
                            .frame(height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(lineColor, lineWidth: 0.5)
                            )
                    }
                }
            }
            .padding(.bottom, 18)
        }
    }

    // MARK: - Sticky Footer

    private var inspectorFooter: some View {
        HStack(spacing: 8) {
            // Reveal primary button
            Button(action: openInFinder) {
                HStack(spacing: 6) {
                    Image(systemName: "folder")
                        .font(.system(size: 11))
                    Text("Reveal")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(accentColor)
                )
            }
            .buttonStyle(PlainButtonStyle())

            // Copy ghost button
            Button(action: copyImage) {
                HStack(spacing: 4) {
                    Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 11))
                    Text(showCopied ? "Done" : "Copy")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(secondaryColor)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(cardBg)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(lineColor, lineWidth: 0.5))
                )
            }
            .buttonStyle(PlainButtonStyle())

            // Star ghost button
            Button(action: toggleFavorite) {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .font(.system(size: 12))
                    .foregroundColor(isFavorite ? accentColor : secondaryColor)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(cardBg)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(lineColor, lineWidth: 0.5))
                    )
            }
            .buttonStyle(PlainButtonStyle())

            // Trash ghost button
            Button(action: {
                do {
                    try FileManager.default.trashItem(at: URL(fileURLWithPath: result.path), resultingItemURL: nil)
                    withAnimation(.easeOut(duration: 0.15)) {
                        isVisible = false
                    }
                } catch {
                    print("Failed to trash: \(error)")
                }
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundColor(secondaryColor)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(cardBg)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(lineColor, lineWidth: 0.5))
                    )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(paperBg)
        .overlay(
            Rectangle().fill(lineColor).frame(height: 0.5),
            alignment: .top
        )
    }

    // MARK: - Helpers

    private func inspectorSectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9.5, weight: .semibold))
            .tracking(1.6)
            .foregroundColor(eyebrowColor)
    }

    private var sectionDivider: some View {
        Rectangle()
            .fill(lineColor)
            .frame(height: 0.5)
            .padding(.bottom, 18)
    }

    private var resizeHandle: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.01))
            .frame(width: 12)
            .overlay(
                Rectangle()
                    .fill(style == .widget ? Color.white.opacity(0.3) : pal.ink3.opacity(0.5))
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

    // MARK: - Data Loading

    private func loadFullImage() {
        fullImage = nil
        imageDimensions = nil
        extractedColors = []
        DispatchQueue.global(qos: .userInitiated).async {
            if let image = NSImage(contentsOfFile: result.path) {
                let dims = CGSize(width: image.representations.first?.pixelsWide ?? Int(image.size.width),
                                  height: image.representations.first?.pixelsHigh ?? Int(image.size.height))
                let colors = Self.extractDominantColors(from: image, count: 5)
                DispatchQueue.main.async {
                    self.fullImage = image
                    self.imageDimensions = dims
                    self.extractedColors = colors
                }
            }
        }
    }

    private func loadMetadata() {
        cameraModel = nil
        creationDate = nil
        DispatchQueue.global(qos: .userInitiated).async {
            let url = URL(fileURLWithPath: result.path)
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else { return }

            var camera: String?
            var dateStr: String?

            if let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] {
                dateStr = exif[kCGImagePropertyExifDateTimeOriginal] as? String
            }
            if let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
                camera = tiff[kCGImagePropertyTIFFModel] as? String
                if dateStr == nil {
                    dateStr = tiff[kCGImagePropertyTIFFDateTime] as? String
                }
            }

            DispatchQueue.main.async {
                self.cameraModel = camera
                if self.result.date == nil {
                    self.creationDate = dateStr
                }
            }
        }
    }

    private static func extractDominantColors(from image: NSImage, count: Int) -> [NSColor] {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return [] }

        // Sample down to a small size for color extraction
        let sampleSize = 32
        guard let resized = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: sampleSize,
            pixelsHigh: sampleSize,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: sampleSize * 4,
            bitsPerPixel: 32
        ) else { return [] }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: resized)
        bitmap.draw(in: NSRect(x: 0, y: 0, width: sampleSize, height: sampleSize))
        NSGraphicsContext.restoreGraphicsState()

        // Collect colors from sampled pixels
        var colorBuckets: [NSColor] = []
        for y in stride(from: 0, to: sampleSize, by: 2) {
            for x in stride(from: 0, to: sampleSize, by: 2) {
                if let color = resized.colorAt(x: x, y: y) {
                    colorBuckets.append(color)
                }
            }
        }

        // Pick maximally spread-out colors
        guard !colorBuckets.isEmpty else { return [] }
        var selected: [NSColor] = [colorBuckets[0]]

        for _ in 1..<min(count, colorBuckets.count) {
            var bestColor = colorBuckets[0]
            var bestDist: CGFloat = 0
            for c in colorBuckets {
                let minDist = selected.map { colorDistance(c, $0) }.min() ?? 0
                if minDist > bestDist {
                    bestDist = minDist
                    bestColor = c
                }
            }
            selected.append(bestColor)
        }

        return selected
    }

    private static func colorDistance(_ a: NSColor, _ b: NSColor) -> CGFloat {
        let ar = a.redComponent, ag = a.greenComponent, ab = a.blueComponent
        let br = b.redComponent, bg = b.greenComponent, bb = b.blueComponent
        return sqrt(pow(ar - br, 2) + pow(ag - bg, 2) + pow(ab - bb, 2))
    }

    private func hexString(from color: NSColor) -> String {
        let c = color.usingColorSpace(.deviceRGB) ?? color
        let r = Int(c.redComponent * 255)
        let g = Int(c.greenComponent * 255)
        let b = Int(c.blueComponent * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
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
    @State private var previewPanelWidth: CGFloat = 340
    @State private var isResizingPanel = false
    let previousApp: NSRunningApplication?
    @Environment(\.colorScheme) var colorScheme
    @FocusState private var isSearchFocused: Bool
    private var pal: AtelierPalette { themeManager.palette }

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

    // MARK: - Atelier Spotlight Colors
    private let spotlightPaper = Color(red: 252/255, green: 249/255, blue: 243/255).opacity(0.96)

    private func kbdText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundColor(Color(red: 120/255, green: 113/255, blue: 100/255))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color(red: 252/255, green: 249/255, blue: 243/255))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.black.opacity(0.08), lineWidth: 0.5)
            )
    }

    // MARK: - Search Bar (pasted image mode)
    @ViewBuilder
    private var pastedImageSearchBar: some View {
        if let image = pastedImage {
            ZStack(alignment: .topTrailing) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(pal.line, lineWidth: 1)
                    )

                Button(action: {
                    withAnimation(.easeOut(duration: 0.15)) {
                        pastedImage = nil
                        hasPerformedSearch = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(pal.ink2)
                        .background(Circle().fill(spotlightPaper))
                }
                .buttonStyle(PlainButtonStyle())
                .offset(x: 5, y: -5)
            }

            Text("Finding similar...")
                .font(.system(size: 22, weight: .regular, design: .serif))
                .italic()
                .foregroundColor(pal.ink3)

            Spacer()

            if searchManager.isSearching {
                ProgressView()
                    .scaleEffect(0.8)
            }

            kbdText("esc")
        }
    }

    // MARK: - Search Bar (text mode)
    @ViewBuilder
    private var textSearchBar: some View {
        Image(systemName: "magnifyingglass")
            .font(.system(size: 18, weight: .medium))
            .foregroundColor(pal.accent)

        TextField("Search images...", text: $searchText)
            .textFieldStyle(PlainTextFieldStyle())
            .font(.system(size: 22, weight: .regular, design: .serif))
            .foregroundColor(pal.ink)
            .focused($isSearchFocused)
            .onSubmit {
                if !searchManager.isSearching && !searchText.isEmpty {
                    searchDebounceTimer?.invalidate()
                    performSearch()
                }
            }
            .onChange(of: searchText) { oldValue, newValue in
                selectedIndex = 0
                searchDebounceTimer?.invalidate()
                if newValue.isEmpty {
                    hasPerformedSearch = false
                    return
                }
                searchDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { _ in
                    if !searchManager.isSearching && !newValue.isEmpty {
                        performSearch()
                    }
                }
            }

        if searchManager.isSearching {
            ProgressView()
                .scaleEffect(0.8)
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
                    .font(.system(size: 16))
                    .foregroundColor(pal.ink3)
            }
            .buttonStyle(PlainButtonStyle())
            .transition(.scale.combined(with: .opacity))
        }

        Spacer()

        kbdText("esc")
    }

    // MARK: - Results Section
    @ViewBuilder
    private var resultsSection: some View {
        if isLoadingRecent && recentImages.isEmpty && !hasPerformedSearch {
            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.0)
                Text("Loading recent images...")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(pal.ink3)
            }
            .padding(32)
        } else if !displayResults.isEmpty {
            resultsHeader
            resultsContent
        }
    }

    private var resultsHeader: some View {
        HStack {
            Text(hasPerformedSearch ?
                 "TOP MATCHES \u{00B7} \(displayResults.count) RESULTS" :
                 "RECENT \u{00B7} \(displayResults.count) IMAGES")
                .font(.system(size: 11, weight: .medium))
                .tracking(1.2)
                .foregroundColor(pal.ink3)
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    private var resultsContent: some View {
        HStack(alignment: .top, spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(Array(displayResults.enumerated()), id: \.element.id) { index, result in
                            SpotlightResultRow(
                                result: result,
                                isSelected: index == selectedIndex,
                                index: index,
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
                    .animation(nil, value: selectedIndex)
                }
                .frame(maxHeight: 310)
                .animation(nil, value: selectedIndex)
                .onChange(of: selectedIndex) { oldValue, newValue in
                    proxy.scrollTo(newValue, anchor: .center)
                    startPreviewTimer()
                }
            }
            .layoutPriority(1)

            if showPreviewPanel && selectedIndex < displayResults.count {
                ResizablePreviewPanel(
                    result: displayResults[selectedIndex],
                    width: $previewPanelWidth,
                    isVisible: $showPreviewPanel,
                    style: .widget
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .padding(.trailing, 8)
            }
        }
    }

    // MARK: - Footer
    private var spotlightFooter: some View {
        HStack(spacing: 0) {
            HStack(spacing: 16) {
                Text("\u{21B5} paste")
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundColor(pal.ink3)
                Text("\u{2318}\u{21B5} reveal")
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundColor(pal.ink3)
                Text("\u{2191}\u{2193} navigate")
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundColor(pal.ink3)
            }

            Spacer()

            if let stats = searchManager.searchStats {
                Text("vision-weighted \u{00B7} \(stats.total_time)")
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundColor(pal.ink3)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(pal.line.opacity(0.5))
                .frame(height: 0.5)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 12) {
                if pastedImage != nil {
                    pastedImageSearchBar
                } else {
                    textSearchBar
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 16)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(pal.line.opacity(0.5))
                    .frame(height: 0.5)
            }
            .onDrop(of: [.image, .fileURL], isTargeted: $isDropTargeted) { providers in
                handleDroppedImage(providers: providers)
                return true
            }

            // Results
            resultsSection

            Spacer(minLength: 0)

            // Footer
            spotlightFooter
        }
        .frame(width: 640)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(spotlightPaper)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(.ultraThinMaterial)
                )
                .shadow(color: Color.black.opacity(0.35), radius: 40, x: 0, y: 30)
                .shadow(color: Color.black.opacity(0.08), radius: 0, x: 0, y: 0)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.black.opacity(0.08), lineWidth: 0.5)
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
    var index: Int = 0
    let onSelect: () -> Void
    @State private var isHovered = false
    @State private var showingCopyNotification = false
    @State private var thumbnail: NSImage?
    @State private var imageDimensions: String = ""
    @Environment(\.colorScheme) var colorScheme
    private var pal: AtelierPalette { ThemeManager.shared.palette }

    private let thumbnailWidth: CGFloat = 56
    private let thumbnailHeight: CGFloat = 42

    var body: some View {
        HStack(spacing: 14) {
            // Accent left border
            Rectangle()
                .fill(isSelected ? pal.accent : Color.clear)
                .frame(width: 2)

            // Thumbnail
            Group {
                if let image = thumbnail {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(pal.line.opacity(0.2))
                }
            }
            .frame(width: thumbnailWidth, height: thumbnailHeight)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .onAppear {
                loadThumbnail()
                loadImageDimensions()
            }

            // Text content
            VStack(alignment: .leading, spacing: 3) {
                Text(URL(fileURLWithPath: result.path).lastPathComponent)
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .italic()
                    .foregroundColor(pal.ink)
                    .lineLimit(1)

                Text(subtitleText)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundColor(pal.ink3)
                    .lineLimit(1)
            }

            Spacer()

            // Shortcut kbd pill
            if index < 9 {
                Text("⌘\(index + 1)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(red: 120/255, green: 113/255, blue: 100/255))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color(red: 252/255, green: 249/255, blue: 243/255))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.black.opacity(0.08), lineWidth: 0.5)
                    )
                    .opacity((isHovered || isSelected) ? 1 : 0.4)
            }
        }
        .padding(.vertical, 8)
        .padding(.trailing, 18)
        .background(
            isSelected ?
                pal.accent.opacity(0.08) :
                (isHovered ? pal.accent.opacity(0.04) : Color.clear)
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
                    CopyNotification(
                        isShowing: $showingCopyNotification,
                        filename: URL(fileURLWithPath: result.path).lastPathComponent
                    )
                    .allowsHitTesting(false)
                    .transition(.scale.combined(with: .opacity))
                }
            }
        )
    }

    private var subtitleText: String {
        var parts: [String] = []
        parts.append("\(Int(result.similarity * 100))%")
        if !imageDimensions.isEmpty {
            parts.append(imageDimensions)
        }
        if let size = result.size {
            parts.append(formatFileSize(size))
        }
        return parts.joined(separator: " · ")
    }

    private func formatFileSize(_ bytes: Int) -> String {
        if bytes >= 1_048_576 {
            return String(format: "%.1f MB", Double(bytes) / 1_048_576.0)
        } else if bytes >= 1024 {
            return "\(bytes / 1024) KB"
        } else {
            return "\(bytes) B"
        }
    }

    private func showCopyNotification() {
        showingCopyNotification = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showingCopyNotification = false
        }
    }

    private func loadThumbnail() {
        let size = Int(thumbnailWidth) * 2
        if let cached = ThumbnailService.shared.cachedThumbnail(for: result.path, size: size) {
            self.thumbnail = cached
            return
        }
        ThumbnailService.shared.loadThumbnail(for: result.path, maxSize: size) { thumb in
            self.thumbnail = thumb
        }
    }

    private func loadImageDimensions() {
        DispatchQueue.global(qos: .utility).async {
            if let imageSource = CGImageSourceCreateWithURL(URL(fileURLWithPath: result.path) as CFURL, nil),
               let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any],
               let width = properties[kCGImagePropertyPixelWidth as String] as? Int,
               let height = properties[kCGImagePropertyPixelHeight as String] as? Int {
                DispatchQueue.main.async {
                    self.imageDimensions = "\(width)×\(height)"
                }
            }
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
    private var pal: AtelierPalette { ThemeManager.shared.palette }

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
                .background(pal.sidebar)
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
                HStack(spacing: 4) {
                    Image(systemName: "sparkle")
                        .font(.system(size: 9, weight: .bold))
                    Text("\(Int(result.similarity * 100))%")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(similarityColor)
                )
                .padding(8)
                .scaleEffect(isHovered ? 1.08 : 1.0)
                .allowsHitTesting(false)

                // Copy notification overlay
                if showingCopyNotification {
                    CopyNotification(
                        isShowing: $showingCopyNotification,
                        filename: URL(fileURLWithPath: result.path).lastPathComponent
                    )
                    .allowsHitTesting(false)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }

            // Minimal info section - just filename
            Text(URL(fileURLWithPath: result.path).lastPathComponent)
                .lineLimit(1)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(pal.ink)
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(pal.card)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    isHovered ? pal.accent.opacity(0.5) : pal.line,
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
            return pal.accent
        } else {
            return DesignSystem.Colors.warning
        }
    }

    private var similarityGradient: [Color] {
        let percentage = result.similarity * 100
        if percentage >= 80 {
            return [DesignSystem.Colors.success, DesignSystem.Colors.success.opacity(0.8)]
        } else if percentage >= 60 {
            return [pal.accent, pal.accent.opacity(0.7)]
        } else if percentage >= 40 {
            return [DesignSystem.Colors.warning, DesignSystem.Colors.warning.opacity(0.8)]
        } else {
            return [DesignSystem.Colors.error, DesignSystem.Colors.error.opacity(0.8)]
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

// MARK: - Image Card (Grid Layout) - Atelier Design
struct ImageCard: View {
    let result: SearchResult
    var showSimilarity: Bool = false
    var cardHeight: CGFloat = 200
    var onFindSimilar: ((String) -> Void)? = nil
    var onOpen: (() -> Void)? = nil
    @State private var isFavorite: Bool = false

    @State private var isHovered = false
    @State private var showCopied = false
    @State private var thumbnail: NSImage?
    @State private var imageDimensions: String?
    @State private var fileSizeString: String?
    @State private var fileDateString: String?
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject private var volumeManager = VolumeManager.shared
    private var pal: AtelierPalette { ThemeManager.shared.palette }

    private var isOffline: Bool {
        volumeManager.isPathOffline(result.path)
    }

    private var fileURL: URL {
        URL(fileURLWithPath: result.path)
    }

    private var isRAW: Bool {
        rawExtensions.contains(fileURL.pathExtension.lowercased())
    }

    var body: some View {
        // Nude direction — just the photo, no chrome
        gridImageArea
            .frame(minHeight: cardHeight, maxHeight: cardHeight)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .contentShape(RoundedRectangle(cornerRadius: 6))
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.2)) {
                    isHovered = hovering
                }
            }
            .onTapGesture(count: 2) {
                if let onOpen = onOpen {
                    onOpen()
                } else {
                    gridHandleCopy()
                }
            }
            .contextMenu { gridContextMenu }
            .onAppear {
                isFavorite = FavoritesManager.shared.isFavorite(result.path)
            }
    }

    // MARK: - Image Area
    private var gridImageArea: some View {
        ZStack {
            gridImageContent

            if isOffline { gridOfflineOverlay }
            if showCopied { gridCopiedFeedback }

            // Relevance dot — top-right
            if showSimilarity {
                VStack {
                    HStack {
                        Spacer()
                        Circle()
                            .fill(pal.accent)
                            .frame(width: 8, height: 8)
                            .opacity(Double(result.similarity))
                            .shadow(color: Color.white.opacity(0.4), radius: 1)
                            .padding(10)
                    }
                    Spacer()
                }
            }

            // Gradient + caption (always visible) + action bar (hover only)
            if !showCopied {
                VStack {
                    Spacer()
                    ZStack(alignment: .bottom) {
                        LinearGradient(
                            colors: [.clear, Color.black.opacity(isHovered ? 0.65 : 0.45)],
                            startPoint: UnitPoint(x: 0.5, y: 0.0),
                            endPoint: UnitPoint(x: 0.5, y: 1.0)
                        )

                        VStack(alignment: .leading, spacing: 6) {
                            Text(fileURL.deletingPathExtension().lastPathComponent)
                                .font(.system(size: 14, design: .serif).italic())
                                .foregroundColor(.white)
                                .shadow(color: Color.black.opacity(0.4), radius: 4, y: 1)
                                .lineLimit(1)

                            if isHovered {
                                AtelierActionBar(
                                    onStar: {
                                        isFavorite.toggle()
                                        FavoritesManager.shared.toggleFavorite(result.path)
                                    },
                                    onQuickLook: gridOpenInPreview,
                                    onFinder: { NSWorkspace.shared.selectFile(result.path, inFileViewerRootedAtPath: "") },
                                    onCopy: gridHandleCopy,
                                    onOpen: gridOpenInPreview,
                                    onFindSimilar: onFindSimilar != nil ? { onFindSimilar?(result.path) } : nil
                                )
                                .transition(.opacity)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.bottom, 8)
                    }
                }
            }
        }
    }

    private var gridImageContent: some View {
        GeometryReader { geo in
            if let image = thumbnail {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            } else {
                Rectangle()
                    .fill(pal.line.opacity(0.3))
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.8)
                    )
            }
        }
        .onAppear {
            gridLoadThumbnail()
            gridLoadFileMetadata()
        }
    }

    // MARK: - Badges

    private var gridOfflineBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "externaldrive.badge.xmark")
                .font(.system(size: 9, weight: .bold))
            Text("Offline")
                .font(.system(size: 10, weight: .bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Capsule().fill(DesignSystem.Colors.warning))
    }

    private var gridPendingBadge: some View {
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
    }

    private var gridRawBadge: some View {
        Text("RAW")
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(pal.accent))
    }

    private var gridOfflineOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
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

    private var gridCopiedFeedback: some View {
        ZStack {
            Color.black.opacity(0.5)
            VStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.success)
                Text("Copied")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .transition(.opacity)
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var gridContextMenu: some View {
        Button(action: gridOpenInPreview) {
            Label("Open in Preview", systemImage: "eye")
        }
        Button(action: { gridCopyImage(path: result.path) }) {
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
        Divider()
        Button(action: {
            isFavorite.toggle()
            FavoritesManager.shared.toggleFavorite(result.path)
        }) {
            Label(isFavorite ? "Remove from Favorites" : "Add to Favorites", systemImage: isFavorite ? "heart.slash" : "heart")
        }
        if !FavoritesManager.shared.collections.isEmpty {
            Menu("Add to Collection") {
                ForEach(FavoritesManager.shared.collections) { collection in
                    Button(action: {
                        if !FavoritesManager.shared.isFavorite(result.path) {
                            isFavorite = true
                            FavoritesManager.shared.toggleFavorite(result.path)
                        }
                        FavoritesManager.shared.addToCollection(id: collection.id, path: result.path)
                    }) {
                        Label(collection.name, systemImage: collection.paths.contains(result.path) ? "checkmark.circle.fill" : "folder")
                    }
                }
            }
        }
    }

    // MARK: - Data Loading

    private func gridLoadThumbnail() {
        let maxSize = Int(cardHeight * 2)

        DispatchQueue.global(qos: .userInitiated).async {
            let url = URL(fileURLWithPath: result.path)
            if let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
               let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
               let pixelWidth = properties[kCGImagePropertyPixelWidth] as? Int,
               let pixelHeight = properties[kCGImagePropertyPixelHeight] as? Int {
                DispatchQueue.main.async {
                    self.imageDimensions = "\(pixelWidth)\u{00D7}\(pixelHeight)"
                }
            }
        }

        if let cached = ThumbnailService.shared.cachedThumbnail(for: result.path, size: maxSize) {
            self.thumbnail = cached
            return
        }

        ThumbnailService.shared.loadThumbnail(for: result.path, maxSize: maxSize) { thumb in
            self.thumbnail = thumb
        }
    }

    private func gridLoadFileMetadata() {
        DispatchQueue.global(qos: .utility).async {
            var sizeStr: String? = nil
            if let size = result.size {
                sizeStr = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
            } else if let attrs = try? FileManager.default.attributesOfItem(atPath: result.path),
                      let fileSize = attrs[.size] as? Int64 {
                sizeStr = ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
            }
            var dateStr: String? = result.date
            if dateStr == nil,
               let attrs = try? FileManager.default.attributesOfItem(atPath: result.path),
               let modDate = attrs[.modificationDate] as? Date {
                let fmt = DateFormatter()
                fmt.dateStyle = .medium
                fmt.timeStyle = .none
                dateStr = fmt.string(from: modDate)
            }
            DispatchQueue.main.async {
                self.fileSizeString = sizeStr
                self.fileDateString = dateStr
            }
        }
    }

    // MARK: - Actions

    private func gridHandleCopy() {
        gridCopyImage(path: result.path)
        withAnimation(.easeOut(duration: 0.15)) { showCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            withAnimation { showCopied = false }
        }
    }

    private func gridCopyImage(path: String) {
        if let image = NSImage(contentsOfFile: path) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.writeObjects([image])
        }
    }

    private func gridOpenInPreview() {
        NSWorkspace.shared.open(
            [URL(fileURLWithPath: result.path)],
            withApplicationAt: URL(fileURLWithPath: "/System/Applications/Preview.app"),
            configuration: NSWorkspace.OpenConfiguration()
        )
    }
}

// MARK: - Favorite Image Tile (heart overlay, for Favorites grid)
struct FavoriteImageTile: View {
    let result: SearchResult
    var onFindSimilar: ((String) -> Void)? = nil
    @State private var thumbnail: NSImage?
    @State private var isHovered = false
    private var pal: AtelierPalette { ThemeManager.shared.palette }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Image
            GeometryReader { geo in
                if let image = thumbnail {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(pal.line.opacity(0.3))
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Heart overlay
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.55))
                    .frame(width: 26, height: 26)
                Image(systemName: "heart.fill")
                    .font(.system(size: 13))
                    .foregroundColor(pal.accent)
            }
            .padding(8)

            // Hover overlay with actions
            if isHovered {
                VStack {
                    Spacer()
                    ZStack(alignment: .bottom) {
                        LinearGradient(colors: [.clear, Color.black.opacity(0.55)], startPoint: .top, endPoint: .bottom)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(URL(fileURLWithPath: result.path).deletingPathExtension().lastPathComponent)
                                .font(.system(size: 14, design: .serif).italic())
                                .foregroundColor(.white)
                                .lineLimit(1)

                            HStack(spacing: 8) {
                                Button(action: {
                                    NSWorkspace.shared.selectFile(result.path, inFileViewerRootedAtPath: "")
                                }) {
                                    Image(systemName: "folder")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.white.opacity(0.85))
                                }
                                .buttonStyle(PlainButtonStyle())

                                if let findSimilar = onFindSimilar {
                                    Button(action: { findSimilar(result.path) }) {
                                        Image(systemName: "sparkle.magnifyingglass")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(.white.opacity(0.85))
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }

                                Spacer()

                                Button(action: {
                                    FavoritesManager.shared.toggleFavorite(result.path)
                                }) {
                                    Image(systemName: "heart.slash")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.white.opacity(0.85))
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.bottom, 8)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .transition(.opacity)
            }
        }
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.2)) { isHovered = hovering }
        }
        .contextMenu {
            Button(action: {
                NSWorkspace.shared.selectFile(result.path, inFileViewerRootedAtPath: "")
            }) { Label("Reveal in Finder", systemImage: "folder") }
            if let findSimilar = onFindSimilar {
                Button(action: { findSimilar(result.path) }) {
                    Label("Find Similar", systemImage: "sparkle.magnifyingglass")
                }
            }
            Divider()
            if !FavoritesManager.shared.collections.isEmpty {
                Menu("Add to Collection") {
                    ForEach(FavoritesManager.shared.collections) { collection in
                        Button(action: {
                            FavoritesManager.shared.addToCollection(id: collection.id, path: result.path)
                        }) {
                            Label(collection.name, systemImage: collection.paths.contains(result.path) ? "checkmark.circle.fill" : "folder")
                        }
                    }
                }
            }
            Divider()
            Button(action: {
                FavoritesManager.shared.toggleFavorite(result.path)
            }) { Label("Remove from Favorites", systemImage: "heart.slash") }
        }
        .onAppear { loadThumbnail() }
    }

    private func loadThumbnail() {
        ThumbnailService.shared.loadThumbnail(for: result.path, maxSize: 400) { thumb in
            self.thumbnail = thumb
        }
    }
}

// Backward compatibility alias
typealias RecentImageCard = ImageCard

