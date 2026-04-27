# M05 Implementation Notes (cycle 1)

## Pre-existing failures (not introduced by M05)

- **AC-V-06 menubar icon visual diff** (`MenuBarIconVisualTest`) fails 100% pixel diff against
  baseline at `.workflow/m02/screenshots/baseline/menubar-icon-visible.png`. Verified by `git
  stash` + re-running pre-M05 working tree — same failure. The test boots the binary and
  captures the system menu strip via `CGWindowListCreateImage`; under the current session
  / display the captured strip differs from baseline. Treating as pre-existing environmental
  flake. Updated `locateBinary()` to honour the `AgentJobsMacApp` rename so the test can at
  least find the binary.

- **Modified `cycle-001/*.png`** under `.workflow/m{02,03,04}/`: these are test-cycle outputs
  (not baselines) that any visual test run rewrites. Preserved as-is — they are not baselines.

## T01 — Package surgery

- `AgentJobsMac` executable target → `AgentJobsMacApp` executable + `AgentJobsMacUI` library.
- Two net-new empty targets: `AgentJobsVisualHarness` (library) + `CaptureAll` (executable).
  Both contain placeholder content so SPM compiles; real implementation lands in T02-T08.
- All test imports updated `import AgentJobsMac` → `import AgentJobsMacUI` (mechanical).
- `StaticGrepRogueRefsTests.appSourceFile()` rewired to the new path.
- `AppLaunchTests` / `MenuBarIconVisualTest` `locateBinary()` now searches both the new
  (`AgentJobsMacApp`) and legacy (`AgentJobsMac`) executable names.
- `ServiceRegistryViewModel`, `init`, `AppDelegate`, plus a wrapper `AgentJobsAppScene`
  scene type are now `public` so the thin `AgentJobsMacApp/main.swift` and `CaptureAll`
  executables can compose them.
