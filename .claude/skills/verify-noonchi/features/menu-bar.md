# Menu bar

The menu bar item shows one entry per service. Automatic mode shows each service's 5-hour window, or its shortest. Custom mode shows the windows picked in Settings. Text turns orange at 80% and red at 95%.

## Sub-features

- `bar-auto` shows one window per service with its icon.
- `bar-custom` shows only picked windows, in the order picked.
- `bar-value` follows the Show setting (`menuBar.value`). Remaining shows `81%` for 19% used, the ring matches the number, and colors still follow used.
- `bar-labels` shows `5h 19%` instead of `19%`.
- `bar-icons` draws symbol, letter, or ring.
- `bar-highlight` colors each high value on its own, plus the icon, and only when the setting is on.
- `bar-states` shows `…` while loading and `⚠︎` with nothing to show.

## How to get to it (user POV)

- It's always visible. Settings > General changes display, labels, and icon. Settings > Services picks custom items.

## Driving it with control-noonchi

Preconditions: `$C start` has returned.

- **Automatic.** Run `$C shot auto`. `auto-menubar.png` shows the asterisk with 5%, and the hexagon with 7%. `auto-menubar.json` has `"template" : true`.
- **High usage.** Run `$C set-claude 5h=86 week=24 Fable=9`, then `$C refresh`, then `$C close-panel`, then `$C shot high`. `high-menubar.png` shows 86% in orange, and the JSON has `"template" : false`.
- **Custom and labels.** Run `$C open-settings`, `$C send segment Custom`, `$C send toggle Labels`, `$C send tab Services`, `$C send press Fable`, then `$C shot custom`. `$C settings` shows `menuBar.mode = custom`, `menuBar.labeled = True`, and the items. The image shows `5h 86% · Fable 9%`, with only `5h 86%` and the icon in orange.
- **No 5-hour limit (Ultra).** Run `$C set-plan "Claude Ultra"`, `$C set-claude week=40 Fable=5`, `$C refresh`, `$C shot ultra`. Automatic shows 40%. The panel header says Ultra and has no 5-hour row. In Custom with only `5h` picked, it shows 40% rather than a dash.
- **Icon.** On the General tab run `$C send press Symbol`, then `$C send press Letter`, then `$C shot letter`. The image shows a boxed C and X.

## Gotchas

- `-menubar.png` is the image the app gave the status item. Without a highlight it's a template drawn in black, and macOS tints it, so black here is correct. With a highlight the other text is white for a dark menu bar, so it vanishes on a white background: view it on a dark one before calling text missing.
- `region` can show the user's own Noonchi next to the test item. Tell them apart by the fake's values.
- Custom mode defaults to `claude:5h` when nothing was saved.
