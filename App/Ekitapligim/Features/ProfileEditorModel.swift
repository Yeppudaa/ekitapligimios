import Foundation
import Combine
import EkitapligimCore

struct ProfileEditorFields: Equatable, Sendable {
    var about: String
    var location: String
    var website: String
    var activityVisible: Bool
}

@MainActor
final class ProfileEditorModel: ObservableObject {
    typealias Save = @Sendable (ProfileEditorFields) async throws -> ProfileDTO
    typealias Upload = @Sendable (ProfileImageKind, Data) async throws -> Void
    static let maxImageBytes = 12 * 1024 * 1024

    @Published var about = ""
    @Published var location = ""
    @Published var website = ""
    @Published var activityVisible = true
    @Published private(set) var isSaving = false
    @Published private(set) var uploadingKind: ProfileImageKind?
    @Published private(set) var errorMessage: String?
    @Published private(set) var uploadError: String?
    @Published private(set) var profile: ProfileDTO?
    private var loadedFields = false
    private var sessionID: UUID?
    private var generation = UUID()
    private var saveProfile: Save?
    private var uploadPhoto: Upload?
    private var sessionIsCurrent: @MainActor () -> Bool = { false }
    var isBusy: Bool { isSaving || uploadingKind != nil }
    var canSave: Bool { loadedFields && sessionIsCurrent() && profile?.canEdit != false && !isBusy }
    var canUploadAvatar: Bool { loadedFields && sessionIsCurrent() && profile?.canUploadAvatar != false && !isBusy }
    var canUploadBanner: Bool { loadedFields && sessionIsCurrent() && profile?.canUploadBanner != false && !isBusy }

    func configure(repository: ProfileRepository, profile: ProfileDTO?, sessionID: UUID,
                   isCurrentSession: @escaping @MainActor () -> Bool) {
        configure(profile: profile, sessionID: sessionID, save: {
            try await repository.updateProfile(about: $0.about, location: $0.location,
                                               website: $0.website, activityVisible: $0.activityVisible)
        }, upload: { kind, data in
            _ = try await repository.uploadImage(kind: kind,
                fileName: kind == .avatar ? "avatar.jpg" : "banner.jpg", mimeType: "image/jpeg", data: data)
        }, isCurrentSession: isCurrentSession)
    }

    func configure(profile: ProfileDTO?, sessionID: UUID, save: @escaping Save, upload: @escaping Upload,
                   isCurrentSession: @escaping @MainActor () -> Bool = { true }) {
        if self.sessionID != sessionID || (self.profile != nil && self.profile?.id != profile?.id) {
            generation = UUID()
            loadedFields = false
            about = ""; location = ""; website = ""; activityVisible = true
            isSaving = false; uploadingKind = nil; errorMessage = nil; uploadError = nil
        }
        self.sessionID = sessionID
        self.profile = profile
        saveProfile = save
        uploadPhoto = upload
        sessionIsCurrent = isCurrentSession
        // A media upload refreshes the server profile. Never overwrite the unsaved draft.
        if !loadedFields, let profile {
            about = profile.about ?? ""
            location = profile.location ?? ""
            website = profile.website ?? ""
            activityVisible = profile.activityVisible ?? true
            loadedFields = true
        }
    }

    func save() async -> ProfileDTO? {
        guard canSave, let saveProfile else { return nil }
        let requestID = generation
        let fields = ProfileEditorFields(
            about: String(about.prefix(5_000)).trimmingCharacters(in: .whitespacesAndNewlines),
            location: String(location.prefix(100)).trimmingCharacters(in: .whitespacesAndNewlines),
            website: String(website.prefix(200)).trimmingCharacters(in: .whitespacesAndNewlines),
            activityVisible: activityVisible)
        isSaving = true
        errorMessage = nil
        defer { if generation == requestID { isSaving = false } }
        do {
            let result = try await saveProfile(fields)
            guard generation == requestID, sessionIsCurrent(), !Task.isCancelled, result.id == profile?.id else { return nil }
            return result
        } catch {
            guard generation == requestID, sessionIsCurrent(), !Task.isCancelled else { return nil }
            errorMessage = L10n.profileEditSaveFailed
            return nil
        }
    }

    /// Loading/encoding is injected by the native PhotosPicker adapter. The busy state
    /// covers that await too, preventing a save or a second picker upload from overlapping.
    func upload(kind: ProfileImageKind, refresh: () async -> Void = {}, loadJPEG: () async throws -> Data) async -> Bool {
        guard kind == .avatar ? canUploadAvatar : canUploadBanner, let uploadPhoto else { return false }
        let requestID = generation
        uploadingKind = kind
        uploadError = nil
        defer { if generation == requestID { uploadingKind = nil } }
        do {
            let data = try await loadJPEG()
            guard generation == requestID, sessionIsCurrent(), !Task.isCancelled else { return false }
            guard !data.isEmpty, data.count <= Self.maxImageBytes else {
                uploadError = data.isEmpty ? L10n.profileEditUploadFailed : L10n.profileEditImageTooLarge
                return false
            }
            try await uploadPhoto(kind, data)
            guard generation == requestID, sessionIsCurrent(), !Task.isCancelled else { return false }
            // Keep the operation busy until the server snapshot is refreshed; an older
            // refresh must not race with a new save and overwrite its profile result.
            await refresh()
            return generation == requestID && sessionIsCurrent() && !Task.isCancelled
        } catch {
            guard generation == requestID, sessionIsCurrent(), !Task.isCancelled else { return false }
            if error.isMissingEndpoint { uploadError = L10n.profileEditUploadUnavailable }
            else if error is ProfilePhotoSizeError { uploadError = L10n.profileEditImageTooLarge }
            else { uploadError = L10n.profileEditUploadFailed }
            return false
        }
    }
}

struct ProfilePhotoSizeError: Error {}
