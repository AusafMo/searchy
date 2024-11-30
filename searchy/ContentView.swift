import SwiftUI
import AppKit

struct ImageViewFromFile: NSViewRepresentable {
    var filePath: String
    
    func makeNSView(context: Context) -> NSImageView {
        let imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        return imageView
    }
    
    func updateNSView(_ nsView: NSImageView, context: Context) {
        DispatchQueue.global(qos: .userInitiated).async {
            if let image = NSImage(contentsOfFile: filePath) {
                let newSize = calculateAspectRatioSize(for: image, maxWidth: 250, maxHeight: 250)
                let resizedImage = resizeImage(image, targetSize: newSize)
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
        
        // Fill background with white
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
class SearchManager: ObservableObject {
    @Published private(set) var results: [SearchResult] = []
    @Published private(set) var isSearching = false
    @Published private(set) var errorMessage: String? = nil
    
    private var currentTask: Process?
    private var workItem: DispatchWorkItem?
    
    func cancelSearch() {
        workItem?.cancel()
        currentTask?.terminate()
        currentTask = nil
        DispatchQueue.main.async {
            self.isSearching = false
            self.errorMessage = nil
        }
    }
    
    func search(query: String, numberOfResults: Int = 5) {
        cancelSearch()
        
        let workItem = DispatchWorkItem { [weak self] in
            self?.performSearch(query: query, numberOfResults: numberOfResults)
        }
        self.workItem = workItem
        
        DispatchQueue.main.async {
            self.isSearching = true
            self.errorMessage = nil
            self.results = []
        }
        
        DispatchQueue.global(qos: .userInitiated).async(execute: workItem)
    }
    
    private func performSearch(query: String, numberOfResults: Int) {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            updateState(error: "Failed to access Application Support directory")
            return
        }
        
        let appDir = appSupport.appendingPathComponent("searchy")
        
        do {
            try FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true, attributes: nil)
            
            let process = Process()
            let pipe = Pipe()
            self.currentTask = process
            
            process.executableURL = URL(fileURLWithPath: "/Users/ausaf/Desktop/searchy/.venv/bin/python3")
            let scriptPath = "/Users/ausaf/Desktop/searchy/searchy/similarity_search.py"
            process.arguments = [scriptPath, query, String(numberOfResults), appDir.path]
            
            process.standardOutput = pipe
            process.standardError = pipe
            
            process.environment = [
                "PYTHONPATH": "/Users/ausaf/Desktop/searchy/searchy:/Users/ausaf/Desktop/searchy/.venv/lib/python3.12/site-packages",
                "PATH": "/Users/ausaf/Desktop/searchy/.venv/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin",
                "PYTHONUNBUFFERED": "1"
            ]
            
            print("Python command:", process.executableURL?.path ?? "nil")
            print("Script path:", scriptPath)
            print("Arguments:", process.arguments ?? [])
            print("Environment:", process.environment ?? [:])

            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            
            if let rawOutput = String(data: data, encoding: .utf8) {
                print("Raw Python output:", rawOutput)
                
                // Split output by lines and take the last non-empty line as our JSON
                let lines = rawOutput.components(separatedBy: .newlines)
                if let lastLine = lines.last(where: { !$0.isEmpty }) {
                    if let jsonData = lastLine.data(using: .utf8) {
                        do {
                            if let results = try? JSONDecoder().decode([SearchResult].self, from: jsonData) {
                                print("Successfully decoded \(results.count) results")
                                updateState(results: results)
                            } else if let error = try? JSONDecoder().decode([String: String].self, from: jsonData),
                                      let errorMessage = error["error"] {
                                print("Error from Python:", errorMessage)
                                updateState(error: errorMessage)
                            } else {
                                print("Failed to decode JSON:", lastLine)
                                updateState(error: "Failed to decode response")
                            }
                        } catch {
                            print("JSON decode error:", error)
                            updateState(error: error.localizedDescription)
                        }
                    } else {
                        print("Failed to convert last line to data:", lastLine)
                        updateState(error: "Invalid JSON format")
                    }
                } else {
                    print("No valid output lines found")
                    updateState(error: "No valid response from search")
                }
            } else {
                print("Failed to decode Python output")
                updateState(error: "No response from search")
            }
        } catch {
            print("Process error:", error)
            updateState(error: error.localizedDescription)
        }
    }
    private func updateState(results: [SearchResult]? = nil, error: String? = nil) {
        DispatchQueue.main.async {
            if let results = results {
                self.results = results
            }
            self.errorMessage = error
            self.isSearching = false
            self.currentTask = nil
        }
    }
}

struct ContentView: View {
    @StateObject private var searchManager = SearchManager()
    @State private var searchText = ""
    
    var body: some View {
        VStack(spacing: 0) {
            searchBar
            errorView
            resultsList
        }
        .onDisappear {
            searchManager.cancelSearch()
        }
    }
    
    private var searchBar: some View {
        HStack {
            
            Image("searchBar") // Use your custom menu bar icon name here
                        .resizable()
                        .frame(width: 16, height: 16)
            
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            TextField("Search images...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .onSubmit(performSearch)
                .disabled(searchManager.isSearching)
            
            if searchManager.isSearching {
                cancelButton
                ProgressView()
                    .scaleEffect(0.8)
                    .padding(.horizontal)
            } else {
                searchButton
            }
        }
        .padding(12)
        .background(Color(.textBackgroundColor))
        .cornerRadius(8)
        .padding()
    }
    
    private var cancelButton: some View {
        Button(action: { searchManager.cancelSearch() }) {
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.gray)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var searchButton: some View {
        Button("Search", action: performSearch)
            .padding(.horizontal)
            .disabled(searchText.isEmpty)
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
        ScrollView {
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

