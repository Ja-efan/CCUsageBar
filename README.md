# Noonchi (눈치)

**English** | [한국어](README.ko.md)

*Noonchi* (눈치) is the Korean knack for reading the room. This app reads your Claude Code usage limits so you can see them before you hit them.

Noonchi shows Claude Code's **5-hour session usage** and **weekly usage** as numbers in the macOS menu bar. The panel also shows **per-model weekly caps** such as Fable.

```
5h 42% · 7d 18%
```

Click it to see a usage bar and reset time for each limit. Long content scrolls, and the settings, refresh, and quit buttons stay pinned at the bottom.

## Features

- **The numbers are right in the menu bar.** You don't have to open a panel to see them.
- **It never reads your credentials.** No Keychain, no browser cookies, no auth files under `~/.claude`, no conversation logs. It runs the official `claude` CLI and reads the `/usage` screen.
- **The app itself makes no network requests.** Only the Claude Code CLI talks to the server. The app has no networking code and no auto-updater.
- **It reads the screen after it finishes updating.** `/usage` first draws cached numbers, then overwrites only the digits that changed. Noonchi replays the output on an emulated terminal screen and reads the final values. In 30 real captures, the old approach (reading the output as plain text) returned the pre-refresh value 23 times; the current approach matched Claude Code's screen all 30 times.
- **It's small.** About 1,200 lines of Swift, and about 24 MB of app memory (measured over one hour, no growth).

Method and data: [`docs/benchmark.md`](docs/benchmark.md) (in Korean)

Good to know:
- Each refresh launches Claude Code once, which costs about 3.5 s of CPU (about 40 s per hour at the default 5-minute interval).
- Claude Code records Noonchi's working folder (`~/Library/Application Support/Noonchi`) in the project list in `~/.claude.json`. Noonchi doesn't write that file itself.
- There are no automatic updates. If Claude Code changes its screen format, you'll need to update Noonchi yourself.

## Settings

Click the gear button at the bottom of the panel to open Settings. Changes are saved automatically.

| Setting | Options |
|---|---|
| Language | 한국어 / English (defaults to the system language) |
| Menu bar | Any combination of the 5-hour session, weekly (all models), and per-model weekly caps (e.g. Fable). With nothing selected, only `CC` is shown |
| Format | With labels `5h 42% · 7d 10% · Fable 2%` / numbers only `42% · 10% · 2%` |
| Bar color | By usage (orange at 70%, red at 90%) or a single color (7 presets or a custom color). With a single color, the red warning at 90% can be turned on or off |

## How it works

- Every 5 minutes (and on wake from sleep), it runs `claude` in a pseudo-terminal (PTY) in the background, sends `/usage`, reads the screen once the refresh is done, and quits it.
- If a refresh fails, it keeps the last values it read and only shows the error.
- It never calls a model, so **it uses no tokens.**
- It doesn't touch the Keychain or the Anthropic API directly; it uses the values Claude Code shows.
- Claude Code runs in `~/Library/Application Support/Noonchi`.

## Requirements

- macOS 14 or later, Apple Silicon (arm64)
- Claude Code installed and signed in (Pro/Max subscription)
- Xcode or the Command Line Tools to build (Swift 5.9+)

Noonchi looks for `claude` in `~/.local/bin`, `~/.claude/local`, `/opt/homebrew/bin`, and `/usr/local/bin`, in that order. If yours is elsewhere, set the `NOONCHI_CLAUDE_PATH` environment variable.

## Install

```bash
git clone https://github.com/Ja-efan/Noonchi.git
cd Noonchi
make install      # build → install to ~/Applications → launch
```

To start it at login, add `Noonchi` under System Settings > General > Login Items.

## Development

| Command | Description |
|---|---|
| `make build` | Debug build |
| `make test` | Parser unit tests |
| `make app` | Build `dist/Noonchi.app` and a zip |
| `make run` | Build the app and run it |
| `make clean` | Remove build output |

To open it in Xcode, run `open Package.swift`.

### Layout

```
Sources/
  UsageCore/            Core logic with no UI (tested)
    ClaudeRunner.swift    Runs claude in a PTY and captures /usage
    TerminalScreen.swift  Replays PTY output on an emulated screen (handles partial redraws)
    TerminalText.swift    Strips ANSI escapes (fallback when screen replay fails)
    UsageParser.swift     Parses usage and reset times
    UsageSnapshot.swift   Model and error types
  Noonchi/              SwiftUI menu bar app (panel, settings window, localized strings)
Tests/UsageCoreTests/   Parser tests and /usage output samples (Fixtures)
Resources/Info.plist    App bundle info (version injected at build time)
scripts/                App bundle build and install scripts
```

### When Claude Code's output changes

1. Click "Show raw output" in the panel and copy the text from the window that opens.
2. Save it as a new sample in `Tests/UsageCoreTests/Fixtures/` and add a test.
3. Fix `UsageParser.swift` until the test passes.

## Releases

Bump `VERSION` and push a tag. GitHub Actions runs the tests, builds the app, and attaches the zip to a Release.

```bash
git tag v0.1.0 && git push origin v0.1.0
```

Released builds are ad-hoc signed, so the first launch may need right-click > Open.

## License

MIT
