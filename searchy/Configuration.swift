import SwiftUI
import Foundation

struct Constants {
    static var baseDirectory: String {
        SetupManager.shared.appSupportPath
    }
    static let defaultPort: Int = 7860
    static var pythonExecutablePath: String {
        SetupManager.shared.venvPythonPath
    }
    static var serverScriptPath: String {
        Bundle.main.path(forResource: "server", ofType: "py") ?? ""
    }
    static var embeddingScriptPath: String {
        Bundle.main.path(forResource: "generate_embeddings", ofType: "py") ?? ""
    }
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

    // Script paths should ALWAYS come from Bundle.main, never cached
    var pythonExecutablePath: String {
        Constants.pythonExecutablePath
    }

    var serverScriptPath: String {
        Constants.serverScriptPath
    }

    var embeddingScriptPath: String {
        Constants.embeddingScriptPath
    }

    private init() {
        // Load from UserDefaults with fallbacks to current constants
        self.baseDirectory = UserDefaults.standard.string(forKey: "baseDirectory") ?? Constants.baseDirectory
        self.defaultPort = UserDefaults.standard.integer(forKey: "defaultPort") != 0 ?
            UserDefaults.standard.integer(forKey: "defaultPort") : Constants.defaultPort

        // Clear any old cached paths (migration)
        UserDefaults.standard.removeObject(forKey: "pythonExecutablePath")
        UserDefaults.standard.removeObject(forKey: "serverScriptPath")
        UserDefaults.standard.removeObject(forKey: "embeddingScriptPath")
    }

    func resetToDefaults() {
        baseDirectory = Constants.baseDirectory
        defaultPort = Constants.defaultPort
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

// MARK: - Indexing Settings
class IndexingSettings: ObservableObject {
    static let shared = IndexingSettings()

    @Published var enableFastIndexing: Bool {
        didSet { UserDefaults.standard.set(enableFastIndexing, forKey: "enableFastIndexing") }
    }

    @Published var maxDimension: Int {
        didSet { UserDefaults.standard.set(maxDimension, forKey: "maxDimension") }
    }

    @Published var batchSize: Int {
        didSet { UserDefaults.standard.set(batchSize, forKey: "batchSize") }
    }

    private init() {
        self.enableFastIndexing = UserDefaults.standard.object(forKey: "enableFastIndexing") as? Bool ?? true
        self.maxDimension = UserDefaults.standard.integer(forKey: "maxDimension") != 0 ?
            UserDefaults.standard.integer(forKey: "maxDimension") : 384
        self.batchSize = UserDefaults.standard.integer(forKey: "batchSize") != 0 ?
            UserDefaults.standard.integer(forKey: "batchSize") : 64
    }
}

// MARK: - Model Settings (CLIP Model Configuration)
struct CLIPModelInfo: Identifiable {
    let id: String  // model_name from HuggingFace
    let name: String
    let description: String
    let embeddingDim: Int
    let sizeMB: Int
}

class ModelSettings: ObservableObject {
    static let shared = ModelSettings()

    @Published var currentModelName: String = ""
    @Published var currentModelDisplayName: String = ""
    @Published var currentDevice: String = ""
    @Published var currentEmbeddingDim: Int = 512
    @Published var availableModels: [CLIPModelInfo] = []
    @Published var isLoading: Bool = false
    @Published var isChangingModel: Bool = false
    @Published var errorMessage: String? = nil
    @Published var requiresReindex: Bool = false

    private let serverURL = "http://127.0.0.1:7860"

    private init() {
        // Pre-populate with known models (will be updated from server)
        availableModels = [
            CLIPModelInfo(id: "openai/clip-vit-base-patch32", name: "CLIP ViT-B/32", description: "Fast, good balance of speed and accuracy", embeddingDim: 512, sizeMB: 605),
            CLIPModelInfo(id: "openai/clip-vit-base-patch16", name: "CLIP ViT-B/16", description: "More accurate than B/32, slower", embeddingDim: 512, sizeMB: 605),
            CLIPModelInfo(id: "openai/clip-vit-large-patch14", name: "CLIP ViT-L/14", description: "High accuracy, requires more memory", embeddingDim: 768, sizeMB: 1710),
            CLIPModelInfo(id: "openai/clip-vit-large-patch14-336", name: "CLIP ViT-L/14@336px", description: "Highest accuracy, processes 336px images", embeddingDim: 768, sizeMB: 1710),
            CLIPModelInfo(id: "laion/CLIP-ViT-B-32-laion2B-s34B-b79K", name: "LAION CLIP ViT-B/32", description: "Trained on LAION-2B dataset", embeddingDim: 512, sizeMB: 605),
            CLIPModelInfo(id: "laion/CLIP-ViT-H-14-laion2B-s32B-b79K", name: "LAION CLIP ViT-H/14", description: "Large model, very accurate", embeddingDim: 1024, sizeMB: 3940)
        ]
    }

    func fetchCurrentModel() {
        isLoading = true
        errorMessage = nil

        guard let url = URL(string: "\(serverURL)/model") else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false

                if let error = error {
                    self?.errorMessage = "Failed to connect: \(error.localizedDescription)"
                    return
                }

                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    self?.errorMessage = "Invalid response"
                    return
                }

                if let status = json["status"] as? String, status == "not_loaded" {
                    self?.currentModelName = ""
                    self?.currentModelDisplayName = "No model loaded"
                    return
                }

                self?.currentModelName = json["model_name"] as? String ?? ""
                self?.currentDevice = json["device"] as? String ?? "unknown"
                self?.currentEmbeddingDim = json["embedding_dim"] as? Int ?? 512
                self?.currentModelDisplayName = json["name"] as? String ?? self?.currentModelName ?? ""
            }
        }.resume()
    }

    func changeModel(to modelId: String, completion: @escaping (Bool, String?) -> Void) {
        isChangingModel = true
        errorMessage = nil
        requiresReindex = false

        guard let url = URL(string: "\(serverURL)/model") else {
            completion(false, "Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["model_name": modelId]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isChangingModel = false

                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    completion(false, error.localizedDescription)
                    return
                }

                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    self?.errorMessage = "Invalid response"
                    completion(false, "Invalid response")
                    return
                }

                let status = json["status"] as? String ?? "error"

                if status == "success" {
                    self?.currentModelName = json["new_model"] as? String ?? modelId
                    self?.currentEmbeddingDim = json["new_embedding_dim"] as? Int ?? 512
                    self?.requiresReindex = json["reindex_required"] as? Bool ?? false

                    // Update display name from our known models
                    if let model = self?.availableModels.first(where: { $0.id == modelId }) {
                        self?.currentModelDisplayName = model.name
                    } else {
                        self?.currentModelDisplayName = modelId
                    }

                    completion(true, self?.requiresReindex == true ? "Re-indexing required due to different embedding dimensions" : nil)
                } else {
                    let message = json["message"] as? String ?? "Failed to change model"
                    self?.errorMessage = message
                    completion(false, message)
                }
            }
        }.resume()
    }
}
