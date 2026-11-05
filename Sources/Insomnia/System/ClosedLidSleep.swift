import Foundation
import IOKit
import IOKit.pwr_mgt

/// Restoring SleepDisabled permits sleep but does not replay a lid-close
/// event. Request normal system sleep only after recovery has been published,
/// and only when the kernel's current clamshell policy calls for it.
enum ClosedLidSleep {
    static let flag = "--sleep-if-lid-closed"

    struct Snapshot {
        var closed: Bool?
        var causesSleep: Bool?
        var sleepDisabled: Bool?
        var eligible: Bool { closed == true && causesSleep == true && sleepDisabled == false }
    }

    static func snapshot() -> Snapshot {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard service != 0 else { return Snapshot() }
        defer { IOObjectRelease(service) }
        func read(_ key: String) -> Bool? {
            IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Bool
        }
        return Snapshot(closed: read("AppleClamshellState"), causesSleep: read("AppleClamshellCausesSleep"), sleepDisabled: read("SleepDisabled"))
    }

    static func request(read: () -> Snapshot = snapshot,
                        sleep: () -> IOReturn = systemSleep) throws -> Bool {
        guard read().eligible else { return false }
        let result = sleep()
        guard result == kIOReturnSuccess else {
            throw DisplayPowerError(what: "closed-lid system sleep request failed (\(result))")
        }
        return true
    }

    private static func systemSleep() -> IOReturn {
        let connection = IOPMFindPowerManagement(0)
        guard connection != 0 else { return kIOReturnNotReady }
        defer { IOServiceClose(connection) }
        // Recheck after acquiring the connection, as the lid may have opened.
        guard snapshot().eligible else { return kIOReturnAborted }
        return IOPMSleepSystem(connection)
    }

    /// Both callers hold the recovery lock. Never sleep with a live session,
    /// un-restored system changes, unreadable journal or unfinished command.
    static func afterCleanup(paths: Paths, perform: () throws -> Bool = { try request() }) throws -> Bool {
        let store = Store(paths: paths)
        guard let state = try store.loadState(), !state.isDirtyApartFromAppOnlyEntries,
              !FileManager.default.fileExists(atPath: paths.unfinishedCommandFile.path)
        else { return false }
        if let session = try store.loadSession(), session.endsAt > Date() { return false }
        return try perform()
    }
}
