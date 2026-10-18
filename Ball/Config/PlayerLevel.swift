import Foundation

// MARK: - Player level (edit these to tune the XP curve and rewards)

/// The player's own level. XP comes from upgrading balls; each new level pays coins and a chest.
nonisolated enum PlayerLevel {
    static let maxLevel = 30

    /// XP needed to go from `level` to the next one, or nil at the top: 25, 55, 85, …
    static func xpToNext(from level: Int) -> Int? {
        level >= maxLevel ? nil : 25 + 30 * (level - 1)
    }

    /// XP for upgrading a ball to `newLevel`: rarer balls and higher levels give more.
    static func upgradeXP(of id: String, toLevel newLevel: Int) -> Int {
        let base = [4, 6, 10, 15][Progression.rarity(of: id).rawValue]
        return base * (newLevel - 1)
    }

    /// What reaching `level` pays: coins growing with level, a Silver chest, Gold every 5th level,
    /// Magic every 10th, and a Legendary chest at the top.
    static func reward(reaching level: Int) -> Progression.Rewards {
        let chest: ChestKind
        if level == maxLevel {
            chest = .legendary
        } else if level.isMultiple(of: 10) {
            chest = .magic
        } else if level.isMultiple(of: 5) {
            chest = .gold
        } else {
            chest = .silver
        }
        return Progression.Rewards(coins: 50 + 25 * level, chests: [chest])
    }

    /// Total XP earned for balls already at `levels` (for saves from before player levels).
    static func xp(forBallLevels levels: [String: Int]) -> Int {
        levels.reduce(0) { total, entry in
            total + (entry.value > 1 ? (2...entry.value).reduce(0) { $0 + upgradeXP(of: entry.key, toLevel: $1) } : 0)
        }
    }
}

/// A level just reached, with what it paid (shown in the level-up celebration).
nonisolated struct LevelUp: Equatable, Identifiable {
    let id = UUID()
    let level: Int
    let rewards: Progression.Rewards
}
