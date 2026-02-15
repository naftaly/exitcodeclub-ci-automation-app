# ExitCodeClub CI Automation App

This app exists for two reasons: to automate testing new KSCrash features in a real crash/report/symbolication pipeline, and to give the [exitcodeclub.com](https://exitcodeclub.com) backend a proper stress test with diverse, realistic crash data.

## How it works

A GitHub Actions cron job runs every 10 minutes. Each run:

1. Builds the app for iOS Simulator (Release, arm64).
2. Uploads dSYMs to the backend via a post-build script phase.
3. Runs 5 crash/relaunch cycles as a UI test:
   - Launches the app, which randomly picks a crash type and triggers it.
   - Relaunches the app, which finds the pending KSCrash report and sends it to the backend.
4. Each cycle picks a different random crash type, so the backend accumulates varied data over time.

## Crash types

16 crash types are randomly selected each cycle:

| Category | Types |
|----------|-------|
| Swift | `fatalError()`, `assertionFailure()`, force-unwrap nil, array out-of-bounds |
| Signals | SIGABRT, SIGSEGV, SIGBUS, SIGFPE, SIGILL, SIGTRAP |
| ObjC/C++ | C++ exception, use-after-free, double-free, stack overflow, buffer overflow |
| Hang | Main thread hang with watchdog SIGKILL |

Stack traces are decorated with 3-8 levels of realistic function names (network, UI, storage, auth) via `CallChain` so crash reports look like real app crashes.

## Prerequisites

- Xcode 26+
- [mise](https://mise.jdx.dev)
- `tuist` (pinned in `mise.toml`)

## Local usage

```bash
mise install
mise exec -- tuist install
mise exec -- tuist generate --no-open
open ExitCodeClubCIAutomationApp.xcodeproj
```

Run the app in the simulator and tap "Trigger Crash Now" to crash with a random type.

## CI

The workflow runs on cron (`*/10 * * * *`) and `workflow_dispatch`. No secrets needed — the backend URL is hardcoded since this is a purpose-built automation app.
