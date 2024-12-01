import SwiftUI
import AppKit
import Foundation

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

struct ImageViewFromFile: NSViewRepresentable {
    var filePath: String
    
    func makeNSView(context: Context) -> NSImageView {
        let imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        return imageView
    }
    
    func updateNSView(_ nsView: NSImageView, context: Context) {
        if let cachedImage = ImageCache.shared.image(for: filePath) {
            nsView.image = cachedImage
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            if let image = NSImage(contentsOfFile: filePath) {
                let newSize = self.calculateAspectRatioSize(for: image, maxWidth: 250, maxHeight: 250)
                let resizedImage = self.resizeImage(image, targetSize: newSize)
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
        let url = URL(string: "http://127.0.0.1:7860/search")!
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
                        do {
                            let response = try JSONDecoder().decode(SearchResponse.self, from: jsonData)
                            return response
                        } catch {
                            print("JSON decode error:", error)
                            throw error
                        }
                    } else {
                        throw NSError(domain: "Invalid JSON format", code: 0, userInfo: nil)
                    }
                } else {
                    throw NSError(domain: "No valid JSON response found", code: 0, userInfo: nil)
                }
            } else {
                throw NSError(domain: "No response from search", code: 0, userInfo: nil)
            }
        }
    
    func cancelSearch() {
        print("Cancelling search...")  // Debug: Cancel search
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
    
    var body: some View {
        print("ContentView body being rendered") //
        return VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Index New Folder") {
                    if !isIndexing {
                        selectAndIndexFolder()
                    }
                }
                .disabled(isIndexing)
                .padding(.horizontal)
            }
            .padding(.vertical, 8)
            
            if !indexingProgress.isEmpty {
                Text(indexingProgress)
                    .foregroundColor(.gray)
                    .padding(.vertical, 4)
            }
            
            searchBarView
            errorView
            statsView  //
            resultsList
        }
        .onDisappear {
            searchManager.cancelSearch()
        }
        .onAppear {
            // No need to start a server, as we're directly communicating with the FastAPI server
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
                .padding(.bottom, 8)
            } else {
                Color.clear
                    .frame(height: 0)
            }
        }
    }
    
    private var searchBarView: some View {
        print("Rendering searchBarView, isIndexing: \(isIndexing)") // Debug
        return  HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            TextField("Search images...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .onSubmit {
                    if !searchManager.isSearching {
                        performSearch()
                    }
                }
                .disabled(searchManager.isSearching || isIndexing)
            
            if searchManager.isSearching {
                Button(action: { searchManager.cancelSearch() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
                .buttonStyle(PlainButtonStyle())
                
                ProgressView()
                    .scaleEffect(0.8)
                    .padding(.horizontal)
            } else {
                Button("Search") {
                    if !searchManager.isSearching {
                        performSearch()
                    }
                }
                .disabled(searchText.isEmpty || isIndexing)
                .padding(.horizontal)
            }
        }
        .padding(12)
        .background(Color(.textBackgroundColor))
        .cornerRadius(8)
        .padding()
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
        print("Starting indexing for url: \(url.path)") // Debug
        isIndexing = true
        indexingProgress = "Starting indexing..."
        
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            let pipe = Pipe()
            
            process.executableURL = URL(fileURLWithPath: "/Users/ausaf/Desktop/searchy/.venv/bin/python3")
            let scriptPath = "/Users/ausaf/Desktop/searchy/searchy/generate_embeddings.py"
            process.arguments = [scriptPath, url.path]
            
            process.standardOutput = pipe
            process.standardError = pipe
            
            process.environment = [
                "PYTHONPATH": "/Users/ausaf/Desktop/searchy/searchy:/Users/ausaf/Desktop/searchy/.venv/lib/python3.12/site-packages",
                "PATH": "/Users/ausaf/Desktop/searchy/.venv/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin",
                "PYTHONUNBUFFERED": "1"
            ]
            
            do {
                try process.run()
                
                // Read output in real-time
                pipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    if !data.isEmpty {
                        if let output = String(data: data, encoding: .utf8) {
                            print("Received output: \(output)") // Debug
                            DispatchQueue.main.async {
                                print("Updating progress: \(output)") // Debug
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
    
    private var errorView: some View {
        Group {
            if let error = searchManager.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            }
        }
    }
    
    private var resultsList: some View {
        print("Rendering resultsList, results count: \(searchManager.results.count)") // Debug
        return  ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 16) {
                ForEach(searchManager.results) { result in
                    resultView(for: result)
                }
            }
            .padding()
        }
    }

    private func resultView(for result: SearchResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ImageViewFromFile(filePath: result.path)
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipped()
            
            VStack(alignment: .leading, spacing: 8) {
                Text(URL(fileURLWithPath: result.path).lastPathComponent)
                    .lineLimit(1)
                    .font(.caption)
                
                HStack {
                    Text("Similarity: \(String(format: "%.1f%%", result.similarity * 100))")
                        .font(.caption2)
                    Spacer()
                    Button("Copy") {
                        copyImage(path: result.path)
                    }
                    .font(.caption2)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .background(Color(.windowBackgroundColor))
        .cornerRadius(8)
        .shadow(radius: 1)
    }
    
    private func performSearch() {
        guard !searchText.isEmpty, !searchManager.isSearching else { return }
        searchManager.search(query: searchText)
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
