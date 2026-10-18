import SwiftUI

/// Procedural cartoon drawing of a fighter ball. Shared by the arena, the fighter cards and the aim picker.
enum FighterArt {
    enum Expression {
        case normal
        case hurt
        case happy
        case knockedOut
    }

    /// Colors used for one ball's drawing.
    struct Palette {
        let base: Color
        let shade: Color
        let light: Color
        let line = Theme.ink
        let accent = Theme.yellow
        let cream = Color(white: 0.96)

        init(team: Color) {
            base = team
            shade = team.mix(with: Theme.ink, by: 0.3)
            light = team.mix(with: .white, by: 0.35)
        }
    }

    /// - Parameters:
    ///   - spin: visual rotation (rolling); rim decorations turn with it. The face stays upright.
    ///   - aimAngle: firing direction for aimed fighters; *not* affected by `spin`.
    ///   - look: direction the pupils point (e.g. toward the opponent).
    ///   - flash: 0…1 white hit flash.
    ///   - coverage: how far an Eclipse's moon has slid across its face (0…1).
    static func draw(
        _ definition: FighterDefinition,
        in context: inout GraphicsContext,
        center: CGPoint,
        radius r: CGFloat,
        team color: Color,
        spin: Double = 0,
        aimAngle: Double? = nil,
        look: CGVector = CGVector(dx: 0.4, dy: 0.2),
        expression: Expression = .normal,
        flash: Double = 0,
        coverage: Double = 0.55
    ) {
        let s = r / CGFloat(definition.radius)
        let ink = Theme.ink
        let outline = 4.2 * s
        let body = circle(center, r)
        let p = Palette(team: color)

        // Ground shadow.
        context.fill(Path(ellipseIn: CGRect(x: center.x - r * 0.9, y: center.y + r * 0.55, width: r * 1.8, height: r * 0.7)),
                     with: .color(ink.opacity(0.22)))

        drawBackParts(definition, in: &context, center: center, r: r, s: s, p: p, spin: spin, aimAngle: aimAngle,
                      coverage: coverage, outline: outline)

        // Body: shaded like a glossy sphere, lit from the top left, with a dark rim crescent.
        context.fill(body, with: .radialGradient(
            Gradient(stops: [.init(color: color.mix(with: .white, by: 0.45), location: 0),
                             .init(color: color, location: 0.5),
                             .init(color: p.shade, location: 1)]),
            center: CGPoint(x: center.x - r * 0.35, y: center.y - r * 0.4), startRadius: 0, endRadius: r * 1.55))
        context.drawLayer { layer in
            layer.clip(to: body)
            var rim = Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
            rim.addEllipse(in: CGRect(x: center.x - r * 1.1, y: center.y - r * 1.16, width: r * 2.04, height: r * 2.04))
            layer.fill(rim, with: .color(p.shade.opacity(0.55)), style: FillStyle(eoFill: true))
            // Bounce light along the bottom edge.
            layer.stroke(Path { path in
                path.addArc(center: center, radius: r * 0.9, startAngle: .degrees(35), endAngle: .degrees(145), clockwise: false)
            }, with: .color(.white.opacity(0.22)), style: StrokeStyle(lineWidth: r * 0.08, lineCap: .round))
        }

        drawSurface(definition, in: &context, center: center, r: r, s: s, p: p, spin: spin, coverage: coverage, body: body)

        // Glossy highlights: a big soft shine and a small hard sparkle.
        context.fill(Path(ellipseIn: CGRect(x: center.x - r * 0.66, y: center.y - r * 0.74, width: r * 0.52, height: r * 0.32))
                        .applying(rotation(-0.6, around: CGPoint(x: center.x - r * 0.4, y: center.y - r * 0.58))),
                     with: .color(.white.opacity(0.75)))
        context.fill(circle(CGPoint(x: center.x - r * 0.18, y: center.y - r * 0.72), r * 0.07), with: .color(.white.opacity(0.9)))

        drawFace(definition, in: &context, center: center, r: r, s: s, look: look, expression: expression)

        // Thick ink outline.
        context.stroke(body, with: .color(ink), lineWidth: outline)

        if flash > 0 {
            context.fill(body, with: .color(.white.opacity(0.7 * flash)))
        }
    }

    // MARK: Parts behind the body

    private static func drawBackParts(_ definition: FighterDefinition, in context: inout GraphicsContext, center: CGPoint,
                                      r: CGFloat, s: CGFloat, p: Palette, spin: Double, aimAngle: Double?,
                                      coverage: Double, outline: CGFloat) {
        let ink = Theme.ink
        switch definition.attack {
        case .contact(let spec):
            var spikes = Path()
            let n = spec.spikeCount
            let half = .pi / Double(n) * 0.62
            for i in 0..<n {
                let a = spin + Double(i) / Double(n) * 2 * .pi
                spikes.move(to: point(center, r * 0.85, a - half))
                spikes.addLine(to: point(center, r + CGFloat(spec.spikeLength) * s * 1.15, a))
                spikes.addLine(to: point(center, r * 0.85, a + half))
                spikes.closeSubpath()
            }
            context.stroke(spikes, with: .color(ink), style: StrokeStyle(lineWidth: outline * 1.6, lineJoin: .round))
            context.fill(spikes, with: .color(p.cream))
        case .projectile:
            if let aimAngle {
                let transform = CGAffineTransform(rotationAngle: aimAngle)
                    .concatenating(CGAffineTransform(translationX: center.x, y: center.y))
                let barrel = Path(roundedRect: CGRect(x: 0, y: -8 * s, width: r + 14 * s, height: 16 * s),
                                  cornerRadius: 5 * s).applying(transform)
                let muzzle = Path(roundedRect: CGRect(x: r + 6 * s, y: -10 * s, width: 10 * s, height: 20 * s),
                                  cornerRadius: 4 * s).applying(transform)
                for part in [barrel, muzzle] {
                    context.stroke(part, with: .color(ink), lineWidth: outline * 1.6)
                }
                context.fill(barrel, with: .color(Color(white: 0.92)))
                context.fill(muzzle, with: .color(p.accent))
                context.stroke(muzzle, with: .color(ink), lineWidth: outline * 0.7)
            }
        case .web(let spec):
            var legs = Path()
            for side in [-1.0, 1.0] {
                for k in 0..<4 {
                    let base = (side > 0 ? 0 : Double.pi) + (Double(k) - 1.5) * 0.42 * side
                    let a = base + sin(spin * 3 + Double(k) * 1.7) * 0.12
                    let hip = point(center, r * 0.8, a)
                    var knee = point(center, r + CGFloat(spec.legLength) * s * 0.55, a)
                    knee.y -= 8 * s
                    var foot = point(center, r + CGFloat(spec.legLength) * s * 0.75, a)
                    foot.y += 6 * s
                    legs.move(to: hip)
                    legs.addLine(to: knee)
                    legs.addLine(to: foot)
                }
            }
            context.stroke(legs, with: .color(ink), style: StrokeStyle(lineWidth: 5 * s, lineCap: .round, lineJoin: .round))
        case .grab:
            for side in [-1.0, 1.0] {
                let a = aimAngle.map { $0 + side * 0.5 } ?? spin + side * .pi / 2
                let fist = circle(point(center, aimAngle == nil ? r * 0.98 : r * 1.12, a), 12 * s)
                context.stroke(fist, with: .color(ink), lineWidth: outline * 1.6)
                context.fill(fist, with: .color(p.accent))
            }
        case .drain:
            let flap = CGFloat(sin(spin * 2.5)) * 6 * s
            for side in [-1.0, 1.0] {
                let x = CGFloat(side)
                var wing = Path()
                wing.move(to: CGPoint(x: center.x + x * r * 0.55, y: center.y - r * 0.35))
                wing.addLine(to: CGPoint(x: center.x + x * (r + 26 * s), y: center.y - r * 0.85 - flap))
                wing.addQuadCurve(to: CGPoint(x: center.x + x * (r + 20 * s), y: center.y - r * 0.05 - flap * 0.5),
                                  control: CGPoint(x: center.x + x * (r + 12 * s), y: center.y - r * 0.5))
                wing.addQuadCurve(to: CGPoint(x: center.x + x * (r + 4 * s), y: center.y + r * 0.2),
                                  control: CGPoint(x: center.x + x * (r + 4 * s), y: center.y - r * 0.1))
                wing.addQuadCurve(to: CGPoint(x: center.x + x * r * 0.55, y: center.y + r * 0.3),
                                  control: CGPoint(x: center.x + x * r * 0.75, y: center.y))
                wing.closeSubpath()
                context.stroke(wing, with: .color(ink), style: StrokeStyle(lineWidth: outline * 1.4, lineJoin: .round))
                context.fill(wing, with: .color(ink.mix(with: .white, by: 0.22)))
            }
        case .chess:
            var crown = Path()
            let base = center.y - r * 0.55
            let top = center.y - r - 14 * s
            crown.move(to: CGPoint(x: center.x - r * 0.55, y: base))
            crown.addLine(to: CGPoint(x: center.x - r * 0.6, y: top + 6 * s))
            crown.addLine(to: CGPoint(x: center.x - r * 0.3, y: top + 14 * s))
            crown.addLine(to: CGPoint(x: center.x, y: top))
            crown.addLine(to: CGPoint(x: center.x + r * 0.3, y: top + 14 * s))
            crown.addLine(to: CGPoint(x: center.x + r * 0.6, y: top + 6 * s))
            crown.addLine(to: CGPoint(x: center.x + r * 0.55, y: base))
            crown.closeSubpath()
            context.stroke(crown, with: .color(ink), style: StrokeStyle(lineWidth: outline * 1.5, lineJoin: .round))
            context.fill(crown, with: .color(p.accent))
            for x in [-0.6, 0.0, 0.6] {
                let jewel = circle(CGPoint(x: center.x + r * x, y: x == 0 ? top : top + 6 * s), 3.5 * s)
                context.fill(jewel, with: .color(.white))
                context.stroke(jewel, with: .color(ink), lineWidth: 1.5 * s)
            }
        case .eclipse:
            var rays = Path()
            let count = 16
            for i in 0..<count {
                let a = spin * 0.3 + Double(i) * 2 * .pi / Double(count)
                let length = (5 + 14 * coverage) * s * (i.isMultiple(of: 2) ? 1 : 0.6)
                rays.move(to: point(center, r * 0.95, a))
                rays.addLine(to: point(center, r + length, a))
            }
            context.stroke(rays, with: .color(ink), style: StrokeStyle(lineWidth: 6 * s, lineCap: .round))
            context.stroke(rays, with: .color(p.accent.mix(with: .white, by: coverage * 0.5)),
                           style: StrokeStyle(lineWidth: 3 * s, lineCap: .round))
        case .arsenal(let attack):
            drawArsenalBack(attack, in: &context, center: center, r: r, s: s, p: p, spin: spin)
        case .pulse:
            break
        }
    }

    // MARK: Rim markings and body decoration

    private static func drawSurface(_ definition: FighterDefinition, in context: inout GraphicsContext, center: CGPoint,
                                    r: CGFloat, s: CGFloat, p: Palette, spin: Double, coverage: Double, body: Path) {
        let ink = Theme.ink
        switch definition.attack {
        case .projectile:
            for i in 0..<4 {
                let a = spin + Double(i) * .pi / 2
                let rivet = circle(point(center, r * 0.78, a), 3.2 * s)
                context.fill(rivet, with: .color(p.light))
                context.stroke(rivet, with: .color(ink), lineWidth: 1.6 * s)
            }
        case .pulse:
            context.stroke(circle(center, r * 0.8), with: .color(p.light), lineWidth: 3 * s)
            for i in 0..<4 {
                let a = spin + Double(i) * .pi / 2
                let node = circle(point(center, r * 0.8, a), 4 * s)
                context.fill(node, with: .color(p.accent))
                context.stroke(node, with: .color(ink), lineWidth: 1.6 * s)
            }
        case .grab:
            context.drawLayer { layer in
                layer.clip(to: body)
                let band = Path(CGRect(x: center.x - r, y: center.y - r * 0.5, width: r * 2, height: r * 0.22))
                layer.fill(band, with: .color(p.accent))
                layer.stroke(band, with: .color(ink), lineWidth: 2.5 * s)
            }
        case .web:
            var web = Path()
            for i in 0..<6 {
                let a = spin + Double(i) * .pi / 3
                web.move(to: center)
                web.addLine(to: point(center, r, a))
            }
            for ring in [0.45, 0.78] {
                for i in 0...6 {
                    let q = point(center, r * ring, spin + Double(i) * .pi / 3)
                    if i == 0 { web.move(to: q) } else { web.addLine(to: q) }
                }
            }
            context.stroke(web, with: .color(.white.opacity(0.45)), lineWidth: 1.8 * s)
        case .drain:
            context.drawLayer { layer in
                layer.clip(to: body)
                var hair = Path()
                hair.move(to: CGPoint(x: center.x - r, y: center.y - r))
                hair.addLine(to: CGPoint(x: center.x + r, y: center.y - r))
                hair.addLine(to: CGPoint(x: center.x + r, y: center.y - r * 0.3))
                hair.addQuadCurve(to: CGPoint(x: center.x, y: center.y - r * 0.28),
                                  control: CGPoint(x: center.x + r * 0.4, y: center.y - r * 0.62))
                hair.addQuadCurve(to: CGPoint(x: center.x - r, y: center.y - r * 0.3),
                                  control: CGPoint(x: center.x - r * 0.4, y: center.y - r * 0.62))
                hair.closeSubpath()
                layer.fill(hair, with: .color(ink.mix(with: .white, by: 0.12)))
            }
        case .chess:
            var dark = Path()
            let segments = 12
            for i in stride(from: 0, to: segments, by: 2) {
                let a0 = Angle(radians: spin + Double(i) * 2 * .pi / Double(segments))
                let a1 = Angle(radians: spin + Double(i + 1) * 2 * .pi / Double(segments))
                dark.addArc(center: center, radius: r * 0.97, startAngle: a0, endAngle: a1, clockwise: false)
                dark.addArc(center: center, radius: r * 0.74, startAngle: a1, endAngle: a0, clockwise: true)
                dark.closeSubpath()
            }
            context.fill(dark, with: .color(ink.opacity(0.28)))
        case .eclipse:
            context.drawLayer { layer in
                layer.clip(to: body)
                let offset = (1 - coverage) * 2.05 * r
                let moonCenter = CGPoint(x: center.x + offset, y: center.y - offset * 0.2)
                layer.fill(circle(moonCenter, r * 0.98), with: .color(ink.mix(with: .white, by: 0.12)))
                for (dx, dy, size) in [(-0.3, -0.3, 0.12), (0.25, 0.1, 0.09), (-0.1, 0.4, 0.07)] {
                    layer.fill(circle(CGPoint(x: moonCenter.x + r * dx, y: moonCenter.y + r * dy), r * size),
                               with: .color(ink.mix(with: .white, by: 0.04)))
                }
            }
        case .arsenal(let attack):
            drawArsenalSurface(attack, in: &context, center: center, r: r, s: s, p: p, spin: spin, body: body)
        case .contact:
            break
        }
    }

    // MARK: Face

    private struct FaceStyle {
        var angry = false
        var extraEyes = false
        var fangs = false
        var monocle = false
    }

    private static func faceStyle(_ definition: FighterDefinition) -> FaceStyle {
        var face = FaceStyle()
        switch definition.attack {
        case .contact, .grab: face.angry = true
        case .web: face.extraEyes = true
        case .drain: face.fangs = true
        case .chess: face.monocle = true
        case .arsenal(let a):
            switch a {
            case .traps, .turrets, .shock, .harpoon: face.angry = true
            case .bombs(let spec): face.angry = !spec.icy
            case .tail: face.fangs = true
            case .wolf: face.fangs = true; face.angry = true
            case .magma: face.angry = true
            default: break
            }
        default: break
        }
        return face
    }

    private static func drawFace(_ definition: FighterDefinition, in context: inout GraphicsContext, center: CGPoint,
                                 r: CGFloat, s: CGFloat, look: CGVector, expression: Expression) {
        let ink = Theme.ink
        let style = faceStyle(definition)
        let eyeY = center.y - r * 0.08
        let eyeDX = r * 0.3
        let line = StrokeStyle(lineWidth: 3.2 * s, lineCap: .round, lineJoin: .round)

        for side in [-1.0, 1.0] {
            let eye = CGPoint(x: center.x + eyeDX * side, y: eyeY)
            switch expression {
            case .normal:
                let white = Path(ellipseIn: CGRect(x: eye.x - r * 0.15, y: eye.y - r * 0.19, width: r * 0.3, height: r * 0.38))
                context.fill(white, with: .color(.white))
                context.stroke(white, with: .color(ink), lineWidth: 2.2 * s)
                let len = max(0.001, hypot(look.dx, look.dy))
                let pupil = CGPoint(x: eye.x + look.dx / len * r * 0.06, y: eye.y + look.dy / len * r * 0.08)
                context.fill(circle(pupil, r * 0.085), with: .color(ink))
            case .hurt:
                var squint = Path()
                squint.move(to: CGPoint(x: eye.x - r * 0.12 * side, y: eye.y - r * 0.1))
                squint.addLine(to: CGPoint(x: eye.x + r * 0.1 * side, y: eye.y))
                squint.addLine(to: CGPoint(x: eye.x - r * 0.12 * side, y: eye.y + r * 0.1))
                context.stroke(squint, with: .color(ink), style: line)
            case .happy:
                var arc = Path()
                arc.addArc(center: CGPoint(x: eye.x, y: eye.y + r * 0.05), radius: r * 0.12,
                           startAngle: .degrees(200), endAngle: .degrees(340), clockwise: false)
                context.stroke(arc, with: .color(ink), style: line)
            case .knockedOut:
                var x = Path()
                let d = r * 0.1
                x.move(to: CGPoint(x: eye.x - d, y: eye.y - d)); x.addLine(to: CGPoint(x: eye.x + d, y: eye.y + d))
                x.move(to: CGPoint(x: eye.x + d, y: eye.y - d)); x.addLine(to: CGPoint(x: eye.x - d, y: eye.y + d))
                context.stroke(x, with: .color(ink), style: line)
            }

            if style.angry && expression != .knockedOut {
                var brow = Path()
                brow.move(to: CGPoint(x: eye.x + r * 0.17 * side, y: eye.y - r * 0.32))
                brow.addLine(to: CGPoint(x: eye.x - r * 0.08 * side, y: eye.y - r * 0.2))
                context.stroke(brow, with: .color(ink), style: StrokeStyle(lineWidth: 3.6 * s, lineCap: .round))
            }
        }

        if style.extraEyes && expression != .knockedOut {
            for side in [-1.0, 1.0] {
                let p = CGPoint(x: center.x + r * 0.13 * side, y: eyeY - r * 0.3)
                let eye = circle(p, r * 0.08)
                context.fill(eye, with: .color(.white))
                context.stroke(eye, with: .color(ink), lineWidth: 1.6 * s)
                context.fill(circle(p, r * 0.035), with: .color(ink))
            }
        }

        // Mouth.
        var mouth = Path()
        let mouthY = center.y + r * 0.32
        switch expression {
        case .normal where style.angry:
            mouth.move(to: CGPoint(x: center.x - r * 0.14, y: mouthY + r * 0.02))
            mouth.addLine(to: CGPoint(x: center.x + r * 0.14, y: mouthY - r * 0.02))
        case .normal:
            mouth.addArc(center: CGPoint(x: center.x, y: mouthY - r * 0.1), radius: r * 0.13,
                         startAngle: .degrees(30), endAngle: .degrees(150), clockwise: false)
        case .happy:
            mouth.addArc(center: CGPoint(x: center.x, y: mouthY - r * 0.12), radius: r * 0.18,
                         startAngle: .degrees(10), endAngle: .degrees(170), clockwise: false)
            mouth.closeSubpath()
            context.fill(mouth, with: .color(ink))
        case .hurt, .knockedOut:
            mouth.addEllipse(in: CGRect(x: center.x - r * 0.08, y: mouthY - r * 0.08, width: r * 0.16, height: r * 0.18))
            context.fill(mouth, with: .color(ink))
        }
        context.stroke(mouth, with: .color(ink), style: StrokeStyle(lineWidth: 3 * s, lineCap: .round))

        if style.fangs && expression != .knockedOut {
            var fangs = Path()
            for side in [-1.0, 1.0] {
                let x = center.x + r * 0.08 * side
                fangs.move(to: CGPoint(x: x - r * 0.05, y: mouthY + r * 0.01))
                fangs.addLine(to: CGPoint(x: x, y: mouthY + r * 0.15))
                fangs.addLine(to: CGPoint(x: x + r * 0.05, y: mouthY + r * 0.01))
                fangs.closeSubpath()
            }
            context.fill(fangs, with: .color(.white))
            context.stroke(fangs, with: .color(ink), style: StrokeStyle(lineWidth: 1.5 * s, lineJoin: .round))
        }

        if style.monocle {
            let eye = CGPoint(x: center.x + eyeDX, y: eyeY)
            context.stroke(circle(eye, r * 0.22), with: .color(ink), lineWidth: 4.5 * s)
            context.stroke(circle(eye, r * 0.22), with: .color(Theme.yellow), lineWidth: 2.2 * s)
            var chain = Path()
            chain.move(to: CGPoint(x: eye.x + r * 0.15, y: eye.y + r * 0.16))
            chain.addQuadCurve(to: CGPoint(x: center.x + r * 0.62, y: center.y + r * 0.62),
                               control: CGPoint(x: center.x + r * 0.62, y: center.y + r * 0.25))
            context.stroke(chain, with: .color(Theme.yellow), style: StrokeStyle(lineWidth: 1.8 * s, lineCap: .round, dash: [2, 2]))
        }
    }

    // MARK: Geometry helpers

    static func point(_ center: CGPoint, _ distance: CGFloat, _ angle: Double) -> CGPoint {
        CGPoint(x: center.x + distance * CGFloat(cos(angle)), y: center.y + distance * CGFloat(sin(angle)))
    }

    static func circle(_ center: CGPoint, _ radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }

    private static func rotation(_ angle: Double, around p: CGPoint) -> CGAffineTransform {
        CGAffineTransform(translationX: -p.x, y: -p.y)
            .concatenating(CGAffineTransform(rotationAngle: angle))
            .concatenating(CGAffineTransform(translationX: p.x, y: p.y))
    }

    /// Comic "POW" starburst.
    static func starburst(center: CGPoint, radius: CGFloat, points: Int = 9, rotation: Double = 0) -> Path {
        var path = Path()
        for i in 0..<(points * 2) {
            let a = rotation + Double(i) * .pi / Double(points)
            let p = point(center, i.isMultiple(of: 2) ? radius : radius * 0.55, a)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        return path
    }

    /// Same starburst; `seed` is accepted for call sites that vary bursts.
    static func burst(center: CGPoint, radius: CGFloat, points: Int = 9, rotation: Double = 0, seed: Int = 0) -> Path {
        starburst(center: center, radius: radius, points: points, rotation: rotation)
    }

    /// Arrow from `start` toward `angle`, used by the aim picker.
    static func arrow(from start: CGPoint, angle: Double, length: CGFloat, headSize: CGFloat) -> (shaft: Path, head: Path) {
        let tip = point(start, length, angle)
        let neck = point(start, length - headSize, angle)
        var shaft = Path()
        shaft.move(to: start)
        shaft.addLine(to: neck)
        var head = Path()
        head.move(to: tip)
        head.addLine(to: point(neck, headSize * 0.65, angle + .pi / 2))
        head.addLine(to: point(neck, headSize * 0.65, angle - .pi / 2))
        head.closeSubpath()
        return (shaft, head)
    }
}
