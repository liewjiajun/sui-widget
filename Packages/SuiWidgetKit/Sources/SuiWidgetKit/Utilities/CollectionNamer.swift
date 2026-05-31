import Foundation

/// Derives a human-readable NFT collection name.
///
/// The bug this fixes: `NFTService` previously stored the raw on-chain struct
/// type (`0x<64-hex-package>::module::Struct`) as the collection name, so the
/// gallery grouped NFTs under unreadable package IDs. Real NFTs only sometimes
/// carry a `collection` Display field; when they don't, the *type* is the only
/// hint we have — so we extract the struct name from it and humanise it
/// (`PrimeMachin` → "Prime Machin", `suins_registration` → "Suins Registration")
/// instead of showing the whole `0x…::module::Struct`.
public enum CollectionNamer {

    /// Best collection name for an NFT, in priority order:
    /// 1. The Display `collection` field (authoritative when present).
    /// 2. A humanised form of the on-chain type's struct name.
    /// 3. "Uncategorized" when there's nothing usable.
    public static func collectionName(displayCollection: String?, type: String?) -> String {
        if let display = displayCollection?.trimmingCharacters(in: .whitespacesAndNewlines),
           !display.isEmpty {
            return display
        }
        if let type, let humanised = humanisedStructName(from: type) {
            return humanised
        }
        return "Uncategorized"
    }

    /// Extracts and humanises the struct name from a fully-qualified Sui type.
    /// `0xabc::suins_registration::SuinsRegistration` → "Suins Registration".
    /// Strips a leading `0x2::coin::Coin<…>` wrapper's inner type if present.
    /// Returns nil when no struct segment can be found.
    static func humanisedStructName(from type: String) -> String? {
        // Unwrap a generic like `Coin<0x…::module::INNER>` to the inner type so
        // we name by the meaningful asset, not "Coin".
        let unwrapped: String
        if let open = type.firstIndex(of: "<"),
           let close = type.lastIndex(of: ">"),
           open < close {
            unwrapped = String(type[type.index(after: open)..<close])
        } else {
            unwrapped = type
        }

        // The struct name is the segment after the last "::".
        guard let structName = unwrapped.split(separator: ":").last.map(String.init),
              !structName.isEmpty else {
            return nil
        }

        let humanised = humanise(structName)
        return humanised.isEmpty ? nil : humanised
    }

    /// Turns an identifier into spaced Title Case:
    /// - `snake_case` → words on underscores
    /// - `camelCase` / `PascalCase` → split on case boundaries
    /// - ALLCAPS tokens (e.g. `SUI`, `USDC`) are kept as-is
    static func humanise(_ identifier: String) -> String {
        // First split on underscores / hyphens.
        let underscoreParts = identifier
            .split(whereSeparator: { $0 == "_" || $0 == "-" })
            .map(String.init)

        var words: [String] = []
        for part in underscoreParts {
            if part.uppercased() == part {
                // ALLCAPS acronym — keep verbatim (SUI, USDC, NFT).
                words.append(part)
            } else {
                words.append(contentsOf: splitCamelCase(part))
            }
        }

        return words
            .map { word -> String in
                // Preserve all-caps acronyms; Title-case the rest.
                if word.uppercased() == word { return word }
                return word.prefix(1).uppercased() + word.dropFirst()
            }
            .joined(separator: " ")
    }

    /// Splits `camelCase`/`PascalCase` into words at lower→upper boundaries,
    /// keeping consecutive capitals together (`NFTGallery` → ["NFT","Gallery"]).
    private static func splitCamelCase(_ s: String) -> [String] {
        var words: [String] = []
        var current = ""
        let chars = Array(s)
        for (i, ch) in chars.enumerated() {
            if ch.isUppercase, !current.isEmpty {
                let prev = chars[i - 1]
                let next: Character? = i + 1 < chars.count ? chars[i + 1] : nil
                // Boundary when previous was lowercase (aB), or this starts a new
                // word after an acronym run (ABc → "AB","c").
                if prev.isLowercase || (next?.isLowercase ?? false) {
                    words.append(current)
                    current = ""
                }
            }
            current.append(ch)
        }
        if !current.isEmpty { words.append(current) }
        return words
    }
}
