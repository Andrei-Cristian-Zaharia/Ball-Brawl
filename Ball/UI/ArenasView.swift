import SwiftUI

/// The trophy road: arenas stacked from the top arena down to the first, beside a track that fills
/// with gold up to the player's trophies. Each arena shows its art, the trophies it takes and its balls.
struct ArenasView: View {
    let model: AppModel
    /// The arena row the road is scrolled to.
    @State private var focused: Int?

    private var profile: ProfileStore { model.profile }

    var body: some View {
        VStack(spacing: 10) {
            // Header stays put; only the road scrolls.
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    BackButton(title: "Menu", action: model.showMenu)
                    Spacer()
                    Button(action: model.online.showLeaderboard) {
                        Label("Leaderboard", systemImage: "list.number")
                            .font(Theme.bodyFont(13, weight: .black))
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, 10).padding(.vertical, 7)
                            .cartoonCard(fill: Theme.yellow, cornerRadius: 12, shadow: 3, lineWidth: 2.5)
                    }
                    .buttonStyle(.plain)
                    TrophyPill(trophies: profile.trophies)
                }
                VStack(spacing: 4) {
                    ScreenTitle("TROPHY ROAD", subtitle: "Win ranked battles for trophies. Every arena adds new balls to your chests.")
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Arenas.tiers.reversed(), id: \.number) { tier in
                        roadRow(tier)
                            .padding(.horizontal, 16)
                            .id(tier.number)
                    }
                }
                .scrollTargetLayout()
                .padding(.vertical, 8)
            }
            .scrollIndicators(.hidden)
            // Open centered on the player's current arena.
            .scrollPosition(id: $focused, anchor: .center)
            .onAppear { focused = profile.arena.number }
        }
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
    }

    // MARK: Road

    private static let railWidth: CGFloat = 58
    /// Every row is the same height, so the track can be drawn without measuring.
    private static let rowHeight: CGFloat = 262

    /// One arena: its stretch of the track on the left, its card on the right.
    private func roadRow(_ tier: ArenaTier) -> some View {
        HStack(alignment: .top, spacing: 10) {
            rail(tier)
                .frame(width: Self.railWidth, height: Self.rowHeight)
            arenaCard(tier)
                .padding(.bottom, 16)
        }
        .frame(height: Self.rowHeight)
    }

    /// The track beside an arena: filled from its gate up toward the next arena by the player's trophies,
    /// with the gate's trophy count in a medallion.
    private func rail(_ tier: ArenaTier) -> some View {
        let next = Arenas.next(after: tier)
        let span = Double((next?.trophies ?? tier.trophies + 500) - tier.trophies)
        let fill = max(0, min(1, Double(profile.trophies - tier.trophies) / max(1, span)))
        let reached = profile.trophies >= tier.trophies
        let isCurrent = profile.arena.number == tier.number
        let track = Self.rowHeight - 30
        return ZStack(alignment: .bottom) {
            Capsule()
                .fill(Theme.ink.opacity(0.35))
                .frame(width: 16)
                .overlay(Capsule().strokeBorder(Theme.ink, lineWidth: 2.5))
            Capsule()
                .fill(LinearGradient(colors: [Theme.yellow, Theme.overtime], startPoint: .top, endPoint: .bottom))
                .frame(width: 10, height: track * fill + (reached ? 30 : 0))
                .padding(.bottom, 3)
            if isCurrent {
                // "You" marker at the current trophy position.
                Text("\(profile.trophies)")
                    .font(Theme.bodyFont(11, weight: .black))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(Capsule().fill(PlayerSlot.one.color))
                    .overlay(Capsule().strokeBorder(Theme.ink, lineWidth: 2))
                    .fixedSize()
                    .offset(y: -(track * fill + 34))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottom) { medallion(tier, reached: reached) }
    }

    private func medallion(_ tier: ArenaTier, reached: Bool) -> some View {
        VStack(spacing: 0) {
            Image(systemName: "trophy.fill").font(.system(size: 11, weight: .bold))
            Text("\(tier.trophies)").font(Theme.bodyFont(11, weight: .black)).lineLimit(1).minimumScaleFactor(0.7)
        }
        .foregroundStyle(reached ? Theme.ink : .white)
        .frame(width: 50, height: 50)
        .background(Circle().fill(reached ? Theme.yellow : Theme.ink.mix(with: .white, by: 0.25)))
        .overlay(Circle().strokeBorder(Theme.ink, lineWidth: 3))
    }

    // MARK: Arena card

    private func arenaCard(_ tier: ArenaTier) -> some View {
        let reached = profile.bestArena.number >= tier.number
        let current = profile.arena.number == tier.number
        let toGo = max(0, tier.trophies - profile.bestTrophiesValue)
        return VStack(spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                ArenaBanner(map: tier.map)
                    .frame(height: 104)
                LinearGradient(colors: [.clear, .clear, Theme.ink.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                    .mask(LinearGradient(colors: [.black, .black.opacity(0.3)], startPoint: .leading, endPoint: .trailing))
                VStack(alignment: .leading, spacing: 3) {
                    ArenaNumberChip(number: tier.number)
                    OutlinedText(tier.name.localized.uppercased(), size: 21, fill: .white, outline: 2.4)
                        .fixedSize()
                }
                .padding(10)
            }
            .frame(height: 104)
            .overlay(alignment: .topTrailing) { statusBadge(reached: reached, current: current, toGo: toGo).padding(8) }
            .overlay {
                if !reached { Theme.ink.opacity(0.35) }
            }
            .clipped()
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.ink).frame(height: 2.5) }

            // The balls this arena adds to chests.
            HStack(spacing: 4) {
                ForEach(tier.balls, id: \.self) { id in
                    if let base = FighterCatalog.definition(id: id) {
                        // Reached but not found yet: shown faded with a chest mark until its first card drops.
                        let found = profile.isUnlocked(id)
                        VStack(spacing: 1) {
                            // Arenas with many balls shrink them so the row still fits the card.
                            FighterPortrait(definition: base, color: reached ? base.rarity.color : Theme.disabled,
                                            size: tier.balls.count > 6 ? 30 : tier.balls.count > 5 ? 36 : 40,
                                            expression: found ? .happy : .normal)
                                .opacity(reached && !found ? 0.55 : 1)
                                .overlay(alignment: .bottomTrailing) {
                                    if reached && !found {
                                        Image(systemName: "shippingbox.fill")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(.white)
                                            .frame(width: 17, height: 17)
                                            .background(Circle().fill(Theme.ink.opacity(0.85)))
                                    }
                                }
                            Text(base.name)
                                .font(Theme.bodyFont(9, weight: .black))
                                .foregroundStyle(reached ? Theme.ink : Theme.textSecondary)
                                .lineLimit(1).minimumScaleFactor(0.6)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.horizontal, 6).padding(.vertical, 8)
            .background(reached ? tier.map.floor.mix(with: .white, by: 0.6) : Theme.cream.mix(with: Theme.ink, by: 0.08))

            rewardsStrip(tier)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(current ? Theme.yellow : Theme.ink, lineWidth: current ? 4 : 3))
        .background(RoundedRectangle(cornerRadius: 18).fill(Theme.ink).offset(y: 5))
    }

    // MARK: Rewards

    /// The rewards on this arena's stretch of the road, claimed by tapping once reached.
    private func rewardsStrip(_ tier: ArenaTier) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(TrophyRoad.rewards(in: tier)) { reward in
                    rewardChip(reward)
                }
            }
            .padding(.horizontal, 8).padding(.vertical, 7)
        }
        .scrollIndicators(.hidden)
        .frame(height: 68)
        .background(Theme.cream)
        .overlay(alignment: .top) { Rectangle().fill(Theme.ink).frame(height: 2.5) }
    }

    private func rewardChip(_ reward: TrophyReward) -> some View {
        let claimed = profile.isClaimed(reward)
        let ready = profile.canClaim(reward)
        return Button { model.claimRoadReward(reward) } label: {
            VStack(spacing: 2) {
                rewardArt(reward.kind)
                    .frame(height: 26)
                    .opacity(claimed ? 0.4 : 1)
                    .overlay(alignment: .bottomTrailing) {
                        if claimed {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14, weight: .black))
                                .foregroundStyle(.white, Theme.go)
                                .offset(x: 6, y: 3)
                        }
                    }
                HStack(spacing: 2) {
                    Image(systemName: ready || claimed ? "trophy.fill" : "lock.fill").font(.system(size: 8, weight: .black))
                    Text("\(reward.trophies)").font(Theme.bodyFont(10, weight: .black).monospacedDigit())
                }
                .foregroundStyle(Theme.ink.opacity(claimed ? 0.5 : 0.85))
            }
            .frame(width: 58, height: 52)
            .background(RoundedRectangle(cornerRadius: 10).fill(ready ? Theme.yellow : claimed ? Theme.creamDark : .white))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.ink, lineWidth: ready ? 2.5 : 1.5))
            .modifier(ReadyPulse(active: ready))
        }
        .buttonStyle(.plain)
        .disabled(!ready)
        .accessibilityLabel(Self.rewardDescription(reward.kind) + ", " + String(localized: "\(reward.trophies) trophies"))
    }

    @ViewBuilder private func rewardArt(_ kind: TrophyReward.Kind) -> some View {
        switch kind {
        case .coins(let amount):
            CoinLabel(amount: amount, size: 11)
        case .chest(let chest):
            ChestIcon(kind: chest, size: 28)
        case .cards(let rarity, let count):
            HStack(spacing: 2) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(rarity.color)
                    .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Theme.ink, lineWidth: 1.5))
                    .overlay(Image(systemName: "questionmark").font(.system(size: 9, weight: .black)).foregroundStyle(.white))
                    .frame(width: 16, height: 22)
                Text("×\(count)").font(Theme.bodyFont(11, weight: .black)).foregroundStyle(Theme.ink)
            }
        }
    }

    private static func rewardDescription(_ kind: TrophyReward.Kind) -> String {
        switch kind {
        case .coins(let amount): return String(localized: "\(amount) coins")
        case .chest(let chest): return chest.name.localized
        case .cards(let rarity, let count): return String(localized: "\(count) \(rarity.name.localized) cards")
        }
    }

    @ViewBuilder private func statusBadge(reached: Bool, current: Bool, toGo: Int) -> some View {
        if current {
            badge("YOU ARE HERE", icon: "person.fill", fill: PlayerSlot.one.color, text: .white)
        } else if reached {
            badge("UNLOCKED", icon: "checkmark", fill: Theme.go, text: .white)
        } else {
            badge(String(localized: "\(toGo) TO GO"), icon: "lock.fill", fill: Theme.ink.mix(with: .white, by: 0.15), text: .white)
        }
    }

    private func badge(_ title: String, icon: String, fill: Color, text: Color) -> some View {
        Label(title.localized, systemImage: icon)
            .font(Theme.bodyFont(10, weight: .black))
            .foregroundStyle(text)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Capsule().fill(fill))
            .overlay(Capsule().strokeBorder(Theme.ink, lineWidth: 2))
            .fixedSize()
    }
}

/// "ARENA 2" on a gold chip, readable over any arena art.
struct ArenaNumberChip: View {
    let number: Int

    var body: some View {
        Text("ARENA \(number)")
            .font(Theme.bodyFont(10, weight: .black))
            .tracking(1.2)
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(Capsule().fill(Theme.yellow))
            .overlay(Capsule().strokeBorder(Theme.ink, lineWidth: 1.5))
            .fixedSize()
    }
}

/// Trophy count in a pill (menu header, arenas screen).
struct TrophyPill: View {
    let trophies: Int
    var arenaName: String?

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.overtime)
            VStack(alignment: .leading, spacing: -1) {
                Text("\(trophies)")
                    .font(.system(size: 16, weight: .black, design: .rounded).monospacedDigit())
                    .foregroundStyle(Theme.ink)
                if let arenaName {
                    Text(arenaName.localized.uppercased())
                        .font(Theme.bodyFont(9, weight: .black))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .fixedSize()
        .cartoonCard(fill: Theme.cream, cornerRadius: 12, shadow: 3, lineWidth: 2.5)
    }
}

/// Celebration when a new arena is reached for the first time.
struct NewArenaOverlay: View {
    let tier: ArenaTier
    let onDone: () -> Void
    @State private var shown = false

    var body: some View {
        ZStack {
            Theme.ink.opacity(0.6).ignoresSafeArea()
                .onTapGesture(perform: onDone)
            VStack(spacing: 14) {
                OutlinedText("NEW ARENA!", size: 36, fill: Theme.yellow, outline: 3.5)
                    .fixedSize()
                ArenaBanner(map: tier.map)
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.ink.opacity(0.85), lineWidth: 2.5))
                    .scaleEffect(shown ? 1 : 0.6)
                Text("Arena \(tier.number) · \(tier.name.localized)")
                    .font(Theme.titleFont(22))
                    .foregroundStyle(Theme.ink)
                Text("New balls in chests — open chests to find them:")
                    .font(Theme.bodyFont(13, weight: .heavy))
                    .foregroundStyle(Theme.textSecondary)
                HStack(spacing: 8) {
                    ForEach(Array(tier.balls.enumerated()), id: \.offset) { index, id in
                        if let base = FighterCatalog.definition(id: id) {
                            VStack(spacing: 2) {
                                FighterPortrait(definition: base, color: base.rarity.color, size: 52, expression: .happy)
                                Text(base.name).font(Theme.bodyFont(11, weight: .black)).foregroundStyle(Theme.ink)
                            }
                            .opacity(shown ? 1 : 0)
                            .offset(y: shown ? 0 : 16)
                            .animation(.spring(duration: 0.4, bounce: 0.5).delay(0.2 + Double(index) * 0.12), value: shown)
                        }
                    }
                }
                Button("Awesome!", action: onDone)
                    .buttonStyle(CartoonButtonStyle(fill: Theme.yellow))
            }
            .padding(22)
            .frame(maxWidth: 380)
            .cartoonCard(fill: Theme.cream, cornerRadius: 28, shadow: 8, lineWidth: 4)
            .padding(20)
        }
        .onAppear { withAnimation(.spring(duration: 0.5, bounce: 0.5)) { shown = true } }
    }
}

/// A gentle bounce on rewards waiting to be claimed.
private struct ReadyPulse: ViewModifier {
    let active: Bool
    @State private var up = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(active && up ? 1.06 : 1)
            .onAppear {
                guard active else { return }
                withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { up = true }
            }
    }
}
