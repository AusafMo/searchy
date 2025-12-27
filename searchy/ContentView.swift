import SwiftUI
import AppKit
import Foundation
import UniformTypeIdentifiers

// MARK: - Design System
struct DesignSystem {
    // Colors
    struct Colors {
        // Primary palette - Claude-inspired
        static let primaryBackground = Color(nsColor: NSColor(red: 0.98, green: 0.98, blue: 0.99, alpha: 1.0))
        static let secondaryBackground = Color.white
        static let tertiaryBackground = Color(nsColor: NSColor(red: 0.96, green: 0.96, blue: 0.97, alpha: 1.0))

        // Dark mode palette
        static let darkPrimaryBackground = Color(nsColor: NSColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0))
        static let darkSecondaryBackground = Color(nsColor: NSColor(red: 0.15, green: 0.15, blue: 0.16, alpha: 1.0))
        static let darkTertiaryBackground = Color(nsColor: NSColor(red: 0.18, green: 0.18, blue: 0.19, alpha: 1.0))

        // Accent colors
        static let accent = Color(nsColor: NSColor(red: 0.33, green: 0.44, blue: 1.0, alpha: 1.0))
        static let accentHover = Color(nsColor: NSColor(red: 0.28, green: 0.39, blue: 0.95, alpha: 1.0))

        // Text colors
        static let primaryText = Color(nsColor: NSColor.labelColor)
        static let secondaryText = Color(nsColor: NSColor.secondaryLabelColor)
        static let tertiaryText = Color(nsColor: NSColor.tertiaryLabelColor)

        // Semantic colors
        static let success = Color(nsColor: NSColor(red: 0.2, green: 0.78, blue: 0.35, alpha: 1.0))
        static let error = Color(nsColor: NSColor(red: 0.96, green: 0.26, blue: 0.21, alpha: 1.0))
        static let warning = Color(nsColor: NSColor(red: 1.0, green: 0.73, blue: 0.0, alpha: 1.0))

        // Borders
        static let border = Color(nsColor: NSColor.separatorColor).opacity(0.2)
        static let borderHover = Color(nsColor: NSColor.separatorColor).opacity(0.4)
    }

    // Typography
    struct Typography {
        static let largeTitle = Font.system(size: 28, weight: .bold, design: .rounded)
        static let title = Font.system(size: 20, weight: .semibold, design: .rounded)
        static let title2 = Font.system(size: 17, weight: .semibold, design: .rounded)
        static let headline = Font.system(size: 15, weight: .semibold, design: .default)
        static let body = Font.system(size: 14, weight: .regular, design: .default)
        static let callout = Font.system(size: 13, weight: .regular, design: .default)
        static let caption = Font.system(size: 11, weight: .regular, design: .default)
        static let caption2 = Font.system(size: 10, weight: .regular, design: .default)
    }

    // Spacing
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    // Corner Radius
    struct CornerRadius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 10
        static let lg: CGFloat = 14
        static let xl: CGFloat = 20
    }

    // Shadows
    struct Shadows {
        static func small(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color.black.opacity(0.3) : Color.black.opacity(0.08)
        }

        static func medium(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color.black.opacity(0.4) : Color.black.opacity(0.12)
        }

        static func large(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color.black.opacity(0.5) : Color.black.opacity(0.15)
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
    
    @Published var pythonExecutablePath: String {
        didSet {
            UserDefaults.standard.set(pythonExecutablePath, forKey: "pythonExecutablePath")
        }
    }
    
    @Published var serverScriptPath: String {
        didSet {
            UserDefaults.standard.set(serverScriptPath, forKey: "serverScriptPath")
        }
    }
    
    @Published var embeddingScriptPath: String {
        didSet {
            UserDefaults.standard.set(embeddingScriptPath, forKey: "embeddingScriptPath")
        }
    }
    
    private init() {
        // Load from UserDefaults with fallbacks to current constants
        self.baseDirectory = UserDefaults.standard.string(forKey: "baseDirectory") ?? Constants.baseDirectory
        self.defaultPort = UserDefaults.standard.integer(forKey: "defaultPort") != 0 ?
            UserDefaults.standard.integer(forKey: "defaultPort") : Constants.defaultPort
        self.pythonExecutablePath = UserDefaults.standard.string(forKey: "pythonExecutablePath") ?? Constants.pythonExecutablePath
        self.serverScriptPath = UserDefaults.standard.string(forKey: "serverScriptPath") ?? Constants.serverScriptPath
        self.embeddingScriptPath = UserDefaults.standard.string(forKey: "embeddingScriptPath") ?? Constants.embeddingScriptPath
    }
    
    func resetToDefaults() {
        baseDirectory = Constants.baseDirectory
        defaultPort = Constants.defaultPort
        pythonExecutablePath = Constants.pythonExecutablePath
        serverScriptPath = Constants.serverScriptPath
        embeddingScriptPath = Constants.embeddingScriptPath
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
                    .foregroundStyle(
                        LinearGradient(
                            colors: [DesignSystem.Colors.accent, DesignSystem.Colors.accent.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
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
    @State private var isShowingPythonPicker = false
    @State private var isShowingServerScriptPicker = false
    @State private var isShowingEmbeddingScriptPicker = false
    @State private var isShowingBaseDirectoryPicker = false
    @State private var isShowingAddDirectorySheet = false
    @State private var isReindexing = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: colorScheme == .dark ?
                    [DesignSystem.Colors.darkPrimaryBackground, DesignSystem.Colors.darkSecondaryBackground] :
                    [DesignSystem.Colors.primaryBackground, DesignSystem.Colors.tertiaryBackground],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
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
                                .fill(
                                    LinearGradient(
                                        colors: [DesignSystem.Colors.accent, DesignSystem.Colors.accent.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(DesignSystem.Spacing.xl)
                .background(
                    (colorScheme == .dark ?
                        DesignSystem.Colors.darkSecondaryBackground :
                        DesignSystem.Colors.secondaryBackground)
                        .opacity(0.8)
                        .background(.ultraThinMaterial)
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

                    // Watched Directories Section
                    SettingsSection(title: "Watched Directories", icon: "eye") {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                            Text("Manage directories that are automatically monitored for new images")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.secondaryText)

                            // Directory List
                            VStack(spacing: DesignSystem.Spacing.sm) {
                                ForEach(dirManager.watchedDirectories) { directory in
                                    WatchedDirectoryRow(directory: directory, onDelete: {
                                        dirManager.removeDirectory(directory)
                                    })
                                }
                            }

                            // Action Buttons
                            HStack(spacing: DesignSystem.Spacing.md) {
                                // Re-index All Button
                                Button(action: {
                                    performReindex()
                                }) {
                                    HStack(spacing: DesignSystem.Spacing.sm) {
                                        if isReindexing {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                                .tint(.white)
                                        } else {
                                            Image(systemName: "arrow.clockwise")
                                        }
                                        Text("Re-index All")
                                    }
                                    .font(DesignSystem.Typography.callout.weight(.medium))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, DesignSystem.Spacing.md)
                                    .background(
                                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                            .fill(
                                                LinearGradient(
                                                    colors: [Color(red: 0.2, green: 0.7, blue: 0.6), Color(red: 0.15, green: 0.6, blue: 0.5)],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                .disabled(isReindexing)

                                // Add Directory Button
                                Button(action: {
                                    isShowingAddDirectorySheet = true
                                }) {
                                    HStack(spacing: DesignSystem.Spacing.sm) {
                                        Image(systemName: "plus.circle.fill")
                                        Text("Add Directory")
                                    }
                                    .font(DesignSystem.Typography.callout.weight(.medium))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, DesignSystem.Spacing.md)
                                    .background(
                                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                            .fill(
                                                LinearGradient(
                                                    colors: [Color(red: 0.2, green: 0.7, blue: 0.6), Color(red: 0.15, green: 0.6, blue: 0.5)],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
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
                    
                    // Python Settings Section
                    SettingsSection(title: "Python", icon: "terminal") {
                        SettingsGroup(title: "Paths") {
                            // Python executable
                            PathSetting(
                                title: "Python Executable",
                                icon: "chevron.left.forwardslash.chevron.right",
                                path: $config.pythonExecutablePath,
                                showPicker: $isShowingPythonPicker
                            )
                            
                            // Server script
                            PathSetting(
                                title: "Server Script",
                                icon: "doc.text",
                                path: $config.serverScriptPath,
                                showPicker: $isShowingServerScriptPicker
                            )
                            
                            // Embedding script
                            PathSetting(
                                title: "Embedding Script",
                                icon: "doc.text.fill",
                                path: $config.embeddingScriptPath,
                                showPicker: $isShowingEmbeddingScriptPicker
                            )
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
        .fileImporter(isPresented: $isShowingPythonPicker, allowedContentTypes: [.directory]) { result in
            if case .success(let url) = result {
                config.pythonExecutablePath = url.path
            }
        }
        .fileImporter(isPresented: $isShowingServerScriptPicker, allowedContentTypes: [.directory]) { result in
            if case .success(let url) = result {
                config.serverScriptPath = url.path
            }
        }
        .fileImporter(isPresented: $isShowingEmbeddingScriptPicker, allowedContentTypes: [.directory]) { result in
            if case .success(let url) = result {
                config.embeddingScriptPath = url.path
            }
        }
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
    @StateObject private var prefs = SearchPreferences.shared
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // Image skeleton
            SkeletonView()
                .frame(width: CGFloat(prefs.imageSize), height: CGFloat(prefs.imageSize))

            // Info skeleton
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                SkeletonView()
                    .frame(height: 12)
                    .frame(maxWidth: .infinity)

                HStack(spacing: DesignSystem.Spacing.xs) {
                    SkeletonView()
                        .frame(width: 60, height: 20)
                    SkeletonView()
                        .frame(width: 60, height: 20)
                }
            }
            .padding(DesignSystem.Spacing.md)
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
                .stroke(DesignSystem.Colors.border, lineWidth: 1)
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
    @State private var searchText = ""
    @State private var selectedIndex: Int = 0
    @State private var recentImages: [SearchResult] = []
    @State private var hasPerformedSearch = false
    @State private var isLoadingRecent = false
    @State private var searchDebounceTimer: Timer?
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
                .padding(DesignSystem.Spacing.md)
                .background(searchBarBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xl)
                        .stroke(
                            LinearGradient(
                                colors: [Color.black.opacity(0.15), Color.black.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .padding(.horizontal, DesignSystem.Spacing.md)

                // Results area
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
                    ScrollViewReader { proxy in
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: DesignSystem.Spacing.sm) {
                                ForEach(Array(displayResults.prefix(8).enumerated()), id: \.element.id) { index, result in
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
                        .frame(maxHeight: 350)
                        .animation(nil, value: selectedIndex)
                        .background(resultsBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xl)
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.black.opacity(0.15), Color.black.opacity(0.05)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.top, DesignSystem.Spacing.sm)
                        .onChange(of: selectedIndex) { oldValue, newValue in
                            // Scroll instantly with no animation
                            proxy.scrollTo(newValue, anchor: .center)
                        }
                    }
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isSearchFocused = true
            }
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
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            // Thumbnail
            if let image = NSImage(contentsOfFile: result.path) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
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
            }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(URL(fileURLWithPath: result.path).lastPathComponent)
                    .font(DesignSystem.Typography.caption.weight(.semibold))
                    .foregroundColor(isSelected ? DesignSystem.Colors.accent : DesignSystem.Colors.primaryText)
                    .lineLimit(1)

                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 8))
                    Text("\(Int(result.similarity * 100))%")
                        .font(DesignSystem.Typography.caption2)
                }
                .foregroundColor(similarityColor)
            }

            Spacer()

            // Action buttons
            HStack(spacing: DesignSystem.Spacing.xs) {
                Button(action: {
                    copyImage(path: result.path)
                    showCopyNotification()
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12))
                        .foregroundColor(DesignSystem.Colors.accent)
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: {
                    NSWorkspace.shared.selectFile(result.path, inFileViewerRootedAtPath: "")
                    onSelect()
                }) {
                    Image(systemName: "folder")
                        .font(.system(size: 12))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
                .buttonStyle(PlainButtonStyle())
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

                // Hover overlay with gradient
                if isHovered {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.black.opacity(0), Color.black.opacity(0.3)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }

                // Similarity badge with glass effect
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 8))
                    Text("\(Int(result.similarity * 100))%")
                        .font(DesignSystem.Typography.caption2.weight(.semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.xs)
                .background(
                    ZStack {
                        Capsule()
                            .fill(similarityColor.opacity(0.9))
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .blendMode(.overlay)
                    }
                    .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 2)
                )
                .padding(DesignSystem.Spacing.sm)
                .scaleEffect(isHovered ? 1.05 : 1.0)
                .allowsHitTesting(false)

                // Copy notification overlay
                if showingCopyNotification {
                    CopyNotification(isShowing: $showingCopyNotification)
                        .allowsHitTesting(false)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }

            // Info section with enhanced buttons
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text(URL(fileURLWithPath: result.path).lastPathComponent)
                    .lineLimit(1)
                    .font(DesignSystem.Typography.caption.weight(.medium))
                    .foregroundColor(DesignSystem.Colors.primaryText)

                // Action buttons with hover states
                HStack(spacing: DesignSystem.Spacing.xs) {
                    ActionButton(
                        icon: "doc.on.doc.fill",
                        title: "Copy",
                        color: DesignSystem.Colors.accent
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            copyImage(path: result.path)
                            showCopyNotification()
                        }
                    }

                    ActionButton(
                        icon: "folder.fill",
                        title: "Reveal",
                        color: DesignSystem.Colors.secondaryText
                    ) {
                        revealInFinder(path: result.path)
                    }

                    Spacer()
                }
            }
            .padding(DesignSystem.Spacing.md)
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
                    isHovered ?
                        LinearGradient(
                            colors: [DesignSystem.Colors.accent.opacity(0.5), DesignSystem.Colors.accent.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [DesignSystem.Colors.border, DesignSystem.Colors.border],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                    lineWidth: isHovered ? 1.5 : 1
                )
        )
        .shadow(
            color: isHovered ? DesignSystem.Shadows.large(colorScheme) : DesignSystem.Shadows.small(colorScheme),
            radius: isHovered ? 16 : 6,
            x: 0,
            y: isHovered ? 8 : 3
        )
        .scaleEffect(isHovered ? 1.03 : 1.0)
        .rotation3DEffect(
            .degrees(isHovered ? 2 : 0),
            axis: (x: 0, y: 1, z: 0),
            perspective: 1.0
        )
        .onHover { hovering in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                isHovered = hovering
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

// MARK: - Recent Image Card
struct RecentImageCard: View {
    let result: SearchResult
    @State private var showingCopyNotification = false
    @State private var isHovered = false
    @State private var isPressed = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // Image container
            ZStack(alignment: .center) {
                if let image = NSImage(contentsOfFile: result.path) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 150, height: 150)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(colorScheme == .dark ?
                            DesignSystem.Colors.darkTertiaryBackground :
                            DesignSystem.Colors.tertiaryBackground)
                        .frame(width: 150, height: 150)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 32))
                                .foregroundColor(DesignSystem.Colors.tertiaryText)
                        )
                }

                // Hover overlay
                if isHovered {
                    Rectangle()
                        .fill(Color.black.opacity(0.3))
                        .overlay(
                            VStack(spacing: DesignSystem.Spacing.sm) {
                                Button(action: {
                                    copyImage(path: result.path)
                                    showCopyNotification()
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "doc.on.doc.fill")
                                        Text("Copy")
                                    }
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(DesignSystem.Colors.accent))
                                }
                                .buttonStyle(PlainButtonStyle())

                                Button(action: {
                                    NSWorkspace.shared.selectFile(result.path, inFileViewerRootedAtPath: "")
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "folder.fill")
                                        Text("Reveal")
                                    }
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(Color.white.opacity(0.3)))
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        )
                        .transition(.opacity)
                }

                // Copy notification
                if showingCopyNotification {
                    CopyNotification(isShowing: $showingCopyNotification)
                        .allowsHitTesting(false)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .scaleEffect(isPressed ? 0.95 : 1.0)

            // Filename
            Text(URL(fileURLWithPath: result.path).lastPathComponent)
                .lineLimit(1)
                .font(DesignSystem.Typography.caption)
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
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .stroke(
                    isHovered ?
                        DesignSystem.Colors.accent.opacity(0.5) :
                        DesignSystem.Colors.border,
                    lineWidth: isHovered ? 1.5 : 1
                )
        )
        .shadow(
            color: isHovered ? DesignSystem.Shadows.medium(colorScheme) : DesignSystem.Shadows.small(colorScheme),
            radius: isHovered ? 12 : 4,
            x: 0,
            y: isHovered ? 6 : 2
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovered = hovering
            }
        }
        .onTapGesture(count: 2) {
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
        if let cachedImage = ImageCache.shared.image(for: filePath) {
            self.image = cachedImage
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            if let loadedImage = NSImage(contentsOfFile: filePath) {
                let maxSize = CGFloat(SearchPreferences.shared.imageSize)
                let newSize = calculateAspectRatioSize(for: loadedImage, maxSize: maxSize)
                let resizedImage = resizeImage(loadedImage, targetSize: newSize)
                ImageCache.shared.setImage(resizedImage, for: filePath)
                DispatchQueue.main.async {
                    self.image = resizedImage
                }
            }
        }
    }

    private func calculateAspectRatioSize(for image: NSImage, maxSize: CGFloat) -> NSSize {
        let imageWidth = image.size.width
        let imageHeight = image.size.height

        let widthRatio = maxSize / imageWidth
        let heightRatio = maxSize / imageHeight

        let ratio = min(widthRatio, heightRatio)

        return NSSize(
            width: imageWidth * ratio,
            height: imageHeight * ratio
        )
    }

    private func resizeImage(_ image: NSImage, targetSize: NSSize) -> NSImage {
        let newImage = NSImage(size: targetSize)

        newImage.lockFocus()

        NSColor.windowBackgroundColor.setFill()
        NSRect(origin: .zero, size: targetSize).fill()

        image.draw(
            in: NSRect(origin: .zero, size: targetSize),
            from: NSRect(origin: .zero, size: image.size),
            operation: .copy,
            fraction: 1.0
        )

        newImage.unlockFocus()
        return newImage
    }
}
// Search Result Model
struct SearchResult: Codable, Identifiable {
    var id = UUID()
    let path: String
    let similarity: Float
    
    enum CodingKeys: String, CodingKey {
        case path
        case similarity
    }
}

struct SearchResponse: Codable {
    let results: [SearchResult]
    let stats: SearchStats
}

struct SearchStats: Codable {
    let total_time: String
    let images_searched: Int
    let images_per_second: String
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
        if let rawOutput = String(data: data, encoding: .utf8) {
            let lines = rawOutput.components(separatedBy: .newlines)
            if let jsonLine = lines.last(where: { line in
                guard !line.isEmpty else { return false }
                return line.starts(with: "{") && line.hasSuffix("}")
            }) {
                if let jsonData = jsonLine.data(using: .utf8) {
                    let response = try JSONDecoder().decode(SearchResponse.self, from: jsonData)
                    return response
                } else {
                    throw NSError(domain: "Invalid JSON format", code: 0, userInfo: nil)
                }
            } else {
                throw NSError(domain: "No valid JSON response found, Are You sure the folders are indexed ?", code: 0, userInfo: nil)
            }
        } else {
            throw NSError(domain: "No response from server", code: 0, userInfo: nil)
        }
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
                    URLQueryItem(name: "top_k", value: "8"),
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

struct ContentView: View {
    @ObservedObject private var searchManager = SearchManager.shared
    @State private var searchText = ""
    @State private var isIndexing = false
    @State private var indexingProgress = ""
    @State private var indexingPercent: Double = 0
    @State private var indexingETA: String = ""
    @State private var batchTimes: [Double] = []
    @State private var lastBatchTime: Double = 0
    @State private var indexingReport: IndexingReport? = nil
    @State private var indexingSpeed: Double = 0
    @State private var indexingElapsed: Double = 0
    @State private var indexingBatchInfo: String = ""
    @State private var indexStats: IndexStats? = nil
    @State private var isShowingSettings = false
    @State private var searchDebounceTimer: Timer?
    @State private var recentImages: [SearchResult] = []
    @State private var isLoadingRecent = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: colorScheme == .dark ?
                    [DesignSystem.Colors.darkPrimaryBackground, DesignSystem.Colors.darkSecondaryBackground] :
                    [DesignSystem.Colors.primaryBackground, DesignSystem.Colors.tertiaryBackground],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Modern header
                modernHeader

                // Main content area
                VStack(spacing: DesignSystem.Spacing.xl) {
                    if isIndexing {
                        indexingProgressView
                    } else if let report = indexingReport {
                        indexingReportView(report)
                    } else if let stats = indexStats {
                        indexStatsView(stats)
                            .padding(.top, DesignSystem.Spacing.xxl)
                    }

                    modernSearchBar
                    errorView

                    // Results area - wrapped in Group with consistent frame to prevent layout shifts
                    Group {
                        if searchManager.isSearching {
                            VStack(spacing: DesignSystem.Spacing.md) {
                                Spacer()
                                ProgressView()
                                    .scaleEffect(1.2)
                                Text("Searching...")
                                    .font(DesignSystem.Typography.callout)
                                    .foregroundColor(DesignSystem.Colors.secondaryText)
                                Spacer()
                            }
                        } else if !searchManager.results.isEmpty {
                            ScrollView {
                                resultsList
                                    .padding(DesignSystem.Spacing.xl)
                            }
                        } else if searchText.isEmpty {
                            // Show recent images section
                            recentImagesSection
                        } else {
                            emptyStateView
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(.horizontal, DesignSystem.Spacing.xl)
            }
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
                .frame(width: 680, height: 760)
        }
        .onAppear {
            loadRecentImages()
            loadIndexStats()
            // Focus the search field on appear
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isSearchFocused = true
            }
        }
        .onDisappear {
            searchManager.cancelSearch()
        }
    }

    // MARK: - Modern Header
    private var modernHeader: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // App title with animated icon
            HStack(spacing: DesignSystem.Spacing.sm) {
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
                        .frame(width: 36, height: 36)

                    Image(systemName: "photo.stack.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [DesignSystem.Colors.accent, DesignSystem.Colors.accent.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Searchy")
                        .font(DesignSystem.Typography.title2)
                        .foregroundColor(DesignSystem.Colors.primaryText)

                    if searchManager.isSearching {
                        Text("Searching...")
                            .font(DesignSystem.Typography.caption2)
                            .foregroundColor(DesignSystem.Colors.accent)
                            .transition(.opacity)
                    } else if !searchManager.results.isEmpty {
                        Text("\(searchManager.results.count) results")
                            .font(DesignSystem.Typography.caption2)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: searchManager.isSearching)
                .animation(.easeInOut(duration: 0.2), value: searchManager.results.count)
            }

            Spacer()

            // Action buttons with status indicator
            HStack(spacing: DesignSystem.Spacing.sm) {
                if isIndexing {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Indexing...")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.accent)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(
                        Capsule()
                            .fill(DesignSystem.Colors.accent.opacity(0.1))
                    )
                    .transition(.scale.combined(with: .opacity))
                }

                ModernButton(
                    icon: "plus.square.fill",
                    title: "Index Folder",
                    style: .secondary,
                    isDisabled: isIndexing
                ) {
                    if !isIndexing {
                        selectAndIndexFolder()
                    }
                }

                ModernButton(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Replace Index",
                    style: .secondary,
                    isDisabled: isIndexing
                ) {
                    if !isIndexing {
                        selectAndReplaceIndex()
                    }
                }

                ModernButton(
                    icon: "gearshape.fill",
                    title: nil,
                    style: .tertiary,
                    isDisabled: false
                ) {
                    isShowingSettings = true
                }
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.xl)
        .padding(.vertical, DesignSystem.Spacing.lg)
        .background(
            (colorScheme == .dark ?
                DesignSystem.Colors.darkSecondaryBackground :
                DesignSystem.Colors.secondaryBackground)
                .opacity(0.7)
                .background(.ultraThinMaterial)
        )
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(DesignSystem.Colors.border.opacity(0.5))
                .frame(maxHeight: .infinity, alignment: .bottom)
        )
    }

    // MARK: - Modern Search Bar
    @FocusState private var isSearchFocused: Bool

    private var modernSearchBar: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.accent.opacity(isSearchFocused ? 0.15 : 0.1))
                    .frame(width: 32, height: 32)

                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSearchFocused ? DesignSystem.Colors.accent : DesignSystem.Colors.secondaryText)
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSearchFocused)

            TextField(isIndexing ? "Indexing in progress..." : "Search your images with natural language...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .font(DesignSystem.Typography.body)
                .focused($isSearchFocused)
                .disabled(isIndexing)
                .onSubmit {
                    if !searchManager.isSearching && !searchText.isEmpty && !isIndexing {
                        performSearch()
                    }
                    // Keep focus after searching
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        isSearchFocused = true
                    }
                }
                .onChange(of: searchText) { oldValue, newValue in
                    // Cancel previous timer
                    searchDebounceTimer?.invalidate()

                    // Don't search while indexing
                    if isIndexing { return }

                    // Clear results if search is empty
                    if newValue.isEmpty {
                        searchManager.clearResults()
                        return
                    }

                    // Debounce: wait 400ms before searching
                    searchDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { _ in
                        if !searchManager.isSearching && !newValue.isEmpty && !self.isIndexing {
                            performSearch()
                        }
                    }
                }

            if !searchText.isEmpty {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        searchText = ""
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(DesignSystem.Colors.tertiaryText.opacity(0.1))
                            .frame(width: 20, height: 20)

                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .transition(.scale.combined(with: .opacity))
            }

            if searchManager.isSearching {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Searching")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.accent)
                }
                .transition(.scale.combined(with: .opacity))
            } else if !searchText.isEmpty {
                Button(action: { performSearch() }) {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Text("Search")
                            .font(DesignSystem.Typography.callout.weight(.semibold))
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 14))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [DesignSystem.Colors.accent, DesignSystem.Colors.accent.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(color: DesignSystem.Colors.accent.opacity(0.3), radius: 8, x: 0, y: 4)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.8).combined(with: .opacity),
                    removal: .scale(scale: 0.9).combined(with: .opacity)
                ))
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(colorScheme == .dark ? DesignSystem.Colors.darkSecondaryBackground : DesignSystem.Colors.secondaryBackground)
                .shadow(
                    color: isSearchFocused ? DesignSystem.Shadows.medium(colorScheme) : DesignSystem.Shadows.small(colorScheme),
                    radius: isSearchFocused ? 12 : 8,
                    x: 0,
                    y: isSearchFocused ? 4 : 2
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .stroke(
                    isSearchFocused ?
                        LinearGradient(
                            colors: [DesignSystem.Colors.accent.opacity(0.5), DesignSystem.Colors.accent.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [DesignSystem.Colors.border, DesignSystem.Colors.border],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                    lineWidth: isSearchFocused ? 1.5 : 1
                )
        )
        .scaleEffect(isSearchFocused ? 1.01 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSearchFocused)
        .contentShape(Rectangle())
        .onTapGesture {
            isSearchFocused = true
        }
        .padding(.top, DesignSystem.Spacing.xl)
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
        HStack(spacing: DesignSystem.Spacing.lg) {
            // Database icon
            Image(systemName: "cylinder.split.1x2")
                .font(.system(size: 20))
                .foregroundColor(DesignSystem.Colors.accent)

            // Stats
            HStack(spacing: DesignSystem.Spacing.xl) {
                Label("\(stats.totalImages) images", systemImage: "photo.stack")

                Label(stats.fileSize, systemImage: "internaldrive")

                if let lastMod = stats.lastModified {
                    Label(formatRelativeDate(lastMod), systemImage: "clock")
                }
            }
            .font(DesignSystem.Typography.caption)
            .foregroundColor(DesignSystem.Colors.secondaryText)

            Spacer()

            // Refresh button
            Button(action: { loadIndexStats() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }
            .buttonStyle(.plain)
        }
        .padding(DesignSystem.Spacing.md)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(DesignSystem.Colors.accent.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .stroke(DesignSystem.Colors.accent.opacity(0.15), lineWidth: 1)
        )
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

    private func formatRelativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
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
                // Animated icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    DesignSystem.Colors.accent.opacity(0.1),
                                    DesignSystem.Colors.accent.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                        .blur(radius: 20)

                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    DesignSystem.Colors.accent.opacity(0.3),
                                    DesignSystem.Colors.accent.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(emptyStateIconRotation))

                    Image(systemName: "photo.stack")
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [DesignSystem.Colors.accent, DesignSystem.Colors.accent.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .onAppear {
                    withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                        emptyStateIconRotation = 360
                    }
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
        VStack(spacing: DesignSystem.Spacing.md) {
            // Header with title and refresh button
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recent Images")
                        .font(DesignSystem.Typography.title2)
                        .foregroundColor(DesignSystem.Colors.primaryText)
                    Text("8 most recent images from your indexed folders")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }

                Spacer()

                Button(action: {
                    loadRecentImages()
                }) {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        if isLoadingRecent {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text("Refresh")
                    }
                    .font(DesignSystem.Typography.callout.weight(.medium))
                    .foregroundColor(DesignSystem.Colors.accent)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                            .fill(DesignSystem.Colors.accent.opacity(0.1))
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isLoadingRecent)
            }
            .padding(.horizontal, DesignSystem.Spacing.md)

            // Recent images grid - use frame to prevent layout shifts
            Group {
                if isLoadingRecent && recentImages.isEmpty {
                    VStack(spacing: DesignSystem.Spacing.md) {
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading recent images...")
                            .font(DesignSystem.Typography.callout)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                        Spacer()
                    }
                } else if recentImages.isEmpty {
                    VStack(spacing: DesignSystem.Spacing.md) {
                        Spacer()
                        Image(systemName: "photo.stack")
                            .font(.system(size: 48, weight: .light))
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                        Text("No recent images")
                            .font(DesignSystem.Typography.callout)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                        Text("Index a folder to see recent images here")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                        Spacer()
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.adaptive(minimum: 150, maximum: 200), spacing: DesignSystem.Spacing.md)
                        ], spacing: DesignSystem.Spacing.md) {
                            ForEach(recentImages.prefix(8)) { result in
                                RecentImageCard(result: result)
                            }
                        }
                        .padding(DesignSystem.Spacing.md)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxHeight: .infinity)
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

            // Grid of results or skeletons
            let columns = Array(
                repeating: GridItem(.flexible(), spacing: DesignSystem.Spacing.lg),
                count: SearchPreferences.shared.gridColumns
            )

            LazyVGrid(columns: columns, spacing: DesignSystem.Spacing.lg) {
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
                        ResultCardView(result: result)
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
    
    private func selectAndIndexFolder() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false

        panel.begin { response in
            if response == .OK, let url = panel.url {
                indexFolder(url)
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
    }

    private func indexFolder(_ url: URL) {
        print("Starting indexing for url: \(url.path)")
        isIndexing = true
        indexingReport = nil
        resetIndexingState()
        indexingProgress = "Starting indexing..."

        DispatchQueue.global(qos: .userInitiated).async {
            let config = AppConfig.shared
            let process = Process()
            let pipe = Pipe()

            process.executableURL = URL(fileURLWithPath: config.pythonExecutablePath)
            process.arguments = [config.embeddingScriptPath, url.path]

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
                        // Reload recent images after indexing
                        self.loadRecentImages()
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isIndexing = false
                    self.indexingProgress = "Error: \(error.localizedDescription)"
                }
            }
        }
    }

    private func selectAndReplaceIndex() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.message = "Select a folder to replace the current index"
        panel.prompt = "Replace Index"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                replaceAndIndexFolder(url)
            }
        }
    }

    private func replaceAndIndexFolder(_ url: URL) {
        print("Replacing index with folder: \(url.path)")
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
                self.indexingProgress = "Starting fresh index..."
            }

            // Now index the new folder
            let process = Process()
            let pipe = Pipe()

            process.executableURL = URL(fileURLWithPath: config.pythonExecutablePath)
            process.arguments = [config.embeddingScriptPath, url.path]

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
                        // Reload recent images after re-indexing
                        self.loadRecentImages()
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isIndexing = false
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
