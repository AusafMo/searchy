import SwiftUI
import AppKit

// MARK: - Loading Skeleton Components
struct SkeletonView: View {
    @State private var isAnimating = false
    @Environment(\.colorScheme) var colorScheme
    private var pal: AtelierPalette { ThemeManager.shared.palette }

    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(
                LinearGradient(
                    colors: [
                        pal.line.opacity(0.3),
                        pal.line.opacity(0.5),
                        pal.line.opacity(0.3)
                    ],
                    startPoint: isAnimating ? .leading : .trailing,
                    endPoint: isAnimating ? .trailing : .leading
                )
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
    }
}

struct ResultCardSkeleton: View {
    @Environment(\.colorScheme) var colorScheme
    private var pal: AtelierPalette { ThemeManager.shared.palette }

    var body: some View {
        VStack(spacing: 0) {
            // Image skeleton - matches ImageCard imageHeight
            SkeletonView()
                .frame(height: 156)

            // Filename skeleton - matches ImageCard filenameSection
            SkeletonView()
                .frame(height: 14)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
        }
        .frame(height: 200)
        .background(pal.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.08),
            radius: 6,
            x: 0,
            y: 3
        )
    }
}

// MARK: - Stat Item Component
struct StatItem: View {
    let icon: String
    let label: String
    let value: String
    @Environment(\.colorScheme) var colorScheme
    private var pal: AtelierPalette { ThemeManager.shared.palette }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(pal.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 11))
                    .foregroundColor(pal.ink3)
                Text(value)
                    .font(.system(size: 13).weight(.semibold))
                    .foregroundColor(pal.ink)
            }
        }
    }
}

// MARK: - Example Query Chip
struct ExampleQueryChip: View {
    let text: String
    @State private var isHovered = false
    @Environment(\.colorScheme) var colorScheme
    private var pal: AtelierPalette { ThemeManager.shared.palette }

    var body: some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundColor(isHovered ? .white : pal.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(isHovered ? pal.accent : pal.accent.opacity(0.1))
            )
            .overlay(
                Capsule()
                    .stroke(pal.accent.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(isHovered ? 1.05 : 1.0)
            .onHover { hovering in
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    isHovered = hovering
                }
            }
    }
}

// MARK: - Filter Capsule
struct FilterCapsule: View {
    let label: String
    let isActive: Bool
    let action: () -> Void

    @State private var isHovered = false
    @Environment(\.colorScheme) var colorScheme
    private var pal: AtelierPalette { ThemeManager.shared.palette }

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: isActive ? .semibold : .regular))
                .foregroundColor(isActive ? pal.accent : pal.ink3)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(isActive ?
                            pal.accent.opacity(0.12) :
                            (colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.04))
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isHovered ? 1.03 : 1.0)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Action Button Component
struct ActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                    isPressed = false
                }
            }
            action()
        }) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                Text(title)
                    .font(.system(size: 11).weight(.medium))
            }
            .foregroundColor(isHovered ? color : color.opacity(0.8))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(color.opacity(isHovered ? 0.15 : 0.1))
            )
            .scaleEffect(isPressed ? 0.92 : (isHovered ? 1.05 : 1.0))
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                isHovered = hovering
            }
        }
    }
}

struct KeyboardHint: View {
    let key: String
    let description: String
    @Environment(\.colorScheme) var colorScheme
    private var pal: AtelierPalette { ThemeManager.shared.palette }

    var body: some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 11).weight(.semibold))
                .foregroundColor(pal.ink)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(pal.sidebar)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(pal.line, lineWidth: 1)
                )

            Text(description)
                .font(.system(size: 11))
                .foregroundColor(pal.ink3)
        }
    }
}

struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active
        return visualEffectView
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Modern Button Component
struct ModernButton: View {
    enum ButtonStyle {
        case primary, secondary, tertiary
    }

    let icon: String
    let title: String?
    let style: ButtonStyle
    let isDisabled: Bool
    let action: () -> Void

    @State private var isHovered = false
    @Environment(\.colorScheme) var colorScheme
    private var pal: AtelierPalette { ThemeManager.shared.palette }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: title == nil ? 16 : 14, weight: .medium))

                if let title = title {
                    Text(title)
                        .font(.system(size: 13).weight(.medium))
                }
            }
            .foregroundColor(foregroundColor)
            .padding(.horizontal, title == nil ? 8 : 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(borderColor, lineWidth: 1)
            )
            .scaleEffect(isHovered && !isDisabled ? 1.02 : 1.0)
            .shadow(color: isHovered && !isDisabled ? Color.black.opacity(0.06) : .clear,
                   radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled)
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovered = hovering
            }
        }
        .opacity(isDisabled ? 0.5 : 1.0)
    }

    private var backgroundColor: Color {
        switch style {
        case .primary:
            return pal.accent
        case .secondary:
            return pal.sidebar
        case .tertiary:
            return (pal.card).opacity(isHovered ? 1.0 : 0.5)
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary:
            return .white
        case .secondary, .tertiary:
            return pal.ink
        }
    }

    private var borderColor: Color {
        if isHovered {
            return pal.line.opacity(0.8)
        }
        return style == .tertiary ? pal.line : .clear
    }
}

struct CopyNotification: View {
    @Binding var isShowing: Bool
    var filename: String = ""
    var fileSize: String = ""
    @Environment(\.colorScheme) var colorScheme
    private var pal: AtelierPalette { ThemeManager.shared.palette }

    private let toastBackground = Color(red: 0x1A/255, green: 0x18/255, blue: 0x14/255)
    private let toastText = Color(red: 0xF5/255, green: 0xF4/255, blue: 0xEE/255)

    var body: some View {
        HStack(spacing: 12) {
            // Accent circle with checkmark
            ZStack {
                Circle()
                    .fill(pal.accent)
                    .frame(width: 26, height: 26)
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }

            // Middle column: title + filename
            VStack(alignment: .leading, spacing: 2) {
                Text("Copied to clipboard")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(toastText)

                if !filename.isEmpty {
                    let detail = fileSize.isEmpty ? filename : "\(filename) \u{00B7} \(fileSize)"
                    Text(detail)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(toastText.opacity(0.55))
                        .lineLimit(1)
                }
            }

            // Right: ⌘V to paste key hint
            Text("⌘V to paste")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(toastText.opacity(0.55))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(toastText.opacity(0.18), lineWidth: 1)
                )
                .padding(.leading, 8)
        }
        .padding(.leading, 16)
        .padding(.trailing, 20)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(toastBackground)
                .shadow(color: Color(red: 20/255, green: 18/255, blue: 15/255).opacity(0.5), radius: 20, x: 0, y: 18)
        )
        .offset(y: isShowing ? 0 : 20)
        .opacity(isShowing ? 1 : 0)
        .scaleEffect(isShowing ? 1 : 0.9)
        .animation(
            .spring(response: 0.35, dampingFraction: 0.75),
            value: isShowing
        )
    }
}

struct DoubleClickImageView: View {
    let filePath: String
    let onDoubleClick: () -> Void
    @State private var image: NSImage?
    @StateObject private var prefs = SearchPreferences.shared
    private var pal: AtelierPalette { ThemeManager.shared.palette }

    var body: some View {
        Group {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(pal.line.opacity(0.3))
            }
        }
        .onTapGesture(count: 2) {
            onDoubleClick()
        }
        .onAppear {
            loadImage()
        }
    }

    private func loadImage() {
        let maxSize = Int(prefs.imageSize) * 2  // 2x for retina

        // Check cache first
        if let cached = ThumbnailService.shared.cachedThumbnail(for: filePath, size: maxSize) {
            self.image = cached
            return
        }

        // Load efficiently using ThumbnailService
        ThumbnailService.shared.loadThumbnail(for: filePath, maxSize: maxSize) { thumbnail in
            self.image = thumbnail
        }
    }
}

// MARK: - Async Thumbnail View
/// Efficiently loads thumbnails using CGImageSource (reads minimal bytes from file)
struct AsyncThumbnailView: View {
    let path: String
    var maxSize: Int = 200
    var contentMode: ContentMode = .fill
    @State private var image: NSImage?
    private var pal: AtelierPalette { ThemeManager.shared.palette }

    var body: some View {
        Group {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Rectangle()
                    .fill(pal.line.opacity(0.3))
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.7)
                    )
            }
        }
        .onAppear {
            loadThumbnail()
        }
    }

    private func loadThumbnail() {
        // Check cache first
        if let cached = ThumbnailService.shared.cachedThumbnail(for: path, size: maxSize) {
            self.image = cached
            return
        }

        // Load efficiently using ThumbnailService
        ThumbnailService.shared.loadThumbnail(for: path, maxSize: maxSize) { thumbnail in
            self.image = thumbnail
        }
    }
}


