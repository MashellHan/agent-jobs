# EyesCare Project Status

## Current Version: v1
## Phase: Dev Implementation Complete — Awaiting Lead Review
## Last Updated: 2026-04-15

---

### Version Roadmap

| Version | Theme | Status |
|---------|-------|--------|
| v1 | Skeleton + Menu Bar + Basic Monitoring | **Dev implementation complete** → Lead review |
| v2 | Core Reminders (20-20-20, 3-tier breaks, CGEventSource) | Pending |
| v3 | Notification Upgrade (Gentle/Normal/Aggressive modes) | Pending |
| v4 | Data Persistence (JSON, UserDefaults, history) | Pending |
| v5 | Health Scoring (4-dimensional algorithm) | Pending |
| v6 | Daily Report System (Markdown, stats, trends) | Pending |
| v7 | Settings Panel (Preferences window, custom intervals) | Pending |
| v8 | Eye Exercises (blink reminders, eye movement guides) | Pending |
| v9 | Dashboard (local web page, weekly/monthly reports) | Pending |
| v10 | Polish & Release (auto-launch, DMG, docs) | Pending |

### v1 Deliverables

| Document | Path | Status |
|----------|------|--------|
| Competitive Analysis | `.eyes-care/specs/competitive-analysis.md` | Complete |
| v1 PRD | `.eyes-care/specs/v1-prd.md` | Complete |
| v1 UX Design | `.eyes-care/specs/v1-ux-design.md` | Complete |
| PM-to-Lead Handoff | `.eyes-care/handoffs/pm-to-lead-v1.md` | Complete |
| v1 Architecture | `.eyes-care/architecture/v1-architecture.md` | Complete |
| v1 Tech Decisions | `.eyes-care/architecture/v1-tech-decisions.md` | Complete |
| Lead-to-Dev Handoff | `.eyes-care/handoffs/lead-to-dev-v1.md` | Complete |
| Dev-to-Lead Handoff | `.eyes-care/handoffs/dev-to-lead-v1.md` | **Complete** |

### v1 Implementation Status

| Component | Status | Notes |
|-----------|--------|-------|
| Package.swift | **Complete** | Test target + strict concurrency + swift-testing dep |
| EyesCareApp.swift | Complete | @main entry point — no changes needed |
| AppDelegate.swift | **Complete** | Full rewrite with monitoring, toggle, status display |
| BreakType.swift | Complete | 3-tier medical break definitions |
| ReminderMode.swift | Complete | Gentle/Normal/Aggressive enum |
| Constants.swift | Complete | Polling/idle thresholds |
| ActivityState.swift | **Complete** | State machine enum with threshold derivation |
| IdleDetecting.swift | **Complete** | Protocol for testability |
| CGEventSourceIdleDetector.swift | **Complete** | Production implementation (4 event types) |
| MonitoringStatus.swift | **Complete** | Immutable snapshot struct |
| MonitoringSessionDelegate.swift | **Complete** | Delegate protocol (@MainActor) |
| TimeFormatter.swift | **Complete** | Time display formatting |
| MonitoringSession.swift | **Complete** | Core orchestrator with state machine |
| Unit Tests (7 files) | **Complete** | 41 tests, 81.82% coverage |

### v1 Task Breakdown (8 Tasks for Dev)

| Task | Description | Status |
|------|-------------|--------|
| 1 | Add test target + strict concurrency to Package.swift | **Complete** |
| 2 | Create ActivityState model | **Complete** |
| 3 | Create IdleDetecting protocol + CGEventSourceIdleDetector | **Complete** |
| 4 | Create MonitoringStatus + MonitoringSessionDelegate | **Complete** |
| 5 | Create TimeFormatter utility | **Complete** |
| 6 | Create MonitoringSession service | **Complete** |
| 7 | Extend AppDelegate with full menu bar integration | **Complete** |
| 8 | Add unit tests (>= 80% coverage) | **Complete** |

### Test Results

- **41 tests passed, 0 failures**
- **Region coverage: 81.82%** (target: >= 80%)
- Framework: Swift Testing via swift-testing package

### Recent Activity

- 2026-04-15: PM completed competitive analysis (Time Out, Stretchly, BreakTimer, Pandan)
- 2026-04-15: PM wrote v1 PRD with 10 acceptance criteria
- 2026-04-15: PM wrote v1 UX design with menu layouts and user flows
- 2026-04-15: PM wrote PM-to-Lead handoff document
- 2026-04-15: Project initialized with skeleton code
- 2026-04-15: Lead completed v1 architecture design (architecture doc, tech decisions, 12 TDs)
- 2026-04-15: Lead wrote 8-task breakdown for Dev (handoff document)
- 2026-04-15: **Dev completed all 8 tasks** (8 commits pushed to main)
- 2026-04-15: **Dev wrote handoff document** (dev-to-lead-v1.md)

### Acceptance Status

- PM Specs: **Complete** (competitive analysis, PRD, UX design, handoff)
- Lead Architecture: **Complete** (architecture, tech decisions, dev handoff)
- Dev Implementation: **Complete** (8 tasks, 41 tests, 81.82% coverage)
- Lead Review: **Awaiting**
- Tester Verification: Not Started
- PM Acceptance: Not Started

### Key Decisions

1. **Idle Detection:** CGEventSource — 4 event types (keyboard, mouse, click, scroll), take minimum
2. **Menu Bar:** NSMenu with stored NSMenuItem references for dynamic updates
3. **State Machine:** 3 states (Active -> Idle -> Away/Natural Break) via pure function
4. **No Dock Icon:** Empty Settings scene approach (LSUIElement style)
5. **Medical Foundation:** AAO 20-20-20, OSHA hourly, EU Directive mandatory
6. **Architecture:** Protocol-based DI, @MainActor for MonitoringSession, delegate pattern
7. **Testing:** Swift Testing framework via swift-testing package
8. **Time Tracking:** Date-based (not accumulated intervals) to prevent drift
9. **Naming:** Protocol = `IdleDetecting`, Concrete = `CGEventSourceIdleDetector`
10. **Immutable Snapshots:** `MonitoringStatus` struct as data transfer object
11. **swift-tools-version:** Bumped to 6.0 for Swift Testing support
12. **swift-testing dependency:** Required since env has CommandLineTools only (no Xcode)

### Blockers

None — ready for Lead review.
