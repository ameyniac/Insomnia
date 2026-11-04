import Foundation

/// Read-only, bounded probe used by the launchd backstop even when the GUI
/// is gone. The caller holds the recovery lock and performs any restoration.
enum SafetyCheckCommand {
    static let flag = "--check-session-safety"
    static let version = 1

    static func run(
        _ arguments: [String],
        config: () throws -> Config = { try Store(paths: Paths.fromEnvironment()).loadConfig() ?? Config() },
        battery: () -> (battery: BatteryStatus, charging: Bool) = { PowerMonitor.readBattery() },
        thermal: () -> ProcessInfo.ThermalState = { ProcessInfo.processInfo.thermalState },
        retryWait: () -> Void = { Thread.sleep(forTimeInterval: 1) },
        endAfter: (UInt32) -> Void
    ) -> ResumeFrozenCommand.Output? {
        guard arguments.first == flag else { return nil }
        guard arguments.count == 1 else { return .init(lines: ["usage"], status: 64) }
        endAfter(10)
        do {
            var settings = try config()
            _ = settings.normalizeFloors()
            if settings.thermalRules, thermal() == .critical { return stop("thermal") }
            var reading = battery()
            if settings.endFloor > 0, !reading.charging, case .unreadable = reading.battery {
                retryWait()
                reading = battery()
            }
            // A critical transition during the retry must also end the session.
            if settings.thermalRules, thermal() == .critical { return stop("thermal") }
            if settings.endFloor > 0, !reading.charging {
                switch reading.battery {
                case let .percent(level) where level < settings.endFloor: return stop("battery")
                case .unreadable: return stop("battery-unreadable")
                default: break
                }
            }
            return .init(lines: ["safe"], status: 0)
        } catch {
            // An unreadable configuration must not silently disable protection.
            return stop("configuration-unreadable")
        }
    }

    private static func stop(_ reason: String) -> ResumeFrozenCommand.Output {
        .init(lines: ["stop-" + reason], status: 10)
    }
}
