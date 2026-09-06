import SwiftUI
import UIKit
import ReadiumNavigator
import ReadiumShared
import ReadiumStreamer
import EkitapligimCore

@MainActor
struct EPUBReaderView: View {
    let sourceURL: URL
    @Binding var progressPercent: Double
    @Binding var position: Int
    var initialPosition: ReaderPositionDTO? = nil
    var onPositionChange: (ReaderPositionDTO) -> Void = { _ in }
    var onFlush: () async -> Void = {}
    var onCaptureFailure: () -> Void = {}
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var model = EPUBReaderModel()

    var body: some View {
        Group {
            if model.isLoading {
                ProgressView(L10n.readerEPUBPreparing)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = model.errorMessage {
                ContentUnavailableView(
                    L10n.readerEPUBUnavailable,
                    systemImage: "book.closed",
                    description: Text(errorMessage)
                )
            } else if let navigator = model.navigator {
                EPUBNavigatorContainer(navigator: navigator)
            }
        }
        .task(id: sourceURL) {
            await model.open(sourceURL: sourceURL, initialPosition: initialPosition,
                onPositionChange: onPositionChange, onCaptureFailure: onCaptureFailure)
        }
        .onChange(of: model.progressPercent) { _, value in progressPercent = value }
        .onChange(of: model.position) { _, value in position = value }
        .onChange(of: scenePhase) { _, phase in if phase != .active { checkpoint() } }
        .onDisappear { checkpoint() }
    }

    private func checkpoint() {
        ReaderBackgroundCheckpoint.run {
            await model.checkpoint()
            await onFlush()
        }
    }
}

@MainActor
private final class EPUBReaderModel: NSObject, ObservableObject, EPUBNavigatorDelegate {
    @Published private(set) var navigator: EPUBNavigatorViewController?
    @Published private(set) var progressPercent: Double = 0
    @Published private(set) var position = 1
    @Published private(set) var isLoading = true
    @Published private(set) var errorMessage: String?

    private let fileManager = FileManager.default
    private let session = URLSession.shared
    private let httpClient: HTTPClient
    private let assetRetriever: AssetRetriever
    private let publicationOpener: PublicationOpener
    private var publication: Publication?
    private var temporaryPublicationURL: URL?
    private var positionAdapter: EPUBPositionAdapter?
    private var savedPosition: ReaderPositionDTO?
    private var initialLocator: Locator?
    private var restored = false
    private var restoring = false
    private var lastCFI: String?
    private var locationGeneration = UUID()
    private var onPositionChange: (ReaderPositionDTO) -> Void = { _ in }
    private var onCaptureFailure: () -> Void = {}

    override init() {
        let httpClient = DefaultHTTPClient()
        let assetRetriever = AssetRetriever(httpClient: httpClient)
        self.httpClient = httpClient
        self.assetRetriever = assetRetriever
        self.publicationOpener = PublicationOpener(
            parser: DefaultPublicationParser(
                httpClient: httpClient,
                assetRetriever: assetRetriever,
                pdfFactory: DefaultPDFDocumentFactory()
            ),
            contentProtections: []
        )
        super.init()
    }

    deinit {
        if let temporaryPublicationURL {
            try? fileManager.removeItem(at: temporaryPublicationURL)
        }
    }

    func open(sourceURL: URL, initialPosition: ReaderPositionDTO?, onPositionChange: @escaping (ReaderPositionDTO) -> Void,
              onCaptureFailure: @escaping () -> Void) async {
        guard sourceURL.scheme?.lowercased() == "https" || sourceURL.isFileURL else {
            fail(with: L10n.readerAtsLinkMissing)
            return
        }

        isLoading = true
        errorMessage = nil
        self.onPositionChange = onPositionChange
        self.onCaptureFailure = onCaptureFailure
        savedPosition = initialPosition
        restored = false
        restoring = false
        lastCFI = nil
        do {
            let localURL = try await downloadAndValidate(sourceURL)
            guard let fileURL = FileURL(url: localURL) else {
                throw EPUBReaderError.invalidLocalURL
            }
            let asset = try await assetRetriever.retrieve(url: fileURL).get()
            let adapter = try await EPUBPositionAdapter(asset: asset)
            let publication = try await publicationOpener.open(
                asset: asset,
                allowUserInteraction: false,
                sender: nil
            ).get()
            guard publication.conforms(to: .epub) else {
                throw EPUBReaderError.unsupportedPublication
            }
            let initialLocator = try adapter.initialLocator(initialPosition, publication: publication)
            let navigator = try EPUBNavigatorViewController(
                publication: publication,
                initialLocation: initialLocator,
                config: EPUBNavigatorViewController.Configuration()
            )
            navigator.delegate = self
            self.publication = publication
            self.positionAdapter = adapter
            self.initialLocator = initialLocator
            self.navigator = navigator
            isLoading = false
        } catch {
            fail(with: L10n.readerEPUBOpenFailed)
        }
    }

    func navigator(_ navigator: Navigator, locationDidChange locator: Locator) {
        let nextPercent = ((locator.locations.totalProgression ?? 0) * 100).clamped(to: 0...100)
        let nextPosition = max(1, locator.locations.position ?? 1)
        if progressPercent != nextPercent { progressPercent = nextPercent }
        if position != nextPosition { position = nextPosition }
        guard let navigator = self.navigator, let adapter = positionAdapter, !restoring else { return }
        let generation = UUID()
        locationGeneration = generation
        if !restored {
            restoring = true
            Task {
                do {
                    if let savedPosition, initialLocator != nil {
                        try await adapter.restore(savedPosition, navigator: navigator)
                    }
                    // Establish the rendered starting anchor without writing it back to the server.
                    let current = try await adapter.current(locator: navigator.currentLocation ?? locator, navigator: navigator)
                    lastCFI = current.positionValue
                    restored = true
                    restoring = false
                } catch {
                    // A bad CFI must never silently overwrite the user's position with chapter/page 1.
                    fail(with: L10n.readerEPUBOpenFailed)
                }
            }
            return
        }
        Task {
            do {
                let current = try await adapter.current(locator: locator, navigator: navigator)
                guard locationGeneration == generation, current.positionValue != lastCFI else { return }
                lastCFI = current.positionValue
                onPositionChange(current)
            } catch {
                guard locationGeneration == generation else { return }
                fail(with: L10n.readerEPUBOpenFailed)
            }
        }
    }

    func navigator(_ navigator: Navigator, presentError error: NavigatorError) {
        fail(with: L10n.readerEPUBOpenFailed)
    }

    func checkpoint() async {
        guard restored, !restoring, let adapter = positionAdapter, let navigator,
              let locator = navigator.currentLocation else { return }
        let generation = UUID()
        locationGeneration = generation
        do {
            let current = try await adapter.current(locator: locator, navigator: navigator)
            guard locationGeneration == generation, current.positionValue != lastCFI else { return }
            lastCFI = current.positionValue
            onPositionChange(current)
        } catch {
            // Keep the last valid durable position; never replace it with a guessed anchor.
            onCaptureFailure()
        }
    }

    private func downloadAndValidate(_ sourceURL: URL) async throws -> URL {
        if sourceURL.isFileURL {
            let handle = try FileHandle(forReadingFrom: sourceURL)
            defer { try? handle.close() }
            let header = try handle.read(upToCount: 1_024) ?? Data()
            try DownloadFilePolicy.validateHeader(header, fileExtension: "epub")
            return sourceURL
        }
        let (downloadURL, response) = try await session.download(from: sourceURL)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw EPUBReaderError.serverRejected
        }
        let handle = try FileHandle(forReadingFrom: downloadURL)
        defer { try? handle.close() }
        let header = try handle.read(upToCount: 1_024) ?? Data()
        try DownloadFilePolicy.validateHeader(header, fileExtension: "epub")

        let directory = try readerSessionDirectory()
        let target = directory.appendingPathComponent(UUID().uuidString).appendingPathExtension("epub")
        try fileManager.moveItem(at: downloadURL, to: target)
        try fileManager.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: target.path
        )
        temporaryPublicationURL = target
        return target
    }

    private func readerSessionDirectory() throws -> URL {
        let caches = try fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let directory = caches.appendingPathComponent("ReaderSessions", isDirectory: true)
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
            )
        }
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableDirectory = directory
        try mutableDirectory.setResourceValues(values)
        return directory
    }

    private func fail(with message: String) {
        errorMessage = message
        isLoading = false
    }
}

@MainActor
private struct EPUBNavigatorContainer: UIViewControllerRepresentable {
    let navigator: EPUBNavigatorViewController

    func makeUIViewController(context: Context) -> EPUBHostViewController {
        EPUBHostViewController(navigator: navigator)
    }

    func updateUIViewController(_ uiViewController: EPUBHostViewController, context: Context) {}
}

@MainActor
private final class EPUBHostViewController: UIViewController {
    private let navigator: EPUBNavigatorViewController

    init(navigator: EPUBNavigatorViewController) {
        self.navigator = navigator
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { return nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        addChild(navigator)
        navigator.view.frame = view.bounds
        navigator.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(navigator.view)
        navigator.didMove(toParent: self)
    }
}

private enum EPUBReaderError: Error {
    case invalidLocalURL
    case unsupportedPublication
    case serverRejected
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
