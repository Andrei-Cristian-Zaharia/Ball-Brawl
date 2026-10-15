import Foundation

/// Behaviour for the arsenal fighters, plus the shared systems they are built from:
/// field hazards, status effects (poison, hold), snake tails and extra projectile kinds.
///
/// Like `AttackSystem`, damage is collected and applied by `BattleSimulation` at the end of the step.
enum ArsenalSystem {
    private static let poisonTickInterval = 0.5
    private static let zoneTickInterval = 0.5

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
            guard state.fighters[i].attackTimer >= spec.cooldown, let wall = myWallHits.first else { break }
            state.fighters[i].attackTimer = 0
            let n = wallNormal(wall.wallPoint, state)
            addHazard(Hazard(owner: slot, kind: .laser(end: crossPoint(from: wall.wallPoint, normal: n, state)),
                             position: wall.wallPoint, radius: 3, lifetime: spec.lifetime, hitCooldown: 0.3, rotation: 0),
                      max: spec.maxLasers, state: &state)
            events.append(.hazardPlaced(owner: slot, position: wall.wallPoint))

        case .zone(let spec):
            guard state.fighters[i].attackTimer >= spec.interval else { break }
            state.fighters[i].attackTimer -= spec.interval
            addHazard(Hazard(owner: slot, kind: .zone, position: me.position, radius: spec.radius, lifetime: spec.duration,
                             hitCooldown: 0.3, rotation: rotation(&state)), max: spec.maxZones, state: &state)
            events.append(.hazardPlaced(owner: slot, position: me.position))

        case .dice(let spec):
            guard state.fighters[i].attackTimer >= spec.interval else { break }
            state.fighters[i].attackTimer -= spec.interval
            let value = Int.random(in: 1...6, using: &state.rng)
            // Dice stay inert briefly so the thrower can roll clear.
            addHazard(Hazard(owner: slot, kind: .die(value: value), position: clampInside(me.position, margin: spec.dieSize, state),
                             radius: spec.dieSize, lifetime: spec.lifetime, hitCooldown: 0.8, rotation: rotation(&state)),
                      max: spec.maxDice, state: &state)
            events.append(.hazardPlaced(owner: slot, position: me.position))

        case .shards(let spec):
            let impacts = myWallHits.filter { $0.impactSpeed >= spec.minImpactSpeed }.count
                + physics.bodyContacts.filter { ($0.a == myIndex || $0.b == myIndex) && $0.impactSpeed >= spec.minImpactSpeed }.count
            guard impacts > 0, state.fighters[i].attackTimer >= spec.cooldown else { break }
            state.fighters[i].attackTimer = 0
            let base = Double.random(in: 0..<(2 * .pi), using: &state.rng)
            for k in 0..<spec.shardCount {
                let a = base + Double(k) / Double(spec.shardCount) * 2 * .pi
                let dir = Vec2.fromAngle(a)
                spawn(Projectile(owner: slot, position: me.position + dir * (me.radius + 6), previousPosition: me.position + dir * (me.radius + 6),
                                 velocity: dir * spec.shardSpeed, radius: 5, baseDamage: spec.damage, maxLifetime: 1.2, kind: .shard),
                      state: &state)
            }
            events.append(.projectileFired(owner: slot, position: me.position, direction: toThem))

        case .knives(let spec):
            let interval = knifeInterval(spec, fighter: state.fighters[i])
            guard state.fighters[i].attackTimer >= interval else { break }
            state.fighters[i].attackTimer = 0
            let start = me.position + toThem * (me.radius + 10)
            spawn(Projectile(owner: slot, position: start, previousPosition: start, velocity: toThem * spec.speed, radius: 7,
                             baseDamage: spec.damage, maxLifetime: 2, kind: .knife), state: &state)
            events.append(.projectileFired(owner: slot, position: start, direction: toThem))

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
            for point in tail.dropLast(2) where (them.position - point).length <= them.radius + spec.segmentRadius {
                let dir = (them.position - point).normalized
                damage.append(DamageEvent(target: slot.opponent, amount: spec.damage * state.damageMultiplier,
                                          point: point + dir * spec.segmentRadius, source: .tail, direction: dir))
                if !them.isFrozen { state.world.bodies[opponentIndex].velocity += dir * spec.knockback }
                state.fighters[i].contactCooldown = spec.hitCooldown
                break
            }

        case .shock(let spec):
            guard touchingOpponent, state.fighters[i].contactCooldown <= 0 else { break }
            state.fighters[i].contactCooldown = spec.cooldown
            damage.append(DamageEvent(target: slot.opponent, amount: spec.damage * state.damageMultiplier,
                                      point: me.position + toThem * me.radius, source: .shock, direction: toThem))
            hold(slot.opponent, for: spec.freezeDuration, style: .shock, state: &state, events: &events)

        case .bombs(let spec):
            guard state.fighters[i].attackTimer >= spec.interval else { break }
            state.fighters[i].attackTimer -= spec.interval
            addHazard(Hazard(owner: slot, kind: .bomb(fuse: spec.fuse), position: clampInside(me.position, margin: 14, state),
                             radius: spec.radius, lifetime: spec.fuse + 1, rotation: rotation(&state)), max: 6, state: &state)
            events.append(.hazardPlaced(owner: slot, position: me.position))

        case .turrets(let spec):
            let owned = state.hazards.filter { if case .turret = $0.kind { return $0.owner == slot }; return false }.count
            guard owned < spec.maxTurrets, state.fighters[i].attackTimer >= spec.cooldown, let wall = myWallHits.first else { break }
            state.fighters[i].attackTimer = 0
            let n = wallNormal(wall.wallPoint, state)
            addHazard(Hazard(owner: slot, kind: .turret(fireTimer: 0.6), position: wall.wallPoint + n * 16, radius: 14,
                             lifetime: spec.lifetime, rotation: 0), max: 99, state: &state)
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

    /// Called when a projectile lands, for effects beyond plain damage.
    static func projectileHit(_ p: Projectile, state: inout BattleState, events: inout [BattleEvent]) {
        if let effect = p.poison {
            poison(p.owner.opponent, perSecond: effect.perSecond, duration: effect.duration, cap: 8, state: &state, events: &events)
        }
        if p.kind == .harpoon, case .arsenal(.harpoon(let spec)) = state.fighter(p.owner).definition.attack {
            state.fighters[p.owner.rawValue].dragRemaining = spec.dragDuration
        }
    }

    // MARK: Shared systems (once per step)

    static func updateShared(_ state: inout BattleState, dt: Double, events: inout [BattleEvent], damage: inout [DamageEvent]) {
        updateStatuses(&state, dt: dt, damage: &damage)
        updateHazards(&state, dt: dt, events: &events, damage: &damage)
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

        for var h in state.hazards {
            h.age += dt
            h.hitCooldown = max(0, h.hitCooldown - dt)
            let enemy = h.owner.opponent
            let enemyBody = state.body(of: enemy)
            let attack = state.fighter(h.owner).definition.attack
            var keep = h.age < h.lifetime

            switch h.kind {
            case .trap(var armIn):
                armIn -= dt
                h.kind = .trap(armIn: armIn)
                if armIn <= 0, !state.fighter(enemy).isHeld, !enemyBody.isKinematic,
                   (enemyBody.position - h.position).length <= enemyBody.radius + h.radius * 0.6,
                   case .arsenal(.traps(let spec)) = attack {
                    damage.append(DamageEvent(target: enemy, amount: spec.damage * state.damageMultiplier, point: h.position,
                                              source: .hazard, direction: (enemyBody.position - h.position).normalized))
                    hold(enemy, for: spec.holdDuration, style: .shackle, state: &state, events: &events)
                    keep = false
                }

            case .zone:
                if h.hitCooldown <= 0, (enemyBody.position - h.position).length <= h.radius + enemyBody.radius * 0.4,
                   case .arsenal(.zone(let spec)) = attack {
                    h.hitCooldown = zoneTickInterval
                    damage.append(DamageEvent(target: enemy, amount: spec.damagePerSecond * zoneTickInterval * state.damageMultiplier,
                                              point: enemyBody.position, source: .hazard, direction: Vec2(0, -1)))
                }

            case .die(let value):
                guard case .arsenal(.dice(let spec)) = attack, h.hitCooldown <= 0 else { break }
                for slot in [enemy, h.owner] {
                    let body = state.body(of: slot)
                    guard (body.position - h.position).length <= body.radius + h.radius else { continue }
                    let perPip = slot == enemy ? spec.damagePerPip : spec.selfDamagePerPip
                    if perPip > 0 {
                        damage.append(DamageEvent(target: slot, amount: Double(value) * perPip * state.damageMultiplier,
                                                  point: h.position, source: .hazard, direction: (body.position - h.position).normalized))
                    }
                    h.kind = .die(value: Int.random(in: 1...6, using: &state.rng))
                    h.hitCooldown = spec.rerollCooldown
                    break
                }

            case .laser(let end):
                guard case .arsenal(.laser(let spec)) = attack, h.hitCooldown <= 0 else { break }
                let a = h.position - enemyBody.position
                let b = end - enemyBody.position
                if Vec2.segmentDistanceToOrigin(a, b) <= enemyBody.radius + 2 {
                    h.hitCooldown = spec.hitCooldown
                    damage.append(DamageEvent(target: enemy, amount: spec.damage * state.damageMultiplier, point: enemyBody.position,
                                              source: .hazard, direction: wallNormal(h.position, state)))
                }

            case .bomb(var fuse):
                fuse -= dt
                h.kind = .bomb(fuse: fuse)
                guard fuse <= 0, case .arsenal(.bombs(let spec)) = attack else { break }
                keep = false
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
        state.hazards = survivors
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

    private static func addHazard(_ hazard: Hazard, max: Int, state: inout BattleState) {
        state.hazards.append(hazard)
        let owned = state.hazards.indices.filter { sameKind(state.hazards[$0], hazard) }
        if owned.count > max, let oldest = owned.first {
            state.hazards.remove(at: oldest)
        }
    }

    private static func sameKind(_ a: Hazard, _ b: Hazard) -> Bool {
        guard a.owner == b.owner else { return false }
        switch (a.kind, b.kind) {
        case (.trap, .trap), (.zone, .zone), (.die, .die), (.laser, .laser), (.bomb, .bomb), (.turret, .turret), (.track, .track):
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

    private static func clampInside(_ p: Vec2, margin: Double, _ state: BattleState) -> Vec2 {
        Vec2(min(state.world.width - margin, max(margin, p.x)), min(state.world.height - margin, max(margin, p.y)))
    }
}
