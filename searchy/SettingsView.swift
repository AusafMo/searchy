import SwiftUI
import Foundation
import UniformTypeIdentifiers

// MARK: - Atelier Settings Card
struct AtelierCard<Content: View>: View {
    let title: String
    let icon: String
    let content: () -> Content
    private var pal: AtelierPalette { ThemeManager.shared.palette }

    init(title: String, icon: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Card title row
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(pal.accent)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(pal.ink)
            }

            content()
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(pal.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(pal.line, lineWidth: 1)
        )
    }
}

// MARK: - Atelier Setting Row
struct AtelierSettingRow<Control: View>: View {
    let label: String
    let hint: String?
    let control: () -> Control
    private var pal: AtelierPalette { ThemeManager.shared.palette }

    init(label: String, hint: String? = nil, @ViewBuilder control: @escaping () -> Control) {
        self.label = label
        self.hint = hint
        self.control = control
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(pal.ink)
                if let hint = hint {
                    Text(hint)
                        .font(.system(size: 12, weight: .regular, design: .serif).italic())
                        .foregroundColor(pal.ink3)
                }
            }
            Spacer()
            control()
        }
    }
}

// MARK: - Atelier Dashed Divider
struct AtelierDashedDivider: View {
    private var pal: AtelierPalette { ThemeManager.shared.palette }

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(height: 1)
            .overlay(
                GeometryReader { geo in
                    Path { path in
                        path.move(to: .zero)
                        path.addLine(to: CGPoint(x: geo.size.width, y: 0))
                    }
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundColor(pal.line)
                }
            )
    }
}

// MARK: - Atelier Toggle
struct AtelierToggle: View {
    @Binding var isOn: Bool
    private var pal: AtelierPalette { ThemeManager.shared.palette }

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                isOn.toggle()
            }
        }) {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? pal.accent : pal.line)
                    .frame(width: 38, height: 22)

                Circle()
                    .fill(Color.white)
                    .frame(width: 18, height: 18)
                    .padding(2)
                    .shadow(color: Color.black.opacity(0.12), radius: 1, y: 1)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Atelier Pill Selector
struct AtelierPillSelector<T: Hashable>: View {
    let options: [T]
    @Binding var selected: T
    let label: (T) -> String
    private var pal: AtelierPalette { ThemeManager.shared.palette }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(options, id: \.self) { option in
                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        selected = option
                    }
                }) {
                    Text(label(option))
                        .font(.system(size: 12, weight: selected == option ? .semibold : .regular))
                        .foregroundColor(selected == option ? .white : pal.ink2)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(selected == option ? pal.accent : pal.paper)
                        )
                        .overlay(
                            Capsule()
                                .stroke(selected == option ? Color.clear : pal.line, lineWidth: 1)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

// MARK: - Atelier Numeric Field
struct AtelierNumericField: View {
    @Binding var value: Int
    var range: ClosedRange<Int> = 1...9999
    var step: Int = 1
    private var pal: AtelierPalette { ThemeManager.shared.palette }

    var body: some View {
        HStack(spacing: 4) {
            TextField("", value: $value, formatter: NumberFormatter())
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(pal.ink)
                .multilineTextAlignment(.center)
                .frame(width: 56)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(pal.paper)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(pal.line, lineWidth: 1)
                )

            Stepper("", value: $value, in: range, step: step)
                .labelsHidden()
        }
    }
}

// MARK: - Settings Tab Enum
enum SettingsTab: String, CaseIterable {
    case display = "Display"
    case search = "Search"
    case indexing = "Indexing"
    case server = "Server"
    case aiModel = "AI Model"

    var icon: String {
        switch self {
        case .display: return "paintbrush"
        case .search: return "magnifyingglass"
        case .indexing: return "square.stack.3d.up"
        case .server: return "server.rack"
        case .aiModel: return "cpu"
        }
    }
}

// MARK: - Kept Legacy Components (used by AddDirectorySheet, etc.)
struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let content: () -> Content
    @Environment(\.colorScheme) var colorScheme
    private var pal: AtelierPalette { ThemeManager.shared.palette }

    init(title: String, icon: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(pal.accent)
                Text(title)
                    .font(.system(size: 22, weight: .regular, design: .serif))
                    .foregroundColor(pal.ink)
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
    private var pal: AtelierPalette { ThemeManager.shared.palette }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(pal.accent)
                Text(title)
                    .font(.system(size: 13).weight(.medium))
                    .foregroundColor(pal.ink)
            }

            HStack(spacing: 8) {
                TextField("Path", text: $path)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 12))
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(pal.sidebar)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(pal.line, lineWidth: 1)
                    )

                Button(action: {
                    showPicker = true
                }) {
                    Text("Browse")
                        .font(.system(size: 12).weight(.medium))
                        .foregroundColor(pal.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(pal.accent.opacity(0.1))
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
    private var pal: AtelierPalette { ThemeManager.shared.palette }

    init(title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(pal.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(pal.line, lineWidth: 1)
        )
    }
}

// MARK: - Model Settings Section
struct AIModelSettingsSection: View {
    @ObservedObject private var modelSettings = ModelSettings.shared
    @State private var selectedModelId: String = ""
    @State private var showingConfirmation = false
    @State private var showingReindexAlert = false
    @State private var pendingModelId: String = ""
    @State private var customModelName: String = ""
    @State private var showingCustomModelInput = false
    @Environment(\.colorScheme) var colorScheme
    private var pal: AtelierPalette { ThemeManager.shared.palette }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Current Model Info Card
            AtelierCard(title: "Active Model", icon: "checkmark.circle.fill") {
                if modelSettings.isLoading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Fetching model info...")
                            .font(.system(size: 12))
                            .foregroundColor(pal.ink2)
                    }
                } else if !modelSettings.currentModelDisplayName.isEmpty {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(modelSettings.currentModelDisplayName)
                                .font(.system(size: 15, weight: .semibold, design: .serif))
                                .foregroundColor(pal.accent)

                            HStack(spacing: 16) {
                                HStack(spacing: 4) {
                                    Image(systemName: "cpu")
                                        .font(.system(size: 11))
                                    Text(modelSettings.currentDevice)
                                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                                }
                                HStack(spacing: 4) {
                                    Image(systemName: "number")
                                        .font(.system(size: 11))
                                    Text("\(modelSettings.currentEmbeddingDim)-dim")
                                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                                }
                            }
                            .foregroundColor(pal.ink2)
                        }
                        Spacer()
                    }
                }
            }

            // Model Selection Card
            AtelierCard(title: "Available Models", icon: "list.bullet") {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(modelSettings.availableModels) { model in
                        ModelSelectionRow(
                            model: model,
                            isSelected: modelSettings.currentModelName == model.id,
                            isCurrent: modelSettings.currentModelName == model.id,
                            onSelect: {
                                if model.id != modelSettings.currentModelName {
                                    pendingModelId = model.id
                                    if model.embeddingDim != modelSettings.currentEmbeddingDim {
                                        showingConfirmation = true
                                    } else {
                                        changeModel(to: model.id)
                                    }
                                }
                            }
                        )
                    }
                }

                AtelierDashedDivider()

                // Custom Model Input
                DisclosureGroup("Use Custom Model", isExpanded: $showingCustomModelInput) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Enter a HuggingFace model name (e.g., openai/clip-vit-base-patch32)")
                            .font(.system(size: 12, weight: .regular, design: .serif).italic())
                            .foregroundColor(pal.ink3)

                        HStack {
                            TextField("Model name", text: $customModelName)
                                .textFieldStyle(PlainTextFieldStyle())
                                .font(.system(size: 13, design: .monospaced))
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 7)
                                        .fill(pal.paper)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 7)
                                        .stroke(pal.line, lineWidth: 1)
                                )

                            Button(action: {
                                if !customModelName.isEmpty {
                                    pendingModelId = customModelName
                                    showingConfirmation = true
                                }
                            }) {
                                Text("Load")
                                    .font(.system(size: 13).weight(.semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(pal.accent)
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .disabled(customModelName.isEmpty || modelSettings.isChangingModel)
                        }
                    }
                    .padding(.top, 8)
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(pal.ink2)
            }

            // Error message
            if let error = modelSettings.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(DesignSystem.Colors.error)
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundColor(DesignSystem.Colors.error)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(DesignSystem.Colors.error.opacity(0.1))
                )
            }

            // Re-index warning
            if modelSettings.requiresReindex {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(DesignSystem.Colors.warning)
                    Text("Re-indexing required! The new model has different embedding dimensions.")
                        .font(.system(size: 12))
                        .foregroundColor(DesignSystem.Colors.warning)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(DesignSystem.Colors.warning.opacity(0.1))
                )
            }

            // Loading overlay
            if modelSettings.isChangingModel {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading model...")
                        .font(.system(size: 12))
                        .foregroundColor(pal.ink2)
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(pal.sidebar)
                )
            }
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
    private var pal: AtelierPalette { ThemeManager.shared.palette }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Radio indicator
                ZStack {
                    Circle()
                        .stroke(isCurrent ? pal.accent : pal.line, lineWidth: 2)
                        .frame(width: 20, height: 20)

                    if isCurrent {
                        Circle()
                            .fill(pal.accent)
                            .frame(width: 12, height: 12)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(model.name)
                            .font(.system(size: 13, weight: isCurrent ? .semibold : .medium))
                            .foregroundColor(isCurrent ? pal.accent : pal.ink)

                        if isCurrent {
                            Text("Active")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(pal.accent)
                                )
                        }
                    }

                    Text(model.description)
                        .font(.system(size: 12, weight: .regular, design: .serif).italic())
                        .foregroundColor(pal.ink3)

                    HStack(spacing: 12) {
                        Label("\(model.embeddingDim)-dim", systemImage: "number")
                        Label("\(model.sizeMB) MB", systemImage: "internaldrive")
                    }
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(pal.ink2)
                }

                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isCurrent ? pal.accent.opacity(0.08) : pal.paper.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isCurrent ? pal.accent.opacity(0.3) : Color.clear, lineWidth: 1)
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
    private var pal: AtelierPalette { ThemeManager.shared.palette }

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(DesignSystem.Colors.success)
                .frame(width: 8, height: 8)

            Image(systemName: "folder.fill")
                .foregroundColor(pal.accent)
                .font(.system(size: 14))

            VStack(alignment: .leading, spacing: 2) {
                Text(directory.path.components(separatedBy: "/").last ?? directory.path)
                    .font(.system(size: 13).weight(.medium))
                    .foregroundColor(pal.ink)

                Text(directory.displayPath)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(pal.ink2)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if let filterDesc = directory.filterDescription {
                    Text(filterDesc)
                        .font(.system(size: 11))
                        .foregroundColor(DesignSystem.Colors.success)
                }
            }

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(pal.ink3)
                    .font(.system(size: 13))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(pal.paper)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(pal.line, lineWidth: 1)
        )
    }
}

// MARK: - Add Directory Sheet
struct AddDirectorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    private var pal: AtelierPalette { ThemeManager.shared.palette }
    @ObservedObject var dirManager = DirectoryManager.shared

    @State private var selectedPath: String = ""
    @State private var filter: String = ""
    @State private var filterType: WatchedDirectory.FilterType = .all
    @State private var isShowingFolderPicker = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ADD DIRECTORY")
                        .font(.system(size: 9.5, weight: .semibold))
                        .tracking(1.6)
                        .foregroundColor(pal.ink3)
                    Text("Watch a folder")
                        .font(.system(size: 22, weight: .regular, design: .serif))
                        .foregroundColor(pal.ink)
                    Text("New images will be indexed automatically")
                        .font(.system(size: 13, weight: .regular, design: .serif))
                        .italic()
                        .foregroundColor(pal.ink2)
                }
                Spacer()
                Button(action: { dismiss() }) {
                    ZStack {
                        Circle()
                            .fill(pal.paper)
                            .overlay(Circle().stroke(pal.line, lineWidth: 1))
                            .frame(width: 28, height: 28)
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(pal.ink3)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)
            .background(pal.card)

            Rectangle().fill(pal.line).frame(height: 0.5)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Directory Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Directory", systemImage: "folder")
                            .font(.system(size: 13).weight(.medium))

                        HStack {
                            Text(selectedPath.isEmpty ? "Select a directory..." : selectedPath)
                                .font(.system(size: 13))
                                .foregroundColor(selectedPath.isEmpty ?
                                    pal.ink2 :
                                    pal.ink)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(pal.sidebar)
                                )

                            Button("Browse") {
                                isShowingFolderPicker = true
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    // Filter Type
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Filter Type", systemImage: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 13).weight(.medium))

                        Picker("", selection: $filterType) {
                            ForEach(WatchedDirectory.FilterType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // Filter Value (if not "All Files")
                    if filterType != .all {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Filter Value", systemImage: "text.magnifyingglass")
                                .font(.system(size: 13).weight(.medium))

                            TextField("e.g., Screenshot", text: $filter)
                                .textFieldStyle(.roundedBorder)

                            Text(filterHelpText)
                                .font(.system(size: 12))
                                .foregroundColor(pal.ink2)
                        }
                    }

                    // Add Button
                    Button(action: addDirectory) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Directory")
                        }
                        .font(.system(size: 13).weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(selectedPath.isEmpty ?
                                    pal.accent.opacity(0.5) :
                                    pal.accent)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(selectedPath.isEmpty)
                }
                .padding(24)
            }
        }
        .frame(width: 450, height: 400)
        .background(pal.paper)
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

// MARK: - Main Settings View (Tabbed Atelier Design)
struct SettingsView: View {
    @ObservedObject private var config = AppConfig.shared
    @ObservedObject private var prefs = SearchPreferences.shared
    @ObservedObject private var indexingSettings = IndexingSettings.shared
    @ObservedObject private var dirManager = DirectoryManager.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var isShowingBaseDirectoryPicker = false
    @State private var isShowingAddDirectorySheet = false
    @State private var isReindexing = false
    @State private var modelTTL: Int = 0  // 0 = never
    @State private var selectedTab: SettingsTab = .display
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    private var pal: AtelierPalette { ThemeManager.shared.palette }

    var body: some View {
        ZStack {
            pal.paper.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                settingsHeader

                // Tab bar
                tabBar

                // Content
                ScrollView {
                    VStack(spacing: 20) {
                        tabContent
                    }
                    .padding(28)
                }

                // Footer — always visible
                HStack(spacing: 12) {
                    Button(action: {
                        withAnimation { config.resetToDefaults() }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 11, weight: .medium))
                            Text("Reset to Defaults")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(DesignSystem.Colors.warning)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(DesignSystem.Colors.warning.opacity(0.08))
                        )
                        .overlay(
                            Capsule()
                                .stroke(DesignSystem.Colors.warning.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            NSApplication.shared.terminate(nil)
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "power")
                                .font(.system(size: 11, weight: .medium))
                            Text("Quit Searchy")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(DesignSystem.Colors.error)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(DesignSystem.Colors.error.opacity(0.08))
                        )
                        .overlay(
                            Capsule()
                                .stroke(DesignSystem.Colors.error.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())

                    Spacer()
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 12)
                .background(pal.sidebar.opacity(0.5))
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(pal.line),
                    alignment: .top
                )
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
        .onAppear { fetchModelTTL() }
    }

    // MARK: - Header
    private var settingsHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("PREFERENCES")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(2)
                    .foregroundColor(pal.ink3)
                Text("Settings")
                    .font(.system(size: 38, weight: .regular, design: .serif))
                    .foregroundColor(pal.ink)
                Text("Tune every corner of the experience")
                    .font(.system(size: 13, weight: .regular, design: .serif).italic())
                    .foregroundColor(pal.ink3)
            }

            Spacer()

            Button(action: { dismiss() }) {
                HStack(spacing: 5) {
                    Text("Done")
                        .font(.system(size: 13, weight: .semibold))
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(
                    Capsule()
                        .fill(pal.accent)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 28)
        .padding(.top, 24)
        .padding(.bottom, 16)
        .background(pal.sidebar)
    }

    // MARK: - Tab Bar
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(SettingsTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        selectedTab = tab
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 12, weight: .medium))
                        Text(tab.rawValue)
                            .font(.system(size: 12, weight: selectedTab == tab ? .semibold : .medium))
                    }
                    .foregroundColor(selectedTab == tab ? pal.accent : pal.ink2)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Group {
                            if selectedTab == tab {
                                Capsule()
                                    .fill(pal.accent.opacity(0.1))
                            }
                        }
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .background(pal.sidebar.opacity(0.5))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(pal.line),
            alignment: .bottom
        )
    }

    // MARK: - Tab Content Router
    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .display:
            displayTab
        case .search:
            searchTab
        case .indexing:
            indexingTab
        case .server:
            serverTab
        case .aiModel:
            aiModelTab
        }
    }

    // MARK: - Display Tab
    private var displayTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Section heading
            sectionHeading(
                eyebrow: "APPEARANCE",
                title: "The look of things",
                subtitle: "Palette, layout, and visual polish"
            )

            // Theme / Palette Card
            AtelierCard(title: "Palette", icon: "paintpalette") {
                VStack(alignment: .leading, spacing: 14) {
                    // Palette pills
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 100, maximum: 160), spacing: 8)
                    ], spacing: 8) {
                        ForEach(AppTheme.allCases, id: \.self) { theme in
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                    themeManager.currentTheme = theme
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(theme.palette.accent)
                                        .frame(width: 14, height: 14)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                        )
                                    Text(theme.rawValue)
                                        .font(.system(size: 12, weight: theme == themeManager.currentTheme ? .semibold : .regular))
                                        .lineLimit(1)
                                }
                                .foregroundColor(theme == themeManager.currentTheme ? .white : pal.ink2)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    Capsule()
                                        .fill(theme == themeManager.currentTheme ? pal.accent : pal.paper)
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(theme == themeManager.currentTheme ? Color.clear : pal.line, lineWidth: 1)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }

                    // Current palette note
                    if !themeManager.currentTheme.palette.note.isEmpty {
                        Text(themeManager.currentTheme.palette.note)
                            .font(.system(size: 12, weight: .regular, design: .serif).italic())
                            .foregroundColor(pal.ink3)
                    }

                    AtelierDashedDivider()

                    // Appearance mode (only for light palettes)
                    if !themeManager.currentTheme.isDark {
                        AtelierSettingRow(label: "Appearance", hint: "System follows macOS setting") {
                            HStack(spacing: 6) {
                                ForEach(AppearanceMode.allCases, id: \.self) { mode in
                                    Button(action: {
                                        withAnimation {
                                            themeManager.appearanceMode = mode
                                        }
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: mode.icon)
                                                .font(.system(size: 11))
                                            Text(mode.rawValue)
                                                .font(.system(size: 12, weight: mode == themeManager.appearanceMode ? .semibold : .regular))
                                        }
                                        .foregroundColor(mode == themeManager.appearanceMode ? .white : pal.ink2)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule()
                                                .fill(mode == themeManager.appearanceMode ? pal.accent : pal.paper)
                                        )
                                        .overlay(
                                            Capsule()
                                                .stroke(mode == themeManager.appearanceMode ? Color.clear : pal.line, lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                    }
                }
            }

            // Layout Card
            AtelierCard(title: "Layout", icon: "square.grid.2x2") {
                VStack(spacing: 0) {
                    AtelierSettingRow(label: "Grid Columns", hint: "Number of columns in results grid") {
                        AtelierPillSelector(
                            options: Array(2...6),
                            selected: $prefs.gridColumns,
                            label: { "\($0)" }
                        )
                    }

                    AtelierDashedDivider()
                        .padding(.vertical, 12)

                    AtelierSettingRow(label: "Image Size", hint: "Thumbnail size in the grid") {
                        HStack(spacing: 8) {
                            Text("S")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(pal.ink3)
                            Slider(value: $prefs.imageSize, in: 100...400, step: 50)
                                .frame(width: 140)
                            Text("L")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(pal.ink3)
                        }
                    }

                    AtelierDashedDivider()
                        .padding(.vertical, 12)

                    AtelierSettingRow(label: "Show Statistics", hint: "Display similarity scores and metadata") {
                        AtelierToggle(isOn: $prefs.showStats)
                    }
                }
            }
        }
    }

    // MARK: - Search Tab
    private var searchTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeading(
                eyebrow: "SEARCH",
                title: "Finding things",
                subtitle: "Result count, thresholds, and behaviour"
            )

            // Default Mode Card
            AtelierCard(title: "Default Mode", icon: "slider.horizontal.3") {
                VStack(spacing: 0) {
                    AtelierSettingRow(label: "Max Results", hint: "Maximum number of results returned") {
                        AtelierPillSelector(
                            options: [10, 20, 50, 100],
                            selected: $prefs.numberOfResults,
                            label: { "\($0)" }
                        )
                    }

                    AtelierDashedDivider()
                        .padding(.vertical, 12)

                    AtelierSettingRow(label: "Minimum Similarity", hint: "Only show results above this threshold") {
                        HStack(spacing: 8) {
                            Text("0%")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(pal.ink3)
                            Slider(value: $prefs.similarityThreshold, in: 0...1, step: 0.05)
                                .frame(width: 140)
                            Text("\(Int(prefs.similarityThreshold * 100))%")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(pal.ink)
                                .frame(width: 32, alignment: .trailing)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Indexing Tab
    private var indexingTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeading(
                eyebrow: "INDEXING",
                title: "Cataloguing the archive",
                subtitle: "Watched folders, schedule, and processing"
            )

            // Watched Folders Card
            AtelierCard(title: "Watched Folders", icon: "folder.badge.gearshape") {
                VStack(alignment: .leading, spacing: 10) {
                    if dirManager.watchedDirectories.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "questionmark.folder")
                                .font(.system(size: 16))
                                .foregroundColor(pal.ink3)
                            Text("No folders watched yet")
                                .font(.system(size: 13, weight: .regular, design: .serif).italic())
                                .foregroundColor(pal.ink3)
                        }
                        .padding(.vertical, 8)
                    } else {
                        ForEach(dirManager.watchedDirectories, id: \.path) { directory in
                            WatchedDirectoryRow(
                                directory: directory,
                                onDelete: {
                                    dirManager.removeDirectory(directory)
                                }
                            )
                        }
                    }

                    Button(action: {
                        isShowingAddDirectorySheet = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .bold))
                            Text("Add Folder")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(pal.accent)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(pal.accent.opacity(0.1))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            // Processing Card
            AtelierCard(title: "Processing", icon: "gearshape.2") {
                VStack(spacing: 0) {
                    AtelierSettingRow(label: "Fast Indexing", hint: "Resize large images before processing") {
                        AtelierToggle(isOn: $indexingSettings.enableFastIndexing)
                    }

                    AtelierDashedDivider()
                        .padding(.vertical, 12)

                    AtelierSettingRow(label: "Max Dimension", hint: "Larger values are slower but more accurate") {
                        HStack(spacing: 4) {
                            AtelierNumericField(
                                value: $indexingSettings.maxDimension,
                                range: 256...768,
                                step: 128
                            )
                            Text("px")
                                .font(.system(size: 12))
                                .foregroundColor(pal.ink2)
                        }
                    }

                    AtelierDashedDivider()
                        .padding(.vertical, 12)

                    AtelierSettingRow(label: "Batch Size", hint: "Images per batch. Higher = faster, more memory") {
                        AtelierNumericField(
                            value: $indexingSettings.batchSize,
                            range: 32...256,
                            step: 32
                        )
                    }
                }
            }
        }
    }

    // MARK: - Server Tab
    private var serverTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeading(
                eyebrow: "SERVER",
                title: "Under the hood",
                subtitle: "Port, directories, and memory management"
            )

            // Configuration Card
            AtelierCard(title: "Configuration", icon: "wrench.and.screwdriver") {
                VStack(spacing: 0) {
                    AtelierSettingRow(label: "Port", hint: "Local server port number") {
                        HStack(spacing: 4) {
                            TextField("", value: $config.defaultPort, formatter: NumberFormatter())
                                .textFieldStyle(PlainTextFieldStyle())
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundColor(pal.ink)
                                .multilineTextAlignment(.center)
                                .frame(width: 64)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(
                                    RoundedRectangle(cornerRadius: 7)
                                        .fill(pal.paper)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 7)
                                        .stroke(pal.line, lineWidth: 1)
                                )
                        }
                    }

                    AtelierDashedDivider()
                        .padding(.vertical, 12)

                    AtelierSettingRow(label: "Base Directory", hint: "Application data storage location") {
                        EmptyView()
                    }
                    HStack(spacing: 8) {
                        TextField("Directory", text: $config.baseDirectory)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: 12, design: .monospaced))
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(pal.paper)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 7)
                                    .stroke(pal.line, lineWidth: 1)
                            )

                        Button(action: {
                            isShowingBaseDirectoryPicker = true
                        }) {
                            Text("Browse")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(pal.accent)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(
                                    Capsule()
                                        .fill(pal.accent.opacity(0.1))
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }

            // Memory Management Card
            AtelierCard(title: "Memory Management", icon: "memorychip") {
                VStack(spacing: 0) {
                    AtelierSettingRow(label: "Model TTL", hint: "Unload CLIP model after idle period. Files stay cached on disk.") {
                        HStack(spacing: 6) {
                            ForEach([
                                (value: 0, label: "Never"),
                                (value: -10, label: "10s"),
                                (value: 5, label: "5m"),
                                (value: 15, label: "15m"),
                                (value: 30, label: "30m")
                            ], id: \.value) { option in
                                Button(action: {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                        modelTTL = option.value
                                        saveModelTTL(option.value)
                                    }
                                }) {
                                    Text(option.label)
                                        .font(.system(size: 12, weight: modelTTL == option.value ? .semibold : .regular))
                                        .foregroundColor(modelTTL == option.value ? .white : pal.ink2)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule()
                                                .fill(modelTTL == option.value ? pal.accent : pal.paper)
                                        )
                                        .overlay(
                                            Capsule()
                                                .stroke(modelTTL == option.value ? Color.clear : pal.line, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                }
            }

        }
    }

    // MARK: - AI Model Tab
    private var aiModelTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeading(
                eyebrow: "AI MODEL",
                title: "The seeing eye",
                subtitle: "CLIP model selection and configuration"
            )

            AIModelSettingsSection()
        }
    }

    // MARK: - Section Heading Helper
    private func sectionHeading(eyebrow: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(eyebrow)
                .font(.system(size: 10, weight: .semibold))
                .tracking(2)
                .foregroundColor(pal.accent)

            Text(title)
                .font(.system(size: 28, weight: .regular, design: .serif))
                .foregroundColor(pal.ink)

            Text(subtitle)
                .font(.system(size: 13, weight: .regular, design: .serif).italic())
                .foregroundColor(pal.ink3)
        }
        .padding(.bottom, 4)
    }

    // MARK: - Network Functions (unchanged)
    private func fetchModelTTL() {
        Task {
            let delegate = await AppDelegate.shared
            guard let serverURL = await delegate.serverURL else { return }
            let url = serverURL.appendingPathComponent("model/ttl")
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let ttl = json["ttl_minutes"] as? Int else { return }
            await MainActor.run { self.modelTTL = ttl }
        }
    }

    private func saveModelTTL(_ minutes: Int) {
        Task {
            let delegate = await AppDelegate.shared
            guard let serverURL = await delegate.serverURL else { return }
            let url = serverURL.appendingPathComponent("model/ttl")
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: ["ttl_minutes": minutes])
            _ = try? await URLSession.shared.data(for: request)
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

// MARK: - Setup Tab Helper Views

struct SetupModelRow: View {
    let model: CLIPModelInfo
    let isSelected: Bool
    let isChanging: Bool
    let onSelect: () -> Void
    @Environment(\.colorScheme) var colorScheme
    private var pal: AtelierPalette { ThemeManager.shared.palette }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                // Selection indicator
                Circle()
                    .fill(isSelected ? pal.accent : Color.clear)
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .stroke(isSelected ? pal.accent : pal.line, lineWidth: 1.5)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(model.name)
                        .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                        .foregroundColor(isSelected ? pal.accent : pal.ink)

                    Text("\(model.embeddingDim)-dim \u{2022} \(model.sizeMB)MB")
                        .font(.system(size: 10))
                        .foregroundColor(pal.ink2)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(pal.accent)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ?
                        pal.accent.opacity(0.08) :
                        (pal.isDark ? Color.white.opacity(0.03) : Color.black.opacity(0.02)))
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
    private var pal: AtelierPalette { ThemeManager.shared.palette }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder.fill")
                .font(.system(size: 14))
                .foregroundColor(pal.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(URL(fileURLWithPath: directory.path).lastPathComponent)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(pal.ink)
                    .lineLimit(1)

                Text(directory.path)
                    .font(.system(size: 10))
                    .foregroundColor(pal.ink2)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            // Filter badge if present
            if directory.filterType != .all && !directory.filter.isEmpty {
                Text(directory.filter)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(pal.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(pal.accent.opacity(0.1))
                    )
            }

            // Delete button on hover
            if isHovered {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(pal.ink2)
                }
                .buttonStyle(PlainButtonStyle())
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(pal.isDark ? Color.white.opacity(0.03) : Color.black.opacity(0.02))
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
    private var pal: AtelierPalette { ThemeManager.shared.palette }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(color)
                .frame(width: 24)

            Text(label)
                .font(.system(size: 12))
                .foregroundColor(pal.ink2)

            Spacer()

            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(pal.ink)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(pal.isDark ? Color.white.opacity(0.03) : Color.black.opacity(0.02))
        )
    }
}
