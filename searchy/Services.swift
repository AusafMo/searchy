import SwiftUI
import AppKit
import AVFoundation

class ImageCache {
    static let shared = ImageCache()
    private var cache = NSCache<NSString, NSImage>()

    func image(for path: String) -> NSImage? {
        return cache.object(forKey: path as NSString)
    }

    func setImage(_ image: NSImage, for path: String) {
        cache.setObject(image, forKey: path as NSString)
    }

    func clear() {
        cache.removeAllObjects()
    }
}

// MARK: - Efficient Thumbnail Service
/// Uses CGImageSource to load only thumbnail data from images, not the full file.
/// This is much faster and uses less memory than loading full images and resizing.
class ThumbnailService {
    static let shared = ThumbnailService()

    private let cache = NSCache<NSString, NSImage>()
    private let queue = DispatchQueue(label: "com.searchy.thumbnails", qos: .userInitiated, attributes: .concurrent)

    private init() {
        // Allow up to 500 thumbnails in cache
        cache.countLimit = 500
    }

    /// Generate a cache key that includes size for different thumbnail sizes
    private func cacheKey(for path: String, size: Int) -> NSString {
        return "\(path)_\(size)" as NSString
    }

    /// Get cached thumbnail if available
    func cachedThumbnail(for path: String, size: Int) -> NSImage? {
        return cache.object(forKey: cacheKey(for: path, size: size))
    }

    /// Load thumbnail efficiently using CGImageSource
    /// This reads only the necessary bytes from the file, not the entire image
    func loadThumbnail(for path: String, maxSize: Int, completion: @escaping (NSImage?) -> Void) {
        let key = cacheKey(for: path, size: maxSize)

        // Check cache first
        if let cached = cache.object(forKey: key) {
            DispatchQueue.main.async {
                completion(cached)
            }
            return
        }

        // Load on background queue
        queue.async { [weak self] in
            guard let self = self else { return }

            let url = URL(fileURLWithPath: path)

            guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            // Options for thumbnail generation
            let options: [CFString: Any] = [
                kCGImageSourceThumbnailMaxPixelSize: maxSize,
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,  // Apply EXIF orientation
                kCGImageSourceShouldCacheImmediately: true
            ]

            guard let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
                // Fallback: try loading full image if thumbnail fails (for some formats)
                self.loadFallbackThumbnail(for: path, maxSize: maxSize, completion: completion)
                return
            }

            let thumbnail = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))

            // Cache it
            self.cache.setObject(thumbnail, forKey: key)

            DispatchQueue.main.async {
                completion(thumbnail)
            }
        }
    }

    /// Fallback for formats that don't support CGImageSource thumbnails well
    private func loadFallbackThumbnail(for path: String, maxSize: Int, completion: @escaping (NSImage?) -> Void) {
        guard let image = NSImage(contentsOfFile: path) else {
            DispatchQueue.main.async { completion(nil) }
            return
        }

        let size = image.size
        let scale = min(CGFloat(maxSize) / size.width, CGFloat(maxSize) / size.height, 1.0)
        let newSize = NSSize(width: size.width * scale, height: size.height * scale)

        let thumbnail = NSImage(size: newSize)
        thumbnail.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize),
                   from: NSRect(origin: .zero, size: size),
                   operation: .copy,
                   fraction: 1.0)
        thumbnail.unlockFocus()

        let key = cacheKey(for: path, size: maxSize)
        cache.setObject(thumbnail, forKey: key)

        DispatchQueue.main.async {
            completion(thumbnail)
        }
    }

    /// Synchronous thumbnail load (for when you need it immediately)
    func loadThumbnailSync(for path: String, maxSize: Int) -> NSImage? {
        let key = cacheKey(for: path, size: maxSize)

        if let cached = cache.object(forKey: key) {
            return cached
        }

        let url = URL(fileURLWithPath: path)

        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: maxSize,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
            return nil
        }

        let thumbnail = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        cache.setObject(thumbnail, forKey: key)

        return thumbnail
    }

    func clearCache() {
        cache.removeAllObjects()
    }
}

// MARK: - Video Thumbnail Service
/// Uses AVAssetImageGenerator for video thumbnails with memory + disk caching.

class VideoThumbnailService {
    static let shared = VideoThumbnailService()

    private let cache = NSCache<NSString, NSImage>()
    private let queue = DispatchQueue(label: "com.searchy.videothumbs", qos: .utility, attributes: .concurrent)
    private let diskCachePath: URL

    private init() {
        cache.countLimit = 200
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        diskCachePath = appSupport.appendingPathComponent("searchy/video_thumbs")
        try? FileManager.default.createDirectory(at: diskCachePath, withIntermediateDirectories: true)
    }

    private func cacheKey(for path: String, size: Int) -> NSString {
        "\(path)_\(size)" as NSString
    }

    private func diskFile(for path: String, size: Int) -> URL {
        let hash = path.data(using: .utf8)!.base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .prefix(80)
        return diskCachePath.appendingPathComponent("\(hash)_\(size).jpg")
    }

    func cachedThumbnail(for path: String, size: Int) -> NSImage? {
        cache.object(forKey: cacheKey(for: path, size: size))
    }

    func loadThumbnail(for path: String, maxSize: Int, completion: @escaping (NSImage?) -> Void) {
        let key = cacheKey(for: path, size: maxSize)

        // Memory cache
        if let cached = cache.object(forKey: key) {
            DispatchQueue.main.async { completion(cached) }
            return
        }

        queue.async { [weak self] in
            guard let self = self else { return }

            // Disk cache
            let diskURL = self.diskFile(for: path, size: maxSize)
            if let diskImage = NSImage(contentsOf: diskURL) {
                self.cache.setObject(diskImage, forKey: key)
                DispatchQueue.main.async { completion(diskImage) }
                return
            }

            // Generate from video
            let asset = AVAsset(url: URL(fileURLWithPath: path))
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: maxSize, height: maxSize)

            let time = CMTime(seconds: 1.0, preferredTimescale: 600)

            do {
                let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
                let thumbnail = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))

                self.cache.setObject(thumbnail, forKey: key)

                // Write to disk cache
                if let tiffData = thumbnail.tiffRepresentation,
                   let bitmap = NSBitmapImageRep(data: tiffData),
                   let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.7]) {
                    try? jpegData.write(to: diskURL)
                }

                DispatchQueue.main.async { completion(thumbnail) }
            } catch {
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }

    func videoDuration(for path: String) async -> Double? {
        let asset = AVAsset(url: URL(fileURLWithPath: path))
        do {
            let duration = try await asset.load(.duration)
            return duration.seconds.isNaN ? nil : duration.seconds
        } catch {
            return nil
        }
    }

    func clearCache() {
        cache.removeAllObjects()
        try? FileManager.default.removeItem(at: diskCachePath)
        try? FileManager.default.createDirectory(at: diskCachePath, withIntermediateDirectories: true)
    }
}
