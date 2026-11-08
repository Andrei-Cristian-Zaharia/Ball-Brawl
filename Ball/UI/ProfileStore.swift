import SwiftUI

/// The player's saved progress: coins, unopened chests, and each ball's level and spare cards.
nonisolated struct PlayerProfile: Codable, Equatable {
    var coins = 0
    /// Unopened chests by type.
    var chests: [ChestKind: Int] = [:]
    var levels: [String: Int] = [:]
    var cards: [String: Int] = [:]
    /// Best stars per crusade level, keyed by `Crusade.key`.
    var crusadeStars: [String: Int] = [:]
    /// Balls knocked out in today's crusade (with the time they fell); they rest until the daily reset.
    var crusadeFallen: [String: Double] = [:]
    /// The day (`Crusade.dayKey`) the crusade progress above belongs to.
    var crusadeDay = ""
    /// The team last picked for the crusade (kept across levels, days and launches); nil until first picked.
    var crusadeTeam: [String]?
    /// Current trophies, and the most ever reached (arenas, and their balls, stay unlocked from that).
    var trophies = 0
    var bestTrophies = 0
    /// In-app purchases already delivered (so a re-sent transaction never pays out twice).
    var deliveredTransactions: [String] = []
    var ownsStarterPack = false
    /// Rewarded ads watched today, per reward (`Shop.AdReward` raw value), for the day `adDay`.
    var adsWatched: [String: Int] = [:]
    var adDay = ""
    /// Name shown in fights: generated on first launch, or chosen by the player (`hasCustomName`),
    /// which then also replaces their Game Center name.
    var playerName = ""
    var hasCustomName = false
    /// The preset (index into `teamPresets`) used as the team for ranked arena battles.
    var activePreset = 0
    /// Player level, XP into the current level, and all XP ever earned (decides which save wins in the cloud).
    var playerLevel = 1
    var xp = 0
    var totalXP = 0
    /// Saved teams the player builds in the Collection; each holds up to 3 ball ids.
    var teamPresets: [[String]] = Array(repeating: [], count: PlayerProfile.presetCount)
    /// Balls the player has found a card of (arena 1's balls count from the start). Reaching an arena only
    /// adds its balls to chest drops; each one unlocks when its first card comes out of a chest.
    var foundBalls: Set<String> = Set(Arenas.tiers[0].balls)
    /// When the player last reset their progress (0 = never). A newer reset beats any older save in the cloud.
    var resetAt: Double = 0
    /// Daily login streak: the current day of it (1–7), the last day played, and the last day it paid out.
    var loginStreak = 0
    var lastLoginDay = ""
    var loginClaimedDay = ""
    /// Today's quests (`questDay`): progress per quest kind, and the ones claimed ("bonus" for all three).
    var questDay = ""
    var questProgress: [String: Int] = [:]
    var questsClaimed: [String] = []
    /// When the next free chest is ready (seconds since 1970; 0 = ready now).
    var nextFreeChest: Double = 0
    /// Voucher codes already redeemed (each pays once per player, even after a reset).
    var redeemedVouchers: [String] = []
    /// Trophy road rewards already claimed, by their trophy count.
    var claimedRoad: [Int] = []

    static let presetCount = 3

    init() {}

    private enum CodingKeys: String, CodingKey {
        case coins, chests, levels, cards, crusadeStars, crusadeFallen, crusadeDay, crusadeTeam, teamPresets
        case chestInventory, playerLevel, xp, totalXP, foundBalls, resetAt
        case loginStreak, lastLoginDay, loginClaimedDay, questDay, questProgress, questsClaimed, nextFreeChest, redeemedVouchers, claimedRoad
        case trophies, bestTrophies, deliveredTransactions, ownsStarterPack, adsWatched, adDay, playerName, hasCustomName, activePreset
        /// Saves from before the crusade rename.
        case campaignStars
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(coins, forKey: .coins)
        try c.encode(Dictionary(uniqueKeysWithValues: chests.map { ($0.key.rawValue, $0.value) }), forKey: .chestInventory)
        try c.encode(levels, forKey: .levels)
        try c.encode(cards, forKey: .cards)
        try c.encode(crusadeStars, forKey: .crusadeStars)
        try c.encode(crusadeFallen, forKey: .crusadeFallen)
        try c.encode(crusadeDay, forKey: .crusadeDay)
        try c.encodeIfPresent(crusadeTeam, forKey: .crusadeTeam)
        try c.encode(teamPresets, forKey: .teamPresets)
        try c.encode(trophies, forKey: .trophies)
        try c.encode(bestTrophies, forKey: .bestTrophies)
        try c.encode(deliveredTransactions, forKey: .deliveredTransactions)
        try c.encode(ownsStarterPack, forKey: .ownsStarterPack)
        try c.encode(adsWatched, forKey: .adsWatched)
        try c.encode(adDay, forKey: .adDay)
        try c.encode(playerName, forKey: .playerName)
        try c.encode(hasCustomName, forKey: .hasCustomName)
        try c.encode(activePreset, forKey: .activePreset)
        try c.encode(playerLevel, forKey: .playerLevel)
        try c.encode(xp, forKey: .xp)
        try c.encode(totalXP, forKey: .totalXP)
        try c.encode(foundBalls.sorted(), forKey: .foundBalls)
        try c.encode(resetAt, forKey: .resetAt)
        try c.encode(loginStreak, forKey: .loginStreak)
        try c.encode(lastLoginDay, forKey: .lastLoginDay)
        try c.encode(loginClaimedDay, forKey: .loginClaimedDay)
        try c.encode(questDay, forKey: .questDay)
        try c.encode(questProgress, forKey: .questProgress)
        try c.encode(questsClaimed, forKey: .questsClaimed)
        try c.encode(nextFreeChest, forKey: .nextFreeChest)
        try c.encode(redeemedVouchers, forKey: .redeemedVouchers)
        try c.encode(claimedRoad, forKey: .claimedRoad)
    }

    /// Fields missing from older saves fall back to their defaults.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        coins = try c.decodeIfPresent(Int.self, forKey: .coins) ?? 0
        let inventory = try c.decodeIfPresent([String: Int].self, forKey: .chestInventory) ?? [:]
        chests = Dictionary(uniqueKeysWithValues: inventory.compactMap { key, count in ChestKind(rawValue: key).map { ($0, count) } })
        // Saves from before chest types counted plain chests: they become Wooden ones.
        if let legacy = try c.decodeIfPresent(Int.self, forKey: .chests), legacy > 0 { chests[.wooden, default: 0] += legacy }
        levels = try c.decodeIfPresent([String: Int].self, forKey: .levels) ?? [:]
        cards = try c.decodeIfPresent([String: Int].self, forKey: .cards) ?? [:]
        crusadeStars = try c.decodeIfPresent([String: Int].self, forKey: .crusadeStars)
            ?? c.decodeIfPresent([String: Int].self, forKey: .campaignStars) ?? [:]
        crusadeFallen = try c.decodeIfPresent([String: Double].self, forKey: .crusadeFallen) ?? [:]
        crusadeDay = try c.decodeIfPresent(String.self, forKey: .crusadeDay) ?? ""
        crusadeTeam = try c.decodeIfPresent([String].self, forKey: .crusadeTeam)
        trophies = try c.decodeIfPresent(Int.self, forKey: .trophies) ?? 0
        bestTrophies = try c.decodeIfPresent(Int.self, forKey: .bestTrophies) ?? 0
        deliveredTransactions = try c.decodeIfPresent([String].self, forKey: .deliveredTransactions) ?? []
        ownsStarterPack = try c.decodeIfPresent(Bool.self, forKey: .ownsStarterPack) ?? false
        adsWatched = try c.decodeIfPresent([String: Int].self, forKey: .adsWatched) ?? [:]
        adDay = try c.decodeIfPresent(String.self, forKey: .adDay) ?? ""
        playerName = try c.decodeIfPresent(String.self, forKey: .playerName) ?? ""
        hasCustomName = try c.decodeIfPresent(Bool.self, forKey: .hasCustomName) ?? false
        activePreset = try c.decodeIfPresent(Int.self, forKey: .activePreset) ?? 0
        let presets = try c.decodeIfPresent([[String]].self, forKey: .teamPresets) ?? []
        teamPresets = (0..<Self.presetCount).map { presets.indices.contains($0) ? presets[$0] : [] }
        if let level = try c.decodeIfPresent(Int.self, forKey: .playerLevel) {
            playerLevel = level
            xp = try c.decodeIfPresent(Int.self, forKey: .xp) ?? 0
            totalXP = try c.decodeIfPresent(Int.self, forKey: .totalXP) ?? 0
        } else {
            // Saves from before player levels: count the upgrades already made (quietly, no rewards).
            _ = addXP(PlayerLevel.xp(forBallLevels: levels))
        }
        resetAt = try c.decodeIfPresent(Double.self, forKey: .resetAt) ?? 0
        loginStreak = try c.decodeIfPresent(Int.self, forKey: .loginStreak) ?? 0
        lastLoginDay = try c.decodeIfPresent(String.self, forKey: .lastLoginDay) ?? ""
        loginClaimedDay = try c.decodeIfPresent(String.self, forKey: .loginClaimedDay) ?? ""
        questDay = try c.decodeIfPresent(String.self, forKey: .questDay) ?? ""
        questProgress = try c.decodeIfPresent([String: Int].self, forKey: .questProgress) ?? [:]
        questsClaimed = try c.decodeIfPresent([String].self, forKey: .questsClaimed) ?? []
        nextFreeChest = try c.decodeIfPresent(Double.self, forKey: .nextFreeChest) ?? 0
        redeemedVouchers = try c.decodeIfPresent([String].self, forKey: .redeemedVouchers) ?? []
        claimedRoad = try c.decodeIfPresent([Int].self, forKey: .claimedRoad) ?? []
        if let found = try c.decodeIfPresent([String].self, forKey: .foundBalls) {
            foundBalls = Set(found).union(Arenas.tiers[0].balls)
        } else {
            // Saves from before balls had to be found: keep every ball their arenas had unlocked.
            foundBalls = Set(Arenas.tiers.filter { $0.trophies <= bestTrophies }.flatMap(\.balls))
        }
    }

    /// Adds XP and returns the levels reached (rewards are paid by `ProfileStore`).
    mutating func addXP(_ amount: Int) -> [Int] {
        totalXP += amount
        xp += amount
        var reached: [Int] = []
        while let need = PlayerLevel.xpToNext(from: playerLevel), xp >= need {
            xp -= need
            playerLevel += 1
            reached.append(playerLevel)
        }
        if PlayerLevel.xpToNext(from: playerLevel) == nil { xp = 0 }
        return reached
    }
}

/// Loads and saves the profile (UserDefaults) and applies upgrades, rewards and chests.
@Observable
final class ProfileStore {
    private(set) var profile: PlayerProfile {
        didSet { save() }
    }

    /// Level-ups waiting to be celebrated (not saved).
    var levelUps: [LevelUp] = []

    private static let storageKey = "playerProfile.v1"
    private static let savedAtKey = "playerProfile.savedAt"
    private let cloud = NSUbiquitousKeyValueStore.default
    /// Set while adopting a cloud save, so it isn't written straight back.
    private var adoptingCloud = false
    #if DEBUG
    /// App Store screenshots: a showcase profile that is never saved or synced.
    private var isStoreDemo = false
    #endif

    init() {
        #if DEBUG
        if StoreDemo.isActive {
            profile = StoreDemo.profile
            isStoreDemo = true
            return
        }
        #endif
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode(PlayerProfile.self, from: data) {
            profile = saved
        } else {
            profile = Self.freshProfile()
        }
        refreshDaily()
        // Older saves could sit below their best arena's line; lift them back to it.
        if profile.trophies < trophyFloor { profile.trophies = trophyFloor }
        startCloudSync()
    }

    /// A new player's profile: starter coins and chests.
    private static func freshProfile() -> PlayerProfile {
        var fresh = PlayerProfile()
        fresh.coins = Progression.starter.coins
        for kind in Progression.starter.chests { fresh.chests[kind, default: 0] += 1 }
        return fresh
    }

    /// Wipes all progress back to a new player's (here and in iCloud). The chosen name, purchases already
    /// delivered and vouchers already used are kept, so none of them can pay out twice.
    func resetProgress() {
        var fresh = Self.freshProfile()
        fresh.playerName = profile.playerName
        fresh.hasCustomName = profile.hasCustomName
        fresh.deliveredTransactions = profile.deliveredTransactions
        fresh.ownsStarterPack = profile.ownsStarterPack
        fresh.redeemedVouchers = profile.redeemedVouchers
        fresh.resetAt = Date.now.timeIntervalSince1970
        levelUps = []
        profile = fresh
    }

    // MARK: iCloud

    /// The profile is also kept in iCloud (key-value storage), so it follows the player to other devices
    /// and survives reinstalls. When the two differ, the save after the latest reset wins, then the one
    /// with more progress (all-time XP, then best trophies, then the most recent).
    private func startCloudSync() {
        NotificationCenter.default.addObserver(forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                                               object: cloud, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.mergeFromCloud() }
        }
        cloud.synchronize()
        mergeFromCloud()
    }

    private func mergeFromCloud() {
        guard let data = cloud.data(forKey: Self.storageKey),
              let remote = try? JSONDecoder().decode(PlayerProfile.self, from: data) else {
            save()  // Nothing in the cloud yet: upload this device's progress.
            return
        }
        let remoteSavedAt = cloud.double(forKey: Self.savedAtKey)
        let localSavedAt = UserDefaults.standard.double(forKey: Self.savedAtKey)
        let remoteWins = remote.resetAt != profile.resetAt
            ? remote.resetAt > profile.resetAt
            : (remote.totalXP, remote.bestTrophies, remoteSavedAt) > (profile.totalXP, profile.bestTrophies, localSavedAt)
        guard remote != profile else { return }
        guard remoteWins else {
            // This device is ahead (e.g. it just reset): put its save back over the older one.
            save()
            return
        }
        adoptingCloud = true
        profile = remote
        adoptingCloud = false
        UserDefaults.standard.set(data, forKey: Self.storageKey)
        UserDefaults.standard.set(remoteSavedAt, forKey: Self.savedAtKey)
    }

    /// The player's generated name (Game Center's name is preferred when signed in; see `AppModel`).
    var playerName: String { profile.playerName }
    var hasCustomName: Bool { profile.hasCustomName }

    /// Sets the player's chosen name. Returns false if it isn't allowed.
    @discardableResult
    func rename(_ raw: String) -> Bool {
        guard let name = PlayerNames.sanitized(raw) else { return false }
        profile.playerName = name
        profile.hasCustomName = true
        return true
    }

    private func save() {
        #if DEBUG
        guard !isStoreDemo else { return }
        #endif
        guard !adoptingCloud, let data = try? JSONEncoder().encode(profile) else { return }
        let now = Date.now.timeIntervalSince1970
        UserDefaults.standard.set(data, forKey: Self.storageKey)
        UserDefaults.standard.set(now, forKey: Self.savedAtKey)
        cloud.set(data, forKey: Self.storageKey)
        cloud.set(now, forKey: Self.savedAtKey)
    }

    // MARK: Player level

    var playerLevel: Int { profile.playerLevel }
    var xp: Int { profile.xp }
    var xpToNext: Int? { PlayerLevel.xpToNext(from: profile.playerLevel) }

    /// Adds XP; each level reached pays its reward and queues a celebration.
    private func gainXP(_ amount: Int) {
        for level in profile.addXP(amount) {
            let rewards = PlayerLevel.reward(reaching: level)
            award(rewards)
            levelUps.append(LevelUp(level: level, rewards: rewards))
        }
    }

    /// XP the next upgrade of a ball would give.
    func upgradeXP(of id: String) -> Int? {
        upgradeCost(of: id) == nil ? nil : PlayerLevel.upgradeXP(of: id, toLevel: level(of: id) + 1)
    }

    // MARK: Queries

    func level(of id: String) -> Int { profile.levels[id] ?? 1 }

    /// What crusade enemies are leveled around (player level and best balls).
    var crusadePower: Int {
        Crusade.power(playerLevel: profile.playerLevel, ballLevels: unlockedRoster.map { level(of: $0.id) })
    }
    func cards(of id: String) -> Int { profile.cards[id] ?? 0 }

    /// The ball as this player fights with it.
    func definition(_ base: FighterDefinition) -> FighterDefinition {
        Progression.leveled(base, level: level(of: base.id))
    }

    func upgradeCost(of id: String) -> (cards: Int, coins: Int)? {
        Progression.upgradeCost(of: id, from: level(of: id))
    }

    func canUpgrade(_ id: String) -> Bool {
        guard let cost = upgradeCost(of: id) else { return false }
        return cards(of: id) >= cost.cards && profile.coins >= cost.coins
    }

    /// Balls with enough cards and coins for their next level, for the menu badge.
    var upgradesAvailable: Int { FighterCatalog.all.filter { canUpgrade($0.id) }.count }

    // MARK: Changes

    func upgrade(_ id: String) {
        guard canUpgrade(id), let cost = upgradeCost(of: id) else { return }
        profile.cards[id, default: 0] -= cost.cards
        profile.coins -= cost.coins
        profile.levels[id] = level(of: id) + 1
        gainXP(PlayerLevel.upgradeXP(of: id, toLevel: level(of: id)))
        advanceQuest(.upgradeBalls)
    }

    /// Applies coins, chests and trophies. Returns the arena just reached for the first time, if any.
    @discardableResult
    func award(_ rewards: Progression.Rewards) -> ArenaTier? {
        profile.coins += rewards.coins
        for kind in rewards.chests { profile.chests[kind, default: 0] += 1 }
        guard rewards.trophies != 0 else { return nil }
        let previousBest = Arenas.tier(forTrophies: profile.bestTrophies)
        // Once an arena is reached you never drop out of it: losses stop at its trophy line
        // (e.g. reach Green Meadow at 150, lose at 160 → 150, and further losses keep you at 150).
        profile.trophies = max(trophyFloor, profile.trophies + rewards.trophies)
        profile.bestTrophies = max(profile.bestTrophies, profile.trophies)
        let best = Arenas.tier(forTrophies: profile.bestTrophies)
        return best.number > previousBest.number ? best : nil
    }

    // MARK: Arenas

    var trophies: Int { profile.trophies }
    /// The trophy line of the best arena reached: trophies never fall below it.
    var trophyFloor: Int { Arenas.tier(forTrophies: profile.bestTrophies).trophies }
    var bestTrophiesValue: Int { profile.bestTrophies }
    /// The arena your current trophies put you in (battles take place here).
    var arena: ArenaTier { Arenas.tier(forTrophies: profile.trophies) }
    /// The furthest arena reached; its balls and all earlier ones can drop from chests.
    var bestArena: ArenaTier { Arenas.tier(forTrophies: profile.bestTrophies) }

    /// The ball's arena has been reached, so its cards can come out of chests.
    func isInChests(_ id: String) -> Bool { Arenas.tier(unlocking: id).trophies <= profile.bestTrophies }

    /// The player has found the ball (got a card of it) and can play it.
    func isUnlocked(_ id: String) -> Bool { profile.foundBalls.contains(id) }

    /// Balls chests can drop.
    var chestBallIDs: Set<String> { Set(FighterCatalog.all.map(\.id).filter(isInChests)) }

    /// The roster the player can pick from.
    var unlockedRoster: [FighterDefinition] { FighterCatalog.all.filter { isUnlocked($0.id) } }

    // MARK: Shop

    var ownsStarterPack: Bool { profile.ownsStarterPack }

    /// Grants a purchase once per transaction. Returns what was granted, or nil if already delivered.
    @discardableResult
    func deliverPurchase(productID: String, transactionID: String) -> Shop.Contents? {
        guard !profile.deliveredTransactions.contains(transactionID), let offer = Shop.offer(for: productID) else { return nil }
        profile.deliveredTransactions.append(transactionID)
        if offer.oneTime { profile.ownsStarterPack = true }
        let contents = Shop.contents(of: offer, arena: bestArena.number)
        grant(contents)
        return contents
    }

    /// Marks the starter pack as owned without granting it again (restored on a new install).
    func restoreStarterPack() {
        profile.ownsStarterPack = true
    }

    func grant(_ contents: Shop.Contents) {
        profile.coins += contents.coins
        for kind in contents.chests { profile.chests[kind, default: 0] += 1 }
        for (id, count) in contents.cards { addCards(count, of: id) }
    }

    /// Adds cards of a ball; the first card found unlocks it.
    private func addCards(_ count: Int, of id: String) {
        profile.cards[id, default: 0] += count
        profile.foundBalls.insert(id)
    }

    /// Rewarded ads left today for a reward.
    func adsLeft(_ reward: Shop.AdReward) -> Int {
        let watched = profile.adDay == Crusade.dayKey() ? profile.adsWatched[reward.rawValue] ?? 0 : 0
        return max(0, reward.dailyLimit - watched)
    }

    /// Counts a watched ad and grants its reward.
    func recordAd(_ reward: Shop.AdReward) {
        if profile.adDay != Crusade.dayKey() {
            profile.adDay = Crusade.dayKey()
            profile.adsWatched = [:]
        }
        profile.adsWatched[reward.rawValue, default: 0] += 1
        grant(reward.contents)
    }

    /// Lets a ball that fell in today's crusade fight again.
    func revive(_ id: String) {
        profile.crusadeFallen[id] = nil
    }

    // MARK: Team presets

    var teamPresets: [[String]] { profile.teamPresets }

    /// The preset used for ranked arena battles.
    var activePreset: Int { profile.activePreset }

    func setActivePreset(_ index: Int) {
        guard profile.teamPresets.indices.contains(index) else { return }
        profile.activePreset = index
    }

    /// The battle team (leveled), or nil until the active preset holds 3 unlocked balls.
    var battleTeam: [FighterDefinition]? {
        let ids = profile.teamPresets[profile.activePreset].filter(isUnlocked)
        guard ids.count == BotSeries.teamSize else { return nil }
        let team = ids.compactMap(FighterCatalog.definition(id:)).map(definition)
        return team.count == BotSeries.teamSize ? team : nil
    }

    /// Puts a ball in a preset slot (or clears it with nil). A ball already elsewhere in the preset moves here.
    func setPresetSlot(preset: Int, slot: Int, id: String?) {
        guard profile.teamPresets.indices.contains(preset), (0..<3).contains(slot) else { return }
        var team = profile.teamPresets[preset]
        if let id { team.removeAll { $0 == id } }
        var slots: [String?] = (0..<3).map { team.indices.contains($0) ? team[$0] : nil }
        slots[slot] = id
        profile.teamPresets[preset] = slots.compactMap { $0 }
    }

    // MARK: Crusade
    //
    // Crusade progress belongs to one day. Reads treat another day's progress as empty, and the
    // first write of a new day clears it, so nothing changes state while views are drawing.

    private var crusadeIsToday: Bool { profile.crusadeDay == Crusade.dayKey() }

    private func startCrusadeDayIfNeeded() {
        guard !crusadeIsToday else { return }
        profile.crusadeStars = [:]
        profile.crusadeFallen = [:]
        profile.crusadeDay = Crusade.dayKey()
    }

    func stars(chapter: Int, level: Int, difficulty: CrusadeDifficulty) -> Int {
        guard crusadeIsToday else { return 0 }
        return profile.crusadeStars[Crusade.key(chapter: chapter, level: level, difficulty: difficulty)] ?? 0
    }

    func totalStars(chapter: Int, difficulty: CrusadeDifficulty) -> Int {
        Crusade.chapters[chapter].levels.reduce(0) { $0 + stars(chapter: chapter, level: $1.number, difficulty: difficulty) }
    }

    func isBossBeaten(chapter: Int, difficulty: CrusadeDifficulty) -> Bool {
        stars(chapter: chapter, level: Crusade.chapters[chapter].levels.count, difficulty: difficulty) > 0
    }

    /// Normal: levels open in order, and a map opens once the previous map's Normal boss falls.
    /// Hard: a map's Hard opens once its own Normal boss falls, then levels open in order.
    func isUnlocked(chapter: Int, level: Int, difficulty: CrusadeDifficulty) -> Bool {
        if level > 1 { return stars(chapter: chapter, level: level - 1, difficulty: difficulty) > 0 }
        switch difficulty {
        case .normal: return chapter == 0 || isBossBeaten(chapter: chapter - 1, difficulty: .normal)
        case .hard: return isBossBeaten(chapter: chapter, difficulty: .normal)
        }
    }

    /// Knocked out in today's crusade, so it can't be sent again until the reset.
    func isResting(_ id: String) -> Bool {
        crusadeIsToday && profile.crusadeFallen[id] != nil
    }

    var crusadeTeam: [String]? { profile.crusadeTeam }

    func setCrusadeTeam(_ ids: [String]) {
        guard profile.crusadeTeam != ids else { return }
        profile.crusadeTeam = ids
    }

    func markFallen(_ id: String) {
        startCrusadeDayIfNeeded()
        profile.crusadeFallen[id] = Date.now.timeIntervalSince1970
    }

    /// Saves a win and returns today's first-clear reward (empty when replaying a level cleared today).
    func completeLevel(chapter: Int, level: Int, difficulty: CrusadeDifficulty, stars: Int) -> Progression.Rewards {
        startCrusadeDayIfNeeded()
        let key = Crusade.key(chapter: chapter, level: level, difficulty: difficulty)
        let previous = profile.crusadeStars[key] ?? 0
        let rewards = previous == 0 ? Crusade.firstClearReward(chapter: chapter, level: level, difficulty: difficulty)
                                    : Progression.Rewards()
        profile.crusadeStars[key] = max(previous, stars)
        award(rewards)
        advanceQuest(.clearCrusade)
        return rewards
    }

    var totalChests: Int { profile.chests.values.reduce(0, +) }

    func chestCount(_ kind: ChestKind) -> Int { profile.chests[kind] ?? 0 }

    /// Opens one chest of a type and adds its contents.
    func openChest(_ kind: ChestKind) -> ChestOpening? {
        guard chestCount(kind) > 0 else { return nil }
        let before = profile.foundBalls
        let contents = takeChest(kind)
        advanceQuest(.openChests)
        return ChestOpening(kind: kind, contents: contents, newBalls: Set(contents.cards.map(\.id)).subtracting(before))
    }

    /// Opens every chest at once; the cards are merged into one reveal, shown as the best chest opened.
    func openAllChests() -> ChestOpening? {
        guard let best = ChestKind.allCases.last(where: { chestCount($0) > 0 }) else { return nil }
        let before = profile.foundBalls
        var coins = 0, count = 0
        var cards: [String: Int] = [:]
        for kind in ChestKind.allCases {
            for _ in 0..<chestCount(kind) {
                let contents = takeChest(kind)
                coins += contents.coins
                count += 1
                for stack in contents.cards { cards[stack.id, default: 0] += stack.count }
            }
        }
        advanceQuest(.openChests, by: count)
        let merged = cards.map { (id: $0.key, count: $0.value) }
            .sorted { (Progression.rarity(of: $0.id), $0.count) > (Progression.rarity(of: $1.id), $1.count) }
        return ChestOpening(kind: best, contents: Progression.ChestContents(coins: coins, cards: merged),
                            count: count, newBalls: Set(cards.keys).subtracting(before))
    }

    // MARK: Trophy road

    func isClaimed(_ reward: TrophyReward) -> Bool { profile.claimedRoad.contains(reward.trophies) }
    func isReached(_ reward: TrophyReward) -> Bool { profile.bestTrophies >= reward.trophies }
    func canClaim(_ reward: TrophyReward) -> Bool { isReached(reward) && !isClaimed(reward) }
    var roadRewardsReady: Int { TrophyRoad.rewards.filter(canClaim).count }

    /// Pays a trophy road reward once. Card rewards go to a random found ball of that rarity
    /// (or the best rarity below it the player has).
    func claim(_ reward: TrophyReward) -> Shop.Contents? {
        guard canClaim(reward) else { return nil }
        var contents = Shop.Contents()
        switch reward.kind {
        case .coins(let amount): contents.coins = amount
        case .chest(let kind): contents.chests = [kind]
        case .cards(let rarity, let count):
            let found = FighterCatalog.all.filter { isUnlocked($0.id) }
            let best = Rarity.allCases.reversed().first { r in r <= rarity && found.contains { $0.rarity == r } }
            guard let ball = found.filter({ $0.rarity == best }).randomElement() else { return nil }
            contents.cards = [ball.id: count]
        }
        profile.claimedRoad.append(reward.trophies)
        grant(contents)
        return contents
    }

    // MARK: Vouchers

    func hasRedeemed(_ code: String) -> Bool { profile.redeemedVouchers.contains(code) }

    /// Pays a voucher once; false if this player already used it.
    func redeemVoucher(_ code: String, rewards: Progression.Rewards) -> Bool {
        guard !hasRedeemed(code) else { return false }
        profile.redeemedVouchers.append(code)
        award(rewards)
        return true
    }

    // MARK: Daily

    /// Rolls the daily state over to today: extends (or restarts) the login streak and starts today's quests.
    /// Called on launch and whenever the menu or daily screen shows.
    func refreshDaily(now: Date = .now) {
        let today = Crusade.dayKey(now)
        if profile.lastLoginDay != today {
            let continues = Daily.dayBefore(today) == profile.lastLoginDay && profile.loginStreak < Daily.loginRewards.count
            profile.loginStreak = continues ? profile.loginStreak + 1 : 1
            profile.lastLoginDay = today
        }
        if profile.questDay != today {
            profile.questDay = today
            profile.questProgress = [:]
            profile.questsClaimed = []
        }
    }

    var todaysQuests: [DailyQuest] { Daily.quests(for: profile.questDay) }

    /// Today's login streak reward, if not collected yet.
    var loginRewardReady: Bool { profile.loginStreak > 0 && profile.loginClaimedDay != profile.lastLoginDay }

    func claimLoginReward() -> Progression.Rewards? {
        guard loginRewardReady else { return nil }
        let rewards = Daily.loginRewards[profile.loginStreak - 1]
        profile.loginClaimedDay = profile.lastLoginDay
        award(rewards)
        return rewards
    }

    func questProgress(_ quest: DailyQuest) -> Int { min(quest.target, profile.questProgress[quest.kind.rawValue] ?? 0) }
    func isClaimed(_ quest: DailyQuest) -> Bool { profile.questsClaimed.contains(quest.kind.rawValue) }
    func canClaim(_ quest: DailyQuest) -> Bool { !isClaimed(quest) && questProgress(quest) >= quest.target }

    /// Counts toward today's quest of this kind, if there is one.
    func advanceQuest(_ kind: DailyQuest.Kind, by amount: Int = 1) {
        refreshDaily()
        guard amount > 0, todaysQuests.contains(where: { $0.kind == kind }) else { return }
        profile.questProgress[kind.rawValue, default: 0] += amount
    }

    func claim(_ quest: DailyQuest) -> Progression.Rewards? {
        guard canClaim(quest) else { return nil }
        profile.questsClaimed.append(quest.kind.rawValue)
        award(quest.reward)
        return quest.reward
    }

    private static let questBonusKey = "bonus"
    var questBonusClaimed: Bool { profile.questsClaimed.contains(Self.questBonusKey) }
    var questBonusReady: Bool { !questBonusClaimed && todaysQuests.allSatisfy(isClaimed) }

    func claimQuestBonus() -> Progression.Rewards? {
        guard questBonusReady else { return nil }
        profile.questsClaimed.append(Self.questBonusKey)
        award(Daily.questBonus)
        return Daily.questBonus
    }

    var nextFreeChest: Date { Date(timeIntervalSince1970: profile.nextFreeChest) }
    func freeChestReady(now: Date = .now) -> Bool { now >= nextFreeChest }

    func claimFreeChest(now: Date = .now) -> Bool {
        guard freeChestReady(now: now) else { return false }
        profile.nextFreeChest = now.addingTimeInterval(Daily.freeChestInterval).timeIntervalSince1970
        award(Progression.Rewards(chests: [Daily.freeChest]))
        return true
    }

    /// Things waiting to be collected on the daily screen (for the menu badge).
    func dailyClaimable(now: Date = .now) -> Int {
        (loginRewardReady ? 1 : 0) + (freeChestReady(now: now) ? 1 : 0)
            + todaysQuests.filter(canClaim).count + (questBonusReady ? 1 : 0)
    }

    /// Removes one chest and adds what was inside.
    private func takeChest(_ kind: ChestKind) -> Progression.ChestContents {
        var rng = SystemRandomNumberGenerator()
        let undiscovered = chestBallIDs.subtracting(profile.foundBalls)
        let contents = Progression.openChest(kind, unlocked: chestBallIDs, undiscovered: undiscovered, using: &rng)
        profile.chests[kind] = chestCount(kind) - 1
        profile.coins += contents.coins
        for stack in contents.cards { addCards(stack.count, of: stack.id) }
        return contents
    }
}

extension Rarity {
    var color: Color {
        switch self {
        case .common: return Color(red: 0.62, green: 0.72, blue: 0.8)
        case .rare: return Color(red: 0.25, green: 0.65, blue: 1)
        case .epic: return Color(red: 0.7, green: 0.35, blue: 0.95)
        case .legendary: return Color(red: 1, green: 0.72, blue: 0.15)
        }
    }
}
