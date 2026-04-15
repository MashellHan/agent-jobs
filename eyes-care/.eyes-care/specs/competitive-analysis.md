# Competitive Analysis: macOS Eye Care & Break Reminder Apps

**Date:** 2026-04-15
**Author:** PM Agent
**Purpose:** Inform EyesCare v1 product strategy by analyzing existing solutions

---

## Executive Summary

The macOS eye-care/break-reminder market has 4 notable players: **Time Out** (native macOS veteran), **Stretchly** (cross-platform open-source), **BreakTimer** (minimalist open-source), and **Pandan** (ultra-lightweight menu bar utility). None of them are built on a **medical-guideline-first** foundation. This represents EyesCare's core differentiator: a 3-tier break system grounded in AAO, OSHA, and EU Directive standards, delivered as a native Swift/SwiftUI macOS app.

---

## Competitor Profiles

### 1. Time Out (Dejal)

| Attribute | Details |
|-----------|---------|
| **Platform** | macOS only (native) |
| **Pricing** | Free (full features); Supporter tiers $3.99-$14.99 |
| **Distribution** | Direct download, Mac App Store, Setapp, TestFlight |
| **Tech Stack** | Native macOS (likely Objective-C/Swift) |
| **Min macOS** | 10.15+ (stable), 26.0+ (beta v3.0) |

**Break System:**
- Normal Break: ~10 min every 60 min
- Micro Break: ~15 sec every 15 min
- Custom Breaks: user-defined (e.g., lunch, afternoon)

**Key Features:**
- Screen dimming/fading transitions during breaks
- Theming: HTML, YouTube, images, plain text
- Actions system: notifications, speech, sounds, AppleScript, Automator
- Activity tracking with visual charts
- Postpone & Skip buttons
- Countdown for natural away-time detection

**Strengths:**
- Mature product (10+ years)
- Deep customization (actions, themes, scripting)
- Activity tracking and visualization
- Native macOS experience

**Weaknesses:**
- No medical foundation — arbitrary break intervals
- Overwhelming customization for new users
- Aging UI (pre-SwiftUI design language)
- No health scoring or wellness insights
- No 20-20-20 rule built-in as a first-class concept

---

### 2. Stretchly

| Attribute | Details |
|-----------|---------|
| **Platform** | Windows, macOS, Linux (Electron) |
| **Pricing** | Free & open source; Sponsor tiers unlock advanced features |
| **Distribution** | Homebrew, GitHub Releases, Snap, Flathub, Microsoft Store |
| **Tech Stack** | Electron (Node.js) |
| **Min macOS** | Not specified (Electron-based) |

**Break System:**
- Mini Break: 20 sec every 10 min (default)
- Long Break: 5 min every 30 min (after 2 mini breaks)

**Key Features:**
- Pre-break notifications (10s mini, 30s long)
- Postpone (2 min mini, 5 min long) and Skip
- Strict Mode (prevents skipping)
- Idle detection (pauses after 5 min inactivity)
- Do Not Disturb awareness
- Sound themes (5 options)
- Advanced JSON config for power users
- Break "ideas" with HTML/image support
- Multi-screen support
- Dark mode / system theme following
- Sunrise-based morning pause

**Strengths:**
- Cross-platform (massive reach)
- Open source with active community
- Strict mode for disciplined users
- Rich customization via JSON
- Multi-screen awareness

**Weaknesses:**
- Electron = heavy resource usage (~100-200MB RAM)
- Not native macOS look & feel
- Complex JSON config for advanced features
- No medical citations — intervals are arbitrary defaults
- No health tracking or scoring
- Known issues: macOS Dock hiding, Wayland idle detection

---

### 3. BreakTimer

| Attribute | Details |
|-----------|---------|
| **Platform** | Windows, macOS, Linux (Electron) |
| **Pricing** | Free & open source (GPLv3) |
| **Distribution** | Direct download (.dmg, .exe, .deb, .rpm, AppImage, Snap) |
| **Tech Stack** | Electron |
| **Min macOS** | Not specified |

**Break System:**
- Single break type: configurable frequency + duration
- No tiered break system

**Key Features:**
- Simple scheduling: set frequency and duration
- Working hours restriction
- Smart notifications with snooze/skip
- Color theme customization
- Custom messages during breaks

**Strengths:**
- Simplest UX — minimal learning curve
- Working hours concept (don't disturb after hours)
- Clean, modern UI

**Weaknesses:**
- Only ONE break type — no micro/macro distinction
- No medical foundation
- Electron overhead
- No idle detection
- No activity tracking
- Minimal features — may feel too basic
- No community/ecosystem

---

### 4. Pandan (Sindre Sorhus)

| Attribute | Details |
|-----------|---------|
| **Platform** | macOS only (native Swift) |
| **Pricing** | Free, no ads |
| **Distribution** | Direct download |
| **Tech Stack** | Native Swift/SwiftUI |
| **Min macOS** | macOS 26+ (current), older builds to macOS 11 |

**Break System:**
- No structured break system — awareness-based approach
- Monitors active/idle time
- User-defined Shortcuts automations for break actions

**Key Features:**
- Menu bar time awareness (session tracking)
- 120-day history (intentional cap)
- Shortcuts app integration (New Session, Set Enabled, sounds, alerts)
- Screen effects: flash, invert (20s), grayscale (20s), lock
- Eye-break countdown timer
- Per-app enable/disable via Shortcuts
- Auto-disable on idle

**Strengths:**
- Ultra-lightweight and native
- Beautiful macOS-native design (Sindre Sorhus quality)
- Shortcuts integration = infinite extensibility
- Zero configuration required
- Privacy-first (no cloud, no accounts)

**Weaknesses:**
- Awareness-only — doesn't actively enforce breaks
- No structured break types (micro/macro/mandatory)
- No medical foundation
- Requires Shortcuts knowledge for advanced use
- No health scoring or reports
- Minimal out-of-box break enforcement

---

## Feature Comparison Matrix

| Feature | Time Out | Stretchly | BreakTimer | Pandan | **EyesCare (Planned)** |
|---------|----------|-----------|------------|--------|------------------------|
| **Native macOS** | Yes | No (Electron) | No (Electron) | Yes | **Yes (Swift/SwiftUI)** |
| **Medical foundation** | No | No | No | No | **Yes (AAO, OSHA, EU)** |
| **20-20-20 rule** | Manual config | Close (20s/10m) | No | No | **Yes (built-in)** |
| **3-tier breaks** | 2 tiers + custom | 2 tiers | 1 tier | 0 tiers | **3 tiers** |
| **Menu bar app** | Yes | Tray icon | Tray icon | Yes | **Yes** |
| **Idle detection** | Yes | Yes (5 min) | No | Yes | **Yes (CGEventSource)** |
| **Natural break credit** | Yes | Yes | No | Yes | **Yes** |
| **Activity tracking** | Yes | No | No | Basic | **Planned (v4+)** |
| **Health scoring** | No | No | No | No | **Planned (v5)** |
| **Daily reports** | No | No | No | No | **Planned (v6)** |
| **Notification modes** | Fade/overlay | Pre-break + break | Single notification | Shortcuts-based | **3 modes (v3)** |
| **Settings UI** | Full preferences | Full preferences | Basic | Minimal | **Planned (v7)** |
| **Eye exercises** | No | Break "ideas" | Custom messages | No | **Planned (v8)** |
| **Open source** | No | Yes | Yes | No | **No** |
| **Price** | Free/Supporter | Free/Sponsor | Free | Free | **Free** |

---

## Market Gaps & Opportunities

### 1. Medical Credibility Gap (PRIMARY)
No competitor cites medical sources for their break intervals. EyesCare's 3-tier system (AAO 20-20-20, OSHA hourly, EU mandatory) provides immediate credibility and trust. Users searching for "doctor-recommended" or "evidence-based" eye care find nothing.

### 2. Native macOS Gap
Only Time Out and Pandan are native. EyesCare joins this elite tier while offering more structure than Pandan and more modern code than Time Out.

### 3. Health Intelligence Gap
Zero competitors offer health scoring, trend analysis, or actionable wellness insights. This is EyesCare's v5-v9 moat.

### 4. Holistic Eye Care Gap
No app combines break reminders + eye exercises + health scoring + reports. EyesCare's full roadmap (v1-v10) creates a comprehensive eye wellness platform.

### 5. Modern macOS Design Gap
Time Out's UI is aging. Stretchly/BreakTimer look non-native. Pandan is beautiful but passive. EyesCare can be the modern, active, native eye care app.

---

## Positioning Strategy

**EyesCare = The doctor-recommended eye care app for macOS power users**

| vs. Competitor | EyesCare Advantage |
|----------------|-------------------|
| vs. Time Out | Medical foundation, modern SwiftUI, health scoring |
| vs. Stretchly | Native performance, 3-tier medical breaks, no Electron bloat |
| vs. BreakTimer | Multi-tier breaks, idle detection, much richer feature set |
| vs. Pandan | Active enforcement (not just awareness), structured breaks, reports |

---

## Key Takeaways for v1

1. **Menu bar is table stakes** — all competitors live in the menu bar / system tray
2. **Idle detection is expected** — 3 of 4 competitors have it; EyesCare must ship with CGEventSource idle monitoring in v1
3. **Start/stop monitoring is essential** — users expect to pause when in meetings, presentations, etc.
4. **Medical branding is our moat** — emphasize AAO, OSHA, EU sources in every interaction
5. **Keep v1 minimal but complete** — skeleton + menu bar + basic monitoring matches competitor MVPs
6. **Timer display in menu bar** — show time until next break (Stretchly's best UX feature)

---

## References

- Time Out: https://www.dejal.com/timeout/
- Stretchly: https://hovancik.net/stretchly/
- BreakTimer: https://breaktimer.app/
- Pandan: https://sindresorhus.com/pandan
- AAO 20-20-20 Rule: https://www.aao.org/eye-health/tips-prevention/computer-usage
- OSHA Computer Workstation Guidelines
- EU Directive 90/270/EEC on Display Screen Equipment
