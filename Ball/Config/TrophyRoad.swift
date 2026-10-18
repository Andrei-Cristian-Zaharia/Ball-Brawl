import Foundation

// MARK: - Trophy road rewards (edit these to tune them)

/// Rewards along the trophy road, between the arena gates: reach the trophies (best ever) once and the
/// reward can be claimed on the Trophy Road screen. Ranked wins themselves only pay coins.
nonisolated struct TrophyReward: Identifiable {
    enum Kind {
        case coins(Int)
        case chest(ChestKind)
        /// Cards for a random ball the player has found, of this rarity or the best below it they have.
        case cards(Rarity, Int)
    }

    let trophies: Int
    let kind: Kind

    var id: Int { trophies }
}

nonisolated enum TrophyRoad {
    static let rewards: [TrophyReward] = [
        // Training Camp (0–150)
        TrophyReward(trophies: 30, kind: .coins(100)),
        TrophyReward(trophies: 60, kind: .chest(.wooden)),
        TrophyReward(trophies: 90, kind: .cards(.common, 15)),
        TrophyReward(trophies: 120, kind: .chest(.silver)),
        // Green Meadow (150–400)
        TrophyReward(trophies: 200, kind: .coins(200)),
        TrophyReward(trophies: 250, kind: .cards(.rare, 8)),
        TrophyReward(trophies: 300, kind: .chest(.silver)),
        TrophyReward(trophies: 350, kind: .chest(.gold)),
        // Sandy Dunes (400–800)
        TrophyReward(trophies: 470, kind: .coins(350)),
        TrophyReward(trophies: 540, kind: .cards(.common, 40)),
        TrophyReward(trophies: 610, kind: .chest(.gold)),
        TrophyReward(trophies: 680, kind: .cards(.epic, 4)),
        TrophyReward(trophies: 750, kind: .chest(.magic)),
        // Frost Peak (800–1300)
        TrophyReward(trophies: 880, kind: .coins(600)),
        TrophyReward(trophies: 960, kind: .cards(.rare, 25)),
        TrophyReward(trophies: 1040, kind: .chest(.gold)),
        TrophyReward(trophies: 1120, kind: .cards(.epic, 8)),
        TrophyReward(trophies: 1200, kind: .chest(.magic)),
        // Lava Volcano (1300–2000)
        TrophyReward(trophies: 1400, kind: .coins(1000)),
        TrophyReward(trophies: 1500, kind: .cards(.common, 120)),
        TrophyReward(trophies: 1600, kind: .chest(.magic)),
        TrophyReward(trophies: 1700, kind: .cards(.legendary, 2)),
        TrophyReward(trophies: 1800, kind: .chest(.gold)),
        TrophyReward(trophies: 1900, kind: .chest(.legendary)),
        // Royal Arena (2000+)
        TrophyReward(trophies: 2100, kind: .coins(1500)),
        TrophyReward(trophies: 2200, kind: .cards(.rare, 60)),
        TrophyReward(trophies: 2300, kind: .chest(.magic)),
        TrophyReward(trophies: 2400, kind: .cards(.epic, 15)),
        TrophyReward(trophies: 2500, kind: .chest(.legendary)),
        TrophyReward(trophies: 2600, kind: .coins(2500)),
        TrophyReward(trophies: 2700, kind: .cards(.legendary, 4)),
        TrophyReward(trophies: 2800, kind: .chest(.magic)),
        TrophyReward(trophies: 2900, kind: .cards(.epic, 25)),
        TrophyReward(trophies: 3000, kind: .chest(.legendary)),
    ]

    /// The rewards inside an arena's stretch of the road (from its gate up to the next arena's).
    static func rewards(in tier: ArenaTier) -> [TrophyReward] {
        let end = Arenas.next(after: tier)?.trophies ?? .max
        return rewards.filter { $0.trophies >= tier.trophies && $0.trophies < end }
    }
}
