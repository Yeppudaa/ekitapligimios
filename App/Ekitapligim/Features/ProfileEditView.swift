import SwiftUI
import PhotosUI
import EkitapligimCore

@MainActor
struct ProfileEditView: View {
    @EnvironmentObject private var container: AppContainer

    var body: some View {
        ProfileEditorContent().id(container.sessionRevision)
    }
}

@MainActor
private struct ProfileEditorContent: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var model = ProfileEditorModel()
    @State private var avatarSelection: PhotosPickerItem?
    @State private var bannerSelection: PhotosPickerItem?
    @FocusState private var focusedField: Field?
    private enum Field: Hashable { case about, location, website }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                introduction
                imageSection
                generalSection
                if let error = model.errorMessage { errorNotice(error) }
                VStack(spacing: 10) {
                    Button {
                        focusedField = nil
                        Task { await save() }
                    } label: {
                        HStack(spacing: 10) {
                            if model.isSaving { ProgressView().tint(.white) }
                            else { Image(systemName: "checkmark.circle.fill") }
                            Text(model.isSaving ? L10n.profileEditSaving : ProfileEditorL10n.text("save"))
                        }
                    }
                    .buttonStyle(CommunityButtonStyle())
                    .disabled(!model.canSave)
                    .opacity(model.canSave ? 1 : 0.55)
                    .accessibilityIdentifier("profileEditor.save")
                    Text(ProfileEditorL10n.text("save.hint"))
                        .font(.caption).foregroundStyle(CommunityStyle.muted)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: 640)
            .padding(.horizontal, 18).padding(.top, 18).padding(.bottom, 32)
            .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("profileEditor.scroll")
        .background { CommunityStyle.page.ignoresSafeArea() }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(L10n.profileEditTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(ProfileEditorL10n.text("keyboard.done")) { focusedField = nil }
            }
        }
        .task { configure() }
        .onChange(of: container.profileState) { _, _ in configure() }
        .onChange(of: avatarSelection) { _, item in
            guard let item else { return }
            Task { await upload(item, kind: .avatar); avatarSelection = nil }
        }
        .onChange(of: bannerSelection) { _, item in
            guard let item else { return }
            Task { await upload(item, kind: .banner); bannerSelection = nil }
        }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(ProfileEditorL10n.text("eyebrow"))
                .font(.caption2.weight(.bold)).tracking(1.8).foregroundStyle(CommunityStyle.teal)
            Text(ProfileEditorL10n.text("title"))
                .font(.system(.largeTitle, design: .serif).bold()).foregroundStyle(CommunityStyle.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(ProfileEditorL10n.text("subtitle"))
                .font(.subheadline).foregroundStyle(CommunityStyle.muted)
                .fixedSize(horizontal: false, vertical: true)
        }.padding(.horizontal, 3)
    }

    private var imageSection: some View {
        CommunityCard(padding: 18) {
            VStack(alignment: .leading, spacing: 18) {
                sectionHeading("images.title", subtitle: "images.subtitle", icon: "photo.on.rectangle.angled")
                bannerPreview
                let layout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14))
                    : AnyLayout(HStackLayout(alignment: .center, spacing: 14))
                layout {
                    EKAvatar(urlString: model.profile?.avatarUrl, username: model.profile?.username ?? "", size: 76)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(model.profile?.username ?? "")
                            .font(.system(.title3, design: .serif).bold()).foregroundStyle(CommunityStyle.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("profileEditor.username")
                        Text(ProfileEditorL10n.text("images.hint"))
                            .font(.subheadline).foregroundStyle(CommunityStyle.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                VStack(spacing: 10) {
                    PhotosPicker(selection: $avatarSelection, matching: .images, photoLibrary: .shared()) {
                        pickerLabel(.avatar)
                    }
                    .buttonStyle(CommunityButtonStyle(primary: false))
                    .disabled(!model.canUploadAvatar).opacity(model.canUploadAvatar || model.uploadingKind == .avatar ? 1 : 0.55)
                    .accessibilityIdentifier("profileEditor.avatar")
                    PhotosPicker(selection: $bannerSelection, matching: .images, photoLibrary: .shared()) {
                        pickerLabel(.banner)
                    }
                    .buttonStyle(CommunityButtonStyle(primary: false))
                    .disabled(!model.canUploadBanner).opacity(model.canUploadBanner || model.uploadingKind == .banner ? 1 : 0.55)
                    .accessibilityIdentifier("profileEditor.banner")
                }
                Text(ProfileEditorL10n.text("images.limit"))
                    .font(.caption).foregroundStyle(CommunityStyle.muted)
                if let error = model.uploadError { errorNotice(error) }
            }
        }
    }

    private var bannerPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "book.pages.fill")
                .font(.title2).foregroundStyle(Color(hex: 0xE2CE9A))
            Text(ProfileEditorL10n.text("banner.quote"))
                .font(.system(.title3, design: .serif).bold()).foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20).frame(maxWidth: .infinity, minHeight: 128, alignment: .leading)
        .background(LinearGradient(colors: [CommunityStyle.ink, CommunityStyle.teal], startPoint: .leading, endPoint: .trailing))
        .overlay {
            GeometryReader { geometry in
                    if let value = model.profile?.bannerUrl, let url = URL(string: value), url.scheme?.lowercased() == "https" {
                        AsyncImage(url: url) { phase in
                            if case .success(let image) = phase {
                                image.resizable().scaledToFill()
                                    .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                            }
                        }
                    }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .accessibilityHidden(true)
    }

    private var generalSection: some View {
        CommunityCard(padding: 18) {
            VStack(alignment: .leading, spacing: 19) {
                sectionHeading(title: L10n.profileEditGeneralSection,
                               subtitle: ProfileEditorL10n.text("general.subtitle"), icon: "person.text.rectangle")
                field(title: L10n.profileEditAbout, icon: "text.alignleft", selected: focusedField == .about) {
                    TextField(ProfileEditorL10n.text("about.placeholder"), text: $model.about, axis: .vertical)
                        .lineLimit(3...8).focused($focusedField, equals: .about)
                        .accessibilityLabel(L10n.profileEditAbout)
                        .accessibilityIdentifier("profileEditor.about")
                        .onChange(of: model.about) { _, value in model.about = String(value.prefix(5_000)) }
                }
                field(title: L10n.profileEditLocation, icon: "mappin.and.ellipse", selected: focusedField == .location) {
                    TextField(ProfileEditorL10n.text("location.placeholder"), text: $model.location)
                        .textContentType(.addressCity).focused($focusedField, equals: .location)
                        .submitLabel(.next).onSubmit { focusedField = .website }
                        .accessibilityLabel(L10n.profileEditLocation)
                        .accessibilityIdentifier("profileEditor.location")
                        .onChange(of: model.location) { _, value in model.location = String(value.prefix(100)) }
                }
                field(title: L10n.profileEditWebsite, icon: "globe", selected: focusedField == .website) {
                    TextField(ProfileEditorL10n.text("website.placeholder"), text: $model.website)
                        .keyboardType(.URL).textContentType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .focused($focusedField, equals: .website).submitLabel(.done).onSubmit { focusedField = nil }
                        .accessibilityLabel(L10n.profileEditWebsite)
                        .accessibilityIdentifier("profileEditor.website")
                        .onChange(of: model.website) { _, value in model.website = String(value.prefix(200)) }
                }
                Toggle(isOn: $model.activityVisible) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(L10n.profileEditActivityVisible).font(.subheadline.weight(.semibold)).foregroundStyle(CommunityStyle.ink)
                        Text(ProfileEditorL10n.text("activity.hint")).font(.caption).foregroundStyle(CommunityStyle.muted)
                    }.fixedSize(horizontal: false, vertical: true)
                }
                .tint(CommunityStyle.teal).padding(15)
                .background(CommunityStyle.soft, in: RoundedRectangle(cornerRadius: 16))
                .accessibilityIdentifier("profileEditor.activity")
            }.disabled(model.isBusy || model.profile == nil || model.profile?.canEdit == false)
        }
    }

    private func sectionHeading(_ key: String, subtitle: String, icon: String) -> some View {
        sectionHeading(title: ProfileEditorL10n.text(key), subtitle: ProfileEditorL10n.text(subtitle), icon: icon)
    }

    private func sectionHeading(title: String, subtitle: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.title3).foregroundStyle(CommunityStyle.teal)
                .frame(width: 42, height: 42).background(CommunityStyle.soft, in: RoundedRectangle(cornerRadius: 13))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(.title3, design: .serif).bold()).foregroundStyle(CommunityStyle.ink)
                Text(subtitle).font(.caption).foregroundStyle(CommunityStyle.muted)
            }.fixedSize(horizontal: false, vertical: true)
        }
    }

    private func field<Content: View>(title: String, icon: String, selected: Bool, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon).font(.subheadline.weight(.semibold)).foregroundStyle(CommunityStyle.ink)
            content().font(.body).foregroundStyle(CommunityStyle.ink)
                .tint(CommunityStyle.teal).padding(14).frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                .background(Color(hex: 0xFAFCFA), in: RoundedRectangle(cornerRadius: 16))
                .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(selected ? CommunityStyle.teal : CommunityStyle.border, lineWidth: selected ? 1.5 : 1) }
        }
    }

    private func pickerLabel(_ kind: ProfileImageKind) -> some View {
        HStack(spacing: 9) {
            if model.uploadingKind == kind { ProgressView().tint(CommunityStyle.teal) }
            else { Image(systemName: kind == .avatar ? "person.crop.square.badge.camera" : "photo.badge.plus") }
            Text(model.uploadingKind == kind ? L10n.profileEditUploading : ProfileEditorL10n.text(kind == .avatar ? "images.avatar" : "images.banner"))
        }
    }

    private func errorNotice(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.circle.fill")
            .font(.subheadline).foregroundStyle(EKitapligimPalette.danger)
            .fixedSize(horizontal: false, vertical: true).padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(EKitapligimPalette.danger.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
            .accessibilityIdentifier("profileEditor.error")
    }

    private func configure() {
        let owner = container
        let session = owner.sessionRevision
        let profileID = owner.profileState?.id
        model.configure(repository: owner.profile, profile: owner.profileState, sessionID: session,
                        isCurrentSession: { [weak owner] in
                            guard let owner else { return false }
                            return owner.sessionRevision == session && owner.profileState?.id == profileID && owner.isSignedIn
                        })
    }

    private func save() async {
        let session = container.sessionRevision
        guard let updated = await model.save(), session == container.sessionRevision, !Task.isCancelled else { return }
        container.updateProfile(updated)
        dismiss()
    }

    private func upload(_ item: PhotosPickerItem, kind: ProfileImageKind) async {
        focusedField = nil
        let session = container.sessionRevision
        _ = await model.upload(kind: kind, refresh: {
            guard session == container.sessionRevision, !Task.isCancelled else { return }
            await container.refreshSessionData()
        }) { try await ProfilePhotoLoader.jpeg(from: item) }
    }
}
