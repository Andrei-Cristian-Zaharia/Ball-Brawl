import Foundation

// MARK: - Chest types (edit these to tune drops)

/// Chest types, worst to best. Better chests hold more coins, more and bigger card stacks,
/// and guarantee higher rarities.
nonisolated enum ChestKind: String, CaseIterable, Codable, Comparable {
    case wooden, silver, gold, magic, legendary

    static func < (a: ChestKind, b: ChestKind) -> Bool {
        allCases.firstIndex(of: a)! < allCases.firstIndex(of: b)!
    }

    var name: String {
        switch self {
        case .wooden: return "Wooden Chest"
        case .silver: return "Silver Chest"
        case .gold: return "Gold Chest"
        case .magic: return "Magic Chest"
        case .legendary: return "Legendary Chest"
        }
    }

    var coins: ClosedRange<Int> {
        switch self {
        case .wooden: return 30...60
        case .silver: return 60...120
        case .gold: return 150...260
        case .magic: return 320...480
        case .legendary: return 500...800
        }
    }

    /// Number of different balls inside.
    var stacks: Int {
        switch self {
        case .wooden: return 3
        case .silver: return 4
        case .gold: return 5
        case .magic, .legendary: return 6
        }
    }

    /// Multiplies each stack's card count.
    var cardMultiplier: Double {
        switch self {
        case .wooden: return 1
        case .silver: return 1.5
        case .gold: return 2
        case .magic: return 3
        case .legendary: return 3
        }
    }

    /// Stacks guaranteed to be at least a rarity (when the player has balls of it unlocked).
    var guaranteed: [Rarity] {
        switch self {
        case .wooden: return []
        case .silver: return [.rare]
        case .gold: return [.epic, .rare]
        case .magic: return [.epic, .epic, .rare]
        case .legendary: return [.legendary, .epic, .rare]
        }
    }
}

extension Progression {
    /// Chance that a stack goes to a ball the player hasn't found yet (when one of that rarity can drop).
    static let undiscoveredChance = 0.3

    /// Opens a chest. Cards only come from `unlocked` balls (the ones the player's arenas have opened);
    /// `undiscovered` ones (not found yet) get a boost so new arenas' balls turn up.
    static func openChest<R: RandomNumberGenerator>(_ kind: ChestKind, unlocked: Set<String>,
                                                    undiscovered: Set<String> = [],
                                                    using rng: inout R) -> ChestContents {
        let byRarity = Dictionary(grouping: FighterCatalog.all.filter { unlocked.contains($0.id) }) { rarity(of: $0.id) }
        let available = Rarity.allCases.filter { byRarity[$0] != nil }
        guard !available.isEmpty else { return ChestContents(coins: Int.random(in: kind.coins, using: &rng), cards: []) }

        // Guaranteed rarities first (falling back to the best the player has), then random weighted picks.
        var rarities = kind.guaranteed.map { wanted in available.last { $0 <= wanted } ?? available[0] }
        let totalWeight = available.reduce(0) { $0 + $1.dropWeight }
        while rarities.count < kind.stacks {
            var roll = Double.random(in: 0..<totalWeight, using: &rng)
            rarities.append(available.first { roll -= $0.dropWeight; return roll < 0 } ?? available[0])
        }

        var stacks: [String: Int] = [:]
        for rarity in rarities {
            // Prefer a ball not already in the chest, so bigger chests show more variety.
            let pool = byRarity[rarity] ?? []
            let fresh = pool.filter { stacks[$0.id] == nil }
            let new = fresh.filter { undiscovered.contains($0.id) }
            let choices = !new.isEmpty && Double.random(in: 0..<1, using: &rng) < undiscoveredChance ? new
                : fresh.isEmpty ? pool : fresh
            guard let pick = choices.randomElement(using: &rng) else { continue }
            let count = Double(Int.random(in: rarity.stackSize, using: &rng)) * kind.cardMultiplier
            stacks[pick.id, default: 0] += max(1, Int(count.rounded()))
        }
        let cards = stacks.map { (id: $0.key, count: $0.value) }
            .sorted { (rarity(of: $0.id), $0.count) > (rarity(of: $1.id), $1.count) }
        return ChestContents(coins: Int.random(in: kind.coins, using: &rng), cards: cards)
    }
}

/// Chests being opened on screen: the type shown (the best one, for Open All), how many, and what came out.
nonisolated struct ChestOpening: Equatable, Identifiable {
    let id = UUID()
    let kind: ChestKind
    let contents: Progression.ChestContents
    var count = 1
    /// Balls found for the first time (now unlocked).
    var newBalls: Set<String> = []
}
