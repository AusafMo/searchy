import SwiftUI
import AppKit
import Foundation
import UniformTypeIdentifiers

struct Constants {
    static let baseDirectory: String = "/Users/ausaf/Library/Application Support/searchy"
    static let defaultPort: Int = 7860
    static let pythonExecutablePath: String = "/Users/ausaf/Desktop/searchy/.venv/bin/python3"
    static let serverScriptPath: String = "/Users/ausaf/Desktop/searchy/searchy/server.py"
    static let embeddingScriptPath: String = "/Users/ausaf/Desktop/searchy/searchy/generate_embeddings.py"
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


struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let content: () -> Content  // Changed to closure type
    
    init(title: String, icon: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(.blue)
            content()  // Call the closure
        }
    }
}

struct PathSetting: View {
    let title: String
    let icon: String
    @Binding var path: String
    @Binding var showPicker: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
            HStack {
                TextField("Path", text: $path)
                    .textFieldStyle(.roundedBorder)
                Button("Browse") {
                    showPicker = true
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

struct SettingsGroup<Content: View>: View {
    let title: String
    let content: () -> Content  // Changed to closure type
    
    init(title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }
    
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                content()  // Call the closure
            }
            .padding(.vertical, 8)
        }
    }
}

struct SettingsView: View {
    @ObservedObject private var config = AppConfig.shared
    @ObservedObject private var prefs = SearchPreferences.shared
    @State private var isShowingPythonPicker = false
    @State private var isShowingServerScriptPicker = false
    @State private var isShowingEmbeddingScriptPicker = false
    @State private var isShowingBaseDirectoryPicker = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Enhanced Header
            HStack {
                Text("Settings")
                    .font(.system(size: 24, weight: .bold))
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
            )
            
            ScrollView {
                VStack(spacing: 24) {
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
                        config.resetToDefaults()
                    }) {
                        Label("Reset to Defaults", systemImage: "arrow.counterclockwise")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.bordered)
                    .padding(.top)
                }
                .padding()
            }
        }
        .frame(width: 600, height: 700)
        .background(Color(.windowBackgroundColor))
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


struct CopyNotification: View {
    @Binding var isShowing: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .imageScale(.medium)
            
            Text("Copied!")
                .font(.system(size: 13, weight: .bold))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            ZStack {
                Color.black
                    .opacity(0.15)
                    .background(.ultraThinMaterial)
                
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.white.opacity(0.3), lineWidth: 0.5)
            }
        )
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.15), radius: 5, x: 0, y: 2)
        .offset(y: isShowing ? 0 : 10)
        .opacity(isShowing ? 1 : 0)
        .animation(
            .spring(response: 0.3, dampingFraction: 0.8),
            value: isShowing
        )
    }
}

struct ResultCardView: View {
    let result: SearchResult
    @State private var showingCopyNotification = false
    @StateObject private var prefs = SearchPreferences.shared
    
    var body: some View {
        VStack(spacing: 6) { // Changed alignment to center by removing alignment parameter
            ZStack {
                DoubleClickImageView(filePath: result.path) {
                    copyImage(path: result.path)
                    showCopyNotification()
                }
                .aspectRatio(contentMode: .fit)
                .frame(width: CGFloat(prefs.imageSize), height: CGFloat(prefs.imageSize))
                .clipped()
                .frame(maxWidth: .infinity, alignment: .center) // Added this line to center the image
                
                CopyNotification(isShowing: $showingCopyNotification)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(URL(fileURLWithPath: result.path).lastPathComponent)
                    .lineLimit(1)
                    .font(.caption2)
                
                HStack {
                    Text("Similarity: \(String(format: "%.1f%%", result.similarity * 100))")
                        .font(.caption2)
                    Spacer()
                    Button(action: {
                        revealInFinder(path: result.path)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "folder")
                                .font(.caption2)
                            Text("Reveal")
                                .font(.caption2)
                        }
                    }
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
        }
        .frame(maxWidth: .infinity) // Added this to ensure the card takes full width
        .background(Color(.windowBackgroundColor))
        .cornerRadius(8)
        .shadow(radius: 1)
    }
    
    private func showCopyNotification() {
        showingCopyNotification = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
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

struct DoubleClickImageView: NSViewRepresentable {
    let filePath: String
    let onDoubleClick: () -> Void
    
    func makeNSView(context: Context) -> NSImageView {
        let imageView = DoubleClickableImageView()
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.onDoubleClick = onDoubleClick
        return imageView
    }
    
    func updateNSView(_ nsView: NSImageView, context: Context) {
        if let cachedImage = ImageCache.shared.image(for: filePath) {
            nsView.image = cachedImage
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            if let image = NSImage(contentsOfFile: filePath) {
                let newSize = calculateAspectRatioSize(for: image, maxWidth: 250, maxHeight: 250)
                let resizedImage = resizeImage(image, targetSize: newSize)
                ImageCache.shared.setImage(resizedImage, for: filePath)
                DispatchQueue.main.async {
                    nsView.image = resizedImage
                }
            }
        }
    }
    
    private func calculateAspectRatioSize(for image: NSImage, maxWidth: CGFloat, maxHeight: CGFloat) -> NSSize {
        let maxSize = CGFloat(SearchPreferences.shared.imageSize)
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

class DoubleClickableImageView: NSImageView {
    var onDoubleClick: (() -> Void)?
    
    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            onDoubleClick?()
        }
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
    @Published private(set) var results: [SearchResult] = []
    @Published private(set) var isSearching = false
    @Published private(set) var errorMessage: String? = nil
    @Published private(set) var searchStats: SearchStats? = nil
    
    private var serverURL: URL {
        get async {
            let delegate = await AppDelegate.shared
            guard let url = await delegate.serverURL else {
                fatalError("Server URL is not initialized")
            }
            return url
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
        let serverURL = await self.serverURL
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
                throw NSError(domain: "No valid JSON response found", code: 0, userInfo: nil)
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
}

struct ContentView: View {
    @StateObject private var searchManager = SearchManager()
    @State private var searchText = ""
    @State private var isIndexing = false
    @State private var indexingProgress = ""
    @State private var isShowingSettings = false  // Add this

    var body: some View {
        VStack(spacing: 0) {
            // Top toolbar
            HStack {
                Button(action: {
                    isShowingSettings = true
                }) {
                    Image(systemName: "gear")
                        .font(.system(size: 16))
                        .foregroundStyle(.blue)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(8)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                Spacer()
                
                Button(action: {
                    if !isIndexing {
                        selectAndIndexFolder()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.square")
                        Text("Index New Folder")
                    }.fontWeight(Font.Weight.semibold).foregroundStyle(.blue)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(8)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                .cornerRadius(8)
                .disabled(isIndexing)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.windowBackgroundColor).opacity(0.8))
            
            // Main content area
            VStack {
                if !indexingProgress.isEmpty {
                    Text(indexingProgress)
                        .foregroundColor(.blue).fontWeight(Font.Weight.bold)
                        .padding(.vertical, 4)
                }
                
                searchBarView
                errorView
                
                ScrollView {
                    resultsList
                        .padding()
                }
                .background(Color(.separatorColor).opacity(0.1))
            }
            .background(Color(.windowBackgroundColor).opacity(0.9))
        }
        .background(Color(.windowBackgroundColor).opacity(0.7))
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
                .frame(width: 600, height: 700)
        }
        .onDisappear {
            searchManager.cancelSearch()
        }
    }
    private var searchBarView: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
                .font(.system(size: 14))
            
            TextField("Search images...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 14))
                .onSubmit {
                    if !searchManager.isSearching {
                        performSearch()
                    }
                }
                .disabled(searchManager.isSearching || isIndexing)
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 12))
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            if searchManager.isSearching {
                ProgressView()
                    .scaleEffect(0.8)
                    .padding(.horizontal)
            } else {
                Button(action: {
                    if !searchManager.isSearching {
                        performSearch()
                    }
                }) {
                    Text("Search")
                        .fontWeight(.semibold)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(searchText.isEmpty ? Color.gray.opacity(0.2) : Color.green)
                .foregroundColor(searchText.isEmpty ? .gray : .white)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(.primary, lineWidth: 0.5)
                )
                .disabled(searchText.isEmpty || isIndexing)
            }
        }
        .padding(12)
        .background(Color(.textBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    LinearGradient(colors: [.blue, .pink], startPoint: .leading, endPoint: .trailing),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        .padding()
    }
    
    private var errorView: some View {
        Group {
            if let error = searchManager.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            }
        }
    }
    
    private var statsView: some View {
        Group {
            if let stats = searchManager.searchStats {
                HStack(spacing: 20) {
                    VStack(alignment: .leading) {
                        Text("Search Time")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(stats.total_time)
                            .font(.caption)
                            .bold()
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Images Searched")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("\(stats.images_searched)")
                            .font(.caption)
                            .bold()
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Images/Second")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(stats.images_per_second)
                            .font(.caption)
                            .bold()
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
        }
    }
    
    private var resultsList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Info label
                HStack(spacing: 4) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                        .imageScale(.small)
                    Text("Double click to copy image")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .padding(.horizontal)
                
                if SearchPreferences.shared.showStats {
                    statsView
                }
                
                let columns = Array(repeating: GridItem(.flexible(), spacing: 12),
                                  count: SearchPreferences.shared.gridColumns)
                
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(searchManager.results.filter { result in
                        result.similarity >= SearchPreferences.shared.similarityThreshold
                    }) { result in
                        ResultCardView(result: result)
                    }
                }
                .padding()
            }
        }
    }

    private func resultView(for result: SearchResult) -> some View {
        @State var showingCopyNotification = false
        
        return VStack(alignment: .leading, spacing: 6) {
            ZStack {
                DoubleClickImageView(filePath: result.path) {
                    copyImage(path: result.path)
                    showCopyNotification()
                }
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipped()
                
                CopyNotification(isShowing: $showingCopyNotification)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(URL(fileURLWithPath: result.path).lastPathComponent)
                    .lineLimit(1)
                    .font(.caption2)
                
                HStack {
                    Text("Similarity: \(String(format: "%.1f%%", result.similarity * 100))")
                        .font(.caption2)
                    Spacer()
                    Button("Copy") {
                        copyImage(path: result.path)
                        showCopyNotification()
                    }
                    .font(.caption2)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
        }
        .background(Color(.windowBackgroundColor))
        .cornerRadius(8)
        .shadow(radius: 1)
        

        func showCopyNotification() {
            showingCopyNotification = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                showingCopyNotification = false
            }
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
    
    private func indexFolder(_ url: URL) {
        print("Starting indexing for url: \(url.path)")
        isIndexing = true
        indexingProgress = "Starting indexing..."
        
        DispatchQueue.global(qos: .userInitiated).async {
            let config = AppConfig.shared
            let process = Process()
            let pipe = Pipe()
            
            process.executableURL = URL(fileURLWithPath: config.pythonExecutablePath)
            process.arguments = [config.embeddingScriptPath, url.path]
            
            process.standardOutput = pipe
            process.standardError = pipe
            
            process.environment = [
                "PYTHONPATH": "\(config.baseDirectory):\(config.baseDirectory)/.venv/lib/python3.12/site-packages",
                "PATH": "\(config.baseDirectory)/.venv/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin",
                "PYTHONUNBUFFERED": "1"
            ]
            
            do {
                try process.run()
                
                pipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    if !data.isEmpty {
                        if let output = String(data: data, encoding: .utf8) {
                            print("Received output: \(output)")
                            DispatchQueue.main.async {
                                self.indexingProgress = output
                            }
                        }
                    }
                }
                
                process.terminationHandler = { _ in
                    DispatchQueue.main.async {
                        self.isIndexing = false
                        self.indexingProgress = ""
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


