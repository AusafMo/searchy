import SwiftUI
import AppKit

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
