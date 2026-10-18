import SwiftUI

/// VS Bot: the player picks 3 different fighters for their team.
struct TeamSelectView: View {
    let model: AppModel
    @State private var picks: [String] = []

    private var team: [FighterDefinition] { picks.compactMap(FighterCatalog.definition(id:)) }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                HStack {
                    BackButton(title: "Menu", action: model.showMenu)
                    Spacer()
                }

                VStack(spacing: 4) {
                    ScreenTitle("PICK YOUR TEAM", subtitle: "Choose 3 fighters. The bot picks 3 at random.")
                }

                teamSlots
                PresetPicker(profile: model.profile, isUnavailable: { !model.profile.isUnlocked($0) }) { preset in
                    picks = Array(preset.filter(model.profile.isUnlocked).prefix(BotSeries.teamSize))
                }
                .padding(10)
                .cartoonCard(fill: Theme.cream, cornerRadius: 18, shadow: 4, lineWidth: 3)
                .frame(maxWidth: 520)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 14) {
                    ForEach(model.profile.unlockedRoster) { fighter in
                        pickCard(fighter)
                    }
                }

                Button {
                    model.confirmTeam(team)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                        Text(picks.count == BotSeries.teamSize ? String(localized: "CONFIRM TEAM") : String(localized: "PICK \(BotSeries.teamSize - picks.count) MORE"))
                    }
                }
                .buttonStyle(CartoonButtonStyle(fill: Theme.yellow, fontSize: 22, cornerRadius: 20))
                .frame(maxWidth: 440)
                .disabled(picks.count != BotSeries.teamSize)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }

    private var teamSlots: some View {
        HStack(spacing: 12) {
            ForEach(0..<BotSeries.teamSize, id: \.self) { i in
                ZStack {
                    if i < team.count {
                        FighterPortrait(definition: team[i], color: PlayerSlot.one.color, size: 64, expression: .happy)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Text("?")
                            .font(Theme.titleFont(30))
                            .foregroundStyle(Theme.ink.opacity(0.25))
                    }
                }
                .frame(width: 84, height: 84)
                .cartoonCard(fill: i < team.count ? PlayerSlot.one.lightColor : Theme.cream, cornerRadius: 18, shadow: 4)
                .onTapGesture { if i < picks.count { picks.remove(at: i) } }
            }
        }
        .animation(.spring(duration: 0.3, bounce: 0.5), value: picks)
    }

    private func pickCard(_ fighter: FighterDefinition) -> some View {
        let order = picks.firstIndex(of: fighter.id)
        let selected = order != nil
        let full = picks.count >= BotSeries.teamSize
        return Button {
            if let order { picks.remove(at: order) } else if !full { picks.append(fighter.id) }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 8) {
                    FighterPortrait(definition: fighter, color: PlayerSlot.one.color, size: 54,
                                    expression: selected ? .happy : .normal)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(fighter.name).font(Theme.titleFont(18)).foregroundStyle(Theme.ink)
                        HStack(spacing: 4) {
                            RarityBadge(rarity: fighter.rarity, size: 8)
                            LevelBadge(level: model.profile.level(of: fighter.id), size: 9)
                        }
                        Text(fighter.attackName.localized.uppercased())
                            .font(Theme.bodyFont(10, weight: .black))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(PlayerSlot.one.color))
                            .overlay(Capsule().strokeBorder(Theme.ink, lineWidth: 1.5))
                    }
                    Spacer(minLength: 0)
                }
                Text(fighter.attackDescription.localized)
                    .font(Theme.bodyFont(11, weight: .semibold))
                    .foregroundStyle(Theme.ink.opacity(0.75))
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
            .cartoonCard(fill: selected ? PlayerSlot.one.lightColor : fighter.rarity.color.mix(with: .white, by: 0.8),
                         cornerRadius: 16, shadow: selected ? 1 : 4)
            .offset(y: selected ? 3 : 0)
            .overlay(alignment: .topTrailing) {
                if let order {
                    Text("\(order + 1)")
                        .font(Theme.titleFont(16))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Theme.yellow))
                        .overlay(Circle().strokeBorder(Theme.ink, lineWidth: 3))
                        .offset(x: 6, y: -6)
                        .transition(.scale)
                }
            }
        }
        .buttonStyle(.plain)
        .opacity(full && !selected ? 0.5 : 1)
        .animation(.spring(duration: 0.3, bounce: 0.5), value: selected)
    }
}
