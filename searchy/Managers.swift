import SwiftUI
import Foundation

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
            "data_dir": kAppSupportPath,
            "similarity_threshold": SearchPreferences.shared.similarityThreshold
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(SearchResponse.self, from: data)

        // Check if server returned an error
        if let errorMessage = response.error {
            throw NSError(domain: "SearchError", code: 0, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }

        return response
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
                    URLQueryItem(name: "top_k", value: "50"),
                    URLQueryItem(name: "data_dir", value: kAppSupportPath)
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

    func findSimilar(imagePath: String, numberOfResults: Int = 20) {
        guard !isSearching else { return }

        DispatchQueue.main.async {
            self.isSearching = true
            self.errorMessage = nil
            self.results = []
            self.searchStats = nil
        }

        Task {
            do {
                let response = try await self.performFindSimilar(imagePath: imagePath, numberOfResults: numberOfResults)
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

    private func performFindSimilar(imagePath: String, numberOfResults: Int) async throws -> SearchResponse {
        guard let serverURL = await self.serverURL else {
            throw NSError(domain: "Server not ready", code: 0, userInfo: [NSLocalizedDescriptionKey: "Server is still starting up. Please wait a moment."])
        }
        let url = serverURL.appendingPathComponent("similar")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "image_path": imagePath,
            "top_k": numberOfResults,
            "data_dir": kAppSupportPath
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(SearchResponse.self, from: data)

        if let errorMessage = response.error {
            throw NSError(domain: "SearchError", code: 0, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }

        return response
    }
}

// MARK: - Duplicates Manager
class DuplicatesManager: ObservableObject {
    static let shared = DuplicatesManager()

    @Published var groups: [DuplicateGroup] = []
    @Published var isScanning = false
    @Published var errorMessage: String? = nil
    @Published var threshold: Float = 0.95
    @Published var totalDuplicates: Int = 0

    private init() {}

    private var serverURL: URL? {
        get async {
            let delegate = await AppDelegate.shared
            return await delegate.serverURL
        }
    }

    func scanForDuplicates() {
        guard !isScanning else { return }

        DispatchQueue.main.async {
            self.isScanning = true
            self.errorMessage = nil
            self.groups = []
        }

        Task {
            do {
                guard let serverURL = await self.serverURL else {
                    throw NSError(domain: "Server not ready", code: 0, userInfo: [NSLocalizedDescriptionKey: "Server is still starting up."])
                }

                let url = serverURL.appendingPathComponent("duplicates")
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")

                let body: [String: Any] = [
                    "threshold": self.threshold,
                    "data_dir": kAppSupportPath
                ]
                request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

                let (data, _) = try await URLSession.shared.data(for: request)
                let response = try JSONDecoder().decode(DuplicatesResponse.self, from: data)

                DispatchQueue.main.async {
                    self.groups = response.groups
                    self.totalDuplicates = response.total_duplicates
                    self.isScanning = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isScanning = false
                }
            }
        }
    }

    func toggleSelection(groupId: Int, imagePath: String) {
        if let groupIndex = groups.firstIndex(where: { $0.id == groupId }),
           let imageIndex = groups[groupIndex].images.firstIndex(where: { $0.path == imagePath }) {
            groups[groupIndex].images[imageIndex].isSelected.toggle()
        }
    }

    func autoSelectSmaller(groupId: Int) {
        if let groupIndex = groups.firstIndex(where: { $0.id == groupId }) {
            // Keep first (largest), select rest
            for i in 0..<groups[groupIndex].images.count {
                groups[groupIndex].images[i].isSelected = i > 0
            }
        }
    }

    func autoSelectAllSmaller() {
        for groupIndex in 0..<groups.count {
            for i in 0..<groups[groupIndex].images.count {
                groups[groupIndex].images[i].isSelected = i > 0
            }
        }
    }

    func deleteSelected(completion: @escaping (Int, Int) -> Void) {
        var deleted = 0
        var failed = 0

        for group in groups {
            for image in group.images where image.isSelected {
                let url = URL(fileURLWithPath: image.path)
                do {
                    try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                    deleted += 1
                } catch {
                    failed += 1
                }
            }
        }

        // Remove deleted images from groups
        DispatchQueue.main.async {
            self.groups = self.groups.compactMap { group in
                var updatedGroup = group
                updatedGroup.images = group.images.filter { !$0.isSelected }
                return updatedGroup.images.count > 1 ? updatedGroup : nil
            }
            self.totalDuplicates = self.groups.reduce(0) { $0 + $1.images.count - 1 }
            completion(deleted, failed)
        }
    }

    func moveSelected(to destination: URL, completion: @escaping (Int, Int) -> Void) {
        var moved = 0
        var failed = 0

        for group in groups {
            for image in group.images where image.isSelected {
                let sourceURL = URL(fileURLWithPath: image.path)
                let destURL = destination.appendingPathComponent(sourceURL.lastPathComponent)
                do {
                    try FileManager.default.moveItem(at: sourceURL, to: destURL)
                    moved += 1
                } catch {
                    failed += 1
                }
            }
        }

        // Remove moved images from groups
        DispatchQueue.main.async {
            self.groups = self.groups.compactMap { group in
                var updatedGroup = group
                updatedGroup.images = group.images.filter { !$0.isSelected }
                return updatedGroup.images.count > 1 ? updatedGroup : nil
            }
            self.totalDuplicates = self.groups.reduce(0) { $0 + $1.images.count - 1 }
            completion(moved, failed)
        }
    }

    var totalSelected: Int {
        groups.reduce(0) { $0 + $1.selectedCount }
    }
}

// MARK: - Favorites Manager
class FavoritesManager: ObservableObject {
    static let shared = FavoritesManager()

    @Published var favorites: Set<String> = []
    @Published var favoriteImages: [SearchResult] = []
    @Published var isLoading = false

    private let favoritesFileURL: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let searchyDir = appSupport.appendingPathComponent("searchy")
        try? FileManager.default.createDirectory(at: searchyDir, withIntermediateDirectories: true)
        favoritesFileURL = searchyDir.appendingPathComponent("favorites.json")
        loadFavorites()
    }

    private func loadFavorites() {
        guard FileManager.default.fileExists(atPath: favoritesFileURL.path) else { return }
        do {
            let data = try Data(contentsOf: favoritesFileURL)
            let paths = try JSONDecoder().decode([String].self, from: data)
            favorites = Set(paths)
            refreshFavoriteImages()
        } catch {
            print("Failed to load favorites: \(error)")
        }
    }

    private func saveFavorites() {
        do {
            let data = try JSONEncoder().encode(Array(favorites))
            try data.write(to: favoritesFileURL)
        } catch {
            print("Failed to save favorites: \(error)")
        }
    }

    func toggleFavorite(_ path: String) {
        objectWillChange.send()  // Force UI update
        if favorites.contains(path) {
            favorites.remove(path)
        } else {
            favorites.insert(path)
        }
        saveFavorites()
        refreshFavoriteImages()
    }

    func isFavorite(_ path: String) -> Bool {
        favorites.contains(path)
    }

    func refreshFavoriteImages() {
        isLoading = true
        let currentFavorites = Array(favorites)

        Task.detached(priority: .userInitiated) {
            let images = currentFavorites.compactMap { path -> SearchResult? in
                guard FileManager.default.fileExists(atPath: path) else { return nil }
                let url = URL(fileURLWithPath: path)
                let attrs = try? FileManager.default.attributesOfItem(atPath: path)
                let size = attrs?[.size] as? Int ?? 0
                let date = attrs?[.modificationDate] as? Date
                let dateStr = date.map { ISO8601DateFormatter().string(from: $0) }
                return SearchResult(
                    path: path,
                    similarity: 1.0,
                    size: size,
                    date: dateStr,
                    type: url.pathExtension.lowercased()
                )
            }.sorted { ($0.date ?? "") > ($1.date ?? "") }

            await MainActor.run {
                self.favoriteImages = images
                self.isLoading = false
            }
        }
    }
}
