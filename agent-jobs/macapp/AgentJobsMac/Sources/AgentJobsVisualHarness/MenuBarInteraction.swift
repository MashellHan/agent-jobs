import Foundation
import CoreGraphics
import ApplicationServices

/// Locates the Agent Jobs `MenuBarExtra` and synthesizes user clicks via
/// the AX + CGEvent stack. Real implementation lands in M05 T06; T02
/// only ships the public surface so callers compile.
public enum MenuBarInteraction {

    public enum Error: Swift.Error, CustomStringConvertible {
        case accessibilityDenied
        case notFound
        case eventPostFailed
        case notImplemented
        public var description: String {
            switch self {
            case .accessibilityDenied: return "Accessibility permission required"
            case .notFound:            return "Menu extra not found"
            case .eventPostFailed:     return "CGEventPost failed"
            case .notImplemented:      return "MenuBarInteraction T06 pending"
            }
        }
    }

    public static func requiresAccessibility() -> Bool {
        !AXIsProcessTrusted()
    }

    public static func locateAgentJobsMenuExtra(bundleHint: String = "AgentJobs") throws -> CGRect {
        throw Error.notImplemented
    }

    public static func clickMenuExtra() throws {
        throw Error.notImplemented
    }

    public static func dismissPopover() throws {
        throw Error.notImplemented
    }
}
