import SwiftUI

// MARK: - Arsenal fighter accessories

extension FighterArt {
    /// Parts drawn behind an arsenal fighter's body (sticking out past its outline).
    static func drawArsenalBack(_ attack: ArsenalAttack, in context: inout GraphicsContext, center: CGPoint,
                                r: CGFloat, s: CGFloat, p: Palette, spin: Double) {
        let ink = Theme.ink
        switch attack {
        case .traps:
            // Chain links around the rim.
            for i in 0..<10 {
                let a = spin + Double(i) / 10 * 2 * .pi
                let c = point(center, r * 1.0, a)
                let link = Path(ellipseIn: CGRect(x: -6 * s, y: -3.5 * s, width: 12 * s, height: 7 * s))
                    .applying(CGAffineTransform(rotationAngle: a + .pi / 2).concatenating(CGAffineTransform(translationX: c.x, y: c.y)))
                context.stroke(link, with: .color(p.line), lineWidth: 4.5 * s)
                context.stroke(link, with: .color(Color(white: 0.75)), lineWidth: 2 * s)
            }
        case .laser:
            var antenna = Path()
            antenna.move(to: CGPoint(x: center.x + r * 0.2, y: center.y - r * 0.8))
            antenna.addLine(to: CGPoint(x: center.x + r * 0.35, y: center.y - r - 16 * s))
            context.stroke(antenna, with: .color(p.line), style: StrokeStyle(lineWidth: 4 * s, lineCap: .round))
            let tip = circle(CGPoint(x: center.x + r * 0.35, y: center.y - r - 18 * s), 5 * s)
            context.fill(tip, with: .color(Color(red: 1, green: 0.2, blue: 0.25)))
            context.stroke(tip, with: .color(ink), lineWidth: 2 * s)
        case .shock:
            // Lightning bolts bristling from the rim.
            for i in 0..<5 {
                let a = spin + Double(i) / 5 * 2 * .pi
                var bolt = Path()
                let b0 = point(center, r * 0.9, a)
                let b1 = point(point(center, r + 9 * s, a), 5 * s, a + .pi / 2)
                let b2 = point(point(center, r + 7 * s, a), 5 * s, a - .pi / 2)
                let b3 = point(center, r + 18 * s, a)
                bolt.move(to: b0); bolt.addLine(to: b1); bolt.addLine(to: b2); bolt.addLine(to: b3)
                context.stroke(bolt, with: .color(ink), style: StrokeStyle(lineWidth: 6 * s, lineCap: .round, lineJoin: .round))
                context.stroke(bolt, with: .color(p.accent), style: StrokeStyle(lineWidth: 3 * s, lineCap: .round, lineJoin: .round))
            }
        case .bombs(let spec):
            if spec.icy {
                // Icicles hanging underneath.
                var icicles = Path()
                for x in [-0.45, -0.1, 0.3] {
                    let base = CGPoint(x: center.x + r * x, y: center.y + r * 0.8)
                    icicles.move(to: CGPoint(x: base.x - 6 * s, y: base.y))
                    icicles.addLine(to: CGPoint(x: base.x + 1 * s, y: base.y + (12 + 8 * CGFloat(abs(x))) * s))
                    icicles.addLine(to: CGPoint(x: base.x + 6 * s, y: base.y))
                    icicles.closeSubpath()
                }
                context.fill(icicles, with: .color(Color(red: 0.75, green: 0.92, blue: 1)))
                context.stroke(icicles, with: .color(p.line), style: StrokeStyle(lineWidth: 2 * s, lineJoin: .round))
            } else {
                // Lit fuse with a flickering spark.
                var fuse = Path()
                fuse.move(to: CGPoint(x: center.x + r * 0.3, y: center.y - r * 0.85))
                fuse.addQuadCurve(to: CGPoint(x: center.x + r * 0.6, y: center.y - r - 14 * s),
                                  control: CGPoint(x: center.x + r * 0.15, y: center.y - r - 10 * s))
                context.stroke(fuse, with: .color(ink), style: StrokeStyle(lineWidth: 5 * s, lineCap: .round))
                context.stroke(fuse, with: .color(Color(red: 0.75, green: 0.6, blue: 0.4)), style: StrokeStyle(lineWidth: 2.5 * s, lineCap: .round))
                let spark = burst(center: CGPoint(x: center.x + r * 0.6, y: center.y - r - 14 * s), radius: (6 + 2 * CGFloat(sin(spin * 9))) * s,
                                  points: 7, rotation: spin * 3)
                context.fill(spark, with: .color(p.accent))
                context.stroke(spark, with: .color(ink), lineWidth: 1.5 * s)
            }
        case .turrets:
            let barrel = Path(roundedRect: CGRect(x: 0, y: -7 * s, width: r * 0.7 + 12 * s, height: 14 * s), cornerRadius: 3 * s)
                .applying(CGAffineTransform(rotationAngle: -.pi / 4).concatenating(CGAffineTransform(translationX: center.x + r * 0.4, y: center.y - r * 0.4)))
            context.fill(barrel, with: .color(Color(white: 0.3)))
            context.stroke(barrel, with: .color(ink), lineWidth: 2.6 * s)
        case .virus:
            for i in 0..<9 {
                let a = spin + Double(i) / 9 * 2 * .pi
                var stalk = Path()
                stalk.move(to: point(center, r * 0.9, a))
                stalk.addLine(to: point(center, r + 9 * s, a))
                context.stroke(stalk, with: .color(p.line), style: StrokeStyle(lineWidth: 3 * s, lineCap: .round))
                let knob = circle(point(center, r + 10 * s, a), 4 * s)
                context.fill(knob, with: .color(Theme.heal))
                context.stroke(knob, with: .color(p.line), lineWidth: 1.6 * s)
            }
        case .harpoon:
            var shaft = Path()
            let from = CGPoint(x: center.x - r * 0.9, y: center.y + r * 0.9)
            let to = CGPoint(x: center.x + r * 1.15, y: center.y - r * 1.15)
            shaft.move(to: from); shaft.addLine(to: to)
            context.stroke(shaft, with: .color(ink), style: StrokeStyle(lineWidth: 6 * s, lineCap: .round))
            context.stroke(shaft, with: .color(Color(red: 0.62, green: 0.45, blue: 0.3)), style: StrokeStyle(lineWidth: 3 * s, lineCap: .round))
            let head = arrow(from: to, angle: -.pi / 4, length: 14 * s, headSize: 14 * s).head
            context.fill(head, with: .color(Color(white: 0.85)))
            context.stroke(head, with: .color(ink), style: StrokeStyle(lineWidth: 2 * s, lineJoin: .round))
        case .knives:
            // Bandana knot tails behind the head.
            var tails = Path()
            tails.move(to: CGPoint(x: center.x + r * 0.85, y: center.y - r * 0.12))
            tails.addLine(to: CGPoint(x: center.x + r * 1.3, y: center.y - r * 0.3))
            tails.move(to: CGPoint(x: center.x + r * 0.85, y: center.y - r * 0.05))
            tails.addLine(to: CGPoint(x: center.x + r * 1.25, y: center.y + r * 0.12))
            context.stroke(tails, with: .color(ink), style: StrokeStyle(lineWidth: 7 * s, lineCap: .round))
            context.stroke(tails, with: .color(Color(white: 0.18)), style: StrokeStyle(lineWidth: 4 * s, lineCap: .round))
        case .train, .zone, .dice, .shards, .tail, .swarm:
            break
        }
    }

    /// Markings on an arsenal fighter's body (under the face).
    static func drawArsenalSurface(_ attack: ArsenalAttack, in context: inout GraphicsContext, center: CGPoint,
                                   r: CGFloat, s: CGFloat, p: Palette, spin: Double, body: Path) {
        let ink = Theme.ink
        switch attack {
        case .train:
            // Conductor's cap.
            var cap = Path()
            cap.move(to: CGPoint(x: center.x - r * 0.75, y: center.y - r * 0.5))
            cap.addQuadCurve(to: CGPoint(x: center.x + r * 0.75, y: center.y - r * 0.5),
                             control: CGPoint(x: center.x, y: center.y - r * 1.45))
            cap.closeSubpath()
            context.fill(cap, with: .color(Color(red: 0.16, green: 0.18, blue: 0.32)))
            context.stroke(cap, with: .color(ink), lineWidth: 2.6 * s)
            var brim = Path()
            brim.move(to: CGPoint(x: center.x - r * 0.85, y: center.y - r * 0.47))
            brim.addLine(to: CGPoint(x: center.x + r * 0.85, y: center.y - r * 0.47))
            context.stroke(brim, with: .color(ink), style: StrokeStyle(lineWidth: 6 * s, lineCap: .round))
            context.stroke(brim, with: .color(Color(red: 0.16, green: 0.18, blue: 0.32)), style: StrokeStyle(lineWidth: 3 * s, lineCap: .round))
            let badge = circle(CGPoint(x: center.x, y: center.y - r * 0.78), 5 * s)
            context.fill(badge, with: .color(p.accent))
            context.stroke(badge, with: .color(ink), lineWidth: 1.5 * s)
        case .zone:
            var dashes = Path()
            for i in stride(from: 0, to: 16, by: 2) {
                let a0 = Angle(radians: spin + Double(i) * .pi / 8)
                let a1 = Angle(radians: spin + Double(i + 1) * .pi / 8)
                dashes.addArc(center: center, radius: r * 0.82, startAngle: a0, endAngle: a1, clockwise: false)
            }
            context.stroke(dashes, with: .color(Color(red: 1, green: 0.25, blue: 0.25)), lineWidth: 5 * s)
        case .dice:
            for i in 0..<6 {
                let c = point(center, r * 0.78, spin + Double(i) * .pi / 3)
                context.fill(circle(c, 3.6 * s), with: .color(.white))
                context.stroke(circle(c, 3.6 * s), with: .color(p.line), lineWidth: 1.5 * s)
            }
        case .shards:
            // Glassy facets and cracks.
            context.drawLayer { layer in
                layer.clip(to: body)
                var facets = Path()
                facets.move(to: CGPoint(x: center.x - r, y: center.y + r * 0.2))
                facets.addLine(to: CGPoint(x: center.x + r * 0.2, y: center.y - r))
                facets.addLine(to: CGPoint(x: center.x + r, y: center.y - r * 0.1))
                facets.closeSubpath()
                layer.fill(facets, with: .color(.white.opacity(0.18)))
                var cracks = Path()
                let o = point(center, r * 0.55, spin + 2.2)
                cracks.move(to: o); cracks.addLine(to: point(o, r * 0.35, spin + 1.4))
                cracks.move(to: o); cracks.addLine(to: point(o, r * 0.3, spin + 3.3))
                cracks.move(to: o); cracks.addLine(to: point(o, r * 0.25, spin + 4.6))
                layer.stroke(cracks, with: .color(.white.opacity(0.8)), style: StrokeStyle(lineWidth: 1.6 * s, lineCap: .round))
            }
        case .knives:
            // Bandit mask across the eyes.
            context.drawLayer { layer in
                layer.clip(to: body)
                let mask = Path(roundedRect: CGRect(x: center.x - r, y: center.y - r * 0.3, width: r * 2, height: r * 0.48),
                                cornerRadius: r * 0.2)
                layer.fill(mask, with: .color(Color(white: 0.16)))
                layer.stroke(mask, with: .color(ink), lineWidth: 2 * s)
            }
        case .tail:
            // Scales.
            context.drawLayer { layer in
                layer.clip(to: body)
                var scales = Path()
                for row in 0..<4 {
                    for col in 0..<6 {
                        let x = center.x - r + CGFloat(col) * r * 0.4 + (row.isMultiple(of: 2) ? 0 : r * 0.2)
                        let y = center.y + r * 0.35 + CGFloat(row) * r * 0.2
                        scales.addArc(center: CGPoint(x: x, y: y), radius: r * 0.2, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
                    }
                }
                layer.stroke(scales, with: .color(p.line.opacity(0.35)), lineWidth: 1.5 * s)
            }
            // Forked tongue.
            var tongue = Path()
            let base = CGPoint(x: center.x, y: center.y + r * 0.36)
            tongue.move(to: base)
            tongue.addLine(to: CGPoint(x: base.x, y: base.y + r * 0.22))
            tongue.move(to: CGPoint(x: base.x, y: base.y + r * 0.2))
            tongue.addLine(to: CGPoint(x: base.x - r * 0.07, y: base.y + r * 0.3))
            tongue.move(to: CGPoint(x: base.x, y: base.y + r * 0.2))
            tongue.addLine(to: CGPoint(x: base.x + r * 0.07, y: base.y + r * 0.3))
            context.stroke(tongue, with: .color(Theme.blood), style: StrokeStyle(lineWidth: 2.4 * s, lineCap: .round))
        case .bombs(let spec) where spec.icy:
            context.drawLayer { layer in
                layer.clip(to: body)
                var frost = Path()
                frost.move(to: CGPoint(x: center.x - r, y: center.y - r * 0.55))
                for i in 0...8 {
                    let x = center.x - r + CGFloat(i) * r * 0.25
                    frost.addLine(to: CGPoint(x: x, y: center.y - r * (i.isMultiple(of: 2) ? 0.5 : 0.62)))
                }
                frost.addLine(to: CGPoint(x: center.x + r, y: center.y - r))
                frost.addLine(to: CGPoint(x: center.x - r, y: center.y - r))
                frost.closeSubpath()
                layer.fill(frost, with: .color(Color(red: 0.88, green: 0.97, blue: 1)))
                layer.stroke(frost, with: .color(p.line.opacity(0.5)), lineWidth: 1.5 * s)
            }
        case .swarm:
            context.drawLayer { layer in
                layer.clip(to: body)
                var cells = Path()
                let size = r * 0.24
                for row in -3...3 {
                    for col in -3...3 {
                        let cx = center.x + CGFloat(col) * size * 1.75 + (row.isMultiple(of: 2) ? 0 : size * 0.87)
                        let cy = center.y + CGFloat(row) * size * 1.5
                        for k in 0...6 {
                            let q = point(CGPoint(x: cx, y: cy), size, Double(k) * .pi / 3 + .pi / 6)
                            if k == 0 { cells.move(to: q) } else { cells.addLine(to: q) }
                        }
                    }
                }
                layer.stroke(cells, with: .color(p.accent.opacity(0.5)), lineWidth: 1.6 * s)
            }
        default:
            break
        }
    }
}

// MARK: - Hazards, tails, projectiles and status effects in the arena

enum ArsenalRenderer {
    static func drawHazard(_ h: Hazard, in context: inout GraphicsContext, time: Double, state: BattleState) {
        let ink = Theme.ink
        let team = h.owner.color
        let c = h.position.cgPoint
        let fadeOut = min(1, max(0, (h.lifetime - h.age) / 0.6))
        switch h.kind {
        case .trap(let armIn):
            context.drawLayer { layer in
                layer.opacity = fadeOut
                let ring = FighterArt.circle(c, h.radius)
                layer.fill(ring, with: .color(Color(white: armIn > 0 ? 0.55 : 0.7)))
                layer.stroke(ring, with: .color(ink), lineWidth: 3)
                // Jaw teeth.
                var teeth = Path()
                for i in 0..<10 {
                    let a = Double(i) / 10 * 2 * .pi
                    teeth.move(to: FighterArt.point(c, h.radius * 0.55, a - 0.25))
                    teeth.addLine(to: FighterArt.point(c, h.radius * 0.95, a))
                    teeth.addLine(to: FighterArt.point(c, h.radius * 0.55, a + 0.25))
                }
                layer.stroke(teeth, with: .color(ink), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
                layer.fill(FighterArt.circle(c, h.radius * 0.35), with: .color(team))
                layer.stroke(FighterArt.circle(c, h.radius * 0.35), with: .color(ink), lineWidth: 2)
            }
        case .zone:
            let pulse = 0.85 + 0.15 * sin(time * 6 + h.rotation)
            let ring = FighterArt.circle(c, h.radius * pulse)
            context.drawLayer { layer in
                layer.opacity = fadeOut
                layer.fill(ring, with: .color(Color(red: 1, green: 0.2, blue: 0.25).opacity(0.18)))
                layer.clip(to: ring)
                var stripes = Path()
                var x = c.x - h.radius * 2
                while x < c.x + h.radius * 2 {
                    stripes.move(to: CGPoint(x: x, y: c.y + h.radius))
                    stripes.addLine(to: CGPoint(x: x + h.radius, y: c.y - h.radius))
                    x += 16
                }
                layer.stroke(stripes, with: .color(Color(red: 1, green: 0.2, blue: 0.25).opacity(0.18)), lineWidth: 6)
            }
            context.stroke(ring, with: .color(Color(red: 0.85, green: 0.1, blue: 0.15).opacity(fadeOut)),
                           style: StrokeStyle(lineWidth: 3, dash: [10, 7], dashPhase: time * 20))
        case .die(let value):
            let size = h.radius * 2
            let rect = CGRect(x: -h.radius, y: -h.radius, width: size, height: size)
            let transform = CGAffineTransform(rotationAngle: h.rotation).concatenating(CGAffineTransform(translationX: c.x, y: c.y))
            let die = Path(roundedRect: rect, cornerRadius: 6).applying(transform)
            context.drawLayer { layer in
                layer.opacity = fadeOut * (h.hitCooldown > 0 ? 0.6 : 1)
                layer.fill(die.offsetBy(dx: 0, dy: 3), with: .color(ink))
                layer.fill(die, with: .color(.white))
                layer.stroke(die, with: .color(ink), lineWidth: 3)
                for pip in pips(value) {
                    let pt = CGPoint(x: pip.x * h.radius * 0.55, y: pip.y * h.radius * 0.55).applying(transform)
                    layer.fill(FighterArt.circle(pt, h.radius * 0.17), with: .color(value == 1 ? Theme.blood : ink))
                }
            }
        case .laser(let end):
            var beam = Path()
            beam.move(to: c)
            beam.addLine(to: end.cgPoint)
            let flicker = 0.8 + 0.2 * sin(time * 40 + h.rotation)
            context.drawLayer { layer in
                layer.opacity = fadeOut
                layer.stroke(beam, with: .color(ink), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                layer.stroke(beam, with: .color(Color(red: 1, green: 0.15, blue: 0.2).opacity(flicker)), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                layer.stroke(beam, with: .color(.white.opacity(0.85)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                for point in [c, end.cgPoint] {
                    let emitter = FighterArt.circle(point, 7)
                    layer.fill(emitter, with: .color(team))
                    layer.stroke(emitter, with: .color(ink), lineWidth: 2.5)
                }
            }
        case .bomb(let fuse):
            let blink = fuse < 0.5 ? (sin(time * 40) > 0) : (sin(time * 14) > 0)
            let icy: Bool = { if case .arsenal(.bombs(let spec)) = state.fighter(h.owner).definition.attack { return spec.icy }; return false }()
            let body = FighterArt.circle(c, 13)
            if icy {
                // Telegraph: faint ring of where the spikes will fly.
                context.stroke(FighterArt.circle(c, 34), with: .color(Color(red: 0.55, green: 0.85, blue: 1).opacity(0.5)),
                               style: StrokeStyle(lineWidth: 2, dash: [3, 5]))
            } else {
                context.stroke(FighterArt.circle(c, h.radius), with: .color(Color(red: 0.85, green: 0.1, blue: 0.15).opacity(0.35)),
                               style: StrokeStyle(lineWidth: 2.5, dash: [8, 8]))
            }
            context.fill(body.offsetBy(dx: 0, dy: 3), with: .color(ink))
            context.fill(body, with: .color(icy ? Color(red: 0.7, green: 0.9, blue: 1) : Color(white: blink ? 0.45 : 0.2)))
            context.stroke(body, with: .color(ink), lineWidth: 3)
            context.fill(FighterArt.circle(CGPoint(x: c.x - 4, y: c.y - 4), 3), with: .color(.white.opacity(0.8)))
            var fuseLine = Path()
            fuseLine.move(to: CGPoint(x: c.x + 6, y: c.y - 10))
            fuseLine.addLine(to: CGPoint(x: c.x + 11, y: c.y - 18))
            context.stroke(fuseLine, with: .color(ink), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            if blink {
                context.fill(FighterArt.burst(center: CGPoint(x: c.x + 11, y: c.y - 19), radius: 6, points: 6), with: .color(Theme.yellow))
            }
        case .turret(let fireTimer):
            let enemy = state.body(of: h.owner.opponent).position
            let angle = (enemy - h.position).angle
            let barrel = Path(roundedRect: CGRect(x: 0, y: -5, width: 22, height: 10), cornerRadius: 3)
                .applying(CGAffineTransform(rotationAngle: angle).concatenating(CGAffineTransform(translationX: c.x, y: c.y)))
            context.drawLayer { layer in
                layer.opacity = fadeOut
                layer.fill(barrel, with: .color(Color(white: 0.3)))
                layer.stroke(barrel, with: .color(ink), lineWidth: 2.5)
                let base = FighterArt.circle(c, h.radius)
                layer.fill(base, with: .color(team))
                layer.stroke(base, with: .color(ink), lineWidth: 3)
                // Charge light.
                layer.fill(FighterArt.circle(c, 4), with: .color(fireTimer < 0.3 ? Theme.yellow : ink.opacity(0.5)))
            }
        case .track(let end, let warning, let progress, _):
            let along = (end - h.position).normalized
            let side = Vec2(-along.y, along.x)
            var rails = Path()
            for offset in [-12.0, 12.0] {
                rails.move(to: (h.position + side * offset).cgPoint)
                rails.addLine(to: (end + side * offset).cgPoint)
            }
            var ties = Path()
            let length = (end - h.position).length
            var d = 8.0
            while d < length {
                let p = h.position + along * d
                ties.move(to: (p + side * 18).cgPoint)
                ties.addLine(to: (p - side * 18).cgPoint)
                d += 18
            }
            context.stroke(ties, with: .color(Color(red: 0.45, green: 0.3, blue: 0.2).opacity(0.7)), lineWidth: 5)
            let urgent = warning > 0 && sin(time * 20) > 0
            context.stroke(rails, with: .color(urgent ? Color(red: 0.95, green: 0.2, blue: 0.2) : Color(white: 0.45)), lineWidth: 3)
            if warning <= 0 {
                let trainPos = h.position + (end - h.position) * min(1, progress)
                let body = Path(roundedRect: CGRect(x: -34, y: -h.radius * 0.8, width: 68, height: h.radius * 1.6), cornerRadius: 10)
                    .applying(CGAffineTransform(rotationAngle: along.angle).concatenating(CGAffineTransform(translationX: trainPos.x, y: trainPos.y)))
                context.fill(body.offsetBy(dx: 0, dy: 4), with: .color(ink))
                context.fill(body, with: .color(team))
                context.stroke(body, with: .color(ink), lineWidth: 3.5)
                let front = trainPos + along * 26
                context.fill(FighterArt.circle(front.cgPoint, 7), with: .color(Theme.yellow))
                context.stroke(FighterArt.circle(front.cgPoint, 7), with: .color(ink), lineWidth: 2.5)
                // Smoke puffs behind.
                for k in 1...3 {
                    let puff = trainPos - along * Double(30 + k * 14) + side * Double(sin(time * 10 + Double(k)) * 5)
                    context.fill(FighterArt.circle(puff.cgPoint, CGFloat(9 - k)), with: .color(.white.opacity(0.6)))
                }
            }
        }
    }

    private static func pips(_ value: Int) -> [CGPoint] {
        switch value {
        case 1: return [.zero]
        case 2: return [CGPoint(x: -1, y: -1), CGPoint(x: 1, y: 1)]
        case 3: return [CGPoint(x: -1, y: -1), .zero, CGPoint(x: 1, y: 1)]
        case 4: return [CGPoint(x: -1, y: -1), CGPoint(x: 1, y: -1), CGPoint(x: -1, y: 1), CGPoint(x: 1, y: 1)]
        case 5: return [CGPoint(x: -1, y: -1), CGPoint(x: 1, y: -1), .zero, CGPoint(x: -1, y: 1), CGPoint(x: 1, y: 1)]
        default: return [CGPoint(x: -1, y: -1), CGPoint(x: 1, y: -1), CGPoint(x: -1, y: 0), CGPoint(x: 1, y: 0),
                         CGPoint(x: -1, y: 1), CGPoint(x: 1, y: 1)]
        }
    }

    static func drawTail(_ points: [Vec2], segmentRadius: CGFloat, color: Color, in context: inout GraphicsContext) {
        let segments = Array(points.dropLast(1))
        guard !segments.isEmpty else { return }
        let line = color.mix(with: Theme.ink, by: 0.75)
        for (i, p) in segments.enumerated() {
            let t = CGFloat(i + 1) / CGFloat(segments.count)
            let radius = segmentRadius * (0.55 + 0.45 * t)
            let seg = FighterArt.circle(p.cgPoint, radius)
            context.fill(seg, with: .color(color.mix(with: Theme.shadowHue, by: i.isMultiple(of: 2) ? 0.2 : 0.35)))
            context.stroke(seg, with: .color(line), lineWidth: 2.5)
        }
    }

    static func drawProjectile(_ p: Projectile, at pos: Vec2, in context: inout GraphicsContext, state: BattleState) {
        let ink = Theme.ink
        let dir = p.velocity.normalized
        let angle = dir.angle
        let c = pos.cgPoint
        func place(_ path: Path) -> Path {
            path.applying(CGAffineTransform(rotationAngle: angle).concatenating(CGAffineTransform(translationX: c.x, y: c.y)))
        }
        switch p.kind {
        case .bolt:
            break
        case .knife:
            var blade = Path()
            blade.move(to: CGPoint(x: 12, y: 0)); blade.addLine(to: CGPoint(x: -2, y: -4)); blade.addLine(to: CGPoint(x: -2, y: 4))
            blade.closeSubpath()
            let handle = Path(roundedRect: CGRect(x: -11, y: -2.5, width: 9, height: 5), cornerRadius: 2)
            context.fill(place(blade), with: .color(Color(white: 0.9)))
            context.stroke(place(blade), with: .color(ink), lineWidth: 2)
            context.fill(place(handle), with: .color(Color(red: 0.4, green: 0.25, blue: 0.15)))
            context.stroke(place(handle), with: .color(ink), lineWidth: 1.5)
        case .shard, .iceSpike:
            var shard = Path()
            shard.move(to: CGPoint(x: 9, y: 0)); shard.addLine(to: CGPoint(x: -5, y: -4)); shard.addLine(to: CGPoint(x: -3, y: 4))
            shard.closeSubpath()
            context.fill(place(shard), with: .color(p.kind == .iceSpike ? Color(red: 0.75, green: 0.93, blue: 1) : Color(red: 0.85, green: 0.97, blue: 1)))
            context.stroke(place(shard), with: .color(ink), style: StrokeStyle(lineWidth: 1.8, lineJoin: .round))
        case .bee:
            let wing = sin(p.age * 60) * 2
            for side in [-1.0, 1.0] {
                let w = Path(ellipseIn: CGRect(x: -4, y: -1, width: 6, height: 5 + wing))
                    .applying(CGAffineTransform(translationX: 0, y: CGFloat(side) * 4))
                context.fill(place(w), with: .color(.white.opacity(0.85)))
                context.stroke(place(w), with: .color(ink), lineWidth: 1)
            }
            let body = Path(ellipseIn: CGRect(x: -6, y: -4, width: 12, height: 8))
            context.fill(place(body), with: .color(Theme.yellow))
            var stripes = Path()
            stripes.move(to: CGPoint(x: -1, y: -4)); stripes.addLine(to: CGPoint(x: -1, y: 4))
            stripes.move(to: CGPoint(x: 2.5, y: -3.5)); stripes.addLine(to: CGPoint(x: 2.5, y: 3.5))
            context.stroke(place(stripes), with: .color(ink), lineWidth: 1.8)
            context.stroke(place(body), with: .color(ink), lineWidth: 1.6)
        case .harpoon:
            let owner = state.body(of: p.owner).position
            var rope = Path()
            rope.move(to: owner.cgPoint)
            rope.addLine(to: c)
            context.stroke(rope, with: .color(Color(red: 0.62, green: 0.45, blue: 0.3)), style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
            var shaft = Path()
            shaft.move(to: CGPoint(x: -16, y: 0)); shaft.addLine(to: CGPoint(x: 4, y: 0))
            context.stroke(place(shaft), with: .color(ink), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            let head = FighterArt.arrow(from: .zero, angle: 0, length: 14, headSize: 12).head
            context.fill(place(head), with: .color(Color(white: 0.85)))
            context.stroke(place(head), with: .color(ink), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
        case .cannonball:
            let ball = FighterArt.circle(c, p.radius)
            context.fill(ball, with: .color(Color(white: 0.22)))
            context.stroke(ball, with: .color(ink), lineWidth: 2.5)
            context.fill(FighterArt.circle(CGPoint(x: c.x - 2, y: c.y - 2), 2), with: .color(.white.opacity(0.7)))
        }
    }

    /// Visual status on top of a fighter: held (shock sparks or shackle chains) and poison.
    static func drawStatus(_ fighter: FighterState, at center: CGPoint, time: Double, in context: inout GraphicsContext) {
        let r = CGFloat(fighter.definition.radius)
        let ink = Theme.ink
        if fighter.isHeld {
            switch fighter.holdStyle {
            case .shock:
                var sparks = Path()
                for i in 0..<6 {
                    let a = Double(i) / 6 * 2 * .pi + time * 7
                    let p0 = FighterArt.point(center, r * 0.95, a)
                    let p1 = FighterArt.point(FighterArt.point(center, r + 8, a), 5, a + 1.2)
                    let p2 = FighterArt.point(center, r + 16, a)
                    sparks.move(to: p0); sparks.addLine(to: p1); sparks.addLine(to: p2)
                }
                context.stroke(sparks, with: .color(ink), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                context.stroke(sparks, with: .color(Theme.yellow), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                context.fill(FighterArt.circle(center, r), with: .color(Color(red: 0.6, green: 0.85, blue: 1).opacity(0.25)))
            case .shackle:
                for k in [-1.0, 1.0] {
                    var chain = Path()
                    chain.move(to: CGPoint(x: center.x - r * 1.05, y: center.y + CGFloat(k) * r * 0.35))
                    chain.addLine(to: CGPoint(x: center.x + r * 1.05, y: center.y - CGFloat(k) * r * 0.35))
                    context.stroke(chain, with: .color(ink), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    context.stroke(chain, with: .color(Color(white: 0.7)), style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [6, 3]))
                }
            }
        }
        if fighter.isPoisoned {
            for k in 0..<3 {
                let t = (time * 0.9 + Double(k) / 3).truncatingRemainder(dividingBy: 1)
                let p = CGPoint(x: center.x + CGFloat(sin(time * 3 + Double(k) * 2)) * r * 0.5,
                                y: center.y - r * 0.6 - CGFloat(t) * r * 0.9)
                let bubble = FighterArt.circle(p, CGFloat(3 + 3 * (1 - t)))
                context.fill(bubble, with: .color(Theme.heal.opacity(1 - t)))
                context.stroke(bubble, with: .color(ink.opacity(1 - t)), lineWidth: 1.5)
            }
        }
    }

    /// HUD status text for arsenal attacks.
    static func status(_ fighter: FighterState, _ attack: ArsenalAttack) -> String {
        let ready = fighter.attackCharge >= 1
        func seconds() -> String { String(format: "%.1fs", fighter.secondsUntilReady) }
        switch attack {
        case .traps, .zone, .dice, .laser, .turrets:
            return fighter.activeHazards > 0 ? "\(fighter.activeHazards) ACTIVE" : (ready ? "READY!" : seconds())
        case .train:
            return fighter.activeHazards > 0 ? "ALL ABOARD!" : (ready ? "NEXT WALL!" : seconds())
        case .tail(let spec):
            return "\(fighter.tailSegments)/\(spec.maxSegments) TAIL"
        case .shock, .virus:
            return ready ? "ARMED!" : seconds()
        case .harpoon:
            return fighter.dragRemaining > 0 ? "REELING!" : seconds()
        case .shards:
            return ready ? "ARMED!" : seconds()
        case .knives, .bombs, .swarm:
            return seconds()
        }
    }
}
