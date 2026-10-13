# Codex Traffic Lights — agent guide

This repository is a native macOS 26 status indicator for local Codex sessions. Read README.md for user-facing installation and coverage limits.

## Install when the user requests it

Prerequisites: macOS 26, a GUI login session and Xcode with Swift 6. No npm, Python, API key or third-party dependency is needed. The downloadable release is arm64 only.

```sh
swift test
./script/build_and_run.sh --install
```

The installer builds and copies the app to `/Applications/Codex Light.app`, installs a stable Hook helper, merges the user's Codex hooks.json with a backup, and launches the app. It honors `CODEX_HOME` when set. Existing Codex clients may need a restart or new conversation to load Hooks.

**The user must review and trust the new Hooks in Codex.** Desktop shows a prompt in a new conversation; CLI provides `/hooks`. Do not edit hook-trust state or bypass trust. Merely launching the app does not prove events have arrived.

## Verify

- App process: `pgrep -fl '/Applications/Codex Light.app/Contents/MacOS/CodexLight'`.
- UI: a draggable floating component with green, yellow and red lenses, top to bottom. Green is idle, yellow breathes while running, red means an explicit waiting/error state. Red outranks yellow, which outranks green.
- The app has no Dock icon. Use the menu-bar dot or right-click the light for its menu.
- Runtime state files are under `~/Library/Application Support/Codex Light/sessions/`. A real event after trust should update a record. Do not expose session metadata or conversation contents in public diagnostics.
- Only explicit observable events are supported. No timeout heuristic or analysis of assistant prose; unsupported errors/waits must be reported as coverage limitations.

## Develop

```sh
swift test
./script/build_and_run.sh --verify
```

`--build-only` builds and stages `dist/Codex Light.app`; default mode builds and launches it. The build script stops the existing GUI process before rebuilding. Do not use `--install` for a purely visual change: build, copy the app and relaunch instead, leaving the stable helper and trusted Hook definitions intact.

- `Sources/LightCore/State.swift`: event reducer and aggregation.
- `Sources/LightCore/SessionStore.swift`: atomic, locked per-session metadata files.
- `Sources/LightCore/HookConfiguration.swift`: non-destructive configuration merging.
- `Sources/CodexLight/`: native UI and command-line helper entry point.
- `Tests/LightCoreTests/`: state, configuration and concurrency regression tests.

Preserve the nonactivating always-on-top panel, existing red > yellow > green precedence, and the high-contrast dark UI. Hook handlers must return success and valid `{}` even on malformed input/storage failure. Bound lock waits so the indicator cannot block Codex. Keep installation backups and unrelated Hooks.

## Uninstall safely

First remove only handlers containing `--codex-light-hook` from Codex hooks.json, preserving unrelated handlers and settings. Stop the app and move it to Trash. Keep the stable helper at `~/Library/Application Support/Codex Light/bin/CodexLightHook` until all sessions with cached Hooks have ended and Codex has restarted; deleting it earlier causes Hook failures. Then remove the helper/state directory if requested.
