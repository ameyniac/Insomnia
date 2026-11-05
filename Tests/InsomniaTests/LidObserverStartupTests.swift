import Foundation
import Testing
@testable import Insomnia

/// Exercises start(), including its IOKit registration, with fake lid reads.
/// All power, audio, brightness and lock effects use the existing fakes.
@Suite(.serialized)
@MainActor
struct LidObserverStartupTests {
    private func settle(_ observer: LidObserver) async {
        var finished = false
        observer.whenSettled { _ in finished = true }
        let deadline = Date().addingTimeInterval(5)
        while !finished, Date() < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
        #expect(finished, "lid debounce did not settle")
    }

    @Test
    func closedAtStartupLocksAndMutesThenRestoresOnOpen() async throws {
        let h = Harness()
        defer { h.home.destroy() }
        let manager = h.makeManager()
        h.clamshell.closed = true
        let lock = ForkScreenLockTests.Lock()
        let freezer = FakeFreezer(apps: [], processes: [], control: h.procs)
        let actions = LidActions(manager: manager, freezer: freezer,
            docker: DockerRule(freezer: freezer, probe: { false }), audio: h.audio,
            display: h.display, keyboard: h.keyboard, screenLock: lock)
        await manager.start(duration: 120)
        var closed = true
        var events: [Bool] = []
        var action: Task<Void, Never>?
        let observer = LidObserver(read: { closed }, debounce: 0.025)
        observer.onChange = { value in
            events.append(value)
            let event = actions.lidEventArrived()
            action = Task { @MainActor in
                if value { await actions.onClose(event: event) }
                else { await actions.onOpen() }
            }
        }
        defer { observer.stop() }
        observer.start()
        await settle(observer)
        await action?.value
        #expect(events == [true])
        #expect(lock.requests == 1)
        #expect(h.audio.mutes == 1)
        #expect(h.audio.muted)
        observer.handleInterest()
        await settle(observer)
        #expect(events == [true], "duplicate notifications must not repeat the close")
        closed = false
        h.clamshell.closed = false
        observer.handleInterest()
        await settle(observer)
        await action?.value
        #expect(events == [true, false])
        #expect(!h.audio.muted)
        #expect(h.audio.volume == 0.6)
        await manager.end(reason: .user)
        #expect(!manager.state.isDirty)
    }

    @Test(arguments: [false, nil] as [Bool?])
    func openOrUnknownStartupDoesNotInventAClose(initial: Bool?) async {
        var reading = initial
        var events: [Bool] = []
        let observer = LidObserver(read: { reading }, debounce: 0.025)
        observer.onChange = { events.append($0) }
        defer { observer.stop() }
        observer.start()
        await settle(observer)
        #expect(events.isEmpty)
        reading = true
        observer.handleInterest()
        await settle(observer)
        #expect(events == [true])
    }

    @Test
    func reopenBeforeInitialDebounceRunsOnlyTheRestore() async {
        var reading = true
        var events: [Bool] = []
        let observer = LidObserver(read: { reading }, debounce: 0.025)
        observer.onChange = { events.append($0) }
        defer { observer.stop() }
        observer.start()
        reading = false
        observer.handleInterest()
        await settle(observer)
        #expect(events == [false], "reopen must restore any journal kept on relaunch without first locking or muting")
    }

    @Test
    func restartWhileClosedDeliversOneCloseForEachSession() async {
        var events: [Bool] = []
        let observer = LidObserver(read: { true }, debounce: 0.025)
        observer.onChange = { events.append($0) }
        defer { observer.stop() }
        observer.start()
        await settle(observer)
        observer.stop()
        observer.start()
        await settle(observer)
        #expect(events == [true, true])
    }

    @Test
    func closeDuringRegistrationIsNotLost() async {
        var reads = 0
        var events: [Bool] = []
        let observer = LidObserver(read: {
            reads += 1
            return reads > 1
        }, debounce: 0.025)
        observer.onChange = { events.append($0) }
        defer { observer.stop() }
        observer.start()
        await settle(observer)
        #expect(events == [true])
    }

    @Test
    func stopCancelsInitialCloseBeforeNextOpenSession() async {
        var reading = true
        var events: [Bool] = []
        let observer = LidObserver(read: { reading }, debounce: 0.025)
        observer.onChange = { events.append($0) }
        defer { observer.stop() }
        observer.start()
        observer.stop()
        reading = false
        observer.start()
        await settle(observer)
        #expect(events.isEmpty)
    }
}
