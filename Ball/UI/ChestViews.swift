import SwiftUI

// MARK: - Chest art

extension ChestKind {
    /// Body, trim (bands and lock), and gem colors.
    var palette: (body: Color, trim: Color, gem: Color) {
        switch self {
        case .wooden: return (Color(red: 0.72, green: 0.45, blue: 0.22), Color(red: 0.88, green: 0.72, blue: 0.36), Theme.yellow)
        case .silver: return (Color(red: 0.5, green: 0.6, blue: 0.76), Color(red: 0.9, green: 0.94, blue: 1), Color(red: 0.45, green: 0.8, blue: 1))
        case .gold: return (Color(red: 0.93, green: 0.62, blue: 0.12), Color(red: 1, green: 0.9, blue: 0.45), Color(red: 1, green: 0.3, blue: 0.3))
        case .magic: return (Color(red: 0.48, green: 0.28, blue: 0.86), Color(red: 0.4, green: 0.9, blue: 1), Color(red: 1, green: 0.45, blue: 0.85))
        case .legendary: return (Color(red: 0.22, green: 0.17, blue: 0.36), Color(red: 1, green: 0.6, blue: 0.16), Color(red: 1, green: 0.85, blue: 0.3))
        }
    }

    /// Glow and light-ray color when it opens.
    var glow: Color {
        switch self {
        case .wooden: return Theme.yellow
        case .silver: return Color(red: 0.6, green: 0.85, blue: 1)
        case .gold: return Color(red: 1, green: 0.8, blue: 0.25)
        case .magic: return Color(red: 0.8, green: 0.5, blue: 1)
        case .legendary: return Color(red: 1, green: 0.6, blue: 0.2)
        }
    }
}

/// A treasure chest drawing. `openAmount` (0–1) lifts the lid and lets the light out.
struct ChestIcon: View {
    var kind: ChestKind = .wooden
    var size: CGFloat = 40
    var openAmount: Double = 0

    var body: some View {
        Canvas { context, canvas in
            let w = canvas.width, h = canvas.height
            let line = max(1.5, w * 0.05)
            let colors = kind.palette

            // Light from inside.
            if openAmount > 0 {
                let center = CGPoint(x: w / 2, y: h * 0.45)
                context.fill(Path(ellipseIn: CGRect(x: center.x - w * 0.6, y: center.y - h * 0.6, width: w * 1.2, height: h * 1.2)),
                             with: .radialGradient(Gradient(colors: [kind.glow.opacity(0.9 * openAmount), kind.glow.opacity(0)]),
                                                   center: center, startRadius: 0, endRadius: w * 0.6))
            }

            // Box.
            let boxRect = CGRect(x: w * 0.08, y: h * 0.44, width: w * 0.84, height: h * 0.46)
            let box = Path(roundedRect: boxRect, cornerRadius: w * 0.07)
            context.fill(box, with: .linearGradient(Gradient(colors: [colors.body, colors.body.mix(with: Theme.ink, by: 0.35)]),
                                                    startPoint: CGPoint(x: 0, y: boxRect.minY), endPoint: CGPoint(x: 0, y: boxRect.maxY)))
            context.stroke(box, with: .color(Theme.ink), lineWidth: line)
            var boxBands = Path()
            boxBands.addRect(CGRect(x: w * 0.23, y: boxRect.minY, width: w * 0.1, height: boxRect.height))
            boxBands.addRect(CGRect(x: w * 0.67, y: boxRect.minY, width: w * 0.1, height: boxRect.height))
            context.fill(boxBands, with: .color(colors.trim))
            context.stroke(boxBands, with: .color(Theme.ink), lineWidth: line * 0.7)
            if kind >= .gold {
                for x in [0.14, 0.86] {
                    let stud = Path(ellipseIn: CGRect(x: w * x - w * 0.04, y: boxRect.maxY - h * 0.13, width: w * 0.08, height: w * 0.08))
                    context.fill(stud, with: .color(colors.trim))
                    context.stroke(stud, with: .color(Theme.ink), lineWidth: line * 0.5)
                }
            }

            // Lid: lifts and tilts back as it opens.
            var lidContext = context
            lidContext.translateBy(x: w * 0.5, y: h * 0.46)
            lidContext.rotate(by: .degrees(-28 * openAmount))
            lidContext.translateBy(x: -w * 0.5 + w * 0.04 * openAmount, y: -h * 0.46 - h * 0.22 * openAmount)
            let lidRect = CGRect(x: w * 0.06, y: h * 0.14, width: w * 0.88, height: h * 0.34)
            let lid = Path(roundedRect: lidRect, cornerRadii: RectangleCornerRadii(topLeading: w * 0.2, bottomLeading: w * 0.04,
                                                                                   bottomTrailing: w * 0.04, topTrailing: w * 0.2))
            lidContext.fill(lid, with: .linearGradient(Gradient(colors: [colors.body.mix(with: .white, by: 0.2), colors.body]),
                                                       startPoint: CGPoint(x: 0, y: lidRect.minY), endPoint: CGPoint(x: 0, y: lidRect.maxY)))
            // Gloss.
            lidContext.fill(Path(roundedRect: CGRect(x: w * 0.16, y: h * 0.18, width: w * 0.5, height: h * 0.06), cornerRadius: h * 0.03),
                            with: .color(.white.opacity(0.35)))
            lidContext.stroke(lid, with: .color(Theme.ink), lineWidth: line)
            var lidBands = Path()
            lidBands.addRect(CGRect(x: w * 0.23, y: lidRect.minY + h * 0.02, width: w * 0.1, height: lidRect.height - h * 0.02))
            lidBands.addRect(CGRect(x: w * 0.67, y: lidRect.minY + h * 0.02, width: w * 0.1, height: lidRect.height - h * 0.02))
            lidContext.fill(lidBands, with: .color(colors.trim))
            lidContext.stroke(lidBands, with: .color(Theme.ink), lineWidth: line * 0.7)
            if kind == .legendary {
                // A little crown on top.
                var crown = Path()
                crown.move(to: CGPoint(x: w * 0.36, y: lidRect.minY + h * 0.02))
                crown.addLine(to: CGPoint(x: w * 0.38, y: lidRect.minY - h * 0.1))
                crown.addLine(to: CGPoint(x: w * 0.44, y: lidRect.minY - h * 0.03))
                crown.addLine(to: CGPoint(x: w * 0.5, y: lidRect.minY - h * 0.13))
                crown.addLine(to: CGPoint(x: w * 0.56, y: lidRect.minY - h * 0.03))
                crown.addLine(to: CGPoint(x: w * 0.62, y: lidRect.minY - h * 0.1))
                crown.addLine(to: CGPoint(x: w * 0.64, y: lidRect.minY + h * 0.02))
                crown.closeSubpath()
                lidContext.fill(crown, with: .color(colors.gem))
                lidContext.stroke(crown, with: .color(Theme.ink), lineWidth: line * 0.6)
            }

            // Lock (with a gem on the better chests).
            let lock = Path(roundedRect: CGRect(x: w * 0.4, y: h * 0.4, width: w * 0.2, height: h * 0.2), cornerRadius: w * 0.04)
            context.fill(lock, with: .color(colors.trim))
            context.stroke(lock, with: .color(Theme.ink), lineWidth: line * 0.7)
            if kind >= .silver {
                let gemRect = CGRect(x: w * 0.455, y: h * 0.44, width: w * 0.09, height: h * 0.1)
                var gem = Path()
                gem.move(to: CGPoint(x: gemRect.midX, y: gemRect.minY))
                gem.addLine(to: CGPoint(x: gemRect.maxX, y: gemRect.midY))
                gem.addLine(to: CGPoint(x: gemRect.midX, y: gemRect.maxY))
                gem.addLine(to: CGPoint(x: gemRect.minX, y: gemRect.midY))
                gem.closeSubpath()
                context.fill(gem, with: .color(colors.gem))
                context.stroke(gem, with: .color(Theme.ink), lineWidth: line * 0.4)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Opening animation

/// The chest drops in, waits for a tap, shakes harder and harder, then bursts open with light, a shower of
/// sparks and coins, and flips its cards out one by one onto a collection-style grid.
struct ChestOpenOverlay: View {
    let opening: ChestOpening
    let profile: ProfileStore
    let onDone: () -> Void

    private enum Stage: Int { case dropping, waiting, shaking, burst, cards, done }
    @State private var stage: Stage = .dropping
    @State private var wobble = false
    @State private var shake = 0.0
    @State private var flash = 0.0
    @State private var burstDate: Date?
    @State private var shownCoins = 0
    @State private var revealed = 0
    @State private var bigReveal: Rarity?

    private var kind: ChestKind { opening.kind }
    private var cards: [(id: String, count: Int)] { opening.contents.cards }

    var body: some View {
        ZStack {
            // Rays live in the backdrop's overlay so their size never stretches the layout.
            Theme.ink.opacity(0.92).ignoresSafeArea()
                .overlay {
                    if stage.rawValue >= Stage.burst.rawValue {
                        LightRays(color: kind.glow)
                            .frame(width: 900, height: 900)
                            .offset(y: stage == .burst ? 40 : -150)
                            .transition(.opacity)
                            .allowsHitTesting(false)
                    }
                }
                .clipped()
                .ignoresSafeArea()

            VStack(spacing: 14) {
                OutlinedText(opening.count > 1 ? String(localized: "\(opening.count) CHESTS") : kind.name.localized.uppercased(),
                             size: 30, fill: kind.glow, outline: 3.5)
                    .fixedSize()

                chest
                    .frame(height: 130)
                    .zIndex(1)

                if stage.rawValue >= Stage.burst.rawValue {
                    CoinLabel(amount: shownCoins, size: 24, textColor: .white)
                        .padding(.horizontal, 14).padding(.vertical, 6)
                        .background(Capsule().fill(Color.white.opacity(0.12)))
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.3), lineWidth: 1.5))
                        .transition(.scale(scale: 0.3).combined(with: .opacity))
                }

                Group {
                    // Open All can hold many stacks: scroll them under the chest.
                    if cards.count > 8 {
                        ScrollView { cardGrid.padding(.vertical, 10).padding(.horizontal, 6) }
                            .scrollIndicators(.hidden)
                            .frame(maxHeight: 360)
                    } else {
                        cardGrid
                    }
                }
                .opacity(stage.rawValue >= Stage.burst.rawValue ? 1 : 0)

                Group {
                    if stage == .done {
                        Button("Collect", action: onDone)
                            .buttonStyle(CartoonButtonStyle(fill: Theme.yellow, fontSize: 20))
                            .transition(.scale(scale: 0.6).combined(with: .opacity))
                    } else {
                        Color.clear
                    }
                }
                .frame(height: 56)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: 520)

            if let bigReveal {
                OutlinedText(String(localized: "\(bigReveal.name.localized.uppercased())!"), size: 46, fill: bigReveal.color, outline: 4.5)
                    .fixedSize()
                    .rotationEffect(.degrees(-8))
                    .transition(.scale(scale: 2.5).combined(with: .opacity))
                    .allowsHitTesting(false)
            }

            Color.white.opacity(flash).ignoresSafeArea().allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: tapped)
        .sensoryFeedback(.impact(weight: .heavy, intensity: 1), trigger: burstDate) { _, _ in GameSettings.vibrationEnabled }
        .sensoryFeedback(.impact(weight: .light), trigger: revealed) { _, _ in GameSettings.vibrationEnabled }
        .task { await drop() }
    }

    // MARK: Pieces

    private var chest: some View {
        let open = stage.rawValue >= Stage.burst.rawValue
        let waiting = stage == .waiting
        let bigChest = stage.rawValue < Stage.burst.rawValue
        return ChestIcon(kind: kind, size: 150, openAmount: open ? 1 : 0)
            .shadow(color: kind.glow.opacity(open ? 0.9 : waiting ? 0.5 : 0), radius: open ? 30 : 14)
            .rotationEffect(.degrees(waiting ? (wobble ? 4 : -4) : 0) + .degrees(sin(shake * 40) * 9 * min(1, shake)))
            .offset(x: sin(shake * 55) * 7 * shake)
            .scaleEffect(bigChest ? 1.35 + shake * 0.15 : 1)
            .overlay(alignment: .bottom) {
                if waiting {
                    OutlinedText("TAP TO OPEN!", size: 24, fill: .white, outline: 2.5)
                        .fixedSize()
                        .scaleEffect(wobble ? 1.08 : 0.94)
                        .offset(y: 100)
                        .transition(.opacity)
                }
            }
            .offset(y: stage == .dropping ? -700 : bigChest ? 150 : 0)
            .overlay {
                if let burstDate {
                    SparkBurst(start: burstDate, kind: kind)
                        .frame(width: 800, height: 800)
                        .offset(y: -10)
                        .allowsHitTesting(false)
                }
            }
    }

    private var cardGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 10) {
            ForEach(Array(cards.enumerated()), id: \.offset) { index, stack in
                if let base = FighterCatalog.definition(id: stack.id) {
                    FlipCard(angle: index < revealed ? 0 : 180) {
                        ChestCardTile(base: base, count: stack.count, isNew: opening.newBalls.contains(stack.id), profile: profile)
                    } back: {
                        CardBack(color: kind.palette.body)
                    }
                    .scaleEffect(index < revealed ? 1 : 0.6)
                    .offset(y: index < revealed ? 0 : -160)
                    .opacity(index < revealed ? 1 : 0)
                    .animation(.spring(duration: 0.55, bounce: 0.35), value: revealed)
                }
            }
        }
    }

    // MARK: Timing

    private func drop() async {
        withAnimation(.spring(duration: 0.6, bounce: 0.45)) { stage = .waiting }
        try? await Task.sleep(for: .seconds(0.5))
        withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) { wobble = true }
    }

    private func tapped() {
        switch stage {
        case .waiting: Task { await burstOpen() }
        case .burst, .cards: revealAll()
        case .done: onDone()
        default: break
        }
    }

    private func burstOpen() async {
        withAnimation(.default) { stage = .shaking; wobble = false }
        // Shake harder and harder.
        for step in 1...14 {
            withAnimation(.linear(duration: 0.05)) { shake = Double(step) / 14 + Double(step) * 0.017 }
            try? await Task.sleep(for: .seconds(0.05))
        }
        shake = 0
        flash = 0.95
        burstDate = .now
        withAnimation(.easeOut(duration: 0.5)) { flash = 0 }
        withAnimation(.spring(duration: 0.5, bounce: 0.45)) { stage = .burst }
        countCoins()
        try? await Task.sleep(for: .seconds(0.7))
        guard stage == .burst else { return }
        withAnimation(.spring(duration: 0.5, bounce: 0.3)) { stage = .cards }
        // Many stacks (Open All) flip faster and only stop for legendaries and new balls.
        let quick = cards.count > 8
        for (index, stack) in cards.enumerated() {
            guard stage == .cards else { return }
            revealed = index + 1
            let rarity = Progression.rarity(of: stack.id)
            if quick ? rarity == .legendary : rarity >= .epic {
                withAnimation(.spring(duration: 0.35, bounce: 0.5)) { bigReveal = rarity }
                try? await Task.sleep(for: .seconds(0.75))
                withAnimation(.easeOut(duration: 0.25)) { bigReveal = nil }
            }
            try? await Task.sleep(for: .seconds(quick ? 0.12 : 0.3))
        }
        finish()
    }

    private func countCoins() {
        let total = opening.contents.coins
        Task {
            for step in 1...12 {
                withAnimation(.snappy(duration: 0.08)) { shownCoins = total * step / 12 }
                try? await Task.sleep(for: .seconds(0.05))
            }
        }
    }

    private func revealAll() {
        bigReveal = nil
        revealed = cards.count
        shownCoins = opening.contents.coins
        finish()
    }

    private func finish() {
        guard stage != .done else { return }
        withAnimation(.spring(duration: 0.4, bounce: 0.4)) { stage = .done }
    }
}

/// A card won from a chest, styled like a Collection tile: portrait, name, level and card progress, plus "×count".
private struct ChestCardTile: View {
    let base: FighterDefinition
    let count: Int
    /// First card of this ball: it just unlocked.
    var isNew = false
    let profile: ProfileStore

    var body: some View {
        let level = profile.level(of: base.id)
        let shine = base.rarity >= .epic
        VStack(spacing: 3) {
            FighterPortrait(definition: profile.definition(base), color: base.rarity.color, size: 50, expression: .happy)
                .padding(.top, 4)
            Text(base.name)
                .font(Theme.bodyFont(11, weight: .black))
                .foregroundStyle(Theme.ink)
                .lineLimit(1).minimumScaleFactor(0.6)
            LevelBadge(level: level, size: 8)
            CardProgressBar(have: profile.cards(of: base.id), need: profile.upgradeCost(of: base.id)?.cards, height: 12)
        }
        .padding(.horizontal, 5).padding(.bottom, 6)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14).fill(LinearGradient(
                colors: [base.rarity.color.mix(with: .white, by: 0.3), base.rarity.color.mix(with: .white, by: 0.8)],
                startPoint: .top, endPoint: .bottom))
        )
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.ink, lineWidth: 2.5))
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.ink).offset(y: 4))
        .shadow(color: shine ? base.rarity.color.opacity(0.9) : .clear, radius: 12)
        .overlay(alignment: .topTrailing) {
            Text("×\(count)")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Capsule().fill(Theme.yellow))
                .overlay(Capsule().strokeBorder(Theme.ink, lineWidth: 2))
                .offset(x: 6, y: -8)
        }
        .overlay(alignment: .bottom) {
            if isNew {
                Text("NEW!")
                    .font(Theme.bodyFont(11, weight: .black))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(Capsule().fill(Theme.blood))
                    .overlay(Capsule().strokeBorder(Theme.ink, lineWidth: 2))
                    .rotationEffect(.degrees(-6))
                    .offset(y: 9)
            }
        }
        .overlay(alignment: .topLeading) {
            if profile.canUpgrade(base.id) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Theme.go))
                    .overlay(Circle().strokeBorder(Theme.ink, lineWidth: 2))
                    .offset(x: -5, y: -7)
            }
        }
    }
}

/// The back of a card before it flips.
private struct CardBack: View {
    let color: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(LinearGradient(colors: [color.mix(with: .white, by: 0.15), color.mix(with: Theme.ink, by: 0.4)],
                                 startPoint: .top, endPoint: .bottom))
            .overlay(Text("?").font(Theme.titleFont(34)).foregroundStyle(Theme.yellow))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.ink, lineWidth: 2.5))
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.ink).offset(y: 4))
    }
}

/// Flips around the vertical axis, showing the back past 90°.
private struct FlipCard<Front: View, Back: View>: View, Animatable {
    var angle: Double
    @ViewBuilder let front: Front
    @ViewBuilder let back: Back

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    var body: some View {
        ZStack {
            front.opacity(angle < 90 ? 1 : 0)
            back.opacity(angle < 90 ? 0 : 1)
        }
        .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
    }
}

/// Slowly turning light rays behind an opened chest.
private struct LightRays: View {
    let color: Color

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let turn = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 360) * 0.25
                let rays = 14
                for i in 0..<rays {
                    let a = turn + Double(i) * 2 * .pi / Double(rays)
                    var ray = Path()
                    ray.move(to: center)
                    ray.addLine(to: CGPoint(x: center.x + cos(a - 0.09) * size.width, y: center.y + sin(a - 0.09) * size.width))
                    ray.addLine(to: CGPoint(x: center.x + cos(a + 0.09) * size.width, y: center.y + sin(a + 0.09) * size.width))
                    ray.closeSubpath()
                    context.fill(ray, with: .radialGradient(Gradient(colors: [color.opacity(0.45), color.opacity(0)]),
                                                            center: center, startRadius: 0, endRadius: size.width * 0.45))
                }
            }
        }
    }
}

/// A burst of sparks, stars and coins flying out of the chest and falling.
private struct SparkBurst: View {
    let start: Date
    let kind: ChestKind

    private struct Spark {
        let angle: Double, speed: Double, spin: Double, size: Double, color: Color, shape: Int
    }

    private static let lifetime = 1.8

    private var sparks: [Spark] {
        var rng = SplitMix64(seed: UInt64(start.timeIntervalSinceReferenceDate * 1000))
        let colors = [kind.glow, kind.palette.trim, kind.palette.gem, .white, Theme.yellow]
        let count = 50 + kind.stacks * 8
        return (0..<count).map { _ in
            Spark(angle: Double.random(in: -.pi * 0.95 ... -.pi * 0.05, using: &rng),
                  speed: Double.random(in: 260...720, using: &rng),
                  spin: Double.random(in: -12...12, using: &rng),
                  size: Double.random(in: 5...13, using: &rng),
                  color: colors.randomElement(using: &rng)!,
                  shape: Int.random(in: 0..<3, using: &rng))
        }
    }

    var body: some View {
        let sparks = sparks
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSince(start)
                guard t < Self.lifetime else { return }
                let origin = CGPoint(x: size.width / 2, y: size.height / 2)
                let fade = max(0, 1 - t / Self.lifetime)
                for spark in sparks {
                    let x = origin.x + cos(spark.angle) * spark.speed * t
                    let y = origin.y + sin(spark.angle) * spark.speed * t + 700 * t * t
                    var piece = context
                    piece.opacity = fade
                    piece.translateBy(x: x, y: y)
                    piece.rotate(by: .radians(spark.spin * t))
                    let s = spark.size
                    switch spark.shape {
                    case 0:
                        piece.fill(Self.star(radius: s), with: .color(spark.color))
                        piece.stroke(Self.star(radius: s), with: .color(Theme.ink), lineWidth: 1.5)
                    case 1:
                        let coin = Path(ellipseIn: CGRect(x: -s * 0.8, y: -s * 0.8, width: s * 1.6, height: s * 1.6))
                        piece.fill(coin, with: .color(Theme.yellow))
                        piece.stroke(coin, with: .color(Theme.ink), lineWidth: 1.5)
                    default:
                        piece.fill(Path(roundedRect: CGRect(x: -s / 2, y: -s / 4, width: s, height: s / 2), cornerRadius: 2),
                                   with: .color(spark.color))
                    }
                }
            }
        }
    }

    private static func star(radius: Double) -> Path {
        var path = Path()
        for i in 0..<10 {
            let r = i.isMultiple(of: 2) ? radius : radius * 0.45
            let a = Double(i) * .pi / 5 - .pi / 2
            let point = CGPoint(x: cos(a) * r, y: sin(a) * r)
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Collection section

/// The player's unopened chests by type; tap one to open it.
struct ChestShelf: View {
    let model: AppModel

    var body: some View {
        let profile = model.profile
        let owned = ChestKind.allCases.reversed().filter { profile.chestCount($0) > 0 }
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("CHESTS")
                    .font(Theme.bodyFont(13, weight: .black))
                    .foregroundStyle(Theme.ink)
                Spacer()
                if profile.totalChests > 1 {
                    Button(action: model.openAllChests) {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                            Text("OPEN ALL \(profile.totalChests)")
                        }
                        .font(Theme.bodyFont(12, weight: .black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Capsule().fill(Theme.go))
                        .overlay(Capsule().strokeBorder(Theme.go.mix(with: Theme.ink, by: 0.62), lineWidth: 2))
                        .background(Capsule().fill(Theme.go.mix(with: Theme.ink, by: 0.62)).offset(y: 3))
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(owned.isEmpty ? String(localized: "None yet") : String(localized: "Tap a chest to open it"))
                        .font(Theme.bodyFont(11, weight: .heavy))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            if owned.isEmpty {
                HStack(spacing: 12) {
                    ChestIcon(kind: .wooden, size: 46).saturation(0).opacity(0.5)
                    Text("Win ranked battles, crusade bosses and VS Bot series to earn chests.")
                        .font(Theme.bodyFont(12, weight: .heavy))
                        .foregroundStyle(Theme.textSecondary)
                }
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 10) {
                    ForEach(owned, id: \.self) { kind in
                        Button { model.openChest(kind) } label: { tile(kind, count: profile.chestCount(kind)) }
                            .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(12)
        .cartoonCard(fill: Theme.cream, cornerRadius: 22, shadow: 6, lineWidth: 3.5)
    }

    /// The chest's name without "Chest", for the small tiles.
    private func shortName(_ kind: ChestKind) -> String {
        switch kind {
        case .wooden: String(localized: "Wooden", comment: "Short chest name")
        case .silver: String(localized: "Silver", comment: "Short chest name")
        case .gold: String(localized: "Gold", comment: "Short chest name")
        case .magic: String(localized: "Magic", comment: "Short chest name")
        case .legendary: String(localized: "Legendary", comment: "Short chest name")
        }
    }

    private func tile(_ kind: ChestKind, count: Int) -> some View {
        VStack(spacing: 2) {
            ChestIcon(kind: kind, size: 58)
            Text(shortName(kind))
                .font(Theme.bodyFont(11, weight: .black))
                .foregroundStyle(Theme.ink)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text("OPEN")
                .font(Theme.bodyFont(10, weight: .black))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 3)
                .background(Capsule().fill(Theme.go))
                .overlay(Capsule().strokeBorder(Theme.ink, lineWidth: 1.5))
        }
        .padding(.horizontal, 6).padding(.top, 4).padding(.bottom, 6)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14).fill(LinearGradient(
                colors: [kind.glow.mix(with: .white, by: 0.45), kind.glow.mix(with: .white, by: 0.8)],
                startPoint: .top, endPoint: .bottom))
        )
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.ink, lineWidth: 2.5))
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.ink).offset(y: 4))
        .overlay(alignment: .topTrailing) {
            if count > 1 {
                Text("×\(count)")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(Theme.blood))
                    .overlay(Capsule().strokeBorder(Theme.ink, lineWidth: 2))
                    .offset(x: 6, y: -7)
            }
        }
    }
}
