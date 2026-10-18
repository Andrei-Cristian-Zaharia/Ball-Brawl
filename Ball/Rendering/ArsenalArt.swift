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
        case .moss:
            // Leaves sprouting from the top.
            for (a, size) in [(-2.1, 1.0), (-1.55, 1.25), (-1.0, 0.95)] {
                let base = point(center, r * 0.92, a)
                let leaf = Path(ellipseIn: CGRect(x: 0, y: -5 * s * size, width: 20 * s * size, height: 10 * s * size))
                    .applying(CGAffineTransform(rotationAngle: a).concatenating(CGAffineTransform(translationX: base.x, y: base.y)))
                context.fill(leaf, with: .color(Color(red: 0.36, green: 0.72, blue: 0.3)))
                context.stroke(leaf, with: .color(ink), lineWidth: 2.2 * s)
            }
        case .magma:
            // Little flames licking off the top.
            for (k, a) in [-2.0, -1.57, -1.14].enumerated() {
                let flicker = 1 + 0.15 * CGFloat(sin(spin * 12 + Double(k) * 1.7))
                let base = point(center, r * 0.85, a)
                let tip = point(center, r + 15 * s * flicker, a)
                var flame = Path()
                flame.move(to: point(base, 7 * s, a - .pi / 2))
                flame.addQuadCurve(to: tip, control: point(point(base, 9 * s, a), 9 * s, a - .pi / 2))
                flame.addQuadCurve(to: point(base, 7 * s, a + .pi / 2), control: point(point(base, 9 * s, a), 9 * s, a + .pi / 2))
                flame.closeSubpath()
                context.fill(flame, with: .color(Color(red: 1, green: 0.5, blue: 0.1)))
                context.stroke(flame, with: .color(ink), style: StrokeStyle(lineWidth: 2 * s, lineJoin: .round))
            }
        case .wolf:
            // Pointy ears.
            for side in [-1.0, 1.0] {
                var ear = Path()
                let a = -.pi / 2 + side * 0.62
                ear.move(to: point(center, r * 0.86, a - side * 0.35))
                ear.addLine(to: point(center, r + 17 * s, a + side * 0.1))
                ear.addLine(to: point(center, r * 0.86, a + side * 0.4))
                ear.closeSubpath()
                context.fill(ear, with: .color(p.shade))
                context.stroke(ear, with: .color(ink), style: StrokeStyle(lineWidth: 2.6 * s, lineJoin: .round))
                var inner = Path()
                inner.move(to: point(center, r * 0.95, a - side * 0.2))
                inner.addLine(to: point(center, r + 9 * s, a + side * 0.08))
                inner.addLine(to: point(center, r * 0.95, a + side * 0.28))
                inner.closeSubpath()
                context.fill(inner, with: .color(Color(red: 1, green: 0.72, blue: 0.75)))
            }
        case .clockwork:
            // Gear teeth around the rim, turning with the ball.
            for k in 0..<12 {
                let a = spin + Double(k) / 12 * 2 * .pi
                let tooth = Path(roundedRect: CGRect(x: -4.5 * s, y: -5 * s, width: 9 * s, height: 10 * s), cornerRadius: 2 * s)
                    .applying(CGAffineTransform(rotationAngle: a + .pi / 2)
                        .concatenating(CGAffineTransform(translationX: point(center, r + 2 * s, a).x, y: point(center, r + 2 * s, a).y)))
                context.fill(tooth, with: .color(Color(red: 0.78, green: 0.62, blue: 0.3)))
                context.stroke(tooth, with: .color(ink), lineWidth: 2 * s)
            }
        case .portal:
            // A halo of orange and blue swirling behind it.
            for (k, color) in [Color(red: 1, green: 0.55, blue: 0.1), Color(red: 0.2, green: 0.6, blue: 1)].enumerated() {
                var arc = Path()
                let start = spin * 2 + Double(k) * .pi
                arc.addArc(center: center, radius: r + 7 * s, startAngle: .radians(start), endAngle: .radians(start + 2.4), clockwise: false)
                context.stroke(arc, with: .color(ink), style: StrokeStyle(lineWidth: 8 * s, lineCap: .round))
                context.stroke(arc, with: .color(color), style: StrokeStyle(lineWidth: 4.5 * s, lineCap: .round))
            }
        case .cell:
            // Wobbly see-through membrane around the cell.
            var membrane = Path()
            for k in 0...36 {
                let a = Double(k) / 36 * 2 * .pi
                let wobble = 1 + 0.05 * sin(a * 5 + spin * 4)
                let q = point(center, (r + 5 * s) * CGFloat(wobble), a)
                if k == 0 { membrane.move(to: q) } else { membrane.addLine(to: q) }
            }
            context.fill(membrane, with: .color(Theme.heal.opacity(0.22)))
            context.stroke(membrane, with: .color(Theme.heal.opacity(0.7)), lineWidth: 2 * s)
        case .train, .zone, .dice, .shards, .tail, .swarm, .fibonacci, .wizard, .glitch, .twin:
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
        case .moss:
            context.drawLayer { layer in
                layer.clip(to: body)
                for (dx, dy, size) in [(-0.45, -0.6, 0.42), (0.1, -0.78, 0.45), (0.6, -0.45, 0.36), (-0.7, 0.35, 0.3), (0.55, 0.55, 0.28)] {
                    let blob = circle(CGPoint(x: center.x + r * dx, y: center.y + r * dy), r * size)
                    layer.fill(blob, with: .color(Color(red: 0.3, green: 0.62, blue: 0.24).opacity(0.85)))
                }
                for (dx, dy) in [(-0.3, -0.55), (0.35, -0.62), (0.62, 0.48)] {
                    layer.fill(circle(CGPoint(x: center.x + r * dx, y: center.y + r * dy), r * 0.07),
                               with: .color(Color(red: 0.2, green: 0.45, blue: 0.16)))
                }
            }
        case .magma:
            context.drawLayer { layer in
                layer.clip(to: body)
                layer.fill(body, with: .color(Color(red: 0.2, green: 0.12, blue: 0.12).opacity(0.45)))
                var cracks = Path()
                cracks.move(to: point(center, r, spin + 0.4)); cracks.addLine(to: point(center, r * 0.35, spin + 0.9))
                cracks.addLine(to: point(center, r * 0.55, spin + 2.0)); cracks.addLine(to: point(center, r, spin + 2.4))
                cracks.move(to: point(center, r * 0.35, spin + 0.9)); cracks.addLine(to: point(center, r * 0.6, spin + 4.2))
                cracks.addLine(to: point(center, r, spin + 4.6))
                let glow = 0.75 + 0.25 * sin(spin * 6)
                layer.stroke(cracks, with: .color(Color(red: 1, green: 0.45, blue: 0.08).opacity(glow)),
                             style: StrokeStyle(lineWidth: 4.5 * s, lineCap: .round, lineJoin: .round))
                layer.stroke(cracks, with: .color(Theme.yellow.opacity(glow)), style: StrokeStyle(lineWidth: 1.6 * s, lineCap: .round, lineJoin: .round))
            }
        case .wolf:
            context.drawLayer { layer in
                layer.clip(to: body)
                let muzzle = Path(ellipseIn: CGRect(x: center.x - r * 0.48, y: center.y + r * 0.12, width: r * 0.96, height: r * 0.62))
                layer.fill(muzzle, with: .color(.white.opacity(0.55)))
            }
            context.fill(circle(CGPoint(x: center.x, y: center.y + r * 0.2), r * 0.11), with: .color(ink))
        case .fibonacci:
            // Golden spiral of quarter arcs.
            var spiral = Path()
            var c = center
            var size = r * 0.06
            var angle = spin
            for _ in 0..<7 {
                spiral.addArc(center: c, radius: size, startAngle: .radians(angle), endAngle: .radians(angle + .pi / 2), clockwise: false)
                let next = size * 1.618
                c = point(c, next - size, angle)
                size = next
                angle += .pi / 2
            }
            context.drawLayer { layer in
                layer.clip(to: body)
                layer.stroke(spiral, with: .color(ink.opacity(0.5)), lineWidth: 4.5 * s)
                layer.stroke(spiral, with: .color(Theme.yellow), lineWidth: 2.4 * s)
            }
        case .twin:
            // A bow on top.
            let knot = CGPoint(x: center.x + r * 0.35, y: center.y - r * 0.82)
            for side in [-1.0, 1.0] {
                var loop = Path()
                loop.move(to: knot)
                loop.addQuadCurve(to: CGPoint(x: knot.x + CGFloat(side) * r * 0.45, y: knot.y - r * 0.25),
                                  control: CGPoint(x: knot.x + CGFloat(side) * r * 0.3, y: knot.y - r * 0.5))
                loop.addQuadCurve(to: knot, control: CGPoint(x: knot.x + CGFloat(side) * r * 0.5, y: knot.y + r * 0.1))
                context.fill(loop, with: .color(Color(red: 1, green: 0.45, blue: 0.7)))
                context.stroke(loop, with: .color(ink), style: StrokeStyle(lineWidth: 2 * s, lineJoin: .round))
            }
            context.fill(circle(knot, 4 * s), with: .color(Color(red: 1, green: 0.45, blue: 0.7)))
            context.stroke(circle(knot, 4 * s), with: .color(ink), lineWidth: 1.8 * s)
        case .cell:
            // Nucleus and little organelles.
            context.drawLayer { layer in
                layer.clip(to: body)
                let nucleus = circle(point(center, r * 0.25, spin * 0.7 + 2.4), r * 0.3)
                layer.fill(nucleus, with: .color(p.line.opacity(0.35)))
                layer.stroke(nucleus, with: .color(p.line.opacity(0.5)), lineWidth: 1.6 * s)
                for (k, size) in [0.08, 0.06, 0.07].enumerated() {
                    layer.fill(circle(point(center, r * 0.6, spin + Double(k) * 2.1), r * CGFloat(size)), with: .color(.white.opacity(0.45)))
                }
            }
        case .clockwork:
            // A clock face with ticking hands.
            let face = circle(center, r * 0.62)
            context.fill(face, with: .color(Theme.cream))
            context.stroke(face, with: .color(ink), lineWidth: 2.5 * s)
            var ticks = Path()
            for k in 0..<12 {
                let a = Double(k) / 12 * 2 * .pi
                ticks.move(to: point(center, r * 0.5, a)); ticks.addLine(to: point(center, r * 0.58, a))
            }
            context.stroke(ticks, with: .color(ink.opacity(0.6)), lineWidth: 1.5 * s)
            var hands = Path()
            hands.move(to: center); hands.addLine(to: point(center, r * 0.42, spin * 4 - .pi / 2))
            hands.move(to: center); hands.addLine(to: point(center, r * 0.28, spin * 0.5 - .pi / 2))
            context.stroke(hands, with: .color(ink), style: StrokeStyle(lineWidth: 2.4 * s, lineCap: .round))
        case .portal:
            context.drawLayer { layer in
                layer.clip(to: body)
                var swirl = Path()
                for k in 0..<40 {
                    let t = Double(k) / 39
                    let q = point(center, r * 0.95 * t, spin * 3 + t * 5.5)
                    if k == 0 { swirl.move(to: q) } else { swirl.addLine(to: q) }
                }
                layer.stroke(swirl, with: .color(Color(red: 1, green: 0.55, blue: 0.1).opacity(0.85)), lineWidth: 4 * s)
                layer.stroke(swirl.applying(CGAffineTransform(translationX: -center.x, y: -center.y)
                    .concatenating(CGAffineTransform(rotationAngle: .pi)).concatenating(CGAffineTransform(translationX: center.x, y: center.y))),
                             with: .color(Color(red: 0.25, green: 0.65, blue: 1).opacity(0.85)), lineWidth: 4 * s)
            }
        case .glitch:
            context.drawLayer { layer in
                layer.clip(to: body)
                // Pixel blocks and a split-color edge.
                let block = r * 0.28
                for (gx, gy, color) in [(-2, -2, Color(red: 1, green: 0.2, blue: 0.8)), (1, -3, Color(red: 0.2, green: 1, blue: 0.9)),
                                        (2, 0, Color(red: 1, green: 0.2, blue: 0.8)), (-3, 1, Color(red: 0.2, green: 1, blue: 0.9)),
                                        (0, 2, Color(white: 0.1))] {
                    let flick = sin(spin * 11 + Double(gx * 3 + gy)) > -0.3
                    guard flick else { continue }
                    layer.fill(Path(CGRect(x: center.x + CGFloat(gx) * block, y: center.y + CGFloat(gy) * block, width: block, height: block)),
                               with: .color(color.opacity(0.75)))
                }
                layer.stroke(circle(CGPoint(x: center.x + 3 * s, y: center.y), r * 0.97), with: .color(Color(red: 1, green: 0.2, blue: 0.8).opacity(0.7)),
                             lineWidth: 3 * s)
                layer.stroke(circle(CGPoint(x: center.x - 3 * s, y: center.y), r * 0.97), with: .color(Color(red: 0.2, green: 1, blue: 0.9).opacity(0.7)),
                             lineWidth: 3 * s)
            }
        case .wizard:
            // Pointed hat with stars.
            var hat = Path()
            hat.move(to: CGPoint(x: center.x - r * 0.72, y: center.y - r * 0.52))
            hat.addQuadCurve(to: CGPoint(x: center.x + r * 0.45, y: center.y - r * 1.55),
                             control: CGPoint(x: center.x - r * 0.1, y: center.y - r * 1.0))
            hat.addQuadCurve(to: CGPoint(x: center.x + r * 0.72, y: center.y - r * 0.52),
                             control: CGPoint(x: center.x + r * 0.35, y: center.y - r * 0.9))
            hat.closeSubpath()
            let hatColor = Color(red: 0.32, green: 0.22, blue: 0.62)
            context.fill(hat, with: .color(hatColor))
            context.stroke(hat, with: .color(ink), style: StrokeStyle(lineWidth: 2.6 * s, lineJoin: .round))
            var brim = Path()
            brim.move(to: CGPoint(x: center.x - r * 0.88, y: center.y - r * 0.5))
            brim.addLine(to: CGPoint(x: center.x + r * 0.88, y: center.y - r * 0.5))
            context.stroke(brim, with: .color(ink), style: StrokeStyle(lineWidth: 7 * s, lineCap: .round))
            context.stroke(brim, with: .color(hatColor), style: StrokeStyle(lineWidth: 4 * s, lineCap: .round))
            for (dx, dy, size) in [(-0.1, -0.78, 5.0), (0.25, -1.12, 3.5)] {
                let star = starburst(center: CGPoint(x: center.x + r * dx, y: center.y + r * dy), radius: CGFloat(size) * s, points: 5,
                                     rotation: spin * 0.5)
                context.fill(star, with: .color(Theme.yellow))
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
            // A ball-sized mine field: steel ring of jaws around a pressure plate.
            context.drawLayer { layer in
                layer.opacity = fadeOut * (armIn > 0 ? 0.55 : 1)
                let area = FighterArt.circle(c, h.radius)
                layer.fill(area, with: .color(Color(white: 0.45).opacity(0.22)))
                layer.stroke(area, with: .color(ink.opacity(0.7)), style: StrokeStyle(lineWidth: 2.5, dash: [7, 5]))
                var teeth = Path()
                for i in 0..<16 {
                    let a = h.rotation + Double(i) / 16 * 2 * .pi
                    teeth.move(to: FighterArt.point(c, h.radius * 0.62, a - 0.13))
                    teeth.addLine(to: FighterArt.point(c, h.radius * 0.88, a))
                    teeth.addLine(to: FighterArt.point(c, h.radius * 0.62, a + 0.13))
                }
                let jaw = FighterArt.circle(c, h.radius * 0.62)
                layer.stroke(jaw, with: .color(ink), lineWidth: 5)
                layer.stroke(jaw, with: .color(Color(white: 0.75)), lineWidth: 2.5)
                layer.fill(teeth, with: .color(Color(white: 0.85)))
                layer.stroke(teeth, with: .color(ink), style: StrokeStyle(lineWidth: 1.8, lineJoin: .round))
                let plate = FighterArt.circle(c, h.radius * 0.28)
                layer.fill(plate, with: .color(team))
                layer.stroke(plate, with: .color(ink), lineWidth: 2)
            }
        case .zone:
            let full: Double = { if case .arsenal(.zone(let spec)) = state.fighter(h.owner).definition.attack {
                return spec.radius(atAge: h.age, base: h.radius) }; return h.radius }()
            let pulse = 0.92 + 0.08 * sin(time * 6 + h.rotation)
            let ring = FighterArt.circle(c, full * pulse)
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
                layer.fill(die, with: .color(h.loaded ? Theme.yellow : .white))
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
        case .miniBomb(let fuse, _):
            let blink = sin(time * (fuse < 0.3 ? 40 : 18)) > 0
            context.stroke(FighterArt.circle(c, h.radius), with: .color(Color(red: 0.85, green: 0.1, blue: 0.15).opacity(0.3)),
                           style: StrokeStyle(lineWidth: 2, dash: [6, 6]))
            let body = FighterArt.circle(c, 9)
            context.fill(body.offsetBy(dx: 0, dy: 2), with: .color(ink))
            context.fill(body, with: .color(Color(white: blink ? 0.5 : 0.22)))
            context.stroke(body, with: .color(ink), lineWidth: 2.5)
            if blink {
                context.fill(FighterArt.burst(center: CGPoint(x: c.x + 7, y: c.y - 11), radius: 4, points: 6), with: .color(Theme.yellow))
            }
        case .honey:
            let patch = FighterArt.circle(c, h.radius)
            context.drawLayer { layer in
                layer.opacity = fadeOut * min(1, h.age / 0.15)
                layer.fill(patch, with: .color(Color(red: 1, green: 0.72, blue: 0.15).opacity(0.5)))
                layer.stroke(patch, with: .color(Color(red: 0.75, green: 0.45, blue: 0.05).opacity(0.9)), lineWidth: 2.5)
                for k in 0..<4 {
                    let a = h.rotation + Double(k) * 1.6
                    layer.fill(FighterArt.circle(FighterArt.point(c, h.radius * 0.5, a), h.radius * 0.12),
                               with: .color(.white.opacity(0.45)))
                }
            }
        case .lava:
            let grow = min(1, h.age / 0.12)
            let patch = FighterArt.circle(c, h.radius * grow)
            context.drawLayer { layer in
                // A flat, see-through puddle on the floor (not a ball): glowing middle, crusted edge.
                layer.opacity = fadeOut * 0.62
                layer.fill(patch, with: .radialGradient(Gradient(colors: [Theme.yellow.opacity(0.9), Color(red: 1, green: 0.42, blue: 0.08).opacity(0.8),
                                                                          Color(red: 0.55, green: 0.12, blue: 0.06).opacity(0.7)]),
                                                        center: c, startRadius: 0, endRadius: h.radius))
                layer.stroke(patch, with: .color(Color(red: 0.4, green: 0.08, blue: 0.05).opacity(0.6)),
                             style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                // A bubble rising and popping.
                let t = (time * 1.3 + h.rotation).truncatingRemainder(dividingBy: 1)
                let bubble = FighterArt.circle(FighterArt.point(c, h.radius * 0.35, h.rotation * 3), h.radius * 0.18 * (0.4 + t))
                layer.stroke(bubble, with: .color(Theme.yellow.opacity(1 - t)), lineWidth: 1.6)
            }
        case .portal(_, let blue):
            let color = blue ? Color(red: 0.25, green: 0.65, blue: 1) : Color(red: 1, green: 0.55, blue: 0.1)
            let grow = min(1, h.age / 0.2)
            context.drawLayer { layer in
                layer.opacity = fadeOut
                let rim = FighterArt.circle(c, h.radius * grow)
                layer.fill(rim, with: .radialGradient(Gradient(colors: [Theme.ink.opacity(0.85), color.opacity(0.6)]),
                                                      center: c, startRadius: 0, endRadius: h.radius))
                var swirl = Path()
                for k in 0..<30 {
                    let t = Double(k) / 29
                    let q = FighterArt.point(c, h.radius * grow * 0.9 * t, time * 6 * (blue ? -1 : 1) + h.rotation + t * 6)
                    if k == 0 { swirl.move(to: q) } else { swirl.addLine(to: q) }
                }
                layer.stroke(swirl, with: .color(.white.opacity(0.75)), lineWidth: 2)
                layer.stroke(rim, with: .color(ink), lineWidth: 5)
                layer.stroke(rim, with: .color(color), lineWidth: 3)
            }
        case .errorTile:
            let size = h.radius * 1.7
            let rect = CGRect(x: c.x - size / 2, y: c.y - size / 2, width: size, height: size)
            let flicker = sin(time * 23 + h.rotation) > -0.6
            context.drawLayer { layer in
                layer.opacity = fadeOut * (h.hitCooldown > 0 ? 0.45 : (flicker ? 0.95 : 0.6))
                let tile = Path(roundedRect: rect, cornerRadius: 4)
                layer.fill(tile, with: .color(Color(white: 0.08)))
                let cell = size / 4
                for row in 0..<4 { for col in 0..<4 where (row + col + Int(h.rotation * 3)).isMultiple(of: 3) {
                    layer.fill(Path(CGRect(x: rect.minX + CGFloat(col) * cell, y: rect.minY + CGFloat(row) * cell, width: cell, height: cell)),
                               with: .color(Color(red: 1, green: 0.2, blue: 0.8).opacity(0.75)))
                } }
                layer.stroke(tile, with: .color(Color(red: 0.2, green: 1, blue: 0.9)), lineWidth: 2.5)
                let mark = layer.resolve(Text("!").font(.system(size: size * 0.55, weight: .black, design: .monospaced))
                    .foregroundStyle(Color.white))
                layer.draw(mark, at: c)
            }
        case .icePatch:
            let patch = FighterArt.circle(c, h.radius)
            context.drawLayer { layer in
                layer.opacity = fadeOut * min(1, h.age / 0.15)
                layer.fill(patch, with: .color(Color(red: 0.72, green: 0.9, blue: 1).opacity(0.55)))
                layer.stroke(patch, with: .color(.white.opacity(0.9)), lineWidth: 2.5)
                var glints = Path()
                for k in 0..<3 {
                    let a = h.rotation + Double(k) * 2.1
                    let p0 = FighterArt.point(c, h.radius * 0.25, a)
                    glints.move(to: p0)
                    glints.addLine(to: FighterArt.point(p0, h.radius * 0.4, a + 0.6))
                }
                layer.stroke(glints, with: .color(.white.opacity(0.9)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            }
        case .arc(let end):
            // Jagged lightning, re-jittered every frame.
            let fade = max(0, 1 - h.age / h.lifetime)
            var bolt = Path()
            let along = end - h.position
            let side = Vec2(-along.normalized.y, along.normalized.x)
            bolt.move(to: c)
            for k in 1..<8 {
                let t = Double(k) / 8
                let jitter = sin(time * 90 + Double(k) * 2.3 + h.rotation) * 12
                bolt.addLine(to: (h.position + along * t + side * jitter).cgPoint)
            }
            bolt.addLine(to: end.cgPoint)
            context.stroke(bolt, with: .color(ink.opacity(fade)), style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
            context.stroke(bolt, with: .color(Theme.yellow.opacity(fade)), style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
            context.stroke(bolt, with: .color(.white.opacity(fade)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))
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

    /// Clockwork's ghost: where it will rewind to.
    static func drawRewindGhost(_ fighter: FighterState, time: Double, in context: inout GraphicsContext) {
        guard case .arsenal(.clockwork) = fighter.definition.attack, let past = fighter.history.first else { return }
        let ghost = FighterArt.circle(past.position.cgPoint, CGFloat(fighter.definition.radius))
        context.fill(ghost, with: .color(fighter.slot.color.opacity(0.14)))
        context.stroke(ghost, with: .color(fighter.slot.color.opacity(0.5)), style: StrokeStyle(lineWidth: 2, dash: [5, 5], dashPhase: time * 15))
    }

    /// Laser's waiting emitter: the last wall hit, ready to link with the next one.
    static func drawLaserAnchor(_ fighter: FighterState, time: Double, in context: inout GraphicsContext) {
        guard let anchor = fighter.laserAnchor else { return }
        let c = anchor.cgPoint
        let blink = 0.5 + 0.5 * sin(time * 10)
        let emitter = FighterArt.circle(c, 7)
        context.fill(FighterArt.circle(c, 12), with: .color(Color(red: 1, green: 0.15, blue: 0.2).opacity(0.25 * blink)))
        context.fill(emitter, with: .color(fighter.slot.color))
        context.stroke(emitter, with: .color(Theme.ink), lineWidth: 2.5)
        context.fill(FighterArt.circle(c, 2.5), with: .color(Color(red: 1, green: 0.15, blue: 0.2).opacity(blink)))
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
        case .thorn:
            var thorn = Path()
            thorn.move(to: CGPoint(x: 8, y: 0)); thorn.addLine(to: CGPoint(x: -4, y: -4)); thorn.addLine(to: CGPoint(x: -4, y: 4))
            thorn.closeSubpath()
            context.fill(place(thorn), with: .color(p.owner.color.mix(with: .white, by: 0.25)))
            context.stroke(place(thorn), with: .color(ink), style: StrokeStyle(lineWidth: 1.8, lineJoin: .round))
        case .flare:
            // A glowing orb with a flickering halo.
            let halo = FighterArt.circle(c, p.radius * (1.7 + 0.2 * CGFloat(sin(p.age * 30))))
            context.fill(halo, with: .color(Color(red: 1, green: 0.55, blue: 0.15).opacity(0.3)))
            let core = FighterArt.circle(c, p.radius)
            context.fill(core, with: .color(Color(red: 1, green: 0.62, blue: 0.2)))
            context.stroke(core, with: .color(ink), lineWidth: 2.5)
            context.fill(FighterArt.circle(c, p.radius * 0.45), with: .color(Theme.yellow))
        case .bat:
            let flap = CGFloat(sin(p.age * 40)) * 3
            var wings = Path()
            wings.move(to: CGPoint(x: 2, y: 0))
            wings.addQuadCurve(to: CGPoint(x: -4, y: -11 - flap), control: CGPoint(x: 4, y: -8))
            wings.addLine(to: CGPoint(x: -3, y: -4))
            wings.addLine(to: CGPoint(x: -6, y: 0))
            wings.addLine(to: CGPoint(x: -3, y: 4))
            wings.addLine(to: CGPoint(x: -4, y: 11 + flap))
            wings.addQuadCurve(to: CGPoint(x: 2, y: 0), control: CGPoint(x: 4, y: 8))
            context.fill(place(wings), with: .color(Color(red: 0.32, green: 0.12, blue: 0.4)))
            context.stroke(place(wings), with: .color(ink), style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
            context.fill(FighterArt.circle(c, 4), with: .color(Color(red: 0.42, green: 0.16, blue: 0.5)))
            context.fill(FighterArt.circle(CGPoint(x: c.x, y: c.y), 1.3), with: .color(Color(red: 1, green: 0.3, blue: 0.3)))
        case .orb:
            let tint: Color = {
                switch p.effect {
                case .poison: return Theme.heal
                case .slow: return Color(red: 0.95, green: 0.95, blue: 1)
                case .stun: return Color(white: 0.78)
                default: return p.owner.color.mix(with: .white, by: 0.2)
                }
            }()
            let orb = FighterArt.circle(c, p.radius)
            context.fill(orb.offsetBy(dx: 0, dy: 2), with: .color(ink.opacity(0.6)))
            context.fill(orb, with: .color(tint))
            context.stroke(orb, with: .color(ink), lineWidth: 2.2)
            context.fill(FighterArt.circle(CGPoint(x: c.x - p.radius * 0.35, y: c.y - p.radius * 0.35), p.radius * 0.3),
                         with: .color(.white.opacity(0.85)))
        case .gear:
            var cog = Path()
            let teeth = 8
            for k in 0..<(teeth * 2) {
                let a = p.age * 12 + Double(k) / Double(teeth * 2) * 2 * .pi
                let rr = k.isMultiple(of: 2) ? p.radius + 3 : p.radius - 1
                let q = FighterArt.point(c, rr, a)
                if k == 0 { cog.move(to: q) } else { cog.addLine(to: q) }
            }
            cog.closeSubpath()
            context.fill(cog, with: .color(Color(red: 0.8, green: 0.64, blue: 0.3)))
            context.stroke(cog, with: .color(ink), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
            context.fill(FighterArt.circle(c, p.radius * 0.35), with: .color(ink))
        case .number:
            // A golden token showing its number.
            let token = FighterArt.circle(c, p.radius + 2)
            context.fill(token.offsetBy(dx: 0, dy: 2), with: .color(ink.opacity(0.6)))
            context.fill(token, with: .color(Theme.yellow))
            context.stroke(token, with: .color(ink), lineWidth: 2.2)
            let digits = context.resolve(Text("\(p.label)").font(.system(size: p.label >= 10 ? 10 : 12, weight: .black, design: .rounded))
                .foregroundStyle(ink))
            context.draw(digits, at: c)
        case .firebolt:
            // Flame tail, then the fiery core.
            for k in 1...3 {
                let q = pos - dir * Double(k) * 7
                context.fill(FighterArt.circle(q.cgPoint, p.radius * (1 - CGFloat(k) * 0.2)),
                             with: .color(Color(red: 1, green: 0.45, blue: 0.1).opacity(0.55 - Double(k) * 0.12)))
            }
            let core = FighterArt.circle(c, p.radius)
            context.fill(core, with: .color(Color(red: 1, green: 0.35, blue: 0.1)))
            context.stroke(core, with: .color(ink), lineWidth: 2.5)
            context.fill(FighterArt.circle(c, p.radius * 0.5), with: .color(Theme.yellow))
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
            case .ice:
                let block = Path(roundedRect: CGRect(x: center.x - r * 1.12, y: center.y - r * 1.12, width: r * 2.24, height: r * 2.24),
                                 cornerRadius: r * 0.35)
                context.fill(block, with: .color(Color(red: 0.7, green: 0.9, blue: 1).opacity(0.55)))
                context.stroke(block, with: .color(ink), lineWidth: 3)
                var glint = Path()
                glint.move(to: CGPoint(x: center.x - r * 0.8, y: center.y - r * 0.3))
                glint.addLine(to: CGPoint(x: center.x - r * 0.3, y: center.y - r * 0.8))
                glint.move(to: CGPoint(x: center.x - r * 0.75, y: center.y + r * 0.05))
                glint.addLine(to: CGPoint(x: center.x + r * 0.05, y: center.y - r * 0.75))
                context.stroke(glint, with: .color(.white.opacity(0.9)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            case .web:
                var strands = Path()
                for k in 0..<5 {
                    let a = Double(k) / 5 * .pi + time * 0.5
                    strands.move(to: FighterArt.point(center, r * 1.1, a))
                    strands.addLine(to: FighterArt.point(center, r * 1.1, a + .pi))
                }
                context.fill(FighterArt.circle(center, r * 1.08), with: .color(.white.opacity(0.35)))
                context.stroke(strands, with: .color(.white.opacity(0.9)), lineWidth: 2)
                context.stroke(FighterArt.circle(center, r * 1.08), with: .color(ink.opacity(0.6)), lineWidth: 1.5)
            case .time:
                // Grayed out with a clock face: frozen in time.
                context.fill(FighterArt.circle(center, r * 1.05), with: .color(Color(white: 0.85).opacity(0.55)))
                context.stroke(FighterArt.circle(center, r * 1.05), with: .color(ink.opacity(0.7)), style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                var hands = Path()
                hands.move(to: center); hands.addLine(to: FighterArt.point(center, r * 0.6, -.pi / 2))
                hands.move(to: center); hands.addLine(to: FighterArt.point(center, r * 0.4, 0))
                context.stroke(hands, with: .color(ink), style: StrokeStyle(lineWidth: 3, lineCap: .round))
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
        if fighter.shield > 0 {
            let bubble = FighterArt.circle(center, r * 1.22)
            context.fill(bubble, with: .color(Color(red: 0.6, green: 0.5, blue: 1).opacity(0.18 + 0.06 * sin(time * 5))))
            context.stroke(bubble, with: .color(Color(red: 0.75, green: 0.65, blue: 1).opacity(0.9)),
                           style: StrokeStyle(lineWidth: 2.5, dash: [8, 4], dashPhase: time * 18))
        }
        if fighter.chill > 0 && !fighter.isHeld {
            // Frost pips: how close the fighter is to freezing solid.
            for k in 0..<fighter.chill {
                let p = FighterArt.point(center, r + 9, -.pi / 2 + (Double(k) - Double(fighter.chill - 1) / 2) * 0.35)
                let flake = FighterArt.burst(center: p, radius: 6, points: 6)
                context.fill(flake, with: .color(Color(red: 0.75, green: 0.93, blue: 1)))
                context.stroke(flake, with: .color(ink), lineWidth: 1.5)
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
            return fighter.activeHazards > 0 ? String(localized: "\(fighter.activeHazards) ACTIVE") : (ready ? String(localized: "READY!") : seconds())
        case .train:
            return fighter.activeHazards > 0 ? String(localized: "ALL ABOARD!") : (ready ? String(localized: "NEXT WALL!") : seconds())
        case .tail(let spec):
            return String(localized: "\(fighter.tailSegments)/\(spec.maxSegments) TAIL")
        case .shock(let spec):
            return fighter.charge >= spec.maxCharge ? String(localized: "SUPERCHARGED!") : String(localized: "CHARGE \(fighter.charge)/\(spec.maxCharge)")
        case .virus:
            return ready ? String(localized: "ARMED!") : seconds()
        case .harpoon:
            return fighter.dragRemaining > 0 ? String(localized: "REELING!") : seconds()
        case .shards:
            return ready ? String(localized: "ARMED!") : seconds()
        case .knives, .bombs, .swarm, .wizard, .glitch:
            return seconds()
        case .twin:
            return ready ? String(localized: "ARMED!") : seconds()
        case .cell(let spec):
            return fighter.cellStage >= spec.stages ? String(localized: "FULL SIZE!")
                : String(localized: "SIZE \(fighter.cellStage + 1)/\(spec.stages + 1)")
        case .clockwork(let spec):
            return String(localized: "REWIND \(Int(max(0, spec.rewindInterval - fighter.rewindTimer).rounded(.up)))s")
        case .portal:
            return fighter.activeHazards > 0 ? String(localized: "\(fighter.activeHazards / 2) PORTALS") : seconds()
        case .moss, .wolf:
            return ready ? String(localized: "ARMED!") : seconds()
        case .magma:
            return String(localized: "\(fighter.activeHazards) POOLS")
        case .fibonacci(let spec):
            return String(localized: "STREAK \(FibonacciSpec.number(at: max(fighter.streak, spec.startIndex)))")
        }
    }
}
