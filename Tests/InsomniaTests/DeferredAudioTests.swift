import Foundation
import Testing
@testable import Insomnia

@Suite(.serialized)
@MainActor
struct DeferredAudioTests {
    private func saveMutedOutput(_ h: Harness, manager: SessionManager) throws {
        try manager.journal { $0.savedAudioOutputs = [SavedAudioOutput(deviceUID: FakeAudioControl.speakers, name: "Test output", volume: 0.6, muted: false, saveID: nil)] }
        try h.audio.mute(deviceUID: FakeAudioControl.speakers)
    }

    @Test(arguments: [true, nil] as [Bool?])
    func endKeepsAudioMutedUntilKnownOpen(lid: Bool?) async throws {
        let h = Harness(); defer { h.home.destroy() }
        let m = h.makeManager()
        await m.start(duration: 120)
        try saveMutedOutput(h, manager: m)
        h.clamshell.closed = lid
        let result = await m.end(reason: .timer)
        #expect(result == .incomplete(agentArmed: true))
        #expect(h.audio.muted)
        #expect(h.audio.applied.isEmpty)
        #expect(m.audioRestoreWaitingForLid)
        #expect(!h.guardFake.sleepDisabled)
        #expect(m.session == nil)
        #expect(try h.store.loadState()?.savedAudioOutputs.count == 1)
        #expect(RecoverySummary.lines(manager: m).contains("Audio saved · waiting for lid to open"))
        await m.outputDevicesChanged()
        await m.restoreLidActionsAfterLidOpens()
        #expect(h.audio.applied.isEmpty)
        h.clamshell.closed = false
        await m.restoreLidActionsAfterLidOpens()
        #expect(!h.audio.muted)
        #expect(h.audio.volume == 0.6)
        #expect(!m.audioRestoreWaitingForLid)
        #expect(!m.state.isDirty)
    }

    @Test
    func endedAudioOnlySessionRestoresViaTimerWithoutAnotherDeviceEvent() async throws {
        let h = Harness(); defer { h.home.destroy() }
        let m = h.makeManager()
        await m.start(duration: 120)
        try saveMutedOutput(h, manager: m)
        h.clamshell.closed = true
        await m.end(reason: .timer)
        #expect(m.session == nil)
        #expect(!m.displayRestoreWaitingForLid)
        h.clamshell.closed = false
        let deadline = Date().addingTimeInterval(8)
        while h.audio.muted, Date() < deadline {
            try? await Task.sleep(for: .milliseconds(25))
        }
        #expect(!h.audio.muted, "audio-only cleanup must not depend on a brightness entry or a device reconnect")
        #expect(!m.state.isDirty)
    }

    @Test
    func audioOnlyJournalOnRelaunchWaitsForOpen() async throws {
        let h = Harness(); defer { h.home.destroy() }
        let previous = h.makeManager()
        try saveMutedOutput(h, manager: previous)
        h.clamshell.closed = true
        let m = h.makeManager()
        await m.reconcile()
        #expect(m.audioRestoreWaitingForLid)
        #expect(h.audio.muted)
        #expect(h.audio.applied.isEmpty)
        h.clamshell.closed = false
        await m.restoreLidActionsAfterLidOpens()
        #expect(!h.audio.muted)
        #expect(!m.state.isDirty)
    }

    @Test
    func reconnectWhileClosedWaitsAndMissingDeviceIsPreservedOnOpen() async throws {
        let h = Harness(); defer { h.home.destroy() }
        let m = h.makeManager()
        h.audio.connect("headphones", volume: 0.4)
        try m.journal { $0.savedAudioOutputs = [.init(deviceUID: "headphones", name: "Test headphones", volume: 0.4, muted: false, saveID: nil)] }
        try h.audio.mute(deviceUID: "headphones")
        h.clamshell.closed = true
        await m.end(reason: .timer)
        h.audio.disconnect("headphones")
        await m.outputDevicesChanged()
        h.clamshell.closed = false
        await m.restoreLidActionsAfterLidOpens()
        #expect(m.outputsWaitingForRestore.count == 1)
        #expect(h.audio.applied.isEmpty)
        h.clamshell.closed = true
        h.audio.connect("headphones", volume: 0.4, muted: true)
        await m.outputDevicesChanged()
        #expect(h.audio.muted)
        #expect(m.audioRestoreWaitingForLid)
        h.clamshell.closed = false
        await m.restoreLidActionsAfterLidOpens()
        #expect(!h.audio.muted)
        #expect(h.audio.volume == 0.4)
        #expect(m.state.savedAudioOutputs.isEmpty)
    }

    @Test
    func manualUnmuteWhileWaitingIsNotOverwritten() async throws {
        let h = Harness(); defer { h.home.destroy() }
        let m = h.makeManager()
        try saveMutedOutput(h, manager: m)
        h.clamshell.closed = true
        await m.end(reason: .timer)
        h.audio.set(FakeAudioControl.speakers, volume: 0.2, muted: false)
        await m.outputDevicesChanged()
        #expect(!h.audio.muted)
        h.clamshell.closed = false
        await m.restoreLidActionsAfterLidOpens()
        #expect(h.audio.volume == 0.2)
        #expect(h.audio.applied.isEmpty)
        #expect(!m.state.isDirty)
    }

    @Test
    func restoreFailureKeepsJournalForRetry() async throws {
        let h = Harness(); defer { h.home.destroy() }
        let m = h.makeManager()
        try saveMutedOutput(h, manager: m)
        h.clamshell.closed = true
        await m.end(reason: .timer)
        h.audio.throwOnApply = true
        h.clamshell.closed = false
        await m.restoreLidActionsAfterLidOpens()
        #expect(h.audio.muted)
        #expect(try h.store.loadState()?.savedAudioOutputs.count == 1)
        h.audio.throwOnApply = false
        await m.outputDevicesChanged()
        #expect(!h.audio.muted)
        #expect(!m.state.isDirty)
    }

    @Test
    func journalClearFailureDoesNotUndoUserAdjustmentOnRetry() async throws {
        let h = Harness()
        defer {
            try? FileManager.default.setAttributes([.immutable: false], ofItemAtPath: h.home.paths.stateFile.path)
            h.home.destroy()
        }
        let m = h.makeManager()
        try saveMutedOutput(h, manager: m)
        h.clamshell.closed = true
        await m.end(reason: .timer)
        try FileManager.default.setAttributes([.immutable: true], ofItemAtPath: h.home.paths.stateFile.path)
        h.clamshell.closed = false
        await m.restoreLidActionsAfterLidOpens()
        #expect(!h.audio.muted)
        #expect(try h.store.loadState()?.savedAudioOutputs.count == 1)
        try FileManager.default.setAttributes([.immutable: false], ofItemAtPath: h.home.paths.stateFile.path)
        h.audio.set(FakeAudioControl.speakers, volume: 0.25, muted: false)
        await m.outputDevicesChanged()
        #expect(h.audio.volume == 0.25)
        #expect(m.state.savedAudioOutputs.isEmpty)
    }

    @Test
    func legacyAudioEntryAlsoWaitsForOpen() async throws {
        let h = Harness(); defer { h.home.destroy() }
        let m = h.makeManager()
        try m.journal { $0.savedOutputVolume = 0.6; $0.savedMuted = false }
        try h.audio.mute(deviceUID: FakeAudioControl.speakers)
        h.clamshell.closed = nil
        await m.reconcile()
        #expect(h.audio.muted)
        #expect(m.audioRestoreWaitingForLid)
        h.clamshell.closed = false
        await m.restoreLidActionsAfterLidOpens()
        #expect(!h.audio.muted)
        #expect(!m.state.isDirty)
    }
}
