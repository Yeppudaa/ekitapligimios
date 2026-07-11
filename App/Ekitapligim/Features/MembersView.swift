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
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading && members.isEmpty {
                ProgressView(L10n.membersLoading)
            } else if let errorMessage, members.isEmpty {
                ContentUnavailableView(L10n.membersUnavailableTitle, systemImage: "wifi.exclamationmark", description: Text(errorMessage))
            } else if members.isEmpty {
                ContentUnavailableView(L10n.membersEmptyTitle, systemImage: "person.3", description: Text(L10n.membersEmptyDescription))
            } else {
                List {
                    Section {
                        LabeledContent(L10n.membersTotalLabel, value: "\(total)")
                        Picker(L10n.membersSortLabel, selection: $sort) {
                            Text(L10n.membersSortAlphabetical).tag("alphabetical")
                            Text(L10n.membersSortNewest).tag("newest")
                            Text(L10n.membersSortActive).tag("active")
                        }
                        .pickerStyle(.menu)
                        .onChange(of: sort) { _, _ in Task { await load(reset: true) } }
                    }
                    ForEach(members) { member in
                        NavigationLink {
                            MemberProfileView(memberID: member.id)
                        } label: {
                            MemberRow(member: member)
                        }
                    }
                    if currentPage < lastPage {
                        Button(L10n.commonLoadMore) { Task { await load(reset: false) } }
                            .disabled(isLoading)
                    }
                }
            }
        }
        .navigationTitle(L10n.membersTitle)
        .searchable(text: $query, prompt: L10n.membersSearchPrompt)
        .onSubmit(of: .search) { Task { await load(reset: true) } }
        .task { await load(reset: true) }
    }

    private func load(reset: Bool) async {
        guard !isLoading else { return }
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
private struct MemberProfileView: View {
    @EnvironmentObject private var container: AppContainer
    let memberID: String

    @State private var member: MemberDTO?
    @State private var isLoading = false
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
        Group {
            if isLoading && member == nil {
                ProgressView(L10n.membersProfileLoading)
            } else if let errorMessage, member == nil {
                ContentUnavailableView(L10n.membersUnavailableTitle, systemImage: "wifi.exclamationmark", description: Text(errorMessage))
            } else if let member {
                List {
                    Section {
                        HStack(spacing: 14) {
                            AsyncImage(url: URL(string: member.avatarUrl)) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Image(systemName: "person.crop.circle.fill").resizable().foregroundStyle(.secondary)
                            }
                            .frame(width: 72, height: 72)
                            .clipShape(Circle())
                            .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(member.username).font(.title3.weight(.semibold))
                                Text(member.roleLabel.isEmpty ? member.userTitle : member.roleLabel)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Section(L10n.membersStatsSection) {
                        LabeledContent(L10n.membersMessagesLabel, value: "\(member.messageCount)")
                        LabeledContent(L10n.membersReactionsLabel, value: "\(member.reactionScore)")
                        if member.registerDate > 0 {
                            LabeledContent(L10n.membersJoinedLabel) {
                                Text(Date(timeIntervalSince1970: TimeInterval(member.registerDate)), format: .dateTime.day().month().year())
                            }
                        }
                    }

                    if !member.about.isEmpty || !member.location.isEmpty {
                        Section(L10n.membersAboutSection) {
                            if !member.about.isEmpty { Text(member.about) }
                            if !member.location.isEmpty { LabeledContent(L10n.membersLocationLabel, value: member.location) }
                        }
                    }

                    if isSignedIn {
                        Section(L10n.membersActionsSection) {
                            if member.canFollow || member.isFollowed {
                                Button(member.isFollowed ? L10n.membersUnfollow : L10n.membersFollow) {
                                    Task { await toggleFollow(member) }
                                }
                                .disabled(isActing)
                            }
                            Button(L10n.membersBlock, role: .destructive) {
                                showBlockConfirmation = true
                            }
                            .disabled(isActing || Int(member.id) == nil)
                        }
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
            try await container.safety.blockMember(userID: userID)
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
