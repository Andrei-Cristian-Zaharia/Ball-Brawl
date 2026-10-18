import SwiftUI

struct BattleView: View {
    let model: AppModel
    let engine: BattleEngine
    @Environment(\.scenePhase) private var scenePhase
    /// The battle whose intro has finished (the view is reused between rounds).
    @State private var introDone: ObjectIdentifier?

    var body: some View {
        VStack(spacing: 12) {
            TimelineView(.animation(minimumInterval: nil, paused: engine.isPaused)) { timeline in
                let _ = engine.tick(timeline.date)
                VStack(spacing: 12) {
                    Canvas { context, size in
                        BattleHUDRenderer.draw(engine.simulation, in: &context, size: size)
                    }
                    .frame(height: 90)

                    Canvas { context, size in
                        BattleRenderer.draw(engine.simulation, alpha: engine.interpolation, in: &context, size: size)
                    }
                    .overlay { launchAimControls }
                }
            }

            // Multiplayer fights (online or a stand-in) can't be paused or restarted; series show the teams instead.
            if !model.isVersusMatch {
                controls
            } else if let series = model.series {
                TeamBench(series: series, engine: engine, localSlot: model.localSlot)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .overlay { overlay }
        .overlay {
            if introDone != ObjectIdentifier(engine) {
                BattleIntroView(setup: engine.setup,
                                onStart: engine.finishIntro,
                                onDone: { introDone = ObjectIdentifier(engine) })
                    .id(ObjectIdentifier(engine))
            }
        }
        .animation(.spring(duration: 0.3, bounce: 0.4), value: engine.isPaused)
        .onChange(of: engine.outcome) { _, outcome in
            if outcome != nil { model.recordResult(from: engine) }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { engine.setPaused(true) }
        }
    }

    /// During the countdown, each player drags on their half of the arena (P1 top, P2 bottom)
    /// to choose their launch direction. Separate views so both can drag at once.
    private var launchAimControls: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                ForEach(PlayerSlot.allCases) { slot in
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                            let y = value.location.y + (slot == .one ? 0 : geo.size.height / 2)
                            aimLaunch(slot, toward: CGPoint(x: value.location.x, y: y), canvasSize: geo.size)
                        })
                        .allowsHitTesting(model.controlledSlots.contains(slot))
                }
            }
        }
    }

    private func aimLaunch(_ slot: PlayerSlot, toward point: CGPoint, canvasSize: CGSize) {
        let sim = engine.simulation
        guard sim.phase == .countdown, !engine.isPaused else { return }
        let target = BattleRenderer.arenaPoint(from: point, canvasSize: canvasSize)
        let offset = target - sim.state.body(of: slot).position
        guard offset.length > 12 else { return }
        model.aimLaunch(offset.angle, for: slot)
    }

    @ViewBuilder private var overlay: some View {
        if let outcome = engine.outcome {
            if model.mode == .crusade, let run = model.crusadeRun, run.result != nil {
                CrusadeResultOverlay(run: run, rewards: model.lastRewards, model: model)
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            } else if let series = model.series, model.mode != .local {
                BotRoundOverlay(outcome: model.playerOutcome(outcome), series: series, rewards: model.lastRewards,
                                opponent: model.mode == .bot ? nil : model.opponentName,
                                autoAdvance: model.isVersusSeries,
                                onNextRound: model.nextBotRound,
                                onPlayAgain: model.playSeriesAgain,
                                onMenu: model.showMenu)
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            } else {
                ResultsOverlay(outcome: outcome, engine: engine,
                               localSlot: model.isVersusMatch ? model.localSlot : nil,
                               rewards: model.lastRewards,
                               rematchStatus: model.rematchStatus, waitingForRematch: model.wantsRematch,
                               onRematch: model.rematch, onChangeFighters: model.changeFighters,
                               onMenu: model.showMenu)
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        } else if engine.isPaused {
            PauseOverlay(onResume: { engine.setPaused(false) },
                         onRestart: restartAction,
                         leaveTitle: model.mode == .local ? String(localized: "Change Fighters") : model.mode == .crusade ? String(localized: "Retreat (ball falls)") : String(localized: "Quit to Menu"),
                         onLeave: leave)
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
        }
    }

    /// Online fights can't be restarted mid-way (the opponent is still watching theirs), and
    /// crusade fights can't be redone to dodge a loss.
    private var restartAction: (() -> Void)? {
        model.isVersusMatch || model.mode == .crusade ? nil : { model.rematch() }
    }

    private func leave() {
        switch model.mode {
        case .local: model.changeFighters()
        case .crusade: model.retreatFromCrusade()
        case .bot, .online, .standIn: model.showMenu()
        }
    }

    private var controls: some View {
        HStack(spacing: 14) {
            Button {
                engine.setPaused(!engine.isPaused)
            } label: {
                Label(engine.isPaused ? String(localized: "Resume") : String(localized: "Pause"), systemImage: engine.isPaused ? "play.fill" : "pause.fill")
            }
            .buttonStyle(CartoonButtonStyle(fill: Theme.cream, fontSize: 17))
            .disabled(!engine.canPause)

            Button(action: model.rematch) {
                Label("Restart", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(CartoonButtonStyle(fill: Theme.cream, fontSize: 17))
            // A finished bot round is already recorded; it can't be replayed. Online fights can't be restarted mid-way.
            .disabled(engine.outcome != nil || model.isVersusMatch || model.mode == .crusade)
        }
    }
}

private struct OverlayCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            Theme.ink.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 14) { content }
                .padding(24)
                .frame(maxWidth: 380)
                .cartoonCard(fill: Theme.cream, cornerRadius: 28, shadow: 8, lineWidth: 4)
                .padding(20)
        }
    }
}

/// End of a crusade fight: pick who goes next, level cleared with stars, or the whole team down.
private struct CrusadeResultOverlay: View {
    let run: AppModel.CrusadeRun
    let rewards: Progression.Rewards?
    let model: AppModel
    @State private var shownStars = 0

    var body: some View {
        OverlayCard {
            switch run.result {
            case .continuing(let enemyDown):
                OutlinedText(enemyDown ? String(localized: "ENEMY DOWN!") : String(localized: "BALL DOWN!"), size: 36,
                             fill: enemyDown ? PlayerSlot.one.color : PlayerSlot.two.color, outline: 3.5)
                if !enemyDown {
                    caption("It rests until the crusade resets tonight. Send in a teammate!")
                }
                if let enemy = run.enemy(run.enemyIndex) {
                    nextEnemy(enemy)
                }
                teamPicker
                Button("Fight!", action: model.continueCrusade)
                    .buttonStyle(CartoonButtonStyle(fill: Theme.yellow))
                Button("Retreat", action: model.openCrusade)
                    .buttonStyle(CartoonButtonStyle(fill: .white, fontSize: 15))
            case .cleared(let stars):
                OutlinedText(run.levelInfo.isBoss ? String(localized: "BOSS DEFEATED!") : String(localized: "LEVEL CLEAR!"), size: 34, fill: Theme.yellow, outline: 3.5)
                if run.difficulty == .hard {
                    Text("HARD").font(Theme.bodyFont(12, weight: .black)).foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Capsule().fill(Theme.blood))
                }
                HStack(spacing: 6) {
                    ForEach(1...3, id: \.self) { i in
                        Image(systemName: i <= shownStars ? "star.fill" : "star")
                            .font(.system(size: 40, weight: .black))
                            .foregroundStyle(i <= shownStars ? Theme.yellow : Theme.ink.opacity(0.25))
                            .scaleEffect(i <= shownStars ? 1 : 0.8)
                    }
                }
                .onAppear {
                    for i in 1...stars {
                        withAnimation(.spring(duration: 0.4, bounce: 0.6).delay(0.25 * Double(i))) { shownStars = i }
                    }
                }
                TeamStatusRow(title: String(localized: "YOUR TEAM"), members: run.team, color: PlayerSlot.one.color)
                if let rewards, rewards != Progression.Rewards() {
                    RewardsLine(rewards: rewards)
                }
                if stars < 3 {
                    caption("Lose no teammates for 3 stars.")
                }
                Button(nextTitle, action: model.nextCrusadeLevel)
                    .buttonStyle(CartoonButtonStyle(fill: Theme.yellow))
                Button("Replay", action: model.retryCrusadeLevel)
                    .buttonStyle(CartoonButtonStyle(fill: .white))
                Button("Crusade Map", action: model.openCrusade)
                    .buttonStyle(CartoonButtonStyle(fill: .white, fontSize: 15))
            case .lost, nil:
                OutlinedText("TEAM DEFEATED", size: 36, fill: PlayerSlot.two.color, outline: 4)
                caption("Your fallen balls rest until the crusade resets tonight. Send a fresh team, or upgrade in the Collection.")
                TeamStatusRow(title: String(localized: "YOUR TEAM"), members: run.team, color: PlayerSlot.one.color)
                Button("New Team", action: model.retryCrusadeLevel)
                    .buttonStyle(CartoonButtonStyle(fill: Theme.yellow))
                Button("Crusade Map", action: model.openCrusade)
                    .buttonStyle(CartoonButtonStyle(fill: .white, fontSize: 15))
            }
        }
    }

    private func nextEnemy(_ enemy: FighterDefinition) -> some View {
        let health = run.enemyHealth ?? enemy.maxHealth
        return HStack(spacing: 10) {
            Text(run.levelInfo.enemies.count > 1 ? String(localized: "ENEMY \(run.enemyIndex + 1)/\(run.levelInfo.enemies.count)") : String(localized: "ENEMY"))
                .font(Theme.bodyFont(12, weight: .black)).foregroundStyle(Theme.ink)
            FighterPortrait(definition: enemy, color: PlayerSlot.two.color, size: 46)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(enemy.name).font(Theme.titleFont(17)).foregroundStyle(Theme.ink)
                    LevelBadge(level: enemy.level, size: 9)
                }
                HealthPill(fraction: health / enemy.maxHealth, color: PlayerSlot.two.color, height: 10)
                    .frame(width: 110)
            }
        }
    }

    private var teamPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("WHO GOES NEXT?")
                .font(Theme.bodyFont(12, weight: .black))
                .foregroundStyle(Theme.ink.opacity(0.7))
            HStack(spacing: 8) {
                ForEach(run.team) { member in
                    Button {
                        model.chooseCrusadeFighter(member.id)
                    } label: {
                        TeamMemberTile(member: member, color: PlayerSlot.one.color, isSelected: member.id == run.active)
                    }
                    .buttonStyle(.plain)
                    .disabled(!member.isAlive)
                }
            }
        }
    }

    private var nextTitle: String {
        if run.level < Crusade.chapters[run.chapter].levels.count { return String(localized: "Next Level") }
        return run.difficulty == .normal ? String(localized: "Hard Mode Unlocked!") : String(localized: "Crusade Map")
    }

    private func caption(_ text: String) -> some View {
        Text(text.localized)
            .font(Theme.bodyFont(15, weight: .heavy))
            .foregroundStyle(Theme.ink)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct PauseOverlay: View {
    let onResume: () -> Void
    let onRestart: (() -> Void)?
    let leaveTitle: String
    let onLeave: () -> Void

    var body: some View {
        OverlayCard {
            OutlinedText("PAUSED", size: 40, fill: Theme.yellow, outline: 3.5)
                .padding(.bottom, 6)
            Button("Resume", action: onResume)
                .buttonStyle(CartoonButtonStyle(fill: Theme.yellow))
            if let onRestart {
                Button("Restart Round", action: onRestart)
                    .buttonStyle(CartoonButtonStyle(fill: .white))
            }
            Button(leaveTitle, action: onLeave)
                .buttonStyle(CartoonButtonStyle(fill: .white))
        }
    }
}

private struct ResultsOverlay: View {
    let outcome: BattleOutcome
    let engine: BattleEngine
    /// Online: this device's slot, so the title reads "YOU WIN!" / "YOU LOSE!".
    let localSlot: PlayerSlot?
    let rewards: Progression.Rewards?
    /// Online: "Waiting for …" / "… wants a rematch!".
    let rematchStatus: String?
    let waitingForRematch: Bool
    let onRematch: () -> Void
    let onChangeFighters: () -> Void
    let onMenu: () -> Void

    var body: some View {
        OverlayCard {
            switch outcome {
            case .winner(let slot):
                let fighter = engine.simulation.state.fighter(slot)
                OutlinedText(localSlot.map { $0 == slot ? String(localized: "YOU WIN!") : String(localized: "YOU LOSE!") } ?? String(localized: "\(slot.title.uppercased()) WINS!"),
                             size: 34, fill: slot.color, outline: 3.5)
                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let burst = FighterArt.starburst(center: center, radius: 58, points: 12)
                    context.stroke(burst, with: .color(Theme.ink), style: StrokeStyle(lineWidth: 5, lineJoin: .round))
                    context.fill(burst, with: .color(Theme.yellow))
                    FighterArt.draw(fighter.definition, in: &context, center: center, radius: 34,
                                    team: slot.color, spin: 0.3,
                                    aimAngle: fighter.definition.requiresAim ? fighter.aim.angle : nil,
                                    expression: .happy)
                }
                .frame(width: 130, height: 130)
                Text("\(fighter.definition.name) survives with \(Int(fighter.health.rounded(.up))) HP")
                    .font(Theme.bodyFont(16, weight: .heavy))
                    .foregroundStyle(Theme.ink)
            case .draw:
                OutlinedText("DRAW!", size: 46, fill: Theme.yellow, outline: 4)
                Text("Both fighters went down on the same frame!")
                    .font(Theme.bodyFont(16, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
            }

            Text("Match time \(String(format: "%.1f", engine.simulation.battleTime))s")
                .font(Theme.bodyFont(13, weight: .heavy))
                .foregroundStyle(Theme.textSecondary)
                .padding(.bottom, 4)
            if let rewards, rewards != Progression.Rewards() {
                RewardsLine(rewards: rewards)
            }

            if let rematchStatus {
                Text(rematchStatus)
                    .font(Theme.bodyFont(14, weight: .black))
                    .foregroundStyle(waitingForRematch ? Theme.textSecondary : Theme.go)
            }
            Button("Rematch", action: onRematch)
                .buttonStyle(CartoonButtonStyle(fill: waitingForRematch ? Theme.disabled : Theme.yellow))
                .disabled(waitingForRematch)
            Button("Change Fighters", action: onChangeFighters)
                .buttonStyle(CartoonButtonStyle(fill: .white))
            Button("Main Menu", action: onMenu)
                .buttonStyle(CartoonButtonStyle(fill: .white, fontSize: 15))
        }
    }
}

private struct BotRoundOverlay: View {
    let outcome: BattleOutcome
    let series: BotSeries
    let rewards: Progression.Rewards?
    /// The opponent's name in ranked; nil against the VS Bot.
    let opponent: String?
    /// Versus series: the next pick opens by itself (both players move on together).
    let autoAdvance: Bool
    let onNextRound: () -> Void
    let onPlayAgain: () -> Void
    let onMenu: () -> Void

    var body: some View {
        OverlayCard {
            if let final = series.outcome {
                switch final {
                case .playerWins:
                    OutlinedText("VICTORY!", size: 44, fill: Theme.yellow, outline: 4)
                    caption(opponent.map { String(localized: "You knocked out \($0)'s whole team!") } ?? String(localized: "You knocked out the bot's whole team!"))
                case .botWins:
                    OutlinedText("DEFEAT", size: 44, fill: PlayerSlot.two.color, outline: 4)
                    caption(opponent.map { String(localized: "\($0) knocked out your whole team.") } ?? String(localized: "The bot knocked out your whole team."))
                case .draw:
                    OutlinedText("SERIES DRAW!", size: 36, fill: Theme.yellow, outline: 4)
                    caption("Both teams' last fighters went down together.")
                }
            } else {
                switch outcome {
                case .winner(.one):
                    OutlinedText("ROUND WON!", size: 38, fill: PlayerSlot.one.color, outline: 3.5)
                case .winner(.two):
                    OutlinedText("ROUND LOST", size: 38, fill: PlayerSlot.two.color, outline: 3.5)
                case .draw:
                    OutlinedText("DOUBLE K.O.!", size: 34, fill: Theme.yellow, outline: 3.5)
                }
            }

            TeamStatusRow(title: String(localized: "YOUR TEAM"), members: series.player, color: PlayerSlot.one.color)
            TeamStatusRow(title: opponent.map { String(localized: "\($0.uppercased())'S TEAM") } ?? String(localized: "BOT TEAM"), members: series.bot,
                          color: PlayerSlot.two.color)
                .padding(.bottom, 4)
            if let rewards, rewards != Progression.Rewards() {
                RewardsLine(rewards: rewards)
            }

            if series.outcome == nil, autoAdvance {
                HStack(spacing: 8) {
                    ProgressView().tint(Theme.ink)
                    Text("Next round starting…")
                        .font(Theme.bodyFont(14, weight: .black))
                        .foregroundStyle(Theme.ink)
                }
            } else if series.outcome == nil {
                Button("Next Round", action: onNextRound)
                    .buttonStyle(CartoonButtonStyle(fill: Theme.yellow))
                Button("Quit to Menu", action: onMenu)
                    .buttonStyle(CartoonButtonStyle(fill: .white, fontSize: 15))
            } else {
                Button("Play Again", action: onPlayAgain)
                    .buttonStyle(CartoonButtonStyle(fill: Theme.yellow))
                Button("Main Menu", action: onMenu)
                    .buttonStyle(CartoonButtonStyle(fill: .white, fontSize: 15))
            }
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text.localized)
            .font(Theme.bodyFont(15, weight: .heavy))
            .foregroundStyle(Theme.ink)
            .multilineTextAlignment(.center)
    }
}

/// Under the arena in a 3v3 series: both teams, with who's fighting now, health left, and who's out.
private struct TeamBench: View {
    let series: BotSeries
    let engine: BattleEngine
    let localSlot: PlayerSlot

    var body: some View {
        let mine = engine.setup.loadouts[localSlot.rawValue].definition.id
        let theirs = engine.setup.loadouts[localSlot.opponent.rawValue].definition.id
        HStack {
            team(series.player, fighting: mine, color: PlayerSlot.one.color)
            Spacer()
            Text("VS")
                .font(Theme.titleFont(15))
                .foregroundStyle(.white.opacity(0.6))
            Spacer()
            team(series.bot, fighting: theirs, color: PlayerSlot.two.color)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 18).fill(Theme.ink.opacity(0.3)))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.15), lineWidth: 1))
    }

    private func team(_ members: [TeamMember], fighting id: String, color: Color) -> some View {
        HStack(spacing: 8) {
            ForEach(members) { member in
                let active = member.definition.id == id && member.isAlive
                VStack(spacing: 3) {
                    FighterPortrait(definition: member.definition, color: member.isAlive ? color : Theme.disabled,
                                    size: 34, expression: member.isAlive ? .normal : .knockedOut)
                        .padding(3)
                        .background(Circle().fill(active ? Theme.yellow.opacity(0.35) : .clear))
                        .overlay(Circle().strokeBorder(active ? Theme.yellow : .clear, lineWidth: 2))
                        .overlay(alignment: .bottomTrailing) { LevelBadge(level: member.definition.level, size: 7).offset(x: 8, y: 3) }
                    Capsule().fill(Theme.ink.opacity(0.5))
                        .frame(width: 30, height: 5)
                        .overlay(alignment: .leading) {
                            Capsule().fill(color)
                                .frame(width: 30 * max(0, min(1, member.health / member.definition.maxHealth)), height: 5)
                        }
                }
                .opacity(member.isAlive ? 1 : 0.45)
            }
        }
    }
}
