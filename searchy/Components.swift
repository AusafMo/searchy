import SwiftUI
import AppKit

// MARK: - Loading Skeleton Components
struct SkeletonView: View {
    @State private var isAnimating = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
            .fill(
                LinearGradient(
                    colors: colorScheme == .dark ? [
                        Color.white.opacity(0.05),
                        Color.white.opacity(0.1),
                        Color.white.opacity(0.05)
                    ] : [
                        Color.gray.opacity(0.2),
                        Color.gray.opacity(0.3),
                        Color.gray.opacity(0.2)
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
        .background(colorScheme == .dark ? Color(hex: "2C2C2E") : Color(hex: "FEF7EE"))
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

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(DesignSystem.Colors.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(DesignSystem.Typography.caption2)
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
                Text(value)
                    .font(DesignSystem.Typography.callout.weight(.semibold))
                    .foregroundColor(DesignSystem.Colors.primaryText)
            }
        }
    }
}

// MARK: - Example Query Chip
struct ExampleQueryChip: View {
    let text: String
    @State private var isHovered = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Text(text)
            .font(DesignSystem.Typography.caption)
            .foregroundColor(isHovered ? .white : DesignSystem.Colors.accent)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .background(
                Capsule()
                    .fill(isHovered ? DesignSystem.Colors.accent : DesignSystem.Colors.accent.opacity(0.1))
            )
            .overlay(
                Capsule()
                    .stroke(DesignSystem.Colors.accent.opacity(0.3), lineWidth: 1)
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

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: isActive ? .semibold : .regular))
                .foregroundColor(isActive ? DesignSystem.Colors.accent : DesignSystem.Colors.tertiaryText)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(isActive ?
                            DesignSystem.Colors.accent.opacity(0.12) :
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
                    .font(DesignSystem.Typography.caption2.weight(.medium))
            }
            .foregroundColor(isHovered ? color : color.opacity(0.8))
            .padding(.horizontal, DesignSystem.Spacing.sm)
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

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Text(key)
                .font(DesignSystem.Typography.caption2.weight(.semibold))
                .foregroundColor(DesignSystem.Colors.primaryText)
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(colorScheme == .dark ?
                            DesignSystem.Colors.darkTertiaryBackground :
                            DesignSystem.Colors.tertiaryBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(DesignSystem.Colors.border, lineWidth: 1)
                )

            Text(description)
                .font(DesignSystem.Typography.caption2)
                .foregroundColor(DesignSystem.Colors.tertiaryText)
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

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: title == nil ? 16 : 14, weight: .medium))

                if let title = title {
                    Text(title)
                        .font(DesignSystem.Typography.callout.weight(.medium))
                }
            }
            .foregroundColor(foregroundColor)
            .padding(.horizontal, title == nil ? DesignSystem.Spacing.sm : DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .stroke(borderColor, lineWidth: 1)
            )
            .scaleEffect(isHovered && !isDisabled ? 1.02 : 1.0)
            .shadow(color: isHovered && !isDisabled ? DesignSystem.Shadows.small(colorScheme) : .clear,
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
            return DesignSystem.Colors.accent
        case .secondary:
            return colorScheme == .dark ?
                DesignSystem.Colors.darkTertiaryBackground :
                DesignSystem.Colors.tertiaryBackground
        case .tertiary:
            return (colorScheme == .dark ?
                DesignSystem.Colors.darkSecondaryBackground :
                DesignSystem.Colors.secondaryBackground).opacity(isHovered ? 1.0 : 0.5)
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary:
            return .white
        case .secondary, .tertiary:
            return DesignSystem.Colors.primaryText
        }
    }

    private var borderColor: Color {
        if isHovered {
            return DesignSystem.Colors.borderHover
        }
        return style == .tertiary ? DesignSystem.Colors.border : .clear
    }
}

struct CopyNotification: View {
    @Binding var isShowing: Bool
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(DesignSystem.Colors.success)
                .font(.system(size: 14, weight: .semibold))

            Text("Copied!")
                .font(DesignSystem.Typography.callout.weight(.semibold))
                .foregroundColor(DesignSystem.Colors.primaryText)
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.vertical, DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(colorScheme == .dark ?
                    DesignSystem.Colors.darkSecondaryBackground :
                    DesignSystem.Colors.secondaryBackground)
                .shadow(color: DesignSystem.Shadows.medium(colorScheme), radius: 12, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .stroke(DesignSystem.Colors.success.opacity(0.3), lineWidth: 1.5)
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

    var body: some View {
        Group {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
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

    var body: some View {
        Group {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
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


