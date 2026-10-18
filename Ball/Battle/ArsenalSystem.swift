import Foundation

/// Behaviour for the arsenal fighters, plus the shared systems they are built from:
/// field hazards, status effects (poison, hold), snake tails and extra projectile kinds.
///
/// Like `AttackSystem`, damage is collected and applied by `BattleSimulation` at the end of the step.
enum ArsenalSystem {
    private static let poisonTickInterval = 0.5
    private static let zoneTickInterval = 0.5
    /// How quickly thrown dice and bombs slow down (fraction of speed lost per second, exponential).
    private static let rollFriction = 2.5
    /// Chill from ice spikes wears off after this long without another hit.
    private static let chillDuration = 3.0

    static func knifeInterval(_ spec: KnifeSpec, fighter: FighterState) -> Double {
        let hp = max(0, min(1, fighter.health / fighter.definition.maxHealth))
        return spec.fastInterval + (spec.slowInterval - spec.fastInterval) * hp
    }

    // MARK: Per-fighter attacks

    static func update(_ slot: PlayerSlot, _ attack: ArsenalAttack, _ state: inout BattleState, dt: Double,
                       physics: PhysicsStepResult, events: inout [BattleEvent], damage: inout [DamageEvent]) {
        let i = slot.rawValue
        let myIndex = state.fighters[i].bodyIndex
        let opponentIndex = state.fighter(slot.opponent).bodyIndex
        let myWallHits = physics.wallContacts.filter { $0.body == myIndex }
        let touchingOpponent = physics.bodyContacts.contains {
            ($0.a == myIndex && $0.b == opponentIndex) || ($0.a == opponentIndex && $0.b == myIndex)
        }
        state.fighters[i].attackTimer += dt
        let me = state.world.bodies[myIndex]
        let them = state.world.bodies[opponentIndex]
        let toThem = (them.position - me.position).normalized

        switch attack {
        case .traps(let spec):
            guard state.fighters[i].attackTimer >= spec.interval else { break }
            state.fighters[i].attackTimer -= spec.interval
            let side = Vec2(-me.velocity.normalized.y, me.velocity.normalized.x)
            for k in 0..<spec.trapsPerDrop {
                let offset = spec.trapsPerDrop == 1 ? 0 : (Double(k) / Double(spec.trapsPerDrop - 1) - 0.5) * spec.spread
                let p = clampInside(me.position - me.velocity.normalized * 20 + side * offset, margin: spec.trapRadius, state)
                addHazard(Hazard(owner: slot, kind: .trap(armIn: spec.armDelay), position: p, radius: spec.trapRadius,
                                 lifetime: spec.lifetime, rotation: rotation(&state)), max: spec.maxTraps, state: &state)
            }
            events.append(.hazardPlaced(owner: slot, position: me.position))

        case .train(let spec):
            let hasTrack = state.hazards.contains { if case .track = $0.kind { return $0.owner == slot }; return false }
            guard !hasTrack, state.fighters[i].attackTimer >= spec.cooldown, let wall = myWallHits.first else { break }
            state.fighters[i].attackTimer = 0
            let n = wallNormal(wall.wallPoint, state)
            addHazard(Hazard(owner: slot, kind: .track(end: crossPoint(from: wall.wallPoint, normal: n, state),
                                                       warning: spec.warning, progress: 0, hasHit: false),
                             position: wall.wallPoint, radius: spec.width, lifetime: 30, rotation: 0), max: 1, state: &state)
            events.append(.hazardPlaced(owner: slot, position: wall.wallPoint))

        case .laser(let spec):
            // Each wall hit is an emitter; a hit on another wall links it to the previous one.
            guard let wall = myWallHits.first else { break }
            if let anchor = state.fighters[i].laserAnchor, state.fighters[i].attackTimer >= spec.cooldown,
               wallNormal(anchor, state) != wallNormal(wall.wallPoint, state), (wall.wallPoint - anchor).length > 80 {
                state.fighters[i].attackTimer = 0
                addHazard(Hazard(owner: slot, kind: .laser(end: wall.wallPoint), position: anchor, radius: 3,
                                 lifetime: spec.lifetime, hitCooldown: 0.3, rotation: rotation(&state)),
                          max: spec.maxLasers, state: &state)
                events.append(.hazardPlaced(owner: slot, position: wall.wallPoint))
            }
            state.fighters[i].laserAnchor = wall.wallPoint

        case .zone(let spec):
            // Zone regenerates while standing on its own turf.
            let onTurf = state.hazards.contains { h in
                guard h.owner == slot, case .zone = h.kind else { return false }
                return (me.position - h.position).length <= spec.radius(atAge: h.age, base: h.radius)
            }
            let fighter = state.fighters[i]
            if onTurf, fighter.health < fighter.definition.maxHealth {
                state.fighters[i].regenTick += dt
                if state.fighters[i].regenTick >= zoneTickInterval {
                    state.fighters[i].regenTick -= zoneTickInterval
                    let healed = min(spec.healPerSecond * zoneTickInterval, fighter.definition.maxHealth - fighter.health)
                    state.fighters[i].health += healed
                    events.append(.healed(slot, amount: healed, position: me.position))
                }
            }
            guard state.fighters[i].attackTimer >= spec.interval else { break }
            state.fighters[i].attackTimer -= spec.interval
            addHazard(Hazard(owner: slot, kind: .zone, position: me.position, radius: spec.radius, lifetime: spec.duration,
                             hitCooldown: 0.3, rotation: rotation(&state)), max: spec.maxZones, state: &state)
            events.append(.hazardPlaced(owner: slot, position: me.position))

        case .dice(let spec):
            guard state.fighters[i].attackTimer >= spec.interval else { break }
            state.fighters[i].attackTimer -= spec.interval
            throwDie(slot, spec, loaded: false, state: &state, events: &events)

        case .shards(let spec):
            let impacts = myWallHits.filter { $0.impactSpeed >= spec.minImpactSpeed }.count
                + physics.bodyContacts.filter { ($0.a == myIndex || $0.b == myIndex) && $0.impactSpeed >= spec.minImpactSpeed }.count
            guard impacts > 0, state.fighters[i].attackTimer >= spec.cooldown else { break }
            state.fighters[i].attackTimer = 0
            // The more cracked Glass is, the more it shatters.
            let hp = max(0, min(1, state.fighters[i].health / state.fighters[i].definition.maxHealth))
            let shardCount = spec.minShards + Int((Double(spec.maxShards - spec.minShards) * (1 - hp)).rounded())
            let base = Double.random(in: 0..<(2 * .pi), using: &state.rng)
            for k in 0..<shardCount {
                let a = base + Double(k) / Double(shardCount) * 2 * .pi
                let dir = Vec2.fromAngle(a)
                spawn(Projectile(owner: slot, position: me.position + dir * (me.radius + 6), previousPosition: me.position + dir * (me.radius + 6),
                                 velocity: dir * spec.shardSpeed, radius: 5, baseDamage: spec.damage, maxLifetime: 1.2, kind: .shard),
                      state: &state)
            }
            events.append(.projectileFired(owner: slot, position: me.position, direction: toThem))

        case .knives(let spec):
            // Pickpocket: a bump steals half the enemy's attack charge and throws knives point-blank.
            if touchingOpponent, state.fighters[i].contactCooldown <= 0 {
                state.fighters[i].contactCooldown = spec.pickpocketCooldown
                state.fighters[slot.opponent.rawValue].attackTimer *= 0.5
                for k in 0..<spec.pickpocketKnives {
                    let a = toThem.angle + (Double(k) - Double(spec.pickpocketKnives - 1) / 2) * 0.35
                    throwKnife(slot, spec, from: me, direction: Vec2.fromAngle(a), state: &state, events: &events)
                }
            }
            let interval = knifeInterval(spec, fighter: state.fighters[i])
            guard state.fighters[i].attackTimer >= interval else { break }
            state.fighters[i].attackTimer = 0
            throwKnife(slot, spec, from: me, direction: toThem, state: &state, events: &events)

        case .tail(let spec):
            if state.fighters[i].attackTimer >= spec.growInterval, state.fighters[i].tailSegments < spec.maxSegments {
                state.fighters[i].attackTimer -= spec.growInterval
                state.fighters[i].tailSegments += 1
            }
            var tail = state.tails[i]
            if tail.isEmpty || (tail[tail.count - 1] - me.position).length >= spec.segmentSpacing {
                tail.append(me.position)
            }
            let keep = state.fighters[i].tailSegments + 2
            if tail.count > keep { tail.removeFirst(tail.count - keep) }
            state.tails[i] = tail
            // Segments close to the head overlap the body; only the rest of the tail hurts.
            guard state.fighters[i].contactCooldown <= 0, !them.isKinematic else { break }
            let segmentRadius = spec.segmentRadius(segments: state.fighters[i].tailSegments)
            for point in tail.dropLast(2) where (them.position - point).length <= them.radius + segmentRadius {
                let dir = (them.position - point).normalized
                damage.append(DamageEvent(target: slot.opponent,
                                          amount: spec.damage * AbilitySystem.tailBoost(state.fighters[i]) * state.damageMultiplier,
                                          point: point + dir * segmentRadius, source: .tail, direction: dir))
                if !them.isFrozen { state.world.bodies[opponentIndex].velocity += dir * spec.knockback }
                state.fighters[i].contactCooldown = spec.hitCooldown
                AbilitySystem.tailBit(slot, state: &state, events: &events)
                break
            }

        case .shock(let spec):
            // Wall bounces store charge; a bump (or, fully charged, a lightning arc) dumps all of it.
            if !myWallHits.isEmpty, state.fighters[i].charge < spec.maxCharge {
                state.fighters[i].charge += 1
            }
            let charge = Double(state.fighters[i].charge)
            let gap = (them.position - me.position).length - me.radius - them.radius
            let arcing = !touchingOpponent && state.fighters[i].charge >= spec.maxCharge && gap <= spec.arcRange
            guard touchingOpponent || arcing, state.fighters[i].contactCooldown <= 0, !them.isKinematic else { break }
            state.fighters[i].contactCooldown = spec.cooldown
            state.fighters[i].charge = 0
            damage.append(DamageEvent(target: slot.opponent, amount: (spec.damage + spec.damagePerCharge * charge) * state.damageMultiplier,
                                      point: them.position - toThem * them.radius, source: .shock, direction: toThem))
            hold(slot.opponent, for: spec.freezeDuration + spec.freezePerCharge * charge, style: .shock, state: &state, events: &events)
            if arcing {
                addHazard(Hazard(owner: slot, kind: .arc(end: them.position - toThem * them.radius * 0.5),
                                 position: me.position + toThem * me.radius, radius: 0, lifetime: 0.3, rotation: rotation(&state)),
                          max: 1, state: &state)
            }

        case .bombs(let spec):
            guard state.fighters[i].attackTimer >= spec.interval else { break }
            state.fighters[i].attackTimer -= spec.interval
            var start = clampInside(me.position, margin: 14, state)
            var velocity = Vec2.zero
            if spec.throwSpeed > 0 {
                // Rolled toward the enemy, hard enough to stop about where it is now.
                start = clampInside(me.position + toThem * (me.radius + 16), margin: 14, state)
                velocity = toThem * min(spec.throwSpeed, (them.position - start).length * rollFriction)
            }
            addHazard(Hazard(owner: slot, kind: .bomb(fuse: spec.fuse), position: start, radius: spec.radius,
                             lifetime: spec.fuse + 1, rotation: rotation(&state), velocity: velocity), max: 6, state: &state)
            events.append(.hazardPlaced(owner: slot, position: me.position))

        case .turrets(let spec):
            // Turrets stay up; past the cap the oldest is replaced.
            guard state.fighters[i].attackTimer >= spec.cooldown, let wall = myWallHits.first else { break }
            state.fighters[i].attackTimer = 0
            let n = wallNormal(wall.wallPoint, state)
            addHazard(Hazard(owner: slot, kind: .turret(fireTimer: 0.6), position: wall.wallPoint + n * 16, radius: 14,
                             lifetime: .infinity, rotation: 0), max: spec.maxTurrets, state: &state)
            events.append(.hazardPlaced(owner: slot, position: wall.wallPoint))

        case .virus(let spec):
            guard touchingOpponent, state.fighters[i].contactCooldown <= 0 else { break }
            state.fighters[i].contactCooldown = spec.cooldown
            poison(slot.opponent, perSecond: spec.damagePerSecond, duration: spec.duration, cap: spec.maxDamagePerSecond,
                   state: &state, events: &events)

        case .harpoon(let spec):
            if state.fighters[i].dragRemaining > 0 {
                state.fighters[i].dragRemaining -= dt
                let gap = (them.position - me.position).length - me.radius - them.radius
                if gap > 6, !them.isKinematic, !them.isFrozen {
                    state.world.bodies[opponentIndex].velocity = -toThem * spec.dragSpeed
                } else {
                    state.fighters[i].dragRemaining = 0
                }
            }
            guard state.fighters[i].attackTimer >= spec.interval else { break }
            state.fighters[i].attackTimer = 0
            let start = me.position + toThem * (me.radius + 10)
            spawn(Projectile(owner: slot, position: start, previousPosition: start, velocity: toThem * spec.speed, radius: 8,
                             baseDamage: spec.damage, maxLifetime: 1.5, kind: .harpoon), state: &state)
            events.append(.projectileFired(owner: slot, position: start, direction: toThem))

        case .moss(let spec):
            // Wall bounces mend it; thorny touches scratch.
            state.fighters[i].healCooldown = max(0, state.fighters[i].healCooldown - dt)
            if !myWallHits.isEmpty, state.fighters[i].healCooldown <= 0 {
                let f = state.fighters[i]
                state.fighters[i].healCooldown = spec.healCooldown
                let healed = max(0, min(spec.wallHeal * f.definition.damageScale * AbilitySystem.wallHealBoost(f),
                                        f.definition.maxHealth - f.health))
                if healed > 0 {
                    state.fighters[i].health += healed
                    events.append(.healed(slot, amount: healed, position: me.position))
                }
            }
            guard touchingOpponent, state.fighters[i].contactCooldown <= 0, !them.isKinematic else { break }
            state.fighters[i].contactCooldown = spec.cooldown
            damage.append(DamageEvent(target: slot.opponent, amount: spec.damage * state.damageMultiplier,
                                      point: them.position - toThem * them.radius, source: .contact, direction: toThem))

        case .magma(let spec):
            if touchingOpponent, state.fighters[i].contactCooldown <= 0, !them.isKinematic {
                state.fighters[i].contactCooldown = spec.igniteCooldown
                poison(slot.opponent, perSecond: spec.ignitePerSecond, duration: spec.igniteDuration, cap: spec.ignitePerSecond * 2,
                       state: &state, events: &events)
            }
            guard state.fighters[i].attackTimer >= spec.dropInterval else { break }
            state.fighters[i].attackTimer -= spec.dropInterval
            guard !me.isFrozen, !me.isKinematic else { break }
            addHazard(Hazard(owner: slot, kind: .lava, position: clampInside(me.position, margin: spec.poolRadius * 0.6, state),
                             radius: spec.poolRadius, lifetime: spec.poolLifetime, rotation: rotation(&state)),
                      max: spec.maxPools, state: &state)

        case .wolf(let spec):
            // Smells blood: the weaker the enemy, the faster it runs and the harder it bites.
            let enemy = state.fighter(slot.opponent)
            let weakness = 1 - max(0, min(1, enemy.health / enemy.definition.maxHealth))
            state.fighters[i].baseSpeedScale = 1 + spec.speedBonus * weakness
            guard touchingOpponent, state.fighters[i].contactCooldown <= 0, !them.isKinematic else { break }
            state.fighters[i].contactCooldown = spec.cooldown
            let amount = spec.damage * (1 + spec.maxBonus * weakness) * state.damageMultiplier
            damage.append(DamageEvent(target: slot.opponent, amount: amount, point: them.position - toThem * them.radius,
                                      source: .contact, direction: toThem))
            AbilitySystem.wolfBit(slot, amount: amount, state: &state, events: &events)

        case .fibonacci(let spec):
            let lowest = max(spec.startIndex, spec.floorIndex)
            if state.fighters[i].streak < lowest { state.fighters[i].streak = lowest }
            guard state.fighters[i].attackTimer >= spec.interval else { break }
            state.fighters[i].attackTimer -= spec.interval
            var index = state.fighters[i].streak
            if state.fighters[i].maxedShots > 0 {
                state.fighters[i].maxedShots -= 1
                index = spec.maxIndex
            }
            let n = FibonacciSpec.number(at: index)
            let start = me.position + toThem * (me.radius + 12)
            spawn(Projectile(owner: slot, position: start, previousPosition: start, velocity: toThem * spec.speed, radius: 9,
                             baseDamage: Double(n) * spec.damageScale, maxLifetime: 2, kind: .number, turnRate: 1.2, label: n),
                  state: &state)
            events.append(.projectileFired(owner: slot, position: start, direction: toThem))

        case .wizard(let spec):
            guard state.fighters[i].attackTimer >= spec.interval else { break }
            state.fighters[i].attackTimer -= spec.interval
            castSpell(slot, spec, state: &state, events: &events, damage: &damage)

        case .clockwork(let spec):
            // Remember where it was, then every so often jump back there.
            state.fighters[i].historyTick += dt
            if state.fighters[i].historyTick >= rewindSample {
                state.fighters[i].historyTick -= rewindSample
                state.fighters[i].history.append(RewindPoint(position: me.position, velocity: me.velocity, health: state.fighters[i].health))
                let keep = Int(spec.rewindWindow / rewindSample) + 1
                if state.fighters[i].history.count > keep { state.fighters[i].history.removeFirst(state.fighters[i].history.count - keep) }
            }
            state.fighters[i].rewindTimer += dt
            if state.fighters[i].rewindTimer >= spec.rewindInterval, let past = state.fighters[i].history.first, free(me) {
                state.fighters[i].rewindTimer = 0
                state.fighters[i].history = []
                let healed = max(0, past.health - state.fighters[i].health)
                teleport(myIndex, to: past.position, velocity: past.velocity, state: &state)
                if healed > 0 {
                    state.fighters[i].health += healed
                    events.append(.healed(slot, amount: healed, position: past.position))
                }
                events.append(.ability(slot, name: "Rewind", position: past.position, ultimate: false))
                AbilitySystem.rewound(slot, state: &state, events: &events)
            }
            guard state.fighters[i].attackTimer >= spec.gearInterval else { break }
            state.fighters[i].attackTimer -= spec.gearInterval
            let start = me.position + toThem * (me.radius + 12)
            spawn(Projectile(owner: slot, position: start, previousPosition: start, velocity: toThem * spec.gearSpeed, radius: 9,
                             baseDamage: spec.gearDamage + AbilitySystem.gearBonus(state.fighters[i]), maxLifetime: 2, kind: .gear,
                             turnRate: 0.6), state: &state)
            events.append(.projectileFired(owner: slot, position: start, direction: toThem))

        case .portal(let spec):
            guard state.fighters[i].attackTimer >= spec.interval, free(me) else { break }
            state.fighters[i].attackTimer -= spec.interval
            // One portal right where the enemy is heading, the other as far from it as possible.
            let entry = clampInside(them.position + them.velocity * 0.45, margin: spec.radius + 8, state)
            var exit = entry
            for _ in 0..<6 {
                let candidate = Vec2(Double.random(in: 70...(state.world.width - 70), using: &state.rng),
                                     Double.random(in: 70...(state.world.height - 70), using: &state.rng))
                if (candidate - entry).length > (exit - entry).length { exit = candidate }
            }
            openPortals(slot, entry: entry, exit: exit, spec: spec, state: &state)
            events.append(.hazardPlaced(owner: slot, position: entry))

        case .glitch(let spec):
            guard state.fighters[i].attackTimer >= spec.interval, free(me) else { break }
            state.fighters[i].attackTimer -= spec.interval
            let angle = toThem.angle + Double.random(in: -0.5...0.5, using: &state.rng)
            var landing = clampInside(me.position + Vec2.fromAngle(angle) * spec.jump, margin: me.radius + 2, state)
            // Never land inside the enemy.
            let gap = (landing - them.position).length
            if gap < me.radius + them.radius + 6 {
                landing = clampInside(them.position + (landing - them.position).normalized * (me.radius + them.radius + 8),
                                      margin: me.radius + 2, state)
            }
            addHazard(Hazard(owner: slot, kind: .errorTile, position: me.position, radius: spec.tileRadius, lifetime: spec.tileLifetime,
                             rotation: rotation(&state)), max: spec.maxTiles, state: &state)
            events.append(.hazardPlaced(owner: slot, position: me.position))
            teleport(myIndex, to: landing, state: &state)
            events.append(.hazardPlaced(owner: slot, position: landing))
            // Landing right next to the enemy zaps it.
            if (landing - them.position).length - me.radius - them.radius <= 40, !them.isKinematic {
                let dir = (them.position - landing).normalized
                damage.append(DamageEvent(target: slot.opponent, amount: spec.zapDamage * state.damageMultiplier,
                                          point: them.position - dir * them.radius, source: .shock, direction: dir))
                addHazard(Hazard(owner: slot, kind: .arc(end: them.position - dir * them.radius * 0.5),
                                 position: landing + dir * me.radius, radius: 0, lifetime: 0.25, rotation: rotation(&state)),
                          max: 3, state: &state)
            }

        case .twin(let spec):
            // The twin joins at the launch (and again after Reunite).
            let hasTwin = state.minions.contains { $0.owner == slot && $0.kind == .twin }
            if !hasTwin, !AbilitySystem.isReunited(state.fighters[i]) {
                let side = Vec2(-me.velocity.normalized.y, me.velocity.normalized.x)
                let spot = clampInside(me.position + side * (me.radius * 2 + 8), margin: me.radius + 2, state)
                let velocity = me.velocity == .zero ? side * 400 : Vec2.fromAngle(me.velocity.angle + 0.9, length: me.velocity.length)
                spawnMinion(slot, .twin, at: spot, velocity: velocity, radius: me.radius, mass: me.mass, lifetime: .infinity, state: &state)
            }
            guard touchingOpponent, state.fighters[i].contactCooldown <= 0, !them.isKinematic else { break }
            state.fighters[i].contactCooldown = spec.cooldown
            damage.append(DamageEvent(target: slot.opponent, amount: spec.damage * AbilitySystem.twinBoost(state.fighters[i]) * state.damageMultiplier,
                                      point: them.position - toThem * them.radius, source: .contact, direction: toThem))

        case .cell(let spec):
            // Grows in stages: bigger and harder hitting.
            state.fighters[i].cellGrowth += dt
            if state.fighters[i].cellStage < spec.stages, state.fighters[i].cellGrowth >= spec.growInterval {
                state.fighters[i].cellGrowth = 0
                state.fighters[i].cellStage += 1
                events.append(.ability(slot, name: "Grow", position: me.position, ultimate: false))
            }
            state.world.bodies[myIndex].radius = state.fighters[i].definition.radius
                * (1 + spec.radiusPerStage * Double(state.fighters[i].cellStage))
            guard touchingOpponent, state.fighters[i].contactCooldown <= 0, !them.isKinematic else { break }
            state.fighters[i].contactCooldown = spec.cooldown
            let amount = spec.damage * (1 + spec.damagePerStage * Double(state.fighters[i].cellStage)) * state.damageMultiplier
            damage.append(DamageEvent(target: slot.opponent, amount: amount, point: them.position - toThem * them.radius,
                                      source: .contact, direction: toThem))

        case .swarm(let spec):
            guard state.fighters[i].attackTimer >= spec.interval else { break }
            state.fighters[i].attackTimer -= spec.interval
            for k in 0..<spec.bees {
                let a = toThem.angle + (Double(k) - Double(spec.bees - 1) / 2) * 0.9 + .pi
                let dir = Vec2.fromAngle(a)
                let start = me.position + dir * (me.radius + 8)
                spawn(Projectile(owner: slot, position: start, previousPosition: start, velocity: dir * spec.speed, radius: 6,
                                 baseDamage: spec.damage, maxLifetime: spec.lifetime, kind: .bee, turnRate: spec.turnRate,
                                 poison: (spec.poisonPerSecond, spec.poisonDuration)), state: &state)
            }
            events.append(.projectileFired(owner: slot, position: me.position, direction: toThem))
        }
    }

    private static let rewindSample = 0.25

    /// Free to act: not held, thrown or carried.
    private static func free(_ body: PhysicsBody) -> Bool { !body.isKinematic && !body.isFrozen && !body.ignoresSpeedLimit }

    /// Moves a ball instantly (no smear between the two spots).
    static func teleport(_ bodyIndex: Int, to point: Vec2, velocity: Vec2? = nil, state: inout BattleState) {
        state.world.bodies[bodyIndex].position = point
        state.world.bodies[bodyIndex].previousPosition = point
        if let velocity { state.world.bodies[bodyIndex].velocity = velocity }
    }

    /// Opens a pair of linked portals (replacing the oldest pair past the cap).
    static func openPortals(_ slot: PlayerSlot, entry: Vec2, exit: Vec2, spec: PortalSpec, state: inout BattleState) {
        let spin = rotation(&state)
        addHazard(Hazard(owner: slot, kind: .portal(exit: exit, blue: false), position: entry, radius: spec.radius,
                         lifetime: spec.lifetime, rotation: spin), max: spec.maxPairs * 2, state: &state)
        addHazard(Hazard(owner: slot, kind: .portal(exit: entry, blue: true), position: exit, radius: spec.radius,
                         lifetime: spec.lifetime, rotation: spin), max: spec.maxPairs * 2, state: &state)
    }

    /// Throws the enemy out at `point`, flung toward the nearest wall.
    static func fling(_ target: PlayerSlot, from point: Vec2, speed: Double, state: inout BattleState) {
        let w = state.world.width, h = state.world.height
        let walls = [(point.x, Vec2(-1, 0)), (w - point.x, Vec2(1, 0)), (point.y, Vec2(0, -1)), (h - point.y, Vec2(0, 1))]
        let toward = walls.min { $0.0 < $1.0 }!.1
        let index = state.fighter(target).bodyIndex
        let r = state.world.bodies[index].radius
        teleport(index, to: clampInside(point, margin: r + 2, state), velocity: toward * speed, state: &state)
        state.world.bodies[index].ignoresSpeedLimit = false
    }

    static let spellNames = ["Firebolt", "Frost Nova", "Lightning", "Arcane Missiles"]

    /// Wizard: casts one random spell (never `excluding`, nor a repeat with Focus). Returns the spell.
    @discardableResult
    static func castSpell(_ slot: PlayerSlot, _ spec: WizardSpec, excluding: [Int] = [], state: inout BattleState,
                          events: inout [BattleEvent], damage: inout [DamageEvent]) -> Int {
        let i = slot.rawValue
        let me = state.body(of: slot)
        let them = state.body(of: slot.opponent)
        let toThem = (them.position - me.position).normalized
        var choices = spellNames.indices.filter { !excluding.contains($0) }
        if spec.noRepeat, choices.count > 1 { choices.removeAll { $0 == state.fighters[i].lastSpell } }
        let spell = choices.randomElement(using: &state.rng) ?? 0
        state.fighters[i].lastSpell = spell
        switch spell {
        case 0:
            let start = me.position + toThem * (me.radius + 12)
            spawn(Projectile(owner: slot, position: start, previousPosition: start, velocity: toThem * 470, radius: 10,
                             baseDamage: spec.fireboltDamage, maxLifetime: 3, kind: .firebolt, turnRate: 1.5), state: &state)
        case 1:
            for k in 0..<8 {
                let dir = Vec2.fromAngle(Double(k) / 8 * 2 * .pi)
                let start = me.position + dir * (me.radius + 6)
                spawn(Projectile(owner: slot, position: start, previousPosition: start, velocity: dir * 430, radius: 6,
                                 baseDamage: spec.frostDamage, maxLifetime: 1.1, kind: .iceSpike,
                                 effect: .slow(amount: 0.35, duration: 2)), state: &state)
            }
        case 2:
            damage.append(DamageEvent(target: slot.opponent, amount: spec.lightningDamage * state.damageMultiplier,
                                      point: them.position - toThem * them.radius, source: .shock, direction: toThem))
            addHazard(Hazard(owner: slot, kind: .arc(end: them.position - toThem * them.radius * 0.5),
                             position: me.position + toThem * me.radius, radius: 0, lifetime: 0.3, rotation: rotation(&state)),
                      max: 3, state: &state)
        default:
            for k in 0..<3 {
                let dir = Vec2.fromAngle(toThem.angle + .pi + (Double(k) - 1) * 0.8)
                let start = me.position + dir * (me.radius + 8)
                spawn(Projectile(owner: slot, position: start, previousPosition: start, velocity: dir * 380, radius: 7,
                                 baseDamage: spec.missileDamage, maxLifetime: 3, kind: .orb, turnRate: 3.2), state: &state)
            }
        }
        events.append(.ability(slot, name: spellNames[spell], position: me.position, ultimate: false))
        return spell
    }

    /// A hit landed on a fighter: it knocks Fibonacci's streak back two steps (if big), and speeds up Cell's growth.
    static func tookHit(_ hit: DamageEvent, state: inout BattleState) {
        let i = hit.target.rawValue
        switch state.fighters[i].definition.attack {
        case .arsenal(.fibonacci(let spec)) where hit.amount >= spec.breakDamage:
            state.fighters[i].streak = max(max(spec.startIndex, spec.floorIndex), state.fighters[i].streak - 2)
        case .arsenal(.cell(let spec)):
            state.fighters[i].cellGrowth += hit.amount * spec.growthPerDamage
        default:
            break
        }
    }

    // MARK: Minions (Twin, Cell)

    static func spawnMinion(_ owner: PlayerSlot, _ kind: Minion.Kind, at point: Vec2, velocity: Vec2, radius: Double, mass: Double,
                            lifetime: Double, state: inout BattleState) {
        var body = PhysicsBody(position: point, radius: radius, mass: mass)
        body.velocity = velocity
        state.world.bodies.append(body)
        state.minions.append(Minion(owner: owner, kind: kind, bodyIndex: state.world.bodies.count - 1, lifetime: lifetime))
    }

    /// Removes a minion and its body (later bodies move down one).
    static func removeMinion(at index: Int, state: inout BattleState) {
        let bodyIndex = state.minions[index].bodyIndex
        state.minions.remove(at: index)
        state.world.bodies.remove(at: bodyIndex)
        for k in state.minions.indices where state.minions[k].bodyIndex > bodyIndex { state.minions[k].bodyIndex -= 1 }
    }

    /// Cell splits into small cells around itself: one more for each growth stage (up to 3).
    static func splitCell(_ slot: PlayerSlot, count: Int, state: inout BattleState) {
        guard case .arsenal(.cell(let spec)) = state.fighter(slot).definition.attack else { return }
        let me = state.body(of: slot)
        let base = Double.random(in: 0..<(2 * .pi), using: &state.rng)
        for k in 0..<count {
            let dir = Vec2.fromAngle(base + Double(k) / Double(count) * 2 * .pi)
            spawnMinion(slot, .cell, at: clampInside(me.position + dir * (me.radius + 14), margin: 14, state),
                        velocity: dir * 420, radius: state.fighter(slot).definition.radius * 0.5, mass: 0.4,
                        lifetime: spec.cellLifetime, state: &state)
        }
    }

    /// Cell's first knockout becomes a split: back at part health, small again, with small cells.
    static func splitInsteadOfFalling(_ state: inout BattleState, events: inout [BattleEvent]) {
        for i in state.fighters.indices where state.fighters[i].isDefeated && !state.fighters[i].splitUsed {
            guard case .arsenal(.cell(let spec)) = state.fighters[i].definition.attack else { continue }
            let slot = state.fighters[i].slot
            state.fighters[i].splitUsed = true
            let count = max(1, min(3, 1 + state.fighters[i].cellStage))
            state.fighters[i].health = state.fighters[i].definition.maxHealth * spec.splitHealth
            state.fighters[i].cellStage = 0
            state.fighters[i].cellGrowth = 0
            state.world.bodies[state.fighters[i].bodyIndex].radius = state.fighters[i].definition.radius
            splitCell(slot, count: count, state: &state)
            events.append(.ability(slot, name: "Split", position: state.body(of: slot).position, ultimate: true))
        }
    }

    /// Minions bite the enemy on contact. Small cells home in, pop when they hit and fade after a while.
    private static func updateMinions(_ state: inout BattleState, dt: Double, events: inout [BattleEvent], damage: inout [DamageEvent]) {
        var k = 0
        while k < state.minions.count {
            state.minions[k].age += dt
            state.minions[k].contactCooldown = max(0, state.minions[k].contactCooldown - dt)
            let m = state.minions[k]
            let body = state.world.bodies[m.bodyIndex]
            let enemy = state.body(of: m.owner.opponent)
            let offset = enemy.position - body.position
            var remove = m.age >= m.lifetime
            if m.kind == .cell {
                // Drift toward the enemy, keeping their speed.
                let blended = body.velocity.normalized.lerp(to: offset.normalized, min(1, 2.2 * dt))
                if blended != .zero { state.world.bodies[m.bodyIndex].velocity = blended.normalized * max(body.velocity.length, 300) }
            }
            if offset.length <= body.radius + enemy.radius + 1.5, m.contactCooldown <= 0, !enemy.isKinematic {
                let dir = offset.normalized
                switch (m.kind, state.fighter(m.owner).definition.attack) {
                case (.twin, .arsenal(.twin(let spec))):
                    state.minions[k].contactCooldown = spec.cooldown
                    damage.append(DamageEvent(target: m.owner.opponent, amount: spec.damage * state.damageMultiplier,
                                              point: enemy.position - dir * enemy.radius, source: .contact, direction: dir))
                case (.cell, .arsenal(.cell(let spec))):
                    damage.append(DamageEvent(target: m.owner.opponent, amount: spec.cellDamage * state.damageMultiplier,
                                              point: enemy.position - dir * enemy.radius, source: .contact, direction: dir))
                    events.append(.explosion(owner: m.owner, position: body.position, radius: 30, icy: false))
                    remove = true
                default:
                    break
                }
            }
            if remove { removeMinion(at: k, state: &state) } else { k += 1 }
        }
    }

    /// Throws a die toward the enemy, hard enough to roll about as far as it is now.
    /// A loaded (golden) die only ever shows 5 or 6.
    static func throwDie(_ slot: PlayerSlot, _ spec: DiceSpec, loaded: Bool, state: inout BattleState, events: inout [BattleEvent]) {
        let me = state.body(of: slot)
        let toThem = (state.body(of: slot.opponent).position - me.position).normalized
        let value = loaded ? Int.random(in: 5...6, using: &state.rng) : Int.random(in: 1...6, using: &state.rng)
        let start = clampInside(me.position + toThem * (me.radius + spec.dieSize), margin: spec.dieSize, state)
        let speed = min(spec.throwSpeed, (state.body(of: slot.opponent).position - start).length * rollFriction)
        // Dice stay inert briefly so the thrower can roll clear.
        addHazard(Hazard(owner: slot, kind: .die(value: value), position: start, radius: spec.dieSize,
                         lifetime: spec.lifetime, hitCooldown: 0.3, rotation: rotation(&state), velocity: toThem * speed,
                         loaded: loaded),
                  max: spec.maxDice, state: &state)
        events.append(.hazardPlaced(owner: slot, position: me.position))
    }

    private static func throwKnife(_ slot: PlayerSlot, _ spec: KnifeSpec, from me: PhysicsBody, direction: Vec2,
                                   state: inout BattleState, events: inout [BattleEvent]) {
        let start = me.position + direction * (me.radius + 10)
        spawn(Projectile(owner: slot, position: start, previousPosition: start, velocity: direction * spec.speed, radius: 7,
                         baseDamage: spec.damage, maxLifetime: 2, kind: .knife), state: &state)
        events.append(.projectileFired(owner: slot, position: start, direction: direction))
    }

    /// Called when a projectile lands, for effects beyond plain damage.
    static func projectileHit(_ p: Projectile, state: inout BattleState, events: inout [BattleEvent]) {
        let attack = state.fighter(p.owner).definition.attack
        if p.kind == .knife, case .arsenal(.knives(let spec)) = attack {
            let thief = state.fighter(p.owner)
            let stolen = max(0, min(p.baseDamage * state.damageMultiplier * spec.stealFraction,
                                    thief.definition.maxHealth - thief.health))
            if stolen > 0 {
                state.fighters[p.owner.rawValue].health += stolen
                events.append(.healed(p.owner, amount: stolen, position: state.body(of: p.owner).position))
            }
        }
        // Glacier's spikes land while the enemy is already frozen, so they don't chill.
        if p.kind == .iceSpike, case .arsenal(.bombs(let spec)) = attack, spec.chillToFreeze > 0,
           !state.fighter(p.owner.opponent).isHeld {
            let target = p.owner.opponent.rawValue
            state.fighters[target].chill += 1
            state.fighters[target].chillRemaining = chillDuration
            if state.fighters[target].chill >= spec.chillToFreeze {
                state.fighters[target].chill = 0
                hold(p.owner.opponent, for: spec.freezeDuration, style: .ice, state: &state, events: &events)
            }
        }
        if let effect = p.poison {
            poison(p.owner.opponent, perSecond: effect.perSecond, duration: effect.duration, cap: 8, state: &state, events: &events)
        }
        if p.kind == .number, case .arsenal(.fibonacci(let spec)) = attack {
            state.fighters[p.owner.rawValue].streak = min(spec.maxIndex, state.fighter(p.owner).streak + 1)
        }
        if p.kind == .harpoon, case .arsenal(.harpoon(let spec)) = state.fighter(p.owner).definition.attack {
            state.fighters[p.owner.rawValue].dragRemaining = spec.dragDuration
        }
    }

    // MARK: Shared systems (once per step)

    static func updateShared(_ state: inout BattleState, dt: Double, events: inout [BattleEvent], damage: inout [DamageEvent]) {
        updateStatuses(&state, dt: dt, damage: &damage)
        updateHazards(&state, dt: dt, events: &events, damage: &damage)
        updateMinions(&state, dt: dt, events: &events, damage: &damage)
        for i in state.fighters.indices {
            let slot = state.fighters[i].slot
            state.fighters[i].activeHazards = state.hazards.filter { $0.owner == slot }.count
        }
    }

    private static func updateStatuses(_ state: inout BattleState, dt: Double, damage: inout [DamageEvent]) {
        for i in state.fighters.indices {
            let bodyIndex = state.fighters[i].bodyIndex
            if state.fighters[i].holdRemaining > 0 {
                state.fighters[i].holdRemaining -= dt
                state.world.bodies[bodyIndex].velocity = .zero
                if state.fighters[i].holdRemaining <= 0 {
                    state.world.bodies[bodyIndex].isFrozen = false
                    state.world.bodies[bodyIndex].velocity = state.fighters[i].heldVelocity
                }
            }
            if state.fighters[i].chillRemaining > 0 {
                state.fighters[i].chillRemaining -= dt
                if state.fighters[i].chillRemaining <= 0 { state.fighters[i].chill = 0 }
            }
            if state.fighters[i].poisonRemaining > 0 {
                state.fighters[i].poisonRemaining -= dt
                state.fighters[i].poisonTick += dt
                if state.fighters[i].poisonTick >= poisonTickInterval {
                    state.fighters[i].poisonTick -= poisonTickInterval
                    let body = state.world.bodies[bodyIndex]
                    damage.append(DamageEvent(target: state.fighters[i].slot,
                                              amount: state.fighters[i].poisonPerSecond * poisonTickInterval * state.damageMultiplier,
                                              point: body.position - Vec2(0, body.radius), source: .poison, direction: Vec2(0, -1)))
                }
                if state.fighters[i].poisonRemaining <= 0 {
                    state.fighters[i].poisonPerSecond = 0
                    state.fighters[i].poisonTick = 0
                }
            }
        }
    }

    private static func updateHazards(_ state: inout BattleState, dt: Double, events: inout [BattleEvent], damage: inout [DamageEvent]) {
        var survivors: [Hazard] = []
        survivors.reserveCapacity(state.hazards.count)
        /// Blasts this step, for setting off nearby bombs.
        var blasts: [(position: Vec2, radius: Double)] = []
        /// Left behind by blasts this step (Cluster, Ice Patch), and Lucky Six's bonus throws.
        var spawned: [Hazard] = []
        var bonusDice: [PlayerSlot] = []

        for i in state.fighters.indices {
            state.fighters[i].burnCooldown = max(0, state.fighters[i].burnCooldown - dt)
            state.fighters[i].portalCooldown = max(0, state.fighters[i].portalCooldown - dt)
        }
        for var h in state.hazards {
            h.age += dt
            h.hitCooldown = max(0, h.hitCooldown - dt)
            if h.velocity != .zero { roll(&h, dt: dt, state) }
            let enemy = h.owner.opponent
            let enemyBody = state.body(of: enemy)
            let attack = state.fighter(h.owner).definition.attack
            var keep = h.age < h.lifetime

            switch h.kind {
            case .trap(var armIn):
                armIn -= dt
                h.kind = .trap(armIn: armIn)
                if armIn <= 0, !state.fighter(enemy).isHeld, !enemyBody.isKinematic,
                   (enemyBody.position - h.position).length <= h.radius + enemyBody.radius * 0.3,
                   case .arsenal(.traps(let spec)) = attack {
                    damage.append(DamageEvent(target: enemy, amount: spec.damage * state.damageMultiplier, point: h.position,
                                              source: .hazard, direction: (enemyBody.position - h.position).normalized))
                    hold(enemy, for: spec.holdDuration, style: .shackle, state: &state, events: &events)
                    keep = false
                }

            case .zone:
                if h.hitCooldown <= 0, case .arsenal(.zone(let spec)) = attack,
                   (enemyBody.position - h.position).length <= spec.radius(atAge: h.age, base: h.radius) + enemyBody.radius * 0.4 {
                    h.hitCooldown = zoneTickInterval
                    damage.append(DamageEvent(target: enemy, amount: spec.damagePerSecond * zoneTickInterval * state.damageMultiplier,
                                              point: enemyBody.position, source: .hazard, direction: Vec2(0, -1)))
                }

            case .die(var value):
                let tumbling = h.velocity != .zero
                // A rolling die keeps flipping faces until it settles.
                if tumbling, Double.random(in: 0..<1, using: &state.rng) < dt * 12 {
                    value = h.loaded ? Int.random(in: 5...6, using: &state.rng) : Int.random(in: 1...6, using: &state.rng)
                    h.kind = .die(value: value)
                }
                guard case .arsenal(.dice(let spec)) = attack, h.hitCooldown <= 0 else { break }
                for slot in [enemy, h.owner] {
                    let body = state.body(of: slot)
                    guard (body.position - h.position).length <= body.radius + h.radius else { continue }
                    let perPip = (slot == enemy ? spec.damagePerPip : spec.selfDamagePerPip) * (tumbling ? spec.tumblingMultiplier : 1)
                    let away = (h.position - body.position).normalized
                    if perPip > 0 {
                        damage.append(DamageEvent(target: slot, amount: Double(value) * perPip * state.damageMultiplier,
                                                  point: h.position, source: .hazard, direction: -away))
                    }
                    if tumbling { h.velocity = away * h.velocity.length * 0.5 }
                    if slot == enemy, value == 6, state.fighter(h.owner).definition.abilities.perk == .luckySix {
                        bonusDice.append(h.owner)
                    }
                    h.kind = .die(value: h.loaded ? Int.random(in: 5...6, using: &state.rng) : Int.random(in: 1...6, using: &state.rng))
                    h.hitCooldown = spec.rerollCooldown
                    break
                }

            case .laser(let end):
                guard case .arsenal(.laser(let spec)) = attack, h.hitCooldown <= 0 else { break }
                let a = h.position - enemyBody.position
                let b = end - enemyBody.position
                if Vec2.segmentDistanceToOrigin(a, b) <= enemyBody.radius + 2 {
                    h.hitCooldown = spec.hitCooldown
                    let along = (end - h.position).normalized
                    let side = Vec2(-along.y, along.x)
                    damage.append(DamageEvent(target: enemy, amount: spec.damage * state.damageMultiplier, point: enemyBody.position,
                                              source: .hazard, direction: side * ((enemyBody.position - h.position).dot(side) >= 0 ? 1 : -1)))
                }

            case .bomb(var fuse):
                guard case .arsenal(.bombs(let spec)) = attack else { break }
                fuse -= dt
                // Rolled bombs go off early when the enemy gets close.
                if spec.throwSpeed > 0, (enemyBody.position - h.position).length <= enemyBody.radius + 22 {
                    fuse = min(fuse, 0.12)
                }
                h.kind = .bomb(fuse: fuse)
                guard fuse <= 0 else { break }
                keep = false
                if spec.chainRadius > 0 { blasts.append((h.position, spec.chainRadius)) }
                let offset = enemyBody.position - h.position
                if offset.length <= spec.radius + enemyBody.radius * 0.5 {
                    let dir = offset.length > 1e-6 ? offset.normalized : Vec2(0, 1)
                    damage.append(DamageEvent(target: enemy, amount: spec.damage * state.damageMultiplier,
                                              point: enemyBody.position - dir * enemyBody.radius, source: .explosion, direction: dir))
                    let index = state.fighter(enemy).bodyIndex
                    if !enemyBody.isKinematic && !enemyBody.isFrozen {
                        state.world.bodies[index].velocity += dir * spec.knockback
                    }
                }
                for k in 0..<spec.spikes {
                    let dir = Vec2.fromAngle(h.rotation + Double(k) / Double(spec.spikes) * 2 * .pi)
                    spawn(Projectile(owner: h.owner, position: h.position + dir * 10, previousPosition: h.position + dir * 10,
                                     velocity: dir * spec.spikeSpeed, radius: 6, baseDamage: spec.spikeDamage, maxLifetime: 1.4,
                                     kind: .iceSpike), state: &state)
                }
                events.append(.explosion(owner: h.owner, position: h.position, radius: spec.radius, icy: spec.icy))
                spawned += AbilitySystem.blastHazards(h.owner, at: h.position, state: &state)

            case .miniBomb(var fuse, let amount):
                fuse -= dt
                if (enemyBody.position - h.position).length <= enemyBody.radius + 16 { fuse = min(fuse, 0.1) }
                h.kind = .miniBomb(fuse: fuse, damage: amount)
                guard fuse <= 0 else { break }
                keep = false
                let offset = enemyBody.position - h.position
                if offset.length <= h.radius + enemyBody.radius * 0.5 {
                    let dir = offset.length > 1e-6 ? offset.normalized : Vec2(0, 1)
                    damage.append(DamageEvent(target: enemy, amount: amount * state.damageMultiplier,
                                              point: enemyBody.position - dir * enemyBody.radius, source: .explosion, direction: dir))
                    if !enemyBody.isKinematic && !enemyBody.isFrozen {
                        state.world.bodies[state.fighter(enemy).bodyIndex].velocity += dir * 220
                    }
                }
                events.append(.explosion(owner: h.owner, position: h.position, radius: h.radius, icy: false))

            case .honey(let slow):
                if (enemyBody.position - h.position).length <= h.radius + enemyBody.radius * 0.3 {
                    state.fighters[enemy.rawValue].slowAmount = max(slow, state.fighter(enemy).slowRemaining > 0 ? state.fighter(enemy).slowAmount : 0)
                    state.fighters[enemy.rawValue].slowRemaining = max(state.fighter(enemy).slowRemaining, 0.3)
                }

            case .lava:
                // One burn tick per half second however many pools the enemy stands in.
                guard state.fighter(h.owner).burnCooldown <= 0, case .arsenal(.magma(let spec)) = attack,
                      (enemyBody.position - h.position).length <= h.radius + enemyBody.radius * 0.35 else { break }
                state.fighters[h.owner.rawValue].burnCooldown = zoneTickInterval
                damage.append(DamageEvent(target: enemy, amount: spec.damagePerSecond * zoneTickInterval * state.damageMultiplier,
                                          point: enemyBody.position + Vec2(0, enemyBody.radius * 0.6), source: .hazard,
                                          direction: Vec2(0, -1)))

            case .portal(let exit, _):
                let enemyState = state.fighter(enemy)
                // Rift: open portals sting the enemy nearby.
                if case .rift(let interval, let sting, let range) = state.fighter(h.owner).definition.abilities.side, h.hitCooldown <= 0,
                   (enemyBody.position - h.position).length <= range {
                    h.hitCooldown = interval
                    damage.append(DamageEvent(target: enemy, amount: sting * state.damageMultiplier, point: enemyBody.position,
                                              source: .hazard, direction: (enemyBody.position - h.position).normalized))
                }
                guard enemyState.portalCooldown <= 0, !enemyState.isHeld, !enemyBody.isKinematic, !enemyBody.ignoresSpeedLimit,
                      (enemyBody.position - h.position).length <= h.radius,
                      case .arsenal(.portal(let spec)) = attack else { break }
                state.fighters[enemy.rawValue].portalCooldown = 1
                fling(enemy, from: exit, speed: spec.fling, state: &state)
                damage.append(DamageEvent(target: enemy, amount: spec.damage * state.damageMultiplier, point: exit,
                                          source: .hazard, direction: Vec2(0, -1)))
                events.append(.hazardPlaced(owner: h.owner, position: h.position))
                events.append(.hazardPlaced(owner: h.owner, position: exit))

            case .errorTile:
                guard h.hitCooldown <= 0, !state.fighter(enemy).isHeld, !enemyBody.isKinematic,
                      (enemyBody.position - h.position).length <= h.radius + enemyBody.radius * 0.35,
                      case .arsenal(.glitch(let spec)) = attack else { break }
                h.hitCooldown = 1.2
                damage.append(DamageEvent(target: enemy, amount: spec.tileDamage * state.damageMultiplier, point: enemyBody.position,
                                          source: .hazard, direction: (enemyBody.position - h.position).normalized))
                hold(enemy, for: spec.tileStun, style: .time, state: &state, events: &events)

            case .icePatch:
                // Standing on the ice chills the enemy toward a freeze.
                guard h.hitCooldown <= 0, !state.fighter(enemy).isHeld, !enemyBody.isKinematic,
                      (enemyBody.position - h.position).length <= h.radius + enemyBody.radius * 0.3,
                      case .arsenal(.bombs(let spec)) = attack, spec.chillToFreeze > 0 else { break }
                h.hitCooldown = 1.1
                state.fighters[enemy.rawValue].chill += 1
                state.fighters[enemy.rawValue].chillRemaining = chillDuration
                if state.fighters[enemy.rawValue].chill >= spec.chillToFreeze {
                    state.fighters[enemy.rawValue].chill = 0
                    hold(enemy, for: spec.freezeDuration, style: .ice, state: &state, events: &events)
                }

            case .turret(var fireTimer):
                fireTimer -= dt
                if fireTimer <= 0, case .arsenal(.turrets(let spec)) = attack {
                    fireTimer = spec.fireInterval
                    let dir = (enemyBody.position - h.position).normalized
                    let start = h.position + dir * 16
                    spawn(Projectile(owner: h.owner, position: start, previousPosition: start, velocity: dir * spec.shotSpeed,
                                     radius: 7, baseDamage: spec.damage, maxLifetime: 2, kind: .cannonball), state: &state)
                    events.append(.projectileFired(owner: h.owner, position: start, direction: dir))
                }
                h.kind = .turret(fireTimer: fireTimer)

            case .arc:
                break

            case .track(let end, var warning, var progress, var hasHit):
                guard case .arsenal(.train(let spec)) = attack else { break }
                if warning > 0 {
                    warning -= dt
                    if warning <= 0 { events.append(.trainDeparted(owner: h.owner, position: h.position)) }
                } else {
                    let length = max(1, (end - h.position).length)
                    progress += spec.trainSpeed * dt / length
                    let train = h.position + (end - h.position) * min(1, progress)
                    let offset = enemyBody.position - train
                    if !hasHit, offset.length <= spec.width + enemyBody.radius {
                        hasHit = true
                        let along = (end - h.position).normalized
                        let side = Vec2(-along.y, along.x)
                        let push = (side * (offset.dot(side) >= 0 ? 1 : -1) + along * 0.6).normalized
                        damage.append(DamageEvent(target: enemy, amount: spec.damage * state.damageMultiplier,
                                                  point: train, source: .train, direction: push))
                        let index = state.fighter(enemy).bodyIndex
                        if !enemyBody.isKinematic && !enemyBody.isFrozen {
                            state.world.bodies[index].velocity = push * spec.knockback
                        }
                    }
                    if progress >= 1 { keep = false }
                }
                h.kind = .track(end: end, warning: warning, progress: progress, hasHit: hasHit)
            }

            if keep { survivors.append(h) }
        }
        // Chain reaction: bombs caught in a blast go off right after.
        for k in survivors.indices {
            guard case .bomb(let fuse) = survivors[k].kind,
                  blasts.contains(where: { (survivors[k].position - $0.position).length <= $0.radius }) else { continue }
            survivors[k].kind = .bomb(fuse: min(fuse, 0.1))
        }
        state.hazards = survivors + spawned
        for slot in bonusDice {
            if case .arsenal(.dice(let spec)) = state.fighter(slot).definition.attack {
                throwDie(slot, spec, loaded: false, state: &state, events: &events)
            }
        }
    }

    /// Moves a thrown hazard, bouncing it off the walls and slowing it to a stop.
    private static func roll(_ h: inout Hazard, dt: Double, _ state: BattleState) {
        let r: Double = { switch h.kind { case .bomb: return 14; case .miniBomb: return 10; default: return h.radius } }()
        let w = state.world.width, height = state.world.height
        h.position += h.velocity * dt
        if (h.position.x < r && h.velocity.x < 0) || (h.position.x > w - r && h.velocity.x > 0) { h.velocity.x = -h.velocity.x }
        if (h.position.y < r && h.velocity.y < 0) || (h.position.y > height - r && h.velocity.y > 0) { h.velocity.y = -h.velocity.y }
        h.position = clampInside(h.position, margin: r, state)
        h.rotation += h.velocity.length * dt / r * (h.velocity.x >= 0 ? 1 : -1)
        h.velocity = h.velocity * exp(-rollFriction * dt)
        if h.velocity.length < 15 { h.velocity = .zero }
    }

    // MARK: Status helpers

    /// Locks a fighter in place. It stays solid, so the attacker can still hit it.
    static func hold(_ slot: PlayerSlot, for duration: Double, style: HoldStyle, state: inout BattleState,
                     events: inout [BattleEvent]) {
        let i = slot.rawValue
        let bodyIndex = state.fighters[i].bodyIndex
        let body = state.world.bodies[bodyIndex]
        guard !body.isKinematic, !body.ignoresSpeedLimit else { return }
        if !state.fighters[i].isHeld {
            state.fighters[i].heldVelocity = body.velocity
        }
        state.fighters[i].holdRemaining = max(state.fighters[i].holdRemaining, duration)
        state.fighters[i].holdStyle = style
        state.world.bodies[bodyIndex].isFrozen = true
        state.world.bodies[bodyIndex].velocity = .zero
        events.append(.held(slot, position: body.position))
    }

    /// Adds poison; repeated applications stack up to `cap` damage per second.
    static func poison(_ slot: PlayerSlot, perSecond: Double, duration: Double, cap: Double, state: inout BattleState,
                       events: inout [BattleEvent]) {
        let i = slot.rawValue
        state.fighters[i].poisonPerSecond = min(cap, state.fighters[i].poisonPerSecond + perSecond)
        state.fighters[i].poisonRemaining = max(state.fighters[i].poisonRemaining, duration)
        events.append(.poisoned(slot, position: state.body(of: slot).position))
    }

    // MARK: Geometry helpers

    private static func spawn(_ projectile: Projectile, state: inout BattleState) {
        state.projectiles.append(projectile)
    }

    static func addHazard(_ hazard: Hazard, max: Int, state: inout BattleState) {
        state.hazards.append(hazard)
        let owned = state.hazards.indices.filter { sameKind(state.hazards[$0], hazard) }
        if owned.count > max, let oldest = owned.first {
            state.hazards.remove(at: oldest)
        }
    }

    private static func sameKind(_ a: Hazard, _ b: Hazard) -> Bool {
        guard a.owner == b.owner else { return false }
        switch (a.kind, b.kind) {
        case (.trap, .trap), (.zone, .zone), (.die, .die), (.laser, .laser), (.bomb, .bomb), (.turret, .turret), (.track, .track),
             (.miniBomb, .miniBomb), (.icePatch, .icePatch), (.honey, .honey), (.lava, .lava), (.portal, .portal),
             (.errorTile, .errorTile):
            return true
        default:
            return false
        }
    }

    private static func rotation(_ state: inout BattleState) -> Double {
        Double.random(in: 0..<(2 * .pi), using: &state.rng)
    }

    /// Unit vector pointing into the arena from a point on a wall.
    static func wallNormal(_ p: Vec2, _ state: BattleState) -> Vec2 {
        let w = state.world.width, h = state.world.height
        let distances = [(p.x, Vec2(1, 0)), (w - p.x, Vec2(-1, 0)), (p.y, Vec2(0, 1)), (h - p.y, Vec2(0, -1))]
        return distances.min { $0.0 < $1.0 }!.1
    }

    /// Where a line from a wall point, heading straight into the arena, meets the opposite wall.
    private static func crossPoint(from p: Vec2, normal n: Vec2, _ state: BattleState) -> Vec2 {
        if n.x != 0 { return Vec2(n.x > 0 ? state.world.width : 0, p.y) }
        return Vec2(p.x, n.y > 0 ? state.world.height : 0)
    }

    static func clampInside(_ p: Vec2, margin: Double, _ state: BattleState) -> Vec2 {
        Vec2(min(state.world.width - margin, max(margin, p.x)), min(state.world.height - margin, max(margin, p.y)))
    }
}
