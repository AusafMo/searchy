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
    @State private var scrollToUnknownSection = false
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
    @State private var showingNewCollectionSheet = false
    @State private var newCollectionName = ""
    @State private var previewPanelWidth: CGFloat = 340
    @State private var sidebarWidth: CGFloat = 196
    @State private var sidebarDragStart: CGFloat = 196
    @State private var modelState: String = "pending"
    @State private var modelMessage: String = ""
    @State private var modelElapsed: Double = 0
    @State private var modelPollTimer: Timer? = nil
    @State private var updateAvailable: String? = nil  // nil = no update, else new version string
    @State private var showUpdateBanner = false
    @State private var showKeyboardOverlay = false
    @State private var showCopyToast = false
    @State private var copyToastFilename = ""
    @State private var lightboxResult: SearchResult? = nil
    @State private var lightboxResults: [SearchResult] = []
    @State private var lightboxIndex: Int = 0
    @State private var recentSearchQueries: [String] = {
        UserDefaults.standard.stringArray(forKey: "recentSearchQueries") ?? []
    }()
    @Environment(\.colorScheme) var colorScheme

    private var p: AtelierPalette { themeManager.palette }

    /// True only when we should show the big editorial greeting (idle state)
    private var showGreeting: Bool {
        searchText.isEmpty && pastedImage == nil && searchManager.results.isEmpty && !searchManager.isSearching
    }

    /// True when there's content below the search bar (results or recent images)
    private var hasContentBelow: Bool {
        !searchManager.results.isEmpty || !recentImages.isEmpty || searchManager.isSearching
    }

    var body: some View {
        ZStack {
            p.paper.ignoresSafeArea()

            HStack(spacing: 0) {
                // Atelier Sidebar
                atelierSidebar

                // Main content
                VStack(spacing: 0) {
                    // Compact header bar
                    atelierHeader

                    // Update banner
                    if showUpdateBanner, let newVersion = updateAvailable {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 13))
                            Text("Searchy v\(newVersion) available")
                                .font(.system(size: 12, weight: .medium))
                            Text("—")
                                .foregroundColor(p.ink2)
                            Text("brew upgrade --cask searchy")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                            Button(action: {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString("brew upgrade --cask searchy", forType: .string)
                            }) {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 10))
                                    .foregroundColor(p.ink2)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .help("Copy command")
                            Spacer()
                            Button(action: { withAnimation { showUpdateBanner = false } }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(p.ink2)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .foregroundColor(p.accent)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(p.accent.opacity(0.08))
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

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
            }

            // MARK: - Full-Window Drop Overlay
            if isDropTargeted {
                dropOverlayView
                    .transition(.opacity)
                    .animation(.easeOut(duration: 0.2), value: isDropTargeted)
            }

            // MARK: - Keyboard Overlay
            if showKeyboardOverlay {
                keyboardOverlayView
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .animation(.spring(response: 0.25, dampingFraction: 0.85), value: showKeyboardOverlay)
            }

            // MARK: - Detail Lightbox
            if lightboxResult != nil {
                atelierLightbox
                    .transition(.opacity)
                    .animation(.easeOut(duration: 0.25), value: lightboxResult != nil)
            }

            // MARK: - Copy Toast
            VStack {
                Spacer()
                CopyNotification(isShowing: $showCopyToast, filename: copyToastFilename)
                    .padding(.bottom, 32)
            }
            .allowsHitTesting(false)
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

    // MARK: - Atelier Sidebar
    private var atelierSidebar: some View {
        let sidebarItems: [(id: AppTab, label: String, icon: String, count: Int?, badge: Bool)] = [
            (.faces,      "Faces",      "person.2",            faceManager.people.count > 0 ? faceManager.people.count : nil, false),
            (.search,     "Searchy",    "magnifyingglass",     nil, false),
            (.volumes,    "Volumes",    "externaldrive",       nil, false),
            (.duplicates, "Duplicates", "doc.on.doc",          duplicatesManager.groups.count > 0 ? duplicatesManager.groups.count : nil, duplicatesManager.groups.count > 0),
            (.favorites,  "Favorites",  "heart",               favoritesManager.favorites.count > 0 ? favoritesManager.favorites.count : nil, false),
            (.setup,      "Setup",      "slider.horizontal.3", nil, false),
        ]

        return VStack(alignment: .leading, spacing: 2) {
            // Logo
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 7)
                    .fill(p.accent)
                    .frame(width: 22, height: 22)
                    .overlay(
                        Text("S")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    )
                Text("Searchy")
                    .font(.system(size: 22, weight: .regular, design: .serif))
                    .foregroundColor(p.ink)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 18)

            // Section header
            Text("LIBRARY")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1)
                .foregroundColor(p.ink3)
                .padding(.horizontal, 8)
                .padding(.bottom, 6)

            // Nav items
            ForEach(sidebarItems, id: \.id) { item in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        activeTab = item.id
                    }
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: item.icon)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(activeTab == item.id ? p.accent : p.ink2)
                            .frame(width: 16)

                        Text(item.label)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(activeTab == item.id ? p.ink : p.ink2)

                        Spacer()

                        if let count = item.count {
                            Text("\(count)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(item.badge ? p.accent : p.ink3)
                                .fontWeight(item.badge ? .semibold : .regular)
                                .monospacedDigit()
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(activeTab == item.id ? p.card : Color.clear)
                            .shadow(color: activeTab == item.id ? Color.black.opacity(0.06) : .clear, radius: 8, y: 2)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }

            // Recent searches
            if !recentSearchQueries.isEmpty {
                Text("RECENT")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1)
                    .foregroundColor(p.ink3)
                    .padding(.horizontal, 8)
                    .padding(.top, 20)
                    .padding(.bottom, 6)

                ForEach(recentSearchQueries, id: \.self) { query in
                    Button(action: {
                        activeTab = .search
                        searchText = query
                        performSearch()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                                .foregroundColor(p.ink3)
                            Text(query)
                                .font(.system(size: 12, weight: .regular, design: .serif))
                                .italic()
                                .foregroundColor(p.ink2)
                                .lineLimit(1)
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .contextMenu {
                        Button(action: {
                            recentSearchQueries.removeAll { $0 == query }
                            UserDefaults.standard.set(recentSearchQueries, forKey: "recentSearchQueries")
                        }) {
                            Label("Remove", systemImage: "xmark")
                        }
                        Button(action: {
                            recentSearchQueries.removeAll()
                            UserDefaults.standard.set(recentSearchQueries, forKey: "recentSearchQueries")
                        }) {
                            Label("Clear All", systemImage: "trash")
                        }
                    }
                }
            }

            Spacer()

            // Model status footer
            HStack(spacing: 8) {
                Image(systemName: "cpu")
                    .font(.system(size: 11))
                    .foregroundColor(p.ink3)

                Circle()
                    .fill(modelState == "ready" ? DesignSystem.Colors.success : (modelState == "loading" ? p.accent : p.ink3))
                    .frame(width: 6, height: 6)
                    .shadow(color: modelState == "ready" ? DesignSystem.Colors.success.opacity(0.6) : .clear, radius: 3)

                Text(modelState == "ready" ? "CLIP \(modelSettings.currentModelName.components(separatedBy: "/").last ?? "ready")" : (modelState == "loading" ? "loading..." : "unloaded"))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(p.ink3)
                    .lineLimit(1)
            }
            .padding(.top, 10)
            .padding(.horizontal, 8)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(p.line)
                    .frame(height: 1)
            }
        }
        .padding(14)
        .padding(.top, 28)
        .frame(width: sidebarWidth)
        .background(p.sidebar)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(p.line)
                .frame(width: 1)
        }
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.clear)
                .frame(width: 5)
                .contentShape(Rectangle())
                .onHover { hovering in
                    if hovering {
                        NSCursor.resizeLeftRight.push()
                    } else {
                        NSCursor.pop()
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { value in
                            let newWidth = sidebarDragStart + value.translation.width
                            sidebarWidth = min(max(newWidth, 140), 320)
                        }
                        .onEnded { _ in
                            sidebarDragStart = sidebarWidth
                        }
                )
        }
    }

    // MARK: - Compact Header (replaces old modernHeader)
    private var atelierHeader: some View {
        HStack(spacing: 8) {
            Spacer()

            // Model loading indicator
            if modelState == "loading" {
                HStack(spacing: 7) {
                    ProgressView()
                        .scaleEffect(0.55)
                    Text("LOADING")
                        .font(.system(size: 9.5, weight: .semibold))
                        .tracking(0.8)
                    Text(String(format: "%.0fs", modelElapsed))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                }
                .foregroundColor(DesignSystem.Colors.warning)
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(DesignSystem.Colors.warning.opacity(0.08))
                        .overlay(Capsule().stroke(DesignSystem.Colors.warning.opacity(0.2), lineWidth: 1))
                )
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            } else if modelState == "ready" && modelElapsed > 0 {
                HStack(spacing: 7) {
                    Circle()
                        .fill(DesignSystem.Colors.success)
                        .frame(width: 6, height: 6)
                        .shadow(color: DesignSystem.Colors.success.opacity(0.6), radius: 3)
                    Text("READY")
                        .font(.system(size: 9.5, weight: .semibold))
                        .tracking(0.8)
                    Text(String(format: "%.1fs", modelElapsed))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                }
                .foregroundColor(DesignSystem.Colors.success)
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(DesignSystem.Colors.success.opacity(0.08))
                        .overlay(Capsule().stroke(DesignSystem.Colors.success.opacity(0.2), lineWidth: 1))
                )
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        withAnimation { self.modelElapsed = 0 }
                    }
                }
            }

            // Indexing indicator
            if isIndexing {
                HStack(spacing: 7) {
                    Circle()
                        .fill(p.accent)
                        .frame(width: 6, height: 6)
                        .shadow(color: p.accent.opacity(0.6), radius: 3)
                    Text("INDEXING")
                        .font(.system(size: 9.5, weight: .semibold))
                        .tracking(0.8)
                        .foregroundColor(p.accent)
                    Text("\(Int(indexingPercent))%")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(p.accent)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(p.accent.opacity(0.08))
                        .overlay(Capsule().stroke(p.accent.opacity(0.2), lineWidth: 1))
                )
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }

            Button(action: { if !isIndexing { selectAndIndexFolder() } }) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isIndexing ? p.ink3.opacity(0.4) : p.ink2)
                    .frame(width: 30, height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(p.paper)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(p.line, lineWidth: 1))
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isIndexing)
            .help("Add folder")

            Button(action: { if !isIndexing { rebuildIndex() } }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isIndexing ? p.ink3.opacity(0.4) : p.ink2)
                    .frame(width: 30, height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(p.paper)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(p.line, lineWidth: 1))
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isIndexing)
            .help("Rebuild index")

            Button(action: { isShowingSettings = true }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(p.ink2)
                    .frame(width: 30, height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(p.paper)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(p.line, lineWidth: 1))
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .help("Settings")

            ThemeSwitcherCompact()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
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

    /// People who are pinned (from filteredPeople)
    private var pinnedPeople: [Person] {
        filteredPeople.filter { faceManager.isPinned($0) }
    }

    /// People who have been given a custom name (not auto-generated "Person N") and are NOT pinned
    private var namedPeople: [Person] {
        filteredPeople.filter { person in
            !faceManager.isPinned(person) && !isUnknownPerson(person)
        }
    }

    /// People with auto-generated names ("Person N") or empty names
    private var unknownPeople: [Person] {
        filteredPeople.filter { person in
            !faceManager.isPinned(person) && isUnknownPerson(person)
        }
    }

    /// Check if a person has an auto-generated name (i.e. hasn't been manually named)
    private func isUnknownPerson(_ person: Person) -> Bool {
        let name = person.name.trimmingCharacters(in: .whitespaces)
        if name.isEmpty { return true }
        // Match auto-generated names like "Person 1", "Person 23", etc.
        let pattern = #"^Person \d+$"#
        return name.range(of: pattern, options: .regularExpression) != nil
    }

    private var facesTabContent: some View {
        VStack(spacing: 0) {
            if selectedPerson != nil {
                personDetailView
            } else {
                facesGridContent
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
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
                        Task { await faceManager.loadClustersFromAPI() }
                    }
                )
            }
        }
        .sheet(isPresented: $showBulkMergeSheet) {
            bulkMergeSheet
        }
        .sheet(isPresented: $showAddGroupSheet) {
            addGroupSheet
        }
    }

    private var facesGridContent: some View {
        VStack(spacing: 0) {
            // Header — primary row: title + stats + action buttons
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("People")
                        .font(.system(size: 38, weight: .regular, design: .serif))
                        .foregroundColor(p.ink)

                    if faceManager.totalFacesDetected > 0 {
                        if !peopleSearchText.isEmpty {
                            Text("\(filteredPeople.count) of \(faceManager.people.count) people")
                                .font(.system(size: 12))
                                .foregroundColor(p.ink2)
                        } else {
                            HStack(spacing: 6) {
                                Image(systemName: "person.crop.circle")
                                    .font(.system(size: 11))
                                    .foregroundColor(p.ink3)
                                Text("\(namedPeople.count) named")
                                    .font(.system(size: 12))
                                    .foregroundColor(p.ink2)
                                Text("\u{00B7}")
                                    .foregroundColor(p.ink3)
                                Image(systemName: "circle")
                                    .font(.system(size: 7))
                                    .foregroundColor(p.ink3)
                                Text("\(unknownPeople.count) unknown")
                                    .font(.system(size: 12))
                                    .foregroundColor(p.ink2)
                                Text("\u{00B7}")
                                    .foregroundColor(p.ink3)
                                Text("\(faceManager.totalFacesDetected) faces")
                                    .font(.system(size: 12))
                                    .foregroundColor(p.ink2)
                            }
                        }
                    }
                }

                Spacer()

                // Selected count indicator (when items selected)
                if !selectedPeopleIds.isEmpty {
                    HStack(spacing: 8) {
                        Text("\(selectedPeopleIds.count) selected")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(p.accent)

                        Button(action: {
                            withAnimation {
                                selectedPeopleIds.removeAll()
                            }
                        }) {
                            Text("Clear")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(p.ink2)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.trailing, 8)
                }

                // Merge ghost button — enters selection mode
                if !faceManager.people.isEmpty && selectedPeopleIds.isEmpty && !faceManager.isScanning {
                    Button(action: {
                        withAnimation { isSelectionMode = true }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.triangle.merge")
                                .font(.system(size: 12, weight: .medium))
                            Text("Merge")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(p.ink2)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.12), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.trailing, 4)
                }

                // Review unknown accent button — scrolls to unknown section
                if unknownPeople.count > 0 && selectedPeopleIds.isEmpty && !faceManager.isScanning {
                    Button(action: {
                        withAnimation {
                            peopleSearchText = ""
                            scrollToUnknownSection = true
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 12, weight: .medium))
                            Text("Review \(unknownPeople.count) unknown")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(p.accent)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                // Overflow menu button
                if selectedPeopleIds.isEmpty && !faceManager.isScanning {
                    Menu {
                        Button(action: {
                            faceManager.reclusterWithConstraints()
                        }) {
                            Label("Re-cluster faces", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .disabled(faceManager.isReclustering || !faceManager.hasVerifiedFaces)

                        Button(action: {
                            faceManager.clearAllFaces()
                        }) {
                            Label("Clear all faces", systemImage: "trash")
                        }
                        .disabled(!faceManager.hasScannedBefore)

                        Button(action: {
                            withAnimation {
                                faceManager.showHidden.toggle()
                            }
                        }) {
                            Label(faceManager.showHidden ? "Hide hidden" : "Show hidden", systemImage: faceManager.showHidden ? "eye.slash" : "eye")
                        }
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.12), lineWidth: 1)
                                .frame(width: 32, height: 32)
                            HStack(spacing: 3) {
                                ForEach(0..<3, id: \.self) { _ in
                                    Circle()
                                        .fill(p.ink2)
                                        .frame(width: 3, height: 3)
                                }
                            }
                        }
                    }
                    .menuStyle(BorderlessButtonMenuStyle())
                    .frame(width: 32, height: 32)
                }
            }
            .padding(.bottom, 4)
            .onAppear {
                faceManager.refreshNewImagesCount()
            }

            // Subtitle
            if !faceManager.people.isEmpty && selectedPerson == nil {
                Text("The faces Searchy keeps finding in your library. Name them, hide them, or merge.")
                    .font(.system(size: 16, weight: .regular, design: .serif))
                    .italic()
                    .foregroundColor(p.ink2)
                    .padding(.bottom, 6)
            }

            // Editorial signal line
            if !faceManager.isScanning && (faceManager.newImagesCount > 0 || faceManager.totalUnverifiedCount > 0) {
                HStack(spacing: 5) {
                    Image(systemName: "sparkle")
                        .font(.system(size: 11))
                        .foregroundColor(p.accent)
                    Group {
                        if faceManager.newImagesCount > 0 && faceManager.totalUnverifiedCount > 0 {
                            Text("\(faceManager.newImagesCount) new faces since last scan \u{00B7} \(faceManager.totalUnverifiedCount) still unverified")
                        } else if faceManager.newImagesCount > 0 {
                            Text("\(faceManager.newImagesCount) new faces since last scan")
                        } else {
                            Text("\(faceManager.totalUnverifiedCount) still unverified")
                        }
                    }
                    .font(.system(size: 14, design: .serif))
                    .italic()
                    .foregroundColor(p.accent)
                }
                .padding(.bottom, 10)
            }

            // Secondary row: scan, badges
            HStack(spacing: 8) {
                Button(action: {
                    if !faceManager.isScanning {
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
                            .fill(faceManager.isScanning ? p.line : p.accent)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(faceManager.isScanning)

                Spacer()
            }
            .padding(.bottom, 12)

            // Search bar - only show when there are people
            if !faceManager.people.isEmpty && selectedPerson == nil {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(p.ink3)

                    TextField("Search people...", text: $peopleSearchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 14))
                        .foregroundColor(p.ink)

                    if !peopleSearchText.isEmpty {
                        Button(action: {
                            withAnimation {
                                peopleSearchText = ""
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(p.ink3)
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
                .padding(.bottom, 8)
            }

            // Group filter bar - only show when there are groups
            if !faceManager.availableGroups.isEmpty && selectedPerson == nil {
                groupFilterBar
                    .padding(.bottom, 12)
            }

            // Scanning progress — inline card
            if faceManager.isScanning {
                HStack(spacing: 10) {
                    // Left: face icon in accent circle
                    ZStack {
                        Circle()
                            .fill(p.accent.opacity(colorScheme == .dark ? 0.15 : 0.1))
                            .frame(width: 30, height: 30)
                        Image(systemName: "faceid")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(p.accent)
                    }

                    // Middle: label + scan count + progress bar
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text("Scanning faces\u{2026}")
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundColor(p.ink)
                            Text(faceManager.scanProgress)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(p.ink2)
                                .lineLimit(1)
                        }

                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 1.5)
                                    .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.06))
                                    .frame(height: 3)

                                RoundedRectangle(cornerRadius: 1.5)
                                    .fill(p.accent)
                                    .frame(width: geometry.size.width * faceManager.scanPercentage, height: 3)
                                    .animation(.easeInOut(duration: 0.3), value: faceManager.scanPercentage)
                            }
                        }
                        .frame(height: 3)
                    }

                    Spacer()

                    // Right: estimated time + pause button
                    VStack(alignment: .trailing, spacing: 4) {
                        let remainingPercent = max(1.0 - faceManager.scanPercentage, 0)
                        let estimatedMinutes = Int(ceil(remainingPercent * 5))
                        Text("~\(estimatedMinutes) min left")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(p.ink3)

                        Button(action: {
                            // Pause scanning
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "pause.fill")
                                    .font(.system(size: 9, weight: .medium))
                                Text("Pause")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(p.ink2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.12), lineWidth: 1)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(p.paper)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08), lineWidth: 1)
                )
                .padding(.bottom, 12)
            }

            // Content
            if faceManager.people.isEmpty && !faceManager.isScanning {
                // Empty state - modern card design
                VStack(spacing: 24) {
                    Spacer()

                    // Icon with gradient background
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        p.accent.opacity(colorScheme == .dark ? 0.25 : 0.15),
                                        p.accent.opacity(colorScheme == .dark ? 0.1 : 0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)

                        Image(systemName: "person.2.crop.square.stack")
                            .font(.system(size: 48, weight: .light))
                            .foregroundColor(p.accent.opacity(colorScheme == .dark ? 0.8 : 0.7))
                    }

                    VStack(spacing: 8) {
                        Text("Face Recognition")
                            .font(.system(size: 22, weight: .regular, design: .serif))
                            .foregroundColor(p.ink)

                        Text(faceManager.hasScannedBefore
                             ? "No faces found in your photos.\nTry scanning more images."
                             : "Find and group people in your photos\nusing face detection.")
                            .font(.system(size: 14))
                            .foregroundColor(p.ink2)
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
                                            colors: [p.accent, p.accent.opacity(0.8)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .shadow(color: p.accent.opacity(0.3), radius: 8, y: 4)
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
                                .foregroundColor(p.ink3)
                            Text("No people matching \"\(peopleSearchText)\"")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(p.ink2)
                            Button(action: { peopleSearchText = "" }) {
                                Text("Clear Search")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(p.accent)
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
                                .foregroundColor(p.ink3)
                            Text("No people in this group")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(p.ink2)
                            Button(action: { faceManager.selectedGroupFilter = nil }) {
                                Text("Show All")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(p.accent)
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
                                .foregroundColor(p.ink3)
                            Text("All people are hidden")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(p.ink2)
                            Button(action: { faceManager.showHidden = true }) {
                                Text("Show Hidden")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(p.accent)
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
                                .foregroundColor(p.ink3)
                            Text("No people to display")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(p.ink2)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            // MARK: - Pinned Section
                            if !pinnedPeople.isEmpty {
                                HStack(spacing: 6) {
                                    Image(systemName: "star")
                                        .font(.system(size: 11))
                                        .foregroundColor(p.ink3)
                                    Text("PINNED")
                                        .font(.system(size: 10, weight: .semibold))
                                        .tracking(1.5)
                                        .foregroundColor(p.ink3)
                                        .textCase(.uppercase)
                                }
                                .padding(.bottom, 14)

                                LazyVGrid(columns: [
                                    GridItem(.adaptive(minimum: 140, maximum: 170), spacing: 18)
                                ], spacing: 18) {
                                    ForEach(pinnedPeople) { person in
                                        PersonCard(
                                            person: person,
                                            isPinned: true,
                                            isHidden: faceManager.isHidden(person),
                                            isSelected: selectedPeopleIds.contains(person.id),
                                            circleSize: 132,
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
                                .padding(.bottom, 36)
                            }

                            // MARK: - Named Section
                            if !namedPeople.isEmpty {
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11))
                                        .foregroundColor(p.ink3)
                                    Text("NAMED")
                                        .font(.system(size: 10, weight: .semibold))
                                        .tracking(1.5)
                                        .foregroundColor(p.ink3)
                                        .textCase(.uppercase)
                                }
                                .padding(.bottom, 14)

                                LazyVGrid(columns: [
                                    GridItem(.adaptive(minimum: 130, maximum: 150), spacing: 18)
                                ], spacing: 18) {
                                    ForEach(namedPeople) { person in
                                        PersonCard(
                                            person: person,
                                            isPinned: false,
                                            isHidden: faceManager.isHidden(person),
                                            isSelected: selectedPeopleIds.contains(person.id),
                                            showPhotosLabel: false,
                                            circleSize: 120,
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
                                .padding(.bottom, 36)
                            }

                            // MARK: - Unknown Section
                            if !unknownPeople.isEmpty {
                                HStack(spacing: 6) {
                                    Image(systemName: "circle")
                                        .font(.system(size: 11))
                                        .foregroundColor(p.ink3)
                                    Text("UNKNOWN \u{00B7} CLICK TO NAME")
                                        .font(.system(size: 10, weight: .semibold))
                                        .tracking(1.5)
                                        .foregroundColor(p.ink3)
                                        .textCase(.uppercase)
                                }
                                .id("unknownSection")
                                .padding(.bottom, 14)

                                LazyVGrid(columns: [
                                    GridItem(.adaptive(minimum: 110, maximum: 130), spacing: 14)
                                ], spacing: 14) {
                                    ForEach(unknownPeople) { person in
                                        PersonCard(
                                            person: person,
                                            isPinned: false,
                                            isHidden: faceManager.isHidden(person),
                                            isSelected: selectedPeopleIds.contains(person.id),
                                            isUnknown: true,
                                            circleSize: 96,
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
                                .padding(.bottom, 16)
                            }
                        }
                        .padding(.top, 8)
                        .padding(.bottom, !selectedPeopleIds.isEmpty ? 80 : 16)
                    }
                    .onChange(of: scrollToUnknownSection) { _, shouldScroll in
                        if shouldScroll {
                            withAnimation {
                                proxy.scrollTo("unknownSection", anchor: .top)
                            }
                            scrollToUnknownSection = false
                        }
                    }
                    } // ScrollViewReader

                    // Floating selection action bar
                    if !selectedPeopleIds.isEmpty {
                        selectionActionBar
                    }
                }
            }
        }
        .padding(.top, 16)
        .padding(.horizontal, 24)
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
                        .foregroundColor(faceManager.selectedGroupFilter == nil ? .white : p.ink2)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(faceManager.selectedGroupFilter == nil ? p.accent : (colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)))
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
                            .foregroundColor(faceManager.selectedGroupFilter == group ? .white : p.ink2)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(faceManager.selectedGroupFilter == group ? p.accent : (colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                // Add group button
                Button(action: { showAddGroupSheet = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(p.ink3)
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
    }

    private var bulkMergeSheet: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("BULK MERGE")
                        .font(.system(size: 9.5, weight: .semibold))
                        .tracking(1.6)
                        .foregroundColor(p.ink3)
                    Text("Merge \(selectedPeopleIds.count) People")
                        .font(.system(size: 22, weight: .regular, design: .serif))
                        .foregroundColor(p.ink)
                    Text("Select which person to keep as the primary")
                        .font(.system(size: 13, weight: .regular, design: .serif))
                        .italic()
                        .foregroundColor(p.ink2)
                }
                Spacer()
                Button(action: { showBulkMergeSheet = false }) {
                    ZStack {
                        Circle()
                            .fill(p.paper)
                            .overlay(Circle().stroke(p.line, lineWidth: 1))
                            .frame(width: 28, height: 28)
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(p.ink3)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)

            Rectangle().fill(p.line).frame(height: 0.5)

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
                                .foregroundColor(p.ink)
                            Text("Merge \(selectedPeopleIds.count - 1) others into this person")
                                .font(.system(size: 11))
                                .foregroundColor(p.ink2)
                        }

                        Spacer()

                        if isMerging {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("Merging...")
                                    .font(.system(size: 13))
                                    .foregroundColor(p.ink2)
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
                                        .fill(p.accent)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding()
                }
                .background(p.card)
            }
        }
        .frame(width: 380, height: 450)
        .background(p.card)
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
                        .stroke(isTarget ? p.accent : p.ink3, lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isTarget {
                        Circle()
                            .fill(p.accent)
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
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(p.line.opacity(0.5))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(p.ink3)
                        )
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(person.name)
                        .font(.system(size: 14, weight: .regular, design: .serif))
                        .italic()
                        .foregroundColor(p.ink)
                    Text("\(person.faceCount) photos")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(p.ink3)
                }

                Spacer()

                if isTarget {
                    Text("Keep")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(p.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(p.accent.opacity(0.15))
                        )
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isTarget
                          ? p.accent.opacity(0.1)
                          : p.line.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isTarget ? p.accent.opacity(0.5) : Color.clear, lineWidth: 1)
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
                        .foregroundColor(p.accent)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(p.accent.opacity(0.1))
                        )
                }
                .buttonStyle(PlainButtonStyle())

                if let person = selectedPerson {
                    // Person name (editable)
                    if isEditingPersonName {
                        TextField("Name", text: $editingPersonName)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: 20, weight: .regular, design: .serif))
                            .foregroundColor(p.ink)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(p.line.opacity(0.3))
                            )
                            .focused($personNameFieldFocused)
                            .onSubmit { commitPersonNameEdit() }
                            .onExitCommand { cancelPersonNameEdit() }
                            .frame(maxWidth: 200)
                    } else {
                        HStack(spacing: 6) {
                            Text(person.name)
                                .font(.system(size: 20, weight: .regular, design: .serif))
                                .italic()
                                .foregroundColor(p.ink)
                                .lineLimit(1)

                            Button(action: { startPersonNameEdit() }) {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(p.accent.opacity(0.7))
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
                            .foregroundColor(DesignSystem.Colors.warning)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(DesignSystem.Colors.warning.opacity(colorScheme == .dark ? 0.2 : 0.1))
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
                        .foregroundColor(p.ink2)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(p.line)
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
                        .foregroundColor(p.ink2)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(p.line)
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
                        .foregroundColor(p.ink2)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(p.line)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())

                    // Photo count badge
                    HStack(spacing: 4) {
                        Image(systemName: "photo.stack")
                            .font(.system(size: 12))
                        Text("\(person.faceCount) photos")
                            .font(.system(size: 12, design: .monospaced))
                    }
                    .foregroundColor(p.ink3)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(p.line)
                    )
                }
            }
            .padding(.bottom, 16)

            // Person's photos grid
            if let person = selectedPerson {
                if person.faces.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 48, weight: .light))
                            .foregroundColor(p.ink3)
                        Text("No photos available")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(p.ink2)
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
                                .foregroundColor(isSelectionMode ? .white : p.ink2)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule()
                                        .fill(isSelectionMode ? p.accent : p.line.opacity(0.5))
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
                                        .foregroundColor(p.accent)
                                }
                                .buttonStyle(PlainButtonStyle())

                                if !selectedFaceIds.isEmpty {
                                    Text("\(selectedFaceIds.count) selected")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(p.ink2)
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
                                    .background(Capsule().fill(DesignSystem.Colors.success))
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
                                    .background(Capsule().fill(DesignSystem.Colors.error))
                                }
                                .buttonStyle(PlainButtonStyle())
                                .disabled(isBatchProcessing)
                            }

                            // Hint (when not in selection mode)
                            if !isSelectionMode && person.unverifiedCount > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "lightbulb.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(DesignSystem.Colors.warning)
                                    Text("Hover to verify")
                                        .font(.system(size: 11))
                                        .foregroundColor(p.ink3)
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
            selectedFaceIds.removeAll()
            isSelectionMode = false
        }
    }

    private var addGroupSheet: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("NEW GROUP")
                    .font(.system(size: 9.5, weight: .semibold))
                    .tracking(1.6)
                    .foregroundColor(p.ink3)
                Text("Create a group")
                    .font(.system(size: 22, weight: .regular, design: .serif))
                    .foregroundColor(p.ink)
                Text("Organize people into named collections")
                    .font(.system(size: 13, weight: .regular, design: .serif))
                    .italic()
                    .foregroundColor(p.ink2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)

            Rectangle().fill(p.line).frame(height: 0.5)

            // Input area
            VStack(alignment: .leading, spacing: 12) {
                Text("Group name")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(p.ink2)

                TextField("e.g. Family, Work, Friends", text: $newGroupName)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 15, weight: .regular, design: .serif))
                    .foregroundColor(p.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(p.paper)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(p.line, lineWidth: 1)
                            )
                    )
            }
            .padding(24)

            Rectangle().fill(p.line).frame(height: 0.5)

            // Footer buttons
            HStack(spacing: 10) {
                Spacer()
                Button(action: { showAddGroupSheet = false; newGroupName = "" }) {
                    Text("Cancel")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(p.ink2)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(p.paper)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(p.line, lineWidth: 1))
                        )
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
                    Text("Create Group")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(newGroupName.isEmpty ? p.accent.opacity(0.4) : p.accent)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(newGroupName.isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 380)
        .background(p.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var mergePersonSheet: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("MERGE")
                        .font(.system(size: 9.5, weight: .semibold))
                        .tracking(1.6)
                        .foregroundColor(p.ink3)
                    Text("Merge People")
                        .font(.system(size: 22, weight: .regular, design: .serif))
                        .foregroundColor(p.ink)
                    if let target = selectedPerson {
                        Text("Select people to combine into \"\(target.name)\"")
                            .font(.system(size: 13, weight: .regular, design: .serif))
                            .italic()
                            .foregroundColor(p.ink2)
                    }
                }
                Spacer()
                Button(action: { showMergeSheet = false }) {
                    ZStack {
                        Circle()
                            .fill(p.paper)
                            .overlay(Circle().stroke(p.line, lineWidth: 1))
                            .frame(width: 28, height: 28)
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(p.ink3)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)

            Rectangle().fill(p.line).frame(height: 0.5)

            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(p.ink3)

                TextField("Search people...", text: $mergeSearchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 14))
                    .foregroundColor(p.ink)

                if !mergeSearchText.isEmpty {
                    Button(action: { mergeSearchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(p.ink3)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(p.line.opacity(0.3))
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
                            .foregroundColor(p.ink2)

                        Spacer()

                        if isMerging {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("Merging...")
                                    .font(.system(size: 13))
                                    .foregroundColor(p.ink2)
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
                                        .fill(p.accent)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding()
                }
                .background(p.card)
            }
        }
        .frame(width: 420, height: 520)
        .background(p.card)
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
                        .stroke(isSelected ? p.accent : p.ink3, lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(p.accent)
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
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(p.line.opacity(0.5))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(p.ink3)
                        )
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(person.name)
                        .font(.system(size: 14, weight: .regular, design: .serif))
                        .italic()
                        .foregroundColor(p.ink)
                    Text("\(person.faceCount) photos")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(p.ink3)
                }

                Spacer()
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected
                          ? p.accent.opacity(0.1)
                          : p.line.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? p.accent.opacity(0.5) : Color.clear, lineWidth: 1)
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
            if favoritesManager.isLoading {
                Spacer()
                ProgressView()
                    .scaleEffect(1.2)
                Spacer()
            } else if favoritesManager.favoriteImages.isEmpty {
                Spacer()
                VStack(spacing: 20) {
                    Image(systemName: "heart.slash")
                        .font(.system(size: 48, weight: .light))
                        .foregroundColor(p.ink3)

                    Text("No Favorites Yet")
                        .font(.system(size: 32, weight: .regular, design: .serif))
                        .foregroundColor(p.ink)

                    Text("Hover over any image and click the heart\nto add it to your favorites.")
                        .font(.system(size: 16, weight: .regular, design: .serif))
                        .italic()
                        .foregroundColor(p.ink2)
                        .multilineTextAlignment(.center)
                }
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Header
                        HStack(alignment: .firstTextBaseline) {
                            Text("Favorites")
                                .font(.system(size: 38, weight: .regular, design: .serif))
                                .tracking(-0.4)
                                .foregroundColor(p.ink)

                            Text("\(favoritesManager.favoriteImages.count) photos")
                                .font(.system(size: 17, weight: .regular, design: .serif))
                                .italic()
                                .foregroundColor(p.ink2)
                                .padding(.leading, 14)

                            Spacer()
                        }

                        Text("Star anything from search. Group into collections by drag — they stay searchable like everything else.")
                            .font(.system(size: 14, weight: .regular, design: .serif))
                            .italic()
                            .foregroundColor(p.ink3)
                            .padding(.top, 6)
                            .padding(.bottom, 28)

                        // Collections row
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                favoritesCollectionCard(
                                    name: "All Favorites", icon: "heart.fill", iconColor: p.accent,
                                    count: favoritesManager.favoriteImages.count,
                                    isSelected: favoritesManager.selectedCollectionId == nil
                                )
                                .onTapGesture { favoritesManager.selectedCollectionId = nil }

                                ForEach(favoritesManager.collections) { collection in
                                    favoritesCollectionCard(
                                        name: collection.name, icon: collection.icon, iconColor: p.accent,
                                        count: collection.paths.count,
                                        isSelected: favoritesManager.selectedCollectionId == collection.id
                                    )
                                    .onTapGesture { favoritesManager.selectedCollectionId = collection.id }
                                    .contextMenu {
                                        Button("Delete Collection") {
                                            favoritesManager.deleteCollection(id: collection.id)
                                        }
                                    }
                                }

                                // Dashed "new collection" button
                                Button(action: { showingNewCollectionSheet = true }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "plus")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(p.ink3)
                                        Text("new collection")
                                            .font(.system(size: 14, design: .serif))
                                            .italic()
                                            .foregroundColor(p.ink3)
                                        Spacer(minLength: 0)
                                    }
                                    .frame(width: 180)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                                            .foregroundColor(p.line)
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.bottom, 28)
                        .sheet(isPresented: $showingNewCollectionSheet) {
                            VStack(spacing: 16) {
                                Text("New Collection")
                                    .font(.system(size: 16, weight: .semibold, design: .serif))
                                TextField("Collection name", text: $newCollectionName)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 240)
                                    .onSubmit {
                                        createCollectionAndDismiss()
                                    }
                                HStack(spacing: 12) {
                                    Button("Cancel") {
                                        newCollectionName = ""
                                        showingNewCollectionSheet = false
                                    }
                                    Button("Create") {
                                        createCollectionAndDismiss()
                                    }
                                    .disabled(newCollectionName.trimmingCharacters(in: .whitespaces).isEmpty)
                                    .keyboardShortcut(.defaultAction)
                                }
                            }
                            .padding(24)
                        }

                        // Recently starred label
                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .font(.system(size: 11))
                                .foregroundColor(p.ink3)
                            Text("RECENTLY STARRED")
                                .font(.system(size: 11, weight: .semibold))
                                .tracking(1)
                                .foregroundColor(p.ink3)
                        }
                        .padding(.bottom, 14)

                        // 4-column grid with heart overlays
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 4), spacing: 14) {
                            ForEach(favoritesManager.displayedImages) { result in
                                FavoriteImageTile(result: result, onFindSimilar: { path in
                                    findSimilarWithPreview(path: path)
                                })
                            }
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 32)
                    .padding(.bottom, 24)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            favoritesManager.refreshFavoriteImages()
        }
    }

    private func createCollectionAndDismiss() {
        let name = newCollectionName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        favoritesManager.createCollection(name: name)
        newCollectionName = ""
        showingNewCollectionSheet = false
    }

    private func favoritesCollectionCard(name: String, icon: String, iconColor: Color, count: Int, isSelected: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.9))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.system(size: 14, design: .serif))
                    .italic()
                    .foregroundColor(p.ink)
                    .lineLimit(1)
                Text("\(count) photos")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(p.ink3)
            }
            Spacer(minLength: 0)
        }
        .frame(width: 180)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(p.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? p.accent : p.line, lineWidth: 1)
                )
                .shadow(color: isSelected ? p.halo : .clear, radius: 10, y: 6)
        )
    }

    // MARK: - Volumes Tab Content
    private var volumesTabContent: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Volumes")
                            .font(.system(size: 38, weight: .regular, design: .serif))
                            .foregroundColor(p.ink)

                        Text("external drives, indexed independently")
                            .font(.system(size: 17, weight: .regular, design: .serif))
                            .italic()
                            .foregroundColor(p.ink2)
                            .padding(.leading, 14)

                        Spacer()

                        Button(action: { isShowingAddVolume = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                    .font(.system(size: 11, weight: .semibold))
                                Text("Add volume")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(p.accent)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    Text("Each volume keeps its own index. Eject a drive and its photos quietly disappear from results.")
                        .font(.system(size: 14, weight: .regular, design: .serif))
                        .italic()
                        .foregroundColor(p.ink3)
                        .padding(.top, 6)
                }
                .padding(.horizontal, 32)
                .padding(.top, 32)

                // Connected Mobile Devices
                if !mobileDeviceManager.devices.isEmpty {
                    devicesSection
                        .padding(.horizontal, 32)
                }

                // All Volumes in 2-column grid
                let allVolumes = VolumeManager.shared.volumes
                if !allVolumes.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                            ForEach(allVolumes) { volume in
                                VolumeCard(volume: volume)
                            }
                        }
                    }
                    .padding(.horizontal, 32)
                }

                // Empty State
                if VolumeManager.shared.volumes.isEmpty {
                    volumesEmptyState
                        .padding(.horizontal, 32)
                }

                Spacer()
            }
            .padding(.bottom, 32)
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
        VStack(alignment: .leading, spacing: 14) {
            Text("CONNECTED DEVICES")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.5)
                .foregroundColor(p.ink3)

            if mobileDeviceManager.devices.isEmpty {
                // Empty state
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "iphone.slash")
                            .font(.system(size: 24))
                            .foregroundColor(p.ink3)
                        Text("No devices connected")
                            .font(.system(size: 12))
                            .foregroundColor(p.ink2)
                        Text("Connect an iPhone, iPad, or camera via USB")
                            .font(.system(size: 12))
                            .foregroundColor(p.ink3)
                    }
                    Spacer()
                }
                .padding(.vertical, 16)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 12)], spacing: 12) {
                    ForEach(mobileDeviceManager.devices) { device in
                        DeviceCard(device: device)
                    }
                }
            }
        }
    }

    private var volumesEmptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "externaldrive.badge.questionmark")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(p.ink3)

            Text("No External Volumes Detected")
                .font(.system(size: 24, weight: .regular, design: .serif))
                .foregroundColor(p.ink)

            Text("Connect an external drive, RAID array, or add a network path manually")
                .font(.system(size: 14, weight: .regular, design: .serif))
                .italic()
                .foregroundColor(p.ink2)
                .multilineTextAlignment(.center)

            Button(action: { isShowingAddVolume = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Add volume")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 10).fill(p.accent))
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
            VStack(alignment: .leading, spacing: 0) {
                // Library heading
                Text("Library")
                    .font(.system(size: 38, weight: .regular, design: .serif))
                    .foregroundColor(p.ink)
                    .padding(.horizontal, 32)
                    .padding(.top, 32)

                Text(isIndexing
                    ? "Searchy is indexing your photos. You can keep using the app."
                    : "At a glance — your indexed photo library.")
                    .font(.system(size: 16, weight: .regular, design: .serif))
                    .italic()
                    .foregroundColor(p.ink2)
                    .padding(.horizontal, 32)
                    .padding(.top, 6)
                    .padding(.bottom, 28)

                // Hero progress card when indexing
                if isIndexing {
                    atelierHeroProgress
                        .padding(.horizontal, 32)
                        .padding(.bottom, 28)
                }

                // Index stats + quick actions
                setupStatsSection
                    .padding(.horizontal, 32)
                    .padding(.bottom, 28)

                // Compact summary cards (directories + model)
                setupSummaryCards
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
            }
        }
        .onAppear {
            modelSettings.fetchCurrentModel()
            loadIndexStats()
        }
    }

    // MARK: - Atelier Hero Progress Card
    private var atelierHeroProgress: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("\(Int(indexingPercent))")
                        .font(.system(size: 56, weight: .regular, design: .serif))
                        .foregroundColor(p.accent)
                    Text("%")
                        .font(.system(size: 28, weight: .regular, design: .serif))
                        .foregroundColor(p.accent)
                }

                VStack(alignment: .leading, spacing: 4) {
                    if !indexingProgress.isEmpty {
                        Text(indexingProgress)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(p.ink)
                    }
                    HStack(spacing: 0) {
                        if !indexingBatchInfo.isEmpty {
                            Text(indexingBatchInfo)
                        }
                        if indexingSpeed > 0 {
                            Text(" \u{00B7} \(String(format: "%.1f", indexingSpeed)) img/s")
                        }
                    }
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(p.ink2)
                }

                Spacer()

                Button(action: { cancelIndexing() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "pause")
                            .font(.system(size: 12))
                        Text("Cancel")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(p.ink2)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(p.line, lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.bottom, 18)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(p.line)
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(p.accent)
                        .frame(width: geo.size.width * (indexingPercent / 100), height: 6)
                        .animation(.easeInOut(duration: 0.3), value: indexingPercent)
                }
            }
            .frame(height: 6)
            .padding(.bottom, 18)

            Divider().background(p.line).padding(.bottom, 18)

            HStack(spacing: 24) {
                atelierStatLabel("Estimated", value: indexingETA.isEmpty ? "\u{2014}" : indexingETA)
                atelierStatLabel("Embeddings", value: "\(modelSettings.currentEmbeddingDim)-dim")
                atelierStatLabel("Model", value: modelSettings.currentModelDisplayName)
                atelierStatLabel("Device", value: modelSettings.currentDevice)
            }
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(p.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(p.line, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.07), radius: 15, x: 0, y: 8)
    }

    private func atelierStatLabel(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(1)
                .foregroundColor(p.ink3)
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(p.ink)
        }
    }

    // MARK: - Setup Summary Cards (compact dashboard)
    private var setupSummaryCards: some View {
        HStack(spacing: 14) {
            // Directories summary card
            setupSummaryCard(
                eyebrow: "DIRECTORIES",
                icon: "folder",
                title: dirManager.watchedDirectories.isEmpty
                    ? "No folders"
                    : "\(dirManager.watchedDirectories.count) watched",
                detail: dirManager.watchedDirectories.isEmpty
                    ? "Add a folder to start indexing"
                    : dirManager.watchedDirectories.prefix(2).map { ($0.path as NSString).lastPathComponent }.joined(separator: ", ")
                      + (dirManager.watchedDirectories.count > 2 ? " +\(dirManager.watchedDirectories.count - 2)" : ""),
                actionLabel: "Manage in Settings",
                action: { isShowingSettings = true }
            )

            // Model summary card
            setupSummaryCard(
                eyebrow: "MODEL",
                icon: "cpu",
                title: modelSettings.currentModelDisplayName.isEmpty ? "No model" : modelSettings.currentModelDisplayName,
                detail: modelSettings.currentModelName.isEmpty
                    ? "Configure a CLIP model"
                    : "\(modelSettings.currentEmbeddingDim)-dim \u{00B7} \(modelSettings.currentDevice)",
                actionLabel: "Manage in Settings",
                action: { isShowingSettings = true }
            )
        }
    }

    private func setupSummaryCard(eyebrow: String, icon: String, title: String, detail: String, actionLabel: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(p.accent)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(p.accent.opacity(0.1))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(eyebrow)
                        .font(.system(size: 9.5, weight: .semibold))
                        .tracking(1.2)
                        .foregroundColor(p.ink3)
                    Text(title)
                        .font(.system(size: 17, weight: .regular, design: .serif))
                        .foregroundColor(p.ink)
                }

                Spacer()
            }
            .padding(.bottom, 12)

            Text(detail)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(p.ink2)
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.bottom, 14)

            Divider().background(p.line).padding(.bottom, 12)

            Button(action: action) {
                HStack(spacing: 5) {
                    Text(actionLabel)
                        .font(.system(size: 12, weight: .medium))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundColor(p.accent)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(p.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(p.line, lineWidth: 1)
        )
    }

    // MARK: - Atelier Stats + Actions Section
    private var setupStatsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("INDEX")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.5)
                    .foregroundColor(p.ink3)
                Spacer()
                Button(action: { loadIndexStats() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                        .foregroundColor(p.ink3)
                }
                .buttonStyle(PlainButtonStyle())
            }

            VStack(spacing: 0) {
                if let stats = indexStats {
                    // Stats rows
                    atelierIndexRow(icon: "photo.stack", label: "Total Images", value: stats.totalImages.formatted())
                    Divider().background(p.line)
                    atelierIndexRow(icon: "externaldrive", label: "Index Size", value: stats.fileSize)
                    if let lastMod = stats.lastModified {
                        Divider().background(p.line)
                        atelierIndexRow(icon: "clock", label: "Last Updated", value: formatRelativeDate(lastMod))
                    }
                    Divider().background(p.line)
                    atelierIndexRow(icon: "folder", label: "Directories", value: "\(dirManager.watchedDirectories.count)")
                } else {
                    HStack {
                        Spacer()
                        ProgressView().scaleEffect(0.8)
                        Text("Loading\u{2026}")
                            .font(.system(size: 13))
                            .foregroundColor(p.ink2)
                        Spacer()
                    }
                    .padding(.vertical, 20)
                }

                Divider().background(p.line)

                // Quick actions
                HStack(spacing: 12) {
                    Button(action: { if !isIndexing { selectAndIndexFolder() } }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Add to Index")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(p.accent))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isIndexing)

                    Button(action: { if !isIndexing { rebuildIndex() } }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 11))
                            Text("Rebuild")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(p.ink2)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .overlay(
                            Capsule().stroke(p.line, lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isIndexing)

                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(p.card)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(p.line, lineWidth: 1)
            )
        }
    }

    private func atelierIndexRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(p.accent)
                .frame(width: 20)
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(p.ink2)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(p.ink)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private func formatRelativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }


    // MARK: - Search Tab Content
    private var searchTabContent: some View {
        HStack(spacing: 0) {
            // Main content column
            VStack(spacing: 0) {
                // Show indexing progress or search greeting + bar
                if isIndexing {
                    indexingProgressView
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                } else if let report = indexingReport {
                    indexingReportView(report)
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                }

                // Greeting above search bar when idle
                if !isIndexing && indexingReport == nil {
                    if showGreeting {
                        Spacer(minLength: 0)
                        atelierGreeting
                    }
                }

                // Search bar (always visible when not indexing) — fixed position, never jumps
                if !isIndexing && indexingReport == nil {
                    modernSearchBar
                        .padding(.horizontal, 32)
                        .padding(.top, showGreeting ? 0 : 16)
                }

                // Filter bar — always present once we have any content, never hides
                if !isIndexing {
                    filterBar
                        .padding(.top, 12)
                        .opacity(hasContentBelow ? (searchManager.isSearching ? 0.5 : 1.0) : 0)
                        .frame(height: hasContentBelow ? nil : 0)
                        .clipped()
                }

                errorView

                // Visual reference card (only for image-based searches)
                if pastedImage != nil && !searchManager.results.isEmpty && !searchManager.isSearching {
                    searchReferenceCard
                        .padding(.horizontal, 32)
                        .padding(.top, 10)
                }

                // Results area — use id to keep transitions smooth
                Group {
                    if showGreeting {
                        VStack(spacing: 0) {
                            recentImagesSection
                        }
                        .transition(.opacity)
                    } else if searchManager.isSearching || searchDebounceTimer != nil {
                        if !searchManager.results.isEmpty {
                            ScrollView {
                                filteredResultsList
                                    .padding(.horizontal, 24)
                            }
                            .opacity(0.4)
                            .transition(.opacity)
                        } else {
                            VStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                            .transition(.opacity)
                        }
                    } else if !searchManager.results.isEmpty && searchManager.errorMessage == nil {
                        ScrollView {
                            filteredResultsList
                                .padding(.horizontal, 24)
                        }
                        .transition(.opacity)
                    } else if searchText.isEmpty && pastedImage == nil {
                        VStack(spacing: 0) {
                            recentImagesSection
                        }
                        .transition(.opacity)
                    } else if searchManager.errorMessage == nil {
                        emptyStateView
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.12), value: showGreeting)
                .animation(.easeInOut(duration: 0.12), value: searchManager.results.isEmpty)
                .animation(.easeInOut(duration: 0.12), value: searchManager.isSearching)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 12)
            }
            .padding(.horizontal, 12)

            // Inspector panel — full height, edge to edge
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

    // MARK: - Atelier Greeting
    private var atelierGreeting: some View {
        VStack(spacing: 4) {
            HStack(spacing: 0) {
                Text("What are you ")
                    .font(.system(size: 28, weight: .regular, design: .serif))
                    .foregroundColor(p.ink)
                Text("looking")
                    .font(.system(size: 28, weight: .regular, design: .serif))
                    .italic()
                    .foregroundColor(p.accent)
                Text(" for?")
                    .font(.system(size: 28, weight: .regular, design: .serif))
                    .foregroundColor(p.ink)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)

            Text("describe a moment, paste a screenshot, drop an image")
                .font(.system(size: 12, weight: .regular, design: .serif))
                .italic()
                .foregroundColor(p.ink3)
        }
        .padding(.top, 20)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Drag Search Reference Card
    private var searchReferenceCard: some View {
        HStack(spacing: 12) {
            // Left: icon or image thumbnail
            if let image = pastedImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(p.accent, lineWidth: 1.5))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(p.accent.opacity(0.1))
                        .frame(width: 36, height: 36)
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(p.accent)
                }
            }

            // Middle: description
            VStack(alignment: .leading, spacing: 2) {
                if pastedImage != nil {
                    Text("Visual reference")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(p.ink)
                } else {
                    Text("\u{201C}\(searchText)\u{201D}")
                        .font(.system(size: 12, weight: .medium, design: .serif))
                        .italic()
                        .foregroundColor(p.ink)
                        .lineLimit(1)
                }

                HStack(spacing: 6) {
                    Text("\(searchManager.results.count) results")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(p.ink2)
                    Text("\u{00B7}")
                        .foregroundColor(p.ink3)
                    Text(pastedImage != nil ? "cosine similarity" : "semantic search")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(p.ink3)
                }
            }

            Spacer()

            // Right: clear button (for image search)
            if pastedImage != nil {
                Button(action: {
                    withAnimation { pastedImage = nil }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(p.ink3)
                        .frame(width: 22, height: 22)
                        .background(
                            Circle()
                                .fill(p.paper)
                                .overlay(Circle().stroke(p.line, lineWidth: 1))
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(p.card)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(p.line, lineWidth: 1))
        )
    }

    // MARK: - Find Similar (with pasted image preview)
    private func findSimilarWithPreview(path: String) {
        // Load the image for the reference card thumbnail
        DispatchQueue.global(qos: .userInitiated).async {
            if let img = NSImage(contentsOfFile: path) {
                DispatchQueue.main.async {
                    self.pastedImage = img
                    self.activeTab = .search
                }
            }
        }
        searchManager.findSimilar(imagePath: path)
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

        return VStack(alignment: .leading, spacing: 16) {
            MasonryGrid(items: results, columns: showPreviewPanel ? 2 : 3, spacing: 16) { result in
                MasonryImageCard(
                    result: result,
                    showSimilarity: true,
                    onFindSimilar: { path in
                        findSimilarWithPreview(path: path)
                    },
                    onOpen: {
                        openLightbox(result: result, allResults: results)
                    },
                    onHoverStart: handlePreviewHoverStart,
                    onHoverEnd: handlePreviewHoverEnd
                )
            }
        }
    }

    // MARK: - Filter Bar (Minimal Capsules)
    @State private var clipBalance: Double = 0.5  // 0 = pure text, 1 = pure vision
    @State private var filterCategory: String = "All"

    private var filterBar: some View {
        HStack(spacing: 0) {
            // Category filters (All / Photos / Screenshots / Documents)
            HStack(spacing: 6) {
                ForEach(["All", "Photos", "Screenshots", "Documents"], id: \.self) { category in
                    FilterCapsule(
                        label: category,
                        isActive: filterCategory == category,
                        action: {
                            filterCategory = category
                            // Update type filters based on category
                            switch category {
                            case "Photos":
                                filterTypes = Set(["jpg", "jpeg", "heic", "png", "raw", "cr2", "nef", "arw"])
                            case "Screenshots":
                                filterTypes = Set(["png"])
                            case "Documents":
                                filterTypes = Set(["pdf", "doc", "docx"])
                            default:
                                filterTypes.removeAll()
                            }
                        }
                    )
                }
            }

            Spacer()

            // Result count + timing inline
            if let stats = searchManager.searchStats {
                HStack(spacing: 8) {
                    Text("\(filteredResults.count) results")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(p.ink2)
                    Text(stats.total_time)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(p.ink3)
                }
            }
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 24)
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
    @State private var dupSimilarityFilter: Float = 0.92
    @State private var dupLastScanDate: Date? = nil

    // MARK: - Duplicates Helpers
    private var dupTotalPhotos: Int {
        duplicatesManager.groups.reduce(0) { $0 + $1.images.count }
    }
    private var dupRecoverableBytes: Int64 {
        // Recoverable = everything except the keeper (first) in each group
        Int64(duplicatesManager.groups.reduce(0) { acc, group in
            acc + group.images.dropFirst().reduce(0) { $0 + $1.size }
        })
    }
    private var dupFilteredGroups: [DuplicateGroup] {
        duplicatesManager.groups.filter { group in
            let avgSim = group.images.isEmpty ? Float(0) : group.images.map { $0.similarity }.reduce(0, +) / Float(group.images.count)
            return avgSim >= dupSimilarityFilter
        }
    }
    private func dupWhyLabel(for group: DuplicateGroup) -> String {
        let avgSim = group.images.isEmpty ? Float(0) : group.images.map { $0.similarity }.reduce(0, +) / Float(group.images.count)
        if avgSim > 0.97 { return "Nearly identical" }
        if avgSim > 0.95 { return "Same scene" }
        if avgSim > 0.93 { return "Very similar" }
        return "Similar"
    }
    private func dupFormattedBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    private func dupImageDimensions(for path: String) -> String {
        guard let nsImage = NSImage(contentsOfFile: path) else { return "" }
        let w = Int(nsImage.size.width)
        let h = Int(nsImage.size.height)
        return "\(w)×\(h)"
    }

    private var duplicatesTabContent: some View {
        ZStack {
            VStack(spacing: 0) {
                // Content
                if duplicatesManager.isScanning {
                    VStack(spacing: 12) {
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Scanning for duplicates...")
                            .font(.system(size: 13))
                            .foregroundColor(p.ink2)
                        Text("This may take a moment for large libraries")
                            .font(.system(size: 12))
                            .foregroundColor(p.ink3)
                        Spacer()
                    }
                } else if let error = duplicatesManager.errorMessage {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(DesignSystem.Colors.warning)
                        Text("Error scanning")
                            .font(.system(size: 15, weight: .medium))
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundColor(p.ink2)
                            .multilineTextAlignment(.center)
                        Spacer()
                    }
                    .padding()
                } else if duplicatesManager.groups.isEmpty {
                    // Header even when empty
                    duplicatesHeader
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                    duplicatesEmptyState
                } else {
                    duplicatesHeader
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                    duplicatesBulkActionBar
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                    duplicatesFilterRail
                        .padding(.horizontal, 24)
                        .padding(.top, 10)
                    duplicatesResultsList

                    // Bottom action bar when items selected
                    if duplicatesManager.totalSelected > 0 {
                        duplicatesActionBar
                    }
                }

                // Feedback toast
                if let feedback = actionFeedback {
                    Text(feedback)
                        .font(.system(size: 13))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(DesignSystem.Colors.success))
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 12)
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

            VStack(spacing: 16) {
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
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
                }

                // File info
                VStack(spacing: 4) {
                    Text(URL(fileURLWithPath: path).lastPathComponent)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)

                    Text(formattedFileSize(for: path))
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))
                }

                // Action buttons
                HStack(spacing: 16) {
                    Button(action: {
                        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "folder")
                            Text("Reveal in Finder")
                        }
                        .font(.system(size: 13))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Color.white.opacity(0.2)))
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: {
                        NSWorkspace.shared.open(URL(fileURLWithPath: path))
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.right.square")
                            Text("Open")
                        }
                        .font(.system(size: 13))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(p.accent))
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

    // MARK: - Duplicates Header
    private var duplicatesHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Duplicates")
                    .font(.system(size: 24, weight: .regular, design: .serif))
                    .foregroundColor(p.ink)

                if !duplicatesManager.groups.isEmpty {
                    Text("\(duplicatesManager.groups.count) clusters \u{00b7} \(dupTotalPhotos) photos \u{00b7}")
                        .font(.system(size: 12))
                        .foregroundColor(p.ink2)
                    Text("\(dupFormattedBytes(dupRecoverableBytes)) recoverable")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(p.accent)
                }

                Spacer()

                Button(action: {
                    duplicatesManager.scanForDuplicates()
                    dupLastScanDate = Date()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 10))
                        Text("Scan")
                    }
                    .font(.system(size: 12).weight(.medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(p.accent))
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(duplicatesManager.isScanning)
            }

            Text("Grouped by similarity. Searchy picks a keeper \u{2014} you confirm.")
                .font(.system(size: 12, design: .serif).italic())
                .foregroundColor(p.ink3)
        }
        .padding(.bottom, 4)
    }

    // MARK: - Bulk Action Bar
    private var duplicatesBulkActionBar: some View {
        let nonKeeperCount = duplicatesManager.groups.reduce(0) { $0 + max($1.images.count - 1, 0) }

        return HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 12))
                .foregroundColor(p.accent)

            Text("Auto-pick all \(duplicatesManager.groups.count) clusters \u{00b7} frees ~\(dupFormattedBytes(dupRecoverableBytes))")
                .font(.system(size: 12))
                .foregroundColor(p.ink2)

            Spacer()

            Button(action: {}) {
                Text("Review")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(p.ink2)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().stroke(p.line, lineWidth: 1))
            }
            .buttonStyle(PlainButtonStyle())

            Button(action: { duplicatesManager.autoSelectAllSmaller() }) {
                HStack(spacing: 3) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                    Text("Apply all")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(p.ink))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(p.sidebar.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(p.line, lineWidth: 0.5)
        )
    }

    // MARK: - Filter Rail
    private var duplicatesFilterRail: some View {
        HStack(spacing: 12) {
            Text("FILTER")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.2)
                .foregroundColor(p.ink3)

            // Similarity slider pill
            HStack(spacing: 6) {
                Text("similarity \u{2265} \(String(format: "%.2f", dupSimilarityFilter))")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(p.ink2)
                Slider(value: $dupSimilarityFilter, in: 0.85...0.99, step: 0.01)
                    .frame(width: 80)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(p.sidebar))

            dupFilterPill(icon: "folder", label: "All sources")
            dupFilterPill(icon: "calendar", label: "All time")
            dupFilterPill(icon: "doc", label: "All formats")

            Spacer()

            Text("\(dupFilteredGroups.count) of \(duplicatesManager.groups.count) shown")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(p.ink3)
        }
        .padding(.bottom, 10)
        .overlay(alignment: .bottom) {
            Rectangle().fill(p.line).frame(height: 1)
        }
    }

    private func dupFilterPill(icon: String, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(label)
                .font(.system(size: 11, weight: .medium))
            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .semibold))
        }
        .foregroundColor(p.ink2)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(p.sidebar))
    }

    // MARK: - Duplicates Empty State
    private var duplicatesEmptyState: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "square.on.square.dashed")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(p.ink3)

            Text("No duplicates found")
                .font(.system(size: 20, weight: .regular, design: .serif))
                .foregroundColor(p.ink)

            Text("Click Scan to search your indexed images")
                .font(.system(size: 12, design: .serif).italic())
                .foregroundColor(p.ink3)

            Spacer()
        }
        .padding()
    }

    // MARK: - Duplicates Results List
    private var duplicatesResultsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(dupFilteredGroups) { group in
                    duplicateGroupCard(group)
                }

                dupEndOfListCard
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - End-of-List Card
    private var dupEndOfListCard: some View {
        VStack(spacing: 6) {
            Text("That\u{2019}s all. Your library is unusually tidy.")
                .font(.system(size: 14, design: .serif).italic())
                .foregroundColor(p.ink2)
                .multilineTextAlignment(.center)

            HStack(spacing: 4) {
                if let lastScan = dupLastScanDate {
                    let interval = Date().timeIntervalSince(lastScan)
                    let ago: String = {
                        if interval < 60 { return "just now" }
                        if interval < 3600 { return "\(Int(interval / 60))m ago" }
                        return "\(Int(interval / 3600))h ago"
                    }()
                    Text("Last scan: \(ago) \u{00b7}")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(p.ink3)
                }

                Button(action: {
                    duplicatesManager.scanForDuplicates()
                    dupLastScanDate = Date()
                }) {
                    Text("Re-scan now")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(p.accent)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .stroke(style: StrokeStyle(lineWidth: 0.5, dash: [6, 4]))
                .foregroundColor(p.line)
        )
    }

    // MARK: - Cluster Card (Redesigned)
    private func duplicateGroupCard(_ group: DuplicateGroup) -> some View {
        let avgSimilarity = group.images.isEmpty ? Float(0) : group.images.map { $0.similarity }.reduce(0, +) / Float(group.images.count)
        let avgSimPercent = Int(avgSimilarity * 100)
        let totalBytes = group.images.reduce(0) { $0 + $1.size }
        let reclaimBytes = Int64(group.images.dropFirst().reduce(0) { $0 + $1.size })
        let whyLabel = dupWhyLabel(for: group)
        let keeperReason: String = {
            guard let first = group.images.first else { return "first in group" }
            let maxSize = group.images.map { $0.size }.max() ?? 0
            return first.size == maxSize ? "largest file" : "first in group"
        }()

        // Date from first image (best-effort)
        let firstImageDate: String = {
            guard let firstImage = group.images.first,
                  let attrs = try? FileManager.default.attributesOfItem(atPath: firstImage.path),
                  let date = attrs[.modificationDate] as? Date else { return "" }
            let fmt = DateFormatter()
            fmt.dateFormat = "MMM d"
            return fmt.string(from: date)
        }()

        return VStack(alignment: .leading, spacing: 0) {
            // Card Header
            HStack(spacing: 8) {
                Text(whyLabel)
                    .font(.system(size: 14, weight: .regular, design: .serif).italic())
                    .foregroundColor(p.ink)

                Text("\(avgSimPercent)%")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(p.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(p.accent.opacity(0.10)))

                if !firstImageDate.isEmpty {
                    Text(firstImageDate)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(p.ink3)
                }

                Spacer()

                Text("\(group.images.count) \u{00b7} \(dupFormattedBytes(Int64(totalBytes)))")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(p.ink3)

                Button(action: { duplicatesManager.autoSelectSmaller(groupId: group.id) }) {
                    HStack(spacing: 3) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 9))
                        Text("Auto-pick")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(p.accent)
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: {
                    withAnimation {
                        if let idx = duplicatesManager.groups.firstIndex(where: { $0.id == group.id }) {
                            duplicatesManager.groups.remove(at: idx)
                        }
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(p.ink3)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .overlay(alignment: .bottom) {
                Rectangle().fill(p.line).frame(height: 0.5)
            }

            // Photo Grid — adaptive sizing, max ~200px per card
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 220), spacing: 8)], spacing: 8) {
                ForEach(Array(group.images.enumerated()), id: \.element.path) { index, image in
                    dupImageCard(image, isKeeper: index == 0, groupId: group.id)
                }
            }
            .padding(10)
        }
        .background(p.card)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(p.line, lineWidth: 0.5)
        )
    }

    // MARK: - Photo Card (Nude direction)
    private func dupImageCard(_ image: DuplicateImage, isKeeper: Bool, groupId: Int) -> some View {
        let fileExt = URL(fileURLWithPath: image.path).pathExtension.uppercased()

        return ZStack {
            // Image fills the fixed aspect ratio frame
            GeometryReader { geo in
                AsyncThumbnailView(path: image.path, contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
            }

            // Top-left badge: KEEP or TRASH
            VStack {
                HStack {
                    if isKeeper {
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 7, weight: .bold))
                            Text("KEEP")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(p.accent))
                    } else {
                        HStack(spacing: 3) {
                            Image(systemName: "trash")
                                .font(.system(size: 7))
                            Text("TRASH")
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundColor(p.ink2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.white.opacity(0.92)))
                    }
                    Spacer()
                }
                Spacer()
            }
            .padding(5)

            // Bottom gradient with meta + actions
            VStack {
                Spacer()
                ZStack(alignment: .bottom) {
                    LinearGradient(
                        colors: [.clear, Color.black.opacity(0.5)],
                        startPoint: UnitPoint(x: 0.5, y: 0.0),
                        endPoint: UnitPoint(x: 0.5, y: 1.0)
                    )
                    .frame(height: 44)

                    HStack(spacing: 4) {
                        Text("\(image.formattedSize) \u{00b7} \(fileExt)")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(1)

                        Spacer(minLength: 2)

                        Button(action: {
                            duplicatesManager.toggleSelection(groupId: groupId, imagePath: image.path)
                        }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(image.isSelected ? p.accent : Color.white.opacity(0.2))
                                    .frame(width: 16, height: 16)
                                if image.isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())

                        Button(action: {
                            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: image.path)])
                        }) {
                            Image(systemName: "folder")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.85))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 6)
                }
            }
        }
        .aspectRatio(1.3, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isKeeper ? p.accent : Color.clear, lineWidth: isKeeper ? 1.5 : 0)
        )
        .contentShape(RoundedRectangle(cornerRadius: 6))
        .onTapGesture {
            withAnimation(.easeOut(duration: 0.2)) {
                previewImagePath = image.path
            }
        }
    }

    // MARK: - Duplicates Action Bar
    private var duplicatesActionBar: some View {
        HStack(spacing: 16) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 13))
                Text("\(duplicatesManager.totalSelected) selected")
                    .font(.system(size: 13))
            }
            .foregroundColor(p.ink2)

            Spacer()

            Button(action: {
                showMovePanel = true
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "folder")
                    Text("Move to Folder")
                }
                .font(.system(size: 13))
                .foregroundColor(p.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .stroke(p.accent, lineWidth: 1)
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
                HStack(spacing: 4) {
                    Image(systemName: "trash")
                    Text("Move to Trash")
                }
                .font(.system(size: 13))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(p.accent2)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(p.sidebar)
        )
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }

    // MARK: - Modern Search Bar
    @FocusState private var isSearchFocused: Bool

    private var modernSearchBar: some View {
        VStack(spacing: 0) {
        HStack(spacing: 14) {
            // Pasted image preview or search icon
            if let image = pastedImage {
                ZStack(alignment: .topTrailing) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(p.accent, lineWidth: 2)
                        )

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
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .italic()
                    .foregroundColor(p.ink2)

                Spacer()

                if searchManager.isSearching {
                    ProgressView()
                        .scaleEffect(0.65)
                }
            } else {
                // Magnifier icon
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(p.accent)

                // Text field
                TextField("describe a moment, or drop an image...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 18, weight: .regular, design: .serif))
                    .foregroundColor(p.ink)
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
                        if pastedImage != nil && !newValue.isEmpty {
                            pastedImage = nil
                        }
                        searchDebounceTimer?.invalidate()
                        searchDebounceTimer = nil
                        if newValue.isEmpty {
                            // Delay clearing so layout doesn't jump immediately
                            searchDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { _ in
                                DispatchQueue.main.async {
                                    self.searchDebounceTimer = nil
                                    self.searchManager.clearResults()
                                }
                            }
                            return
                        }
                        searchDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { _ in
                            DispatchQueue.main.async {
                                self.searchDebounceTimer = nil
                            }
                            if !searchManager.isSearching && !newValue.isEmpty {
                                performSearch()
                            }
                        }
                    }

                if searchManager.isSearching {
                    ProgressView()
                        .scaleEffect(0.65)
                        .transition(.opacity)
                } else if !searchText.isEmpty || !searchManager.results.isEmpty || pastedImage != nil {
                    Button(action: {
                        searchText = ""
                        pastedImage = nil
                        searchDebounceTimer?.invalidate()
                        searchDebounceTimer = nil
                        searchManager.clearResults()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(p.ink3)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .transition(.opacity)
                }

                // Keyboard shortcut hint
                Text("\u{2318} K")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(p.ink3)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(p.sidebar)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(p.line, lineWidth: 1)
                            )
                    )
            }
        }

            // Vision / Text balance slider
            HStack(spacing: 10) {
                Text("Text")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(clipBalance < 0.4 ? p.accent : p.ink3)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Track
                        RoundedRectangle(cornerRadius: 2)
                            .fill(p.line)
                            .frame(height: 3)

                        // Fill
                        RoundedRectangle(cornerRadius: 2)
                            .fill(p.accent.opacity(0.4))
                            .frame(width: geo.size.width * clipBalance, height: 3)

                        // Thumb
                        Circle()
                            .fill(p.accent)
                            .frame(width: 12, height: 12)
                            .shadow(color: p.accent.opacity(0.3), radius: 3, y: 1)
                            .offset(x: max(0, min(geo.size.width - 12, geo.size.width * clipBalance - 6)))
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                clipBalance = max(0, min(1, value.location.x / geo.size.width))
                            }
                    )
                }
                .frame(height: 12)

                Text("Vision")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(clipBalance > 0.6 ? p.accent : p.ink3)
            }
            .padding(.top, 10)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(p.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(p.line, lineWidth: 1)
                )
        )
        .shadow(color: isSearchFocused ? p.halo : .clear, radius: 12, y: 0)
        .shadow(color: Color.black.opacity(0.06), radius: 20, y: 8)
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
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(p.accent, lineWidth: 2)
                }
            }
        )
        .frame(maxWidth: 720)
    }

    // MARK: - Drop Overlay
    private var dropOverlayView: some View {
        ZStack {
            // Background: palette halo with blur, behind content at 40%
            p.halo.opacity(0.40)
                .background(.ultraThinMaterial)
                .ignoresSafeArea()

            // Dashed accent border inset 16
            RoundedRectangle(cornerRadius: 22)
                .stroke(style: StrokeStyle(lineWidth: 2.5, dash: [10, 6]))
                .foregroundColor(p.accent)
                .padding(16)

            // Center content
            VStack(spacing: 16) {
                // Upload icon box — rotated -2deg per spec
                ZStack {
                    RoundedRectangle(cornerRadius: 26)
                        .fill(p.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: 26)
                                .stroke(p.line, lineWidth: 1)
                        )
                        .shadow(color: p.halo, radius: 20, y: 14)
                        .frame(width: 88, height: 88)

                    Image(systemName: "arrow.up.doc")
                        .font(.system(size: 36, weight: .light))
                        .foregroundColor(p.accent)
                }
                .rotationEffect(.degrees(-2))

                // Title
                VStack(spacing: 8) {
                    HStack(spacing: 0) {
                        Text("drop to find ")
                            .font(.system(size: 38, weight: .regular, design: .serif))
                            .tracking(-0.4)
                            .foregroundColor(p.ink)
                        Text("visually similar")
                            .font(.system(size: 38, weight: .regular, design: .serif))
                            .tracking(-0.4)
                            .italic()
                            .foregroundColor(p.accent)
                    }

                    // Subtitle
                    Text("Searchy will match colour, composition, subject — your library, calmly.")
                        .font(.system(size: 17, design: .serif))
                        .italic()
                        .foregroundColor(p.ink2)
                }

                // Bottom hints row
                HStack(spacing: 14) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(p.accent)
                            .frame(width: 8, height: 8)
                        Text("jpg \u{00B7} png \u{00B7} heic \u{00B7} webp")
                            .font(.system(size: 12))
                            .foregroundColor(p.ink3)
                    }

                    Text("\u{00B7}")
                        .foregroundColor(p.ink3)

                    Text("up to 50 MB")
                        .font(.system(size: 12))
                        .foregroundColor(p.ink3)

                    Text("\u{00B7}")
                        .foregroundColor(p.ink3)

                    Text("or paste from clipboard")
                        .font(.system(size: 12))
                        .foregroundColor(p.ink3)
                }
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Keyboard Overlay
    private var keyboardOverlayView: some View {
        ZStack {
            // Scrim
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { showKeyboardOverlay = false }

            // Card
            VStack(spacing: 0) {
                // Header
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "keyboard")
                            .font(.system(size: 16))
                            .foregroundColor(p.accent)
                        Text("Keyboard Shortcuts")
                            .font(.system(size: 22, weight: .regular, design: .serif))
                            .foregroundColor(p.ink)
                    }
                    Spacer()
                    Button(action: { showKeyboardOverlay = false }) {
                        ZStack {
                            Circle()
                                .fill(p.paper)
                                .overlay(Circle().stroke(p.line, lineWidth: 1))
                                .frame(width: 28, height: 28)
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(p.ink3)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 32)
                .padding(.top, 28)
                .padding(.bottom, 20)

                Rectangle().fill(p.line).frame(height: 0.5)

                // Two-column grid of shortcuts
                ScrollView {
                    HStack(alignment: .top, spacing: 40) {
                        // Left column
                        VStack(alignment: .leading, spacing: 24) {
                            keyboardSection("Navigation", shortcuts: [
                                ("⌘ K", "Focus search"),
                                ("⌘ 1-6", "Switch tabs"),
                                ("⌘ ,", "Settings"),
                                ("Esc", "Close panel / overlay"),
                                ("⌘ ?", "Toggle this overlay"),
                            ])
                            keyboardSection("Search", shortcuts: [
                                ("Return", "Search"),
                                ("⌘ V", "Paste image to search"),
                                ("⌘ ⇧ F", "Find similar"),
                                ("⌘ ⇧ C", "Copy result path"),
                            ])
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Rectangle().fill(p.line).frame(width: 0.5)

                        // Right column
                        VStack(alignment: .leading, spacing: 24) {
                            keyboardSection("Results", shortcuts: [
                                ("Space", "Quick Look"),
                                ("⌘ O", "Open in default app"),
                                ("⌘ ⇧ R", "Reveal in Finder"),
                                ("⌘ C", "Copy image"),
                                ("⌘ ⇧ I", "Toggle inspector"),
                            ])
                            keyboardSection("Faces & Duplicates", shortcuts: [
                                ("⌘ M", "Merge selected"),
                                ("⌘ A", "Select all"),
                                ("Delete", "Remove selection"),
                                ("⌘ ⇧ N", "New group"),
                            ])
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 24)
                }

                // Footer hint
                HStack {
                    Spacer()
                    Text("Press ⌘ ? or Esc to close")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(p.ink3)
                    Spacer()
                }
                .padding(.vertical, 14)
                .overlay(alignment: .top) {
                    Rectangle().fill(p.line).frame(height: 0.5)
                }
            }
            .frame(width: 720, height: 520)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(p.card)
                    .shadow(color: Color.black.opacity(0.3), radius: 40, y: 20)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(p.line, lineWidth: 1)
            )
        }
    }

    private func keyboardSection(_ title: String, shortcuts: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 9.5, weight: .semibold))
                .tracking(1.6)
                .foregroundColor(p.ink3)
                .padding(.bottom, 2)

            ForEach(Array(shortcuts.enumerated()), id: \.offset) { _, shortcut in
                HStack(spacing: 12) {
                    Text(shortcut.0)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(p.ink)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(p.sidebar)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(p.line, lineWidth: 1)
                                )
                        )
                        .frame(minWidth: 70, alignment: .center)

                    Text(shortcut.1)
                        .font(.system(size: 12))
                        .foregroundColor(p.ink2)

                    Spacer()
                }
            }
        }
    }

    // MARK: - Detail Lightbox (AtelierDetail)
    private var atelierLightbox: some View {
        let result = lightboxResult ?? lightboxResults.first
        let darkBg = Color(red: 0x0E/255, green: 0x0C/255, blue: 0x09/255)
        let sidebarBg = Color(red: 0x15/255, green: 0x12/255, blue: 0x0D/255)
        let dimWhite = Color.white.opacity(0.85)
        let dimWhite2 = Color.white.opacity(0.45)
        let dimWhite3 = Color.white.opacity(0.4)
        let divider = Color.white.opacity(0.08)

        return ZStack {
            darkBg.ignoresSafeArea()

            HStack(spacing: 0) {
                // Main image area
                ZStack {
                    if let r = result {
                        LightboxImage(path: r.path)
                    }

                    // Counter top-left
                    VStack {
                        HStack {
                            if lightboxResults.count > 1 {
                                Text("\(lightboxIndex + 1) of \(lightboxResults.count)")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            Spacer()
                            // Close button
                            Button(action: { withAnimation { lightboxResult = nil } }) {
                                ZStack {
                                    Circle()
                                        .fill(Color.white.opacity(0.08))
                                        .frame(width: 32, height: 32)
                                    Image(systemName: "xmark")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(20)
                        Spacer()
                    }

                    // Filmstrip at bottom
                    if lightboxResults.count > 1 {
                        VStack {
                            Spacer()
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(Array(lightboxResults.prefix(20).enumerated()), id: \.element.id) { idx, r in
                                        Button(action: {
                                            lightboxIndex = idx
                                            lightboxResult = lightboxResults[idx]
                                        }) {
                                            AsyncThumbnailView(path: r.path, maxSize: 100, contentMode: .fill)
                                                .frame(width: 44, height: 30)
                                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                                .opacity(idx == lightboxIndex ? 1 : 0.4)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 4)
                                                        .stroke(idx == lightboxIndex ? p.accent : Color.clear, lineWidth: 1)
                                                )
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                            .padding(.bottom, 20)
                        }
                    }

                    // Arrow nav
                    if lightboxResults.count > 1 {
                        HStack {
                            if lightboxIndex > 0 {
                                Button(action: { navigateLightbox(-1) }) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 20, weight: .medium))
                                        .foregroundColor(.white.opacity(0.6))
                                        .frame(width: 40, height: 40)
                                        .background(Circle().fill(Color.white.opacity(0.08)))
                                }
                                .buttonStyle(PlainButtonStyle())
                                .padding(.leading, 16)
                            }
                            Spacer()
                            if lightboxIndex < lightboxResults.count - 1 {
                                Button(action: { navigateLightbox(1) }) {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 20, weight: .medium))
                                        .foregroundColor(.white.opacity(0.6))
                                        .frame(width: 40, height: 40)
                                        .background(Circle().fill(Color.white.opacity(0.08)))
                                }
                                .buttonStyle(PlainButtonStyle())
                                .padding(.trailing, 16)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Sidebar
                if let r = result {
                    VStack(alignment: .leading, spacing: 0) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 18) {
                                // Title
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(URL(fileURLWithPath: r.path).deletingPathExtension().lastPathComponent)
                                        .font(.system(size: 22, weight: .regular, design: .serif))
                                        .italic()
                                        .foregroundColor(.white)
                                        .lineLimit(2)

                                    if r.similarity > 0 {
                                        Text("match \(String(format: "%.2f", r.similarity)) \u{00B7} vision-weighted")
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundColor(dimWhite2)
                                    }
                                }

                                // Divider
                                Rectangle().fill(divider).frame(height: 1)

                                // Metadata grid
                                LightboxMetadataGrid(path: r.path, result: r)

                                Rectangle().fill(divider).frame(height: 1)

                                // Detected text section (if available from OCR)
                                LightboxDetectedText(path: r.path)
                            }
                            .padding(24)
                        }

                        Spacer()

                        // Action buttons
                        HStack(spacing: 8) {
                            Button(action: {
                                NSWorkspace.shared.selectFile(r.path, inFileViewerRootedAtPath: "")
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "folder")
                                        .font(.system(size: 13))
                                    Text("Reveal in Finder")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(RoundedRectangle(cornerRadius: 8).fill(p.accent))
                            }
                            .buttonStyle(PlainButtonStyle())

                            Button(action: {
                                if let image = NSImage(contentsOfFile: r.path) {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.writeObjects([image])
                                    copyToastFilename = URL(fileURLWithPath: r.path).lastPathComponent
                                    showCopyToast = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        showCopyToast = false
                                    }
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 13))
                                    Text("Copy")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.08)))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(24)
                    }
                    .frame(width: 280)
                    .background(sidebarBg)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(divider).frame(width: 1)
                    }
                }
            }
        }
        .onExitCommand { withAnimation { lightboxResult = nil } }
    }

    private func navigateLightbox(_ direction: Int) {
        let newIndex = lightboxIndex + direction
        guard newIndex >= 0 && newIndex < lightboxResults.count else { return }
        lightboxIndex = newIndex
        lightboxResult = lightboxResults[newIndex]
    }

    private func openLightbox(result: SearchResult, allResults: [SearchResult]) {
        lightboxResults = allResults
        lightboxIndex = allResults.firstIndex(where: { $0.id == result.id }) ?? 0
        withAnimation(.easeOut(duration: 0.25)) {
            lightboxResult = result
        }
    }

    // MARK: - Indexing Progress View
    private var indexingProgressView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top row: percentage + info + cancel
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("\(Int(indexingPercent))")
                        .font(.system(size: 36, weight: .regular, design: .serif))
                        .foregroundColor(p.accent)
                    Text("%")
                        .font(.system(size: 18, weight: .regular, design: .serif))
                        .foregroundColor(p.accent)
                }

                VStack(alignment: .leading, spacing: 3) {
                    if !indexingProgress.isEmpty {
                        Text(indexingProgress)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(p.ink)
                    }
                    HStack(spacing: 0) {
                        if !indexingBatchInfo.isEmpty {
                            Text(indexingBatchInfo)
                        }
                        if indexingSpeed > 0 {
                            Text(" \u{00B7} \(String(format: "%.1f", indexingSpeed)) img/s")
                        }
                        if indexingElapsed > 0 {
                            Text(" \u{00B7} \(formatDuration(indexingElapsed))")
                        }
                    }
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(p.ink2)
                }

                Spacer()

                Button(action: { cancelIndexing() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .medium))
                        Text("Cancel")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(p.ink2)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(p.line, lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.bottom, 14)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(p.line)
                        .frame(height: 5)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(p.accent)
                        .frame(width: geo.size.width * (indexingPercent / 100), height: 5)
                        .animation(.easeInOut(duration: 0.3), value: indexingPercent)
                }
            }
            .frame(height: 5)
            .padding(.bottom, 14)

            // Bottom stats row
            HStack(spacing: 20) {
                if !indexingETA.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ETA")
                            .font(.system(size: 9.5, weight: .semibold))
                            .tracking(0.8)
                            .foregroundColor(p.ink3)
                        Text(indexingETA)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(p.ink)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("MODEL")
                        .font(.system(size: 9.5, weight: .semibold))
                        .tracking(0.8)
                        .foregroundColor(p.ink3)
                    Text(modelSettings.currentModelDisplayName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(p.ink)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("DEVICE")
                        .font(.system(size: 9.5, weight: .semibold))
                        .tracking(0.8)
                        .foregroundColor(p.ink3)
                    Text(modelSettings.currentDevice)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(p.ink)
                }
                Spacer()
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(p.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(p.line, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
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
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("COMPLETE")
                        .font(.system(size: 9.5, weight: .semibold))
                        .tracking(1.6)
                        .foregroundColor(DesignSystem.Colors.success)

                    Text("Indexing finished")
                        .font(.system(size: 20, weight: .regular, design: .serif))
                        .foregroundColor(p.ink)
                }

                Spacer()

                Button(action: { indexingReport = nil }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(p.ink3)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(p.paper)
                                .overlay(Circle().stroke(p.line, lineWidth: 1))
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.bottom, 16)

            Divider().background(p.line).padding(.bottom, 16)

            // Stats row
            HStack(spacing: 24) {
                atelierStatLabel("Images", value: "\(report.newImages)")
                atelierStatLabel("Duration", value: formatDuration(report.totalTime))
                atelierStatLabel("Speed", value: String(format: "%.1f img/s", report.imagesPerSec))
                atelierStatLabel("Model", value: modelSettings.currentModelDisplayName)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(p.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(DesignSystem.Colors.success.opacity(0.4), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
        .onAppear {
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
        HStack(spacing: 18) {
            HStack(spacing: 6) {
                Image(systemName: "photo.stack")
                    .font(.system(size: 10))
                    .foregroundColor(p.ink3)
                Text("\(stats.totalImages)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(p.ink2)
                Text("indexed")
                    .font(.system(size: 11))
                    .foregroundColor(p.ink3)
            }

            if let lastMod = stats.lastModified {
                HStack(spacing: 5) {
                    Circle()
                        .fill(DesignSystem.Colors.success)
                        .frame(width: 5, height: 5)
                    Text("updated \(formatRelativeDate(lastMod))")
                        .font(.system(size: 11, design: .default))
                        .italic()
                        .foregroundColor(p.ink3)
                }
            }

            Spacer()

            Button(action: { loadIndexStats() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11))
                    .foregroundColor(p.ink3)
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
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 0) {
                // Stacked paper illustration
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(p.card)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(p.line, lineWidth: 1))
                        .frame(width: 180, height: 180)
                        .rotationEffect(.degrees(-6))
                    RoundedRectangle(cornerRadius: 8)
                        .fill(p.card)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(p.line, lineWidth: 1))
                        .frame(width: 180, height: 180)
                        .rotationEffect(.degrees(3))
                    RoundedRectangle(cornerRadius: 8)
                        .fill(p.card)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(p.line, lineWidth: 1))
                        .frame(width: 180, height: 180)
                        .overlay(
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 40, weight: .light))
                                .foregroundColor(p.ink3)
                        )
                }
                .padding(.bottom, 28)

                Text("nothing matches that, yet")
                    .font(.system(size: 32, weight: .regular, design: .serif))
                    .tracking(-0.3)
                    .foregroundColor(p.ink)
                    .padding(.bottom, 8)

                HStack(spacing: 0) {
                    Text("Searchy looked across ")
                        .font(.system(size: 16, weight: .regular, design: .serif))
                        .italic()
                        .foregroundColor(p.ink2)
                    if let stats = indexStats {
                        Text("\(stats.totalImages.formatted()) photos")
                            .font(.system(size: 16, weight: .medium, design: .serif))
                            .foregroundColor(p.ink)
                    }
                    Text(". None passed the similarity floor.")
                        .font(.system(size: 16, weight: .regular, design: .serif))
                        .italic()
                        .foregroundColor(p.ink2)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: 540)
                .padding(.bottom, 24)

                // Suggestions
                VStack(alignment: .leading, spacing: 10) {
                    emptyStateSuggestion(icon: "sparkles", text: "try a softer phrase like ", emphasis: "\u{201C}violet sky\u{201D}")
                    emptyStateSuggestion(icon: "eye", text: "drop more of the search toward ", emphasis: "vision")
                    emptyStateSuggestion(icon: "arrow.up.doc", text: "drag in a reference image to find ", emphasis: "visually like this")
                }
                .padding(.bottom, 36)

                // Closest matches below threshold card
                if !recentImages.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("CLOSEST MATCHES (BELOW THRESHOLD)")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(1)
                            .foregroundColor(p.ink3)

                        HStack(spacing: 8) {
                            ForEach(Array(recentImages.prefix(5).enumerated()), id: \.element.id) { idx, result in
                                ZStack(alignment: .topLeading) {
                                    AsyncThumbnailView(path: result.path)
                                        .aspectRatio(1, contentMode: .fill)
                                        .frame(maxWidth: .infinity)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .opacity(0.6)

                                    Text(String(format: "%.2f", max(0.45, 0.61 - Double(idx) * 0.03)))
                                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1)
                                        .background(RoundedRectangle(cornerRadius: 4).fill(Color.black.opacity(0.6)))
                                        .padding(4)
                                }
                            }
                        }
                    }
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(p.card)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(p.line, lineWidth: 1))
                    )
                    .frame(maxWidth: 540)
                }
            }
            .frame(maxWidth: 540)

            Spacer()
        }
    }

    private func emptyStateSuggestion(icon: String, text: String, emphasis: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(p.accent)
                .frame(width: 16)
            HStack(spacing: 0) {
                Text(text)
                    .font(.system(size: 13))
                    .foregroundColor(p.ink2)
                Text(emphasis)
                    .font(.system(size: 13, design: .serif))
                    .italic()
                    .foregroundColor(p.ink)
            }
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
                        .foregroundColor(p.ink3)
                    Text("No photos yet")
                        .font(.system(size: 14, weight: .medium, design: .serif))
                        .italic()
                        .foregroundColor(p.ink2)
                    Spacer()
                }
            } else if filteredRecentImages.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 36, weight: .light))
                        .foregroundColor(p.ink3)
                    Text("No photos match filters")
                        .font(.system(size: 14, weight: .medium, design: .serif))
                        .italic()
                        .foregroundColor(p.ink2)
                    Spacer()
                }
            } else {
                ScrollView {
                    // Suggestion chips (Atelier style)
                    if searchText.isEmpty {
                        HStack(spacing: 8) {
                            ForEach(["sunset over mountains", "invoice 2024", "screenshots", "people wearing red"], id: \.self) { suggestion in
                                Button(action: {
                                    searchText = suggestion
                                    performSearch()
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: suggestionIcon(for: suggestion))
                                            .font(.system(size: 11))
                                            .foregroundColor(p.ink3)
                                        Text(suggestion)
                                            .font(.system(size: 14, weight: .regular, design: .serif))
                                            .italic()
                                            .foregroundColor(p.ink2)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(p.card)
                                            .overlay(Capsule().stroke(p.line, lineWidth: 1))
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)
                    }

                    MasonryGrid(items: filteredRecentImages, columns: showPreviewPanel ? 2 : 3, spacing: 16) { result in
                        MasonryImageCard(
                            result: result,
                            onFindSimilar: { path in
                                findSimilarWithPreview(path: path)
                            },
                            onOpen: {
                                openLightbox(result: result, allResults: filteredRecentImages)
                            },
                            onHoverStart: handlePreviewHoverStart,
                            onHoverEnd: handlePreviewHoverEnd
                        )
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
    }

    private func suggestionIcon(for text: String) -> String {
        if text.contains("sunset") || text.contains("sun") { return "sun.max" }
        if text.contains("people") || text.contains("person") { return "person.2" }
        if text.contains("screenshot") { return "rectangle.on.rectangle" }
        if text.contains("invoice") || text.contains("doc") { return "doc.text" }
        return "sparkles"
    }

    // MARK: - Error View
    private var errorView: some View {
        Group {
            if let error = searchManager.errorMessage {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(DesignSystem.Colors.error)

                    Text(error)
                        .font(.system(size: 13))
                        .foregroundColor(p.ink)

                    Spacer()

                    Button(action: {
                        searchManager.cancelSearch()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(p.ink3)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(DesignSystem.Colors.error.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
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
                HStack(spacing: 24) {
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
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(colorScheme == .dark ?
                            p.card :
                            p.card)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(p.line, lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Results List
    private var resultsList: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with info and stats
            if !searchManager.isSearching || !searchManager.results.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(p.accent)
                            Text("Double-click any image to copy")
                                .font(.system(size: 12))
                                .foregroundColor(p.ink2)
                        }

                        Spacer()

                        if !searchManager.results.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 10))
                                    .foregroundColor(p.accent)
                                Text("\(searchManager.results.count) results")
                                    .font(.system(size: 12).weight(.medium))
                                    .foregroundColor(p.ink2)
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
                                findSimilarWithPreview(path: path)
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
        // Save to recent searches
        let query = searchText.trimmingCharacters(in: .whitespaces)
        if !query.isEmpty {
            recentSearchQueries.removeAll { $0 == query }
            recentSearchQueries.insert(query, at: 0)
            if recentSearchQueries.count > 8 {
                recentSearchQueries = Array(recentSearchQueries.prefix(8))
            }
            UserDefaults.standard.set(recentSearchQueries, forKey: "recentSearchQueries")
        }
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

            // Check for Cmd+K (focus search)
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "k" {
                DispatchQueue.main.async {
                    self.activeTab = .search
                    self.isSearchFocused = true
                }
                return nil
            }

            // Check for Cmd+1-6 (switch tabs)
            if event.modifierFlags.contains(.command), let chars = event.charactersIgnoringModifiers, chars.count == 1,
               let digit = chars.first?.wholeNumberValue, digit >= 1 && digit <= 6 {
                let tabs: [AppTab] = [.faces, .search, .volumes, .duplicates, .favorites, .setup]
                DispatchQueue.main.async {
                    self.activeTab = tabs[digit - 1]
                }
                return nil
            }

            // Check for Cmd+, (settings)
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "," {
                DispatchQueue.main.async {
                    self.isShowingSettings = true
                }
                return nil
            }

            // Check for Cmd+? (keyboard overlay toggle)
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "/" {
                DispatchQueue.main.async {
                    withAnimation { self.showKeyboardOverlay.toggle() }
                }
                return nil
            }

            // Check for Escape to close overlays/panels
            if event.keyCode == 53 {
                if self.showKeyboardOverlay {
                    DispatchQueue.main.async {
                        withAnimation { self.showKeyboardOverlay = false }
                    }
                    return nil
                }
                if self.lightboxResult != nil {
                    DispatchQueue.main.async {
                        withAnimation { self.lightboxResult = nil }
                    }
                    return nil
                }
                if self.showPreviewPanel {
                    DispatchQueue.main.async {
                        withAnimation { self.showPreviewPanel = false }
                    }
                    return nil
                }
            }

            // Arrow keys for lightbox navigation
            if self.lightboxResult != nil {
                if event.keyCode == 123 { // Left arrow
                    DispatchQueue.main.async { self.navigateLightbox(-1) }
                    return nil
                }
                if event.keyCode == 124 { // Right arrow
                    DispatchQueue.main.async { self.navigateLightbox(1) }
                    return nil
                }
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

