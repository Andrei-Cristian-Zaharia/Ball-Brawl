import SwiftUI

/// Main menu, laid out to fit one screen: wallet, title, the arena (ranked Battle), the daily Crusade,
/// and the other modes as compact rows.
struct MenuView: View {
    let model: AppModel

    /// Deeper, richer takes on the team colors for the mode tiles.
    private static let crimson = Color(red: 0.85, green: 0.2, blue: 0.27)
    private static let amber = Color(red: 0.95, green: 0.52, blue: 0.12)
    private static let royal = Color(red: 0.17, green: 0.46, blue: 0.92)
    private static let violet = Color(red: 0.55, green: 0.31, blue: 0.86)
    private static let forest = Color(red: 0.12, green: 0.48, blue: 0.3)
    private static let gold = Color(red: 1.0, green: 0.8, blue: 0.25)

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Button(action: model.openShop) {
                    HStack(spacing: 5) {
                        Image(systemName: "cart.fill")
                        Text("SHOP")
                    }
                    .font(Theme.bodyFont(14, weight: .black))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .shadow(color: Theme.ink.opacity(0.6), radius: 0, x: 0, y: 1.5)
                    .cartoonCard(fill: Theme.go, cornerRadius: 12, shadow: 3, lineWidth: 2.5)
                }
                .buttonStyle(.plain)
                .fixedSize()
                dailyButton
                Spacer()
                WalletBar(model: model)
            }
            .padding(.top, 4)

            HStack(spacing: 10) {
                PlayerLevelBar(model: model)
                Button(action: model.openSettings) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 46, height: 46)
                        .cartoonCard(fill: Theme.cream, cornerRadius: 14, shadow: 3, lineWidth: 2.5)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Settings")
            }

            Spacer(minLength: 0)

            title

            arenaCard

            crusadeCard

            Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                GridRow {
                    modeTile(title: "VS BOT", subtitle: "3v3 vs computer", icon: "cpu",
                             fill: Self.crimson, action: model.openBotTeamSelect)
                    modeTile(title: "ONLINE", subtitle: "Casual & friends", icon: "globe",
                             fill: Self.amber, action: model.openOnlineLobby)
                }
                GridRow {
                    modeTile(title: "2 PLAYERS", subtitle: "Same device", icon: "person.2.fill",
                             fill: Self.royal, action: model.openLocalSetup)
                    modeTile(title: "COLLECTION", subtitle: collectionSubtitle, icon: "square.stack.3d.up.fill",
                             fill: Self.violet, badge: model.profile.upgradesAvailable, action: model.openCollection)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .frame(maxWidth: 460)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Daily rewards, with a badge while something is waiting to be collected.
    private var dailyButton: some View {
        TimelineView(.periodic(from: .now, by: 30)) { timeline in
            let ready = model.profile.dailyClaimable(now: timeline.date)
            Button(action: model.openDaily) {
                Image(systemName: "gift.fill")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 34, height: 32)
                    .cartoonCard(fill: Theme.yellow, cornerRadius: 12, shadow: 3, lineWidth: 2.5)
            }
            .buttonStyle(.plain)
            .overlay(alignment: .topTrailing) {
                if ready > 0 {
                    Text("\(ready)")
                        .font(Theme.bodyFont(11, weight: .black))
                        .foregroundStyle(.white)
                        .frame(minWidth: 20, minHeight: 20)
                        .background(Circle().fill(Theme.blood))
                        .overlay(Circle().strokeBorder(Theme.ink, lineWidth: 2))
                        .offset(x: 7, y: -7)
                }
            }
            .accessibilityLabel(ready > 0 ? String(localized: "Daily rewards, \(ready) ready") : String(localized: "Daily rewards"))
        }
    }

    private var title: some View {
        HStack(spacing: 10) {
            OutlinedText("BALL", size: 44, fill: .white, outline: 3.5)
                .fixedSize()
            OutlinedText("BRAWL", size: 44, fill: Self.gold, outline: 3.5)
                .fixedSize()
        }
    }

    // MARK: Arena battle

    /// The main event: a ranked battle in your current arena. Tapping the arena opens the trophy road.
    private var arenaCard: some View {
        let profile = model.profile
        let arena = profile.arena
        let next = Arenas.next(after: arena)
        let progress = next.map {
            Double(profile.trophies - arena.trophies) / Double(max(1, $0.trophies - arena.trophies))
        } ?? 1
        let panel = arena.map.background.mix(with: Theme.ink, by: 0.25)
        return VStack(spacing: 0) {
            Button(action: model.openArenas) {
                ZStack(alignment: .bottomLeading) {
                    ArenaBanner(map: arena.map)
                        .frame(height: 104)
                    LinearGradient(colors: [.clear, .clear, Theme.ink.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                        .mask(LinearGradient(colors: [.black, .black.opacity(0.3)], startPoint: .leading, endPoint: .trailing))
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 3) {
                            ArenaNumberChip(number: arena.number)
                            OutlinedText(arena.name.localized.uppercased(), size: 22, fill: .white, outline: 2.5)
                                .fixedSize()
                        }
                        Spacer()
                        HStack(spacing: 3) {
                            Text("ARENAS")
                            Image(systemName: "chevron.right")
                        }
                        .font(Theme.bodyFont(12, weight: .black))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(Self.gold))
                        .overlay(Capsule().strokeBorder(Theme.ink, lineWidth: 2))
                        .overlay(alignment: .topTrailing) {
                            // Trophy road rewards waiting to be claimed.
                            let ready = profile.roadRewardsReady
                            if ready > 0 {
                                Text("\(ready)")
                                    .font(Theme.bodyFont(11, weight: .black))
                                    .foregroundStyle(.white)
                                    .frame(minWidth: 20, minHeight: 20)
                                    .background(Circle().fill(Theme.blood))
                                    .overlay(Circle().strokeBorder(Theme.ink, lineWidth: 2))
                                    .offset(x: 6, y: -9)
                            }
                        }
                    }
                    .padding(10)
                }
                .frame(height: 104)
                .clipped()
            }
            .buttonStyle(.plain)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.ink.opacity(0.8)).frame(height: 2) }

            HStack(spacing: 12) {
                // Trophies toward the next arena.
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 5) {
                        Image(systemName: "trophy.fill").foregroundStyle(Self.gold)
                        Text("\(profile.trophies)")
                            .font(.system(size: 18, weight: .black, design: .rounded).monospacedDigit())
                            .foregroundStyle(.white)
                        if let next {
                            Text("/ \(next.trophies)")
                                .font(Theme.bodyFont(12, weight: .heavy))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.ink.opacity(0.5))
                            Capsule().fill(LinearGradient(colors: [Self.gold, Theme.overtime], startPoint: .leading, endPoint: .trailing))
                                .frame(width: geo.size.width * max(0.03, min(1, progress)))
                        }
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(Theme.ink, lineWidth: 2))
                    }
                    .frame(height: 12)
                    Text(next.map { String(localized: "Next arena: \($0.name.localized)") } ?? String(localized: "Top arena reached!"))
                        .font(Theme.bodyFont(11, weight: .heavy))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                }
                Button(action: model.playRanked) {
                    VStack(spacing: 0) {
                        OutlinedText("BATTLE", size: 23, fill: .white, outline: 2.6)
                            .fixedSize()
                        if case .unavailable = model.online.auth {
                            // Ranked needs Game Center.
                            Label("GAME CENTER", systemImage: "lock.fill")
                                .font(Theme.bodyFont(9, weight: .black))
                                .foregroundStyle(Theme.ink)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        } else {
                            Text("RANKED")
                                .font(Theme.bodyFont(10, weight: .black))
                                .tracking(1.5)
                                .foregroundStyle(Theme.ink)
                        }
                    }
                    .frame(width: 104)
                }
                .buttonStyle(CartoonButtonStyle(fill: Self.gold, foreground: Theme.ink, fontSize: 23, cornerRadius: 16,
                                                labelShadow: false))
                .fixedSize()
                .modifier(BreathingGlow(color: Self.gold))
            }
            .padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 6)
            .background(LinearGradient(colors: [panel.mix(with: .white, by: 0.1), panel], startPoint: .top, endPoint: .bottom))
        }
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Theme.ink.opacity(0.85), lineWidth: 2.5))
        .background(RoundedRectangle(cornerRadius: 22).fill(Theme.ink.opacity(0.8)).offset(y: 5))
        .padding(.bottom, 5)
    }

    // MARK: Featured crusade

    private var crusadeCard: some View {
        let profile = model.profile
        let earned = Crusade.chapters.indices.reduce(0) { total, chapter in
            total + CrusadeDifficulty.allCases.reduce(0) { $0 + profile.totalStars(chapter: chapter, difficulty: $1) }
        }
        let possible = Crusade.chapters.reduce(0) { $0 + $1.maxStars } * CrusadeDifficulty.allCases.count
        return Button(action: model.openCrusade) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    OutlinedText("CRUSADE", size: 24, fill: .white, outline: 2.6)
                        .fixedSize()
                    Text("DAILY")
                        .font(Theme.bodyFont(10, weight: .black))
                        .tracking(1.5)
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(Capsule().fill(Self.gold))
                        .overlay(Capsule().strokeBorder(Theme.ink, lineWidth: 2))
                }
                Text("Lead a team of 3 across the maps")
                    .font(Theme.bodyFont(12, weight: .heavy))
                    .foregroundStyle(.white)
                    .shadow(color: Theme.ink.opacity(0.6), radius: 0, x: 0, y: 1.5)
                HStack(spacing: 8) {
                    chip(icon: "star.fill", iconColor: Self.gold, text: "\(earned)/\(possible)")
                    TimelineView(.periodic(from: .now, by: 30)) { timeline in
                        let minutes = max(1, Int(Crusade.nextReset(after: timeline.date).timeIntervalSince(timeline.date) / 60))
                        chip(icon: "clock.fill", iconColor: Theme.ink.opacity(0.7), text: String(localized: "\(minutes / 60)h \(minutes % 60)m"))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
            .background(alignment: .trailing) {
                // The two maps peek in from the right edge, fading into the card.
                ArenaBanner(map: .meadow, showsBalls: false)
                    .frame(width: 170)
                    .mask(LinearGradient(colors: [.clear, .black.opacity(0.8), .black], startPoint: .leading, endPoint: .trailing))
                .padding(.vertical, -13).padding(.trailing, -10)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(CartoonButtonStyle(fill: Self.forest, foreground: .white, cornerRadius: 20, labelShadow: false))
    }

    private func chip(icon: String, iconColor: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).foregroundStyle(iconColor)
            Text(text).foregroundStyle(Theme.ink)
        }
        .font(Theme.bodyFont(11, weight: .black))
        .padding(.horizontal, 8).padding(.vertical, 2)
        .background(Capsule().fill(.white))
        .overlay(Capsule().strokeBorder(Theme.ink, lineWidth: 2))
    }

    // MARK: Other modes

    private var collectionSubtitle: String {
        let ready = model.profile.upgradesAvailable
        return ready > 0 ? String(localized: "\(ready) ready to upgrade") : String(localized: "Upgrade balls")
    }

    /// A compact mode button: icon on the left, title and subtitle beside it.
    private func modeTile(title: String, subtitle: String, icon: String, fill: Color, badge: Int = 0,
                          action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(RoundedRectangle(cornerRadius: 11).fill(LinearGradient(
                        colors: [fill.mix(with: .white, by: 0.2), fill.mix(with: Theme.ink, by: 0.15)],
                        startPoint: .top, endPoint: .bottom)))
                    .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(.white.opacity(0.35), lineWidth: 1))
                    .shadow(color: fill.opacity(0.5), radius: 6, y: 2)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title.localized)
                        .font(Theme.titleFont(15))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(subtitle.localized)
                        .font(Theme.bodyFont(11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1).minimumScaleFactor(0.75)
                }
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(GlassTileStyle())
        .overlay(alignment: .topTrailing) {
            if badge > 0 {
                Text("\(badge)")
                    .font(Theme.bodyFont(12, weight: .black))
                    .foregroundStyle(.white)
                    .frame(minWidth: 24, minHeight: 24)
                    .background(Circle().fill(Theme.blood))
                    .overlay(Circle().strokeBorder(Theme.ink, lineWidth: 2.5))
                    .offset(x: 6, y: -8)
            }
        }
    }
}

/// The player's name and level with the XP bar to the next level.
struct PlayerLevelBar: View {
    let model: AppModel
    @State private var renaming = false
    @State private var draft = ""
    @State private var rejected = false

    var body: some View {
        Button {
            draft = model.playerDisplayName
            renaming = true
        } label: { bar }
        .buttonStyle(.plain)
        .alert("Change Name", isPresented: $renaming) {
            TextField("Name", text: $draft)
            Button("Save") {
                if !model.profile.rename(draft) { rejected = true }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This is the name opponents see. 3–16 letters, numbers, spaces, _ - or .")
        }
        .alert("Name Not Allowed", isPresented: $rejected) {
            Button("Try Again") { renaming = true }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Use 3–16 letters, numbers, spaces, _ - or .")
        }
    }

    private var bar: some View {
        let profile = model.profile
        return HStack(spacing: 10) {
            PlayerLevelBadge(level: profile.playerLevel, size: 40)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Text(model.playerDisplayName)
                        .font(Theme.bodyFont(15, weight: .black))
                        .foregroundStyle(.white)
                        .shadow(color: Theme.ink.opacity(0.6), radius: 0, x: 0, y: 1.5)
                        .lineLimit(1)
                    Image(systemName: "pencil")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(.white.opacity(0.7))
                }
                if let need = profile.xpToNext {
                    GeometryReader { geo in
                        Capsule().fill(Theme.ink.opacity(0.45))
                            .overlay(alignment: .leading) {
                                Capsule().fill(Theme.yellow)
                                    .frame(width: max(8, geo.size.width * min(1, Double(profile.xp) / Double(need))))
                            }
                            .overlay(
                                Text("\(profile.xp) / \(need) XP")
                                    .font(Theme.bodyFont(10, weight: .black))
                                    .foregroundStyle(.white)
                                    .shadow(color: Theme.ink, radius: 0, x: 0, y: 1)
                            )
                    }
                    .frame(height: 14)
                    .overlay(Capsule().strokeBorder(Theme.ink, lineWidth: 2))
                } else {
                    Text("MAX LEVEL")
                        .font(Theme.bodyFont(11, weight: .black))
                        .foregroundStyle(Theme.yellow)
                }
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.ink.opacity(0.3)))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
    }
}

/// A soft glow that slowly breathes around the main call to action.
private struct BreathingGlow: ViewModifier {
    let color: Color
    @State private var bright = false

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(bright ? 0.75 : 0.2), radius: bright ? 14 : 6)
            .scaleEffect(bright ? 1.03 : 1)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) { bright = true }
            }
    }
}
