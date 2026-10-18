import SwiftUI

/// Chapter (map) picker and an illustrated trail of the chapter's levels, climbing from the start
/// at the bottom to the boss at the top.
struct CrusadeView: View {
    @Bindable var model: AppModel

    private var profile: ProfileStore { model.profile }
    private var chapterIndex: Int { model.crusadeChapter }
    private var chapter: CrusadeChapter { Crusade.chapters[chapterIndex] }
    private var difficulty: CrusadeDifficulty { model.crusadeDifficulty }
    /// First uncleared level that's open (where the player is on the trail).
    private var currentLevel: Int? {
        chapter.levels.map(\.number).first {
            profile.isUnlocked(chapter: chapterIndex, level: $0, difficulty: difficulty)
                && profile.stars(chapter: chapterIndex, level: $0, difficulty: difficulty) == 0
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    HStack {
                        BackButton(title: "Menu", action: model.showMenu)
                        Spacer()
                        WalletBar(model: model)
                    }

                    VStack(spacing: 4) {
                        ScreenTitle("CRUSADE")
                        ResetCountdown()
                    }

                    difficultyPicker

                    HStack(spacing: 12) {
                        ForEach(Crusade.chapters.indices, id: \.self) { index in
                            chapterCard(index)
                        }
                    }

                    if !profile.isUnlocked(chapter: chapterIndex, level: 1, difficulty: difficulty) {
                        Text(lockedMessage)
                            .font(Theme.bodyFont(14, weight: .heavy))
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.center)
                            .padding(10)
                            .cartoonCard(fill: Theme.yellow, cornerRadius: 14, shadow: 3, lineWidth: 2.5)
                    }

                    CrusadeTrail(model: model, chapterIndex: chapterIndex, difficulty: difficulty, currentLevel: currentLevel)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .onAppear { scrollToCurrent(proxy, animated: false) }
            .onChange(of: chapterIndex) { scrollToCurrent(proxy, animated: true) }
            .onChange(of: difficulty) { scrollToCurrent(proxy, animated: true) }
        }
    }

    private func scrollToCurrent(_ proxy: ScrollViewProxy, animated: Bool) {
        guard let level = currentLevel ?? chapter.levels.last?.number else { return }
        let id = "level-\(chapterIndex)-\(level)"
        if animated {
            withAnimation(.easeInOut(duration: 0.5)) { proxy.scrollTo(id, anchor: .center) }
        } else {
            DispatchQueue.main.async { proxy.scrollTo(id, anchor: .center) }
        }
    }

    private var lockedMessage: String {
        if difficulty == .hard { return String(localized: "Beat the Normal boss of \(chapter.map.name.localized) today to open Hard!") }
        return String(localized: "Defeat the boss of \(Crusade.chapters[chapterIndex - 1].map.name.localized) to open this map!")
    }

    private var difficultyPicker: some View {
        HStack(spacing: 8) {
            ForEach(CrusadeDifficulty.allCases, id: \.self) { option in
                let selected = difficulty == option
                Button {
                    withAnimation(.spring(duration: 0.3, bounce: 0.35)) { model.crusadeDifficulty = option }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: option == .normal ? "shield.fill" : "flame.fill")
                        Text(option.name.localized.uppercased())
                        if option == .hard {
                            Text("×2").font(Theme.bodyFont(11, weight: .black))
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(Capsule().fill(Theme.yellow))
                        }
                    }
                    .font(Theme.bodyFont(15, weight: .black))
                    .foregroundStyle(selected ? .white : Theme.ink)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .cartoonCard(fill: selected ? (option == .hard ? Theme.blood : PlayerSlot.one.color) : Theme.cream,
                                 cornerRadius: 14, shadow: selected ? 1 : 4, lineWidth: 3)
                    .offset(y: selected ? 3 : 0)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func chapterCard(_ index: Int) -> some View {
        let map = Crusade.chapters[index].map
        let unlocked = profile.isUnlocked(chapter: index, level: 1, difficulty: difficulty)
        let selected = chapterIndex == index
        return Button {
            withAnimation(.spring(duration: 0.3, bounce: 0.35)) { model.crusadeChapter = index }
        } label: {
            VStack(spacing: 6) {
                MapPreview(map: map)
                    .frame(height: 64)
                    .overlay {
                        if !unlocked {
                            Image(systemName: "lock.fill").font(.system(size: 26, weight: .black)).foregroundStyle(.white)
                                .shadow(color: Theme.ink, radius: 0, x: 2, y: 2)
                        }
                    }
                Text("\(index + 1). \(map.name.localized)")
                    .font(Theme.bodyFont(14, weight: .black))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1).minimumScaleFactor(0.7)
                HStack(spacing: 3) {
                    Image(systemName: "star.fill").foregroundStyle(Theme.yellow)
                    Text("\(profile.totalStars(chapter: index, difficulty: difficulty))/\(Crusade.chapters[index].maxStars)")
                        .foregroundStyle(Theme.ink)
                }
                .font(Theme.bodyFont(12, weight: .black))
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .cartoonCard(fill: selected ? Theme.yellow.mix(with: .white, by: 0.5) : Theme.cream, cornerRadius: 18,
                         shadow: selected ? 1 : 5, lineWidth: 3)
            .offset(y: selected ? 3 : 0)
            .opacity(unlocked ? 1 : 0.7)
        }
        .buttonStyle(.plain)
    }
}

/// "Resets in 5h 12m", ticking twice a minute. `compact` draws it as a small pill (menu card).
struct ResetCountdown: View {
    var compact = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { timeline in
            let minutes = max(1, Int(Crusade.nextReset(after: timeline.date).timeIntervalSince(timeline.date) / 60))
            let text = String(localized: "\(minutes / 60)h \(minutes % 60)m")
            if compact {
                Label(text, systemImage: "clock.arrow.circlepath")
                    .font(Theme.bodyFont(12, weight: .black))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(.white))
                    .overlay(Capsule().strokeBorder(Theme.ink, lineWidth: 2))
            } else {
                Label("Resets in \(text)", systemImage: "clock.arrow.circlepath")
                    .font(Theme.bodyFont(13, weight: .black))
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
    }
}

// MARK: - Trail map

/// The chapter drawn as a board-game trail: themed scenery, a winding road, and level stops on it.
private struct CrusadeTrail: View {
    let model: AppModel
    let chapterIndex: Int
    let difficulty: CrusadeDifficulty
    let currentLevel: Int?

    private static let spacing: CGFloat = 124
    /// Room above the boss for the castle / volcano.
    private static let topPadding: CGFloat = 220
    private static let bottomPadding: CGFloat = 90

    private var chapter: CrusadeChapter { Crusade.chapters[chapterIndex] }
    private var height: CGFloat {
        Self.topPadding + Self.bottomPadding + CGFloat(chapter.levels.count - 1) * Self.spacing
    }

    /// Level 1 sits at the bottom; the path snakes left and right as it climbs.
    private func position(of number: Int, width: CGFloat) -> CGPoint {
        let x = width / 2 + CGFloat(sin(Double(number) * 1.25 + 0.4)) * width * 0.26
        let y = height - Self.bottomPadding - CGFloat(number - 1) * Self.spacing
        return CGPoint(x: x, y: y)
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let points = chapter.levels.map { position(of: $0.number, width: width) }
            let cleared = chapter.levels.filter {
                model.profile.stars(chapter: chapterIndex, level: $0.number, difficulty: difficulty) > 0
            }.count
            ZStack(alignment: .topLeading) {
                TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    Canvas { context, size in
                        TrailArt.draw(map: chapter.map, points: points, cleared: cleared, size: size, time: time,
                                      in: &context)
                        if difficulty == .hard {
                            // Hard: the land darkens toward the edges.
                            let rect = CGRect(origin: .zero, size: size)
                            context.fill(Path(rect), with: .radialGradient(
                                Gradient(colors: [.clear, Theme.blood.opacity(0.45)]),
                                center: CGPoint(x: size.width / 2, y: size.height / 2),
                                startRadius: size.width * 0.3, endRadius: size.height * 0.7))
                        }
                    }
                }
                // Invisible rows centered on each stop, so the trail can scroll to a level.
                VStack(spacing: 0) {
                    Color.clear.frame(height: Self.topPadding - Self.spacing / 2)
                    ForEach(chapter.levels.reversed(), id: \.number) { level in
                        Color.clear.frame(height: Self.spacing).id("level-\(chapterIndex)-\(level.number)")
                    }
                }
                .allowsHitTesting(false)
                ForEach(chapter.levels, id: \.number) { level in
                    let point = position(of: level.number, width: width)
                    LevelStop(model: model, chapterIndex: chapterIndex, difficulty: difficulty, level: level,
                              isCurrent: level.number == currentLevel)
                        .position(point)
                }
            }
        }
        .frame(height: height)
        .overlay(alignment: .bottomLeading) { ribbon.padding(14) }
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).strokeBorder(Theme.ink, lineWidth: 4))
        .background(RoundedRectangle(cornerRadius: 28).fill(Theme.ink).offset(y: 7))
    }
}

private extension CrusadeTrail {
    /// The map's name on a banner at the start of the trail.
    var ribbon: some View {
        HStack(spacing: 6) {
            Text("\(chapterIndex + 1)")
                .font(Theme.titleFont(14))
                .foregroundStyle(Theme.ink)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Theme.yellow))
                .overlay(Circle().strokeBorder(Theme.ink, lineWidth: 2))
            Text(chapter.map.name.localized.uppercased())
                .font(Theme.titleFont(14))
                .foregroundStyle(.white)
                .shadow(color: Theme.ink.opacity(0.8), radius: 0, x: 0, y: 1.5)
            if difficulty == .hard {
                Image(systemName: "flame.fill").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.yellow)
            }
        }
        .padding(.leading, 5).padding(.trailing, 12).padding(.vertical, 5)
        .background(Capsule().fill(difficulty == .hard ? Theme.blood : PlayerSlot.one.color.mix(with: Theme.ink, by: 0.25)))
        .overlay(Capsule().strokeBorder(Theme.ink, lineWidth: 3))
    }
}

/// One stop on the trail: number (or boss badge), stars, and the enemy waiting there.
private struct LevelStop: View {
    let model: AppModel
    let chapterIndex: Int
    let difficulty: CrusadeDifficulty
    let level: CrusadeLevel
    let isCurrent: Bool
    @State private var bounce = false

    var body: some View {
        let profile = model.profile
        let unlocked = profile.isUnlocked(chapter: chapterIndex, level: level.number, difficulty: difficulty)
        let stars = profile.stars(chapter: chapterIndex, level: level.number, difficulty: difficulty)
        let chestReward = stars == 0 ? Crusade.firstClearReward(chapter: chapterIndex, level: level.number,
                                                                difficulty: difficulty).chests.first : nil
        let size: CGFloat = level.isBoss ? 78 : 58
        let colors = stoneColors(unlocked: unlocked, cleared: stars > 0)
        Button {
            if unlocked { model.openCrusadeLevel(chapter: chapterIndex, level: level.number) }
        } label: {
            ZStack {
                // Pedestal shadow on the ground.
                Ellipse()
                    .fill(Theme.ink.opacity(0.3))
                    .frame(width: size * 1.25, height: size * 0.4)
                    .offset(y: size * 0.46)
                if isCurrent {
                    Circle()
                        .stroke(PlayerSlot.one.color, lineWidth: 5)
                        .frame(width: size + 20, height: size + 20)
                        .scaleEffect(bounce ? 1.12 : 0.95)
                        .opacity(bounce ? 0.25 : 0.95)
                }
                // 3D lip, then the glossy stone.
                Circle()
                    .fill(colors.bottom.mix(with: Theme.ink, by: 0.45))
                    .overlay(Circle().strokeBorder(Theme.ink, lineWidth: 4))
                    .frame(width: size, height: size)
                    .offset(y: 6)
                Circle()
                    .fill(LinearGradient(colors: [colors.top, colors.bottom], startPoint: .top, endPoint: .bottom))
                    .overlay(Circle().inset(by: 6).strokeBorder(.white.opacity(0.45), lineWidth: 2))
                    .overlay(Circle().strokeBorder(Theme.ink, lineWidth: 4))
                    .frame(width: size, height: size)
                Group {
                    if !unlocked {
                        Image(systemName: "lock.fill").font(.system(size: size * 0.34, weight: .bold))
                    } else if level.isBoss {
                        Image(systemName: "crown.fill").font(.system(size: size * 0.38, weight: .bold))
                    } else {
                        Text("\(level.number)").font(Theme.titleFont(size * 0.44))
                    }
                }
                .foregroundStyle(unlocked ? Theme.ink : Theme.ink.opacity(0.75))

                starsRow(stars)
                    .offset(y: size / 2 + 12)
                    .opacity(unlocked ? 1 : 0)

                if let chestReward {
                    ChestIcon(kind: chestReward, size: 24)
                        .padding(5)
                        .background(Circle().fill(.white))
                        .overlay(Circle().strokeBorder(Theme.ink, lineWidth: 2.5))
                        .offset(x: size / 2 + 6, y: -size / 2 + 4)
                }

                if isCurrent {
                    youMarker
                        .offset(y: -size / 2 - 32 - (bounce ? 6 : 0))
                }
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .onAppear {
            guard isCurrent else { return }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { bounce = true }
        }
    }

    /// Gold once cleared, crimson for an open boss, white when open, slate when locked.
    private func stoneColors(unlocked: Bool, cleared: Bool) -> (top: Color, bottom: Color) {
        if !unlocked { return (Color(red: 0.7, green: 0.72, blue: 0.8), Color(red: 0.5, green: 0.53, blue: 0.63)) }
        if cleared { return (Color(red: 1, green: 0.9, blue: 0.5), Color(red: 0.96, green: 0.66, blue: 0.1)) }
        if level.isBoss { return (Color(red: 1, green: 0.5, blue: 0.5), Color(red: 0.82, green: 0.16, blue: 0.24)) }
        return (.white, Color(red: 0.84, green: 0.86, blue: 0.92))
    }

    private func starsRow(_ stars: Int) -> some View {
        HStack(spacing: 1) {
            ForEach(1...3, id: \.self) { i in
                Image(systemName: "star.fill")
                    .font(.system(size: i == 2 ? 15 : 12, weight: .black))
                    .foregroundStyle(i <= stars ? Theme.yellow : Color.white.opacity(0.55))
                    .shadow(color: Theme.ink, radius: 0, x: 1, y: 1)
                    .offset(y: i == 2 ? 3 : 0)
            }
        }
    }

    private var youMarker: some View {
        VStack(spacing: 0) {
            Text("NEXT")
                .font(Theme.bodyFont(11, weight: .black))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Capsule().fill(Theme.yellow))
                .overlay(Capsule().strokeBorder(Theme.ink, lineWidth: 2.5))
            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(Theme.ink)
                .offset(y: -2)
        }
    }
}

/// Scenery and road for a chapter's trail map.
private enum TrailArt {
    static func draw(map: ArenaMap, points: [CGPoint], cleared: Int, size: CGSize, time: Double,
                     in context: inout GraphicsContext) {
        let rect = CGRect(origin: .zero, size: size)
        context.fill(Path(rect), with: .linearGradient(
            Gradient(colors: [map.floor.mix(with: .white, by: 0.08), map.floor, map.floor.mix(with: Theme.ink, by: 0.1)]),
            startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
        // The road runs on past the boss: up to the castle gate, or into the volcano.
        let roadEnd = CGPoint(x: size.width / 2, y: map == .meadow ? 136 : 172)
        let road = roadPath(points + [roadEnd], size: size)
        // A river crosses the road between levels 3 and 4, under a bridge.
        let bridge = points.count > 3
            ? CGPoint(x: (points[2].x + points[3].x) / 2, y: (points[2].y + points[3].y) / 2) : nil
        let river = bridge.map { riverPath(through: $0, width: size.width) }
        var avoid = samples(points)
        if let bridge {
            avoid += stride(from: 0.0, through: Double(size.width), by: 30).map {
                CGPoint(x: $0, y: Double(bridge.y) + sin(($0 - Double(bridge.x)) * 0.025) * 12)
            }
        }

        switch map {
        case .meadow: drawMeadow(size: size, time: time, avoid: avoid, river: river, in: &context)
        case .volcano: drawVolcano(size: size, time: time, avoid: avoid, river: river, in: &context)
        default: break
        }

        // Road: ink outline, a darker verge, the surface, and a dashed center that turns gold where cleared.
        let surface: Color = map == .volcano ? Color(red: 0.36, green: 0.29, blue: 0.29) : Color(red: 0.95, green: 0.85, blue: 0.62)
        context.stroke(road, with: .color(Theme.ink), style: StrokeStyle(lineWidth: 38, lineCap: .round, lineJoin: .round))
        context.stroke(road, with: .color(surface.mix(with: Theme.ink, by: 0.22)),
                       style: StrokeStyle(lineWidth: 31, lineCap: .round, lineJoin: .round))
        context.stroke(road, with: .color(surface), style: StrokeStyle(lineWidth: 23, lineCap: .round, lineJoin: .round))
        context.stroke(road, with: .color(Theme.ink.opacity(0.16)),
                       style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [2, 14]))
        if cleared > 0 {
            let done = roadPath(Array(points.prefix(cleared + 1)), size: size)
            context.stroke(done, with: .color(Theme.yellow), style: StrokeStyle(lineWidth: 5, lineCap: .round, dash: [10, 10]))
        }

        if let bridge, points.count > 3 {
            drawBridge(at: bridge, along: CGPoint(x: points[3].x - points[2].x, y: points[3].y - points[2].y),
                       stone: map == .volcano, in: &context)
        }

        // Landmarks go over the road, which runs into the castle gate or the volcano's foot.
        switch map {
        case .meadow: drawCastle(at: CGPoint(x: size.width / 2, y: 104), time: time, in: &context)
        case .volcano: drawVolcanoPeak(size: size, time: time, in: &context)
        default: break
        }

        if map == .meadow { drawClouds(size: size, time: time, in: &context) }

        // Start flag at the bottom of the trail.
        if let first = points.first {
            let side: CGFloat = first.x > size.width / 2 ? -86 : 86
            drawFlag(at: CGPoint(x: first.x + side, y: size.height - 18), color: PlayerSlot.one.color, in: &context)
        }
    }

    /// A gently winding river across the map that passes exactly through `point`.
    private static func riverPath(through point: CGPoint, width: CGFloat) -> Path {
        var path = Path()
        for x in stride(from: -20.0, through: Double(width) + 20, by: 6) {
            let y = Double(point.y) + sin((x - Double(point.x)) * 0.025) * 12
            if x == -20 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        return path
    }

    private static func drawRiver(_ river: Path, water: Color, glow: Color, time: Double, in context: inout GraphicsContext) {
        context.stroke(river, with: .color(Theme.ink), style: StrokeStyle(lineWidth: 32, lineCap: .round, lineJoin: .round))
        context.stroke(river, with: .color(water), style: StrokeStyle(lineWidth: 26, lineCap: .round, lineJoin: .round))
        context.stroke(river, with: .color(glow.opacity(0.7)),
                       style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [14, 22], dashPhase: -time * 18))
    }

    /// Planks (meadow) or a stone span (volcano) laid along the road where it crosses the river.
    private static func drawBridge(at center: CGPoint, along direction: CGPoint, stone: Bool, in context: inout GraphicsContext) {
        let angle = atan2(direction.y, direction.x)
        let transform = CGAffineTransform(translationX: center.x, y: center.y).rotated(by: angle)
        let deck = Path(roundedRect: CGRect(x: -26, y: -21, width: 52, height: 42), cornerRadius: 6).applying(transform)
        let wood = stone ? Color(red: 0.58, green: 0.55, blue: 0.6) : Color(red: 0.74, green: 0.5, blue: 0.3)
        context.fill(deck, with: .color(wood))
        var seams = Path()
        for x in stride(from: -18.0, through: 18, by: 9) {
            seams.move(to: CGPoint(x: x, y: -21)); seams.addLine(to: CGPoint(x: x, y: 21))
        }
        context.stroke(seams.applying(transform), with: .color(Theme.ink.opacity(0.35)), lineWidth: 2)
        context.stroke(deck, with: .color(Theme.ink), lineWidth: 3)
        for y in [-21.0, 21.0] {
            let rail = Path(roundedRect: CGRect(x: -28, y: y - 3.5, width: 56, height: 7), cornerRadius: 3.5).applying(transform)
            context.fill(rail, with: .color(wood.mix(with: Theme.ink, by: 0.3)))
            context.stroke(rail, with: .color(Theme.ink), lineWidth: 2.5)
        }
    }

    /// Soft clouds drifting across, with their shadows on the ground.
    private static func drawClouds(size: CGSize, time: Double, in context: inout GraphicsContext) {
        for k in 0..<3 {
            let speed = 10.0 + Double(k) * 4
            let span = Double(size.width) + 240
            let x = (time * speed + Double(k) * 230).truncatingRemainder(dividingBy: span) - 120
            let y = Double(size.height) * (0.22 + Double(k) * 0.28)
            let cloud = Path { path in
                path.addEllipse(in: CGRect(x: x - 50, y: y - 14, width: 60, height: 34))
                path.addEllipse(in: CGRect(x: x - 20, y: y - 28, width: 56, height: 44))
                path.addEllipse(in: CGRect(x: x + 14, y: y - 12, width: 52, height: 32))
            }
            context.fill(cloud.offsetBy(dx: 18, dy: 60), with: .color(Theme.ink.opacity(0.06)))
            context.fill(cloud, with: .color(.white.opacity(0.5)))
        }
    }

    /// Smooth road through every stop, running off the bottom (start) and up to the boss.
    private static func roadPath(_ points: [CGPoint], size: CGSize) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        let start = CGPoint(x: first.x, y: size.height + 20)
        path.move(to: start)
        var previous = start
        for point in points {
            let mid = CGPoint(x: (previous.x + point.x) / 2, y: (previous.y + point.y) / 2)
            path.addQuadCurve(to: mid, control: CGPoint(x: previous.x, y: mid.y))
            path.addQuadCurve(to: point, control: CGPoint(x: point.x, y: mid.y))
            previous = point
        }
        return path
    }

    /// Points along the road, so scenery can keep clear of it.
    private static func samples(_ points: [CGPoint]) -> [CGPoint] {
        var result: [CGPoint] = []
        for (a, b) in zip(points, points.dropFirst()) {
            for k in 0...6 {
                let t = CGFloat(k) / 6
                result.append(CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t))
            }
        }
        return result + points
    }

    /// Random scenery spots away from the road and the level stops.
    private static func spots(_ count: Int, seed: UInt64, size: CGSize, avoid: [CGPoint], clearance: CGFloat) -> [CGPoint] {
        var rng = SplitMix64(seed: seed)
        var result: [CGPoint] = []
        var attempts = 0
        while result.count < count && attempts < count * 30 {
            attempts += 1
            let p = CGPoint(x: Double.random(in: 10...(Double(size.width) - 10), using: &rng),
                            y: Double.random(in: 10...(Double(size.height) - 10), using: &rng))
            // Keep clear of the road and of the other scenery placed in this batch.
            if avoid.allSatisfy({ hypot($0.x - p.x, $0.y - p.y) > clearance }),
               result.allSatisfy({ hypot($0.x - p.x, $0.y - p.y) > clearance * 0.8 }) { result.append(p) }
        }
        return result
    }

    // MARK: Meadow

    private static func drawMeadow(size: CGSize, time: Double, avoid: [CGPoint], river: Path?,
                                   in context: inout GraphicsContext) {
        let leaf = Color(red: 0.27, green: 0.62, blue: 0.32)
        let pine = Color(red: 0.18, green: 0.5, blue: 0.34)
        // Rolling hills: lighter mounds with a shaded underside.
        for p in spots(9, seed: 1, size: size, avoid: [], clearance: 120) {
            let hill = Path(ellipseIn: CGRect(x: p.x - 80, y: p.y - 36, width: 160, height: 72))
            context.fill(hill, with: .linearGradient(
                Gradient(colors: [Color(red: 0.78, green: 0.92, blue: 0.56), Color(red: 0.6, green: 0.82, blue: 0.42)]),
                startPoint: CGPoint(x: p.x, y: p.y - 36), endPoint: CGPoint(x: p.x, y: p.y + 36)))
        }
        if let river {
            drawRiver(river, water: Color(red: 0.36, green: 0.7, blue: 0.95), glow: .white, time: time, in: &context)
        }
        // Rocks.
        for (i, p) in spots(8, seed: 9, size: size, avoid: avoid, clearance: 44).enumerated() {
            let r = CGFloat(8 + (i % 3) * 3)
            let rock = Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r * 0.7, width: r * 2, height: r * 1.4))
            context.fill(rock, with: .color(Color(red: 0.72, green: 0.72, blue: 0.76)))
            context.fill(Path(ellipseIn: CGRect(x: p.x - r * 0.6, y: p.y - r * 0.55, width: r, height: r * 0.5)),
                         with: .color(.white.opacity(0.45)))
            context.stroke(rock, with: .color(Theme.ink), lineWidth: 2)
        }
        // Bushes.
        for p in spots(10, seed: 10, size: size, avoid: avoid, clearance: 40) {
            let bush = Path { path in
                path.addEllipse(in: CGRect(x: p.x - 16, y: p.y - 10, width: 18, height: 16))
                path.addEllipse(in: CGRect(x: p.x - 6, y: p.y - 15, width: 20, height: 20))
                path.addEllipse(in: CGRect(x: p.x + 6, y: p.y - 9, width: 16, height: 14))
            }
            context.fill(bush, with: .color(leaf.mix(with: .white, by: 0.12)))
            context.stroke(bush, with: .color(Theme.ink), lineWidth: 2)
        }
        // Trees: a mix of round trees and pines, swaying a little. Drawn top to bottom so nearer ones overlap.
        let trees = spots(18, seed: 3, size: size, avoid: avoid, clearance: 58).enumerated()
            .filter { $0.element.y > 200 || abs($0.element.x - size.width / 2) > 130 }
            .sorted { $0.element.y < $1.element.y }
        for (i, p) in trees {
            let sway = CGFloat(sin(time * 1.2 + Double(i))) * 1.5
            if i.isMultiple(of: 3) {
                drawPine(at: p, sway: sway, in: &context)
            } else {
                drawRoundTree(at: p, sway: sway, scale: i.isMultiple(of: 2) ? 1 : 0.85, in: &context)
            }
        }
        drawCastleMound(at: CGPoint(x: size.width / 2, y: 104), in: &context)

        // Flowers.
        let petals: [Color] = [.white, Color(red: 1, green: 0.55, blue: 0.7), Color(red: 1, green: 0.85, blue: 0.3)]
        for (i, p) in spots(24, seed: 4, size: size, avoid: avoid, clearance: 34).enumerated() {
            for k in 0..<5 {
                let a = Double(k) / 5 * 2 * .pi + sin(time + Double(i)) * 0.15
                context.fill(FighterArt.circle(FighterArt.point(p, 4, a), 3.2), with: .color(petals[i % petals.count]))
            }
            context.fill(FighterArt.circle(p, 2.2), with: .color(Theme.yellow))
        }
    }

    // MARK: Trees

    private static let bark = Color(red: 0.5, green: 0.32, blue: 0.18)

    /// Trunk with roots and a bark line, plus a soft ground shadow.
    private static func drawTrunk(at p: CGPoint, height: CGFloat, width: CGFloat, in context: inout GraphicsContext) {
        context.fill(Path(ellipseIn: CGRect(x: p.x - width * 2.6, y: p.y - 6, width: width * 5.2, height: 14)),
                     with: .color(Theme.ink.opacity(0.2)))
        var trunk = Path()
        trunk.move(to: CGPoint(x: p.x - width * 0.9, y: p.y))
        trunk.addQuadCurve(to: CGPoint(x: p.x - width * 0.45, y: p.y - height), control: CGPoint(x: p.x - width * 0.4, y: p.y - height * 0.4))
        trunk.addLine(to: CGPoint(x: p.x + width * 0.45, y: p.y - height))
        trunk.addQuadCurve(to: CGPoint(x: p.x + width * 0.9, y: p.y), control: CGPoint(x: p.x + width * 0.4, y: p.y - height * 0.4))
        trunk.closeSubpath()
        context.fill(trunk, with: .linearGradient(Gradient(colors: [bark.mix(with: .white, by: 0.15), bark.mix(with: Theme.ink, by: 0.25)]),
                                                  startPoint: CGPoint(x: p.x - width, y: p.y), endPoint: CGPoint(x: p.x + width, y: p.y)))
        var grain = Path()
        grain.move(to: CGPoint(x: p.x + width * 0.1, y: p.y - 3))
        grain.addQuadCurve(to: CGPoint(x: p.x, y: p.y - height * 0.8), control: CGPoint(x: p.x + width * 0.35, y: p.y - height * 0.45))
        context.stroke(grain, with: .color(Theme.ink.opacity(0.35)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        context.stroke(trunk, with: .color(Theme.ink), style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
    }

    /// A leafy tree: several shaded clumps, lit from the top left, with leaf highlights.
    private static func drawRoundTree(at p: CGPoint, sway: CGFloat, scale k: CGFloat, in context: inout GraphicsContext) {
        drawTrunk(at: p, height: 26 * k, width: 6 * k, in: &context)
        let top = CGPoint(x: p.x + sway, y: p.y - 26 * k)
        let clumps: [(CGFloat, CGFloat, CGFloat)] = [(-17, -8, 15), (17, -8, 15), (0, -4, 17), (-10, -24, 16), (11, -25, 16), (0, -36, 15)]
        var canopy = Path()
        for (dx, dy, r) in clumps {
            canopy.addEllipse(in: CGRect(x: top.x + (dx - r) * k, y: top.y + (dy - r) * k, width: 2 * r * k, height: 2 * r * k))
        }
        let light = Color(red: 0.47, green: 0.78, blue: 0.36)
        let dark = Color(red: 0.16, green: 0.46, blue: 0.24)
        context.stroke(canopy, with: .color(Theme.ink), lineWidth: 5)
        context.fill(canopy, with: .radialGradient(Gradient(colors: [light, Color(red: 0.3, green: 0.62, blue: 0.3), dark]),
                                                   center: CGPoint(x: top.x - 12 * k, y: top.y - 34 * k),
                                                   startRadius: 2, endRadius: 52 * k))
        // Shade the underside of each lower clump, then a few leaf highlights on top.
        context.drawLayer { layer in
            layer.clip(to: canopy)
            for (dx, dy, r) in clumps where dy > -10 {
                layer.fill(Path(ellipseIn: CGRect(x: top.x + (dx - r) * k, y: top.y + (dy + r * 0.35) * k, width: 2 * r * k, height: r * k)),
                           with: .color(dark.opacity(0.55)))
            }
        }
        for (dx, dy) in [(-12.0, -30.0), (4.0, -40.0), (-20.0, -12.0), (10.0, -20.0)] {
            var leafMark = Path()
            let c = CGPoint(x: top.x + CGFloat(dx) * k, y: top.y + CGFloat(dy) * k)
            leafMark.addArc(center: c, radius: 5 * k, startAngle: .degrees(200), endAngle: .degrees(320), clockwise: false)
            context.stroke(leafMark, with: .color(.white.opacity(0.5)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
    }

    /// A pine: three tiers, each with a lit left edge and a shaded underside.
    private static func drawPine(at p: CGPoint, sway: CGFloat, in context: inout GraphicsContext) {
        drawTrunk(at: p, height: 16, width: 5.5, in: &context)
        let needle = Color(red: 0.15, green: 0.46, blue: 0.33)
        let tiers: [(base: CGFloat, half: CGFloat, height: CGFloat)] = [(p.y - 12, 26, 30), (p.y - 30, 21, 27), (p.y - 46, 15, 24)]
        for (index, tier) in tiers.enumerated() {
            let lean = sway * CGFloat(index + 1) * 0.6
            var shape = Path()
            shape.move(to: CGPoint(x: p.x - tier.half + lean * 0.5, y: tier.base))
            shape.addQuadCurve(to: CGPoint(x: p.x + lean, y: tier.base - tier.height),
                               control: CGPoint(x: p.x - tier.half * 0.35 + lean, y: tier.base - tier.height * 0.45))
            shape.addQuadCurve(to: CGPoint(x: p.x + tier.half + lean * 0.5, y: tier.base),
                               control: CGPoint(x: p.x + tier.half * 0.35 + lean, y: tier.base - tier.height * 0.45))
            // Scalloped hem along the bottom edge.
            let scallops = 4
            for k in stride(from: scallops, to: 0, by: -1) {
                let x0 = p.x - tier.half + lean * 0.5 + CGFloat(k) * tier.half * 2 / CGFloat(scallops)
                let x1 = x0 - tier.half * 2 / CGFloat(scallops)
                shape.addQuadCurve(to: CGPoint(x: x1, y: tier.base), control: CGPoint(x: (x0 + x1) / 2, y: tier.base + 6))
            }
            shape.closeSubpath()
            context.fill(shape, with: .linearGradient(Gradient(colors: [needle.mix(with: .white, by: 0.3), needle, needle.mix(with: Theme.ink, by: 0.3)]),
                                                      startPoint: CGPoint(x: p.x - tier.half, y: tier.base - tier.height),
                                                      endPoint: CGPoint(x: p.x + tier.half, y: tier.base)))
            context.stroke(shape, with: .color(Theme.ink), style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
        }
    }

    // MARK: Castle

    /// The rocky mound under the castle; drawn before the road so the road climbs onto it.
    private static func drawCastleMound(at c: CGPoint, in context: inout GraphicsContext) {
        let mound = Path(ellipseIn: CGRect(x: c.x - 110, y: c.y + 26, width: 220, height: 40))
        context.fill(mound, with: .color(Color(red: 0.55, green: 0.5, blue: 0.48)))
        context.stroke(mound, with: .color(Theme.ink), lineWidth: 3)
    }

    /// The boss's keep: brick walls shaded on one side, battlements, round towers with cone roofs and
    /// waving flags, lit windows, and an arched gate with a portcullis.
    private static func drawCastle(at c: CGPoint, time: Double, in context: inout GraphicsContext) {
        let stone = Color(red: 0.8, green: 0.78, blue: 0.86)
        let stoneDark = Color(red: 0.6, green: 0.58, blue: 0.7)
        let roof = Color(red: 0.8, green: 0.2, blue: 0.27)
        let shade = Gradient(colors: [stone.mix(with: .white, by: 0.2), stone, stoneDark])

        func bricks(in rect: CGRect) {
            var lines = Path()
            var row = 0
            var y = rect.minY + 9
            while y < rect.maxY - 2 {
                lines.move(to: CGPoint(x: rect.minX + 2, y: y)); lines.addLine(to: CGPoint(x: rect.maxX - 2, y: y))
                var x = rect.minX + (row.isMultiple(of: 2) ? 8 : 16)
                while x < rect.maxX - 4 {
                    lines.move(to: CGPoint(x: x, y: y - 9)); lines.addLine(to: CGPoint(x: x, y: y))
                    x += 16
                }
                y += 9
                row += 1
            }
            context.stroke(lines, with: .color(Theme.ink.opacity(0.18)), lineWidth: 1.2)
        }

        // Curtain wall with battlements.
        let wallRect = CGRect(x: c.x - 66, y: c.y - 8, width: 132, height: 44)
        var wall = Path(wallRect)
        for x in stride(from: wallRect.minX, to: wallRect.maxX - 4, by: 16) {
            wall.addRect(CGRect(x: x + 2, y: wallRect.minY - 9, width: 10, height: 10))
        }
        context.fill(wall, with: .linearGradient(shade, startPoint: CGPoint(x: wallRect.minX, y: 0), endPoint: CGPoint(x: wallRect.maxX, y: 0)))
        bricks(in: wallRect)
        context.stroke(wall, with: .color(Theme.ink), style: StrokeStyle(lineWidth: 3, lineJoin: .round))

        // Gate: arch, portcullis bars, and a banner above.
        let gateRect = CGRect(x: c.x - 15, y: c.y + 6, width: 30, height: 30)
        var gate = Path()
        gate.move(to: CGPoint(x: gateRect.minX, y: gateRect.maxY))
        gate.addLine(to: CGPoint(x: gateRect.minX, y: gateRect.minY + 15))
        gate.addArc(center: CGPoint(x: gateRect.midX, y: gateRect.minY + 15), radius: 15, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        gate.addLine(to: CGPoint(x: gateRect.maxX, y: gateRect.maxY))
        gate.closeSubpath()
        context.fill(gate, with: .color(Color(red: 0.16, green: 0.12, blue: 0.24)))
        context.drawLayer { layer in
            layer.clip(to: gate)
            var bars = Path()
            for x in stride(from: gateRect.minX + 5, to: gateRect.maxX, by: 6) {
                bars.move(to: CGPoint(x: x, y: gateRect.minY)); bars.addLine(to: CGPoint(x: x, y: gateRect.maxY))
            }
            for y in stride(from: gateRect.minY + 8, to: gateRect.maxY, by: 8) {
                bars.move(to: CGPoint(x: gateRect.minX, y: y)); bars.addLine(to: CGPoint(x: gateRect.maxX, y: y))
            }
            layer.stroke(bars, with: .color(Color(red: 0.55, green: 0.55, blue: 0.62)), lineWidth: 1.8)
        }
        context.stroke(gate, with: .color(Theme.ink), lineWidth: 3)
        var banner = Path()
        banner.move(to: CGPoint(x: c.x - 9, y: wallRect.minY + 2))
        banner.addLine(to: CGPoint(x: c.x + 9, y: wallRect.minY + 2))
        banner.addLine(to: CGPoint(x: c.x + 9, y: wallRect.minY + 14))
        banner.addLine(to: CGPoint(x: c.x, y: wallRect.minY + 10))
        banner.addLine(to: CGPoint(x: c.x - 9, y: wallRect.minY + 14))
        banner.closeSubpath()
        context.fill(banner, with: .color(roof))
        context.stroke(banner, with: .color(Theme.ink), style: StrokeStyle(lineWidth: 2, lineJoin: .round))

        // Two round towers with lit windows, cone roofs and flags.
        for (index, x) in [c.x - 70, c.x + 70].enumerated() {
            let towerRect = CGRect(x: x - 18, y: c.y - 34, width: 36, height: 70)
            let tower = Path(roundedRect: towerRect, cornerRadius: 4)
            context.fill(tower, with: .linearGradient(shade, startPoint: CGPoint(x: towerRect.minX, y: 0),
                                                      endPoint: CGPoint(x: towerRect.maxX, y: 0)))
            bricks(in: towerRect)
            context.stroke(tower, with: .color(Theme.ink), lineWidth: 3)
            let window = Path(roundedRect: CGRect(x: x - 5, y: c.y - 20, width: 10, height: 15), cornerRadius: 5)
            let flicker = 0.75 + 0.25 * sin(time * 3 + Double(index))
            context.fill(window, with: .color(Color(red: 1, green: 0.8, blue: 0.35).opacity(flicker)))
            context.stroke(window, with: .color(Theme.ink), lineWidth: 2)

            var cone = Path()
            cone.move(to: CGPoint(x: x - 24, y: towerRect.minY + 2))
            cone.addQuadCurve(to: CGPoint(x: x, y: towerRect.minY - 38), control: CGPoint(x: x - 8, y: towerRect.minY - 14))
            cone.addQuadCurve(to: CGPoint(x: x + 24, y: towerRect.minY + 2), control: CGPoint(x: x + 8, y: towerRect.minY - 14))
            cone.closeSubpath()
            context.fill(cone, with: .linearGradient(Gradient(colors: [roof.mix(with: .white, by: 0.25), roof, roof.mix(with: Theme.ink, by: 0.3)]),
                                                     startPoint: CGPoint(x: x - 24, y: 0), endPoint: CGPoint(x: x + 24, y: 0)))
            context.stroke(cone, with: .color(Theme.ink), style: StrokeStyle(lineWidth: 3, lineJoin: .round))

            // Flag on a pole, rippling.
            let poleTop = CGPoint(x: x, y: towerRect.minY - 56)
            var pole = Path()
            pole.move(to: CGPoint(x: x, y: towerRect.minY - 36)); pole.addLine(to: poleTop)
            context.stroke(pole, with: .color(Theme.ink), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            let wave = CGFloat(sin(time * 4 + Double(index) * 1.3)) * 3
            var flag = Path()
            flag.move(to: poleTop)
            flag.addQuadCurve(to: CGPoint(x: x + 20, y: poleTop.y + 5 + wave), control: CGPoint(x: x + 10, y: poleTop.y - 3 + wave))
            flag.addQuadCurve(to: CGPoint(x: x, y: poleTop.y + 12), control: CGPoint(x: x + 10, y: poleTop.y + 13 - wave))
            flag.closeSubpath()
            context.fill(flag, with: .color(Theme.yellow))
            context.stroke(flag, with: .color(Theme.ink), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
        }
    }

    // MARK: Volcano

    private static func drawVolcano(size: CGSize, time: Double, avoid: [CGPoint], river: Path?,
                                    in context: inout GraphicsContext) {
        // Darker rock patches and glowing cracks in the ground.
        for p in spots(10, seed: 5, size: size, avoid: [], clearance: 0) {
            context.fill(Path(ellipseIn: CGRect(x: p.x - 60, y: p.y - 30, width: 120, height: 60)),
                         with: .color(Color(red: 0.38, green: 0.28, blue: 0.27).opacity(0.8)))
        }
        var crackRng = SplitMix64(seed: 12)
        for p in spots(7, seed: 11, size: size, avoid: avoid, clearance: 50) where p.y > 190 {
            var crack = Path()
            crack.move(to: p)
            var q = p
            var angle = Double.random(in: 0..<(2 * .pi), using: &crackRng)
            for _ in 0..<3 {
                angle += Double.random(in: -0.8...0.8, using: &crackRng)
                q = FighterArt.point(q, CGFloat(Double.random(in: 10...20, using: &crackRng)), angle)
                crack.addLine(to: q)
            }
            context.stroke(crack, with: .color(Color(red: 1, green: 0.45, blue: 0.12).opacity(0.75 + 0.2 * sin(time * 2))),
                           style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        }
        if let river {
            drawRiver(river, water: Color(red: 1, green: 0.42, blue: 0.1), glow: Color(red: 1, green: 0.9, blue: 0.4),
                      time: time, in: &context)
        }
        let glow = 0.6 + 0.3 * sin(time * 2.4)
        // Lava pools.
        for p in spots(4, seed: 6, size: size, avoid: avoid, clearance: 80) where p.y > 200 {
            let pool = Path(ellipseIn: CGRect(x: p.x - 36, y: p.y - 18, width: 72, height: 36))
            context.fill(pool, with: .color(Color(red: 1, green: 0.42, blue: 0.1)))
            context.fill(Path(ellipseIn: CGRect(x: p.x - 22, y: p.y - 10, width: 44, height: 20)),
                         with: .color(Color(red: 1, green: 0.8, blue: 0.3).opacity(glow)))
            context.stroke(pool, with: .color(Theme.ink), lineWidth: 3)
        }
        // Rocks.
        for (i, p) in spots(18, seed: 7, size: size, avoid: avoid, clearance: 46).enumerated() where p.y > 190 {
            let r = CGFloat(10 + (i % 3) * 5)
            var rock = Path()
            rock.move(to: CGPoint(x: p.x - r, y: p.y + r * 0.5))
            rock.addLine(to: CGPoint(x: p.x - r * 0.6, y: p.y - r * 0.6))
            rock.addLine(to: CGPoint(x: p.x + r * 0.3, y: p.y - r * 0.8))
            rock.addLine(to: CGPoint(x: p.x + r, y: p.y + r * 0.1))
            rock.addLine(to: CGPoint(x: p.x + r * 0.7, y: p.y + r * 0.6))
            rock.closeSubpath()
            let tone = Color(red: 0.4, green: 0.34, blue: 0.36)
            context.fill(rock, with: .linearGradient(Gradient(colors: [tone.mix(with: .white, by: 0.2), tone, tone.mix(with: Theme.ink, by: 0.35)]),
                                                     startPoint: CGPoint(x: p.x - r, y: p.y - r), endPoint: CGPoint(x: p.x + r, y: p.y + r)))
            // Lit top facet and a crack.
            var facet = Path()
            facet.move(to: CGPoint(x: p.x - r * 0.6, y: p.y - r * 0.6))
            facet.addLine(to: CGPoint(x: p.x + r * 0.3, y: p.y - r * 0.8))
            facet.addLine(to: CGPoint(x: p.x + r * 0.15, y: p.y - r * 0.1))
            facet.addLine(to: CGPoint(x: p.x - r * 0.45, y: p.y))
            facet.closeSubpath()
            context.fill(facet, with: .color(.white.opacity(0.16)))
            var crack = Path()
            crack.move(to: CGPoint(x: p.x + r * 0.15, y: p.y - r * 0.1))
            crack.addLine(to: CGPoint(x: p.x + r * 0.45, y: p.y + r * 0.45))
            context.stroke(crack, with: .color(Theme.ink.opacity(0.4)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            context.stroke(rock, with: .color(Theme.ink), style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
        }
        // Embers drifting up.
        var rng = SplitMix64(seed: 8)
        for i in 0..<26 {
            let x = Double.random(in: 0...Double(size.width), using: &rng)
            let speed = Double.random(in: 20...45, using: &rng)
            let offset = Double.random(in: 0...Double(size.height), using: &rng)
            let y = Double(size.height) - (time * speed + offset).truncatingRemainder(dividingBy: Double(size.height))
            let flicker = 0.5 + 0.5 * sin(time * 7 + Double(i))
            context.fill(FighterArt.circle(CGPoint(x: x + sin(time + Double(i)) * 6, y: y), 2.4),
                         with: .color(Color(red: 1, green: 0.65, blue: 0.2).opacity(0.35 + 0.5 * flicker)))
        }
    }

    /// The volcano at the top, glowing and smoking. Drawn over the road, which ends at its foot.
    private static func drawVolcanoPeak(size: CGSize, time: Double, in context: inout GraphicsContext) {
        let peak = CGPoint(x: size.width / 2, y: 60)
        var cone = Path()
        cone.move(to: CGPoint(x: peak.x - 150, y: peak.y + 110))
        cone.addLine(to: CGPoint(x: peak.x - 34, y: peak.y))
        cone.addLine(to: CGPoint(x: peak.x + 34, y: peak.y))
        cone.addLine(to: CGPoint(x: peak.x + 150, y: peak.y + 110))
        cone.closeSubpath()
        let rockTone = Color(red: 0.32, green: 0.23, blue: 0.23)
        context.fill(cone, with: .linearGradient(Gradient(colors: [rockTone.mix(with: .white, by: 0.15), rockTone, rockTone.mix(with: Theme.ink, by: 0.35)]),
                                                 startPoint: CGPoint(x: peak.x - 150, y: peak.y), endPoint: CGPoint(x: peak.x + 150, y: peak.y + 110)))
        // Ridges down the slopes.
        var ridges = Path()
        for (dx, spread) in [(-22.0, -70.0), (-8.0, -30.0), (10.0, 34.0), (24.0, 86.0)] {
            ridges.move(to: CGPoint(x: peak.x + dx, y: peak.y + 8))
            ridges.addQuadCurve(to: CGPoint(x: peak.x + spread, y: peak.y + 104),
                                control: CGPoint(x: peak.x + dx + spread * 0.2, y: peak.y + 60))
        }
        context.stroke(ridges, with: .color(Theme.ink.opacity(0.3)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        context.stroke(cone, with: .color(Theme.ink), style: StrokeStyle(lineWidth: 3.5, lineJoin: .round))
        // Glowing crater rim.
        let crater = Path(ellipseIn: CGRect(x: peak.x - 36, y: peak.y - 7, width: 72, height: 14))
        context.fill(crater, with: .color(Color(red: 1, green: 0.5, blue: 0.15)))
        context.fill(Path(ellipseIn: CGRect(x: peak.x - 24, y: peak.y - 4, width: 48, height: 8)), with: .color(Color(red: 1, green: 0.85, blue: 0.4)))
        context.stroke(crater, with: .color(Theme.ink), lineWidth: 3)
        let glow = 0.6 + 0.3 * sin(time * 2.4)
        var lavaFlow = Path()
        lavaFlow.move(to: CGPoint(x: peak.x - 22, y: peak.y + 2))
        lavaFlow.addQuadCurve(to: CGPoint(x: peak.x - 50, y: peak.y + 104), control: CGPoint(x: peak.x - 10, y: peak.y + 50))
        lavaFlow.move(to: CGPoint(x: peak.x + 14, y: peak.y + 2))
        lavaFlow.addQuadCurve(to: CGPoint(x: peak.x + 60, y: peak.y + 104), control: CGPoint(x: peak.x + 40, y: peak.y + 40))
        context.stroke(lavaFlow, with: .color(Color(red: 1, green: 0.4, blue: 0.1).opacity(glow)), style: StrokeStyle(lineWidth: 9, lineCap: .round))
        context.stroke(lavaFlow, with: .color(Color(red: 1, green: 0.85, blue: 0.35).opacity(glow)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        for k in 0..<4 {
            let t = (time * 0.25 + Double(k) / 4).truncatingRemainder(dividingBy: 1)
            let puff = CGPoint(x: peak.x + CGFloat(sin(t * 6 + Double(k)) * 14), y: peak.y - CGFloat(t) * 40)
            let r = CGFloat(10 + t * 16)
            context.fill(Path(ellipseIn: CGRect(x: puff.x - r, y: puff.y - r, width: r * 2, height: r * 2)),
                         with: .color(Color(white: 0.55).opacity(0.55 * (1 - t))))
        }
    }

    private static func drawFlag(at base: CGPoint, color: Color, in context: inout GraphicsContext) {
        var pole = Path()
        pole.move(to: base)
        pole.addLine(to: CGPoint(x: base.x, y: base.y - 40))
        context.stroke(pole, with: .color(Theme.ink), style: StrokeStyle(lineWidth: 4, lineCap: .round))
        var flag = Path()
        flag.move(to: CGPoint(x: base.x, y: base.y - 40))
        flag.addLine(to: CGPoint(x: base.x + 26, y: base.y - 32))
        flag.addLine(to: CGPoint(x: base.x, y: base.y - 24))
        flag.closeSubpath()
        context.fill(flag, with: .color(color))
        context.stroke(flag, with: .color(Theme.ink), style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
    }
}

/// A small swatch of a map's floor and decorations.
struct MapPreview: View {
    let map: ArenaMap
    /// Rounded card with an outline; off for a full-bleed backdrop.
    var framed = true

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            let shape = framed ? Path(roundedRect: rect.insetBy(dx: 1.5, dy: 1.5), cornerRadius: 12) : Path(rect)
            context.fill(shape, with: .color(map.floor))
            context.drawLayer { layer in
                layer.clip(to: shape)
                var tiles = Path()
                let tile: CGFloat = 16
                for row in 0...Int(size.height / tile) {
                    for col in 0...Int(size.width / tile) where (row + col).isMultiple(of: 2) {
                        tiles.addRect(CGRect(x: CGFloat(col) * tile, y: CGFloat(row) * tile, width: tile, height: tile))
                    }
                }
                layer.fill(tiles, with: .color(map.tile))
                // Decorations are sized for the arena; shrink them to suit a thumbnail.
                let scale: CGFloat = 0.45
                layer.scaleBy(x: scale, y: scale)
                map.drawDecorations(in: &layer, size: CGSize(width: size.width / scale, height: size.height / scale), time: 0)
            }
            if framed {
                context.stroke(shape, with: .color(Theme.ink), lineWidth: 3)
            }
        }
    }
}

// MARK: - Level prep

/// Before a crusade level: who you're up against, the reward, and the team of up to 3 to send.
/// Balls that fell in the crusade within the last day are resting and can't be picked.
struct CrusadePrepView: View {
    let model: AppModel
    @State private var picks: [String] = []
    /// A resting ball the player tapped, offered a revive for watching an ad.
    @State private var reviveCandidate: FighterDefinition?
    @State private var aimAngle: Double = .pi / 2

    private var chapterIndex: Int { model.crusadeChapter }
    private var difficulty: CrusadeDifficulty { model.crusadeDifficulty }
    private var level: CrusadeLevel { Crusade.chapters[chapterIndex].levels[model.crusadeLevel - 1] }
    private var profile: ProfileStore { model.profile }
    /// Ready balls first (strongest first), resting balls last.
    private var roster: [FighterDefinition] {
        profile.unlockedRoster.map(profile.definition).sorted {
            let a = !profile.isResting($0.id), b = !profile.isResting($1.id)
            if a != b { return a }
            return ($0.level, $0.rarity, $1.name) > ($1.level, $1.rarity, $0.name)
        }
    }
    private var team: [FighterDefinition] { picks.compactMap { id in roster.first { $0.id == id } } }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    BackButton(title: "Crusade", action: model.openCrusade)
                    Spacer()
                }

                VStack(spacing: 4) {
                    Text(Crusade.chapters[chapterIndex].map.name.localized.uppercased())
                        .font(Theme.bodyFont(14, weight: .black))
                        .foregroundStyle(.white.opacity(0.85))
                    OutlinedText(level.isBoss ? "BOSS LEVEL" : String(localized: "LEVEL \(level.number)"), size: 36,
                                 fill: level.isBoss ? Theme.overtime : Theme.yellow, outline: 3.5)
                    if difficulty == .hard {
                        Label("HARD · ENEMIES +\(difficulty.levelBonus) LEVELS · REWARDS ×\(difficulty.rewardMultiplier)", systemImage: "flame.fill")
                            .font(Theme.bodyFont(12, weight: .black))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Capsule().fill(Theme.blood))
                            .overlay(Capsule().strokeBorder(Theme.ink, lineWidth: 2))
                    }
                }

                enemyCard

                VStack(alignment: .leading, spacing: 10) {
                    Text("YOUR TEAM — UP TO \(Crusade.teamSize)")
                        .font(Theme.bodyFont(12, weight: .black))
                        .foregroundStyle(Theme.ink.opacity(0.7))
                    teamSlots
                    PresetPicker(profile: profile, isUnavailable: { profile.isResting($0) || !profile.isUnlocked($0) }) { preset in
                        // Resting or locked members are left out; their slots stay open.
                        picks = preset.filter { !profile.isResting($0) && profile.isUnlocked($0) }
                        saveTeam()
                    }
                    Text("Knocked-out balls rest until the crusade resets at midnight.")
                        .font(Theme.bodyFont(11, weight: .heavy))
                        .foregroundStyle(Theme.textSecondary)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 8)], spacing: 10) {
                        ForEach(roster) { def in
                            ballTile(def)
                        }
                    }
                    if let aimed = team.first(where: \.requiresAim) {
                        AimPickerView(definition: aimed, slot: .one, angle: $aimAngle)
                    }
                }
                .padding(12)
                .cartoonCard(fill: Theme.cream, cornerRadius: 20, shadow: 6, lineWidth: 3)

                Button {
                    model.startCrusadeLevel(teamIDs: picks, aimAngle: aimAngle)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "flag.fill")
                        Text(team.isEmpty ? String(localized: "PICK YOUR TEAM")
                             : team.count == 1 ? String(localized: "SEND 1 BALL!") : String(localized: "SEND TEAM OF \(team.count)!"))
                    }
                }
                .buttonStyle(CartoonButtonStyle(fill: Theme.yellow, fontSize: 22, cornerRadius: 20))
                .disabled(team.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .animation(.spring(duration: 0.3, bounce: 0.4), value: picks)
        .confirmationDialog(reviveTitle, isPresented: Binding(get: { reviveCandidate != nil },
                                                              set: { if !$0 { reviveCandidate = nil } }),
                            titleVisibility: .visible) {
            if let ball = reviveCandidate, profile.adsLeft(.crusadeRevive) > 0 {
                Button("Watch an ad to revive \(ball.name)") {
                    model.watchAd(for: .crusadeRevive, reviving: ball.id)
                }
                .disabled(!model.ads.isReady)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(profile.adsLeft(.crusadeRevive) > 0
                 ? (model.ads.isReady ? String(localized: "One free revive a day.") : String(localized: "The ad is still loading. Try again in a moment."))
                 : String(localized: "You've used today's revive. Fallen balls return when the crusade resets."))
        }
        .onAppear {
            guard picks.isEmpty else { return }
            if let saved = profile.crusadeTeam {
                // The saved team, minus anyone resting today; their slots stay open to refill.
                picks = saved.filter { !profile.isResting($0) && profile.isUnlocked($0) }
            } else {
                picks = Array(roster.filter { !profile.isResting($0.id) }.prefix(Crusade.teamSize).map(\.id))
            }
        }

    }

    private var teamSlots: some View {
        HStack(spacing: 10) {
            ForEach(0..<Crusade.teamSize, id: \.self) { i in
                ZStack {
                    if i < team.count {
                        VStack(spacing: 2) {
                            FighterPortrait(definition: team[i], color: PlayerSlot.one.color, size: 56, expression: .happy)
                            Text(team[i].name).font(Theme.bodyFont(11, weight: .black)).foregroundStyle(Theme.ink).lineLimit(1)
                        }
                        .transition(.scale.combined(with: .opacity))
                    } else {
                        Text("?").font(Theme.titleFont(28)).foregroundStyle(Theme.ink.opacity(0.25))
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 84)
                .cartoonCard(fill: i < team.count ? PlayerSlot.one.lightColor : .white, cornerRadius: 16, shadow: 3, lineWidth: 2.5)
                .overlay(alignment: .topLeading) {
                    Text("\(i + 1)").font(Theme.bodyFont(11, weight: .black)).foregroundStyle(Theme.ink)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(Theme.yellow))
                        .overlay(Circle().strokeBorder(Theme.ink, lineWidth: 2))
                        .offset(x: -6, y: -6)
                }
                .onTapGesture {
                    guard i < picks.count else { return }
                    picks.remove(at: i)
                    saveTeam()
                }
            }
        }
    }

    private var enemyCard: some View {
        let stars = profile.stars(chapter: chapterIndex, level: level.number, difficulty: difficulty)
        let reward = Crusade.firstClearReward(chapter: chapterIndex, level: level.number, difficulty: difficulty)
        return VStack(spacing: 10) {
            Text(level.isBoss ? String(localized: "BOSS GAUNTLET — \(level.enemies.count) ENEMIES IN A ROW")
                 : level.enemies.count > 1 ? String(localized: "\(level.enemies.count) ENEMIES IN A ROW") : String(localized: "YOUR OPPONENT"))
                .font(Theme.bodyFont(12, weight: .black))
                .foregroundStyle(Theme.ink.opacity(0.7))
            HStack(spacing: 10) {
                ForEach(level.enemies.indices, id: \.self) { i in
                    if let enemy = level.enemyDefinition(i, difficulty: difficulty, power: profile.crusadePower) {
                        VStack(spacing: 3) {
                            FighterPortrait(definition: enemy, color: PlayerSlot.two.color, size: 64)
                            Text(enemy.name).font(Theme.bodyFont(13, weight: .black)).foregroundStyle(Theme.ink)
                            HStack(spacing: 3) {
                                RarityBadge(rarity: enemy.rarity, size: 8)
                                LevelBadge(level: enemy.level, size: 9)
                            }
                            Text("\(Int(enemy.maxHealth)) HP").font(Theme.bodyFont(11, weight: .heavy)).foregroundStyle(Theme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            HStack(spacing: 10) {
                HStack(spacing: 2) {
                    ForEach(1...3, id: \.self) { i in
                        Image(systemName: i <= stars ? "star.fill" : "star")
                            .foregroundStyle(i <= stars ? Theme.yellow : Theme.ink.opacity(0.3))
                    }
                }
                .font(.system(size: 16, weight: .black))
                if stars == 0 {
                    Text("Today's clear:").font(Theme.bodyFont(12, weight: .heavy)).foregroundStyle(Theme.ink)
                    RewardsLine(rewards: reward)
                } else {
                    Text("★★★ lose no one · ★★ lose one")
                        .font(Theme.bodyFont(11, weight: .heavy))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .padding(12)
        .cartoonCard(fill: PlayerSlot.two.lightColor, cornerRadius: 20, shadow: 6, lineWidth: 3)
    }

    private func ballTile(_ def: FighterDefinition) -> some View {
        let order = picks.firstIndex(of: def.id)
        let resting = profile.isResting(def.id) ? Crusade.nextReset() : nil
        let full = picks.count >= Crusade.teamSize
        return Button {
            guard resting == nil else {
                if model.ads.isAvailable { reviveCandidate = def }
                return
            }
            if let order {
                picks.remove(at: order)
            } else {
                // A full team swaps out its last pick.
                if full { picks.removeLast() }
                picks.append(def.id)
            }
            saveTeam()
        } label: {
            VStack(spacing: 2) {
                FighterPortrait(definition: def, color: resting == nil ? PlayerSlot.one.color : Theme.disabled, size: 50,
                                expression: resting != nil ? .knockedOut : order != nil ? .happy : .normal)
                    .overlay(alignment: .bottomTrailing) { LevelBadge(level: def.level, size: 8).offset(x: 6) }
                Text(resting.map(Self.restText) ?? def.name)
                    .font(Theme.bodyFont(11, weight: .black))
                    .foregroundStyle(resting == nil ? Theme.ink : Theme.ink.opacity(0.6))
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity)
            .cartoonCard(fill: order != nil ? PlayerSlot.one.lightColor : resting != nil ? Theme.disabled.opacity(0.5)
                         : def.rarity.color.mix(with: .white, by: 0.75),
                         cornerRadius: 14, shadow: order != nil ? 1 : 4, lineWidth: 2.5)
            .offset(y: order != nil ? 3 : 0)
            .overlay(alignment: .topTrailing) {
                if let order {
                    Text("\(order + 1)").font(Theme.bodyFont(11, weight: .black)).foregroundStyle(Theme.ink)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(Theme.yellow))
                        .overlay(Circle().strokeBorder(Theme.ink, lineWidth: 2))
                        .offset(x: 5, y: -5)
                } else if resting != nil {
                    Image(systemName: "moon.zzz.fill").font(.system(size: 13, weight: .black)).foregroundStyle(Theme.ink)
                        .padding(3).background(Circle().fill(.white)).overlay(Circle().strokeBorder(Theme.ink, lineWidth: 1.5))
                        .offset(x: 5, y: -5)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var reviveTitle: String {
        reviveCandidate.map { String(localized: "\($0.name) is resting") } ?? ""
    }

    /// Remembers the team the player picked. Resting members dropped when loading aren't removed
    /// from the saved team until the player edits it, so they're back after the daily reset.
    private func saveTeam() {
        profile.setCrusadeTeam(picks)
    }

    /// "5h 12m" until a resting ball is back.
    private static func restText(_ until: Date) -> String {
        let minutes = max(1, Int(until.timeIntervalSinceNow / 60))
        return minutes >= 60 ? String(localized: "\(minutes / 60)h \(minutes % 60)m") : String(localized: "\(minutes)m")
    }
}
