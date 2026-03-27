import SwiftUI
import Foundation

class FaceManager: ObservableObject {
    static let shared = FaceManager()

    @Published var people: [Person] = []
    @Published var isScanning = false
    @Published var scanProgress: String = ""
    @Published var scanPercentage: Double = 0
    @Published var totalFacesDetected = 0
    @Published var hasScannedBefore = false
    @Published var newImagesCount = 0
    @Published var pinnedClusterIds: Set<String> = []
    @Published var hiddenClusterIds: Set<String> = []
    @Published var showHidden: Bool = false
    @Published var isReclustering = false
    @Published var orphanedFacesCount = 0

    /// Returns true if any person has at least one verified face
    var hasVerifiedFaces: Bool {
        // If unverifiedCount < faceCount, then some faces are verified
        people.contains { person in
            person.unverifiedCount < person.faceCount
        }
    }

    let baseURL = "http://localhost:7860"
    let dataDir: String = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("searchy").path
    }()
    private var statusPollTimer: Timer?

    private init() {
        // Load initial state from Python backend
        Task {
            await loadPinnedClusters()
            await loadHiddenClusters()
            await loadGroups()
            await loadClustersFromAPI()
            await checkForNewImages()
        }
    }

    // MARK: - API Calls

    /// Check for new indexed images that haven't been scanned
    func checkForNewImages() async {
        guard let url = URL(string: "\(baseURL)/face-new-count?data_dir=\(dataDir.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? dataDir)") else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(FaceNewCountResponse.self, from: data)
            await MainActor.run {
                self.newImagesCount = response.new_count
                self.hasScannedBefore = response.already_scanned > 0
            }
        } catch {
            print("Failed to check new images: \(error)")
        }
    }

    /// Load face clusters from Python backend
    func loadClustersFromAPI() async {
        guard let url = URL(string: "\(baseURL)/face-clusters?data_dir=\(dataDir.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? dataDir)") else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(FaceClustersResponse.self, from: data)
            await MainActor.run {
                self.people = response.clusters.map { Person(from: $0) }
                self.totalFacesDetected = response.total_faces
                self.hasScannedBefore = response.total_faces > 0
            }
        } catch {
            print("Failed to load clusters: \(error)")
        }
    }

    /// Start face scanning via Python backend
    func scanForFaces(fullRescan: Bool = false) {
        guard !isScanning else { return }

        Task {
            await MainActor.run {
                self.isScanning = true
                self.scanProgress = "Starting face scan..."
                self.scanPercentage = 0
            }

            // Call the Python API to start scanning
            guard let url = URL(string: "\(baseURL)/face-scan") else {
                await MainActor.run {
                    self.isScanning = false
                    self.scanProgress = "Error: Invalid URL"
                }
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")

            let body: [String: Any] = [
                "data_dir": dataDir,
                "incremental": !fullRescan
            ]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)

            do {
                let (data, _) = try await URLSession.shared.data(for: request)
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let status = json["status"] as? String {
                    if status == "started" || status == "already_scanning" {
                        // Start polling for status
                        await startStatusPolling()
                    } else if status == "error" {
                        let message = json["message"] as? String ?? "Unknown error"
                        await MainActor.run {
                            self.isScanning = false
                            self.scanProgress = "Error: \(message)"
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.isScanning = false
                    self.scanProgress = "Error: \(error.localizedDescription)"
                }
            }
        }
    }

    /// Start polling for scan status
    private func startStatusPolling() async {
        await MainActor.run {
            self.statusPollTimer?.invalidate()
            self.statusPollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                Task {
                    await self?.pollScanStatus()
                }
            }
        }
    }

    /// Poll scan status from Python backend
    private func pollScanStatus() async {
        guard let url = URL(string: "\(baseURL)/face-scan-status?data_dir=\(dataDir.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? dataDir)") else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(FaceScanStatusResponse.self, from: data)

            await MainActor.run {
                self.scanProgress = response.status
                self.scanPercentage = response.progress
                self.totalFacesDetected = response.total_faces

                if !response.is_scanning {
                    // Scan complete - stop polling and load results
                    self.statusPollTimer?.invalidate()
                    self.statusPollTimer = nil
                    self.isScanning = false
                    self.newImagesCount = 0

                    // Load updated clusters
                    Task {
                        await self.loadClustersFromAPI()
                    }
                }
            }
        } catch {
            print("Failed to poll status: \(error)")
        }
    }

    /// Clear all face data via Python backend
    func clearAllFaces() {
        Task {
            guard let url = URL(string: "\(baseURL)/face-clear?data_dir=\(dataDir.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? dataDir)") else { return }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"

            do {
                let _ = try await URLSession.shared.data(for: request)
                await MainActor.run {
                    self.people = []
                    self.totalFacesDetected = 0
                    self.hasScannedBefore = false
                    self.newImagesCount = 0
                    self.scanProgress = "All face data cleared"
                }
                // Check for new images after clearing
                await checkForNewImages()
            } catch {
                print("Failed to clear faces: \(error)")
            }
        }
    }

    /// Re-cluster faces using verified faces as anchors
    /// This respects negative constraints from rejections and tries to place orphaned faces
    func reclusterWithConstraints() {
        guard !isReclustering && !isScanning else { return }

        Task {
            await MainActor.run {
                self.isReclustering = true
                self.scanProgress = "Re-clustering faces..."
            }

            var components = URLComponents(string: "\(baseURL)/face-recluster")
            components?.queryItems = [
                URLQueryItem(name: "data_dir", value: dataDir),
                URLQueryItem(name: "similarity_threshold", value: "0.60")
            ]

            guard let url = components?.url else {
                await MainActor.run {
                    self.isReclustering = false
                    self.scanProgress = "Error: Invalid URL"
                }
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"

            do {
                let (data, _) = try await URLSession.shared.data(for: request)
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let error = json["error"] as? String {
                        await MainActor.run {
                            self.isReclustering = false
                            self.scanProgress = error
                        }
                    } else {
                        let facesMoved = json["faces_moved"] as? Int ?? 0
                        let orphansPlaced = json["orphans_placed"] as? Int ?? 0
                        let orphansRemaining = json["orphans_remaining"] as? Int ?? 0

                        await MainActor.run {
                            self.isReclustering = false
                            self.orphanedFacesCount = orphansRemaining
                            self.scanProgress = "Re-clustered: \(facesMoved) moved, \(orphansPlaced) orphans placed"
                        }

                        // Reload clusters to reflect changes
                        await loadClustersFromAPI()
                    }
                }
            } catch {
                await MainActor.run {
                    self.isReclustering = false
                    self.scanProgress = "Error: \(error.localizedDescription)"
                }
            }
        }
    }

    /// Verify or reject a face in a cluster
    func verifyFace(faceId: String, clusterId: String, isCorrect: Bool) async {
        var components = URLComponents(string: "\(baseURL)/face-verify")
        components?.queryItems = [
            URLQueryItem(name: "face_id", value: faceId),
            URLQueryItem(name: "cluster_id", value: clusterId),
            URLQueryItem(name: "is_correct", value: isCorrect ? "true" : "false"),
            URLQueryItem(name: "data_dir", value: dataDir)
        ]

        guard let url = components?.url else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let status = json["status"] as? String ?? ""
                print("Face verification result: \(status)")

                // Reload clusters to reflect the change
                await loadClustersFromAPI()
            }
        } catch {
            print("Failed to verify face: \(error)")
        }
    }

    /// Batch verify or reject multiple faces
    func verifyFaces(faceIds: [String], clusterId: String, isCorrect: Bool) async {
        // Process faces sequentially to avoid overwhelming the server
        for faceId in faceIds {
            var components = URLComponents(string: "\(baseURL)/face-verify")
            components?.queryItems = [
                URLQueryItem(name: "face_id", value: faceId),
                URLQueryItem(name: "cluster_id", value: clusterId),
                URLQueryItem(name: "is_correct", value: isCorrect ? "true" : "false"),
                URLQueryItem(name: "data_dir", value: dataDir)
            ]

            guard let url = components?.url else { continue }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"

            do {
                let _ = try await URLSession.shared.data(for: request)
            } catch {
                print("Failed to verify face \(faceId): \(error)")
            }
        }

        // Reload clusters once after all verifications
        await loadClustersFromAPI()
    }

    /// Get images for a specific person
    func getImagesForPerson(_ person: Person) -> [SearchResult] {
        let uniquePaths = Set(person.faces.map { $0.imagePath })
        return uniquePaths.compactMap { path -> SearchResult? in
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
    }

    /// Refresh new images count - call from UI
    func refreshNewImagesCount() {
        Task {
            await checkForNewImages()
        }
    }

    /// Rename a person with a custom name
    func renamePerson(_ person: Person, to newName: String) async -> Bool {
        // Build URL with query parameters
        var components = URLComponents(string: "\(baseURL)/face-rename")
        components?.queryItems = [
            URLQueryItem(name: "cluster_id", value: person.id),
            URLQueryItem(name: "name", value: newName),
            URLQueryItem(name: "data_dir", value: dataDir)
        ]
        guard let url = components?.url else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("Rename response: \(json)")
                if let status = json["status"] as? String, status == "success" {
                    // Update local state - replace entire element to trigger SwiftUI update
                    await MainActor.run {
                        self.objectWillChange.send()
                        if let index = self.people.firstIndex(where: { $0.id == person.id }) {
                            var updatedPerson = self.people[index]
                            updatedPerson.name = newName
                            self.people[index] = updatedPerson
                            print("Updated person at index \(index) to name: \(newName)")
                        } else {
                            print("Person not found in people array: \(person.id)")
                        }
                    }
                    return true
                } else if let error = json["error"] as? String, error.contains("not found") {
                    // Cluster IDs may have changed - reload clusters
                    print("Cluster not found, reloading clusters from API...")
                    await loadClustersFromAPI()
                } else {
                    print("Rename failed - status not success: \(json)")
                }
            }
        } catch {
            print("Failed to rename person: \(error)")
        }
        return false
    }

    // MARK: - Pin/Favorite Methods

    /// Load pinned clusters from backend
    func loadPinnedClusters() async {
        guard let url = URL(string: "\(baseURL)/face-pinned?data_dir=\(dataDir.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? dataDir)") else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let pinned = json["pinned"] as? [String] {
                await MainActor.run {
                    self.pinnedClusterIds = Set(pinned)
                }
            }
        } catch {
            print("Failed to load pinned clusters: \(error)")
        }
    }

    /// Check if a person is pinned
    func isPinned(_ person: Person) -> Bool {
        return pinnedClusterIds.contains(person.id)
    }

    /// Toggle pin status for a person
    func togglePin(_ person: Person) async {
        let isPinned = pinnedClusterIds.contains(person.id)
        let endpoint = isPinned ? "face-unpin" : "face-pin"

        var components = URLComponents(string: "\(baseURL)/\(endpoint)")
        components?.queryItems = [
            URLQueryItem(name: "cluster_id", value: person.id),
            URLQueryItem(name: "data_dir", value: dataDir)
        ]
        guard let url = components?.url else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let status = json["status"] as? String, status == "success",
               let pinned = json["pinned"] as? [String] {
                await MainActor.run {
                    self.pinnedClusterIds = Set(pinned)
                }
            }
        } catch {
            print("Failed to toggle pin: \(error)")
        }
    }

    // MARK: - Hide/Archive Methods

    /// Load hidden clusters from backend
    func loadHiddenClusters() async {
        guard let url = URL(string: "\(baseURL)/face-hidden?data_dir=\(dataDir.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? dataDir)") else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let hidden = json["hidden"] as? [String] {
                await MainActor.run {
                    self.hiddenClusterIds = Set(hidden)
                }
            }
        } catch {
            print("Failed to load hidden clusters: \(error)")
        }
    }

    /// Check if a person is hidden
    func isHidden(_ person: Person) -> Bool {
        return hiddenClusterIds.contains(person.id)
    }

    /// Toggle hide status for a person
    func toggleHide(_ person: Person) async {
        let isHidden = hiddenClusterIds.contains(person.id)
        let endpoint = isHidden ? "face-unhide" : "face-hide"

        var components = URLComponents(string: "\(baseURL)/\(endpoint)")
        components?.queryItems = [
            URLQueryItem(name: "cluster_id", value: person.id),
            URLQueryItem(name: "data_dir", value: dataDir)
        ]
        guard let url = components?.url else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let status = json["status"] as? String, status == "success",
               let hidden = json["hidden"] as? [String] {
                await MainActor.run {
                    self.hiddenClusterIds = Set(hidden)
                }
            }
        } catch {
            print("Failed to toggle hide: \(error)")
        }
    }

    /// Get visible people (filtered by hidden status, sorted with pinned first)
    var sortedPeople: [Person] {
        // Filter by hidden status
        let visible = showHidden ? people : people.filter { !hiddenClusterIds.contains($0.id) }
        // Sort with pinned first
        let pinned = visible.filter { pinnedClusterIds.contains($0.id) }
        let unpinned = visible.filter { !pinnedClusterIds.contains($0.id) }
        return pinned + unpinned
    }

    /// Count of hidden people
    var hiddenCount: Int {
        return hiddenClusterIds.count
    }

    /// Total count of unverified faces across all people
    var totalUnverifiedCount: Int {
        return people.reduce(0) { $0 + $1.unverifiedCount }
    }

    // MARK: - Groups/Tags

    @Published var availableGroups: [String] = []
    @Published var groupAssignments: [String: [String]] = [:] // cluster_id -> [group names]
    @Published var selectedGroupFilter: String? = nil

    func loadGroups() async {
        guard let url = URL(string: "\(baseURL)/face-groups?data_dir=\(dataDir.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? dataDir)") else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            struct GroupsResponse: Codable {
                let groups: [String]
                let assignments: [String: [String]]
            }
            let response = try JSONDecoder().decode(GroupsResponse.self, from: data)
            await MainActor.run {
                self.availableGroups = response.groups
                self.groupAssignments = response.assignments
            }
        } catch {
            print("Error loading groups: \(error)")
        }
    }

    func createGroup(_ name: String) async {
        var components = URLComponents(string: "\(baseURL)/face-group-create")
        components?.queryItems = [
            URLQueryItem(name: "name", value: name),
            URLQueryItem(name: "data_dir", value: dataDir)
        ]
        guard let url = components?.url else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        do {
            let (_, _) = try await URLSession.shared.data(for: request)
            await loadGroups()
        } catch {
            print("Error creating group: \(error)")
        }
    }

    func deleteGroup(_ name: String) async {
        var components = URLComponents(string: "\(baseURL)/face-group-delete")
        components?.queryItems = [
            URLQueryItem(name: "name", value: name),
            URLQueryItem(name: "data_dir", value: dataDir)
        ]
        guard let url = components?.url else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        do {
            let (_, _) = try await URLSession.shared.data(for: request)
            await loadGroups()
        } catch {
            print("Error deleting group: \(error)")
        }
    }

    func assignGroup(_ clusterId: String, group: String) async {
        var components = URLComponents(string: "\(baseURL)/face-group-assign")
        components?.queryItems = [
            URLQueryItem(name: "cluster_id", value: clusterId),
            URLQueryItem(name: "group", value: group),
            URLQueryItem(name: "data_dir", value: dataDir)
        ]
        guard let url = components?.url else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        do {
            let (_, _) = try await URLSession.shared.data(for: request)
            await loadGroups()
        } catch {
            print("Error assigning group: \(error)")
        }
    }

    func removeGroup(_ clusterId: String, group: String) async {
        var components = URLComponents(string: "\(baseURL)/face-group-remove")
        components?.queryItems = [
            URLQueryItem(name: "cluster_id", value: clusterId),
            URLQueryItem(name: "group", value: group),
            URLQueryItem(name: "data_dir", value: dataDir)
        ]
        guard let url = components?.url else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        do {
            let (_, _) = try await URLSession.shared.data(for: request)
            await loadGroups()
        } catch {
            print("Error removing group: \(error)")
        }
    }

    func getGroupsForCluster(_ clusterId: String) -> [String] {
        return groupAssignments[clusterId] ?? []
    }

    // MARK: - Merge Methods

    /// Merge source person into target person
    func mergePeople(source: Person, into target: Person) async -> Bool {
        var components = URLComponents(string: "\(baseURL)/face-merge")
        components?.queryItems = [
            URLQueryItem(name: "source_cluster_id", value: source.id),
            URLQueryItem(name: "target_cluster_id", value: target.id),
            URLQueryItem(name: "data_dir", value: dataDir)
        ]
        guard let url = components?.url else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let status = json["status"] as? String, status == "success" {
                // Reload clusters to get updated state
                await loadClustersFromAPI()
                await loadPinnedClusters()
                await loadHiddenClusters()
                return true
            }
        } catch {
            print("Failed to merge people: \(error)")
        }
        return false
    }
}
