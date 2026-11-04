# Panel

Clicking the menu bar item opens a panel with one section per installed service. Each limit is one line with a label, bar, percent, and reset time. A line predicting a limit appears only when the pace would reach it before the reset.

## Sub-features

- `panel-sections` shows each service with its plan, in registry order.
- `panel-rows` shows one line per window, with reset time as minutes, time, weekday and time, or date.
- `panel-model-kept` keeps a model cap's last value when Claude Code says the caps are unavailable.
- `panel-pace` shows the prediction line only when a limit comes before its reset.
- `panel-footer` shows the update time, Refresh, and the ⋯ menu.
- `panel-raw` opens the raw output window from ⋯, with a picker per service.

## How to get to it (user POV)

- Click the Noonchi item in the menu bar.
- From the panel: ⋯ > Show raw output.

## Driving it with control-noonchi

Preconditions: `$C start` has returned.

- **Open.** Run `$C open-panel`, then `$C shot panel`, then `$C close-panel`. `panel-tree.json` has `Claude Code`, `Max`, `5-hour, 5% used`, `Weekly, 26% used`, `Fable, 2% used`, `Codex`, `Free`, `30-day, 7% used`, `Updated`.
- **Prediction shows.** Run `$C set-codex plus=86,41`, then `$C refresh`, then `$C open-panel`. The tree has `On pace to hit the 5-hour limit`. The fake puts each Codex window halfway through, so 86% always arrives early.
- **Prediction hides.** Run `$C set-codex plus=18,41`, then `$C refresh`, then `$C open-panel`. The line is gone.
- **Model cap kept.** Run `$C set-claude 5h=6 week=27 note=rate-limited`, then `$C refresh`, then `$C state`. Claude still has `model:Fable` at 2. Run `$C set-claude 5h=6 week=27`, then `$C refresh`, then `$C state`. `model:Fable` is gone, because without the notice a missing cap really is gone.
- **Refresh button.** Run `$C set-codex free=9`, then `$C press-refresh`, then `$C state`. Codex's window reads 9.
- **Raw output.** With the panel open, run `$C send press More`, then `$C send press "Show raw output"`, then `$C send segment Codex`. Read the new window with `$C shot raw`. It shows rate limit JSON and has no `fake-account-id`.

## Gotchas

- Claude reset times in the fake are fixed wording (`3pm`), so the time left depends on when you run. Use Codex to test time-based behavior.
- The prediction needs 10% of a window to have passed. Claude's fixed `3pm` can land under that and hide the line.
- `Sun 9:00 AM` in the tree comes from the fake's `Nov 8` wording and changes as that date passes.
