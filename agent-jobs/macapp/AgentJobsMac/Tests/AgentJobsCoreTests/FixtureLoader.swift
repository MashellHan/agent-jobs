import Foundation

/// Shared loader for test fixture files copied into the test bundle via
/// `Package.swift` `resources: [.copy("Fixtures")]`. Centralized so each
/// test suite reads files the same way.
enum FixtureLoader {

    enum Error: Swift.Error, CustomStringConvertible {
        case missing(name: String)
        case decode(name: String)

        var description: String {
            switch self {
            case .missing(let n): return "fixture not found in bundle: \(n)"
            case .decode(let n):  return "fixture not utf8-decodable: \(n)"
            }
        }
    }

    /// Returns the full URL of `Fixtures/<name>.<ext>` inside the test bundle.
    static func url(_ name: String, ext: String) throws -> URL {
        guard let url = Bundle.module.url(
            forResource: name, withExtension: ext, subdirectory: "Fixtures"
        ) ?? Bundle.module.url(
            forResource: name, withExtension: ext
        ) else {
            throw Error.missing(name: "\(name).\(ext)")
        }
        return url
    }

    /// Reads the fixture as raw bytes.
    static func data(_ name: String, ext: String) throws -> Data {
        try Data(contentsOf: try url(name, ext: ext))
    }

    /// Reads the fixture as a UTF-8 string.
    static func text(_ name: String, ext: String) throws -> String {
        let data = try data(name, ext: ext)
        guard let s = String(data: data, encoding: .utf8) else {
            throw Error.decode(name: "\(name).\(ext)")
        }
        return s
    }
}
