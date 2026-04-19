import SwiftUI

/// Single source of truth for visual rhythm. Reference Refactoring UI + Apple HIG.
public enum DesignTokens {

    public enum Spacing {
        public static let xxs: CGFloat = 2
        public static let xs:  CGFloat = 4
        public static let s:   CGFloat = 8
        public static let m:   CGFloat = 12
        public static let l:   CGFloat = 16
        public static let xl:  CGFloat = 24
        public static let xxl: CGFloat = 32
    }

    public enum Radius {
        public static let s:  CGFloat = 6
        public static let m:  CGFloat = 10
        public static let l:  CGFloat = 14
        public static let xl: CGFloat = 20
    }

    public enum Typography {
        public static let title    = Font.system(.title3, design: .rounded, weight: .semibold)
        public static let heading  = Font.system(.headline, design: .rounded, weight: .semibold)
        public static let body     = Font.system(.body)
        public static let metric   = Font.system(.title2, design: .rounded, weight: .medium)
        public static let caption  = Font.system(.caption, design: .rounded)
        public static let mono     = Font.system(.body, design: .monospaced)
        public static let monoSmall = Font.system(.caption, design: .monospaced)
    }

    public enum StatusColor {
        public static let running   = Color(.systemGreen)
        public static let scheduled = Color(.systemBlue)
        public static let failed    = Color(.systemRed)
        public static let idle      = Color(.systemGray)
        public static let paused    = Color(.systemOrange)
        public static let done      = Color(.systemTeal)
        public static let unknown   = Color.gray.opacity(0.6)
    }

    public enum ResourceColor {
        public static func cpu(_ pct: Double) -> Color {
            switch pct {
            case ..<5:  return .green
            case ..<50: return .yellow
            default:    return .red
            }
        }
        public static func memory(_ rss: UInt64) -> Color {
            switch rss {
            case ..<(100 * 1024 * 1024):  return .green
            case ..<(500 * 1024 * 1024):  return .yellow
            default:                       return .red
            }
        }
    }
}
