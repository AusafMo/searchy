import SwiftUI
import AppKit

// Image View Component
struct ImageViewFromFile: NSViewRepresentable {
    var filePath: String
    
    func makeNSView(context: Context) -> NSImageView {
        let imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyDown
        imageView.wantsLayer = true
        return imageView
    }
    
    func updateNSView(_ nsView: NSImageView, context: Context) {
        DispatchQueue.global(qos: .userInitiated).async {
            if let image = NSImage(contentsOfFile: filePath) {
                let resizedImage = resizeImage(image)
                DispatchQueue.main.async {
                    nsView.image = resizedImage
                }
            }
        }
    }
    
    private func resizeImage(_ image: NSImage) -> NSImage {
        let maxDimension: CGFloat = 1200
        let originalSize = image.size
        
        // Check if resize is needed
        if originalSize.width <= maxDimension && originalSize.height <= maxDimension {
            return image
        }
        
        // Calculate new size maintaining aspect ratio
        let widthRatio = maxDimension / originalSize.width
        let heightRatio = maxDimension / originalSize.height
        let scale = min(widthRatio, heightRatio)
        
        let newSize = NSSize(
            width: originalSize.width * scale,
            height: originalSize.height * scale
        )
        
        // Create resized image
        let resizedImage = NSImage(size: newSize)
        resizedImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(
            in: NSRect(origin: .zero, size: newSize),
            from: NSRect(origin: .zero, size: originalSize),
            operation: .copy,
            fraction: 1.0
        )
        resizedImage.unlockFocus()
        
        
        return resizedImage
    }
}

// Search Result Model
struct SearchResult: Codable, Identifiable {
    var id = UUID()
    let path: String
    let similarity: Float
}

// Search Manager
class SearchManager: ObservableObject {
    @Published var results: [SearchResult] = []
    @Published var isSearching = false
    @Published var errorMessage: String? = nil
    
    func search(query: String, numberOfResults: Int = 5) {
        isSearching = true
        errorMessage = nil
        
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            let pipe = Pipe()
            
            process.executableURL = URL(fileURLWithPath: "/Users/ausaf/Desktop/searchy/searchy/env/usr/bin/python3")
            // Update this path to your script location
            let scriptPath = "/Users/ausaf/Desktop/searchy/similarity_search.py"
            process.arguments = [scriptPath, query, String(numberOfResults)]
            
            process.standardOutput = pipe
            process.standardError = pipe
            
            do {
                try process.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8),
                   let jsonData = output.data(using: .utf8) {
                    
                    // Try to decode the results
                    if let results = try? JSONDecoder().decode([SearchResult].self, from: jsonData) {
                        DispatchQueue.main.async {
                            self.results = results
                            self.isSearching = false
                        }
                    } else if let error = try? JSONDecoder().decode([String: String].self, from: jsonData),
                              let errorMessage = error["error"] {
                        DispatchQueue.main.async {
                            self.errorMessage = errorMessage
                            self.isSearching = false
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isSearching = false
                }
            }
        }
    }
}

// Main Content View
struct ContentView: View {
    @StateObject private var searchManager = SearchManager()
    @State private var searchText = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search images...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .onSubmit {
                        performSearch()
                    }
                
                if searchManager.isSearching {
                    ProgressView()
                        .scaleEffect(0.8)
                        .padding(.horizontal)
                } else {
                    Button("Search") {
                        performSearch()
                    }
                    .padding(.horizontal)
                }
            }
            .padding(12)
            .background(Color(.textBackgroundColor))
            .cornerRadius(8)
            .padding()
            
            if let error = searchManager.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            }
            
            // Results
            ScrollView {
                LazyVStack(spacing: 20) {
                    ForEach(searchManager.results) { result in
                        VStack(alignment: .leading) {
                            ImageViewFromFile(filePath: result.path)
                                .frame(maxWidth: .infinity)
                                .frame(height: 400)
                                .clipped()
                            
                            HStack {
                                Text("Similarity: \(String(format: "%.1f%%", result.similarity * 100))")
                                    .font(.caption)
                                Spacer()
                                Button("Copy") {
                                    copyImage(path: result.path)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                        }
                        .background(Color(.windowBackgroundColor))
                        .cornerRadius(8)
                        .shadow(radius: 2)
                    }
                }
                .padding()
            }
        }
    }
    
    private func performSearch() {
        guard !searchText.isEmpty else { return }
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
        .frame(minWidth: 800, minHeight: 600)
}
