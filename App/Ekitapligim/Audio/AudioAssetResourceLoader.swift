import Foundation
import AVFoundation
import UniformTypeIdentifiers
import EkitapligimCore

/// AVFoundation sees only an opaque local scheme. Authenticated HTTPS byte ranges are fetched here,
/// without redirect following, disk caching, static bearer headers or unauthenticated MP3 fallbacks.
@MainActor
final class AudioAssetResourceLoader: NSObject, AVAssetResourceLoaderDelegate {
    private let repository: AudioRepository
    private let bookID: Int
    private let chapter: AudioChapterDTO
    private let account: String
    private var jobs: [ObjectIdentifier: Task<Void, Never>] = [:]
    private var metadata: AudioMediaMetadata?
    private var stopped = false
    var onFailure: ((Error) -> Void)?
    init(repository: AudioRepository, bookID: Int, chapter: AudioChapterDTO, account: String) {
        self.repository = repository; self.bookID = bookID; self.chapter = chapter; self.account = account
    }
    func asset() throws -> AVURLAsset {
        _ = try repository.mediaURL(bookID: bookID, chapter: chapter)
        guard let url = URL(string: "ekitapligim-audio://chapter/\(bookID)/\(chapter.id)") else { throw AudioError.invalidResponse }
        let asset = AVURLAsset(url: url)
        asset.resourceLoader.setDelegate(self, queue: .main)
        return asset
    }
    nonisolated func resourceLoader(_ resourceLoader: AVAssetResourceLoader,
        shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        Task { @MainActor [weak self] in self?.begin(loadingRequest) }
        return true
    }
    nonisolated func resourceLoader(_ resourceLoader: AVAssetResourceLoader, didCancel loadingRequest: AVAssetResourceLoadingRequest) {
        Task { @MainActor [weak self] in self?.jobs.removeValue(forKey: ObjectIdentifier(loadingRequest))?.cancel() }
    }
    func stop() { stopped = true; for job in jobs.values { job.cancel() }; jobs.removeAll() }
    private func begin(_ request: AVAssetResourceLoadingRequest) {
        guard !stopped, !request.isCancelled else { request.finishLoading(with: CancellationError()); return }
        let key = ObjectIdentifier(request)
        jobs[key] = Task { [weak self] in
            guard let self else { return }
            defer { self.jobs.removeValue(forKey: key) }
            do {
                try Task.checkCancellation()
                let metadata: AudioMediaMetadata
                if let cached = self.metadata { metadata = cached }
                else {
                    metadata = try await self.repository.mediaMetadata(bookID: self.bookID, chapter: self.chapter, account: self.account)
                    self.metadata = metadata
                }
                try Task.checkCancellation()
                if let info = request.contentInformationRequest {
                    info.contentType = metadata.mimeType == "application/octet-stream" ? UTType.mp3.identifier : (UTType(mimeType: metadata.mimeType)?.identifier ?? UTType.mp3.identifier)
                    info.contentLength = metadata.length; info.isByteRangeAccessSupported = true
                }
                if let target = request.dataRequest {
                    guard target.requestedOffset >= 0 else { throw AudioError.invalidRange }
                    var offset = max(target.requestedOffset, target.currentOffset)
                    guard offset >= 0, offset <= metadata.length else { throw AudioError.invalidRange }
                    let requestedEnd: Int64
                    if target.requestsAllDataToEndOfResource { requestedEnd = metadata.length }
                    else {
                        let length = Int64(target.requestedLength)
                        guard length >= 0, target.requestedOffset <= Int64.max - length else { throw AudioError.invalidRange }
                        requestedEnd = min(metadata.length, target.requestedOffset + length)
                    }
                    while offset < requestedEnd {
                        try Task.checkCancellation()
                        guard !self.stopped, !request.isCancelled else { throw CancellationError() }
                        let end = offset + min(AudioRangePolicy.chunkSize, requestedEnd - offset) - 1
                        let data = try await self.repository.mediaData(bookID: self.bookID, chapter: self.chapter,
                            account: self.account, start: offset, end: end)
                        try Task.checkCancellation()
                        guard !request.isCancelled else { throw CancellationError() }
                        target.respond(with: data); offset += Int64(data.count)
                    }
                }
                if !request.isCancelled { request.finishLoading() }
            } catch {
                if !request.isCancelled { request.finishLoading(with: error) }
                if !(error is CancellationError), !self.stopped { self.onFailure?(error) }
            }
        }
    }
}
