import Foundation

/// Side abilities, Ultimates and speed effects (see `BallAbilities`), plus the hooks other systems
/// call when a perk changes how a main attack lands.
///
/// Like `AttackSystem`, damage is collected and applied by `BattleSimulation` at the end of the step.
enum AbilitySystem {
    private static let bloodMoonTick = 0.25

    static func update(_ state: inout BattleState, dt: Double, events: inout [BattleEvent], damage: inout [DamageEvent]) {
        for slot in PlayerSlot.allCases {
            updateSpeed(slot, &state, dt: dt)
            let abilities = state.fighter(slot).definition.abilities
            if let side = abilities.side { updateSide(slot, side, &state, dt: dt, events: &events) }
            if let ultimate = abilities.ultimate { updateUltimate(slot, ultimate, &state, dt: dt, events: &events, damage: &damage) }
        }
    }

    // MARK: Speed

    private static func updateSpeed(_ slot: PlayerSlot, _ state: inout BattleState, dt: Double) {
        let i = slot.rawValue
        var f = state.fighters[i]
        f.slowRemaining = max(0, f.slowRemaining - dt)
        f.perkCooldown = max(0, f.perkCooldown - dt)
        f.boostRemaining = max(0, f.boostRemaining - dt)
        state.fighters[i] = f
        let scale = f.baseSpeedScale * (f.slowRemaining > 0 ? 1 - f.slowAmount : 1) * (f.boostRemaining > 0 ? f.boostAmount : 1)
        state.world.bodies[f.bodyIndex].speedScale = scale
    }

    // MARK: Side abilities

    private static func updateSide(_ slot: PlayerSlot, _ side: SideAbility, _ state: inout BattleState, dt: Double,
                                   events: inout [BattleEvent]) {
        let i = slot.rawValue
        let me = state.body(of: slot)
        let them = state.body(of: slot.opponent)
        let toThem = (them.position - me.position).normalized
        // Timed abilities wait while their ball is held or thrown.
        let free = !me.isKinematic && !me.isFrozen && !me.ignoresSpeedLimit
        func ready(_ interval: Double) -> Bool {
            state.fighters[i].sideTimer += dt
            guard state.fighters[i].sideTimer >= interval, free else { return false }
            state.fighters[i].sideTimer = 0
            return true
        }

        switch side {
        case .spikeShed(let interval, let thorns, let damage):
            guard ready(interval) else { return }
            let base = Double.random(in: 0..<(2 * .pi), using: &state.rng)
            for k in 0..<thorns {
                let dir = Vec2.fromAngle(base + Double(k) / Double(thorns) * 2 * .pi)
                let start = me.position + dir * (me.radius + 8)
                state.projectiles.append(Projectile(owner: slot, position: start, previousPosition: start, velocity: dir * 480,
                                                    radius: 5, baseDamage: damage, maxLifetime: 0.9, kind: .thorn))
            }
            events.append(.projectileFired(owner: slot, position: me.position, direction: toThem))

        case .flare(let interval, let damage, _, _):
            guard ready(interval) else { return }
            let start = me.position + toThem * (me.radius + 12)
            state.projectiles.append(Projectile(owner: slot, position: start, previousPosition: start, velocity: toThem * 420,
                                                radius: 10, baseDamage: damage, maxLifetime: 2.5, kind: .flare, turnRate: 1.6))
            events.append(.projectileFired(owner: slot, position: start, direction: toThem))

        case .batSwarm(let interval, let bats, let damage, _):
            guard ready(interval) else { return }
            for k in 0..<bats {
                let dir = Vec2.fromAngle(toThem.angle + (Double(k) - Double(bats - 1) / 2) * 1.1 + .pi)
                let start = me.position + dir * (me.radius + 8)
                state.projectiles.append(Projectile(owner: slot, position: start, previousPosition: start, velocity: dir * 330,
                                                    radius: 6, baseDamage: damage, maxLifetime: 4, kind: .bat, turnRate: 4))
            }
            events.append(.projectileFired(owner: slot, position: me.position, direction: toThem))

        case .weightedDie(let interval):
            guard ready(interval), case .arsenal(.dice(let spec)) = state.fighter(slot).definition.attack else { return }
            ArsenalSystem.throwDie(slot, spec, loaded: true, state: &state, events: &events)

        case .shedSkin(let threshold, let boost, let duration):
            let f = state.fighters[i]
            guard !f.shedUsed, f.health / f.definition.maxHealth < threshold, f.health > 0 else { return }
            state.fighters[i].shedUsed = true
            state.fighters[i].tailSegments -= state.fighters[i].tailSegments / 4
            state.tails[i] = Array(state.tails[i].suffix(state.fighters[i].tailSegments + 2))
            state.fighters[i].boostAmount = boost
            state.fighters[i].boostRemaining = duration
            state.world.bodies[f.bodyIndex].velocity = me.velocity * boost
            events.append(.ability(slot, name: "Shed Skin", position: me.position, ultimate: false))

        case .volley(let interval, let count, let damage, let speed, let homing, let aimed, let kind, let effect):
            guard ready(interval) else { return }
            let base = Double.random(in: 0..<(2 * .pi), using: &state.rng)
            for k in 0..<count {
                let angle = aimed ? toThem.angle + (Double(k) - Double(count - 1) / 2) * 0.3
                                  : base + Double(k) / Double(count) * 2 * .pi
                let dir = Vec2.fromAngle(angle)
                let radius: Double = kind == .orb ? 7 : 5
                let start = me.position + dir * (me.radius + radius + 4)
                state.projectiles.append(Projectile(owner: slot, position: start, previousPosition: start, velocity: dir * speed,
                                                    radius: radius, baseDamage: damage, maxLifetime: homing > 0 ? 3 : 1.6,
                                                    kind: kind, turnRate: homing, effect: effect))
            }
            events.append(.projectileFired(owner: slot, position: me.position, direction: toThem))

        case .aura(let interval, let damage, let range, let knockback):
            guard ready(interval) else { return }
            state.pulses.append(PulseWave(owner: slot, center: me.position, startRadius: me.radius, range: range, expandDuration: 0.25,
                                          baseDamage: damage, knockback: knockback))
            events.append(.pulseReleased(owner: slot, position: me.position))

        case .mine(let interval, let damage, let blast):
            guard ready(interval) else { return }
            // Waits on the floor until the enemy comes close (or a while passes).
            let spot = ArsenalSystem.clampInside(me.position - me.velocity.normalized * (me.radius + 14), margin: 12, state)
            state.hazards.append(Hazard(owner: slot, kind: .miniBomb(fuse: 6, damage: damage), position: spot, radius: blast,
                                        lifetime: 7, rotation: 0))
            events.append(.hazardPlaced(owner: slot, position: spot))

        case .mortar(let interval, let damage, let blast):
            guard ready(interval) else { return }
            let spot = ArsenalSystem.clampInside(them.position + them.velocity * 0.3, margin: 12, state)
            state.hazards.append(Hazard(owner: slot, kind: .miniBomb(fuse: 0.8, damage: damage), position: spot, radius: blast,
                                        lifetime: 2, rotation: 0))
            events.append(.hazardPlaced(owner: slot, position: spot))

        case .regen(let interval, let amount):
            guard ready(interval) else { return }
            let f = state.fighters[i]
            let healed = max(0, min(amount, f.definition.maxHealth - f.health))
            guard healed > 0 else { return }
            state.fighters[i].health += healed
            events.append(.healed(slot, amount: healed, position: me.position))

        case .honey(let interval, let radius, let duration, let slow):
            guard ready(interval) else { return }
            state.hazards.append(Hazard(owner: slot, kind: .honey(slow: slow), position: me.position, radius: radius,
                                        lifetime: duration, rotation: Double.random(in: 0..<(2 * .pi), using: &state.rng)))
            events.append(.hazardPlaced(owner: slot, position: me.position))

        case .howl(let interval, let boost, let duration):
            guard ready(interval) else { return }
            state.fighters[i].boostAmount = boost
            state.fighters[i].boostRemaining = duration
            events.append(.ability(slot, name: "Howl", position: me.position, ultimate: false))

        case .manaShield(let interval, let amount):
            guard ready(interval) else { return }
            state.fighters[i].shield = max(state.fighters[i].shield, amount * state.fighters[i].definition.damageScale)
            events.append(.ability(slot, name: "Mana Shield", position: me.position, ultimate: false))

        case .lagSpike(let interval, let duration):
            guard ready(interval) else { return }
            ArsenalSystem.hold(slot.opponent, for: duration, style: .time, state: &state, events: &events)
            events.append(.ability(slot, name: "Lag Spike", position: them.position, ultimate: false))

        case .swap(let interval):
            guard ready(interval), let twin = state.minions.firstIndex(where: { $0.owner == slot && $0.kind == .twin }) else { return }
            let twinIndex = state.minions[twin].bodyIndex
            let twinBody = state.world.bodies[twinIndex]
            ArsenalSystem.teleport(state.fighter(slot).bodyIndex, to: twinBody.position, velocity: twinBody.velocity, state: &state)
            ArsenalSystem.teleport(twinIndex, to: me.position, velocity: me.velocity, state: &state)
            events.append(.ability(slot, name: "Swap", position: twinBody.position, ultimate: false))

        case .cluster, .shockwave, .icePatch, .tickTock, .rift:
            // Triggered by the main attack (see the hooks below).
            break
        }
    }

    // MARK: Ultimates

    /// Adds meter for damage dealt and taken this step (only balls with an Ultimate have one).
    static func chargeUltimates(_ hits: [DamageEvent], state: inout BattleState) {
        for hit in hits {
            let attacker = hit.target.opponent
            if state.fighter(attacker).definition.abilities.ultimate != nil, canCharge(state.fighter(attacker)) {
                state.fighters[attacker.rawValue].ultimateCharge = min(1, state.fighter(attacker).ultimateCharge
                                                                         + hit.amount * Ultimate.chargePerDamageDealt)
            }
            if state.fighter(hit.target).definition.abilities.ultimate != nil, canCharge(state.fighter(hit.target)) {
                state.fighters[hit.target.rawValue].ultimateCharge = min(1, state.fighter(hit.target).ultimateCharge
                                                                           + hit.amount * Ultimate.chargePerDamageTaken)
            }
        }
    }

    private static func canCharge(_ fighter: FighterState) -> Bool {
        !fighter.isUltimateActive && fighter.ultimateLockout <= 0
    }

    private static func updateUltimate(_ slot: PlayerSlot, _ ultimate: Ultimate, _ state: inout BattleState, dt: Double,
                                       events: inout [BattleEvent], damage: inout [DamageEvent]) {
        let i = slot.rawValue
        let me = state.body(of: slot)
        let them = state.body(of: slot.opponent)
        let toThem = (them.position - me.position).normalized

        state.fighters[i].ultimateLockout = max(0, state.fighters[i].ultimateLockout - dt)
        if state.fighters[i].isUltimateActive {
            state.fighters[i].ultimateRemaining = max(0, state.fighters[i].ultimateRemaining - dt)
            runUltimate(slot, ultimate, &state, dt: dt, events: &events, damage: &damage)
            if !state.fighters[i].isUltimateActive {
                state.fighters[i].spreeGrabs = 0
                state.fighters[i].ultimateLockout = Ultimate.lockout
            }
            return
        }

        // Full meter: fire once the ball is free to act.
        guard state.fighters[i].ultimateCharge >= 1, !me.isKinematic, !me.isFrozen, !me.ignoresSpeedLimit else { return }
        state.fighters[i].ultimateCharge = 0
        state.fighters[i].ultimateRemaining = ultimate.duration
        state.fighters[i].ultimateTick = 0
        if ultimate.duration == 0 { state.fighters[i].ultimateLockout = Ultimate.lockout }
        events.append(.ability(slot, name: ultimate.name, position: me.position, ultimate: true))

        switch ultimate {
        case .carpetBomb(let bombs, let damage):
            // Along where the enemy is heading.
            for k in 0..<bombs {
                let t = 0.12 + 0.16 * Double(k)
                let p = ArsenalSystem.clampInside(them.position + them.velocity * t, margin: 14, state)
                state.hazards.append(Hazard(owner: slot, kind: .miniBomb(fuse: 0.45 + 0.15 * Double(k), damage: damage),
                                            position: p, radius: 70, lifetime: 3, rotation: 0))
            }
        case .glacier(let freeze, let spikes, let damage):
            ArsenalSystem.hold(slot.opponent, for: freeze, style: .ice, state: &state, events: &events)
            for k in 0..<spikes {
                let dir = Vec2.fromAngle(Double(k) / Double(spikes) * 2 * .pi)
                let start = ArsenalSystem.clampInside(them.position + dir * 130, margin: 8, state)
                let velocity = (them.position - start).normalized * 320
                state.projectiles.append(Projectile(owner: slot, position: start, previousPosition: start, velocity: velocity,
                                                    radius: 6, baseDamage: damage, maxLifetime: 0.8, kind: .iceSpike))
            }
        case .snakeEyes:
            for k in state.hazards.indices where state.hazards[k].owner == slot {
                guard case .die = state.hazards[k].kind else { continue }
                state.hazards[k].kind = .die(value: 6)
                state.hazards[k].loaded = true
                state.hazards[k].hitCooldown = 0
                state.hazards[k].velocity = (them.position - state.hazards[k].position).normalized * 520
            }
        case .hydra:
            if case .arsenal(.tail(let spec)) = state.fighter(slot).definition.attack {
                state.fighters[i].tailSegments = spec.maxSegments
            }
        case .wreckingSpree(let extra, _):
            state.fighters[i].spreeGrabs = extra
            if case .grab(let spec) = state.fighter(slot).definition.attack { state.fighters[i].attackTimer = spec.cooldown }
        case .lockdown(_, let duration, let hurt, let style):
            ArsenalSystem.hold(slot.opponent, for: duration, style: style, state: &state, events: &events)
            damage.append(DamageEvent(target: slot.opponent, amount: hurt * state.damageMultiplier, point: them.position,
                                      source: .hazard, direction: toThem))
        case .nova(_, let count, let damage, let kind, let effect):
            let base = Double.random(in: 0..<(2 * .pi), using: &state.rng)
            let bee = kind == .bee
            for k in 0..<count {
                let dir = Vec2.fromAngle(base + Double(k) / Double(count) * 2 * .pi)
                let start = me.position + dir * (me.radius + 8)
                state.projectiles.append(Projectile(owner: slot, position: start, previousPosition: start,
                                                    velocity: dir * (bee ? 260 : 480), radius: bee ? 6 : 5, baseDamage: damage,
                                                    maxLifetime: bee ? 4 : 1.2, kind: kind, turnRate: bee ? 3.5 : 0, effect: effect))
            }
            events.append(.projectileFired(owner: slot, position: me.position, direction: toThem))
        case .siphon(_, let amount):
            damage.append(DamageEvent(target: slot.opponent, amount: amount * state.damageMultiplier, point: them.position,
                                      source: .drain, direction: toThem))
            let f = state.fighters[i]
            let healed = max(0, min(amount * f.definition.damageScale, f.definition.maxHealth - f.health))
            state.fighters[i].health += healed
            events.append(.healed(slot, amount: healed, position: me.position))
        case .infect(_, let perSecond, let duration):
            ArsenalSystem.poison(slot.opponent, perSecond: perSecond, duration: duration,
                                 cap: max(state.fighter(slot.opponent).poisonPerSecond, perSecond), state: &state, events: &events)
        case .eruption(let blast):
            // Every lava pool turns into a quick blast, rippling out in the order they were dropped.
            var k = 0
            for h in state.hazards.indices where state.hazards[h].owner == slot {
                guard case .lava = state.hazards[h].kind else { continue }
                state.hazards[h] = Hazard(owner: slot, kind: .miniBomb(fuse: 0.05 + 0.04 * Double(k), damage: blast),
                                          position: state.hazards[h].position, radius: 58, lifetime: 2, rotation: 0)
                k += 1
            }
        case .sequence(let shots):
            state.fighters[i].maxedShots = shots
            if case .arsenal(.fibonacci(let spec)) = state.fighter(slot).definition.attack {
                state.fighters[i].attackTimer = spec.interval
            }
        case .arcaneStorm(let spells):
            guard case .arsenal(.wizard(let spec)) = state.fighter(slot).definition.attack else { break }
            var cast: [Int] = []
            for _ in 0..<spells {
                cast.append(ArsenalSystem.castSpell(slot, spec, excluding: cast, state: &state, events: &events, damage: &damage))
            }
        case .wormhole(let hurt):
            // Out of a portal far from where it was, straight at a wall.
            let far = ArsenalSystem.clampInside(Vec2(state.world.width - them.position.x, state.world.height - them.position.y),
                                                margin: 70, state)
            let from = them.position
            ArsenalSystem.fling(slot.opponent, from: far, speed: 1000, state: &state)
            damage.append(DamageEvent(target: slot.opponent, amount: hurt * state.damageMultiplier, point: far,
                                      source: .hazard, direction: Vec2(0, -1)))
            events.append(.hazardPlaced(owner: slot, position: from))
            events.append(.hazardPlaced(owner: slot, position: far))
        case .crash(let freeze, let tiles):
            ArsenalSystem.hold(slot.opponent, for: freeze, style: .time, state: &state, events: &events)
            if case .arsenal(.glitch(let spec)) = state.fighter(slot).definition.attack {
                let base = Double.random(in: 0..<(2 * .pi), using: &state.rng)
                for k in 0..<tiles {
                    let p = ArsenalSystem.clampInside(them.position + Vec2.fromAngle(base + Double(k) / Double(tiles) * 2 * .pi) * 85,
                                                      margin: spec.tileRadius, state)
                    ArsenalSystem.addHazard(Hazard(owner: slot, kind: .errorTile, position: p, radius: spec.tileRadius,
                                                   lifetime: spec.tileLifetime, hitCooldown: 0.4, rotation: base + Double(k)),
                                            max: spec.maxTiles + tiles, state: &state)
                }
            }
        case .reunite:
            // The twin rolls back into the main ball for the duration.
            if let twin = state.minions.firstIndex(where: { $0.owner == slot && $0.kind == .twin }) {
                ArsenalSystem.removeMinion(at: twin, state: &state)
            }
        case .mitosis:
            ArsenalSystem.splitCell(slot, count: min(3, 1 + state.fighter(slot).cellStage), state: &state)
        case .juggernaut, .barrage, .bloodMoon, .frenzy, .overcharge, .storm, .bloom, .hunt:
            _ = toThem
        }
    }

    /// One step of an Ultimate that lasts a while.
    private static func runUltimate(_ slot: PlayerSlot, _ ultimate: Ultimate, _ state: inout BattleState, dt: Double,
                                    events: inout [BattleEvent], damage: inout [DamageEvent]) {
        let i = slot.rawValue
        let myIndex = state.fighters[i].bodyIndex
        let me = state.world.bodies[myIndex]
        let them = state.body(of: slot.opponent)
        let toThem = (them.position - me.position).normalized
        let free = !me.isKinematic && !me.isFrozen && !me.ignoresSpeedLimit

        switch ultimate {
        case .juggernaut:
            if free { steer(myIndex, toward: toThem, state: &state, dt: dt) }

        case .wreckingSpree:
            if free, state.fighters[i].grabPhase == .idle, state.fighters[i].spreeGrabs > 0 {
                steer(myIndex, toward: toThem, state: &state, dt: dt)
            }

        case .barrage(_, let rate, let damage):
            guard free else { return }
            state.fighters[i].ultimateTick += dt
            let interval = 1 / rate
            while state.fighters[i].ultimateTick >= interval {
                state.fighters[i].ultimateTick -= interval
                state.fighters[i].barrageAngle += 2.4
                // Two bolts at a time, opposite ways.
                for flip in [0.0, Double.pi] {
                    let dir = Vec2.fromAngle(state.fighters[i].barrageAngle + flip)
                    let start = me.position + dir * (me.radius + 12)
                    state.projectiles.append(Projectile(owner: slot, position: start, previousPosition: start, velocity: dir * 750,
                                                        radius: 9, baseDamage: damage, maxLifetime: 2))
                }
                events.append(.projectileFired(owner: slot, position: me.position, direction: toThem))
            }

        case .bloodMoon(_, let perSecond):
            state.fighters[i].ultimateTick += dt
            guard state.fighters[i].ultimateTick >= bloodMoonTick else { return }
            state.fighters[i].ultimateTick -= bloodMoonTick
            let amount = perSecond * bloodMoonTick * state.damageMultiplier
            damage.append(DamageEvent(target: slot.opponent, amount: amount, point: them.position - toThem * them.radius,
                                      source: .drain, direction: toThem))
            let fighter = state.fighters[i]
            var overheal = 0.0
            var healFraction = 0.6
            if case .drain(let spec) = fighter.definition.attack { overheal = spec.maxOverheal; healFraction = spec.healFraction }
            let healed = max(0, min(amount * fighter.definition.damageScale * healFraction,
                                    fighter.definition.maxHealth + overheal - fighter.health))
            state.fighters[i].health += healed
            events.append(.healed(slot, amount: healed, position: me.position))

        case .frenzy(_, _, let rate):
            // The main attack's timers run faster.
            let extra = dt * (rate - 1)
            state.fighters[i].attackTimer += extra
            state.fighters[i].contactCooldown = max(0, state.fighters[i].contactCooldown - extra)

        case .storm(_, _, let interval, let strike):
            state.fighters[i].ultimateTick += dt
            guard state.fighters[i].ultimateTick >= interval else { return }
            state.fighters[i].ultimateTick -= interval
            damage.append(DamageEvent(target: slot.opponent, amount: strike * state.damageMultiplier,
                                      point: them.position - toThem * them.radius, source: .shock, direction: toThem))
            ArsenalSystem.addHazard(Hazard(owner: slot, kind: .arc(end: them.position - toThem * them.radius * 0.5),
                                           position: me.position + toThem * me.radius, radius: 0, lifetime: 0.3,
                                           rotation: Double.random(in: 0..<(2 * .pi), using: &state.rng)),
                                    max: 2, state: &state)

        case .bloom(let duration, let heal):
            let f = state.fighters[i]
            let healed = max(0, min(heal / duration * dt * f.definition.damageScale, f.definition.maxHealth - f.health))
            state.fighters[i].health += healed
            state.fighters[i].ultimateTick += healed
            // Show the healing in readable chunks.
            if state.fighters[i].ultimateTick >= 3 {
                events.append(.healed(slot, amount: state.fighters[i].ultimateTick, position: me.position))
                state.fighters[i].ultimateTick = 0
            }

        case .hunt, .reunite:
            if free { steer(myIndex, toward: toThem, state: &state, dt: dt) }

        case .sequence:
            // The burst: bolts come four times as fast until the maxed shots are used up.
            if state.fighters[i].maxedShots > 0 { state.fighters[i].attackTimer += dt * 3 }

        case .carpetBomb, .glacier, .snakeEyes, .hydra, .overcharge, .lockdown, .nova, .siphon, .infect, .eruption, .arcaneStorm,
             .wormhole, .crash, .mitosis:
            break
        }
    }

    /// Turns a ball toward a direction, keeping it fast.
    private static func steer(_ index: Int, toward direction: Vec2, state: inout BattleState, dt: Double) {
        let v = state.world.bodies[index].velocity
        let speed = max(v.length, 520)
        let blended = v.normalized.lerp(to: direction, min(1, 5 * dt))
        state.world.bodies[index].velocity = (blended == .zero ? direction : blended.normalized) * speed
    }

    // MARK: Hooks from the main attacks

    /// Multiplier on a Spike ram (Juggernaut).
    static func ramBoost(_ fighter: FighterState) -> Double {
        if fighter.isUltimateActive, case .juggernaut(_, let boost) = fighter.definition.abilities.ultimate { return 1 + boost }
        return 1
    }

    /// Clockwork rewound: Spring and Tick-Tock.
    static func rewound(_ slot: PlayerSlot, state: inout BattleState, events: inout [BattleEvent]) {
        let i = slot.rawValue
        let f = state.fighter(slot)
        if case .spring(let boost, let duration) = f.definition.abilities.perk {
            let me = state.body(of: slot)
            let toThem = (state.body(of: slot.opponent).position - me.position).normalized
            state.fighters[i].boostAmount = boost
            state.fighters[i].boostRemaining = duration
            state.world.bodies[f.bodyIndex].velocity = toThem * max(me.velocity.length, 420) * boost
        }
        if case .tickTock(let stun, _) = f.definition.abilities.side {
            ArsenalSystem.hold(slot.opponent, for: stun, style: .time, state: &state, events: &events)
        }
    }

    /// Twin is merged into one ball (Reunite).
    static func isReunited(_ fighter: FighterState) -> Bool {
        if fighter.isUltimateActive, case .reunite = fighter.definition.abilities.ultimate { return true }
        return false
    }

    /// Multiplier on the main Twin's bites (Reunite).
    static func twinBoost(_ fighter: FighterState) -> Double {
        if fighter.isUltimateActive, case .reunite(_, let boost) = fighter.definition.abilities.ultimate { return 1 + boost }
        return 1
    }

    /// Extra gear damage (Tick-Tock).
    static func gearBonus(_ fighter: FighterState) -> Double {
        if case .tickTock(_, let bonus) = fighter.definition.abilities.side { return bonus }
        return 0
    }

    /// Multiplier on Moss's wall heals (Bloom).
    static func wallHealBoost(_ fighter: FighterState) -> Double {
        if fighter.isUltimateActive, case .bloom = fighter.definition.abilities.ultimate { return 2 }
        return 1
    }

    /// A Wolf bite landed: Hunt heals it.
    static func wolfBit(_ slot: PlayerSlot, amount: Double, state: inout BattleState, events: inout [BattleEvent]) {
        let f = state.fighter(slot)
        guard f.isUltimateActive, case .hunt(_, let lifesteal) = f.definition.abilities.ultimate else { return }
        let healed = max(0, min(amount * f.definition.damageScale * lifesteal, f.definition.maxHealth - f.health))
        guard healed > 0 else { return }
        state.fighters[slot.rawValue].health += healed
        events.append(.healed(slot, amount: healed, position: state.body(of: slot).position))
    }

    /// Multiplier on a Snake tail bite (Hydra).
    static func tailBoost(_ fighter: FighterState) -> Double {
        if fighter.isUltimateActive, case .hydra(_, let boost) = fighter.definition.abilities.ultimate { return 1 + boost }
        return 1
    }

    /// A Spike ram landed.
    static func rammed(_ slot: PlayerSlot, state: inout BattleState, events: inout [BattleEvent]) {
        let fighter = state.fighter(slot)
        if case .barbs(let perSecond, let duration) = fighter.definition.abilities.perk {
            ArsenalSystem.poison(slot.opponent, perSecond: perSecond, duration: duration, cap: perSecond * 2, state: &state, events: &events)
        }
        if ramBoost(fighter) > 1 { state.fighters[slot.rawValue].contactCooldown *= 0.5 }
    }

    /// A Snake tail bite landed.
    static func tailBit(_ slot: PlayerSlot, state: inout BattleState, events: inout [BattleEvent]) {
        if case .venom(let perSecond, let duration) = state.fighter(slot).definition.abilities.perk {
            ArsenalSystem.poison(slot.opponent, perSecond: perSecond, duration: duration, cap: perSecond * 2, state: &state, events: &events)
        }
    }

    /// Momentum: extra slam damage for a throw landing at `impactSpeed`.
    static func slamBoost(_ fighter: FighterState, impactSpeed: Double) -> Double {
        guard case .momentum(let bonus) = fighter.definition.abilities.perk else { return 1 }
        return 1 + bonus * min(1, impactSpeed / 900)
    }

    /// A Grappler slam landed at `point`: Shockwave, and Wrecking Spree's next grab.
    static func slammed(_ slot: PlayerSlot, at point: Vec2, state: inout BattleState, events: inout [BattleEvent]) {
        let i = slot.rawValue
        if case .shockwave(let damage, let range, let knockback) = state.fighter(slot).definition.abilities.side {
            state.pulses.append(PulseWave(owner: slot, center: point, startRadius: 10, range: range, expandDuration: 0.25,
                                          baseDamage: damage, knockback: knockback))
            events.append(.pulseReleased(owner: slot, position: point))
        }
        if state.fighters[i].isUltimateActive, state.fighters[i].spreeGrabs > 0, case .grab(let spec) = state.fighter(slot).definition.attack {
            state.fighters[i].spreeGrabs -= 1
            state.fighters[i].attackTimer = spec.cooldown
            // Keep the window open long enough to land the next one.
            state.fighters[i].ultimateRemaining = max(state.fighters[i].ultimateRemaining, 1.5)
        }
    }

    /// A bomb or ice bomb went off: Cluster and Ice Patch leave something behind.
    static func blastHazards(_ owner: PlayerSlot, at position: Vec2, state: inout BattleState) -> [Hazard] {
        switch state.fighter(owner).definition.abilities.side {
        case .cluster(let bombs, let damage, let blast):
            let base = Double.random(in: 0..<(2 * .pi), using: &state.rng)
            return (0..<bombs).map { k in
                let dir = Vec2.fromAngle(base + Double(k) / Double(bombs) * 2 * .pi)
                return Hazard(owner: owner, kind: .miniBomb(fuse: 0.7, damage: damage),
                              position: ArsenalSystem.clampInside(position + dir * 24, margin: 12, state), radius: blast,
                              lifetime: 3, rotation: 0, velocity: dir * 280)
            }
        case .icePatch(let radius, let duration):
            return [Hazard(owner: owner, kind: .icePatch, position: position, radius: radius, lifetime: duration,
                           rotation: Double.random(in: 0..<(2 * .pi), using: &state.rng))]
        default:
            return []
        }
    }

    /// Extra effects when one of the ability projectiles lands.
    static func projectileHit(_ p: Projectile, state: inout BattleState, events: inout [BattleEvent]) {
        if let effect = p.effect { apply(effect, by: p.owner, state: &state, events: &events) }
        let owner = state.fighter(p.owner)
        switch (p.kind, owner.definition.abilities.side) {
        case (.thorn, _):
            state.fighters[p.owner.rawValue].contactCooldown = 0
        case (.flare, .flare(_, _, let slow, let duration)):
            let target = p.owner.opponent.rawValue
            state.fighters[target].slowAmount = slow
            state.fighters[target].slowRemaining = max(state.fighters[target].slowRemaining, duration)
        case (.bat, .batSwarm(_, _, _, let heal)):
            var overheal = 0.0
            if case .drain(let spec) = owner.definition.attack {
                overheal = spec.maxOverheal
                state.fighters[p.owner.rawValue].attackTimer = min(spec.cooldown, owner.attackTimer + 1)
            }
            state.fighters[p.owner.rawValue].health += max(0, min(heal, owner.definition.maxHealth + overheal - owner.health))
        default:
            break
        }
    }

    /// Does a hit effect to the enemy of `attacker`.
    static func apply(_ effect: HitEffect, by attacker: PlayerSlot, state: inout BattleState, events: inout [BattleEvent]) {
        let target = attacker.opponent
        switch effect {
        case .slow(let amount, let duration):
            state.fighters[target.rawValue].slowAmount = max(amount, state.fighter(target).slowRemaining > 0 ? state.fighter(target).slowAmount : 0)
            state.fighters[target.rawValue].slowRemaining = max(state.fighter(target).slowRemaining, duration)
        case .poison(let perSecond, let duration):
            ArsenalSystem.poison(target, perSecond: perSecond, duration: duration,
                                 cap: max(state.fighter(target).poisonPerSecond, perSecond * 2), state: &state, events: &events)
        case .stun(let duration, let style):
            ArsenalSystem.hold(target, for: duration, style: style, state: &state, events: &events)
        case .heal(let amount):
            let f = state.fighter(attacker)
            var overheal = 0.0
            if case .drain(let spec) = f.definition.attack { overheal = spec.maxOverheal }
            let healed = max(0, min(amount, f.definition.maxHealth + overheal - f.health))
            state.fighters[attacker.rawValue].health += healed
            if healed > 0 { events.append(.healed(attacker, amount: healed, position: state.body(of: attacker).position)) }
        }
    }

    /// A hit just landed: on-hit perks.
    static func landed(_ hit: DamageEvent, state: inout BattleState, events: inout [BattleEvent]) {
        let attacker = hit.target.opponent
        guard hit.source != .poison, state.fighter(attacker).perkCooldown <= 0,
              case .onHit(let effect, let cooldown) = state.fighter(attacker).definition.abilities.perk else { return }
        state.fighters[attacker.rawValue].perkCooldown = cooldown
        apply(effect, by: attacker, state: &state, events: &events)
    }

    /// How much more (or less) damage `target` takes right now: Bloodmark, Brittle, Weakness and Overcharge.
    static func damageTakenMultiplier(_ target: PlayerSlot, state: BattleState) -> Double {
        let attacker = state.fighter(target.opponent)
        let victim = state.fighter(target)
        var multiplier = 1.0
        if attacker.isUltimateActive, case .overcharge(_, _, let boost) = attacker.definition.abilities.ultimate { multiplier *= 1 + boost }
        if case .weaken(let amount) = victim.definition.abilities.perk, attacker.isPoisoned { multiplier *= 1 - amount }
        // Cell's membrane, while it's still growing.
        if case .arsenal(.cell(let spec)) = victim.definition.attack, victim.cellStage < spec.stages { multiplier *= 1 - spec.membrane }
        return multiplier * perkMultiplier(attacker: attacker, victim: victim)
    }

    private static func perkMultiplier(attacker: FighterState, victim: FighterState) -> Double {
        switch attacker.definition.abilities.perk {
        case .bloodmark(let bonus):
            if case .draining = attacker.drainPhase { return 1 + bonus }
            if attacker.isUltimateActive, case .bloodMoon = attacker.definition.abilities.ultimate { return 1 + bonus }
        case .brittle(let bonus):
            if victim.isHeld, victim.holdStyle == .ice { return 1 + bonus }
        default:
            break
        }
        return 1
    }
}
