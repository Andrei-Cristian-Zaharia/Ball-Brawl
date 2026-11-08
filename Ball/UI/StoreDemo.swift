#if DEBUG
import Foundation

/// App Store screenshots (debug builds only): launch with `-storeDemo <scene>` to open that screen on a
/// fixed showcase profile that is never saved or synced. `-demoTime` and `-demoSeed` pick the moment of
/// the abilities fight; `-storeArt <folder>` renders the marketing images instead (see `StoreArt`).
enum StoreDemo {
    enum Scene: String { case abilities, daily, collection, arenas, modes, crusade }

    static let scene: Scene? = argument("-storeDemo").flatMap(Scene.init(rawValue:))
    static var isActive: Bool { scene != nil || argument("-storeArt") != nil }

    static func argument(_ name: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    static var battleTime: Double { argument("-demoTime").flatMap(Double.init) ?? 27 }
    static var battleSeed: UInt64 { argument("-demoSeed").flatMap(UInt64.init) ?? 7 }

    static let playerTeam = ["wizard", "electric", "cannon"]
    static let opponentName = "FrostyStorm"
    static let opponentTeam = ["wolf", "vampire", "bomb"]
    static let opponentLevel = 9

    /// A player well into the game: Royal Arena, level 18, every ball found, chests waiting.
    static var profile: PlayerProfile {
        var p = PlayerProfile()
        p.coins = 12_450
        p.trophies = 2_140
        p.bestTrophies = 2_140
        p.playerName = "BallMaster"
        p.hasCustomName = true
        p.playerLevel = 18
        p.xp = 210
        p.totalXP = 9_000
        p.chests = [.magic: 1, .gold: 2, .silver: 3]
        p.foundBalls = Set(FighterCatalog.all.map(\.id))
        for (i, ball) in FighterCatalog.all.enumerated() {
            let base = [10, 9, 8, 7][Progression.rarity(of: ball.id).rawValue]
            let level = base - (i % 3)
            p.levels[ball.id] = level
            // Every third ball has the cards for its next level.
            let need = Progression.upgradeCost(of: ball.id, from: level)?.cards ?? 0
            p.cards[ball.id] = i % 3 == 0 ? need : need / 2
        }
        p.levels["wizard"] = 10
        p.teamPresets = [playerTeam, [], []]
        p.claimedRoad = TrophyRoad.rewards.filter { $0.trophies <= p.bestTrophies }.map(\.trophies)
        let today = Crusade.dayKey()
        p.lastLoginDay = today
        p.loginStreak = 5
        p.questDay = today
        for (i, quest) in Daily.quests(for: today).enumerated() {
            p.questProgress[quest.kind.rawValue] = i == 2 ? quest.target : max(1, quest.target / 2)
        }
        p.crusadeDay = today
        p.crusadeTeam = playerTeam
        p.nextFreeChest = 0
        return p
    }
}

extension AppModel {
    /// Opens the screen a `-storeDemo` launch asked for.
    func startStoreDemo() {
        #if os(iOS)
        if StoreDemo.argument("-storeArt") != nil {
            DispatchQueue.main.async { StoreArt.runIfAsked() }
            return
        }
        #endif
        switch StoreDemo.scene {
        case .daily: openDaily()
        case .collection: openCollection()
        case .arenas: openArenas()
        case .crusade: openCrusade()
        case .abilities: startStoreDemoBattle()
        case .modes, nil: break
        }
    }
}
#endif
