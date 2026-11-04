# Settings

Settings has General and Services tabs. Choices save immediately and survive a restart.

## Sub-features

- `set-open` opens from the ⋯ menu.
- `set-general` covers display, labels, icon, highlight, bar color, language.
- `set-persist` keeps choices after a restart.
- `set-language` switches all text between English and Korean.

## How to get to it (user POV)

- Panel > ⋯ > Settings….

## Driving it with control-noonchi

Preconditions: `$C start` has returned.

- **Open.** Run `$C open-settings`, then `$C shot settings`. `settings-window0.png` shows the General tab.
- **Change.** Run `$C send toggle "Highlight high usage"`, `$C send press System`, `$C send press Blue`. `$C settings` shows `highlightHigh = False` and `barColor = #3B82F6`.
- **Effect.** Run `$C set-claude 5h=86 week=24`, `$C refresh`, `$C open-panel`, `$C shot blue`. The bar is blue, and 86% isn't orange.
- **Language.** Run `$C stop`, `$C start language=ko`, `$C open-panel`. The tree has `5시간, 5% 사용`.

## Gotchas

- Never press `Open at login` here. It registers with the system.
- `$C stop` deletes the settings domain, so a restart inside one run isn't available yet: report `set-persist` as not covered, or stop the app with the run's pid and relaunch by hand.
- Popups are pressed by their current value (`System`, `Symbol`, `English`), and the value changes after a pick.
