import SwiftUI
import EkitapligimCore

/// Native room transcript; requests and interaction state are owned by ChatModel.
@MainActor
struct ChatView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var initialRoomID: String?
    private let serviceOverride: (any ChatServing)?
    private let signedInOverride: Bool?

    @StateObject private var model = ChatModel()
    @FocusState private var isComposerFocused: Bool
    @State private var showingLogin = false
    @State private var isFollowingLatest = true
    @State private var reactionTarget: ChatMessageDTO?
    @State private var loadedSessionRevision: UUID?
    @State private var isVisible = false

    init(initialRoomID: String? = nil, service: (any ChatServing)? = nil, signedIn: Bool? = nil) {
        self.initialRoomID = initialRoomID
        self.serviceOverride = service
        self.signedInOverride = signedIn
    }

    private var signedIn: Bool { signedInOverride ?? container.isSignedIn }

    private var rooms: [ChatRoomDTO] { model.rooms }
    private var capabilities: ChatCapabilitiesDTO { model.capabilities }
    private var selectedRoomID: String? { model.selectedRoomID }
    private var selectedRoom: ChatRoomDTO? { model.selectedRoom }
    private var messages: [ChatMessageDTO] { model.messages }
    private var hasOlder: Bool { model.hasOlder }
    private var isLoadingRooms: Bool { model.isLoadingRooms }
    private var isLoadingMessages: Bool { model.isLoadingMessages }
    private var isLoadingOlder: Bool { model.isLoadingOlder }
    private var isSending: Bool { model.isSending }
    private var errorMessage: String? { model.errorMessage }
    private var sendError: String? { model.sendError }
    private var draft: String { model.draft }
    private var canSend: Bool { signedIn && model.canSend }
    private var sessionReady: Bool { signedIn && model.sessionReady }

    var body: some View {
        ZStack {
            Color(hex: 0xF5F8F9).ignoresSafeArea()
            LinearGradient(
                colors: [Color(hex: 0xF9FCFC), Color(hex: 0xF2F8F8), Color(hex: 0xFFFCF5)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            VStack(spacing: 0) {
                transcript
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            composer
        }
        .navigationTitle(L10n.chatTitle)
        .modifier(ChatNavigationSubtitleModifier(subtitle: L10n.chatSubtitle))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await model.loadMessages() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel(L10n.chatRefresh)
            }
        }
        .sheet(isPresented: $showingLogin) { LoginView() }
        .sheet(item: $reactionTarget) { message in
            ChatReactionPicker(
                options: model.reactionOptions,
                selectedID: message.visitorReactionId
            ) { id in
                reactionTarget = nil
                Task { await model.setReaction(messageID: message.id, reactionID: id) }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .task(id: container.sessionRevision) {
            reactionTarget = nil
            model.setBlockedUsers(Set(container.blockedUserIDs.map(String.init)))
            if loadedSessionRevision == container.sessionRevision, !model.rooms.isEmpty {
                await model.resume()
            } else {
                loadedSessionRevision = container.sessionRevision
                await model.connect(service: serviceOverride ?? container.chat, signedIn: signedIn, initialRoomID: initialRoomID)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await model.resume(visible: isVisible) }
            } else {
                model.disconnect()
                reactionTarget = nil
            }
        }
        .onChange(of: container.blockedUserIDs) { _, blockedIDs in
            model.setBlockedUsers(Set(blockedIDs.map(String.init)))
        }
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false; model.disconnect() }
    }

    // MARK: Hero + odalar

    private var chatHero: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .center, spacing: 13) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(
                        LinearGradient(
                            colors: [EKitapligimPalette.chatTeal, Color(hex: 0x046B70)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 17, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.chatHeroTitle)
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(EKitapligimPalette.chatInk)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(L10n.chatHeroSubtitle)
                        .font(.caption)
                        .foregroundStyle(EKitapligimPalette.chatMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                HStack(spacing: 5) {
                    Circle()
                        .fill(Color(hex: 0x1CB879))
                        .frame(width: 7, height: 7)
                    Text(L10n.chatLiveBadge)
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(Color(hex: 0x08734E))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color(hex: 0xE5FAF1), in: Capsule())
            }

            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: sessionReady ? "checkmark.shield.fill" : "eye.fill")
                        .font(.caption2)
                        .foregroundStyle(EKitapligimPalette.chatTeal)
                    Text(chatHeroStatusText)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(EKitapligimPalette.chatInk)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(.white.opacity(0.72), in: Capsule())
                .overlay(Capsule().stroke(Color(hex: 0xD5E8E7)))

                Text(L10n.chatHeroLiveUpdate)
                    .font(.system(size: 10))
                    .foregroundStyle(EKitapligimPalette.chatMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(17)
        .background(
            LinearGradient(
                colors: [.white, Color(hex: 0xEAF8F7), Color(hex: 0xFFF6E5)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color(hex: 0xCFE8E8))
        }
    }

    private var roomTabs: some View {
        Group {
            if rooms.count == 1, let room = rooms.first {
                chatRoomTab(room, expanded: true)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(rooms) { room in
                            chatRoomTab(room, expanded: false)
                        }
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 9)
                }
                .background(.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(EKitapligimPalette.chatBorder)
                }
            }
        }
    }

    private func chatRoomTab(_ room: ChatRoomDTO, expanded: Bool) -> some View {
        let selected = selectedRoomID == room.id
        return Button {
            guard selectedRoomID != room.id else { return }
            reactionTarget = nil
            Task { await model.selectRoom(room.id) }
        } label: {
            HStack(spacing: expanded ? 10 : 6) {
                Image(systemName: room.isPrivate ? "lock.fill" : "person.3.fill")
                    .font(expanded ? .body : .caption)
                    .accessibilityHidden(true)
                    .foregroundStyle(!expanded && selected ? .white : EKitapligimPalette.chatTeal)
                    .frame(width: expanded ? 39 : 24, height: expanded ? 39 : 24)
                    .background(
                        (!expanded && selected ? Color.white.opacity(0.16) : EKitapligimPalette.chatTealSoft),
                        in: RoundedRectangle(cornerRadius: expanded ? 12 : 8, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(room.name)
                        .font(expanded ? .subheadline.weight(.bold) : .caption.weight(.bold))
                        .foregroundStyle(!expanded && selected ? .white : EKitapligimPalette.chatInk)
                        .lineLimit(1)
                    if expanded {
                        Text(roomDescription(room))
                            .font(.caption2)
                            .foregroundStyle(EKitapligimPalette.chatMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: expanded ? .infinity : nil, alignment: .leading)

                onlinePill(for: room, selected: !expanded && selected)
            }
            .padding(.horizontal, expanded ? 14 : 12)
            .padding(.vertical, expanded ? 12 : 9)
            .frame(maxWidth: expanded ? .infinity : nil, alignment: .leading)
            .background {
                if expanded {
                    LinearGradient(
                        colors: [.white, Color(hex: 0xF0FAF9), Color(hex: 0xFFFAEF)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                } else if selected {
                    EKitapligimPalette.chatTeal
                } else {
                    Color(hex: 0xF3F7F7)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: expanded ? 18 : 13, style: .continuous))
            .overlay {
                if expanded || !selected {
                    RoundedRectangle(cornerRadius: expanded ? 18 : 13, style: .continuous)
                        .stroke(EKitapligimPalette.chatBorder)
                }
            }
        }
        .accessibilityLabel(room.name)
        .buttonStyle(.plain)
    }

    private func onlinePill(for room: ChatRoomDTO, selected: Bool) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(selected ? Color.white : Color(hex: 0x1CB879))
                .frame(width: 6, height: 6)
            Text(room.userCount > 0 ? L10n.chatOnlineCount(room.userCount) : L10n.chatRoomOpen)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(selected ? .white : Color(hex: 0x08734E))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            selected ? Color.white.opacity(0.16) : Color(hex: 0xE5FAF1),
            in: Capsule()
        )
    }

    private func roomDescription(_ room: ChatRoomDTO) -> String {
        let trimmed = room.description.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? L10n.chatRoomFallbackDescription : trimmed
    }

    private var chatHeroStatusText: String {
        if sessionReady { return L10n.chatStatusMember }
        if signedIn { return L10n.chatStatusSecureRead }
        return L10n.chatStatusGuest
    }

    // MARK: Mesaj listesi

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if isLoadingRooms && rooms.isEmpty {
                        chatLoadingCard(title: L10n.chatRoomsLoading)
                    } else if rooms.isEmpty {
                        if let errorMessage {
                            chatReconnectCard(message: errorMessage) {
                                Task { await model.reloadRooms(signedIn: signedIn) }
                            }
                        } else {
                            chatEmptyCard(message: L10n.chatRoomsEmpty)
                        }
                    } else {
                        chatHero

                        roomTabs

                        welcomeCard

                        if hasOlder {
                            Button {
                                Task { await model.loadOlder() }
                            } label: {
                                HStack(spacing: 7) {
                                    if isLoadingOlder {
                                        ProgressView()
                                            .controlSize(.small)
                                            .tint(EKitapligimPalette.chatTeal)
                                    } else {
                                        Image(systemName: "clock.arrow.circlepath")
                                            .font(.system(size: 17, weight: .semibold))
                                            .accessibilityHidden(true)
                                    }
                                    Text(isLoadingOlder ? L10n.commonLoading : L10n.chatLoadOlder)
                                }
                                .font(.caption.weight(.bold))
                                .foregroundStyle(EKitapligimPalette.chatTeal)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(EKitapligimPalette.chatTealSoft)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .accessibilityLabel(L10n.chatLoadOlder)
                            .buttonStyle(.plain)
                            .disabled(isLoadingOlder)
                        }

                        if isLoadingMessages && messages.isEmpty {
                            chatLoadingCard(title: L10n.chatMessagesLoading)
                        } else if let errorMessage, messages.isEmpty {
                            chatReconnectCard(message: errorMessage) {
                                Task { await model.reloadRooms(signedIn: signedIn) }
                            }
                        } else if messages.isEmpty {
                            chatEmptyCard(message: L10n.chatMessagesEmpty)
                        } else {
                            ForEach(messages.filter { message in
                                guard let userID = Int(message.userId) else { return true }
                                return !container.blockedUserIDs.contains(userID)
                            }) { message in
                                ChatMessageBubble(
                                    message: message,
                                    canInteract: model.canSend,
                                    isReacting: model.reactingMessageIDs.contains(message.id),
                                    onQuote: {
                                        model.quote(message)
                                        isComposerFocused = true
                                    },
                                    onReact: { reactionTarget = message },
                                    onSelectReaction: { id in
                                        Task { await model.setReaction(messageID: message.id, reactionID: id) }
                                    },
                                    onBlocked: { model.removeBlockedUser(message.userId) }
                                )
                                .id(message.id)
                                .onAppear { model.setMessageVisible(message.id, visible: true) }
                                .onDisappear { model.setMessageVisible(message.id, visible: false) }
                            }
                        }
                    }
                    Color.clear.frame(height: 1)
                    .id("chat-latest")
                    .onAppear { isFollowingLatest = true }
                    .onDisappear { isFollowingLatest = false }
                }
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: messages.last?.id) { _, id in
                guard isFollowingLatest, let id else { return }
                withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(id, anchor: .bottom) }
            }
            .onChange(of: model.scrollRequest) { _, _ in
                withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("chat-latest", anchor: .bottom) }
            }
        }
    }

    private var welcomeCard: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: sessionReady ? "checkmark.shield.fill" : "eye.fill")
                .font(.body)
                .foregroundStyle(sessionReady ? EKitapligimPalette.chatTeal : EKitapligimPalette.chatAmber)
            VStack(alignment: .leading, spacing: 3) {
                Text(welcomeTitle)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(EKitapligimPalette.chatInk)
                Text(welcomeBody)
                    .font(.caption2)
                    .foregroundStyle(EKitapligimPalette.chatMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .background(sessionReady ? Color(hex: 0xEAF8F7) : Color(hex: 0xFFF8EA))
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(sessionReady ? Color(hex: 0xC8E7E4) : Color(hex: 0xF0DFC0))
        }
    }

    private var welcomeTitle: String {
        if sessionReady { return L10n.chatWelcomeReady }
        if signedIn { return L10n.chatWelcomeSecure }
        return L10n.chatWelcomeGuest
    }

    private var welcomeBody: String {
        if let room = selectedRoom {
            let trimmed = room.description.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return L10n.chatWelcomeRules
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

            if !signedIn {
                chatAccessCallToAction(
                    icon: "arrow.right.circle.fill",
                    title: L10n.chatComposerGuestTitle,
                    subtitle: L10n.chatComposerGuestSubtitle,
                    buttonTitle: L10n.commonLogin
                ) {
                    showingLogin = true
                }
            } else if signedIn && isLoadingRooms {
                chatSessionPreparing
            } else if signedIn && !capabilities.authenticated {
                chatAccessCallToAction(
                    icon: "wifi.slash",
                    title: L10n.chatComposerSessionTitle,
                    subtitle: L10n.chatComposerSessionSubtitle,
                    buttonTitle: L10n.chatSessionRefresh
                ) {
                    Task {
                        await container.refreshSessionData()
                        await model.reloadRooms(signedIn: signedIn)
                    }
                }
            } else if !capabilities.canUse || selectedRoom?.isReadOnly == true {
                readOnlyNotice(
                    title: L10n.chatComposerReadOnlyTitle,
                    subtitle: selectedRoom?.isReadOnly == true
                        ? L10n.chatComposerReadOnlySubtitle
                        : L10n.chatComposerNoPermission
                )
            } else if !(selectedRoom?.canSend ?? false) {
                readOnlyNotice(
                    title: L10n.chatComposerReadOnlyTitle,
                    subtitle: L10n.chatComposerNoPermission
                )
            } else {
                if let quoted = model.quotedMessage {
                    HStack(alignment: .top, spacing: 8) {
                        ChatQuotePreview(username: quoted.username, message: quoted.message, onDark: false,
                                         lineLimit: dynamicTypeSize.isAccessibilitySize ? 1 : 3)
                        Button {
                            model.cancelQuote()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(EKitapligimPalette.chatMuted)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(L10n.chatCancelReply)
                        .accessibilityIdentifier("chat-cancel-reply")
                    }
                    .accessibilityIdentifier("chat-reply-context")
                }
                HStack(alignment: .bottom, spacing: 9) {
                    HStack(spacing: 8) {
                        Image(systemName: "person.fill")
                            .font(.subheadline)
                            .foregroundStyle(EKitapligimPalette.chatTeal)
                            .accessibilityHidden(true)
                        TextField(L10n.chatComposerPlaceholder, text: $model.draft, axis: .vertical)
                            .focused($isComposerFocused)
                            .lineLimit(1...(dynamicTypeSize.isAccessibilitySize ? 2 : 4))
                            .accessibilityIdentifier("chat-composer")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(hex: 0xF8FCFC))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(
                                isComposerFocused ? EKitapligimPalette.chatTeal : Color(hex: 0xD8E3E4),
                                lineWidth: 1
                            )
                    }

                    Button {
                        Task { await model.send() }
                    } label: {
                        Group {
                            if isSending {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "paperplane.fill")
                                    .font(.subheadline)
                                    .accessibilityHidden(true)
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(width: 50, height: 50)
                        .background(
                            canSend ? EKitapligimPalette.chatTeal : Color(hex: 0xCCD6D9),
                            in: RoundedRectangle(cornerRadius: 17, style: .continuous)
                        )
                    }
                    .accessibilityLabel(L10n.chatComposerSend)
                    .accessibilityIdentifier("chat-send")
                    .buttonStyle(.plain)
                    .disabled(!canSend || isSending || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
        .background(Color.white.opacity(0.92))
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 22,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 22,
                style: .continuous
            )
        )
        .overlay {
            UnevenRoundedRectangle(
                topLeadingRadius: 22,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 22,
                style: .continuous
            )
            .stroke(EKitapligimPalette.chatBorder, lineWidth: 1)
        }
    }

    private var chatSessionPreparing: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(EKitapligimPalette.chatTeal)
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.chatSessionPreparingTitle)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(EKitapligimPalette.chatInk)
                Text(L10n.chatSessionPreparingSubtitle)
                    .font(.caption2)
                    .foregroundStyle(EKitapligimPalette.chatMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private func chatLoadingCard(title: String) -> some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(EKitapligimPalette.chatTeal)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(EKitapligimPalette.chatInk)
                .multilineTextAlignment(.center)
            Text(L10n.chatRoomsLoadingSubtitle)
                .font(.system(size: 11))
                .foregroundStyle(EKitapligimPalette.chatMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 34)
        .padding(.vertical, 28)
        .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(EKitapligimPalette.chatBorder, lineWidth: 1)
        }
    }

    private func chatEmptyCard(message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.title)
                .foregroundStyle(EKitapligimPalette.chatTeal)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(EKitapligimPalette.chatMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(EKitapligimPalette.chatBorder, lineWidth: 1)
        }
    }

    private func chatReconnectCard(message: String, retry: @escaping () -> Void) -> some View {
        VStack(spacing: 11) {
            Image(systemName: "wifi.slash")
                .font(.title2)
                .foregroundStyle(EKitapligimPalette.chatTeal)
                .frame(width: 58, height: 58)
                .background(EKitapligimPalette.chatTealSoft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            Text(L10n.chatReconnectTitle)
                .font(.headline.weight(.heavy))
                .foregroundStyle(EKitapligimPalette.chatInk)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.caption)
                .foregroundStyle(EKitapligimPalette.chatMuted)
                .multilineTextAlignment(.center)
            Button(action: retry) {
                Label(L10n.chatReconnect, systemImage: "arrow.clockwise")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(EKitapligimPalette.chatTeal, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(26)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(colors: [.white, Color(hex: 0xFFFAF0)], startPoint: .top, endPoint: .bottom),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color(hex: 0xE2D7C5), lineWidth: 1)
        }
    }

    private func chatAccessCallToAction(
        icon: String,
        title: String,
        subtitle: String,
        buttonTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(EKitapligimPalette.chatTeal)
                .frame(width: 44, height: 44)
                .background(
                    LinearGradient(
                        colors: [EKitapligimPalette.chatTealSoft, Color(hex: 0xFFF4DD)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(EKitapligimPalette.chatInk)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(EKitapligimPalette.chatMuted)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Button(action: action) {
                Text(buttonTitle)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 9)
                    .background(EKitapligimPalette.chatTeal, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private func readOnlyNotice(title: String, subtitle: String) -> some View {
        HStack(alignment: .center, spacing: 11) {
            Image(systemName: "eye.fill")
                .font(.body)
                .foregroundStyle(EKitapligimPalette.chatTeal)
                .frame(width: 42, height: 42)
                .background(EKitapligimPalette.chatTealSoft, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .accessibilityHidden(true)
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
        }
    }

}

private struct ChatNavigationSubtitleModifier: ViewModifier {
    let subtitle: String

    @ViewBuilder
    func body(content: Content) -> some View {
#if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content.navigationSubtitle(subtitle)
        } else {
            content
        }
#else
        content
#endif
    }
}

// MARK: - Mesaj baloncuğu

struct ChatMessageBubble: View {
    @ScaledMetric(relativeTo: .caption) private var reactionChipWidth = 76.0
    let message: ChatMessageDTO
    let canInteract: Bool
    let isReacting: Bool
    let onQuote: () -> Void
    let onReact: () -> Void
    let onSelectReaction: (Int) -> Void
    let onBlocked: () -> Void

    private var profileMemberID: String? {
        guard !message.isBot else { return nil }
        return message.userId
    }

    var body: some View {
        if message.isAnnouncement {
            announcement
        } else {
            bubble
        }
    }

    private var announcement: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "megaphone.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(
                    LinearGradient(
                        colors: [EKitapligimPalette.chatAmber, Color(hex: 0xC47E0A)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.chatAnnouncementLabel)
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(EKitapligimPalette.chatAmber)
                Text(EKitapligimFormat.plainText(message.message))
                    .font(.subheadline)
                    .foregroundStyle(EKitapligimPalette.chatAnnouncementInk)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [EKitapligimPalette.chatAnnouncement, Color(hex: 0xFFF0CC)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(EKitapligimPalette.chatAnnouncementBorder, lineWidth: 1)
        }
        .shadow(color: EKitapligimPalette.chatAmber.opacity(0.12), radius: 8, y: 3)
    }

    private var bubble: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.isMine { Spacer(minLength: 20) }
            if !message.isMine {
                MemberProfileLink(memberID: profileMemberID) {
                    EKAvatar(
                        urlString: message.avatarUrl,
                        username: message.username,
                        size: 36,
                        background: message.isBot ? EKitapligimPalette.chatBotBubble : EKitapligimPalette.chatTealSoft,
                        foreground: message.isBot ? Color(hex: 0x95610A) : EKitapligimPalette.chatTeal
                    )
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                }
                .accessibilityLabel(L10n.chatOpenProfile(message.username))
                .accessibilityIdentifier("chat-avatar-\(message.id)")
            }
            VStack(alignment: message.isMine ? .trailing : .leading, spacing: 5) {
                VStack(alignment: .leading, spacing: 8) {
                    if !message.isMine {
                        ViewThatFits(in: .horizontal) {
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                senderName
                                if let roleBadge { badge(roleBadge) }
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                senderName
                                if let roleBadge { badge(roleBadge) }
                            }
                        }
                    }
                    if let quote = message.quotedMessage {
                        ChatQuotePreview(username: quote.username, message: quote.message, onDark: message.isMine)
                    }
                    Text(EKitapligimFormat.plainText(message.message))
                        .font(.body)
                        .foregroundStyle(message.isMine ? .white : EKitapligimPalette.chatInk)
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .accessibilityIdentifier("chat-message-\(message.id)")
                    Text(timestampLabel)
                        .font(.caption2)
                        .foregroundStyle(message.isMine ? Color.white.opacity(0.82) : EKitapligimPalette.chatMuted)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background { bubbleBackground }
                .clipShape(chatBubbleShape)
                .overlay {
                    if !message.isMine { chatBubbleShape.stroke(EKitapligimPalette.chatBorder, lineWidth: 1) }
                }
                .shadow(color: EKitapligimPalette.chatTeal.opacity(message.isMine ? 0.12 : 0.04), radius: 6, y: 3)

                if !message.reactions.isEmpty {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: min(reactionChipWidth, 160)), spacing: 6)], alignment: .leading, spacing: 6) {
                        ForEach(message.reactions) { reaction in
                            Button {
                                onSelectReaction(message.visitorReactionId == reaction.reactionId ? 0 : reaction.reactionId)
                            } label: {
                                ViewThatFits(in: .horizontal) {
                                    HStack(spacing: 4) {
                                        ChatReactionSymbol(reaction: reaction)
                                        Text(reaction.count.formatted()).font(.caption.weight(.semibold))
                                    }
                                    VStack(spacing: 2) {
                                        ChatReactionSymbol(reaction: reaction)
                                        Text(reaction.count.formatted()).font(.caption.weight(.semibold))
                                    }
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .frame(minHeight: 44)
                                .frame(maxWidth: .infinity)
                                .foregroundStyle(EKitapligimPalette.chatTeal)
                                .background(
                                    message.visitorReactionId == reaction.reactionId ? EKitapligimPalette.chatTealSoft : Color.white,
                                    in: Capsule()
                                )
                                .overlay(Capsule().stroke(EKitapligimPalette.chatBorder))
                            }
                            .buttonStyle(.plain)
                            .disabled(!canInteract || !message.canReact || isReacting)
                            .accessibilityLabel(L10n.chatReactionCount(reaction.title, reaction.count))
                            .accessibilityAddTraits(message.visitorReactionId == reaction.reactionId ? .isSelected : [])
                            .accessibilityIdentifier("chat-reaction-\(message.id)-\(reaction.reactionId)")
                        }
                    }
                }
                HStack(spacing: 6) {
                    if canInteract && message.canQuote {
                        Button(action: onQuote) {
                            Image(systemName: "arrowshape.turn.up.left")
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                            .accessibilityLabel(L10n.chatReply)
                            .accessibilityIdentifier("chat-reply-\(message.id)")
                    }
                    if canInteract && message.canReact {
                        Button(action: onReact) {
                            Group {
                                if isReacting { ProgressView().controlSize(.small) }
                                else { Image(systemName: "face.smiling") }
                            }
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                        }
                        .disabled(isReacting)
                        .accessibilityLabel(L10n.chatReact)
                        .accessibilityIdentifier("chat-react-\(message.id)")
                    }
                    if !message.isMine, let contentID = Int(message.id) {
                        UGCSafetyMenu(type: .chatMessage, contentID: contentID,
                                      userID: Int(message.userId), onBlocked: onBlocked)
                            .frame(width: 44, height: 44)
                    }
                }
                .buttonStyle(.plain)
                .font(.body)
                .foregroundStyle(EKitapligimPalette.chatTeal)
                .frame(maxWidth: .infinity, alignment: message.isMine ? .trailing : .leading)
            }
            .frame(maxWidth: .infinity)
            if !message.isMine { Spacer(minLength: 8) }
        }
        .frame(maxWidth: .infinity, alignment: message.isMine ? .trailing : .leading)
        .accessibilityElement(children: .contain)
    }

    private var senderName: some View {
        MemberProfileLink(memberID: profileMemberID) {
            Text(message.username)
                .font(.caption.weight(.bold))
                .foregroundStyle(message.isBot ? Color(hex: 0x95610A) : EKitapligimPalette.chatTeal)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityLabel(L10n.chatOpenProfile(message.username))
    }

    private func badge(_ title: String) -> some View {
        Text(title)
            .font(.caption2.weight(.bold))
            .foregroundStyle(EKitapligimPalette.chatAmber)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(EKitapligimPalette.chatAnnouncement, in: Capsule())
    }

    private var timestampLabel: String {
        EKitapligimFormat.relativeTime(message.messageDate) + (message.isEdited ? L10n.chatEdited : "")
    }

    @ViewBuilder
    private var bubbleBackground: some View {
        if message.isMine {
            LinearGradient(
                colors: [EKitapligimPalette.chatTeal, Color(hex: 0x046B70)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if message.isBot {
            LinearGradient(
                colors: [EKitapligimPalette.chatBotBubble, Color(hex: 0xFFF0D4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            Color.white
        }
    }

    private var chatBubbleShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 16,
            bottomLeadingRadius: message.isMine ? 16 : 5,
            bottomTrailingRadius: message.isMine ? 5 : 16,
            topTrailingRadius: 16,
            style: .continuous
        )
    }

    private var roleBadge: String? {
        if message.isAdmin { return L10n.chatRoleAdmin }
        if message.isModerator || message.isStaff { return L10n.chatRoleModerator }
        return nil
    }

}

struct ChatQuotePreview: View {
    let username: String
    let message: String
    let onDark: Bool
    var lineLimit: Int? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(onDark ? Color.white.opacity(0.8) : EKitapligimPalette.chatTeal)
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.chatReplyTo(username))
                    .font(.caption.weight(.bold))
                Text(EKitapligimFormat.plainText(message))
                    .font(.caption)
                    .lineLimit(lineLimit)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
        .foregroundStyle(onDark ? Color.white.opacity(0.9) : EKitapligimPalette.chatInk)
        .padding(10)
        .background(onDark ? Color.white.opacity(0.12) : EKitapligimPalette.chatTealSoft,
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct ChatReactionSymbol: View {
    let reaction: ChatReactionDTO

    var body: some View {
        Group {
            if !reaction.emoji.isEmpty {
                Text(reaction.emoji).font(.title3)
            } else if let raw = reaction.imageUrl, let url = URL(string: raw), url.scheme == "https" {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        if reaction.spriteMode, let sprite = reaction.spriteParams {
                            Canvas { context, size in
                                let resolved = context.resolve(image)
                                if let viewport = sprite.viewport(imageWidth: resolved.size.width,
                                                                  imageHeight: resolved.size.height,
                                                                  size: min(size.width, size.height)) {
                                    context.clip(to: Path(CGRect(x: viewport.insetX, y: viewport.insetY,
                                                                width: viewport.cellWidth, height: viewport.cellHeight)))
                                    context.draw(resolved, in: CGRect(x: viewport.offsetX, y: viewport.offsetY,
                                                                     width: viewport.sheetWidth, height: viewport.sheetHeight))
                                } else {
                                    context.draw(context.resolve(Image(systemName: "face.smiling")),
                                                 in: CGRect(origin: .zero, size: size))
                                }
                            }
                        } else if !reaction.spriteMode {
                            image.resizable().scaledToFit()
                        } else {
                            Image(systemName: "face.smiling")
                        }
                    } else {
                        Image(systemName: "face.smiling")
                    }
                }
                .frame(width: 24, height: 24)
            } else {
                Image(systemName: "face.smiling").font(.title3)
            }
        }
        .accessibilityHidden(true)
    }
}

struct ChatReactionPicker: View {
    let options: [ChatReactionDTO]
    let selectedID: Int
    let onSelect: (Int) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 12)], spacing: 12) {
                    ForEach(options) { reaction in
                        Button { onSelect(selectedID == reaction.reactionId ? 0 : reaction.reactionId) } label: {
                            VStack(spacing: 8) {
                                ChatReactionSymbol(reaction: reaction)
                                Text(reaction.title)
                                    .font(.subheadline.weight(.semibold))
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, minHeight: 80)
                            .foregroundStyle(EKitapligimPalette.chatInk)
                            .background(selectedID == reaction.reactionId ? EKitapligimPalette.chatTealSoft : Color(hex: 0xF4F7F8),
                                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(reaction.title)
                        .accessibilityAddTraits(selectedID == reaction.reactionId ? .isSelected : [])
                        .accessibilityIdentifier("chat-picker-reaction-\(reaction.reactionId)")
                    }
                }
                .padding(16)
                if selectedID > 0 {
                    Button(L10n.chatRemoveReaction) { onSelect(0) }
                        .padding(12)
                        .frame(minHeight: 44)
                }
            }
            .navigationTitle(L10n.chatReact)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
