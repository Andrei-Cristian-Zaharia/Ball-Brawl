import Foundation

// MARK: - Daily rewards (edit these to tune them)

/// Reasons to come back each day: a 7-day login streak, three daily quests (plus a bonus for all three),
/// and a free chest every few hours. Days follow the Crusade's local-midnight reset.
nonisolated enum Daily {
    /// What each day of the login streak pays; after day 7 it starts over at day 1.
    static let loginRewards: [Progression.Rewards] = [
        Progression.Rewards(coins: 60),
        Progression.Rewards(chests: [.wooden]),
        Progression.Rewards(coins: 120),
        Progression.Rewards(chests: [.silver]),
        Progression.Rewards(coins: 200),
        Progression.Rewards(chests: [.gold]),
        Progression.Rewards(coins: 150, chests: [.magic]),
    ]

    /// A free chest waits this long after the last one was claimed.
    static let freeChestInterval: TimeInterval = 4 * 60 * 60
    static let freeChest = ChestKind.wooden

    static let questsPerDay = 3
    /// Claiming all of the day's quests pays this on top.
    static let questBonus = Progression.Rewards(chests: [.silver])

    /// Every quest that can come up; each day picks `questsPerDay` different ones.
    static let questPool: [DailyQuest] = [
        DailyQuest(kind: .playBattles, target: 3, reward: Progression.Rewards(coins: 80)),
        DailyQuest(kind: .winRanked, target: 2, reward: Progression.Rewards(coins: 120)),
        DailyQuest(kind: .winBotSeries, target: 1, reward: Progression.Rewards(coins: 80)),
        DailyQuest(kind: .clearCrusade, target: 2, reward: Progression.Rewards(coins: 100)),
        DailyQuest(kind: .upgradeBalls, target: 2, reward: Progression.Rewards(coins: 100)),
        DailyQuest(kind: .openChests, target: 3, reward: Progression.Rewards(coins: 60)),
    ]

    /// The day's quests: the same for everyone on that date, and stable all day.
    static func quests(for day: String) -> [DailyQuest] {
        var rng = SplitMix64(seed: day.utf8.reduce(0xcbf2_9ce4_8422_2325) { ($0 ^ UInt64($1)) &* 0x100_0000_01b3 })
        return Array(questPool.shuffled(using: &rng).prefix(questsPerDay))
    }

    /// The day before `day` (both as `Crusade.dayKey` strings).
    static func dayBefore(_ day: String) -> String? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: day),
              let previous = Calendar.current.date(byAdding: .day, value: -1, to: date) else { return nil }
        return Crusade.dayKey(previous)
    }
}

nonisolated struct DailyQuest: Equatable {
    enum Kind: String, CaseIterable {
        case playBattles, winRanked, winBotSeries, clearCrusade, upgradeBalls, openChests
    }

    let kind: Kind
    let target: Int
    let reward: Progression.Rewards

    var title: String {
        switch kind {
        case .playBattles: return String(localized: "Play \(target) battles")
        case .winRanked: return String(localized: "Win \(target) ranked battles")
        case .winBotSeries: return target == 1 ? String(localized: "Win a VS Bot series") : String(localized: "Win \(target) VS Bot series")
        case .clearCrusade: return String(localized: "Clear \(target) Crusade levels")
        case .upgradeBalls: return String(localized: "Upgrade \(target) balls")
        case .openChests: return String(localized: "Open \(target) chests")
        }
    }

    var icon: String {
        switch kind {
        case .playBattles: return "figure.boxing"
        case .winRanked: return "trophy.fill"
        case .winBotSeries: return "cpu"
        case .clearCrusade: return "flag.fill"
        case .upgradeBalls: return "arrow.up.circle.fill"
        case .openChests: return "shippingbox.fill"
        }
    }
}
