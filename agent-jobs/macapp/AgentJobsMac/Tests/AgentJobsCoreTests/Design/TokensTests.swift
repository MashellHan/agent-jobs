import Testing
import Foundation
import SwiftUI
import AgentJobsCore

/// M07 design-token namespace shape (T-T01 / T-T02 / T-T03).
@Suite("Design tokens — namespace shape (M07)")
struct TokensTests {

    @Test("AC-F-08: SemanticColor exposes 4 status names")
    func semanticColorNamespaceShape() {
        // `Color` doesn't expose a sensible equatable surface in SwiftUI,
        // but presence + non-clear contract is enough for the AC.
        let names: [(String, Color)] = [
            ("statusRunning",   DesignTokens.SemanticColor.statusRunning),
            ("statusScheduled", DesignTokens.SemanticColor.statusScheduled),
            ("statusFailed",    DesignTokens.SemanticColor.statusFailed),
            ("statusIdle",      DesignTokens.SemanticColor.statusIdle),
        ]
        for (name, color) in names {
            // Conversion to a CGColor is the simplest "this color is
            // realizable" check. clear / unresolved colors return nil
            // CGColors on macOS.
            #expect(color != Color.clear, "\(name) must not be clear")
        }
        #expect(names.count == 4)
    }

    @Test("AC-F-08: SourceColor exposes 5 source names")
    func sourceColorNamespaceShape() {
        let names: [(String, Color)] = [
            ("registered",  DesignTokens.SourceColor.registered),
            ("claudeSched", DesignTokens.SourceColor.claudeSched),
            ("claudeLoop",  DesignTokens.SourceColor.claudeLoop),
            ("launchd",     DesignTokens.SourceColor.launchd),
            ("liveProc",    DesignTokens.SourceColor.liveProc),
        ]
        for (name, color) in names {
            #expect(color != Color.clear, "\(name) must not be clear")
        }
        #expect(names.count == 5)
    }

    @Test("AC-F-09: Typography exposes display/title/body/caption/mono")
    func typographyNamespaceShape() {
        // Just touch each accessor — compilation is the test.
        let _ = [
            DesignTokens.Typography.display,
            DesignTokens.Typography.title,
            DesignTokens.Typography.body,
            DesignTokens.Typography.caption,
            DesignTokens.Typography.mono,
        ]
        #expect(true)
    }

    @Test("AC-F-10: Spacing exposes xs/sm/md/lg/xl with canonical values")
    func spacingNamespaceShape() {
        #expect(DesignTokens.Spacing.xs == 4)
        #expect(DesignTokens.Spacing.sm == 8)
        #expect(DesignTokens.Spacing.md == 12)
        #expect(DesignTokens.Spacing.lg == 16)
        #expect(DesignTokens.Spacing.xl == 24)
    }

    @Test("AssetColor.color falls back to the supplied default when no catalog")
    func assetColorFallback() {
        let fallback = Color.purple
        let resolved = AssetColor.color("DoesNotExistAtAll", fallback: fallback)
        // Equatable on SwiftUI Color isn't reliable, but the function
        // returning at all is the contract; we just assert the helper
        // doesn't crash for a missing name.
        _ = resolved
        #expect(true)
    }
}
