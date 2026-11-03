import Foundation
import ImageIO
import UniformTypeIdentifiers
import EkitapligimCore

enum AgendaPhotoProcessor {
    static func prepare(_ original: Data) async throws -> Data {
        let task = Task.detached(priority: .userInitiated) { try jpeg(original) }
        return try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel() }
    }

    /// ImageIO downsamples without decoding the full resolution photo. The new JPEG contains
    /// pixels only: the source EXIF/GPS/filename metadata is not copied.
    static func jpeg(_ original: Data) throws -> Data {
        guard !original.isEmpty, original.count <= 40 * 1_024 * 1_024,
              let source = CGImageSourceCreateWithData(original as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 2_048,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { throw AgendaMediaError.invalidImage }
        try Task.checkCancellation()
        let result = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(result, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw AgendaMediaError.invalidImage
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.86] as CFDictionary)
        guard CGImageDestinationFinalize(destination), result.length <= AgendaMediaPolicy.maximumUploadBytes else {
            throw AgendaMediaError.invalidImage
        }
        return result as Data
    }
}
