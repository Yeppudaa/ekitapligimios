import Foundation
import XCTest
import EkitapligimCore
@testable import Ekitapligim

@MainActor
final class AgendaPhotoModelTests: XCTestCase {
    func testPreparedPhotoCanBeRemovedWithoutChangingOtherComposerFields() async {
        let model = AgendaPhotoModel { _ in Data([9, 8]) }
        await model.select { Data([1]) }
        XCTAssertEqual(model.data, Data([9, 8]))
        XCTAssertFalse(model.isPreparing)
        model.remove()
        XCTAssertNil(model.data)
        XCTAssertNil(model.error)
    }

    func testFailedSelectionIsExplicitAndCanBeCleared() async {
        let model = AgendaPhotoModel { _ in throw AgendaMediaError.invalidImage }
        await model.select { Data([1]) }
        XCTAssertNil(model.data)
        XCTAssertNotNil(model.error)
        XCTAssertFalse(model.isPreparing)
        model.remove()
        XCTAssertNil(model.error)
    }

    func testMissingPickerBytesNeverReachEncoder() async {
        let model = AgendaPhotoModel { _ in XCTFail("Missing image reached encoder"); return Data() }
        await model.select { nil }
        XCTAssertNotNil(model.error)
        XCTAssertNil(model.data)
    }

    func testLateICloudResultCannotRestoreRemovedPhoto() async {
        let pending = AgendaPhotoGate()
        let model = AgendaPhotoModel { $0 }
        let operation = Task { await model.select { await pending.load() } }
        await pending.waitUntilStarted()
        XCTAssertTrue(model.isPreparing)
        model.remove()
        await pending.finish(Data([1]))
        await operation.value
        XCTAssertNil(model.data)
        XCTAssertFalse(model.isPreparing)
    }

    func testLateOldSelectionCannotReplaceNewPhoto() async {
        let pending = AgendaPhotoGate()
        let model = AgendaPhotoModel { $0 }
        let old = Task { await model.select { await pending.load() } }
        await pending.waitUntilStarted()
        await model.select { Data([2]) }
        await pending.finish(Data([1]))
        await old.value
        XCTAssertEqual(model.data, Data([2]))
        XCTAssertFalse(model.isPreparing)
    }

    func testCancelledSelectionDoesNotPublishAnImageOrError() async {
        let pending = AgendaPhotoGate()
        let model = AgendaPhotoModel { $0 }
        let operation = Task { await model.select { await pending.load() } }
        await pending.waitUntilStarted()
        operation.cancel()
        await pending.finish(Data([1]))
        await operation.value
        XCTAssertNil(model.data)
        XCTAssertNil(model.error)
        XCTAssertFalse(model.isPreparing)
    }
}

private actor AgendaPhotoGate {
    private var continuation: CheckedContinuation<Data?, Never>?
    private var started: CheckedContinuation<Void, Never>?
    func load() async -> Data? {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            started?.resume(); started = nil
        }
    }
    func waitUntilStarted() async {
        if continuation != nil { return }
        await withCheckedContinuation { started = $0 }
    }
    func finish(_ data: Data) { continuation?.resume(returning: data); continuation = nil }
}
