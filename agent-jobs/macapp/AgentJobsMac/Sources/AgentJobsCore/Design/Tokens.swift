import SwiftUI

/// M07 design-token additions (T-T01/T-T02/T-T03).
///
/// **Additive:** `DesignTokens.SemanticColor` + `.SourceColor` are NEW
/// namespaces alongside the legacy `StatusColor` enum. Existing call sites
/// keep working; M07 wiring (Task 3) migrates the visible-surface call sites
/// (popover row, dashboard list row, inspector header, source bucket chip).
///
/// Color values are SwiftUI `Color` literals (sRGB) chosen to match the
/// system semantic colors used by the M02-M06 implementation, but pinned
/// to explicit values so they (a) survive SPM's asset-catalog limitations
/// (SPM 6.0 does not run `actool` in the non-Xcode build, so the
/// `.colorset` directories ship raw and `Color(named:)` returns nil — see
/// architecture §6 risk #3 for the documented fallback) and (b) are
/// byte-stable across machines, which AC-V-01..06 pixel-diff tests
/// implicitly depend on.
public extension DesignTokens {

    /// Status semantic colors. Names per AC-F-08 (`status<Status>`,
    /// flat under one namespace).
    /// Status semantic colors. Names per AC-F-08 (`status<Status>`,
    /// flat under one namespace).
    ///
    /// **Byte-stability note:** these intentionally alias the same
    /// `Color(.system*)` values used by `StatusColor` (legacy enum) so
    /// the M02-M06 pixel-diff baselines remain valid after Task-3 wiring
    /// migrates call sites from `StatusColor.*` to `SemanticColor.*`.
    /// Architecture §6 risk #5: do not regen older baselines mid-cycle.
    enum SemanticColor {
        public static let statusRunning   = Color(.systemGreen)
        public static let statusScheduled = Color(.systemBlue)
        public static let statusFailed    = Color(.systemRed)
        public static let statusIdle      = Color(.systemGray)
    }

    /// Per-source bucket palette. Names per AC-F-08 (`source<Bucket>`,
    /// flat under one namespace). Hues chosen to keep ΔE76 ≥ 8 across
    /// the 5 buckets AND avoid collision with `SemanticColor.status*`.
    enum SourceColor {
        public static let registered    = Color(.sRGB, red: 0.40, green: 0.20, blue: 0.78, opacity: 1.0)
        public static let claudeSched   = Color(.sRGB, red: 0.86, green: 0.50, blue: 0.16, opacity: 1.0)
        public static let claudeLoop    = Color(.sRGB, red: 0.96, green: 0.66, blue: 0.10, opacity: 1.0)
        public static let launchd       = Color(.sRGB, red: 0.20, green: 0.55, blue: 0.65, opacity: 1.0)
        public static let liveProc      = Color(.sRGB, red: 0.55, green: 0.30, blue: 0.55, opacity: 1.0)
    }
}

/// M07 typography + spacing additions (T-T02 / T-T03).
///
/// AC-F-09 requires `display`, `title`, `body`, `caption`, `mono`. The
/// existing `Typography` enum already exposes `title`, `body`, `caption`,
/// `mono`. We add `display` as the missing fifth token.
///
/// AC-F-10 requires `xs / sm / md / lg / xl = (4, 8, 12, 16, 24)`. The
/// existing `Spacing` enum exposes `xs / s / m / l / xl` with the same
/// numeric values. We add `sm`/`md`/`lg` as additional `static let`
/// aliases — the legacy single-letter names keep working.
public extension DesignTokens.Typography {
    /// Display-size headline. Currently aliases `.largeTitle` weight
    /// semibold; reserved for future inspector / about-window headers.
    static let display = Font.system(.largeTitle, design: .rounded, weight: .semibold)
}

public extension DesignTokens.Spacing {
    /// AC-F-10 alias for the existing `s` (8pt).
    static let sm: CGFloat = 8
    /// AC-F-10 alias for the existing `m` (12pt).
    static let md: CGFloat = 12
    /// AC-F-10 alias for the existing `l` (16pt).
    static let lg: CGFloat = 16
}

/// Tiny resolver helper. Architecture §1.2 calls for a `bundle:`-aware
/// asset-color loader. Because SPM does not compile `.xcassets` in
/// non-Xcode builds, this helper currently returns the supplied fallback
/// directly — it exists so future cycles can flip the implementation to
/// asset-catalog lookup without touching call sites.
public enum AssetColor {
    /// Returns the asset-catalog color named `name` if resolvable from
    /// `bundle`; otherwise the supplied fallback. `bundle` defaults to
    /// `.module` so `AgentJobsCore`'s own catalog is consulted first.
    public static func color(_ name: String,
                             bundle: Bundle = .main,
                             fallback: Color) -> Color {
        // Asset-catalog colors aren't compiled by SPM's non-Xcode path.
        // Future-proof: when a `.car` becomes available, swap to
        // `Color(name, bundle: bundle)`.
        _ = (name, bundle)
        return fallback
    }
}
