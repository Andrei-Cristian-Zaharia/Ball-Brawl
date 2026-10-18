import SwiftUI

/// Draws the arena and everything in it. Logical arena coordinates are scaled to fit
/// the canvas; physics dimensions never change.
enum BattleRenderer {
    private static let borderWidth: CGFloat = 7
    private static let shadowDepth: CGFloat = 10
    private static let cornerRadius: CGFloat = 22

    /// Scale and top-left offset that fit the arena into a canvas of `size`.
    private static func layout(for size: CGSize) -> (scale: CGFloat, origin: CGPoint) {
        let width = GameConfig.arenaWidth
        let height = GameConfig.arenaHeight
        let margin = borderWidth / 2 + 2
        let scale = min(size.width / (width + margin * 2), size.height / (height + margin * 2 + shadowDepth))
        return (scale, CGPoint(x: (size.width - width * scale) / 2, y: (size.height - (height + shadowDepth) * scale) / 2))
    }

    /// Converts a point in the canvas (e.g. a touch) to arena coordinates.
    static func arenaPoint(from point: CGPoint, canvasSize size: CGSize) -> Vec2 {
        let (scale, origin) = layout(for: size)
        return Vec2(Double((point.x - origin.x) / scale), Double((point.y - origin.y) / scale))
    }

    static func draw(_ sim: BattleSimulation, alpha: Double, in context: inout GraphicsContext, size: CGSize) {
        let (scale, origin) = layout(for: size)
        let shake = sim.effects.shakeOffset
        context.translateBy(x: origin.x + shake.x * scale, y: origin.y + shake.y * scale)
        context.scaleBy(x: scale, y: scale)

        let state = sim.state
        drawArena(in: &context, sim: sim)

        let positions = state.fighters.map { position(of: $0, in: state, alpha: alpha) }

        // Floor-level things stay inside the arena.
        context.drawLayer { layer in
            layer.clip(to: arenaPath)
            for hazard in state.hazards {
                ArsenalRenderer.drawHazard(hazard, in: &layer, time: state.battleTime, state: state)
            }
            for fighter in state.fighters where !fighter.isDefeated {
                ArsenalRenderer.drawLaserAnchor(fighter, time: state.battleTime, in: &layer)
                ArsenalRenderer.drawRewindGhost(fighter, time: state.battleTime, in: &layer)
            }
            for fighter in state.fighters where !fighter.isDefeated {
                drawChessPlan(fighter, at: positions[fighter.slot.rawValue], in: &layer)
            }
            for fighter in state.fighters where !fighter.isDefeated {
                if case .pulse(let spec) = fighter.definition.attack {
                    drawPulseRange(fighter, spec, at: positions[fighter.slot.rawValue], in: &layer)
                }
                drawGrab(fighter, positions: positions, in: &layer)
            }
        }
        for thread in state.threads { drawThread(thread, to: positions[thread.owner.rawValue], state: state, in: &context) }
        for fighter in state.fighters where !fighter.isDefeated {
            drawDrainTether(fighter, positions: positions, time: state.battleTime, in: &context)
            drawBloodMoon(fighter, positions: positions, time: state.battleTime, in: &context)
            if case .arsenal(.tail(let spec)) = fighter.definition.attack {
                ArsenalRenderer.drawTail(state.tails[fighter.slot.rawValue],
                                         segmentRadius: CGFloat(spec.segmentRadius(segments: fighter.tailSegments)),
                                         color: fighter.slot.color, in: &context)
            }
        }
        for wave in state.pulses { drawPulseWave(wave, in: &context) }
        for projectile in state.projectiles {
            if projectile.kind == .bolt {
                drawProjectile(projectile, alpha: alpha, in: &context)
            } else {
                ArsenalRenderer.drawProjectile(projectile, at: projectile.previousPosition.lerp(to: projectile.position, alpha),
                                               in: &context, state: state)
            }
        }

        // Extra balls (Twin's twin, Cell's small cells), under the fighters.
        for minion in state.minions {
            let body = state.world.bodies[minion.bodyIndex]
            let fighter = state.fighter(minion.owner)
            let at = body.previousPosition.lerp(to: body.position, alpha).cgPoint
            let fade = minion.lifetime.isFinite ? min(1, max(0, (minion.lifetime - minion.age) / 0.6)) : 1
            context.drawLayer { layer in
                layer.opacity = fade
                FighterArt.draw(fighter.definition, in: &layer, center: at, radius: CGFloat(body.radius), team: minion.owner.color,
                                spin: fighter.spin * (minion.kind == .twin ? -1 : 1.5),
                                look: CGVector(dx: positions[minion.owner.opponent.rawValue].x - at.x,
                                               dy: positions[minion.owner.opponent.rawValue].y - at.y),
                                expression: .normal)
            }
        }

        for fighter in state.fighters {
            let me = positions[fighter.slot.rawValue]
            let them = positions[fighter.slot.opponent.rawValue]
            drawFighter(fighter, label: sim.labels[fighter.slot.rawValue], at: me, lookingAt: them, alpha: alpha,
                        phase: sim.phase, state: state, in: &context)
        }

        drawEffects(sim.effects, in: &context)
        for fighter in state.fighters {
            drawTotality(fighter, positions: positions, in: &context)
        }
        drawBanner(sim, in: &context)
    }

    private static var arenaPath: Path {
        Path(roundedRect: CGRect(x: 0, y: 0, width: GameConfig.arenaWidth, height: GameConfig.arenaHeight),
             cornerRadius: cornerRadius)
    }

    private static func position(of fighter: FighterState, in state: BattleState, alpha: Double) -> CGPoint {
        let body = state.world.bodies[fighter.bodyIndex]
        return body.previousPosition.lerp(to: body.position, alpha).cgPoint
    }

    // MARK: Arena

    private static func drawArena(in context: inout GraphicsContext, sim: BattleSimulation) {
        let rect = CGRect(x: 0, y: 0, width: GameConfig.arenaWidth, height: GameConfig.arenaHeight)
        let frame = arenaPath

        let map = sim.map
        context.fill(frame.offsetBy(dx: 0, dy: shadowDepth), with: .color(Theme.ink))
        context.fill(frame, with: .color(map.floor))

        // Checkerboard floor tiles (Gambit moves on these).
        context.drawLayer { layer in
            layer.clip(to: frame)
            var tiles = Path()
            let tile = CGFloat(GameConfig.boardTile)
            var row = 0
            var y: CGFloat = 0
            while y < rect.height {
                var col = 0
                var x: CGFloat = 0
                while x < rect.width {
                    if (row + col).isMultiple(of: 2) { tiles.addRect(CGRect(x: x, y: y, width: tile, height: tile)) }
                    x += tile
                    col += 1
                }
                y += tile
                row += 1
            }
            layer.fill(tiles, with: .color(map.tile))
            map.drawDecorations(in: &layer, size: rect.size, time: sim.elapsed)
        }

        let mid = CGPoint(x: rect.midX, y: rect.midY)
        var midline = Path()
        midline.move(to: CGPoint(x: 0, y: rect.midY))
        midline.addLine(to: CGPoint(x: rect.width, y: rect.midY))
        context.stroke(midline, with: .color(map.marking), style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [14, 14]))
        context.stroke(FighterArt.circle(mid, 70), with: .color(map.marking), lineWidth: 4)

        let borderColor: Color = sim.isOvertime && sin(sim.battleTime * 8) > 0 ? Theme.overtime : Theme.ink
        context.stroke(frame, with: .color(borderColor), lineWidth: borderWidth)

        for corner in [CGPoint(x: 18, y: 18), CGPoint(x: rect.maxX - 18, y: 18),
                       CGPoint(x: 18, y: rect.maxY - 18), CGPoint(x: rect.maxX - 18, y: rect.maxY - 18)] {
            let bolt = FighterArt.circle(corner, 6)
            context.fill(bolt, with: .color(map.bolt))
            context.stroke(bolt, with: .color(Theme.ink), lineWidth: 2.5)
        }
    }

    // MARK: Attacks

    private static func drawPulseRange(_ fighter: FighterState, _ spec: PulseAttack, at center: CGPoint,
                                       in context: inout GraphicsContext) {
        let color = fighter.slot.color
        let ring = FighterArt.circle(center, spec.range)
        let telegraph = max(0, (fighter.attackCharge - 0.75) / 0.25)
        context.fill(ring, with: .color(color.opacity(0.06 + 0.08 * telegraph)))
        context.stroke(ring, with: .color(color.mix(with: Theme.ink, by: 0.2).opacity(0.55 + 0.4 * telegraph)),
                       style: StrokeStyle(lineWidth: 3 + 2 * telegraph, lineCap: .round, dash: [10, 10],
                                          dashPhase: fighter.spin * 4))
    }

    private static func drawPulseWave(_ wave: PulseWave, in context: inout GraphicsContext) {
        let color = wave.owner.color
        let fade = wave.age <= wave.expandDuration
            ? 1.0
            : max(0, 1 - (wave.age - wave.expandDuration) / PulseWave.fadeDuration)
        let circle = FighterArt.circle(wave.center.cgPoint, wave.radius)
        let thickness = 3 + 7 * (1 - wave.progress)
        context.fill(circle, with: .color(color.opacity(0.22 * fade)))
        context.stroke(circle, with: .color(Theme.ink.opacity(fade)), lineWidth: thickness + 5)
        context.stroke(circle, with: .color(color.mix(with: .white, by: 0.2).opacity(fade)), lineWidth: thickness)
    }

    private static func drawProjectile(_ p: Projectile, alpha: Double, in context: inout GraphicsContext) {
        let color = p.owner.color
        let pos = p.previousPosition.lerp(to: p.position, alpha)
        let dir = p.velocity.normalized
        let side = Vec2(-dir.y, dir.x)

        var lines = Path()
        for (offset, length) in [(-0.6, 2.6), (0.0, 3.6), (0.6, 2.6)] {
            let start = pos - dir * (p.radius * 1.5) + side * (p.radius * offset)
            lines.move(to: start.cgPoint)
            lines.addLine(to: (start - dir * (p.radius * length)).cgPoint)
        }
        context.stroke(lines, with: .color(Theme.ink.opacity(0.55)), style: StrokeStyle(lineWidth: 3, lineCap: .round))

        let core = FighterArt.circle(pos.cgPoint, p.radius)
        context.fill(core, with: .color(color))
        context.stroke(core, with: .color(Theme.ink), lineWidth: 3.5)
        context.fill(FighterArt.circle((pos + Vec2(-p.radius * 0.35, -p.radius * 0.35)).cgPoint, p.radius * 0.3),
                     with: .color(.white.opacity(0.9)))
    }

    private static func drawThread(_ thread: WebThread, to end: CGPoint, state: BattleState,
                                   in context: inout GraphicsContext) {
        let owner = state.body(of: thread.owner)
        let slack = owner.isKinematic || owner.ignoresSpeedLimit
        let remaining = thread.lifetime - thread.age
        let blink = remaining < 1 && sin(thread.age * 30) < 0
        let opacity = slack ? 0.35 : (blink ? 0.4 : 1)

        var line = Path()
        line.move(to: thread.anchor.cgPoint)
        line.addLine(to: end)
        context.drawLayer { layer in
            layer.opacity = opacity
            layer.stroke(line, with: .color(Theme.ink), style: StrokeStyle(lineWidth: 6, lineCap: .round))
            layer.stroke(line, with: .color(.white),
                         style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: slack ? [6, 6] : []))
            let a = thread.anchor.cgPoint
            var splat = Path()
            for i in 0..<6 {
                let angle = Double(i) * .pi / 3
                splat.move(to: a)
                splat.addLine(to: FighterArt.point(a, 13, angle))
            }
            splat.addPath(FighterArt.circle(a, 7))
            layer.stroke(splat, with: .color(Theme.ink), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            layer.stroke(splat, with: .color(.white), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
        }
    }

    private static func drawGrab(_ fighter: FighterState, positions: [CGPoint], in context: inout GraphicsContext) {
        guard case .grab(let spec) = fighter.definition.attack else { return }
        let me = positions[fighter.slot.rawValue]
        let them = positions[fighter.slot.opponent.rawValue]
        switch fighter.grabPhase {
        case .idle where fighter.attackCharge >= 1:
            let ring = FighterArt.circle(me, CGFloat(fighter.definition.radius + spec.reach))
            context.stroke(ring, with: .color(fighter.slot.color.mix(with: Theme.ink, by: 0.2).opacity(0.6)),
                           style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [4, 9], dashPhase: fighter.spin * 6))
        case .swinging:
            var chain = Path()
            chain.move(to: me)
            chain.addLine(to: them)
            context.stroke(chain, with: .color(Theme.ink), style: StrokeStyle(lineWidth: 11, lineCap: .round))
            context.stroke(chain, with: .color(Theme.yellow), style: StrokeStyle(lineWidth: 5, lineCap: .round, dash: [7, 5]))
        default:
            break
        }
    }

    private static func drawChessPlan(_ fighter: FighterState, at position: CGPoint, in context: inout GraphicsContext) {
        let move: ChessMove
        switch fighter.chessPhase {
        case .thinking(let m, _, _), .moving(let m, _, _, _): move = m
        case .idle: return
        }
        let tile = GameConfig.boardTile
        let dest = move.destination
        let square = CGRect(x: floor(dest.x / tile) * tile, y: floor(dest.y / tile) * tile, width: tile, height: tile)
        let highlight = Path(roundedRect: square.insetBy(dx: 3, dy: 3), cornerRadius: 8)
        context.fill(highlight, with: .color(Theme.yellow.opacity(0.55)))
        context.stroke(highlight, with: .color(Theme.ink), style: StrokeStyle(lineWidth: 4, dash: [8, 6]))

        var path = Path()
        path.move(to: position)
        for point in move.path.dropFirst() { path.addLine(to: point.cgPoint) }
        context.stroke(path, with: .color(Theme.ink.opacity(0.45)),
                       style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round, dash: [1, 12]))
    }

    private static func drawDrainTether(_ fighter: FighterState, positions: [CGPoint], time: Double,
                                        in context: inout GraphicsContext) {
        guard case .draining = fighter.drainPhase else { return }
        let me = positions[fighter.slot.rawValue]
        let them = positions[fighter.slot.opponent.rawValue]
        var tether = Path()
        tether.move(to: me)
        tether.addLine(to: them)
        context.stroke(tether, with: .color(Theme.ink), style: StrokeStyle(lineWidth: 10, lineCap: .round))
        context.stroke(tether, with: .color(Theme.blood), style: StrokeStyle(lineWidth: 5, lineCap: .round))
        for k in 0..<3 {
            let t = CGFloat((time * 1.6 + Double(k) / 3).truncatingRemainder(dividingBy: 1))
            let p = CGPoint(x: them.x + (me.x - them.x) * t, y: them.y + (me.y - them.y) * t)
            let drop = FighterArt.circle(p, 6)
            context.fill(drop, with: .color(Theme.blood))
            context.stroke(drop, with: .color(Theme.ink), lineWidth: 2.5)
        }
    }

    private static func drawTotality(_ fighter: FighterState, positions: [CGPoint], in context: inout GraphicsContext) {
        guard case .eclipse(let spec) = fighter.definition.attack,
              case .totality(let elapsed) = fighter.eclipsePhase else { return }
        let fade = max(0, 1 - elapsed / spec.darknessDuration)
        context.fill(arenaPath, with: .color(Theme.ink.opacity(0.6 * fade)))

        let from = positions[fighter.slot.rawValue]
        let to = positions[fighter.slot.opponent.rawValue]
        var beam = Path()
        beam.move(to: from)
        beam.addLine(to: to)
        context.stroke(beam, with: .color(Theme.ink.opacity(fade)), style: StrokeStyle(lineWidth: 26 * fade + 4, lineCap: .round))
        context.stroke(beam, with: .color(Theme.yellow.opacity(fade)), style: StrokeStyle(lineWidth: 18 * fade + 2, lineCap: .round))
        context.stroke(beam, with: .color(.white.opacity(fade)), style: StrokeStyle(lineWidth: 7 * fade + 1, lineCap: .round))
        let ring = FighterArt.circle(from, CGFloat(fighter.definition.radius) + 6)
        context.stroke(ring, with: .color(Theme.yellow.opacity(fade)), lineWidth: 6)
        context.stroke(ring, with: .color(.white.opacity(fade)), lineWidth: 2.5)
    }

    // MARK: Fighters

    private static func drawFighter(_ fighter: FighterState, label: String, at center: CGPoint, lookingAt target: CGPoint,
                                    alpha: Double, phase: BattleSimulation.Phase, state: BattleState,
                                    in context: inout GraphicsContext) {
        let def = fighter.definition
        let color = fighter.slot.color
        let body = state.world.bodies[fighter.bodyIndex]
        // The body's own size (a growing Cell is bigger than its definition).
        let r = CGFloat(body.radius)
        let look = CGVector(dx: target.x - center.x, dy: target.y - center.y)
        var aim = def.requiresAim ? fighter.aim.angle : nil
        if case .swinging = fighter.grabPhase { aim = atan2(look.dy, look.dx) }
        // Held, thrown or frozen by the opponent (a Gambit is kinematic during its own move, which doesn't count).
        let manhandled = (body.isKinematic && fighter.chessPhase == .idle) || body.ignoresSpeedLimit || body.isFrozen
        var drawRadius = r
        if case .moving(let move, let traveled, _, _) = fighter.chessPhase, move.piece == .knight {
            drawRadius = r * (1 + 0.3 * CGFloat(sin(.pi * min(1, traveled / move.length))))
        }

        if body.ignoresSpeedLimit {
            let dir = body.velocity.normalized
            let side = Vec2(-dir.y, dir.x)
            var lines = Path()
            for offset in [-0.6, 0.0, 0.6] {
                let start = Vec2(center.x, center.y) - dir * (body.radius * 1.2) + side * (body.radius * offset)
                lines.move(to: start.cgPoint)
                lines.addLine(to: (start - dir * (body.radius * (offset == 0 ? 1.6 : 1.1))).cgPoint)
            }
            context.stroke(lines, with: .color(Theme.ink.opacity(0.6)), style: StrokeStyle(lineWidth: 4, lineCap: .round))
        }

        if fighter.isDefeated {
            FighterArt.draw(def, in: &context, center: center, radius: r, team: Theme.disabled,
                            spin: fighter.spin, aimAngle: aim, look: look, expression: .knockedOut,
                            coverage: fighter.eclipseCoverage)
            return
        }

        let expression: FighterArt.Expression
        if fighter.flash > 0.2 || manhandled {
            expression = .hurt
        } else if case .finished(.winner(let winner)) = phase, winner == fighter.slot {
            expression = .happy
        } else {
            expression = .normal
        }

        var coverage = fighter.eclipseCoverage
        if case .stalling = fighter.eclipsePhase {
            coverage += 0.035 * sin(state.battleTime * 22)
        }
        let spin = fighter.previousSpin + (fighter.spin - fighter.previousSpin) * alpha
        FighterArt.draw(def, in: &context, center: center, radius: drawRadius, team: color, spin: spin,
                        aimAngle: aim, look: look, expression: expression, flash: fighter.flash, coverage: coverage)
        ArsenalRenderer.drawStatus(fighter, at: center, time: state.battleTime, in: &context)

        // Cooldown ring.
        let ringRadius = CGFloat(def.visualRadius) + 9
        if phase == .fighting {
            context.stroke(FighterArt.circle(center, ringRadius), with: .color(Theme.ink.opacity(0.15)), lineWidth: 5)
            var arc = Path()
            arc.addArc(center: center, radius: ringRadius, startAngle: .degrees(-90),
                       endAngle: .degrees(-90 + 360 * fighter.attackCharge), clockwise: false)
            let ready = fighter.attackCharge >= 1
            context.stroke(arc, with: .color(ready ? Theme.ink : color.mix(with: Theme.ink, by: 0.15)),
                           style: StrokeStyle(lineWidth: 5, lineCap: .round))
            if def.abilities.ultimate != nil { drawUltimateMeter(fighter, at: center, radius: ringRadius + 7, time: state.battleTime, in: &context) }
        }

        switch fighter.chessPhase {
        case .thinking(let move, _, _), .moving(let move, _, _, _):
            let bubbleCenter = CGPoint(x: center.x, y: center.y - ringRadius - 26)
            let bubble = FighterArt.circle(bubbleCenter, 22)
            context.fill(bubble.offsetBy(dx: 0, dy: 3), with: .color(Theme.ink))
            context.fill(bubble, with: .color(.white))
            context.stroke(bubble, with: .color(Theme.ink), lineWidth: 3)
            context.draw(Text(move.piece.glyph).font(.system(size: 30)).foregroundStyle(Theme.ink),
                         at: CGPoint(x: bubbleCenter.x, y: bubbleCenter.y + 1))
        case .idle:
            CartoonText.draw(label, size: 17, fill: color, outline: 2.5,
                             at: CGPoint(x: center.x, y: center.y - ringRadius - 16), maxWidth: 150, in: &context)
        }
    }

    /// Thin gold arc for the Ultimate meter; a pulsing golden aura while it's active.
    private static func drawUltimateMeter(_ fighter: FighterState, at center: CGPoint, radius: CGFloat, time: Double,
                                          in context: inout GraphicsContext) {
        let gold = Rarity.legendary.color
        if fighter.isUltimateActive {
            let pulse = CGFloat(0.5 + 0.5 * sin(time * 14))
            context.fill(FighterArt.circle(center, radius + 4 + 3 * pulse), with: .color(gold.opacity(0.18 + 0.12 * Double(pulse))))
            context.stroke(FighterArt.circle(center, radius + 2 * pulse), with: .color(gold), lineWidth: 4)
            return
        }
        guard fighter.ultimateCharge > 0 else { return }
        var arc = Path()
        arc.addArc(center: center, radius: radius, startAngle: .degrees(-90),
                   endAngle: .degrees(-90 + 360 * fighter.ultimateCharge), clockwise: false)
        context.stroke(arc, with: .color(Theme.ink.opacity(0.6)), style: StrokeStyle(lineWidth: 5, lineCap: .round))
        context.stroke(arc, with: .color(gold), style: StrokeStyle(lineWidth: 3, lineCap: .round))
    }

    /// Blood Moon: a pulsing red tether to the enemy, wherever it is.
    private static func drawBloodMoon(_ fighter: FighterState, positions: [CGPoint], time: Double, in context: inout GraphicsContext) {
        guard fighter.isUltimateActive, case .bloodMoon = fighter.definition.abilities.ultimate else { return }
        var line = Path()
        line.move(to: positions[fighter.slot.rawValue])
        line.addLine(to: positions[fighter.slot.opponent.rawValue])
        context.stroke(line, with: .color(Theme.ink.opacity(0.5)), style: StrokeStyle(lineWidth: 7, lineCap: .round))
        context.stroke(line, with: .color(Color(red: 0.85, green: 0.05, blue: 0.15)),
                       style: StrokeStyle(lineWidth: 3.5, lineCap: .round, dash: [10, 6], dashPhase: -time * 60))
    }

    // MARK: Effects & banners

    private static func drawEffects(_ effects: EffectsState, in context: inout GraphicsContext) {
        for star in effects.stars {
            let t = star.life / star.maxLife
            let pop = t > 0.7 ? (1 - t) / 0.3 : 1.0
            let size = star.size * (0.6 + 0.5 * pop) * (0.6 + 0.4 * t)
            let path = FighterArt.starburst(center: star.position.cgPoint, radius: size, rotation: star.rotation)
            context.drawLayer { layer in
                layer.opacity = min(1, t * 2.5)
                layer.stroke(path, with: .color(Theme.ink), style: StrokeStyle(lineWidth: 6, lineJoin: .round))
                layer.fill(path, with: .color(star.tint.color))
            }
        }
        for p in effects.particles {
            let t = max(0, p.life / p.maxLife)
            let dot = FighterArt.circle(p.position.cgPoint, p.size * (0.4 + 0.6 * t))
            context.fill(dot, with: .color(p.tint.color))
            context.stroke(dot, with: .color(Theme.ink), lineWidth: 1.5)
        }
        for text in effects.texts {
            let t = max(0, text.life / text.maxLife)
            context.drawLayer { layer in
                layer.opacity = min(1, t * 1.8)
                CartoonText.draw(text.text, size: CGFloat(text.size), fill: text.tint.color, outline: 2.5, at: text.position.cgPoint, in: &layer)
            }
        }
    }

    /// Countdown arrow showing which way a ball will launch.
    private static func drawLaunchArrow(_ sim: BattleSimulation, _ slot: PlayerSlot, in context: inout GraphicsContext) {
        let body = sim.state.body(of: slot)
        let angle = sim.launchVelocities[slot.rawValue].angle
        let bob = CGFloat(4 * sin(sim.elapsed * 8))
        let arrow = FighterArt.arrow(from: FighterArt.point(body.position.cgPoint, CGFloat(body.radius) + 10 + bob, angle),
                                     angle: angle, length: 70, headSize: 20)
        context.stroke(arrow.shaft, with: .color(Theme.ink), style: StrokeStyle(lineWidth: 12, lineCap: .round))
        context.stroke(arrow.head, with: .color(Theme.ink), style: StrokeStyle(lineWidth: 8, lineJoin: .round))
        context.stroke(arrow.shaft, with: .color(slot.color), style: StrokeStyle(lineWidth: 6, lineCap: .round))
        context.fill(arrow.head, with: .color(slot.color))
    }

    private static func drawBanner(_ sim: BattleSimulation, in context: inout GraphicsContext) {
        let center = CGPoint(x: GameConfig.arenaWidth / 2, y: GameConfig.arenaHeight / 2)
        switch sim.phase {
        case .countdown where sim.isWaitingForLaunchLock:
            for slot in PlayerSlot.allCases { drawLaunchArrow(sim, slot, in: &context) }
            CartoonText.draw("WAITING FOR RIVAL…", size: 30, fill: .white, outline: 3, at: center, in: &context)
        case .countdown:
            let remaining = sim.countdownRemaining
            let number = max(1, Int(remaining.rounded(.up)))
            let frac = remaining - floor(remaining)
            let bounce = 1 + 0.45 * frac * frac * sin(frac * .pi * 3)
            context.drawLayer { layer in
                layer.translateBy(x: center.x, y: center.y)
                layer.scaleBy(x: bounce, y: bounce)
                CartoonText.draw("\(number)", size: 140, fill: Theme.yellow, outline: 6, at: .zero, in: &layer)
            }
            for slot in PlayerSlot.allCases where sim.steerableSlots.contains(slot) {
                drawLaunchArrow(sim, slot, in: &context)
            }
            CartoonText.draw(sim.steerableSlots.isEmpty ? "GET READY!" : "DRAG TO AIM!", size: 28, fill: .white, outline: 3,
                             at: CGPoint(x: center.x, y: center.y + 110), in: &context)
        case .fighting:
            if sim.battleTime < 0.8 && !sim.isPreview {
                let t = sim.battleTime / 0.8
                let wobble = 1 + 0.25 * sin(t * .pi)
                context.drawLayer { layer in
                    layer.opacity = t < 0.75 ? 1 : (1 - t) / 0.25
                    layer.translateBy(x: center.x, y: center.y)
                    layer.rotate(by: .degrees(-6))
                    layer.scaleBy(x: wobble, y: wobble)
                    let burst = FighterArt.starburst(center: .zero, radius: 170, points: 14)
                    layer.stroke(burst, with: .color(Theme.ink), style: StrokeStyle(lineWidth: 8, lineJoin: .round))
                    layer.fill(burst, with: .color(Theme.yellow))
                    CartoonText.draw("FIGHT!", size: 80, fill: .white, outline: 5, at: .zero, in: &layer)
                }
            }
            if sim.isOvertime {
                let label = String(localized: "OVERTIME ×\(sim.state.damageMultiplier.formatted(.number.precision(.fractionLength(1))))")
                let pill = Path(roundedRect: CGRect(x: center.x - 130, y: 22, width: 260, height: 44), cornerRadius: 22)
                context.fill(pill.offsetBy(dx: 0, dy: 5), with: .color(Theme.ink))
                context.fill(pill, with: .color(Theme.overtime))
                context.stroke(pill, with: .color(Theme.ink), lineWidth: 4)
                CartoonText.draw(label, size: 22, fill: .white, outline: 2.5, at: CGPoint(x: center.x, y: 43), in: &context)
            }
        case .finished(let outcome):
            let label = outcome == .draw ? "DOUBLE K.O.!" : "K.O.!"
            let t = min(1, sim.timeSinceFinish / 0.3)
            let overshoot = 1 + 0.3 * sin(t * .pi)
            context.drawLayer { layer in
                layer.opacity = min(1, t * 3)
                layer.translateBy(x: center.x, y: center.y)
                layer.rotate(by: .degrees(-8))
                layer.scaleBy(x: overshoot, y: overshoot)
                let burst = FighterArt.starburst(center: .zero, radius: outcome == .draw ? 230 : 180, points: 16)
                layer.stroke(burst, with: .color(Theme.ink), style: StrokeStyle(lineWidth: 8, lineJoin: .round))
                layer.fill(burst, with: .color(Theme.overtime))
                CartoonText.draw(label, size: outcome == .draw ? 60 : 92, fill: Theme.yellow, outline: 6,
                                 at: .zero, in: &layer)
            }
        }
    }
}

/// Draws the top status bar: names, health, attack cooldowns and the match clock.
enum BattleHUDRenderer {
    static func draw(_ sim: BattleSimulation, in context: inout GraphicsContext, size: CGSize) {
        let clockWidth: CGFloat = 84
        let panelWidth = (size.width - clockWidth - 16) / 2
        for fighter in sim.state.fighters {
            let leading = fighter.slot == .one
            let x = leading ? 0 : size.width - panelWidth
            drawPanel(fighter, label: sim.labels[fighter.slot.rawValue],
                      rect: CGRect(x: x, y: 0, width: panelWidth, height: size.height), leading: leading, in: &context)
        }
        drawClock(sim, rect: CGRect(x: (size.width - clockWidth) / 2, y: 6, width: clockWidth, height: 62), in: &context)
    }

    private static func drawClock(_ sim: BattleSimulation, rect: CGRect, in context: inout GraphicsContext) {
        let overtime = sim.isOvertime
        let badge = Path(roundedRect: rect, cornerRadius: 16)
        context.fill(badge.offsetBy(dx: 0, dy: 5), with: .color(Theme.ink))
        context.fill(badge, with: .color(overtime ? Theme.overtime : Theme.cream))
        context.stroke(badge, with: .color(Theme.ink), lineWidth: 3)

        let seconds = Int(sim.battleTime)
        context.draw(Text(String(format: "%d:%02d", seconds / 60, seconds % 60))
                        .font(.system(size: 24, weight: .black, design: .rounded).monospacedDigit())
                        .foregroundStyle(Theme.ink),
                     at: CGPoint(x: rect.midX, y: rect.minY + 24))
        context.draw(Text(overtime ? String(localized: "OT ×\(sim.state.damageMultiplier.formatted(.number.precision(.fractionLength(1))))") : String(localized: "TIME"))
                        .font(Theme.bodyFont(11, weight: .black))
                        .foregroundStyle(Theme.ink.opacity(overtime ? 1 : 0.6)),
                     at: CGPoint(x: rect.midX, y: rect.minY + 47))
    }

    private static func drawPanel(_ fighter: FighterState, label: String, rect: CGRect, leading: Bool,
                                  in context: inout GraphicsContext) {
        let color = fighter.slot.color
        let anchor: UnitPoint = leading ? .leading : .trailing
        let edgeX = leading ? rect.minX + 2 : rect.maxX - 2

        CartoonText.draw("\(label) \(fighter.definition.name.uppercased())", size: 16, fill: color,
                         outline: 2.5, at: CGPoint(x: edgeX, y: rect.minY + 12), anchor: anchor,
                         maxWidth: rect.width - 4, in: &context)

        let bar = CGRect(x: rect.minX, y: rect.minY + 26, width: rect.width, height: 20)
        let maxHP = fighter.definition.maxHealth
        let shape = Path(roundedRect: bar, cornerRadius: 9)
        context.fill(shape.offsetBy(dx: 0, dy: 4), with: .color(Theme.ink))
        context.fill(shape, with: .color(Theme.ink.mix(with: .white, by: 0.15)))

        func segment(_ fraction: Double) -> Path {
            let w = bar.width * CGFloat(max(0, min(1, fraction)))
            return Path(CGRect(x: leading ? bar.minX : bar.maxX - w, y: bar.minY, width: w, height: bar.height))
        }
        context.drawLayer { layer in
            layer.clip(to: shape)
            layer.fill(segment(fighter.trailingHealth / maxHP), with: .color(.white))
            layer.fill(segment(fighter.health / maxHP), with: .color(color))
            if fighter.health > maxHP {
                let w = bar.width * CGFloat(min(1, (fighter.health - maxHP) / maxHP))
                layer.fill(Path(CGRect(x: leading ? bar.maxX - w : bar.minX, y: bar.minY, width: w, height: bar.height)),
                           with: .color(Theme.heal))
            }
            layer.fill(Path(CGRect(x: bar.minX, y: bar.minY + 3, width: bar.width, height: 5)),
                       with: .color(.white.opacity(0.3)))
            var ticks = Path()
            for i in 1..<4 {
                let x = bar.minX + bar.width * CGFloat(i) / 4
                ticks.move(to: CGPoint(x: x, y: bar.minY))
                ticks.addLine(to: CGPoint(x: x, y: bar.maxY))
            }
            layer.stroke(ticks, with: .color(Theme.ink.opacity(0.35)), lineWidth: 2)
        }
        context.stroke(shape, with: .color(Theme.ink), lineWidth: 3)
        CartoonText.draw("\(Int(max(0, fighter.health).rounded(.up)))", size: 14, fill: .white, outline: 2,
                         at: CGPoint(x: leading ? bar.minX + 9 : bar.maxX - 9, y: bar.midY - 1), anchor: anchor,
                         in: &context)

        let ready = fighter.attackCharge >= 1
        let cd = CGRect(x: rect.minX, y: bar.maxY + 10, width: rect.width, height: 8)
        let cdShape = Path(roundedRect: cd, cornerRadius: 4)
        context.fill(cdShape, with: .color(Theme.ink.mix(with: .white, by: 0.15)))
        let fillWidth = cd.width * CGFloat(fighter.attackCharge)
        context.drawLayer { layer in
            layer.clip(to: cdShape)
            layer.fill(Path(CGRect(x: leading ? cd.minX : cd.maxX - fillWidth, y: cd.minY, width: fillWidth, height: cd.height)),
                       with: .color(ready ? Theme.yellow : color.mix(with: .white, by: 0.3)))
        }
        context.stroke(cdShape, with: .color(Theme.ink), lineWidth: 2.5)

        let status: String
        if fighter.isDefeated {
            status = String(localized: "K.O.")
        } else {
            switch fighter.definition.attack {
            case .contact:
                status = ready ? String(localized: "ARMED!") : String(format: "%.1fs", fighter.secondsUntilReady)
            case .web(let spec):
                status = String(localized: "\(fighter.activeThreads)/\(spec.maxThreads) WEBS")
            case .grab:
                switch fighter.grabPhase {
                case .swinging: status = String(localized: "SPIN!")
                case .thrown: status = String(localized: "THROW!")
                case .idle: status = ready ? String(localized: "READY!") : String(format: "%.1fs", fighter.secondsUntilReady)
                }
            case .drain:
                status = fighter.drainPhase != .idle ? String(localized: "DRAIN!") : (ready ? String(localized: "READY!") : String(format: "%.1fs", fighter.secondsUntilReady))
            case .chess:
                switch fighter.chessPhase {
                case .thinking(let move, _, _), .moving(let move, _, _, _): status = move.piece.name.localized.uppercased() + "!"
                case .idle: status = String(format: "%.1fs", fighter.secondsUntilReady)
                }
            case .eclipse:
                switch fighter.eclipsePhase {
                case .waxing: status = "\(Int(fighter.eclipseCoverage * 100))%"
                case .stalling: status = String(localized: "ALMOST…")
                case .totality: status = String(localized: "TOTALITY!")
                }
            case .projectile, .pulse:
                status = String(format: "%.1fs", fighter.secondsUntilReady)
            case .arsenal(let attack):
                status = ArsenalRenderer.status(fighter, attack)
            }
        }
        let line = Text("\(Text(fighter.definition.attackName.localized.uppercased()).foregroundStyle(.white.opacity(0.75)))  \(Text(status).foregroundStyle(ready ? Theme.yellow : .white))")
        context.draw(line.font(Theme.bodyFont(11, weight: .black)),
                     at: CGPoint(x: edgeX, y: cd.maxY + 11), anchor: anchor)
    }
}
