# Updates

Check for Updates asks GitHub for the latest release. If it's newer, Install downloads it, verifies it, replaces the app, and reopens it. A failure before the swap leaves the installed app untouched. If the new app can't be put in place or won't open, the old one goes back, and the next launch says so.

## Sub-features

- `upd-latest` says it's up to date.
- `upd-available` offers Install, What's New, and Later.
- `upd-refuse` refuses a damaged download, another app, a mismatched version, and an unsigned app.
- `upd-install` replaces the app and reopens it, with settings kept.
- `upd-source` hides Install on a build that must not be replaced (local branch only).
- `upd-manual` offers only the page when a release can't be installed from inside the app.

## How to get to it (user POV)

- Panel > ⋯ > Check for Updates….

## Driving it with control-noonchi

Preconditions: `$C start` has returned. The run has its own copy of the app and its own local feed.

- **Up to date.** Run `$C set-update 0.4.2` with the current version, then `$C open-update`, then `$C send tree`. It has `You're up to date`. Press `OK`.
- **Refused.** Run `$C set-update 9.9.9 damaged`, `$C open-update`, `$C send press Install`, wait 2 seconds, `$C send tree`. It has `The download is damaged`. Repeat with `other-app` and `unsigned` for `The downloaded app isn't valid`. The app in the run's `Applications` folder is still the old version, with nothing beside it.
- **Manual.** Run `$C set-update 9.9.9 no-digest`, `$C open-update`, `$C send tree`. It has `can't be installed from here` and no Install button.
- **Install.** Run `$C set-update 9.9.9`, `$C open-update`, `$C send press Install`, `$C wait-new-app`. The reply has `"version" : "9.9.9"`. The relaunched app is still isolated: `home` is the run's folder.

## Gotchas

- The feed is local, so this doesn't prove GitHub's response or a CI-built zip. For those, run `ReleaseInstaller.prepare` on the real release in a temporary test.
- A release at the running version reads as up to date, and an older one too.
- In zsh, `$C set-update "9.9.9 damaged"` passes one argument and reads as an unreadable release. Pass two.
