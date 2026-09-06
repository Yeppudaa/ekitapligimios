import Foundation
import Combine
@preconcurrency import PDFKit
@preconcurrency import UIKit

protocol PDFThumbnailProviding: Sendable {
    func pageCount() async throws -> Int
    func thumbnail(at index: Int) async throws -> UIImage?
    func cancel() async
}

/// Owns a separate PDFDocument. Synchronous PDFKit work is serialized on this actor,
/// never on the main actor and never concurrently with the reader's PDFDocument.
actor PDFThumbnailService: PDFThumbnailProviding {
    private let url: URL
    private let byteLimit: Int
    private let makeDocument: @Sendable (URL) -> PDFDocument?
    private var document: PDFDocument?
    private var didOpen = false
    private var isCancelled = false
    private var images: [Int: UIImage] = [:]
    private var accessOrder: [Int] = []
    private(set) var cachedBytes = 0

    init(
        url: URL,
        byteLimit: Int = 20 * 1024 * 1024,
        makeDocument: @escaping @Sendable (URL) -> PDFDocument? = { PDFDocument(url: $0) }
    ) {
        self.url = url
        self.byteLimit = max(0, byteLimit)
        self.makeDocument = makeDocument
    }

    func pageCount() throws -> Int {
        try checkCancellation()
        return try openDocument().pageCount
    }

    func thumbnail(at index: Int) throws -> UIImage? {
        try checkCancellation()
        if let cached = images[index] {
            touch(index)
            return cached
        }
        let document = try openDocument()
        guard index >= 0, index < document.pageCount, let page = document.page(at: index) else { return nil }
        let image = autoreleasepool {
            page.thumbnail(of: CGSize(width: 160, height: 220), for: .cropBox)
        }
        try checkCancellation()
        let cost = imageCost(image)
        if cost > 0, cost <= byteLimit {
            while cachedBytes + cost > byteLimit, let oldest = accessOrder.first {
                accessOrder.removeFirst()
                if let evicted = images.removeValue(forKey: oldest) { cachedBytes -= imageCost(evicted) }
            }
            images[index] = image
            cachedBytes += cost
            touch(index)
        }
        return image
    }

    func cancel() {
        isCancelled = true
        images.removeAll()
        accessOrder.removeAll()
        cachedBytes = 0
        document = nil
    }

    private func openDocument() throws -> PDFDocument {
        if !didOpen {
            didOpen = true
            document = makeDocument(url)
        }
        guard let document else { throw BookFileTransferError.invalidFile }
        return document
    }

    private func checkCancellation() throws {
        try Task.checkCancellation()
        if isCancelled { throw CancellationError() }
    }

    private func touch(_ index: Int) {
        accessOrder.removeAll { $0 == index }
        accessOrder.append(index)
    }

    private func imageCost(_ image: UIImage) -> Int {
        guard let cgImage = image.cgImage else { return 0 }
        return cgImage.bytesPerRow * cgImage.height
    }
}

@MainActor
final class PDFPagePickerModel: ObservableObject {
    @Published private(set) var pageCount: Int?
    @Published private(set) var failed = false
    @Published private(set) var service: (any PDFThumbnailProviding)?
    private let makeService: (URL) -> any PDFThumbnailProviding
    private var generation = UUID()

    init(makeService: @escaping (URL) -> any PDFThumbnailProviding = { PDFThumbnailService(url: $0) }) {
        self.makeService = makeService
    }

    func load(url: URL) async {
        cancel()
        let generation = self.generation
        let service = makeService(url)
        self.service = service
        pageCount = nil
        failed = false
        await withTaskCancellationHandler {
            do {
                let count = try await service.pageCount()
                guard !Task.isCancelled, self.generation == generation else { return }
                pageCount = count
            } catch {
                guard !Task.isCancelled, self.generation == generation else { return }
                failed = true
            }
        } onCancel: {
            Task { await service.cancel() }
        }
    }

    func cancel() {
        generation = UUID()
        if let service { Task { await service.cancel() } }
        service = nil
    }
}
