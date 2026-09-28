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
    @ObservedObject var manager: DownloadManager

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
                            ForEach(manager.states.keys.sorted(), id: \.self) { bookID in
                                let state = manager.states[bookID] ?? .notDownloaded
                                DownloadStateRow(bookID: bookID, state: state, progress: manager.transferProgress[bookID])
                                    .padding(14)
                                    .ekitapligimCard(radius: 14)
                                    .contextMenu {
                                        if case .downloaded(let fileName) = state {
                                            Button(role: .destructive) {
                                                Task {
                                                    await manager.remove(
                                                        bookID: bookID,
                                                        fileExtension: URL(fileURLWithPath: fileName).pathExtension
                                                    )
                                                }
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
                }
            }
        }
        .navigationTitle(L10n.downloadsTitle)
    }
}

@MainActor
private struct DownloadStateRow: View {
    let bookID: String
    let state: DownloadState
    let progress: BookTransferProgress?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.commonBookNumber(bookID))
                    .font(.headline)
                    .foregroundStyle(EKitapligimPalette.ink)
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(EKitapligimPalette.muted)
            }
            Spacer()
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
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
