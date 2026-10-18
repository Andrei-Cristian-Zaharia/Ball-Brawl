import SwiftUI

/// Colors and floor decorations for each map.
extension ArenaMap {
    /// Arena floor.
    var floor: Color {
        switch self {
        case .classic: return Theme.cream
        case .meadow: return Color(red: 0.66, green: 0.86, blue: 0.47)
        case .dunes: return Color(red: 0.96, green: 0.84, blue: 0.58)
        case .frost: return Color(red: 0.85, green: 0.93, blue: 0.99)
        case .volcano: return Color(red: 0.47, green: 0.36, blue: 0.33)
        case .royal: return Color(red: 0.58, green: 0.5, blue: 0.74)
        }
    }

    /// Checkerboard tiles drawn over the floor (Gambit moves on these).
    var tile: Color {
        switch self {
        case .classic: return Theme.creamDark.opacity(0.6)
        case .meadow: return Color(red: 0.55, green: 0.79, blue: 0.38).opacity(0.75)
        case .dunes: return Color(red: 0.92, green: 0.77, blue: 0.5).opacity(0.75)
        case .frost: return Color(red: 0.75, green: 0.87, blue: 0.97).opacity(0.8)
        case .volcano: return Color(red: 0.4, green: 0.3, blue: 0.28).opacity(0.85)
        case .royal: return Color(red: 0.5, green: 0.42, blue: 0.67).opacity(0.85)
        }
    }

    /// Center line and circle.
    var marking: Color {
        switch self {
        case .classic: return Theme.ink.opacity(0.12)
        case .meadow: return Color.white.opacity(0.45)
        case .dunes: return Color(red: 0.75, green: 0.55, blue: 0.3).opacity(0.35)
        case .frost: return Color.white.opacity(0.7)
        case .volcano: return Color(red: 1, green: 0.45, blue: 0.15).opacity(0.35)
        case .royal: return Color(red: 1, green: 0.82, blue: 0.3).opacity(0.5)
        }
    }

    /// Screen background behind the arena.
    var background: Color {
        switch self {
        case .classic: return Theme.background
        case .meadow: return Color(red: 0.16, green: 0.42, blue: 0.3)
        case .dunes: return Color(red: 0.62, green: 0.38, blue: 0.16)
        case .frost: return Color(red: 0.2, green: 0.4, blue: 0.62)
        case .volcano: return Color(red: 0.33, green: 0.1, blue: 0.12)
        case .royal: return Color(red: 0.25, green: 0.15, blue: 0.42)
        }
    }

    /// Corner bolts.
    var bolt: Color {
        switch self {
        case .classic, .meadow, .dunes, .royal: return Theme.yellow
        case .frost: return Color(red: 0.6, green: 0.85, blue: 1)
        case .volcano: return Color(red: 1, green: 0.5, blue: 0.15)
        }
    }

    /// Scenery drawn on the floor under everything else.
    func drawDecorations(in context: inout GraphicsContext, size: CGSize, time: Double) {
        switch self {
        case .classic:
            drawTrainingCamp(in: &context, size: size)
        case .meadow:
            drawMeadow(in: &context, size: size, time: time)
        case .volcano:
            drawVolcano(in: &context, size: size, time: time)
        case .dunes:
            drawDunes(in: &context, size: size, time: time)
        case .frost:
            drawFrost(in: &context, size: size, time: time)
        case .royal:
            drawRoyal(in: &context, size: size, time: time)
        }
    }

    // MARK: Meadow: grass tufts and flowers

    private func drawMeadow(in context: inout GraphicsContext, size: CGSize, time: Double) {
        var rng = SplitMix64(seed: 7)
        let grass = Color(red: 0.36, green: 0.65, blue: 0.27)
        var tufts = Path()
        for _ in 0..<38 {
            let p = randomPoint(&rng, size)
            for k in -1...1 {
                tufts.move(to: CGPoint(x: p.x + CGFloat(k) * 4, y: p.y))
                tufts.addQuadCurve(to: CGPoint(x: p.x + CGFloat(k) * 7, y: p.y - 11 + CGFloat(abs(k)) * 3),
                                   control: CGPoint(x: p.x + CGFloat(k) * 3, y: p.y - 6))
            }
        }
        context.stroke(tufts, with: .color(grass), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))

        let petals: [Color] = [.white, Color(red: 1, green: 0.55, blue: 0.7), Color(red: 1, green: 0.85, blue: 0.3),
                               Color(red: 0.6, green: 0.7, blue: 1)]
        for i in 0..<16 {
            let p = randomPoint(&rng, size)
            let sway = CGFloat(sin(time * 1.6 + Double(i))) * 0.12
            let color = petals[i % petals.count]
            for k in 0..<5 {
                let a = Double(k) / 5 * 2 * .pi + Double(sway)
                let petal = FighterArt.circle(FighterArt.point(p, 5, a), 4)
                context.fill(petal, with: .color(color))
                context.stroke(petal, with: .color(Theme.ink.opacity(0.35)), lineWidth: 1)
            }
            context.fill(FighterArt.circle(p, 3), with: .color(Theme.yellow))
        }
    }

    // MARK: Volcano: glowing lava cracks and rising embers

    private func drawVolcano(in context: inout GraphicsContext, size: CGSize, time: Double) {
        var rng = SplitMix64(seed: 11)
        let glow = 0.55 + 0.25 * sin(time * 2.2)
        for _ in 0..<9 {
            var crack = Path()
            var p = randomPoint(&rng, size)
            crack.move(to: p)
            var angle = Double.random(in: 0..<(2 * .pi), using: &rng)
            for _ in 0..<4 {
                angle += Double.random(in: -0.9...0.9, using: &rng)
                p = FighterArt.point(p, CGFloat(Double.random(in: 14...30, using: &rng)), angle)
                crack.addLine(to: p)
            }
            context.stroke(crack, with: .color(Color(red: 1, green: 0.35, blue: 0.1).opacity(glow * 0.45)),
                           style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round))
            context.stroke(crack, with: .color(Color(red: 1, green: 0.62, blue: 0.2).opacity(glow)),
                           style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
            context.stroke(crack, with: .color(Color(red: 1, green: 0.95, blue: 0.6).opacity(glow * 0.8)),
                           style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))
        }
        // Embers drift upward and wrap around.
        for i in 0..<22 {
            let start = randomPoint(&rng, size)
            let speed = Double.random(in: 18...40, using: &rng)
            let y = (Double(start.y) - time * speed).truncatingRemainder(dividingBy: Double(size.height))
            let x = Double(start.x) + sin(time * 1.3 + Double(i)) * 8
            let point = CGPoint(x: x, y: y < 0 ? y + Double(size.height) : y)
            let flicker = 0.5 + 0.5 * sin(time * 6 + Double(i) * 1.7)
            context.fill(FighterArt.circle(point, 2.2), with: .color(Color(red: 1, green: 0.7, blue: 0.25).opacity(0.4 + 0.5 * flicker)))
        }
    }

    // MARK: Training camp: chalk play marks and training cones along the edges

    private func drawTrainingCamp(in context: inout GraphicsContext, size: CGSize) {
        let chalk = Color.white.opacity(0.75)
        var rng = SplitMix64(seed: 41)
        // Chalk X's and O's, like a coach's whiteboard.
        for k in 0..<8 {
            let p = randomPoint(&rng, size)
            var mark = Path()
            if k.isMultiple(of: 2) {
                mark.move(to: CGPoint(x: p.x - 7, y: p.y - 7)); mark.addLine(to: CGPoint(x: p.x + 7, y: p.y + 7))
                mark.move(to: CGPoint(x: p.x + 7, y: p.y - 7)); mark.addLine(to: CGPoint(x: p.x - 7, y: p.y + 7))
            } else {
                mark.addEllipse(in: CGRect(x: p.x - 8, y: p.y - 8, width: 16, height: 16))
            }
            context.stroke(mark, with: .color(chalk), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }
        // Training cones along the side walls.
        for y in stride(from: size.height * 0.18, to: size.height * 0.9, by: size.height * 0.24) {
            for x in [CGFloat(20), size.width - 20] {
                var cone = Path()
                cone.move(to: CGPoint(x: x - 9, y: y + 8))
                cone.addLine(to: CGPoint(x: x, y: y - 12))
                cone.addLine(to: CGPoint(x: x + 9, y: y + 8))
                cone.closeSubpath()
                context.fill(Path(roundedRect: CGRect(x: x - 12, y: y + 6, width: 24, height: 5), cornerRadius: 2),
                             with: .color(Color(red: 0.95, green: 0.45, blue: 0.12)))
                context.fill(cone, with: .color(Color(red: 1, green: 0.55, blue: 0.15)))
                context.fill(Path(CGRect(x: x - 5, y: y - 3, width: 10, height: 3.5)), with: .color(.white))
                context.stroke(cone, with: .color(Theme.ink.opacity(0.6)), style: StrokeStyle(lineWidth: 1.8, lineJoin: .round))
            }
        }
    }

    // MARK: Dunes: wind ripples, cacti and pebbles

    private func drawDunes(in context: inout GraphicsContext, size: CGSize, time: Double) {
        var rng = SplitMix64(seed: 21)
        // Wind ripples across the sand.
        var ripples = Path()
        for row in stride(from: 30.0, to: Double(size.height), by: 46) {
            let phase = Double.random(in: 0..<6, using: &rng)
            ripples.move(to: CGPoint(x: 0, y: row))
            for x in stride(from: 0.0, through: Double(size.width), by: 12) {
                ripples.addLine(to: CGPoint(x: x, y: row + sin(x * 0.04 + phase) * 7))
            }
        }
        context.stroke(ripples, with: .color(Color(red: 0.8, green: 0.6, blue: 0.32).opacity(0.35)), lineWidth: 2.5)
        // Pebbles.
        for _ in 0..<14 {
            let p = randomPoint(&rng, size)
            let r = CGFloat(Double.random(in: 3...6, using: &rng))
            let pebble = Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r * 0.7, width: r * 2, height: r * 1.4))
            context.fill(pebble, with: .color(Color(red: 0.72, green: 0.58, blue: 0.42)))
            context.stroke(pebble, with: .color(Theme.ink.opacity(0.4)), lineWidth: 1.2)
        }
        // Little cacti near the edges, out of the way of the fight.
        for (k, p) in [CGPoint(x: 26, y: size.height * 0.2), CGPoint(x: size.width - 26, y: size.height * 0.62),
                        CGPoint(x: 30, y: size.height * 0.85)].enumerated() {
            let green = Color(red: 0.36, green: 0.62, blue: 0.36)
            var cactus = Path(roundedRect: CGRect(x: p.x - 6, y: p.y - 26, width: 12, height: 30), cornerRadius: 6)
            cactus.addPath(Path(roundedRect: CGRect(x: p.x - 16, y: p.y - 18, width: 8, height: 14), cornerRadius: 4))
            cactus.addPath(Path(roundedRect: CGRect(x: p.x + 8, y: p.y - (k.isMultiple(of: 2) ? 22 : 14), width: 8, height: 14), cornerRadius: 4))
            context.fill(cactus, with: .color(green))
            context.stroke(cactus, with: .color(Theme.ink.opacity(0.7)), lineWidth: 2)
        }
    }

    // MARK: Frost: ice cracks, frosty patches and falling snow

    private func drawFrost(in context: inout GraphicsContext, size: CGSize, time: Double) {
        var rng = SplitMix64(seed: 31)
        for _ in 0..<7 {
            let p = randomPoint(&rng, size)
            context.fill(Path(ellipseIn: CGRect(x: p.x - 50, y: p.y - 24, width: 100, height: 48)),
                         with: .color(.white.opacity(0.45)))
        }
        for _ in 0..<8 {
            var crack = Path()
            var p = randomPoint(&rng, size)
            crack.move(to: p)
            var angle = Double.random(in: 0..<(2 * .pi), using: &rng)
            for _ in 0..<4 {
                angle += Double.random(in: -0.7...0.7, using: &rng)
                p = FighterArt.point(p, CGFloat(Double.random(in: 12...26, using: &rng)), angle)
                crack.addLine(to: p)
            }
            context.stroke(crack, with: .color(Color(red: 0.45, green: 0.68, blue: 0.9).opacity(0.7)),
                           style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
        // Snow drifting down.
        for i in 0..<28 {
            let x0 = Double.random(in: 0...Double(size.width), using: &rng)
            let speed = Double.random(in: 14...30, using: &rng)
            let offset = Double.random(in: 0...Double(size.height), using: &rng)
            let y = (offset + time * speed).truncatingRemainder(dividingBy: Double(size.height))
            let x = x0 + sin(time * 0.8 + Double(i)) * 10
            context.fill(FighterArt.circle(CGPoint(x: x, y: y), 2.6), with: .color(.white.opacity(0.9)))
        }
    }

    // MARK: Royal: carved stone, gold trim and banners

    private func drawRoyal(in context: inout GraphicsContext, size: CGSize, time: Double) {
        let gold = Color(red: 1, green: 0.82, blue: 0.3)
        // Gold trim inset from the walls, with corner diamonds.
        let trim = Path(roundedRect: CGRect(origin: .zero, size: size).insetBy(dx: 16, dy: 16), cornerRadius: 14)
        context.stroke(trim, with: .color(gold.opacity(0.75)), lineWidth: 3)
        for corner in [CGPoint(x: 16, y: 16), CGPoint(x: size.width - 16, y: 16),
                       CGPoint(x: 16, y: size.height - 16), CGPoint(x: size.width - 16, y: size.height - 16)] {
            var diamond = Path()
            diamond.move(to: CGPoint(x: corner.x, y: corner.y - 8))
            diamond.addLine(to: CGPoint(x: corner.x + 8, y: corner.y))
            diamond.addLine(to: CGPoint(x: corner.x, y: corner.y + 8))
            diamond.addLine(to: CGPoint(x: corner.x - 8, y: corner.y))
            diamond.closeSubpath()
            context.fill(diamond, with: .color(gold))
            context.stroke(diamond, with: .color(Theme.ink.opacity(0.6)), lineWidth: 1.5)
        }
        // A crest in the center circle.
        let crest = Path(ellipseIn: CGRect(x: size.width / 2 - 26, y: size.height / 2 - 26, width: 52, height: 52))
        context.fill(crest, with: .color(gold.opacity(0.22)))
        context.stroke(crest, with: .color(gold.opacity(0.7)), lineWidth: 2.5)
        // Banners hanging from the side walls, swaying.
        for (k, x) in [CGFloat(30), size.width - 30].enumerated() {
            for y in [size.height * 0.28, size.height * 0.72] {
                let sway = CGFloat(sin(time * 1.4 + Double(k) + Double(y))) * 2
                var banner = Path()
                banner.move(to: CGPoint(x: x - 10, y: y - 26))
                banner.addLine(to: CGPoint(x: x + 10, y: y - 26))
                banner.addLine(to: CGPoint(x: x + 10 + sway, y: y + 18))
                banner.addLine(to: CGPoint(x: x + sway, y: y + 10))
                banner.addLine(to: CGPoint(x: x - 10 + sway, y: y + 18))
                banner.closeSubpath()
                context.fill(banner, with: .color(Color(red: 0.78, green: 0.18, blue: 0.3)))
                context.stroke(banner, with: .color(gold), lineWidth: 2)
            }
        }
    }

    private func randomPoint(_ rng: inout SplitMix64, _ size: CGSize) -> CGPoint {
        CGPoint(x: Double.random(in: 14...(Double(size.width) - 14), using: &rng),
                y: Double.random(in: 14...(Double(size.height) - 14), using: &rng))
    }
}
