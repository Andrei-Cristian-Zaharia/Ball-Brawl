import SwiftUI

/// VS Bot: between rounds the player keeps their survivor or sends in another fighter.
struct RoundPrepView: View {
    let model: AppModel
    let series: BotSeries
    @State private var selected: Int?
    @State private var aimAngle: Double = .pi / 2

    private var choice: Int? { selected ?? series.playerSurvivor ?? series.playerChoices.first }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                HStack {
                    BackButton(title: "Quit", action: model.showMenu)
                    Spacer()
                }

                VStack(spacing: 4) {
                    OutlinedText(String(localized: "ROUND \(series.round)"), size: 36, fill: Theme.yellow, outline: 3.5)
                    if let deadline = model.pickDeadline, !model.isWaitingForOpponentPick {
                        PickClock(deadline: deadline, total: AppModel.pickDuration)
                    }
                    Text(instructions)
                        .font(Theme.bodyFont(14, weight: .heavy))
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                }

                TeamStatusRow(title: model.opponentTeamTitle, members: series.bot, color: PlayerSlot.two.color,
                              activeIndex: series.botSurvivor)
                    .padding(12)
                    .cartoonCard(fill: Theme.cream, cornerRadius: 20, shadow: 6, lineWidth: 3)

                VStack(alignment: .leading, spacing: 10) {
                    Text("YOUR TEAM — TAP TO CHOOSE")
                        .font(Theme.bodyFont(12, weight: .black))
                        .foregroundStyle(Theme.ink.opacity(0.7))
                    HStack(spacing: 8) {
                        ForEach(series.player) { member in
                            Button {
                                selected = member.id
                            } label: {
                                TeamMemberTile(member: member, color: PlayerSlot.one.color,
                                               isSelected: member.id == choice, tag: tag(for: member))
                            }
                            .buttonStyle(.plain)
                            .disabled(!member.isAlive)
                        }
                    }
                    .padding(.top, 8)

                    if let choice, series.player[choice].definition.requiresAim {
                        AimPickerView(definition: series.player[choice].definition, slot: .one, angle: $aimAngle)
                    }
                }
                .padding(12)
                .cartoonCard(fill: Theme.cream, cornerRadius: 20, shadow: 6, lineWidth: 3)
                .animation(.spring(duration: 0.3, bounce: 0.4), value: choice)

                Button {
                    if let choice { model.startSeriesRound(playerIndex: choice, aimAngle: aimAngle) }
                } label: {
                    HStack(spacing: 10) {
                        if model.isWaitingForOpponentPick {
                            ProgressView().tint(Theme.ink)
                            Text("WAITING FOR \(model.opponentName.uppercased())…")
                        } else {
                            Image(systemName: "bolt.fill")
                            Text(fightLabel)
                        }
                    }
                }
                .buttonStyle(CartoonButtonStyle(fill: Theme.yellow, fontSize: 22, cornerRadius: 20))
                .disabled(choice == nil || model.isWaitingForOpponentPick)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        // Out of time: whatever is chosen now gets sent.
        .task(id: model.pickDeadline) {
            guard let deadline = model.pickDeadline else { return }
            try? await Task.sleep(for: .seconds(max(0, deadline.timeIntervalSinceNow)))
            guard !Task.isCancelled else { return }
            model.pickTimedOut(choice: choice, aimAngle: aimAngle)
        }
    }

    private var instructions: String {
        if let survivor = series.playerSurvivor {
            let member = series.player[survivor]
            return String(localized: "Your \(member.definition.name) survived with \(Int(member.health.rounded(.up))) HP. Keep it in, or swap in a teammate.")
        }
        if series.round == 1 {
            return String(localized: "Choose who starts. Health carries over between rounds.")
        }
        return String(localized: "Your fighter was knocked out. Send in one of your remaining fighters.")
    }

    private func tag(for member: TeamMember) -> String? {
        guard member.isAlive, member.id == choice else { return nil }
        if member.id == series.playerSurvivor { return String(localized: "KEEP") }
        return series.playerSurvivor == nil ? String(localized: "SEND") : String(localized: "SWAP IN")
    }

    private var fightLabel: String {
        guard let choice else { return String(localized: "FIGHT!") }
        return String(localized: "SEND \(series.player[choice].definition.name.uppercased())!")
    }
}

/// Seconds left to pick, as a draining bar that turns red near the end.
private struct PickClock: View {
    let deadline: Date
    let total: TimeInterval

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { timeline in
            let left = max(0, deadline.timeIntervalSince(timeline.date))
            let urgent = left <= 3
            HStack(spacing: 8) {
                Image(systemName: "timer")
                Text("\(Int(left.rounded(.up)))s")
                    .monospacedDigit()
                    .lineLimit(1)
                    .fixedSize()
                    .frame(minWidth: 34, alignment: .leading)
                GeometryReader { geo in
                    Capsule().fill(Theme.ink.opacity(0.25))
                        .overlay(alignment: .leading) {
                            Capsule().fill(urgent ? Theme.blood : Theme.yellow)
                                .frame(width: geo.size.width * left / total)
                        }
                }
                .frame(height: 10)
                .overlay(Capsule().strokeBorder(Theme.ink, lineWidth: 2))
            }
            .font(Theme.bodyFont(15, weight: .black))
            .foregroundStyle(urgent ? Theme.blood : Theme.ink)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .frame(maxWidth: 260)
            .background(Capsule().fill(.white))
            .overlay(Capsule().strokeBorder(Theme.ink, lineWidth: 2.5))
            .scaleEffect(urgent && Int(left * 2).isMultiple(of: 2) ? 1.05 : 1)
            .animation(.easeInOut(duration: 0.2), value: urgent ? Int(left * 2) : 0)
        }
    }
}
