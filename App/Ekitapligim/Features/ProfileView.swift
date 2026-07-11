import SwiftUI
import EkitapligimCore

struct ProfileView: View {
    @EnvironmentObject private var container: AppContainer

    @State private var profile: ProfileDTO?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView(L10n.profileLoading)
            } else if let errorMessage {
                ContentUnavailableView(L10n.profileUnavailableTitle, systemImage: "person.crop.circle.badge.exclamationmark", description: Text(errorMessage))
            } else if let profile {
                List {
                    Section {
                        Text(profile.username)
                            .font(.title2.bold())
                        Text(profile.email)
                            .foregroundStyle(.secondary)
                        if let title = profile.title, !title.isEmpty {
                            Text(title)
                        }
                    }

                    Section(L10n.profileStatsSection) {
                        LabeledContent(L10n.profileMessageCount, value: String(profile.messageCount ?? 0))
                        LabeledContent(L10n.profileReactionScore, value: String(profile.reactionScore ?? 0))
                        if let registerDate = profile.registerDate {
                            LabeledContent(L10n.profileRegisterDate, value: Date(timeIntervalSince1970: TimeInterval(registerDate)).formatted(date: .abbreviated, time: .omitted))
                        }
                    }

                    Section(L10n.profilePermissionsSection) {
                        LabeledContent(L10n.profileStaff, value: profile.isStaff == true ? L10n.profileYes : L10n.profileNo)
                        LabeledContent(L10n.profileCanEdit, value: profile.canEdit == true ? L10n.profileOpen : L10n.profileClosed)
                    }

                    if profile.canEdit == true {
                        Section {
                            NavigationLink {
                                ProfileEditView(profile: profile) { updated in
                                    self.profile = updated
                                }
                            } label: {
                                Label(L10n.profileEditTitle, systemImage: "pencil")
                            }
                            NavigationLink {
                                AccountSecurityView(currentEmail: profile.email) {
                                    Task { await load() }
                                }
                            } label: {
                                Label(L10n.accountSecurityTitle, systemImage: "lock.shield")
                            }
                        }
                    }
                }
            } else {
                ContentUnavailableView(L10n.profileEmptyTitle, systemImage: "person.crop.circle")
            }
        }
        .navigationTitle(L10n.profileTitle)
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            profile = try await container.profile.profile()
        } catch {
            errorMessage = L10n.profileLoadFailed
        }
    }
}

private struct ProfileEditView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss
    let profile: ProfileDTO
    let didSave: (ProfileDTO) -> Void

    @State private var about: String
    @State private var location: String
    @State private var website: String
    @State private var activityVisible: Bool
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(profile: ProfileDTO, didSave: @escaping (ProfileDTO) -> Void) {
        self.profile = profile
        self.didSave = didSave
        _about = State(initialValue: profile.about ?? "")
        _location = State(initialValue: profile.location ?? "")
        _website = State(initialValue: profile.website ?? "")
        _activityVisible = State(initialValue: profile.activityVisible ?? true)
    }

    var body: some View {
        Form {
            Section(L10n.profileEditGeneralSection) {
                TextField(L10n.profileEditAbout, text: $about, axis: .vertical)
                    .lineLimit(3...8)
                    .onChange(of: about) { _, value in about = String(value.prefix(5_000)) }
                TextField(L10n.profileEditLocation, text: $location)
                    .onChange(of: location) { _, value in location = String(value.prefix(100)) }
                TextField(L10n.profileEditWebsite, text: $website)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: website) { _, value in website = String(value.prefix(200)) }
                Toggle(L10n.profileEditActivityVisible, isOn: $activityVisible)
            }

            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(.red) }
            }

            Section {
                Button(isSaving ? L10n.profileEditSaving : L10n.profileEditSave) {
                    Task { await save() }
                }
                .disabled(isSaving)
            }
        }
        .navigationTitle(L10n.profileEditTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            let updated = try await container.profile.updateProfile(
                about: about.trimmingCharacters(in: .whitespacesAndNewlines),
                location: location.trimmingCharacters(in: .whitespacesAndNewlines),
                website: website.trimmingCharacters(in: .whitespacesAndNewlines),
                activityVisible: activityVisible
            )
            didSave(updated)
            dismiss()
        } catch {
            errorMessage = L10n.profileEditSaveFailed
        }
    }
}
