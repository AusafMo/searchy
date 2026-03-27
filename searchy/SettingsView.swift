import SwiftUI
import Foundation
import UniformTypeIdentifiers

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

    var body: some View {
        SettingsSection(title: "CLIP Model", icon: "cpu") {
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
    @State private var modelTTL: Int = 0  // 0 = never
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

                        SettingsGroup(title: "Memory Management") {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Label("Model TTL", systemImage: "timer")
                                    Spacer()
                                    Picker("", selection: $modelTTL) {
                                        Text("Never").tag(0)
                                        Text("10 sec").tag(-10)
                                        Text("5 min").tag(5)
                                        Text("15 min").tag(15)
                                        Text("30 min").tag(30)
                                    }
                                    .frame(width: 120)
                                    .onChange(of: modelTTL) { _, newValue in
                                        saveModelTTL(newValue)
                                    }
                                }
                                Text("Unload CLIP model from memory after idle period. Model files stay cached on disk — no re-download needed.")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.tertiaryText)
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

                    Button(action: {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            NSApplication.shared.terminate(nil)
                        }
                    }) {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            Image(systemName: "power")
                                .font(.system(size: 14))
                            Text("Quit Searchy")
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
        .onAppear { fetchModelTTL() }
    }

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

