import SwiftUI
import EkitapligimCore

/// Okur Sohbeti — room tabs, message bubbles and the 5 second `after_id` poll used by Android.
@MainActor
struct ChatView: View {
    @EnvironmentObject private var container: AppContainer
    var initialRoomID: String?

    @State private var rooms: [ChatRoomDTO] = []
    @State private var capabilities = ChatCapabilitiesDTO()
    @State private var selectedRoomID: String?
    @State private var messages: [ChatMessageDTO] = []
    @State private var oldestID: String?
    @State private var newestID: String?
    @State private var hasOlder = false
    @State private var draft = ""
    @State private var isLoadingRooms = false
    @State private var isLoadingMessages = false
    @State private var isLoadingOlder = false
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var sendError: String?
    @State private var showingLogin = false
    @State private var pollTask: Task<Void, Never>?

    private static let pollInterval: Duration = .seconds(5)

    private var selectedRoom: ChatRoomDTO? {
        rooms.first { $0.id == selectedRoomID }
    }

    private var canSend: Bool {
        container.isSignedIn && (selectedRoom?.canSend ?? false) && !(selectedRoom?.isReadOnly ?? false)
    }

    var body: some View {
        ZStack {
            EKitapligimPageBackground()
            VStack(spacing: 0) {
                header
                if !rooms.isEmpty {
                    roomTabs
                }
                Divider().overlay(EKitapligimPalette.chatBorder)
                transcript
                composer
            }
        }
        .navigationTitle(L10n.chatTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await loadMessages(reset: true) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel(L10n.chatRefresh)
            }
        }
        .sheet(isPresented: $showingLogin) { LoginView() }
        .task { await loadRooms() }
        .onDisappear { stopPolling() }
    }

    // MARK: Başlık

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "bubble.left.and.text.bubble.right.fill")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(.white.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(selectedRoom?.name ?? L10n.chatTitle)
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(statusText)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            HStack(spacing: 5) {
                Circle()
                    .fill(EKitapligimPalette.liveDot)
                    .frame(width: 7, height: 7)
                Text(L10n.chatLiveBadge)
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(.white.opacity(0.16), in: Capsule())
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [EKitapligimPalette.chatTeal, Color(hex: 0x0B4F55)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }

    private var statusText: String {
        if !container.isSignedIn { return L10n.chatStatusGuest }
        if canSend { return L10n.chatStatusMember }
        return L10n.chatStatusSecureRead
    }

    private var roomTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(rooms) { room in
                    EKChip(
                        title: room.name,
                        isSelected: selectedRoomID == room.id,
                        selectedBackground: EKitapligimPalette.chatTeal
                    ) {
                        guard selectedRoomID != room.id else { return }
                        selectedRoomID = room.id
                        Task { await loadMessages(reset: true) }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
        }
        .background(.white)
    }

    // MARK: Mesaj listesi

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    welcomeCard

                    if hasOlder {
                        Button {
                            Task { await loadOlder() }
                        } label: {
                            Text(isLoadingOlder ? L10n.commonLoading : L10n.chatLoadOlder)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(EKitapligimPalette.chatTeal)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(EKitapligimPalette.chatTealSoft)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(isLoadingOlder)
                    }

                    if isLoadingMessages && messages.isEmpty {
                        EKSkeletonCard(height: 52)
                        EKSkeletonCard(height: 52)
                    } else if let errorMessage, messages.isEmpty {
                        EKStateCard(
                            title: L10n.chatReconnectTitle,
                            message: errorMessage,
                            retryTitle: L10n.chatReconnect
                        ) {
                            Task { await loadRooms() }
                        }
                    } else if messages.isEmpty {
                        EKStateCard(title: L10n.chatMessagesEmpty)
                    } else {
                        ForEach(messages) { message in
                            ChatMessageBubble(message: message)
                                .id(message.id)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .onChange(of: messages.last?.id) { _, id in
                guard let id else { return }
                withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(id, anchor: .bottom) }
            }
        }
    }

    private var welcomeCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(welcomeTitle)
                .font(.caption.weight(.bold))
                .foregroundStyle(EKitapligimPalette.chatInk)
            Text(L10n.chatWelcomeRules)
                .font(.caption2)
                .foregroundStyle(EKitapligimPalette.chatMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(EKitapligimPalette.chatTealSoft)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    private var welcomeTitle: String {
        if !container.isSignedIn { return L10n.chatWelcomeGuest }
        return canSend ? L10n.chatWelcomeReady : L10n.chatWelcomeSecure
    }

    // MARK: Mesaj yazma

    @ViewBuilder private var composer: some View {
        VStack(spacing: 8) {
            if let sendError {
                Text(sendError)
                    .font(.caption2)
                    .foregroundStyle(EKitapligimPalette.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !container.isSignedIn {
                guestPrompt(title: L10n.chatComposerGuestTitle, subtitle: L10n.chatComposerGuestSubtitle) {
                    showingLogin = true
                }
            } else if selectedRoom?.isReadOnly == true {
                readOnlyNotice(title: L10n.chatComposerReadOnlyTitle, subtitle: L10n.chatComposerReadOnlySubtitle)
            } else if !canSend {
                readOnlyNotice(
                    title: capabilities.canUse ? L10n.chatComposerNoPermission : L10n.chatComposerDisabled,
                    subtitle: L10n.chatComposerReadOnlySubtitle
                )
            } else {
                HStack(spacing: 10) {
                    TextField(L10n.chatComposerPlaceholder, text: $draft, axis: .vertical)
                        .lineLimit(1...4)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 10)
                        .background(EKitapligimPalette.chatSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                    Button {
                        Task { await send() }
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(EKitapligimPalette.chatTeal)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(isSending || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel(L10n.chatComposerSend)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(.white)
        .overlay(alignment: .top) {
            Rectangle().fill(EKitapligimPalette.chatBorder).frame(height: 1)
        }
    }

    private func guestPrompt(title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .foregroundStyle(EKitapligimPalette.chatTeal)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(EKitapligimPalette.chatInk)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(EKitapligimPalette.chatMuted)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(EKitapligimPalette.chatTeal)
            }
            .padding(13)
            .background(EKitapligimPalette.chatTealSoft)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func readOnlyNotice(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(EKitapligimPalette.chatAnnouncementInk)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(EKitapligimPalette.chatAnnouncementInk.opacity(0.85))
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(EKitapligimPalette.chatAnnouncement)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(EKitapligimPalette.chatAnnouncementBorder)
        }
    }

    // MARK: Veri

    private func loadRooms() async {
        guard !isLoadingRooms else { return }
        isLoadingRooms = true
        errorMessage = nil
        defer { isLoadingRooms = false }

        do {
            let response = try await container.chat.rooms()
            rooms = response.rooms
            capabilities = response.capabilities
            if selectedRoomID == nil {
                selectedRoomID = initialRoomID.flatMap { id in rooms.first { $0.id == id }?.id } ?? rooms.first?.id
            }
            if rooms.isEmpty {
                errorMessage = L10n.chatRoomsEmpty
            } else {
                await loadMessages(reset: true)
            }
        } catch {
            errorMessage = L10n.chatRoomsFailed
        }
    }

    private func loadMessages(reset: Bool) async {
        guard let roomID = selectedRoomID else { return }
        stopPolling()
        if reset {
            messages = []
            oldestID = nil
            newestID = nil
            hasOlder = false
        }
        isLoadingMessages = true
        defer { isLoadingMessages = false }

        do {
            let page = try await container.chat.messages(roomID: roomID, limit: 40)
            messages = page.messages
            oldestID = page.oldestId
            newestID = page.newestId
            hasOlder = page.hasMore
            errorMessage = nil
            startPolling()
        } catch {
            errorMessage = L10n.chatRoomsFailed
        }
    }

    private func loadOlder() async {
        guard let roomID = selectedRoomID, let beforeID = oldestID, !isLoadingOlder else { return }
        isLoadingOlder = true
        defer { isLoadingOlder = false }

        guard let page = try? await container.chat.messages(roomID: roomID, limit: 40, beforeID: beforeID) else { return }
        let existing = Set(messages.map(\.id))
        messages.insert(contentsOf: page.messages.filter { !existing.contains($0.id) }, at: 0)
        oldestID = page.oldestId ?? oldestID
        hasOlder = page.hasMore
    }

    private func pollNewMessages() async {
        guard let roomID = selectedRoomID, let afterID = newestID else { return }
        guard let page = try? await container.chat.messages(roomID: roomID, limit: 40, afterID: afterID) else { return }
        guard !page.messages.isEmpty else { return }
        let existing = Set(messages.map(\.id))
        messages.append(contentsOf: page.messages.filter { !existing.contains($0.id) })
        newestID = page.newestId ?? newestID
    }

    private func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let roomID = selectedRoomID else { return }
        isSending = true
        sendError = nil
        defer { isSending = false }

        do {
            let sent = try await container.chat.send(roomID: roomID, message: text)
            draft = ""
            if !messages.contains(where: { $0.id == sent.id }) {
                messages.append(sent)
            }
            newestID = sent.id
        } catch {
            sendError = (error as? APIClientError)?.serverMessage ?? L10n.chatSendFailed
        }
    }

    private func startPolling() {
        stopPolling()
        pollTask = Task { [pollInterval = Self.pollInterval] in
            while !Task.isCancelled {
                try? await Task.sleep(for: pollInterval)
                if Task.isCancelled { return }
                await pollNewMessages()
            }
        }
    }

    private func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }
}

// MARK: - Mesaj baloncuğu

private struct ChatMessageBubble: View {
    let message: ChatMessageDTO

    var body: some View {
        if message.isAnnouncement {
            announcement
        } else {
            bubble
        }
    }

    private var announcement: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "megaphone.fill")
                    .font(.caption2)
                Text(message.username)
                    .font(.caption2.weight(.heavy))
                Spacer(minLength: 0)
                Text(EKitapligimFormat.clockTime(message.messageDate))
                    .font(.system(size: 9))
            }
            .foregroundStyle(EKitapligimPalette.chatAnnouncementInk)

            Text(EKitapligimFormat.plainText(message.message))
                .font(.subheadline)
                .foregroundStyle(EKitapligimPalette.chatAnnouncementInk)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(EKitapligimPalette.chatAnnouncement)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(EKitapligimPalette.chatAnnouncementBorder)
        }
    }

    private var bubble: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isMine { Spacer(minLength: 40) }

            if !message.isMine {
                EKAvatar(urlString: message.avatarUrl, username: message.username, size: 30)
            }

            VStack(alignment: message.isMine ? .trailing : .leading, spacing: 4) {
                if !message.isMine {
                    HStack(spacing: 5) {
                        Text(message.username)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(EKitapligimPalette.chatInk)
                        if let roleBadge {
                            Text(roleBadge)
                                .font(.system(size: 8, weight: .heavy))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(EKitapligimPalette.chatAmber, in: Capsule())
                        }
                    }
                }

                Text(EKitapligimFormat.plainText(message.message))
                    .font(.subheadline)
                    .foregroundStyle(message.isMine ? .white : EKitapligimPalette.chatInk)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 9)
                    .background(bubbleBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

                Text(EKitapligimFormat.clockTime(message.messageDate) + (message.isEdited ? L10n.chatEdited : ""))
                    .font(.system(size: 9))
                    .foregroundStyle(EKitapligimPalette.chatMuted)
            }

            if !message.isMine { Spacer(minLength: 40) }
        }
        .frame(maxWidth: .infinity, alignment: message.isMine ? .trailing : .leading)
        .accessibilityElement(children: .combine)
    }

    private var bubbleBackground: Color {
        if message.isMine { return EKitapligimPalette.chatTeal }
        if message.isBot { return EKitapligimPalette.chatBotBubble }
        return EKitapligimPalette.chatSurface
    }

    private var roleBadge: String? {
        if message.isAdmin { return L10n.chatRoleAdmin }
        if message.isModerator { return L10n.chatRoleModerator }
        return nil
    }
}
