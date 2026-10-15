import Foundation

// MARK: - Attack configuration
//
// Each attack kind has its own settings struct. To add a new fighter, add a
// `FighterDefinition` to `FighterCatalog.all` that reuses one of these attack kinds.
// To add a new kind of attack, add a case to `AttackSpec` and handle it in
// `AttackSystem` (Battle/AttackSystem.swift) and `FighterArt` (Rendering/FighterArt.swift).

struct ProjectileAttack: Equatable {
    /// Seconds between shots.
    var interval: Double
    var damage: Double
    var projectileSpeed: Double
    var projectileRadius: Double
    /// Safety limit; projectiles normally vanish on hitting a wall first.
    var maxLifetime: Double
}

struct ContactAttack: Equatable {
    /// Damage scales with how fast Spike is ramming into the opponent:
    /// `minDamage` when barely moving toward them, `maxDamage` at `fullDamageSpeed` or faster.
    var minDamage: Double
    var maxDamage: Double
    var fullDamageSpeed: Double
    /// Minimum seconds between two contact hits, so sustained contact
    /// can't deal damage every frame.
    var cooldown: Double
    var spikeCount: Int
    var spikeLength: Double
}

struct PulseAttack: Equatable {
    /// Seconds between shockwaves.
    var interval: Double
    var damage: Double
    /// Distance from the Pulse ball's center to the opponent's edge that counts as a hit.
    var range: Double
    /// How long the ring takes to expand to full range.
    var expandDuration: Double
    /// Velocity added to the opponent, pointing away from the pulse center.
    var knockback: Double
}

struct GrabAttack: Equatable {
    /// Seconds to recharge after a grab ends.
    var cooldown: Double
    /// Max edge-to-edge gap at which the opponent can be grabbed.
    var reach: Double
    /// How long the opponent is swung around before being thrown.
    var swingDuration: Double
    /// Spin rate (radians/second) at the start and end of the swing.
    var startSpinSpeed: Double
    var endSpinSpeed: Double
    /// Launch speed of the thrown opponent (allowed to exceed the normal max speed).
    var throwSpeed: Double
    /// Damage when the opponent hits a wall, either mid-swing or after the throw.
    var smashDamage: Double
    /// A throw that hasn't reached a wall after this long fizzles.
    var throwTimeout: Double
}

struct WebAttack: Equatable {
    /// Threads alive at once; the oldest is removed when a new one is spun.
    var maxThreads: Int
    /// Seconds a thread lasts.
    var threadLifetime: Double
    /// Damage when the opponent crosses a thread. The thread snaps on hit.
    var damage: Double
    /// Extra hit width of a thread on top of the opponent's radius.
    var thickness: Double
    var legLength: Double
}

struct DrainAttack: Equatable {
    /// Seconds to recharge after a drain ends.
    var cooldown: Double
    /// Max edge-to-edge gap at which the Vampire can latch on.
    var reach: Double
    /// How long the tether holds.
    var duration: Double
    /// Damage per second to the opponent while latched.
    var drainPerSecond: Double
    /// Fraction of the drained damage the Vampire heals. Below 1 so a Vampire mirror can't stalemate.
    var healFraction: Double
    /// Healing can push the Vampire above its max health by up to this much.
    var maxOverheal: Double
    /// Drain is applied in chunks this often.
    var tickInterval: Double
    /// Extra slack on the tether before it pulls the two balls together.
    var tetherSlack: Double
}

struct ChessAttack: Equatable {
    /// Seconds between chess moves.
    var interval: Double
    /// Pause before moving, while the destination square is shown.
    var thinkDuration: Double
    /// Dash speed along the move path.
    var moveSpeed: Double
    /// Damage if the opponent is touched during the move (once per move).
    var damage: Double
    /// Velocity added to the opponent when hit.
    var knockback: Double
}

struct EclipseAttack: Equatable {
    /// Seconds for the moon to slide from clear to the stall point.
    var chargeTime: Double
    /// Coverage (0…1) where the moon stalls on a thin crescent.
    var stallCoverage: Double
    /// The stall lasts a random time in this range.
    var minStall: Double
    var maxStall: Double
    /// Guaranteed damage at totality.
    var damage: Double
    /// How long the arena stays dark after totality.
    var darknessDuration: Double
}

enum AttackSpec: Equatable {
    case projectile(ProjectileAttack)
    case contact(ContactAttack)
    case pulse(PulseAttack)
    case grab(GrabAttack)
    case web(WebAttack)
    case drain(DrainAttack)
    case chess(ChessAttack)
    case eclipse(EclipseAttack)
    /// Second-wave fighters built from shared hazard / projectile / status systems.
    case arsenal(ArsenalAttack)

    /// Only attacks that fire in a chosen direction need the aim picker.
    var requiresAim: Bool {
        if case .projectile = self { return true }
        return false
    }
}

// MARK: - Fighter definition

struct FighterDefinition: Identifiable, Equatable {
    let id: String
    let name: String
    let tagline: String
    let attackName: String
    let attackDescription: String
    let maxHealth: Double
    let radius: Double
    let mass: Double
    let attack: AttackSpec

    var requiresAim: Bool { attack.requiresAim }

    /// Furthest extent of the fighter's drawn body (spikes and legs stick out past the radius).
    var visualRadius: Double {
        switch attack {
        case .contact(let c): return radius + c.spikeLength
        case .web(let w): return radius + w.legLength * 0.6
        case .grab: return radius + 6
        case .drain: return radius + 10
        case .chess: return radius + 4
        case .eclipse: return radius + 10
        case .arsenal: return radius + 8
        default: return radius
        }
    }

    /// Human-readable stats shown on the fighter cards.
    var stats: [(label: String, value: String)] {
        var lines: [(String, String)] = [("HP", Self.format(maxHealth))]
        switch attack {
        case .projectile(let a):
            lines += [("Damage", Self.format(a.damage)),
                      ("Interval", "\(Self.format(a.interval))s"),
                      ("Shot speed", Self.format(a.projectileSpeed))]
        case .contact(let a):
            lines += [("Damage", "\(Self.format(a.minDamage))–\(Self.format(a.maxDamage))"),
                      ("Cooldown", "\(Self.format(a.cooldown))s"),
                      ("Range", "Touch")]
        case .pulse(let a):
            lines += [("Damage", Self.format(a.damage)),
                      ("Interval", "\(Self.format(a.interval))s"),
                      ("Range", Self.format(a.range))]
        case .grab(let a):
            lines += [("Slam dmg", Self.format(a.smashDamage)),
                      ("Cooldown", "\(Self.format(a.cooldown))s"),
                      ("Reach", Self.format(a.reach))]
        case .web(let a):
            lines += [("Damage", Self.format(a.damage)),
                      ("Threads", "\(a.maxThreads)"),
                      ("Lasts", "\(Self.format(a.threadLifetime))s")]
        case .drain(let a):
            lines += [("Drain", "\(Self.format(a.drainPerSecond))/s"),
                      ("Max HP", Self.format(maxHealth + a.maxOverheal)),
                      ("Cooldown", "\(Self.format(a.cooldown))s")]
        case .chess(let a):
            lines += [("Damage", Self.format(a.damage)),
                      ("Interval", "\(Self.format(a.interval))s"),
                      ("Pieces", "5")]
        case .eclipse(let a):
            lines += [("Damage", Self.format(a.damage)),
                      ("Charge", "\(Self.format(a.chargeTime))s"),
                      ("Stall", "\(Self.format(a.minStall))–\(Self.format(a.maxStall))s")]
        case .arsenal(let a):
            lines += a.stats
        }
        return lines
    }

    private static func format(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value)
    }
}

// MARK: - Fighter balance values (edit these to rebalance)

nonisolated enum FighterCatalog {
    /// Shared body size for every fighter.
    static let ballRadius: Double = 38

    static let blaster = FighterDefinition(
        id: "blaster",
        name: "Blaster",
        tagline: "Long-range turret",
        attackName: "Auto-Shot",
        attackDescription: "Fires a bolt every 1.2s in the direction you aim. The aim stays locked to the arena no matter how it bounces.",
        maxHealth: 100,
        radius: ballRadius,
        mass: 1,
        attack: .projectile(ProjectileAttack(
            interval: 1.2,
            damage: 34,
            projectileSpeed: 900,
            projectileRadius: 16,
            maxLifetime: 3
        ))
    )

    static let spike = FighterDefinition(
        id: "spike",
        name: "Spike",
        tagline: "Close-quarters brawler",
        attackName: "Spike Ram",
        attackDescription: "Damages the opponent on every collision — the faster it rams in, the harder it hits. Short cooldown between hits.",
        maxHealth: 100,
        radius: ballRadius,
        mass: 1,
        attack: .contact(ContactAttack(
            minDamage: 9,
            maxDamage: 17,
            fullDamageSpeed: 420,
            cooldown: 0.6,
            spikeCount: 10,
            spikeLength: 11
        ))
    )

    static let pulse = FighterDefinition(
        id: "pulse",
        name: "Pulse",
        tagline: "Area controller",
        attackName: "Shockwave",
        attackDescription: "Releases a circular shockwave every 2.5s that damages and knocks back a nearby opponent.",
        maxHealth: 100,
        radius: ballRadius,
        mass: 1,
        attack: .pulse(PulseAttack(
            interval: 2.5,
            damage: 19,
            range: 170,
            expandDuration: 0.32,
            knockback: 420
        ))
    )

    static let grappler = FighterDefinition(
        id: "grappler",
        name: "Grappler",
        tagline: "Wrestler",
        attackName: "Spin Slam",
        attackDescription: "Grabs a nearby opponent, spins it around and hurls it. Deals damage when the opponent smashes into a wall.",
        maxHealth: 100,
        radius: ballRadius,
        mass: 1,
        attack: .grab(GrabAttack(
            cooldown: 3.8,
            reach: 55,
            swingDuration: 0.7,
            startSpinSpeed: 5,
            endSpinSpeed: 12,
            throwSpeed: 950,
            smashDamage: 22,
            throwTimeout: 1.2
        ))
    )

    static let weaver = FighterDefinition(
        id: "weaver",
        name: "Spider",
        tagline: "Trap layer",
        attackName: "Web Line",
        attackDescription: "Every wall bounce spins a web thread from the wall to itself. The opponent takes damage crossing a thread, which snaps.",
        maxHealth: 100,
        radius: ballRadius,
        mass: 1,
        attack: .web(WebAttack(
            maxThreads: 3,
            threadLifetime: 7,
            damage: 7,
            thickness: 3,
            legLength: 18
        ))
    )

    static let vampire = FighterDefinition(
        id: "vampire",
        name: "Vampire",
        tagline: "Life stealer",
        attackName: "Life Drain",
        attackDescription: "Latches onto a nearby opponent with a tether, draining its health and healing itself with most of what it steals — even past full health.",
        maxHealth: 100,
        radius: ballRadius,
        mass: 1,
        attack: .drain(DrainAttack(
            cooldown: 4.5,
            reach: 50,
            duration: 1.6,
            drainPerSecond: 11,
            healFraction: 0.6,
            maxOverheal: 50,
            tickInterval: 0.4,
            tetherSlack: 70
        ))
    )

    static let gambit = FighterDefinition(
        id: "gambit",
        name: "Gambit",
        tagline: "Chess master",
        attackName: "Chess Move",
        attackDescription: "Every few seconds it plays a random chess move — king, queen, rook, bishop or knight — across the board, hurting anything in its way.",
        maxHealth: 100,
        radius: ballRadius,
        mass: 1,
        attack: .chess(ChessAttack(
            interval: 1.7,
            thinkDuration: 0.3,
            moveSpeed: 1200,
            damage: 24,
            knockback: 380
        ))
    )

    static let eclipse = FighterDefinition(
        id: "eclipse",
        name: "Eclipse",
        tagline: "Celestial sniper",
        attackName: "Totality",
        attackDescription: "A moon slowly slides across its face. Just before full eclipse it stalls for a random, tense moment — then totality strikes the enemy wherever they are.",
        maxHealth: 100,
        radius: ballRadius,
        mass: 1,
        attack: .eclipse(EclipseAttack(
            chargeTime: 8.2,
            stallCoverage: 0.94,
            minStall: 1,
            maxStall: 4,
            damage: 38,
            darknessDuration: 0.7
        ))
    )

    static let base: [FighterDefinition] = [blaster, spike, pulse, grappler, weaver, vampire, gambit, eclipse]

    static let all: [FighterDefinition] = base + arsenal

    static func definition(id: String) -> FighterDefinition? {
        all.first { $0.id == id }
    }
}
