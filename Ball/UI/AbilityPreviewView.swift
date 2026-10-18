import SwiftUI

/// One stage of a ball to preview: its basic attack (level 1) or a star power (at its level).
struct AbilityPreviewRequest: Identifiable, Equatable {
    let ballID: String
    let level: Int
    let title: String
    let tag: String
    let description: String

    var id: String { "\(ballID).\(level)" }
    var isUltimate: Bool { level == Progression.starLevels.last }
}

/// A short looping clip of a ball beating an enemy, played live by the battle simulation. It replays one fight
/// the ball wins, ending on the K.O., so it repeats like a video. The fight comes from `PreviewFight.table`
/// (worked out ahead of time), so it starts at once; only if that entry is missing, or its first loop turns out
/// not to be a win, does it look for another one a little each frame.
@Observable
final class AbilityPreview {
    typealias Choice = PreviewFight.Choice

    let request: AbilityPreviewRequest
    /// The fight on screen.
    @ObservationIgnored private(set) var simulation: BattleSimulation
    @ObservationIgnored private(set) var interpolation: Double = 0
    @ObservationIgnored private var lastDate: Date?
    @ObservationIgnored private var accumulator: Double = 0
    @ObservationIgnored private var chargedUltimate = false
    /// The fight being looped; nil while searching for one.
    @ObservationIgnored private var choice: Choice?
    /// The first loop of a stored fight is checked: if the ball doesn't win (balance changed), search again.
    @ObservationIgnored private var verifying = false
    @ObservationIgnored private var search = Search()
    /// Playback waits until the dialog has finished appearing.
    @ObservationIgnored private var startAt: Date?

    /// Fights found by searching this session, so a preview opened again starts at once.
    private static var found: [String: Choice] = [:]

    private let longestFight: Double
    /// How long the K.O. stays on screen before the clip starts over.
    private static let holdAfterKnockout = 1.5
    /// Display-frame time a fallback search may use.
    private static let searchBudget = 0.004
    /// Longest frame the clip catches up on, so a slow frame doesn't make it jump ahead.
    private static let maxFrame = 1.0 / 30

    private var key: String { PreviewFight.key(ballID: request.ballID, level: request.level) }

    init(_ request: AbilityPreviewRequest) {
        self.request = request
        longestFight = PreviewFight.longestFight(ballID: request.ballID)
        let key = PreviewFight.key(ballID: request.ballID, level: request.level)
        if let known = Self.found[key] {
            choice = known
        } else if let stored = PreviewFight.table[key] {
            choice = stored
            verifying = true
        }
        let first = choice ?? PreviewFight.candidates(level: request.level)[0]
        simulation = Self.makeSimulation(request, first)
    }

    /// Called once per display frame.
    func tick(_ date: Date) {
        if startAt == nil { startAt = date.addingTimeInterval(0.3) }
        guard let choice else {
            advanceSearch()
            return
        }
        guard date >= startAt! else { return }
        guard let last = lastDate else { lastDate = date; return }
        lastDate = date
        let dt = GameConfig.fixedTimeStep
        accumulator += min(max(0, date.timeIntervalSince(last)), Self.maxFrame)
        while accumulator >= dt {
            PreviewFight.step(simulation, level: request.level, charged: &chargedUltimate)
            accumulator -= dt
        }
        interpolation = accumulator / dt
        _ = simulation.drainEvents()

        let finished: BattleOutcome?
        if case .finished(let outcome) = simulation.phase { finished = outcome } else { finished = nil }
        let over = finished != nil ? simulation.timeSinceFinish >= Self.holdAfterKnockout : simulation.battleTime >= longestFight
        guard over else { return }
        if verifying {
            verifying = false
            if finished != .winner(.one) {
                // The stored fight no longer ends in a win: find another (shown from its launch meanwhile).
                self.choice = nil
                search = Search()
                return
            }
        }
        play(choice)
    }

    private func play(_ choice: Choice) {
        simulation = Self.makeSimulation(request, choice)
        accumulator = 0
        lastDate = nil
        chargedUltimate = false
    }

    private static func makeSimulation(_ request: AbilityPreviewRequest, _ choice: Choice) -> BattleSimulation {
        PreviewFight.makeSimulation(ballID: request.ballID, level: request.level, choice: choice,
                                    label: FighterCatalog.definition(id: request.ballID)!.name.uppercased())
    }

    // MARK: Fallback search (only when the table has no good fight)

    private struct Search {
        var attempt = 0
        var simulation: BattleSimulation?
        var charged = false
        var ultimateAt: Double?
        var anyWin: Choice?
    }

    /// Plays the candidate fights off screen a few milliseconds per frame and keeps the first good win.
    private func advanceSearch() {
        let candidates = PreviewFight.candidates(level: request.level)
        let deadline = Date.now.addingTimeInterval(Self.searchBudget)
        while Date.now < deadline {
            guard search.attempt < candidates.count else {
                finishSearch(search.anyWin ?? candidates.last!)
                return
            }
            let candidate = candidates[search.attempt]
            if search.simulation == nil {
                search.simulation = Self.makeSimulation(request, candidate)
                search.charged = false
                search.ultimateAt = nil
            }
            let fight = search.simulation!
            for _ in 0..<60 {
                PreviewFight.step(fight, level: request.level, charged: &search.charged)
                if case .finished = fight.phase { break }
                if fight.battleTime >= longestFight { break }
            }
            for event in fight.drainEvents() {
                if case .ability(.one, _, _, true) = event, search.ultimateAt == nil { search.ultimateAt = fight.battleTime }
            }
            if case .finished(let outcome) = fight.phase {
                if outcome == .winner(.one) {
                    let time = fight.battleTime
                    let showedUltimate = !request.isUltimate || search.ultimateAt.map { time >= $0 + 0.5 } == true
                    if time >= PreviewFight.shortestWin && showedUltimate {
                        finishSearch(candidate)
                        return
                    }
                    if search.anyWin == nil { search.anyWin = candidate }
                }
                search.simulation = nil
                search.attempt += 1
            } else if fight.battleTime >= longestFight {
                search.simulation = nil
                search.attempt += 1
            }
        }
    }

    private func finishSearch(_ choice: Choice) {
        Self.found[key] = choice
        self.choice = choice
        search = Search()
        play(choice)
    }
}

/// The preview dialog: the clip on repeat.
struct AbilityPreviewDialog: View {
    let request: AbilityPreviewRequest
    let onClose: () -> Void
    /// Made once the dialog is on screen (not on every parent update).
    @State private var preview: AbilityPreview?

    var body: some View {
        ZStack {
            Theme.ink.opacity(0.7).ignoresSafeArea()
                .onTapGesture(perform: onClose)
            VStack(spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(request.title.localized)
                                .font(Theme.titleFont(20))
                                .foregroundStyle(Theme.ink)
                            Text(request.tag)
                                .font(Theme.bodyFont(9, weight: .black))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(Capsule().fill(request.isUltimate ? Rarity.legendary.color : Theme.background))
                                .overlay(Capsule().strokeBorder(Theme.ink, lineWidth: 1.5))
                                .fixedSize()
                        }
                        Text(request.description.localized)
                            .font(Theme.bodyFont(12, weight: .semibold))
                            .foregroundStyle(Theme.ink.opacity(0.75))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    Button(action: onClose) {
                        Image(systemName: "xmark").font(.system(size: 14, weight: .black)).foregroundStyle(Theme.ink)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(.white))
                            .overlay(Circle().strokeBorder(Theme.ink, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                }

                ZStack {
                    if let preview {
                        TimelineView(.animation) { timeline in
                            let _ = preview.tick(timeline.date)
                            let frame = timeline.date
                            Canvas { context, size in
                                // Reading the frame's date makes the canvas redraw every frame.
                                _ = frame
                                BattleRenderer.draw(preview.simulation, alpha: preview.interpolation, in: &context, size: size)
                            }
                        }
                    }
                }
                .aspectRatio(GameConfig.arenaWidth / GameConfig.arenaHeight, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .frame(maxHeight: 420)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(14)
            .frame(maxWidth: 420)
            .cartoonCard(fill: Theme.cream, cornerRadius: 22, shadow: 6, lineWidth: 4)
            .padding(16)
        }
        .onAppear {
            if preview == nil { preview = AbilityPreview(request) }
        }
    }
}

/// The round "watch" button next to each stage.
struct PreviewButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "play.fill")
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Theme.go))
                .overlay(Circle().strokeBorder(Theme.ink, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Watch preview")
    }
}
