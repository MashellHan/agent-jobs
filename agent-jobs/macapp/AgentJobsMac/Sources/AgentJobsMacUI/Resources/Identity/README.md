# Identity assets

This directory holds the **vector source-of-truth** for the app's visual
identity:

- `menubar-glyph.svg` — 16pt logical canvas, monoline black-on-clear.
  Rasterized to `Resources/Assets.xcassets/MenuBarIcon.imageset/menubar-glyph{,@2x,@3x}.png`
  by `scripts/build-icns.sh`. AppKit treats the rendered image as a
  template (`renderingMode: .template`) so it auto-tints by menubar
  appearance — never check in a colored PNG.
- `app-icon.svg` — 1024 master canvas. Rasterized to the 10
  AppIcon slots (16/32/128/256/512 @1x and @2x) AND to a stand-alone
  `agent-jobs.icns` via `iconutil`.

## Why two distinct artifacts (not one symbol)

The macOS menubar template glyph and the Dock app icon serve different
jobs (per `competitive-analysis.md` §1 + §3). The menubar glyph must
read at 16pt under a wallpaper-tinted, dynamically-themed status strip;
the app icon gets to be richer because it lives in the Dock at 64-128pt
under a known background. Coupling them to a single SVG forces the
weakest of both worlds.

## Regenerating PNG assets

```bash
bash scripts/build-icns.sh
```

This is **idempotent** — re-running with no SVG edit produces no
`git diff`. The script renders via Swift+CoreGraphics (no `librsvg`
dependency); see `scripts/build-icns.sh` for the precise pipeline.

The script writes the PNGs into:
- `Sources/AgentJobsMacUI/Resources/Assets.xcassets/AppIcon.appiconset/`
- `Sources/AgentJobsMacUI/Resources/Assets.xcassets/MenuBarIcon.imageset/`

…and a stand-alone `.build/agent-jobs.icns` for documented standalone
distribution (referenced by AC-F-05).

## Cycle-1 notes

The committed SVGs are placeholders — a layered "stack" glyph chosen
to be recognizable as a service/job list while we wait on the real
icon design. Cycle-2 lands the real glyph after ui-critic feedback
(per architecture §7). The pipeline + asset wiring + tests are real
and don't change between cycles.
