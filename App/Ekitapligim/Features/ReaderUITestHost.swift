#if DEBUG
import SwiftUI
import UIKit
import PDFKit
import EkitapligimCore

/// Offline visual fixtures use the shipping PDF view and chrome. No account or network is created.
@MainActor
struct ReaderUITestHost: View {
    @StateObject private var fixture = ReaderFixtureDocument()
    @State private var progress = ReadingProgress(currentPage: 1, totalPages: 60)
    @State private var requestedPage: Int?
    @State private var theme: ReaderPaperTheme
    @State private var showsControls = false
    @State private var isBookmarked = false
    @State private var showsSettings = false
    @State private var showsPages = false
    @State private var layout = PDFReadingLayout.continuous
    @State private var isClosed = false
    private let mode: String

    init() {
        let environment = ProcessInfo.processInfo.environment
        mode = environment["READER_FIXTURE_MODE"] ?? "reading"
        _theme = State(initialValue: ReaderPaperTheme(rawValue: environment["READER_FIXTURE_THEME"] ?? "sepia") ?? .sepia)
    }

    private var detail: String { L10n.readerPage(progress.currentPage, 60) }
    private var loadingPhase: ReaderLoadingPhase? {
        switch mode {
        case "download-known": .downloading(BookTransferProgress(receivedBytes: 37_000_000, expectedBytes: 100_000_000))
        case "download-unknown": .downloading(BookTransferProgress(receivedBytes: 37_000_000, expectedBytes: -1))
        case "authorizing": .authorizing
        case "restoring": .restoring
        case "opening": .opening
        default: nil
        }
    }

    var body: some View {
        ZStack {
            theme.paper.ignoresSafeArea()
            if isClosed {
                Text(L10n.commonClose).accessibilityIdentifier("reader.fixture.closed")
            } else {
                if let loadingPhase {
                    ReaderLoadingView(title: ReaderFixtureDocument.title, author: ReaderFixtureDocument.author,
                                      phase: loadingPhase, theme: theme)
                } else if let document = fixture.document {
                    PDFReader(url: fixture.url, document: document, progress: $progress, requestedPage: $requestedPage,
                              layout: layout, initialPage: 25, onToggleControls: { showsControls.toggle() })
                        .modifier(ReaderPDFPaper(theme: theme))
                        .ignoresSafeArea(.container)
                        .accessibilityIdentifier("reader.fixture.document")
                } else {
                    ContentUnavailableView(L10n.readerUnavailable, systemImage: "doc")
                }
                chrome
            }
        }
        .preferredColorScheme(theme.colorScheme)
        .statusBarHidden(!showsControls)
        .persistentSystemOverlays(showsControls ? .automatic : .hidden)
        .accessibilityIdentifier("reader.fullscreen")
        .sheet(isPresented: $showsSettings) {
            NavigationStack {
                Form {
                    Picker(L10n.readerLayout, selection: $layout) {
                        Text(L10n.readerContinuousLayout).tag(PDFReadingLayout.continuous)
                        Text(L10n.readerPagedLayout).tag(PDFReadingLayout.paged)
                    }.pickerStyle(.inline)
                }
                .navigationTitle(L10n.readerSettings)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L10n.commonClose) { showsSettings = false }
                            .accessibilityIdentifier("reader.fixture.closeSettings")
                    }
                }
            }.presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showsPages) {
            List(1...60, id: \.self) { page in
                Button(L10n.readerPageNumber(page)) {
                    requestedPage = page
                    showsPages = false
                }
            }
        }
    }

    private var chrome: some View {
        VStack {
            if showsControls {
                ReaderChrome(title: ReaderFixtureDocument.title, detail: "PDF · " + detail, theme: theme,
                             isBookmarked: isBookmarked, supportsPDF: true, enabled: loadingPhase == nil,
                             close: { isClosed = true }, focus: { showsControls = false }, changeTheme: cycleTheme,
                             bookmark: { isBookmarked.toggle() }, bookmarks: { showsPages = true },
                             pages: { showsPages = true }, settings: { showsSettings = true })
            } else {
                HStack {
                    ReaderIconButton(icon: "chevron.left", label: L10n.commonClose, theme: theme) { isClosed = true }
                        .background(theme.panel, in: RoundedRectangle(cornerRadius: 14))
                        .accessibilityIdentifier("reader.close")
                    Spacer()
                    ReaderIconButton(icon: "slider.horizontal.3", label: ReaderL10n.text("showControls"), theme: theme) {
                        showsControls = true
                    }
                    .background(theme.panel, in: RoundedRectangle(cornerRadius: 14))
                    .accessibilityIdentifier("reader.showControls")
                }.padding(.horizontal, 12).padding(.top, 6)
            }
            Spacer(minLength: 0)
            if loadingPhase == nil {
                if showsControls {
                    ReaderPageControls(progress: progress, accessiblePageLimit: 60, hasLockedContent: false,
                                       detail: detail, syncLabel: L10n.readerSyncReady, syncFailed: false,
                                       theme: theme, onRequestPage: { requestedPage = $0 })
                } else {
                    Text(detail).font(.caption2.monospacedDigit().weight(.medium))
                        .foregroundStyle(theme.ink.opacity(0.65))
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(theme.paper.opacity(0.92), in: Capsule())
                        .padding(.bottom, 6).allowsHitTesting(false)
                        .accessibilityIdentifier("reader.focusProgress")
                }
            }
        }
    }

    private func cycleTheme() {
        theme = theme == .sepia ? .night : (theme == .night ? .white : .sepia)
    }
}

@MainActor
private final class ReaderFixtureDocument: ObservableObject {
    static let title = "Okuma Yolculuğu"
    static let author = "Ekitaplığım"
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("reader-ui-fixture.pdf")
    let document: PDFDocument?

    init() {
        let bounds = CGRect(x: 0, y: 0, width: 390, height: 640)
        let data = UIGraphicsPDFRenderer(bounds: bounds).pdfData { renderer in
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = 7
            paragraph.alignment = .justified
            let body = "Bir kitabı açmak, yeni bir yolculuğa çıkmaktır. Sayfalar ilerledikçe düşünceler durulur; her satır, keşfedilmeyi bekleyen başka bir dünyaya kapı aralar.\n\nPencerenin önüne oturdu. Dışarıda ağaçlar hafifçe sallanıyordu. Elindeki kitabın sayfalarını çevirirken günün telaşı yavaşça geride kaldı.\n\nOkuduğu cümleler ona eskiden bildiği bir yeri hatırlattı. Bir sokağın sessizliği, denizin sesi ve uzun bir yolun sonunda karşılaşılan dostluk…\n\nBir sonraki sayfaya geçti. Yolculuk henüz yeni başlıyordu."
            for page in 1...60 {
                renderer.beginPage()
                UIColor.white.setFill()
                renderer.cgContext.fill(bounds)
                (Self.title.uppercased() as NSString).draw(in: CGRect(x: 40, y: 36, width: 310, height: 18), withAttributes: [
                    .font: UIFont.systemFont(ofSize: 9, weight: .medium), .foregroundColor: UIColor.darkGray, .kern: 2
                ])
                ("Bir Sayfa Daha" as NSString).draw(in: CGRect(x: 40, y: 78, width: 310, height: 35), withAttributes: [
                    .font: UIFont(name: "Georgia", size: 23) ?? UIFont.systemFont(ofSize: 23), .foregroundColor: UIColor.black
                ])
                (body as NSString).draw(in: CGRect(x: 40, y: 136, width: 310, height: 442), withAttributes: [
                    .font: UIFont(name: "Georgia", size: 14) ?? UIFont.systemFont(ofSize: 14),
                    .foregroundColor: UIColor.black, .paragraphStyle: paragraph
                ])
                (String(page) as NSString).draw(at: CGPoint(x: 187, y: 607), withAttributes: [
                    .font: UIFont.systemFont(ofSize: 10), .foregroundColor: UIColor.darkGray
                ])
            }
        }
        document = PDFDocument(data: data)
    }
}
#endif
