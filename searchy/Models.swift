import SwiftUI
import Foundation

// MARK: - Search Models

struct SearchResult: Codable, Identifiable {
    var id = UUID()
    let path: String
    let similarity: Float
    let size: Int?
    let date: String?
    let type: String?
    let isPending: Bool  // True if detected but not yet indexed (not searchable yet)

    enum CodingKeys: String, CodingKey {
        case path
        case similarity
        case size
        case date
        case type
        case isPending = "is_pending"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        path = try container.decode(String.self, forKey: .path)
        similarity = try container.decode(Float.self, forKey: .similarity)
        size = try container.decodeIfPresent(Int.self, forKey: .size)
        date = try container.decodeIfPresent(String.self, forKey: .date)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        isPending = try container.decodeIfPresent(Bool.self, forKey: .isPending) ?? false
    }

    // Memberwise initializer for direct construction
    init(path: String, similarity: Float, size: Int? = nil, date: String? = nil, type: String? = nil, isPending: Bool = false) {
        self.path = path
        self.similarity = similarity
        self.size = size
        self.date = date
        self.type = type
        self.isPending = isPending
    }

    var formattedSize: String {
        guard let size = size else { return "Unknown" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }

    var fileExtension: String {
        type ?? URL(fileURLWithPath: path).pathExtension.lowercased()
    }
}

struct SearchResponse: Codable {
    let results: [SearchResult]
    let stats: SearchStats
    let error: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.error = try container.decodeIfPresent(String.self, forKey: .error)
        // If there's an error, set empty results and default stats
        if self.error != nil {
            self.results = []
            self.stats = SearchStats(total_time: "0s", images_searched: 0, images_per_second: "0")
        } else {
            self.results = try container.decode([SearchResult].self, forKey: .results)
            self.stats = try container.decode(SearchStats.self, forKey: .stats)
        }
    }
}

struct SearchStats: Codable {
    let total_time: String
    let images_searched: Int
    let images_per_second: String

    init(total_time: String, images_searched: Int, images_per_second: String) {
        self.total_time = total_time
        self.images_searched = images_searched
        self.images_per_second = images_per_second
    }
}

// MARK: - Indexing Progress Models
struct IndexingProgressData: Codable {
    let type: String
    let batch: Int?
    let total_batches: Int?
    let images_processed: Int?
    let total_images: Int?
    let elapsed: Double?
    let new_images: Int?
    let total_time: Double?
    let images_per_sec: Double?
}

struct IndexingReport {
    let totalImages: Int
    let newImages: Int
    let totalTime: Double
    let imagesPerSec: Double
}

struct IndexStats {
    let totalImages: Int
    let fileSize: String
    let lastModified: Date?
}

// MARK: - App Tabs
enum AppTab: String, CaseIterable {
    case faces = "Faces"
    case search = "Searchy"
    case volumes = "Volumes"
    case duplicates = "Duplicates"
    case favorites = "Favorites"
    case setup = "Setup"

    var icon: String {
        switch self {
        case .faces: return "person.2"
        case .search: return "magnifyingglass"
        case .volumes: return "externaldrive"
        case .duplicates: return "doc.on.doc"
        case .favorites: return "heart.fill"
        case .setup: return "slider.horizontal.3"
        }
    }
}

// MARK: - Duplicates Models
struct DuplicateImage: Identifiable, Codable {
    var id: String { path }
    let path: String
    let size: Int
    let date: String?
    let type: String
    let similarity: Float
    var isSelected: Bool = false

    enum CodingKeys: String, CodingKey {
        case path, size, date, type, similarity
    }

    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
}

struct DuplicateGroup: Identifiable, Codable {
    let id: Int
    var images: [DuplicateImage]

    var selectedCount: Int {
        images.filter { $0.isSelected }.count
    }
}

struct DuplicatesResponse: Codable {
    let groups: [DuplicateGroup]
    let total_duplicates: Int
    let total_groups: Int
}

// MARK: - Face Detection & Clustering

// MARK: - Face Data Models (matching Python API)

struct FaceData: Codable, Identifiable {
    let face_id: String
    let image_path: String
    let bbox: FaceBBox
    let confidence: Double
    let thumbnail_path: String?
    let verified: Bool?
    let added_date: String?

    var id: String { face_id }
    var imagePath: String { image_path }
    var thumbnailPath: String? { thumbnail_path }
    var isVerified: Bool { verified ?? false }

    struct FaceBBox: Codable {
        let x: Int
        let y: Int
        let w: Int
        let h: Int
    }
}

struct FaceCluster: Codable, Identifiable {
    let cluster_id: String
    let name: String
    let face_count: Int
    let unverified_count: Int?
    let thumbnail_path: String?
    let faces: [FaceData]

    var id: String { cluster_id }
    var faceCount: Int { face_count }
    var unverifiedCount: Int { unverified_count ?? face_count }
    var thumbnailPath: String? { thumbnail_path }
}

struct FaceClustersResponse: Codable {
    let clusters: [FaceCluster]
    let total_clusters: Int
    let total_faces: Int
}

struct FaceScanStatusResponse: Codable {
    let is_scanning: Bool
    let progress: Double
    let status: String
    let total_to_scan: Int
    let scanned_count: Int
    let total_faces: Int
    let total_clusters: Int
}

struct FaceNewCountResponse: Codable {
    let new_count: Int
    let total_indexed: Int
    let already_scanned: Int
}

// Keep legacy types for compatibility with existing views
struct DetectedFace: Codable, Identifiable {
    var id = UUID()
    let imagePath: String
    let boundingBox: CGRect
    var embedding: [Float]?
    var personId: String?
    var faceId: String?  // The face_id from Python API (used for verification)
    var verified: Bool = false

    enum CodingKeys: String, CodingKey {
        case id, imagePath, boundingBox, embedding, personId, faceId, verified
    }

    init(id: UUID = UUID(), imagePath: String, boundingBox: CGRect, embedding: [Float]? = nil, personId: String? = nil, faceId: String? = nil, verified: Bool = false) {
        self.id = id
        self.imagePath = imagePath
        self.boundingBox = boundingBox
        self.embedding = embedding
        self.personId = personId
        self.faceId = faceId
        self.verified = verified
    }

    // Create from FaceData (Python API response)
    init(from faceData: FaceData) {
        self.id = UUID()
        self.imagePath = faceData.image_path
        self.boundingBox = CGRect(
            x: CGFloat(faceData.bbox.x),
            y: CGFloat(faceData.bbox.y),
            width: CGFloat(faceData.bbox.w),
            height: CGFloat(faceData.bbox.h)
        )
        self.embedding = nil
        self.personId = nil
        self.faceId = faceData.face_id
        self.verified = faceData.isVerified
    }
}

struct Person: Identifiable, Equatable {
    let id: String
    var name: String
    var faces: [DetectedFace]
    var thumbnailPath: String?
    var unverifiedCount: Int

    var faceCount: Int { faces.count }

    // Create from FaceCluster (Python API response)
    init(from cluster: FaceCluster) {
        self.id = cluster.cluster_id
        self.name = cluster.name
        self.faces = cluster.faces.map { DetectedFace(from: $0) }
        self.thumbnailPath = cluster.thumbnail_path
        self.unverifiedCount = cluster.unverifiedCount
    }

    init(id: String, name: String, faces: [DetectedFace], thumbnailPath: String? = nil, unverifiedCount: Int = 0) {
        self.id = id
        self.name = name
        self.faces = faces
        self.thumbnailPath = thumbnailPath
        self.unverifiedCount = unverifiedCount
    }

    static func == (lhs: Person, rhs: Person) -> Bool {
        lhs.id == rhs.id
    }
}
