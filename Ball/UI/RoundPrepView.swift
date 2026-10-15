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
                    OutlinedText("ROUND \(series.round)", size: 36, fill: Theme.yellow, outline: 3.5)
                        .rotationEffect(.degrees(-2))
                    Text(instructions)
                        .font(Theme.bodyFont(14, weight: .heavy))
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                }

                TeamStatusRow(title: "BOT TEAM", members: series.bot, color: PlayerSlot.two.color,
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
                    if let choice { model.startBotRound(playerIndex: choice, aimAngle: aimAngle) }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "bolt.fill")
                        Text(fightLabel)
                    }
                }
                .buttonStyle(CartoonButtonStyle(fill: Theme.yellow, fontSize: 22, cornerRadius: 20))
                .disabled(choice == nil)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }

    private var instructions: String {
        if let survivor = series.playerSurvivor {
            let member = series.player[survivor]
            return "Your \(member.definition.name) survived with \(Int(member.health.rounded(.up))) HP. Keep it in, or swap in a teammate."
        }
        if series.round == 1 {
            return "Choose who starts. Health carries over between rounds."
        }
        return "Your fighter was knocked out. Send in one of your remaining fighters."
    }

    private func tag(for member: TeamMember) -> String? {
        guard member.isAlive, member.id == choice else { return nil }
        if member.id == series.playerSurvivor { return "KEEP" }
        return series.playerSurvivor == nil ? "SEND" : "SWAP IN"
    }

    private var fightLabel: String {
        guard let choice else { return "FIGHT!" }
        return "SEND \(series.player[choice].definition.name.uppercased())!"
    }
}
