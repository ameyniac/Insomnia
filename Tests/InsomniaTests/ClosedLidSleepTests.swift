import Foundation
import IOKit.pwr_mgt
import XCTest
@testable import Insomnia

final class ClosedLidSleepTests: XCTestCase {
    func testOnlyKnownClosedUndockedRestoredStateCanRequestSleep() throws {
        for closed: Bool? in [nil, false, true] {
            for policy: Bool? in [nil, false, true] {
                for disabled: Bool? in [nil, false, true] {
                    var calls = 0
                    let result = try ClosedLidSleep.request(read: {
                        .init(closed: closed, causesSleep: policy, sleepDisabled: disabled)
                    }, sleep: { calls += 1; return kIOReturnSuccess })
                    let expected = closed == true && policy == true && disabled == false
                    XCTAssertEqual(result, expected)
                    XCTAssertEqual(calls, expected ? 1 : 0)
                }
            }
        }
    }

    func testSleepRefusalIsReported() {
        XCTAssertThrowsError(try ClosedLidSleep.request(read: {
            .init(closed: true, causesSleep: true, sleepDisabled: false)
        }, sleep: { kIOReturnNotPermitted }))
    }

    func testWakeReleasesItsAssertionAndNeverReleasesAFailedDeclaration() {
        var released: [IOPMAssertionID] = []
        for _ in 0..<3 {
            DisplayPower.wakeOnce(declare: { $0 = 42; return kIOReturnSuccess },
                                  release: { released.append($0); return kIOReturnSuccess })
        }
        XCTAssertEqual(released, [42, 42, 42])
        DisplayPower.wakeOnce(declare: { _ in kIOReturnNotPermitted },
                              release: { _ in XCTFail("no assertion was acquired"); return kIOReturnSuccess })
    }

    @MainActor func testJournalGateAllowsDeferredAudioButRejectsLiveSessionAndUnfinishedWork() throws {
        let h = Harness(); defer { h.home.destroy() }
        var calls = 0
        func run() throws -> Bool {
            try ClosedLidSleep.afterCleanup(paths: h.home.paths) { calls += 1; return true }
        }
        XCTAssertFalse(try run(), "missing journal")
        var state = RuntimeState()
        state.sleepDisabledByUs = true
        try h.store.saveState(state)
        XCTAssertFalse(try run())
        state.sleepDisabledByUs = false
        state.savedDisplayBrightness = 0.8
        try h.store.saveState(state)
        XCTAssertTrue(try run(), "closed-lid brightness is intentionally deferred")
        try Data("{}".utf8).write(to: h.home.paths.unfinishedCommandFile)
        XCTAssertFalse(try run())
        try FileManager.default.removeItem(at: h.home.paths.unfinishedCommandFile)
        let session = Session(startedAt: Date(), endsAt: Date(timeIntervalSinceNow: 60))
        try h.store.saveSession(session)
        XCTAssertFalse(try run())
        XCTAssertEqual(calls, 1)
    }
}

@MainActor
final class ClosedLidEndTests: XCTestCase {
    func testTimerRequestsSleepOnlyAfterPublishedCleanup() async throws {
        let h = Harness(); defer { h.home.destroy() }
        let store = h.store
        let m = h.makeManager(requestClosedLidSleep: {
            XCTAssertNil(try store.loadSession())
            XCTAssertFalse(try XCTUnwrap(store.loadState()).sleepDisabledByUs)
            try Data("called".utf8).write(to: store.paths.appSupport.appendingPathComponent("sleep-request-test"))
            return true
        })
        await m.start(duration: 120)
        h.clamshell.closed = true
        _ = await m.end(reason: .timer)
        XCTAssertTrue(FileManager.default.fileExists(atPath: h.home.paths.appSupport.appendingPathComponent("sleep-request-test").path))
    }

    func testFailedCleanupOrOpenLidNeverRequestsSleep() async throws {
        for failed in [false, true] {
            let h = Harness(); defer { h.home.destroy() }
            let m = h.makeManager(requestClosedLidSleep: { XCTFail("must not sleep"); return true })
            await m.start(duration: 120)
            h.clamshell.closed = failed
            if failed { h.guardFake.throwOn.insert("disablesleep 0") }
            _ = await m.end(reason: .timer)
        }
    }
}
