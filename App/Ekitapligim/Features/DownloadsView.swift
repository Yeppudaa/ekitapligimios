import SwiftUI
import EkitapligimCore

struct DownloadsView: View {
    @EnvironmentObject private var container: AppContainer

    var body: some View {
        List {
            if container.downloadManager.states.isEmpty {
                ContentUnavailableView(L10n.downloadsEmptyTitle, systemImage: "arrow.down.circle", description: Text(L10n.downloadsEmptyDescription))
            } else {
                ForEach(container.downloadManager.states.keys.sorted(), id: \.self) { bookID in
                    DownloadStateRow(bookID: bookID, state: container.downloadManager.states[bookID] ?? .notDownloaded)
                }
            }
        }
        .navigationTitle(L10n.downloadsTitle)
    }
}

private struct DownloadStateRow: View {
    let bookID: String
    let state: DownloadState

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(L10n.commonBookNumber(bookID))
                    .font(.headline)
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
        case .downloading(let progress): L10n.downloadsDownloading(Int(progress * 100))
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
        case .downloaded: .green
        case .failed: .red
        default: .secondary
        }
    }
}
