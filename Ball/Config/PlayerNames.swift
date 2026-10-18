import Foundation

/// Random gamer-style usernames, for players without a Game Center name and for stand-in opponents.
nonisolated enum PlayerNames {
    private static let adjectives = [
        "Shadow", "Turbo", "Lucky", "Mega", "Silent", "Crazy", "Golden", "Iron", "Frosty", "Sneaky",
        "Pixel", "Rocket", "Cosmic", "Spicy", "Wild", "Swift", "Royal", "Mighty", "Fuzzy", "Electric",
        "Stormy", "Bouncy", "Hyper", "Blazing", "Sly",
    ]
    private static let nouns = [
        "Ball", "Brawler", "Bouncer", "Fox", "Tiger", "Wolf", "Knight", "King", "Comet", "Storm",
        "Panda", "Bomber", "Ninja", "Falcon", "Dragon", "Rider", "Shark", "Viper", "Goose", "Taco",
        "Pebble", "Rocket", "Ace", "Blaze", "Otter",
    ]

    /// e.g. "ShadowComet42", "lucky_panda", "xXViperXx", "TurboAce", "falcon2011".
    static func random<R: RandomNumberGenerator>(using rng: inout R) -> String {
        let adjective = adjectives.randomElement(using: &rng)!
        let noun = nouns.randomElement(using: &rng)!
        switch Int.random(in: 0..<6, using: &rng) {
        case 0: return "\(adjective)\(noun)\(Int.random(in: 1...99, using: &rng))"
        case 1: return "\(adjective.lowercased())_\(noun.lowercased())"
        case 2: return "xX\(noun)Xx"
        case 3: return "\(noun.lowercased())\(Int.random(in: 1995...2015, using: &rng))"
        case 4: return "\(adjective)\(noun)"
        default: return "The\(adjective)\(noun)"
        }
    }

    static let nameLength = 3...16

    /// A name as players may choose it: trimmed, 3–16 letters, numbers, spaces, `_`, `-` or `.`; nil if not allowed.
    static func sanitized(_ raw: String) -> String? {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " _-."))
        guard nameLength.contains(name.count), name.unicodeScalars.allSatisfy(allowed.contains) else { return nil }
        return name
    }

    static func random() -> String {
        var rng = SystemRandomNumberGenerator()
        return random(using: &rng)
    }
}
