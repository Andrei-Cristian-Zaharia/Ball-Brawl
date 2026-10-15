import Foundation

/// Runs every fighter's automatic attack for one fixed step.
///
/// Damage is *collected* here and applied by `BattleSimulation` at the end of the
/// step, so simultaneous lethal hits resolve as a draw.
enum AttackSystem {
    static func update(
        _ state: inout BattleState,
        dt: Double,
        physics: PhysicsStepResult,
        events: inout [BattleEvent]
    ) -> [DamageEvent] {
        var damage: [DamageEvent] = []
        let contacts = physics.bodyContacts

        // Tick contact cooldowns first and snapshot who is armed, so the result
        // doesn't depend on which player is processed first.
        for i in state.fighters.indices {
            state.fighters[i].contactCooldown = max(0, state.fighters[i].contactCooldown - dt)
        }
        let armed = state.fighters.map { $0.contactCooldown <= 0 }
        let grabber = resolveGrabStarter(state)
        let drainer = resolveDrainStarter(state)

        for slot in PlayerSlot.allCases {
            switch state.fighter(slot).definition.attack {
            case .projectile(let spec):
                updateProjectileAttack(slot, spec, &state, dt: dt, events: &events)
            case .contact(let spec):
                updateContactAttack(slot, spec, &state, armed: armed, contacts: contacts, damage: &damage)
            case .pulse(let spec):
                updatePulseAttack(slot, spec, &state, dt: dt, events: &events)
            case .grab(let spec):
                updateGrabAttack(slot, spec, &state, dt: dt, startGrab: grabber == slot,
                                 physics: physics, events: &events, damage: &damage)
            case .web(let spec):
                spinWebThreads(slot, spec, &state, physics: physics, events: &events)
            case .drain(let spec):
                updateDrainAttack(slot, spec, &state, dt: dt, canLatch: drainer == slot, events: &events, damage: &damage)
            case .chess(let spec):
                updateChessAttack(slot, spec, &state, dt: dt, events: &events, damage: &damage)
            case .eclipse(let spec):
                updateEclipseAttack(slot, spec, &state, dt: dt, events: &events, damage: &damage)
            case .arsenal(let attack):
                ArsenalSystem.update(slot, attack, &state, dt: dt, physics: physics, events: &events, damage: &damage)
            }
        }

        ArsenalSystem.updateShared(&state, dt: dt, events: &events, damage: &damage)
        updateProjectiles(&state, dt: dt, events: &events, damage: &damage)
        updatePulses(&state, dt: dt, damage: &damage)
        updateWebThreads(&state, dt: dt, events: &events, damage: &damage)
        state.world.enforceSpeedLimits()
        return damage
    }

    // MARK: Blaster

    private static func updateProjectileAttack(
        _ slot: PlayerSlot, _ spec: ProjectileAttack,
        _ state: inout BattleState, dt: Double, events: inout [BattleEvent]
    ) {
        state.fighters[slot.rawValue].attackTimer += dt
        while state.fighters[slot.rawValue].attackTimer >= spec.interval {
            state.fighters[slot.rawValue].attackTimer -= spec.interval
            let fighter = state.fighter(slot)
            let body = state.body(of: slot)
            let spawn = body.position + fighter.aim * (body.radius + spec.projectileRadius + 2)
            state.projectiles.append(Projectile(
                owner: slot,
                position: spawn,
                previousPosition: spawn,
                velocity: fighter.aim * spec.projectileSpeed,
                radius: spec.projectileRadius,
                baseDamage: spec.damage,
                maxLifetime: spec.maxLifetime
            ))
            events.append(.projectileFired(owner: slot, position: spawn, direction: fighter.aim))
        }
    }

    private static func updateProjectiles(
        _ state: inout BattleState, dt: Double,
        events: inout [BattleEvent], damage: inout [DamageEvent]
    ) {
        let width = state.world.width
        let height = state.world.height
        var survivors: [Projectile] = []
        survivors.reserveCapacity(state.projectiles.count)

        for var p in state.projectiles {
            let target = state.body(of: p.owner.opponent)

            // Homing projectiles (bees) turn toward the opponent at a limited rate.
            if p.turnRate > 0 {
                let speed = p.velocity.length
                let desired = (target.position - p.position).angle
                var diff = desired - p.velocity.angle
                while diff > .pi { diff -= 2 * .pi }
                while diff < -.pi { diff += 2 * .pi }
                let turn = max(-p.turnRate * dt, min(p.turnRate * dt, diff))
                p.velocity = Vec2.fromAngle(p.velocity.angle + turn, length: speed)
            }

            p.previousPosition = p.position
            p.position += p.velocity * dt
            p.age += dt

            // Swept test in the target's frame of reference, so neither the
            // projectile's nor the target's motion can skip over a hit.
            let relStart = p.previousPosition - target.previousPosition
            let relEnd = p.position - target.position
            if Vec2.segmentDistanceToOrigin(relStart, relEnd) <= target.radius + p.radius {
                let direction = p.velocity.normalized
                damage.append(DamageEvent(
                    target: p.owner.opponent,
                    amount: p.baseDamage * state.damageMultiplier,
                    point: target.position - direction * target.radius,
                    source: p.kind == .shard || p.kind == .iceSpike ? .shard : .projectile,
                    direction: direction
                ))
                ArsenalSystem.projectileHit(p, state: &state, events: &events)
                continue
            }

            let r = p.radius
            if p.position.x - r <= 0 || p.position.x + r >= width ||
                p.position.y - r <= 0 || p.position.y + r >= height {
                if p.kind == .bee {
                    // Bees bounce off walls instead of dying.
                    if p.position.x - r <= 0 || p.position.x + r >= width { p.velocity.x = -p.velocity.x }
                    if p.position.y - r <= 0 || p.position.y + r >= height { p.velocity.y = -p.velocity.y }
                    p.position = Vec2(min(max(p.position.x, r), width - r), min(max(p.position.y, r), height - r))
                } else {
                    let impact = Vec2(min(max(p.position.x, r), width - r), min(max(p.position.y, r), height - r))
                    events.append(.projectileHitWall(owner: p.owner, position: impact))
                    continue
                }
            }

            if p.age < p.maxLifetime { survivors.append(p) }
        }
        state.projectiles = survivors
    }

    // MARK: Spike

    private static func updateContactAttack(
        _ slot: PlayerSlot, _ spec: ContactAttack,
        _ state: inout BattleState, armed: [Bool],
        contacts: [BodyContact], damage: inout [DamageEvent]
    ) {
        guard armed[slot.rawValue] else { return }

        let mine = state.fighter(slot).bodyIndex
        let theirs = state.fighter(slot.opponent).bodyIndex
        guard let contact = contacts.first(where: {
            ($0.a == mine && $0.b == theirs) || ($0.a == theirs && $0.b == mine)
        }) else { return }

        let towardOpponent = contact.a == mine ? contact.normal : -contact.normal
        let approach = contact.a == mine ? contact.approachSpeedA : contact.approachSpeedB
        let opponentApproach = contact.a == mine ? contact.approachSpeedB : contact.approachSpeedA

        // Clash: when two armed contact fighters collide, only the harder rammer lands the hit.
        if case .contact = state.fighter(slot.opponent).definition.attack,
           armed[slot.opponent.rawValue],
           opponentApproach > approach {
            return
        }
        let ramFactor = min(1, approach / spec.fullDamageSpeed)
        let base = spec.minDamage + (spec.maxDamage - spec.minDamage) * ramFactor
        let myBody = state.world.bodies[mine]
        damage.append(DamageEvent(
            target: slot.opponent,
            amount: base * state.damageMultiplier,
            point: myBody.position + towardOpponent * myBody.radius,
            source: .contact,
            direction: towardOpponent
        ))
        state.fighters[slot.rawValue].contactCooldown = spec.cooldown
    }

    // MARK: Pulse

    private static func updatePulseAttack(
        _ slot: PlayerSlot, _ spec: PulseAttack,
        _ state: inout BattleState, dt: Double, events: inout [BattleEvent]
    ) {
        state.fighters[slot.rawValue].attackTimer += dt
        guard state.fighters[slot.rawValue].attackTimer >= spec.interval else { return }
        state.fighters[slot.rawValue].attackTimer -= spec.interval

        let body = state.body(of: slot)
        state.pulses.append(PulseWave(
            owner: slot,
            center: body.position,
            startRadius: body.radius,
            range: spec.range,
            expandDuration: spec.expandDuration,
            baseDamage: spec.damage,
            knockback: spec.knockback
        ))
        events.append(.pulseReleased(owner: slot, position: body.position))
    }

    private static func updatePulses(_ state: inout BattleState, dt: Double, damage: inout [DamageEvent]) {
        for i in state.pulses.indices {
            state.pulses[i].age += dt
            let wave = state.pulses[i]
            guard !wave.hasHit, wave.age <= wave.expandDuration + dt else { continue }

            let targetSlot = wave.owner.opponent
            let targetIndex = state.fighter(targetSlot).bodyIndex
            let target = state.world.bodies[targetIndex]
            let offset = target.position - wave.center
            guard offset.length - target.radius <= wave.radius else { continue }

            state.pulses[i].hasHit = true
            let direction = offset.length > 1e-6 ? offset.normalized : Vec2(0, 1)
            if !target.isKinematic {
                state.world.bodies[targetIndex].velocity += direction * wave.knockback
            }
            damage.append(DamageEvent(
                target: targetSlot,
                amount: wave.baseDamage * state.damageMultiplier,
                point: target.position - direction * target.radius,
                source: .pulse,
                direction: direction
            ))
        }
        state.pulses.removeAll { $0.isFinished }
    }

    // MARK: Grappler

    /// Who may start a grab this step. If both could, the one driving harder
    /// toward the other wins, so the result doesn't depend on processing order.
    private static func resolveGrabStarter(_ state: BattleState) -> PlayerSlot? {
        func eagerness(_ slot: PlayerSlot) -> Double? {
            let fighter = state.fighter(slot)
            guard case .grab(let spec) = fighter.definition.attack,
                  fighter.grabPhase == .idle,
                  fighter.attackTimer >= spec.cooldown else { return nil }
            let me = state.body(of: slot)
            let them = state.body(of: slot.opponent)
            // Nobody grabs while either ball is already held or flying from a throw.
            guard !me.isKinematic, !them.isKinematic, !me.ignoresSpeedLimit, !them.ignoresSpeedLimit,
                  !me.isFrozen, !them.isFrozen else { return nil }
            let offset = them.position - me.position
            guard offset.length - me.radius - them.radius <= spec.reach else { return nil }
            return me.velocity.dot(offset.normalized)
        }
        switch (eagerness(.one), eagerness(.two)) {
        case let (a?, b?): return a >= b ? .one : .two
        case (.some, nil): return .one
        case (nil, .some): return .two
        case (nil, nil): return nil
        }
    }

    private static func updateGrabAttack(
        _ slot: PlayerSlot, _ spec: GrabAttack,
        _ state: inout BattleState, dt: Double, startGrab: Bool,
        physics: PhysicsStepResult, events: inout [BattleEvent], damage: inout [DamageEvent]
    ) {
        var fighter = state.fighter(slot)
        let targetIndex = state.fighter(slot.opponent).bodyIndex
        var target = state.world.bodies[targetIndex]
        let me = state.body(of: slot)

        func finishGrab() {
            target.isKinematic = false
            target.ignoresSpeedLimit = false
            fighter.grabPhase = .idle
            fighter.attackTimer = 0
        }

        switch fighter.grabPhase {
        case .idle:
            fighter.attackTimer = min(spec.cooldown, fighter.attackTimer + dt)
            if startGrab {
                let offset = target.position - me.position
                let relVel = target.velocity - me.velocity
                // Spin the way the opponent was already sliding past.
                let direction: Double = offset.x * relVel.y - offset.y * relVel.x >= 0 ? 1 : -1
                target.isKinematic = true
                fighter.grabPhase = .swinging(angle: offset.angle, direction: direction, elapsed: 0)
                events.append(.grabbed(by: slot, position: target.position))
            }

        case .swinging(var angle, let direction, var elapsed):
            elapsed += dt
            let t = min(1, elapsed / spec.swingDuration)
            let spinSpeed = spec.startSpinSpeed + (spec.endSpinSpeed - spec.startSpinSpeed) * t
            angle += direction * spinSpeed * dt

            let orbit = me.radius + target.radius + 6
            let radial = Vec2.fromAngle(angle)
            let tangent = Vec2(-radial.y, radial.x) * direction
            var position = me.position + radial * orbit
            target.velocity = me.velocity + tangent * (spinSpeed * orbit)

            // Swung into a wall: smash!
            let r = target.radius
            var wallNormal = Vec2.zero
            if position.x < r { position.x = r; wallNormal.x = 1 }
            else if position.x > state.world.width - r { position.x = state.world.width - r; wallNormal.x = -1 }
            if position.y < r { position.y = r; wallNormal.y = 1 }
            else if position.y > state.world.height - r { position.y = state.world.height - r; wallNormal.y = -1 }
            target.position = position

            if wallNormal != .zero {
                let n = wallNormal.normalized
                let into = target.velocity.dot(n)
                if into < 0 { target.velocity -= n * (2 * into) }
                damage.append(DamageEvent(target: slot.opponent, amount: spec.smashDamage * state.damageMultiplier,
                                          point: position - n * r, source: .slam, direction: -n))
                finishGrab()
            } else if elapsed >= spec.swingDuration {
                target.isKinematic = false
                target.ignoresSpeedLimit = true
                target.velocity = tangent * spec.throwSpeed
                fighter.grabPhase = .thrown(elapsed: 0)
                events.append(.thrown(by: slot, position: position))
            } else {
                fighter.grabPhase = .swinging(angle: angle, direction: direction, elapsed: elapsed)
            }

        case .thrown(var elapsed):
            elapsed += dt
            if let wall = physics.wallContacts.first(where: { $0.body == targetIndex }) {
                let direction = (wall.wallPoint - wall.point).normalized
                damage.append(DamageEvent(target: slot.opponent, amount: spec.smashDamage * state.damageMultiplier,
                                          point: wall.wallPoint, source: .slam, direction: direction))
                finishGrab()
            } else if elapsed >= spec.throwTimeout ||
                        physics.bodyContacts.contains(where: { $0.a == targetIndex || $0.b == targetIndex }) {
                // Throw blocked or fizzled: no damage.
                finishGrab()
            } else {
                fighter.grabPhase = .thrown(elapsed: elapsed)
            }
        }

        state.fighters[slot.rawValue] = fighter
        state.world.bodies[targetIndex] = target
    }

    // MARK: Vampire

    /// Who may latch on this step. Only one Vampire drains at a time; if both could latch
    /// together, the one driving harder toward the other wins (same idea as grabs).
    private static func resolveDrainStarter(_ state: BattleState) -> PlayerSlot? {
        func eagerness(_ slot: PlayerSlot) -> Double? {
            let fighter = state.fighter(slot)
            let opponent = state.fighter(slot.opponent)
            guard case .drain(let spec) = fighter.definition.attack,
                  fighter.drainPhase == .idle,
                  opponent.drainPhase == .idle,
                  fighter.attackTimer >= spec.cooldown else { return nil }
            let me = state.body(of: slot)
            let them = state.body(of: slot.opponent)
            guard !me.isKinematic, !them.isKinematic else { return nil }
            let offset = them.position - me.position
            guard offset.length - me.radius - them.radius <= spec.reach else { return nil }
            return me.velocity.dot(offset.normalized)
        }
        switch (eagerness(.one), eagerness(.two)) {
        case let (a?, b?): return a >= b ? .one : .two
        case (.some, nil): return .one
        case (nil, .some): return .two
        case (nil, nil): return nil
        }
    }

    private static func updateDrainAttack(
        _ slot: PlayerSlot, _ spec: DrainAttack, _ state: inout BattleState, dt: Double, canLatch: Bool,
        events: inout [BattleEvent], damage: inout [DamageEvent]
    ) {
        var fighter = state.fighter(slot)
        let myIndex = fighter.bodyIndex
        let targetIndex = state.fighter(slot.opponent).bodyIndex
        let me = state.world.bodies[myIndex]
        let them = state.world.bodies[targetIndex]
        let offset = them.position - me.position

        switch fighter.drainPhase {
        case .idle:
            fighter.attackTimer = min(spec.cooldown, fighter.attackTimer + dt)
            if canLatch {
                fighter.drainPhase = .draining(elapsed: 0, tick: 0)
                events.append(.latched(by: slot, position: them.position))
            }

        case .draining(var elapsed, var tick):
            elapsed += dt
            tick += dt
            if tick >= spec.tickInterval {
                tick -= spec.tickInterval
                let amount = spec.drainPerSecond * spec.tickInterval * state.damageMultiplier
                let direction = offset.normalized
                damage.append(DamageEvent(target: slot.opponent, amount: amount,
                                          point: them.position - direction * them.radius,
                                          source: .drain, direction: direction))
                let healed = max(0, min(amount * spec.healFraction,
                                         fighter.definition.maxHealth + spec.maxOverheal - fighter.health))
                fighter.health += healed
                events.append(.healed(slot, amount: healed, position: me.position))
            }

            // The tether acts like a rope: past its slack it pulls the two balls together.
            let ropeLength = me.radius + them.radius + spec.tetherSlack
            let distance = offset.length
            if distance > ropeLength, !me.isKinematic, !them.isKinematic, distance > 1e-6 {
                let n = offset / distance
                let excess = distance - ropeLength
                state.world.bodies[myIndex].position += n * (excess / 2)
                state.world.bodies[targetIndex].position -= n * (excess / 2)
                let separating = (them.velocity - me.velocity).dot(n)
                if separating > 0 {
                    state.world.bodies[myIndex].velocity += n * (separating / 2)
                    state.world.bodies[targetIndex].velocity -= n * (separating / 2)
                }
            }

            let snapped = distance > ropeLength + spec.tetherSlack * 2
            if elapsed >= spec.duration || snapped {
                fighter.drainPhase = .idle
                fighter.attackTimer = 0
            } else {
                fighter.drainPhase = .draining(elapsed: elapsed, tick: tick)
            }
        }
        state.fighters[slot.rawValue] = fighter
    }

    // MARK: Gambit

    /// Gambit picks randomly among this many of its best-aimed moves.
    private static let chessCandidates = 3

    private static func updateChessAttack(
        _ slot: PlayerSlot, _ spec: ChessAttack, _ state: inout BattleState, dt: Double,
        events: inout [BattleEvent], damage: inout [DamageEvent]
    ) {
        var fighter = state.fighter(slot)
        let myIndex = fighter.bodyIndex
        let targetIndex = state.fighter(slot.opponent).bodyIndex

        switch fighter.chessPhase {
        case .idle:
            fighter.attackTimer = min(spec.interval, fighter.attackTimer + dt)
            let me = state.world.bodies[myIndex]
            // Wait while being held or thrown by someone else.
            if fighter.attackTimer >= spec.interval, !me.isKinematic, !me.ignoresSpeedLimit, !me.isFrozen {
                let move = randomChessMove(from: me.position, radius: me.radius,
                                           target: state.world.bodies[targetIndex].position, state: &state)
                state.world.bodies[myIndex].isKinematic = true
                fighter.chessPhase = .thinking(move: move, elapsed: 0, savedVelocity: me.velocity)
                events.append(.chessPlanned(slot, piece: move.piece, position: me.position))
            }

        case .thinking(let move, var elapsed, let saved):
            elapsed += dt
            fighter.chessPhase = elapsed >= spec.thinkDuration
                ? .moving(move: move, traveled: 0, savedVelocity: saved, hasHit: false)
                : .thinking(move: move, elapsed: elapsed, savedVelocity: saved)

        case .moving(let move, var traveled, let saved, var hasHit):
            traveled += spec.moveSpeed * dt
            let position = move.point(at: traveled)
            state.world.bodies[myIndex].position = position

            // Anything in the way gets hit (once per move) and shoved aside.
            let me = state.world.bodies[myIndex]
            let them = state.world.bodies[targetIndex]
            let offset = them.position - position
            let minDistance = me.radius + them.radius
            if !hasHit, offset.length < minDistance {
                hasHit = true
                let direction = offset.length > 1e-6 ? offset.normalized : Vec2(1, 0)
                damage.append(DamageEvent(target: slot.opponent, amount: spec.damage * state.damageMultiplier,
                                          point: position + direction * me.radius, source: .chess, direction: direction))
                if !them.isKinematic {
                    state.world.bodies[targetIndex].position = position + direction * (minDistance + 1)
                    state.world.bodies[targetIndex].velocity += direction * spec.knockback
                }
            }

            if traveled >= move.length {
                state.world.bodies[myIndex].isKinematic = false
                state.world.bodies[myIndex].velocity = saved
                fighter.chessPhase = .idle
                fighter.attackTimer = 0
                events.append(.chessLanded(slot, position: position))
            } else {
                fighter.chessPhase = .moving(move: move, traveled: traveled, savedVelocity: saved, hasHit: hasHit)
            }
        }
        state.fighters[slot.rawValue] = fighter
    }

    /// Picks a random piece, then one of its legal moves from the ball's current square.
    /// The move is chosen at random among the few whose path comes closest to the opponent.
    private static func randomChessMove(from position: Vec2, radius: Double, target: Vec2,
                                        state: inout BattleState) -> ChessMove {
        let tile = GameConfig.boardTile
        let cols = Int(state.world.width / tile)
        let rows = Int(state.world.height / tile)
        let col = min(cols - 1, max(0, Int(position.x / tile)))
        let row = min(rows - 1, max(0, Int(position.y / tile)))
        let width = state.world.width
        let height = state.world.height

        func center(_ c: Int, _ r: Int) -> Vec2 {
            // Square centre, nudged in so the ball never pokes through a wall.
            Vec2(min(width - radius, max(radius, (Double(c) + 0.5) * tile)),
                 min(height - radius, max(radius, (Double(r) + 0.5) * tile)))
        }

        func move(_ piece: ChessPiece, to dest: (col: Int, row: Int)) -> ChessMove {
            var path = [position]
            if piece == .knight {
                // Long leg first, then the short one: the classic L.
                path.append(abs(dest.col - col) == 2 ? center(dest.col, row) : center(col, dest.row))
            }
            path.append(center(dest.col, dest.row))
            return ChessMove(piece: piece, path: path)
        }

        func closestApproach(_ m: ChessMove) -> Double {
            zip(m.path, m.path.dropFirst()).map { Vec2.segmentDistanceToOrigin($0.0 - target, $0.1 - target) }.min() ?? .infinity
        }

        for piece in ChessPiece.allCases.shuffled(using: &state.rng) {
            let moves = piece.destinations(col: col, row: row, cols: cols, rows: rows)
                .map { move(piece, to: $0) }
                .sorted { closestApproach($0) < closestApproach($1) }
            guard !moves.isEmpty else { continue }
            return moves[Int.random(in: 0..<min(Self.chessCandidates, moves.count), using: &state.rng)]
        }
        return ChessMove(piece: .king, path: [position, center(col, row)])
    }

    // MARK: Eclipse

    private static func updateEclipseAttack(
        _ slot: PlayerSlot, _ spec: EclipseAttack, _ state: inout BattleState, dt: Double,
        events: inout [BattleEvent], damage: inout [DamageEvent]
    ) {
        var fighter = state.fighter(slot)
        switch fighter.eclipsePhase {
        case .waxing:
            fighter.attackTimer = min(spec.chargeTime, fighter.attackTimer + dt)
            if fighter.attackTimer >= spec.chargeTime {
                let stall = Double.random(in: spec.minStall...spec.maxStall, using: &state.rng)
                fighter.eclipsePhase = .stalling(remaining: stall)
            }
        case .stalling(var remaining):
            remaining -= dt
            if remaining > 0 {
                fighter.eclipsePhase = .stalling(remaining: remaining)
            } else {
                // Totality: guaranteed hit wherever the enemy is.
                let me = state.body(of: slot)
                let target = state.body(of: slot.opponent)
                let direction = (target.position - me.position).normalized
                damage.append(DamageEvent(target: slot.opponent, amount: spec.damage * state.damageMultiplier,
                                          point: target.position, source: .eclipse, direction: direction))
                events.append(.totality(by: slot, target: target.position))
                fighter.eclipsePhase = .totality(elapsed: 0)
            }
        case .totality(var elapsed):
            elapsed += dt
            if elapsed >= spec.darknessDuration {
                fighter.eclipsePhase = .waxing
                fighter.attackTimer = 0
            } else {
                fighter.eclipsePhase = .totality(elapsed: elapsed)
            }
        }
        state.fighters[slot.rawValue] = fighter
    }

    // MARK: Weaver

    private static func spinWebThreads(
        _ slot: PlayerSlot, _ spec: WebAttack, _ state: inout BattleState,
        physics: PhysicsStepResult, events: inout [BattleEvent]
    ) {
        let myIndex = state.fighter(slot).bodyIndex
        for wall in physics.wallContacts where wall.body == myIndex {
            state.threads.append(WebThread(owner: slot, anchor: wall.wallPoint, lifetime: spec.threadLifetime))
            events.append(.webSpun(owner: slot, anchor: wall.wallPoint))
            let mine = state.threads.indices.filter { state.threads[$0].owner == slot }
            if mine.count > spec.maxThreads, let oldest = mine.first {
                state.threads.remove(at: oldest)
            }
        }
    }

    private static func updateWebThreads(
        _ state: inout BattleState, dt: Double,
        events: inout [BattleEvent], damage: inout [DamageEvent]
    ) {
        for i in state.threads.indices { state.threads[i].age += dt }
        state.threads.removeAll { $0.age >= $0.lifetime }

        var survivors: [WebThread] = []
        for thread in state.threads {
            guard case .web(let spec) = state.fighter(thread.owner).definition.attack else { continue }
            // Webs go slack (harmless) while their owner is held or flying from a throw.
            let owner = state.body(of: thread.owner)
            if owner.isKinematic || owner.ignoresSpeedLimit {
                survivors.append(thread)
                continue
            }
            // The thread runs from its wall anchor to the owner's ball.
            let end = state.body(of: thread.owner).position
            let target = state.body(of: thread.owner.opponent)
            let a = thread.anchor - target.position
            let b = end - target.position
            guard Vec2.segmentDistanceToOrigin(a, b) <= target.radius + spec.thickness else {
                survivors.append(thread)
                continue
            }
            // Closest point on the thread to the target, for effects.
            let ab = b - a
            let t = ab.lengthSquared > 1e-9 ? min(1, max(0, -a.dot(ab) / ab.lengthSquared)) : 0
            let point = thread.anchor + (end - thread.anchor) * t
            // A dashing Gambit cuts straight through webs without getting hurt.
            if case .moving = state.fighter(thread.owner.opponent).chessPhase {
                events.append(.webSnapped(owner: thread.owner, point: point))
                continue
            }
            damage.append(DamageEvent(target: thread.owner.opponent, amount: spec.damage * state.damageMultiplier,
                                      point: point, source: .web, direction: (target.position - point).normalized))
            events.append(.webSnapped(owner: thread.owner, point: point))
        }
        state.threads = survivors

        for i in state.fighters.indices {
            let slot = state.fighters[i].slot
            state.fighters[i].activeThreads = state.threads.filter { $0.owner == slot }.count
        }
    }
}
