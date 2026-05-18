import Foundation

/// Test-only helper that loads fixture files from the test bundle's `Fixtures/`
/// resource directory (declared in Package.swift via `.process("Fixtures")`).
enum FixtureLoader {
    enum LoaderError: Error, CustomStringConvertible {
        case notFound(name: String)
        var description: String {
            switch self {
            case .notFound(let name): return "Fixture not found: \(name)"
            }
        }
    }

    /// Loads raw bytes for the named fixture. The name should include the file extension.
    static func data(named name: String) throws -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: nil) else {
            // Fallback: try splitting on the last dot in case Bundle wants base+extension.
            let parts = name.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
            if parts.count == 2,
               let url = Bundle.module.url(forResource: String(parts[0]), withExtension: String(parts[1])) {
                return try Data(contentsOf: url)
            }
            throw LoaderError.notFound(name: name)
        }
        return try Data(contentsOf: url)
    }

    static func string(named name: String) throws -> String {
        String(decoding: try data(named: name), as: UTF8.self)
    }

    static func decoded<T: Decodable>(_ type: T.Type, from name: String) throws -> T {
        try JSONDecoder().decode(type, from: try data(named: name))
    }
}
