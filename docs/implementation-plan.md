# Codex Light Implementation Plan

Goal: One native high-contrast light for local Codex sessions, red > yellow > green.
Architecture: A small SwiftPM app with a testable Foundation core; the same executable handles silent Hooks before starting AppKit. Per-session atomic files carry only status metadata. SwiftUI glass is hosted in a draggable nonactivating NSPanel.
Tech stack: Swift 6, SwiftUI, AppKit, macOS 26. No third-party dependencies.
Spec: design.md. User approved immediate implementation, performed inline.

## Constraints and review focus
- No timeout-based inference, no conversation-text inference, no trust bypass.
- Preserve unrelated hooks and fail without overwriting malformed config.
- Concurrent sessions and concurrent tool calls must not clear another pending wait.
- Ignore unreadable state files; remove records only for explicit end/dead owner.
- Errors in the indicator must never block Codex; Stop must output valid JSON.
- Installed hook executable must remain stable across builds/uninstallation.

## Tasks
- [x] Core: `Sources/LightCore/State.swift`, `SessionStore.swift`, `HookConfiguration.swift`; tests in `Tests/LightCoreTests/`. Test aggregate priority, explicit input wait, waiting-tool recovery, errors, end, config preservation and atomic independent-session writes. Watch tests fail, implement, run `swift test`.
- [x] App: `Sources/CodexLight/main.swift`, `LightView.swift`, `AppController.swift`. Panel is 86×188, opaque dark housing with three lenses top-to-bottom green/yellow/red, only current state illuminated, no text in the light, yellow breathing only. Native menu carries state, hook setup and quit. Save drag position. Poll state every 0.5 seconds; reap dead recorded owner processes, never expire by age.
- [x] Delivery: `script/build_and_run.sh` stages/signs a real app; environment Run action uses it. Install into Applications, merge Hooks after a backup, retain previous no-op script. Validate actual panel with CUA and inject two isolated session events via the shipped binary. Package source and quick usage in outputs.

## Event coverage
Use only the installed CLI's supported hook events: SessionStart, SessionEnd, UserPromptSubmit, PreToolUse, PermissionRequest, PostToolUse, PreCompact, PostCompact, Stop, Interrupt. Detect explicit request_user_input tools and structured tool failures. Current Codex has no standalone StopFailure/Elicitation hook; disclose that fatal errors or waiting states not surfaced in supported hooks cannot be observed. No transcript scanning.
