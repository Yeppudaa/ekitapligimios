import SwiftUI
import EkitapligimCore

@MainActor
struct ConversationRichContent: View {
    @Environment(\.colorScheme) private var scheme
    let previewConversationID: String?
    let conversationID: String?
    let images: [ConversationImageDTO]
    private let content: ConversationContentPresentation

    init(raw: String, previewConversationID: String? = nil, conversationID: String? = nil,
         images: [ConversationImageDTO] = []) {
        self.previewConversationID = previewConversationID
        self.conversationID = conversationID
        self.images = images
        content = ConversationContentPresentation(raw)
    }
    private var links: [ConversationLinkPresentation] {
        if previewConversationID != nil {
            return (content.links.first(where: { $0.bookID != nil }) ?? content.links.first).map { [$0] } ?? []
        }
        return content.links
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !content.text.isEmpty || links.isEmpty {
                if let id = previewConversationID {
                    NavigationLink { ConversationDetailView(conversationID: id) } label: { caption }
                        .buttonStyle(.plain)
                } else { caption.textSelection(.enabled) }
            }
            ForEach(links) { link in
                ConversationLinkCard(link: link, compact: previewConversationID != nil)
            }
            if let id = conversationID ?? previewConversationID {
                ForEach(visibleImages) { image in
                    let source = ConversationPhotoSource.attachment(conversationID: id, imageID: image.id)
                    NavigationLink { ConversationPhotoDestination(source: source) } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            ConversationPhotoView(source: source, allowsRetry: false).frame(height: 180)
                            Label(ReadingRoomL10n.text("message.openImage"), systemImage: "arrow.up.right")
                                .font(.caption.weight(.semibold)).frame(minHeight: 44)
                        }
                    }.buttonStyle(.plain)
                        .accessibilityLabel(ReadingRoomL10n.text("message.openImage"))
                        .accessibilityIdentifier("messages.image.\(image.id)")
                }
            }
        }
    }

    private var visibleImages: [ConversationImageDTO] {
        var ids = Set<String>()
        let valid = images.filter { Int($0.id).map { $0 > 0 } == true && ids.insert($0.id).inserted }
        return Array(valid.prefix(previewConversationID == nil ? 10 : 1))
    }

    private var caption: some View {
        Text(content.text.isEmpty ? ReadingRoomL10n.text("message.openConversation") : content.text)
            .font(.subheadline).lineSpacing(3)
            .foregroundStyle(ReadingRoomStyle(scheme: scheme).muted)
            .lineLimit(previewConversationID == nil ? nil : 3)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

@MainActor
final class ConversationBookPreviewModel: ObservableObject {
    @Published private(set) var book: BookDTO?
    private var generation = UUID()

    func load(id: Int?, repository: any BookRepositoryProtocol) async {
        guard !Task.isCancelled else { return }
        let current = UUID()
        generation = current
        book = nil
        guard let id else { return }
        do {
            let result = try await repository.book(id: id)
            guard generation == current, !Task.isCancelled, result.id == String(id) else { return }
            book = result
        } catch {
            // A private/deleted/unavailable book keeps a neutral card and its real destination.
        }
    }
}

@MainActor
struct ConversationLinkCard: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.openURL) private var openURL
    @StateObject private var model = ConversationBookPreviewModel()
    let link: ConversationLinkPresentation
    var compact = false
    private var style: ReadingRoomStyle { ReadingRoomStyle(scheme: scheme) }
    private var kind: String { link.bookID != nil ? "book" : link.isImage ? "image" : "link" }
    private var title: String {
        if link.bookID != nil { return model.book?.title ?? ReadingRoomL10n.text("message.sharedBook") }
        if link.isImage { return ReadingRoomL10n.text("message.sharedImage") }
        return link.url.host ?? ReadingRoomL10n.text("message.sharedLink")
    }
    private var actionTitle: String {
        ReadingRoomL10n.text(link.bookID != nil ? "message.openBook" : link.isImage ? "message.openImage" : "message.openLink")
    }

    var body: some View {
        destination
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(title). \(actionTitle)")
            .accessibilityIdentifier("messages.preview.\(kind).\(link.bookID.map(String.init) ?? "link")")
            .task(id: "\(container.sessionRevision)|\(link.id)") {
                await model.load(id: link.bookID, repository: container.books)
            }
    }

    @ViewBuilder private var destination: some View {
        if let id = link.bookID {
            NavigationLink { BookDetailDestination(bookIDString: String(id)) } label: { card }
        } else if let image = link.inlineImageURL {
            NavigationLink { ConversationPhotoDestination(source: .publicURL(image)) } label: { card }
        } else {
            Button {
                if let route = link.route { container.open(route: route) }
                else { openURL(link.url) }
            } label: { card }
            .accessibilityLabel("\(title). \(actionTitle)")
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !compact, let imageURL = link.inlineImageURL {
                ConversationPhotoView(source: .publicURL(imageURL), allowsRetry: false)
                .frame(maxWidth: .infinity).frame(height: 170)
                .background(style.soft, in: RoundedRectangle(cornerRadius: 12))
                .accessibilityHidden(true)
            }
            (typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout(alignment: .center, spacing: 12))) {
                thumbnail
                VStack(alignment: .leading, spacing: 6) {
                    Text(ReadingRoomL10n.text("message.\(kind)"))
                        .font(.caption2.weight(.semibold)).tracking(1).foregroundStyle(style.accent)
                    Text(title).font(.system(.headline, design: .serif)).foregroundStyle(style.ink)
                        .lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                    if let author = model.book?.author, !author.isEmpty {
                        Text(author).font(.caption).foregroundStyle(style.muted)
                            .lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                    }
                    Label(actionTitle, systemImage: "arrow.right")
                        .font(.caption.weight(.semibold)).foregroundStyle(style.accent).padding(.top, 2)
                }.fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [style.soft, style.paper], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(style.border) }
        .contentShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder private var thumbnail: some View {
        if link.bookID != nil {
            EKitapligimRemoteCover(urlString: model.book?.coverUrl ?? "", title: title, author: model.book?.author ?? "")
                .frame(width: 52, height: 78).clipShape(RoundedRectangle(cornerRadius: 5))
                .accessibilityHidden(true)
        } else {
            Image(systemName: link.isImage ? "photo" : "link")
                .font(.title2).foregroundStyle(style.accent)
                .frame(width: 48, height: 54).background(style.soft, in: RoundedRectangle(cornerRadius: 12))
                .accessibilityHidden(true)
        }
    }
}
