import SwiftUI

nonisolated struct PlayerSetup: Equatable {
    let slot: PlayerSlot
    var fighterID: String?
    var aimAngle: Double
    var isReady = false

    init(slot: PlayerSlot) {
        self.slot = slot
        // Default aim: toward the opponent's half (P1 spawns at the top, P2 at the bottom).
        self.aimAngle = slot == .one ? .pi / 2 : -.pi / 2
    }

    var fighter: FighterDefinition? { fighterID.flatMap(FighterCatalog.definition(id:)) }
}

@Observable
final class AppModel {
    enum Screen { case menu, setup, teamSelect, roundPrep, battle }
    enum Mode { case local, bot }

    private(set) var screen: Screen = .menu
    private(set) var mode: Mode = .local
    var players: [PlayerSetup] = PlayerSlot.allCases.map(PlayerSetup.init(slot:))
    /// Replaced on every start / rematch / restart; the old engine (and its loop) is discarded.
    private(set) var battle: BattleEngine?

    /// Bot mode state.
    private(set) var series: BotSeries?
    private var roundPicks: (player: Int, bot: Int)?
    private var recordedBattle: ObjectIdentifier?

    var canStart: Bool { players.allSatisfy { $0.isReady && $0.fighter != nil } }

    // MARK: Navigation

    func showMenu() {
        battle = nil
        series = nil
        screen = .menu
    }

    func openLocalSetup() {
        mode = .local
        for i in players.indices { players[i].isReady = false }
        screen = .setup
    }

    func openBotTeamSelect() {
        mode = .bot
        battle = nil
        series = nil
        screen = .teamSelect
    }

    // MARK: Local 2-player

    func select(_ fighterID: String, for slot: PlayerSlot) {
        players[slot.rawValue].fighterID = fighterID
        players[slot.rawValue].isReady = false
    }

    func setAim(_ angle: Double, for slot: PlayerSlot) {
        players[slot.rawValue].aimAngle = angle
    }

    func setReady(_ ready: Bool, for slot: PlayerSlot) {
        guard players[slot.rawValue].fighter != nil else { return }
        players[slot.rawValue].isReady = ready
    }

    func startBattle() {
        guard canStart else { return }
        let setup = MatchSetup(loadouts: players.map {
            FighterLoadout(definition: $0.fighter!, aimAngle: $0.aimAngle)
        })
        battle = BattleEngine(setup: setup)
        screen = .battle
    }

    /// Same fighters, aim and starting health; new random launch angles.
    func rematch() {
        guard let setup = battle?.setup else { return }
        battle = BattleEngine(setup: setup)
    }

    func changeFighters() {
        battle = nil
        for i in players.indices { players[i].isReady = false }
        screen = .setup
    }

    // MARK: VS Bot

    func confirmTeam(_ team: [FighterDefinition]) {
        guard team.count == BotSeries.teamSize else { return }
        series = BotSeries(playerTeam: team)
        screen = .roundPrep
    }

    func startBotRound(playerIndex: Int, aimAngle: Double) {
        guard var series, series.player[playerIndex].isAlive else { return }
        let botIndex = series.botPick()
        let you = series.player[playerIndex]
        let them = series.bot[botIndex]
        let setup = MatchSetup(
            loadouts: [
                FighterLoadout(definition: you.definition, aimAngle: aimAngle, startingHealth: you.health),
                FighterLoadout(definition: them.definition, aimAngle: series.botAimAngle(), startingHealth: them.health),
            ],
            labels: ["YOU", "BOT"]
        )
        self.series = series
        roundPicks = (playerIndex, botIndex)
        battle = BattleEngine(setup: setup)
        screen = .battle
    }

    /// Called once when a bot-mode battle shows its result.
    func recordBotRound(from engine: BattleEngine) {
        guard mode == .bot, var series, let picks = roundPicks, let outcome = engine.outcome,
              recordedBattle != ObjectIdentifier(engine) else { return }
        recordedBattle = ObjectIdentifier(engine)
        let state = engine.simulation.state
        series.record(outcome, playerIndex: picks.player, botIndex: picks.bot,
                      playerHealth: state.fighter(.one).health, botHealth: state.fighter(.two).health)
        self.series = series
    }

    func nextBotRound() {
        battle = nil
        roundPicks = nil
        screen = .roundPrep
    }
}
