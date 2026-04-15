# EyesHealth - Agent Collaboration Protocol

## Agents

| Role | Responsibility |
|------|---------------|
| **PM** | Competitive research, feature design, UX, beautification |
| **Lead** | Code review, architecture, project acceptance |
| **Dev** | Code implementation, split commits, push to main |
| **Tester** | Test cases, bug finding, issue reporting |

## Iteration Flow

```
PM: spec → Lead: review spec → Dev: implement → Lead: review code
                                                      ↓
                                              Tester: test → report
                                                      ↓
                                              Dev: fix issues
                                                      ↓
                                              PM: check features → plan next
```

## Document Naming

- `specs/v{N}-spec.md` — PM design spec
- `reviews/v{N}-spec-review.md` — Lead review of spec
- `reviews/v{N}-code-review.md` — Lead code review
- `test-reports/v{N}-test-report.md` — Tester report
- `iterations/v{N}-summary.md` — Iteration summary
- `handoffs/v{N}-{from}-to-{to}.md` — Agent handoff notes

## Acceptance Criteria

- Minimum 10 iterations
- PM and Lead both agree "no issues" for 3 consecutive hours → project accepted
- Each iteration ~30 minutes

## Version Roadmap

| Version | Focus |
|---------|-------|
| V1 | Project skeleton + idle detection + basic menu bar app |
| V2 | 20-20-20 rule + notification reminders |
| V3 | Multiple reminder modes (gentle/modal/fullscreen) |
| V4 | Usage tracking + data persistence |
| V5 | Daily report generation (markdown) |
| V6 | Eye health score algorithm |
| V7 | Blink exercise guidance + statistics |
| V8 | Settings UI + auto-start + polish |
| V9 | Dashboard view + weekly trends |
| V10 | Final polish, performance, acceptance |
