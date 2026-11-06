import AppKit
import Observation

/// A read-only launchd snapshot. A successful exit is evidence of a past
/// run, never a promise that a future restoration or safety probe will work.
struct RecoveryHealthSnapshot: Equatable {
    var summary: String
    var warning: Bool

    static func parse(_ result: ShellResult) -> Self {
        guard result.succeeded else { return .init(summary: "Recovery helper unavailable", warning: true) }
        func field(_ name: String) -> String? {
            result.stdout.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
                .first { $0.hasPrefix(name + " = ") }.map { String($0.dropFirst(name.count + 3)) }
        }
        guard field("run interval") == "60 seconds" else {
            return .init(summary: "Recovery helper schedule needs repair", warning: true)
        }
        if let exit = field("last exit code"), exit != "0" {
            return .init(summary: "Recovery helper last exit: \(exit) — check recovery", warning: true)
        }
        if let runs = field("runs"), let count = Int(runs), count > 0, field("last exit code") == "0" {
            return .init(summary: "Recovery helper: last run succeeded · checks every minute", warning: false)
        }
        return .init(summary: "Recovery helper loaded · no completed run reported", warning: false)
    }
}

@MainActor
@Observable
final class RecoveryHealth {
    static let shared = RecoveryHealth()
    private(set) var snapshot = RecoveryHealthSnapshot(summary: "Recovery helper: not checked yet", warning: true)
    private(set) var checkedAt: Date?
    private(set) var checking = false
    @ObservationIgnored private let read: @Sendable () async throws -> ShellResult

    init(read: @escaping @Sendable () async throws -> ShellResult = {
        try await CancellableCommand().run("/bin/launchctl", ["print", "gui/\(getuid())/\(Paths.backstopLabel)"], timeout: 3)
    }) { self.read = read }

    func refresh() async {
        guard !checking else { return }
        checking = true
        defer { checking = false }
        do { snapshot = .parse(try await read()) }
        catch { snapshot = .init(summary: "Recovery helper check failed or timed out", warning: true) }
        checkedAt = Date()
    }

    var line: String {
        guard let checkedAt else { return snapshot.summary }
        return snapshot.summary + " (checked \(checkedAt.formatted(date: .omitted, time: .standard)))"
    }
}

@MainActor
enum RecoverySummary {
    static func copy(manager: SessionManager) async {
        await RecoveryHealth.shared.refresh()
        let result = try? await CancellableCommand().run("/usr/bin/pmset", ["-g"], timeout: 3)
        let disabled = result.flatMap { $0.succeeded ? PmsetSleepGuard.readSleepDisabled($0.stdout) : nil }
        let summary = diagnostics(manager: manager, health: .shared, sleepDisabled: disabled)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(summary, forType: .string)
    }

    static func lines(manager: SessionManager) -> [String] {
        let end = manager.session.map { "Ends at \($0.endsAt.formatted(date: .omitted, time: .standard))" } ?? "No active session"
        let floor = manager.config.endFloor > 0 ? "Battery cutoff: below \(manager.config.endFloor)%" : "Battery cutoff: off"
        let thermal = manager.config.thermalRules ? "Critical-heat cutoff: on" : "Critical-heat cutoff: off"
        let state = manager.effectiveState
        let cleanup = manager.lidRestoreWaitingDescription.map { "\($0) saved · waiting for lid to open" }
            ?? (state.isDirty || state.hasRefusedBrightness || manager.pendingEnd != nil || manager.commandWarning != nil ? "Cleanup pending · see status details" : "No pending cleanup")
        return [end, floor + " · " + thermal, cleanup]
    }

    /// Deliberately excludes device names, SSIDs, paths, process identifiers,
    /// raw logs and credentials. It is copied only on an explicit click.
    static func diagnostics(manager: SessionManager, health: RecoveryHealth, sleepDisabled: Bool?) -> String {
        (["insomniac diagnostic summary", AppBuild.current.label,
          "macOS \(ProcessInfo.processInfo.operatingSystemVersionString)",
          "Checked: \(Date().ISO8601Format())"] + lines(manager: manager) +
         [health.line, "SleepDisabled readback: \(sleepDisabled.map { $0 ? "1" : "0" } ?? "unavailable")",
          "Lock on close: \(manager.config.lockOnLidClose); lock when docked: \(manager.config.lockWithExternalDisplay)",
          "Session reports an error: \(manager.lastError != nil)"])
            .joined(separator: "\n")
    }
}
