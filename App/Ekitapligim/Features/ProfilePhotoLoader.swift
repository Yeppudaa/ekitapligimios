import PhotosUI
import UIKit
import EkitapligimCore

@MainActor
enum ProfilePhotoLoader {
    static func jpeg(from item: PhotosPickerItem) async throws -> Data {
        guard let original = try await item.loadTransferable(type: Data.self) else {
            throw ProfilePhotoDecodingError()
        }
        return try jpeg(from: original)
    }

    static func jpeg(from original: Data) throws -> Data {
        guard original.count <= ProfileEditorModel.maxImageBytes else { throw ProfilePhotoSizeError() }
        // PhotosPicker can return PNG/HEIC. Send actual JPEG bytes with the existing
        // JPEG endpoint metadata instead of labelling the original bytes as image/jpeg.
        guard let image = UIImage(data: original), let jpeg = image.jpegData(compressionQuality: 0.9) else {
            throw ProfilePhotoDecodingError()
        }
        guard jpeg.count <= ProfileEditorModel.maxImageBytes else { throw ProfilePhotoSizeError() }
        return jpeg
    }
}

private struct ProfilePhotoDecodingError: Error {}
