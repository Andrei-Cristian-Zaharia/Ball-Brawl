import Foundation

/// Arena look. Maps only change how the arena is drawn, never the physics.
nonisolated enum ArenaMap: String, CaseIterable {
    case classic
    case meadow
    case dunes
    case frost
    case volcano
    case royal

    var name: String {
        switch self {
        case .classic: return "Training Camp"
        case .meadow: return "Green Meadow"
        case .dunes: return "Sandy Dunes"
        case .frost: return "Frost Peak"
        case .volcano: return "Lava Volcano"
        case .royal: return "Royal Arena"
        }
    }
}

/// Crusade difficulty. Hard opens for a map once its Normal boss is beaten that day.
nonisolated enum CrusadeDifficulty: String, CaseIterable {
    case normal
    case hard

    var name: String { self == .normal ? "Normal" : "Hard" }
    /// Added to every enemy's level.
    var levelBonus: Int { self == .normal ? 0 : 2 }
    /// Multiplies first-clear coins and chests.
    var rewardMultiplier: Int { self == .normal ? 1 : 2 }
}

/// One crusade level: one or more enemies fought in a row. The player sends a team of up to 3;
/// health carries over between fights on both sides, and the next teammate steps in when one falls.
nonisolated struct CrusadeLevel {
    struct Enemy {
        let id: String
        /// Levels above the player's crusade power (see `Crusade.power`).
        let offset: Int
    }

    let number: Int
    let enemies: [Enemy]
    /// The chapter's final gauntlet; beating it opens the next map.
    let isBoss: Bool

    /// The enemy at `index`, leveled to the player's `power` plus its offset and the difficulty bonus.
    func enemyDefinition(_ index: Int, difficulty: CrusadeDifficulty = .normal, power: Int) -> FighterDefinition? {
        guard enemies.indices.contains(index), let base = FighterCatalog.definition(id: enemies[index].id) else { return nil }
        let level = power + enemies[index].offset + difficulty.levelBonus
        return Progression.leveled(base, level: min(Progression.maxLevel, max(1, level)))
    }
}

nonisolated struct CrusadeChapter {
    let map: ArenaMap
    let levels: [CrusadeLevel]
    /// Multiplies first-clear coins.
    let rewardScale: Int

    var maxStars: Int { levels.count * 3 }
}

// MARK: - Crusade content (edit these to change levels)
// Enemy numbers are levels above the player's crusade power, so the crusade scales with the player.

/// The daily crusade: up to 3 maps of levels, in Normal and Hard. All progress and every
/// ball's rest reset at local midnight.
nonisolated enum Crusade {
    static let maxChapters = 3

    /// The level crusade enemies are built around: halfway between the player's three best balls
    /// (average level) and their player level scaled onto ball levels (player 1 → 1, player 30 → 15).
    static func power(playerLevel: Int, ballLevels: [Int]) -> Int {
        let best = ballLevels.sorted(by: >).prefix(3)
        let balls = best.isEmpty ? 1 : Double(best.reduce(0, +)) / Double(best.count)
        let player = 1 + Double(playerLevel - 1) * Double(Progression.maxLevel - 1) / Double(PlayerLevel.maxLevel - 1)
        return max(1, Int(((balls + player) / 2).rounded()))
    }

    private static func level(_ number: Int, _ enemies: (String, Int)...) -> CrusadeLevel {
        CrusadeLevel(number: number, enemies: enemies.map { CrusadeLevel.Enemy(id: $0.0, offset: $0.1) }, isBoss: false)
    }

    /// The chapter's final level: a long gauntlet that ends with the boss itself.
    private static func boss(_ number: Int, _ enemies: (String, Int)...) -> CrusadeLevel {
        CrusadeLevel(number: number, enemies: enemies.map { CrusadeLevel.Enemy(id: $0.0, offset: $0.1) }, isBoss: true)
    }

    static let chapters: [CrusadeChapter] = [
        CrusadeChapter(map: .meadow, levels: [
            level(1, ("spike", 0)),
            level(2, ("blaster", 0), ("snake", 0)),
            level(3, ("snake", 0), ("pulse", 0)),
            level(4, ("pulse", 1), ("glass", 0)),
            level(5, ("glass", 1), ("dice", 1)),
            level(6, ("dice", 0), ("grappler", 0), ("spike", 0)),
            level(7, ("grappler", 2), ("laser", 1)),
            level(8, ("laser", 0), ("zone", 0), ("blaster", 0)),
            level(9, ("zone", 1), ("shackle", 0), ("bomb", 0)),
            boss(10, ("spike", 0), ("blaster", 0), ("bomb", 1), ("electric", 1)),
        ], rewardScale: 1),
        CrusadeChapter(map: .volcano, levels: [
            level(1, ("hive", 1), ("bomb", 1)),
            level(2, ("bomb", 1), ("conductor", 1)),
            level(3, ("conductor", 1), ("icecone", 1), ("dice", 1)),
            level(4, ("icecone", 2), ("vampire", 2)),
            level(5, ("vampire", 1), ("cannon", 1), ("thief", 1)),
            level(6, ("cannon", 3), ("thief", 3)),
            level(7, ("thief", 2), ("gambit", 2), ("laser", 2)),
            level(8, ("gambit", 2), ("harpoon", 2), ("zone", 2)),
            level(9, ("harpoon", 3), ("virus", 3), ("electric", 3)),
            boss(10, ("dice", 2), ("virus", 2), ("gambit", 3), ("eclipse", 3)),
        ], rewardScale: 2),
    ]

    static let teamSize = 3

    /// Stars for a win: 3 with no teammate lost, 2 with one lost, 1 otherwise.
    static func stars(fallen: Int) -> Int {
        max(1, 3 - fallen)
    }

    /// Paid the first time each day a level is cleared. The boss gives a chest; Hard pays double
    /// and also gives a chest at level 5.
    static func firstClearReward(chapter: Int, level: Int, difficulty: CrusadeDifficulty) -> Progression.Rewards {
        let scale = chapters[chapter].rewardScale * difficulty.rewardMultiplier
        let chest = chapters[chapter].levels[level - 1].isBoss || (difficulty == .hard && level == 5)
        let boss = chapters[chapter].levels[level - 1].isBoss
        let kind: ChestKind = boss ? (difficulty == .hard ? .magic : .gold) : .silver
        return Progression.Rewards(coins: (10 + 5 * level) * scale, chests: chest ? [kind] : [])
    }

    /// Key for saved stars, e.g. "meadow.hard.3".
    static func key(chapter: Int, level: Int, difficulty: CrusadeDifficulty) -> String {
        "\(chapters[chapter].map.rawValue).\(difficulty.rawValue).\(level)"
    }

    /// Today's date (local), which crusade progress belongs to.
    static func dayKey(_ date: Date = .now) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// When today's crusade resets (next local midnight).
    static func nextReset(after date: Date = .now) -> Date {
        Calendar.current.startOfDay(for: date).addingTimeInterval(24 * 60 * 60)
    }
}
