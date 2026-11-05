<p align="center">
  <img src="docs/assets/eye-open.svg" alt="Insomniac's wide-awake eye on overlapping cobalt shapes" width="128" height="128">
</p>

<h1 align="center">Insomniac</h1>

<p align="center"><strong>A little eye. A little more time.</strong></p>
<p align="center">
  Keep your Mac awake for as long as you need.<br>
  Set a timer, close the lid, and let your session finish.
</p>

<p align="center">
  <img alt="macOS 26 or later" src="https://img.shields.io/badge/macOS-26%2B-1645F5?style=flat-square">
  <img alt="Apple Silicon" src="https://img.shields.io/badge/Apple_Silicon-arm64-0D28A6?style=flat-square">
  <a href="LICENSE"><img alt="MIT license" src="https://img.shields.io/badge/License-MIT-1645F5?style=flat-square"></a>
</p>

<p align="center">
  <a href="#install">Install</a> &nbsp;·&nbsp;
  <a href="#using-it">How it works</a> &nbsp;·&nbsp;
  <a href="#when-the-lid-closes">Lid behavior</a> &nbsp;·&nbsp;
  <a href="docs/fork-validation.md">Tested behavior</a>
</p>

---

Insomniac lives in your menu bar, with no Dock icon or main window. Its eye
rests when idle, blinks through startup, and opens when your session is ready.
Move your cursor nearby and the pupil follows along.

| Your session | Your preferences | A way back |
| --- | --- | --- |
| Set days, hours and minutes. Add time or end early. | Choose locking, audio and power behavior in four Settings tabs. | Changes are recorded before they happen, with an independent recovery helper if the app exits. |

## Install

Requires **macOS 26 or later**, an **Apple Silicon** Mac, and a Swift 6.2 or
later toolchain from Xcode or the Command Line Tools.

```bash
git clone --branch main https://github.com/ameyniac/Insomnia.git
cd Insomnia
./scripts/install.sh
open "$HOME/Applications/Insomnia.app"
```

Enter your Mac administrator password when Terminal asks. Password typing
is hidden. The app appears as an eye in the menu bar.

This repository builds Insomniac from source. The upstream release installer
does not include these changes. Upstream update checks are disabled because
an upstream release would replace the fork's changes. The retained
[upstream installation guide](docs/install.md) describes upstream packages;
use the commands above for this version.

<details>
<summary><strong>What gets installed</strong></summary>

- The app at `~/Applications/Insomnia.app`. Its displayed name is Insomniac;
  the existing bundle and support paths are retained for upgrades.
- A `launchd` recovery helper that checks once a minute and restores journaled
  changes after an expired or unsafe session, even if the GUI has crashed.
- A sudoers rule at `/etc/sudoers.d/insomnia` allowing your account to run
  these four power commands without another password prompt:

```text
/usr/bin/pmset -a disablesleep 1
/usr/bin/pmset -a disablesleep 0
/usr/bin/pmset -b lowpowermode 1
/usr/bin/pmset -b lowpowermode 0
```

The rule applies to programs running as your user, not only this app.
The locally built app is ad-hoc signed, not Apple-notarized.
[Installation details](docs/install.md#what-gets-installed)

</details>

## Using it

1. **Click the eye.** Enter a duration and press Enter. Five startup blinks
   accompany the sleep-guard check; those seconds count toward your session.
2. **Keep working.** The open eye and countdown show an active session.
   Click the eye or countdown to add time.
3. **Finish whenever you like.** Click × to end early, or let the timer expire.
   Escape cancels duration entry before you submit it.
4. **Make it yours.** Right-click the eye for Settings, recovery status and
   Copy Diagnostics. The copied summary omits device names, network names
   and raw logs.

Opening the lid does not end your session. When docked, the countdown keeps
updating on your external monitor, including when you start with the lid closed.
Reduce Motion replaces startup blinks with a numeric countdown.

## When the lid closes

| Setting | During the session | When you reopen |
| --- | --- | --- |
| **Lock the Screen** | Locks by default. An external display skips locking unless **Also Lock When Docked** is enabled. | Unlock normally. |
| **Mute Audio** | Saves and mutes the output. Audio stays muted if the session expires while closed. | Restores saved volume and mute state. Music may remain paused. |
| **Turn Off Display and Keyboard Light** | Saves and lowers brightness where supported. Unsupported controls are left alone. | Restores saved levels; macOS may manage keyboard lighting itself. |
| **Use Low Power Mode** | Reduces power use while closed. | Clears the app's change unless a battery or heat rule still needs it. |

If locking cannot be confirmed, the session ends and normal sleep is restored.
At expiry, sleep and power settings are restored first. On an undocked Mac,
the app requests system sleep when the current lid policy permits it. A Mac
with a powered external display can remain awake under normal macOS docked
behavior. Saved audio and brightness wait until the lid is known open.

The built-in microphone disconnects in hardware when the lid closes on Apple
Silicon and T2 laptops. Use an external microphone or headphones with a mic
for closed-lid recording. [More about lid behavior](docs/lid-close.md)

## Recovery, without guesswork

Each reversible change is written to a journal before it is applied. The app
and independent helper use that record to restore settings. Incomplete
cleanup stays recorded and appears in the status menu for retry.

By default, battery power below **40%** enables Low Power Mode and below
**10%** ends the session. Critical heat also ends it. The independent helper
checks the battery cutoff and critical heat once a minute, including after a
GUI crash. These thresholds are configurable in Settings.

The helper cannot restore audio or brightness by itself. Keep the app running,
or reopen it, to finish those restores once the lid is open. Notifications
are optional; recovery does not depend on notification permission.

> Keep an awake Mac on a stable, ventilated surface. Recovery is a fallback,
> not a guarantee that it is safe to run a closed laptop in a bag.

**Verified on the test Mac:** undocked locking, real sleep after expiry,
audio and display restoration, battery cutoff after a GUI crash, docked
locking options, and starting with the lid already closed. Hardware and OS
behavior can vary; screen locking uses a private macOS entry point with
availability and confirmation checks.

[Validation evidence](docs/fork-validation.md) ·
[Recovery guide](docs/recovery.md) · [Security](SECURITY.md)

<details>
<summary><strong>Optional tools and privacy</strong></summary>

Advanced settings include app pausing, Docker, hotspot recovery and opt-in
tmux nudges. The app freeze list starts empty. Broad app freezing and Docker
freezing are off by default; protected apps are excluded.

Hotspot passwords are stored in your login Keychain. macOS requires Location
Services permission to read Wi-Fi network names. tmux nudges only target
explicitly marked panes; submitting with Enter is a separate opt-in.

Settings live in `~/Library/Application Support/Insomnia/`; logs live in
`~/Library/Logs/Insomnia/`. Owner-only permissions are applied, but existing
symlinks and ACLs are preserved. Raw logs can contain network names and
process details. Review them before sharing, or use Copy Diagnostics.

[Optional tools](docs/extras.md) · [Configuration and privacy](docs/extras.md#configuration-and-privacy)

</details>

## Uninstall

From your source checkout:

```bash
./scripts/uninstall.sh          # remove the app, helper and sudoers rule
./scripts/uninstall.sh --purge  # also remove settings and logs
```

The uninstaller restores an open session first and stops if it cannot.

## Development

```bash
swift build
swift test
```

Tests use fakes and temporary folders rather than changing your power settings.
[Contributing](CONTRIBUTING.md) · [Design notes](docs/spec.md) ·
[Release process](docs/releasing.md)

---

Built on [Insomnia by Krish Garg](https://github.com/krishhgg/Insomnia).
This fork adds its own visual identity, settings design and recovery behavior.
[MIT licensed](LICENSE).
