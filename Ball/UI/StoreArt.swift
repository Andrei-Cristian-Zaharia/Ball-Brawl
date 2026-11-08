#if DEBUG && os(iOS)
import SwiftUI
import UIKit

/// App Store marketing images (debug builds only). Launch with `-storeArt <job.json>`: renders every item in
/// the job (the product page header, the search result image and framed screenshots) as PNGs, using the
/// game's own ball art, then quits. Sizes are in pixels.
enum StoreArt {
    struct Job: Decodable {
        let items: [Item]
    }

    struct Item: Decodable {
        enum Kind: String, Decodable { case header, search, shot }
        let kind: Kind
        let width: CGFloat
        let height: CGFloat
        let file: String
        var tagline: String?
        var bullets: [String]?
        var lines: [String]?
        /// A raw capture shown in a device frame.
        var screen: String?
        var isPad: Bool?
        var tilt: Double?
        /// Ball ids shown glowing at the sides: [left (blue), right (red)].
        var balls: [String]?
    }

    static func runIfAsked() {
        guard let path = StoreDemo.argument("-storeArt"),
              let data = FileManager.default.contents(atPath: path),
              let job = try? JSONDecoder().decode(Job.self, from: data) else { return }
        for item in job.items {
            let renderer = ImageRenderer(content: view(for: item).frame(width: item.width, height: item.height))
            renderer.scale = 1
            renderer.isOpaque = true
            renderer.proposedSize = ProposedViewSize(width: item.width, height: item.height)
            guard let image = renderer.uiImage, let png = image.pngData() else {
                print("StoreArt: failed \(item.file)")
                continue
            }
            try? FileManager.default.createDirectory(atPath: (item.file as NSString).deletingLastPathComponent,
                                                     withIntermediateDirectories: true)
            FileManager.default.createFile(atPath: item.file, contents: png)
            print("StoreArt: wrote \(item.file)")
        }
        exit(0)
    }

    @ViewBuilder @MainActor
    static func view(for item: Item) -> some View {
        switch item.kind {
        case .header: HeaderArt(item: item)
        case .search: SearchArt(item: item)
        case .shot: ShotArt(item: item)
        }
    }
}

// MARK: - Pieces

private func ball(_ id: String) -> FighterDefinition {
    Progression.leveled(FighterCatalog.definition(id: id) ?? FighterCatalog.all[0], level: 10)
}

/// The stage: blue on the left, red on the right, spotlights from above, stars, and a glowing grid floor.
private struct Stage: View {
    /// Where the floor's horizon sits (fraction of the height).
    var horizon: CGFloat = 0.6

    var body: some View {
        Canvas { context, size in
            let w = size.width, h = size.height
            let rect = CGRect(origin: .zero, size: size)
            context.fill(Path(rect), with: .linearGradient(
                Gradient(colors: [Color(red: 0.13, green: 0.17, blue: 0.45), Color(red: 0.24, green: 0.17, blue: 0.42),
                                  Color(red: 0.42, green: 0.13, blue: 0.3)]),
                startPoint: CGPoint(x: 0, y: h * 0.5), endPoint: CGPoint(x: w, y: h * 0.5)))
            // Darker sky at the top.
            context.fill(Path(rect), with: .linearGradient(
                Gradient(colors: [Color(red: 0.05, green: 0.04, blue: 0.16).opacity(0.75), .clear]),
                startPoint: .zero, endPoint: CGPoint(x: 0, y: h * horizon)))

            // Spotlight beams.
            let unit = max(w, h)
            for i in 0..<5 {
                let x = w * (0.18 + 0.16 * CGFloat(i))
                let spread = unit * 0.09
                var beam = Path()
                beam.move(to: CGPoint(x: x - unit * 0.012, y: 0))
                beam.addLine(to: CGPoint(x: x + unit * 0.012, y: 0))
                beam.addLine(to: CGPoint(x: x + spread + (x - w / 2) * 0.25, y: h * horizon))
                beam.addLine(to: CGPoint(x: x - spread + (x - w / 2) * 0.25, y: h * horizon))
                beam.closeSubpath()
                context.fill(beam, with: .linearGradient(Gradient(colors: [.white.opacity(0.13), .white.opacity(0.0)]),
                                                         startPoint: .zero, endPoint: CGPoint(x: 0, y: h * horizon)))
            }

            // Stars.
            var rng = SplitMix64(seed: 42)
            for _ in 0..<Int(w * h / 30000) {
                let p = CGPoint(x: .random(in: 0..<w, using: &rng), y: .random(in: 0..<(h * horizon), using: &rng))
                let r = unit * .random(in: 0.0006..<0.0016, using: &rng)
                context.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                             with: .color(.white.opacity(.random(in: 0.12..<0.45, using: &rng))))
            }

            // Floor.
            let top = h * horizon
            context.fill(Path(CGRect(x: 0, y: top, width: w, height: h - top)), with: .linearGradient(
                Gradient(colors: [Color(red: 0.3, green: 0.2, blue: 0.55), Color(red: 0.14, green: 0.09, blue: 0.3)]),
                startPoint: CGPoint(x: 0, y: top), endPoint: CGPoint(x: 0, y: h)))
            let line = GraphicsContext.Shading.color(Color(red: 0.62, green: 0.5, blue: 1).opacity(0.45))
            let lineWidth = unit * 0.0011
            var depth: CGFloat = 0.02
            while top + (h - top) * depth < h {
                let y = top + (h - top) * depth
                context.stroke(Path { $0.move(to: CGPoint(x: 0, y: y)); $0.addLine(to: CGPoint(x: w, y: y)) }, with: line, lineWidth: lineWidth)
                depth *= 1.45
            }
            let vanishing = CGPoint(x: w / 2, y: top - h * 0.25)
            for i in -24...24 {
                let bottomX = w / 2 + CGFloat(i) * unit * 0.07
                let t = (top - vanishing.y) / (h - vanishing.y)
                let startX = vanishing.x + (bottomX - vanishing.x) * t
                context.stroke(Path { $0.move(to: CGPoint(x: startX, y: top)); $0.addLine(to: CGPoint(x: bottomX, y: h)) },
                               with: line, lineWidth: lineWidth)
            }
            // Horizon glow.
            context.fill(Path(CGRect(x: 0, y: top - unit * 0.002, width: w, height: unit * 0.004)),
                         with: .color(Color(red: 0.75, green: 0.6, blue: 1).opacity(0.7)))
        }
    }
}

/// A ball with a team-colored glow.
private struct GlowBall: View {
    let id: String
    let color: Color
    let size: CGFloat
    var expression: FighterArt.Expression = .happy
    var blur: CGFloat = 0

    var body: some View {
        ZStack {
            Circle().fill(color.opacity(0.55)).frame(width: size * 1.25, height: size * 1.25).blur(radius: size * 0.22)
            FighterPortrait(definition: ball(id), color: color, size: size, expression: expression)
        }
        .blur(radius: blur)
    }
}

/// The "BALL BRAWL" logo under a soft spotlight.
private struct Logo: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            Ellipse().fill(Color(red: 1, green: 0.85, blue: 0.55).opacity(0.35))
                .frame(width: size * 6.2, height: size * 1.9).blur(radius: size * 0.35)
            HStack(spacing: size * 0.12) {
                OutlinedText("BALL", size: size, fill: .white, outline: size * 0.075).fixedSize()
                OutlinedText("BRAWL", size: size, fill: Theme.yellow, outline: size * 0.075).fixedSize()
            }
        }
    }
}

/// The red ribbon with the tagline.
private struct Ribbon: View {
    let text: String
    let size: CGFloat

    var body: some View {
        Text(text)
            .font(Theme.titleFont(size))
            .foregroundStyle(.white)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, size * 0.8)
            .padding(.vertical, size * 0.28)
            .background(
                RoundedRectangle(cornerRadius: size * 0.12)
                    .fill(LinearGradient(colors: [Color(red: 0.93, green: 0.22, blue: 0.3), Color(red: 0.75, green: 0.1, blue: 0.2)],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay(RoundedRectangle(cornerRadius: size * 0.12).stroke(.white, lineWidth: size * 0.07))
            )
            .shadow(color: Theme.ink.opacity(0.6), radius: 0, y: size * 0.12)
            .rotationEffect(.degrees(-2.5))
    }
}

/// The clash in the middle of the header: a burst of light between two balls.
private struct Clash: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            Canvas { context, canvas in
                let c = CGPoint(x: canvas.width / 2, y: canvas.height / 2)
                var rng = SplitMix64(seed: 7)
                for _ in 0..<70 {
                    let a = Double.random(in: 0..<(2 * .pi), using: &rng)
                    let inner = size * .random(in: 0.15..<0.35, using: &rng)
                    let outer = size * .random(in: 0.45..<0.8, using: &rng)
                    context.stroke(Path {
                        $0.move(to: CGPoint(x: c.x + cos(a) * inner, y: c.y + sin(a) * inner))
                        $0.addLine(to: CGPoint(x: c.x + cos(a) * outer, y: c.y + sin(a) * outer))
                    }, with: .color(.white.opacity(.random(in: 0.4..<0.9, using: &rng))), lineWidth: size * 0.006)
                }
                for _ in 0..<16 {
                    let a = Double.random(in: 0..<(2 * .pi), using: &rng)
                    let d = size * .random(in: 0.25..<0.6, using: &rng)
                    let r = size * .random(in: 0.02..<0.045, using: &rng)
                    let p = CGPoint(x: c.x + cos(a) * d, y: c.y + sin(a) * d * 0.8)
                    context.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                                 with: .color(Color(red: 1, green: 0.5, blue: 0.15)))
                }
                var star = Path()
                for i in 0..<16 {
                    let a = Double(i) * .pi / 8
                    let r = size * (i.isMultiple(of: 2) ? 0.26 : 0.1)
                    let p = CGPoint(x: c.x + cos(a) * r * 0.8, y: c.y + sin(a) * r)
                    if i == 0 { star.move(to: p) } else { star.addLine(to: p) }
                }
                star.closeSubpath()
                context.fill(star, with: .color(Color(red: 1, green: 0.93, blue: 0.55)))
            }
            .frame(width: size * 2.2, height: size * 2.2)
            Circle().fill(Color(red: 1, green: 0.8, blue: 0.4).opacity(0.6)).frame(width: size * 0.5).blur(radius: size * 0.12)
            GlowBall(id: "wizard", color: PlayerSlot.one.color, size: size * 0.52, expression: .hurt)
                .offset(x: -size * 0.3, y: size * 0.04)
            GlowBall(id: "magma", color: PlayerSlot.two.color, size: size * 0.52, expression: .normal)
                .offset(x: size * 0.3, y: -size * 0.02)
        }
    }
}

/// A device with a screen capture in it.
private struct Device: View {
    let screen: String?
    let width: CGFloat
    let isPad: Bool

    var body: some View {
        let image = screen.flatMap { UIImage(contentsOfFile: $0) }
        let aspect = image.map { $0.size.height / $0.size.width } ?? (isPad ? 1.333 : 2.17)
        let bezel = width * (isPad ? 0.035 : 0.04)
        let screenWidth = width - bezel * 2
        let corner = width * (isPad ? 0.06 : 0.15)
        ZStack {
            RoundedRectangle(cornerRadius: corner)
                .fill(LinearGradient(colors: [Color(red: 0.2, green: 0.18, blue: 0.32), Color(red: 0.07, green: 0.06, blue: 0.14)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: corner).stroke(Color(red: 0.45, green: 0.42, blue: 0.62), lineWidth: width * 0.006))
            Group {
                if let image { Image(uiImage: image).resizable() } else { Color.black }
            }
            .frame(width: screenWidth, height: screenWidth * aspect)
            .clipShape(RoundedRectangle(cornerRadius: corner - bezel))
        }
        .frame(width: width, height: screenWidth * aspect + bezel * 2)
        .shadow(color: .black.opacity(0.55), radius: width * 0.04, y: width * 0.03)
    }
}

/// A font size that keeps `text` on one line within `width` (CJK glyphs are about square, Latin capitals narrower).
private func fit(_ text: String, _ size: CGFloat, _ width: CGFloat, latin: CGFloat = 0.7) -> CGFloat {
    let ems = text.unicodeScalars.reduce(CGFloat(0)) { total, scalar in
        total + (scalar.value >= 0x2E80 ? 1.0 : scalar.properties.isWhitespace ? 0.3 : latin)
    }
    return min(size, width / max(ems, 1))
}

// MARK: - Images

private struct HeaderArt: View {
    let item: StoreArt.Item

    var body: some View {
        let w = item.width, h = item.height
        ZStack {
            Stage(horizon: 0.6)
            GlowBall(id: "spike", color: PlayerSlot.one.color, size: h * 0.2, expression: .normal).position(x: w * 0.23, y: h * 0.36)
            GlowBall(id: "wolf", color: PlayerSlot.one.color, size: h * 0.14, expression: .normal).position(x: w * 0.12, y: h * 0.71)
            GlowBall(id: "glitch", color: PlayerSlot.two.color, size: h * 0.17).position(x: w * 0.77, y: h * 0.34)
            GlowBall(id: "portal", color: PlayerSlot.two.color, size: h * 0.14).position(x: w * 0.88, y: h * 0.72)
            GlowBall(id: "cell", color: PlayerSlot.one.color, size: h * 0.36, blur: h * 0.006).position(x: w * 0.025, y: h * 0.98)
            GlowBall(id: "bomb", color: PlayerSlot.two.color, size: h * 0.36, blur: h * 0.006).position(x: w * 0.975, y: h * 0.98)
            Logo(size: h * 0.11).position(x: w * 0.5, y: h * 0.4)
            Clash(size: h * 0.5).position(x: w * 0.5, y: h * 0.8)
            Ribbon(text: item.tagline ?? "", size: h * 0.033).position(x: w * 0.5, y: h * 0.56)
        }
        .frame(width: w, height: h)
        .clipped()
    }
}

private struct SearchArt: View {
    let item: StoreArt.Item

    var body: some View {
        let w = item.width, h = item.height
        let icons = ["circle.grid.3x3.fill", "trophy.fill", "globe"]
        ZStack {
            Stage(horizon: 0.58)
            GlowBall(id: "cell", color: PlayerSlot.one.color, size: h * 0.22, blur: h * 0.005).position(x: w * 0.07, y: h * 0.13)
            GlowBall(id: "eclipse", color: PlayerSlot.two.color, size: h * 0.15).position(x: w * 0.91, y: h * 0.15)
            GlowBall(id: "wolf", color: PlayerSlot.one.color, size: h * 0.11, expression: .normal).position(x: w * 0.085, y: h * 0.86)
            GlowBall(id: "bomb", color: PlayerSlot.two.color, size: h * 0.3, blur: h * 0.005).position(x: w * 0.93, y: h * 0.96)
            VStack(alignment: .leading, spacing: h * 0.03) {
                Logo(size: h * 0.075)
                    .padding(.bottom, h * 0.02)
                ForEach(Array((item.bullets ?? []).enumerated()), id: \.offset) { i, text in
                    HStack(spacing: h * 0.018) {
                        Image(systemName: icons[i % icons.count])
                            .font(.system(size: h * 0.022, weight: .black))
                            .foregroundStyle(Theme.ink)
                            .frame(width: h * 0.042, height: h * 0.042)
                            .background(Circle().fill(Theme.yellow))
                        Text(text)
                            .font(Theme.titleFont(h * 0.03))
                            .foregroundStyle(.white)
                            .shadow(color: Theme.ink, radius: 0, y: h * 0.003)
                            .fixedSize()
                    }
                }
            }
            .position(x: w * 0.31, y: h * 0.5)
            Device(screen: item.screen, width: h * 0.29, isPad: true)
                .rotationEffect(.degrees(item.tilt ?? 7))
                .position(x: w * 0.67, y: h * 0.5)
            GlowBall(id: "wizard", color: PlayerSlot.one.color, size: h * 0.1).position(x: w * 0.755, y: h * 0.33)
            GlowBall(id: "magma", color: PlayerSlot.two.color, size: h * 0.09, expression: .normal).position(x: w * 0.565, y: h * 0.67)
        }
        .frame(width: w, height: h)
        .clipped()
    }
}

private struct ShotArt: View {
    let item: StoreArt.Item

    var body: some View {
        let w = item.width, h = item.height
        let isPad = item.isPad ?? false
        let lines = item.lines ?? ["", "", ""]
        let balls = item.balls ?? ["wizard", "magma"]
        let deviceWidth = w * (isPad ? 0.74 : 0.8)
        let unit = isPad ? h * 0.75 : w
        ZStack {
            Stage(horizon: 0.87)
            VStack(spacing: unit * 0.006) {
                OutlinedText(lines[0], size: fit(lines[0], unit * (isPad ? 0.1 : 0.13), w * 0.9), fill: Theme.yellow, outline: unit * 0.008)
                    .fixedSize()
                OutlinedText(lines[1], size: fit(lines[1], unit * (isPad ? 0.075 : 0.095), w * 0.9), fill: .white, outline: unit * 0.007)
                    .fixedSize()
                Text(lines[2])
                    .font(Theme.bodyFont(fit(lines[2], unit * (isPad ? 0.036 : 0.045), w * 0.9, latin: 0.55), weight: .heavy))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.top, unit * 0.008)
                    .fixedSize()
            }
            .frame(width: w * 0.94)
            .position(x: w / 2, y: h * (isPad ? 0.1 : 0.095))
            Device(screen: item.screen, width: deviceWidth, isPad: isPad)
                .rotationEffect(.degrees(item.tilt ?? 0))
                .position(x: w / 2, y: h * (isPad ? 0.6 : 0.64))
            GlowBall(id: balls[0], color: PlayerSlot.one.color, size: unit * 0.15).position(x: w * 0.08, y: h * 0.33)
            GlowBall(id: balls[1], color: PlayerSlot.two.color, size: unit * 0.15).position(x: w * 0.92, y: h * 0.4)
        }
        .frame(width: w, height: h)
        .clipped()
    }
}
#endif
