import Network
import SwiftUI

nonisolated struct PlayerSetup: Equatable {
    let slot: PlayerSlot
    var fighterID: String?
    var aimAngle: Double
    var isReady = false
    /// The opponent's ball level in an online match (local slots use this device's profile).
    var level = 1
    /// The opponent's trophies in an online match (picks the arena).
    var trophies = 0

    init(slot: PlayerSlot) {
        self.slot = slot
        // Default aim: toward the opponent's half (P1 spawns at the top, P2 at the bottom).
        self.aimAngle = slot == .one ? .pi / 2 : -.pi / 2
    }

    var fighter: FighterDefinition? { fighterID.flatMap(FighterCatalog.definition(id:)) }
}

@Observable
final class AppModel {
    enum Screen { case menu, setup, teamSelect, roundPrep, battle, onlineLobby, collection, crusade, crusadePrep, arenas, shop, settings, daily }
    enum Mode {
        case local, bot, online, crusade
        /// Matchmaking found no one, so a bot stands in as an online opponent.
        case standIn
    }

    /// The bot standing in for an online opponent: a player-like name, a ball and a level.
    struct StandInOpponent: Equatable {
        let id = UUID()
        let name: String
        let ranked: Bool
        let fighterID: String
        let level: Int
    }

    /// A crusade level in progress: the player's team of up to 3 against the level's enemies.
    /// Health carries over on both sides; when a fight ends the player picks who goes next.
    struct CrusadeRun: Equatable {
        enum Result: Equatable {
            /// A fight ended but the level goes on (`enemyDown`: the player won that fight).
            case continuing(enemyDown: Bool)
            case cleared(stars: Int)
            case lost
        }

        let chapter: Int
        let level: Int
        let difficulty: CrusadeDifficulty
        let aimAngle: Double
        /// Fixed when the level starts, so upgrades mid-level don't change the enemies.
        let power: Int
        var team: [TeamMember]
        /// Team member in (or next into) the arena.
        var active = 0
        var enemyIndex = 0
        /// The current enemy's health if it survived the last fight (nil = full).
        var enemyHealth: Double?
        var result: Result?

        var levelInfo: CrusadeLevel { Crusade.chapters[chapter].levels[level - 1] }
        var fallen: Int { team.filter { !$0.isAlive }.count }

        func enemy(_ index: Int) -> FighterDefinition? { levelInfo.enemyDefinition(index, difficulty: difficulty, power: power) }
    }

    private(set) var screen: Screen = .menu
    private(set) var mode: Mode = .local
    var players: [PlayerSetup] = PlayerSlot.allCases.map(PlayerSetup.init(slot:))
    /// Replaced on every start / rematch / restart; the old engine (and its loop) is discarded.
    private(set) var battle: BattleEngine? {
        didSet { lastRewards = nil }
    }

    /// Bot mode state.
    private(set) var series: BotSeries?
    private var roundPicks: (player: Int, bot: Int)?
    private var recordedBattle: ObjectIdentifier?

    /// Shown on the Collection when the player needs to finish their battle team first.
    var collectionNotice: String?

    /// Ranked online series: each side's pick for the next round (team index, aim).
    private var myPick: (index: Int, aim: Double)?
    private var remotePick: (index: Int, aim: Double)?
    /// Ranked online: waiting for the opponent to choose their next fighter.
    var isWaitingForOpponentPick: Bool { isVersusMatch && myPick != nil && battle == nil }

    /// Versus series (ranked online or stand-in): the pick timer and automatic advance between rounds.
    var isVersusSeries: Bool { isVersusMatch && series != nil }
    static let pickDuration: TimeInterval = 10
    /// How long a round's result shows before both players move on to the next pick.
    static let roundResultDuration: TimeInterval = 2.5
    /// When the current pick runs out (versus series only).
    private(set) var pickDeadline: Date?

    /// Opens round prep; in a versus series the pick clock starts.
    private func enterRoundPrep() {
        battle = nil
        roundPicks = nil
        pickDeadline = isVersusSeries ? .now.addingTimeInterval(Self.pickDuration) : nil
        screen = .roundPrep
    }

    /// Saved coins, chests, cards and ball levels.
    let profile = ProfileStore()
    /// Coins and chests earned by the last finished battle, for the results screen.
    private(set) var lastRewards: Progression.Rewards?
    /// A chest that was just opened, shown until dismissed.
    var openedChest: ChestOpening?
    /// An arena reached for the first time, celebrated until dismissed.
    var newArena: ArenaTier?

    /// Voucher codes for free coins and chests.
    let vouchers = VoucherService()

    /// Redeems a voucher code; pays it and shows what it gave.
    func redeemVoucher(_ code: String) async -> VoucherService.Outcome {
        let outcome = await vouchers.redeem(code, profile: profile)
        if case .redeemed(let rewards) = outcome { announce(rewards) }
        return outcome
    }

    /// Sound and vibration preferences.
    let settings = GameSettings.shared

    /// In-app purchases and rewarded ads.
    let store: StoreService
    let ads = AdService()
    /// A short "you got…" banner after a purchase or an ad reward.
    var shopToast: String?

    /// Online play over Game Center.
    let online = OnlineSession()
    /// Why the last online match ended early, shown in the lobby.
    private(set) var onlineNotice: String?

    var canStart: Bool { players.allSatisfy { $0.isReady && $0.fighter != nil } }

    /// Slots that people on this device control (setup panels and launch aiming).
    var controlledSlots: Set<PlayerSlot> {
        switch mode {
        case .local: return Set(PlayerSlot.allCases)
        case .bot, .crusade, .standIn: return [.one]
        case .online: return [online.localSlot]
        }
    }

    init() {
        store = StoreService(profile: profile)
        store.onDelivered = { [weak self] offer in self?.showToast(String(localized: "\(offer.title.localized) delivered!")) }
        online.onEvent = { [weak self] event in self?.handleOnline(event) }
        #if DEBUG
        if !StoreDemo.isActive { ads.start() }
        #else
        ads.start()
        #endif
        online.localName = { [weak self] in self?.playerDisplayName ?? "" }
        #if DEBUG
        if StoreDemo.isActive {
            startStoreDemo()
            return
        }
        #endif
        // A ranked series the app was closed in the middle of counts as a loss.
        forfeitRankedSeries()
        watchNetwork()
        // Sign in to Game Center in the background. Only online play (casual and ranked) needs it;
        // bots, the Crusade and the Collection work without it.
        online.authenticate()
    }

    // MARK: Navigation

    func openCollection() {
        screen = .collection
    }

    func openArenas() {
        screen = .arenas
    }

    // MARK: Names and versus matches

    /// The name shown for this player in fights: the one they chose, else their Game Center name.
    var playerDisplayName: String {
        if profile.hasCustomName { return profile.playerName }
        if case .signedIn(let name) = online.auth, !name.isEmpty { return name }
        return String(localized: "Player")
    }

    /// Online or stand-in: a one-on-one against "another player".
    var isVersusMatch: Bool { mode == .online || mode == .standIn }
    var isRankedMatch: Bool { mode == .online ? online.isRanked : standIn?.ranked ?? false }
    var opponentName: String { mode == .online ? online.opponentName : standIn?.name ?? "" }
    /// The slot this device plays in a versus match.
    var localSlot: PlayerSlot { mode == .online ? online.localSlot : .one }

    private(set) var standIn: StandInOpponent?

    /// No one turned up: a bot steps in with a player-like name, a ball from your arenas and a level usual
    /// for your arena, and picks and readies up with a human-ish delay.
    private func startStandInMatch(ranked: Bool) {
        var rng = SystemRandomNumberGenerator()
        let pool = Arenas.tiers.filter { $0.number <= profile.arena.number }.flatMap(\.balls)
        let best = profile.unlockedRoster.map { profile.level(of: $0.id) }.max() ?? 1
        func botLevel() -> Int { Arenas.botLevel(trophies: profile.trophies, playerBest: best, using: &rng) }
        let level = botLevel()
        let opponent = StandInOpponent(name: PlayerNames.random(using: &rng), ranked: ranked,
                                       fighterID: pool.randomElement(using: &rng) ?? "spike", level: level)
        mode = .standIn
        standIn = opponent
        series = nil
        if ranked, let mine = profile.battleTeam {
            // Ranked is 3v3: the stand-in brings a team from your arenas.
            let theirs = Array(Set(pool)).shuffled(using: &rng).prefix(BotSeries.teamSize)
                .compactMap(FighterCatalog.definition(id:)).map { Progression.leveled($0, level: botLevel()) }
            if theirs.count == BotSeries.teamSize {
                series = BotSeries(playerTeam: mine, opponentTeam: theirs)
                rankedSeriesInProgress = true
                myPick = nil
                enterRoundPrep()
                return
            }
        }
        var rival = PlayerSetup(slot: .two)
        rival.level = opponent.level
        rival.aimAngle = -.pi / 2 + Double.random(in: -0.7...0.7, using: &rng)
        players[PlayerSlot.two.rawValue] = rival
        backToSetup()
        // "Choosing a fighter…"
        Task {
            try? await Task.sleep(for: .seconds(Double.random(in: 1.4...3.2)))
            guard standIn?.id == opponent.id, screen == .setup else { return }
            players[PlayerSlot.two.rawValue].fighterID = opponent.fighterID
            advanceStandIn()
        }
    }

    /// Once both have picked and the player has locked in, the stand-in locks in too and the fight starts.
    private func advanceStandIn() {
        guard mode == .standIn, let opponent = standIn, screen == .setup,
              players[PlayerSlot.one.rawValue].isReady, players[PlayerSlot.two.rawValue].fighter != nil,
              !players[PlayerSlot.two.rawValue].isReady else { return }
        Task {
            try? await Task.sleep(for: .seconds(Double.random(in: 0.6...1.6)))
            guard standIn?.id == opponent.id, screen == .setup, players[PlayerSlot.one.rawValue].isReady else { return }
            players[PlayerSlot.two.rawValue].isReady = true
            startStandInBattle()
        }
    }

    private func startStandInBattle() {
        guard let opponent = standIn, canStart else { return }
        let setup = MatchSetup(
            loadouts: PlayerSlot.allCases.map {
                FighterLoadout(definition: definition(for: $0)!, aimAngle: players[$0.rawValue].aimAngle)
            },
            labels: [playerDisplayName, opponent.name],
            steerableSlots: [.one],
            map: profile.arena.map
        )
        battle = BattleEngine(setup: setup)
        screen = .battle
    }

    func openSettings() {
        screen = .settings
    }

    func openDaily() {
        profile.refreshDaily()
        screen = .daily
    }

    /// Collects a trophy road reward and says what it gave.
    func claimRoadReward(_ reward: TrophyReward) {
        guard let contents = profile.claim(reward) else { return }
        if let (id, count) = contents.cards.first, let ball = FighterCatalog.definition(id: id) {
            showToast(String(localized: "+\(count) \(ball.name) cards!"))
        } else {
            announce(Progression.Rewards(coins: contents.coins, chests: contents.chests))
        }
    }

    /// A "+120 coins" banner after collecting a daily reward.
    func announce(_ rewards: Progression.Rewards) {
        var parts: [String] = []
        if rewards.coins > 0 { parts.append(String(localized: "+\(rewards.coins) coins")) }
        for kind in ChestKind.allCases.reversed() where rewards.chests.contains(kind) {
            let count = rewards.chests.filter { $0 == kind }.count
            parts.append(count > 1 ? "\(count)× \(kind.name.localized)" : kind.name.localized)
        }
        if !parts.isEmpty { showToast(parts.joined(separator: " · ") + "!") }
    }

    /// Wipes the player's progress and returns to the menu as a new player.
    func resetProgress() {
        crusadeRun = nil
        openedChest = nil
        newArena = nil
        collectionNotice = nil
        profile.resetProgress()
        showMenu()
    }

    func openShop() {
        screen = .shop
    }

    /// Watches a rewarded ad and, if it was watched to the end, grants the reward.
    func watchAd(for reward: Shop.AdReward, reviving ballID: String? = nil) {
        guard profile.adsLeft(reward) > 0, ads.isReady else { return }
        Task {
            guard await ads.showRewarded() else { return }
            profile.recordAd(reward)
            switch reward {
            case .coins: showToast(String(localized: "+\(reward.contents.coins) coins!"))
            case .chest: showToast(String(localized: "Free chest added!"))
            case .crusadeRevive:
                if let ballID {
                    profile.revive(ballID)
                    showToast(String(localized: "\(FighterCatalog.definition(id: ballID)?.name ?? String(localized: "Your ball")) is back in the fight!"))
                }
            }
        }
    }

    private func showToast(_ text: String) {
        withAnimation(.spring(duration: 0.3, bounce: 0.4)) { shopToast = text }
        Task {
            try? await Task.sleep(for: .seconds(2.2))
            withAnimation(.easeOut(duration: 0.3)) { if shopToast == text { shopToast = nil } }
        }
    }

    func openChest(_ kind: ChestKind) {
        guard openedChest == nil, let opening = profile.openChest(kind) else { return }
        openedChest = opening
    }

    func openAllChests() {
        guard openedChest == nil, let opening = profile.openAllChests() else { return }
        openedChest = opening
    }

    /// Set to show the Collection's chests (the wallet's chest button).
    var focusChests = false

    func openChests() {
        focusChests = true
        screen = .collection
    }

    /// A slot's ball with levels applied: this device's levels for its own slots, the opponent's online.
    func definition(for slot: PlayerSlot) -> FighterDefinition? {
        guard let base = players[slot.rawValue].fighter else { return nil }
        if controlledSlots.contains(slot) { return profile.definition(base) }
        return Progression.leveled(base, level: players[slot.rawValue].level)
    }

    /// Balls offered on the setup screen: every ball for 2 players on one device, owned balls otherwise.
    var setupRoster: [FighterDefinition] { mode == .local ? FighterCatalog.all : profile.unlockedRoster }

    func showMenu() {
        forfeitRankedSeries()
        if mode == .online { online.leave() }
        standIn = nil
        collectionNotice = nil
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
        guard controlledSlots.contains(slot) else { return }
        players[slot.rawValue].fighterID = fighterID
        players[slot.rawValue].isReady = false
        shareSetup()
    }

    func setAim(_ angle: Double, for slot: PlayerSlot) {
        guard controlledSlots.contains(slot) else { return }
        players[slot.rawValue].aimAngle = angle
        shareSetup()
    }

    func setReady(_ ready: Bool, for slot: PlayerSlot) {
        guard controlledSlots.contains(slot), players[slot.rawValue].fighter != nil else { return }
        players[slot.rawValue].isReady = ready
        shareSetup()
        startOnlineIfReady()
        advanceStandIn()
    }

    /// Points a fighter's launch during the countdown (and tells the opponent, online).
    func aimLaunch(_ angle: Double, for slot: PlayerSlot) {
        guard let battle, controlledSlots.contains(slot) else { return }
        battle.simulation.setLaunchAngle(angle, for: slot)
        if mode == .online { online.send(.launchAim(seed: battle.seed, angle: angle), reliable: false) }
    }

    func startBattle() {
        guard mode != .online, canStart else { return }
        let setup = MatchSetup(loadouts: PlayerSlot.allCases.map {
            FighterLoadout(definition: definition(for: $0)!, aimAngle: players[$0.rawValue].aimAngle)
        }, map: profile.arena.map)
        battle = BattleEngine(setup: setup)
        screen = .battle
    }

    /// Same fighters, aim and starting health; new random launch angles.
    func rematch() {
        if mode == .standIn {
            // A "rematch" looks for a new opponent, like a real queue.
            if standIn?.ranked == true { playRanked() } else { openOnlineLobby(); findOnlineMatch() }
            return
        }
        if mode == .online {
            // Both players have to ask; then the host picks the seed and starts it for both.
            guard !wantsRematch else { return }
            wantsRematch = true
            online.send(.rematch)
            startRematchIfAgreed()
            return
        }
        guard let setup = battle?.setup else { return }
        battle = BattleEngine(setup: setup)
    }

    func changeFighters() {
        if mode == .online { online.send(.changeFighters) }
        backToSetup()
    }

    private func backToSetup() {
        battle = nil
        for i in players.indices { players[i].isReady = false }
        screen = .setup
    }

    // MARK: Online

    func openOnlineLobby() {
        wantsRanked = false
        mode = .online
        battle = nil
        series = nil
        onlineNotice = nil
        screen = .onlineLobby
        online.authenticate()
    }

    func findOnlineMatch(roomCode: Int? = nil) {
        onlineNotice = nil
        online.findMatch(roomCode: roomCode)
    }

    /// Set when the player hit Battle before Game Center finished signing in.
    private var wantsRanked = false

    /// The arena Battle button: a ranked online match that wins or loses trophies.
    /// The arena Battle button needs a full battle team (the active preset); otherwise it opens the Collection.
    func playRanked() {
        guard profile.battleTeam != nil else {
            collectionNotice = String(localized: "Arena battles are 3v3. Fill your battle preset with 3 balls first.")
            openCollection()
            return
        }
        // Ranked needs Game Center: without it the lobby shows why and offers to sign in again.
        openOnlineLobby()
        if online.isSignedIn {
            online.findMatch(ranked: true, arena: profile.arena.number)
        } else {
            wantsRanked = true
        }
    }

    func inviteFriend(_ friend: OnlineSession.Friend) {
        onlineNotice = nil
        online.invite(friend)
    }

    private func handleOnline(_ event: OnlineSession.Event) {
        switch event {
        case .noOpponentFound(let ranked):
            guard screen == .onlineLobby else { return }
            startStandInMatch(ranked: ranked)
        case .signedIn:
            online.submitTrophies(profile.trophies)
            if wantsRanked, screen == .onlineLobby {
                wantsRanked = false
                online.findMatch(ranked: true, arena: profile.arena.number)
            }
        case .signInFailed:
            wantsRanked = false
        case .inviteAccepted:
            mode = .online
            battle = nil
            series = nil
            onlineNotice = nil
            screen = .onlineLobby
        case .connected:
            let remote = online.remoteSlot.rawValue
            players[remote] = PlayerSetup(slot: online.remoteSlot)
            if online.isRanked, let team = profile.battleTeam {
                // Ranked is a 3v3 series: swap teams, then pick fighters round by round.
                series = nil
                myPick = nil
                remotePick = nil
                online.send(.team(fighterIDs: team.map(\.id), levels: team.map(\.level), trophies: profile.trophies))
            } else {
                backToSetup()
                shareSetup()
            }
        case .disconnected(let reason):
            guard mode == .online else { return }
            if rankedSeriesInProgress, series?.outcome == nil {
                endRankedSeriesEarly()
            } else {
                onlineNotice = reason
            }
            battle = nil
            series = nil
            screen = .onlineLobby
        case .message(let message):
            receive(message)
        }
    }

    private func receive(_ message: OnlineMessage) {
        let remote = online.remoteSlot
        switch message {
        case .hello:
            break
        case .setup(let fighterID, let level, let trophies, let aimAngle, let isReady):
            players[remote.rawValue].fighterID = fighterID
            players[remote.rawValue].level = level
            players[remote.rawValue].trophies = trophies
            players[remote.rawValue].aimAngle = aimAngle
            players[remote.rawValue].isReady = isReady
            startOnlineIfReady()
        case .team(let ids, let levels, let trophies):
            players[remote.rawValue].trophies = trophies
            let theirs = zip(ids, levels).compactMap { id, level in
                FighterCatalog.definition(id: id).map { Progression.leveled($0, level: level) }
            }
            guard let mine = profile.battleTeam, theirs.count == BotSeries.teamSize else { return }
            series = BotSeries(playerTeam: mine, opponentTeam: theirs)
            rankedSeriesInProgress = true
            myPick = nil
            remotePick = nil
            enterRoundPrep()
        case .roundPick(let index, let aim):
            remotePick = (index, aim)
            startOnlineSeriesRoundIfReady()
        case .start(let seed, let arena):
            guard !online.isHost else { return }
            let map = ArenaMap(rawValue: arena) ?? .classic
            if series != nil { startOnlineSeriesRound(seed: seed, map: map) } else { startOnlineBattle(seed: seed, map: map) }
        case .launchAim(let seed, let angle):
            if let battle, battle.seed == seed { battle.simulation.setLaunchAngle(angle, for: remote) }
        case .launchLock(let seed, let angle):
            if let battle, battle.seed == seed { battle.simulation.lockLaunch(remote, angle: angle) }
        case .rematch:
            // Ignore a request that crossed with a rematch the host already started.
            guard battle?.outcome != nil else { return }
            opponentWantsRematch = true
            startRematchIfAgreed()
        case .changeFighters:
            backToSetup()
        }
    }

    /// Sends this device's setup choices to the opponent.
    private func shareSetup() {
        guard mode == .online, online.status == .connected else { return }
        let me = players[online.localSlot.rawValue]
        online.send(.setup(fighterID: me.fighterID, level: me.fighterID.map(profile.level(of:)) ?? 1,
                           trophies: profile.trophies, aimAngle: me.aimAngle, isReady: me.isReady))
    }

    /// The host starts as soon as both players have locked in.
    private func startOnlineIfReady() {
        guard mode == .online, online.isHost, screen == .setup, canStart else { return }
        startOnlineBattle(seed: .random(in: .min ... .max))
    }

    /// The host picks the arena: the higher of the two players' arenas.
    private func startOnlineBattle(seed: UInt64, map: ArenaMap? = nil) {
        // A client always follows the host's start, even if it un-readied a moment too late.
        guard players.allSatisfy({ $0.fighter != nil }) else { return }
        let arena = map ?? Arenas.tier(forTrophies: max(profile.trophies, players[online.remoteSlot.rawValue].trophies)).map
        if online.isHost { online.send(.start(seed: seed, arena: arena.rawValue)) }
        var labels = ["", ""]
        labels[online.localSlot.rawValue] = playerDisplayName
        labels[online.remoteSlot.rawValue] = online.opponentName
        let setup = MatchSetup(loadouts: PlayerSlot.allCases.map {
                                   FighterLoadout(definition: definition(for: $0)!, aimAngle: players[$0.rawValue].aimAngle)
                               },
                               labels: labels, map: arena)
        let engine = BattleEngine(setup: setup, seed: seed, onlineSlot: online.localSlot)
        engine.onLaunchLocked = { [weak self] angle in self?.online.send(.launchLock(seed: seed, angle: angle)) }
        battle = engine
        wantsRematch = false
        opponentWantsRematch = false
        screen = .battle
    }

    // MARK: Rematches and leaving

    /// Online: this player, and the opponent, asked for a rematch after the current fight.
    private(set) var wantsRematch = false
    private(set) var opponentWantsRematch = false

    /// What the results screen says about a rematch (online only).
    var rematchStatus: String? {
        guard mode == .online else { return nil }
        if wantsRematch { return String(localized: "Waiting for \(online.opponentName)…") }
        if opponentWantsRematch { return String(localized: "\(online.opponentName) wants a rematch!") }
        return nil
    }

    private func startRematchIfAgreed() {
        guard online.isHost, wantsRematch, opponentWantsRematch, battle?.outcome != nil else { return }
        startOnlineBattle(seed: .random(in: .min ... .max))
    }

    /// Set while a ranked series is being played (saved, so closing the app mid-series still counts).
    private static let rankedSeriesKey = "rankedSeriesInProgress"
    private var rankedSeriesInProgress: Bool {
        get { UserDefaults.standard.bool(forKey: Self.rankedSeriesKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.rankedSeriesKey) }
    }

    /// Leaving a ranked series before it's decided is a loss (so quitting can't dodge one).
    private func forfeitRankedSeries() {
        guard rankedSeriesInProgress else { return }
        rankedSeriesInProgress = false
        _ = profile.award(Progression.onlineLoss)
        online.submitTrophies(profile.trophies)
        showToast(String(localized: "You left a ranked battle: \(Progression.onlineLoss.trophies) trophies"))
    }

    /// The opponent left a ranked series before it was decided: this player wins it.
    private func winByForfeit() {
        rankedSeriesInProgress = false
        let rewards = Progression.onlineWin
        profile.advanceQuest(.winRanked)
        if let reached = profile.award(rewards) { newArena = reached }
        online.submitTrophies(profile.trophies)
        onlineNotice = String(localized: "\(online.opponentName) left the battle. You win! +\(rewards.trophies) trophies")
    }

    /// The ranked opponent is gone mid-series (the connection dropped, or their pick never came). Whoever had
    /// trouble on their side (the app in the background, no network) loses; the other player wins. Without
    /// this, both devices would see the other one leave and both would win.
    private func endRankedSeriesEarly() {
        if connectionTroubleIsOurs {
            forfeitRankedSeries()
            onlineNotice = String(localized: "Your connection dropped, so the ranked battle counts as a loss.")
        } else {
            winByForfeit()
        }
    }

    /// Ranked online: if the opponent's pick (or, for the client, the host's start) never comes, they've gone.
    private func waitForOpponentPick(round: Int) {
        Task {
            try? await Task.sleep(for: .seconds(GameConfig.onlineAwayLimit))
            guard mode == .online, screen == .roundPrep, isWaitingForOpponentPick, series?.round == round,
                  rankedSeriesInProgress else { return }
            endRankedSeriesEarly()
            online.leave()
            battle = nil
            series = nil
            screen = .onlineLobby
        }
    }

    // MARK: Away and connection trouble

    /// The app is in the background / has no network right now.
    @ObservationIgnored private var isAway = false
    @ObservationIgnored private var isOffline = false
    /// When this device last went to or came back from the background, or lost or regained its network.
    @ObservationIgnored private var lastTroubleAt: Date?
    /// When the app went to the background in the middle of a versus match.
    @ObservationIgnored private var awaySince: Date?
    @ObservationIgnored private let network = NWPathMonitor()
    /// A dropped versus match is this device's fault if it had trouble this recently (the drop can arrive
    /// a while after the trouble, e.g. once the app is back on screen).
    private static let troubleWindow: TimeInterval = 30

    private var connectionTroubleIsOurs: Bool {
        isAway || isOffline || lastTroubleAt.map { Date.now.timeIntervalSince($0) < Self.troubleWindow } ?? false
    }

    private func watchNetwork() {
        network.pathUpdateHandler = { [weak self] path in
            let reachable = path.status == .satisfied
            Task { @MainActor in self?.networkChanged(reachable: reachable) }
        }
        network.start(queue: .main)
    }

    private func networkChanged(reachable: Bool) {
        guard isOffline == reachable else { return }
        isOffline = !reachable
        lastTroubleAt = .now
    }

    /// The app moved to or from the background. Away from a versus match too long counts as leaving it.
    func scenePhaseChanged(_ phase: ScenePhase) {
        switch phase {
        case .background:
            isAway = true
            lastTroubleAt = .now
            if isVersusMatch, awaySince == nil { awaySince = .now }
        case .active:
            if isAway { lastTroubleAt = .now }
            isAway = false
            if let awaySince, Date.now.timeIntervalSince(awaySince) > GameConfig.onlineAwayLimit {
                leaveVersusMatchAfterAway()
            }
            awaySince = nil
        default:
            break
        }
    }

    /// Away from a versus match too long: it counts as leaving (a ranked series is lost).
    private func leaveVersusMatchAfterAway() {
        let fighting = screen == .battle && battle?.outcome == nil
        guard isVersusMatch, rankedSeriesInProgress || fighting else { return }
        let ranked = rankedSeriesInProgress
        showMenu()
        if !ranked { showToast(String(localized: "You were away too long and left the battle.")) }
    }

    // MARK: Crusade

    /// Chapter shown on the crusade screen, and the level picked for the prep screen.
    var crusadeChapter = 0
    private(set) var crusadeLevel = 1
    var crusadeDifficulty: CrusadeDifficulty = .normal
    private(set) var crusadeRun: CrusadeRun?

    func openCrusade() {
        mode = .crusade
        battle = nil
        crusadeRun = nil
        screen = .crusade
    }

    func openCrusadeLevel(chapter: Int, level: Int) {
        guard profile.isUnlocked(chapter: chapter, level: level, difficulty: crusadeDifficulty) else { return }
        crusadeChapter = chapter
        crusadeLevel = level
        battle = nil
        crusadeRun = nil
        screen = .crusadePrep
    }

    /// Sends a team (up to 3 balls that aren't resting) into the selected level.
    func startCrusadeLevel(teamIDs: [String], aimAngle: Double) {
        let team = teamIDs.compactMap(FighterCatalog.definition(id:))
            .filter { !profile.isResting($0.id) }
            .prefix(Crusade.teamSize)
            .enumerated()
            .map { TeamMember(id: $0.offset, definition: profile.definition($0.element), health: profile.definition($0.element).maxHealth) }
        guard !team.isEmpty else { return }
        crusadeRun = CrusadeRun(chapter: crusadeChapter, level: crusadeLevel, difficulty: crusadeDifficulty,
                                aimAngle: aimAngle, power: profile.crusadePower, team: team)
        startCrusadeFight()
    }

    /// Between fights: pick which living teammate goes in next.
    func chooseCrusadeFighter(_ index: Int) {
        guard let run = crusadeRun, run.team.indices.contains(index), run.team[index].isAlive else { return }
        crusadeRun?.active = index
    }

    func continueCrusade() {
        guard case .continuing = crusadeRun?.result else { return }
        crusadeRun?.result = nil
        startCrusadeFight()
    }

    /// Back to the level's prep screen to pick a team again (fallen balls are resting).
    func retryCrusadeLevel() {
        guard let run = crusadeRun else { return }
        openCrusadeLevel(chapter: run.chapter, level: run.level)
    }

    /// Leaving a crusade fight before it ends counts as the fighting ball falling,
    /// so quitting can't dodge the rest.
    func retreatFromCrusade() {
        if let run = crusadeRun, run.result == nil, battle?.outcome == nil {
            profile.markFallen(run.team[run.active].definition.id)
        }
        openCrusade()
    }

    /// The level after the current one, or back to the map after a boss (where Hard / the next map now opens).
    func nextCrusadeLevel() {
        guard let run = crusadeRun else { return }
        crusadeDifficulty = run.difficulty
        if run.level < Crusade.chapters[run.chapter].levels.count {
            openCrusadeLevel(chapter: run.chapter, level: run.level + 1)
        } else {
            openCrusade()
        }
    }

    private func startCrusadeFight() {
        guard let run = crusadeRun, let enemy = run.enemy(run.enemyIndex) else { return }
        let member = run.team[run.active]
        let setup = MatchSetup(
            loadouts: [
                FighterLoadout(definition: member.definition, aimAngle: run.aimAngle, startingHealth: member.health),
                // Enemy Blasters aim roughly up the arena, toward the player.
                FighterLoadout(definition: enemy, aimAngle: -.pi / 2 + .random(in: -0.7...0.7), startingHealth: run.enemyHealth),
            ],
            labels: ["YOU", enemy.name.uppercased()],
            steerableSlots: [.one],
            map: Crusade.chapters[run.chapter].map
        )
        battle = BattleEngine(setup: setup)
        screen = .battle
    }

    // MARK: VS Bot

    func confirmTeam(_ team: [FighterDefinition]) {
        guard team.count == BotSeries.teamSize else { return }
        // Your balls at your levels; the bot fields balls from the arenas you've reached, each at a level
        // usual for your arena (not your bought upgrades).
        let leveled = team.map(profile.definition)
        var rng = SystemRandomNumberGenerator()
        let best = profile.unlockedRoster.map { profile.level(of: $0.id) }.max() ?? 1
        let pool = profile.unlockedRoster.count >= BotSeries.teamSize ? profile.unlockedRoster : FighterCatalog.all
        let theirs = pool.shuffled(using: &rng).prefix(BotSeries.teamSize).map {
            Progression.leveled($0, level: Arenas.botLevel(trophies: profile.trophies, playerBest: best, using: &rng))
        }
        series = BotSeries(playerTeam: leveled, opponentTeam: Array(theirs))
        screen = .roundPrep
    }

    /// The next round of a 3v3 series: VS Bot, a ranked stand-in, or a ranked online opponent.
    func startSeriesRound(playerIndex: Int, aimAngle: Double) {
        switch mode {
        case .online:
            guard let series, series.player[playerIndex].isAlive, myPick == nil else { return }
            myPick = (playerIndex, aimAngle)
            online.send(.roundPick(index: playerIndex, aimAngle: aimAngle))
            startOnlineSeriesRoundIfReady()
            waitForOpponentPick(round: series.round)
        case .standIn:
            // Like a real opponent, the stand-in "locks in" a moment later (never past the clock).
            guard let series, series.player[playerIndex].isAlive, myPick == nil else { return }
            myPick = (playerIndex, aimAngle)
            let left = pickDeadline.map { $0.timeIntervalSinceNow } ?? 0
            let delay = min(max(0, left), Double.random(in: 0.5...2.2))
            let round = series.round
            Task {
                try? await Task.sleep(for: .seconds(delay))
                guard mode == .standIn, screen == .roundPrep, battle == nil, self.series?.round == round,
                      let pick = myPick else { return }
                myPick = nil
                startBotRound(playerIndex: pick.index, aimAngle: pick.aim,
                              labels: [playerDisplayName, standIn?.name ?? "RIVAL"])
            }
        default:
            startBotRound(playerIndex: playerIndex, aimAngle: aimAngle)
        }
    }

    /// The host starts a round once both picks are in.
    private func startOnlineSeriesRoundIfReady() {
        guard online.isHost, myPick != nil, remotePick != nil, screen == .roundPrep, battle == nil else { return }
        let map = Arenas.tier(forTrophies: max(profile.trophies, players[online.remoteSlot.rawValue].trophies)).map
        let seed = UInt64.random(in: .min ... .max)
        online.send(.start(seed: seed, arena: map.rawValue))
        startOnlineSeriesRound(seed: seed, map: map)
    }

    private func startOnlineSeriesRound(seed: UInt64, map: ArenaMap) {
        guard let series, let mine = myPick, let theirs = remotePick else { return }
        let me = series.player[mine.index], them = series.bot[theirs.index]
        var loadouts = [FighterLoadout](repeating: FighterLoadout(definition: me.definition, aimAngle: 0), count: 2)
        loadouts[online.localSlot.rawValue] = FighterLoadout(definition: me.definition, aimAngle: mine.aim, startingHealth: me.health)
        loadouts[online.remoteSlot.rawValue] = FighterLoadout(definition: them.definition, aimAngle: theirs.aim, startingHealth: them.health)
        var labels = ["", ""]
        labels[online.localSlot.rawValue] = playerDisplayName
        labels[online.remoteSlot.rawValue] = online.opponentName
        let engine = BattleEngine(setup: MatchSetup(loadouts: loadouts, labels: labels, map: map), seed: seed,
                                  onlineSlot: online.localSlot)
        engine.onLaunchLocked = { [weak self] angle in self?.online.send(.launchLock(seed: seed, angle: angle)) }
        roundPicks = (mine.index, theirs.index)
        // Picks are used up; the next round's may arrive while this one's result still shows.
        myPick = nil
        remotePick = nil
        pickDeadline = nil
        battle = engine
        screen = .battle
    }

    func startBotRound(playerIndex: Int, aimAngle: Double, labels: [String] = ["YOU", "BOT"]) {
        guard var series, series.player[playerIndex].isAlive else { return }
        let botIndex = series.botPick()
        let you = series.player[playerIndex]
        let them = series.bot[botIndex]
        let setup = MatchSetup(
            loadouts: [
                FighterLoadout(definition: you.definition, aimAngle: aimAngle, startingHealth: you.health),
                FighterLoadout(definition: them.definition, aimAngle: series.botAimAngle(), startingHealth: them.health),
            ],
            labels: labels,
            steerableSlots: [.one],
            map: profile.arena.map
        )
        self.series = series
        pickDeadline = nil
        roundPicks = (playerIndex, botIndex)
        battle = BattleEngine(setup: setup)
        screen = .battle
    }

    /// Called once when a battle shows its result: records bot rounds and pays out rewards.
    func recordResult(from engine: BattleEngine) {
        guard let outcome = engine.outcome, recordedBattle != ObjectIdentifier(engine) else { return }
        recordedBattle = ObjectIdentifier(engine)
        var rewards = Progression.Rewards()
        if mode != .local { profile.advanceQuest(.playBattles) }
        defer {
            // A ranked win (single battle or a whole series) pays trophies.
            if rewards.trophies > 0 { profile.advanceQuest(.winRanked) }
        }
        switch mode {
        case .local:
            return
        case .crusade:
            guard var run = crusadeRun, run.result == nil else { return }
            let state = engine.simulation.state
            run.team[run.active].health = max(0, state.fighter(.one).health)
            if !run.team[run.active].isAlive { profile.markFallen(run.team[run.active].definition.id) }
            let enemyDown = state.fighter(.two).health <= 0
            if enemyDown {
                run.enemyIndex += 1
                run.enemyHealth = nil
            } else {
                run.enemyHealth = state.fighter(.two).health
            }
            if run.enemyIndex >= run.levelInfo.enemies.count {
                let stars = Crusade.stars(fallen: run.fallen)
                rewards = profile.completeLevel(chapter: run.chapter, level: run.level, difficulty: run.difficulty, stars: stars)
                run.result = .cleared(stars: stars)
            } else if let next = run.team.firstIndex(where: \.isAlive) {
                if !run.team[run.active].isAlive { run.active = next }
                run.result = .continuing(enemyDown: enemyDown)
            } else {
                run.result = .lost
            }
            crusadeRun = run
            lastRewards = rewards
            return
        case .standIn where series != nil, .online where series != nil:
            rewards = recordRankedSeriesRound(outcome, state: engine.simulation.state)
        case .standIn:
            guard standIn?.ranked == true else { return }
            switch outcome {
            case .winner(let slot): rewards = slot == .one ? Progression.onlineWin : Progression.onlineLoss
            case .draw: rewards = Progression.onlineDraw
            }
        case .online:
            // Only ranked battles pay out; quick match, rooms and friend games are just for fun.
            guard online.isRanked else { return }
            switch outcome {
            case .winner(let slot): rewards = slot == online.localSlot ? Progression.onlineWin : Progression.onlineLoss
            case .draw: rewards = Progression.onlineDraw
            }
        case .bot:
            guard var series, let picks = roundPicks else { return }
            let state = engine.simulation.state
            series.record(outcome, playerIndex: picks.player, botIndex: picks.bot,
                          playerHealth: state.fighter(.one).health, botHealth: state.fighter(.two).health)
            self.series = series
            if outcome == .winner(.one) { rewards = rewards + Progression.botRoundWin }
            switch series.outcome {
            case .playerWins:
                rewards = rewards + Progression.botSeriesWin
                profile.advanceQuest(.winBotSeries)
            case .botWins, .draw: rewards = rewards + Progression.botSeriesLoss
            case nil: break
            }
        }
        if let reached = profile.award(rewards) { newArena = reached }
        // Versus series: after a moment on the round result, both players go straight to the next pick.
        if isVersusSeries, series?.outcome == nil {
            let finished = ObjectIdentifier(engine)
            Task {
                try? await Task.sleep(for: .seconds(Self.roundResultDuration))
                guard let battle, ObjectIdentifier(battle) == finished, screen == .battle else { return }
                nextBotRound()
            }
        }
        lastRewards = rewards
        if rewards.trophies != 0 { online.submitTrophies(profile.trophies) }
    }

    /// Records a ranked series round from this player's side; trophies and rewards come only when it ends.
    private func recordRankedSeriesRound(_ outcome: BattleOutcome, state: BattleState) -> Progression.Rewards {
        guard var series, let picks = roundPicks else { return Progression.Rewards() }
        let local = localSlot
        let mine: BattleOutcome = {
            switch outcome {
            case .winner(let slot): return .winner(slot == local ? .one : .two)
            case .draw: return .draw
            }
        }()
        series.record(mine, playerIndex: picks.player, botIndex: picks.bot,
                      playerHealth: state.fighter(local).health, botHealth: state.fighter(local.opponent).health)
        self.series = series
        if series.outcome != nil { rankedSeriesInProgress = false }
        switch series.outcome {
        case .playerWins: return Progression.onlineWin
        case .botWins: return Progression.onlineLoss
        case .draw: return Progression.onlineDraw
        case nil: return Progression.Rewards()
        }
    }

    /// This player's view of a round result (online, this device may be slot two).
    func playerOutcome(_ outcome: BattleOutcome) -> BattleOutcome {
        guard case .winner(let slot) = outcome else { return outcome }
        return .winner(slot == localSlot ? .one : .two)
    }

    /// After a series: another VS Bot series, or back into the ranked queue.
    func playSeriesAgain() {
        guard mode != .bot else { return openBotTeamSelect() }
        if mode == .online { online.leave() }
        standIn = nil
        series = nil
        battle = nil
        playRanked()
    }

    /// Heading for the opponent's team in a series.
    var opponentTeamTitle: String {
        mode == .bot ? String(localized: "BOT TEAM") : String(localized: "\(opponentName.uppercased())'S TEAM")
    }

    func nextBotRound() {
        // Online, the opponent's next pick may already be here: keep it.
        if mode != .online { remotePick = nil }
        myPick = nil
        enterRoundPrep()
    }

    /// The pick clock ran out: send the survivor, or the first fighter still standing.
    func pickTimedOut(choice: Int?, aimAngle: Double) {
        guard isVersusSeries, screen == .roundPrep, myPick == nil, let series else { return }
        guard let index = choice.flatMap({ series.player[$0].isAlive ? $0 : nil })
                ?? series.playerSurvivor ?? series.playerChoices.first else { return }
        startSeriesRound(playerIndex: index, aimAngle: aimAngle)
    }
}

#if DEBUG
extension AppModel {
    /// App Store screenshot: a ranked fight frozen mid-way, with both teams on the bench.
    func startStoreDemoBattle() {
        let mine = StoreDemo.playerTeam.compactMap(FighterCatalog.definition(id:)).map(profile.definition)
        let theirs = StoreDemo.opponentTeam.compactMap(FighterCatalog.definition(id:))
            .map { Progression.leveled($0, level: StoreDemo.opponentLevel) }
        mode = .standIn
        standIn = StandInOpponent(name: StoreDemo.opponentName, ranked: true, fighterID: theirs[0].id, level: StoreDemo.opponentLevel)
        series = BotSeries(playerTeam: mine, opponentTeam: theirs, seed: 1)
        roundPicks = (0, 0)
        let setup = MatchSetup(
            loadouts: [FighterLoadout(definition: mine[0], aimAngle: .pi / 2), FighterLoadout(definition: theirs[0], aimAngle: -.pi / 2)],
            labels: [playerDisplayName, StoreDemo.opponentName],
            steerableSlots: [.one],
            map: profile.arena.map
        )
        let engine = BattleEngine(setup: setup, seed: StoreDemo.battleSeed)
        engine.holdForStoreDemo(at: StoreDemo.battleTime)
        battle = engine
        screen = .battle
    }
}
#endif
