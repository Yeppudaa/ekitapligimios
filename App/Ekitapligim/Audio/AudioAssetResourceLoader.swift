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
    #if DEBUG
    private var requestCount = 0
    private var informationCount = 0
    private var dataRequestCount = 0
    private var responseBytes: Int64 = 0
    private var finishedCount = 0
    private var cancelledCount = 0
    private var failureCount = 0
    private var lastRequestedLength = 0
    private enum DebugMIME: String { case unknown, wav, mpeg, aac, mp4, flac, ogg, octet, other }
    private enum DebugUTI: String { case unknown, wav, mp3, aac, m4a, flac, ogg, dynamic, other }
    private var debugMIME: DebugMIME = .unknown
    private var debugUTI: DebugUTI = .unknown
    private var debugAllowedCount = -1
    private var debugSelectedAllowed = true
    private var debugIsDynamic = false
    /// Numeric/enum transport state only. No URL, account, token, title, or response body is retained.
    var debugSnapshot: String {
        "requests=\(requestCount),info=\(informationCount),data=\(dataRequestCount),bytes=\(responseBytes),finished=\(finishedCount),cancelled=\(cancelledCount),failures=\(failureCount),lastLength=\(lastRequestedLength),jobs=\(jobs.count),metadata=\(metadata != nil),mime=\(debugMIME.rawValue),uti=\(debugUTI.rawValue),allowedCount=\(debugAllowedCount),selectedAllowed=\(debugSelectedAllowed),isDynamic=\(debugIsDynamic)"
    }
    private func recordContentType(_ info: AVAssetResourceLoadingContentInformationRequest, metadata: AudioMediaMetadata) {
        switch metadata.mimeType {
        case "audio/wav", "audio/wave", "audio/x-wav", "audio/vnd.wave": debugMIME = .wav
        case "audio/mpeg", "audio/mp3", "audio/x-mp3": debugMIME = .mpeg
        case "audio/aac", "audio/aacp", "audio/x-aac": debugMIME = .aac
        case "audio/mp4", "audio/m4a", "audio/x-m4a": debugMIME = .mp4
        case "audio/flac", "audio/x-flac": debugMIME = .flac
        case "audio/ogg", "audio/vorbis": debugMIME = .ogg
        case "application/octet-stream": debugMIME = .octet
        default: debugMIME = .other
        }
        let identifier = info.contentType
        debugIsDynamic = identifier.flatMap { UTType($0) }?.isDynamic == true
        if debugIsDynamic { debugUTI = .dynamic }
        else {
            switch identifier {
            case UTType.wav.identifier: debugUTI = .wav
            case UTType.mp3.identifier: debugUTI = .mp3
            case "public.aac-audio": debugUTI = .aac
            case "public.mpeg-4-audio": debugUTI = .m4a
            case "org.xiph.flac": debugUTI = .flac
            case "org.xiph.ogg-audio": debugUTI = .ogg
            case nil: debugUTI = .unknown
            default: debugUTI = .other
            }
        }
        debugAllowedCount = info.allowedContentTypes?.count ?? -1
        if let identifier, let allowed = info.allowedContentTypes { debugSelectedAllowed = allowed.contains(identifier) }
        else { debugSelectedAllowed = true }
    }
    #endif
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
        Task { @MainActor [weak self] in
            #if DEBUG
            self?.cancelledCount += 1
            #endif
            self?.jobs.removeValue(forKey: ObjectIdentifier(loadingRequest))?.cancel()
        }
    }
    func stop() { stopped = true; for job in jobs.values { job.cancel() }; jobs.removeAll() }
    private func begin(_ request: AVAssetResourceLoadingRequest) {
        guard !stopped, !request.isCancelled else { request.finishLoading(with: CancellationError()); return }
        #if DEBUG
        requestCount += 1
        if request.contentInformationRequest != nil { informationCount += 1 }
        if let target = request.dataRequest { dataRequestCount += 1; lastRequestedLength = target.requestedLength }
        #endif
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
                    #if DEBUG
                    self.recordContentType(info, metadata: metadata)
                    #endif
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
                        #if DEBUG
                        self.responseBytes += Int64(data.count)
                        #endif
                    }
                }
                if !request.isCancelled {
                    request.finishLoading()
                    #if DEBUG
                    self.finishedCount += 1
                    #endif
                }
            } catch {
                #if DEBUG
                if !(error is CancellationError) { self.failureCount += 1 }
                #endif
                if !request.isCancelled { request.finishLoading(with: error) }
                if !(error is CancellationError), !self.stopped { self.onFailure?(error) }
            }
        }
    }
}
