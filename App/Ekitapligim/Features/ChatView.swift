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
    @FocusState private var isComposerFocused: Bool
    @State private var isLoadingRooms = false
    @State private var isLoadingMessages = false
    @State private var isLoadingOlder = false
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var sendError: String?
    @State private var showingLogin = false
    @State private var pollTask: Task<Void, Never>?

    private static let pollInterval: Duration = .seconds(5)
    private static let draftCharacterLimit = 1_000

    private var selectedRoom: ChatRoomDTO? {
        rooms.first { $0.id == selectedRoomID }
    }

    private var canSend: Bool {
        container.isSignedIn
            && capabilities.authenticated
            && capabilities.canUse
            && (selectedRoom?.canSend ?? false)
    }

    private var sessionReady: Bool {
        container.isSignedIn && capabilities.authenticated
    }

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
        .navigationSubtitle(L10n.chatSubtitle)
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
        .onChange(of: draft) { _, newValue in
            if newValue.count > Self.draftCharacterLimit {
                draft = String(newValue.prefix(Self.draftCharacterLimit))
            }
        }
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
                    .lineLimit(1)
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
            selectedRoomID = room.id
            Task { await loadMessages(reset: true) }
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
                            .font(.system(size: 10))
                            .foregroundStyle(EKitapligimPalette.chatMuted)
                            .lineLimit(1)
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
        if container.isSignedIn { return L10n.chatStatusSecureRead }
        return L10n.chatStatusGuest
    }

    // MARK: Mesaj listesi

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if isLoadingRooms && rooms.isEmpty {
                        chatLoadingCard(title: L10n.chatRoomsLoading)
                    } else if rooms.isEmpty {
                        if let errorMessage {
                            chatReconnectCard(message: errorMessage) {
                                Task { await loadRooms() }
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
                                Task { await loadOlder() }
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
                                Task { await loadRooms() }
                            }
                        } else if messages.isEmpty {
                            chatEmptyCard(message: L10n.chatMessagesEmpty)
                        } else {
                            ForEach(messages) { message in
                                ChatMessageBubble(message: message)
                                    .id(message.id)
                            }
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
        if container.isSignedIn { return L10n.chatWelcomeSecure }
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

            if !container.isSignedIn {
                chatAccessCallToAction(
                    icon: "arrow.right.circle.fill",
                    title: L10n.chatComposerGuestTitle,
                    subtitle: L10n.chatComposerGuestSubtitle,
                    buttonTitle: L10n.commonLogin
                ) {
                    showingLogin = true
                }
            } else if container.isSignedIn && isLoadingRooms {
                chatSessionPreparing
            } else if container.isSignedIn && !capabilities.authenticated {
                chatAccessCallToAction(
                    icon: "wifi.slash",
                    title: L10n.chatComposerSessionTitle,
                    subtitle: L10n.chatComposerSessionSubtitle,
                    buttonTitle: L10n.chatSessionRefresh
                ) {
                    Task {
                        await container.refreshSessionData()
                        await loadRooms()
                    }
                }
            } else if !capabilities.canUse || selectedRoom?.isReadOnly == true {
                readOnlyNotice(
                    title: L10n.chatComposerReadOnlyTitle,
                    subtitle: selectedRoom?.isReadOnly == true
                        ? L10n.chatComposerReadOnlySubtitle
                        : L10n.chatComposerNoPermission
                )
            } else {
                HStack(alignment: .bottom, spacing: 9) {
                    HStack(spacing: 8) {
                        Image(systemName: "person.fill")
                            .font(.subheadline)
                            .foregroundStyle(EKitapligimPalette.chatTeal)
                            .accessibilityHidden(true)
                        TextField(L10n.chatComposerPlaceholder, text: $draft, axis: .vertical)
                            .focused($isComposerFocused)
                            .lineLimit(1...4)
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
                        Task { await send() }
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
                    .buttonStyle(.plain)
                    .disabled(!canSend || isSending || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(.white)
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
            if !rooms.isEmpty {
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
            errorMessage = L10n.chatMessagesFailed
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
        guard canSend, selectedRoom?.isReadOnly != true, !text.isEmpty, let roomID = selectedRoomID else { return }
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
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "sparkles")
                .font(.body.weight(.semibold))
                .foregroundStyle(EKitapligimPalette.chatAmber)
            Text(EKitapligimFormat.plainText(message.message))
                .font(.subheadline)
                .foregroundStyle(EKitapligimPalette.chatAnnouncementInk)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EKitapligimPalette.chatAnnouncement, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(EKitapligimPalette.chatAnnouncementBorder, lineWidth: 1)
        }
    }

    private var bubble: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isMine { Spacer(minLength: 40) }

            if !message.isMine {
                EKAvatar(urlString: message.avatarUrl, username: message.username, size: 35)
            }

            VStack(alignment: message.isMine ? .trailing : .leading, spacing: 3) {
                if !message.isMine {
                    HStack(spacing: 6) {
                        Text(message.username)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(message.isBot ? Color(hex: 0x95610A) : EKitapligimPalette.chatTeal)
                        if let roleBadge {
                            Text(roleBadge)
                                .font(.system(size: 8, weight: .heavy))
                                .foregroundStyle(EKitapligimPalette.chatAmber)
                        }
                    }
                }

                Text(EKitapligimFormat.plainText(message.message))
                    .font(.subheadline)
                    .foregroundStyle(message.isMine ? .white : EKitapligimPalette.chatInk)
                    .multilineTextAlignment(.leading)

                Text(EKitapligimFormat.clockTime(message.messageDate) + (message.isEdited ? L10n.chatEdited : ""))
                    .font(.system(size: 10))
                    .foregroundStyle(message.isMine ? Color.white.opacity(0.72) : EKitapligimPalette.chatMuted)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .frame(maxWidth: 310, alignment: message.isMine ? .trailing : .leading)
            .background(bubbleBackground)
            .clipShape(chatBubbleShape)
            .overlay {
                if !message.isMine {
                    chatBubbleShape.stroke(EKitapligimPalette.chatBorder, lineWidth: 1)
                }
            }

            if !message.isMine { Spacer(minLength: 40) }
        }
        .frame(maxWidth: .infinity, alignment: message.isMine ? .trailing : .leading)
        .accessibilityElement(children: .combine)
    }

    private var bubbleBackground: Color {
        if message.isMine { return EKitapligimPalette.chatTeal }
        if message.isBot { return EKitapligimPalette.chatBotBubble }
        return .white
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
