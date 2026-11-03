import SwiftUI
import EkitapligimCore

@MainActor
struct MyAudioCommentsView: View {
    @EnvironmentObject private var container: AppContainer
    @StateObject private var model: MyAudioCommentsModel

    init(repository: any MyAudioCommentsServing) {
        _model = StateObject(wrappedValue: MyAudioCommentsModel(repository: repository))
    }

    var body: some View {
        EKitapligimScreen {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if !container.isSignedIn {
                        EKEmptyState(title: AudioL10n.text("myAudioComments"), message: AudioL10n.text("signInRequired"), systemImage: "lock")
                    } else if model.isLoading && model.comments.isEmpty {
                        EKLoadingState(message: AudioL10n.text("commentsLoading"))
                    } else if let message = model.errorMessage, model.comments.isEmpty {
                        EKErrorState(title: AudioL10n.text("myAudioComments"), message: message) {
                            Task { await model.retry() }
                        }
                    } else if model.comments.isEmpty {
                        EKEmptyState(title: AudioL10n.text("commentsEmptyTitle"), message: AudioL10n.text("commentsEmptyMessage"), systemImage: "text.bubble")
                    } else {
                        Text(AudioL10n.text("commentsHint"))
                            .font(.subheadline).foregroundStyle(EKitapligimPalette.muted)
                            .fixedSize(horizontal: false, vertical: true)
                        ForEach(model.comments) { comment in
                            if let bookID = Int(comment.threadId) {
                                NavigationLink {
                                    AudioRouteDestination(route: .audiobook(bookID))
                                } label: {
                                    commentRow(comment)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("audio.comments.row.\(comment.id)")
                            }
                        }
                        if let message = model.errorMessage {
                            EKInlineError(message: message, retryTitle: L10n.commonRetry) {
                                Task { await model.retry() }
                            }
                        }
                        if model.hasMore {
                            EKLoadMoreButton(isLoading: model.isLoading) { Task { await model.load(reset: false) } }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18).padding(.vertical, 16)
            }
            .accessibilityIdentifier("audio.comments.scroll")
            .refreshable { await model.load(reset: true) }
        }
        .navigationTitle(AudioL10n.text("myAudioComments"))
        .navigationBarTitleDisplayMode(.inline)
        .task(id: container.sessionRevision) {
            model.activate(sessionID: container.sessionRevision, signedIn: container.isSignedIn)
            await model.load(reset: true)
        }
        .onChange(of: container.sessionRevision) { _, sessionID in
            model.activate(sessionID: sessionID, signedIn: container.isSignedIn)
        }
    }

    private func commentRow(_ comment: ForumPostDTO) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Text(comment.threadTitle ?? AudioL10n.text("title"))
                    .font(.headline).fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold)).foregroundStyle(EKitapligimPalette.profileTealDeep)
                    .accessibilityHidden(true)
            }
            Text(EKitapligimFormat.plainText(comment.message))
                .font(.subheadline).fixedSize(horizontal: false, vertical: true)
            if comment.postDate > 0 {
                Text(Date(timeIntervalSince1970: TimeInterval(comment.postDate)), style: .date)
                    .font(.caption).foregroundStyle(EKitapligimPalette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .foregroundStyle(EKitapligimPalette.ink)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .padding(16).ekitapligimCard(radius: 18)
        .accessibilityElement(children: .combine)
    }
}
