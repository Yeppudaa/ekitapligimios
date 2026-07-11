import SwiftUI
import EkitapligimCore

@MainActor
struct ConversationsView: View {
    @EnvironmentObject private var container: AppContainer
    @State private var conversations: [ConversationDTO] = []
    @State private var currentPage = 0
    @State private var lastPage = 1
    @State private var isLoading = false
    @State private var showComposer = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading && conversations.isEmpty {
                ProgressView(L10n.conversationsLoading)
            } else if let errorMessage, conversations.isEmpty {
                ContentUnavailableView(L10n.conversationsUnavailableTitle, systemImage: "wifi.exclamationmark", description: Text(errorMessage))
            } else if conversations.isEmpty {
                ContentUnavailableView(L10n.conversationsEmptyTitle, systemImage: "envelope.open", description: Text(L10n.conversationsEmptyDescription))
            } else {
                List {
                    ForEach(conversations) { conversation in
                        NavigationLink {
                            ConversationDetailView(conversationID: conversation.id)
                        } label: {
                            ConversationRow(conversation: conversation)
                        }
                    }
                    if currentPage < lastPage {
                        Button(L10n.commonLoadMore) { Task { await load(reset: false) } }
                            .disabled(isLoading)
                    }
                }
                .refreshable { await load(reset: true) }
            }
        }
        .navigationTitle(L10n.conversationsTitle)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showComposer = true } label: {
                    Image(systemName: "square.and.pencil")
                }
                .accessibilityLabel(L10n.conversationsNew)
            }
        }
        .task { await load(reset: true) }
        .sheet(isPresented: $showComposer) {
            NewConversationView { recipient, title, message in
                do {
                    _ = try await container.conversations.create(recipient: recipient, title: title, message: message)
                    await load(reset: true)
                    return true
                } catch {
                    return false
                }
            }
        }
    }

    private func load(reset: Bool) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let result = try await container.conversations.conversations(page: reset ? 1 : currentPage + 1)
            conversations = reset ? result.items : conversations + result.items.filter { item in
                !conversations.contains(where: { $0.id == item.id })
            }
            currentPage = result.currentPage
            lastPage = result.lastPage
        } catch {
            errorMessage = L10n.conversationsLoadFailed
        }
    }
}

private struct ConversationRow: View {
    let conversation: ConversationDTO

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: conversation.isUnread ? "envelope.badge.fill" : "envelope")
                .foregroundStyle(conversation.isUnread ? Color.accentColor : .secondary)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.title)
                        .font(.headline)
                        .fontWeight(conversation.isUnread ? .bold : .regular)
                    Spacer()
                    if conversation.lastMessageDate > 0 {
                        Text(Date(timeIntervalSince1970: TimeInterval(conversation.lastMessageDate)), format: .dateTime.day().month(.abbreviated))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if !conversation.preview.isEmpty {
                    Text(conversation.preview)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Text(L10n.conversationsReplyCount(conversation.replyCount))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

@MainActor
private struct ConversationDetailView: View {
    @EnvironmentObject private var container: AppContainer
    let conversationID: String

    @State private var detail: ConversationDetailDTO?
    @State private var replyText = ""
    @State private var isLoading = false
    @State private var isSending = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if isLoading && detail == nil {
                    ProgressView(L10n.conversationsLoading)
                } else if let errorMessage, detail == nil {
                    ContentUnavailableView(L10n.conversationsUnavailableTitle, systemImage: "wifi.exclamationmark", description: Text(errorMessage))
                } else if let detail {
                    List(detail.messages) { message in
                        MessageBubble(message: message)
                            .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                }
            }

            if detail?.conversation.canReply == true {
                HStack(alignment: .bottom, spacing: 8) {
                    TextField(L10n.conversationsReplyPlaceholder, text: $replyText, axis: .vertical)
                        .lineLimit(1...4)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: replyText) { _, value in replyText = String(value.prefix(10_000)) }
                    Button {
                        Task { await sendReply() }
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .frame(width: 32, height: 32)
                    }
                    .disabled(replyText.trimmed.isEmpty || isSending)
                    .accessibilityLabel(L10n.commonSubmit)
                }
                .padding(10)
                .background(.bar)
            }
        }
        .navigationTitle(detail?.conversation.title ?? L10n.conversationsMessageTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .alert(
            L10n.conversationsSendFailedTitle,
            isPresented: Binding(
                get: { errorMessage != nil && detail != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button(L10n.commonClose) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? L10n.conversationsSendFailed)
        }
    }

    private func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            detail = try await container.conversations.conversation(id: conversationID)
        } catch {
            errorMessage = L10n.conversationsLoadFailed
        }
    }

    private func sendReply() async {
        let message = replyText.trimmed
        guard !message.isEmpty, !isSending else { return }
        isSending = true
        defer { isSending = false }
        do {
            _ = try await container.conversations.reply(id: conversationID, message: message)
            replyText = ""
            await load()
        } catch {
            errorMessage = L10n.conversationsSendFailed
        }
    }
}

private struct MessageBubble: View {
    let message: ConversationMessageDTO

    var body: some View {
        HStack {
            if message.isMine { Spacer(minLength: 44) }
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(message.username).font(.caption.weight(.semibold))
                    Spacer()
                    if message.messageDate > 0 {
                        Text(Date(timeIntervalSince1970: TimeInterval(message.messageDate)), format: .dateTime.hour().minute())
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(message.message)
                    .font(.body)
                    .textSelection(.enabled)
            }
            .padding(10)
            .background(message.isMine ? Color.accentColor.opacity(0.14) : Color.secondary.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            if !message.isMine { Spacer(minLength: 44) }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct NewConversationView: View {
    @Environment(\.dismiss) private var dismiss
    let submit: (String, String, String) async -> Bool

    @State private var recipient = ""
    @State private var title = ""
    @State private var message = ""
    @State private var isSending = false
    @State private var sendFailed = false

    var body: some View {
        NavigationStack {
            Form {
                TextField(L10n.conversationsRecipient, text: $recipient)
                    .onChange(of: recipient) { _, value in recipient = String(value.prefix(50)) }
                TextField(L10n.conversationsSubject, text: $title)
                    .onChange(of: title) { _, value in title = String(value.prefix(100)) }
                TextField(L10n.conversationsMessageBody, text: $message, axis: .vertical)
                    .lineLimit(4...10)
                    .onChange(of: message) { _, value in message = String(value.prefix(10_000)) }
                if sendFailed {
                    Text(L10n.conversationsSendFailed)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle(L10n.conversationsNew)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.commonCancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSending ? L10n.conversationsSending : L10n.commonSubmit) {
                        Task {
                            isSending = true
                            sendFailed = false
                            let sent = await submit(recipient.trimmed, title.trimmed, message.trimmed)
                            isSending = false
                            if sent { dismiss() } else { sendFailed = true }
                        }
                    }
                    .disabled(recipient.trimmed.isEmpty || title.trimmed.isEmpty || message.trimmed.isEmpty || isSending)
                }
            }
        }
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
