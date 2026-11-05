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

## Version 0.2.1: initial closed-lid event

The November 5 hardware trial on 0.2.0 started its lid observer at
09:24:57 PST with the lid already closed. The log recorded Low Power Mode,
but no close-event delivery, lock attempt, brightness journal or mute attempt.
The user reported continuous headphone audio and no lock screen. Opening at
09:25:09 and manual End at 09:25:22 restored the normal sleep setting; no
session or pending journal remained. This trial did not exercise native
locking or headphone muting, so neither is marked as passing.

The observer now queues an initial closed state through the normal two-second
debounce and re-reads after notification registration. Reopening during setup
cancels the pending close and delivers the open needed to restore any journal
retained on relaunch. Duplicate notifications do not repeat the initial close,
and stopping cancels it. The fork link and source-install instructions now
point to `main`, where the previous work was merged.

The reproduction failed before the fix. Afterward, all six new Swift Testing
tests (including a parameterized open/unknown case) passed, as did 179 existing
lid, recovery, integration, packaging and release-workflow tests. The tests
register the native observer but inject lid reads and fake all lock, audio,
brightness and power effects. Physical retesting of 0.2.1 remains pending.

## Version 0.2.2: audio waits for reopening

In the November 5 closed-lid expiry trial on 0.2.1, the timer restored audio
while the lid was still closed, and the user heard music resume. The user
approved changing that behavior. Audio restoration now waits until the lid is
known open, even after the session expires. Sleep suppression and Low Power
Mode cleanup still run immediately.

The existing five-second deferred-brightness timer now also handles saved
audio, including an audio-only journal. Reconnecting a saved device under a
closed or unreadable lid does not unmute it. Relaunch reconstructs the wait
from the saved journal. Once open, the existing device-specific restore,
missing-device, manual-unmute and failed-clear rules still apply. Status and
session-end messages distinguish audio, brightness, or both waiting for open.
No journal schema or privileged command changed.

Validation on 2026-11-05:

- Initial focused coverage passed 126 existing tests and seven new Swift
  Testing tests, including a parameterized closed/unknown-lid case.
- Broad application regression passed 1,057 XCTest cases with 13 tmux skips
  and zero failures, plus 13 Swift Testing tests across the startup and audio
  suites. The unchanged recovery shell suite was excluded.
- A final focused run passed all eight audio tests after adding a real-timer
  case: an ended audio-only session restored through the five-second timer
  without a device event or brightness entry. All 11 release-workflow tests
  also passed after the README update.
- Release build and strict ad-hoc signature verification passed. Tests use
  temporary journals and fake audio/power effects. No installation or physical
  audio retest is claimed by this validation step.

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


## Independent battery cutoff observed, 2026-11-05

On installed 0.2.1, the user started a ten-minute session on battery power
with the lid open (36% battery). The exact GUI process was force-killed,
then a temporary 99% cutoff was applied. With the GUI absent, the helper
reported `stop-battery` at 10:15:08 PST, restored sleep at 10:15:09 and cleared
Low Power Mode and the journal at 10:15:10. The original deadline was
10:23:18, so this was battery-driven recovery before timer expiry.

The original 10% end floor and 40% Low Power threshold were restored and the
GUI reopened. Readback confirmed SleepDisabled 0, no session and a clean
journal. This verifies the installed worker's independent battery path.
Version 0.2.2 uses the unchanged worker, but its new deferred-audio behavior
still needs an installed physical trial. Actual system sleep after closed-lid
expiry, external-display lock policies and live diagnostics UI remain pending.

## 0.3.0 approved UI (2026-11-05)

Implements the approved Paper design: General, Lid Behavior, Safety and
Advanced settings; focused drilldowns for optional tools; a shorter native
context menu with routine details under Diagnostics and recovery warnings
kept visible. Duration fields retain their units and width while typing.
Pending starts say “Starting…”; refused starts retain the entered duration
and provide an explanation popover.

The half-open idle eye and wide-awake running eye share vector geometry with
the approved artwork. Running veins taper to points. The Overlap app icon
uses the idle eye without the exploration's missing corner, on overlapping
cobalt shapes. All macOS icon sizes and the README SVG are generated from
that source. The nearby-cursor pupil response is bounded to 1.5 design units
and stops its timer when settled; it is disabled while editing, while a menu
is open, and under Reduce Motion. Increased Contrast and Reduce Transparency
use solid Settings chrome.

This version also includes 0.2.2's deferred audio restoration. Bundle IDs,
installed paths and recovery formats stay compatible with existing installs.
Physical validation is still required on the installed 0.3.0 build, especially
expiry while closed, audio/brightness restoration after reopening, and actual
sleep. The earlier 0.2.1 battery-helper result is historical evidence only.

Validation: the broad run exercised 1,047 XCTest cases (13 tmux skips) and
14 Swift Testing cases. Its five assertions concerned the old icon, old
mute-label placement and old version metadata. After correcting the rendering
preview and updating those design contracts, the focused 72 XCTest cases
plus eight deferred-audio cases passed. A final 34-case pass covered Settings
layout, microphone copy, password handling, recovery presentation and startup,
with no failures. All four native Settings tabs were rendered and visually
inspected in light and dark appearances. The unchanged 248-case recovery
script suite was not repeated for this UI change.

## 0.3.1 startup feedback (2026-11-05)

The installed 0.3.0 trial confirmed pupil tracking, all four Settings tabs,
two-minute session entry, the end button, and Escape cancelling unsubmitted
entry. The visible five-second startup delay is the existing sleep-guard
verification; it counts toward the requested session duration.

At Ameya's request, startup now uses five finite blinks, approximately one
per second, instead of “Starting…”. Each blink closes in 100 ms and reopens
in 160 ms. The brow stays fixed and the pupil is clipped by the moving lid.
Only confirmed session state shows the wide-awake eye. A slower check stops
blinking after five cycles and shows “Verifying…”; a failed check restores
the duration fields and error details. Reduce Motion keeps the eye still
and shows 5, 4, 3, 2, 1, then “Verifying…” if needed. The animation task is
cancelled when the pending-start view disappears and never loops at idle.

The 63-case branding/startup/status run passed, including slow starts,
refusals, retries and fixed-width duration entry. Blink frames were rendered
and inspected at reference and native menu-bar sizes. No session, recovery,
power, deadline or audio behavior changed. The agreed final version is 1.0.0
after the remaining installed hardware checks pass.
The follow-up 31-case artwork and packaging run also passed, including the
new blink-frame rendering checks and 0.3.1 bundle metadata.

## 0.3.2 consolidated eye artwork (2026-11-05)

Ameya selected Paper Eye Study 02 and the fully open running eye for the
Overlap app icon. Idle, blink and running now share one 24-unit geometry:
the upper lid moves over a fixed lower contour, pupil and tapered veins.
The eyebrow is removed. Pupil tracking remains bounded and the moving lid
clips both pupil and veins. The app icon uses the exact running geometry,
centered in white over the existing cobalt artwork; PNG, ICNS and README
SVG assets were regenerated together.

The status eye stays mounted across startup and confirmation, allowing a
continuous opening transition rather than replacing drawings. Startup
still uses five finite blinks and the same safety verification. Reduced
Motion retains the static eye and numeric countdown. The eye opens fully
only after confirmation; interrupted blinks settle into the new state.

The 87-test artwork, packaging, startup and status run passed. Rendered
blink frames and the generated app icon were visually inspected against
Paper. Installed motion and the remaining hardware checks still require
Ameya. This is a 0.3.2 test build; 1.0.0 remains reserved for final validation.

After the final interrupted-blink adjustment, all 64 artwork, startup and
status tests passed again with no failures.

## Closed-lid expiry sleep investigation (2026-11-05)

On installed 0.3.2 (de182a37ac5f), the 14:42 PST two-minute trial and
14:48 PST one-minute trial both ended on time. Audio and brightness stayed
saved and muted/dark until reopening, then restored; the journal was clean.
The second trial had playback paused. Locking passed by log and user report.
Unrestricted pmset and kernel sleep/wake timestamps confirmed neither trial
entered system sleep; the last kernel sleep was 11:03:13 PST.

Two issues were identified:

- DisplayServicesDimmer.wake discarded the activity assertion ID. Repeated
  restores left multiple UserIsActive assertions lasting the configured
  30-minute display timer. The app now avoids declaring activity when the
  panel is already awake and releases a successful wake assertion immediately.
- Restoring SleepDisabled permits sleep but does not replay the earlier lid
  close. Apple's published IOPMrootDomain.cpp handles
  kPowerEventUserDisabledSleep by changing the flag only. Other idle-sleep
  assertions (including Claude during these trials) can then keep the Mac
  awake. Their presence alone does not prove they caused the failure.

0.3.3 adds an explicit public IOPMSleepSystem request after automatic session
cleanup, under the recovery lock. A fresh kernel snapshot must say the lid
is closed, clamshell sleep policy is enabled, and SleepDisabled is false.
Unknown readings, an open lid, docked policy, a live session, an unfinished
command or un-restored system changes prevent the request. Deferred audio
and brightness remain journaled for reopening. The versioned headless helper
provides the same journal/policy checks to the recovery worker after it
publishes cleanup. Forced installer/uninstaller recovery never requests sleep.
A successful request means accepted by the OS, not proof of physical sleep.

The new helper was run with the real lid open and returned sleep-skipped.
The new unit tests use injected sleep calls; none puts the test Mac to sleep.
Physical closed-lid expiry on the new build remains pending.

Sources: local macOS IOPMLib.h (IOPMAssertionDeclareUserActivity and
IOPMSleepSystem), and Apple's published
[IOPMrootDomain.cpp](https://github.com/apple-oss-distributions/xnu/blob/main/iokit/Kernel/IOPMrootDomain.cpp).

Validation: 346 XCTest cases passed with zero failures, plus six Swift
Testing tests in the lid-observer startup suite. This run covered the new
sleep guards and assertion release, session/lid recovery, deferred restores,
helper ordering, forced-cleanup exclusion and packaging. bash -n and git
diff --check passed. The GUI diagnostics menu could not be inspected through
computer use (application lookup timed out); its model/privacy tests passed,
but that is not a claim of live UI verification.

## Installed 0.3.3 hardware acceptance (2026-11-05)

Ameya completed the unplugged two-minute session trial on installed 0.3.3,
source 86931ba24630. Closing the lid at 15:08:13 PST locked the screen,
darkened the panel and muted headphones. Reopening during the session at
15:08:45 restored panel brightness to 1.0 and headphone volume to 0.496063,
unmuted. Keyboard backlight was already suppressed by macOS with no trusted
saved reading; the app correctly left it to macOS. This does not establish
an app-managed keyboard-backlight restoration result.

After the second close, the helper restored normal sleep and Low Power Mode
at the 15:09:50 deadline. Audio and brightness remained deferred while the
lid was closed. The OS accepted the explicit sleep request; pmset recorded
actual Software Sleep at 15:10:21 and lid/HID wake at 15:11:35. Kernel sleep
and wake timestamps independently corroborated that sleep occurred.

At 15:11:39 the app restored the saved headphone volume/unmuted state and
panel brightness, then cleared the recovery journal. No session file or
residual Insomnia activity assertion remained; SleepDisabled and app-set
Low Power Mode were both zero. Music was observed paused afterwards. Ameya
accepted playback staying paused; restoring device audio settings does not
promise resuming media playback, and no automatic playback was added.

The core undocked lock, active-session reopening, closed-lid expiry, actual
system sleep and post-wake cleanup trial passed. External-display policy,
starting with the lid already closed, and live Copy diagnostics inspection
remain unverified on hardware. Notification permission remains disabled.
