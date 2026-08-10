import Observation
import UIKit

/// The collector's identity: a display name and an optional profile photo.
/// Both persist in `UserDefaults`; the photo file itself lives in `ImageStore`
/// (center-cropped to a square, at most 800 px on a side).
@Observable @MainActor
final class ProfileStore {
    static let shared = ProfileStore()

    private static let nameKey = "profileName"
    private static let photoPathKey = "profilePhotoPath"
    private static let photoMaxDimension: CGFloat = 800

    /// The collector's chosen name — empty when unset. UI falls back to
    /// "Your Passport".
    private(set) var displayName: String

    /// `ImageStore` file name of the profile photo, if one is set.
    private(set) var photoPath: String?

    @ObservationIgnored private var cachedPhoto: UIImage?
    @ObservationIgnored private var cachedPhotoPath: String?

    private init() {
        let defaults = UserDefaults.standard
        displayName = defaults.string(forKey: Self.nameKey) ?? ""
        photoPath = defaults.string(forKey: Self.photoPathKey)
    }

    /// The profile photo, loaded from `ImageStore` once and cached in memory.
    var photo: UIImage? {
        guard let photoPath else { return nil }
        if photoPath == cachedPhotoPath, let cachedPhoto {
            return cachedPhoto
        }
        let loaded = ImageStore.load(photoPath)
        cachedPhoto = loaded
        cachedPhotoPath = photoPath
        return loaded
    }

    /// Replaces (or clears, when `image` is nil) the profile photo. The image
    /// is center-cropped to a square capped at 800 px, saved via `ImageStore`,
    /// and the previous photo file is deleted from disk.
    func setPhoto(_ image: UIImage?) {
        if let oldPath = photoPath {
            ImageStore.delete(oldPath)
        }
        cachedPhoto = nil
        cachedPhotoPath = nil

        let newPath = image
            .map { Self.squareCropped($0, maxDimension: Self.photoMaxDimension) }
            .flatMap { ImageStore.save($0, maxDimension: Self.photoMaxDimension) }

        photoPath = newPath
        if let newPath {
            UserDefaults.standard.set(newPath, forKey: Self.photoPathKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.photoPathKey)
        }
    }

    /// Trims and persists the display name.
    func setName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        displayName = trimmed
        UserDefaults.standard.set(trimmed, forKey: Self.nameKey)
    }

    // MARK: - Cropping

    /// Center-crops to a square and downscales so the side is at most
    /// `maxDimension` pixels, rendering at 1× so points equal pixels.
    private static func squareCropped(_ image: UIImage,
                                      maxDimension: CGFloat) -> UIImage {
        let pixelWidth = image.size.width * image.scale
        let pixelHeight = image.size.height * image.scale
        let pixelSide = min(pixelWidth, pixelHeight)
        guard pixelSide > 0 else { return image }

        let target = min(pixelSide, maxDimension)
        let factor = target / pixelSide

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: target,
                                                            height: target),
                                               format: format)
        return renderer.image { _ in
            let drawSize = CGSize(width: pixelWidth * factor,
                                  height: pixelHeight * factor)
            let origin = CGPoint(x: (target - drawSize.width) / 2,
                                 y: (target - drawSize.height) / 2)
            image.draw(in: CGRect(origin: origin, size: drawSize))
        }
    }
}
