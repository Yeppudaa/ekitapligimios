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
        .task(id: sourceURL) { await model.open(sourceURL: sourceURL) }
        .onChange(of: model.progressPercent) { _, value in progressPercent = value }
        .onChange(of: model.position) { _, value in position = value }
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

    func open(sourceURL: URL) async {
        guard sourceURL.scheme?.lowercased() == "https" || sourceURL.isFileURL else {
            fail(with: L10n.readerAtsLinkMissing)
            return
        }

        isLoading = true
        errorMessage = nil
        do {
            let localURL = try await downloadAndValidate(sourceURL)
            guard let fileURL = FileURL(url: localURL) else {
                throw EPUBReaderError.invalidLocalURL
            }
            let asset = try await assetRetriever.retrieve(url: fileURL).get()
            let publication = try await publicationOpener.open(
                asset: asset,
                allowUserInteraction: false,
                sender: nil
            ).get()
            guard publication.conforms(to: .epub) else {
                throw EPUBReaderError.unsupportedPublication
            }
            let navigator = try EPUBNavigatorViewController(
                publication: publication,
                initialLocation: nil,
                config: EPUBNavigatorViewController.Configuration()
            )
            navigator.delegate = self
            self.publication = publication
            self.navigator = navigator
            isLoading = false
        } catch {
            fail(with: L10n.readerEPUBOpenFailed)
        }
    }

    func navigator(_ navigator: Navigator, locationDidChange locator: Locator) {
        progressPercent = ((locator.locations.totalProgression ?? 0) * 100).clamped(to: 0...100)
        position = max(1, locator.locations.position ?? 1)
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

private struct EPUBNavigatorContainer: UIViewControllerRepresentable {
    let navigator: EPUBNavigatorViewController

    func makeUIViewController(context: Context) -> EPUBHostViewController {
        EPUBHostViewController(navigator: navigator)
    }

    func updateUIViewController(_ uiViewController: EPUBHostViewController, context: Context) {}
}

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
