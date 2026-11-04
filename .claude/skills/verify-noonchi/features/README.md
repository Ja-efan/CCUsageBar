# Noonchi verification map

The maintained source for verifying what a Noonchi user sees. Read this index, then use the matching file as the recipe.

## Baseline preconditions

- `C=.claude/skills/verify-noonchi/control-noonchi`, from the repo root.
- `$C build` after the last code change, then `$C start`.
- `$C doctor` passes and `build=` equals `head=`.
- Every recipe starts from the state `$C start` leaves unless it says otherwise. Run `$C stop` and `$C start` between features.

## Driving conventions

- Prefer the helper's commands; use `$C send` for individual controls.
- Labels are literal and follow the run's language. Default is English.
- Read values with `$C state` when the screen isn't the point. Open the panel only to capture or press something in it, and close it after.
- Don't assume the panel stayed open. Run `$C open-panel` before reading the tree.
- Change what a service reports with `set-claude` or `set-codex`, then `$C refresh`.

## Proof and skip reporting

- Capture before and after the action with `$C shot`, and read the images.
- Use `$C region` when the relation between the menu bar and the panel matters.
- Name the feature ID and entry point used with every artifact.
- Report an unreachable path with the command tried and the unmet precondition. Don't report a skipped path as verified through another one.

## Feature entry contract

Each file starts with an H1 and one paragraph on the user-visible behavior, then has exactly these H2s in order: `Sub-features`, `How to get to it (user POV)`, `Driving it with control-noonchi`, `Gotchas`.

## Features

- [Panel](./panel.md) covers service sections, rows, reset times, plan names, the prediction line, and the footer.
- [Menu bar](./menu-bar.md) covers automatic and custom items, labels, icon styles, and high-usage color.
- [Failed reads](./failed-reads.md) covers kept values, reasons, first failures, and recovery.
- [Services on and off](./services.md) covers turning a service off, the panel resizing, and missing CLIs.
- [Settings](./settings.md) covers saved choices, language, and bar color.
