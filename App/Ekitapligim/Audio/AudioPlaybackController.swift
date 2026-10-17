import Foundation
import SwiftUI
import AVFoundation
import MediaPlayer
import UIKit
import EkitapligimCore

/// Exactly one instance belongs to the application shell. Screens only observe it; navigation never
/// recreates playback. Closing/sign-out releases the media, whereas backgrounding keeps playback alive.
@MainActor
final class AudioPlaybackController: ObservableObject {
    @Published private(set) var manifest: AudioManifestDTO?
    @Published private(set) var chapterIndex = 0
    @Published private(set) var position: Double = 0
    @Published private(set) var duration: Double = 0
    @Published private(set) var playing = false
    @Published private(set) var loading = false
    @Published private(set) var error: String?
    @Published private(set) var accessError: AudioError?
    @Published private(set) var speed: Double = 1
    @Published private(set) var bookmarks: [AudioBookmarkDTO] = []
    @Published private(set) var savingBookmark = false
    @Published private(set) var sleepMinutes = 0
    @Published private(set) var sleepAtChapterEnd = false
    @Published private(set) var volume: Float = 1
    @Published private(set) var requestedBookID: Int?
    @Published private(set) var revision = UUID()
    @Published private(set) var favorite = false
    @Published var noteRequested = false
    @Published var expanded = false
    @Published private(set) var annotationError: String?
    var onActivityChanged: (() -> Void)?
    var book: AudioBookDTO? { manifest?.book }
    var chapter: AudioChapterDTO? { manifest?.chapters.indices.contains(chapterIndex) == true ? manifest?.chapters[chapterIndex] : nil }
    var visible: Bool { requestedBookID != nil || manifest != nil }
    var canPrevious: Bool { chapterIndex > 0 }
    var canNext: Bool { manifest.map { chapterIndex + 1 < $0.chapters.count } ?? false }
    private(set) var account: String?
    private let repository: AudioRepository
    private var player: AVPlayer?
    private var loader: AudioAssetResourceLoader?
    private var statusObservation: NSKeyValueObservation?
    private var periodicObserver: Any?
    private var notifications: [NSObjectProtocol] = []
    private var remoteTargets: [(MPRemoteCommand, Any)] = []
    private var loadTask: Task<Void, Never>?
    private var progressTail: Task<Void, Never>?
    private var ledger = AudioProgressLedger()
    private var generation = UUID()
    private var lastTick = ProcessInfo.processInfo.systemUptime
    private var lastSave = ProcessInfo.processInfo.systemUptime
    private var sleepDeadline: TimeInterval?
    private var playWhenReady = false
    private var artworkTask: Task<Void, Never>?
    private var nowPlayingArtwork: MPMediaItemArtwork?
    private var acknowledgedActivities: Set<String> = []
    #if DEBUG
    private var debugAudioSessionPhase = "not-requested"
    private enum DebugInitialSeekPhase: String { case notStarted, awaiting, completed, interrupted }
    private var debugInitialSeekPhase: DebugInitialSeekPhase = .notStarted
    /// Content-free state used only by native tests; it never exposes media or account data.
    var debugPlaybackState: String {
        "loading=\(loading),playing=\(playing),position=\(position),duration=\(duration),itemStatus=\(player?.currentItem?.status.rawValue ?? -1),timeControl=\(player?.timeControlStatus.rawValue ?? -1),waiting=\(player?.reasonForWaitingToPlay?.rawValue ?? "none"),audioSession=\(debugAudioSessionPhase),initialSeek=\(debugInitialSeekPhase.rawValue),loader={\(loader?.debugSnapshot ?? "none")}"
    }
    #endif

    init(repository: AudioRepository) {
        self.repository = repository
        configureRemoteControls()
        let center = NotificationCenter.default
        notifications.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            guard let type = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  type == AVAudioSession.InterruptionType.began.rawValue else { return }
            Task { @MainActor in self?.pause() }
        })
        notifications.append(center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] note in
            guard let reason = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue else { return }
            Task { @MainActor in self?.pause() }
        })
        notifications.append(center.addObserver(forName: UIApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.close() }
        })
    }
    func activate(account: String?) {
        guard self.account != account else { return }
        close(); progressTail?.cancel(); progressTail = nil; self.account = account; acknowledgedActivities.removeAll()
    }
    func start(bookID: Int, chapterID: Int? = nil) {
        guard bookID > 0 else { return }
        guard let account else { fail(AudioError.authenticationRequired); return }
        if book?.id == bookID, error == nil, let chapterID, let index = manifest?.chapters.firstIndex(where: { $0.id == chapterID }) {
            selectChapter(index); return
        }
        if book?.id == bookID, error == nil, chapterID == nil, player != nil { resume(); return }
        pause(); let previousSave = progressTail
        loadTask?.cancel(); generation = UUID(); let expected = generation
        releasePlayer(); manifest = nil; bookmarks = []; requestedBookID = bookID
        error = nil; accessError = nil; loading = true; playing = false; playWhenReady = true
        loadTask = Task { [weak self] in
            guard let self else { return }
            await previousSave?.value
            do {
                try Task.checkCancellation()
                guard self.account == account, self.generation == expected else { throw CancellationError() }
                let manifest = try await self.repository.manifest(bookID: bookID, account: account)
                try Task.checkCancellation()
                guard self.account == account, self.generation == expected else { throw CancellationError() }
                self.manifest = manifest; self.bookmarks = manifest.bookmarks; self.speed = manifest.state.speed
                self.favorite = manifest.book.state.favorite
                self.ledger.activate(session: manifest.session, sequence: manifest.sequence)
                let index = manifest.chapters.firstIndex { $0.id == (chapterID ?? manifest.state.chapterID) } ?? 0
                var position = chapterID == nil || chapterID == manifest.state.chapterID ? manifest.state.position : 0
                if index == manifest.chapters.count - 1, manifest.chapters[index].duration > 0, position >= manifest.chapters[index].duration - 0.75 { position = 0 }
                try self.prepare(index: index, position: position, generation: expected)
                self.fetchArtwork(manifest.book)
            } catch is CancellationError { }
            catch { guard self.generation == expected else { return }; self.fail(error) }
        }
    }
    func retry() { if let id = requestedBookID { start(bookID: id, chapterID: chapter?.id) } }
    func toggle() { playing ? pause() : resume() }
    func resume() {
        guard error == nil else { retry(); return }
        playWhenReady = true
        guard !loading, let player else { return }
        Task { [weak self] in
            guard let self, let account = self.account, await self.repository.isCurrent(account: account) else { self?.close(); return }
            guard self.playWhenReady, self.player === player else { return }
            do {
                try self.activateAudioSession(); player.playImmediately(atRate: Float(self.speed)); self.playing = true
                self.lastTick = ProcessInfo.processInfo.systemUptime; self.updateNowPlaying()
            } catch { self.fail(error) }
        }
    }
    func pause() {
        playWhenReady = false; player?.pause(); playing = false; updatePosition(); flush(); updateNowPlaying()
    }
    /// No mini-player survives this operation; releasing the asset also cancels outstanding HTTP ranges.
    func close() {
        pause(); loadTask?.cancel(); generation = UUID(); releasePlayer(); manifest = nil; requestedBookID = nil
        loading = false; playing = false; error = nil; accessError = nil; bookmarks = []; position = 0; duration = 0; noteRequested = false; savingBookmark = false; expanded = false; annotationError = nil
        sleepDeadline = nil; sleepMinutes = 0; sleepAtChapterEnd = false; artworkTask?.cancel(); nowPlayingArtwork = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    func seek(to value: Double) {
        guard let player, !loading else { return }
        let target = min(max(0, AudioPolicy.finite(value)), max(0, duration))
        position = target; player.seek(to: CMTime(seconds: target, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        flush(); updateNowPlaying()
    }
    func skip(_ seconds: Double) { seek(to: position + seconds) }
    func selectChapter(_ index: Int) {
        guard let manifest, manifest.chapters.indices.contains(index) else { return }
        pause(); let previous = progressTail; playWhenReady = true
        let expected = generation
        loadTask?.cancel(); loadTask = Task { [weak self] in
            await previous?.value
            guard let self, self.generation == expected else { return }
            do { try Task.checkCancellation(); try self.prepare(index: index, position: 0, generation: expected) }
            catch is CancellationError { } catch { self.fail(error) }
        }
    }
    func setSpeed(_ value: Double) { speed = AudioPolicy.speed(value); if playing { player?.rate = Float(speed) }; flush(); updateNowPlaying() }
    func setVolume(_ value: Float) { volume = min(1, max(0, value.isFinite ? value : 1)); player?.volume = volume }
    func setSleep(minutes: Int) {
        sleepMinutes = max(0, min(120, minutes)); sleepAtChapterEnd = false
        sleepDeadline = sleepMinutes > 0 ? ProcessInfo.processInfo.systemUptime + Double(sleepMinutes * 60) : nil
    }
    func setSleepAtChapterEnd() { sleepAtChapterEnd = true; sleepMinutes = 0; sleepDeadline = nil }
    func addBookmark() async { await addAnnotation(kind: .bookmark, text: AudioL10n.text("bookmarkTitle"), chapterID: chapter?.id, position: position) }
    func addAnnotation(kind: AudioAnnotationKind, text: String, chapterID: Int?, position: Double) async {
        guard !savingBookmark, let manifest, let account, let chapterID,
              let chapter = manifest.chapters.first(where: { $0.id == chapterID }) else { return }
        let expected = generation; savingBookmark = true; annotationError = nil
        defer { if generation == expected { savingBookmark = false } }
        do {
            let label = try AudioPolicy.annotation(kind: kind, text: text)
            let bookmark = try await repository.bookmark(bookID: manifest.book.id, chapterID: chapterID,
                position: min(AudioPolicy.finite(position), chapter.duration), label: label, account: account)
            guard generation == expected else { return }; bookmarks.append(bookmark); revision = UUID()
        } catch is CancellationError { } catch { if generation == expected { self.annotationError = AudioL10n.error(error) } }
    }
    func deleteBookmark(_ bookmark: AudioBookmarkDTO) async {
        guard let manifest, let account else { return }; let expected = generation
        do {
            try await repository.deleteBookmark(bookID: manifest.book.id, bookmarkID: bookmark.id, account: account)
            guard generation == expected else { return }; bookmarks.removeAll { $0.id == bookmark.id }; revision = UUID()
        } catch is CancellationError { } catch { if generation == expected { self.annotationError = AudioL10n.error(error) } }
    }
    func openBookmark(_ bookmark: AudioBookmarkDTO) {
        guard let manifest, let index = manifest.chapters.firstIndex(where: { $0.id == bookmark.chapterID }) else { return }
        if index == chapterIndex { seek(to: bookmark.position) }
        else {
            pause(); let previous = progressTail; let expected = generation; playWhenReady = true
            loadTask?.cancel(); loadTask = Task { [weak self] in
                await previous?.value
                guard let self, self.generation == expected else { return }
                do { try Task.checkCancellation(); try self.prepare(index: index, position: bookmark.position, generation: expected) }
                catch is CancellationError { } catch { self.fail(error) }
            }
        }
    }
    func toggleFavorite() async {
        guard let book, let account else { return }; let expected = generation
        do {
            let value = !favorite
            try await repository.shelf(bookID: book.id, field: .favorite, value: value, account: account)
            guard expected == generation else { return }
            await acknowledgeShelfChange(bookID: book.id, field: .favorite, value: value, account: account)
        } catch is CancellationError { } catch { if expected == generation { self.error = AudioL10n.error(error) } }
    }
    /// Apply only a server-acknowledged shelf mutation. A detail screen can update an already playing
    /// book without obtaining a new manifest, resetting its position or restarting AVPlayer.
    func acknowledgeShelfChange(bookID: Int, field: AudioShelfField, value: Bool, account owner: String) async {
        guard bookID > 0, account == owner, await repository.isCurrent(account: owner), account == owner else { return }
        if book?.id == bookID, field == .favorite { favorite = value }
        revision = UUID(); onActivityChanged?()
    }
    private func prepare(index: Int, position: Double, generation expected: UUID) throws {
        guard let manifest, let account, manifest.chapters.indices.contains(index) else { throw AudioError.invalidResponse }
        releasePlayer(); chapterIndex = index; self.position = min(AudioPolicy.finite(position), manifest.chapters[index].duration)
        duration = manifest.chapters[index].duration; loading = true; playing = false; error = nil; accessError = nil
        #if DEBUG
        debugInitialSeekPhase = .notStarted
        #endif
        let loader = AudioAssetResourceLoader(repository: repository, bookID: manifest.book.id, chapter: manifest.chapters[index], account: account)
        loader.onFailure = { [weak self] error in guard self?.generation == expected else { return }; self?.fail(error) }
        let item = AVPlayerItem(asset: try loader.asset()); self.loader = loader
        let player = AVPlayer(playerItem: item); player.volume = volume; player.automaticallyWaitsToMinimizeStalling = true; self.player = player
        let initialPosition = self.position
        statusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self, weak player] item, _ in
            Task { @MainActor in
                guard let self, let player, self.generation == expected, self.player === player else { return }
                switch item.status {
                case .readyToPlay:
                    self.loading = false
                    let realDuration = item.duration.seconds
                    if realDuration.isFinite, realDuration > 0 { self.duration = realDuration }
                    #if DEBUG
                    self.debugInitialSeekPhase = .awaiting
                    let seekFinished = await player.seek(to: CMTime(seconds: min(initialPosition, self.duration), preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
                    if self.generation == expected, self.player === player {
                        self.debugInitialSeekPhase = seekFinished ? .completed : .interrupted
                    }
                    #else
                    await player.seek(to: CMTime(seconds: min(initialPosition, self.duration), preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
                    #endif
                    guard self.generation == expected, self.player === player else { return }
                    if self.playWhenReady { self.resume() }; self.updateNowPlaying()
                case .failed: self.fail(item.error ?? AudioError.invalidResponse)
                default: break
                }
            }
        }
        periodicObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 600), queue: .main) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        notifications.append(NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.generation == expected else { return }
                self.position = self.duration; self.pause()
                if self.sleepAtChapterEnd { self.sleepAtChapterEnd = false }
                else if self.canNext { self.selectChapter(self.chapterIndex + 1) }
            }
        })
        lastTick = ProcessInfo.processInfo.systemUptime; lastSave = lastTick
    }
    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        ledger.accrue(elapsed: now - lastTick, playing: playing && player?.timeControlStatus == .playing)
        lastTick = now; updatePosition()
        if let sleepDeadline, now >= sleepDeadline { self.sleepDeadline = nil; sleepMinutes = 0; pause() }
        if now - lastSave >= 15 { lastSave = now; flush() }
        updateNowPlaying()
    }
    private func updatePosition() {
        if let value = player?.currentTime().seconds, value.isFinite { position = max(0, min(value, max(duration, value))) }
    }
    private func flush() {
        guard let book, let chapter, let account,
              let write = try? ledger.reserve(bookID: book.id, chapterID: chapter.id, position: position, speed: speed) else { return }
        let previous = progressTail; let expected = generation
        progressTail = Task { [weak self] in
            await previous?.value
            guard let self, !Task.isCancelled else { return }
            do {
                let result = try await self.repository.saveProgress(write, account: account)
                guard self.generation == expected else { return }
                if result.saved {
                    self.ledger.acknowledged(write)
                    let started = result.credited > 0 && self.acknowledgedActivities.insert("started:\(account):\(write.bookID)").inserted
                    let completed = (result.completed || (result.state?.completedDate ?? 0) > 0) && self.acknowledgedActivities.insert("completed:\(account):\(write.bookID)").inserted
                    if started || completed { self.revision = UUID(); self.onActivityChanged?() }
                }
                else { self.ledger.failed(write) }
            } catch is CancellationError { }
            catch {
                guard self.generation == expected else { return }
                self.ledger.failed(write)
                if let access = error as? AudioError, [.authenticationRequired, .premiumRequired, .sessionConflict, .accountChanged].contains(access) { self.fail(error) }
            }
        }
    }
    private func fail(_ error: Error) {
        updatePosition(); releasePlayer(); playing = false; loading = false; playWhenReady = false
        self.error = AudioL10n.error(error); accessError = error as? AudioError
        loader?.stop(); updateNowPlaying()
    }
    private func releasePlayer() {
        statusObservation?.invalidate(); statusObservation = nil
        if let periodicObserver, let player { player.removeTimeObserver(periodicObserver) }; periodicObserver = nil
        player?.pause(); player?.replaceCurrentItem(with: nil); player = nil; loader?.stop(); loader = nil
        // The first three observers are the controller's lifetime interruption/route/termination listeners.
        if notifications.count > 3 {
            notifications.dropFirst(3).forEach { NotificationCenter.default.removeObserver($0) }; notifications = Array(notifications.prefix(3))
        }
    }
    private func activateAudioSession() throws {
        #if DEBUG
        debugAudioSessionPhase = "setting-category"
        #endif
        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [])
        #if DEBUG
        debugAudioSessionPhase = "activating"
        #endif
        try AVAudioSession.sharedInstance().setActive(true)
        #if DEBUG
        debugAudioSessionPhase = "active"
        #endif
    }
    private func configureRemoteControls() {
        let center = MPRemoteCommandCenter.shared()
        func bind(_ command: MPRemoteCommand, action: @escaping @MainActor (AudioPlaybackController, MPRemoteCommandEvent) -> Void) {
            let token = command.addTarget { [weak self] event in
                Task { @MainActor in guard let self, self.visible else { return }; action(self, event) }; return .success
            }; remoteTargets.append((command, token))
        }
        center.skipForwardCommand.preferredIntervals = [15]; center.skipBackwardCommand.preferredIntervals = [15]
        bind(center.playCommand) { controller, _ in controller.resume() }
        bind(center.pauseCommand) { controller, _ in controller.pause() }
        bind(center.togglePlayPauseCommand) { controller, _ in controller.toggle() }
        bind(center.stopCommand) { controller, _ in controller.close() }
        bind(center.skipForwardCommand) { controller, _ in controller.skip(15) }
        bind(center.skipBackwardCommand) { controller, _ in controller.skip(-15) }
        bind(center.nextTrackCommand) { controller, _ in if controller.canNext { controller.selectChapter(controller.chapterIndex + 1) } }
        bind(center.previousTrackCommand) { controller, _ in if controller.canPrevious { controller.selectChapter(controller.chapterIndex - 1) } }
        bind(center.changePlaybackPositionCommand) { controller, event in
            if let event = event as? MPChangePlaybackPositionCommandEvent { controller.seek(to: event.positionTime) }
        }
    }
    private func updateNowPlaying() {
        guard let book else { return }
        var info: [String: Any] = [MPMediaItemPropertyTitle: book.title, MPMediaItemPropertyArtist: book.author,
            MPMediaItemPropertyAlbumTitle: chapter?.title ?? book.title, MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: position, MPNowPlayingInfoPropertyPlaybackRate: playing ? speed : 0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: speed, MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue]
        if let nowPlayingArtwork { info[MPMediaItemPropertyArtwork] = nowPlayingArtwork }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPRemoteCommandCenter.shared().nextTrackCommand.isEnabled = canNext
        MPRemoteCommandCenter.shared().previousTrackCommand.isEnabled = canPrevious
    }
    private func fetchArtwork(_ book: AudioBookDTO) {
        artworkTask?.cancel(); nowPlayingArtwork = nil
        guard let url = URL(string: book.coverURL), url.scheme == "https", url.user == nil, url.password == nil else { return }
        artworkTask = Task { [weak self] in
            guard let (data, response) = try? await URLSession.shared.data(from: url), data.count <= 4_000_000,
                  (response as? HTTPURLResponse)?.statusCode == 200, let image = UIImage(data: data), !Task.isCancelled,
                  let self, self.book?.id == book.id else { return }
            self.nowPlayingArtwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }; self.updateNowPlaying()
        }
    }
}
