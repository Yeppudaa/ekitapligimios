import XCTest
import EkitapligimCore
@testable import Ekitapligim

@MainActor
final class ProfileEditorModelTests: XCTestCase {
    func testLateProfileLoadsAndRefreshPreservesUnsavedDraft() throws {
        let model = ProfileEditorModel()
        let session = UUID()
        configure(model, profile: nil, session: session)
        XCTAssertFalse(model.canSave)
        configure(model, profile: try profile(), session: session)
        XCTAssertEqual(model.about, "Server about")
        model.about = "Unsaved draft"
        model.location = "İzmir"
        model.website = "https://example.invalid/reader"
        model.activityVisible = false
        configure(model, profile: try profile(about: "Refreshed server about"), session: session)
        XCTAssertEqual(model.about, "Unsaved draft")
        XCTAssertEqual(model.location, "İzmir")
        XCTAssertEqual(model.website, "https://example.invalid/reader")
        XCTAssertFalse(model.activityVisible)
    }

    func testSaveTrimsAndEnforcesExistingFieldLimits() async throws {
        let account = try profile()
        let model = ProfileEditorModel()
        let calls = ProfileEditorCalls()
        model.configure(profile: account, sessionID: UUID(), save: { fields in
            await calls.save(fields); return account
        }, upload: { _, _ in })
        model.about = String(repeating: "ş", count: 5_100)
        model.location = "  İstanbul  "
        model.website = String(repeating: "a", count: 220)
        model.activityVisible = false
        let result = await model.save()
        let sent = await calls.saved
        XCTAssertEqual(result?.id, account.id)
        XCTAssertEqual(sent?.about.count, 5_000)
        XCTAssertEqual(sent?.location, "İstanbul")
        XCTAssertEqual(sent?.website.count, 200)
        XCTAssertEqual(sent?.activityVisible, false)
        XCTAssertFalse(model.isSaving)
    }

    func testServerPermissionsDisableOperationsBeforeCallingRepository() async throws {
        let account = try profile(canEdit: false, canUpload: false)
        let calls = ProfileEditorCalls()
        let model = ProfileEditorModel()
        model.configure(profile: account, sessionID: UUID(), save: { fields in
            await calls.save(fields); return account
        }, upload: { _, _ in await calls.upload() })
        let saved = await model.save()
        let uploaded = await model.upload(kind: .avatar) { Data([1]) }
        XCTAssertNil(saved)
        XCTAssertFalse(uploaded)
        XCTAssertFalse(model.canUploadBanner)
        let count = await calls.uploads
        let fields = await calls.saved
        XCTAssertEqual(count, 0)
        XCTAssertNil(fields)
    }

    func testUploadBusyStateIncludesPhotoLoadingAndPreventsOverlappingSave() async throws {
        let account = try profile()
        let calls = ProfileEditorCalls()
        let started = expectation(description: "Photo loading")
        let gate = ProfilePhotoGate(started: started)
        let model = ProfileEditorModel()
        model.configure(profile: account, sessionID: UUID(), save: { fields in
            await calls.save(fields); return account
        }, upload: { _, _ in await calls.upload() })
        let task = Task { await model.upload(kind: .avatar) { await gate.load() } }
        await fulfillment(of: [started], timeout: 3)
        XCTAssertEqual(model.uploadingKind, .avatar)
        let saved = await model.save()
        let overlap = await model.upload(kind: .banner) { Data([1]) }
        XCTAssertNil(saved)
        XCTAssertFalse(overlap)
        await gate.release()
        let success = await task.value
        XCTAssertTrue(success)
        XCTAssertFalse(model.isBusy)
        let count = await calls.uploads
        let fields = await calls.saved
        XCTAssertEqual(count, 1)
        XCTAssertNil(fields)
    }

    func testOldAccountSaveResponseIsRejectedAndNewDraftSurvives() async throws {
        let old = try profile()
        let new = try profile(id: "2", about: "New account")
        let started = expectation(description: "Save suspended")
        let gate = ProfileSaveGate(value: old, started: started)
        let model = ProfileEditorModel()
        model.configure(profile: old, sessionID: UUID(), save: { _ in await gate.run() }, upload: { _, _ in })
        let task = Task { await model.save() }
        await fulfillment(of: [started], timeout: 3)
        configure(model, profile: new, session: UUID())
        model.about = "New unsaved draft"
        await gate.release()
        let result = await task.value
        XCTAssertNil(result)
        XCTAssertEqual(model.about, "New unsaved draft")
        XCTAssertFalse(model.isBusy)
    }

    func testPostUploadRefreshCannotRaceWithSave() async throws {
        let account = try profile()
        let started = expectation(description: "Post-upload profile refresh")
        let gate = ProfilePhotoGate(started: started)
        let model = ProfileEditorModel()
        configure(model, profile: account, session: UUID())
        model.about = "Unsaved text"
        let task = Task {
            await model.upload(kind: .avatar, refresh: { _ = await gate.load() }) { Data([1]) }
        }
        await fulfillment(of: [started], timeout: 3)
        XCTAssertTrue(model.isBusy)
        XCTAssertFalse(model.canSave)
        let saved = await model.save()
        XCTAssertNil(saved)
        await gate.release()
        let result = await task.value
        XCTAssertTrue(result)
        XCTAssertTrue(model.canSave)
        XCTAssertEqual(model.about, "Unsaved text")
    }

    func testAccountSwitchDuringPhotoLoadingNeverUploadsOldPhoto() async throws {
        let account = try profile()
        let started = expectation(description: "Photo loading")
        let gate = ProfilePhotoGate(started: started)
        let calls = ProfileEditorCalls()
        let model = ProfileEditorModel()
        model.configure(profile: account, sessionID: UUID(), save: { _ in account }, upload: { _, _ in await calls.upload() })
        let task = Task { await model.upload(kind: .avatar) { await gate.load() } }
        await fulfillment(of: [started], timeout: 3)
        configure(model, profile: try profile(id: "2"), session: UUID())
        await gate.release()
        let success = await task.value
        let uploads = await calls.uploads
        XCTAssertFalse(success)
        XCTAssertEqual(uploads, 0)
        XCTAssertFalse(model.isBusy)
    }

    func testOversizedAndEmptyImagesAreRejectedLocally() async throws {
        let account = try profile()
        let calls = ProfileEditorCalls()
        let model = ProfileEditorModel()
        model.configure(profile: account, sessionID: UUID(), save: { _ in account }, upload: { _, _ in await calls.upload() })
        let empty = await model.upload(kind: .avatar) { Data() }
        let oversized = await model.upload(kind: .banner) { Data(count: ProfileEditorModel.maxImageBytes + 1) }
        XCTAssertFalse(empty)
        XCTAssertFalse(oversized)
        XCTAssertEqual(model.uploadError, L10n.profileEditImageTooLarge)
        let uploads = await calls.uploads
        XCTAssertEqual(uploads, 0)
        XCTAssertTrue(model.canSave)
    }

    func testDisposedEditorChecksLiveSessionBeforeSendingPhotoWithoutReconfiguration() async throws {
        let account = try profile()
        let started = expectation(description: "Photo loading in old view")
        let gate = ProfilePhotoGate(started: started)
        let calls = ProfileEditorCalls()
        let identity = ProfileEditorIdentity()
        let model = ProfileEditorModel()
        model.configure(profile: account, sessionID: UUID(), save: { _ in account },
                        upload: { _, _ in await calls.upload() }, isCurrentSession: { identity.isCurrent })
        let task = Task { await model.upload(kind: .avatar) { await gate.load() } }
        await fulfillment(of: [started], timeout: 3)
        identity.isCurrent = false
        await gate.release()
        let result = await task.value
        let uploads = await calls.uploads
        XCTAssertFalse(result)
        XCTAssertEqual(uploads, 0)
        XCTAssertFalse(model.canSave)
        let saved = await model.save()
        XCTAssertNil(saved)
    }

    func testSaveFailureKeepsDraftAndCanRetry() async throws {
        let account = try profile()
        let session = UUID()
        let model = ProfileEditorModel()
        model.configure(profile: account, sessionID: session, save: { _ in throw ProfileEditorTestError.offline }, upload: { _, _ in })
        model.about = "Do not lose this"
        let first = await model.save()
        XCTAssertNil(first)
        XCTAssertEqual(model.errorMessage, L10n.profileEditSaveFailed)
        XCTAssertEqual(model.about, "Do not lose this")
        configure(model, profile: account, session: session)
        let retry = await model.save()
        XCTAssertEqual(retry?.id, account.id)
        XCTAssertNil(model.errorMessage)
    }

    private func configure(_ model: ProfileEditorModel, profile: ProfileDTO?, session: UUID) {
        model.configure(profile: profile, sessionID: session, save: { _ in
            guard let profile else { throw ProfileEditorTestError.offline }; return profile
        }, upload: { _, _ in })
    }

    private func profile(id: String = "1", about: String = "Server about", canEdit: Bool = true, canUpload: Bool = true) throws -> ProfileDTO {
        let data = try JSONSerialization.data(withJSONObject: ["id": id, "username": "reader", "about": about,
            "canEdit": canEdit, "canUploadAvatar": canUpload, "canUploadBanner": canUpload])
        return try JSONDecoder().decode(ProfileDTO.self, from: data)
    }
}

private enum ProfileEditorTestError: Error { case offline }
@MainActor private final class ProfileEditorIdentity { var isCurrent = true }
private actor ProfileEditorCalls {
    var saved: ProfileEditorFields?
    var uploads = 0
    func save(_ fields: ProfileEditorFields) { saved = fields }
    func upload() { uploads += 1 }
}
private actor ProfilePhotoGate {
    let started: XCTestExpectation
    var continuation: CheckedContinuation<Data, Never>?
    init(started: XCTestExpectation) { self.started = started }
    func load() async -> Data { await withCheckedContinuation { continuation = $0; started.fulfill() } }
    func release() { continuation?.resume(returning: Data([1, 2, 3])); continuation = nil }
}
private actor ProfileSaveGate {
    let value: ProfileDTO
    let started: XCTestExpectation
    var continuation: CheckedContinuation<ProfileDTO, Never>?
    init(value: ProfileDTO, started: XCTestExpectation) { self.value = value; self.started = started }
    func run() async -> ProfileDTO { await withCheckedContinuation { continuation = $0; started.fulfill() } }
    func release() { continuation?.resume(returning: value); continuation = nil }
}
