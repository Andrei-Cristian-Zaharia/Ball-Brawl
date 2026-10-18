import Foundation

/// The fights the Collection's ability previews loop: the ball (at a stage's level) against a same-level enemy
/// that starts hurt, chosen so the ball wins inside the clip. The good choice for every ball and stage is worked
/// out ahead of time (`PreviewFight.table`, generated); `search` is the slow fallback when one is missing.
enum PreviewFight {
    /// Which fight to loop: an attempt number (picks the seed) and how much health the enemy starts with.
    struct Choice: Equatable {
        var attempt: Int
        var enemyHealth: Double
    }

    enum Result { case goodWin, win, other }

    static let seedsPerStep = 4
    /// A win sooner than this is over before the ball shows much.
    static let shortestWin = 3.0
    /// When an Ultimate clip fills the meter.
    static let ultimateAt = 1.2

    static func isUltimate(level: Int) -> Bool { level == Progression.starLevels.last }

    /// Enemy starting health to try, most first: enough for the ball to show its moves, low enough that it wins
    /// inside the clip. Ultimate clips keep the enemy tougher so it lasts past the Ultimate.
    static func healthSteps(level: Int) -> [Double] { isUltimate(level: level) ? [0.7, 0.5, 0.3] : [0.35, 0.2, 0.12] }

    /// Every fight the search tries, in order.
    static func candidates(level: Int) -> [Choice] {
        healthSteps(level: level).enumerated().flatMap { step, health in
            (0..<seedsPerStep).map { Choice(attempt: step * seedsPerStep + $0, enemyHealth: health) }
        }
    }

    /// The longest fight tried (Eclipse's totality takes a while, so it gets more).
    static func longestFight(ballID: String) -> Double {
        if case .eclipse(let spec) = FighterCatalog.definition(id: ballID)!.attack { return spec.chargeTime + spec.maxStall + 3 }
        return 12
    }

    static func key(ballID: String, level: Int) -> String { "\(ballID).\(level)" }

    /// A fixed seed per clip and attempt (FNV-1a), so every loop plays out the same.
    static func seed(ballID: String, level: Int, attempt: Int) -> UInt64 {
        "\(key(ballID: ballID, level: level)).\(attempt)".utf8.reduce(0xcbf2_9ce4_8422_2325) { ($0 ^ UInt64($1)) &* 0x100_0000_01b3 }
    }

    static func makeSimulation(ballID: String, level: Int, choice: Choice, label: String) -> BattleSimulation {
        let base = FighterCatalog.definition(id: ballID)!
        let me = Progression.leveled(base, level: level)
        let enemyID = ballID == "spike" ? "blaster" : "spike"
        let enemy = Progression.leveled(FighterCatalog.definition(id: enemyID)!, level: level)
        let setup = MatchSetup(loadouts: [FighterLoadout(definition: me, aimAngle: .pi / 2),
                                          FighterLoadout(definition: enemy, aimAngle: -.pi / 2,
                                                         startingHealth: enemy.maxHealth * choice.enemyHealth)],
                               labels: [label, "ENEMY"], steerableSlots: [], map: .classic)
        let simulation = BattleSimulation(setup: setup, seed: seed(ballID: ballID, level: level, attempt: choice.attempt))
        simulation.isPreview = true
        // Skip the countdown: start the clip right at the launch.
        while case .countdown = simulation.phase { simulation.step(dt: GameConfig.fixedTimeStep) }
        _ = simulation.drainEvents()
        return simulation
    }

    /// One fixed step; Ultimate clips fill the meter shortly after the launch.
    static func step(_ simulation: BattleSimulation, level: Int, charged: inout Bool) {
        simulation.step(dt: GameConfig.fixedTimeStep)
        if isUltimate(level: level), !charged, simulation.battleTime >= ultimateAt {
            charged = true
            simulation.chargeUltimate(.one)
        }
    }

    /// Plays a fight to the end: a good win (the ball wins, not too fast, after its Ultimate on Ultimate clips),
    /// a plain win, or neither.
    static func play(ballID: String, level: Int, choice: Choice) -> Result {
        let fight = makeSimulation(ballID: ballID, level: level, choice: choice, label: "")
        var charged = false
        var ultimateAt: Double?
        let limit = longestFight(ballID: ballID)
        while fight.battleTime < limit {
            step(fight, level: level, charged: &charged)
            for event in fight.drainEvents() {
                if case .ability(.one, _, _, true) = event, ultimateAt == nil { ultimateAt = fight.battleTime }
            }
            if case .finished(let outcome) = fight.phase {
                guard outcome == .winner(.one) else { return .other }
                let showedUltimate = !isUltimate(level: level) || ultimateAt.map { fight.battleTime >= $0 + 0.5 } == true
                return fight.battleTime >= shortestWin && showedUltimate ? .goodWin : .win
            }
        }
        return .other
    }

    /// The first good win among the candidates (else any win, else the last one). Slow: plays whole fights.
    static func search(ballID: String, level: Int) -> Choice {
        var anyWin: Choice?
        let all = candidates(level: level)
        for choice in all {
            switch play(ballID: ballID, level: level, choice: choice) {
            case .goodWin: return choice
            case .win: if anyWin == nil { anyWin = choice }
            case .other: break
            }
        }
        return anyWin ?? all.last!
    }
}
