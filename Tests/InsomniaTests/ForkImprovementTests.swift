import Foundation
import XCTest
@testable import Insomnia

@MainActor
final class ForkLidRecoveryTests: XCTestCase {
    var h: Harness!
    override func setUp() async throws { h = Harness() }
    override func tearDown() async throws { h.home.destroy() }

    func testClosedLidEndRestoresSleepButDefersDisplayUntilOpen() async throws {
        let m = h.makeManager()
        await m.start(duration: 120)
        _ = await m.setLowPower(true)
        try m.journal {
            $0.savedDisplayBrightness = 0.8
            $0.savedKeyboardBrightness = 0.3
        }
        h.clamshell.closed = true
        let outcome = await m.end(reason: .timer)
        XCTAssertEqual(outcome, .incomplete(agentArmed: true))
        XCTAssertFalse(m.state.sleepDisabledByUs)
        XCTAssertFalse(m.state.lowPowerSetByUs)
        XCTAssertNil(m.session)
        XCTAssertTrue(m.displayRestoreWaitingForLid)
        XCTAssertEqual(h.display.wakes, 0)
        XCTAssertTrue(h.display.sets.isEmpty)
        XCTAssertTrue(h.keyboard.sets.isEmpty)
        XCTAssertEqual(try h.store.loadState()?.savedDisplayBrightness, 0.8)
        await m.restoreLidActionsAfterLidOpens()
        XCTAssertTrue(h.display.sets.isEmpty)
        h.clamshell.closed = false
        await m.restoreLidActionsAfterLidOpens()
        XCTAssertEqual(h.display.wakes, 1)
        XCTAssertEqual(h.display.sets, [0.8])
        XCTAssertEqual(h.keyboard.sets, [0.3])
        XCTAssertFalse(m.displayRestoreWaitingForLid)
        XCTAssertFalse(m.state.isDirty)
        XCTAssertNil(try h.store.loadSession())
    }

    func testRelaunchWithDeferredBrightnessDoesNotWakeClosedPanel() async throws {
        var state = RuntimeState()
        state.savedDisplayBrightness = 0.7
        state.sleepDisabledByUs = true
        try h.store.saveState(state)
        h.clamshell.closed = true
        let m = h.makeManager()
        await m.reconcile()
        XCTAssertFalse(m.state.sleepDisabledByUs)
        XCTAssertTrue(m.displayRestoreWaitingForLid)
        XCTAssertTrue(h.display.sets.isEmpty)
        h.clamshell.closed = false
        await m.restoreLidActionsAfterLidOpens()
        XCTAssertEqual(h.display.sets, [0.7])
        XCTAssertFalse(m.state.isDirty)
    }

    func testUnknownLidKeepsSavedBrightnessUntilKnownOpen() async throws {
        var state = RuntimeState()
        state.savedDisplayBrightness = 0.7
        try h.store.saveState(state)
        h.clamshell.closed = nil
        let m = h.makeManager()
        await m.reconcile()
        XCTAssertEqual(h.display.wakes, 0)
        XCTAssertEqual(try h.store.loadState()?.savedDisplayBrightness, 0.7)
        h.clamshell.closed = false
        await m.restoreLidActionsAfterLidOpens()
        XCTAssertEqual(h.display.sets, [0.7])
    }

    func testFailedDisplayRestoreAfterOpenKeepsJournal() async throws {
        var state = RuntimeState()
        state.savedDisplayBrightness = 0.7
        try h.store.saveState(state)
        h.clamshell.closed = true
        let m = h.makeManager()
        await m.reconcile()
        h.display.throwOnSet = true
        h.clamshell.closed = false
        await m.restoreLidActionsAfterLidOpens()
        XCTAssertEqual(try h.store.loadState()?.savedDisplayBrightness, 0.7)
        XCTAssertFalse(m.state.sleepDisabledByUs)
        XCTAssertNotNil(m.lastError)
        h.display.throwOnSet = false
        await m.end(reason: .user)
        XCTAssertNil(try h.store.loadState()?.savedDisplayBrightness)
    }
}

@MainActor
final class ForkScreenLockTests: XCTestCase {
    final class Lock: ScreenLocking {
        var external = false
        var fail = false
        var requests = 0
        func hasExternalDisplay() throws -> Bool { external }
        func lock() async throws {
            requests += 1
            if fail { throw ScreenLockError(message: "test lock unavailable") }
        }
    }

    func testLockPolicyAndFailureEndsSession() async throws {
        for (external, docked, enabled, shouldFail, expected) in [
            (false, false, true, false, 1),
            (true, false, true, false, 0),
            (true, true, true, false, 1),
            (false, false, false, false, 0),
            (false, false, true, true, 1)
        ] {
            let h = Harness()
            defer { h.home.destroy() }
            let m = h.makeManager()
            m.config.lockOnLidClose = enabled
            m.config.lockWithExternalDisplay = docked
            let lock = Lock(); lock.external = external; lock.fail = shouldFail
            let freezer = FakeFreezer(apps: [], processes: [], control: h.procs)
            let actions = LidActions(manager: m, freezer: freezer,
                docker: DockerRule(freezer: freezer, probe: { false }),
                audio: h.audio, display: h.display, keyboard: h.keyboard, screenLock: lock)
            await m.start(duration: 120)
            await actions.onClose()
            XCTAssertEqual(lock.requests, expected)
            XCTAssertEqual(m.isActive, !shouldFail)
            if shouldFail {
                XCTAssertFalse(m.state.sleepDisabledByUs)
                XCTAssertTrue(h.display.sets.isEmpty, "must not darken after an unconfirmed lock")
                XCTAssertTrue(m.lastError?.contains("screen lock failed") == true)
            }
        }
    }

    func testOldConfigurationGetsLockingDefaultAndOptOutPersists() throws {
        let old = try JSONDecoder().decode(Config.self, from: Data("{}".utf8))
        XCTAssertTrue(old.lockOnLidClose)
        XCTAssertFalse(old.lockWithExternalDisplay)
        let optedOut = try JSONDecoder().decode(Config.self, from: Data(#"{"lockOnLidClose":false,"lockWithExternalDisplay":true}"#.utf8))
        XCTAssertFalse(optedOut.lockOnLidClose)
        XCTAssertTrue(optedOut.lockWithExternalDisplay)
    }
}

@MainActor
final class ForkRecoveryHealthTests: XCTestCase {
    func testHealthDistinguishesMissingUnrunFailedAndSuccessfulJobs() {
        func parse(_ text: String, status: Int32 = 0) -> RecoveryHealthSnapshot {
            .parse(ShellResult(status: status, stdout: text, stderr: ""))
        }
        XCTAssertTrue(parse("", status: 113).warning)
        XCTAssertTrue(parse("runs = 1\nlast exit code = 0").warning, "missing poll schedule")
        XCTAssertTrue(parse("run interval = 60 seconds\nruns = 1\nlast exit code = 1").warning)
        XCTAssertTrue(parse("run interval = 60 seconds\nruns = 0").summary.contains("no completed run"))
        XCTAssertFalse(parse("run interval = 60 seconds\nruns = 1\nlast exit code = 0").warning)
    }

    func testDiagnosticsExcludeSensitiveStateAndShowPendingCleanup() async throws {
        let h = Harness(); defer { h.home.destroy() }
        let m = h.makeManager()
        m.config.hotspotSSID = "secret-network"
        try m.journal { $0.savedAudioOutputs = [.init(deviceUID: "private-device-id", name: "Personal headphones", volume: 0.5, muted: false, saveID: nil)] }
        let health = RecoveryHealth(read: { ShellResult(status: 0, stdout: "run interval = 60 seconds\nruns = 2\nlast exit code = 0", stderr: "") })
        await health.refresh()
        let report = RecoverySummary.diagnostics(manager: m, health: health, sleepDisabled: false)
        XCTAssertTrue(report.contains("Cleanup pending"))
        XCTAssertTrue(report.contains("SleepDisabled readback: 0"))
        for secret in ["secret-network", "private-device-id", "Personal headphones", h.home.paths.appSupport.path] {
            XCTAssertFalse(report.contains(secret))
        }
    }

    func testForkBuildIdentityAndReleaseCheckNeverFetchesUpstream() async {
        struct NeverFetch: ReleaseFetching {
            func latestRelease() async throws -> Data? { XCTFail("fork contacted upstream"); return nil }
            func releases() async throws -> Data { XCTFail("fork contacted upstream"); return Data("[]".utf8) }
        }
        let build = AppBuild(info: ["CFBundleShortVersionString": "0.1.0", "CFBundleVersion": "1", "InsomniaForkName": "Personal fork", "InsomniaForkVersion": "0.2.0", "InsomniaSourceRevision": "abcd1234"])
        XCTAssertTrue(build.isFork)
        XCTAssertEqual(build.label, "Personal fork 0.2.0 · abcd1234")
        let checker = ReleaseChecker(fetcher: NeverFetch(), installed: build)
        checker.check()
        if case .failed = checker.state {} else { XCTFail("fork must not check upstream releases") }
    }
}
