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
                                        .padding(14)
                                        .ekitapligimCard(radius: 14)
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
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.membersTotalLabel)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(EKitapligimPalette.muted)
                Spacer()
                Text("\(total)").font(.headline.weight(.heavy)).foregroundStyle(EKitapligimPalette.tealDark)
            }
            Picker(L10n.membersSortLabel, selection: $sort) {
                Text(L10n.membersSortAlphabetical).tag("alphabetical")
                Text(L10n.membersSortNewest).tag("newest")
                Text(L10n.membersSortActive).tag("active")
            }
            .pickerStyle(.segmented)
            .onChange(of: sort) { _, _ in Task { await load(reset: true) } }
        }
        .padding(14)
        .ekitapligimCard(radius: 14)
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
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: member.avatarUrl)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .foregroundStyle(.secondary)
            }
            .frame(width: 46, height: 46)
            .clipShape(Circle())
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(member.username).font(.headline)
                    if member.showVerifiedBadge {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.blue)
                            .accessibilityLabel(L10n.membersVerified)
                    }
                }
                Text(member.roleLabel.isEmpty ? member.userTitle : member.roleLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(L10n.membersMessageCount(member.messageCount))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
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
    @State private var blockCompleted = false

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
        .alert(L10n.membersBlockCompleted, isPresented: $blockCompleted) {
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
        HStack(spacing: 14) {
            AsyncImage(url: URL(string: member.avatarUrl)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: "person.crop.circle.fill").resizable().foregroundStyle(EKitapligimPalette.muted)
            }
            .frame(width: 72, height: 72)
            .clipShape(Circle())
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(member.username).font(.title3.weight(.semibold)).foregroundStyle(EKitapligimPalette.ink)
                Text(member.roleLabel.isEmpty ? member.userTitle : member.roleLabel)
                    .foregroundStyle(EKitapligimPalette.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .ekitapligimCard()
    }

    private func statsCard(_ member: MemberDTO) -> some View {
        VStack(spacing: 10) {
            LabeledContent(L10n.membersMessagesLabel, value: "\(member.messageCount)")
            LabeledContent(L10n.membersReactionsLabel, value: "\(member.reactionScore)")
            if member.registerDate > 0 {
                LabeledContent(L10n.membersJoinedLabel) {
                    Text(Date(timeIntervalSince1970: TimeInterval(member.registerDate)), format: .dateTime.day().month().year())
                }
            }
        }
        .padding(16)
        .ekitapligimCard(radius: 14)
    }

    private func aboutCard(_ member: MemberDTO) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.membersAboutSection).font(.headline).foregroundStyle(EKitapligimPalette.ink)
            if !member.about.isEmpty { Text(member.about).foregroundStyle(EKitapligimPalette.profileInk) }
            if !member.location.isEmpty {
                LabeledContent(L10n.membersLocationLabel, value: member.location)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ekitapligimCard(radius: 14)
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
                .padding(.vertical, 12)
                .background(EKitapligimPalette.teal, in: RoundedRectangle(cornerRadius: 12))
                .disabled(isActing)
            }
            Button(L10n.membersBlock, role: .destructive) {
                showBlockConfirmation = true
            }
            .disabled(isActing || Int(member.id) == nil)
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
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
