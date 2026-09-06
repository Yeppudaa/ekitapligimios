import XCTest
@testable import EkitapligimCore

@MainActor
final class ReaderWriteQueueTests: XCTestCase {
    func testSlowShelfWriteDoesNotBlockEnqueueAndFinishesBeforeProgress() async {
        let queue = ReaderWriteQueue()
        let gate = ReaderWriteGate()
        let started = expectation(description: "Shelf request started")
        var events: [String] = []
        let shelf = queue.enqueue {
            events.append("shelf-start")
            started.fulfill()
            await gate.wait()
            events.append("shelf-finish")
        }
        let progress = queue.enqueue { events.append("progress-12") }
        await fulfillment(of: [started], timeout: 2)
        XCTAssertEqual(events, ["shelf-start"])
        await gate.release()
        await shelf.value
        await progress.value
        XCTAssertEqual(events, ["shelf-start", "shelf-finish", "progress-12"])
    }

    func testSubmittedWritesStayOrderedWhenOriginalTaskIsCancelled() async {
        let queue = ReaderWriteQueue()
        let gate = ReaderWriteGate()
        let started = expectation(description: "First progress request started")
        var storedPage = 0
        let first = queue.enqueue {
            started.fulfill()
            await gate.wait()
            storedPage = 3
        }
        await fulfillment(of: [started], timeout: 2)
        first.cancel()
        let last = queue.enqueue { storedPage = 9 }
        await gate.release()
        await last.value
        XCTAssertEqual(storedPage, 9)
    }

    func testFailedShelfOperationDoesNotStopLaterProgress() async {
        enum Failure: Error { case rejected }
        let queue = ReaderWriteQueue()
        var progressSaved = false
        queue.enqueue {
            do { throw Failure.rejected } catch { /* Existing best-effort shelf behavior. */ }
        }
        let progress = queue.enqueue { progressSaved = true }
        await progress.value
        XCTAssertTrue(progressSaved)
    }
}

private actor ReaderWriteGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var released = false

    func wait() async {
        if released { return }
        await withCheckedContinuation { continuation = $0 }
    }

    func release() {
        released = true
        continuation?.resume()
        continuation = nil
    }
}
