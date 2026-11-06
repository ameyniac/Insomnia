<img src="docs/assets/eye-open.svg" alt="insomniac's wide-awake eye on overlapping cobalt shapes" width="112" height="112">

# insomniac

**Your Mac can sleep in a minute.**

A small menu-bar timer that keeps your Mac awake, even with the lid closed.
Set the timer. Get back to whatever you were doing.

The eye opens while a session is running, gets sleepy when it isn't, and
follows your cursor when you get close.

No Dock icon. No main window.

Keep your Mac on a ventilated surface while it's awake, including with the lid closed.

[Install](#install) · [Using it](#using-it) · [Lid behavior](#when-the-lid-closes) · [Tested behavior](docs/fork-validation.md)

## Install

Runs on **macOS 14 Sonoma, 15 Sequoia, and 26 Tahoe** on Apple Silicon.
Building from source requires **Swift 6.2 or later** and a compatible macOS
SDK, independently of the app's minimum runtime version. Xcode 26.2 requires
macOS 15.6 or later to build; a Sonoma user needs a prebuilt app.

The app is compiled for macOS 14. Installed lid/sleep checks have been
completed on Tahoe; physical checks on Sonoma and Sequoia are still pending.
The installer checks both its own minimum and the bundle's minimum before
requesting an administrator password.

```bash
git clone --branch main https://github.com/ameyniac/insomniac.git
cd insomniac
./scripts/install.sh
open "$HOME/Applications/Insomnia.app"
```

Enter your Mac administrator password when Terminal asks. Password typing
is hidden. The app appears as an eye in the menu bar.

This repository builds insomniac from source. The upstream release installer
does not include these changes. Upstream update checks are disabled because
an upstream release would replace the fork's changes. The retained
[upstream installation guide](docs/install.md) describes upstream packages;
use the commands above for this version.

<details>
<summary><strong>What gets installed</strong></summary>

- The app at `~/Applications/Insomnia.app`. Its displayed name is insomniac;
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

On Apple Silicon and T2 laptops, closing the lid disconnects the built-in
microphone in hardware. Recording a meeting with the lid closed needs
AirPods or an external mic. [More about lid behavior](docs/lid-close.md)

## When the session ends

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

Built by [Ameya](https://ameyniac.com/), on top of
[Insomnia by Krish Garg](https://github.com/krishhgg/Insomnia).
A new eye, reworked settings, and a lot of opening and closing a laptop
to get recovery right. [MIT licensed](LICENSE).
