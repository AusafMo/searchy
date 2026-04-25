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

// MARK: - Atelier Palette
struct AtelierPalette {
    let name: String
    let note: String
    let accent: Color
    let accent2: Color
    let paper: Color       // Main background
    let sidebar: Color     // Sidebar background
    let card: Color        // Card / elevated surface
    let ink: Color         // Primary text
    let ink2: Color        // Secondary text
    let ink3: Color        // Tertiary text
    let line: Color        // Borders / dividers
    let halo: Color        // Accent glow / focus ring

    // Whether this palette is dark-mode
    var isDark: Bool {
        switch ThemeManager.shared.currentTheme {
        case .noir, .onyx: return true
        default: return false
        }
    }
}

// MARK: - Theme System
enum AppTheme: String, CaseIterable {
    case terracotta = "Terracotta"
    case sage = "Sage"
    case ink = "Ink & Ochre"
    case bordeaux = "Bordeaux"
    case cobalt = "Cobalt"
    case noir = "Noir"
    case onyx = "Onyx"

    var icon: String {
        switch self {
        case .terracotta: return "sun.max.fill"
        case .sage: return "leaf.fill"
        case .ink: return "pencil.line"
        case .bordeaux: return "book.fill"
        case .cobalt: return "drop.fill"
        case .noir: return "moon.stars.fill"
        case .onyx: return "circle.fill"
        }
    }

    var description: String {
        switch self {
        case .terracotta: return "Warm orange on bone paper"
        case .sage: return "Botanical green, oat paper"
        case .ink: return "Editorial near-black with mustard"
        case .bordeaux: return "Deep wine on cream"
        case .cobalt: return "Deep blue against linen"
        case .noir: return "Inverted dark, serif in charge"
        case .onyx: return "True black, one green ember"
        }
    }

    var palette: AtelierPalette {
        switch self {
        case .terracotta: return .terracotta
        case .sage: return .sage
        case .ink: return .ink
        case .bordeaux: return .bordeaux
        case .cobalt: return .cobalt
        case .noir: return .noir
        case .onyx: return .onyx
        }
    }

    var isDark: Bool {
        switch self {
        case .noir, .onyx: return true
        default: return false
        }
    }
}

// MARK: - Atelier Palette Definitions
extension AtelierPalette {
    static let terracotta = AtelierPalette(
        name: "Terracotta",
        note: "Warm orange on bone paper. The original calm.",
        accent: Color(hex: "C2410C"),
        accent2: Color(hex: "F59E0B"),
        paper: Color(hex: "FAF7F1"),
        sidebar: Color(hex: "F4EFE6"),
        card: Color(hex: "FFFFFF"),
        ink: Color(hex: "1A1814"),
        ink2: Color(hex: "6B6760"),
        ink3: Color(hex: "A39E94"),
        line: Color(hex: "1A1814").opacity(0.08),
        halo: Color(hex: "C2410C").opacity(0.07)
    )

    static let sage = AtelierPalette(
        name: "Sage",
        note: "Botanical green, oat paper. Slow, considered.",
        accent: Color(hex: "3F6B49"),
        accent2: Color(hex: "A7B89C"),
        paper: Color(hex: "F5F2E8"),
        sidebar: Color(hex: "EBE7DA"),
        card: Color(hex: "FBFAF5"),
        ink: Color(hex: "1F2620"),
        ink2: Color(hex: "5C6359"),
        ink3: Color(hex: "9AA095"),
        line: Color(hex: "1F2620").opacity(0.08),
        halo: Color(hex: "3F6B49").opacity(0.07)
    )

    static let ink = AtelierPalette(
        name: "Ink & Ochre",
        note: "Editorial near-black with one pop of mustard.",
        accent: Color(hex: "B8860B"),
        accent2: Color(hex: "1F1B16"),
        paper: Color(hex: "F2EFE7"),
        sidebar: Color(hex: "E8E4D9"),
        card: Color(hex: "FBFAF5"),
        ink: Color(hex: "15110D"),
        ink2: Color(hex: "54504A"),
        ink3: Color(hex: "8E8A82"),
        line: Color(hex: "15110D").opacity(0.10),
        halo: Color(hex: "B8860B").opacity(0.10)
    )

    static let bordeaux = AtelierPalette(
        name: "Bordeaux",
        note: "Deep wine on cream. Library / monograph energy.",
        accent: Color(hex: "7E1D1F"),
        accent2: Color(hex: "D49A56"),
        paper: Color(hex: "FBF6EC"),
        sidebar: Color(hex: "F2EBDB"),
        card: Color(hex: "FFFCF5"),
        ink: Color(hex: "1B100E"),
        ink2: Color(hex: "6B5651"),
        ink3: Color(hex: "A89A92"),
        line: Color(hex: "1B100E").opacity(0.08),
        halo: Color(hex: "7E1D1F").opacity(0.07)
    )

    static let cobalt = AtelierPalette(
        name: "Cobalt",
        note: "A single deep blue against linen. Quiet, technical.",
        accent: Color(hex: "1E3A8A"),
        accent2: Color(hex: "60A5FA"),
        paper: Color(hex: "F4F2EC"),
        sidebar: Color(hex: "E9E6DC"),
        card: Color(hex: "FBFAF5"),
        ink: Color(hex: "0F1530"),
        ink2: Color(hex: "4F5673"),
        ink3: Color(hex: "8E94A6"),
        line: Color(hex: "0F1530").opacity(0.08),
        halo: Color(hex: "1E3A8A").opacity(0.08)
    )

    static let noir = AtelierPalette(
        name: "Noir",
        note: "Atelier inverted. Dark mode, serif still in charge.",
        accent: Color(hex: "E0B05A"),
        accent2: Color(hex: "D9CFC0"),
        paper: Color(hex: "161310"),
        sidebar: Color(hex: "0F0D0B"),
        card: Color(hex: "1F1B17"),
        ink: Color(hex: "F2EBDD"),
        ink2: Color(hex: "A8A095"),
        ink3: Color(hex: "6B665C"),
        line: Color(hex: "FFF7E8").opacity(0.08),
        halo: Color(hex: "E0B05A").opacity(0.10)
    )

    static let onyx = AtelierPalette(
        name: "Onyx",
        note: "True black. The serif holds the room. One green ember.",
        accent: Color(hex: "7BC97D"),
        accent2: Color(hex: "E8E4D9"),
        paper: Color(hex: "000000"),
        sidebar: Color(hex: "070706"),
        card: Color(hex: "0E0E0C"),
        ink: Color(hex: "F5F1E8"),
        ink2: Color(hex: "9C988E"),
        ink3: Color(hex: "5A574F"),
        line: Color(hex: "F5F1E8").opacity(0.07),
        halo: Color(hex: "7BC97D").opacity(0.10)
    )
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
            applyAppearance()
        }
    }

    @Published var appearanceMode: AppearanceMode {
        didSet {
            UserDefaults.standard.set(appearanceMode.rawValue, forKey: "appearanceMode")
            applyAppearance()
        }
    }

    var palette: AtelierPalette {
        currentTheme.palette
    }

    private init() {
        if let saved = UserDefaults.standard.string(forKey: "appTheme"),
           let theme = AppTheme(rawValue: saved) {
            self.currentTheme = theme
        } else {
            self.currentTheme = .sage
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
            // Dark palettes force dark appearance, light palettes force light
            if self.currentTheme.isDark {
                NSApp.appearance = NSAppearance(named: .darkAqua)
            } else {
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
}

// MARK: - Legacy ThemeColors (backward compatibility)
struct ThemeColors {
    let lightPrimary: Color
    let lightSecondary: Color
    let lightTertiary: Color
    let darkPrimary: Color
    let darkSecondary: Color
    let darkTertiary: Color
    let accent: Color
    let accentHover: Color
    let accentGradientStart: Color
    let accentGradientEnd: Color
    let success: Color
    let error: Color
    let warning: Color

    static func current() -> ThemeColors {
        let p = ThemeManager.shared.palette
        return ThemeColors(
            lightPrimary: p.paper,
            lightSecondary: p.card,
            lightTertiary: p.sidebar,
            darkPrimary: p.paper,
            darkSecondary: p.card,
            darkTertiary: p.sidebar,
            accent: p.accent,
            accentHover: p.accent.opacity(0.85),
            accentGradientStart: p.accent,
            accentGradientEnd: p.accent2,
            success: Color(hex: "22C55E"),
            error: Color(hex: "EF4444"),
            warning: Color(hex: "F59E0B")
        )
    }
}

// MARK: - Design System
struct DesignSystem {

    // MARK: - Colors (Palette-Aware)
    struct Colors {
        static var palette: AtelierPalette { ThemeManager.shared.palette }

        // Surface colors
        static var primaryBackground: Color { palette.paper }
        static var secondaryBackground: Color { palette.card }
        static var tertiaryBackground: Color { palette.sidebar }

        static var darkPrimaryBackground: Color { palette.paper }
        static var darkSecondaryBackground: Color { palette.card }
        static var darkTertiaryBackground: Color { palette.sidebar }

        // Accent colors
        static var accent: Color { palette.accent }
        static var accentHover: Color { palette.accent.opacity(0.85) }
        static var accentSubtle: Color { palette.halo }
        static var accentGradientEnd: Color { palette.accent2 }

        static var accentGradient: LinearGradient {
            LinearGradient(
                colors: [palette.accent, palette.accent2],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        // Text colors - use palette ink colors
        static var primaryText: Color { palette.ink }
        static var secondaryText: Color { palette.ink2 }
        static var tertiaryText: Color { palette.ink3 }

        // Semantic colors
        static var success: Color { Color(hex: "22C55E") }
        static var error: Color { Color(hex: "EF4444") }
        static var warning: Color { Color(hex: "F59E0B") }

        // Borders
        static var border: Color { palette.line }
        static var borderHover: Color { palette.line.opacity(0.8) }

        static func surface(_ level: Int, for scheme: ColorScheme) -> Color {
            switch level {
            case 0: return palette.paper
            case 1: return palette.card
            case 2: return palette.sidebar
            default: return palette.paper
            }
        }
    }

    // MARK: - Typography (Atelier: serif headlines, system body, mono stats)
    struct Typography {
        // Editorial serif headlines - New York (system serif) for Instrument Serif feel
        static let displayLarge = Font.system(size: 44, weight: .regular, design: .serif)
        static let displayMedium = Font.system(size: 32, weight: .regular, design: .serif)
        static let largeTitle = Font.system(size: 38, weight: .regular, design: .serif)
        static let title = Font.system(size: 22, weight: .regular, design: .serif)
        static let title2 = Font.system(size: 19, weight: .regular, design: .serif)
        static let title3 = Font.system(size: 17, weight: .regular, design: .serif)
        static let headline = Font.system(size: 15, weight: .medium, design: .default)

        // Body text
        static let body = Font.system(size: 13, weight: .regular, design: .default)
        static let bodyMedium = Font.system(size: 13, weight: .medium, design: .default)
        static let callout = Font.system(size: 13, weight: .regular, design: .default)
        static let caption = Font.system(size: 12, weight: .regular, design: .default)
        static let captionMedium = Font.system(size: 12, weight: .medium, design: .default)
        static let caption2 = Font.system(size: 11, weight: .regular, design: .default)
        static let micro = Font.system(size: 10, weight: .medium, design: .default)

        // Monospace for stats/numbers
        static let mono = Font.system(size: 11, weight: .medium, design: .monospaced)
        static let monoSmall = Font.system(size: 10, weight: .medium, design: .monospaced)

        // Section headers (uppercase, tracked)
        static let sectionHeader = Font.system(size: 10, weight: .semibold, design: .default)

        // Friendly labels
        static let friendlyLabel = Font.system(size: 13, weight: .semibold, design: .default)
        static let friendlySmall = Font.system(size: 11, weight: .medium, design: .default)
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

    // MARK: - Corner Radius
    struct CornerRadius {
        static let xs: CGFloat = 6
        static let sm: CGFloat = 10
        static let md: CGFloat = 14
        static let lg: CGFloat = 18
        static let xl: CGFloat = 22
        static let xxl: CGFloat = 28
        static let card: CGFloat = 14
        static let full: CGFloat = 9999
    }

    // MARK: - Shadows (Soft, paper-like)
    struct Shadows {
        static func soft(_ colorScheme: ColorScheme) -> Color {
            Color.black.opacity(0.06)
        }

        static func medium(_ colorScheme: ColorScheme) -> Color {
            Color.black.opacity(0.08)
        }

        static func lifted(_ colorScheme: ColorScheme) -> Color {
            Color.black.opacity(0.12)
        }

        static func small(_ colorScheme: ColorScheme) -> Color { soft(colorScheme) }
        static func large(_ colorScheme: ColorScheme) -> Color { lifted(colorScheme) }

        static func glow(_ colorScheme: ColorScheme) -> Color {
            DesignSystem.Colors.accent.opacity(0.2)
        }

        struct ShadowParams {
            let color: Color
            let radius: CGFloat
            let x: CGFloat
            let y: CGFloat
        }

        static func cardShadow(_ scheme: ColorScheme) -> ShadowParams {
            ShadowParams(
                color: Color.black.opacity(0.08),
                radius: 14,
                x: 0,
                y: 4
            )
        }

        static func cardLifted(_ scheme: ColorScheme) -> ShadowParams {
            ShadowParams(
                color: Color.black.opacity(0.12),
                radius: 24,
                x: 0,
                y: 12
            )
        }

        static func floatingShadow(_ scheme: ColorScheme) -> ShadowParams {
            ShadowParams(color: lifted(scheme), radius: 28, x: 0, y: 12)
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
                .fill(DesignSystem.Colors.tertiaryBackground)
        )
        .onTapGesture {}
        .onHover { _ in }
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
                        .fill(isHovered ? DesignSystem.Colors.palette.line : Color.clear)
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
                // Appearance Mode Section (only for light palettes)
                if !themeManager.currentTheme.isDark {
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
                }

                // Palette Section
                VStack(alignment: .leading, spacing: 4) {
                    Text("PALETTE")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                        .padding(.horizontal, 12)
                        .padding(.top, themeManager.currentTheme.isDark ? 8 : 0)

                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Button(action: {
                            withAnimation {
                                themeManager.currentTheme = theme
                            }
                        }) {
                            HStack(spacing: 10) {
                                // Accent color swatch
                                Circle()
                                    .fill(theme.palette.accent)
                                    .frame(width: 14, height: 14)
                                    .overlay(
                                        Circle()
                                            .stroke(theme.palette.ink.opacity(0.15), lineWidth: 0.5)
                                    )

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
            .frame(width: 220)
        }
        .help("Change palette")
        .onAppear {
            themeManager.applyAppearance()
        }
    }
}
