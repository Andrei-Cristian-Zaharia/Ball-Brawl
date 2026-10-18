import SwiftUI

/// An illustrated scene of an arena for banners (menu, trophy road, crusade): sky, layered hills,
/// and the arena floor in perspective with a blue and a red ball facing off on it.
struct ArenaBanner: View {
    let map: ArenaMap
    /// Draw the two fighters on the floor.
    var showsBalls = true

    var body: some View {
        Canvas { context, size in
            let w = size.width, h = size.height
            let rect = CGRect(origin: .zero, size: size)
            let palette = map.bannerPalette

            // Sky.
            context.fill(Path(rect), with: .linearGradient(Gradient(colors: [palette.skyTop, palette.skyBottom]),
                                                           startPoint: .zero, endPoint: CGPoint(x: 0, y: h * 0.7)))
            let sun = CGPoint(x: w * 0.78, y: h * 0.22)
            context.fill(Path(rect), with: .radialGradient(Gradient(colors: [palette.glow.opacity(0.75), palette.glow.opacity(0)]),
                                                           center: sun, startRadius: 0, endRadius: h * 0.9))
            context.fill(Path(ellipseIn: CGRect(x: sun.x - h * 0.11, y: sun.y - h * 0.11, width: h * 0.22, height: h * 0.22)),
                         with: .color(palette.glow))

            // Far and near hills (peaks for the frost and volcano maps).
            // High horizon, so the floor and fighters sit above the title that banners lay over the bottom-left.
            let horizon = h * 0.36
            context.fill(ridge(width: w, base: horizon + h * 0.04, height: h * 0.26, waves: 3.2, phase: 0.6, peaked: palette.peaked),
                         with: .color(palette.far))
            if map == .frost {
                // Snow caps on the far peaks.
                context.drawLayer { layer in
                    layer.clip(to: ridge(width: w, base: horizon + h * 0.04, height: h * 0.26, waves: 3.2, phase: 0.6, peaked: true))
                    layer.fill(Path(CGRect(x: 0, y: 0, width: w, height: horizon - h * 0.08)), with: .color(.white.opacity(0.9)))
                }
            }
            if map == .volcano {
                // Lava glow seeping over the ridge.
                context.fill(Path(rect), with: .linearGradient(Gradient(colors: [.clear, Color(red: 1, green: 0.35, blue: 0.1).opacity(0.45)]),
                                                               startPoint: CGPoint(x: 0, y: horizon - h * 0.2),
                                                               endPoint: CGPoint(x: 0, y: horizon + h * 0.1)))
            }
            context.fill(ridge(width: w, base: horizon + h * 0.1, height: h * 0.14, waves: 2.1, phase: 2.2, peaked: false),
                         with: .color(palette.near))

            // Ground.
            context.fill(Path(CGRect(x: 0, y: horizon + h * 0.08, width: w, height: h)), with: .color(palette.near))

            // Arena floor in perspective.
            let top = horizon + h * 0.1, bottom = h * 1.15
            let topHalf = w * 0.2, bottomHalf = w * 0.5
            let center = w * 0.62
            var floor = Path()
            floor.move(to: CGPoint(x: center - topHalf, y: top))
            floor.addLine(to: CGPoint(x: center + topHalf, y: top))
            floor.addLine(to: CGPoint(x: center + bottomHalf, y: bottom))
            floor.addLine(to: CGPoint(x: center - bottomHalf, y: bottom))
            floor.closeSubpath()
            context.fill(floor.offsetBy(dx: 0, dy: 4), with: .color(Theme.ink.opacity(0.35)))
            context.fill(floor, with: .color(map.floor))
            context.drawLayer { layer in
                layer.clip(to: floor)
                // Checker tiles: rows get taller toward the viewer.
                let rows = 6, columns = 8
                func y(_ t: Double) -> Double { top + (bottom - top) * pow(t, 1.35) }
                func x(_ u: Double, at yy: Double) -> Double {
                    let t = (yy - top) / (bottom - top)
                    let half = topHalf + (bottomHalf - topHalf) * t
                    return center - half + 2 * half * u
                }
                for row in 0..<rows {
                    let y0 = y(Double(row) / Double(rows)), y1 = y(Double(row + 1) / Double(rows))
                    for col in 0..<columns where (row + col).isMultiple(of: 2) {
                        let u0 = Double(col) / Double(columns), u1 = Double(col + 1) / Double(columns)
                        var cell = Path()
                        cell.move(to: CGPoint(x: x(u0, at: y0), y: y0))
                        cell.addLine(to: CGPoint(x: x(u1, at: y0), y: y0))
                        cell.addLine(to: CGPoint(x: x(u1, at: y1), y: y1))
                        cell.addLine(to: CGPoint(x: x(u0, at: y1), y: y1))
                        cell.closeSubpath()
                        layer.fill(cell, with: .color(map.tile))
                    }
                }
                // Light falling on the middle of the floor.
                layer.fill(floor, with: .radialGradient(Gradient(colors: [.white.opacity(0.35), .white.opacity(0)]),
                                                        center: CGPoint(x: center, y: (top + bottom) / 2),
                                                        startRadius: 0, endRadius: w * 0.4))
            }
            context.stroke(floor, with: .color(Theme.ink.opacity(0.8)), lineWidth: 2.5)

            // Corner posts.
            for (px, py) in [(center - topHalf, top), (center + topHalf, top)] {
                let post = Path(roundedRect: CGRect(x: px - 2.5, y: py - h * 0.12, width: 5, height: h * 0.12), cornerRadius: 2)
                context.fill(post, with: .color(map.bolt))
                context.stroke(post, with: .color(Theme.ink.opacity(0.8)), lineWidth: 1.5)
            }
            if map == .royal {
                // Pennants on the posts.
                for px in [center - topHalf, center + topHalf] {
                    var flag = Path()
                    flag.move(to: CGPoint(x: px + 2.5, y: top - h * 0.12))
                    flag.addLine(to: CGPoint(x: px + 16, y: top - h * 0.09))
                    flag.addLine(to: CGPoint(x: px + 2.5, y: top - h * 0.06))
                    flag.closeSubpath()
                    context.fill(flag, with: .color(Theme.yellow))
                    context.stroke(flag, with: .color(Theme.ink.opacity(0.8)), lineWidth: 1.2)
                }
            }

            // Two fighters facing off.
            if showsBalls {
                let r = h * 0.15
                ball(in: &context, at: CGPoint(x: center - w * 0.04, y: top + (bottom - top) * 0.22), radius: r,
                     color: PlayerSlot.one.color)
                ball(in: &context, at: CGPoint(x: center + w * 0.17, y: top + (bottom - top) * 0.12), radius: r * 0.85,
                     color: PlayerSlot.two.color)
            }
        }
    }

    private func ridge(width: Double, base: Double, height: Double, waves: Double, phase: Double, peaked: Bool) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: base))
        let steps = 48
        for i in 0...steps {
            let x = width * Double(i) / Double(steps)
            let t = Double(i) / Double(steps) * waves * 2 * .pi + phase
            let wave = peaked ? 1 - abs(sin(t / 2)) * 2 + 1 : (sin(t) + 1) / 2
            let bump = peaked ? max(0, wave - 0.2) / 1.8 : wave
            path.addLine(to: CGPoint(x: x, y: base - height * (0.35 + 0.65 * bump)))
        }
        path.addLine(to: CGPoint(x: width, y: base + 400))
        path.addLine(to: CGPoint(x: 0, y: base + 400))
        path.closeSubpath()
        return path
    }

    private func ball(in context: inout GraphicsContext, at center: CGPoint, radius r: Double, color: Color) {
        context.fill(Path(ellipseIn: CGRect(x: center.x - r * 0.9, y: center.y + r * 0.7, width: r * 1.8, height: r * 0.55)),
                     with: .color(Theme.ink.opacity(0.3)))
        let body = Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
        context.fill(body, with: .radialGradient(Gradient(colors: [color.mix(with: .white, by: 0.45), color, color.mix(with: Theme.ink, by: 0.3)]),
                                                 center: CGPoint(x: center.x - r * 0.35, y: center.y - r * 0.4),
                                                 startRadius: 0, endRadius: r * 1.6))
        context.stroke(body, with: .color(Theme.ink), lineWidth: 2)
        context.fill(Path(ellipseIn: CGRect(x: center.x - r * 0.55, y: center.y - r * 0.7, width: r * 0.5, height: r * 0.3)),
                     with: .color(.white.opacity(0.6)))
        // Eyes.
        for dx in [-0.3, 0.3] {
            let eye = CGRect(x: center.x + r * dx - r * 0.13, y: center.y - r * 0.18, width: r * 0.26, height: r * 0.34)
            context.fill(Path(ellipseIn: eye), with: .color(.white))
            context.fill(Path(ellipseIn: eye.insetBy(dx: r * 0.05, dy: r * 0.08).offsetBy(dx: 0, dy: r * 0.04)), with: .color(Theme.ink))
        }
    }
}

extension ArenaMap {
    /// Sky, glow and hill colors for banner illustrations.
    var bannerPalette: (skyTop: Color, skyBottom: Color, glow: Color, far: Color, near: Color, peaked: Bool) {
        switch self {
        case .classic:
            return (Color(red: 0.35, green: 0.62, blue: 1), Color(red: 0.72, green: 0.86, blue: 1), Color(red: 1, green: 0.95, blue: 0.75),
                    Color(red: 0.5, green: 0.62, blue: 0.86), Color(red: 0.42, green: 0.7, blue: 0.45), false)
        case .meadow:
            return (Color(red: 0.4, green: 0.72, blue: 1), Color(red: 0.8, green: 0.93, blue: 1), Color(red: 1, green: 0.95, blue: 0.7),
                    Color(red: 0.42, green: 0.66, blue: 0.5), Color(red: 0.36, green: 0.66, blue: 0.3), false)
        case .dunes:
            return (Color(red: 1, green: 0.65, blue: 0.35), Color(red: 1, green: 0.88, blue: 0.62), Color(red: 1, green: 0.92, blue: 0.6),
                    Color(red: 0.88, green: 0.62, blue: 0.36), Color(red: 0.94, green: 0.76, blue: 0.46), false)
        case .frost:
            return (Color(red: 0.42, green: 0.62, blue: 0.95), Color(red: 0.82, green: 0.92, blue: 1), Color(red: 0.92, green: 0.97, blue: 1),
                    Color(red: 0.52, green: 0.62, blue: 0.82), Color(red: 0.86, green: 0.93, blue: 1), true)
        case .volcano:
            return (Color(red: 0.25, green: 0.08, blue: 0.14), Color(red: 0.62, green: 0.2, blue: 0.14), Color(red: 1, green: 0.55, blue: 0.2),
                    Color(red: 0.2, green: 0.1, blue: 0.12), Color(red: 0.32, green: 0.18, blue: 0.16), true)
        case .royal:
            return (Color(red: 0.3, green: 0.2, blue: 0.62), Color(red: 0.75, green: 0.55, blue: 0.85), Color(red: 1, green: 0.85, blue: 0.45),
                    Color(red: 0.38, green: 0.28, blue: 0.62), Color(red: 0.44, green: 0.34, blue: 0.6), false)
        }
    }
}
