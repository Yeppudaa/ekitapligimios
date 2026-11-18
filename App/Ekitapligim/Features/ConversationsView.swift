import SwiftUI
import EkitapligimCore

@MainActor
struct ConversationsView: View {
    @EnvironmentObject private var container: AppContainer
    var body: some View { ConversationInboxView().id(container.sessionRevision) }
}

@MainActor
private struct ConversationInboxView: View {
    @Environment(\.colorScheme) private var scheme
    private var style: ReadingRoomStyle { ReadingRoomStyle(scheme: scheme) }
    @EnvironmentObject private var container: AppContainer
    @StateObject private var model = ConversationInboxModel()
    @State private var showComposer = false

    private var visibleConversations: [ConversationDTO] {
        model.conversations.filter { conversation in
            let blocked = conversation.participants.contains { participant in
                Int(participant.id).map(container.blockedUserIDs.contains) == true
            }
            return conversation.participants.count > 2 || !blocked
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 15) {
                    Label(CommunityDesignL10n.text("messages.eyebrow"), systemImage: "envelope.fill")
                        .font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(style.accent)
                    Text(CommunityDesignL10n.text("messages.hero"))
                        .font(.system(.largeTitle, design: .serif).bold()).foregroundStyle(style.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(CommunityDesignL10n.text("messages.subtitle"))
                        .font(.subheadline).foregroundStyle(style.muted)
                }
                .padding(22).frame(maxWidth: .infinity, alignment: .leading)
                .background(LinearGradient(colors: [style.soft, style.paper],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: 26))
                .overlay { RoundedRectangle(cornerRadius: 26).strokeBorder(style.border) }

                if model.isLoading && model.conversations.isEmpty {
                    ProgressView(L10n.conversationsLoading).frame(maxWidth: .infinity).padding(24)
                } else if let errorMessage = model.errorMessage, model.conversations.isEmpty {
                    EKErrorState(title: L10n.conversationsUnavailableTitle, message: errorMessage) {
                        Task { await load(reset: true) }
                    }
                } else if visibleConversations.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                            Text(L10n.conversationsEmptyTitle).font(.title3.bold()).foregroundStyle(style.ink)
                            Text(L10n.conversationsEmptyDescription).font(.subheadline).foregroundStyle(style.muted)
                            Button { showComposer = true } label: {
                                Label(L10n.conversationsNew, systemImage: "square.and.pencil")
                            }.buttonStyle(ReadingRoomButtonStyle())
                    }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
                        .background(style.card, in: RoundedRectangle(cornerRadius: 24))
                        .overlay { RoundedRectangle(cornerRadius: 24).strokeBorder(style.border) }
                } else {
                    ForEach(visibleConversations) { conversation in
                        ZStack(alignment: .topTrailing) {
                            ConversationRow(conversation: conversation)
                            if let message = conversation.lastMessage, !message.isMine, let contentID = Int(message.id) {
                                UGCSafetyMenu(type: .conversationMessage, contentID: contentID, userID: message.userId) {
                                    model.removeParticipant(message.userId)
                                }.padding(12)
                            }
                        }
                    }
                }
                if let errorMessage = model.errorMessage, !model.conversations.isEmpty { EKInlineError(message: errorMessage) }
                if model.hasMore {
                    EKLoadMoreButton(isLoading: model.isLoading) { Task { await load(reset: false) } }
                }
            }
            .frame(maxWidth: 760).padding(18).frame(maxWidth: .infinity)
            .floatingLauncherClearance()
        }
        .background(style.page.ignoresSafeArea())
        .refreshable { await load(reset: true) }
        .navigationTitle(L10n.conversationsTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { Task { await load(reset: true) } } label: {
                    Image(systemName: "arrow.clockwise").frame(width: 44, height: 44)
                }.disabled(model.isLoading).accessibilityLabel(L10n.commonRefresh).accessibilityIdentifier("messages.refresh")
                Button { showComposer = true } label: {
                    Image(systemName: "square.and.pencil").frame(width: 44, height: 44)
                }.accessibilityLabel(L10n.conversationsNew).accessibilityIdentifier("messages.compose")
            }
        }
        .task { await load(reset: true) }
        .onChange(of: container.sessionRevision) { _, _ in model.invalidate(); showComposer = false }
        .sheet(isPresented: $showComposer) {
            NewConversationView { recipient, title, message in
                let revision = container.sessionRevision
                do {
                    let result = try await container.conversations.create(recipient: recipient, title: title, message: message)
                    guard revision == container.sessionRevision, !Task.isCancelled, result.success else { return false }
                    await load(reset: true)
                    return true
                } catch { return false }
            }
        }
    }

    private func load(reset: Bool) async {
        let repository = container.conversations
        await model.load(reset: reset) { try await repository.conversations(page: $0) }
    }
}

@MainActor
private struct ConversationRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var scheme
    let conversation: ConversationDTO
    private var style: ReadingRoomStyle { ReadingRoomStyle(scheme: scheme) }
    private var preview: String {
        if let rich = conversation.lastMessage?.richMessage, !rich.isEmpty { return rich }
        if let message = conversation.lastMessage?.message, !message.isEmpty { return message }
        return conversation.preview
    }

    private var hasSafetyMenu: Bool {
        guard let message = conversation.lastMessage else { return false }
        return !message.isMine && Int(message.id) != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            NavigationLink { ConversationDetailView(conversationID: conversation.id) } label: {
            (dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                : AnyLayout(HStackLayout(alignment: .top, spacing: 13))) {
                EKAvatar(urlString: avatarURL, username: avatarName, size: 52, cornerRadius: 18,
                         background: style.soft, foreground: style.accent)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(conversation.title).font(.headline.weight(conversation.isUnread ? .bold : .semibold))
                        .foregroundStyle(style.ink)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    if !participantLine.isEmpty {
                        Text(participantLine).font(.subheadline.weight(.medium)).foregroundStyle(style.accent)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, hasSafetyMenu ? 44 : 0)
            }
            }.buttonStyle(.plain)
                .accessibilityIdentifier("messages.conversation.\(conversation.id)")
            ConversationRichContent(raw: preview, previewConversationID: conversation.id,
                                    images: conversation.lastMessage?.images ?? [])
            NavigationLink { ConversationDetailView(conversationID: conversation.id) } label: {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { metadata }
                VStack(alignment: .leading, spacing: 7) { metadata }
            }.frame(minHeight: 44, alignment: .leading)
            }.buttonStyle(.plain)
        }
        .padding(19).frame(maxWidth: .infinity, alignment: .leading)
        .background(style.card, in: RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(conversation.isUnread ? style.accent.opacity(0.6) : style.border,
                              lineWidth: conversation.isUnread ? 1.5 : 1)
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder private var metadata: some View {
        if conversation.isUnread {
            Label(L10n.notificationsUnread, systemImage: "circle.fill")
                .font(.caption.weight(.semibold)).foregroundStyle(style.accent)
        }
        if conversation.lastMessageDate > 0 {
            Text(EKitapligimFormat.relativeTime(conversation.lastMessageDate)).font(.caption)
                .foregroundStyle(style.muted)
        }
        if conversation.replyCount > 0 {
            Text(L10n.conversationsReplyCount(conversation.replyCount)).font(.caption).foregroundStyle(style.muted)
        }
        if conversation.isStarred {
            Image(systemName: "star.fill").foregroundStyle(EKitapligimPalette.amber)
                .accessibilityLabel(L10n.conversationsStarred)
        }
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
    var body: some View {
        ConversationContentView(conversationID: conversationID)
            .id(conversationID + "|" + container.sessionRevision.uuidString)
    }
}

@MainActor
private struct ConversationContentView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.replyViewportHeight) private var replyViewportHeight
    let conversationID: String
    @Environment(\.colorScheme) private var scheme
    private var style: ReadingRoomStyle { ReadingRoomStyle(scheme: scheme) }

    @StateObject private var model = ConversationDetailModel()
    @FocusState private var isReplyFocused: Bool

    private var visibleMessages: [ConversationMessageDTO] {
        (model.detail?.messages ?? []).filter { message in
            !container.blockedUserIDs.contains(message.userId)
        }
    }

    var body: some View {
        ZStack {
            style.page.ignoresSafeArea()
            Group {
                if model.isLoading && model.detail == nil {
                    EKLoadingState(message: L10n.conversationsLoading)
                } else if let errorMessage = model.errorMessage, model.detail == nil {
                    EKErrorState(title: L10n.conversationsUnavailableTitle, message: errorMessage) {
                        Task { await load() }
                    }
                } else if let detail = model.detail {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            conversationHero(detail.conversation)
                            if model.hasEarlier {
                                Button(ReadingRoomL10n.text("message.earlier")) {
                                    Task { await load(earlier: true) }
                                }.buttonStyle(ReadingRoomButtonStyle())
                                    .disabled(model.isLoadingEarlier)
                                    .accessibilityIdentifier("messages.earlier")
                            }
                            ForEach(visibleMessages) { message in
                                ConversationMessageCard(message: message)
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                    }
                    .accessibilityIdentifier("conversation-messages-scroll")
                    .scrollDismissesKeyboard(.interactively)
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        if detail.conversation.canReply {
                            replyComposer
                                .ekPinnedReplyBar()
                        }
                    }
                }
            }
        }
        .navigationTitle(model.detail?.conversation.title ?? L10n.conversationsMessageTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(L10n.commonDismiss) { isReplyFocused = false }
                    .accessibilityIdentifier("keyboard-dismiss")
            }
        }
        .task { await load() }
        .onChange(of: container.sessionRevision) { _, _ in model.invalidate() }
        .onDisappear { isReplyFocused = false }
        .alert(
            // One alert reports both a failed reply and a failed earlier-page load.
            model.errorMessage == L10n.conversationsSendFailed ? L10n.conversationsSendFailedTitle : L10n.conversationsUnavailableTitle,
            isPresented: Binding(
                get: { model.errorMessage != nil && model.detail != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )
        ) {
            Button(L10n.commonClose) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? L10n.conversationsSendFailed)
        }
    }

    private func conversationHero(_ conversation: ConversationDTO) -> some View {
        (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14)) : AnyLayout(HStackLayout(alignment: .top, spacing: 14))) {
            Image(systemName: "envelope.open.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(EKitapligimPalette.teal)
                .frame(width: 58, height: 58)
                .background(style.soft, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color(hex: 0xD9C79F), lineWidth: 1)
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(conversation.title)
                    .font(.system(.title3, design: .serif).weight(.heavy))
                    .foregroundStyle(style.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                if !conversationParticipantLine(conversation).isEmpty {
                    Text(conversationParticipantLine(conversation))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(style.accent)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(L10n.conversationsReplyCount(conversation.replyCount))
                    .font(.caption)
                    .foregroundStyle(style.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(style.soft, in: RoundedRectangle(cornerRadius: 24))
        .overlay { RoundedRectangle(cornerRadius: 24).strokeBorder(style.border) }
    }

    private var usesCompactReply: Bool { replyViewportHeight < 300 }

    private var replyComposer: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !usesCompactReply && dynamicTypeSize.isAccessibilitySize && model.draft.trimmed.isEmpty {
                Text(L10n.conversationsReplyPlaceholder)
                    .font(.body)
                    .foregroundStyle(style.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityHidden(true)
            }
            // AnyLayout preserves editor focus when the keyboard changes the viewport.
            (usesCompactReply
                ? AnyLayout(HStackLayout(alignment: .bottom, spacing: 8))
                : AnyLayout(VStackLayout(alignment: .leading, spacing: 10))) {
                replyEditor
                HStack(alignment: .center) {
                    if !usesCompactReply {
                        Text("\(model.draft.count)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(style.muted)
                            .accessibilityHidden(true)
                        Spacer(minLength: 0)
                    }
                    replySendButton
                }
                .fixedSize(horizontal: usesCompactReply, vertical: true)
            }
        }
        .padding(usesCompactReply ? 8 : 12)
        .background(style.paper)
        .overlay(alignment: .top) {
            Rectangle().fill(style.border).frame(height: 1)
        }
    }

    private var replyEditor: some View {
        TextEditor(text: $model.draft)
            .foregroundStyle(style.ink)
            .focused($isReplyFocused)
            .accessibilityLabel(L10n.conversationsReplyPlaceholder)
            .accessibilityIdentifier("conversation-reply-input")
            .ekPinnedReplyEditor()
            .padding(usesCompactReply ? 4 : 10)
            .scrollContentBackground(.hidden)
            .background(style.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isReplyFocused ? style.accent : style.border, lineWidth: 1)
            }
            .overlay(alignment: .topLeading) {
                if !usesCompactReply && !dynamicTypeSize.isAccessibilitySize && model.draft.trimmed.isEmpty {
                    Text(L10n.conversationsReplyPlaceholder)
                        .font(.body)
                        .foregroundStyle(style.muted)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 18)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .onChange(of: model.draft) { _, value in model.draft = String(value.prefix(10_000)) }
            .frame(maxWidth: .infinity)
    }

    private var replySendButton: some View {
        Button {
            Task { await sendReply() }
        } label: {
            Group {
                if model.isSending {
                    ProgressView().tint(.white)
                } else if usesCompactReply {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 17, weight: .bold))
                        .accessibilityHidden(true)
                } else {
                    Label(L10n.commonSubmit, systemImage: "paperplane.fill")
                }
            }
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, usesCompactReply ? 0 : 16)
            .padding(.vertical, usesCompactReply ? 0 : 10)
            .frame(minWidth: 44, minHeight: 44)
        }
        .background(
            (model.isSending || model.draft.trimmed.isEmpty)
                ? EKitapligimPalette.teal.opacity(0.45)
                : EKitapligimPalette.teal,
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .disabled(model.draft.trimmed.isEmpty || model.isSending)
        .accessibilityLabel(L10n.commonSubmit)
        .accessibilityIdentifier("conversation-reply-send")
    }

    private func load(earlier: Bool = false) async {
        let repository = container.conversations
        let revision = container.sessionRevision
        let loaded = await model.load(id: conversationID, earlier: earlier) {
            try await repository.conversation(id: conversationID, page: $0)
        }
        if loaded, !earlier, revision == container.sessionRevision, !Task.isCancelled, let id = Int(conversationID) {
            try? await container.notificationReadSync.markConversationRead(id)
        }
    }

    private func sendReply() async {
        let repository = container.conversations
        await model.send(id: conversationID) { try await repository.reply(id: conversationID, message: $0) }
    }
}

@MainActor
private struct ConversationMessageCard: View {
    @Environment(\.colorScheme) private var scheme
    private var style: ReadingRoomStyle { ReadingRoomStyle(scheme: scheme) }
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let message: ConversationMessageDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                MemberProfileLink(memberID: message.userId) {
                    HStack(alignment: .center, spacing: 12) {
                        EKAvatar(
                            urlString: message.avatarUrl,
                            username: ForumMessageFormatting.displayUsername(message.username),
                            size: 44,
                            cornerRadius: 12
                        )
                        VStack(alignment: .leading, spacing: 4) {
                            (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6)) : AnyLayout(HStackLayout(spacing: 6))) {
                                Text(ForumMessageFormatting.displayUsername(message.username))
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(style.ink)
                                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
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
                                    .foregroundStyle(style.muted)
                            }
                        }
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
                .fill(style.border)
                .frame(height: 1)
                .padding(.vertical, 14)

            ConversationRichContent(raw: message.richMessage.flatMap { $0.isEmpty ? nil : $0 } ?? message.message,
                                    conversationID: String(message.conversationId), images: message.images)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            message.isMine ? style.soft : style.card,
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(style.border)
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
                                .accessibilityIdentifier("conversation-new-message-input")
                                .frame(minHeight: 160, maxHeight: 240)
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
                        .background(.white, in: RoundedRectangle(cornerRadius: 20))
                        .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(CommunityStyle.border) }

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
                .scrollDismissesKeyboard(.interactively)
                .disabled(isSending)
            }
            .navigationTitle(L10n.conversationsNew)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.commonCancel) { dismiss() }.disabled(isSending)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSending ? L10n.conversationsSending : L10n.commonSubmit) {
                        Task {
                            guard !isSending else { return }
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
                        .accessibilityIdentifier("keyboard-dismiss")
                }
            }
        }
        .interactiveDismissDisabled(isSending)
        .onDisappear { focusedField = nil }
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
        .background(.white, in: RoundedRectangle(cornerRadius: 20))
                        .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(CommunityStyle.border) }
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
