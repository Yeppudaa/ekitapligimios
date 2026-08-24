import SwiftUI
import PhotosUI
import EkitapligimCore

@MainActor
struct ProfileEditView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss

    @State private var about = ""
    @State private var location = ""
    @State private var website = ""
    @State private var activityVisible = true
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var hasLoadedFields = false

    @State private var avatarSelection: PhotosPickerItem?
    @State private var bannerSelection: PhotosPickerItem?
    @State private var uploadingKind: ProfileImageKind?
    @State private var uploadError: String?

    /// XenForo rejects oversized uploads, so the client stops them before spending bandwidth.
    private static let maxImageBytes = 12 * 1024 * 1024

    private var profile: ProfileDTO? { container.profileState }

    var body: some View {
        EKitapligimScreen {
            Form {
                imageSection
            generalSection
            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(EKitapligimPalette.danger) }
            }
            Section {
                Button(isSaving ? L10n.profileEditSaving : L10n.profileEditSave) {
                    Task { await save() }
                }
                .disabled(isSaving)
            }
            }
            .ekitapligimListScreen()
        }
        .navigationTitle(L10n.profileEditTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task { loadFieldsIfNeeded() }
        .onChange(of: avatarSelection) { _, item in
            guard let item else { return }
            Task { await upload(item: item, kind: .avatar) }
        }
        .onChange(of: bannerSelection) { _, item in
            guard let item else { return }
            Task { await upload(item: item, kind: .banner) }
        }
    }

    private var imageSection: some View {
        Section(L10n.profileEditPhotoSection) {
            HStack(spacing: 14) {
                EKAvatar(urlString: profile?.avatarUrl, username: profile?.username ?? "", size: 62)
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.profileEditAvatar)
                        .font(.subheadline.weight(.semibold))
                    PhotosPicker(selection: $avatarSelection, matching: .images, photoLibrary: .shared()) {
                        Text(uploadingKind == .avatar ? L10n.profileEditUploading : L10n.profileEditChoosePhoto)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(EKitapligimPalette.teal)
                    }
                    .disabled(uploadingKind != nil || profile?.canUploadAvatar == false)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 14) {
                bannerPreview
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.profileEditBanner)
                        .font(.subheadline.weight(.semibold))
                    PhotosPicker(selection: $bannerSelection, matching: .images, photoLibrary: .shared()) {
                        Text(uploadingKind == .banner ? L10n.profileEditUploading : L10n.profileEditChoosePhoto)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(EKitapligimPalette.teal)
                    }
                    .disabled(uploadingKind != nil || profile?.canUploadBanner == false)
                }
                Spacer(minLength: 0)
            }

            if let uploadError {
                Text(uploadError)
                    .font(.caption)
                    .foregroundStyle(EKitapligimPalette.danger)
            }
        }
    }

    private var bannerPreview: some View {
        ZStack {
            EKitapligimPalette.profileBannerGradient
            if let bannerUrl = profile?.bannerUrl,
               !bannerUrl.isEmpty,
               let url = URL(string: bannerUrl),
               url.scheme?.lowercased() == "https" {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    }
                }
            }
        }
        .frame(width: 96, height: 54)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityHidden(true)
    }

    private var generalSection: some View {
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
    }

    private func loadFieldsIfNeeded() {
        guard !hasLoadedFields, let profile else { return }
        about = profile.about ?? ""
        location = profile.location ?? ""
        website = profile.website ?? ""
        activityVisible = profile.activityVisible ?? true
        hasLoadedFields = true
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
            container.updateProfile(updated)
            dismiss()
        } catch {
            errorMessage = L10n.profileEditSaveFailed
        }
    }

    private func upload(item: PhotosPickerItem, kind: ProfileImageKind) async {
        uploadingKind = kind
        uploadError = nil
        defer {
            uploadingKind = nil
            if kind == .avatar { avatarSelection = nil } else { bannerSelection = nil }
        }

        guard let data = try? await item.loadTransferable(type: Data.self) else {
            uploadError = L10n.profileEditUploadFailed
            return
        }
        guard data.count <= Self.maxImageBytes else {
            uploadError = L10n.profileEditImageTooLarge
            return
        }

        do {
            _ = try await container.profile.uploadImage(
                kind: kind,
                fileName: kind == .avatar ? "avatar.jpg" : "banner.jpg",
                mimeType: "image/jpeg",
                data: data
            )
            await container.refreshSessionData()
        } catch where error.isMissingEndpoint {
            uploadError = L10n.profileEditUploadUnavailable
        } catch {
            uploadError = (error as? APIClientError)?.serverMessage ?? L10n.profileEditUploadFailed
        }
    }
}
