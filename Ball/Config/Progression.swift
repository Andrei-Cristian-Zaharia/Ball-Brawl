import Foundation

// MARK: - Rarity

/// Higher rarity balls are stronger at every level, but their cards drop less often.
nonisolated enum Rarity: Int, CaseIterable, Comparable {
    case common, rare, epic, legendary

    var name: String { ["Common", "Rare", "Epic", "Legendary"][rawValue] }

    /// HP and damage multiplier, on top of the level bonus.
    var power: Double { [1.0, 1.08, 1.16, 1.25][rawValue] }

    /// Relative chance that a chest card stack is this rarity.
    var dropWeight: Double { [50, 28, 14, 8][rawValue] }

    /// Cards in one chest stack of this rarity.
    var stackSize: ClosedRange<Int> { [5...8, 3...5, 2...3, 1...2][rawValue] }

    /// Cards needed to go from level `i + 1` to `i + 2`: doubling early, then still climbing steeply.
    var cardCosts: [Int] {
        switch self {
        case .common: return [2, 4, 8, 16, 30, 50, 80, 120, 180, 250, 350, 500, 700, 1000]
        case .rare: return [1, 2, 4, 8, 15, 25, 40, 60, 90, 130, 180, 250, 350, 500]
        case .epic: return [1, 1, 2, 4, 6, 10, 15, 20, 30, 40, 55, 75, 100, 140]
        case .legendary: return [1, 1, 1, 2, 2, 3, 4, 6, 8, 10, 13, 17, 22, 30]
        }
    }

    /// Multiplier on `Progression.coinCosts`.
    var coinFactor: Double { [1, 1.25, 1.5, 2][rawValue] }

    static func < (a: Rarity, b: Rarity) -> Bool { a.rawValue < b.rawValue }
}

// MARK: - Star powers

/// A perk unlocked at a milestone level; it tweaks the ball's attack settings.
nonisolated struct StarPower {
    let level: Int
    let name: String
    let description: String
    let apply: (inout AttackSpec) -> Void
    /// Perks, side abilities and Ultimates this star power unlocks.
    let ability: (inout BallAbilities) -> Void

    init(_ level: Int, _ name: String, _ description: String, _ apply: @escaping (inout AttackSpec) -> Void) {
        self.level = level
        self.name = name
        self.description = description
        self.apply = apply
        self.ability = { _ in }
    }

    init(_ level: Int, _ name: String, _ description: String, ability: @escaping (inout BallAbilities) -> Void = { _ in },
         attack: @escaping (inout AttackSpec) -> Void = { _ in }) {
        self.level = level
        self.name = name
        self.description = description
        self.apply = attack
        self.ability = ability
    }
}

// MARK: - Progression rules (edit these to rebalance)

nonisolated enum Progression {
    static let maxLevel = 15
    /// Levels that unlock a star power; the last one is the ball's Ultimate.
    static let starLevels = [5, 10, 15]
    /// HP and damage added per level above 1 (both scale, so each level is ~15% stronger overall;
    /// level 15 has about double the HP and damage of level 1).
    static let powerPerLevel = 0.07
    /// Coins to go from level `i + 1` to `i + 2`, before the rarity factor.
    static let coinCosts = [20, 50, 100, 200, 400, 700, 1100, 1700, 2500, 3600, 5000, 7000, 10000, 14000]

    struct Rewards: Equatable {
        var coins = 0
        var chests: [ChestKind] = []
        /// Trophy change (negative for a loss).
        var trophies = 0

        static func + (a: Rewards, b: Rewards) -> Rewards {
            Rewards(coins: a.coins + b.coins, chests: a.chests + b.chests, trophies: a.trophies + b.trophies)
        }
    }

    /// A ranked win pays coins and trophies; chests come from the trophy road (`TrophyRoad`) instead.
    static let onlineWin = Rewards(coins: 40, trophies: Arenas.onlineWin)
    static let onlineLoss = Rewards(coins: 15, trophies: Arenas.onlineLoss)
    static let onlineDraw = Rewards(coins: 20)
    static let botRoundWin = Rewards(coins: 15)
    static let botSeriesWin = Rewards(coins: 50, chests: [.wooden])
    static let botSeriesLoss = Rewards(coins: 10)

    /// What a new player starts with.
    static let starter = Rewards(coins: 100, chests: [.silver])

    /// Weaker balls get the higher rarities, so the power tier also evens the roster out.
    static func rarity(of id: String) -> Rarity {
        switch id {
        case "eclipse", "weaver", "hive", "harpoon", "clockwork", "portal", "glitch": return .legendary
        case "gambit", "vampire", "pulse", "blaster", "grappler", "fibonacci", "wizard", "twin": return .epic
        case "conductor", "spike", "virus", "dice", "icecone", "zone", "wolf", "cell": return .rare
        default: return .common
        }
    }

    /// Combined HP and damage multiplier for a ball at a level.
    static func power(of id: String, level: Int) -> Double {
        rarity(of: id).power * (1 + powerPerLevel * Double(level - 1))
    }

    /// Cards and coins to upgrade from `level`, or nil at max level.
    static func upgradeCost(of id: String, from level: Int) -> (cards: Int, coins: Int)? {
        guard level < maxLevel else { return nil }
        let rarity = rarity(of: id)
        return (rarity.cardCosts[level - 1], Int((Double(coinCosts[level - 1]) * rarity.coinFactor).rounded()))
    }

    /// The ball as it fights at `level`: rarity and level scale its health and damage,
    /// and unlocked star powers adjust its attack.
    static func leveled(_ base: FighterDefinition, level: Int) -> FighterDefinition {
        let level = max(1, min(maxLevel, level))
        let power = power(of: base.id, level: level)
        var attack = base.attack
        var abilities = BallAbilities()
        for star in starPowers(for: base.id) where level >= star.level {
            star.apply(&attack)
            star.ability(&abilities)
        }
        return FighterDefinition(id: base.id, name: base.name, tagline: base.tagline, attackName: base.attackName,
                                 attackDescription: base.attackDescription, maxHealth: (base.maxHealth * power).rounded(),
                                 radius: base.radius, mass: base.mass, attack: attack, level: level, damageScale: power, abilities: abilities)
    }

    /// Every ball's star powers: two at levels 5 and 10, and a much stronger Ultimate at 15.
    static func starPowers(for id: String) -> [StarPower] {
        abilityStarPowers(for: id) ?? baseStarPowers(for: id) + [ultimate(for: id)].compactMap { $0 }
    }

    /// The level-15 Ultimate: a big upgrade to everything the ball does best.
    private static func ultimate(for id: String) -> StarPower? {
        let level = starLevels.last!
        switch id {
        case "blaster": return StarPower(level, "Overcharge", "Fires 20% faster with bigger bolts that hit 10 harder.") { if case .projectile(var a) = $0 { a.interval *= 0.8; a.projectileRadius += 4; a.damage += 10; $0 = .projectile(a) } }
        case "spike": return StarPower(level, "Juggernaut", "Rams hit 6–12 harder and recover 20% faster.") { if case .contact(var a) = $0 { a.minDamage += 6; a.maxDamage += 12; a.cooldown *= 0.8; $0 = .contact(a) } }
        case "pulse": return StarPower(level, "Shockstorm", "Shockwave reaches 40 further and pulses every 1.6s.") { if case .pulse(var a) = $0 { a.range += 40; a.interval = min(a.interval, 1.6); $0 = .pulse(a) } }
        case "grappler": return StarPower(level, "Titan Grip", "Grabs from 30 further and wall slams deal 14 more.") { if case .grab(var a) = $0 { a.reach += 30; a.smashDamage += 14; $0 = .grab(a) } }
        case "weaver": return StarPower(level, "Grand Web", "Two more threads at a time, each dealing 3 more.") { if case .web(var a) = $0 { a.maxThreads += 2; a.damage += 3; $0 = .web(a) } }
        case "vampire": return StarPower(level, "Night Lord", "Drains 8 more per second and heals even more.") { if case .drain(var a) = $0 { a.drainPerSecond += 8; a.healFraction += 0.2; $0 = .drain(a) } }
        case "gambit": return StarPower(level, "Grandmaster", "Moves hit 14 harder and come faster.") { if case .chess(var a) = $0 { a.damage += 14; a.interval -= 0.2; $0 = .chess(a) } }
        case "eclipse": return StarPower(level, "Total Eclipse", "Charges 1.5s faster and totality deals 18 more.") { if case .eclipse(var a) = $0 { a.chargeTime -= 1.5; a.damage += 18; $0 = .eclipse(a) } }
        case "shackle": return StarPower(level, "Warden", "One more trap; traps hold 0.6s longer and bite 10 harder.") { if case .arsenal(.traps(var a)) = $0 { a.maxTraps += 1; a.holdDuration += 0.6; a.damage += 10; $0 = .arsenal(.traps(a)) } }
        case "conductor": return StarPower(level, "Bullet Train", "New track 0.6s sooner and trains deal 14 more.") { if case .arsenal(.train(var a)) = $0 { a.cooldown -= 0.6; a.damage += 14; $0 = .arsenal(.train(a)) } }
        case "laser": return StarPower(level, "Death Ray", "Two more beams, burning 2 more.") { if case .arsenal(.laser(var a)) = $0 { a.maxLasers += 2; a.damage += 2; $0 = .arsenal(.laser(a)) } }
        case "zone": return StarPower(level, "Dominion", "Zones are 20 bigger and burn 6 more per second.") { if case .arsenal(.zone(var a)) = $0 { a.radius += 20; a.damagePerSecond += 6; $0 = .arsenal(.zone(a)) } }
        case "dice": return StarPower(level, "Jackpot", "Two more dice, and every pip hurts 1 more.") { if case .arsenal(.dice(var a)) = $0 { a.maxDice += 2; a.damagePerPip += 1; $0 = .arsenal(.dice(a)) } }
        case "glass": return StarPower(level, "Shatterstorm", "Up to 4 more shards, each dealing 1.5 more.") { if case .arsenal(.shards(var a)) = $0 { a.maxShards += 4; a.damage += 1.5; $0 = .arsenal(.shards(a)) } }
        case "thief": return StarPower(level, "Master Thief", "Steals 15% more health and pickpocket throws 2 more knives.") { if case .arsenal(.knives(var a)) = $0 { a.stealFraction += 0.15; a.pickpocketKnives += 2; $0 = .arsenal(.knives(a)) } }
        case "snake": return StarPower(level, "Basilisk", "Tail grows faster and hits 8 harder.") { if case .arsenal(.tail(var a)) = $0 { a.growInterval -= 0.15; a.damage += 8; $0 = .arsenal(.tail(a)) } }
        case "electric": return StarPower(level, "Thunder God", "Each charge adds 2 more damage and lightning arcs 50 further.") { if case .arsenal(.shock(var a)) = $0 { a.damagePerCharge += 2; a.arcRange += 50; $0 = .arsenal(.shock(a)) } }
        case "icecone": return StarPower(level, "Absolute Zero", "Freezes 0.6s longer and bursts into 6 more spikes.") { if case .arsenal(.bombs(var a)) = $0 { a.freezeDuration += 0.6; a.spikes += 6; $0 = .arsenal(.bombs(a)) } }
        case "cannon": return StarPower(level, "Fortress", "Two more turrets, with shots dealing 4 more.") { if case .arsenal(.turrets(var a)) = $0 { a.maxTurrets += 2; a.damage += 4; $0 = .arsenal(.turrets(a)) } }
        case "bomb": return StarPower(level, "Megaton", "Even bigger blasts that hit 14 harder.") { if case .arsenal(.bombs(var a)) = $0 { a.radius += 25; a.damage += 14; $0 = .arsenal(.bombs(a)) } }
        case "virus": return StarPower(level, "Plague", "Poison lasts 2s longer and stacks much higher.") { if case .arsenal(.virus(var a)) = $0 { a.duration += 2; a.maxDamagePerSecond += 3; $0 = .arsenal(.virus(a)) } }
        case "harpoon": return StarPower(level, "Leviathan", "Harpoon hits 8 harder and fires 0.4s sooner.") { if case .arsenal(.harpoon(var a)) = $0 { a.damage += 8; a.interval = max(0.6, a.interval - 0.4); $0 = .arsenal(.harpoon(a)) } }
        case "hive": return StarPower(level, "Queen Bee", "Releases two more bees that chase 2s longer.") { if case .arsenal(.swarm(var a)) = $0 { a.bees += 2; a.lifetime += 2; $0 = .arsenal(.swarm(a)) } }
        default: return nil
        }
    }

    private static func baseStarPowers(for id: String) -> [StarPower] {
        switch id {
        case "blaster": return [
            StarPower(5, "Rapid Fire", "Fires 25% faster.") { if case .projectile(var a) = $0 { a.interval *= 0.75; $0 = .projectile(a) } },
            StarPower(10, "Big Bolt", "Bigger bolts that hit 12 harder.") { if case .projectile(var a) = $0 { a.projectileRadius += 6; a.damage += 12; $0 = .projectile(a) } },
        ]
        case "spike": return [
            StarPower(5, "Sharpened", "Rams hit 3–6 harder.") { if case .contact(var a) = $0 { a.minDamage += 3; a.maxDamage += 6; $0 = .contact(a) } },
            StarPower(10, "Quick Recovery", "Can ram again sooner (0.45s).") { if case .contact(var a) = $0 { a.cooldown = 0.45; $0 = .contact(a) } },
        ]
        case "pulse": return [
            StarPower(5, "Wide Wave", "Shockwave reaches 30 further.") { if case .pulse(var a) = $0 { a.range += 30; $0 = .pulse(a) } },
            StarPower(10, "Aftershock", "Pulses every 2s.") { if case .pulse(var a) = $0 { a.interval = 2; $0 = .pulse(a) } },
        ]
        case "grappler": return [
            StarPower(5, "Long Arms", "Grabs from 20 further away.") { if case .grab(var a) = $0 { a.reach += 20; $0 = .grab(a) } },
            StarPower(10, "Wrecking Ball", "Wall slams deal 8 more.") { if case .grab(var a) = $0 { a.smashDamage += 8; $0 = .grab(a) } },
        ]
        case "weaver": return [
            StarPower(5, "Extra Thread", "One more web thread at a time.") { if case .web(var a) = $0 { a.maxThreads += 1; $0 = .web(a) } },
            StarPower(10, "Steel Silk", "Threads deal 2 more.") { if case .web(var a) = $0 { a.damage += 2; $0 = .web(a) } },
        ]
        case "vampire": return [
            StarPower(5, "Thirst", "Drains 4 more per second.") { if case .drain(var a) = $0 { a.drainPerSecond += 4; $0 = .drain(a) } },
            StarPower(10, "Blood Pact", "Latches on again 1s sooner, heals more and can overheal 25 further.") { if case .drain(var a) = $0 { a.cooldown -= 1; a.healFraction += 0.2; a.maxOverheal += 25; $0 = .drain(a) } },
        ]
        case "gambit": return [
            StarPower(5, "Opening Theory", "Thinks and moves faster.") { if case .chess(var a) = $0 { a.thinkDuration = 0.15; a.interval -= 0.2; $0 = .chess(a) } },
            StarPower(10, "Checkmate", "Moves hit 8 harder.") { if case .chess(var a) = $0 { a.damage += 8; $0 = .chess(a) } },
        ]
        case "eclipse": return [
            StarPower(5, "Waxing Moon", "Charges 1.2s faster.") { if case .eclipse(var a) = $0 { a.chargeTime -= 1.2; $0 = .eclipse(a) } },
            StarPower(10, "Blood Moon", "Totality deals 12 more.") { if case .eclipse(var a) = $0 { a.damage += 12; $0 = .eclipse(a) } },
        ]
        case "shackle": return [
            StarPower(5, "Extra Trap", "One more trap on the field, and traps bite 4 harder.") { if case .arsenal(.traps(var a)) = $0 { a.maxTraps += 1; a.damage += 4; $0 = .arsenal(.traps(a)) } },
            StarPower(10, "Iron Grip", "Traps hold 0.6s longer and bite 8 harder.") { if case .arsenal(.traps(var a)) = $0 { a.holdDuration += 0.6; a.damage += 8; $0 = .arsenal(.traps(a)) } },
        ]
        case "conductor": return [
            StarPower(5, "Express", "New track 0.6s sooner.") { if case .arsenal(.train(var a)) = $0 { a.cooldown -= 0.6; $0 = .arsenal(.train(a)) } },
            StarPower(10, "Heavy Freight", "Trains deal 10 more.") { if case .arsenal(.train(var a)) = $0 { a.damage += 10; $0 = .arsenal(.train(a)) } },
        ]
        case "laser": return [
            StarPower(5, "Overclock", "One more beam (6).") { if case .arsenal(.laser(var a)) = $0 { a.maxLasers += 1; $0 = .arsenal(.laser(a)) } },
            StarPower(10, "Searing Beam", "Beams burn 1.5 more.") { if case .arsenal(.laser(var a)) = $0 { a.damage += 1.5; $0 = .arsenal(.laser(a)) } },
        ]
        case "zone": return [
            StarPower(5, "Wide Turf", "Zones are 15 bigger.") { if case .arsenal(.zone(var a)) = $0 { a.radius += 15; $0 = .arsenal(.zone(a)) } },
            StarPower(10, "Sanctuary", "Zones burn 4 more per second and heal 2 more.") { if case .arsenal(.zone(var a)) = $0 { a.damagePerSecond += 4; a.healPerSecond += 2; $0 = .arsenal(.zone(a)) } },
        ]
        case "dice": return [
            StarPower(5, "Loaded", "Its own dice no longer hurt it.") { if case .arsenal(.dice(var a)) = $0 { a.selfDamagePerPip = 0; $0 = .arsenal(.dice(a)) } },
            StarPower(10, "High Roller", "Two more dice on the field, and every pip hurts more.") { if case .arsenal(.dice(var a)) = $0 { a.maxDice += 2; a.damagePerPip += 0.6; $0 = .arsenal(.dice(a)) } },
        ]
        case "glass": return [
            StarPower(5, "Shrapnel", "Up to 3 more shards.") { if case .arsenal(.shards(var a)) = $0 { a.maxShards += 3; $0 = .arsenal(.shards(a)) } },
            StarPower(10, "Razor Glass", "Shards deal 1 more.") { if case .arsenal(.shards(var a)) = $0 { a.damage += 1; $0 = .arsenal(.shards(a)) } },
        ]
        case "thief": return [
            StarPower(5, "Sticky Fingers", "Steals 10% more health.") { if case .arsenal(.knives(var a)) = $0 { a.stealFraction += 0.1; $0 = .arsenal(.knives(a)) } },
            StarPower(10, "Quick Hands", "Pickpocket throws one more knife.") { if case .arsenal(.knives(var a)) = $0 { a.pickpocketKnives += 1; $0 = .arsenal(.knives(a)) } },
        ]
        case "snake": return [
            StarPower(5, "Venom Fangs", "Tail grows a bit faster and hits 2 harder.") { if case .arsenal(.tail(var a)) = $0 { a.growInterval -= 0.1; a.damage += 2; $0 = .arsenal(.tail(a)) } },
            StarPower(10, "Constrictor", "Tail hits 6 harder and can hit again sooner.") { if case .arsenal(.tail(var a)) = $0 { a.damage += 6; a.hitCooldown = 0.3; $0 = .arsenal(.tail(a)) } },
        ]
        case "electric": return [
            StarPower(5, "Live Wire", "Each stored charge adds 1 more damage.") { if case .arsenal(.shock(var a)) = $0 { a.damagePerCharge += 1; $0 = .arsenal(.shock(a)) } },
            StarPower(10, "Storm", "Lightning arcs 50 further and recharges faster.") { if case .arsenal(.shock(var a)) = $0 { a.arcRange += 50; a.cooldown -= 0.4; $0 = .arsenal(.shock(a)) } },
        ]
        case "icecone": return [
            StarPower(5, "Deep Freeze", "Freezes 0.4s longer.") { if case .arsenal(.bombs(var a)) = $0 { a.freezeDuration += 0.4; $0 = .arsenal(.bombs(a)) } },
            StarPower(10, "Blizzard", "Bursts into 6 more spikes.") { if case .arsenal(.bombs(var a)) = $0 { a.spikes += 6; $0 = .arsenal(.bombs(a)) } },
        ]
        case "cannon": return [
            StarPower(5, "Battery", "One more turret (6).") { if case .arsenal(.turrets(var a)) = $0 { a.maxTurrets += 1; $0 = .arsenal(.turrets(a)) } },
            StarPower(10, "Heavy Shells", "Turret shots deal 3 more.") { if case .arsenal(.turrets(var a)) = $0 { a.damage += 3; $0 = .arsenal(.turrets(a)) } },
        ]
        case "bomb": return [
            StarPower(5, "Short Fuse", "Bombs go off 0.4s sooner and hit 4 harder.") { if case .arsenal(.bombs(var a)) = $0 { a.fuse -= 0.4; a.damage += 4; $0 = .arsenal(.bombs(a)) } },
            StarPower(10, "Big Bang", "Bigger blasts that hit 8 harder.") { if case .arsenal(.bombs(var a)) = $0 { a.radius += 30; a.damage += 8; $0 = .arsenal(.bombs(a)) } },
        ]
        case "virus": return [
            StarPower(5, "Contagious", "Poison lasts 2s longer.") { if case .arsenal(.virus(var a)) = $0 { a.duration += 2; $0 = .arsenal(.virus(a)) } },
            StarPower(10, "Pandemic", "Poison stacks higher.") { if case .arsenal(.virus(var a)) = $0 { a.damagePerSecond += 0.5; a.maxDamagePerSecond += 2; $0 = .arsenal(.virus(a)) } },
        ]
        case "harpoon": return [
            StarPower(5, "Barbed", "Harpoon hits 3 harder.") { if case .arsenal(.harpoon(var a)) = $0 { a.damage += 3; $0 = .arsenal(.harpoon(a)) } },
            StarPower(10, "Quick Reel", "Fires 0.4s sooner.") { if case .arsenal(.harpoon(var a)) = $0 { a.interval -= 0.4; $0 = .arsenal(.harpoon(a)) } },
        ]
        case "hive": return [
            StarPower(5, "Long Flight", "Bees chase 2.5s longer.") { if case .arsenal(.swarm(var a)) = $0 { a.lifetime += 2.5; $0 = .arsenal(.swarm(a)) } },
            StarPower(10, "Bigger Swarm", "Releases one more bee.") { if case .arsenal(.swarm(var a)) = $0 { a.bees += 1; $0 = .arsenal(.swarm(a)) } },
        ]
        default: return []
        }
    }

    // MARK: Chests

    struct ChestContents: Equatable {
        var coins: Int
        /// Card stacks, one per ball (ids may come from any rarity).
        var cards: [(id: String, count: Int)]

        static func == (a: ChestContents, b: ChestContents) -> Bool {
            a.coins == b.coins && a.cards.map(\.id) == b.cards.map(\.id) && a.cards.map(\.count) == b.cards.map(\.count)
        }
    }
}
