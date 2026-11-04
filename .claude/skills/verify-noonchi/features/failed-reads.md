# Failed reads

When a read fails, a service keeps its last values, dimmed, with the time they're from and a one-line reason. A first read that fails shows only the reason. The next good read clears it all.

## Sub-features

- `fail-stale` keeps old values with `As of <time>` and a reason.
- `fail-first` shows the reason with no values.
- `fail-independent` lets one service fail while the other updates.
- `fail-recover` clears the state on the next good read.

## How to get to it (user POV)

- It happens on its own when a CLI fails or logs out. The user sees it on opening the panel.

## Driving it with control-noonchi

Preconditions: `$C start` has returned.

- **Stale.** Run `$C set-codex not-logged-in`, `$C refresh`, `$C open-panel`, `$C shot stale`. Under Codex the tree has `As of`, `30-day, 7% used`, and `Not logged in · will retry`. Claude is unchanged.
- **Hang.** Run `$C set-claude hang`, `$C refresh` (about 15 seconds), `$C open-panel`. Claude shows `As of` with old values.
- **Recover.** Run `$C set-claude 5h=10 week=11`, `$C set-codex free=7`, `$C refresh`, `$C open-panel`. The tree has `Max`, `Free`, new values, and no `As of`.
- **First failure.** Run `$C stop`, then `$C start`. Run `$C set-claude not-logged-in`, `$C set-codex not-logged-in`, `$C refresh`, `$C open-panel`. Values stay because `start` already read once, so this is stale too. A true first failure needs the fake set before launch, which the helper doesn't do yet: report `fail-first` as not covered.

## Gotchas

- A hanging `claude` reads as `Couldn't read usage`, not `No response`, because the app has already sent `/usage` when it gives up. That's current behavior.
- The panel gets taller with a reason line. Check `$C gap` here too.
