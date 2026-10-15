import Foundation

/// One fighter on a 3-fighter team. Health carries over between rounds.
struct TeamMember: Identifiable, Equatable {
    let id: Int
    let definition: FighterDefinition
    var health: Double

    var isAlive: Bool { health > 0 }
    var healthFraction: Double { max(0, health) / definition.maxHealth }
}

/// Rules for the 3v3 "VS Bot" series.
///
/// Each round is a normal 1v1 battle. The survivor's owner may keep it (with its
/// remaining health) or swap in another living teammate; the side that lost the
/// round must send one of its remaining fighters. A side with no fighters left loses.
struct BotSeries {
    static let teamSize = 3

    enum Outcome: Equatable {
        case playerWins
        case botWins
        case draw
    }

    private(set) var player: [TeamMember]
    private(set) var bot: [TeamMember]
    /// Last round's survivor on each side, which may be kept or swapped out.
    private(set) var playerSurvivor: Int?
    private(set) var botSurvivor: Int?
    private(set) var round = 1
    private(set) var lastRound: BattleOutcome?
    private var rng: SplitMix64

    /// Bot swaps out a survivor below this health fraction if a healthier teammate is available.
    private static let botSwapThreshold = 0.35

    init(playerTeam: [FighterDefinition], seed: UInt64 = UInt64.random(in: .min ... .max)) {
        rng = SplitMix64(seed: seed)
        player = playerTeam.enumerated().map { TeamMember(id: $0.offset, definition: $0.element, health: $0.element.maxHealth) }
        let botTeam = Array(FighterCatalog.all.shuffled(using: &rng).prefix(Self.teamSize))
        bot = botTeam.enumerated().map { TeamMember(id: $0.offset, definition: $0.element, health: $0.element.maxHealth) }
    }

    var outcome: Outcome? {
        let playerLeft = player.contains(where: \.isAlive)
        let botLeft = bot.contains(where: \.isAlive)
        switch (playerLeft, botLeft) {
        case (true, true): return nil
        case (true, false): return .playerWins
        case (false, true): return .botWins
        case (false, false): return .draw
        }
    }

    var playerChoices: [Int] { player.indices.filter { player[$0].isAlive } }

    /// Bot picks its next fighter: keep a healthy survivor, otherwise send someone at random
    /// (or its healthiest teammate if the survivor is badly hurt).
    mutating func botPick() -> Int {
        let alive = bot.indices.filter { bot[$0].isAlive }
        if let survivor = botSurvivor, bot[survivor].isAlive {
            let healthiest = alive.max { bot[$0].health < bot[$1].health } ?? survivor
            let hurt = bot[survivor].healthFraction < Self.botSwapThreshold
            return hurt && bot[healthiest].health > bot[survivor].health + 20 ? healthiest : survivor
        }
        return alive.randomElement(using: &rng) ?? 0
    }

    /// Bot Blasters aim roughly up the arena, toward the player's side.
    mutating func botAimAngle() -> Double {
        -.pi / 2 + Double.random(in: -0.7...0.7, using: &rng)
    }

    /// Stores the result of a finished round.
    mutating func record(_ result: BattleOutcome, playerIndex: Int, botIndex: Int,
                         playerHealth: Double, botHealth: Double) {
        player[playerIndex].health = max(0, playerHealth)
        bot[botIndex].health = max(0, botHealth)
        playerSurvivor = player[playerIndex].isAlive ? playerIndex : nil
        botSurvivor = bot[botIndex].isAlive ? botIndex : nil
        lastRound = result
        round += 1
    }
}
