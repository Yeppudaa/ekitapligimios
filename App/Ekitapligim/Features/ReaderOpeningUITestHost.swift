#if DEBUG
import SwiftUI
import EkitapligimCore

/// No account, transport, remote artwork, or reader-session request is created.
@MainActor
struct ReaderOpeningUITestHost: View {
    @State private var source = ReaderOpeningSource()
    @State private var snapshot: ReaderOpeningSnapshot?
    @State private var isPresented = false
    @State private var showsNestedCover = false
    @State private var didShowNestedCover = false
    private let book = try? JSONDecoder().decode(BookDTO.self, from: Data("""
        {"id":"900042","title":"Okuma Yolculuğu","author":"Ekitaplığım","publisher":"",
         "isbn":"","category":"Deneme","language":"Türkçe","publishYear":"2026",
         "description":"","coverUrl":"","pdfUrl":"","pageCount":60,"isPremiumOnly":false}
        """.utf8))

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Text(L10n.bookDetailTitle).font(.title.bold())
                if let book {
                    EKitapligimMissingBookCover(title: book.title, author: book.author)
                        .frame(width: 170, height: 250)
                        .background(ReaderOpeningAnchor(source: source))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    Button(L10n.bookDetailRead) {
                        guard !isPresented else { return }
                        snapshot = source.capture()
                        present(true)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("book.openReader")
                }
            }.padding(32).frame(maxWidth: .infinity)
        }
        .background(Color(red: 0.98, green: 0.96, blue: 0.92).ignoresSafeArea())
        .fullScreenCover(isPresented: $isPresented, onDismiss: { snapshot = nil }) {
            if let book {
                ReaderOpeningPresentation(book: book, snapshot: $snapshot, onCancel: { present(false) },
                                          sequence: makeSequence()) {
                    ReaderUITestHost(mode: "reading", onClose: { present(false) })
                        .fullScreenCover(isPresented: $showsNestedCover) {
                            Button(L10n.commonClose) { showsNestedCover = false }
                                .accessibilityIdentifier("reader.opening.fixture.closeNestedCover")
                        }
                        .task {
                            guard ProcessInfo.processInfo.environment["READER_OPENING_NESTED_COVER"] == "1",
                                  !didShowNestedCover else { return }
                            didShowNestedCover = true
                            showsNestedCover = true
                        }
                }
                .environment(\.accessibilityReduceMotion,
                             ProcessInfo.processInfo.environment["READER_OPENING_REDUCE_MOTION"] == "1")
            }
        }
    }

    private func present(_ presented: Bool) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) { isPresented = presented }
    }

    private func makeSequence() -> ReaderOpeningSequence {
        if ProcessInfo.processInfo.environment["READER_OPENING_HOLD"] == "1" {
            return ReaderOpeningSequence(sleep: { _ in try await Task.sleep(for: .seconds(30)) })
        }
        return ReaderOpeningSequence()
    }
}
#endif
