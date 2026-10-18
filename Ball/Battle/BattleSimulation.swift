import Foundation

/// Seedable RNG so a match's launch angles are reproducible from its seed.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Owns one match: countdown → fighting → finished. Advanced only in fixed steps.
final class BattleSimulation {
    enum Phase: Equatable {
        case countdown
        case fighting
        case finished(BattleOutcome)
    }

    /// Display names for each slot ("P1"/"P2", or "YOU"/"BOT").
    let labels: [String]
    private(set) var state: BattleState
    private(set) var phase: Phase = .countdown
    private(set) var effects = EffectsState()
    /// Total simulated time including the countdown.
    private(set) var elapsed: Double = 0
    private(set) var timeSinceFinish: Double = 0
    /// Events from the most recent steps; drained by the presentation layer (haptics).
    private(set) var pendingEvents: [BattleEvent] = []
    /// Recent positions per fighter (newest last), for motion trails.
    private(set) var trails: [[Vec2]] = [[], []]
    private var trailTick = 0
    private static let trailLength = 14

    private var rng: SplitMix64
    /// Random by default; players can re-aim them during the countdown.
    private(set) var launchVelocities: [Vec2]
    let steerableSlots: Set<PlayerSlot>
    let map: ArenaMap
    /// Online: the launch waits at the end of the countdown until both final directions are locked,
    /// so both devices start the fight from exactly the same state.
    var waitsForLaunchLock = false
    private(set) var lockedSlots: Set<PlayerSlot> = []
    var isWaitingForLaunchLock: Bool { waitsForLaunchLock && phase == .countdown && countdownRemaining <= 0 }
    /// Ability previews only: drawn without the "FIGHT!" banner, since the clip loops.
    var isPreview = false

    init(setup: MatchSetup, seed: UInt64) {
        rng = SplitMix64(seed: seed)
        labels = setup.labels
        steerableSlots = setup.steerableSlots
        map = setup.map
        let width = GameConfig.arenaWidth
        let height = GameConfig.arenaHeight
        var world = PhysicsWorld(width: width, height: height, settings: GameConfig.physics)
        var fighters: [FighterState] = []

        for slot in PlayerSlot.allCases {
            let loadout = setup.loadout(for: slot)
            let def = loadout.definition
            let y = slot == .one ? height * GameConfig.spawnHeightFraction : height * (1 - GameConfig.spawnHeightFraction)
            var body = PhysicsBody(position: Vec2(width / 2, y), radius: def.radius, mass: def.mass)
            if case .arsenal(.tail(let tail)) = def.attack { body.speedScale = tail.speedMultiplier }
            world.bodies.append(body)
            fighters.append(FighterState(
                slot: slot,
                definition: def,
                aim: Vec2.fromAngle(loadout.aimAngle),
                bodyIndex: world.bodies.count - 1,
                health: loadout.startingHealth ?? def.maxHealth,
                trailingHealth: loadout.startingHealth ?? def.maxHealth
            ))
        }

        for i in fighters.indices { fighters[i].baseSpeedScale = world.bodies[fighters[i].bodyIndex].speedScale }
        state = BattleState(world: world, fighters: fighters)
        state.rng = SplitMix64(seed: seed ^ 0xC0FF_EE00_D15E_A5E5)

        // Same speed for both (unless a fighter is naturally faster), independently randomized directions.
        var velocities: [Vec2] = []
        for slot in PlayerSlot.allCases {
            let speed = GameConfig.physics.launchSpeed * world.bodies[fighters[slot.rawValue].bodyIndex].speedScale
            velocities.append(Vec2.fromAngle(Self.randomLaunchAngle(using: &rng), length: speed))
        }
        launchVelocities = velocities
    }

    private static func randomLaunchAngle(using rng: inout SplitMix64) -> Double {
        let avoid = GameConfig.launchAxisAvoidance
        // Pick a quadrant, then an angle inside it that stays clear of the axes.
        let quadrant = Double(Int.random(in: 0..<4, using: &rng))
        return quadrant * .pi / 2 + Double.random(in: avoid...(.pi / 2 - avoid), using: &rng)
    }

    /// Points a fighter's launch toward `angle` (radians, arena space). Only during the countdown.
    func setLaunchAngle(_ angle: Double, for slot: PlayerSlot) {
        guard phase == .countdown, steerableSlots.contains(slot), !lockedSlots.contains(slot) else { return }
        let speed = launchVelocities[slot.rawValue].length
        launchVelocities[slot.rawValue] = Vec2.fromAngle(angle, length: speed)
    }

    /// Fixes a fighter's final launch direction. Both devices rebuild the velocity from the same angle.
    func lockLaunch(_ slot: PlayerSlot, angle: Double) {
        guard phase == .countdown, !lockedSlots.contains(slot) else { return }
        let speed = launchVelocities[slot.rawValue].length
        launchVelocities[slot.rawValue] = Vec2.fromAngle(angle, length: speed)
        lockedSlots.insert(slot)
    }

    var battleTime: Double { state.battleTime }
    var countdownRemaining: Double { max(0, GameConfig.countdownDuration - elapsed) }
    var isOvertime: Bool { GameConfig.overtime.isActive(at: state.battleTime) }

    func drainEvents() -> [BattleEvent] {
        defer { pendingEvents.removeAll(keepingCapacity: true) }
        return pendingEvents
    }

    // MARK: Step

    func step(dt: Double) {
        elapsed += dt
        var events: [BattleEvent] = []

        switch phase {
        case .countdown:
            let launchReady = !waitsForLaunchLock || lockedSlots.count == PlayerSlot.allCases.count
            if elapsed >= GameConfig.countdownDuration && launchReady {
                for (i, v) in launchVelocities.enumerated() { state.world.bodies[i].velocity = v }
                phase = .fighting
                events.append(.launched)
            }
        case .fighting:
            stepFight(dt: dt, events: &events)
        case .finished:
            timeSinceFinish += dt
        }

        updatePresentation(dt: dt)
        for event in events { effects.react(to: event) }
        pendingEvents.append(contentsOf: events)
    }

    private func stepFight(dt: Double, events: inout [BattleEvent]) {
        let wasOvertime = isOvertime
        state.battleTime += dt
        if !wasOvertime && isOvertime { events.append(.overtimeStarted) }

        let physics = state.world.step(dt: dt)
        for c in physics.bodyContacts where c.impactSpeed > 0 {
            events.append(.ballCollision(point: c.point, impactSpeed: c.impactSpeed))
        }
        for w in physics.wallContacts {
            events.append(.wallBounce(point: w.point, impactSpeed: w.impactSpeed))
        }

        let hits = AttackSystem.update(&state, dt: dt, physics: physics, events: &events)

        // Apply all of this step's damage together, then judge defeat once.
        // Each hit is scaled by its attacker's rarity and level.
        var applied: [DamageEvent] = []
        for raw in hits {
            let scale = state.fighter(raw.target.opponent).definition.damageScale
                * AbilitySystem.damageTakenMultiplier(raw.target, state: state)
            var amount = raw.amount * scale
            // A Mana Shield soaks up damage first.
            let shield = state.fighters[raw.target.rawValue].shield
            if shield > 0 {
                let absorbed = min(shield, amount)
                state.fighters[raw.target.rawValue].shield -= absorbed
                amount -= absorbed
                guard amount > 0 else { continue }
            }
            let hit = DamageEvent(target: raw.target, amount: amount,
                                  point: raw.point, source: raw.source, direction: raw.direction)
            applied.append(hit)
            ArsenalSystem.tookHit(hit, state: &state)
            AbilitySystem.landed(hit, state: &state, events: &events)
            state.fighters[hit.target.rawValue].health -= hit.amount
            state.fighters[hit.target.rawValue].flash = 1
            events.append(.damage(hit))
        }
        AbilitySystem.chargeUltimates(applied, state: &state)

        ArsenalSystem.splitInsteadOfFalling(&state, events: &events)
        let defeated = PlayerSlot.allCases.filter { state.fighter($0).isDefeated }
        guard !defeated.isEmpty else { return }

        for slot in defeated {
            state.fighters[slot.rawValue].health = 0
            events.append(.defeated(slot, position: state.body(of: slot).position))
        }
        state.projectiles.removeAll()
        for i in state.world.bodies.indices {
            state.world.bodies[i].isKinematic = false
            state.world.bodies[i].ignoresSpeedLimit = false
            state.world.bodies[i].isFrozen = false
        }
        phase = .finished(defeated.count == 2 ? .draw : .winner(defeated[0].opponent))
    }

    // MARK: Ability previews

    /// Fills a fighter's Ultimate meter, so it fires as soon as it can.
    func chargeUltimate(_ slot: PlayerSlot) {
        state.fighters[slot.rawValue].ultimateCharge = 1
    }

    private func updatePresentation(dt: Double) {
        trailTick += 1
        if trailTick.isMultiple(of: 2) {
            for fighter in state.fighters {
                var trail = trails[fighter.slot.rawValue]
                trail.append(state.world.bodies[fighter.bodyIndex].position)
                if trail.count > Self.trailLength { trail.removeFirst(trail.count - Self.trailLength) }
                trails[fighter.slot.rawValue] = trail
            }
        }
        for i in state.fighters.indices {
            let body = state.world.bodies[state.fighters[i].bodyIndex]
            state.fighters[i].previousSpin = state.fighters[i].spin
            // Rolling look: spin follows travel distance; direction follows horizontal motion.
            let roll = body.velocity.length * dt / body.radius
            state.fighters[i].spin += body.velocity.x >= 0 ? roll : -roll
            state.fighters[i].flash = max(0, state.fighters[i].flash - dt / 0.14)
            let target = state.fighters[i].health
            let trailing = state.fighters[i].trailingHealth
            state.fighters[i].trailingHealth = trailing > target ? max(target, trailing - 45 * dt) : target
        }
        effects.update(dt: dt)
    }
}
