# Personal fork: changes and validation

This fork starts at upstream `b8e7e20d617f008179583918599669fc1c13a731`
(2026-10-27). It is a local source build for Apple Silicon, not a new upstream
release. The original MIT license is retained.

## Changes

- The end control activates on mouse release. AppKit hit testing uses the
  actual pointer and visible status-item bounds; dragging away cancels.
  The SwiftUI button retains keyboard and accessibility activation.
- The existing launchd recovery worker now checks the battery end floor and
  critical thermal state independently of the GUI. A bounded command in the
  signed app reads the same configuration and system sensors. It does not
  change power settings itself.
- A failed probe conservatively ends the session. Before restoring anything,
  the worker atomically expires the saved deadline under the recovery lock.
  Failed restoration remains journaled for retry, even if later readings
  become healthy. The GUI notices externally ended sessions and refuses to
  extend them.
- New configurations have an empty application freeze list. Existing user
  configurations are preserved. Other optional app-freezing, Docker, hotspot,
  and tmux features remain opt-in.

The worker runs at launchd's existing 60-second interval. Scheduling, lock
contention and recovery work can delay it. This is periodic protection, not
an instantaneous cutoff. Battery monitoring respects the configured end floor
(default 10%; zero disables it); critical-heat monitoring respects the thermal
rules switch. An unreadable battery on battery power is retried once before
ending. Older bundles without the versioned probe keep deadline-only recovery.
A missing or invalid bundle can prevent the signed launchd entry point from
running at all. Saved audio and some display restoration still need the GUI.

## Version 0.2.0 improvements

- Lid-aware cleanup restores sleep suppression immediately at session end,
  without declaring user activity or restoring ordinary saved brightness
  while the lid is closed or unreadable. Saved levels remain in the journal.
  A five-second timer restores them once the lid is known open, including
  after wake when the original session's services are stopped. A relaunch
  reconstructs the pending work from the journal. Existing refused-brightness
  readback and compatibility checks are preserved.
- Explicit screen locking is enabled by default, except when an active
  external display is connected. Settings exposes both the main switch and
  the docked override. A missing lock function, failed display inspection or
  unconfirmed lock ends the session through the normal recovery path. The
  private `SACLockScreenImmediate` function is resolved at runtime, then the
  session's locked state is checked for up to two seconds. The behavior was
  inspired by Amped; our implementation adds confirmation and failure handling.
- The menu and Settings show the deadline, safety cutoffs, pending cleanup
  and a timestamped read-only launchd status. A successful helper exit describes
  a past run, not a future guarantee. Copy diagnostics includes a fresh power
  readback and excludes network/device names, paths, raw logs and credentials.
- Settings and the menu identify the personal fork as 0.2.0. The signed
  bundle records a source revision (with a dirty marker for tracked changes,
  or `source-archive` when Git metadata is unavailable). Fork builds do not
  query upstream releases; the UI links to the reviewed fork branch instead.

The native lock confirmation and revised closed-lid expiry behavior still need
an installed-Mac trial. The earlier hardware results below apply to the first
fork build, not version 0.2.0. No new privileged commands or daemon were added.

Version 0.2.0 validation:

- All 208 targeted tests passed, including lid-aware recovery, lock policy and
  failure handling, diagnostics, existing refused-brightness cases, packaging,
  and selected source/ad-hoc installation fixtures.
- Broad application regression: 1,057 tests, 13 tmux tests skipped because
  tmux is absent, zero failures. This run excludes `RecoveryScriptTests`;
  the relevant installation cases are included in the targeted run above.
- Release build, strict code-signature verification, the packaged read-only
  safety command (`safe`, exit 0), Bash syntax and pinned ShellCheck 0.11.0
  passed.
- Read-only inspection found the native lock entry point on this Mac. It was
  not called during automated validation; successful physical locking remains
  a supervised hardware check.
- The unchanged recovery shell worker's full 248-test run belongs to the first
  build below. This update reruns its relevant build/install fixtures, not the
  entire shell suite.

## Local verification, 2026-11-04

Environment: macOS 26.5.2, arm64, Xcode Swift 6.3.3.

- New tests cover battery, thermal and unreadable-sensor decisions, failed
  probes, persistent expiry and retry, GUI reconciliation, extension refusal,
  and stop-click hit testing and cancellation.
- The focused non-UI runs completed 59 tests with no failures. The separate
  desktop-enabled UIStatusTests run passed all 42 tests.
- Full regression run exercised 1,296 tests in about 19 minutes. All 248
  recovery-script tests passed. Thirteen tmux tests were skipped because tmux
  is not installed. One README contract test had three assertion failures
  because it expected upstream installation instructions. After updating that
  test for this fork and retaining the upstream guide link, all 11 tests in
  ReleaseWorkflowTests passed on rerun. No application, recovery or installer
  tests failed. Only README/test/documentation files changed after the full
  run; the application and recovery code were unchanged.
- Release build: passed. The resulting app's ad-hoc code signature verifies.
  The packaged read-only safety command returned `safe` with exit status 0.
- Bash syntax check and ShellCheck 0.11.0 passed for the repository scripts.
  The pinned ShellCheck archive's SHA-256 matched the repository's CI pin.
- The separate CI suppression-audit helper requires Bash 5.2 or later and
  cannot run with this Mac's Bash 3.2. No suppression directives were changed.

Automated tests use temporary homes and mocked privileged commands. The
separate installed-Mac observations below provide the hardware evidence.
The upstream release-validation document records upstream history, not proof
that this fork passed those hardware checks.

## Installation and supervised trial

The checked-out source is `~/Insomnia`. The prepared local
bundle is `dist/Insomnia.app`. Install this exact locally built bundle from
Terminal:

```bash
cd "$HOME/Insomnia"
./scripts/install.sh --app ./dist/Insomnia.app --allow-unverified-origin
open "$HOME/Applications/Insomnia.app"
```

The origin override is required by the upstream installer for a locally built
bundle without GitHub release provenance. Its code signature was verified
locally. The installer still checks the bundle and requires administrator
authentication to install its four-command sudoers rule. The installer also
installs the per-user recovery LaunchAgent.

Before relying on it, perform these checks on an open, ventilated desk:

1. Verify that installation and the recovery agent succeed. Record the normal
   sleep setting and confirm the freeze list is empty.
2. Start a two-minute session, then click End. Confirm the UI ends and
   `pmset -g` shows sleep restored.
3. Start another short session, close the lid briefly, then reopen. Check that
   the intended task continued, and audio and brightness recover.
4. In a fresh two-minute session, force-quit the GUI and leave the lid open.
   After the deadline and the worker's next run, verify sleep restoration and
   inspect `~/Library/Logs/Insomnia/insomnia.log`. Relaunch to reconcile any
   remaining GUI-owned state.
5. Exercise the battery rule by temporarily setting the end floor above the
   current percentage on battery power, keeping the lid open. Confirm the
   session ends, then restore the normal floor. Never deliberately overheat
   the Mac; the critical-thermal path is covered by injected test readings.

### Observed results, 2026-11-04

- Installation passed: the signed app launches, and the recovery LaunchAgent
  is loaded with its 60-second interval and successful runs.
- Timer cleanup with the lid closed passed: the GUI ended the session at its
  deadline and recorded sleep, audio, brightness and Low Power Mode
  restoration. Readback found SleepDisabled 0, powermode 0 and a clean journal.
  The inspected macOS log did not show an actual Sleep/Wake transition;
  physical sleep after expiry remains unverified.
- Manual end passed: clicking the end control produced a user-initiated end
  and restored sleep four seconds after the session started. No unfinished
  command or session record remained.
- Deadline recovery after GUI crash passed: the verified GUI process was
  force-killed during an active session. With the GUI still absent, launchd
  restored sleep ten seconds after the saved deadline and cleared the journal.
  Readback confirmed SleepDisabled 0. The GUI was reopened afterward.

Independent battery-cutoff hardware testing and user confirmation of perceived
brightness/audio restoration remain pending. The critical-thermal path has
only injected test coverage. Stop if restoration fails; inspect the journal
and log before another session. The upstream uninstaller remains available
as `./scripts/uninstall.sh`.

Version 0.2.0 disables the upstream update check for fork builds and links to
this branch. Install a reviewed build from this branch to retain the changes.
