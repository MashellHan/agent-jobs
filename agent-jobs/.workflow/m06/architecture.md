# M06 Architecture — Information Architecture

**Owner agent:** architect
**Filed:** 2026-04-27
**Cycle:** 1
**Inputs:** `m06/spec.md`, `m06/acceptance.md`, `m06/competitive-analysis.md`, `DESIGN.md`, M05 RELEASED state.

> One-paragraph summary. M06 reshapes geometry around the M05 content layer.
> The popover view is rebuilt to render at ≥480pt with grouped status sections,
> rich rows, and a Retry affordance on failed rows; the dashboard window opens
> at 1280×800 with sidebar=220 / inspector=360 / list=remainder. T-014 is the
> rendering-fix prerequisite: `Snapshot.capture` is patched so dashboard
> `Table` rows AND dark-scheme backgrounds actually render before any other
> visual baseline is captured. WL-2 (file split) is pre-committed; WL-3
> (`ProviderDiagnostics` surface trim) is reduced to `internal`. Six tickets
> close in three implementation waves, each gated on a build-green checkpoint.

---

## 1. Module / file plan

### 1.1 New files

| File | Owner module | Purpose |
|---|---|---|
| `Sources/AgentJobsMacUI/Features/MenuBar/MenuBarPopoverView.swift` | `AgentJobsMacUI` | Extracted from `MenuBarViews.swift`; popover root only. WL-2 split. |
| `Sources/AgentJobsMacUI/Features/MenuBar/MenuBarRowViews.swift` | `AgentJobsMacUI` | Group header view + `MenuBarRichRow` (rich-row replacement of `ServiceRowCompact` for popover use). WL-2 split. |
| `Sources/AgentJobsMacUI/Features/MenuBar/PopoverGrouping.swift` | `AgentJobsMacUI` | Pure helper `enum PopoverGrouping` with `groupByStatus(_:) -> [(StatusGroup, [Service])]`. Unit-testable; AC-F-05. |
| `Sources/AgentJobsMacUI/Components/RetryAffordance.swift` | `AgentJobsMacUI` | Small button (`arrow.clockwise`) used in failed-row trailing slot. AC-F-12 / T-016. |
| `Sources/AgentJobsMacUI/Features/Dashboard/DashboardWindowConfig.swift` | `AgentJobsMacUI` | Constants for default size + split-view widths (`defaultSize = 1280×800`, `sidebarWidth = 220`, `inspectorWidth = 360`, `listMinWidth = 480`). AC-F-07/F-08/F-09. |
| `Tests/AgentJobsMacUITests/PopoverGroupingTests.swift` | tests | Pin status-group ordering. |
| `Tests/AgentJobsMacUITests/DashboardWindowConfigTests.swift` | tests | Pin window-config defaults. |
| `Tests/AgentJobsMacUITests/Visual/SnapshotRendererTests.swift` | tests | T-014 regression tests — populated table renders ≥3 rows; dark-scheme corner luminance < 0.3. AC-F-13/F-14. |

### 1.2 Edited files (high-level)

| File | Edit | Tickets |
|---|---|---|
| `Sources/AgentJobsVisualHarness/Snapshot.swift` | Wrap host in window-backed renderer; force `appearance` propagation; longer settle; render dark frame fully. | **T-014** |
| `Sources/AgentJobsMacUI/AgentJobsMacUI.swift` | Bump popover width 360 → 480; bump dashboard `frame(minWidth:)` to 1280×800; thin-out file (move popover composition to new files). | T-002, T-003, WL-2 |
| `Sources/AgentJobsMacUI/Features/MenuBar/MenuBarViews.swift` | DELETED after moving body to `MenuBarPopoverView.swift` + `MenuBarRowViews.swift`. | WL-2 |
| `Sources/AgentJobsMacUI/Features/Dashboard/DashboardView.swift` | Replace bare `NavigationSplitView` with explicit column-width modifiers; install `inspector` collapse rule at list < 480. | T-003 |
| `Sources/AgentJobsMacUI/Features/Dashboard/SourceBucketStrip.swift` | Add `layoutPriority`/explicit `fixedSize(horizontal: false, vertical: true)` on each chip; verify horizontal axis under harness. | T-015 |
| `Sources/AgentJobsMacUI/Features/Dashboard/SourceBucketChip.swift` | Apply `.fixedSize(horizontal: true, vertical: false)` so chip can't be squeezed to vertical-stripe; dim count at 0 (`opacity ≤ 0.6`); `.help()` already present — extend tooltip body to include zero-state copy. | T-008, T-015 |
| `Sources/AgentJobsMacUI/Components/SummaryChip.swift` | Same fixed-size invariant for parity. | T-015 (defensive) |
| `Sources/AgentJobsMacUI/Components/ServiceRowCompact.swift` | KEEP for dashboard-table cell use; popover replaces it with `MenuBarRichRow`. No edit needed unless retry-trailing-slot variant chosen — see §3.6. | (referenced) |
| `Sources/CaptureAll/Scenarios.swift` | All popover scenarios → 480 × auto. All dashboard scenarios → 1280 × 800 (except 09 narrow → 1024 × 700). | spec §"capture-all scenario list" |
| `Sources/AgentJobsCore/Discovery/ServiceProvider.swift` | `ProviderDiagnostics` actor: drop `public` on type + members not used cross-module. Keep `ProviderHealth` public; `var diagnostics: ProviderDiagnostics?` requirement on `ServiceProvider` made `internal` (move requirement out of public protocol or keep but mark `@_spi` is overkill — simpler: change `public actor ProviderDiagnostics` → `internal`, move requirement to `internal extension`). | **WL-3 / AC-F-18** |

### 1.3 Deleted

- `Sources/AgentJobsMacUI/Features/MenuBar/MenuBarViews.swift` (after split lands).

---

## 2. Key types

### 2.1 `PopoverGrouping`

```swift
enum PopoverGrouping {
    enum StatusGroup: Int, CaseIterable, Identifiable {
        case running, scheduled, failed, other
        var id: Int { rawValue }
        var displayName: String { /* "RUNNING", "SCHEDULED", "FAILED", "OTHER" — uppercase per Things 3 pattern */ }
    }
    /// AC-F-05: deterministic ordering — running, scheduled, failed, then other.
    /// Empty groups are dropped by default; pass `includeEmpty: true` to keep them
    /// (used by the empty-state scenario to render section headers with 0-count chips).
    static func groupByStatus(_ services: [Service], includeEmpty: Bool = false)
        -> [(StatusGroup, [Service])]
}
```

Status mapping rule:
- `.running` → `.running`
- `.scheduled` → `.scheduled`
- `.failed` → `.failed`
- everything else (`.idle`, `.paused`, `.done`, `.unknown`) → `.other`

### 2.2 `MenuBarRichRow` (in `MenuBarRowViews.swift`)

Replaces `ServiceRowCompact` inside the popover only. Contract:

```swift
struct MenuBarRichRow: View {
    let service: Service
    var onRetry: ((Service) -> Void)? = nil   // AC-F-12 — only set on failed rows by parent
    /* renders: status-pill (capsule, semantic color) | VStack { friendly title (.body/.medium), 1-line summary (mono, secondary) } | Spacer | trailing slot:
       - .failed → RetryAffordance (button) — AC-F-12 / T-016
       - else    → CPU%/RSS cluster as today
    */
}
```

`ServiceRowCompact` remains untouched for any non-popover users (none today; kept as a generic compact row in case Dashboard wants it later — review may flag as dead code, see §6).

### 2.3 `DashboardWindowConfig`

```swift
enum DashboardWindowConfig {
    static let defaultSize  = CGSize(width: 1280, height: 800)
    static let minSize      = CGSize(width: 1024, height: 700)
    static let sidebarWidth: CGFloat   = 220
    static let inspectorWidth: CGFloat = 360
    static let listMinWidth: CGFloat   = 480
}
```

Used by:
- `AgentJobsAppScene.Window` — `.frame(minWidth: minSize.width, minHeight: minSize.height)` and `.defaultSize(...)` modifier on `Scene`.
- `DashboardView.body` — `NavigationSplitView { sidebar.navigationSplitViewColumnWidth(min: 180, ideal: sidebarWidth, max: 280) } content: { ... .navigationSplitViewColumnWidth(min: listMinWidth, ideal: 700) } detail: { ... .navigationSplitViewColumnWidth(min: 280, ideal: inspectorWidth, max: 460) }`.
- `HarnessScenes.dashboard(...)` — default `size` parameter changes 1200×700 → 1280×800.

### 2.4 `RetryAffordance`

```swift
struct RetryAffordance: View {
    let action: () -> Void
    /* HoverableIconButton-flavored 22×22 button with arrow.clockwise SF symbol,
       .help("Retry"), .accessibilityLabel("Retry"), keyboardShortcut nothing
       (focusable via tab — view-tree retains the Button identity). */
}
```

Wired by `MenuBarRichRow` only when `service.status == .failed`. Action → `Task { await registry.refresh() }` (M06 scope: trigger a global refresh; per-service retry is a richer M+ feature, deliberately out of scope here per spec §"out of scope"). Acceptance only requires the affordance to exist and be reachable (AC-F-12).

---

## 3. Per-AC change plan

### 3.1 T-014 — capture-all rendering fix (TASK 1, BLOCKING)

**Symptom (M05 ui-review.md):** dashboard `Table` body renders empty in PNG; dark scheme leaks white background into the top half.

**Root-cause hypothesis:**
1. `NSHostingView` is not attached to a window. `NSTableView` (which `SwiftUI.Table` lowers to) lazily realizes rows in response to `viewWillDraw`/`tile`; without a window + run-loop tick after layout, it stays in the unrealized state — draws headers, no rows.
2. Setting `host.appearance` on the NSHostingView only theme-marks the host; SwiftUI background materials traverse `NSWindow.effectiveAppearance`. With no window, the top region (which happens to render against the host's super-layer) draws light, and only the body that uses `Color.primary` etc. picks up the dark scheme. Hence "half-rendered dark".

**Fix in `Snapshot.capture` (`AgentJobsVisualHarness/Snapshot.swift`):**

```swift
public static func capture<V: View>(_ view: V, size: CGSize, appearance: NSAppearance.Name = .aqua) throws -> Data {
    let colorScheme: ColorScheme = (appearance == .darkAqua) ? .dark : .light
    // Build an offscreen window so AppKit promotes NSHostingView to a real
    // window context. NSTableView uses this to realize rows; SwiftUI
    // material+background fills inherit window.effectiveAppearance from it.
    let window = NSWindow(
        contentRect: CGRect(origin: .zero, size: size),
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    window.appearance = NSAppearance(named: appearance)   // critical for dark-frame parity (AC-F-14)
    window.isReleasedWhenClosed = false
    let host = NSHostingView(rootView: view
        .environment(\.colorScheme, colorScheme)
        .frame(width: size.width, height: size.height))
    host.frame = CGRect(origin: .zero, size: size)
    window.contentView = host
    host.layoutSubtreeIfNeeded()

    // Two run-loop passes: first to commit layout, second to let NSTableView's
    // delayed row realization run. 0.05s + 0.05s is cheap and matches the
    // existing budget hint in M05 RELEASED.md (capture-all 1.69s for 10 PNGs).
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
    host.layoutSubtreeIfNeeded()
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))

    guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { throw CaptureError.bitmapAllocFailed }
    host.cacheDisplay(in: host.bounds, to: rep)
    guard let data = rep.representation(using: .png, properties: [:]) else { throw CaptureError.pngEncodeFailed }
    return data
}
```

Tests (`Tests/.../Visual/SnapshotRendererTests.swift`):
- AC-F-13 verification: render `HarnessScenes.dashboard(viewModel: populatedFixture)` at 1280×800; sample the rectangle bounded by Table content rows; assert luminance variance > threshold AND ≥3 distinct horizontal "row" bands detected by run-length scan over the y-axis (cheap heuristic — pin distinct dark/light alternation when `tableStyle(.inset(alternatesRowBackgrounds: true))`).
- AC-F-14 verification: render dashboard dark; sample 4 corner 8×8 regions; mean luminance < 0.3 for each.

**Why this is task 1:** every other capture-all baseline produced before this lands is suspect and would have to be regenerated anyway. Sequence is fixed.

### 3.2 T-002 — popover width + grouped rich rows

Files: `MenuBarPopoverView.swift` (new), `MenuBarRowViews.swift` (new), `PopoverGrouping.swift` (new), `AgentJobsMacUI.swift` (width bump 360→480).

Composition (`MenuBarPopoverView.body`):

```
VStack {
  header                                          // unchanged
  Divider
  summaryStrip                                    // unchanged (chips already horizontal)
  Optional ErrorBanner
  Divider
  ScrollView {
    VStack(spacing: l) {
      ForEach(grouped) { group in
        GroupHeader(group)                        // uppercase caption + count chip
        ForEach(group.services) { svc in
          MenuBarRichRow(service: svc, onRetry: ...)
        }
      }
      // empty-state fallback if grouped.allSatisfy { $0.services.isEmpty }
    }
  }
  footer
}
.frame(width: 480)   // moved here from AgentJobsMacUI.swift; AC-F-04
```

Where `grouped = PopoverGrouping.groupByStatus(registry.services, includeEmpty: false)` for populated, and `includeEmpty: true` for the empty-state scenario (so headers + 0-count chips still render — drives AC-D-05/T-008 in the popover surface).

`AgentJobsAppScene.MenuBarExtra` no longer applies its own `.frame(width: 360)` — width owned by `MenuBarPopoverView` itself so capture-all and production stay in sync.

VoiceOver ordering risk (spec §risk #5): SwiftUI traversal walks ScrollView → VStack → groups in declaration order → rows. Group order = status priority order, so VoiceOver reads "RUNNING, npm run dev, … SCHEDULED, daily-cleanup, …" — top-to-bottom by status group. No extra `.accessibility...` plumbing needed.

### 3.3 T-003 — dashboard default size + 3-pane sizing

Files: `DashboardWindowConfig.swift` (new), `AgentJobsMacUI.swift`, `DashboardView.swift`, `Scenarios.swift`.

In `AgentJobsAppScene.body`:

```swift
Window("Agent Jobs", id: "dashboard") {
    DashboardView()
        .environment(registry)
        .frame(minWidth: DashboardWindowConfig.minSize.width,
               minHeight: DashboardWindowConfig.minSize.height)
        .task { await registry.startWatchers() }
}
.defaultSize(DashboardWindowConfig.defaultSize)         // AC-F-07
.windowResizability(.contentMinSize)
```

In `DashboardView.body` apply:

```swift
NavigationSplitView { sidebar.navigationSplitViewColumnWidth(
        min: 180, ideal: DashboardWindowConfig.sidebarWidth, max: 280) }
content: { contentColumn.navigationSplitViewColumnWidth(
        min: DashboardWindowConfig.listMinWidth, ideal: 700) }    // AC-F-09
detail: { inspectorColumn.navigationSplitViewColumnWidth(
        min: 280, ideal: DashboardWindowConfig.inspectorWidth, max: 460) }    // AC-F-08
```

Inspector hide-at-narrow rule: NavigationSplitView's built-in column behavior collapses the detail column when the window is narrowed below the sum of sidebar.min + list.min + detail.min. With 180 + 480 + 280 = 940, dragging below 940pt collapses the detail. Verified by scenario 09 (1024×700: detail visible; will need a unit-tested resize check at 940).

### 3.4 T-008 — 0-count chip explanation

File: `SourceBucketChip.swift`.

- `foreground` already returns `.secondary` at `count == 0`. Add an explicit `.opacity(0.55)` modifier on the whole chip when `count == 0 && !isSelected` (AC-F-11 dimming threshold ≤ 0.6).
- Tooltip text: extend `helpText` to inject zero-state copy when count is 0:
  - `.registered` → "No registered services in agent-jobs.json"
  - `.claudeScheduled` → "No claude-loop crons in ~/.claude/projects/"
  - `.claudeSession` → "No active Claude sessions found"
  - `.launchd` → "No matching launchd user agents"
  - `.liveProcess` → "No live processes match the discovery filter"

Source of strings: a new `internal extension ServiceSource.Bucket { var emptyExplanation: String { ... } }` in `SourceBucketChip.swift` (private to the file — keeps `ServiceSource.Bucket` API clean).

### 3.5 T-015 — SourceBucketStrip horizontal layout fix

File: `SourceBucketStrip.swift`, `SourceBucketChip.swift`.

Hypothesis (M05 ui-review): when the dashboard `content` column is narrow and the strip has 5 chips + total label, SwiftUI's HStack was collapsing each chip's text to single-character lines because `Capsule()` background combined with `lineLimit(nil)` and ambiguous `Text` sizing caused width-zero allocations.

Fix:
- Add `.fixedSize(horizontal: true, vertical: false)` to the inner HStack of `SourceBucketChip.body` (forces the chip to claim its intrinsic width, no width-clamping).
- Add `Text(bucket.displayName).fixedSize()` defensively.
- Wrap the strip chips in a `ScrollView(.horizontal, showsIndicators: false) { HStack { … } }` so when the dashboard is dragged extremely narrow (below the 5-chips-plus-label intrinsic width), the strip scrolls horizontally instead of collapsing chips.

This means the strip is BOTH:
- horizontally laid out (AC-F-10),
- robust to narrow widths in the harness (which is where the M05 vertical-stripe bug surfaced — likely a side-effect of `NSHostingView` reporting a too-narrow `idealSize`).

### 3.6 T-016 — Retry affordance on failed popover rows

`MenuBarRichRow` already plumbs `onRetry`. In `MenuBarPopoverView.section(...)`:

```swift
let onRetry: ((Service) -> Void)? = (svc.status == .failed)
    ? { _ in Task { await registry.refresh() } }
    : nil
MenuBarRichRow(service: svc, onRetry: onRetry)
```

Trailing slot in `MenuBarRichRow`:
- `.failed` → `RetryAffordance(action: { onRetry?(service) })`
- otherwise → existing CPU/RSS cluster.

Keyboard reachability: `Button` is focusable by default; tab-cycle reaches it via SwiftUI's accessibility tree (AC-F-12).

### 3.7 WL-2 / AC-F-17 — file split

Pre-commit decision: **YES, split now.** Reasoning:
- `AgentJobsMacUI.swift` is at 497 LOC. T-002 alone (grouping helper + `MenuBarRichRow` + group header view + popover composition rewrite) adds ~150-180 LOC.
- The tipping point predicted by spec is 600 LOC. We are deterministically going to land 650+ LOC in this file if we don't split.
- Splitting now (before bulk T-002 edit) keeps the diff narrative clean: split-first commit moves code, second commit adds new behavior. Splitting after IMPL forces a "move + rewrite" diff that is impossible to review.

Final layout under `Sources/AgentJobsMacUI/`:

```
AgentJobsMacUI.swift                  # AgentJobsAppScene + AppDelegate + ServiceRegistryViewModel + MenuBarSummary + HarnessScenes + seedForCapture extension. (~360 LOC after popover composition leaves)
Features/MenuBar/
  MenuBarPopoverView.swift            # popover root view (~140 LOC)
  MenuBarRowViews.swift               # MenuBarRichRow + GroupHeader (~120 LOC)
  PopoverGrouping.swift               # pure helper (~50 LOC)
  AutoRefreshIndicator.swift          # unchanged
Features/Dashboard/
  DashboardView.swift                 # unchanged structure; column-width modifiers added
  DashboardWindowConfig.swift         # NEW (~30 LOC)
  ... (other dashboard files unchanged)
Components/
  RetryAffordance.swift               # NEW (~30 LOC)
  ... (other components unchanged)
```

### 3.8 WL-3 / AC-F-18 — `ProviderDiagnostics` surface trim

File: `Sources/AgentJobsCore/Discovery/ServiceProvider.swift`.

Today the actor is `public` because:
1. The `ServiceProvider` protocol declares `var diagnostics: ProviderDiagnostics? { get }` and the protocol is `public`.
2. Concrete providers (`ClaudeScheduledTasksProvider`, `ClaudeSessionCronProvider`) declare `public let diagnostics: ProviderDiagnostics?`.

Trim plan:
- Change `public actor ProviderDiagnostics` → `internal actor ProviderDiagnostics`.
- Change `var diagnostics: ProviderDiagnostics? { get }` requirement out of the public `ServiceProvider` protocol — move to `internal protocol DiagnosticsBearing { var diagnostics: ProviderDiagnostics? { get } }`. Concrete providers conform to both.
- `ServiceRegistry.discoverAllDetailed()` already builds `ProviderHealth` from each provider; the `ProviderHealth` type stays public. Cross-module callers (the view model's `collapseHealth(_:)`) only ever consume `ProviderHealth`.

Verified path:
- `ServiceRegistryViewModel.collapseHealth(_:)` consumes `[ProviderHealth]` only — no `ProviderDiagnostics` import needed in `AgentJobsMacUI`.
- Tests: `ProviderDiagnosticsTests.swift` lives in `AgentJobsCoreTests` (same module visibility) — `internal` access is fine.

This is non-blocking AC; if the protocol-split adds review friction, fall back to keeping `var diagnostics` requirement `public` but making the `ProviderDiagnostics` type itself `internal` (the requirement type would then need to be `Any?` or hidden behind a `var diagnosticsSnapshot: ProviderHealth?` shim — recommended only if the `internal protocol DiagnosticsBearing` approach hits a wall).

### 3.9 WL-1 — Visual ↔ design AC delineation guidance

Encoded in `acceptance.md`. For agents downstream:

- **tester** runs `AC-F-*` (build/behavior, code-structure introspection, view-tree assertions) and `AC-V-*` (pixel diffs vs. the post-T-014 baselines under `.workflow/m06/screenshots/baseline/`). Tester does NOT score quality.
- **ui-critic** runs `AC-D-*` (rubric-scored against the 6 axes in `DESIGN.md`, reading PNGs from `.workflow/m06/screenshots/critique/`). UI-critic does NOT diff pixels.
- **Order-of-operations:** tester runs first (TESTING phase). Tester regenerates baselines from `capture-all` only AFTER T-014 is in. UI-critic enters from `phase: UI-CRITIC` only after tester reports PASS — this guarantees the critique PNGs the critic reads are the post-fix renders.

---

## 4. Data flow (popover rich rows)

```
ServiceRegistry → ServiceRegistryViewModel.refresh()
                     │
                     ▼
              registry.services: [Service]   (already sorted by name)
                     │
                     ▼
   PopoverGrouping.groupByStatus(_:)         (pure, view-side; AC-F-05)
                     │
                     ▼
           [(StatusGroup, [Service])]
                     │
                     ▼
   ForEach in MenuBarPopoverView body
                     │
                     ▼
   MenuBarRichRow                            (rich row; trailing slot conditional on status)
```

Decision: **grouping happens in the view layer, NOT the view model.** Rationale:
- View model already sorts by name and exposes summary counts. Adding a grouped representation duplicates state for one consumer.
- `PopoverGrouping` is a pure free function — testable without spinning the view model.
- Dashboard does not group by status (it filters by source-bucket / category instead) — keeping grouping out of the view model avoids dashboard-side noise.

This addresses spec §"Next" architect prompt directly.

---

## 5. Test plan (architect's view — full enumeration is the tester's job)

| Area | Test | AC |
|---|---|---|
| Status grouping order | `PopoverGroupingTests.statusOrder()` | AC-F-05 |
| Empty-include flag | `PopoverGroupingTests.includeEmpty()` | AC-F-05 |
| Window config defaults | `DashboardWindowConfigTests` | AC-F-07/F-08/F-09 |
| `Snapshot.capture` produces non-blank table | `SnapshotRendererTests.dashboardRowsRender()` | AC-F-13 |
| Dark frame is fully dark | `SnapshotRendererTests.darkSchemeNoBleed()` | AC-F-14 |
| Popover width set | `MenuBarPopoverViewTests.widthAtLeast480()` (`.frame(minWidth:)` introspection or snapshot intrinsic-width assertion) | AC-F-04 |
| Rich row renders all 3 fields | `MenuBarRichRowTests` | AC-F-06 |
| Retry affordance present iff failed | `MenuBarRichRowTests.retryGate()` | AC-F-12 |
| Strip is horizontal | `SourceBucketStripLayoutTests` (capture strip alone, assert width > 5×chipMinWidth, height < 50pt) | AC-F-10 |
| 0-count chip dimming + tooltip | `SourceBucketChipTests.zeroState()` | AC-F-11 |
| `capture-all` byte-stable | `CaptureAllStabilityTests` (re-run, hash-compare 8/10) | AC-F-19 |
| `ProviderDiagnostics` not public | tester diff: `swift symbolgraph` or grep on built `.swiftinterface` of `AgentJobsCore` | AC-F-18 |

Net new tests: ≥13 (target AC-F-02: ≥330 total, M05 ended at 317). Counting: PopoverGrouping (3), DashboardWindowConfig (2), SnapshotRenderer (3), MenuBarPopoverView (1), MenuBarRichRow (2), SourceBucketStripLayout (1), SourceBucketChip zeroState (1), CaptureAllStability (1) = 14.

---

## 6. Risks and decisions

| Risk | Mitigation | Owner |
|---|---|---|
| `Snapshot.capture` window-backed render changes timings; baselines redline globally. | Expected — entire baseline set regenerates anyway after T-014. Tester treats first capture post-T-014 as the baseline. | tester |
| `NavigationSplitView` collapse behavior depends on macOS minor version. | Pin via runtime check + record observed macOS version in capture-all sidecar JSON (already in metadata). | architect (already covered) |
| `WL-2` split adds a large move-only diff that hides bugs. | Sequence: split-first commit (pure rename + move, no behavior change), then T-002 commit (adds rich-row + grouping). Reviewer can review the split as a no-op. | implementer |
| Rich-row replaces `ServiceRowCompact` → may become dead code. | Keep `ServiceRowCompact` for now; reviewer is empowered to flag as dead if no consumers exist post-IMPL. M07 will revisit. | reviewer |
| `internal protocol DiagnosticsBearing` requires touching every provider. | Two providers today (`ClaudeScheduledTasksProvider`, `ClaudeSessionCronProvider`). Edit cost is small. | implementer |
| `RetryAffordance` global-refresh semantic is weaker than per-service retry. | Documented in spec §"out of scope". AC-F-12 only requires the affordance to exist + be reachable. | architect |
| Strip horizontal fix may not be the right root cause. | If `.fixedSize` doesn't reproduce the fix, fall back to laying out chips in a `LazyHGrid` with a single row — explicit, can't collapse axis. | implementer |

---

## 7. Out of scope (pinned again for implementer)

Per spec — do NOT touch:
- Color tokens / typography scale (M07).
- Custom menubar icon (T-001 / M07).
- Hook ring buffer (T-013).
- Sessions / agent observability (M10).
- Per-service retry semantics beyond global refresh.

---

## 8. Compliance summary

| Ticket | ACs covered | File(s) |
|---|---|---|
| T-014 | AC-F-13, AC-F-14, AC-V-03, AC-V-04, AC-D-07 | `Snapshot.swift` + `SnapshotRendererTests.swift` |
| T-002 | AC-F-04, AC-F-05, AC-F-06, AC-V-01, AC-V-02, AC-D-01, AC-D-02 | `MenuBarPopoverView.swift`, `MenuBarRowViews.swift`, `PopoverGrouping.swift`, `AgentJobsMacUI.swift` |
| T-003 | AC-F-07, AC-F-08, AC-F-09, AC-V-05, AC-D-03 | `DashboardWindowConfig.swift`, `DashboardView.swift`, `AgentJobsMacUI.swift`, `Scenarios.swift` |
| T-008 | AC-F-11, AC-D-05 | `SourceBucketChip.swift` |
| T-015 | AC-F-10, AC-D-04 | `SourceBucketStrip.swift`, `SourceBucketChip.swift` |
| T-016 | AC-F-12, AC-D-05 (affordance), AC-D-06 | `MenuBarRowViews.swift`, `RetryAffordance.swift` |
| WL-1 | AC verifier columns | `acceptance.md` (already encoded) |
| WL-2 | AC-F-17 | file moves listed above |
| WL-3 | AC-F-18 | `ServiceProvider.swift` + provider concretes |

All 6 tickets + 3 watch-list items have explicit file targets.
