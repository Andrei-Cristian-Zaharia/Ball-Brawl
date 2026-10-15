import Foundation

/// What a player locked in during setup.
struct FighterLoadout: Equatable {
    var definition: FighterDefinition
    /// Firing direction in arena space (radians, 0 = right, π/2 = down).
    /// Ignored by fighters that don't require aim.
    var aimAngle: Double
    /// Health to start the battle with (carried over between rounds in bot mode). Defaults to full.
    var startingHealth: Double? = nil
}

struct MatchSetup: Equatable {
    /// Indexed by `PlayerSlot.rawValue`.
    var loadouts: [FighterLoadout]
    /// Short names shown above the balls and in the HUD, indexed by slot.
    var labels: [String] = PlayerSlot.allCases.map(\.label)

    func loadout(for slot: PlayerSlot) -> FighterLoadout { loadouts[slot.rawValue] }
}

enum BattleOutcome: Equatable {
    case winner(PlayerSlot)
    case draw
}

enum GrabPhase: Equatable {
    case idle
    /// Holding the opponent and spinning it around.
    case swinging(angle: Double, direction: Double, elapsed: Double)
    /// Opponent released and flying toward a wall.
    case thrown(elapsed: Double)
}

enum DrainPhase: Equatable {
    case idle
    case draining(elapsed: Double, tick: Double)
}

enum ChessPiece: CaseIterable {
    case king, queen, rook, bishop, knight

    var name: String {
        switch self {
        case .king: return "King"
        case .queen: return "Queen"
        case .rook: return "Rook"
        case .bishop: return "Bishop"
        case .knight: return "Knight"
        }
    }

    var glyph: String {
        switch self {
        case .king: return "♚"
        case .queen: return "♛"
        case .rook: return "♜"
        case .bishop: return "♝"
        case .knight: return "♞"
        }
    }

    /// Board squares this piece can reach from (col, row), ignoring other pieces.
    func destinations(col: Int, row: Int, cols: Int, rows: Int) -> [(col: Int, row: Int)] {
        let straight = [(1, 0), (-1, 0), (0, 1), (0, -1)]
        let diagonal = [(1, 1), (1, -1), (-1, 1), (-1, -1)]
        func inside(_ c: Int, _ r: Int) -> Bool { c >= 0 && c < cols && r >= 0 && r < rows }
        func slides(_ dirs: [(Int, Int)]) -> [(col: Int, row: Int)] {
            dirs.flatMap { d in
                (1..<max(cols, rows)).map { (col + d.0 * $0, row + d.1 * $0) }.filter { inside($0.0, $0.1) }
            }.map { (col: $0.0, row: $0.1) }
        }
        switch self {
        case .king:
            return (straight + diagonal).map { (col: col + $0.0, row: row + $0.1) }.filter { inside($0.col, $0.row) }
        case .knight:
            return [(1, 2), (2, 1), (-1, 2), (-2, 1), (1, -2), (2, -1), (-1, -2), (-2, -1)]
                .map { (col: col + $0.0, row: row + $0.1) }.filter { inside($0.col, $0.row) }
        case .rook: return slides(straight)
        case .bishop: return slides(diagonal)
        case .queen: return slides(straight + diagonal)
        }
    }
}

struct ChessMove: Equatable {
    let piece: ChessPiece
    /// Polyline from the start position to the destination square (knights take an L).
    let path: [Vec2]
    var destination: Vec2 { path[path.count - 1] }

    var length: Double {
        zip(path, path.dropFirst()).reduce(0) { $0 + ($1.1 - $1.0).length }
    }

    func point(at distance: Double) -> Vec2 {
        var remaining = distance
        for (a, b) in zip(path, path.dropFirst()) {
            let leg = (b - a).length
            if remaining <= leg { return leg > 0 ? a + (b - a) * (remaining / leg) : b }
            remaining -= leg
        }
        return destination
    }
}

enum ChessPhase: Equatable {
    case idle
    /// Frozen in place, showing the chosen move.
    case thinking(move: ChessMove, elapsed: Double, savedVelocity: Vec2)
    /// Dashing along the move path.
    case moving(move: ChessMove, traveled: Double, savedVelocity: Vec2, hasHit: Bool)
}

enum EclipsePhase: Equatable {
    /// Moon sliding across; progress is `attackTimer / chargeTime`.
    case waxing
    /// Stuck on a thin crescent for a random time.
    case stalling(remaining: Double)
    /// Just struck; the arena is dark.
    case totality(elapsed: Double)
}

struct FighterState {
    let slot: PlayerSlot
    let definition: FighterDefinition
    /// Fixed aim direction in arena space; independent of movement and rotation.
    let aim: Vec2
    /// Index of this fighter's body in `PhysicsWorld.bodies`.
    let bodyIndex: Int

    var health: Double
    /// Seconds accumulated toward the next timed attack (projectile / pulse).
    var attackTimer: Double = 0
    /// Seconds left before a contact attack can hit again.
    var contactCooldown: Double = 0
    /// Grappler state machine.
    var grabPhase: GrabPhase = .idle
    /// Weaver web threads currently alive.
    var activeThreads = 0
    /// Vampire state machine.
    var drainPhase: DrainPhase = .idle
    /// Gambit state machine.
    var chessPhase: ChessPhase = .idle
    /// Eclipse state machine.
    var eclipsePhase: EclipsePhase = .waxing

    /// How much of an Eclipse's face is covered (0…1), for drawing and the HUD.
    var eclipseCoverage: Double {
        guard case .eclipse(let a) = definition.attack else { return 0 }
        switch eclipsePhase {
        case .waxing: return min(1, attackTimer / a.chargeTime) * a.stallCoverage
        case .stalling: return a.stallCoverage
        case .totality: return 1
        }
    }

    // Arsenal fighters and status effects.
    /// Snake tail length in segments.
    var tailSegments = 0
    /// Harpoon: seconds left of dragging the opponent in.
    var dragRemaining: Double = 0
    /// Hazards this fighter currently owns (traps, lasers, dice…), for the HUD.
    var activeHazards = 0
    /// Poison applied *to* this fighter.
    var poisonPerSecond: Double = 0
    var poisonRemaining: Double = 0
    var poisonTick: Double = 0
    /// Locked in place (shocked or caught in a trap).
    var holdRemaining: Double = 0
    var holdStyle: HoldStyle = .shock
    /// Velocity to restore when a hold ends.
    var heldVelocity: Vec2 = .zero

    var isPoisoned: Bool { poisonRemaining > 0 && poisonPerSecond > 0 }
    var isHeld: Bool { holdRemaining > 0 }

    // Presentation-only values, advanced by the simulation so they pause with it.
    var spin: Double = 0
    var previousSpin: Double = 0
    var flash: Double = 0
    var trailingHealth: Double

    var isDefeated: Bool { health <= 0 }

    /// 0…1 readiness of the automatic attack, for cooldown indicators.
    var attackCharge: Double {
        switch definition.attack {
        case .projectile(let a): return min(1, attackTimer / a.interval)
        case .pulse(let a): return min(1, attackTimer / a.interval)
        case .contact(let a): return 1 - min(1, contactCooldown / a.cooldown)
        case .grab(let a): return grabPhase == .idle ? min(1, attackTimer / a.cooldown) : 1
        case .web(let a): return Double(activeThreads) / Double(a.maxThreads)
        case .drain(let a): return drainPhase == .idle ? min(1, attackTimer / a.cooldown) : 1
        case .chess(let a): return chessPhase == .idle ? min(1, attackTimer / a.interval) : 1
        case .eclipse: return eclipseCoverage
        case .arsenal(let a):
            switch a {
            case .tail(let t): return Double(tailSegments) / Double(t.maxSegments)
            case .shock(let t): return 1 - min(1, contactCooldown / t.cooldown)
            case .virus(let t): return 1 - min(1, contactCooldown / t.cooldown)
            case .knives(let k): return min(1, attackTimer / ArsenalSystem.knifeInterval(k, fighter: self))
            default: return min(1, attackTimer / (a.interval ?? 1))
            }
        }
    }

    /// Seconds until the attack is ready (0 when a contact attack is armed).
    var secondsUntilReady: Double {
        switch definition.attack {
        case .projectile(let a): return max(0, a.interval - attackTimer)
        case .pulse(let a): return max(0, a.interval - attackTimer)
        case .contact: return max(0, contactCooldown)
        case .grab(let a): return grabPhase == .idle ? max(0, a.cooldown - attackTimer) : 0
        case .web: return 0
        case .drain(let a): return drainPhase == .idle ? max(0, a.cooldown - attackTimer) : 0
        case .chess(let a): return chessPhase == .idle ? max(0, a.interval - attackTimer) : 0
        case .eclipse(let a): return eclipsePhase == .waxing ? max(0, a.chargeTime - attackTimer) : 0
        case .arsenal(let a):
            switch a {
            case .tail: return 0
            case .shock, .virus: return max(0, contactCooldown)
            case .knives(let k): return max(0, ArsenalSystem.knifeInterval(k, fighter: self) - attackTimer)
            default: return max(0, (a.interval ?? 0) - attackTimer)
            }
        }
    }
}

enum HoldStyle {
    case shock
    case shackle
}

enum ProjectileKind {
    case bolt
    case knife
    case shard
    case bee
    case harpoon
    case iceSpike
    case cannonball
}

struct Projectile {
    let owner: PlayerSlot
    var position: Vec2
    var previousPosition: Vec2
    var velocity: Vec2
    let radius: Double
    let baseDamage: Double
    var age: Double = 0
    let maxLifetime: Double
    var kind: ProjectileKind = .bolt
    /// Homing projectiles steer toward the opponent at this rate (radians/second).
    var turnRate: Double = 0
    /// Poison applied on hit (per second, duration).
    var poison: (perSecond: Double, duration: Double)? = nil
}

/// Something an arsenal fighter leaves on the field.
struct Hazard {
    enum Kind {
        case trap(armIn: Double)
        case zone
        case die(value: Int)
        case laser(end: Vec2)
        case bomb(fuse: Double)
        case turret(fireTimer: Double)
        /// Track from `position` to `end`; the train waits `warning`, then runs (progress 0…1).
        case track(end: Vec2, warning: Double, progress: Double, hasHit: Bool)
    }

    let owner: PlayerSlot
    var kind: Kind
    var position: Vec2
    let radius: Double
    var age: Double = 0
    let lifetime: Double
    /// Per-hazard hit cooldown so standing on it doesn't hit every frame.
    var hitCooldown: Double = 0
    /// Random spin for drawing dice and bombs.
    let rotation: Double
}

struct PulseWave {
    let owner: PlayerSlot
    /// The shockwave is released at a point and expands from there.
    let center: Vec2
    let startRadius: Double
    let range: Double
    let expandDuration: Double
    let baseDamage: Double
    let knockback: Double
    var age: Double = 0
    /// Each pulse may hit the opponent at most once.
    var hasHit = false

    static let fadeDuration = 0.2

    var progress: Double { min(1, age / expandDuration) }
    var radius: Double {
        let t = progress
        let eased = 1 - (1 - t) * (1 - t) // ease-out
        return startRadius + (range - startRadius) * eased
    }
    var isFinished: Bool { age >= expandDuration + Self.fadeDuration }
}

/// A Weaver thread, stretched from a wall anchor to its owner's ball.
struct WebThread {
    let owner: PlayerSlot
    let anchor: Vec2
    var age: Double = 0
    let lifetime: Double
}

enum DamageSource {
    case projectile
    case contact
    case pulse
    case slam
    case web
    case drain
    case chess
    case eclipse
    case poison
    case hazard
    case explosion
    case shard
    case shock
    case tail
    case train
}

struct DamageEvent {
    let target: PlayerSlot
    let amount: Double
    let point: Vec2
    let source: DamageSource
    /// Direction the hit came from (for particles).
    let direction: Vec2
}

/// Notable moments the effects / haptics layers react to.
enum BattleEvent {
    case launched
    case projectileFired(owner: PlayerSlot, position: Vec2, direction: Vec2)
    case projectileHitWall(owner: PlayerSlot, position: Vec2)
    case pulseReleased(owner: PlayerSlot, position: Vec2)
    case grabbed(by: PlayerSlot, position: Vec2)
    case thrown(by: PlayerSlot, position: Vec2)
    case webSpun(owner: PlayerSlot, anchor: Vec2)
    case webSnapped(owner: PlayerSlot, point: Vec2)
    case latched(by: PlayerSlot, position: Vec2)
    case healed(PlayerSlot, amount: Double, position: Vec2)
    case chessPlanned(PlayerSlot, piece: ChessPiece, position: Vec2)
    case chessLanded(PlayerSlot, position: Vec2)
    case totality(by: PlayerSlot, target: Vec2)
    case hazardPlaced(owner: PlayerSlot, position: Vec2)
    case explosion(owner: PlayerSlot, position: Vec2, radius: Double, icy: Bool)
    case held(PlayerSlot, position: Vec2)
    case poisoned(PlayerSlot, position: Vec2)
    case trainDeparted(owner: PlayerSlot, position: Vec2)
    case ballCollision(point: Vec2, impactSpeed: Double)
    case wallBounce(point: Vec2, impactSpeed: Double)
    case damage(DamageEvent)
    case defeated(PlayerSlot, position: Vec2)
    case overtimeStarted
}

/// All gameplay state touched by the attack system.
struct BattleState {
    var world: PhysicsWorld
    var fighters: [FighterState]
    var projectiles: [Projectile] = []
    var pulses: [PulseWave] = []
    var threads: [WebThread] = []
    var hazards: [Hazard] = []
    /// Snake tail points per fighter slot (oldest first).
    var tails: [[Vec2]] = [[], []]
    var battleTime: Double = 0
    /// Seeded randomness for attacks that need it (Gambit's moves).
    var rng = SplitMix64(seed: 0)

    var damageMultiplier: Double { GameConfig.overtime.damageMultiplier(at: battleTime) }

    func fighter(_ slot: PlayerSlot) -> FighterState { fighters[slot.rawValue] }
    func body(of slot: PlayerSlot) -> PhysicsBody { world.bodies[fighters[slot.rawValue].bodyIndex] }
}
