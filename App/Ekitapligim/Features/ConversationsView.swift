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
        EKitapligimScreen {
            Group {
                if isLoading && conversations.isEmpty {
                    EKLoadingState(message: L10n.conversationsLoading)
                } else if let errorMessage, conversations.isEmpty {
                    EKErrorState(title: L10n.conversationsUnavailableTitle, message: errorMessage) {
                        Task { await load(reset: true) }
                    }
                } else if conversations.isEmpty {
                    EKEmptyState(
                        title: L10n.conversationsEmptyTitle,
                        message: L10n.conversationsEmptyDescription,
                        systemImage: "envelope.open"
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(conversations.filter { conversation in
                                let blockedParticipants = conversation.participants.filter { participant in
                                    Int(participant.id).map(container.blockedUserIDs.contains) == true
                                }
                                return conversation.participants.count > 2 || blockedParticipants.isEmpty
                            }) { conversation in
                                ZStack(alignment: .topTrailing) {
                                    NavigationLink {
                                        ConversationDetailView(conversationID: conversation.id)
                                    } label: {
                                        ConversationRow(conversation: conversation)
                                            .ekitapligimCard(radius: 16)
                                    }
                                    .buttonStyle(.plain)
                                    if let message = conversation.lastMessage, !message.isMine, let contentID = Int(message.id) {
                                        UGCSafetyMenu(
                                            type: .conversationMessage,
                                            contentID: contentID,
                                            userID: message.userId
                                        ) {
                                            conversations.removeAll { item in
                                                item.participants.contains { Int($0.id) == message.userId }
                                            }
                                        }
                                        .padding(8)
                                    }
                                }
                            }
                            if currentPage < lastPage {
                                EKLoadMoreButton(isLoading: isLoading) {
                                    Task { await load(reset: false) }
                                }
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                    }
                    .refreshable { await load(reset: true) }
                }
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

@MainActor
private struct ConversationRow: View {
    let conversation: ConversationDTO

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Rectangle()
                .fill(conversation.isUnread ? EKitapligimPalette.teal : Color.clear)
                .frame(width: 3)
                .accessibilityHidden(true)

            HStack(alignment: .top, spacing: 12) {
                EKAvatar(
                    urlString: avatarURL,
                    username: avatarName,
                    size: 46,
                    cornerRadius: 14
                )

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(conversation.title)
                            .font(.headline.weight(conversation.isUnread ? .bold : .semibold))
                            .foregroundStyle(EKitapligimPalette.ink)
                            .lineLimit(2)
                        if conversation.isUnread {
                            Circle()
                                .fill(EKitapligimPalette.teal)
                                .frame(width: 7, height: 7)
                                .accessibilityLabel(L10n.notificationsUnread)
                        }
                        Spacer(minLength: 8)
                        if conversation.isStarred {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundStyle(EKitapligimPalette.amber)
                                .accessibilityLabel(L10n.conversationsStarred)
                        }
                        if conversation.lastMessageDate > 0 {
                            Text(EKitapligimFormat.relativeTime(conversation.lastMessageDate))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(EKitapligimPalette.muted)
                                .lineLimit(1)
                        }
                    }

                    if !participantLine.isEmpty {
                        Text(participantLine)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(EKitapligimPalette.tealDark)
                            .lineLimit(1)
                    }

                    if !conversation.preview.isEmpty {
                        Text(conversation.preview)
                            .font(.subheadline)
                            .foregroundStyle(EKitapligimPalette.muted)
                            .lineLimit(2)
                    }

                    EKPill(
                        title: L10n.conversationsReplyCount(conversation.replyCount),
                        systemImage: "arrowshape.turn.up.left",
                        foreground: EKitapligimPalette.muted,
                        background: EKitapligimPalette.surfaceAlt
                    )
                }
            }
            .padding(.leading, 12)
            .padding(.trailing, 14)
            .padding(.vertical, 14)
        }
        .accessibilityElement(children: .combine)
    }

    private var avatarURL: String {
        if let url = conversation.lastMessage?.avatarUrl, !url.isEmpty {
            return url
        }
        return conversation.participants.first?.avatarUrl ?? ""
    }

    private var avatarName: String {
        if !conversation.lastMessageUsername.isEmpty {
            return ForumMessageFormatting.displayUsername(conversation.lastMessageUsername)
        }
        if let name = conversation.participants.first?.username, !name.isEmpty {
            return ForumMessageFormatting.displayUsername(name)
        }
        return ForumMessageFormatting.displayUsername(conversation.starterUsername)
    }

    private var participantLine: String {
        conversationParticipantLine(conversation)
    }
}

@MainActor
struct ConversationDetailView: View {
    @EnvironmentObject private var container: AppContainer
    let conversationID: String

    @State private var detail: ConversationDetailDTO?
    @State private var replyText = ""
    @State private var isLoading = false
    @State private var isSending = false
    @State private var errorMessage: String?
    @FocusState private var isReplyFocused: Bool

    private var visibleMessages: [ConversationMessageDTO] {
        (detail?.messages ?? []).filter { message in
            !container.blockedUserIDs.contains(message.userId)
        }
    }

    var body: some View {
        EKitapligimScreen {
            Group {
                if isLoading && detail == nil {
                    EKLoadingState(message: L10n.conversationsLoading)
                } else if let errorMessage, detail == nil {
                    EKErrorState(title: L10n.conversationsUnavailableTitle, message: errorMessage) {
                        Task { await load() }
                    }
                } else if let detail {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            conversationHero(detail.conversation)
                            ForEach(visibleMessages) { message in
                                ConversationMessageCard(message: message)
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                    }
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        if detail.conversation.canReply {
                            replyComposer
                                .ekPinnedReplyBar()
                        }
                    }
                }
            }
        }
        .navigationTitle(detail?.conversation.title ?? L10n.conversationsMessageTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(L10n.commonDismiss) { isReplyFocused = false }
            }
        }
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

    private func conversationHero(_ conversation: ConversationDTO) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "envelope.open.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(EKitapligimPalette.teal)
                .frame(width: 58, height: 58)
                .background(EKitapligimPalette.tealSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color(hex: 0xD9C79F), lineWidth: 1)
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(conversation.title)
                    .font(.system(.title3, design: .serif).weight(.heavy))
                    .foregroundStyle(EKitapligimPalette.ink)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                if !conversationParticipantLine(conversation).isEmpty {
                    Text(conversationParticipantLine(conversation))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(EKitapligimPalette.tealDark)
                        .lineLimit(2)
                }
                Text(L10n.conversationsReplyCount(conversation.replyCount))
                    .font(.caption)
                    .foregroundStyle(EKitapligimPalette.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .forumHeroSurface(radius: 12)
    }

    private var replyComposer: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextEditor(text: $replyText)
                .focused($isReplyFocused)
                .accessibilityLabel(L10n.conversationsReplyPlaceholder)
                .ekPinnedReplyEditor()
                .padding(10)
                .scrollContentBackground(.hidden)
                .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(hex: isReplyFocused ? 0x087A80 : 0xD7C59C), lineWidth: 1)
                }
                .overlay(alignment: .topLeading) {
                    if replyText.trimmed.isEmpty {
                        Text(L10n.conversationsReplyPlaceholder)
                            .font(.body)
                            .foregroundStyle(EKitapligimPalette.muted)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 18)
                            .allowsHitTesting(false)
                    }
                }
                .onChange(of: replyText) { _, value in replyText = String(value.prefix(10_000)) }

            HStack(alignment: .center) {
                Text("\(replyText.count)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(EKitapligimPalette.muted)
                    .accessibilityHidden(true)
                Spacer(minLength: 0)
                Button {
                    Task { await sendReply() }
                } label: {
                    Group {
                        if isSending {
                            ProgressView().tint(.white)
                        } else {
                            Label(L10n.commonSubmit, systemImage: "paperplane.fill")
                        }
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .background(
                    (isSending || replyText.trimmed.isEmpty)
                        ? EKitapligimPalette.teal.opacity(0.45)
                        : EKitapligimPalette.teal,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .disabled(replyText.trimmed.isEmpty || isSending)
                .accessibilityLabel(L10n.commonSubmit)
            }
        }
        .padding(12)
        .background(.white)
        .overlay(alignment: .top) {
            Rectangle().fill(EKitapligimPalette.border).frame(height: 1)
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

@MainActor
private struct ConversationMessageCard: View {
    let message: ConversationMessageDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                EKAvatar(
                    urlString: message.avatarUrl,
                    username: ForumMessageFormatting.displayUsername(message.username),
                    size: 44,
                    cornerRadius: 12
                )
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(ForumMessageFormatting.displayUsername(message.username))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(EKitapligimPalette.ink)
                            .lineLimit(1)
                        if message.isMine {
                            EKPill(
                                title: L10n.conversationsYou,
                                foreground: EKitapligimPalette.tealDark,
                                background: EKitapligimPalette.tealSoft
                            )
                        }
                    }
                    if message.messageDate > 0 {
                        Text(EKitapligimFormat.relativeTime(message.messageDate))
                            .font(.caption)
                            .foregroundStyle(EKitapligimPalette.muted)
                    }
                }
                Spacer(minLength: 0)
                if !message.isMine, let contentID = Int(message.id) {
                    UGCSafetyMenu(
                        type: .conversationMessage,
                        contentID: contentID,
                        userID: message.userId
                    )
                }
            }

            Rectangle()
                .fill(Color(hex: 0xE9D9BA))
                .frame(height: 1)
                .padding(.vertical, 14)

            ForumMessageBody(message: message.message)
                .textSelection(.enabled)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            message.isMine ? EKitapligimPalette.tealSoft.opacity(0.55) : EKitapligimPalette.paper,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(message.isMine ? EKitapligimPalette.teal.opacity(0.18) : EKitapligimPalette.border)
        }
    }
}

@MainActor
private struct NewConversationView: View {
    @Environment(\.dismiss) private var dismiss
    let submit: (String, String, String) async -> Bool

    @State private var recipient = ""
    @State private var title = ""
    @State private var message = ""
    @State private var isSending = false
    @State private var sendFailed = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case recipient, title, message
    }

    var body: some View {
        NavigationStack {
            EKitapligimScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        labeledField(
                            title: L10n.conversationsRecipient,
                            text: $recipient,
                            focus: .recipient,
                            limit: 50
                        )
                        labeledField(
                            title: L10n.conversationsSubject,
                            text: $title,
                            focus: .title,
                            limit: 100
                        )

                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.conversationsMessageBody)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(EKitapligimPalette.muted)
                            TextEditor(text: $message)
                                .focused($focusedField, equals: .message)
                                .accessibilityLabel(L10n.conversationsMessageBody)
                                .frame(minHeight: 160)
                                .scrollContentBackground(.hidden)
                                .overlay(alignment: .topLeading) {
                                    if message.trimmed.isEmpty {
                                        Text(L10n.conversationsMessageBody)
                                            .foregroundStyle(EKitapligimPalette.muted)
                                            .padding(.top, 8)
                                            .padding(.leading, 4)
                                            .allowsHitTesting(false)
                                    }
                                }
                                .onChange(of: message) { _, value in message = String(value.prefix(10_000)) }
                            Text("\(message.count)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(EKitapligimPalette.muted)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .padding(14)
                        .ekitapligimCard(radius: 14)

                        if sendFailed {
                            Text(L10n.conversationsSendFailed)
                                .font(.footnote)
                                .foregroundStyle(EKitapligimPalette.danger)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(EKitapligimPalette.warningBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle(L10n.conversationsNew)
            .navigationBarTitleDisplayMode(.inline)
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
                    .fontWeight(.semibold)
                    .disabled(recipient.trimmed.isEmpty || title.trimmed.isEmpty || message.trimmed.isEmpty || isSending)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(L10n.commonDismiss) { focusedField = nil }
                }
            }
        }
    }

    private func labeledField(title: String, text: Binding<String>, focus: Field, limit: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(EKitapligimPalette.muted)
            TextField(title, text: text)
                .focused($focusedField, equals: focus)
                .textInputAutocapitalization(focus == .recipient ? .never : .sentences)
                .autocorrectionDisabled(focus == .recipient)
                .onChange(of: text.wrappedValue) { _, value in
                    text.wrappedValue = String(value.prefix(limit))
                }
        }
        .padding(14)
        .ekitapligimCard(radius: 14)
    }
}

private func conversationParticipantLine(_ conversation: ConversationDTO) -> String {
    let names = conversation.participants
        .map { $0.username.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
    if names.count >= 2 {
        return names.joined(separator: " · ")
    }
    if let only = names.first {
        return only
    }
    let starter = conversation.starterUsername.trimmingCharacters(in: .whitespacesAndNewlines)
    let last = conversation.lastMessageUsername.trimmingCharacters(in: .whitespacesAndNewlines)
    if !starter.isEmpty, !last.isEmpty, starter.caseInsensitiveCompare(last) != .orderedSame {
        return "\(starter) · \(last)"
    }
    if !starter.isEmpty { return starter }
    return last
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
