import SwiftUI

/// Daily rewards: the login streak, a free chest every few hours, and today's quests.
struct DailyView: View {
    let model: AppModel

    private var profile: ProfileStore { model.profile }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                HStack {
                    BackButton(title: "Menu", action: model.showMenu)
                    Spacer()
                    WalletBar(model: model)
                }

                ScreenTitle("DAILY", subtitle: "New quests and streak rewards every day")

                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    VStack(spacing: 18) {
                        streakSection
                        freeChestSection(now: timeline.date)
                        questsSection(now: timeline.date)
                    }
                    // Roll over at midnight while the screen is open.
                    .onChange(of: Crusade.dayKey(timeline.date)) { profile.refreshDaily() }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .onAppear { profile.refreshDaily() }
    }

    // MARK: Login streak

    private var streakSection: some View {
        let streak = profile.profile.loginStreak
        let ready = profile.loginRewardReady
        return section("LOGIN STREAK", icon: "flame.fill") {
            VStack(spacing: 12) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                    ForEach(Daily.loginRewards.indices, id: \.self) { index in
                        dayTile(index: index, streak: streak, ready: ready)
                    }
                }
                Text(ready ? String(localized: "Day \(streak) reward is ready!") : String(localized: "Come back tomorrow for day \(streak % Daily.loginRewards.count + 1)."))
                    .font(Theme.bodyFont(13, weight: .heavy))
                    .foregroundStyle(Theme.textSecondary)
                if ready {
                    Button("Collect Day \(streak)") {
                        if let rewards = profile.claimLoginReward() { model.announce(rewards) }
                    }
                    .buttonStyle(CartoonButtonStyle(fill: Theme.yellow))
                }
            }
            .padding(12)
            .cartoonCard(fill: Theme.cream, cornerRadius: 18, shadow: 4, lineWidth: 3)
        }
    }

    private func dayTile(index: Int, streak: Int, ready: Bool) -> some View {
        let day = index + 1
        let collected = day < streak || (day == streak && !ready)
        let today = day == streak && ready
        let rewards = Daily.loginRewards[index]
        return VStack(spacing: 3) {
            Text("DAY \(day)")
                .font(Theme.bodyFont(9, weight: .black))
                .foregroundStyle(Theme.ink.opacity(0.7))
            ZStack {
                if let chest = rewards.chests.last {
                    ChestIcon(kind: chest, size: 26)
                } else {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Theme.ink, Theme.yellow)
                }
                if collected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(.white, Theme.go)
                        .offset(x: 12, y: 10)
                }
            }
            .frame(height: 30)
            Text(rewards.coins > 0 ? "\(rewards.coins)" : " ")
                .font(Theme.bodyFont(10, weight: .black).monospacedDigit())
                .foregroundStyle(Theme.ink)
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 10).fill(today ? Theme.yellow : collected ? Theme.go.opacity(0.18) : .white))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.ink, lineWidth: today ? 2.5 : 1.5))
        .opacity(collected ? 0.75 : 1)
    }

    // MARK: Free chest

    private func freeChestSection(now: Date) -> some View {
        let ready = profile.freeChestReady(now: now)
        return section("FREE CHEST", icon: "clock.fill") {
            HStack(spacing: 14) {
                ChestIcon(kind: Daily.freeChest, size: 52)
                VStack(alignment: .leading, spacing: 4) {
                    Text(Daily.freeChest.name.localized)
                        .font(Theme.titleFont(17))
                        .foregroundStyle(Theme.ink)
                    Text(ready ? String(localized: "Ready to collect!") : String(localized: "Next one in \(Self.countdown(to: profile.nextFreeChest, from: now))"))
                        .font(Theme.bodyFont(12, weight: .heavy).monospacedDigit())
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: 0)
                Button("Collect") {
                    if profile.claimFreeChest() { model.announce(Progression.Rewards(chests: [Daily.freeChest])) }
                }
                .buttonStyle(CartoonButtonStyle(fill: ready ? Theme.go : Theme.disabled, foreground: .white, fontSize: 15))
                .fixedSize()
                .disabled(!ready)
            }
            .padding(12)
            .cartoonCard(fill: Theme.cream, cornerRadius: 18, shadow: 4, lineWidth: 3)
        }
    }

    // MARK: Quests

    private func questsSection(now: Date) -> some View {
        section("DAILY QUESTS", icon: "checklist") {
            VStack(spacing: 10) {
                ForEach(profile.todaysQuests, id: \.kind) { quest in
                    questRow(quest)
                }
                bonusRow
                Text("New quests in \(Self.countdown(to: Crusade.nextReset(after: now), from: now))")
                    .font(Theme.bodyFont(12, weight: .heavy).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
    }

    private func questRow(_ quest: DailyQuest) -> some View {
        let progress = profile.questProgress(quest)
        let claimed = profile.isClaimed(quest)
        let ready = profile.canClaim(quest)
        return HStack(spacing: 12) {
            Image(systemName: quest.icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.background))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.ink, lineWidth: 2))
            VStack(alignment: .leading, spacing: 5) {
                Text(quest.title)
                    .font(Theme.bodyFont(14, weight: .black))
                    .foregroundStyle(Theme.ink)
                CardProgressBar(have: progress, need: quest.target, height: 16)
            }
            if claimed {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 26, weight: .black))
                    .foregroundStyle(.white, Theme.go)
                    .frame(width: 84)
            } else {
                Button {
                    if let rewards = profile.claim(quest) { model.announce(rewards) }
                } label: {
                    CoinLabel(amount: quest.reward.coins, size: 14)
                }
                .buttonStyle(CartoonButtonStyle(fill: ready ? Theme.yellow : Theme.disabled, fontSize: 14))
                .frame(width: 84)
                .disabled(!ready)
            }
        }
        .padding(10)
        .cartoonCard(fill: claimed ? Theme.creamDark : Theme.cream, cornerRadius: 16, shadow: 3, lineWidth: 2.5)
    }

    private var bonusRow: some View {
        let ready = profile.questBonusReady
        let done = profile.questBonusClaimed
        return HStack(spacing: 12) {
            ChestIcon(kind: Daily.questBonus.chests.first ?? .silver, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text("All quests done")
                    .font(Theme.bodyFont(14, weight: .black))
                    .foregroundStyle(Theme.ink)
                Text("Bonus \(Daily.questBonus.chests.first?.name.localized ?? String(localized: "chest"))")
                    .font(Theme.bodyFont(12, weight: .heavy))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 0)
            if done {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 26, weight: .black))
                    .foregroundStyle(.white, Theme.go)
                    .frame(width: 84)
            } else {
                Button("Collect") {
                    if let rewards = profile.claimQuestBonus() { model.announce(rewards) }
                }
                .buttonStyle(CartoonButtonStyle(fill: ready ? Theme.go : Theme.disabled, foreground: .white, fontSize: 14))
                .frame(width: 84)
                .disabled(!ready)
            }
        }
        .padding(10)
        .cartoonCard(fill: Theme.yellow.mix(with: .white, by: 0.55), cornerRadius: 16, shadow: 3, lineWidth: 2.5)
    }

    // MARK: Pieces

    private func section<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title.localized, systemImage: icon)
                .font(Theme.bodyFont(14, weight: .black))
                .foregroundStyle(.white)
                .shadow(color: Theme.ink.opacity(0.6), radius: 0, x: 0, y: 1.5)
            content()
        }
    }

    /// "3h 12m", or "4m 05s" in the last hour.
    static func countdown(to date: Date, from now: Date) -> String {
        let seconds = max(0, Int(date.timeIntervalSince(now)))
        let hours = seconds / 3600, minutes = seconds % 3600 / 60
        return hours > 0 ? String(localized: "\(hours)h \(minutes)m") : String(localized: "\(minutes)m \(String(format: "%02d", seconds % 60))s")
    }
}
