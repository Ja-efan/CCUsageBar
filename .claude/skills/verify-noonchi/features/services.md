# Services on and off

Settings > Services lists each service with its path and a switch. Turning one off stops polling it and removes it from the panel and menu bar, and the panel shrinks to fit, staying directly under the menu bar.

## Sub-features

- `svc-off` removes a service from the panel and stops its reads.
- `svc-on` brings it back with a fresh read.
- `svc-resize` keeps the panel fitted to its content, with no blank band. Regression: the window used to keep its old height.
- `svc-chips` shows menu bar choices per service in custom mode.

## How to get to it (user POV)

- Panel > ⋯ > Settings… > Services, then the switch next to the service.

## Driving it with control-noonchi

Preconditions: `$C start` has returned.

- **Before.** Run `$C open-panel`, `$C gap`, `$C shot before`. Height is 214 with both services.
- **Turn off.** Run `$C open-settings Services`, then `$C send toggle Codex`. `$C settings` shows `disabledProviders = ['codex']`.
- **Reopen.** Run `$C close-settings`, `$C open-panel`, `$C gap`, `$C region off`, `$C shot off`. Height is 147, smaller than before, and the gap is 2. In `off-region.png` the panel sits directly under the menu bar, with no blank band above or below it. `off-tree.json` has no `Codex`.
- **Turn on.** Run `$C close-panel`, `$C open-settings Services`, `$C send toggle Codex`, `$C wait-idle`, `$C close-settings`, `$C open-panel`, `$C gap`, `$C close-panel`. Height is 214 again.

## Gotchas

- `gap` measures the window. When the bug is present the window is too tall and the gap still reads 2, so compare heights and read the image.
- Exact heights change with the rows; what matters is that off is smaller than on.
- The fake's paths appear in the Services tab, so don't reuse these captures in public docs.
- The panel closes when a service is turned off or on while it's open, or when that service's item changes in the menu bar. That's current behavior, cause unknown. Follow the order above, and reopen before reading.
