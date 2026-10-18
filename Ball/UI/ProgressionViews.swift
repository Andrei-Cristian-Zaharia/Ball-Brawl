import SwiftUI

/// "EPIC"-style chip in the rarity's color.
struct RarityBadge: View {
    let rarity: Rarity
    var size: CGFloat = 10

    var body: some View {
        Text(rarity.name.localized.uppercased())
            .font(Theme.bodyFont(size, weight: .black))
            .foregroundStyle(Theme.ink)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, size * 0.6).padding(.vertical, size * 0.15)
            .background(Capsule().fill(rarity.color))
            .overlay(Capsule().strokeBorder(Theme.ink, lineWidth: 2))
    }
}

/// "LV 4" chip; gold once the ball is maxed.
struct LevelBadge: View {
    let level: Int
    var size: CGFloat = 11

    var body: some View {
        Text(level >= Progression.maxLevel ? String(localized: "MAX") : String(localized: "LV \(level)"))
            .font(Theme.bodyFont(size, weight: .black))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, size * 0.55).padding(.vertical, size * 0.12)
            .background(RoundedRectangle(cornerRadius: size * 0.5).fill(level >= Progression.maxLevel ? Theme.yellow : .white))
            .overlay(RoundedRectangle(cornerRadius: size * 0.5).strokeBorder(Theme.ink, lineWidth: 2))
    }
}

/// Stars for unlocked star powers (levels 5 and 10).
struct StarRow: View {
    let level: Int
    var size: CGFloat = 11

    var body: some View {
        HStack(spacing: 1) {
            ForEach(Progression.starLevels, id: \.self) { starLevel in
                Image(systemName: level >= starLevel ? "star.fill" : "star")
                    .font(.system(size: size, weight: .black))
                    .foregroundStyle(level >= starLevel ? Theme.yellow : Theme.ink.opacity(0.3))
            }
        }
    }
}

/// Cards collected toward the next level.
struct CardProgressBar: View {
    let have: Int
    let need: Int?
    var height: CGFloat = 16

    var body: some View {
        let full = need.map { have >= $0 } ?? true
        GeometryReader { geo in
            ZStack {
                Capsule().fill(Theme.ink.mix(with: .white, by: 0.2))
                Capsule().fill(full ? Theme.heal : Color(red: 0.3, green: 0.6, blue: 1))
                    .frame(width: geo.size.width * (need.map { min(1, Double(have) / Double(max(1, $0))) } ?? 1))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(need.map { "\(have)/\($0)" } ?? String(localized: "MAX"))
                    .font(Theme.bodyFont(height * 0.62, weight: .black))
                    .foregroundStyle(.white)
                    .shadow(color: Theme.ink, radius: 0, x: 1, y: 1)
            }
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(Theme.ink, lineWidth: 2))
        }
        .frame(height: height)
    }
}

/// Coin icon and amount.
struct CoinLabel: View {
    let amount: Int
    var size: CGFloat = 16
    var textColor: Color = Theme.ink

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Theme.yellow)
                .overlay(Circle().strokeBorder(Theme.ink, lineWidth: 2))
                .overlay(Text("$").font(.system(size: size * 0.6, weight: .black, design: .rounded)).foregroundStyle(Theme.ink))
                .frame(width: size * 1.1, height: size * 1.1)
            Text("\(amount)")
                .font(.system(size: size, weight: .black, design: .rounded).monospacedDigit())
                .foregroundStyle(textColor)
                .lineLimit(1)
                .fixedSize()
        }
    }
}

/// "+40 coins · +1 chest" after a battle.
struct RewardsLine: View {
    let rewards: Progression.Rewards

    var body: some View {
        HStack(spacing: 12) {
            if rewards.trophies != 0 {
                HStack(spacing: 4) {
                    Image(systemName: "trophy.fill").foregroundStyle(Theme.overtime)
                    Text(rewards.trophies > 0 ? "+\(rewards.trophies)" : "\(rewards.trophies)")
                        .foregroundStyle(rewards.trophies > 0 ? Theme.ink : Theme.blood)
                }
                .font(.system(size: 16, weight: .black, design: .rounded))
            }
            if rewards.coins > 0 {
                HStack(spacing: 2) {
                    plus
                    CoinLabel(amount: rewards.coins, size: 16)
                }
            }
            ForEach(ChestKind.allCases.reversed().filter(rewards.chests.contains), id: \.self) { kind in
                HStack(spacing: 2) {
                    ChestIcon(kind: kind, size: 26)
                    let count = rewards.chests.filter { $0 == kind }.count
                    if count > 1 {
                        Text("×\(count)").font(.system(size: 15, weight: .black, design: .rounded)).foregroundStyle(Theme.ink)
                    }
                }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .cartoonCard(fill: .white, cornerRadius: 12, shadow: 0, lineWidth: 2.5)
    }

    private var plus: some View {
        Text("+").font(.system(size: 16, weight: .black, design: .rounded)).foregroundStyle(Theme.ink)
    }
}

/// Row of the player's 3 team presets; tapping one loads it into the team being picked.
struct PresetPicker: View {
    let profile: ProfileStore
    /// Balls that can't be picked right now (e.g. resting in the crusade) are greyed in the chips.
    var isUnavailable: (String) -> Bool = { _ in false }
    let onLoad: ([String]) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text("PRESETS")
                .font(Theme.bodyFont(11, weight: .black))
                .foregroundStyle(Theme.ink.opacity(0.7))
            ForEach(0..<PlayerProfile.presetCount, id: \.self) { index in
                chip(index)
            }
        }
    }

    private func chip(_ index: Int) -> some View {
        let team = profile.teamPresets[index]
        return Button {
            if !team.isEmpty { onLoad(team) }
        } label: {
            HStack(spacing: -8) {
                if team.isEmpty {
                    Text("\(index + 1) · empty")
                        .font(Theme.bodyFont(10, weight: .black))
                        .foregroundStyle(Theme.ink.opacity(0.6))
                        .padding(.horizontal, 4)
                } else {
                    ForEach(team, id: \.self) { id in
                        if let base = FighterCatalog.definition(id: id) {
                            FighterPortrait(definition: base, color: isUnavailable(id) ? Theme.disabled : base.rarity.color,
                                            size: 26, expression: isUnavailable(id) ? .knockedOut : .happy)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 34)
            .background(Capsule().fill(.white))
            .overlay(Capsule().strokeBorder(Theme.ink, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }
}

/// The player's level on a blue shield-like star.
struct PlayerLevelBadge: View {
    let level: Int
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            Image(systemName: "seal.fill")
                .resizable()
                .foregroundStyle(LinearGradient(colors: [Color(red: 0.35, green: 0.7, blue: 1), Color(red: 0.12, green: 0.38, blue: 0.85)],
                                                startPoint: .top, endPoint: .bottom))
                .background(Image(systemName: "seal.fill").resizable().foregroundStyle(Theme.ink).scaleEffect(1.14))
            Text("\(level)")
                .font(Theme.titleFont(size * 0.42))
                .foregroundStyle(.white)
                .shadow(color: Theme.ink, radius: 0, x: 0, y: size * 0.04)
        }
        .frame(width: size, height: size)
    }
}

/// "LEVEL UP!" with the new level and what it paid.
struct LevelUpOverlay: View {
    let levelUp: LevelUp
    let onDone: () -> Void
    @State private var shown = false

    var body: some View {
        ZStack {
            Theme.ink.opacity(0.7).ignoresSafeArea()
                .onTapGesture(perform: onDone)
            VStack(spacing: 14) {
                OutlinedText("LEVEL UP!", size: 40, fill: Theme.yellow, outline: 4)
                    .fixedSize()
                PlayerLevelBadge(level: levelUp.level, size: 110)
                    .scaleEffect(shown ? 1 : 0.3)
                    .rotationEffect(.degrees(shown ? 0 : -40))
                    .shadow(color: Theme.yellow.opacity(0.7), radius: shown ? 22 : 0)
                Text("You reached level \(levelUp.level)!")
                    .font(Theme.titleFont(20))
                    .foregroundStyle(Theme.ink)
                RewardsLine(rewards: levelUp.rewards)
                    .scaleEffect(shown ? 1 : 0.5)
                    .opacity(shown ? 1 : 0)
                    .animation(.spring(duration: 0.4, bounce: 0.5).delay(0.3), value: shown)
                Text("Chests wait in your Collection.")
                    .font(Theme.bodyFont(12, weight: .heavy))
                    .foregroundStyle(Theme.textSecondary)
                Button("Collect", action: onDone)
                    .buttonStyle(CartoonButtonStyle(fill: Theme.yellow))
            }
            .padding(22)
            .frame(maxWidth: 360)
            .cartoonCard(fill: Theme.cream, cornerRadius: 28, shadow: 8, lineWidth: 4)
            .padding(20)
        }
        .sensoryFeedback(.success, trigger: shown) { _, _ in GameSettings.vibrationEnabled }
        .onAppear { withAnimation(.spring(duration: 0.6, bounce: 0.55)) { shown = true } }
    }
}
