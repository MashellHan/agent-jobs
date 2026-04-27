# M07 Competitive Analysis — Menubar Identity, Icon Pipeline, Token Strategy

**Filed:** 2026-04-27
**Owner agent:** pm
**Scope:** how peer macOS menu-bar utilities solve (a) 16pt menubar legibility, (b) running-count badging, (c) the .icns master pipeline, (d) SF-Symbol customization patterns. Used to ground T-001 + T-T01..T03 design decisions.

---

## 1. Stats (exelban/stats)

**What it is:** open-source system monitor (CPU / GPU / RAM / Disk / Network / Battery / Sensors), one menubar widget per metric.

**Menubar strategy at 16pt:**
- Each module renders its own template image generated at runtime (NSImage with `isTemplate = true`), composited from a base glyph + a live data layer (mini-bar chart, percent text, or sparkline).
- Glyphs are simple, mostly single-shape outlines — Stats avoids fine detail at 16pt because hairlines disappear when macOS auto-tints for dark menubars.
- Color escapes the template constraint by being drawn as an *overlay* (e.g., the CPU% number is colored by threshold, not the underlying glyph).

**Lesson for T-001:** keep the agent-jobs glyph monoline / monoshape. Push color into a *separate* badge layer that is NOT marked `isTemplate`, drawn on top of the template glyph. That mirrors Stats's separation and is the only way to get a colored count badge while still having the glyph track menubar appearance.

**.icns pipeline:** Stats commits a single 1024×1024 PNG master under `Stats/Supporting Files/Assets.xcassets/AppIcon.appiconset/` and lets Xcode generate the rendered .icns. The full appiconset includes 16, 32, 128, 256, 512 each at @1x and @2x. Source vector is not committed — they iterate on the raster master.

**Lesson:** committing the SVG/vector source under `Resources/Identity/` (not just the rendered PNG) is strictly better than Stats's setup; we avoid lossy round-tripping when the glyph changes.

---

## 2. Bartender (surtees-software, closed-source)

**What it is:** menubar-organizer that hides/shows other menubar items.

**Menubar strategy at 16pt:**
- Single bold glyph: stylized "B" with a horizontal bar through it. Reads as "menubar manager" via the bar-through-letter metaphor. Single-color template.
- No badge layer at idle — they use a small triangle disclosure when popover state is "items hidden." Demonstrates that *state can be communicated without a badge* by mutating the glyph itself.

**Lesson:** count-badge is one option for state, but glyph mutation (adding a small dot, a rotation, a stroke) is also legitimate and arguably more native. We're going with badge per T-001 done-when, but keep glyph-mutation as a fallback if the badge legibility tests fail at 16pt.

**Identity strength:** Bartender's "B-with-bar" is a literal logo + literal product noun fused into one glyph. Worth aiming for the same compression in agent-jobs — e.g., a watching-eye + task-list metaphor fused.

---

## 3. iStat Menus (bjango, closed-source — premium reference)

**What it is:** the gold standard for macOS menubar metric displays.

**Menubar strategy at 16pt:**
- Per-module: highly optimized glyph + live data text. Uses custom-rendered text in the menubar (NSStatusItem with attributed string), not just an image — gives them sub-pixel control over digit kerning at 16pt.
- The "Combined" widget shows multiple metrics in one item with explicit micro-typography for the numerals.
- Their iconography uses a consistent stroke weight (1px @1x, 2px @2x) across all 12+ modules — visual cohesion across a multi-module surface.

**Lesson for T-001 count badge:** at 16pt, custom-rendered text (NSAttributedString with a tight monospace font) is more legible than a bitmap badge. For a 1-2 digit count, this is achievable. Document under T-001 architecture: badge implementation should prefer text-attribute composition over a pre-rendered badge image.

**Identity at 1024:** iStat Menus uses a single recognizable graph-line motif scaled across all icon sizes. The 1024 master is heavily detailed with depth + shadow; the 16pt is reduced to pure outline. Two distinct artifacts, one identity.

**Lesson:** for our 1024 system icon, we can afford detail (gradient, depth, shadow) that the 16pt menubar version cannot have. Plan for *two* visual artifacts: the simple template glyph (monoline, no fill) + the rich app icon (full-color, layered).

---

## 4. SF Symbol customization patterns (Apple-native baseline)

**Status quo (M06 placeholder):** we ship `Image(systemName: "circle")` or similar. Generic, meaningless.

**Customization options Apple provides:**
- **Symbol variants** — `.fill`, `.circle`, `.slash`, `.square` modifiers. Useful for state but visually weak as identity.
- **Symbol effects (iOS 17 / macOS 14)** — `.symbolEffect(.pulse)`, `.bounce`, `.variableColor`. Reserved for M11 (motion) per ROADMAP, not in scope here.
- **Symbol composition** — overlaying two SF Symbols (e.g., `clock` + `badge.checkmark`). Better than single symbol but still feels generic; common Apple-app pattern (Reminders, Mail).
- **Custom SF Symbols** — Apple's SF Symbols.app lets you export a starter `.svg` template (~1MB), edit in Illustrator/Sketch/Figma to honor the 9-stroke-weight x 3-scale grid, re-import as a `.symbolset` in Xcode asset catalog. This is the recommended path for shipping a genuinely custom glyph that still inherits SF Symbols' weight/scale/dynamic-type behavior.

**Lesson for T-001:** the "right" identity path is a **custom SF Symbol** in the asset catalog (not a raw PNG asset). Trade-offs:
- ✅ Inherits SwiftUI font-weight + dynamic-type scaling automatically.
- ✅ Renders crisp at any size from a single source.
- ✅ Plays well with `.renderingMode(.template)`.
- ❌ Requires a vector design + 9-weight × 3-scale variants (significant designer work).
- ❌ Not all weight/scale combos may be needed — can ship just `.regular` weight × `medium` scale to start, expand later.

**Recommendation:** ship a custom SF Symbol as the menubar glyph (inherits all the platform plumbing) AND a separate full-color rasterized 1024 master for the system app icon (where SF Symbol's monochrome constraint would hurt identity). Two sources, two pipelines, one consistent design language.

---

## 5. .icns master pipeline (industry summary)

**Three viable paths:**

| Path | How | Pros | Cons |
|---|---|---|---|
| Asset catalog `AppIcon.appiconset` | Drop pre-rendered PNGs at 16/32/128/256/512 @1x+@2x; Xcode produces .icns at build | Standard, tooled, what Stats does | 10 PNGs to keep in sync; manual export pain |
| `iconutil --convert icns my.iconset` | Build a `my.iconset/` folder with named PNGs (`icon_16x16.png` … `icon_512x512@2x.png`); run `iconutil` in a script | Reproducible from a single 1024 source via ImageMagick downscale; CI-friendly | Requires a shell script step in build |
| Single 1024 in asset catalog (modern, macOS 11+) | Asset catalog accepts a single 1024×1024 PNG; system synthesizes other sizes | Lowest maintenance | Synthesis may be lower quality than designer-tuned downscales at small sizes |

**Recommendation for M07:** **Option 2 (`iconutil` from script)** because:
- Single 1024 SVG source committed under `Resources/Identity/app-icon.svg`.
- A small build script (or a `Package.swift` target plugin) renders the 1024 PNG, downscales to all required sizes via `sips` or `rsvg-convert`, builds the `.iconset/`, and runs `iconutil`.
- Reproducible: anyone can regenerate the .icns from the SVG. CI can verify the committed .icns matches the source SVG's render.
- One source of truth; no "which PNG is canonical" question.

If architect finds this is over-engineering for a one-time icon, fall back to Option 1 (asset catalog with hand-exported PNGs). Document the choice in `Resources/Identity/README.md`.

---

## 6. Color token strategy (industry summary)

**Reference patterns:**

- **Apple HIG semantic colors** (`Color.accentColor`, `.red`, `.systemBlue`) — auto-adapts light/dark, but limited palette + can't communicate domain semantics ("running" vs "scheduled" vs "failed").
- **Linear-style design tokens** — single source of truth in TS (`colors.status.success`, `colors.surface.primary`); compiled to CSS variables. Native equivalent: a Swift `enum` namespace with `static let` properties returning `Color`.
- **Stripe-style two-tier tokens** — primitives (`gray-100`, `blue-500`) + semantic aliases (`text-secondary`, `interactive-primary`) referencing primitives. Overkill for our scope — we ship semantic only.

**Recommendation for T-T01:** single-tier semantic tokens, namespaced `DesignTokens.Color`, returning SwiftUI `Color` values that resolve via asset-catalog color sets (NOT hardcoded RGB). This gives us:
- Light/dark variants free (asset catalog handles it).
- Future-proof for Increased Contrast / High Contrast accessibility (asset catalog supports those variants too — useful in M14).
- Searchable, discoverable, refactorable from Xcode.

Color set names: `StatusRunning`, `StatusScheduled`, `StatusFailed`, `StatusIdle`, `SourceRegistered`, `SourceClaudeSched`, `SourceClaudeLoop`, `SourceLaunchd`, `SourceLiveProc`. Static properties on `DesignTokens.Color` reference these by name. 9 color sets total.

---

## 7. Type scale strategy (industry summary)

**Reference patterns:**

- **Apple HIG dynamic type styles** (`.largeTitle`, `.title`, `.body`, `.caption`) — automatic Dynamic Type support, native idiom. Strongly preferred for any text the user reads.
- **Custom point-size scales** — tempting but loses Dynamic Type unless you wrap in `.font(.system(size: ..., weight: ...))` and add a custom Dynamic-Type adjustment layer. Not worth the complexity for this milestone.

**Recommendation for T-T02:** use Apple's `Font.TextStyle` enum as the scale; just wrap in our `DesignTokens.Font` namespace so callsites read intent (`DesignTokens.Font.title`, not `.font(.title)`). Adds ~zero code, gains intent-revealing call sites. Mappings:

| Token | Maps to | Used for |
|---|---|---|
| `display` | `.largeTitle.weight(.semibold)` | (reserved; not used in M07 surfaces) |
| `title` | `.title2.weight(.semibold)` | inspector header, dashboard window title, popover row primary title |
| `body` | `.body` | row summary lines, body copy |
| `caption` | `.caption` | metadata grid labels, microcopy |
| `mono` | `.system(.body, design: .monospaced)` | command strings, paths |

5 tokens. Smallest scale that covers M07's visible surfaces.

---

## 8. Cross-cutting takeaways for T-001 + tokens

1. **Two artifacts, one identity.** Custom SF Symbol for menubar (template, monoline) + rich rasterized app icon (color, layered) sharing a common motif. Never try to use the same artifact for both.
2. **Badge as separate non-template overlay.** Template constraint forbids color in the glyph; the badge MUST be a separate layer. Use NSAttributedString text composition over a bitmap badge for digit legibility at 16pt (per iStat Menus technique).
3. **Commit the SVG source.** Don't bet "the right answer" on a binary artifact alone. `Resources/Identity/menubar-glyph.svg` + `Resources/Identity/app-icon.svg` + a regen script.
4. **Asset-catalog color sets, not hardcoded RGB.** Buys light/dark + accessibility variants for free; pays back in M14.
5. **Apple `Font.TextStyle` under our namespace.** Gains intent-revealing call sites without losing Dynamic Type support.
6. **Avoid SF Symbol effects in M07.** Reserved for M11 (motion). Tempting at icon-pipeline time; resist.
7. **Count badge contract: 0 / 1..9 / 9+.** Three tested branches. Matches every peer (Stats, iStat, Mail).

---

## 9. References

- exelban/stats — https://github.com/exelban/stats (asset catalog under `Stats/Supporting Files/Assets.xcassets/`)
- bjango/iStat Menus — proprietary; visual reference only
- Apple SF Symbols 5 release notes & SF Symbols.app export workflow — Apple Developer documentation
- Apple HIG — App icons, Menu bar extras, Color
- Linear / Stripe public design-token writings — design-system reference for namespacing strategy
