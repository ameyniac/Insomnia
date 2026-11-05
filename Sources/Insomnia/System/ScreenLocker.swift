import Foundation
import CoreGraphics

@MainActor
protocol ScreenLocking {
    func hasExternalDisplay() throws -> Bool
    func lock() async throws
}

/// Test/default dependency. Production explicitly injects ScreenLocker.
struct NoopScreenLock: ScreenLocking {
    func hasExternalDisplay() throws -> Bool { false }
    func lock() async throws {}
}

struct ScreenLockError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// macOS has no public lock-now API. Resolve its lock-menu entry point at
/// runtime, and verify the session lock state instead of claiming success
/// solely because the function exists. No password or UI automation needed.
struct ScreenLocker: ScreenLocking {
    private typealias LockFunction = @convention(c) () -> Void
    private static let lockFunction: LockFunction? = {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/login.framework/Versions/Current/login", RTLD_LAZY),
              let symbol = dlsym(handle, "SACLockScreenImmediate") else { return nil }
        return unsafeBitCast(symbol, to: LockFunction.self)
    }()

    func hasExternalDisplay() throws -> Bool {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success else {
            throw ScreenLockError(message: "could not inspect connected displays")
        }
        guard count > 0 else { return false }
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &displays, &count) == .success else {
            throw ScreenLockError(message: "could not inspect connected displays")
        }
        return displays.prefix(Int(count)).contains { CGDisplayIsBuiltin($0) == 0 }
    }

    func lock() async throws {
        guard let lock = Self.lockFunction else {
            throw ScreenLockError(message: "macOS screen-lock function is unavailable")
        }
        lock()
        for _ in 0..<20 {
            if let session = CGSessionCopyCurrentDictionary() as? [String: Any],
               session["CGSSessionScreenIsLocked"] as? Bool == true { return }
            try await Task.sleep(for: .milliseconds(100))
        }
        throw ScreenLockError(message: "macOS did not confirm a locked screen")
    }
}
