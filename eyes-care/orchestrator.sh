#!/bin/bash
###############################################################################
# EyesCare Orchestrator — Multi-Agent Development Loop
#
# Coordinates 4 agents (PM, Lead, Dev, Tester) through iterative development
# of the EyesCare macOS app. Uses continuous-claude for Dev implementation
# and standard claude -p for other agents.
#
# Usage:
#   ./orchestrator.sh                    # Run all 10 versions
#   ./orchestrator.sh --start-version 3  # Resume from v3
#   ./orchestrator.sh --dry-run          # Print commands without executing
#
# Requirements:
#   - claude CLI in PATH
#   - continuous-claude in PATH
#   - gh CLI (GitHub CLI)
#   - git
###############################################################################

set -euo pipefail

# ─── Configuration ──────────────────────────────────────────────────────────
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
EYES_CARE_DIR="$PROJECT_DIR/.eyes-care"
PROMPTS_DIR="$EYES_CARE_DIR/prompts"
MAX_VERSIONS=10
START_VERSION=1
DRY_RUN=false
ACCEPTANCE_TIMEOUT_HOURS=3
DEV_MAX_RUNS=5

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --start-version) START_VERSION="$2"; shift 2 ;;
    --max-versions) MAX_VERSIONS="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --dev-max-runs) DEV_MAX_RUNS="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ─── Helpers ────────────────────────────────────────────────────────────────
log() {
  local level="$1"; shift
  local ts
  ts=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$ts] [$level] $*"
  echo "[$ts] [$level] $*" >> "$EYES_CARE_DIR/orchestrator.log"
}

run_agent() {
  local role="$1"
  local prompt_file="$2"
  local version="$3"
  local extra_context="${4:-}"

  log "INFO" "=== Running $role Agent (v$version) ==="

  if [[ "$DRY_RUN" == "true" ]]; then
    log "DRY-RUN" "Would run: claude -p <$prompt_file> in $PROJECT_DIR"
    return 0
  fi

  # Build the prompt with version context
  local prompt
  prompt="$(cat "$prompt_file")

## Current Version: v${version}
## Project Directory: ${PROJECT_DIR}
## Working Directory: You are already in the project directory.

${extra_context}

Read .eyes-care/status.md first to understand the current state.
Then execute your role for version v${version}."

  cd "$PROJECT_DIR"

  # Run claude with the prompt
  claude -p "$prompt" \
    --allowedTools "Read,Write,Edit,Bash,Grep,Glob,WebSearch,WebFetch,Agent" \
    2>&1 | tee -a "$EYES_CARE_DIR/logs/${role}-v${version}.log"

  log "INFO" "$role Agent (v$version) completed"
}

run_dev_agent() {
  local version="$1"

  log "INFO" "=== Running Dev Agent via continuous-claude (v$version) ==="

  if [[ "$DRY_RUN" == "true" ]]; then
    log "DRY-RUN" "Would run: continuous-claude in $PROJECT_DIR"
    return 0
  fi

  local prompt
  prompt="$(cat "$PROMPTS_DIR/dev-prompt.md")

## Current Version: v${version}
## Project Directory: ${PROJECT_DIR}

Read .eyes-care/handoffs/lead-to-dev-v${version}.md for your task list.
Read .eyes-care/status.md for current state.
Implement all tasks, committing and pushing each one separately."

  cd "$PROJECT_DIR"

  continuous-claude \
    -p "$prompt" \
    --max-runs "$DEV_MAX_RUNS" \
    --disable-branches \
    --notes-file "$EYES_CARE_DIR/handoffs/lead-to-dev-v${version}.md" \
    2>&1 | tee -a "$EYES_CARE_DIR/logs/dev-v${version}.log"

  log "INFO" "Dev Agent (v$version) completed"
}

check_acceptance() {
  local version="$1"

  local pm_acceptance="$EYES_CARE_DIR/handoffs/pm-acceptance-v${version}.md"
  local lead_acceptance="$EYES_CARE_DIR/reviews/v${version}-acceptance.md"

  local pm_ok=false
  local lead_ok=false

  if [[ -f "$pm_acceptance" ]] && grep -qi "ACCEPTED: true" "$pm_acceptance" 2>/dev/null; then
    pm_ok=true
  fi

  if [[ -f "$lead_acceptance" ]] && grep -qi "ACCEPTED: true" "$lead_acceptance" 2>/dev/null; then
    lead_ok=true
  fi

  if [[ "$pm_ok" == "true" ]] && [[ "$lead_ok" == "true" ]]; then
    return 0
  fi
  return 1
}

# ─── Setup ──────────────────────────────────────────────────────────────────
mkdir -p "$EYES_CARE_DIR"/{specs,architecture,reviews,testing,handoffs,prompts,logs}

log "INFO" "╔══════════════════════════════════════════════╗"
log "INFO" "║  EyesCare Orchestrator Starting              ║"
log "INFO" "║  Versions: $START_VERSION → $MAX_VERSIONS              ║"
log "INFO" "║  Dev max runs per version: $DEV_MAX_RUNS    ║"
log "INFO" "║  Dry run: $DRY_RUN                          ║"
log "INFO" "╚══════════════════════════════════════════════╝"

# ─── Main Loop ──────────────────────────────────────────────────────────────
VERSION=$START_VERSION

while [[ $VERSION -le $MAX_VERSIONS ]]; do
  log "INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  log "INFO" "  VERSION $VERSION / $MAX_VERSIONS"
  log "INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # ── Phase 1: PM — PRD + UX Design ─────────────────────────────────────
  if [[ $VERSION -eq 1 ]]; then
    run_agent "pm" "$PROMPTS_DIR/pm-prompt.md" "$VERSION" \
      "This is the FIRST version. Start with competitive research, then write the PRD and UX design."
  else
    run_agent "pm" "$PROMPTS_DIR/pm-prompt.md" "$VERSION" \
      "This is version $VERSION. Review previous version results, do acceptance check, then plan this version."
  fi

  # ── Phase 2: Lead — Architecture + Task Breakdown ─────────────────────
  run_agent "lead" "$PROMPTS_DIR/lead-prompt.md" "$VERSION" \
    "PHASE: Architecture. Read PM's PRD and design the architecture, then write task breakdown for Dev."

  # ── Phase 3: Dev — Implementation ─────────────────────────────────────
  run_dev_agent "$VERSION"

  # ── Phase 4: Lead — Code Review ───────────────────────────────────────
  run_agent "lead" "$PROMPTS_DIR/lead-prompt.md" "$VERSION" \
    "PHASE: Code Review. Dev has finished implementing. Review the code and write your review document."

  # ── Phase 5: Tester — Testing + Bug Reports ───────────────────────────
  run_agent "tester" "$PROMPTS_DIR/tester-prompt.md" "$VERSION"

  # ── Phase 6: PM + Lead — Acceptance ───────────────────────────────────
  run_agent "pm" "$PROMPTS_DIR/pm-prompt.md" "$VERSION" \
    "PHASE: Acceptance. Review tester reports and Lead's review. Decide if this version is acceptable."

  run_agent "lead" "$PROMPTS_DIR/lead-prompt.md" "$VERSION" \
    "PHASE: Acceptance. Review tester reports. Write acceptance document."

  # ── Check Acceptance ──────────────────────────────────────────────────
  if check_acceptance "$VERSION"; then
    log "INFO" "✅ Version $VERSION ACCEPTED by both PM and Lead"
  else
    log "WARN" "⚠️ Version $VERSION has issues — proceeding to next version anyway"
    log "WARN" "Issues will be carried forward to v$((VERSION + 1))"
  fi

  # ── Iteration Bugfix Loop (if Tester found bugs) ──────────────────────
  bug_report="$EYES_CARE_DIR/testing/v${VERSION}-bug-report.md"
  if [[ -f "$bug_report" ]] && grep -qi "CRITICAL\|HIGH" "$bug_report" 2>/dev/null; then
    log "INFO" "🐛 Critical/High bugs found — running bugfix iteration"

    # Dev fixes bugs
    run_dev_agent "$VERSION"

    # Lead re-reviews
    run_agent "lead" "$PROMPTS_DIR/lead-prompt.md" "$VERSION" \
      "PHASE: Code Review (bugfix pass). Dev fixed bugs. Re-review the changes."

    # Tester re-tests
    run_agent "tester" "$PROMPTS_DIR/tester-prompt.md" "$VERSION"
  fi

  VERSION=$((VERSION + 1))
done

log "INFO" "╔══════════════════════════════════════════════╗"
log "INFO" "║  EyesCare Orchestrator Complete              ║"
log "INFO" "║  $MAX_VERSIONS versions processed             ║"
log "INFO" "╚══════════════════════════════════════════════╝"
