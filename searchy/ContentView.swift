import SwiftUI
import AppKit
import Foundation
import UniformTypeIdentifiers
import Vision

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

struct Constants {
    static var baseDirectory: String {
        SetupManager.shared.appSupportPath
    }
    static let defaultPort: Int = 7860
    static var pythonExecutablePath: String {
        SetupManager.shared.venvPythonPath
    }
    static var serverScriptPath: String {
        Bundle.main.path(forResource: "server", ofType: "py") ?? ""
    }
    static var embeddingScriptPath: String {
        Bundle.main.path(forResource: "generate_embeddings", ofType: "py") ?? ""
    }
}

class AppConfig: ObservableObject {
    static let shared = AppConfig()

    @Published var baseDirectory: String {
        didSet {
            UserDefaults.standard.set(baseDirectory, forKey: "baseDirectory")
        }
    }

    @Published var defaultPort: Int {
        didSet {
            UserDefaults.standard.set(defaultPort, forKey: "defaultPort")
        }
    }

    // Script paths should ALWAYS come from Bundle.main, never cached
    var pythonExecutablePath: String {
        Constants.pythonExecutablePath
    }

    var serverScriptPath: String {
        Constants.serverScriptPath
    }

    var embeddingScriptPath: String {
        Constants.embeddingScriptPath
    }

    private init() {
        // Load from UserDefaults with fallbacks to current constants
        self.baseDirectory = UserDefaults.standard.string(forKey: "baseDirectory") ?? Constants.baseDirectory
        self.defaultPort = UserDefaults.standard.integer(forKey: "defaultPort") != 0 ?
            UserDefaults.standard.integer(forKey: "defaultPort") : Constants.defaultPort

        // Clear any old cached paths (migration)
        UserDefaults.standard.removeObject(forKey: "pythonExecutablePath")
        UserDefaults.standard.removeObject(forKey: "serverScriptPath")
        UserDefaults.standard.removeObject(forKey: "embeddingScriptPath")
    }

    func resetToDefaults() {
        baseDirectory = Constants.baseDirectory
        defaultPort = Constants.defaultPort
    }
}

class SearchPreferences: ObservableObject {
    static let shared = SearchPreferences()

    @Published var numberOfResults: Int {
        didSet { UserDefaults.standard.set(numberOfResults, forKey: "numberOfResults") }
    }

    @Published var gridColumns: Int {
        didSet { UserDefaults.standard.set(gridColumns, forKey: "gridColumns") }
    }

    @Published var showStats: Bool {
        didSet { UserDefaults.standard.set(showStats, forKey: "showStats") }
    }

    @Published var imageSize: Float {
        didSet { UserDefaults.standard.set(imageSize, forKey: "imageSize") }
    }

    @Published var similarityThreshold: Float {
        didSet { UserDefaults.standard.set(similarityThreshold, forKey: "similarityThreshold") }
    }

    private init() {
        self.numberOfResults = UserDefaults.standard.integer(forKey: "numberOfResults") != 0 ?
            UserDefaults.standard.integer(forKey: "numberOfResults") : 20
        self.gridColumns = UserDefaults.standard.integer(forKey: "gridColumns") != 0 ?
            UserDefaults.standard.integer(forKey: "gridColumns") : 4
        self.showStats = UserDefaults.standard.bool(forKey: "showStats") != false
        self.imageSize = UserDefaults.standard.float(forKey: "imageSize") != 0 ?
            UserDefaults.standard.float(forKey: "imageSize") : 250
        self.similarityThreshold = UserDefaults.standard.float(forKey: "similarityThreshold") != 0 ?
            UserDefaults.standard.float(forKey: "similarityThreshold") : 0.5
    }
}

// MARK: - Indexing Settings
class IndexingSettings: ObservableObject {
    static let shared = IndexingSettings()

    @Published var enableFastIndexing: Bool {
        didSet { UserDefaults.standard.set(enableFastIndexing, forKey: "enableFastIndexing") }
    }

    @Published var maxDimension: Int {
        didSet { UserDefaults.standard.set(maxDimension, forKey: "maxDimension") }
    }

    @Published var batchSize: Int {
        didSet { UserDefaults.standard.set(batchSize, forKey: "batchSize") }
    }

    private init() {
        self.enableFastIndexing = UserDefaults.standard.object(forKey: "enableFastIndexing") as? Bool ?? true
        self.maxDimension = UserDefaults.standard.integer(forKey: "maxDimension") != 0 ?
            UserDefaults.standard.integer(forKey: "maxDimension") : 384
        self.batchSize = UserDefaults.standard.integer(forKey: "batchSize") != 0 ?
            UserDefaults.standard.integer(forKey: "batchSize") : 64
    }
}

// MARK: - Model Settings (AI Model Configuration)
struct CLIPModelInfo: Identifiable {
    let id: String  // model_name from HuggingFace
    let name: String
    let description: String
    let embeddingDim: Int
    let sizeMB: Int
}

class ModelSettings: ObservableObject {
    static let shared = ModelSettings()

    @Published var currentModelName: String = ""
    @Published var currentModelDisplayName: String = ""
    @Published var currentDevice: String = ""
    @Published var currentEmbeddingDim: Int = 512
    @Published var availableModels: [CLIPModelInfo] = []
    @Published var isLoading: Bool = false
    @Published var isChangingModel: Bool = false
    @Published var errorMessage: String? = nil
    @Published var requiresReindex: Bool = false

    private let serverURL = "http://127.0.0.1:7860"

    private init() {
        // Pre-populate with known models (will be updated from server)
        availableModels = [
            CLIPModelInfo(id: "openai/clip-vit-base-patch32", name: "CLIP ViT-B/32", description: "Fast, good balance of speed and accuracy", embeddingDim: 512, sizeMB: 605),
            CLIPModelInfo(id: "openai/clip-vit-base-patch16", name: "CLIP ViT-B/16", description: "More accurate than B/32, slower", embeddingDim: 512, sizeMB: 605),
            CLIPModelInfo(id: "openai/clip-vit-large-patch14", name: "CLIP ViT-L/14", description: "High accuracy, requires more memory", embeddingDim: 768, sizeMB: 1710),
            CLIPModelInfo(id: "openai/clip-vit-large-patch14-336", name: "CLIP ViT-L/14@336px", description: "Highest accuracy, processes 336px images", embeddingDim: 768, sizeMB: 1710),
            CLIPModelInfo(id: "laion/CLIP-ViT-B-32-laion2B-s34B-b79K", name: "LAION CLIP ViT-B/32", description: "Trained on LAION-2B dataset", embeddingDim: 512, sizeMB: 605),
            CLIPModelInfo(id: "laion/CLIP-ViT-H-14-laion2B-s32B-b79K", name: "LAION CLIP ViT-H/14", description: "Large model, very accurate", embeddingDim: 1024, sizeMB: 3940)
        ]
    }

    func fetchCurrentModel() {
        isLoading = true
        errorMessage = nil

        guard let url = URL(string: "\(serverURL)/model") else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false

                if let error = error {
                    self?.errorMessage = "Failed to connect: \(error.localizedDescription)"
                    return
                }

                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    self?.errorMessage = "Invalid response"
                    return
                }

                if let status = json["status"] as? String, status == "not_loaded" {
                    self?.currentModelName = ""
                    self?.currentModelDisplayName = "No model loaded"
                    return
                }

                self?.currentModelName = json["model_name"] as? String ?? ""
                self?.currentDevice = json["device"] as? String ?? "unknown"
                self?.currentEmbeddingDim = json["embedding_dim"] as? Int ?? 512
                self?.currentModelDisplayName = json["name"] as? String ?? self?.currentModelName ?? ""
            }
        }.resume()
    }

    func changeModel(to modelId: String, completion: @escaping (Bool, String?) -> Void) {
        isChangingModel = true
        errorMessage = nil
        requiresReindex = false

        guard let url = URL(string: "\(serverURL)/model") else {
            completion(false, "Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["model_name": modelId]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isChangingModel = false

                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    completion(false, error.localizedDescription)
                    return
                }

                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    self?.errorMessage = "Invalid response"
                    completion(false, "Invalid response")
                    return
                }

                let status = json["status"] as? String ?? "error"

                if status == "success" {
                    self?.currentModelName = json["new_model"] as? String ?? modelId
                    self?.currentEmbeddingDim = json["new_embedding_dim"] as? Int ?? 512
                    self?.requiresReindex = json["reindex_required"] as? Bool ?? false

                    // Update display name from our known models
                    if let model = self?.availableModels.first(where: { $0.id == modelId }) {
                        self?.currentModelDisplayName = model.name
                    } else {
                        self?.currentModelDisplayName = modelId
                    }

                    completion(true, self?.requiresReindex == true ? "Re-indexing required due to different embedding dimensions" : nil)
                } else {
                    let message = json["message"] as? String ?? "Failed to change model"
                    self?.errorMessage = message
                    completion(false, message)
                }
            }
        }.resume()
    }
}

// MARK: - Watched Directory Model
struct WatchedDirectory: Identifiable, Codable, Equatable {
    var id: UUID
    var path: String
    var filter: String
    var filterType: FilterType

    enum FilterType: String, Codable, CaseIterable {
        case all = "All Files"
        case startsWith = "Starts With"
        case endsWith = "Ends With"
        case contains = "Contains"
        case regex = "Regex"
    }

    init(id: UUID = UUID(), path: String, filter: String = "", filterType: FilterType = .all) {
        self.id = id
        self.path = path
        self.filter = filter
        self.filterType = filterType
    }

    var displayPath: String {
        (path as NSString).abbreviatingWithTildeInPath
    }

    var filterDescription: String? {
        guard !filter.isEmpty && filterType != .all else { return nil }
        return "\(filterType.rawValue): \(filter)"
    }
}

// MARK: - Directory Manager
class DirectoryManager: ObservableObject {
    static let shared = DirectoryManager()

    @Published var watchedDirectories: [WatchedDirectory] {
        didSet { saveDirectories() }
    }

    private let userDefaultsKey = "watchedDirectories"

    private init() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let directories = try? JSONDecoder().decode([WatchedDirectory].self, from: data) {
            self.watchedDirectories = directories
        } else {
            // Default directories
            self.watchedDirectories = [
                WatchedDirectory(path: NSString(string: "~/Downloads").expandingTildeInPath),
                WatchedDirectory(path: NSString(string: "~/Desktop").expandingTildeInPath, filter: "Screenshot", filterType: .startsWith)
            ]
        }
    }

    private func saveDirectories() {
        if let data = try? JSONEncoder().encode(watchedDirectories) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    func addDirectory(_ directory: WatchedDirectory) {
        watchedDirectories.append(directory)
    }

    func removeDirectory(_ directory: WatchedDirectory) {
        watchedDirectories.removeAll { $0.id == directory.id }
    }

    func updateDirectory(_ directory: WatchedDirectory) {
        if let index = watchedDirectories.firstIndex(where: { $0.id == directory.id }) {
            watchedDirectories[index] = directory
        }
    }
}


struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let content: () -> Content
    @Environment(\.colorScheme) var colorScheme

    init(title: String, icon: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.accent)
                Text(title)
                    .font(DesignSystem.Typography.title2)
                    .foregroundColor(DesignSystem.Colors.primaryText)
            }
            content()
        }
    }
}

struct PathSetting: View {
    let title: String
    let icon: String
    @Binding var path: String
    @Binding var showPicker: Bool
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(DesignSystem.Colors.accent)
                Text(title)
                    .font(DesignSystem.Typography.callout.weight(.medium))
                    .foregroundColor(DesignSystem.Colors.primaryText)
            }

            HStack(spacing: DesignSystem.Spacing.sm) {
                TextField("Path", text: $path)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(DesignSystem.Typography.caption)
                    .padding(DesignSystem.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                            .fill(colorScheme == .dark ?
                                DesignSystem.Colors.darkTertiaryBackground :
                                DesignSystem.Colors.tertiaryBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                            .stroke(DesignSystem.Colors.border, lineWidth: 1)
                    )

                Button(action: {
                    showPicker = true
                }) {
                    Text("Browse")
                        .font(DesignSystem.Typography.caption.weight(.medium))
                        .foregroundColor(DesignSystem.Colors.accent)
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.vertical, DesignSystem.Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                                .fill(DesignSystem.Colors.accent.opacity(0.1))
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

struct SettingsGroup<Content: View>: View {
    let title: String
    let content: () -> Content
    @Environment(\.colorScheme) var colorScheme

    init(title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            content()
        }
        .padding(DesignSystem.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(colorScheme == .dark ?
                    DesignSystem.Colors.darkSecondaryBackground :
                    DesignSystem.Colors.secondaryBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .stroke(DesignSystem.Colors.border, lineWidth: 1)
        )
    }
}

// MARK: - AI Model Settings Section
struct AIModelSettingsSection: View {
    @ObservedObject private var modelSettings = ModelSettings.shared
    @State private var selectedModelId: String = ""
    @State private var showingConfirmation = false
    @State private var showingReindexAlert = false
    @State private var pendingModelId: String = ""
    @State private var customModelName: String = ""
    @State private var showingCustomModelInput = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        SettingsSection(title: "AI Model", icon: "cpu") {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                // Current Model Info
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    HStack {
                        Text("Current Model")
                            .font(DesignSystem.Typography.callout.weight(.medium))
                            .foregroundColor(DesignSystem.Colors.primaryText)
                        Spacer()
                        if modelSettings.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }

                    if !modelSettings.currentModelDisplayName.isEmpty {
                        HStack(spacing: DesignSystem.Spacing.md) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(modelSettings.currentModelDisplayName)
                                    .font(DesignSystem.Typography.body.weight(.semibold))
                                    .foregroundColor(DesignSystem.Colors.accent)

                                HStack(spacing: DesignSystem.Spacing.md) {
                                    Label(modelSettings.currentDevice, systemImage: "cpu")
                                    Label("\(modelSettings.currentEmbeddingDim)-dim", systemImage: "number")
                                }
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                            }
                            Spacer()
                        }
                        .padding(DesignSystem.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                .fill(colorScheme == .dark ?
                                    DesignSystem.Colors.darkTertiaryBackground :
                                    DesignSystem.Colors.tertiaryBackground)
                        )
                    }
                }

                Divider()

                // Model Selection
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Change Model")
                        .font(DesignSystem.Typography.callout.weight(.medium))
                        .foregroundColor(DesignSystem.Colors.primaryText)

                    Text("Select a different CLIP model from HuggingFace")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)

                    // Model Picker
                    ForEach(modelSettings.availableModels) { model in
                        ModelSelectionRow(
                            model: model,
                            isSelected: modelSettings.currentModelName == model.id,
                            isCurrent: modelSettings.currentModelName == model.id,
                            onSelect: {
                                if model.id != modelSettings.currentModelName {
                                    pendingModelId = model.id
                                    // Check if dimensions are different
                                    if model.embeddingDim != modelSettings.currentEmbeddingDim {
                                        showingConfirmation = true
                                    } else {
                                        changeModel(to: model.id)
                                    }
                                }
                            }
                        )
                    }

                    // Custom Model Input
                    DisclosureGroup("Use Custom Model", isExpanded: $showingCustomModelInput) {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("Enter a HuggingFace model name (e.g., openai/clip-vit-base-patch32)")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.secondaryText)

                            HStack {
                                TextField("Model name", text: $customModelName)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .font(DesignSystem.Typography.body)
                                    .padding(DesignSystem.Spacing.sm)
                                    .background(
                                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                                            .fill(colorScheme == .dark ?
                                                DesignSystem.Colors.darkTertiaryBackground :
                                                DesignSystem.Colors.tertiaryBackground)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                                            .stroke(DesignSystem.Colors.border, lineWidth: 1)
                                    )

                                Button(action: {
                                    if !customModelName.isEmpty {
                                        pendingModelId = customModelName
                                        showingConfirmation = true
                                    }
                                }) {
                                    Text("Load")
                                        .font(DesignSystem.Typography.callout.weight(.medium))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, DesignSystem.Spacing.lg)
                                        .padding(.vertical, DesignSystem.Spacing.sm)
                                        .background(
                                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                                .fill(DesignSystem.Colors.accent)
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                                .disabled(customModelName.isEmpty || modelSettings.isChangingModel)
                            }
                        }
                        .padding(.top, DesignSystem.Spacing.sm)
                    }
                    .font(DesignSystem.Typography.callout)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                }

                // Error message
                if let error = modelSettings.errorMessage {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(DesignSystem.Colors.error)
                        Text(error)
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.error)
                    }
                    .padding(DesignSystem.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                            .fill(DesignSystem.Colors.error.opacity(0.1))
                    )
                }

                // Re-index warning
                if modelSettings.requiresReindex {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Re-indexing required! The new model has different embedding dimensions.")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(.orange)
                    }
                    .padding(DesignSystem.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                            .fill(Color.orange.opacity(0.1))
                    )
                }

                // Loading overlay
                if modelSettings.isChangingModel {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading model...")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                    .padding(DesignSystem.Spacing.md)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                            .fill(colorScheme == .dark ?
                                DesignSystem.Colors.darkTertiaryBackground :
                                DesignSystem.Colors.tertiaryBackground)
                    )
                }
            }
            .padding(DesignSystem.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                    .fill(colorScheme == .dark ?
                        DesignSystem.Colors.darkSecondaryBackground :
                        DesignSystem.Colors.secondaryBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                    .stroke(DesignSystem.Colors.border, lineWidth: 1)
            )
        }
        .onAppear {
            modelSettings.fetchCurrentModel()
        }
        .alert("Change Model?", isPresented: $showingConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Change & Re-index") {
                changeModel(to: pendingModelId)
            }
        } message: {
            Text("This model has different embedding dimensions. Your image index will need to be rebuilt, which may take some time.")
        }
    }

    private func changeModel(to modelId: String) {
        modelSettings.changeModel(to: modelId) { success, message in
            if success && modelSettings.requiresReindex {
                showingReindexAlert = true
            }
        }
    }
}

// MARK: - Model Selection Row
struct ModelSelectionRow: View {
    let model: CLIPModelInfo
    let isSelected: Bool
    let isCurrent: Bool
    let onSelect: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: DesignSystem.Spacing.md) {
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isCurrent ? DesignSystem.Colors.accent : DesignSystem.Colors.border, lineWidth: 2)
                        .frame(width: 20, height: 20)

                    if isCurrent {
                        Circle()
                            .fill(DesignSystem.Colors.accent)
                            .frame(width: 12, height: 12)
                    }
                }

                // Model info
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(model.name)
                            .font(DesignSystem.Typography.body.weight(.medium))
                            .foregroundColor(isCurrent ? DesignSystem.Colors.accent : DesignSystem.Colors.primaryText)

                        if isCurrent {
                            Text("Current")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(DesignSystem.Colors.accent)
                                )
                        }
                    }

                    Text(model.description)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)

                    HStack(spacing: DesignSystem.Spacing.md) {
                        Label("\(model.embeddingDim)-dim", systemImage: "number")
                        Label("\(model.sizeMB) MB", systemImage: "internaldrive")
                    }
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
                }

                Spacer()
            }
            .padding(DesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .fill(isCurrent ?
                        DesignSystem.Colors.accent.opacity(0.1) :
                        (colorScheme == .dark ?
                            DesignSystem.Colors.darkTertiaryBackground :
                            DesignSystem.Colors.tertiaryBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .stroke(isCurrent ? DesignSystem.Colors.accent : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Watched Directory Row
struct WatchedDirectoryRow: View {
    let directory: WatchedDirectory
    let onDelete: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "folder.fill")
                .foregroundColor(DesignSystem.Colors.accent)
                .font(.system(size: 16))

            VStack(alignment: .leading, spacing: 2) {
                Text(directory.path.components(separatedBy: "/").last ?? directory.path)
                    .font(DesignSystem.Typography.body.weight(.medium))
                    .foregroundColor(DesignSystem.Colors.primaryText)

                Text(directory.displayPath)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.secondaryText)

                if let filterDesc = directory.filterDescription {
                    Text(filterDesc)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.success)
                }
            }

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "trash.fill")
                    .foregroundColor(DesignSystem.Colors.error)
                    .font(.system(size: 14))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(colorScheme == .dark ?
                    DesignSystem.Colors.darkTertiaryBackground :
                    DesignSystem.Colors.tertiaryBackground)
        )
    }
}

// MARK: - Add Directory Sheet
struct AddDirectorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var dirManager = DirectoryManager.shared

    @State private var selectedPath: String = ""
    @State private var filter: String = ""
    @State private var filterType: WatchedDirectory.FilterType = .all
    @State private var isShowingFolderPicker = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Directory")
                    .font(DesignSystem.Typography.title)
                    .foregroundColor(DesignSystem.Colors.primaryText)
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(DesignSystem.Colors.secondaryText)
            }
            .padding(DesignSystem.Spacing.xl)
            .background(colorScheme == .dark ?
                DesignSystem.Colors.darkSecondaryBackground :
                DesignSystem.Colors.secondaryBackground)

            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                    // Directory Selection
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Label("Directory", systemImage: "folder")
                            .font(DesignSystem.Typography.callout.weight(.medium))

                        HStack {
                            Text(selectedPath.isEmpty ? "Select a directory..." : selectedPath)
                                .font(DesignSystem.Typography.body)
                                .foregroundColor(selectedPath.isEmpty ?
                                    DesignSystem.Colors.secondaryText :
                                    DesignSystem.Colors.primaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(DesignSystem.Spacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                                        .fill(colorScheme == .dark ?
                                            DesignSystem.Colors.darkTertiaryBackground :
                                            DesignSystem.Colors.tertiaryBackground)
                                )

                            Button("Browse") {
                                isShowingFolderPicker = true
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    // Filter Type
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Label("Filter Type", systemImage: "line.3.horizontal.decrease.circle")
                            .font(DesignSystem.Typography.callout.weight(.medium))

                        Picker("", selection: $filterType) {
                            ForEach(WatchedDirectory.FilterType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // Filter Value (if not "All Files")
                    if filterType != .all {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Label("Filter Value", systemImage: "text.magnifyingglass")
                                .font(DesignSystem.Typography.callout.weight(.medium))

                            TextField("e.g., Screenshot", text: $filter)
                                .textFieldStyle(.roundedBorder)

                            Text(filterHelpText)
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                        }
                    }

                    // Add Button
                    Button(action: addDirectory) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Directory")
                        }
                        .font(DesignSystem.Typography.body.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                .fill(selectedPath.isEmpty ?
                                    DesignSystem.Colors.accent.opacity(0.5) :
                                    DesignSystem.Colors.accent)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(selectedPath.isEmpty)
                }
                .padding(DesignSystem.Spacing.xl)
            }
        }
        .frame(width: 450, height: 400)
        .background(colorScheme == .dark ?
            DesignSystem.Colors.darkPrimaryBackground :
            DesignSystem.Colors.primaryBackground)
        .fileImporter(isPresented: $isShowingFolderPicker, allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result {
                selectedPath = url.path
            }
        }
    }

    private var filterHelpText: String {
        switch filterType {
        case .all: return ""
        case .startsWith: return "Only index files whose names start with this text"
        case .endsWith: return "Only index files whose names end with this text"
        case .contains: return "Only index files whose names contain this text"
        case .regex: return "Only index files matching this regular expression"
        }
    }

    private func addDirectory() {
        guard !selectedPath.isEmpty else { return }
        let newDir = WatchedDirectory(
            path: selectedPath,
            filter: filterType == .all ? "" : filter,
            filterType: filterType
        )
        dirManager.addDirectory(newDir)
        dismiss()
    }
}

struct SettingsView: View {
    @ObservedObject private var config = AppConfig.shared
    @ObservedObject private var prefs = SearchPreferences.shared
    @ObservedObject private var indexingSettings = IndexingSettings.shared
    @ObservedObject private var dirManager = DirectoryManager.shared
    @State private var isShowingBaseDirectoryPicker = false
    @State private var isShowingAddDirectorySheet = false
    @State private var isReindexing = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            // Clean solid background
            (colorScheme == .dark ? Color(hex: "000000") : Color(hex: "FFFFFF"))
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Modern Header
                HStack(spacing: DesignSystem.Spacing.md) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("Settings")
                            .font(DesignSystem.Typography.largeTitle)
                            .foregroundColor(DesignSystem.Colors.primaryText)
                        Text("Customize your search experience")
                            .font(DesignSystem.Typography.callout)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }

                    Spacer()

                    Button(action: {
                        dismiss()
                    }) {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Text("Done")
                                .font(DesignSystem.Typography.body.weight(.semibold))
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        .padding(.vertical, DesignSystem.Spacing.sm)
                        .background(
                            Capsule()
                                .fill(DesignSystem.Colors.accent)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(DesignSystem.Spacing.xl)
                .background(
                    colorScheme == .dark ?
                        Color(hex: "111111") :
                        Color(hex: "FAFAFA")
                )

                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.xl) {
                        // Display Settings Section
                    SettingsSection(title: "Display", icon: "paintbrush") {
                        // Grid Layout Settings
                        SettingsGroup(title: "Grid Layout") {
                            // Number of columns
                            HStack {
                                Label("Columns", systemImage: "square.grid.3x3")
                                Spacer()
                                Picker("", selection: $prefs.gridColumns) {
                                    ForEach(2...6, id: \.self) { num in
                                        Text("\(num)").tag(num)
                                    }
                                }
                                .frame(width: 100)
                            }
                            
                            // Image size slider
                            VStack(alignment: .leading, spacing: 6) {
                                Label("Image Size", systemImage: "photo.fill")
                                Slider(value: $prefs.imageSize, in: 100...400, step: 50) {
                                    Text("Image Size")
                                } minimumValueLabel: {
                                    Text("S").font(.caption)
                                } maximumValueLabel: {
                                    Text("L").font(.caption)
                                }
                            }
                            
                            // Stats toggle
                            Toggle(isOn: $prefs.showStats) {
                                Label("Show Statistics", systemImage: "chart.bar.fill")
                            }
                        }
                    }
                    
                    // Search Settings Section
                    SettingsSection(title: "Search", icon: "magnifyingglass") {
                        SettingsGroup(title: "Results") {
                            // Number of results
                            HStack {
                                Label("Max Results", systemImage: "number.circle.fill")
                                Spacer()
                                Picker("", selection: $prefs.numberOfResults) {
                                    ForEach([10, 20, 50, 100], id: \.self) { num in
                                        Text("\(num)").tag(num)
                                    }
                                }
                                .frame(width: 100)
                            }

                            // Similarity threshold
                            VStack(alignment: .leading, spacing: 6) {
                                Label("Minimum Similarity", systemImage: "slider.horizontal.3")
                                Slider(value: $prefs.similarityThreshold, in: 0...1, step: 0.05) {
                                    Text("Similarity")
                                } minimumValueLabel: {
                                    Text("0%").font(.caption)
                                } maximumValueLabel: {
                                    Text("100%").font(.caption)
                                }
                            }
                        }
                    }

                    // Indexing Settings Section
                    SettingsSection(title: "Indexing", icon: "square.stack.3d.up") {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                            // Fast Indexing toggle
                            VStack(alignment: .leading, spacing: 4) {
                                Toggle(isOn: $indexingSettings.enableFastIndexing) {
                                    HStack(spacing: DesignSystem.Spacing.sm) {
                                        Image(systemName: "bolt.fill")
                                            .foregroundColor(.yellow)
                                        Text("Fast Indexing")
                                            .font(DesignSystem.Typography.body)
                                    }
                                }
                                .toggleStyle(.checkbox)
                                Text("Resize large images before processing (recommended)")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.secondaryText)
                                    .padding(.leading, 24)
                            }

                            Divider()

                            // Max Dimension
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    HStack(spacing: DesignSystem.Spacing.sm) {
                                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                                            .foregroundColor(DesignSystem.Colors.accent)
                                        Text("Max Dimension")
                                    }
                                    Spacer()
                                    HStack(spacing: 4) {
                                        TextField("", value: $indexingSettings.maxDimension, formatter: NumberFormatter())
                                            .textFieldStyle(.roundedBorder)
                                            .frame(width: 60)
                                            .multilineTextAlignment(.center)
                                        Text("px")
                                            .foregroundColor(DesignSystem.Colors.secondaryText)
                                        Stepper("", value: $indexingSettings.maxDimension, in: 256...768, step: 128)
                                            .labelsHidden()
                                    }
                                }
                                Text("Larger values = slower indexing, potentially better accuracy")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.secondaryText)
                            }

                            Divider()

                            // Batch Size
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    HStack(spacing: DesignSystem.Spacing.sm) {
                                        Image(systemName: "square.stack.3d.up.fill")
                                            .foregroundColor(DesignSystem.Colors.accent)
                                        Text("Batch Size")
                                    }
                                    Spacer()
                                    HStack(spacing: 4) {
                                        TextField("", value: $indexingSettings.batchSize, formatter: NumberFormatter())
                                            .textFieldStyle(.roundedBorder)
                                            .frame(width: 60)
                                            .multilineTextAlignment(.center)
                                        Stepper("", value: $indexingSettings.batchSize, in: 32...256, step: 32)
                                            .labelsHidden()
                                    }
                                }
                                Text("Images processed at once. Higher = faster but more memory")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.secondaryText)
                            }
                        }
                        .padding(DesignSystem.Spacing.lg)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                                .fill(colorScheme == .dark ?
                                    DesignSystem.Colors.darkSecondaryBackground :
                                    DesignSystem.Colors.secondaryBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                                .stroke(DesignSystem.Colors.border, lineWidth: 1)
                        )
                    }

                    // Server Settings Section
                    SettingsSection(title: "Server", icon: "server.rack") {
                        SettingsGroup(title: "Configuration") {
                            // Port setting
                            HStack {
                                Label("Port", systemImage: "network")
                                Spacer()
                                TextField("Port", value: $config.defaultPort, formatter: NumberFormatter())
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 100)
                            }
                            
                            // Base directory
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Base Directory", systemImage: "folder")
                                HStack {
                                    TextField("Directory", text: $config.baseDirectory)
                                        .textFieldStyle(.roundedBorder)
                                    Button("Browse") {
                                        isShowingBaseDirectoryPicker = true
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                    }
                    
                    // Reset Button
                    Button(action: {
                        withAnimation {
                            config.resetToDefaults()
                        }
                    }) {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            Image(systemName: "arrow.counterclockwise.circle.fill")
                                .font(.system(size: 14))
                            Text("Reset to Defaults")
                                .font(DesignSystem.Typography.callout.weight(.medium))
                        }
                        .foregroundColor(DesignSystem.Colors.error)
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        .padding(.vertical, DesignSystem.Spacing.md)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                .fill(DesignSystem.Colors.error.opacity(0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                .stroke(DesignSystem.Colors.error.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(DesignSystem.Spacing.xl)
            }
            }
        }
        .frame(minWidth: 700, idealWidth: 750, maxWidth: 850, minHeight: 600, idealHeight: 800, maxHeight: .infinity)
        .fileImporter(isPresented: $isShowingBaseDirectoryPicker, allowedContentTypes: [.directory]) { result in
            if case .success(let url) = result {
                config.baseDirectory = url.path
            }
        }
        .sheet(isPresented: $isShowingAddDirectorySheet) {
            AddDirectorySheet()
        }
    }

    // MARK: - Re-index Function
    private func performReindex() {
        isReindexing = true

        DispatchQueue.global(qos: .userInitiated).async {
            let config = AppConfig.shared
            let indexingSettings = IndexingSettings.shared

            // Delete existing index
            let indexPath = "\(config.baseDirectory)/image_index.pkl"
            try? FileManager.default.removeItem(atPath: indexPath)

            // Re-index all watched directories
            for directory in dirManager.watchedDirectories {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: config.pythonExecutablePath)
                process.arguments = [
                    config.embeddingScriptPath,
                    directory.path,
                    "--max-dimension", String(indexingSettings.maxDimension),
                    "--batch-size", String(indexingSettings.batchSize)
                ]

                if indexingSettings.enableFastIndexing {
                    process.arguments?.append("--fast")
                }

                // Add filter arguments if applicable
                if !directory.filter.isEmpty && directory.filterType != .all {
                    process.arguments?.append("--filter-type")
                    process.arguments?.append(directory.filterType.rawValue.lowercased().replacingOccurrences(of: " ", with: "-"))
                    process.arguments?.append("--filter")
                    process.arguments?.append(directory.filter)
                }

                let resourcesPath = Bundle.main.resourcePath ?? ""
                process.environment = [
                    "PYTHONPATH": resourcesPath,
                    "PATH": "\(config.baseDirectory)/venv/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
                ]
                process.currentDirectoryURL = URL(fileURLWithPath: resourcesPath)

                do {
                    try process.run()
                    process.waitUntilExit()
                } catch {
                    print("Error re-indexing \(directory.path): \(error)")
                }
            }

            DispatchQueue.main.async {
                isReindexing = false
            }
        }
    }
}

#Preview {
    SettingsView()
}
// Extension to support Python file types
extension UTType {
    static var pythonScript: UTType {
        UTType(filenameExtension: "py")!
    }
    
    static var unixExecutable: UTType {
        UTType(filenameExtension: "")!
    }
}

class ImageCache {
    static let shared = ImageCache()
    private var cache = NSCache<NSString, NSImage>()

    func image(for path: String) -> NSImage? {
        return cache.object(forKey: path as NSString)
    }

    func setImage(_ image: NSImage, for path: String) {
        cache.setObject(image, forKey: path as NSString)
    }

    func clear() {
        cache.removeAllObjects()
    }
}

// MARK: - Efficient Thumbnail Service
/// Uses CGImageSource to load only thumbnail data from images, not the full file.
/// This is much faster and uses less memory than loading full images and resizing.
class ThumbnailService {
    static let shared = ThumbnailService()

    private let cache = NSCache<NSString, NSImage>()
    private let queue = DispatchQueue(label: "com.searchy.thumbnails", qos: .userInitiated, attributes: .concurrent)

    private init() {
        // Allow up to 500 thumbnails in cache
        cache.countLimit = 500
    }

    /// Generate a cache key that includes size for different thumbnail sizes
    private func cacheKey(for path: String, size: Int) -> NSString {
        return "\(path)_\(size)" as NSString
    }

    /// Get cached thumbnail if available
    func cachedThumbnail(for path: String, size: Int) -> NSImage? {
        return cache.object(forKey: cacheKey(for: path, size: size))
    }

    /// Load thumbnail efficiently using CGImageSource
    /// This reads only the necessary bytes from the file, not the entire image
    func loadThumbnail(for path: String, maxSize: Int, completion: @escaping (NSImage?) -> Void) {
        let key = cacheKey(for: path, size: maxSize)

        // Check cache first
        if let cached = cache.object(forKey: key) {
            DispatchQueue.main.async {
                completion(cached)
            }
            return
        }

        // Load on background queue
        queue.async { [weak self] in
            guard let self = self else { return }

            let url = URL(fileURLWithPath: path)

            guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            // Options for thumbnail generation
            let options: [CFString: Any] = [
                kCGImageSourceThumbnailMaxPixelSize: maxSize,
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,  // Apply EXIF orientation
                kCGImageSourceShouldCacheImmediately: true
            ]

            guard let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
                // Fallback: try loading full image if thumbnail fails (for some formats)
                self.loadFallbackThumbnail(for: path, maxSize: maxSize, completion: completion)
                return
            }

            let thumbnail = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))

            // Cache it
            self.cache.setObject(thumbnail, forKey: key)

            DispatchQueue.main.async {
                completion(thumbnail)
            }
        }
    }

    /// Fallback for formats that don't support CGImageSource thumbnails well
    private func loadFallbackThumbnail(for path: String, maxSize: Int, completion: @escaping (NSImage?) -> Void) {
        guard let image = NSImage(contentsOfFile: path) else {
            DispatchQueue.main.async { completion(nil) }
            return
        }

        let size = image.size
        let scale = min(CGFloat(maxSize) / size.width, CGFloat(maxSize) / size.height, 1.0)
        let newSize = NSSize(width: size.width * scale, height: size.height * scale)

        let thumbnail = NSImage(size: newSize)
        thumbnail.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize),
                   from: NSRect(origin: .zero, size: size),
                   operation: .copy,
                   fraction: 1.0)
        thumbnail.unlockFocus()

        let key = cacheKey(for: path, size: maxSize)
        cache.setObject(thumbnail, forKey: key)

        DispatchQueue.main.async {
            completion(thumbnail)
        }
    }

    /// Synchronous thumbnail load (for when you need it immediately)
    func loadThumbnailSync(for path: String, maxSize: Int) -> NSImage? {
        let key = cacheKey(for: path, size: maxSize)

        if let cached = cache.object(forKey: key) {
            return cached
        }

        let url = URL(fileURLWithPath: path)

        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: maxSize,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
            return nil
        }

        let thumbnail = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        cache.setObject(thumbnail, forKey: key)

        return thumbnail
    }

    func clearCache() {
        cache.removeAllObjects()
    }
}


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

    private let baseWidth: CGFloat = 200

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

            // Top row - favorite button and similarity badge
            VStack {
                HStack {
                    if isHovered {
                        favoriteButton
                    }
                    Spacer()
                    if showSimilarity {
                        similarityBadge
                    }
                }
                Spacer()
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

// MARK: - Person Card for Face Recognition
struct PersonCard: View {
    let person: Person
    var onRename: ((String) -> Void)?
    var onSelect: (() -> Void)?
    @State private var thumbnail: NSImage?
    @State private var isHovered = false
    @State private var isEditing = false
    @State private var editedName = ""
    @FocusState private var isNameFieldFocused: Bool

    private let avatarSize: CGFloat = 88
    private let cardWidth: CGFloat = 140

    var body: some View {
        VStack(spacing: 12) {
            // Avatar with ring and hover effect
            ZStack {
                // Outer ring on hover
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [DesignSystem.Colors.accent, DesignSystem.Colors.accent.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isHovered ? 3 : 0
                    )
                    .frame(width: avatarSize + 8, height: avatarSize + 8)
                    .animation(.easeInOut(duration: 0.2), value: isHovered)

                // Avatar image
                if let image = thumbnail {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: avatarSize, height: avatarSize)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 2)
                        )
                } else {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    DesignSystem.Colors.accent.opacity(0.2),
                                    DesignSystem.Colors.accent.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: avatarSize, height: avatarSize)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 36, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.accent.opacity(0.5))
                        )
                }

                // Photo count badge
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("\(person.faceCount)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(DesignSystem.Colors.accent)
                                    .shadow(color: Color.black.opacity(0.2), radius: 2, y: 1)
                            )
                    }
                }
                .frame(width: avatarSize + 8, height: avatarSize + 8)
            }
            .onAppear { loadThumbnail() }
            .scaleEffect(isHovered ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)

            // Name with inline editing
            VStack(spacing: 4) {
                if isEditing {
                    TextField("Name", text: $editedName)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.primaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(DesignSystem.Colors.tertiaryBackground)
                        )
                        .focused($isNameFieldFocused)
                        .onSubmit { commitRename() }
                        .onExitCommand { cancelRename() }
                } else {
                    HStack(spacing: 4) {
                        Text(person.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.primaryText)
                            .lineLimit(1)
                            .onTapGesture(count: 2) { startEditing() }

                        if isHovered {
                            Button(action: { startEditing() }) {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(DesignSystem.Colors.accent)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .animation(.easeInOut(duration: 0.15), value: isHovered)
                }
            }
            .frame(height: 24)
        }
        .frame(width: cardWidth)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(DesignSystem.Colors.secondaryBackground)
                .shadow(
                    color: Color.black.opacity(isHovered ? 0.12 : 0.06),
                    radius: isHovered ? 12 : 6,
                    y: isHovered ? 6 : 3
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isHovered ? DesignSystem.Colors.accent.opacity(0.3) : Color.clear,
                    lineWidth: 1
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if !isEditing {
                onSelect?()
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }

    private func loadThumbnail() {
        guard let path = person.thumbnailPath else { return }
        let size = Int(avatarSize) * 2  // 2x for retina
        if let cached = ThumbnailService.shared.cachedThumbnail(for: path, size: size) {
            self.thumbnail = cached
            return
        }
        ThumbnailService.shared.loadThumbnail(for: path, maxSize: size) { thumb in
            self.thumbnail = thumb
        }
    }

    private func startEditing() {
        editedName = person.name
        isEditing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isNameFieldFocused = true
        }
    }

    private func commitRename() {
        let trimmed = editedName.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty && trimmed != person.name {
            onRename?(trimmed)
        }
        isEditing = false
    }

    private func cancelRename() {
        isEditing = false
        editedName = person.name
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

            // Top row - favorite button (left) and similarity badge (right) - ON TOP
            VStack {
                HStack {
                    if isHovered {
                        favoriteButton
                    }
                    Spacer()
                    if showSimilarity {
                        similarityBadge
                    }
                }
                Spacer()
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

// Search Result Model
struct SearchResult: Codable, Identifiable {
    var id = UUID()
    let path: String
    let similarity: Float
    let size: Int?
    let date: String?
    let type: String?

    enum CodingKeys: String, CodingKey {
        case path
        case similarity
        case size
        case date
        case type
    }

    var formattedSize: String {
        guard let size = size else { return "Unknown" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }

    var fileExtension: String {
        type ?? URL(fileURLWithPath: path).pathExtension.lowercased()
    }
}

struct SearchResponse: Codable {
    let results: [SearchResult]
    let stats: SearchStats
    let error: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.error = try container.decodeIfPresent(String.self, forKey: .error)
        // If there's an error, set empty results and default stats
        if self.error != nil {
            self.results = []
            self.stats = SearchStats(total_time: "0s", images_searched: 0, images_per_second: "0")
        } else {
            self.results = try container.decode([SearchResult].self, forKey: .results)
            self.stats = try container.decode(SearchStats.self, forKey: .stats)
        }
    }
}

struct SearchStats: Codable {
    let total_time: String
    let images_searched: Int
    let images_per_second: String

    init(total_time: String, images_searched: Int, images_per_second: String) {
        self.total_time = total_time
        self.images_searched = images_searched
        self.images_per_second = images_per_second
    }
}

class SearchManager: ObservableObject {
    static let shared = SearchManager()

    @Published private(set) var results: [SearchResult] = []
    @Published private(set) var isSearching = false
    @Published private(set) var errorMessage: String? = nil
    @Published private(set) var searchStats: SearchStats? = nil

    private init() {}

    private var serverURL: URL? {
        get async {
            let delegate = await AppDelegate.shared
            return await delegate.serverURL
        }
    }
    
    func search(query: String, numberOfResults: Int = 5) {
        guard !isSearching else { return }
        
        DispatchQueue.main.async {
            self.isSearching = true
            self.errorMessage = nil
            self.results = []
            self.searchStats = nil
        }
        
        Task {
            do {
                let response = try await self.performSearch(query: query, numberOfResults: numberOfResults)
                DispatchQueue.main.async {
                    let filteredResults = response.results.filter {
                        $0.similarity >= SearchPreferences.shared.similarityThreshold
                    }
                    self.results = filteredResults
                    self.searchStats = response.stats
                    self.isSearching = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isSearching = false
                }
            }
        }
    }
    
    private func performSearch(query: String, numberOfResults: Int) async throws -> SearchResponse {
        guard let serverURL = await self.serverURL else {
            throw NSError(domain: "Server not ready", code: 0, userInfo: [NSLocalizedDescriptionKey: "Server is still starting up. Please wait a moment."])
        }
        let url = serverURL.appendingPathComponent("search")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "query": query,
            "top_k": numberOfResults,
            "data_dir": "/Users/ausaf/Library/Application Support/searchy",
            "similarity_threshold": SearchPreferences.shared.similarityThreshold
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(SearchResponse.self, from: data)

        // Check if server returned an error
        if let errorMessage = response.error {
            throw NSError(domain: "SearchError", code: 0, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }

        return response
    }
    func cancelSearch() {
        DispatchQueue.main.async {
            self.isSearching = false
            self.errorMessage = nil
        }
    }

    func clearResults() {
        DispatchQueue.main.async {
            self.results = []
            self.searchStats = nil
            self.errorMessage = nil
        }
    }

    func loadRecentImages(completion: @escaping ([SearchResult]) -> Void) {
        Task {
            do {
                guard let serverURL = await self.serverURL else {
                    // Server not ready yet, return empty
                    DispatchQueue.main.async {
                        completion([])
                    }
                    return
                }
                let url = serverURL.appendingPathComponent("recent")
                var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
                components.queryItems = [
                    URLQueryItem(name: "top_k", value: "50"),
                    URLQueryItem(name: "data_dir", value: "/Users/ausaf/Library/Application Support/searchy")
                ]

                guard let finalURL = components.url else {
                    DispatchQueue.main.async {
                        completion([])
                    }
                    return
                }

                let (data, _) = try await URLSession.shared.data(from: finalURL)
                let decoder = JSONDecoder()
                let response = try decoder.decode(SearchResponse.self, from: data)

                DispatchQueue.main.async {
                    completion(response.results)
                }
            } catch {
                print("Error loading recent images: \(error)")
                DispatchQueue.main.async {
                    completion([])
                }
            }
        }
    }

    func findSimilar(imagePath: String, numberOfResults: Int = 20) {
        guard !isSearching else { return }

        DispatchQueue.main.async {
            self.isSearching = true
            self.errorMessage = nil
            self.results = []
            self.searchStats = nil
        }

        Task {
            do {
                let response = try await self.performFindSimilar(imagePath: imagePath, numberOfResults: numberOfResults)
                DispatchQueue.main.async {
                    self.results = response.results
                    self.searchStats = response.stats
                    self.isSearching = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isSearching = false
                }
            }
        }
    }

    private func performFindSimilar(imagePath: String, numberOfResults: Int) async throws -> SearchResponse {
        guard let serverURL = await self.serverURL else {
            throw NSError(domain: "Server not ready", code: 0, userInfo: [NSLocalizedDescriptionKey: "Server is still starting up. Please wait a moment."])
        }
        let url = serverURL.appendingPathComponent("similar")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "image_path": imagePath,
            "top_k": numberOfResults,
            "data_dir": "/Users/ausaf/Library/Application Support/searchy"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(SearchResponse.self, from: data)

        if let errorMessage = response.error {
            throw NSError(domain: "SearchError", code: 0, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }

        return response
    }
}

// MARK: - Indexing Progress Models
struct IndexingProgressData: Codable {
    let type: String
    let batch: Int?
    let total_batches: Int?
    let images_processed: Int?
    let total_images: Int?
    let elapsed: Double?
    let new_images: Int?
    let total_time: Double?
    let images_per_sec: Double?
}

struct IndexingReport {
    let totalImages: Int
    let newImages: Int
    let totalTime: Double
    let imagesPerSec: Double
}

struct IndexStats {
    let totalImages: Int
    let fileSize: String
    let lastModified: Date?
}

// MARK: - Setup Tab Helper Views

struct SetupModelRow: View {
    let model: CLIPModelInfo
    let isSelected: Bool
    let isChanging: Bool
    let onSelect: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                // Selection indicator
                Circle()
                    .fill(isSelected ? DesignSystem.Colors.accent : Color.clear)
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .stroke(isSelected ? DesignSystem.Colors.accent : DesignSystem.Colors.border, lineWidth: 1.5)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(model.name)
                        .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                        .foregroundColor(isSelected ? DesignSystem.Colors.accent : DesignSystem.Colors.primaryText)

                    Text("\(model.embeddingDim)-dim • \(model.sizeMB)MB")
                        .font(.system(size: 10))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(DesignSystem.Colors.accent)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ?
                        DesignSystem.Colors.accent.opacity(0.08) :
                        (colorScheme == .dark ? Color.white.opacity(0.03) : Color.black.opacity(0.02)))
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isChanging)
        .opacity(isChanging && !isSelected ? 0.5 : 1)
    }
}

struct SetupDirectoryRow: View {
    let directory: WatchedDirectory
    let onDelete: () -> Void
    @State private var isHovered = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "folder.fill")
                .font(.system(size: 14))
                .foregroundColor(DesignSystem.Colors.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(URL(fileURLWithPath: directory.path).lastPathComponent)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                    .lineLimit(1)

                Text(directory.path)
                    .font(.system(size: 10))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            // Filter badge if present
            if directory.filterType != .all && !directory.filter.isEmpty {
                Text(directory.filter)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(DesignSystem.Colors.accent.opacity(0.1))
                    )
            }

            // Delete button on hover
            if isHovered {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
                .buttonStyle(PlainButtonStyle())
                .transition(.opacity)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(colorScheme == .dark ? Color.white.opacity(0.03) : Color.black.opacity(0.02))
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

struct SetupStatRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(color)
                .frame(width: 24)

            Text(label)
                .font(.system(size: 12))
                .foregroundColor(DesignSystem.Colors.secondaryText)

            Spacer()

            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(DesignSystem.Colors.primaryText)
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(colorScheme == .dark ? Color.white.opacity(0.03) : Color.black.opacity(0.02))
        )
    }
}

// MARK: - App Tabs
enum AppTab: String, CaseIterable {
    case faces = "Faces"
    case search = "Searchy"
    case duplicates = "Duplicates"
    case favorites = "Favorites"
    case setup = "Setup"

    var icon: String {
        switch self {
        case .faces: return "person.2"
        case .search: return "magnifyingglass"
        case .duplicates: return "doc.on.doc"
        case .favorites: return "heart.fill"
        case .setup: return "slider.horizontal.3"
        }
    }
}

// MARK: - Duplicates Models
struct DuplicateImage: Identifiable, Codable {
    var id: String { path }
    let path: String
    let size: Int
    let date: String?
    let type: String
    let similarity: Float
    var isSelected: Bool = false

    enum CodingKeys: String, CodingKey {
        case path, size, date, type, similarity
    }

    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
}

struct DuplicateGroup: Identifiable, Codable {
    let id: Int
    var images: [DuplicateImage]

    var selectedCount: Int {
        images.filter { $0.isSelected }.count
    }
}

struct DuplicatesResponse: Codable {
    let groups: [DuplicateGroup]
    let total_duplicates: Int
    let total_groups: Int
}

// MARK: - Duplicates Manager
class DuplicatesManager: ObservableObject {
    static let shared = DuplicatesManager()

    @Published var groups: [DuplicateGroup] = []
    @Published var isScanning = false
    @Published var errorMessage: String? = nil
    @Published var threshold: Float = 0.95
    @Published var totalDuplicates: Int = 0

    private init() {}

    private var serverURL: URL? {
        get async {
            let delegate = await AppDelegate.shared
            return await delegate.serverURL
        }
    }

    func scanForDuplicates() {
        guard !isScanning else { return }

        DispatchQueue.main.async {
            self.isScanning = true
            self.errorMessage = nil
            self.groups = []
        }

        Task {
            do {
                guard let serverURL = await self.serverURL else {
                    throw NSError(domain: "Server not ready", code: 0, userInfo: [NSLocalizedDescriptionKey: "Server is still starting up."])
                }

                let url = serverURL.appendingPathComponent("duplicates")
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")

                let body: [String: Any] = [
                    "threshold": self.threshold,
                    "data_dir": "/Users/ausaf/Library/Application Support/searchy"
                ]
                request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

                let (data, _) = try await URLSession.shared.data(for: request)
                let response = try JSONDecoder().decode(DuplicatesResponse.self, from: data)

                DispatchQueue.main.async {
                    self.groups = response.groups
                    self.totalDuplicates = response.total_duplicates
                    self.isScanning = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isScanning = false
                }
            }
        }
    }

    func toggleSelection(groupId: Int, imagePath: String) {
        if let groupIndex = groups.firstIndex(where: { $0.id == groupId }),
           let imageIndex = groups[groupIndex].images.firstIndex(where: { $0.path == imagePath }) {
            groups[groupIndex].images[imageIndex].isSelected.toggle()
        }
    }

    func autoSelectSmaller(groupId: Int) {
        if let groupIndex = groups.firstIndex(where: { $0.id == groupId }) {
            // Keep first (largest), select rest
            for i in 0..<groups[groupIndex].images.count {
                groups[groupIndex].images[i].isSelected = i > 0
            }
        }
    }

    func autoSelectAllSmaller() {
        for groupIndex in 0..<groups.count {
            for i in 0..<groups[groupIndex].images.count {
                groups[groupIndex].images[i].isSelected = i > 0
            }
        }
    }

    func deleteSelected(completion: @escaping (Int, Int) -> Void) {
        var deleted = 0
        var failed = 0

        for group in groups {
            for image in group.images where image.isSelected {
                let url = URL(fileURLWithPath: image.path)
                do {
                    try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                    deleted += 1
                } catch {
                    failed += 1
                }
            }
        }

        // Remove deleted images from groups
        DispatchQueue.main.async {
            self.groups = self.groups.compactMap { group in
                var updatedGroup = group
                updatedGroup.images = group.images.filter { !$0.isSelected }
                return updatedGroup.images.count > 1 ? updatedGroup : nil
            }
            self.totalDuplicates = self.groups.reduce(0) { $0 + $1.images.count - 1 }
            completion(deleted, failed)
        }
    }

    func moveSelected(to destination: URL, completion: @escaping (Int, Int) -> Void) {
        var moved = 0
        var failed = 0

        for group in groups {
            for image in group.images where image.isSelected {
                let sourceURL = URL(fileURLWithPath: image.path)
                let destURL = destination.appendingPathComponent(sourceURL.lastPathComponent)
                do {
                    try FileManager.default.moveItem(at: sourceURL, to: destURL)
                    moved += 1
                } catch {
                    failed += 1
                }
            }
        }

        // Remove moved images from groups
        DispatchQueue.main.async {
            self.groups = self.groups.compactMap { group in
                var updatedGroup = group
                updatedGroup.images = group.images.filter { !$0.isSelected }
                return updatedGroup.images.count > 1 ? updatedGroup : nil
            }
            self.totalDuplicates = self.groups.reduce(0) { $0 + $1.images.count - 1 }
            completion(moved, failed)
        }
    }

    var totalSelected: Int {
        groups.reduce(0) { $0 + $1.selectedCount }
    }
}

// MARK: - Favorites Manager
class FavoritesManager: ObservableObject {
    static let shared = FavoritesManager()

    @Published var favorites: Set<String> = []
    @Published var favoriteImages: [SearchResult] = []
    @Published var isLoading = false

    private let favoritesFileURL: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let searchyDir = appSupport.appendingPathComponent("searchy")
        try? FileManager.default.createDirectory(at: searchyDir, withIntermediateDirectories: true)
        favoritesFileURL = searchyDir.appendingPathComponent("favorites.json")
        loadFavorites()
    }

    private func loadFavorites() {
        guard FileManager.default.fileExists(atPath: favoritesFileURL.path) else { return }
        do {
            let data = try Data(contentsOf: favoritesFileURL)
            let paths = try JSONDecoder().decode([String].self, from: data)
            favorites = Set(paths)
            refreshFavoriteImages()
        } catch {
            print("Failed to load favorites: \(error)")
        }
    }

    private func saveFavorites() {
        do {
            let data = try JSONEncoder().encode(Array(favorites))
            try data.write(to: favoritesFileURL)
        } catch {
            print("Failed to save favorites: \(error)")
        }
    }

    func toggleFavorite(_ path: String) {
        objectWillChange.send()  // Force UI update
        if favorites.contains(path) {
            favorites.remove(path)
        } else {
            favorites.insert(path)
        }
        saveFavorites()
        refreshFavoriteImages()
    }

    func isFavorite(_ path: String) -> Bool {
        favorites.contains(path)
    }

    func refreshFavoriteImages() {
        isLoading = true
        let currentFavorites = Array(favorites)

        Task.detached(priority: .userInitiated) {
            let images = currentFavorites.compactMap { path -> SearchResult? in
                guard FileManager.default.fileExists(atPath: path) else { return nil }
                let url = URL(fileURLWithPath: path)
                let attrs = try? FileManager.default.attributesOfItem(atPath: path)
                let size = attrs?[.size] as? Int ?? 0
                let date = attrs?[.modificationDate] as? Date
                let dateStr = date.map { ISO8601DateFormatter().string(from: $0) }
                return SearchResult(
                    path: path,
                    similarity: 1.0,
                    size: size,
                    date: dateStr,
                    type: url.pathExtension.lowercased()
                )
            }.sorted { ($0.date ?? "") > ($1.date ?? "") }

            await MainActor.run {
                self.favoriteImages = images
                self.isLoading = false
            }
        }
    }
}

// MARK: - Face Detection & Clustering

// MARK: - Face Data Models (matching Python API)

struct FaceData: Codable, Identifiable {
    let face_id: String
    let image_path: String
    let bbox: FaceBBox
    let confidence: Double
    let thumbnail_path: String?

    var id: String { face_id }
    var imagePath: String { image_path }
    var thumbnailPath: String? { thumbnail_path }

    struct FaceBBox: Codable {
        let x: Int
        let y: Int
        let w: Int
        let h: Int
    }
}

struct FaceCluster: Codable, Identifiable {
    let cluster_id: String
    let name: String
    let face_count: Int
    let thumbnail_path: String?
    let faces: [FaceData]

    var id: String { cluster_id }
    var faceCount: Int { face_count }
    var thumbnailPath: String? { thumbnail_path }
}

struct FaceClustersResponse: Codable {
    let clusters: [FaceCluster]
    let total_clusters: Int
    let total_faces: Int
}

struct FaceScanStatusResponse: Codable {
    let is_scanning: Bool
    let progress: Double
    let status: String
    let total_to_scan: Int
    let scanned_count: Int
    let total_faces: Int
    let total_clusters: Int
}

struct FaceNewCountResponse: Codable {
    let new_count: Int
    let total_indexed: Int
    let already_scanned: Int
}

// Keep legacy types for compatibility with existing views
struct DetectedFace: Codable, Identifiable {
    var id = UUID()
    let imagePath: String
    let boundingBox: CGRect
    var embedding: [Float]?
    var personId: String?

    enum CodingKeys: String, CodingKey {
        case id, imagePath, boundingBox, embedding, personId
    }

    init(id: UUID = UUID(), imagePath: String, boundingBox: CGRect, embedding: [Float]? = nil, personId: String? = nil) {
        self.id = id
        self.imagePath = imagePath
        self.boundingBox = boundingBox
        self.embedding = embedding
        self.personId = personId
    }

    // Create from FaceData (Python API response)
    init(from faceData: FaceData) {
        self.id = UUID()
        self.imagePath = faceData.image_path
        self.boundingBox = CGRect(
            x: CGFloat(faceData.bbox.x),
            y: CGFloat(faceData.bbox.y),
            width: CGFloat(faceData.bbox.w),
            height: CGFloat(faceData.bbox.h)
        )
        self.embedding = nil
        self.personId = nil
    }
}

struct Person: Identifiable {
    let id: String
    var name: String
    var faces: [DetectedFace]
    var thumbnailPath: String?

    var faceCount: Int { faces.count }

    // Create from FaceCluster (Python API response)
    init(from cluster: FaceCluster) {
        self.id = cluster.cluster_id
        self.name = cluster.name
        self.faces = cluster.faces.map { DetectedFace(from: $0) }
        self.thumbnailPath = cluster.thumbnail_path
    }

    init(id: String, name: String, faces: [DetectedFace], thumbnailPath: String? = nil) {
        self.id = id
        self.name = name
        self.faces = faces
        self.thumbnailPath = thumbnailPath
    }
}

class FaceManager: ObservableObject {
    static let shared = FaceManager()

    @Published var people: [Person] = []
    @Published var isScanning = false
    @Published var scanProgress: String = ""
    @Published var scanPercentage: Double = 0
    @Published var totalFacesDetected = 0
    @Published var hasScannedBefore = false
    @Published var newImagesCount = 0

    private let baseURL = "http://localhost:7860"
    private let dataDir = "/Users/ausaf/Library/Application Support/searchy"
    private var statusPollTimer: Timer?

    private init() {
        // Load initial state from Python backend
        Task {
            await loadClustersFromAPI()
            await checkForNewImages()
        }
    }

    // MARK: - API Calls

    /// Check for new indexed images that haven't been scanned
    func checkForNewImages() async {
        guard let url = URL(string: "\(baseURL)/face-new-count?data_dir=\(dataDir.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? dataDir)") else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(FaceNewCountResponse.self, from: data)
            await MainActor.run {
                self.newImagesCount = response.new_count
                self.hasScannedBefore = response.already_scanned > 0
            }
        } catch {
            print("Failed to check new images: \(error)")
        }
    }

    /// Load face clusters from Python backend
    func loadClustersFromAPI() async {
        guard let url = URL(string: "\(baseURL)/face-clusters?data_dir=\(dataDir.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? dataDir)") else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(FaceClustersResponse.self, from: data)
            await MainActor.run {
                self.people = response.clusters.map { Person(from: $0) }
                self.totalFacesDetected = response.total_faces
                self.hasScannedBefore = response.total_faces > 0
            }
        } catch {
            print("Failed to load clusters: \(error)")
        }
    }

    /// Start face scanning via Python backend
    func scanForFaces(fullRescan: Bool = false) {
        guard !isScanning else { return }

        Task {
            await MainActor.run {
                self.isScanning = true
                self.scanProgress = "Starting face scan..."
                self.scanPercentage = 0
            }

            // Call the Python API to start scanning
            guard let url = URL(string: "\(baseURL)/face-scan") else {
                await MainActor.run {
                    self.isScanning = false
                    self.scanProgress = "Error: Invalid URL"
                }
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")

            let body: [String: Any] = [
                "data_dir": dataDir,
                "incremental": !fullRescan
            ]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)

            do {
                let (data, _) = try await URLSession.shared.data(for: request)
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let status = json["status"] as? String {
                    if status == "started" || status == "already_scanning" {
                        // Start polling for status
                        await startStatusPolling()
                    } else if status == "error" {
                        let message = json["message"] as? String ?? "Unknown error"
                        await MainActor.run {
                            self.isScanning = false
                            self.scanProgress = "Error: \(message)"
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.isScanning = false
                    self.scanProgress = "Error: \(error.localizedDescription)"
                }
            }
        }
    }

    /// Start polling for scan status
    private func startStatusPolling() async {
        await MainActor.run {
            self.statusPollTimer?.invalidate()
            self.statusPollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                Task {
                    await self?.pollScanStatus()
                }
            }
        }
    }

    /// Poll scan status from Python backend
    private func pollScanStatus() async {
        guard let url = URL(string: "\(baseURL)/face-scan-status?data_dir=\(dataDir.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? dataDir)") else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(FaceScanStatusResponse.self, from: data)

            await MainActor.run {
                self.scanProgress = response.status
                self.scanPercentage = response.progress
                self.totalFacesDetected = response.total_faces

                if !response.is_scanning {
                    // Scan complete - stop polling and load results
                    self.statusPollTimer?.invalidate()
                    self.statusPollTimer = nil
                    self.isScanning = false
                    self.newImagesCount = 0

                    // Load updated clusters
                    Task {
                        await self.loadClustersFromAPI()
                    }
                }
            }
        } catch {
            print("Failed to poll status: \(error)")
        }
    }

    /// Clear all face data via Python backend
    func clearAllFaces() {
        Task {
            guard let url = URL(string: "\(baseURL)/face-clear?data_dir=\(dataDir.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? dataDir)") else { return }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"

            do {
                let _ = try await URLSession.shared.data(for: request)
                await MainActor.run {
                    self.people = []
                    self.totalFacesDetected = 0
                    self.hasScannedBefore = false
                    self.newImagesCount = 0
                    self.scanProgress = "All face data cleared"
                }
                // Check for new images after clearing
                await checkForNewImages()
            } catch {
                print("Failed to clear faces: \(error)")
            }
        }
    }

    /// Get images for a specific person
    func getImagesForPerson(_ person: Person) -> [SearchResult] {
        let uniquePaths = Set(person.faces.map { $0.imagePath })
        return uniquePaths.compactMap { path -> SearchResult? in
            guard FileManager.default.fileExists(atPath: path) else { return nil }
            let url = URL(fileURLWithPath: path)
            let attrs = try? FileManager.default.attributesOfItem(atPath: path)
            let size = attrs?[.size] as? Int ?? 0
            let date = attrs?[.modificationDate] as? Date
            let dateStr = date.map { ISO8601DateFormatter().string(from: $0) }
            return SearchResult(
                path: path,
                similarity: 1.0,
                size: size,
                date: dateStr,
                type: url.pathExtension.lowercased()
            )
        }.sorted { ($0.date ?? "") > ($1.date ?? "") }
    }

    /// Refresh new images count - call from UI
    func refreshNewImagesCount() {
        Task {
            await checkForNewImages()
        }
    }

    /// Rename a person with a custom name
    func renamePerson(_ person: Person, to newName: String) async -> Bool {
        // Build URL with query parameters
        var components = URLComponents(string: "\(baseURL)/face-rename")
        components?.queryItems = [
            URLQueryItem(name: "cluster_id", value: person.id),
            URLQueryItem(name: "name", value: newName),
            URLQueryItem(name: "data_dir", value: dataDir)
        ]
        guard let url = components?.url else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("Rename response: \(json)")
                if let status = json["status"] as? String, status == "success" {
                    // Update local state - replace entire element to trigger SwiftUI update
                    await MainActor.run {
                        self.objectWillChange.send()
                        if let index = self.people.firstIndex(where: { $0.id == person.id }) {
                            var updatedPerson = self.people[index]
                            updatedPerson.name = newName
                            self.people[index] = updatedPerson
                            print("Updated person at index \(index) to name: \(newName)")
                        } else {
                            print("Person not found in people array: \(person.id)")
                        }
                    }
                    return true
                } else if let error = json["error"] as? String, error.contains("not found") {
                    // Cluster IDs may have changed - reload clusters
                    print("Cluster not found, reloading clusters from API...")
                    await loadClustersFromAPI()
                } else {
                    print("Rename failed - status not success: \(json)")
                }
            }
        } catch {
            print("Failed to rename person: \(error)")
        }
        return false
    }
}

struct ContentView: View {
    @ObservedObject private var searchManager = SearchManager.shared
    @ObservedObject private var duplicatesManager = DuplicatesManager.shared
    @ObservedObject private var favoritesManager = FavoritesManager.shared
    @ObservedObject private var faceManager = FaceManager.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var modelSettings = ModelSettings.shared
    @ObservedObject private var dirManager = DirectoryManager.shared
    @State private var activeTab: AppTab = .search
    @Namespace private var tabAnimation
    @State private var selectedPerson: Person? = nil
    @State private var searchText = ""
    @State private var isIndexing = false
    @State private var indexingProgress = ""
    @State private var indexingProcess: Process? = nil
    @State private var indexingPercent: Double = 0
    @State private var indexingETA: String = ""
    @State private var batchTimes: [Double] = []
    @State private var lastBatchTime: Double = 0
    @State private var indexingReport: IndexingReport? = nil
    @State private var indexingSpeed: Double = 0
    @State private var indexingElapsed: Double = 0
    @State private var indexingBatchInfo: String = ""
    @State private var elapsedTimer: Timer? = nil
    @State private var indexingStartTime: Date? = nil
    @State private var indexStats: IndexStats? = nil
    @State private var isShowingSettings = false
    @State private var filterTypes: Set<String> = []
    @State private var filterSizeMin: Int? = nil
    @State private var filterSizeMax: Int? = nil
    @State private var filterDateFrom: Date? = nil
    @State private var filterDateTo: Date? = nil
    @State private var searchDebounceTimer: Timer?
    @State private var recentImages: [SearchResult] = []
    @State private var isLoadingRecent = false
    @State private var pastedImage: NSImage? = nil
    @State private var isDropTargeted = false
    @State private var keyMonitor: Any? = nil
    @State private var previewResult: SearchResult? = nil
    @State private var previewTimer: Timer? = nil
    @State private var showPreviewPanel = false
    @State private var previewPanelWidth: CGFloat = 300
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            // Clean solid background
            (colorScheme == .dark ? Color(hex: "000000") : Color(hex: "FFFFFF"))
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Friendly header
                modernHeader

                // Tab Picker
                tabPicker
                    .padding(.top, DesignSystem.Spacing.md)

                // Main content area based on active tab
                switch activeTab {
                case .faces:
                    facesTabContent
                case .search:
                    searchTabContent
                case .duplicates:
                    duplicatesTabContent
                case .favorites:
                    favoritesTabContent
                case .setup:
                    setupTabContent
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
                .frame(width: 680, height: 760)
        }
        .onAppear {
            loadRecentImages()
            loadIndexStats()
            setupPasteMonitor()
            // Focus the search field on appear
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isSearchFocused = true
            }
        }
        .onDisappear {
            searchManager.cancelSearch()
            removePasteMonitor()
        }
    }

    // MARK: - Header (Friendly, Craft-style)
    private var modernHeader: some View {
        HStack(spacing: DesignSystem.Spacing.lg) {
            // Friendly logo - warm, inviting
            HStack(spacing: 10) {
                // Photo icon instead of tech magnifying glass
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(DesignSystem.Colors.accent.opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: "photo.stack.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.accent)
                }
                Text("Searchy")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(DesignSystem.Colors.primaryText)
            }

            Spacer()

            // Friendly icon buttons
            HStack(spacing: DesignSystem.Spacing.sm) {
                // Indexing indicator (only when active)
                if isIndexing {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text("\(Int(indexingPercent))%")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                    }
                    .foregroundColor(DesignSystem.Colors.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(DesignSystem.Colors.accent.opacity(0.1))
                    .clipShape(Capsule())
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }

                MinimalIconButton(icon: "plus", tooltip: "Add folder") {
                    if !isIndexing { selectAndIndexFolder() }
                }
                .disabled(isIndexing)

                MinimalIconButton(icon: "arrow.clockwise", tooltip: "Rebuild index") {
                    if !isIndexing { rebuildIndex() }
                }
                .disabled(isIndexing)

                MinimalIconButton(icon: "gearshape", tooltip: "Settings") {
                    isShowingSettings = true
                }

                // Theme switcher - compact
                ThemeSwitcherCompact()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Tab Picker (Minimal)
    private var tabPicker: some View {
        HStack(spacing: 2) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                tabButton(for: tab)
            }
        }
        .padding(3)
        .background(
            colorScheme == .dark ?
                Color.white.opacity(0.04) :
                Color.black.opacity(0.03)
        )
        .clipShape(RoundedRectangle(cornerRadius: 11))
    }

    private func tabButton(for tab: AppTab) -> some View {
        let isActive = activeTab == tab

        return Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                activeTab = tab
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.system(size: 13, weight: .medium))
                Text(tab.rawValue)
                    .font(.system(size: 13, weight: isActive ? .semibold : .medium))
            }
            .foregroundColor(isActive ? DesignSystem.Colors.accent : DesignSystem.Colors.tertiaryText)
            .scaleEffect(isActive ? 1.08 : 1.0)
            .padding(.horizontal, 18)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            ZStack {
                if isActive {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(DesignSystem.Colors.accent.opacity(0.12))
                        .matchedGeometryEffect(id: "activeTab", in: tabAnimation)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }

    // MARK: - Faces Tab Content
    private var facesTabContent: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("People")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(DesignSystem.Colors.primaryText)
                    if faceManager.totalFacesDetected > 0 {
                        Text("\(faceManager.people.count) people • \(faceManager.totalFacesDetected) faces")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                }

                Spacer()

                if faceManager.hasScannedBefore && !faceManager.isScanning {
                    Button(action: {
                        faceManager.clearAllFaces()
                    }) {
                        Text("Clear")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.trailing, 8)
                }

                // Show new images badge if there are unscanned images
                if faceManager.newImagesCount > 0 && !faceManager.isScanning {
                    Text("\(faceManager.newImagesCount) new")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.orange))
                        .padding(.trailing, 4)
                }

                Button(action: {
                    if faceManager.isScanning {
                        // Could add cancel functionality
                    } else {
                        faceManager.scanForFaces()
                    }
                }) {
                    HStack(spacing: 6) {
                        if faceManager.isScanning {
                            ProgressView()
                                .scaleEffect(0.6)
                                .frame(width: 14, height: 14)
                        } else {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 12, weight: .medium))
                        }
                        Text(faceManager.isScanning ? "Scanning..." :
                             (faceManager.newImagesCount > 0 ? "Scan New" : "Scan Faces"))
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(faceManager.isScanning ? Color.gray : DesignSystem.Colors.accent)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(faceManager.isScanning)
            }
            .padding(.bottom, DesignSystem.Spacing.md)
            .onAppear {
                faceManager.refreshNewImagesCount()
            }

            // Scanning progress
            if faceManager.isScanning {
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        // Animated face icon
                        ZStack {
                            Circle()
                                .fill(DesignSystem.Colors.accent.opacity(0.1))
                                .frame(width: 44, height: 44)
                            Image(systemName: "faceid")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.accent)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Scanning for faces...")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(DesignSystem.Colors.primaryText)
                            Text(faceManager.scanProgress)
                                .font(.system(size: 11))
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                                .lineLimit(1)
                        }

                        Spacer()

                        Text("\(Int(faceManager.scanPercentage * 100))%")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(DesignSystem.Colors.accent)
                    }

                    // Modern progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(DesignSystem.Colors.tertiaryBackground)
                                .frame(height: 6)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [DesignSystem.Colors.accent, DesignSystem.Colors.accent.opacity(0.7)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * faceManager.scanPercentage, height: 6)
                                .animation(.easeInOut(duration: 0.3), value: faceManager.scanPercentage)
                        }
                    }
                    .frame(height: 6)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(DesignSystem.Colors.secondaryBackground)
                        .shadow(color: Color.black.opacity(0.05), radius: 8, y: 2)
                )
                .padding(.bottom, DesignSystem.Spacing.lg)
            }

            // Content
            if selectedPerson != nil {
                personDetailView
            } else if faceManager.people.isEmpty && !faceManager.isScanning {
                // Empty state - modern card design
                VStack(spacing: 24) {
                    Spacer()

                    // Icon with gradient background
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        DesignSystem.Colors.accent.opacity(0.15),
                                        DesignSystem.Colors.accent.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)

                        Image(systemName: "person.2.crop.square.stack")
                            .font(.system(size: 48, weight: .light))
                            .foregroundColor(DesignSystem.Colors.accent.opacity(0.7))
                    }

                    VStack(spacing: 8) {
                        Text("Face Recognition")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(DesignSystem.Colors.primaryText)

                        Text(faceManager.hasScannedBefore
                             ? "No faces found in your photos.\nTry scanning more images."
                             : "Find and group people in your photos\nusing AI-powered face detection.")
                            .font(.system(size: 14))
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                    }

                    if !faceManager.hasScannedBefore {
                        Button(action: {
                            faceManager.scanForFaces()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "faceid")
                                    .font(.system(size: 14, weight: .medium))
                                Text("Start Scanning")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(
                                        LinearGradient(
                                            colors: [DesignSystem.Colors.accent, DesignSystem.Colors.accent.opacity(0.8)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .shadow(color: DesignSystem.Colors.accent.opacity(0.3), radius: 8, y: 4)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.top, 8)
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // People grid
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 140, maximum: 160), spacing: 20)
                    ], spacing: 20) {
                        ForEach(faceManager.people) { person in
                            PersonCard(
                                person: person,
                                onRename: { newName in
                                    Task {
                                        await faceManager.renamePerson(person, to: newName)
                                    }
                                },
                                onSelect: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedPerson = person
                                    }
                                }
                            )
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @State private var isEditingPersonName = false
    @State private var editingPersonName = ""
    @FocusState private var personNameFieldFocused: Bool

    private var personDetailView: some View {
        VStack(spacing: 0) {
            // Header with back button, name, and photo count
            HStack(alignment: .center, spacing: 12) {
                // Back button
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedPerson = nil
                        isEditingPersonName = false
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.accent)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(DesignSystem.Colors.accent.opacity(0.1))
                        )
                }
                .buttonStyle(PlainButtonStyle())

                if let person = selectedPerson {
                    // Person name (editable)
                    if isEditingPersonName {
                        TextField("Name", text: $editingPersonName)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(DesignSystem.Colors.primaryText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(DesignSystem.Colors.tertiaryBackground)
                            )
                            .focused($personNameFieldFocused)
                            .onSubmit { commitPersonNameEdit() }
                            .onExitCommand { cancelPersonNameEdit() }
                            .frame(maxWidth: 200)
                    } else {
                        HStack(spacing: 6) {
                            Text(person.name)
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(DesignSystem.Colors.primaryText)
                                .lineLimit(1)

                            Button(action: { startPersonNameEdit() }) {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(DesignSystem.Colors.accent.opacity(0.7))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }

                    Spacer()

                    // Photo count badge
                    HStack(spacing: 4) {
                        Image(systemName: "photo.stack")
                            .font(.system(size: 12))
                        Text("\(person.faceCount) photos")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(DesignSystem.Colors.tertiaryBackground)
                    )
                }
            }
            .padding(.bottom, DesignSystem.Spacing.lg)

            // Person's photos grid
            if let person = selectedPerson {
                let images = faceManager.getImagesForPerson(person)
                if images.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 48, weight: .light))
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                        Text("No photos available")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                        Spacer()
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.adaptive(minimum: 160, maximum: 220), spacing: 16)
                        ], spacing: 16) {
                            ForEach(images) { result in
                                ImageCard(result: result, onFindSimilar: { _ in })
                            }
                        }
                        .padding(.bottom, 20)
                    }
                }
            }
        }
    }

    private func startPersonNameEdit() {
        guard let person = selectedPerson else { return }
        editingPersonName = person.name
        isEditingPersonName = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            personNameFieldFocused = true
        }
    }

    private func commitPersonNameEdit() {
        let trimmed = editingPersonName.trimmingCharacters(in: .whitespaces)
        if let person = selectedPerson, !trimmed.isEmpty && trimmed != person.name {
            Task {
                let success = await faceManager.renamePerson(person, to: trimmed)
                if success {
                    // Update local selectedPerson reference
                    await MainActor.run {
                        if let updated = faceManager.people.first(where: { $0.id == person.id }) {
                            selectedPerson = updated
                        }
                    }
                }
            }
        }
        isEditingPersonName = false
    }

    private func cancelPersonNameEdit() {
        isEditingPersonName = false
        editingPersonName = selectedPerson?.name ?? ""
    }

    // MARK: - Favorites Tab Content
    private var favoritesTabContent: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Favorites")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(DesignSystem.Colors.primaryText)

                    Text("\(favoritesManager.favoriteImages.count) images")
                        .font(DesignSystem.Typography.callout)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }

                Spacer()
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.md)

            if favoritesManager.isLoading {
                Spacer()
                ProgressView()
                    .scaleEffect(1.2)
                Spacer()
            } else if favoritesManager.favoriteImages.isEmpty {
                Spacer()
                VStack(spacing: DesignSystem.Spacing.lg) {
                    Image(systemName: "heart.slash")
                        .font(.system(size: 64, weight: .light))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)

                    Text("No Favorites Yet")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(DesignSystem.Colors.primaryText)

                    Text("Hover over any image and click the heart\nto add it to your favorites.")
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .multilineTextAlignment(.center)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 20),
                        GridItem(.flexible(), spacing: 20),
                        GridItem(.flexible(), spacing: 20),
                        GridItem(.flexible(), spacing: 20)
                    ], spacing: 24) {
                        ForEach(favoritesManager.favoriteImages) { result in
                            ImageCard(
                                result: result,
                                showSimilarity: false,
                                onFindSimilar: { path in
                                    activeTab = .search
                                    searchManager.findSimilar(imagePath: path)
                                }
                            )
                        }
                    }
                    .padding(DesignSystem.Spacing.lg)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            favoritesManager.refreshFavoriteImages()
        }
    }

    // MARK: - Setup Tab Content
    private var setupTabContent: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.xxl) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Setup")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(DesignSystem.Colors.primaryText)

                        Text("Configure your search index and AI model")
                            .font(DesignSystem.Typography.callout)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                    Spacer()
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.top, DesignSystem.Spacing.md)

                // Three column layout for cards
                HStack(alignment: .top, spacing: DesignSystem.Spacing.xl) {
                    // Model Card
                    setupModelCard

                    // Directories Card
                    setupDirectoriesCard

                    // Stats Card
                    setupStatsCard
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)

                Spacer()
            }
            .padding(.bottom, DesignSystem.Spacing.xxl)
        }
    }

    private var setupModelCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Card Header
            HStack {
                Image(systemName: "cpu")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.accent)
                Text("AI Model")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                Spacer()
                if modelSettings.isChangingModel {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }

            Divider()

            // Current Model
            if modelSettings.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading model info...")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
                .padding(DesignSystem.Spacing.sm)
            } else if modelSettings.currentModelName.isEmpty {
                // No model loaded
                VStack(spacing: DesignSystem.Spacing.sm) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text("No model loaded")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }

                    Button(action: {
                        // Load the default model
                        modelSettings.changeModel(to: "openai/clip-vit-base-patch32") { _, _ in }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 10))
                            Text("Load Default Model")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(DesignSystem.Colors.accent)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(DesignSystem.Spacing.sm)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.orange.opacity(0.08))
                )
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text(modelSettings.currentModelDisplayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.accent)

                    HStack(spacing: DesignSystem.Spacing.md) {
                        Label(modelSettings.currentDevice, systemImage: "cpu")
                        Label("\(modelSettings.currentEmbeddingDim)-dim", systemImage: "number")
                    }
                    .font(.system(size: 11))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                }
                .padding(DesignSystem.Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(DesignSystem.Colors.accent.opacity(0.08))
                )
            }

            // Model Selection
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text("Available Models")
                    .font(DesignSystem.Typography.caption.weight(.medium))
                    .foregroundColor(DesignSystem.Colors.secondaryText)

                ForEach(modelSettings.availableModels) { model in
                    SetupModelRow(
                        model: model,
                        isSelected: modelSettings.currentModelName == model.id,
                        isChanging: modelSettings.isChangingModel
                    ) {
                        changeModelFromSetup(to: model.id, newDim: model.embeddingDim)
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "2C2C2E") : .white)
                .shadow(color: Color.black.opacity(0.06), radius: 12, y: 4)
        )
        .frame(maxWidth: .infinity)
        .onAppear {
            modelSettings.fetchCurrentModel()
        }
    }

    private var setupDirectoriesCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Card Header
            HStack {
                Image(systemName: "folder")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.accent)
                Text("Watched Directories")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                Spacer()
                Button(action: { addNewDirectory() }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(DesignSystem.Colors.accent)
                }
                .buttonStyle(PlainButtonStyle())
            }

            Divider()

            // Directory List
            if dirManager.watchedDirectories.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                    Text("No directories added")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.xl)
            } else {
                VStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(dirManager.watchedDirectories) { directory in
                        SetupDirectoryRow(directory: directory) {
                            dirManager.removeDirectory(directory)
                        }
                    }
                }
            }

            // Quick add button
            Button(action: { addNewDirectory() }) {
                HStack {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Add Directory")
                        .font(DesignSystem.Typography.caption.weight(.medium))
                }
                .foregroundColor(DesignSystem.Colors.accent)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(DesignSystem.Colors.accent.opacity(0.3), lineWidth: 1)
                        .background(DesignSystem.Colors.accent.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(DesignSystem.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "2C2C2E") : .white)
                .shadow(color: Color.black.opacity(0.06), radius: 12, y: 4)
        )
        .frame(maxWidth: .infinity)
    }

    private var setupStatsCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Card Header
            HStack {
                Image(systemName: "chart.bar")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.accent)
                Text("Index Stats")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                Spacer()
                Button(action: { loadIndexStats() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
                .buttonStyle(PlainButtonStyle())
            }

            Divider()

            if let stats = indexStats {
                VStack(spacing: DesignSystem.Spacing.md) {
                    // Total Images
                    SetupStatRow(
                        icon: "photo.stack",
                        label: "Total Images",
                        value: "\(stats.totalImages.formatted())",
                        color: DesignSystem.Colors.accent
                    )

                    // Index Size
                    SetupStatRow(
                        icon: "externaldrive",
                        label: "Index Size",
                        value: stats.fileSize,
                        color: .orange
                    )

                    // Last Updated
                    if let lastMod = stats.lastModified {
                        SetupStatRow(
                            icon: "clock",
                            label: "Last Updated",
                            value: formatRelativeDate(lastMod),
                            color: .green
                        )
                    }

                    // Directories Count
                    SetupStatRow(
                        icon: "folder",
                        label: "Directories",
                        value: "\(dirManager.watchedDirectories.count)",
                        color: .purple
                    )
                }
            } else {
                VStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading stats...")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.xl)
            }

            Divider()

            // Quick Actions
            VStack(spacing: DesignSystem.Spacing.sm) {
                Button(action: { if !isIndexing { selectAndIndexFolder() } }) {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("Add to Index")
                        Spacer()
                    }
                    .font(DesignSystem.Typography.caption.weight(.medium))
                    .foregroundColor(DesignSystem.Colors.accent)
                    .padding(DesignSystem.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(DesignSystem.Colors.accent.opacity(0.08))
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isIndexing)

                Button(action: { if !isIndexing { rebuildIndex() } }) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Rebuild Index")
                        Spacer()
                    }
                    .font(DesignSystem.Typography.caption.weight(.medium))
                    .foregroundColor(.orange)
                    .padding(DesignSystem.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.orange.opacity(0.08))
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isIndexing)
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "2C2C2E") : .white)
                .shadow(color: Color.black.opacity(0.06), radius: 12, y: 4)
        )
        .frame(maxWidth: .infinity)
    }

    private func formatRelativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func addNewDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select a directory to watch for images"

        if panel.runModal() == .OK, let url = panel.url {
            let newDir = WatchedDirectory(path: url.path)
            dirManager.addDirectory(newDir)
        }
    }

    @State private var showingModelChangeAlert = false
    @State private var pendingModelChange: (id: String, dim: Int)?

    private func changeModelFromSetup(to modelId: String, newDim: Int) {
        guard modelId != modelSettings.currentModelName else { return }

        // Check if embedding dimension changes (requires reindex)
        if newDim != modelSettings.currentEmbeddingDim {
            pendingModelChange = (modelId, newDim)
            showingModelChangeAlert = true
        } else {
            modelSettings.changeModel(to: modelId) { _, _ in }
        }
    }

    // MARK: - Search Tab Content
    private var searchTabContent: some View {
        VStack(spacing: 20) {
            // Show indexing progress or search bar
            if isIndexing {
                indexingProgressView
            } else if let report = indexingReport {
                indexingReportView(report)
            } else {
                modernSearchBar
                    .padding(.top, 12)
            }

            // Filter bar (show when there are results or recent images)
            if (!searchManager.results.isEmpty || !recentImages.isEmpty) && !searchManager.isSearching && !isIndexing {
                filterBar
            }

            errorView

            // Results area with optional preview panel
            HStack(alignment: .top, spacing: 16) {
                // Results
                Group {
                    if searchManager.isSearching {
                        VStack {
                            Spacer()
                            ProgressView()
                            Text("Searching...")
                                .font(.system(size: 13))
                                .foregroundColor(DesignSystem.Colors.tertiaryText)
                                .padding(.top, 8)
                            Spacer()
                        }
                    } else if !searchManager.results.isEmpty {
                        ScrollView {
                            filteredResultsList
                                .padding(.horizontal, DesignSystem.Spacing.xl)
                        }
                    } else if searchText.isEmpty {
                        recentImagesSection
                    } else {
                        emptyStateView
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Preview panel (appears after 500ms hover)
                if showPreviewPanel, let result = previewResult {
                    ResizablePreviewPanel(
                        result: result,
                        width: $previewPanelWidth,
                        isVisible: $showPreviewPanel,
                        style: .app
                    )
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .onChange(of: showPreviewPanel) { _, newValue in
                        if !newValue {
                            previewResult = nil
                        }
                    }
                }
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.xl)
        .padding(.top, 8)
    }

    // MARK: - Preview Hover Handling
    private func handlePreviewHoverStart(_ result: SearchResult) {
        previewTimer?.invalidate()
        previewTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            withAnimation(.easeOut(duration: 0.2)) {
                previewResult = result
                showPreviewPanel = true
            }
        }
    }

    private func handlePreviewHoverEnd() {
        previewTimer?.invalidate()
        previewTimer = nil
        // Keep panel visible when hovering different items - only hide when mouse leaves all results
    }

    // MARK: - Filtered Results
    private func applyFilters(to results: [SearchResult]) -> [SearchResult] {
        results.filter { result in
            // Type filter
            if !filterTypes.isEmpty {
                if !filterTypes.contains(result.fileExtension) {
                    return false
                }
            }

            // Size filter
            if let minSize = filterSizeMin, let resultSize = result.size {
                if resultSize < minSize { return false }
            }
            if let maxSize = filterSizeMax, let resultSize = result.size {
                if resultSize > maxSize { return false }
            }

            // Date filter
            if let dateStr = result.date,
               let resultDate = ISO8601DateFormatter().date(from: dateStr) {
                if let fromDate = filterDateFrom, resultDate < fromDate {
                    return false
                }
                if let toDate = filterDateTo, resultDate > toDate {
                    return false
                }
            }

            return true
        }
    }

    private var filteredResults: [SearchResult] {
        applyFilters(to: searchManager.results)
    }

    private var filteredRecentImages: [SearchResult] {
        applyFilters(to: recentImages)
    }

    private var displayedResults: [SearchResult] {
        searchManager.results.isEmpty ? filteredRecentImages : filteredResults
    }

    private var filteredResultsList: some View {
        let results = filteredResults.filter { result in
            result.similarity >= SearchPreferences.shared.similarityThreshold
        }

        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            // Stats header
            if SearchPreferences.shared.showStats, let stats = searchManager.searchStats {
                HStack(spacing: DesignSystem.Spacing.lg) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                        Text(stats.total_time)
                            .font(DesignSystem.Typography.caption)
                    }
                    .foregroundColor(DesignSystem.Colors.secondaryText)

                    HStack(spacing: 4) {
                        Image(systemName: "photo.stack")
                            .font(.system(size: 11))
                        Text("\(stats.images_searched)")
                            .font(DesignSystem.Typography.caption)
                    }
                    .foregroundColor(DesignSystem.Colors.secondaryText)

                    HStack(spacing: 4) {
                        Image(systemName: "speedometer")
                            .font(.system(size: 11))
                        Text("\(stats.images_per_second) img/s")
                            .font(DesignSystem.Typography.caption)
                    }
                    .foregroundColor(DesignSystem.Colors.secondaryText)

                    if filteredResults.count != searchManager.results.count {
                        HStack(spacing: 4) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(.system(size: 11))
                            Text("\(filteredResults.count)/\(searchManager.results.count)")
                                .font(DesignSystem.Typography.caption)
                        }
                        .foregroundColor(DesignSystem.Colors.accent)
                    }
                    Spacer()
                }
                .padding(.bottom, DesignSystem.Spacing.sm)
            }

            MasonryGrid(items: results, columns: 4, spacing: 12) { result in
                MasonryImageCard(
                    result: result,
                    showSimilarity: true,
                    onFindSimilar: { path in
                        searchManager.findSimilar(imagePath: path)
                    },
                    onHoverStart: handlePreviewHoverStart,
                    onHoverEnd: handlePreviewHoverEnd
                )
            }
        }
    }

    // MARK: - Filter Bar (Minimal Capsules)
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Type filters
                ForEach(["JPG", "PNG", "GIF", "HEIC"], id: \.self) { type in
                    FilterCapsule(
                        label: type,
                        isActive: filterTypes.contains(type.lowercased()),
                        action: {
                            if filterTypes.contains(type.lowercased()) {
                                filterTypes.remove(type.lowercased())
                            } else {
                                filterTypes.insert(type.lowercased())
                            }
                        }
                    )
                }

                Divider()
                    .frame(height: 16)
                    .opacity(0.3)

                // Size filters
                FilterCapsule(
                    label: "Small",
                    isActive: filterSizeMax == 100 * 1024,
                    action: {
                        if filterSizeMax == 100 * 1024 {
                            filterSizeMin = nil; filterSizeMax = nil
                        } else {
                            filterSizeMin = nil; filterSizeMax = 100 * 1024
                        }
                    }
                )
                FilterCapsule(
                    label: "Large",
                    isActive: filterSizeMin == 1024 * 1024,
                    action: {
                        if filterSizeMin == 1024 * 1024 {
                            filterSizeMin = nil; filterSizeMax = nil
                        } else {
                            filterSizeMin = 1024 * 1024; filterSizeMax = nil
                        }
                    }
                )

                Divider()
                    .frame(height: 16)
                    .opacity(0.3)

                // Date filters
                FilterCapsule(
                    label: "Today",
                    isActive: filterDateFrom == Calendar.current.startOfDay(for: Date()),
                    action: {
                        if filterDateFrom == Calendar.current.startOfDay(for: Date()) {
                            filterDateFrom = nil; filterDateTo = nil
                        } else {
                            filterDateFrom = Calendar.current.startOfDay(for: Date()); filterDateTo = nil
                        }
                    }
                )
                FilterCapsule(
                    label: "This Week",
                    isActive: dateFilterLabel == "This Week",
                    action: {
                        if dateFilterLabel == "This Week" {
                            filterDateFrom = nil; filterDateTo = nil
                        } else {
                            filterDateFrom = Calendar.current.date(byAdding: .day, value: -7, to: Date()); filterDateTo = nil
                        }
                    }
                )

                // Clear all (only when filters active)
                if activeFilterCount > 0 {
                    Button(action: clearFilters) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var sizeFilterLabel: String {
        if filterSizeMin == nil && filterSizeMax == nil { return "Size" }
        if filterSizeMax == 100 * 1024 { return "Small" }
        if filterSizeMin == 100 * 1024 && filterSizeMax == 1024 * 1024 { return "Medium" }
        if filterSizeMin == 1024 * 1024 { return "Large" }
        return "Size"
    }

    private var dateFilterLabel: String {
        if filterDateFrom == nil && filterDateTo == nil { return "Date" }
        if let from = filterDateFrom {
            let days = Calendar.current.dateComponents([.day], from: from, to: Date()).day ?? 0
            if days <= 1 { return "Today" }
            if days <= 7 { return "This Week" }
            if days <= 31 { return "This Month" }
            return "This Year"
        }
        return "Date"
    }

    private var activeFilterCount: Int {
        var count = 0
        if !filterTypes.isEmpty { count += 1 }
        if filterSizeMin != nil || filterSizeMax != nil { count += 1 }
        if filterDateFrom != nil || filterDateTo != nil { count += 1 }
        return count
    }

    private var sizeRangeText: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file

        if let min = filterSizeMin, let max = filterSizeMax {
            return "\(formatter.string(fromByteCount: Int64(min))) - \(formatter.string(fromByteCount: Int64(max)))"
        } else if let min = filterSizeMin {
            return "> \(formatter.string(fromByteCount: Int64(min)))"
        } else if let max = filterSizeMax {
            return "< \(formatter.string(fromByteCount: Int64(max)))"
        }
        return ""
    }

    private func clearFilters() {
        filterTypes.removeAll()
        filterSizeMin = nil
        filterSizeMax = nil
        filterDateFrom = nil
        filterDateTo = nil
    }

    // MARK: - Duplicates Tab Content
    @State private var showMovePanel = false
    @State private var actionFeedback: String? = nil
    @State private var previewImagePath: String? = nil

    private var duplicatesTabContent: some View {
        ZStack {
            VStack(spacing: 0) {
                // Duplicates header
                duplicatesHeader
                    .padding(.horizontal, DesignSystem.Spacing.xl)
                    .padding(.top, DesignSystem.Spacing.lg)

                // Content
                if duplicatesManager.isScanning {
                    VStack(spacing: DesignSystem.Spacing.md) {
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Scanning for duplicates...")
                            .font(DesignSystem.Typography.callout)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                        Text("This may take a moment for large libraries")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                        Spacer()
                    }
                } else if let error = duplicatesManager.errorMessage {
                    VStack(spacing: DesignSystem.Spacing.md) {
                        Spacer()
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(DesignSystem.Colors.warning)
                        Text("Error scanning")
                            .font(DesignSystem.Typography.headline)
                        Text(error)
                            .font(DesignSystem.Typography.callout)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                            .multilineTextAlignment(.center)
                        Spacer()
                    }
                    .padding()
                } else if duplicatesManager.groups.isEmpty {
                    duplicatesEmptyState
                } else {
                    duplicatesResultsList
                }

                // Action bar
                if !duplicatesManager.groups.isEmpty && duplicatesManager.totalSelected > 0 {
                    duplicatesActionBar
                }

                // Feedback toast
                if let feedback = actionFeedback {
                    Text(feedback)
                        .font(DesignSystem.Typography.callout)
                        .foregroundColor(.white)
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        .padding(.vertical, DesignSystem.Spacing.md)
                        .background(Capsule().fill(DesignSystem.Colors.success))
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, DesignSystem.Spacing.md)
                }
            }

            // Image preview overlay
            if let previewPath = previewImagePath {
                imagePreviewOverlay(path: previewPath)
            }
        }
    }

    private func imagePreviewOverlay(path: String) -> some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.2)) {
                        previewImagePath = nil
                    }
                }

            VStack(spacing: DesignSystem.Spacing.lg) {
                // Close button
                HStack {
                    Spacer()
                    Button(action: {
                        withAnimation(.easeOut(duration: 0.2)) {
                            previewImagePath = nil
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding()
                }

                Spacer()

                // Preview image
                if let nsImage = NSImage(contentsOfFile: path) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 600, maxHeight: 500)
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg))
                        .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
                }

                // File info
                VStack(spacing: DesignSystem.Spacing.xs) {
                    Text(URL(fileURLWithPath: path).lastPathComponent)
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(.white)

                    Text(formattedFileSize(for: path))
                        .font(DesignSystem.Typography.callout)
                        .foregroundColor(.white.opacity(0.7))
                }

                // Action buttons
                HStack(spacing: DesignSystem.Spacing.lg) {
                    Button(action: {
                        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
                    }) {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: "folder")
                            Text("Reveal in Finder")
                        }
                        .font(DesignSystem.Typography.callout)
                        .foregroundColor(.white)
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        .padding(.vertical, DesignSystem.Spacing.md)
                        .background(Capsule().fill(Color.white.opacity(0.2)))
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: {
                        NSWorkspace.shared.open(URL(fileURLWithPath: path))
                    }) {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: "arrow.up.right.square")
                            Text("Open")
                        }
                        .font(DesignSystem.Typography.callout)
                        .foregroundColor(.white)
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        .padding(.vertical, DesignSystem.Spacing.md)
                        .background(Capsule().fill(DesignSystem.Colors.accent))
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                Spacer()
            }
        }
        .transition(.opacity)
    }

    private func formattedFileSize(for path: String) -> String {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attrs[.size] as? Int64 else {
            return ""
        }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    private var duplicatesHeader: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.on.square.badge.person.crop")
                            .font(.system(size: 18, weight: .medium))
                        Text("Find Duplicates")
                            .font(DesignSystem.Typography.title2)
                    }
                    .foregroundColor(DesignSystem.Colors.primaryText)

                    if !duplicatesManager.groups.isEmpty {
                        Text("\(duplicatesManager.totalDuplicates) duplicate\(duplicatesManager.totalDuplicates == 1 ? "" : "s") in \(duplicatesManager.groups.count) group\(duplicatesManager.groups.count == 1 ? "" : "s")")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                }

                Spacer()

                // Threshold slider
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Text("Similarity:")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)

                    Slider(value: $duplicatesManager.threshold, in: 0.85...0.99, step: 0.01)
                        .frame(width: 100)

                    Text("\(Int(duplicatesManager.threshold * 100))%")
                        .font(DesignSystem.Typography.caption.monospacedDigit())
                        .foregroundColor(DesignSystem.Colors.accent)
                        .frame(width: 35)
                }

                Button(action: { duplicatesManager.scanForDuplicates() }) {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Scan")
                    }
                    .font(DesignSystem.Typography.callout.weight(.medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(
                        Capsule()
                            .fill(DesignSystem.Colors.accent)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(duplicatesManager.isScanning)
            }

            // Quick actions when groups exist
            if !duplicatesManager.groups.isEmpty {
                HStack {
                    Button(action: { duplicatesManager.autoSelectAllSmaller() }) {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: "checkmark.circle")
                            Text("Auto-select smaller files")
                        }
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.accent)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Spacer()
                }
            }
        }
        .padding(.bottom, DesignSystem.Spacing.md)
    }

    private var duplicatesEmptyState: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Spacer()

            Image(systemName: "square.on.square.dashed")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(DesignSystem.Colors.tertiaryText)

            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("No duplicates found")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(DesignSystem.Colors.primaryText)

                Text("Click Scan to search your indexed images for duplicates")
                    .font(DesignSystem.Typography.callout)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding()
    }

    private var duplicatesResultsList: some View {
        ScrollView {
            LazyVStack(spacing: DesignSystem.Spacing.lg) {
                ForEach(duplicatesManager.groups) { group in
                    duplicateGroupCard(group)
                }
            }
            .padding(DesignSystem.Spacing.xl)
        }
    }

    private func duplicateGroupCard(_ group: DuplicateGroup) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Group header
            HStack {
                Text("Group \(group.id)")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(DesignSystem.Colors.primaryText)

                Text("\(group.images.count) images")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.secondaryText)

                Spacer()

                Button(action: { duplicatesManager.autoSelectSmaller(groupId: group.id) }) {
                    Text("Keep largest")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.accent)
                }
                .buttonStyle(PlainButtonStyle())
            }

            // Images grid
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: DesignSystem.Spacing.md)], spacing: DesignSystem.Spacing.md) {
                ForEach(Array(group.images.enumerated()), id: \.element.path) { index, image in
                    duplicateImageCard(image, isFirst: index == 0, groupId: group.id)
                }
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(colorScheme == .dark ? DesignSystem.Colors.darkSecondaryBackground : DesignSystem.Colors.secondaryBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .stroke(DesignSystem.Colors.border, lineWidth: 1)
        )
    }

    private func duplicateImageCard(_ image: DuplicateImage, isFirst: Bool, groupId: Int) -> some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            // Image thumbnail
            ZStack(alignment: .topLeading) {
                // Clickable image area
                ZStack {
                    Rectangle()
                        .fill(colorScheme == .dark ? Color.black.opacity(0.3) : Color.gray.opacity(0.1))

                    AsyncThumbnailView(path: image.path, contentMode: .fit)
                }
                .frame(height: 140)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                        .stroke(image.isSelected ? DesignSystem.Colors.error : (isFirst ? DesignSystem.Colors.success : DesignSystem.Colors.border.opacity(0.5)), lineWidth: image.isSelected || isFirst ? 2 : 1)
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.2)) {
                        previewImagePath = image.path
                    }
                }

                // Top row: Badge on left, checkbox on right
                HStack {
                    // Best quality badge
                    if isFirst {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 8))
                            Text("Best")
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(DesignSystem.Colors.success))
                    }

                    Spacer()

                    // Selection checkbox
                    Button(action: {
                        duplicatesManager.toggleSelection(groupId: groupId, imagePath: image.path)
                    }) {
                        ZStack {
                            Circle()
                                .fill(image.isSelected ? DesignSystem.Colors.error : Color.white.opacity(0.9))
                                .frame(width: 24, height: 24)
                                .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)

                            if image.isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            } else {
                                Circle()
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1.5)
                                    .frame(width: 22, height: 22)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(DesignSystem.Spacing.sm)

                // Preview hint on hover
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: "eye.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                        Spacer()
                    }
                    .padding(.bottom, DesignSystem.Spacing.sm)
                }
                .opacity(0.7)
            }

            // Image info
            VStack(alignment: .leading, spacing: 3) {
                Text(URL(fileURLWithPath: image.path).lastPathComponent)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.primaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 6) {
                    // Size with icon
                    HStack(spacing: 2) {
                        Image(systemName: "doc")
                            .font(.system(size: 9))
                        Text(image.formattedSize)
                    }
                    .font(DesignSystem.Typography.caption2)
                    .foregroundColor(isFirst ? DesignSystem.Colors.success : DesignSystem.Colors.secondaryText)

                    // Match percentage
                    HStack(spacing: 2) {
                        Image(systemName: "percent")
                            .font(.system(size: 8))
                        Text("\(Int(image.similarity * 100))%")
                    }
                    .font(DesignSystem.Typography.caption2)
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(DesignSystem.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md + 2)
                .fill(image.isSelected ? DesignSystem.Colors.error.opacity(0.1) : Color.clear)
        )
    }

    private var duplicatesActionBar: some View {
        HStack(spacing: DesignSystem.Spacing.lg) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 13))
                Text("\(duplicatesManager.totalSelected) selected")
                    .font(DesignSystem.Typography.callout)
            }
            .foregroundColor(DesignSystem.Colors.secondaryText)

            Spacer()

            Button(action: {
                showMovePanel = true
            }) {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "folder")
                    Text("Move to Folder")
                }
                .font(DesignSystem.Typography.callout)
                .foregroundColor(DesignSystem.Colors.accent)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(
                    Capsule()
                        .stroke(DesignSystem.Colors.accent, lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
            .fileImporter(isPresented: $showMovePanel, allowedContentTypes: [.folder]) { result in
                if case .success(let url) = result {
                    duplicatesManager.moveSelected(to: url) { moved, failed in
                        withAnimation {
                            actionFeedback = "Moved \(moved) file\(moved == 1 ? "" : "s")"
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { actionFeedback = nil }
                        }
                    }
                }
            }

            Button(action: {
                duplicatesManager.deleteSelected { deleted, failed in
                    withAnimation {
                        actionFeedback = "Moved \(deleted) file\(deleted == 1 ? "" : "s") to Trash"
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { actionFeedback = nil }
                    }
                }
            }) {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "trash")
                    Text("Move to Trash")
                }
                .font(DesignSystem.Typography.callout)
                .foregroundColor(.white)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(
                    Capsule()
                        .fill(DesignSystem.Colors.error)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(DesignSystem.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(colorScheme == .dark ? DesignSystem.Colors.darkTertiaryBackground : DesignSystem.Colors.tertiaryBackground)
        )
        .padding(.horizontal, DesignSystem.Spacing.xl)
        .padding(.bottom, DesignSystem.Spacing.lg)
    }

    // MARK: - Modern Search Bar
    @FocusState private var isSearchFocused: Bool

    private var modernSearchBar: some View {
        HStack(spacing: 12) {
            // Pasted image preview or search icon
            if let image = pastedImage {
                // Show pasted image thumbnail
                ZStack(alignment: .topTrailing) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(DesignSystem.Colors.accent, lineWidth: 2)
                        )

                    // Clear button
                    Button(action: {
                        withAnimation(.easeOut(duration: 0.15)) {
                            pastedImage = nil
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                            .background(Circle().fill(Color.black.opacity(0.6)))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .offset(x: 6, y: -6)
                }

                Text("Finding similar images...")
                    .font(.system(size: 14))
                    .foregroundColor(DesignSystem.Colors.secondaryText)

                Spacer()

                if searchManager.isSearching {
                    ProgressView()
                        .scaleEffect(0.65)
                }
            } else {
                // Normal search mode
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.tertiaryText)

                // Clean text field
                TextField("Search by text or drop an image here...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 14))
                    .focused($isSearchFocused)
                    .onSubmit {
                        if !searchManager.isSearching && !searchText.isEmpty {
                            performSearch()
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            isSearchFocused = true
                        }
                    }
                    .onChange(of: searchText) { oldValue, newValue in
                        // Clear pasted image when user starts typing
                        if pastedImage != nil && !newValue.isEmpty {
                            pastedImage = nil
                        }
                        searchDebounceTimer?.invalidate()
                        if newValue.isEmpty {
                            searchManager.clearResults()
                            return
                        }
                        searchDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { _ in
                            if !searchManager.isSearching && !newValue.isEmpty {
                                performSearch()
                            }
                        }
                    }

                // Right side: clear button, loading, or filter
                if searchManager.isSearching {
                    ProgressView()
                        .scaleEffect(0.65)
                        .transition(.opacity)
                } else if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .transition(.opacity)
                }

            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isSearchFocused ? DesignSystem.Colors.accent : Color.clear,
                    lineWidth: isSearchFocused ? 1.5 : 0
                )
        )
        .animation(.easeOut(duration: 0.2), value: isSearchFocused)
        .contentShape(Rectangle())
        .onTapGesture { isSearchFocused = true }
        .onDrop(of: [.image, .fileURL], isTargeted: $isDropTargeted) { providers in
            handleDroppedImage(providers: providers)
            return true
        }
        .overlay(
            Group {
                if isDropTargeted {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(DesignSystem.Colors.accent, lineWidth: 3)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(DesignSystem.Colors.accent.opacity(0.1))
                        )
                }
            }
        )
    }

    // MARK: - Indexing Progress View
    private var indexingProgressView: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            // Progress bar
            ProgressView(value: indexingPercent, total: 100)
                .progressViewStyle(LinearProgressViewStyle(tint: DesignSystem.Colors.accent))
                .scaleEffect(x: 1, y: 1.5, anchor: .center)

            // Top row: percentage and ETA
            HStack {
                Text("\(Int(indexingPercent))%")
                    .font(DesignSystem.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundColor(DesignSystem.Colors.accent)
                    .monospacedDigit()

                Spacer()

                if !indexingETA.isEmpty {
                    Text(indexingETA)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
            }

            // Bottom row: detailed stats
            HStack(spacing: DesignSystem.Spacing.md) {
                // Images processed
                if !indexingProgress.isEmpty {
                    Label(indexingProgress, systemImage: "photo.stack")
                }

                // Batch info
                if !indexingBatchInfo.isEmpty {
                    Label(indexingBatchInfo, systemImage: "square.stack.3d.up")
                }

                // Speed
                if indexingSpeed > 0 {
                    Label(String(format: "%.1f/s", indexingSpeed), systemImage: "speedometer")
                }

                // Elapsed time
                if indexingElapsed > 0 {
                    Label(formatDuration(indexingElapsed), systemImage: "clock")
                }

                Spacer()

                // Cancel button
                Button(action: { cancelIndexing() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                        Text("Cancel")
                    }
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.error)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .font(DesignSystem.Typography.caption)
            .foregroundColor(DesignSystem.Colors.secondaryText)
        }
        .padding(DesignSystem.Spacing.md)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(DesignSystem.Colors.accent.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .stroke(DesignSystem.Colors.accent.opacity(0.3), lineWidth: 1)
        )
    }

    private func cancelIndexing() {
        if let process = indexingProcess, process.isRunning {
            process.terminate()
        }
        DispatchQueue.main.async {
            isIndexing = false
            indexingProcess = nil
            stopElapsedTimer()
            indexingPercent = 0
            indexingETA = ""
            indexingProgress = ""
            indexingBatchInfo = ""
            indexingSpeed = 0
            indexingElapsed = 0
            batchTimes = []
            // Reload index stats since partial index was saved
            loadIndexStats()
        }
    }

    // MARK: - Indexing Report View
    private func indexingReportView(_ report: IndexingReport) -> some View {
        HStack(spacing: DesignSystem.Spacing.lg) {
            // Success icon
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(.green)

            // Stats
            VStack(alignment: .leading, spacing: 4) {
                Text("Indexing Complete")
                    .font(DesignSystem.Typography.callout)
                    .fontWeight(.medium)
                    .foregroundColor(DesignSystem.Colors.primaryText)

                HStack(spacing: DesignSystem.Spacing.md) {
                    Label("\(report.newImages) images", systemImage: "photo.stack")
                    Label(formatDuration(report.totalTime), systemImage: "clock")
                    Label(String(format: "%.1f/s", report.imagesPerSec), systemImage: "speedometer")
                }
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.secondaryText)
            }

            Spacer()

            // Dismiss button
            Button(action: { indexingReport = nil }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }
            .buttonStyle(.plain)
        }
        .padding(DesignSystem.Spacing.md)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(Color.green.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
        .onAppear {
            // Auto-dismiss after 8 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                withAnimation {
                    indexingReport = nil
                    loadIndexStats()
                }
            }
        }
    }

    // MARK: - Index Stats View
    private func indexStatsView(_ stats: IndexStats) -> some View {
        // Minimal inline stats with icons
        HStack(spacing: 16) {
            HStack(spacing: 5) {
                Image(systemName: "photo.stack")
                    .font(.system(size: 11))
                Text("\(stats.totalImages) indexed")
                    .font(.system(size: 12))
            }
            .foregroundColor(DesignSystem.Colors.tertiaryText)

            if let lastMod = stats.lastModified {
                HStack(spacing: 5) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                    Text(formatRelativeDate(lastMod))
                        .font(.system(size: 12))
                }
                .foregroundColor(DesignSystem.Colors.tertiaryText.opacity(0.7))
            }

            Spacer()

            Button(action: { loadIndexStats() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11))
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
            }
            .buttonStyle(.plain)
            .opacity(0.6)
        }
    }

    private func loadIndexStats() {
        let config = AppConfig.shared
        let indexPath = "\(config.baseDirectory)/image_index.bin"

        DispatchQueue.global(qos: .utility).async {
            let fileManager = FileManager.default

            guard fileManager.fileExists(atPath: indexPath) else {
                DispatchQueue.main.async {
                    self.indexStats = nil
                }
                return
            }

            // Get file attributes
            var fileSize = "Unknown"
            var lastModified: Date? = nil

            if let attrs = try? fileManager.attributesOfItem(atPath: indexPath) {
                if let size = attrs[.size] as? Int64 {
                    fileSize = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
                }
                lastModified = attrs[.modificationDate] as? Date
            }

            // Get image count from server
            let port = config.defaultPort
            guard let url = URL(string: "http://localhost:\(port)/index-count") else { return }

            var imageCount = 0
            let semaphore = DispatchSemaphore(value: 0)

            URLSession.shared.dataTask(with: url) { data, _, _ in
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let count = json["count"] as? Int {
                    imageCount = count
                }
                semaphore.signal()
            }.resume()

            semaphore.wait()

            DispatchQueue.main.async {
                self.indexStats = IndexStats(
                    totalImages: imageCount,
                    fileSize: fileSize,
                    lastModified: lastModified
                )
            }
        }
    }

    private func formatDuration(_ seconds: Double) -> String {
        if seconds < 60 {
            return String(format: "%.1fs", seconds)
        } else if seconds < 3600 {
            let mins = Int(seconds) / 60
            let secs = Int(seconds) % 60
            return "\(mins)m \(secs)s"
        } else {
            let hours = Int(seconds) / 3600
            let mins = (Int(seconds) % 3600) / 60
            return "\(hours)h \(mins)m"
        }
    }

    // MARK: - Empty State
    @State private var emptyStateIconRotation: Double = 0

    private var emptyStateView: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Spacer()

            VStack(spacing: DesignSystem.Spacing.xl) {
                // Clean icon
                ZStack {
                    Circle()
                        .fill(DesignSystem.Colors.accent.opacity(0.08))
                        .frame(width: 100, height: 100)

                    Image(systemName: "photo.stack")
                        .font(.system(size: 40, weight: .light))
                        .foregroundColor(DesignSystem.Colors.accent.opacity(0.7))
                }

                VStack(spacing: DesignSystem.Spacing.md) {
                    Text("Search Your Images")
                        .font(DesignSystem.Typography.title)
                        .foregroundColor(DesignSystem.Colors.primaryText)

                    Text("Use natural language to find images in your indexed folders")
                        .font(DesignSystem.Typography.callout)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 400)

                    // Example queries
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("Try searching for:")
                            .font(DesignSystem.Typography.caption.weight(.medium))
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                            .padding(.top, DesignSystem.Spacing.md)

                        HStack(spacing: DesignSystem.Spacing.sm) {
                            ExampleQueryChip(text: "sunset over mountains")
                            ExampleQueryChip(text: "cat sleeping")
                            ExampleQueryChip(text: "coffee cup")
                        }
                    }
                }
            }
            .padding(DesignSystem.Spacing.xxl)

            Spacer()
        }
    }

    // MARK: - Recent Images Section
    private var recentImagesSection: some View {
        Group {
            if recentImages.isEmpty && !isLoadingRecent {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 36, weight: .light))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                    Text("No photos yet")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                    Spacer()
                }
            } else if filteredRecentImages.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 36, weight: .light))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                    Text("No photos match filters")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                    Spacer()
                }
            } else {
                ScrollView {
                    MasonryGrid(items: filteredRecentImages, columns: 4, spacing: 12) { result in
                        MasonryImageCard(
                            result: result,
                            onFindSimilar: { path in
                                searchManager.findSimilar(imagePath: path)
                            },
                            onHoverStart: handlePreviewHoverStart,
                            onHoverEnd: handlePreviewHoverEnd
                        )
                    }
                    .padding(.horizontal, DesignSystem.Spacing.xl)
                }
            }
        }
    }

    // MARK: - Error View
    private var errorView: some View {
        Group {
            if let error = searchManager.errorMessage {
                HStack(spacing: DesignSystem.Spacing.md) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(DesignSystem.Colors.error)

                    Text(error)
                        .font(DesignSystem.Typography.callout)
                        .foregroundColor(DesignSystem.Colors.primaryText)

                    Spacer()

                    Button(action: {
                        searchManager.cancelSearch()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(DesignSystem.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                        .fill(DesignSystem.Colors.error.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                        .stroke(DesignSystem.Colors.error.opacity(0.3), lineWidth: 1)
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    // MARK: - Stats View
    private var statsView: some View {
        Group {
            if let stats = searchManager.searchStats {
                HStack(spacing: DesignSystem.Spacing.xl) {
                    StatItem(
                        icon: "clock.fill",
                        label: "Search Time",
                        value: stats.total_time
                    )

                    Divider()
                        .frame(height: 30)

                    StatItem(
                        icon: "photo.stack.fill",
                        label: "Images Searched",
                        value: "\(stats.images_searched)"
                    )

                    Divider()
                        .frame(height: 30)

                    StatItem(
                        icon: "speedometer",
                        label: "Images/Second",
                        value: stats.images_per_second
                    )
                }
                .padding(DesignSystem.Spacing.lg)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                        .fill(colorScheme == .dark ?
                            DesignSystem.Colors.darkSecondaryBackground :
                            DesignSystem.Colors.secondaryBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                        .stroke(DesignSystem.Colors.border, lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Results List
    private var resultsList: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            // Header with info and stats
            if !searchManager.isSearching || !searchManager.results.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    HStack {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(DesignSystem.Colors.accent)
                            Text("Double-click any image to copy")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                        }

                        Spacer()

                        if !searchManager.results.isEmpty {
                            HStack(spacing: DesignSystem.Spacing.xs) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 10))
                                    .foregroundColor(DesignSystem.Colors.accent)
                                Text("\(searchManager.results.count) results")
                                    .font(DesignSystem.Typography.caption.weight(.medium))
                                    .foregroundColor(DesignSystem.Colors.secondaryText)
                            }
                            .transition(.opacity)
                        }
                    }

                    if SearchPreferences.shared.showStats {
                        statsView
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Grid of results or skeletons - consistent card sizing
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 20),
                GridItem(.flexible(), spacing: 20),
                GridItem(.flexible(), spacing: 20),
                GridItem(.flexible(), spacing: 20)
            ], spacing: 24) {
                if searchManager.isSearching && searchManager.results.isEmpty {
                    // Show skeleton loaders while searching
                    ForEach(0..<12, id: \.self) { _ in
                        ResultCardSkeleton()
                    }
                } else {
                    // Show actual results
                    ForEach(searchManager.results.filter { result in
                        result.similarity >= SearchPreferences.shared.similarityThreshold
                    }) { result in
                        ImageCard(
                            result: result,
                            showSimilarity: true,
                            onFindSimilar: { path in
                                searchManager.findSimilar(imagePath: path)
                            }
                        )
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.8).combined(with: .opacity),
                            removal: .scale(scale: 0.9).combined(with: .opacity)
                        ))
                    }
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: searchManager.results.count)
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: searchManager.isSearching)
        }
    }
    
    private func performSearch() {
        guard !searchText.isEmpty, !searchManager.isSearching else { return }
        searchManager.search(query: searchText, numberOfResults: SearchPreferences.shared.numberOfResults)
    }

    // MARK: - Image Paste/Drop Handling
    private func setupPasteMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Check for Backspace/Delete to clear pasted image
            if self.pastedImage != nil && (event.keyCode == 51 || event.keyCode == 117) {
                DispatchQueue.main.async {
                    self.pastedImage = nil
                    self.searchManager.clearResults()
                }
                return nil // Consume the event
            }

            // Check for Cmd+V
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "v" {
                // Check if clipboard has an image
                let pasteboard = NSPasteboard.general
                if pasteboard.canReadObject(forClasses: [NSImage.self], options: nil) {
                    if let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil),
                       let image = images.first as? NSImage {
                        DispatchQueue.main.async {
                            self.pastedImage = image
                            self.saveAndSearchImage(image)
                        }
                        return nil // Consume the event
                    }
                }
            }
            return event // Let other events pass through
        }
    }

    private func removePasteMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    private func handleImagePaste(providers: [NSItemProvider]) {
        guard let provider = providers.first else { return }

        // Try to load as image data
        if provider.hasItemConformingToTypeIdentifier("public.image") {
            provider.loadDataRepresentation(forTypeIdentifier: "public.image") { data, error in
                guard let data = data, let image = NSImage(data: data) else { return }
                DispatchQueue.main.async {
                    self.pastedImage = image
                    self.saveAndSearchImage(image)
                }
            }
        }
    }

    private func handleDroppedImage(providers: [NSItemProvider]) {
        guard let provider = providers.first else { return }

        // Try to load as file URL first (for dragged files)
        if provider.hasItemConformingToTypeIdentifier("public.file-url") {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, error in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil),
                      let image = NSImage(contentsOf: url) else { return }
                DispatchQueue.main.async {
                    self.pastedImage = image
                    // Use the file directly if it exists
                    self.searchManager.findSimilar(imagePath: url.path)
                }
            }
        } else if provider.hasItemConformingToTypeIdentifier("public.image") {
            // Fall back to image data
            provider.loadDataRepresentation(forTypeIdentifier: "public.image") { data, error in
                guard let data = data, let image = NSImage(data: data) else { return }
                DispatchQueue.main.async {
                    self.pastedImage = image
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

    private func selectAndIndexFolder() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.message = "Select folder(s) to add (⌘-click for multiple)"
        panel.prompt = "Add"

        panel.begin { response in
            if response == .OK, !panel.urls.isEmpty {
                addAndIndexFolders(panel.urls)
            }
        }
    }

    private func addAndIndexFolders(_ urls: [URL]) {
        // Add folders to watched directories (avoid duplicates)
        let dirManager = DirectoryManager.shared
        var newFolders: [URL] = []

        for url in urls {
            let alreadyWatched = dirManager.watchedDirectories.contains { $0.path == url.path }
            if !alreadyWatched {
                dirManager.addDirectory(WatchedDirectory(path: url.path))
                newFolders.append(url)
            }
        }

        guard !newFolders.isEmpty else {
            indexingProgress = "Folders already in watch list"
            return
        }

        // Incremental index - only new folders, keep existing index
        let folderCount = newFolders.count
        let folderText = folderCount == 1 ? "folder" : "folders"
        print("Adding \(folderCount) new \(folderText) to index")
        isIndexing = true
        indexingReport = nil
        resetIndexingState()
        indexingProgress = "Indexing \(folderCount) new \(folderText)..."

        DispatchQueue.global(qos: .userInitiated).async {
            let config = AppConfig.shared
            let process = Process()
            let pipe = Pipe()

            // Store process reference for cancellation
            DispatchQueue.main.async {
                self.indexingProcess = process
            }

            process.executableURL = URL(fileURLWithPath: config.pythonExecutablePath)
            // Pass new folder paths - incremental indexing (no index deletion)
            process.arguments = [config.embeddingScriptPath] + newFolders.map { $0.path }

            process.standardOutput = pipe
            process.standardError = pipe

            let resourcesPath = Bundle.main.resourcePath ?? ""
            process.environment = [
                "PYTHONPATH": resourcesPath,
                "PATH": "\(config.baseDirectory)/venv/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin",
                "PYTHONUNBUFFERED": "1"
            ]
            process.currentDirectoryURL = URL(fileURLWithPath: resourcesPath)

            do {
                try process.run()

                pipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    if !data.isEmpty {
                        if let output = String(data: data, encoding: .utf8) {
                            print("Received output: \(output)")
                            self.parseIndexingOutput(output)
                        }
                    }
                }

                process.terminationHandler = { _ in
                    DispatchQueue.main.async {
                        self.isIndexing = false
                        self.indexingProcess = nil
                        self.stopElapsedTimer()
                        // Reload recent images and stats after indexing
                        self.loadRecentImages()
                        self.loadIndexStats()
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isIndexing = false
                    self.indexingProcess = nil
                    self.stopElapsedTimer()
                    self.indexingProgress = "Error: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Progress Parsing & ETA Calculation
    private func parseIndexingOutput(_ output: String) {
        // Try to parse each line as JSON
        for line in output.components(separatedBy: "\n") {
            guard !line.isEmpty else { continue }

            if let data = line.data(using: .utf8),
               let progress = try? JSONDecoder().decode(IndexingProgressData.self, from: data) {

                DispatchQueue.main.async {
                    switch progress.type {
                    case "start":
                        self.indexingPercent = 0
                        self.indexingETA = "Calculating..."
                        self.batchTimes = []
                        self.lastBatchTime = 0
                        if let total = progress.total_images {
                            self.indexingProgress = "Indexing \(total) images..."
                        }

                    case "progress":
                        if let batch = progress.batch,
                           let totalBatches = progress.total_batches,
                           let elapsed = progress.elapsed {
                            // Calculate percentage
                            self.indexingPercent = Double(batch) / Double(totalBatches) * 100

                            // Track elapsed time and speed
                            self.indexingElapsed = elapsed
                            if let speed = progress.images_per_sec {
                                self.indexingSpeed = speed
                            }

                            // Batch info
                            self.indexingBatchInfo = "Batch \(batch)/\(totalBatches)"

                            // Track batch time for rolling average
                            let batchTime = elapsed - self.lastBatchTime
                            self.lastBatchTime = elapsed
                            if batch > 1 { // Skip first batch (includes model loading)
                                self.batchTimes.append(batchTime)
                                // Keep last 5 batch times for rolling average
                                if self.batchTimes.count > 5 {
                                    self.batchTimes.removeFirst()
                                }
                            }

                            // Calculate ETA using rolling average
                            let remainingBatches = totalBatches - batch
                            if !self.batchTimes.isEmpty && remainingBatches > 0 {
                                let avgBatchTime = self.batchTimes.reduce(0, +) / Double(self.batchTimes.count)
                                let etaSeconds = avgBatchTime * Double(remainingBatches)
                                self.indexingETA = self.formatETA(etaSeconds)
                            } else if remainingBatches == 0 {
                                self.indexingETA = "Finishing..."
                            }

                            if let processed = progress.images_processed, let total = progress.total_images {
                                self.indexingProgress = "\(processed)/\(total) images"
                            }
                        }

                    case "complete":
                        self.indexingPercent = 100
                        self.indexingETA = ""
                        if let totalImages = progress.total_images,
                           let newImages = progress.new_images,
                           let totalTime = progress.total_time,
                           let imagesPerSec = progress.images_per_sec {
                            self.indexingReport = IndexingReport(
                                totalImages: totalImages,
                                newImages: newImages,
                                totalTime: totalTime,
                                imagesPerSec: imagesPerSec
                            )
                        }

                    default:
                        break
                    }
                }
            }
        }
    }

    private func formatETA(_ seconds: Double) -> String {
        if seconds < 60 {
            return "~\(Int(seconds))s remaining"
        } else if seconds < 3600 {
            let mins = Int(seconds) / 60
            let secs = Int(seconds) % 60
            return "~\(mins)m \(secs)s remaining"
        } else {
            let hours = Int(seconds) / 3600
            let mins = (Int(seconds) % 3600) / 60
            return "~\(hours)h \(mins)m remaining"
        }
    }

    private func resetIndexingState() {
        indexingPercent = 0
        indexingETA = ""
        indexingProgress = ""
        batchTimes = []
        lastBatchTime = 0
        indexingSpeed = 0
        indexingElapsed = 0
        indexingBatchInfo = ""
        startElapsedTimer()
    }

    private func startElapsedTimer() {
        // Stop existing timer if any
        elapsedTimer?.invalidate()
        indexingStartTime = Date()
        indexingElapsed = 0

        // Create timer on main thread
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if let start = self.indexingStartTime {
                self.indexingElapsed = Date().timeIntervalSince(start)
            }
        }
    }

    private func stopElapsedTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
        indexingStartTime = nil
    }


    private func rebuildIndex() {
        let directories = DirectoryManager.shared.watchedDirectories
        guard !directories.isEmpty else {
            indexingProgress = "No folders configured. Add folders first."
            return
        }

        let folderCount = directories.count
        let folderText = folderCount == 1 ? "folder" : "folders"
        print("Rebuilding index from \(folderCount) watched \(folderText)")
        isIndexing = true
        indexingReport = nil
        resetIndexingState()
        indexingProgress = "Clearing existing index..."

        DispatchQueue.global(qos: .userInitiated).async {
            let config = AppConfig.shared

            // Delete existing index files
            let indexPath = "\(config.baseDirectory)/image_index.bin"
            let indexPklPath = "\(config.baseDirectory)/image_index.pkl"
            try? FileManager.default.removeItem(atPath: indexPath)
            try? FileManager.default.removeItem(atPath: indexPklPath)

            DispatchQueue.main.async {
                self.indexingProgress = "Rebuilding index from \(folderCount) \(folderText)..."
            }

            // Index all watched directories
            let process = Process()
            let pipe = Pipe()

            // Store process reference for cancellation
            DispatchQueue.main.async {
                self.indexingProcess = process
            }

            process.executableURL = URL(fileURLWithPath: config.pythonExecutablePath)
            // Pass all watched folder paths as arguments
            process.arguments = [config.embeddingScriptPath] + directories.map { $0.path }

            process.standardOutput = pipe
            process.standardError = pipe

            let resourcesPath = Bundle.main.resourcePath ?? ""
            process.environment = [
                "PYTHONPATH": resourcesPath,
                "PATH": "\(config.baseDirectory)/venv/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin",
                "PYTHONUNBUFFERED": "1"
            ]
            process.currentDirectoryURL = URL(fileURLWithPath: resourcesPath)

            do {
                try process.run()

                pipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    if !data.isEmpty {
                        if let output = String(data: data, encoding: .utf8) {
                            print("Received output: \(output)")
                            self.parseIndexingOutput(output)
                        }
                    }
                }

                process.terminationHandler = { _ in
                    DispatchQueue.main.async {
                        self.isIndexing = false
                        self.indexingProcess = nil
                        self.stopElapsedTimer()
                        // Reload recent images after re-indexing
                        self.loadRecentImages()
                        self.loadIndexStats()
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isIndexing = false
                    self.indexingProcess = nil
                    self.stopElapsedTimer()
                    self.indexingProgress = "Error: \(error.localizedDescription)"
                }
            }
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

    private func copyImage(path: String) {
        if let image = NSImage(contentsOfFile: path) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.writeObjects([image])
        }
    }
}

#Preview {
    ContentView()
        .frame(minWidth: 600, minHeight: 600)
}
