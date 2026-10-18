import Foundation

/// One step on the trophy road: reach `trophies` to unlock the arena and its balls.
nonisolated struct ArenaTier {
    let number: Int
    let name: String
    let map: ArenaMap
    /// Highest trophy count needed to reach this arena.
    let trophies: Int
    /// Balls unlocked by reaching this arena.
    let balls: [String]
    /// Ball levels a player here typically has without buying chests; bots stay inside this range.
    /// From simulating a free player (ranked wins, chests, level-up rewards): the team averages about 5 by
    /// the end of Training Camp, then climbs slowly as card costs grow, to about 8 in the Royal Arena.
    let botLevels: ClosedRange<Int>
}

// MARK: - Trophy road (edit these to rebalance)

nonisolated enum Arenas {
    static let tiers: [ArenaTier] = [
        ArenaTier(number: 1, name: "Training Camp", map: .classic, trophies: 0,
                  balls: ["blaster", "spike", "pulse", "snake", "bomb", "glass", "virus", "electric"], botLevels: 1...5),
        ArenaTier(number: 2, name: "Green Meadow", map: .meadow, trophies: 150,
                  balls: ["grappler", "laser", "dice", "thief", "moss", "icecone"], botLevels: 4...6),
        ArenaTier(number: 3, name: "Sandy Dunes", map: .dunes, trophies: 400,
                  balls: ["zone", "shackle", "cannon", "magma", "harpoon"], botLevels: 5...7),
        ArenaTier(number: 4, name: "Frost Peak", map: .frost, trophies: 800,
                  balls: ["conductor", "wolf", "fibonacci", "cell", "gambit", "vampire"], botLevels: 6...8),
        ArenaTier(number: 5, name: "Lava Volcano", map: .volcano, trophies: 1300,
                  balls: ["hive", "weaver", "wizard", "twin"], botLevels: 7...9),
        ArenaTier(number: 6, name: "Royal Arena", map: .royal, trophies: 2000,
                  balls: ["eclipse", "clockwork", "portal", "glitch"], botLevels: 7...10),
    ]

    /// Trophies won or lost per ranked battle. A loss never drops you below your arena's gate.
    static let onlineWin = 30
    static let onlineLoss = -20

    /// The arena a trophy count puts you in.
    static func tier(forTrophies trophies: Int) -> ArenaTier {
        tiers.last { trophies >= $0.trophies } ?? tiers[0]
    }

    /// The arena that unlocks a ball.
    static func tier(unlocking id: String) -> ArenaTier {
        tiers.first { $0.balls.contains(id) } ?? tiers[0]
    }

    static func next(after tier: ArenaTier) -> ArenaTier? {
        tiers.first { $0.number == tier.number + 1 }
    }

    /// A bot ball's level for a player at `trophies`: inside the arena's usual range, rising as the player
    /// climbs toward the next arena, and never more than one above the player's own best ball
    /// (so a player who skipped upgrades isn't crushed). Buying cards doesn't make bots stronger.
    static func botLevel<R: RandomNumberGenerator>(trophies: Int, playerBest: Int, using rng: inout R) -> Int {
        let tier = tier(forTrophies: trophies)
        let range = tier.botLevels
        let progress: Double
        if let next = next(after: tier) {
            progress = Double(trophies - tier.trophies) / Double(next.trophies - tier.trophies)
        } else {
            progress = Double(trophies - tier.trophies) / 1000
        }
        let center = Double(range.lowerBound) + Double(range.count - 1) * min(1, max(0, progress))
        let rolled = Int((center + Double.random(in: -1...1, using: &rng)).rounded())
        let cap = max(range.lowerBound, playerBest + 1)
        return min(cap, max(range.lowerBound, min(range.upperBound, rolled)))
    }
}
