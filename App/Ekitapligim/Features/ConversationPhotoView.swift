import SwiftUI
import UIKit
import EkitapligimCore

enum ConversationPhotoSource: Hashable {
    case attachment(conversationID: String, imageID: String)
    case publicURL(URL)
}

@MainActor
private final class ConversationPhotoModel: ObservableObject {
    @Published private(set) var image: UIImage?
    @Published private(set) var failed = false
    private var generation = UUID()

    func clear() { generation = UUID(); image = nil; failed = false }

    func load(_ source: ConversationPhotoSource, repository: ConversationsRepository) async {
        guard !Task.isCancelled else { return }
        clear()
        let generation = self.generation
        do {
            let data: Data
            switch source {
            case .attachment(let conversationID, let imageID):
                data = try await repository.image(conversationID: conversationID, imageID: imageID)
            case .publicURL(let url): data = try await repository.publicImage(url: url)
            }
            try Task.checkCancellation()
            let decoded = await Task.detached(priority: .utility) { try? AgendaPhotoProcessor.jpeg(data) }.value
            guard generation == self.generation, !Task.isCancelled else { return }
            guard let decoded, let image = UIImage(data: decoded) else { throw AgendaMediaError.invalidImage }
            self.image = image
        } catch {
            guard generation == self.generation, !Task.isCancelled else { return }
            failed = true
        }
    }
}

/// Private images use the existing authorized endpoint, bounded transport and in-memory pixels only.
@MainActor
struct ConversationPhotoView: View {
    @EnvironmentObject private var container: AppContainer
    @StateObject private var model = ConversationPhotoModel()
    @State private var retry = 0
    let source: ConversationPhotoSource
    var allowsRetry = true

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.primary.opacity(0.04)
                if let image = model.image {
                    Image(uiImage: image).resizable().scaledToFit()
                        .accessibilityIdentifier("messages.photo.loaded")
                } else if model.failed {
                    VStack(spacing: 8) {
                        Image(systemName: "photo.badge.exclamationmark").accessibilityHidden(true)
                        Text(AgendaMediaL10n.text("image.failed")).font(.caption)
                        if allowsRetry {
                            Button(AgendaMediaL10n.text("image.retry")) { retry += 1 }
                                .frame(minHeight: 44)
                        }
                    }.padding().multilineTextAlignment(.center)
                } else { ProgressView().accessibilityLabel(AgendaMediaL10n.text("image.loading")) }
            }.frame(width: geometry.size.width, height: geometry.size.height)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityLabel(ReadingRoomL10n.text("message.sharedImage"))
        .task(id: LoadKey(source: source, session: container.sessionRevision, retry: retry)) {
            await model.load(source, repository: container.conversations)
        }
        .onChange(of: container.sessionRevision) { _, _ in model.clear() }
        .onChange(of: source) { _, _ in model.clear() }
    }
    private struct LoadKey: Hashable { let source: ConversationPhotoSource; let session: UUID; let retry: Int }
}

@MainActor
struct ConversationPhotoDestination: View {
    let source: ConversationPhotoSource
    var body: some View {
        GeometryReader { geometry in
            ConversationPhotoView(source: source)
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .navigationTitle(ReadingRoomL10n.text("message.sharedImage"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
