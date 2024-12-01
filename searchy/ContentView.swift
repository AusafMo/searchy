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

struct SettingsView: View {
    @ObservedObject private var config = AppConfig.shared
    @State private var isShowingPythonPicker = false
    @State private var isShowingServerScriptPicker = false
    @State private var isShowingEmbeddingScriptPicker = false
    @State private var isShowingBaseDirectoryPicker = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color(.windowBackgroundColor))
            
            ScrollView {
                VStack(spacing: 20) {
                    // Server Configuration Group
                    GroupBox(label: settingsHeader("Server Configuration", icon: "server.rack")) {
                        VStack(spacing: 12) {
                            settingsRow("Default Port:", icon: "network") {
                                TextField("Port", value: $config.defaultPort, formatter: NumberFormatter())
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 100)
                            }
                            
                            settingsRow("Base Directory:", icon: "folder") {
                                TextField("Directory", text: $config.baseDirectory)
                                    .textFieldStyle(.roundedBorder)
                                Button("Browse") {
                                    isShowingBaseDirectoryPicker = true
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    
                    // Python Configuration Group
                    GroupBox(label: settingsHeader("Python Configuration", icon: "terminal")) {
                        VStack(spacing: 12) {
                            settingsRow("Python Executable:", icon: "chevron.left.forwardslash.chevron.right") {
                                TextField("Path", text: $config.pythonExecutablePath)
                                    .textFieldStyle(.roundedBorder)
                                Button("Browse") {
                                    isShowingPythonPicker = true
                                }
                                .buttonStyle(.bordered)
                            }
                            
                            settingsRow("Server Script:", icon: "doc.text") {
                                TextField("Path", text: $config.serverScriptPath)
                                    .textFieldStyle(.roundedBorder)
                                Button("Browse") {
                                    isShowingServerScriptPicker = true
                                }
                                .buttonStyle(.bordered)
                            }
                            
                            settingsRow("Embedding Script:", icon: "doc.text.fill") {
                                TextField("Path", text: $config.embeddingScriptPath)
                                    .textFieldStyle(.roundedBorder)
                                Button("Browse") {
                                    isShowingEmbeddingScriptPicker = true
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    
                    // Reset Button
                    HStack {
                        Spacer()
                        Button(action: {
                            config.resetToDefaults()
                        }) {
                            HStack {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Reset to Defaults")
                            }
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.red)
                    }
                }
                .padding()
            }
        }
        .frame(width: 600, height: 400)
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
    
    private func settingsHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
            Text(title)
                .font(.headline)
        }
    }
    
    private func settingsRow<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.gray)
                    .frame(width: 20)
                Text(title)
                    .foregroundColor(.primary)
            }
            .frame(width: 150, alignment: .leading)
            
            content()
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
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
        let imageWidth = image.size.width
        let imageHeight = image.size.height
        
        let widthRatio = maxWidth / imageWidth
        let heightRatio = maxHeight / imageHeight
        
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
    
    private func performSearch(query: String, numberOfResults: Int) async throws -> SearchResponse {
        let serverURL = await self.serverURL
        let url = serverURL.appendingPathComponent("search")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["query": query, "top_k": numberOfResults, "data_dir": "/Users/ausaf/Library/Application Support/searchy"]
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

                .clipShape(Circle())
                
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
                .frame(width: 600, height: 400)
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
        VStack(alignment: .leading, spacing: 12) {
            // Info label above the grid
            HStack(spacing: 4) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                    .imageScale(.small)
                Text("Double click to copy image")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            .padding(.horizontal)
            
            ScrollView {
                VStack(spacing: 12) {
                    statsView
                    
                    // Results grid
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ], spacing: 12) {
                        ForEach(searchManager.results) { result in
                            ResultCardView(result: result)
                        }
                    }
                    .padding()
                    .foregroundStyle(.gray)
                }
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
        
        // Local function to handle showing/hiding notification
        func showCopyNotification() {
            showingCopyNotification = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                showingCopyNotification = false
            }
        }
    }
    
    private func performSearch() {
        guard !searchText.isEmpty, !searchManager.isSearching else { return }
        searchManager.search(query: searchText)
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


