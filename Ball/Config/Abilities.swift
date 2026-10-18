import Foundation

// MARK: - Ball abilities (edit these to tune perks, side abilities and Ultimates)

/// Extras a ball's star powers can unlock on top of its main attack:
/// a perk (changes how the main attack behaves), a side ability (a small helper attack on its own timer)
/// and an Ultimate (charges from damage dealt and taken, then fires on its own).
/// Damage numbers here are base values; like every hit, they scale with the ball's rarity and level.
nonisolated struct BallAbilities: Equatable {
    var perk: Perk?
    var side: SideAbility?
    var ultimate: Ultimate?
}

/// Something extra a hit does to the enemy.
nonisolated enum HitEffect: Equatable {
    /// Slows the enemy by `amount` (0.3 = 30%) for `duration`.
    case slow(amount: Double, duration: Double)
    /// Poison (or bleed) damage over time.
    case poison(perSecond: Double, duration: Double)
    /// Locks the enemy in place.
    case stun(duration: Double, style: HoldStyle)
    /// Heals the attacker.
    case heal(amount: Double)
}

nonisolated enum Perk: Equatable {
    /// Every hit the ball lands also does `effect` (at most once per `cooldown`).
    case onHit(HitEffect, cooldown: Double)
    /// Poisoned enemies deal this much less damage (0.1 = 10% less).
    case weaken(amount: Double)
    /// Rams leave a bleed.
    case barbs(perSecond: Double, duration: Double)
    /// Bolts bounce off this many walls before breaking.
    case ricochet(bounces: Int)
    /// While latched on, the enemy takes this much more damage from everything (0.1 = +10%).
    case bloodmark(bonus: Double)
    /// Thrown slams hit up to this much harder when the throw lands at full speed.
    case momentum(bonus: Double)
    /// Tail hits poison.
    case venom(perSecond: Double, duration: Double)
    /// Frozen enemies take this much more damage from everything.
    case brittle(bonus: Double)
    /// A die that hits on a 6 throws a bonus die.
    case luckySix
    /// Clockwork: after a rewind, springs at the enemy (`boost` times as fast for `duration`).
    case spring(boost: Double, duration: Double)
}

nonisolated enum SideAbility: Equatable {
    /// Every `interval`, a ring of small thorns; a thorn hit re-arms the ram.
    case spikeShed(interval: Double, thorns: Int, damage: Double)
    /// Every `interval`, a slow homing flare that slows the enemy by `slow` (0.35 = 35%) for `duration`.
    case flare(interval: Double, damage: Double, slow: Double, duration: Double)
    /// Every blast throws mini-bombs.
    case cluster(bombs: Int, damage: Double, blast: Double)
    /// Every `interval`, homing bats that heal on bite and speed up the next latch.
    case batSwarm(interval: Double, bats: Int, damage: Double, heal: Double)
    /// Every slam sends out a small shockwave.
    case shockwave(damage: Double, range: Double, knockback: Double)
    /// Once per fight, below `threshold` health, sheds half the tail for a burst of speed.
    case shedSkin(threshold: Double, speedBoost: Double, duration: Double)
    /// Bursts leave ice on the floor that chills the enemy standing on it.
    case icePatch(radius: Double, duration: Double)
    /// Every `interval`, a golden die that only rolls 5 or 6.
    case weightedDie(interval: Double)

    // Shared building blocks.
    /// Every `interval`, `count` small shots: aimed at the enemy (fanned out), or in a ring. They can home in and add an effect.
    case volley(interval: Double, count: Int, damage: Double, speed: Double, homing: Double, aimed: Bool,
                kind: ProjectileKind, effect: HitEffect?)
    /// Every `interval`, a small shockwave around the ball.
    case aura(interval: Double, damage: Double, range: Double, knockback: Double)
    /// Every `interval`, a mine left where the ball is.
    case mine(interval: Double, damage: Double, blast: Double)
    /// Every `interval`, a small bomb lobbed at where the enemy is.
    case mortar(interval: Double, damage: Double, blast: Double)
    /// Every `interval`, mends `amount` health.
    case regen(interval: Double, amount: Double)
    /// Every `interval`, a sticky patch on the floor that slows the enemy standing in it.
    case honey(interval: Double, radius: Double, duration: Double, slow: Double)
    /// Every `interval`, a burst of speed (`boost` times as fast) for `duration`.
    case howl(interval: Double, boost: Double, duration: Double)
    /// Every `interval`, a shield that soaks up the next `amount` damage.
    case manaShield(interval: Double, amount: Double)
    /// Clockwork: gears hit `gearBonus` harder, and each rewind stuns the enemy for `stun`.
    case tickTock(stun: Double, gearBonus: Double)
    /// Portal: open portals sting the enemy within `range` (every `interval`).
    case rift(interval: Double, damage: Double, range: Double)
    /// Every `interval`, the enemy freezes for `duration`, as if lagging.
    case lagSpike(interval: Double, duration: Double)
    /// Twin: every `interval`, the two twins swap places.
    case swap(interval: Double)
}

nonisolated enum Ultimate: Equatable {
    /// Charges at the enemy; rams hit harder and re-arm twice as fast.
    case juggernaut(duration: Double, damageBoost: Double)
    /// Bolts in every direction.
    case barrage(duration: Double, shotsPerSecond: Double, damage: Double)
    /// A line of bombs along the enemy's path.
    case carpetBomb(bombs: Int, damage: Double)
    /// Drains from any distance.
    case bloodMoon(duration: Double, drainPerSecond: Double)
    /// Extra grabs right after a slam, chasing the enemy (`duration` is the window to land them).
    case wreckingSpree(extraGrabs: Int, duration: Double)
    /// Full-length tail that bites harder.
    case hydra(duration: Double, damageBoost: Double)
    /// Freezes the enemy and closes a ring of ice spikes on it.
    case glacier(freeze: Double, spikes: Int, damage: Double)
    /// All its dice turn loaded and roll at the enemy.
    case snakeEyes

    // Shared building blocks (each with its own name).
    /// The main attack recharges `rate` times as fast.
    case frenzy(name: String, duration: Double, rate: Double)
    /// Everything the ball deals hits harder.
    case overcharge(name: String, duration: Double, boost: Double)
    /// Locks the enemy in place and hurts it.
    case lockdown(name: String, duration: Double, damage: Double, style: HoldStyle)
    /// A ring of shots from the ball (bees home in).
    case nova(name: String, count: Int, damage: Double, kind: ProjectileKind, effect: HitEffect?)
    /// Lightning strikes the enemy every `interval`.
    case storm(name: String, duration: Double, interval: Double, damage: Double)
    /// Steals health: hurts the enemy and heals the ball by `amount`.
    case siphon(name: String, amount: Double)
    /// Heavy poison.
    case infect(name: String, perSecond: Double, duration: Double)
    /// Moss: heals `heal` over `duration`, and wall bounces heal twice as much meanwhile.
    case bloom(duration: Double, heal: Double)
    /// Magma: every lava pool bursts at once (`damage` per blast).
    case eruption(damage: Double)
    /// Wolf: hunts the enemy down, and bites heal it by `lifesteal` of their damage.
    case hunt(duration: Double, lifesteal: Double)
    /// Fibonacci: the next `shots` bolts fire at once and hit for the top number.
    case sequence(shots: Int)
    /// Wizard: casts `spells` different spells at once.
    case arcaneStorm(spells: Int)
    /// Portal: yanks the enemy through space and flings it into a wall.
    case wormhole(damage: Double)
    /// Glitch: freezes the enemy and scatters error tiles around it.
    case crash(freeze: Double, tiles: Int)
    /// Twin: the twins merge into one ball that hunts the enemy, biting `boost` harder.
    case reunite(duration: Double, boost: Double)
    /// Cell: splits right away (without being knocked out), one small cell per growth stage plus one.
    case mitosis

    var name: String {
        switch self {
        case .frenzy(let n, _, _), .overcharge(let n, _, _), .lockdown(let n, _, _, _), .nova(let n, _, _, _, _),
             .storm(let n, _, _, _), .siphon(let n, _), .infect(let n, _, _): return n
        case .juggernaut: return "Juggernaut"
        case .barrage: return "Barrage"
        case .carpetBomb: return "Carpet Bomb"
        case .bloodMoon: return "Blood Moon"
        case .wreckingSpree: return "Wrecking Spree"
        case .hydra: return "Hydra"
        case .glacier: return "Glacier"
        case .snakeEyes: return "Snake Eyes"
        case .bloom: return "Bloom"
        case .eruption: return "Eruption"
        case .hunt: return "Hunt"
        case .sequence: return "Sequence"
        case .arcaneStorm: return "Arcane Storm"
        case .wormhole: return "Wormhole"
        case .crash: return "Crash"
        case .reunite: return "Reunite"
        case .mitosis: return "Mitosis"
        }
    }

    /// How long it stays active once fired (0 for instant ones).
    var duration: Double {
        switch self {
        case .juggernaut(let d, _), .barrage(let d, _, _), .bloodMoon(let d, _), .wreckingSpree(_, let d), .hydra(let d, _): return d
        case .frenzy(_, let d, _), .overcharge(_, let d, _), .storm(_, let d, _, _), .bloom(let d, _), .hunt(let d, _), .reunite(let d, _): return d
        // Long enough for the burst of maxed bolts.
        case .sequence: return 2.5
        case .carpetBomb, .glacier, .snakeEyes, .lockdown, .nova, .siphon, .infect, .eruption, .arcaneStorm, .wormhole, .crash, .mitosis: return 0
        }
    }

    /// Meter gained per point of damage dealt / taken (full at 1).
    static let chargePerDamageDealt = 1.0 / 90
    static let chargePerDamageTaken = 1.0 / 130
    /// Seconds after an Ultimate ends before its meter starts filling again.
    static let lockout = 4.0
}

extension Progression {
    /// Star powers for balls with perks, side abilities and Ultimates (nil for the rest).
    static func abilityStarPowers(for id: String) -> [StarPower]? {
        let (perk, side, ult) = (starLevels[0], starLevels[1], starLevels[2])
        switch id {
        case "spike": return [
            StarPower(perk, "Barbs", "Rams leave a bleed: 1.5 damage per second for 2s.", ability: { $0.perk = .barbs(perSecond: 1.5, duration: 2) }),
            StarPower(side, "Spike Shed", "Every 4s, sheds a ring of 6 thorns (2 damage each). A thorn hit re-arms the ram.",
                      ability: { $0.side = .spikeShed(interval: 4, thorns: 6, damage: 2) }),
            StarPower(ult, "Juggernaut", "Charges from damage. For 3s it charges at the enemy; rams hit 25% harder and re-arm twice as fast.",
                      ability: { $0.ultimate = .juggernaut(duration: 3, damageBoost: 0.25) }),
        ]
        case "blaster": return [
            StarPower(perk, "Ricochet", "Bolts bounce off one wall before breaking, and fire 8% faster.",
                      ability: { $0.perk = .ricochet(bounces: 1) },
                      attack: { if case .projectile(var a) = $0 { a.interval *= 0.92; $0 = .projectile(a) } }),
            StarPower(side, "Flare", "Every 5s, a slow homing flare (3 damage) that slows the enemy by 25% for 2s.",
                      ability: { $0.side = .flare(interval: 5, damage: 3, slow: 0.25, duration: 2) }),
            StarPower(ult, "Barrage", "Charges from damage. For 2s it fires bolts in every direction (4 damage each).",
                      ability: { $0.ultimate = .barrage(duration: 2, shotsPerSecond: 8, damage: 4) }),
        ]
        case "bomb": return [
            StarPower(perk, "Short Fuse", "Bombs go off 25% sooner, with 15 bigger blasts.") { if case .arsenal(.bombs(var a)) = $0 { a.fuse *= 0.75; a.radius += 15; $0 = .arsenal(.bombs(a)) } },
            StarPower(side, "Cluster", "Blasts hit 6 harder and throw 3 mini-bombs (5 damage each).",
                      ability: { $0.side = .cluster(bombs: 3, damage: 5, blast: 55) },
                      attack: { if case .arsenal(.bombs(var a)) = $0 { a.damage += 6; $0 = .arsenal(.bombs(a)) } }),
            StarPower(ult, "Carpet Bomb", "Charges from damage. Drops a line of 5 bombs along the enemy's path (8 damage each).",
                      ability: { $0.ultimate = .carpetBomb(bombs: 5, damage: 8) }),
        ]
        case "vampire": return [
            StarPower(perk, "Bloodmark", "Drains 1 more per second, and while latched on the enemy takes 10% more damage from everything.",
                      ability: { $0.perk = .bloodmark(bonus: 0.1) },
                      attack: { if case .drain(var a) = $0 { a.drainPerSecond += 1; $0 = .drain(a) } }),
            StarPower(side, "Bat Swarm", "Every 6s, 3 homing bats (2 damage each). Each bite heals 3 and speeds up the next latch.",
                      ability: { $0.side = .batSwarm(interval: 6, bats: 3, damage: 2, heal: 3) }),
            StarPower(ult, "Blood Moon", "Charges from damage. For 4s it drains the enemy from anywhere (5 per second).",
                      ability: { $0.ultimate = .bloodMoon(duration: 4, drainPerSecond: 5) }),
        ]
        case "grappler": return [
            StarPower(perk, "Momentum", "Thrown slams hit up to 10% harder, the faster the throw lands.",
                      ability: { $0.perk = .momentum(bonus: 0.1) }),
            StarPower(side, "Shockwave", "Every slam sends out a small shockwave (2 damage) that shoves the enemy.",
                      ability: { $0.side = .shockwave(damage: 2, range: 90, knockback: 200) }),
            StarPower(ult, "Wrecking Spree", "Charges from damage. For a few seconds it hunts the enemy down, grabbing again right after each slam (up to 2 extra).",
                      ability: { $0.ultimate = .wreckingSpree(extraGrabs: 2, duration: 3) }),
        ]
        case "snake": return [
            StarPower(perk, "Venom", "Tail grows faster, and its hits poison: 3 damage per second for 2s.",
                      ability: { $0.perk = .venom(perSecond: 3, duration: 2) },
                      attack: { if case .arsenal(.tail(var a)) = $0 { a.growInterval -= 0.15; $0 = .arsenal(.tail(a)) } }),
            StarPower(side, "Shed Skin", "Tail hits 4 harder. Once per fight, below 40% health, sheds a quarter of its tail for a 2.5s burst of speed.",
                      ability: { $0.side = .shedSkin(threshold: 0.4, speedBoost: 1.4, duration: 2.5) },
                      attack: { if case .arsenal(.tail(var a)) = $0 { a.damage += 4; $0 = .arsenal(.tail(a)) } }),
            StarPower(ult, "Hydra", "Charges from damage. The tail grows to full length and bites 40% harder for 5s.",
                      ability: { $0.ultimate = .hydra(duration: 5, damageBoost: 0.4) }),
        ]
        case "icecone": return [
            StarPower(perk, "Brittle", "Freezes last 0.3s longer, and frozen enemies take 15% more damage from everything.",
                      ability: { $0.perk = .brittle(bonus: 0.15) },
                      attack: { if case .arsenal(.bombs(var a)) = $0 { a.freezeDuration += 0.3; $0 = .arsenal(.bombs(a)) } }),
            StarPower(side, "Ice Patch", "Bursts leave ice on the floor for 2.5s. Standing on it chills the enemy toward a freeze.",
                      ability: { $0.side = .icePatch(radius: 50, duration: 2.5) }),
            StarPower(ult, "Glacier", "Charges from damage. Freezes the enemy and closes a ring of 8 ice spikes on it (2 damage each).",
                      ability: { $0.ultimate = .glacier(freeze: 1.2, spikes: 8, damage: 2) }),
        ]
        case "dice": return [
            StarPower(perk, "Lucky Six", "A die that hits on a 6 throws a bonus die.", ability: { $0.perk = .luckySix }),
            StarPower(side, "Weighted Die", "Every 5s, throws a golden die that only rolls 5 or 6.",
                      ability: { $0.side = .weightedDie(interval: 5) }),
            StarPower(ult, "Snake Eyes", "Charges from damage. All its dice turn golden (5s and 6s only) and roll at the enemy.",
                      ability: { $0.ultimate = .snakeEyes }),
        ]
        case "pulse": return [
            StarPower(perk, "Concussion", "Shockwave reaches 30 further, and its hits slow the enemy by 30% for 1.5s.",
                      ability: { $0.perk = .onHit(.slow(amount: 0.3, duration: 1.5), cooldown: 0) },
                      attack: { if case .pulse(var a) = $0 { a.range += 30; $0 = .pulse(a) } }),
            StarPower(side, "Aftershock", "Shockwaves come every 2.2s, plus a small extra one (4 damage) every 3s.",
                      ability: { $0.side = .aura(interval: 3, damage: 4, range: 105, knockback: 220) },
                      attack: { if case .pulse(var a) = $0 { a.interval = min(a.interval, 2.2); $0 = .pulse(a) } }),
            StarPower(ult, "Overdrive", "Charges from damage. For 4s its shockwave recharges 2.5× as fast.",
                      ability: { $0.ultimate = .frenzy(name: "Overdrive", duration: 4, rate: 2.5) }),
        ]
        case "weaver": return [
            StarPower(perk, "Sticky Silk", "One more thread at a time; threads slow the enemy by 35% for 1.5s when they snap on it.",
                      ability: { $0.perk = .onHit(.slow(amount: 0.35, duration: 1.5), cooldown: 0) },
                      attack: { if case .web(var a) = $0 { a.maxThreads += 1; $0 = .web(a) } }),
            StarPower(side, "Silk Shot", "Threads deal 2 more. Every 4s, spits a web ball (3 damage) that slows the enemy by 30% for 1.5s.",
                      ability: { $0.side = .volley(interval: 4, count: 1, damage: 3, speed: 520, homing: 1, aimed: true, kind: .orb,
                                                   effect: .slow(amount: 0.3, duration: 1.5)) },
                      attack: { if case .web(var a) = $0 { a.damage += 2; $0 = .web(a) } }),
            StarPower(ult, "Cocoon", "Charges from damage. Wraps the enemy in silk: stuck for 1.5s and 6 damage.",
                      ability: { $0.ultimate = .lockdown(name: "Cocoon", duration: 1.5, damage: 6, style: .web) }),
        ]
        case "gambit": return [
            StarPower(perk, "Check", "A move that hits stuns the enemy for 0.4s.",
                      ability: { $0.perk = .onHit(.stun(duration: 0.4, style: .shock), cooldown: 1) }),
            StarPower(side, "Pawn Push", "Moves hit 6 harder. Every 4s, flicks a pawn at the enemy (4 damage).",
                      ability: { $0.side = .volley(interval: 4, count: 1, damage: 4, speed: 600, homing: 0.5, aimed: true, kind: .orb, effect: nil) },
                      attack: { if case .chess(var a) = $0 { a.damage += 6; $0 = .chess(a) } }),
            StarPower(ult, "Blitz", "Charges from damage. For 4s it plays its moves 2.5× as fast.",
                      ability: { $0.ultimate = .frenzy(name: "Blitz", duration: 4, rate: 2.5) }),
        ]
        case "eclipse": return [
            StarPower(perk, "Moonburn", "Totality burns the enemy: 2 damage per second for 3s.",
                      ability: { $0.perk = .onHit(.poison(perSecond: 2, duration: 3), cooldown: 0) }),
            StarPower(side, "Starfall", "Every 4s, 3 homing stars (1.5 damage each).",
                      ability: { $0.side = .volley(interval: 4, count: 3, damage: 1.5, speed: 380, homing: 3, aimed: false, kind: .orb, effect: nil) }),
            StarPower(ult, "New Moon", "Charges from damage. For 4s the moon slides across 1.6× as fast.",
                      ability: { $0.ultimate = .frenzy(name: "New Moon", duration: 4, rate: 1.6) }),
        ]
        case "shackle": return [
            StarPower(perk, "Rusty Jaws", "One more trap, biting 4 harder; trapped enemies bleed 2 damage per second for 2s.",
                      ability: { $0.perk = .onHit(.poison(perSecond: 2, duration: 2), cooldown: 0) },
                      attack: { if case .arsenal(.traps(var a)) = $0 { a.maxTraps += 1; a.damage += 4; $0 = .arsenal(.traps(a)) } }),
            StarPower(side, "Chain Toss", "Traps hold 0.3s longer. Every 4.5s, throws a chain at the enemy (4 damage) that holds it for 0.3s.",
                      ability: { $0.side = .volley(interval: 4.5, count: 1, damage: 4, speed: 620, homing: 0.6, aimed: true, kind: .orb,
                                                   effect: .stun(duration: 0.3, style: .shackle)) },
                      attack: { if case .arsenal(.traps(var a)) = $0 { a.holdDuration += 0.3; $0 = .arsenal(.traps(a)) } }),
            StarPower(ult, "Lockdown", "Charges from damage. Chains the enemy in place for 2s and deals 6 damage.",
                      ability: { $0.ultimate = .lockdown(name: "Lockdown", duration: 2, damage: 6, style: .shackle) }),
        ]
        case "conductor": return [
            StarPower(perk, "Steam Cloud", "New track 0.5s sooner; train hits slow the enemy by 30% for 2s.",
                      ability: { $0.perk = .onHit(.slow(amount: 0.3, duration: 2), cooldown: 0) },
                      attack: { if case .arsenal(.train(var a)) = $0 { a.cooldown -= 0.5; $0 = .arsenal(.train(a)) } }),
            StarPower(side, "Coal Toss", "Trains deal 10 more. Every 3.5s, throws 3 lumps of coal at the enemy (2 damage each).",
                      ability: { $0.side = .volley(interval: 3.5, count: 3, damage: 2, speed: 560, homing: 0, aimed: true, kind: .orb, effect: nil) },
                      attack: { if case .arsenal(.train(var a)) = $0 { a.damage += 10; $0 = .arsenal(.train(a)) } }),
            StarPower(ult, "Rush Hour", "Charges from damage. For 5s it lays new tracks 3× as fast.",
                      ability: { $0.ultimate = .frenzy(name: "Rush Hour", duration: 5, rate: 3) }),
        ]
        case "laser": return [
            StarPower(perk, "Overheat", "Beams burn: 2 damage per second for 2s.",
                      ability: { $0.perk = .onHit(.poison(perSecond: 2, duration: 2), cooldown: 0) }),
            StarPower(side, "Zap", "Every 4s, fires a quick laser bolt at the enemy (4 damage).",
                      ability: { $0.side = .volley(interval: 4, count: 1, damage: 4, speed: 950, homing: 0, aimed: true, kind: .orb, effect: nil) }),
            StarPower(ult, "Overcharge", "Charges from damage. For 5s everything it deals hits 40% harder.",
                      ability: { $0.ultimate = .overcharge(name: "Overcharge", duration: 5, boost: 0.4) }),
        ]
        case "zone": return [
            StarPower(perk, "Quicksand", "Zones are 15 bigger, and enemies burning in them are slowed by 25%.",
                      ability: { $0.perk = .onHit(.slow(amount: 0.25, duration: 0.7), cooldown: 0) },
                      attack: { if case .arsenal(.zone(var a)) = $0 { a.radius += 15; $0 = .arsenal(.zone(a)) } }),
            StarPower(side, "Flare Up", "Zones burn 4 more per second. Every 4s, a small heat wave around it (4 damage).",
                      ability: { $0.side = .aura(interval: 4, damage: 4, range: 110, knockback: 180) },
                      attack: { if case .arsenal(.zone(var a)) = $0 { a.damagePerSecond += 4; $0 = .arsenal(.zone(a)) } }),
            StarPower(ult, "Martial Law", "Charges from damage. For 5s everything it deals hits 40% harder.",
                      ability: { $0.ultimate = .overcharge(name: "Martial Law", duration: 5, boost: 0.4) }),
        ]
        case "glass": return [
            StarPower(perk, "Sharp Edges", "Up to 3 more shards, and they make the enemy bleed: 1.5 damage per second for 2s.",
                      ability: { $0.perk = .onHit(.poison(perSecond: 1.5, duration: 2), cooldown: 0) },
                      attack: { if case .arsenal(.shards(var a)) = $0 { a.maxShards += 3; $0 = .arsenal(.shards(a)) } }),
            StarPower(side, "Patch Up", "Every 5s, mends 8 health.",
                      ability: { $0.side = .regen(interval: 5, amount: 8) }),
            StarPower(ult, "Shatterstorm", "Charges from damage. Bursts into a ring of 14 shards (3 damage each).",
                      ability: { $0.ultimate = .nova(name: "Shatterstorm", count: 14, damage: 3, kind: .shard, effect: nil) }),
        ]
        case "thief": return [
            StarPower(perk, "Hamstring", "Steals 5% more health, and knife hits slow the enemy by 20% for 1s.",
                      ability: { $0.perk = .onHit(.slow(amount: 0.2, duration: 1), cooldown: 0) },
                      attack: { if case .arsenal(.knives(var a)) = $0 { a.stealFraction += 0.05; $0 = .arsenal(.knives(a)) } }),
            StarPower(side, "Caltrops", "Pickpocket throws one more knife. Every 5s, drops a mine behind it (5 damage).",
                      ability: { $0.side = .mine(interval: 5, damage: 5, blast: 55) },
                      attack: { if case .arsenal(.knives(var a)) = $0 { a.pickpocketKnives += 1; $0 = .arsenal(.knives(a)) } }),
            StarPower(ult, "Heist", "Charges from damage. Steals 12 health from the enemy.",
                      ability: { $0.ultimate = .siphon(name: "Heist", amount: 12) }),
        ]
        case "electric": return [
            StarPower(perk, "Static", "Each charge adds 1 more damage, and shocks slow the enemy by 25% for 2.5s.",
                      ability: { $0.perk = .onHit(.slow(amount: 0.25, duration: 2.5), cooldown: 0) },
                      attack: { if case .arsenal(.shock(var a)) = $0 { a.damagePerCharge += 1; $0 = .arsenal(.shock(a)) } }),
            StarPower(side, "Spark Ring", "Every 3.5s, throws off a ring of 6 sparks (3 damage each).",
                      ability: { $0.side = .volley(interval: 3.5, count: 6, damage: 3, speed: 460, homing: 0, aimed: false, kind: .thorn, effect: nil) }),
            StarPower(ult, "Thunderstorm", "Charges from damage. For 3s lightning strikes the enemy every half second (4 damage).",
                      ability: { $0.ultimate = .storm(name: "Thunderstorm", duration: 3, interval: 0.5, damage: 4) }),
        ]
        case "cannon": return [
            StarPower(perk, "Incendiary", "Turret shots burn: 1.5 damage per second for 2s.",
                      ability: { $0.perk = .onHit(.poison(perSecond: 1.5, duration: 2), cooldown: 0) }),
            StarPower(side, "Mortar", "Every 4s, lobs a shell where the enemy is (5 damage).",
                      ability: { $0.side = .mortar(interval: 4, damage: 5, blast: 60) }),
            StarPower(ult, "Broadside", "Charges from damage. For 5s everything it deals hits 50% harder.",
                      ability: { $0.ultimate = .overcharge(name: "Broadside", duration: 5, boost: 0.5) }),
        ]
        case "virus": return [
            StarPower(perk, "Weakness", "Infects 0.15s sooner and poison lasts 1.5s longer; poisoned enemies deal 15% less damage.",
                      ability: { $0.perk = .weaken(amount: 0.15) },
                      attack: { if case .arsenal(.virus(var a)) = $0 { a.duration += 1.5; a.cooldown -= 0.15; $0 = .arsenal(.virus(a)) } }),
            StarPower(side, "Spores", "Every 3.5s, 4 homing spores (1 damage) that add poison.",
                      ability: { $0.side = .volley(interval: 3.5, count: 4, damage: 1, speed: 300, homing: 3, aimed: false, kind: .orb,
                                                   effect: .poison(perSecond: 1.5, duration: 2)) }),
            StarPower(ult, "Pandemic", "Charges from damage. Infects the enemy with heavy poison: 7 damage per second for 4s.",
                      ability: { $0.ultimate = .infect(name: "Pandemic", perSecond: 7, duration: 4) }),
        ]
        case "harpoon": return [
            StarPower(perk, "Barbed Hook", "Harpoon hits bleed: 1.5 damage per second for 2s.",
                      ability: { $0.perk = .onHit(.poison(perSecond: 1.5, duration: 2), cooldown: 0) }),
            StarPower(side, "Net", "Every 5s, throws a net at the enemy (2 damage) that holds it for 0.5s.",
                      ability: { $0.side = .volley(interval: 5, count: 1, damage: 2, speed: 560, homing: 0.8, aimed: true, kind: .orb,
                                                   effect: .stun(duration: 0.5, style: .web)) }),
            StarPower(ult, "Feeding Frenzy", "Charges from damage. For 3s it fires harpoons twice as fast.",
                      ability: { $0.ultimate = .frenzy(name: "Feeding Frenzy", duration: 3, rate: 2) }),
        ]
        case "hive": return [
            StarPower(perk, "Royal Jelly", "Each sting heals it 1.",
                      ability: { $0.perk = .onHit(.heal(amount: 1), cooldown: 0) }),
            StarPower(side, "Honey Trap", "One more bee per swarm. Every 5s, drips a honey patch for 3s that slows the enemy by 40%.",
                      ability: { $0.side = .honey(interval: 5, radius: 55, duration: 3, slow: 0.4) },
                      attack: { if case .arsenal(.swarm(var a)) = $0 { a.bees += 1; $0 = .arsenal(.swarm(a)) } }),
            StarPower(ult, "Killer Swarm", "Charges from damage. Releases 6 extra bees at once.",
                      ability: { $0.ultimate = .nova(name: "Killer Swarm", count: 6, damage: 1.5, kind: .bee,
                                                     effect: .poison(perSecond: 1.2, duration: 2.5)) }),
        ]
        case "moss": return [
            StarPower(perk, "Thornbush", "Wall bounces heal 1 more, and thorny touches make the enemy bleed: 1.5 damage per second for 2s.",
                      ability: { $0.perk = .onHit(.poison(perSecond: 1.5, duration: 2), cooldown: 0) },
                      attack: { if case .arsenal(.moss(var a)) = $0 { a.wallHeal += 1; $0 = .arsenal(.moss(a)) } }),
            StarPower(side, "Pollen", "Every 4s, puffs out 6 pollen spores (1 damage each) that slow the enemy by 25% for 1.5s.",
                      ability: { $0.side = .volley(interval: 4, count: 6, damage: 1, speed: 300, homing: 0, aimed: false, kind: .orb,
                                                   effect: .slow(amount: 0.25, duration: 1.5)) }),
            StarPower(ult, "Bloom", "Charges from damage. Heals 24 over 4s, and wall bounces heal twice as much meanwhile.",
                      ability: { $0.ultimate = .bloom(duration: 4, heal: 24) }),
        ]
        case "magma": return [
            StarPower(perk, "Scorch", "Pools last 0.4s longer, and burning slows the enemy by 25%.",
                      ability: { $0.perk = .onHit(.slow(amount: 0.25, duration: 0.8), cooldown: 0) },
                      attack: { if case .arsenal(.magma(var a)) = $0 { a.poolLifetime += 0.4; $0 = .arsenal(.magma(a)) } }),
            StarPower(side, "Fireball", "Every 4s, a homing fireball (5 damage) that burns 2 per second for 2s.",
                      ability: { $0.side = .volley(interval: 4, count: 1, damage: 5, speed: 460, homing: 1.3, aimed: true, kind: .firebolt,
                                                   effect: .poison(perSecond: 2, duration: 2)) }),
            StarPower(ult, "Eruption", "Charges from damage. Every lava pool bursts at once (8 damage per blast).",
                      ability: { $0.ultimate = .eruption(damage: 8) }),
        ]
        case "wolf": return [
            StarPower(perk, "Bleed", "Bites make the enemy bleed: 2 damage per second for 2s.",
                      ability: { $0.perk = .onHit(.poison(perSecond: 2, duration: 2), cooldown: 0) }),
            StarPower(side, "Howl", "Bites hit 3 harder. Every 6s, howls for a burst of speed: 35% faster for 2s.",
                      ability: { $0.side = .howl(interval: 6, boost: 1.35, duration: 2) },
                      attack: { if case .arsenal(.wolf(var a)) = $0 { a.damage += 3; $0 = .arsenal(.wolf(a)) } }),
            StarPower(ult, "Hunt", "Charges from damage. For 3s it hunts the enemy down, and its bites heal it for a third of their damage.",
                      ability: { $0.ultimate = .hunt(duration: 3, lifesteal: 0.33) }),
        ]
        case "fibonacci": return [
            StarPower(perk, "Golden Ratio", "The streak starts one number higher (at 3), and bolts fire 5% faster.",
                      attack: { if case .arsenal(.fibonacci(var a)) = $0 { a.startIndex += 1; a.interval *= 0.95; $0 = .arsenal(.fibonacci(a)) } }),
            StarPower(side, "Spiral", "The streak never drops below 5. Every 5s, throws a spiral of 3 homing numbers (2 damage each).",
                      ability: { $0.side = .volley(interval: 5, count: 3, damage: 2, speed: 380, homing: 2.2, aimed: false, kind: .orb, effect: nil) },
                      attack: { if case .arsenal(.fibonacci(var a)) = $0 { a.floorIndex = 4; $0 = .arsenal(.fibonacci(a)) } }),
            StarPower(ult, "Sequence", "Charges from damage. Its next 5 bolts fire in a quick burst, all at the top number.",
                      ability: { $0.ultimate = .sequence(shots: 5) }),
        ]
        case "wizard": return [
            StarPower(perk, "Focus", "Never casts the same spell twice in a row, and casts 10% faster.",
                      attack: { if case .arsenal(.wizard(var a)) = $0 { a.noRepeat = true; a.interval *= 0.9; $0 = .arsenal(.wizard(a)) } }),
            StarPower(side, "Mana Shield", "Every 6s, a magic shield soaks up the next 6 damage.",
                      ability: { $0.side = .manaShield(interval: 6, amount: 6) }),
            StarPower(ult, "Arcane Storm", "Charges from damage. Casts three different spells at once.",
                      ability: { $0.ultimate = .arcaneStorm(spells: 3) }),
        ]
        case "clockwork": return [
            StarPower(perk, "Spring", "After each rewind it springs at the enemy: twice as fast for 1s.",
                      ability: { $0.perk = .spring(boost: 2, duration: 1) }),
            StarPower(side, "Tick-Tock", "Gears hit 1 harder, and each rewind stuns the enemy for 0.35s.",
                      ability: { $0.side = .tickTock(stun: 0.35, gearBonus: 1) }),
            StarPower(ult, "Time Stop", "Charges from damage. Freezes the enemy in time for 1.5s and deals 4 damage.",
                      ability: { $0.ultimate = .lockdown(name: "Time Stop", duration: 1.5, damage: 4, style: .time) }),
        ]
        case "portal": return [
            StarPower(perk, "Disorient", "Coming out of a portal leaves the enemy dazed for 0.35s.",
                      ability: { $0.perk = .onHit(.stun(duration: 0.35, style: .time), cooldown: 1) }),
            StarPower(side, "Rift", "Open portals sting the enemy nearby: 1 damage every second.",
                      ability: { $0.side = .rift(interval: 1, damage: 1, range: 70) }),
            StarPower(ult, "Wormhole", "Charges from damage. Yanks the enemy through space and flings it into a wall (12 damage).",
                      ability: { $0.ultimate = .wormhole(damage: 12) }),
        ]
        case "glitch": return [
            StarPower(perk, "Corrupt", "Error tiles hit 3 harder and last 1s longer.",
                      attack: { if case .arsenal(.glitch(var a)) = $0 { a.tileDamage += 3; a.tileLifetime += 1; $0 = .arsenal(.glitch(a)) } }),
            StarPower(side, "Lag Spike", "Blinks zap 2 harder. Every 5s, the enemy lags: frozen for 0.6s.",
                      ability: { $0.side = .lagSpike(interval: 5, duration: 0.6) },
                      attack: { if case .arsenal(.glitch(var a)) = $0 { a.zapDamage += 2; $0 = .arsenal(.glitch(a)) } }),
            StarPower(ult, "Crash", "Charges from damage. Freezes the enemy for 1.8s and scatters 6 error tiles around it.",
                      ability: { $0.ultimate = .crash(freeze: 1.8, tiles: 6) }),
        ]
        case "twin": return [
            StarPower(perk, "Bond", "Every bite either twin lands heals Twin 2 (at most twice a second).",
                      ability: { $0.perk = .onHit(.heal(amount: 2), cooldown: 0.5) }),
            StarPower(side, "Swap", "Bites hit 1 harder. Every 5s the twins swap places, dodging out of trouble.",
                      ability: { $0.side = .swap(interval: 5) },
                      attack: { if case .arsenal(.twin(var a)) = $0 { a.damage += 1; $0 = .arsenal(.twin(a)) } }),
            StarPower(ult, "Reunite", "Charges from damage. The twins merge into one ball for 4s that hunts the enemy, biting 60% harder.",
                      ability: { $0.ultimate = .reunite(duration: 4, boost: 0.6) }),
        ]
        case "cell": return [
            StarPower(perk, "Thick Membrane", "The membrane soaks up 10% more damage while it grows.",
                      attack: { if case .arsenal(.cell(var a)) = $0 { a.membrane += 0.1; $0 = .arsenal(.cell(a)) } }),
            StarPower(side, "Cytoplasm", "Bites hit 1 harder. Every 4s, leaves a sticky blob that slows the enemy by 30% for 3s.",
                      ability: { $0.side = .honey(interval: 4, radius: 45, duration: 3, slow: 0.3) },
                      attack: { if case .arsenal(.cell(var a)) = $0 { a.damage += 1; $0 = .arsenal(.cell(a)) } }),
            StarPower(ult, "Mitosis", "Charges from damage. Splits right away without being knocked out: one small cell per growth stage, plus one.",
                      ability: { $0.ultimate = .mitosis }),
        ]
        default: return nil
        }
    }
}
