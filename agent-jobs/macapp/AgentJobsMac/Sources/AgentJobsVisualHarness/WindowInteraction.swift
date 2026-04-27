import Foundation
import AppKit

/// Locates the Agent Jobs main window and drives resize / scroll / click.
/// Real implementation lands in M05 T06.
public enum WindowInteraction {

    public enum Error: Swift.Error, CustomStringConvertible {
        case notFound
        case notImplemented
        public var description: String {
            switch self {
            case .notFound:        return "Main window not found"
            case .notImplemented:  return "WindowInteraction T06 pending"
            }
        }
    }

    @MainActor
    public static func locateMainWindow() throws -> NSWindow? {
        NSApp?.windows.first { $0.title == "Agent Jobs" || $0.identifier?.rawValue == "dashboard" }
    }

    @MainActor
    public static func resizeMainWindow(to size: CGSize) throws {
        throw Error.notImplemented
    }

    @MainActor
    public static func scrollList(by lines: Int) {
        // TODO(T06): synthesize scroll-wheel event via CGEvent.
    }

    @MainActor
    public static func clickRow(at index: Int) {
        // TODO(T06): post mouse-down/up at the row's screen rect.
    }
}
