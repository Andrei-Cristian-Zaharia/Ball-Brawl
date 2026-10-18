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
    /// Minimum time between new lasers. Each wall hit becomes an emitter; the next hit on a
    /// *different* wall links the two with a beam.
    var cooldown: Double
    var maxLasers: Int          // the oldest beam switches off when a new one goes up
    var lifetime: Double
    var damage: Double
    var hitCooldown: Double     // per-laser, so sitting on a laser doesn't hit every frame
}

struct ZoneSpec: Equatable {
    var interval: Double
    var radius: Double          // full size, reached after `growTime`
    var growTime: Double
    var duration: Double
    var damagePerSecond: Double
    /// Zone heals itself while standing in one of its own zones.
    var healPerSecond: Double
    var maxZones: Int

    func radius(atAge age: Double, base: Double) -> Double {
        base * (0.35 + 0.65 * min(1, age / growTime))
    }
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
    /// Dice are thrown at the enemy and tumble until they stop; this caps the throw speed.
    var throwSpeed: Double
    /// Damage multiplier for a die that is still tumbling when it hits.
    var tumblingMultiplier: Double
}

struct ShardSpec: Equatable {
    var cooldown: Double
    /// Shards per shatter at full health, rising to `maxShards` as Glass cracks up.
    var minShards: Int
    var maxShards: Int
    var shardSpeed: Double
    var damage: Double
    var minImpactSpeed: Double
}

struct KnifeSpec: Equatable {
    var slowInterval: Double    // at full health
    var fastInterval: Double    // near death
    var speed: Double
    var damage: Double
    /// Share of knife damage the thief steals back as health.
    var stealFraction: Double
    /// Bumping the enemy halves its attack charge and throws knives at point-blank range.
    var pickpocketCooldown: Double
    var pickpocketKnives: Int
}

struct TailSpec: Equatable {
    var growInterval: Double
    var maxSegments: Int
    var segmentSpacing: Double
    /// Tail segments thicken from `minSegmentRadius` to `maxSegmentRadius` as the tail grows.
    var minSegmentRadius: Double
    var maxSegmentRadius: Double
    var damage: Double
    var knockback: Double
    var hitCooldown: Double
    /// Scales Snake's min/max/launch speed.
    var speedMultiplier: Double

    func segmentRadius(segments: Int) -> Double {
        minSegmentRadius + (maxSegmentRadius - minSegmentRadius) * min(1, Double(segments) / Double(maxSegments))
    }
}

struct ShockSpec: Equatable {
    var cooldown: Double
    /// Bump damage and freeze with no charge; each stored charge adds more.
    var damage: Double
    var damagePerCharge: Double
    var freezeDuration: Double
    var freezePerCharge: Double
    /// Each wall bounce stores one charge, up to this many.
    var maxCharge: Int
    /// Fully charged, Electric arcs lightning at an enemy this close (edge to edge) without touching it.
    var arcRange: Double
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
    /// Bombs are rolled toward the enemy at up to this speed (0 = dropped in place).
    var throwSpeed: Double
    /// Bombs this close to a blast go off too.
    var chainRadius: Double
    /// Ice spike hits needed to freeze the enemy solid (0 = no freezing).
    var chillToFreeze: Int
    var freezeDuration: Double
}

struct TurretSpec: Equatable {
    var cooldown: Double
    /// Turrets stay until a new one replaces the oldest.
    var maxTurrets: Int
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

struct MossSpec: Equatable {
    /// Thorny touch.
    var damage: Double
    var cooldown: Double
    /// Health mended on each wall bounce (at most once per `healCooldown`).
    var wallHeal: Double
    var healCooldown: Double
}

struct MagmaSpec: Equatable {
    /// A lava pool drops every `dropInterval` while Magma rolls.
    var dropInterval: Double
    var poolRadius: Double
    var poolLifetime: Double
    var maxPools: Int
    /// Burn while the enemy is in a pool (ticks every half second).
    var damagePerSecond: Double
    /// Touching the enemy sets it on fire (burn per second, seconds, at most once per `igniteCooldown`).
    var ignitePerSecond: Double
    var igniteDuration: Double
    var igniteCooldown: Double
}

struct WolfSpec: Equatable {
    /// Bite damage at full enemy health; up to `1 + maxBonus` times that as the enemy runs out of health.
    var damage: Double
    var cooldown: Double
    var maxBonus: Double
    /// Speed added as the enemy weakens (0.3 = up to 30% faster).
    var speedBonus: Double
}

struct FibonacciSpec: Equatable {
    var interval: Double
    var speed: Double
    /// Index into the Fibonacci numbers (1, 1, 2, 3, 5, 8, 13, 21, 34…) the streak starts at, can't drop below,
    /// and stops growing at.
    var startIndex: Int
    var floorIndex: Int
    var maxIndex: Int
    /// Damage per hit is the streak's number times this.
    var damageScale: Double
    /// Taking a hit this big halves the streak.
    var breakDamage: Double

    static func number(at index: Int) -> Int {
        var (a, b) = (1, 1)
        for _ in 0..<max(0, index) { (a, b) = (b, a + b) }
        return a
    }
}

struct WizardSpec: Equatable {
    var interval: Double
    /// Never casts the same spell twice in a row (Focus).
    var noRepeat: Bool
    var fireboltDamage: Double
    var frostDamage: Double
    var lightningDamage: Double
    var missileDamage: Double
}

struct ClockworkSpec: Equatable {
    /// Fires a gear at the enemy every `gearInterval`.
    var gearInterval: Double
    var gearSpeed: Double
    var gearDamage: Double
    /// Every `rewindInterval` it jumps back to where it was `rewindWindow` seconds ago, with the health it had then
    /// (if that was more).
    var rewindInterval: Double
    var rewindWindow: Double
}

struct PortalSpec: Equatable {
    /// Opens a pair of portals every `interval`: one in the enemy's path, one far across the arena.
    var interval: Double
    var radius: Double
    var lifetime: Double
    var maxPairs: Int
    /// Coming out of a portal hurts and flings the enemy toward the nearest wall.
    var damage: Double
    var fling: Double
}

struct GlitchSpec: Equatable {
    /// Teleports `jump` toward the enemy every `interval`, leaving an error tile where it was.
    var interval: Double
    var jump: Double
    var tileRadius: Double
    var tileLifetime: Double
    var maxTiles: Int
    var tileDamage: Double
    var tileStun: Double
    /// Blinking in right next to the enemy zaps it.
    var zapDamage: Double
}

struct TwinSpec: Equatable {
    /// Both twins bite on contact.
    var damage: Double
    var cooldown: Double
}

struct CellSpec: Equatable {
    /// Contact damage at the smallest size; each growth stage adds `damagePerStage` of it.
    var damage: Double
    var damagePerStage: Double
    var cooldown: Double
    /// Seconds per growth stage (taking damage speeds it up by `growthPerDamage` seconds per point).
    var growInterval: Double
    var growthPerDamage: Double
    var stages: Int
    /// Radius added per stage (fraction of the base size).
    var radiusPerStage: Double
    /// Damage soaked up while still growing (0.25 = 25% less).
    var membrane: Double
    /// The first time it's knocked out it splits: comes back with this share of its health, plus small cells.
    var splitHealth: Double
    var cellDamage: Double
    var cellLifetime: Double
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
    case moss(MossSpec)
    case magma(MagmaSpec)
    case wolf(WolfSpec)
    case fibonacci(FibonacciSpec)
    case wizard(WizardSpec)
    case clockwork(ClockworkSpec)
    case portal(PortalSpec)
    case glitch(GlitchSpec)
    case twin(TwinSpec)
    case cell(CellSpec)

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
        case .moss(let a): return a.cooldown
        case .magma(let a): return a.dropInterval
        case .wolf(let a): return a.cooldown
        case .fibonacci(let a): return a.interval
        case .wizard(let a): return a.interval
        case .clockwork(let a): return a.gearInterval
        case .portal(let a): return a.interval
        case .glitch(let a): return a.interval
        case .twin(let a): return a.cooldown
        case .cell(let a): return a.cooldown
        }
    }

    var stats: [(String, String)] {
        func f(_ v: Double) -> String { v.rounded() == v ? String(Int(v)) : String(format: "%.1f", v) }
        switch self {
        case .traps(let a): return [("Damage", f(a.damage)), ("Hold", "\(f(a.holdDuration))s"), ("Traps", "\(a.trapsPerDrop)×")]
        case .train(let a): return [("Damage", f(a.damage)), ("Trigger", "Wall"), ("Cooldown", "\(f(a.cooldown))s")]
        case .laser(let a): return [("Damage", f(a.damage)), ("Lasers", "\(a.maxLasers)"), ("Lasts", "\(f(a.lifetime))s")]
        case .zone(let a): return [("DPS", f(a.damagePerSecond)), ("Self-heal", "\(f(a.healPerSecond))/s"), ("Interval", "\(f(a.interval))s")]
        case .dice(let a): return [("Damage", "\(f(a.damagePerPip))–\(f(a.damagePerPip * 6))"), ("Dice", "\(a.maxDice)"), ("Interval", "\(f(a.interval))s")]
        case .shards(let a): return [("Shard dmg", f(a.damage)), ("Shards", "\(a.minShards)→\(a.maxShards)"), ("Trigger", "Impact")]
        case .knives(let a): return [("Damage", f(a.damage)), ("Rate", "\(f(a.slowInterval))→\(f(a.fastInterval))s"), ("Steal", "\(Int(a.stealFraction * 100))%")]
        case .tail(let a): return [("Damage", f(a.damage)), ("Max tail", "\(a.maxSegments)"), ("Grows", "\(f(a.growInterval))s")]
        case .shock(let a):
            let full = Double(a.maxCharge)
            return [("Damage", "\(f(a.damage))–\(f(a.damage + a.damagePerCharge * full))"),
                    ("Freeze", "\(f(a.freezeDuration))–\(f(a.freezeDuration + a.freezePerCharge * full))s"), ("Charge", "Walls")]
        case .bombs(let a):
            return a.spikes > 0
                ? [("Spike dmg", f(a.spikeDamage)), ("Spikes", "\(a.spikes)"), ("Freeze", "\(a.chillToFreeze) hits")]
                : [("Damage", f(a.damage)), ("Radius", f(a.radius)), ("Interval", "\(f(a.interval))s")]
        case .turrets(let a): return [("Shot dmg", f(a.damage)), ("Turrets", "\(a.maxTurrets)"), ("Fire rate", "\(f(a.fireInterval))s")]
        case .virus(let a): return [("Poison", "\(f(a.damagePerSecond))/s"), ("Lasts", "\(f(a.duration))s"), ("Stacks", "Yes")]
        case .harpoon(let a): return [("Damage", f(a.damage)), ("Drag", "\(f(a.dragDuration))s"), ("Interval", "\(f(a.interval))s")]
        case .swarm(let a): return [("Bees", "\(a.bees)"), ("Poison", "\(f(a.poisonPerSecond))/s"), ("Interval", "\(f(a.interval))s")]
        case .moss(let a): return [("Damage", f(a.damage)), ("Wall heal", f(a.wallHeal)), ("Cooldown", "\(f(a.cooldown))s")]
        case .magma(let a): return [("Burn", "\(f(a.damagePerSecond))/s"), ("Pools", "\(a.maxPools)"), ("Lasts", "\(f(a.poolLifetime))s")]
        case .wolf(let a): return [("Damage", "\(f(a.damage))–\(f(a.damage * (1 + a.maxBonus)))"), ("Cooldown", "\(f(a.cooldown))s"),
                                   ("Speed", "+\(Int(a.speedBonus * 100))%")]
        case .fibonacci(let a):
            return [("Damage", "\(f(Double(FibonacciSpec.number(at: a.startIndex)) * a.damageScale))–\(f(Double(FibonacciSpec.number(at: a.maxIndex)) * a.damageScale))"),
                    ("Interval", "\(f(a.interval))s"), ("Streak", "Hits")]
        case .clockwork(let a): return [("Gear dmg", f(a.gearDamage)), ("Rewind", "\(f(a.rewindInterval))s"), ("Window", "\(f(a.rewindWindow))s")]
        case .portal(let a): return [("Damage", f(a.damage)), ("Portals", "\(a.maxPairs * 2)"), ("Interval", "\(f(a.interval))s")]
        case .glitch(let a): return [("Tile dmg", f(a.tileDamage)), ("Stun", "\(f(a.tileStun))s"), ("Teleport", "\(f(a.interval))s")]
        case .twin(let a): return [("Damage", f(a.damage)), ("Balls", "2"), ("Cooldown", "\(f(a.cooldown))s")]
        case .cell(let a): return [("Damage", "\(f(a.damage))–\(f(a.damage * (1 + a.damagePerStage * Double(a.stages))))"),
                                   ("Membrane", "\(Int(a.membrane * 100))%"), ("Split", "Once")]
        case .wizard(let a): return [("Spells", "4"), ("Damage", "\(f(a.missileDamage * 3))–\(f(a.fireboltDamage))"), ("Interval", "\(f(a.interval))s")]
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
        "Plants ball-sized trap zones like mines, up to 4 at once. An enemy that rolls into one is locked in place and hurt.",
        .traps(TrapSpec(interval: 2.2, trapsPerDrop: 1, spread: 0, trapRadius: ballRadius, armDelay: 0.6, lifetime: 16,
                        maxTraps: 4, damage: 18, holdDuration: 1.6)))

    static let conductor = make("conductor", "Conductor", "Rail boss", "Express Line",
        "Hitting a wall lays a track across the arena. Moments later a train thunders down it and rams anything in the way.",
        .train(TrainSpec(cooldown: 2.4, warning: 0.6, trainSpeed: 760, damage: 34, knockback: 520, width: 40)))

    static let laser = make("laser", "Laser", "Grid maker", "Tripwire",
        "Every wall hit plants an emitter; the next hit on another wall links them with a laser beam. Up to 5 beams burn the enemy each time it crosses.",
        .laser(LaserSpec(cooldown: 0.6, maxLasers: 5, lifetime: 9, damage: 4.5, hitCooldown: 1)))

    static let zone = make("zone", "Zone", "Area denial", "Red Zone",
        "Paints a red danger zone that spreads out from where it stands. The enemy takes steady damage inside; Zone heals in its own turf.",
        .zone(ZoneSpec(interval: 3.5, radius: 115, growTime: 1.5, duration: 6, damagePerSecond: 12, healPerSecond: 2,
                       maxZones: 2)))

    static let dice = make("dice", "Dice", "Gambler", "Loaded Dice",
        "Throws dice at the enemy that tumble until they settle. Touching one hurts by its number, double while still rolling. Its own dice hurt it a little too.",
        .dice(DiceSpec(interval: 2.2, maxDice: 5, lifetime: 9, damagePerPip: 2.2, selfDamagePerPip: 0.3, dieSize: 15,
                       rerollCooldown: 1.2, throwSpeed: 700, tumblingMultiplier: 1.3)))

    static let glass = make("glass", "Glass", "Fragile menace", "Shatter",
        "Every hard impact scatters sharp glass shards in all directions. The more cracked Glass gets, the more shards fly.",
        .shards(ShardSpec(cooldown: 0.3, minShards: 7, maxShards: 18, shardSpeed: 520, damage: 4.5, minImpactSpeed: 80)))

    static let thief = make("thief", "Thief", "Knife thrower", "Cutpurse",
        "Throws knives that steal health. Bumping the enemy picks its pocket: it loses half its attack charge and eats a point-blank knife. Throws faster when hurt.",
        .knives(KnifeSpec(slowInterval: 1.6, fastInterval: 0.6, speed: 780, damage: 5.5, stealFraction: 0.1,
                          pickpocketCooldown: 3, pickpocketKnives: 1)))

    static let snake = make("snake", "Snake", "Slitherer", "Long Tail",
        "Slithers faster than other balls and grows a longer, thicker tail over time. The tail hurts and knocks back the enemy on contact.",
        .tail(TailSpec(growInterval: 0.8, maxSegments: 28, segmentSpacing: 20, minSegmentRadius: 12, maxSegmentRadius: 22,
                       damage: 14, knockback: 380, hitCooldown: 0.4, speedMultiplier: 1.2)))

    static let electric = make("electric", "Electric", "Live wire", "Stun Shock",
        "Every wall bounce stores a charge. Bumping the enemy dumps it all: more charge, bigger shock and longer freeze. Fully charged, it arcs lightning from a distance.",
        .shock(ShockSpec(cooldown: 2, damage: 8, damagePerCharge: 3, freezeDuration: 0.5, freezePerCharge: 0.15,
                         maxCharge: 4, arcRange: 110)))

    static let iceCone = make("icecone", "Ice Cone", "Frost bomber", "Ice Burst",
        "Drops ice bombs that burst into a ring of icy spikes. Every 2 spike hits freeze the enemy solid.",
        .bombs(BombSpec(interval: 2.5, fuse: 0.9, radius: 70, damage: 8, knockback: 150, spikes: 14, spikeSpeed: 430,
                        spikeDamage: 8, icy: true, throwSpeed: 0, chainRadius: 0, chillToFreeze: 2, freezeDuration: 1.3)))

    static let cannon = make("cannon", "Cannon", "Artillery", "Wall Turrets",
        "Each wall hit can mount a turret on the wall that keeps shooting the enemy. Up to 5; a new one replaces the oldest.",
        .turrets(TurretSpec(cooldown: 2.4, maxTurrets: 5, fireInterval: 1.6, shotSpeed: 600, damage: 5.5)))

    static let bomb = make("bomb", "Bomb", "Demolition", "Kaboom",
        "Rolls bombs at the enemy that go off early if it gets close. Blasts set off nearby bombs in a chain reaction.",
        .bombs(BombSpec(interval: 2.1, fuse: 1.6, radius: 120, damage: 17, knockback: 460, spikes: 0, spikeSpeed: 0,
                        spikeDamage: 0, icy: false, throwSpeed: 650, chainRadius: 110, chillToFreeze: 0, freezeDuration: 0)))

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

    static let moss = make("moss", "Moss", "Evergreen", "Overgrowth",
        "Covered in thorny moss that scratches on touch. Every wall bounce mends a little health, so it wins the long game.",
        .moss(MossSpec(damage: 9, cooldown: 0.8, wallHeal: 4, healCooldown: 0.35)))

    static let magma = make("magma", "Magma", "Molten core", "Lava Trail",
        "Leaves a trail of lava pools as it rolls, and touching it sets the enemy on fire. The enemy burns while standing in lava.",
        .magma(MagmaSpec(dropInterval: 0.25, poolRadius: 32, poolLifetime: 3.5, maxPools: 18, damagePerSecond: 11,
                         ignitePerSecond: 3, igniteDuration: 2.5, igniteCooldown: 1)))

    static let wolf = FighterDefinition(id: "wolf", name: "Wolf", tagline: "Pack hunter", attackName: "Smell Blood",
        attackDescription: "Bites on contact. The weaker the enemy gets, the harder it bites (up to 80% harder) and the faster it runs.",
        maxHealth: 100, radius: ballRadius, mass: 1,
        attack: .arsenal(.wolf(WolfSpec(damage: 11, cooldown: 0.6, maxBonus: 0.8, speedBonus: 0.3))))

    static let fibonacci = make("fibonacci", "Fibonacci", "Golden ratio", "Sequence",
        "Fires number bolts. Every hit in a row deals the next Fibonacci number: 2, 3, 5, 8, 13, 21. Taking a big hit halves the streak.",
        .fibonacci(FibonacciSpec(interval: 1, speed: 620, startIndex: 2, floorIndex: 2, maxIndex: 7, damageScale: 0.3,
                                 breakDamage: 15)))

    static let wizard = make("wizard", "Wizard", "Spellcaster", "Random Spell",
        "Casts a random spell every few seconds: a homing Firebolt, a slowing Frost Nova, a Lightning strike or three Arcane Missiles.",
        .wizard(WizardSpec(interval: 1.9, noRepeat: false, fireboltDamage: 13, frostDamage: 3, lightningDamage: 11,
                           missileDamage: 3.5)))

    static let clockwork = make("clockwork", "Clockwork", "Time keeper", "Rewind",
        "Fires gears at the enemy. Every 9 seconds it rewinds to where it was 3 seconds ago, healing back the health it lost since.",
        .clockwork(ClockworkSpec(gearInterval: 1.2, gearSpeed: 560, gearDamage: 6, rewindInterval: 9, rewindWindow: 3)))

    static let portal = make("portal", "Portal", "Space bender", "Wormhole",
        "Opens pairs of portals, one right in the enemy's path. Rolling into one throws it out of the other, hurt and flung toward a wall.",
        .portal(PortalSpec(interval: 3, radius: 28, lifetime: 6, maxPairs: 2, damage: 8.5, fling: 650)))

    static let glitch = make("glitch", "Glitch", "Error 404", "Blink",
        "Blinks toward the enemy every couple of seconds, zapping it if it lands close, and leaves an error tile behind. Rolling over a tile hurts and freezes the enemy for a moment.",
        .glitch(GlitchSpec(interval: 2, jump: 160, tileRadius: 34, tileLifetime: 5, maxTiles: 7, tileDamage: 8, tileStun: 0.3,
                           zapDamage: 4)))

    static let twin = FighterDefinition(id: "twin", name: "Twin", tagline: "Double trouble", attackName: "Two of a Kind",
        attackDescription: "Two smaller balls that both bite on contact. Only the main one can be hurt; its twin keeps bouncing in to help.",
        maxHealth: 110, radius: ballRadius * 0.8, mass: 0.8,
        attack: .arsenal(.twin(TwinSpec(damage: 7.5, cooldown: 0.6))))

    static let cell = make("cell", "Cell", "Living blob", "Mitosis",
        "Grows bigger and hits harder over time, faster when it takes damage, and a membrane soaks up damage while it grows. The first time it's knocked out, it splits instead: back at 35% health, plus small cells that pop on the enemy.",
        .cell(CellSpec(damage: 6.5, damagePerStage: 0.3, cooldown: 0.7, growInterval: 5.5, growthPerDamage: 0.12, stages: 3,
                       radiusPerStage: 0.12, membrane: 0.25, splitHealth: 0.35, cellDamage: 6, cellLifetime: 8)))

    static let arsenal: [FighterDefinition] = [
        shackle, conductor, laser, zone, dice, glass, thief, snake, electric, iceCone, cannon, bomb, virus, harpoon, hive,
        moss, magma, wolf, fibonacci, wizard, clockwork, portal, glitch, twin, cell,
    ]
}
