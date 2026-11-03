import SwiftUI
import UIKit
import ImageIO
import EkitapligimCore

@MainActor
private final class AgendaImageModel: ObservableObject {
    @Published private(set) var image: UIImage?
    @Published private(set) var failed = false

    func load(repository: BookAgendaRepository, postID: String, attachment: BookAgendaAttachmentDTO) async {
        image = nil
        failed = false
        do {
            let data = try await repository.image(postID: postID, attachment: attachment)
            let decoded = await Task.detached(priority: .utility) { () -> Data? in
                // Reuse the bounded, orientation-aware pixel conversion for remote images.
                try? AgendaPhotoProcessor.jpeg(data)
            }.value
            try Task.checkCancellation()
            guard let decoded, let image = UIImage(data: decoded) else { throw AgendaMediaError.invalidImage }
            self.image = image
        } catch {
            guard !Task.isCancelled else { return }
            failed = true
        }
    }
}

/// The caller owns the slot. Photos always fit inside it, with no stretching or book-cover fallback.
@MainActor
struct AgendaPhotoView: View {
    @EnvironmentObject private var container: AppContainer
    @StateObject private var model = AgendaImageModel()
    let postID: String
    let attachment: BookAgendaAttachmentDTO
    var allowsRetry = true
    @State private var retry = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.primary.opacity(0.035)
                if let image = model.image {
                    AgendaPhotoPixels(image: image)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                } else if model.failed {
                    VStack(spacing: 8) {
                        Image(systemName: "photo.badge.exclamationmark").font(.title2)
                        Text(AgendaMediaL10n.text("image.failed")).font(.caption).multilineTextAlignment(.center)
                        if allowsRetry {
                            Button(AgendaMediaL10n.text("image.retry")) { retry += 1 }
                                .font(.caption.weight(.semibold)).frame(minHeight: 44)
                                .accessibilityIdentifier("agenda.image.retry.\(postID).\(attachment.id)")
                        }
                    }.padding(10).foregroundStyle(.secondary)
                } else {
                    ProgressView().accessibilityLabel(AgendaMediaL10n.text("image.loading"))
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L10n.agendaPostImage)
        .accessibilityIdentifier("agenda.image.\(postID).\(attachment.id)")
        .task(id: "\(container.sessionRevision):\(postID):\(attachment.id):\(attachment.url):\(retry)") {
            await model.load(repository: container.bookAgenda, postID: postID, attachment: attachment)
        }
    }
}

struct AgendaPhotoPixels: View {
    let image: UIImage
    var body: some View {
        Image(uiImage: image).resizable().scaledToFit()
    }
}

@MainActor
struct AgendaPhotosView: View {
    let post: BookAgendaPostDTO
    @State private var selection = 0

    var body: some View {
        if let first = post.attachments.first {
            VStack(spacing: 8) {
                if post.attachments.count == 1 {
                    AgendaPhotoView(postID: post.id, attachment: first)
                        .aspectRatio(min(1.8, max(0.8, first.aspectRatio)), contentMode: .fit)
                } else {
                    TabView(selection: $selection) {
                        ForEach(Array(post.attachments.enumerated()), id: \.element.id) { index, attachment in
                            AgendaPhotoView(postID: post.id, attachment: attachment).tag(index)
                                .padding(.bottom, 28)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))
                    .indexViewStyle(.page(backgroundDisplayMode: .always))
                    .frame(height: 300)
                    .accessibilityLabel(AgendaMediaL10n.text("images.gallery"))
                }
            }
        }
    }
}
