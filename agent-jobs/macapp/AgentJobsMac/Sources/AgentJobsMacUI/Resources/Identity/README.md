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

## Cycle-2 notes

Cycle-1 shipped a sparse 3-bar placeholder; tester REJECT 24/26 on
AC-V-01 (central 8x8 luma 0.631 vs <0.2 spec target). Cycle-2 lands
the real glyph: a centered, filled 14×14 rounded "tray" body with two
1px negative-space slits (header / body / footer split) and a
"running" badge-anchor dot overhanging the upper-right corner. The
slits sit OUTSIDE the central 8x8 sample window so the glyph reads
as a dense cluster at small sizes (central 8x8 luma over white ≈
0.04, white-tinted over black ≈ 0.96 — clears AC-V-01 < 0.2 and
AC-V-04 / AC-F-17 > 0.7 with healthy margin).
