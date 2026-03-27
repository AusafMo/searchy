import SwiftUI
import AppKit
import Foundation
import UniformTypeIdentifiers
import Vision
import ImageCaptureCore

// MARK: - Global Constants
let kAppSupportPath: String = {
    let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    return appSupport.appendingPathComponent("searchy").path
}()



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
    @State private var peopleSearchText = ""
    @State private var selectedPeopleIds: Set<String> = []
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
    @State private var modelState: String = "pending"
    @State private var modelMessage: String = ""
    @State private var modelElapsed: Double = 0
    @State private var modelPollTimer: Timer? = nil
    @State private var updateAvailable: String? = nil  // nil = no update, else new version string
    @State private var showUpdateBanner = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            // Clean solid background
            (colorScheme == .dark ? Color(hex: "000000") : Color(hex: "FFFFFF"))
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Friendly header
                modernHeader

                // Update banner
                if showUpdateBanner, let newVersion = updateAvailable {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 13))
                        Text("Searchy v\(newVersion) available")
                            .font(.system(size: 12, weight: .medium))
                        Text("—")
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                        Text("brew upgrade --cask searchy")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                        Button(action: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString("brew upgrade --cask searchy", forType: .string)
                        }) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 10))
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Copy command")
                        Spacer()
                        Button(action: { withAnimation { showUpdateBanner = false } }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .foregroundColor(DesignSystem.Colors.accent)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(DesignSystem.Colors.accent.opacity(0.08))
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Tab Picker
                tabPicker
                    .padding(.top, DesignSystem.Spacing.md)

                // Main content area based on active tab
                switch activeTab {
                case .faces:
                    facesTabContent
                case .search:
                    searchTabContent
                case .volumes:
                    volumesTabContent
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
            startModelStatusPolling()
            checkForUpdates()
            // Focus the search field on appear
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isSearchFocused = true
            }
        }
        .onDisappear {
            searchManager.cancelSearch()
            removePasteMonitor()
            modelPollTimer?.invalidate()
            modelPollTimer = nil
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
                // Model loading indicator
                if modelState == "loading" {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text("Loading model \(String(format: "%.0fs", modelElapsed))")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(Capsule())
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                } else if modelState == "ready" && modelElapsed > 0 {
                    Text("Model ready \(String(format: "%.1fs", modelElapsed))")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.green)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.green.opacity(0.1))
                        .clipShape(Capsule())
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                                withAnimation { self.modelElapsed = 0 }
                            }
                        }
                } else if modelState == "unloaded" {
                    Text("Model unloaded")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Capsule())
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }

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

    private var filteredPeople: [Person] {
        var result = faceManager.sortedPeople

        // Filter by search text
        if !peopleSearchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(peopleSearchText)
            }
        }

        // Filter by group
        if let groupFilter = faceManager.selectedGroupFilter {
            result = result.filter {
                faceManager.getGroupsForCluster($0.id).contains(groupFilter)
            }
        }

        return result
    }

    private var facesTabContent: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("People")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(DesignSystem.Colors.primaryText)
                    if faceManager.totalFacesDetected > 0 {
                        if !peopleSearchText.isEmpty {
                            Text("\(filteredPeople.count) of \(faceManager.people.count) people")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                        } else {
                            Text("\(faceManager.people.count) people • \(faceManager.totalFacesDetected) faces")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                        }
                    }
                }

                Spacer()

                // Selected count indicator (when items selected)
                if !selectedPeopleIds.isEmpty {
                    HStack(spacing: 8) {
                        Text("\(selectedPeopleIds.count) selected")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.accent)

                        Button(action: {
                            withAnimation {
                                selectedPeopleIds.removeAll()
                            }
                        }) {
                            Text("Clear")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.trailing, 8)
                }

                if faceManager.hasScannedBefore && !faceManager.isScanning && selectedPeopleIds.isEmpty {
                    Button(action: {
                        faceManager.clearAllFaces()
                    }) {
                        Text("Clear All")
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

                // Show unverified count badge
                if faceManager.totalUnverifiedCount > 0 && !faceManager.isScanning {
                    HStack(spacing: 3) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 9))
                        Text("\(faceManager.totalUnverifiedCount) to review")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.orange.opacity(0.8)))
                    .padding(.trailing, 4)
                }

                // Show Hidden toggle (only when there are hidden people)
                if faceManager.hiddenCount > 0 {
                    Button(action: {
                        withAnimation {
                            faceManager.showHidden.toggle()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: faceManager.showHidden ? "eye" : "eye.slash")
                                .font(.system(size: 11, weight: .medium))
                            Text("\(faceManager.hiddenCount)")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(faceManager.showHidden ? DesignSystem.Colors.accent : DesignSystem.Colors.secondaryText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(faceManager.showHidden
                                      ? DesignSystem.Colors.accent.opacity(colorScheme == .dark ? 0.2 : 0.1)
                                      : (colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.04)))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
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

                // Re-cluster button - only show when there are verified faces
                if faceManager.hasVerifiedFaces && !faceManager.isScanning {
                    Button(action: {
                        faceManager.reclusterWithConstraints()
                    }) {
                        HStack(spacing: 6) {
                            if faceManager.isReclustering {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .frame(width: 14, height: 14)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            Text(faceManager.isReclustering ? "Re-clustering..." : "Re-cluster")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(DesignSystem.Colors.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(DesignSystem.Colors.accent, lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(faceManager.isReclustering)
                    .help("Re-assign faces using verified faces as anchors")
                }
            }
            .padding(.bottom, DesignSystem.Spacing.md)
            .onAppear {
                faceManager.refreshNewImagesCount()
            }

            // Search bar - only show when there are people
            if !faceManager.people.isEmpty && selectedPerson == nil {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)

                    TextField("Search people...", text: $peopleSearchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 14))
                        .foregroundColor(DesignSystem.Colors.primaryText)

                    if !peopleSearchText.isEmpty {
                        Button(action: {
                            withAnimation {
                                peopleSearchText = ""
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(DesignSystem.Colors.tertiaryText)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06), lineWidth: 1)
                )
                .padding(.bottom, DesignSystem.Spacing.sm)
            }

            // Group filter bar - only show when there are groups
            if !faceManager.availableGroups.isEmpty && selectedPerson == nil {
                groupFilterBar
                    .padding(.bottom, DesignSystem.Spacing.md)
            }

            // Scanning progress
            if faceManager.isScanning {
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        // Animated face icon
                        ZStack {
                            Circle()
                                .fill(DesignSystem.Colors.accent.opacity(colorScheme == .dark ? 0.2 : 0.1))
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
                                .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.06))
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
                        .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.03))
                        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.05), radius: 8, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(colorScheme == .dark ? Color.white.opacity(0.08) : Color.clear, lineWidth: 1)
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
                                        DesignSystem.Colors.accent.opacity(colorScheme == .dark ? 0.25 : 0.15),
                                        DesignSystem.Colors.accent.opacity(colorScheme == .dark ? 0.1 : 0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)

                        Image(systemName: "person.2.crop.square.stack")
                            .font(.system(size: 48, weight: .light))
                            .foregroundColor(DesignSystem.Colors.accent.opacity(colorScheme == .dark ? 0.8 : 0.7))
                    }

                    VStack(spacing: 8) {
                        Text("Face Recognition")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(DesignSystem.Colors.primaryText)

                        Text(faceManager.hasScannedBefore
                             ? "No faces found in your photos.\nTry scanning more images."
                             : "Find and group people in your photos\nusing face detection.")
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
                if filteredPeople.isEmpty {
                    if !peopleSearchText.isEmpty {
                        // No search results
                        VStack(spacing: 16) {
                            Spacer()
                            Image(systemName: "person.slash")
                                .font(.system(size: 40, weight: .light))
                                .foregroundColor(DesignSystem.Colors.tertiaryText)
                            Text("No people matching \"\(peopleSearchText)\"")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                            Button(action: { peopleSearchText = "" }) {
                                Text("Clear Search")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(DesignSystem.Colors.accent)
                            }
                            .buttonStyle(PlainButtonStyle())
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if faceManager.selectedGroupFilter != nil {
                        // Group filter filters out everyone
                        VStack(spacing: 16) {
                            Spacer()
                            Image(systemName: "person.2.slash")
                                .font(.system(size: 40, weight: .light))
                                .foregroundColor(DesignSystem.Colors.tertiaryText)
                            Text("No people in this group")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                            Button(action: { faceManager.selectedGroupFilter = nil }) {
                                Text("Show All")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(DesignSystem.Colors.accent)
                            }
                            .buttonStyle(PlainButtonStyle())
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if !faceManager.showHidden && faceManager.hiddenCount > 0 && faceManager.people.count == faceManager.hiddenCount {
                        // All people are hidden
                        VStack(spacing: 16) {
                            Spacer()
                            Image(systemName: "eye.slash")
                                .font(.system(size: 40, weight: .light))
                                .foregroundColor(DesignSystem.Colors.tertiaryText)
                            Text("All people are hidden")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                            Button(action: { faceManager.showHidden = true }) {
                                Text("Show Hidden")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(DesignSystem.Colors.accent)
                            }
                            .buttonStyle(PlainButtonStyle())
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        // Fallback empty state - shouldn't normally happen
                        VStack(spacing: 16) {
                            Spacer()
                            Image(systemName: "person.crop.circle.badge.questionmark")
                                .font(.system(size: 40, weight: .light))
                                .foregroundColor(DesignSystem.Colors.tertiaryText)
                            Text("No people to display")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.adaptive(minimum: 130, maximum: 150), spacing: 12)
                        ], spacing: 14) {
                            ForEach(filteredPeople) { person in
                                PersonCard(
                                    person: person,
                                    isPinned: faceManager.isPinned(person),
                                    isHidden: faceManager.isHidden(person),
                                    isSelected: selectedPeopleIds.contains(person.id),
                                    onRename: { newName in
                                        Task {
                                            await faceManager.renamePerson(person, to: newName)
                                        }
                                    },
                                    onSelect: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedPerson = person
                                        }
                                    },
                                    onTogglePin: {
                                        Task {
                                            await faceManager.togglePin(person)
                                        }
                                    },
                                    onToggleHide: {
                                        Task {
                                            await faceManager.toggleHide(person)
                                        }
                                    },
                                    onToggleSelection: {
                                        withAnimation {
                                            if selectedPeopleIds.contains(person.id) {
                                                selectedPeopleIds.remove(person.id)
                                            } else {
                                                selectedPeopleIds.insert(person.id)
                                            }
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.top, 8)
                        .padding(.bottom, !selectedPeopleIds.isEmpty ? 80 : 16)
                    }

                    // Floating selection action bar
                    if !selectedPeopleIds.isEmpty {
                        selectionActionBar
                    }
                }
            }
        }
        .padding(.top, DesignSystem.Spacing.lg)
        .padding(.horizontal, DesignSystem.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var groupFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // All filter (no filter)
                Button(action: {
                    withAnimation { faceManager.selectedGroupFilter = nil }
                }) {
                    Text("All")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(faceManager.selectedGroupFilter == nil ? .white : DesignSystem.Colors.secondaryText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(faceManager.selectedGroupFilter == nil ? DesignSystem.Colors.accent : (colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)))
                        )
                }
                .buttonStyle(PlainButtonStyle())

                // Group filters
                ForEach(faceManager.availableGroups, id: \.self) { group in
                    Button(action: {
                        withAnimation {
                            faceManager.selectedGroupFilter = faceManager.selectedGroupFilter == group ? nil : group
                        }
                    }) {
                        Text(group)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(faceManager.selectedGroupFilter == group ? .white : DesignSystem.Colors.secondaryText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(faceManager.selectedGroupFilter == group ? DesignSystem.Colors.accent : (colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                // Add group button
                Button(action: { showAddGroupSheet = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                        .frame(width: 26, height: 26)
                        .background(
                            Circle()
                                .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04))
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    @State private var showAddGroupSheet = false
    @State private var newGroupName = ""

    private var selectionActionBar: some View {
        VStack {
            Spacer()
            HStack(spacing: 16) {
                // Hide/Unhide button
                Button(action: {
                    Task {
                        for id in selectedPeopleIds {
                            if let person = faceManager.people.first(where: { $0.id == id }) {
                                await faceManager.toggleHide(person)
                            }
                        }
                        withAnimation {
                            selectedPeopleIds.removeAll()
                        }
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "eye.slash")
                            .font(.system(size: 18))
                        Text("Hide")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(width: 60)
                }
                .buttonStyle(PlainButtonStyle())

                // Pin/Unpin button
                Button(action: {
                    Task {
                        for id in selectedPeopleIds {
                            if let person = faceManager.people.first(where: { $0.id == id }) {
                                await faceManager.togglePin(person)
                            }
                        }
                        withAnimation {
                            selectedPeopleIds.removeAll()
                        }
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "pin")
                            .font(.system(size: 18))
                        Text("Pin")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(width: 60)
                }
                .buttonStyle(PlainButtonStyle())

                // Merge button (only when 2+ selected)
                if selectedPeopleIds.count >= 2 {
                    Button(action: {
                        bulkMergeTargetId = nil
                        showBulkMergeSheet = true
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.merge")
                                .font(.system(size: 18))
                            Text("Merge")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .frame(width: 60)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                // Select All button
                Button(action: {
                    withAnimation {
                        if selectedPeopleIds.count == filteredPeople.count {
                            selectedPeopleIds.removeAll()
                        } else {
                            selectedPeopleIds = Set(filteredPeople.map { $0.id })
                        }
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: selectedPeopleIds.count == filteredPeople.count ? "checkmark.circle" : "checkmark.circle.fill")
                            .font(.system(size: 18))
                        Text(selectedPeopleIds.count == filteredPeople.count ? "Deselect" : "All")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(width: 60)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.85))
                    .shadow(color: Color.black.opacity(0.3), radius: 10, y: 4)
            )
            .padding(.bottom, 16)
        }
        .sheet(isPresented: $showBulkMergeSheet) {
            bulkMergeSheet
        }
    }

    private var bulkMergeSheet: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Merge \(selectedPeopleIds.count) People")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                Spacer()
                Button(action: { showBulkMergeSheet = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()

            // Info text
            Text("Select which person to keep. All other selected people will be merged into them.")
                .font(.system(size: 13))
                .foregroundColor(DesignSystem.Colors.secondaryText)
                .padding(.horizontal)
                .padding(.bottom, 16)

            // List of selected people to pick target
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(bulkMergeSelectedPeople) { person in
                        bulkMergeTargetRow(person)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, bulkMergeTargetId == nil ? 16 : 80)
            }

            // Bottom action bar when target is selected
            if let targetId = bulkMergeTargetId,
               let target = faceManager.people.first(where: { $0.id == targetId }) {
                VStack(spacing: 0) {
                    Divider()
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Keep: \(target.name)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.primaryText)
                            Text("Merge \(selectedPeopleIds.count - 1) others into this person")
                                .font(.system(size: 11))
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                        }

                        Spacer()

                        if isMerging {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("Merging...")
                                    .font(.system(size: 13))
                                    .foregroundColor(DesignSystem.Colors.secondaryText)
                            }
                        } else {
                            Button(action: performBulkMerge) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.triangle.merge")
                                        .font(.system(size: 12, weight: .medium))
                                    Text("Merge")
                                        .font(.system(size: 13, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(DesignSystem.Colors.accent)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding()
                }
                .background(colorScheme == .dark ? Color(hex: "1a1a1a") : Color.white)
            }
        }
        .frame(width: 380, height: 450)
        .background(colorScheme == .dark ? Color(hex: "1a1a1a") : Color.white)
    }

    private var bulkMergeSelectedPeople: [Person] {
        return faceManager.people.filter { selectedPeopleIds.contains($0.id) }
    }

    private func bulkMergeTargetRow(_ person: Person) -> some View {
        let isTarget = bulkMergeTargetId == person.id
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                bulkMergeTargetId = person.id
            }
        }) {
            HStack(spacing: 12) {
                // Radio button
                ZStack {
                    Circle()
                        .stroke(isTarget ? DesignSystem.Colors.accent : DesignSystem.Colors.tertiaryText, lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isTarget {
                        Circle()
                            .fill(DesignSystem.Colors.accent)
                            .frame(width: 14, height: 14)
                    }
                }

                // Thumbnail
                if let thumbPath = person.thumbnailPath,
                   let image = NSImage(contentsOfFile: thumbPath) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(DesignSystem.Colors.tertiaryText)
                        )
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(person.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.primaryText)
                    Text("\(person.faceCount) photos")
                        .font(.system(size: 12))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }

                Spacer()

                if isTarget {
                    Text("Keep")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(DesignSystem.Colors.accent.opacity(0.15))
                        )
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isTarget
                          ? DesignSystem.Colors.accent.opacity(colorScheme == .dark ? 0.15 : 0.1)
                          : (colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.02)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isTarget ? DesignSystem.Colors.accent.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isMerging)
    }

    private func performBulkMerge() {
        guard let targetId = bulkMergeTargetId,
              let target = faceManager.people.first(where: { $0.id == targetId }) else { return }

        let sourceIds = selectedPeopleIds.filter { $0 != targetId }
        guard !sourceIds.isEmpty else { return }

        isMerging = true

        Task {
            var allSuccess = true
            for sourceId in sourceIds {
                if let source = faceManager.people.first(where: { $0.id == sourceId }) {
                    let success = await faceManager.mergePeople(source: source, into: target)
                    if !success {
                        allSuccess = false
                    }
                }
            }

            await MainActor.run {
                isMerging = false
                if allSuccess {
                    showBulkMergeSheet = false
                    selectedPeopleIds.removeAll()
                    bulkMergeTargetId = nil
                }
            }
        }
    }

    @State private var isEditingPersonName = false
    @State private var editingPersonName = ""
    @FocusState private var personNameFieldFocused: Bool
    @State private var showMergeSheet = false
    @State private var mergeSearchText = ""
    @State private var mergeSelectedIds: Set<String> = []
    @State private var isMerging = false
    @State private var showBulkMergeSheet = false
    @State private var bulkMergeTargetId: String? = nil
    @State private var showVerificationView = false
    @State private var selectedFaceIds: Set<UUID> = []
    @State private var isSelectionMode = false
    @State private var isBatchProcessing = false

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
                                .fill(DesignSystem.Colors.accent.opacity(colorScheme == .dark ? 0.2 : 0.1))
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
                                    .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.04))
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

                    // Review button (only show if there are unverified faces)
                    if person.unverifiedCount > 0 {
                        Button(action: {
                            showVerificationView = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle")
                                    .font(.system(size: 12, weight: .medium))
                                Text("Review")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(.orange)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(Color.orange.opacity(colorScheme == .dark ? 0.2 : 0.1))
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    // Merge button
                    Button(action: {
                        mergeSearchText = ""
                        mergeSelectedIds.removeAll()
                        showMergeSheet = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.merge")
                                .font(.system(size: 12, weight: .medium))
                            Text("Merge")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.04))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())

                    // Share button
                    Button(action: {
                        sharePersonPhotos(person)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 12, weight: .medium))
                            Text("Share")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(DesignSystem.Colors.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(DesignSystem.Colors.accent.opacity(colorScheme == .dark ? 0.2 : 0.1))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())

                    // Create Album button
                    Button(action: {
                        createAlbumForPerson(person)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "folder.badge.plus")
                                .font(.system(size: 12, weight: .medium))
                            Text("Album")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.04))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())

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
                            .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.04))
                    )
                }
            }
            .padding(.bottom, DesignSystem.Spacing.lg)

            // Person's photos grid
            if let person = selectedPerson {
                if person.faces.isEmpty {
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
                    VStack(spacing: 0) {
                        // Selection toolbar
                        HStack(spacing: 12) {
                            // Selection mode toggle
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isSelectionMode.toggle()
                                    if !isSelectionMode {
                                        selectedFaceIds.removeAll()
                                    }
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: isSelectionMode ? "checkmark.circle.fill" : "checkmark.circle")
                                        .font(.system(size: 12, weight: .medium))
                                    Text(isSelectionMode ? "Done" : "Select")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundColor(isSelectionMode ? .white : DesignSystem.Colors.secondaryText)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule()
                                        .fill(isSelectionMode ? DesignSystem.Colors.accent : (colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.04)))
                                )
                            }
                            .buttonStyle(PlainButtonStyle())

                            if isSelectionMode {
                                // Select all / Deselect all
                                Button(action: {
                                    if selectedFaceIds.count == person.faces.count {
                                        selectedFaceIds.removeAll()
                                    } else {
                                        selectedFaceIds = Set(person.faces.map { $0.id })
                                    }
                                }) {
                                    Text(selectedFaceIds.count == person.faces.count ? "Deselect All" : "Select All")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(DesignSystem.Colors.accent)
                                }
                                .buttonStyle(PlainButtonStyle())

                                if !selectedFaceIds.isEmpty {
                                    Text("\(selectedFaceIds.count) selected")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(DesignSystem.Colors.secondaryText)
                                }
                            }

                            Spacer()

                            // Batch action buttons (only when items selected)
                            if isSelectionMode && !selectedFaceIds.isEmpty {
                                // Batch Verify
                                Button(action: {
                                    batchVerifySelectedFaces(person: person, isCorrect: true)
                                }) {
                                    HStack(spacing: 4) {
                                        if isBatchProcessing {
                                            ProgressView()
                                                .scaleEffect(0.6)
                                                .frame(width: 12, height: 12)
                                        } else {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 11, weight: .bold))
                                        }
                                        Text("Verify All")
                                            .font(.system(size: 12, weight: .semibold))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(Color.green))
                                }
                                .buttonStyle(PlainButtonStyle())
                                .disabled(isBatchProcessing)

                                // Batch Reject
                                Button(action: {
                                    batchVerifySelectedFaces(person: person, isCorrect: false)
                                }) {
                                    HStack(spacing: 4) {
                                        if isBatchProcessing {
                                            ProgressView()
                                                .scaleEffect(0.6)
                                                .frame(width: 12, height: 12)
                                        } else {
                                            Image(systemName: "xmark")
                                                .font(.system(size: 11, weight: .bold))
                                        }
                                        Text("Reject All")
                                            .font(.system(size: 12, weight: .semibold))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(Color.red))
                                }
                                .buttonStyle(PlainButtonStyle())
                                .disabled(isBatchProcessing)
                            }

                            // Hint (when not in selection mode)
                            if !isSelectionMode && person.unverifiedCount > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "lightbulb.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(.orange)
                                    Text("Hover to verify")
                                        .font(.system(size: 11))
                                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.bottom, 12)

                        ScrollView {
                            LazyVGrid(columns: [
                                GridItem(.adaptive(minimum: 160, maximum: 220), spacing: 16)
                            ], spacing: 16) {
                                ForEach(person.faces, id: \.id) { face in
                                    let result = SearchResult(
                                        path: face.imagePath,
                                        similarity: 1.0,
                                        size: (try? FileManager.default.attributesOfItem(atPath: face.imagePath)[.size] as? Int) ?? 0,
                                        date: nil,
                                        type: URL(fileURLWithPath: face.imagePath).pathExtension.lowercased()
                                    )
                                    PersonFaceCard(
                                        face: face,
                                        personId: person.id,
                                        result: result,
                                        faceManager: faceManager,
                                        isSelected: selectedFaceIds.contains(face.id),
                                        isSelectionMode: isSelectionMode,
                                        onSelect: {
                                            if selectedFaceIds.contains(face.id) {
                                                selectedFaceIds.remove(face.id)
                                            } else {
                                                selectedFaceIds.insert(face.id)
                                            }
                                        }
                                    )
                                }
                            }
                            .padding(.bottom, 20)
                        }
                    }
                }
            }
        }
        .onChange(of: selectedPerson) { _ in
            // Clear selection when changing person
            selectedFaceIds.removeAll()
            isSelectionMode = false
        }
        .sheet(isPresented: $showMergeSheet) {
            mergePersonSheet
        }
        .sheet(isPresented: $showVerificationView) {
            if let person = selectedPerson {
                FaceVerificationView(
                    person: person,
                    faceManager: faceManager,
                    onDismiss: {
                        showVerificationView = false
                    }
                )
            }
        }
        .sheet(isPresented: $showAddGroupSheet) {
            addGroupSheet
        }
    }

    private var addGroupSheet: some View {
        VStack(spacing: 16) {
            Text("Create Group")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(DesignSystem.Colors.primaryText)

            TextField("Group name", text: $newGroupName)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 14))
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04))
                )

            HStack(spacing: 12) {
                Button(action: { showAddGroupSheet = false; newGroupName = "" }) {
                    Text("Cancel")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.04)))
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: {
                    if !newGroupName.isEmpty {
                        Task {
                            await faceManager.createGroup(newGroupName)
                            newGroupName = ""
                            showAddGroupSheet = false
                        }
                    }
                }) {
                    Text("Create")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(DesignSystem.Colors.accent))
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(newGroupName.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 280)
        .background(DesignSystem.Colors.secondaryBackground)
    }

    private var mergePersonSheet: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Merge People")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                Spacer()
                Button(action: { showMergeSheet = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()

            // Info text
            if let target = selectedPerson {
                Text("Select people to merge into \"\(target.name)\". Their faces will be combined into this person.")
                    .font(.system(size: 13))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .padding(.horizontal)
                    .padding(.bottom, 12)
            }

            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.tertiaryText)

                TextField("Search people...", text: $mergeSearchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 14))
                    .foregroundColor(DesignSystem.Colors.primaryText)

                if !mergeSearchText.isEmpty {
                    Button(action: { mergeSearchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04))
            )
            .padding(.horizontal)
            .padding(.bottom, 12)

            // People list with multi-select
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(mergeTargetPeople) { person in
                        mergePeopleRow(person)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, mergeSelectedIds.isEmpty ? 16 : 80)
            }

            // Bottom action bar
            if !mergeSelectedIds.isEmpty {
                VStack(spacing: 0) {
                    Divider()
                    HStack {
                        Text("\(mergeSelectedIds.count) selected")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.secondaryText)

                        Spacer()

                        if isMerging {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("Merging...")
                                    .font(.system(size: 13))
                                    .foregroundColor(DesignSystem.Colors.secondaryText)
                            }
                        } else {
                            Button(action: performMerge) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.triangle.merge")
                                        .font(.system(size: 12, weight: .medium))
                                    Text("Merge into \(selectedPerson?.name ?? "Person")")
                                        .font(.system(size: 13, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(DesignSystem.Colors.accent)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding()
                }
                .background(colorScheme == .dark ? Color(hex: "1a1a1a") : Color.white)
            }
        }
        .frame(width: 420, height: 520)
        .background(colorScheme == .dark ? Color(hex: "1a1a1a") : Color.white)
    }

    private var mergeTargetPeople: [Person] {
        // Exclude the currently selected person and filter by search
        let available = faceManager.people.filter { $0.id != selectedPerson?.id }
        if mergeSearchText.isEmpty {
            return available
        }
        return available.filter {
            $0.name.localizedCaseInsensitiveContains(mergeSearchText)
        }
    }

    private func mergePeopleRow(_ person: Person) -> some View {
        let isSelected = mergeSelectedIds.contains(person.id)
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                if isSelected {
                    mergeSelectedIds.remove(person.id)
                } else {
                    mergeSelectedIds.insert(person.id)
                }
            }
        }) {
            HStack(spacing: 12) {
                // Selection checkbox
                ZStack {
                    Circle()
                        .stroke(isSelected ? DesignSystem.Colors.accent : DesignSystem.Colors.tertiaryText, lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(DesignSystem.Colors.accent)
                            .frame(width: 22, height: 22)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

                // Thumbnail
                if let thumbPath = person.thumbnailPath,
                   let image = NSImage(contentsOfFile: thumbPath) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(DesignSystem.Colors.tertiaryText)
                        )
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(person.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.primaryText)
                    Text("\(person.faceCount) photos")
                        .font(.system(size: 12))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }

                Spacer()
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected
                          ? DesignSystem.Colors.accent.opacity(colorScheme == .dark ? 0.15 : 0.1)
                          : (colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.02)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? DesignSystem.Colors.accent.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isMerging)
    }

    private func performMerge() {
        guard let target = selectedPerson, !mergeSelectedIds.isEmpty else { return }
        isMerging = true

        Task {
            var allSuccess = true
            // Merge each selected person into the target (current person)
            for sourceId in mergeSelectedIds {
                if let source = faceManager.people.first(where: { $0.id == sourceId }) {
                    let success = await faceManager.mergePeople(source: source, into: target)
                    if !success {
                        allSuccess = false
                    }
                }
            }

            await MainActor.run {
                isMerging = false
                if allSuccess {
                    showMergeSheet = false
                    mergeSelectedIds.removeAll()
                    // Update selectedPerson to refreshed version
                    if let updated = faceManager.people.first(where: { $0.id == target.id }) {
                        selectedPerson = updated
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

    private func sharePersonPhotos(_ person: Person) {
        let images = faceManager.getImagesForPerson(person)
        let urls = images.compactMap { URL(fileURLWithPath: $0.path) }

        guard !urls.isEmpty else { return }

        // Get the key window to show the share picker
        guard let window = NSApp.keyWindow else { return }

        let picker = NSSharingServicePicker(items: urls)
        // Show the picker relative to the window's content view
        if let contentView = window.contentView {
            let rect = CGRect(x: contentView.bounds.midX, y: contentView.bounds.maxY - 50, width: 1, height: 1)
            picker.show(relativeTo: rect, of: contentView, preferredEdge: .minY)
        }
    }

    private func createAlbumForPerson(_ person: Person) {
        // Show save panel to select location
        let panel = NSSavePanel()
        panel.nameFieldStringValue = person.name
        panel.canCreateDirectories = true
        panel.title = "Create Album"
        panel.message = "Choose a location to save the album folder"

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }

            // Create directory
            do {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)

                // Get images for person
                let images = faceManager.getImagesForPerson(person)

                // Create symlinks for each image
                for image in images {
                    let sourceURL = URL(fileURLWithPath: image.path)
                    let destURL = url.appendingPathComponent(sourceURL.lastPathComponent)

                    // Handle duplicate filenames
                    var finalDestURL = destURL
                    var counter = 1
                    while FileManager.default.fileExists(atPath: finalDestURL.path) {
                        let name = sourceURL.deletingPathExtension().lastPathComponent
                        let ext = sourceURL.pathExtension
                        finalDestURL = url.appendingPathComponent("\(name)_\(counter).\(ext)")
                        counter += 1
                    }

                    try FileManager.default.createSymbolicLink(at: finalDestURL, withDestinationURL: sourceURL)
                }

                // Open folder in Finder
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
            } catch {
                print("Error creating album: \(error)")
            }
        }
    }

    private func batchVerifySelectedFaces(person: Person, isCorrect: Bool) {
        guard !selectedFaceIds.isEmpty else { return }

        isBatchProcessing = true

        // Get the face IDs (faceId from API, not local UUID)
        let faceIdsToVerify = person.faces
            .filter { selectedFaceIds.contains($0.id) }
            .compactMap { $0.faceId }

        Task {
            await faceManager.verifyFaces(faceIds: faceIdsToVerify, clusterId: person.id, isCorrect: isCorrect)

            await MainActor.run {
                isBatchProcessing = false
                selectedFaceIds.removeAll()
                isSelectionMode = false
            }
        }
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

    // MARK: - Volumes Tab Content
    private var volumesTabContent: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.xxl) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Volumes")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(DesignSystem.Colors.primaryText)
                        Text("Manage external drives, RAID arrays, and network storage")
                            .font(DesignSystem.Typography.callout)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                    Spacer()

                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Button(action: {
                            VolumeManager.shared.refreshVolumes()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 11, weight: .medium))
                                Text("Refresh")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(DesignSystem.Colors.accent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(DesignSystem.Colors.accentSubtle)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())

                        Button(action: {
                            isShowingAddVolume = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.system(size: 11, weight: .semibold))
                                Text("Add Path")
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
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.top, DesignSystem.Spacing.md)

                // Volume Stats Summary
                volumeStatsSummary
                    .padding(.horizontal, DesignSystem.Spacing.lg)

                // Connected Mobile Devices
                if !mobileDeviceManager.devices.isEmpty {
                    devicesSection
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                }

                // Online Volumes
                let onlineVolumes = VolumeManager.shared.volumes.filter { $0.isOnline }
                if !onlineVolumes.isEmpty {
                    volumeSection(title: "Online Volumes", icon: "checkmark.circle.fill", iconColor: DesignSystem.Colors.success, volumes: onlineVolumes)
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                }

                // Offline Volumes
                let offlineVolumes = VolumeManager.shared.volumes.filter { !$0.isOnline }
                if !offlineVolumes.isEmpty {
                    volumeSection(title: "Offline Volumes", icon: "xmark.circle.fill", iconColor: DesignSystem.Colors.secondaryText, volumes: offlineVolumes)
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                }

                // Empty State
                if VolumeManager.shared.volumes.isEmpty {
                    volumesEmptyState
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                }

                Spacer()
            }
            .padding(.bottom, DesignSystem.Spacing.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $isShowingAddVolume) {
            AddVolumeSheet(isPresented: $isShowingAddVolume)
        }
        .onAppear {
            mobileDeviceManager.startScanning()
        }
        .onDisappear {
            mobileDeviceManager.stopScanning()
        }
    }

    @State private var isShowingAddVolume = false
    @ObservedObject private var mobileDeviceManager = MobileDeviceManager.shared

    private var devicesSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack(spacing: 6) {
                Image(systemName: "iphone")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.accent)
                Text("Connected Devices")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                Text("(\(mobileDeviceManager.devices.count))")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }

            if mobileDeviceManager.devices.isEmpty {
                // Empty state
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "iphone.slash")
                            .font(.system(size: 24))
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                        Text("No devices connected")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                        Text("Connect an iPhone, iPad, or camera via USB")
                            .font(DesignSystem.Typography.caption2)
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                    }
                    Spacer()
                }
                .padding(.vertical, DesignSystem.Spacing.lg)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: DesignSystem.Spacing.md)], spacing: DesignSystem.Spacing.md) {
                    ForEach(mobileDeviceManager.devices) { device in
                        DeviceCard(device: device)
                    }
                }
            }
        }
    }

    private var volumeStatsSummary: some View {
        let volumes = VolumeManager.shared.volumes
        let onlineCount = volumes.filter { $0.isOnline }.count
        let totalImages = volumes.reduce(0) { $0 + $1.imageCount }
        let enabledCount = volumes.filter { $0.isEnabled }.count

        return HStack(spacing: DesignSystem.Spacing.md) {
            VolumeStatCard(title: "Total Volumes", value: "\(volumes.count)", icon: "externaldrive", color: DesignSystem.Colors.accent)
            VolumeStatCard(title: "Online", value: "\(onlineCount)", icon: "checkmark.circle", color: DesignSystem.Colors.success)
            VolumeStatCard(title: "Indexed Images", value: formatNumber(totalImages), icon: "photo.stack", color: .purple)
            VolumeStatCard(title: "Enabled", value: "\(enabledCount)", icon: "power", color: DesignSystem.Colors.warning)
        }
    }

    private func volumeSection(title: String, icon: String, iconColor: Color, volumes: [ExternalVolume]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                Text("(\(volumes.count))")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: DesignSystem.Spacing.md)], spacing: DesignSystem.Spacing.md) {
                ForEach(volumes) { volume in
                    VolumeCard(volume: volume)
                }
            }
        }
    }

    private var volumesEmptyState: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "externaldrive.badge.questionmark")
                .font(.system(size: 48))
                .foregroundColor(DesignSystem.Colors.tertiaryText)
            Text("No External Volumes Detected")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(DesignSystem.Colors.primaryText)
            Text("Connect an external drive, RAID array, or add a network path manually")
                .font(DesignSystem.Typography.callout)
                .foregroundColor(DesignSystem.Colors.secondaryText)
                .multilineTextAlignment(.center)
            Button(action: { isShowingAddVolume = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Add Manual Path")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(DesignSystem.Colors.accent)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func formatNumber(_ num: Int) -> String {
        if num >= 1000000 {
            return String(format: "%.1fM", Double(num) / 1000000)
        } else if num >= 1000 {
            return String(format: "%.1fK", Double(num) / 1000)
        }
        return "\(num)"
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

                        Text("Configure your search index and CLIP model")
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
                Text("CLIP Model")
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

    private func checkForUpdates() {
        Task {
            guard let url = URL(string: "https://api.github.com/repos/AusafMo/searchy/releases/latest") else { return }
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String else { return }
            // Strip "v" prefix: "v4.0" -> "4.0"
            let remoteVersion = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
            let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
            if remoteVersion.compare(currentVersion, options: .numeric) == .orderedDescending {
                await MainActor.run {
                    self.updateAvailable = remoteVersion
                    withAnimation { self.showUpdateBanner = true }
                }
            }
        }
    }

    private func startSlowModelPolling() {
        // Poll every 10s to detect TTL unload or reload
        modelPollTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            Task {
                let delegate = await AppDelegate.shared
                guard let serverURL = await delegate.serverURL else { return }
                let url = serverURL.appendingPathComponent("status")
                guard let (data, _) = try? await URLSession.shared.data(from: url),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let model = json["model"] as? [String: Any],
                      let state = model["state"] as? String else { return }
                let message = model["message"] as? String ?? ""
                let elapsed = model["elapsed_seconds"] as? Double ?? 0
                await MainActor.run {
                    let oldState = self.modelState
                    self.modelState = state
                    self.modelMessage = message
                    self.modelElapsed = elapsed
                    // If model started loading again (after unload + new query), switch to fast polling
                    if state == "loading" && oldState != "loading" {
                        self.modelPollTimer?.invalidate()
                        self.modelPollTimer = nil
                        self.startModelStatusPolling()
                    }
                }
            }
        }
    }

    private func startModelStatusPolling() {
        modelPollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task {
                let delegate = await AppDelegate.shared
                guard let serverURL = await delegate.serverURL else { return }
                let url = serverURL.appendingPathComponent("status")
                guard let (data, _) = try? await URLSession.shared.data(from: url),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let model = json["model"] as? [String: Any],
                      let state = model["state"] as? String else { return }
                let message = model["message"] as? String ?? ""
                let elapsed = model["elapsed_seconds"] as? Double ?? 0
                await MainActor.run {
                    self.modelState = state
                    self.modelMessage = message
                    self.modelElapsed = elapsed
                    if state == "ready" || state == "error" {
                        // Slow down polling once model is stable
                        self.modelPollTimer?.invalidate()
                        self.modelPollTimer = nil
                        self.startSlowModelPolling()
                    }
                }
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

