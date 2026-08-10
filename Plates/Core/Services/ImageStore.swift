import UIKit

/// File-backed storage for receipt and food photos. SwiftData stores only the
/// returned file names, keeping the database small.
enum ImageStore {
    private static var baseDir: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Images", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Saves a JPEG (downscaled to `maxDimension`) and returns its file name.
    static func save(_ image: UIImage, maxDimension: CGFloat = 2000) -> String? {
        let resized = image.plResized(maxDimension: maxDimension)
        guard let data = resized.jpegData(compressionQuality: 0.82) else { return nil }
        let name = UUID().uuidString + ".jpg"
        do {
            try data.write(to: baseDir.appendingPathComponent(name))
            return name
        } catch {
            return nil
        }
    }

    static func load(_ name: String) -> UIImage? {
        UIImage(contentsOfFile: baseDir.appendingPathComponent(name).path)
    }

    static func url(_ name: String) -> URL {
        baseDir.appendingPathComponent(name)
    }

    static func delete(_ name: String) {
        try? FileManager.default.removeItem(at: baseDir.appendingPathComponent(name))
    }
}

extension UIImage {
    func plResized(maxDimension: CGFloat) -> UIImage {
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension else { return self }
        let scale = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        return UIGraphicsImageRenderer(size: newSize).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
