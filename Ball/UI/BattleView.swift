import SwiftUI

struct BattleView: View {
    let model: AppModel
    let engine: BattleEngine
    @Environment(\.scenePhase) private var scenePhase

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
                }
            }

            controls
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .overlay { overlay }
        .animation(.spring(duration: 0.3, bounce: 0.4), value: engine.isPaused)
        .onChange(of: engine.outcome) { _, outcome in
            if outcome != nil { model.recordBotRound(from: engine) }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { engine.setPaused(true) }
        }
    }

    @ViewBuilder private var overlay: some View {
        if let outcome = engine.outcome {
            if model.mode == .bot, let series = model.series {
                BotRoundOverlay(outcome: outcome, series: series,
                                onNextRound: model.nextBotRound,
                                onPlayAgain: model.openBotTeamSelect,
                                onMenu: model.showMenu)
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            } else {
                ResultsOverlay(outcome: outcome, engine: engine,
                               onRematch: model.rematch, onChangeFighters: model.changeFighters,
                               onMenu: model.showMenu)
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        } else if engine.isPaused {
            PauseOverlay(onResume: { engine.setPaused(false) },
                         onRestart: model.rematch,
                         leaveTitle: model.mode == .bot ? "Quit to Menu" : "Change Fighters",
                         onLeave: leave)
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
        }
    }

    private func leave() {
        if model.mode == .bot { model.showMenu() } else { model.changeFighters() }
    }

    private var controls: some View {
        HStack(spacing: 14) {
            Button {
                engine.setPaused(!engine.isPaused)
            } label: {
                Label(engine.isPaused ? "Resume" : "Pause", systemImage: engine.isPaused ? "play.fill" : "pause.fill")
            }
            .buttonStyle(CartoonButtonStyle(fill: Theme.cream, fontSize: 17))
            .disabled(!engine.canPause)

            Button(action: model.rematch) {
                Label("Restart", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(CartoonButtonStyle(fill: Theme.cream, fontSize: 17))
            // A finished bot round is already recorded; it can't be replayed.
            .disabled(engine.outcome != nil)
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

private struct PauseOverlay: View {
    let onResume: () -> Void
    let onRestart: () -> Void
    let leaveTitle: String
    let onLeave: () -> Void

    var body: some View {
        OverlayCard {
            OutlinedText("PAUSED", size: 40, fill: Theme.yellow, outline: 3.5)
                .rotationEffect(.degrees(-3))
                .padding(.bottom, 6)
            Button("Resume", action: onResume)
                .buttonStyle(CartoonButtonStyle(fill: Theme.yellow))
            Button("Restart Round", action: onRestart)
                .buttonStyle(CartoonButtonStyle(fill: .white))
            Button(leaveTitle, action: onLeave)
                .buttonStyle(CartoonButtonStyle(fill: .white))
        }
    }
}

private struct ResultsOverlay: View {
    let outcome: BattleOutcome
    let engine: BattleEngine
    let onRematch: () -> Void
    let onChangeFighters: () -> Void
    let onMenu: () -> Void

    var body: some View {
        OverlayCard {
            switch outcome {
            case .winner(let slot):
                let fighter = engine.simulation.state.fighter(slot)
                OutlinedText("\(slot.title.uppercased()) WINS!", size: 34, fill: slot.color, outline: 3.5)
                    .rotationEffect(.degrees(-3))
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
                    .rotationEffect(.degrees(-3))
                Text("Both fighters went down on the same frame!")
                    .font(Theme.bodyFont(16, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
            }

            Text("Match time \(String(format: "%.1f", engine.simulation.battleTime))s")
                .font(Theme.bodyFont(13, weight: .heavy))
                .foregroundStyle(Theme.textSecondary)
                .padding(.bottom, 4)

            Button("Rematch", action: onRematch)
                .buttonStyle(CartoonButtonStyle(fill: Theme.yellow))
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
    let onNextRound: () -> Void
    let onPlayAgain: () -> Void
    let onMenu: () -> Void

    var body: some View {
        OverlayCard {
            if let final = series.outcome {
                switch final {
                case .playerWins:
                    OutlinedText("VICTORY!", size: 44, fill: Theme.yellow, outline: 4).rotationEffect(.degrees(-3))
                    caption("You knocked out the whole bot team!")
                case .botWins:
                    OutlinedText("DEFEAT", size: 44, fill: PlayerSlot.two.color, outline: 4).rotationEffect(.degrees(-3))
                    caption("The bot knocked out your whole team.")
                case .draw:
                    OutlinedText("SERIES DRAW!", size: 36, fill: Theme.yellow, outline: 4).rotationEffect(.degrees(-3))
                    caption("Both teams' last fighters went down together.")
                }
            } else {
                switch outcome {
                case .winner(.one):
                    OutlinedText("ROUND WON!", size: 38, fill: PlayerSlot.one.color, outline: 3.5).rotationEffect(.degrees(-3))
                case .winner(.two):
                    OutlinedText("ROUND LOST", size: 38, fill: PlayerSlot.two.color, outline: 3.5).rotationEffect(.degrees(-3))
                case .draw:
                    OutlinedText("DOUBLE K.O.!", size: 34, fill: Theme.yellow, outline: 3.5).rotationEffect(.degrees(-3))
                }
            }

            TeamStatusRow(title: "YOUR TEAM", members: series.player, color: PlayerSlot.one.color)
            TeamStatusRow(title: "BOT TEAM", members: series.bot, color: PlayerSlot.two.color)
                .padding(.bottom, 4)

            if series.outcome == nil {
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
        Text(text)
            .font(Theme.bodyFont(15, weight: .heavy))
            .foregroundStyle(Theme.ink)
            .multilineTextAlignment(.center)
    }
}
