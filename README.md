# PatchDesk

A native macOS front-end for the [Issue-to-Patch Agent](../issue-to-patch-agent/)
CLI. Pick an issue file and a repo folder, press Run, and review the
validated patch draft — in a real Mac app window instead of a terminal.

PatchDesk does **not** bundle, copy, or modify the CLI project. It
locates the CLI folder (you choose it; it defaults to a sibling
`issue-to-patch-agent` folder), runs it with `Foundation.Process`,
and reads the `patch.diff` / `report.md` it writes into a fresh
temporary directory. Nothing is ever applied to your real repo: the
CLI validates every patch in a temporary copy and stops, and you
apply it yourself with `git apply patch.diff` only if you agree
with it.

## What it is

- **Swift only** — SwiftUI + AppKit + Foundation, macOS 13+, no
  third-party dependencies, no network.
- **Dry-run by default** — the rule-based patcher needs no API key
  and makes no network calls. LLM mode is one toggle away and needs
  `LLM_API_KEY` in your shell, exactly like the CLI.
- **Testable logic, separated from the UI** — `PatchParser` (unified
  diff → files / hunks / added / removed counts) and `RunStatus`
  (exit code + report text → patched / no patch / rejected / failed)
  live in their own files and are covered by XCTest (15 tests).
- **Honest about missing pieces** — if the CLI folder is missing or
  wrong, the app says so instead of failing silently.

## Build and run (on a Mac)

Requires Xcode 15+ (Swift 5.9+) and Python 3 with `git` on PATH.
The CLI folder must be a checkout of the Issue-to-Patch Agent
project — by default the sibling folder `../issue-to-patch-agent`
next to this project, as in this portfolio layout:

```text
ai-agent-portfolio/
├── issue-to-patch-agent/   # the Python CLI (unchanged)
└── macos-patchdesk/        # this project
```

```bash
cd macos-patchdesk
swift build
swift test
swift run
```

Or open it in Xcode and press Run:

```bash
open Package.swift
```

The app opens with the CLI folder pre-filled when it finds the
sibling folder; otherwise press "Choose…" next to "CLI folder"
and pick the `issue-to-patch-agent` folder.

## 60-second demo

Uses the CLI's own sample repo — no key, no network, nothing is
modified.

1. Build and launch the app (`swift run`).
2. **Issue file** → Choose → `../issue-to-patch-agent/examples/issues/issue-1-empty-average.md`
3. **Repo folder** → Choose → `../issue-to-patch-agent/examples/sample_repo`
4. Leave **Dry-run** on. Press **Run**.
5. The status reads **"Patch ready — validated, not applied"**,
   the summary reads **1 file · 1 hunk · +2 −0**, and the Patch tab
   shows a diff adding the `if not numbers: return 0.0` guard to
   `average()`.
6. Press **Copy Patch** (or **Save Patch…**) to take the diff away
   for review. The sample repo is untouched — verify with
   `git -C ../issue-to-patch-agent status`.

Try the no-patch path too: issue `issue-4-dark-mode.md` returns
**"No patch proposed"** — the correct answer for a feature request
the dry-run patcher does not cover.

## Project layout

```text
Package.swift                  Swift Package, macOS 13+, executable + tests
Sources/PatchDesk/
  PatchDeskApp.swift           @main SwiftUI App entry point
  ContentView.swift            UI + view model + AppKit file panels
  Runner.swift                 CLI location + Foundation.Process execution
  PatchParser.swift            Unified-diff parser (pure, tested)
  RunStatus.swift              Exit code / report text → status (pure, tested)
Tests/PatchDeskTests/
  PatchParserTests.swift       7 tests, incl. malformed-diff cases
  RunStatusTests.swift         8 tests
README.md
.gitignore
macos-patchdesk-paths.txt      Manifest of every file in this project
```

## What this proves vs the JD

The role is Full-Stack Engineer (macOS): macOS apps, backend
services, C++ or Python, test strategy and automation, CI/CD,
quality-first delivery.

| This app demonstrates | How |
| --- | --- |
| SwiftUI + AppKit on macOS | Native app: `NSOpenPanel` / `NSSavePanel`, pasteboard, window, menus |
| Swift + Foundation | `Process` / `Pipe` subprocess execution, file handling, temp directories |
| Python interop | Drives a real Python CLI by contract (args, exit code, output files) |
| Testability | Pure parser + status mapping, 15 XCTest tests, no UI in the logic |
| Quality-first habits | Validates before showing results, malformed input is reported not crashed, human-in-the-loop by design |
| CI-friendly | `swift build` / `swift test` with no secrets, no network, no key |

**What it does NOT prove — stated plainly:**

- **C++**: this app is Swift only, and the author has no C++
  experience. The Python side is the evidence for the
  "or Python" half of the requirement.
- **Linux**: built and run on macOS only; no Linux background is
  claimed.
- **Security engineering**: no threat modeling or secure-coding
  work is shown here; the app's security posture is limited to
  "runs a local CLI you chose, writes only to a temp folder, and
  never applies a patch by itself".
- **Backend services / cloud**: the CLI is a local tool; no
  server, database, or cloud work is demonstrated.

## Notes

- The CLI folder is never written to by PatchDesk except through
  the CLI itself, which writes its outputs to the temp directory
  PatchDesk passes via `--out-diff` / `--out-md` / `--out-json`.
- If the CLI exits non-zero, the app shows the CLI's stderr
  instead of a generic failure message.
- PatchDesk was written on a Linux VM and **has not been compiled
  on macOS yet** — `swift build` / `swift test` on a Mac is the
  first thing to run (see above).
```

## License

Same as the portfolio: personal portfolio project, sample repo only.
