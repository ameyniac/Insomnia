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

## Local verification, 2026-11-04

Environment: macOS 26.5.2, arm64, Xcode Swift 6.3.3.

- New tests cover battery, thermal and unreadable-sensor decisions, failed
  probes, persistent expiry and retry, GUI reconciliation, extension refusal,
  and stop-click hit testing and cancellation.
- The focused non-UI runs completed 59 tests with no failures. The separate
  desktop-enabled UIStatusTests run passed all 42 tests.
- Full regression suite: running; final result will be recorded here.
- Release build: passed. The resulting app's ad-hoc code signature verifies.
  The packaged read-only safety command returned `safe` with exit status 0.
- Bash syntax check and ShellCheck 0.11.0 passed for the repository scripts.
  The pinned ShellCheck archive's SHA-256 matched the repository's CI pin.
- The separate CI suppression-audit helper requires Bash 5.2 or later and
  cannot run with this Mac's Bash 3.2. No suppression directives were changed.

Tests use temporary homes and mocked privileged commands. These results do
not establish real lid-close, battery-cutoff or crash recovery on this Mac.
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

Installation and these hardware checks are pending. Stop if restoration fails;
inspect the journal and log before starting another session. The upstream
uninstaller remains available as `./scripts/uninstall.sh`.

The app's update checker still points to upstream releases. Installing one of
those replaces this fork's changes; rebuild this branch to retain them.
