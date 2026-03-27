import SwiftUI
import AppKit

// MARK: - Color Extension for Hex Support
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Theme System
enum AppTheme: String, CaseIterable {
    case electric = "Electric"
    case warm = "Warm"
    case mono = "Mono"
    case midnight = "Midnight"

    var icon: String {
        switch self {
        case .electric: return "bolt.fill"
        case .warm: return "sun.max.fill"
        case .mono: return "circle.lefthalf.filled"
        case .midnight: return "moon.stars.fill"
        }
    }

    var description: String {
        switch self {
        case .electric: return "Vibrant gradients, neon accents"
        case .warm: return "Amber tones, cozy feel"
        case .mono: return "Grayscale + one pop color"
        case .midnight: return "Dark-first, subtle glows"
        }
    }
}

// MARK: - Appearance Mode
enum AppearanceMode: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - Theme Manager
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published var currentTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: "appTheme")
        }
    }

    @Published var appearanceMode: AppearanceMode {
        didSet {
            UserDefaults.standard.set(appearanceMode.rawValue, forKey: "appearanceMode")
            applyAppearance()
        }
    }

    private init() {
        if let saved = UserDefaults.standard.string(forKey: "appTheme"),
           let theme = AppTheme(rawValue: saved) {
            self.currentTheme = theme
        } else {
            self.currentTheme = .mono  // Sharp, clean default
        }

        if let savedAppearance = UserDefaults.standard.string(forKey: "appearanceMode"),
           let mode = AppearanceMode(rawValue: savedAppearance) {
            self.appearanceMode = mode
        } else {
            self.appearanceMode = .system
        }
    }

    func applyAppearance() {
        DispatchQueue.main.async {
            switch self.appearanceMode {
            case .system:
                NSApp.appearance = nil
            case .light:
                NSApp.appearance = NSAppearance(named: .aqua)
            case .dark:
                NSApp.appearance = NSAppearance(named: .darkAqua)
            }
        }
    }
}

// MARK: - Theme Color Definitions
struct ThemeColors {
    let lightPrimary: Color      // Page background
    let lightSecondary: Color    // Cards
    let lightTertiary: Color     // Inputs

    let darkPrimary: Color       // Page background dark
    let darkSecondary: Color     // Cards dark
    let darkTertiary: Color      // Inputs dark

    let accent: Color            // Primary accent
    let accentHover: Color       // Hover state
    let accentGradientStart: Color
    let accentGradientEnd: Color

    let success: Color
    let error: Color
    let warning: Color

    // MARK: - Theme Definitions
    static let electric = ThemeColors(
        lightPrimary: Color(hex: "F8F7FF"),
        lightSecondary: Color(hex: "FFFFFF"),
        lightTertiary: Color(hex: "F0EEFF"),
        darkPrimary: Color(hex: "0A0A0F"),
        darkSecondary: Color(hex: "12121A"),
        darkTertiary: Color(hex: "1A1A25"),
        accent: Color(hex: "7C3AED"),           // Vivid purple
        accentHover: Color(hex: "8B5CF6"),
        accentGradientStart: Color(hex: "7C3AED"),
        accentGradientEnd: Color(hex: "EC4899"),  // Pink
        success: Color(hex: "10B981"),
        error: Color(hex: "EF4444"),
        warning: Color(hex: "F59E0B")
    )

    static let warm = ThemeColors(
        lightPrimary: Color(hex: "FFFBF5"),
        lightSecondary: Color(hex: "FFFFFF"),
        lightTertiary: Color(hex: "FEF3E2"),
        darkPrimary: Color(hex: "1A1612"),
        darkSecondary: Color(hex: "231F1A"),
        darkTertiary: Color(hex: "2D2820"),
        accent: Color(hex: "EA580C"),           // Warm orange
        accentHover: Color(hex: "F97316"),
        accentGradientStart: Color(hex: "EA580C"),
        accentGradientEnd: Color(hex: "FBBF24"),  // Amber
        success: Color(hex: "22C55E"),
        error: Color(hex: "DC2626"),
        warning: Color(hex: "EAB308")
    )

    static let mono = ThemeColors(
        lightPrimary: Color(hex: "FFFFFF"),     // Pure white
        lightSecondary: Color(hex: "FFFFFF"),   // Pure white
        lightTertiary: Color(hex: "F5F5F5"),    // Very light gray for inputs
        darkPrimary: Color(hex: "000000"),      // True black
        darkSecondary: Color(hex: "111111"),    // Near black for cards
        darkTertiary: Color(hex: "1A1A1A"),     // Slight lift for inputs
        accent: Color(hex: "888888"),           // Neutral gray - visible on both black and white
        accentHover: Color(hex: "999999"),
        accentGradientStart: Color(hex: "888888"),
        accentGradientEnd: Color(hex: "888888"),  // No gradient
        success: Color(hex: "22C55E"),
        error: Color(hex: "EF4444"),
        warning: Color(hex: "EAB308")
    )

    static let midnight = ThemeColors(
        lightPrimary: Color(hex: "F1F5F9"),     // Slate tint for light
        lightSecondary: Color(hex: "FFFFFF"),
        lightTertiary: Color(hex: "E2E8F0"),
        darkPrimary: Color(hex: "020617"),      // Near black
        darkSecondary: Color(hex: "0F172A"),    // Slate 900
        darkTertiary: Color(hex: "1E293B"),     // Slate 800
        accent: Color(hex: "38BDF8"),           // Sky blue glow
        accentHover: Color(hex: "7DD3FC"),
        accentGradientStart: Color(hex: "38BDF8"),
        accentGradientEnd: Color(hex: "818CF8"),  // Indigo
        success: Color(hex: "4ADE80"),
        error: Color(hex: "FB7185"),
        warning: Color(hex: "FBBF24")
    )

    static func current() -> ThemeColors {
        switch ThemeManager.shared.currentTheme {
        case .electric: return .electric
        case .warm: return .warm
        case .mono: return .mono
        case .midnight: return .midnight
        }
    }
}

// MARK: - Design System
struct DesignSystem {

    // MARK: - Colors (Theme-Aware)
    struct Colors {
        // Surface colors - pull from active theme
        static var primaryBackground: Color { ThemeColors.current().lightPrimary }
        static var secondaryBackground: Color { ThemeColors.current().lightSecondary }
        static var tertiaryBackground: Color { ThemeColors.current().lightTertiary }

        static var darkPrimaryBackground: Color { ThemeColors.current().darkPrimary }
        static var darkSecondaryBackground: Color { ThemeColors.current().darkSecondary }
        static var darkTertiaryBackground: Color { ThemeColors.current().darkTertiary }

        // Accent colors - mono theme uses adaptive label color
        static var accent: Color {
            if ThemeManager.shared.currentTheme == .mono {
                return Color(nsColor: NSColor.labelColor)  // Black in light, white in dark
            }
            return ThemeColors.current().accent
        }
        static var accentHover: Color {
            if ThemeManager.shared.currentTheme == .mono {
                return Color(nsColor: NSColor.secondaryLabelColor)
            }
            return ThemeColors.current().accentHover
        }
        static var accentSubtle: Color { accent.opacity(0.12) }
        static var accentGradientEnd: Color { ThemeColors.current().accentGradientEnd }

        // Accent gradient
        static var accentGradient: LinearGradient {
            LinearGradient(
                colors: [ThemeColors.current().accentGradientStart, ThemeColors.current().accentGradientEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        // Text colors (system adaptive)
        static let primaryText = Color(nsColor: NSColor.labelColor)
        static let secondaryText = Color(nsColor: NSColor.secondaryLabelColor)
        static let tertiaryText = Color(nsColor: NSColor.tertiaryLabelColor)

        // Semantic colors
        static var success: Color { ThemeColors.current().success }
        static var error: Color { ThemeColors.current().error }
        static var warning: Color { ThemeColors.current().warning }

        // Borders
        static let border = Color(nsColor: NSColor.separatorColor)
        static let borderHover = Color(nsColor: NSColor.separatorColor).opacity(0.8)

        // Helper functions
        static func surface(_ level: Int, for scheme: ColorScheme) -> Color {
            switch (level, scheme) {
            case (0, .light): return primaryBackground
            case (1, .light): return secondaryBackground
            case (2, .light): return tertiaryBackground
            case (0, .dark): return darkPrimaryBackground
            case (1, .dark): return darkSecondaryBackground
            case (2, .dark): return darkTertiaryBackground
            default: return scheme == .dark ? darkPrimaryBackground : primaryBackground
            }
        }
    }

    // MARK: - Typography (Friendly, using SF Rounded for headers)
    struct Typography {
        // Friendly rounded headers - warm and inviting
        static let displayLarge = Font.system(size: 32, weight: .bold, design: .rounded)
        static let displayMedium = Font.system(size: 24, weight: .semibold, design: .rounded)
        static let largeTitle = Font.system(size: 28, weight: .bold, design: .rounded)
        static let title = Font.system(size: 20, weight: .semibold, design: .rounded)
        static let title2 = Font.system(size: 17, weight: .semibold, design: .rounded)
        static let title3 = Font.system(size: 15, weight: .medium, design: .rounded)
        static let headline = Font.system(size: 15, weight: .semibold, design: .rounded)

        // Body text - default design for readability
        static let body = Font.system(size: 14, weight: .regular, design: .default)
        static let bodyMedium = Font.system(size: 14, weight: .medium, design: .default)
        static let callout = Font.system(size: 13, weight: .regular, design: .default)
        static let caption = Font.system(size: 12, weight: .regular, design: .default)
        static let captionMedium = Font.system(size: 12, weight: .medium, design: .default)
        static let caption2 = Font.system(size: 11, weight: .regular, design: .default)
        static let micro = Font.system(size: 10, weight: .medium, design: .default)

        // Monospace for stats/numbers
        static let mono = Font.system(size: 12, weight: .medium, design: .monospaced)
        static let monoSmall = Font.system(size: 10, weight: .medium, design: .monospaced)

        // Friendly labels - rounded for buttons and badges
        static let friendlyLabel = Font.system(size: 13, weight: .semibold, design: .rounded)
        static let friendlySmall = Font.system(size: 11, weight: .medium, design: .rounded)
    }

    // MARK: - Spacing
    struct Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 48
    }

    // MARK: - Corner Radius (Softer, more friendly)
    struct CornerRadius {
        static let xs: CGFloat = 6
        static let sm: CGFloat = 10
        static let md: CGFloat = 14
        static let lg: CGFloat = 18
        static let xl: CGFloat = 22
        static let xxl: CGFloat = 28
        static let card: CGFloat = 16  // Craft-style card corners
        static let full: CGFloat = 9999
    }

    // MARK: - Shadows (Soft, diffuse - like objects on a surface)
    struct Shadows {
        // Craft-style soft shadows - more diffuse, less harsh
        static func soft(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color.black.opacity(0.25) : Color.black.opacity(0.06)
        }

        static func medium(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color.black.opacity(0.35) : Color.black.opacity(0.08)
        }

        static func lifted(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color.black.opacity(0.4) : Color.black.opacity(0.12)
        }

        // Legacy compatibility
        static func small(_ colorScheme: ColorScheme) -> Color { soft(colorScheme) }
        static func large(_ colorScheme: ColorScheme) -> Color { lifted(colorScheme) }

        static func glow(_ colorScheme: ColorScheme) -> Color {
            DesignSystem.Colors.accent.opacity(colorScheme == .dark ? 0.3 : 0.2)
        }

        struct ShadowParams {
            let color: Color
            let radius: CGFloat
            let x: CGFloat
            let y: CGFloat
        }

        // Craft-style card shadow - soft, diffuse, feels like paper
        static func cardShadow(_ scheme: ColorScheme) -> ShadowParams {
            ShadowParams(
                color: scheme == .dark ? Color.black.opacity(0.3) : Color.black.opacity(0.08),
                radius: 16,
                x: 0,
                y: 6
            )
        }

        // Lifted card shadow - when hovering, feels like picking up
        static func cardLifted(_ scheme: ColorScheme) -> ShadowParams {
            ShadowParams(
                color: scheme == .dark ? Color.black.opacity(0.4) : Color.black.opacity(0.12),
                radius: 24,
                x: 0,
                y: 12
            )
        }

        static func floatingShadow(_ scheme: ColorScheme) -> ShadowParams {
            ShadowParams(color: lifted(scheme), radius: scheme == .dark ? 32 : 28, x: 0, y: scheme == .dark ? 16 : 12)
        }
    }

    // MARK: - Animation
    struct Animation {
        static let springQuick = SwiftUI.Animation.spring(response: 0.25, dampingFraction: 0.8)
        static let springMedium = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.75)
        static let springBouncy = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.65)
        static let easeOut = SwiftUI.Animation.easeOut(duration: 0.2)
    }
}

// MARK: - Theme Switcher View
struct ThemeSwitcher: View {
    @ObservedObject var themeManager = ThemeManager.shared
    @State private var isExpanded = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            if isExpanded {
                ForEach(AppTheme.allCases, id: \.self) { theme in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            themeManager.currentTheme = theme
                            isExpanded = false
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: theme.icon)
                                .font(.system(size: 12, weight: .medium))
                            if theme == themeManager.currentTheme {
                                Text(theme.rawValue)
                                    .font(DesignSystem.Typography.caption)
                            }
                        }
                        .foregroundColor(theme == themeManager.currentTheme ? .white : DesignSystem.Colors.secondaryText)
                        .padding(.horizontal, theme == themeManager.currentTheme ? 10 : 8)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(theme == themeManager.currentTheme ? DesignSystem.Colors.accent : Color.clear)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            } else {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isExpanded = true
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: themeManager.currentTheme.icon)
                            .font(.system(size: 12, weight: .medium))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .foregroundColor(DesignSystem.Colors.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(DesignSystem.Colors.accentSubtle)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(DesignSystem.Spacing.xs)
        .background(
            Capsule()
                .fill(colorScheme == .dark ? DesignSystem.Colors.darkTertiaryBackground : DesignSystem.Colors.tertiaryBackground)
        )
        .onTapGesture {} // Capture taps
        .onHover { _ in } // Keep expanded on hover
    }
}

// MARK: - Minimal Icon Button
struct MinimalIconButton: View {
    let icon: String
    let tooltip: String
    let action: () -> Void

    @State private var isHovered = false
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.isEnabled) var isEnabled

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isEnabled ? (isHovered ? DesignSystem.Colors.primaryText : DesignSystem.Colors.secondaryText) : DesignSystem.Colors.tertiaryText)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isHovered ? (colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)) : Color.clear)
                )
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .help(tooltip)
    }
}

// MARK: - Theme Switcher Compact
struct ThemeSwitcherCompact: View {
    @ObservedObject var themeManager = ThemeManager.shared
    @State private var isHovered = false
    @State private var showPicker = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: {
            showPicker.toggle()
        }) {
            Image(systemName: themeManager.currentTheme.icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isHovered ? DesignSystem.Colors.accent : DesignSystem.Colors.secondaryText)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isHovered ? DesignSystem.Colors.accent.opacity(0.1) : Color.clear)
                )
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .popover(isPresented: $showPicker, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
                // Appearance Mode Section
                VStack(alignment: .leading, spacing: 4) {
                    Text("APPEARANCE")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                        .padding(.horizontal, 12)
                        .padding(.top, 8)

                    HStack(spacing: 4) {
                        ForEach(AppearanceMode.allCases, id: \.self) { mode in
                            Button(action: {
                                withAnimation {
                                    themeManager.appearanceMode = mode
                                }
                            }) {
                                VStack(spacing: 4) {
                                    Image(systemName: mode.icon)
                                        .font(.system(size: 14))
                                    Text(mode.rawValue)
                                        .font(.system(size: 10))
                                }
                                .foregroundColor(mode == themeManager.appearanceMode ? DesignSystem.Colors.accent : DesignSystem.Colors.secondaryText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(mode == themeManager.appearanceMode ? DesignSystem.Colors.accent.opacity(0.1) : Color.clear)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 8)
                }

                Divider()
                    .padding(.vertical, 8)

                // Theme Section
                VStack(alignment: .leading, spacing: 4) {
                    Text("THEME")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                        .padding(.horizontal, 12)

                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Button(action: {
                            withAnimation {
                                themeManager.currentTheme = theme
                            }
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: theme.icon)
                                    .font(.system(size: 14))
                                    .foregroundColor(theme == themeManager.currentTheme ? DesignSystem.Colors.accent : DesignSystem.Colors.secondaryText)
                                    .frame(width: 20)

                                Text(theme.rawValue)
                                    .font(.system(size: 13, weight: theme == themeManager.currentTheme ? .medium : .regular))
                                    .foregroundColor(DesignSystem.Colors.primaryText)

                                Spacer()

                                if theme == themeManager.currentTheme {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(DesignSystem.Colors.accent)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(theme == themeManager.currentTheme ? DesignSystem.Colors.accent.opacity(0.1) : Color.clear)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.bottom, 8)
            }
            .frame(width: 200)
        }
        .help("Change theme")
        .onAppear {
            themeManager.applyAppearance()
        }
    }
}
