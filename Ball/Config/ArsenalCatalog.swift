import Foundation

// MARK: - Arsenal attacks
//
// The second wave of fighters. They are built from shared systems — field hazards,
// projectiles, status effects (poison, hold) and a growing tail — so each one is just
// a configuration. Behaviour lives in Battle/ArsenalSystem.swift.

struct TrapSpec: Equatable {
    var interval: Double        // seconds between drops
    var trapsPerDrop: Int
    var spread: Double          // distance between traps in one drop
    var trapRadius: Double
    var armDelay: Double        // traps can't trigger until armed
    var lifetime: Double
    var maxTraps: Int
    var damage: Double
    var holdDuration: Double    // enemy is locked in place this long
}

struct TrainSpec: Equatable {
    var cooldown: Double        // after a train finishes, before a new track
    var warning: Double         // track visible before the train comes
    var trainSpeed: Double
    var damage: Double
    var knockback: Double
    var width: Double           // half-width of the train for hit testing
}

struct LaserSpec: Equatable {
    var cooldown: Double        // minimum time between new lasers
    var maxLasers: Int
    var lifetime: Double
    var damage: Double
    var hitCooldown: Double     // per-laser, so sitting on a laser doesn't hit every frame
}

struct ZoneSpec: Equatable {
    var interval: Double
    var radius: Double
    var duration: Double
    var damagePerSecond: Double
    var maxZones: Int
}

struct DiceSpec: Equatable {
    var interval: Double
    var maxDice: Int
    var lifetime: Double
    var damagePerPip: Double
    /// The thrower also gets hurt by its own dice, at this rate.
    var selfDamagePerPip: Double
    var dieSize: Double
    var rerollCooldown: Double
}

struct ShardSpec: Equatable {
    var cooldown: Double
    var shardCount: Int
    var shardSpeed: Double
    var damage: Double
    var minImpactSpeed: Double
}

struct KnifeSpec: Equatable {
    var slowInterval: Double    // at full health
    var fastInterval: Double    // near death
    var speed: Double
    var damage: Double
}

struct TailSpec: Equatable {
    var growInterval: Double
    var maxSegments: Int
    var segmentSpacing: Double
    var segmentRadius: Double
    var damage: Double
    var knockback: Double
    var hitCooldown: Double
}

struct ShockSpec: Equatable {
    var cooldown: Double
    var damage: Double
    var freezeDuration: Double
}

struct BombSpec: Equatable {
    var interval: Double
    var fuse: Double
    var radius: Double
    var damage: Double
    var knockback: Double
    /// Ice Cone bombs burst into this many spikes (0 for a plain bomb).
    var spikes: Int
    var spikeSpeed: Double
    var spikeDamage: Double
    var icy: Bool
}

struct TurretSpec: Equatable {
    var cooldown: Double
    var maxTurrets: Int
    var lifetime: Double
    var fireInterval: Double
    var shotSpeed: Double
    var damage: Double
}

struct VirusSpec: Equatable {
    var cooldown: Double
    var damagePerSecond: Double
    var duration: Double
    var maxDamagePerSecond: Double
}

struct HarpoonSpec: Equatable {
    var interval: Double
    var speed: Double
    var damage: Double
    var dragDuration: Double
    var dragSpeed: Double
}

struct SwarmSpec: Equatable {
    var interval: Double
    var bees: Int
    var speed: Double
    var turnRate: Double
    var lifetime: Double
    var damage: Double
    var poisonPerSecond: Double
    var poisonDuration: Double
}

enum ArsenalAttack: Equatable {
    case traps(TrapSpec)
    case train(TrainSpec)
    case laser(LaserSpec)
    case zone(ZoneSpec)
    case dice(DiceSpec)
    case shards(ShardSpec)
    case knives(KnifeSpec)
    case tail(TailSpec)
    case shock(ShockSpec)
    case bombs(BombSpec)
    case turrets(TurretSpec)
    case virus(VirusSpec)
    case harpoon(HarpoonSpec)
    case swarm(SwarmSpec)

    /// Time-based recharge used for the cooldown ring (nil for non-timer attacks).
    var interval: Double? {
        switch self {
        case .traps(let a): return a.interval
        case .train(let a): return a.cooldown
        case .laser(let a): return a.cooldown
        case .zone(let a): return a.interval
        case .dice(let a): return a.interval
        case .shards(let a): return a.cooldown
        case .knives(let a): return a.slowInterval
        case .tail(let a): return a.growInterval
        case .shock(let a): return a.cooldown
        case .bombs(let a): return a.interval
        case .turrets(let a): return a.cooldown
        case .virus(let a): return a.cooldown
        case .harpoon(let a): return a.interval
        case .swarm(let a): return a.interval
        }
    }

    var stats: [(String, String)] {
        func f(_ v: Double) -> String { v.rounded() == v ? String(Int(v)) : String(format: "%.1f", v) }
        switch self {
        case .traps(let a): return [("Damage", f(a.damage)), ("Hold", "\(f(a.holdDuration))s"), ("Traps", "\(a.trapsPerDrop)×")]
        case .train(let a): return [("Damage", f(a.damage)), ("Trigger", "Wall"), ("Cooldown", "\(f(a.cooldown))s")]
        case .laser(let a): return [("Damage", f(a.damage)), ("Lasers", "\(a.maxLasers)"), ("Lasts", "\(f(a.lifetime))s")]
        case .zone(let a): return [("DPS", f(a.damagePerSecond)), ("Radius", f(a.radius)), ("Interval", "\(f(a.interval))s")]
        case .dice(let a): return [("Damage", "\(f(a.damagePerPip))–\(f(a.damagePerPip * 6))"), ("Dice", "\(a.maxDice)"), ("Interval", "\(f(a.interval))s")]
        case .shards(let a): return [("Shard dmg", f(a.damage)), ("Shards", "\(a.shardCount)"), ("Trigger", "Impact")]
        case .knives(let a): return [("Damage", f(a.damage)), ("Rate", "\(f(a.slowInterval))→\(f(a.fastInterval))s"), ("Aim", "Auto")]
        case .tail(let a): return [("Damage", f(a.damage)), ("Max tail", "\(a.maxSegments)"), ("Grows", "\(f(a.growInterval))s")]
        case .shock(let a): return [("Damage", f(a.damage)), ("Freeze", "\(f(a.freezeDuration))s"), ("Cooldown", "\(f(a.cooldown))s")]
        case .bombs(let a):
            return a.spikes > 0
                ? [("Spike dmg", f(a.spikeDamage)), ("Spikes", "\(a.spikes)"), ("Interval", "\(f(a.interval))s")]
                : [("Damage", f(a.damage)), ("Radius", f(a.radius)), ("Interval", "\(f(a.interval))s")]
        case .turrets(let a): return [("Shot dmg", f(a.damage)), ("Turrets", "\(a.maxTurrets)"), ("Fire rate", "\(f(a.fireInterval))s")]
        case .virus(let a): return [("Poison", "\(f(a.damagePerSecond))/s"), ("Lasts", "\(f(a.duration))s"), ("Stacks", "Yes")]
        case .harpoon(let a): return [("Damage", f(a.damage)), ("Drag", "\(f(a.dragDuration))s"), ("Interval", "\(f(a.interval))s")]
        case .swarm(let a): return [("Bees", "\(a.bees)"), ("Poison", "\(f(a.poisonPerSecond))/s"), ("Interval", "\(f(a.interval))s")]
        }
    }
}

// MARK: - Arsenal fighters (edit these to rebalance)

nonisolated extension FighterCatalog {
    private static func make(_ id: String, _ name: String, _ tagline: String, _ attackName: String,
                             _ description: String, _ attack: ArsenalAttack) -> FighterDefinition {
        FighterDefinition(id: id, name: name, tagline: tagline, attackName: attackName,
                          attackDescription: description, maxHealth: 100, radius: ballRadius, mass: 1,
                          attack: .arsenal(attack))
    }

    static let shackle = make("shackle", "Shackle", "Jailer", "Snap Traps",
        "Drops pairs of steel traps behind it. An enemy that rolls over one is locked in place and hurt.",
        .traps(TrapSpec(interval: 3.4, trapsPerDrop: 2, spread: 52, trapRadius: 18, armDelay: 0.5, lifetime: 10,
                        maxTraps: 4, damage: 12, holdDuration: 1.1)))

    static let conductor = make("conductor", "Conductor", "Rail boss", "Express Line",
        "Hitting a wall lays a track across the arena. Moments later a train thunders down it and rams anything in the way.",
        .train(TrainSpec(cooldown: 2.4, warning: 0.6, trainSpeed: 760, damage: 34, knockback: 520, width: 40)))

    static let laser = make("laser", "Laser", "Grid maker", "Tripwire",
        "Every wall hit leaves a laser beam across the arena. Lasers stay and burn the enemy each time it crosses.",
        .laser(LaserSpec(cooldown: 1, maxLasers: 2, lifetime: 6, damage: 4.5, hitCooldown: 1)))

    static let zone = make("zone", "Zone", "Area denial", "Red Zone",
        "Paints a red danger zone where it stands. The enemy takes steady damage while inside.",
        .zone(ZoneSpec(interval: 4, radius: 110, duration: 5, damagePerSecond: 12, maxZones: 2)))

    static let dice = make("dice", "Dice", "Gambler", "Loaded Dice",
        "Drops dice around the arena. Touching one hurts by its number, then it rerolls. Its own dice hurt it a little too.",
        .dice(DiceSpec(interval: 2.2, maxDice: 5, lifetime: 9, damagePerPip: 2.5, selfDamagePerPip: 0.3, dieSize: 15,
                       rerollCooldown: 1)))

    static let glass = make("glass", "Glass", "Fragile menace", "Shatter",
        "Every hard impact scatters sharp glass shards in all directions. Punishes anyone who gets close.",
        .shards(ShardSpec(cooldown: 0.3, shardCount: 8, shardSpeed: 520, damage: 4.5, minImpactSpeed: 80)))

    static let thief = make("thief", "Thief", "Knife thrower", "Cutpurse",
        "Throws knives straight at the enemy. The lower its health, the faster it throws.",
        .knives(KnifeSpec(slowInterval: 1.6, fastInterval: 0.6, speed: 780, damage: 5.5)))

    static let snake = make("snake", "Snake", "Slitherer", "Long Tail",
        "Grows a longer tail over time. The tail hurts and knocks back the enemy on contact.",
        .tail(TailSpec(growInterval: 1, maxSegments: 16, segmentSpacing: 20, segmentRadius: 16, damage: 14,
                       knockback: 380, hitCooldown: 0.4)))

    static let electric = make("electric", "Electric", "Live wire", "Stun Shock",
        "Bumping the enemy shocks it and freezes it in place for a moment.",
        .shock(ShockSpec(cooldown: 2, damage: 16, freezeDuration: 1.3)))

    static let iceCone = make("icecone", "Ice Cone", "Frost bomber", "Ice Burst",
        "Drops ice bombs that burst into a ring of icy spikes, hitting the enemy even from a distance.",
        .bombs(BombSpec(interval: 3, fuse: 0.9, radius: 70, damage: 8, knockback: 150, spikes: 12, spikeSpeed: 430,
                        spikeDamage: 8, icy: true)))

    static let cannon = make("cannon", "Cannon", "Artillery", "Wall Turrets",
        "Each wall hit can mount a turret on the wall that shoots the enemy until it breaks down.",
        .turrets(TurretSpec(cooldown: 2.8, maxTurrets: 2, lifetime: 8, fireInterval: 1.5, shotSpeed: 600, damage: 7.5)))

    static let bomb = make("bomb", "Bomb", "Demolition", "Kaboom",
        "Drops bombs that explode after a short fuse, damaging and blasting the enemy away.",
        .bombs(BombSpec(interval: 2.1, fuse: 1.1, radius: 140, damage: 30, knockback: 460, spikes: 0, spikeSpeed: 0,
                        spikeDamage: 0, icy: false)))

    static let virus = make("virus", "Virus", "Contagion", "Infect",
        "Touching the enemy infects it with poison that keeps hurting over time. Repeated touches stack.",
        .virus(VirusSpec(cooldown: 0.9, damagePerSecond: 3, duration: 4, maxDamagePerSecond: 6)))

    static let harpoon = make("harpoon", "Harpoon", "Hunter", "Reel In",
        "Fires a harpoon at the enemy and drags it back across the arena.",
        .harpoon(HarpoonSpec(interval: 3.2, speed: 820, damage: 18, dragDuration: 0.7, dragSpeed: 480)))

    static let hive = make("hive", "Hive", "Swarm keeper", "Angry Bees",
        "Releases homing bees that chase the enemy and poison it on sting.",
        .swarm(SwarmSpec(interval: 3.5, bees: 2, speed: 260, turnRate: 3.5, lifetime: 4, damage: 1.5, poisonPerSecond: 1.2,
                         poisonDuration: 2.5)))

    static let arsenal: [FighterDefinition] = [
        shackle, conductor, laser, zone, dice, glass, thief, snake, electric, iceCone, cannon, bomb, virus, harpoon, hive,
    ]
}
