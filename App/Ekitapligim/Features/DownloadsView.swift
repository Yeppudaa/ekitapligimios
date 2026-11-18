import SwiftUI
import EkitapligimCore

@MainActor
struct DownloadsView: View {
    @EnvironmentObject private var container: AppContainer

    var body: some View {
        DownloadsContent(manager: container.downloadManager)
    }
}

@MainActor
private struct DownloadsContent: View {
    @EnvironmentObject private var container: AppContainer
    @ObservedObject var manager: DownloadManager
    /// Titles looked up from the public catalog for files not in the library. Display only.
    @State private var fetchedTitles: [String: String] = [:]
    @State private var pendingRemoval: PendingRemoval?

    private struct PendingRemoval: Identifiable {
        let bookID: String
        let fileName: String
        let title: String
        var id: String { bookID }
    }

    private var downloadedIDs: [String] { manager.states.keys.sorted() }

    private func title(for bookID: String) -> String? {
        if let title = container.libraryItems.first(where: { $0.bookId == bookID })?.title
            .trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty { return title }
        return fetchedTitles[bookID]
    }

    var body: some View {
        EKitapligimScreen {
            Group {
                if manager.states.isEmpty {
                    EKEmptyState(
                        title: L10n.downloadsEmptyTitle,
                        message: L10n.downloadsEmptyDescription,
                        systemImage: "arrow.down.circle"
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(downloadedIDs, id: \.self) { bookID in
                                let state = manager.states[bookID] ?? .notDownloaded
                                row(bookID: bookID, state: state)
                                    .contextMenu {
                                        if case .downloaded(let fileName) = state {
                                            Button(role: .destructive) {
                                                confirmRemoval(bookID: bookID, fileName: fileName)
                                            } label: {
                                                Label(L10n.commonRemove, systemImage: "trash")
                                            }
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                    }
                    .floatingLauncherClearance()
                }
            }
        }
        .navigationTitle(L10n.downloadsTitle)
        .task(id: downloadedIDs) { await loadMissingTitles() }
        .confirmationDialog(
            L10n.commonRemove,
            isPresented: Binding(get: { pendingRemoval != nil }, set: { if !$0 { pendingRemoval = nil } }),
            titleVisibility: .visible,
            presenting: pendingRemoval
        ) { removal in
            Button(L10n.commonRemove, role: .destructive) {
                pendingRemoval = nil
                Task {
                    // Same removal path as before; only the confirmation is new.
                    await manager.remove(bookID: removal.bookID,
                                         fileExtension: URL(fileURLWithPath: removal.fileName).pathExtension)
                }
            }
            Button(L10n.commonCancel, role: .cancel) { pendingRemoval = nil }
        } message: { removal in
            Text(removal.title)
        }
    }

    /// The open link and the remove button are siblings, never nested, so each tap has one target.
    private func row(bookID: String, state: DownloadState) -> some View {
        HStack(alignment: .center, spacing: 10) {
            details(bookID: bookID, state: state)
            if case .downloaded(let fileName) = state {
                Button {
                    confirmRemoval(bookID: bookID, fileName: fileName)
                } label: {
                    Image(systemName: "trash")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(EKitapligimPalette.danger)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.commonRemove)
                .accessibilityIdentifier("downloads.remove.\(bookID)")
            }
        }
        .padding(14)
        .ekitapligimCard(radius: 14)
    }

    @ViewBuilder
    private func details(bookID: String, state: DownloadState) -> some View {
        let content = DownloadStateRow(title: title(for: bookID) ?? L10n.commonBookNumber(bookID),
                                       state: state, progress: manager.transferProgress[bookID])
        if Int(bookID).map({ $0 > 0 }) == true {
            // Opens the normal book detail; reading still goes through the existing reader flow.
            NavigationLink { BookDetailDestination(bookIDString: bookID) } label: {
                content.contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("downloads.open.\(bookID)")
        } else {
            content
        }
    }

    private func confirmRemoval(bookID: String, fileName: String) {
        pendingRemoval = PendingRemoval(bookID: bookID, fileName: fileName,
                                        title: title(for: bookID) ?? L10n.commonBookNumber(bookID))
    }

    private func loadMissingTitles() async {
        let repository = container.books
        for bookID in downloadedIDs where title(for: bookID) == nil {
            guard !Task.isCancelled, let id = Int(bookID), id > 0 else { continue }
            // Offline or unavailable books simply keep their number; nothing else depends on this.
            guard let book = try? await repository.book(id: id), !Task.isCancelled else { continue }
            let name = book.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty { fetchedTitles[bookID] = name }
        }
    }
}

@MainActor
private struct DownloadStateRow: View {
    let title: String
    let state: DownloadState
    let progress: BookTransferProgress?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(EKitapligimPalette.ink)
                    .multilineTextAlignment(.leading)
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(EKitapligimPalette.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
                .fixedSize()
                .accessibilityHidden(true)
        }
    }

    private var statusText: String {
        switch state {
        case .notDownloaded: L10n.downloadsNotDownloaded
        case .queued: L10n.downloadsQueued
        case .downloading:
            if let percent = progress?.percent { L10n.downloadsDownloading(percent) }
            else { ReaderL10n.text("loading.downloading") + (progress.map { " · " + $0.byteDescription } ?? "") }
        case .downloaded(let fileName): L10n.downloadsReady(fileName)
        case .failed(let message): message
        }
    }

    private var iconName: String {
        switch state {
        case .downloaded: "checkmark.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        case .downloading, .queued: "arrow.down.circle"
        case .notDownloaded: "circle"
        }
    }

    private var iconColor: Color {
        switch state {
        case .downloaded: EKitapligimPalette.success
        case .failed: EKitapligimPalette.danger
        default: EKitapligimPalette.muted
        }
    }
}
