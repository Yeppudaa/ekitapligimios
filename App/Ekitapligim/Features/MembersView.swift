import SwiftUI
import EkitapligimCore

@MainActor
struct MembersView: View {
    @EnvironmentObject private var container: AppContainer
    @State private var members: [MemberDTO] = []
    @State private var query = ""
    @State private var sort = "alphabetical"
    @State private var currentPage = 0
    @State private var lastPage = 1
    @State private var total = 0
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        EKitapligimScreen {
            Group {
                if isLoading && members.isEmpty {
                    EKLoadingState(message: L10n.membersLoading)
                } else if let errorMessage, members.isEmpty {
                    EKErrorState(title: L10n.membersUnavailableTitle, message: errorMessage) {
                        Task { await load(reset: true) }
                    }
                } else if members.isEmpty {
                    EKEmptyState(title: L10n.membersEmptyTitle, message: L10n.membersEmptyDescription, systemImage: "person.3")
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            membersHeader
                            ForEach(members) { member in
                                NavigationLink {
                                    MemberProfileView(memberID: member.id)
                                } label: {
                                    MemberRow(member: member)
                                }
                                .buttonStyle(.plain)
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
                }
            }
        }
        .navigationTitle(L10n.membersTitle)
        .searchable(text: $query, prompt: L10n.membersSearchPrompt)
        .onSubmit(of: .search) { Task { await load(reset: true) } }
        .task { await load(reset: true) }
    }

    private var membersHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.membersTitle)
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(EKitapligimPalette.ink)
                    Text(L10n.membersTotalLabel)
                        .font(.caption)
                        .foregroundStyle(EKitapligimPalette.muted)
                }
                Spacer()
                Text("\(total)")
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(EKitapligimPalette.tealDark)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(EKitapligimPalette.tealSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            Picker(L10n.membersSortLabel, selection: $sort) {
                Text(L10n.membersSortAlphabetical).tag("alphabetical")
                Text(L10n.membersSortNewest).tag("newest")
                Text(L10n.membersSortActive).tag("active")
            }
            .pickerStyle(.segmented)
            .onChange(of: sort) { _, _ in Task { await load(reset: true) } }
        }
        .padding(16)
        .ekitapligimCard(radius: 16)
    }

    private func load(reset: Bool) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let result = try await container.members.members(
                page: reset ? 1 : currentPage + 1,
                query: query.trimmed.nilIfEmpty,
                sort: sort
            )
            members = reset ? result.members : members + result.members.filter { item in
                !members.contains(where: { $0.id == item.id })
            }
            members = members.filter { member in
                guard let id = Int(member.id) else { return true }
                return !container.blockedUserIDs.contains(id)
            }
            currentPage = result.currentPage
            lastPage = result.lastPage
            total = result.total
        } catch {
            errorMessage = L10n.membersLoadFailed
        }
    }
}

@MainActor
private struct MemberRow: View {
    let member: MemberDTO

    var body: some View {
        HStack(spacing: 14) {
            ZStack(alignment: .bottomTrailing) {
                AsyncImage(url: URL(string: member.avatarUrl)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .foregroundStyle(EKitapligimPalette.muted)
                }
                .frame(width: 56, height: 56)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color(hex: 0xE0EAEB), lineWidth: 1))
                .accessibilityHidden(true)

                if member.showVerifiedBadge {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundStyle(EKitapligimPalette.teal)
                        .background(Circle().fill(.white).padding(-2))
                        .accessibilityLabel(L10n.membersVerified)
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(member.username)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(EKitapligimPalette.ink)
                    .lineLimit(1)
                Text(member.roleLabel.isEmpty ? member.userTitle : member.roleLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(EKitapligimPalette.tealDark)
                    .lineLimit(1)
                if !member.about.isEmpty {
                    Text(member.about)
                        .font(.caption)
                        .foregroundStyle(EKitapligimPalette.muted)
                        .lineLimit(2)
                }
                Text(L10n.membersMessageCount(member.messageCount))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(EKitapligimPalette.muted)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(EKitapligimPalette.muted)
        }
        .padding(14)
        .ekitapligimCard(radius: 16)
    }
}

@MainActor
struct MemberProfileView: View {
    @EnvironmentObject private var container: AppContainer
    let memberID: String

    @State private var member: MemberDTO?
    @State private var isLoading = true
    @State private var isActing = false
    @State private var errorMessage: String?
    @State private var operationError: String?
    @State private var showBlockConfirmation = false
    @State private var showUnblockConfirmation = false
    @State private var showBlockAndReport = false
    @State private var blockCompleted = false
    @State private var unblockCompleted = false

    private var isSignedIn: Bool {
        if case .signedIn = container.authState { return true }
        return false
    }

    var body: some View {
        EKitapligimScreen {
            Group {
                if isLoading && member == nil {
                    EKLoadingState(message: L10n.membersProfileLoading)
                } else if let errorMessage, member == nil {
                    EKErrorState(title: L10n.membersUnavailableTitle, message: errorMessage) {
                        Task { await load() }
                    }
                } else if let member {
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            memberHero(member)
                            statsCard(member)
                            if !member.about.isEmpty || !member.location.isEmpty {
                                aboutCard(member)
                            }
                            if isSignedIn {
                                actionsCard(member)
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                    }
                } else {
                    EKErrorState(title: L10n.membersProfileLoadFailed, message: nil) {
                        Task { await load() }
                    }
                }
            }
        }
        .navigationTitle(member?.username ?? L10n.membersProfileTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .confirmationDialog(L10n.membersBlockConfirmation, isPresented: $showBlockConfirmation, titleVisibility: .visible) {
            Button(L10n.membersBlock, role: .destructive) { Task { await block() } }
            Button(L10n.commonCancel, role: .cancel) {}
        }
        .confirmationDialog(L10n.membersUnblockConfirmation, isPresented: $showUnblockConfirmation, titleVisibility: .visible) {
            Button(L10n.membersUnblock) { Task { await unblock() } }
            Button(L10n.commonCancel, role: .cancel) {}
        }
        .sheet(isPresented: $showBlockAndReport) {
            if let userID = Int(memberID) {
                ReportContentView(kind: .memberBlock(userID: userID)) { success in
                    if success { blockCompleted = true }
                }
            }
        }
        .alert(L10n.membersBlockCompleted, isPresented: $blockCompleted) {
            Button(L10n.commonClose) {}
        }
        .alert(L10n.membersUnblockCompleted, isPresented: $unblockCompleted) {
            Button(L10n.commonClose) {}
        }
        .alert(
            L10n.membersActionFailed,
            isPresented: Binding(
                get: { operationError != nil },
                set: { if !$0 { operationError = nil } }
            )
        ) {
            Button(L10n.commonClose) { operationError = nil }
        }
    }

    private func memberHero(_ member: MemberDTO) -> some View {
        VStack(spacing: 14) {
            AsyncImage(url: URL(string: member.avatarUrl)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .foregroundStyle(EKitapligimPalette.muted)
            }
            .frame(width: 96, height: 96)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color(hex: 0xDDE8EA), lineWidth: 2))
            .accessibilityHidden(true)

            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Text(member.username)
                        .font(.title2.weight(.heavy))
                        .foregroundStyle(EKitapligimPalette.ink)
                    if member.showVerifiedBadge {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(EKitapligimPalette.teal)
                    }
                }
                Text(member.roleLabel.isEmpty ? member.userTitle : member.roleLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(EKitapligimPalette.tealDark)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(EKitapligimPalette.tealSoft, in: Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .ekitapligimCard(radius: 18)
    }

    private func statsCard(_ member: MemberDTO) -> some View {
        HStack(spacing: 10) {
            memberStat(title: L10n.membersMessagesLabel, value: "\(member.messageCount)")
            memberStat(title: L10n.membersReactionsLabel, value: "\(member.reactionScore)")
            if member.registerDate > 0 {
                memberStat(
                    title: L10n.membersJoinedLabel,
                    value: Date(timeIntervalSince1970: TimeInterval(member.registerDate))
                        .formatted(.dateTime.year().month(.abbreviated))
                )
            }
        }
    }

    private func memberStat(title: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(EKitapligimPalette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.caption2)
                .foregroundStyle(EKitapligimPalette.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .ekitapligimCard(radius: 14)
    }

    private func aboutCard(_ member: MemberDTO) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.membersAboutSection).font(.headline).foregroundStyle(EKitapligimPalette.ink)
            if !member.about.isEmpty { Text(member.about).foregroundStyle(EKitapligimPalette.profileInk) }
            if !member.location.isEmpty {
                Label(member.location, systemImage: "mappin.and.ellipse")
                    .font(.subheadline)
                    .foregroundStyle(EKitapligimPalette.muted)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ekitapligimCard(radius: 14)
    }

    private var isBlocked: Bool {
        Int(memberID).map(container.blockedUserIDs.contains) == true
    }

    private func actionsCard(_ member: MemberDTO) -> some View {
        VStack(spacing: 10) {
            if member.canFollow || member.isFollowed {
                Button(member.isFollowed ? L10n.membersUnfollow : L10n.membersFollow) {
                    Task { await toggleFollow(member) }
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(EKitapligimPalette.teal, in: RoundedRectangle(cornerRadius: 12))
                .disabled(isActing)
            }

            if isBlocked {
                Button(L10n.membersUnblock) {
                    showUnblockConfirmation = true
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(EKitapligimPalette.tealDark)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(EKitapligimPalette.tealSoft, in: RoundedRectangle(cornerRadius: 12))
                .disabled(isActing || Int(member.id) == nil)
            } else {
                Button(L10n.membersBlockAndReport) {
                    showBlockAndReport = true
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(EKitapligimPalette.danger, in: RoundedRectangle(cornerRadius: 12))
                .disabled(isActing || Int(member.id) == nil)

                Button(L10n.membersBlock) {
                    showBlockConfirmation = true
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(EKitapligimPalette.danger)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .disabled(isActing || Int(member.id) == nil)
            }
        }
        .padding(16)
        .ekitapligimCard(radius: 14)
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            member = try await container.members.member(id: memberID)
        } catch {
            errorMessage = L10n.membersProfileLoadFailed
        }
    }

    private func toggleFollow(_ current: MemberDTO) async {
        guard !isActing else { return }
        isActing = true
        defer { isActing = false }
        do {
            let result = current.isFollowed
                ? try await container.members.unfollow(id: current.id)
                : try await container.members.follow(id: current.id)
            member = result.member
        } catch {
            operationError = L10n.membersActionFailed
        }
    }

    private func block() async {
        guard let userID = Int(memberID), !isActing else { return }
        isActing = true
        defer { isActing = false }
        do {
            _ = try await container.safety.blockMember(userID: userID)
            container.rememberBlockedUser(userID)
            blockCompleted = true
        } catch {
            operationError = L10n.membersActionFailed
        }
    }

    private func unblock() async {
        guard let userID = Int(memberID), !isActing else { return }
        isActing = true
        defer { isActing = false }
        do {
            _ = try await container.safety.unblockMember(userID: userID)
            container.forgetBlockedUser(userID)
            unblockCompleted = true
        } catch {
            operationError = L10n.membersActionFailed
        }
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
