import Foundation

if CommandLine.arguments.dropFirst().first == ClosedLidSleep.flag {
    guard CommandLine.arguments.count == 2 else { exit(2) }
    do {
        let requested = try ClosedLidSleep.afterCleanup(paths: .fromEnvironment())
        print(requested ? "sleep-requested" : "sleep-skipped")
        exit(0)
    } catch {
        print("sleep-request-failed")
        exit(1)
    }
}

if let output = SafetyCheckCommand.run(Array(CommandLine.arguments.dropFirst()), endAfter: ResumeFrozenCommand.endProcess) {
    for line in output.lines { print(line) }
    exit(output.status)
}

// Entry point. A one-shot command-line mode is answered here, before AppKit
// or SwiftUI start, so backstop.sh can borrow the app's kernel-level
// identity check (see ResumeFrozenCommand), which ends itself when its
// lifetime is up. Anything else starts the menu bar app.
if let output = ResumeFrozenCommand.run(Array(CommandLine.arguments.dropFirst()), endAfter: ResumeFrozenCommand.endProcess) {
    for line in output.lines { print(line) }
    exit(output.status)
}
InsomniaApp.main()
