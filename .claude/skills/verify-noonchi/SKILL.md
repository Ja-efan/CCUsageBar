---
name: verify-noonchi
description: Launch and drive a disposable copy of Noonchi (the macOS menu bar app) to prove a change on the real screen: open the panel, press buttons in Settings, change what the CLIs report, and capture evidence. Use after any change to the panel, menu bar, settings, providers, or window behavior, and before reporting a UI fix as done. Never touches the user's installed app, settings, history, or CLI accounts.
---

# Verify Noonchi

Noonchi has no window of its own: the user sees a menu bar item, a panel under it, and a Settings window. `control-noonchi` runs a copy with its own bundle ID, its own home folder, and fake `claude` and `codex` commands, and operates it through a driver compiled in only for this build.

Run commands from the repo root.

```bash
C=.claude/skills/verify-noonchi/control-noonchi
```

The feature recipes are in [`features/README.md`](features/README.md). Read the index before driving.

## What's real and what isn't

| Real | Replaced |
|---|---|
| Status item, panel, Settings, every control the driver presses | The `claude` and `codex` executables (through `NOONCHI_CLAUDE_PATH`, `NOONCHI_CODEX_PATH`) |
| PTY capture, screen replay, parser, JSON-RPC client, UsageStore, saved settings | Home folder (`CFFIXED_USER_HOME`) and bundle ID (`.verify`) |

The fakes are the only mocks: they sit at the boundary where the app already talks to an outside program. A pass here doesn't prove the real CLIs still answer the same way. When a change touches parsing or CLI behavior, also run the live check under Evidence.

## Launch

```bash
$C build     # once per code change; output in .build/verify-app, no effect on dist/
$C start     # prints "ready: run <id>, pid <n>" when every service has answered
```

`start` begins from clean settings, `language=en`, Claude at 5h 5% / week 26% / Fable 2%, and Codex Free at 7%. Pass settings to change that: `$C start language=ko menuBar.mode=custom`.

Only one run at a time; `start` refuses while one is active.

## Doctor

Run this first whenever anything looks off. It's read-only.

```bash
$C doctor
```

It fails unless the driver answers, the bundle ID is the verification one, and the app's home is this run's folder. Check that `build=` equals `head=`: if not, run `$C build`, because you'd be testing old code.

## Drive

| Command | Does |
|---|---|
| `$C open-panel` / `$C close-panel` | Opens or closes the panel by clicking the status item. Exits 3 if it won't stay open |
| `$C open-settings [General\|Services]` | Goes through the panel's ⋯ menu, closes the panel, and hands focus back |
| `$C close-settings` | Closes Settings. Do this before `open-panel`: the panel won't open over an inactive Settings window |
| `$C refresh` | Reads every service again and waits, with no window. Use for changing state |
| `$C press-refresh` | The panel's Refresh button. Use when the button itself is under test |
| `$C state` | JSON of each service's loading state, error, plan, and values, with no window |
| `$C wait-idle` | Waits until nothing is loading, with no window |
| `$C set-claude 5h=86 week=24 Fable=9` | What `/usage` shows on the next read. Also `not-logged-in`, `hang` |
| `$C set-codex free=7`, `$C set-codex plus=18,41` | One 30-day window, or 5-hour and weekly. Also `not-logged-in`, `hang` |
| `$C send press <label>` | Presses a button, menu item, popup, or chip by its visible label |
| `$C send toggle <text>` | Presses the switch next to that text |
| `$C send segment <label>` | Picks a segment, e.g. `Custom` |
| `$C send tab <label>` | Switches the Settings tab |
| `$C send tree` | JSON of every element's role and label in the open windows |
| `$C send windows` | JSON of window frames and the status item's frame |
| `$C settings` | What the app saved |
| `$C gap` | Panel height and its distance below the menu item |

Pass labels as shown in the language of the run. Look them up with `$C send tree`; don't guess.

## Evidence

Everything goes to `.verify-artifacts/<run>/` (gitignored) and survives `stop`. `$C evidence` prints the folder.

```bash
$C shot <name>     # <name>-window0.png..., -menubar.png, -tree.json, -windows.json. App windows only.
$C region <name>   # <name>-region.png: menu bar and panel together, as a user sees them
```

Standards for a proof:

- **Look at the image.** Read the PNG yourself. Numbers from `gap` don't replace it, and passing tests don't either.
- **Show the path.** Capture before and after the action, and drive the way a user does (the status item, ⋯ menu, Settings), not by writing settings directly.
- **Check side effects.** `$C settings` after a settings change. `<home>/Library/Application Support/Noonchi/` for files, read while the run is active.
- **A regression check must be able to fail.** For a bug fix, remove the fix, rebuild, confirm the journey fails, then restore it and rebuild.
- **`region` images hold neighbouring menu bar icons and the desktop.** Keep them local; never commit them or use them in the README.

Live check (real CLIs, read-only, no tokens), when parsing or CLI behavior changed. Temporarily add a test that calls `ClaudeCodeProvider(workDirectory: NSTemporaryDirectory() + "noonchi-live").fetch()` or the same for `CodexProvider`, run it with `swift test --filter`, and delete it. A new folder gets recorded in the user's `~/.claude.json` as trusted, so say so in your report.

## Cleanup

```bash
$C stop
```

Ends this run's app and fakes (matched by this run's folder, never by process name), deletes its scratch folder and settings domain, and keeps the evidence. Run it after every failed attempt too. To confirm: `ps -axo pid,command | grep noonchi-verify` prints nothing, and the evidence folder still exists.

## Rules

- **Never run the installed app's bundle, `make install`, or `make run` to verify.** They use the user's settings, and writing `io.github.ja-efan.noonchi` has overwritten real choices before.
- **Never run `defaults` against `io.github.ja-efan.noonchi`.** Only the `.verify` domain, and let the helper do it.
- **Don't press `Open at login` with this build.** It registers with the system, outside the disposable folder.
- **Say what you couldn't prove.** Only after trying the workarounds here, and name what you tried.
- **The user is probably working on this Mac.** Measured with `lsappinfo front` every 100 ms: only `open-settings` takes focus, for about 1.3 seconds, and the driver hands it back. Everything else leaves it alone. Keep it that way:
  - Check values with `$C state` and `$C send status-image <path>`. They open nothing.
  - Open the panel only to capture or press something in it, then close it.
  - Windows still appear on screen. Finish in one go, and verify at the end of a task rather than after each edit.
  - Exit 3 from `open-panel` means the user is clicking elsewhere. Don't loop. Wait and retry later, or report it.
