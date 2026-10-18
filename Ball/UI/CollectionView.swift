import SwiftUI

/// Every ball with its rarity, level and cards, plus the player's 3 team presets.
/// Tap a ball to see its star powers and upgrade it; tap a preset slot, then a ball, to build a team.
struct CollectionView: View {
    let model: AppModel
    @State private var selectedID: String?
    @State private var filter: Rarity?
    /// Preset slot waiting for a ball (preset, slot); while set, tapping a ball fills it.
    @State private var editing: (preset: Int, slot: Int)?
    /// The preset tab being shown (starts on the battle team).
    @State private var shownPreset: Int?
    /// A ball stage playing in the preview dialog.
    @State private var preview: AbilityPreviewRequest?

    private var profile: ProfileStore { model.profile }
    /// Unlocked first, then locked by arena; within those, highest rarity, then by name.
    private var roster: [FighterDefinition] {
        FighterCatalog.all
            .filter { filter == nil || $0.rarity == filter }
            .sorted {
                // Unlocked balls first, then highest rarity, then by name.
                let a = profile.isUnlocked($0.id), b = profile.isUnlocked($1.id)
                if a != b { return a }
                // Locked balls in the order their arenas come.
                let arenaA = Arenas.tier(unlocking: $0.id).number, arenaB = Arenas.tier(unlocking: $1.id).number
                // (Balls already in chests come first, since their arenas are earlier.)
                if !a, arenaA != arenaB { return arenaA < arenaB }
                return ($0.rarity, $1.name) > ($1.rarity, $0.name)
            }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    HStack {
                        BackButton(title: "Menu", action: model.showMenu)
                        Spacer()
                        WalletBar(model: model)
                    }
                    .id(Self.topID)

                    VStack(spacing: 6) {
                        ScreenTitle("COLLECTION")
                        summary
                    }

                    if let id = selectedID, editing == nil, let base = FighterCatalog.definition(id: id) {
                        BallDetailCard(base: base, profile: profile, onPreview: { preview = $0 }) { selectedID = nil }
                            .transition(.scale(scale: 0.9).combined(with: .opacity))
                    }

                    presets

                    ChestShelf(model: model)
                        .id(Self.chestsID)

                    VStack(spacing: 12) {
                        if let editing {
                            editBanner(editing)
                        }
                        filterChips
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 10) {
                            ForEach(roster) { base in
                                tile(base)
                            }
                        }
                    }
                    .padding(12)
                    .cartoonCard(fill: Theme.cream, cornerRadius: 22, shadow: 6, lineWidth: 3.5)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: 820)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .animation(.spring(duration: 0.3, bounce: 0.35), value: selectedID)
            .animation(.spring(duration: 0.3, bounce: 0.35), value: filter)
            .animation(.spring(duration: 0.3, bounce: 0.35), value: editing?.preset)
            .animation(.spring(duration: 0.3, bounce: 0.35), value: editing?.slot)
            // The wallet's chest button lands here.
            .task(id: model.focusChests) {
                guard model.focusChests else { return }
                try? await Task.sleep(for: .seconds(0.3))
                withAnimation(.easeInOut(duration: 0.4)) { proxy.scrollTo(Self.chestsID, anchor: .center) }
                model.focusChests = false
            }
            // Picking a ball opens its upgrade card at the top, so jump up to it.
            .onChange(of: selectedID) { _, id in
                guard id != nil else { return }
                withAnimation(.easeInOut(duration: 0.35)) { proxy.scrollTo(Self.topID, anchor: .top) }
            }
        }
        .overlay {
            if let preview {
                AbilityPreviewDialog(request: preview) { self.preview = nil }
                    .id(preview.id)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .animation(.spring(duration: 0.3, bounce: 0.35), value: preview)
    }

    private static let topID = "collection-top"
    private static let chestsID = "collection-chests"

    // MARK: Summary

    private var summary: some View {
        let all = FighterCatalog.all
        let maxed = all.filter { profile.level(of: $0.id) >= Progression.maxLevel }.count
        let stars = all.reduce(0) { total, ball in
            total + Progression.starLevels.filter { profile.level(of: ball.id) >= $0 }.count
        }
        return HStack(spacing: 8) {
            summaryChip(icon: "circle.grid.3x3.fill", text: String(localized: "\(all.count) balls"))
            summaryChip(icon: "star.fill", text: String(localized: "\(stars)/\(all.count * Progression.starLevels.count) stars"))
            summaryChip(icon: "crown.fill", text: String(localized: "\(maxed) maxed"))
        }
    }

    private func summaryChip(icon: String, text: String) -> some View {
        Label(text.localized, systemImage: icon)
            .font(Theme.bodyFont(12, weight: .black))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(Capsule().fill(.white))
            .overlay(Capsule().strokeBorder(Theme.ink, lineWidth: 2))
    }

    // MARK: Presets

    private var presets: some View {
        let preset = shownPreset ?? profile.activePreset
        let team = profile.teamPresets[preset]
        let isBattleTeam = preset == profile.activePreset
        return VStack(alignment: .leading, spacing: 10) {
            if let notice = model.collectionNotice {
                Label(notice, systemImage: "exclamationmark.triangle.fill")
                    .font(Theme.bodyFont(12, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.blood))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.ink, lineWidth: 2))
            }
            HStack(spacing: 6) {
                ForEach(0..<PlayerProfile.presetCount, id: \.self) { index in
                    presetTab(index, selected: index == preset)
                }
            }
            HStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { slot in
                    presetSlot(preset: preset, slot: slot, id: team.indices.contains(slot) ? team[slot] : nil)
                }
            }
            if isBattleTeam {
                Label(team.count == 3 ? String(localized: "Battle team: used in arena battles (3v3)") : String(localized: "Battle team: add 3 balls to play arena battles"),
                      systemImage: "shield.lefthalf.filled")
                    .font(Theme.bodyFont(12, weight: .black))
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.yellow.mix(with: .white, by: 0.5)))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.ink, lineWidth: 2))
            } else {
                Button {
                    profile.setActivePreset(preset)
                    if profile.battleTeam != nil { model.collectionNotice = nil }
                } label: {
                    Label("Use for Battles", systemImage: "checkmark.circle.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(CartoonButtonStyle(fill: Theme.go, foreground: .white, fontSize: 15, cornerRadius: 12))
            }
        }
        .padding(12)
        .cartoonCard(fill: Theme.cream, cornerRadius: 22, shadow: 6, lineWidth: 3.5)
        .onChange(of: profile.battleTeam != nil) { _, ready in if ready { model.collectionNotice = nil } }
    }

    private func presetTab(_ index: Int, selected: Bool) -> some View {
        Button {
            shownPreset = index
            editing = nil
        } label: {
            HStack(spacing: 4) {
                if index == profile.activePreset {
                    Image(systemName: "shield.lefthalf.filled").font(.system(size: 11, weight: .black))
                }
                Text("Preset \(index + 1)")
            }
            .font(Theme.bodyFont(13, weight: .black))
            .foregroundStyle(selected ? Theme.ink : Theme.ink.opacity(0.55))
            .frame(maxWidth: .infinity, minHeight: 32)
            .background(Capsule().fill(selected ? Theme.yellow : .white))
            .overlay(Capsule().strokeBorder(Theme.ink, lineWidth: selected ? 2.5 : 2))
        }
        .buttonStyle(.plain)
    }

    private func presetSlot(preset: Int, slot: Int, id: String?) -> some View {
        let active = editing?.preset == preset && editing?.slot == slot
        let base = id.flatMap(FighterCatalog.definition(id:))
        return Button {
            editing = active ? nil : (preset, slot)
            selectedID = nil
        } label: {
            ZStack {
                if let base {
                    FighterPortrait(definition: profile.definition(base), color: base.rarity.color, size: 50, expression: .happy)
                } else {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(Theme.ink.opacity(0.35))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(RoundedRectangle(cornerRadius: 14).fill(active ? Theme.yellow : base?.rarity.color.mix(with: .white, by: 0.6) ?? .white))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Theme.ink, style: StrokeStyle(lineWidth: active ? 3.5 : 2.5, dash: base == nil && !active ? [6, 4] : [])))
            .overlay(alignment: .topTrailing) {
                if base != nil {
                    Button {
                        profile.setPresetSlot(preset: preset, slot: slot, id: nil)
                        if active { editing = nil }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(Circle().fill(Theme.blood))
                            .overlay(Circle().strokeBorder(Theme.ink, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                    .offset(x: 6, y: -6)
                }
            }
            .scaleEffect(active ? 1.05 : 1)
        }
        .buttonStyle(.plain)
    }

    private func editBanner(_ target: (preset: Int, slot: Int)) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "hand.tap.fill")
            Text("Pick a ball for Preset \(target.preset + 1), slot \(target.slot + 1)")
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button("Done") { editing = nil }
                .font(Theme.bodyFont(13, weight: .black))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Capsule().fill(.white))
                .overlay(Capsule().strokeBorder(Theme.ink, lineWidth: 2))
                .buttonStyle(.plain)
        }
        .font(Theme.bodyFont(13, weight: .black))
        .foregroundStyle(Theme.ink)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.yellow))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.ink, lineWidth: 2.5))
    }

    /// Puts the tapped ball in the slot being edited, then moves on to the next slot of that preset.
    private func assign(_ id: String) {
        guard let target = editing else { return }
        profile.setPresetSlot(preset: target.preset, slot: target.slot, id: id)
        let filled = profile.teamPresets[target.preset].count
        editing = filled < 3 ? (target.preset, filled) : nil
    }

    // MARK: Grid

    private var filterChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                chip(title: "ALL", color: .white, selected: filter == nil) { filter = nil }
                ForEach(Rarity.allCases, id: \.self) { rarity in
                    chip(title: rarity.name.localized.uppercased(), color: rarity.color, selected: filter == rarity) {
                        filter = filter == rarity ? nil : rarity
                    }
                }
            }
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }

    private func chip(title: String, color: Color, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title.localized)
                .font(Theme.bodyFont(11, weight: .black))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Capsule().fill(selected ? color : color.mix(with: .white, by: 0.6)))
                .overlay(Capsule().strokeBorder(Theme.ink, lineWidth: selected ? 2.5 : 1.5))
                .offset(y: selected ? 1 : 0)
        }
        .buttonStyle(.plain)
    }

    private func tile(_ base: FighterDefinition) -> some View {
        let level = profile.level(of: base.id)
        let selected = selectedID == base.id && editing == nil
        let inPreset = editing.map { profile.teamPresets[$0.preset].contains(base.id) } ?? false
        let canUpgrade = profile.canUpgrade(base.id)
        let locked = !profile.isUnlocked(base.id)
        return Button {
            if editing != nil {
                if !locked { assign(base.id) }
            } else {
                selectedID = selected ? nil : base.id
            }
        } label: {
            VStack(spacing: 3) {
                FighterPortrait(definition: profile.definition(base), color: base.rarity.color, size: 50,
                                expression: selected || inPreset ? .happy : .normal)
                    .padding(.top, 4)
                Text(base.name)
                    .font(Theme.bodyFont(11, weight: .black))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1).minimumScaleFactor(0.6)
                if locked {
                    // Where it unlocks, in place of level and cards: its arena, or chests once that's reached.
                    let inChests = profile.isInChests(base.id)
                    HStack(spacing: 3) {
                        Image(systemName: inChests ? "shippingbox.fill" : "lock.fill").font(.system(size: 8, weight: .bold))
                        Text(inChests ? String(localized: "IN CHESTS") : String(localized: "ARENA \(Arenas.tier(unlocking: base.id).number)"))
                            .lineLimit(1)
                            .fixedSize()
                    }
                        .font(Theme.bodyFont(10, weight: .black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Capsule().fill(Theme.ink.opacity(0.8)))
                        .padding(.top, 2)
                } else {
                    HStack(spacing: 2) {
                        LevelBadge(level: level, size: 8)
                        StarRow(level: level, size: 7)
                    }
                    CardProgressBar(have: profile.cards(of: base.id), need: profile.upgradeCost(of: base.id)?.cards, height: 12)
                }
            }
            .padding(.horizontal, 5).padding(.bottom, 6)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14).fill(LinearGradient(
                    colors: [base.rarity.color.mix(with: .white, by: selected ? 0.2 : 0.35), base.rarity.color.mix(with: .white, by: 0.8)],
                    startPoint: .top, endPoint: .bottom))
            )
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.ink, lineWidth: selected || inPreset ? 3.5 : 2.5))
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.ink).offset(y: selected ? 1 : 4))
            .offset(y: selected ? 3 : 0)
            .saturation(locked ? 0.15 : 1)
            .opacity(locked ? 0.75 : 1)
            .overlay(alignment: .topTrailing) {
                if locked {
                    EmptyView()
                } else if inPreset {
                    badgeIcon("checkmark", fill: Theme.yellow, foreground: Theme.ink)
                } else if canUpgrade {
                    badgeIcon("arrow.up", fill: Theme.go, foreground: .white)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func badgeIcon(_ name: String, fill: Color, foreground: Color) -> some View {
        Image(systemName: name)
            .font(.system(size: 11, weight: .black))
            .foregroundStyle(foreground)
            .frame(width: 22, height: 22)
            .background(Circle().fill(fill))
            .overlay(Circle().strokeBorder(Theme.ink, lineWidth: 2))
            .offset(x: 5, y: -5)
    }
}

/// Selected ball: rarity, level, power bonus, star powers and the upgrade button.
private struct BallDetailCard: View {
    let base: FighterDefinition
    let profile: ProfileStore
    let onPreview: (AbilityPreviewRequest) -> Void
    let onClose: () -> Void

    var body: some View {
        let level = profile.level(of: base.id)
        let current = Progression.leveled(base, level: level)
        let cost = profile.upgradeCost(of: base.id)
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                FighterPortrait(definition: current, color: base.rarity.color, size: 78, expression: .happy)
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(base.name).font(Theme.titleFont(24)).foregroundStyle(Theme.ink)
                        RarityBadge(rarity: base.rarity)
                    }
                    HStack(spacing: 6) {
                        LevelBadge(level: level, size: 13)
                        StarRow(level: level, size: 13)
                    }
                    Text(powerText(level: level))
                        .font(Theme.bodyFont(13, weight: .heavy))
                        .foregroundStyle(Theme.ink.opacity(0.8))
                }
                Spacer(minLength: 0)
                Button(action: onClose) {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .black)).foregroundStyle(Theme.ink)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(.white))
                        .overlay(Circle().strokeBorder(Theme.ink, lineWidth: 2))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                Text(base.attackDescription.localized)
                    .font(Theme.bodyFont(13, weight: .semibold))
                    .foregroundStyle(Theme.ink.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                PreviewButton {
                    onPreview(AbilityPreviewRequest(ballID: base.id, level: 1, title: base.attackName.localized,
                                                    tag: String(localized: "BASIC ATTACK"), description: base.attackDescription.localized))
                }
            }

            VStack(spacing: 8) {
                ForEach(Array(Progression.starPowers(for: base.id).enumerated()), id: \.offset) { _, star in
                    starRow(star, unlocked: level >= star.level, hasAbilities: Progression.abilityStarPowers(for: base.id) != nil)
                }
            }

            if cost != nil {
                // What the next level adds, so upgrades feel worth it.
                let next = Progression.leveled(base, level: level + 1)
                let damage = Int(((next.damageScale / current.damageScale - 1) * 100).rounded())
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.right").font(.system(size: 11, weight: .black))
                    Text("Next level: +\(Int(next.maxHealth - current.maxHealth)) HP · +\(damage)% damage")
                }
                .font(Theme.bodyFont(12, weight: .black))
                .foregroundStyle(Theme.go.mix(with: Theme.ink, by: 0.35))
            }

            CardProgressBar(have: profile.cards(of: base.id), need: cost?.cards, height: 20)

            if let cost {
                Button {
                    withAnimation(.spring(duration: 0.35, bounce: 0.5)) { profile.upgrade(base.id) }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.up.circle.fill")
                        Text("UPGRADE TO LV \(level + 1)")
                        CoinLabel(amount: cost.coins, size: 15)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(.white))
                        if let xp = profile.upgradeXP(of: base.id) {
                            Text("+\(xp) XP")
                                .font(Theme.bodyFont(12, weight: .black))
                                .foregroundStyle(Theme.ink)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(Theme.yellow))
                                .fixedSize()
                        }
                    }
                }
                .buttonStyle(CartoonButtonStyle(fill: profile.canUpgrade(base.id) ? Theme.go : Theme.disabled, foreground: .white))
                .disabled(!profile.canUpgrade(base.id))
                if !profile.canUpgrade(base.id) {
                    Text(missingText(cost))
                        .font(Theme.bodyFont(12, weight: .heavy))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            } else {
                Text("Fully upgraded!")
                    .font(Theme.bodyFont(15, weight: .black))
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(14)
        .cartoonCard(fill: Theme.cream, cornerRadius: 22, shadow: 6, lineWidth: 4)
    }

    private func powerText(level: Int) -> String {
        let percent = Int(((Progression.power(of: base.id, level: level) - 1) * 100).rounded())
        let hp = Int(Progression.leveled(base, level: level).maxHealth)
        return percent > 0 ? String(localized: "\(hp) HP · +\(percent)% damage") : String(localized: "\(hp) HP · base damage")
    }

    private func missingText(_ cost: (cards: Int, coins: Int)) -> String {
        let cards = cost.cards - profile.cards(of: base.id)
        let coins = cost.coins - profile.profile.coins
        switch (cards > 0, coins > 0) {
        case (true, true):
            return cards == 1 ? String(localized: "Need 1 more card and \(coins) more coins")
                : String(localized: "Need \(cards) more cards and \(coins) more coins")
        case (true, false):
            return cards == 1 ? String(localized: "Need 1 more card") : String(localized: "Need \(cards) more cards")
        case (false, true):
            return String(localized: "Need \(coins) more coins")
        case (false, false):
            return ""
        }
    }

    private func starRow(_ star: StarPower, unlocked: Bool, hasAbilities: Bool) -> some View {
        let ultimate = star.level == Progression.starLevels.last
        // Balls with abilities: a perk, a side ability, then the Ultimate.
        let side = hasAbilities && star.level == Progression.starLevels[1]
        let tag: String? = ultimate ? String(localized: "ULTIMATE") : !hasAbilities ? nil : side ? String(localized: "SIDE ABILITY") : String(localized: "PERK")
        let tagColor = ultimate ? Rarity.legendary.color : side ? Rarity.epic.color : Rarity.rare.color
        let icon = ultimate ? "crown.fill" : !hasAbilities ? "star.fill" : side ? "sparkles" : "bolt.fill"
        return HStack(spacing: 10) {
            Image(systemName: unlocked ? icon : "lock.fill")
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(unlocked ? (ultimate ? Rarity.legendary.color : Theme.yellow) : Theme.ink.opacity(0.4))
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text("\(star.name.localized) · LV \(star.level)")
                        .font(Theme.bodyFont(13, weight: .black))
                        .foregroundStyle(Theme.ink)
                    if let tag {
                        Text(tag)
                            .font(Theme.bodyFont(9, weight: .black))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Capsule().fill(tagColor))
                            .overlay(Capsule().strokeBorder(Theme.ink, lineWidth: 1.5))
                    }
                }
                Text(star.description.localized)
                    .font(Theme.bodyFont(12, weight: .semibold))
                    .foregroundStyle(Theme.ink.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            PreviewButton {
                onPreview(AbilityPreviewRequest(ballID: base.id, level: star.level, title: star.name.localized,
                                                tag: String(localized: "\(tag ?? String(localized: "STAR POWER")) · LV \(star.level)"), description: star.description.localized))
            }
        }
        .padding(8)
        .cartoonCard(fill: unlocked ? Theme.yellow.mix(with: .white, by: 0.6) : .white, cornerRadius: 12, shadow: 0, lineWidth: 2)
        .opacity(unlocked ? 1 : 0.75)
    }
}

/// Coins and the chest button, shown on the menu and collection.
struct WalletBar: View {
    let model: AppModel
    /// Sleek translucent pills for dark screens (the menu) instead of cartoon cards.
    var dark = false

    var body: some View {
        let profile = model.profile.profile
        let chests = model.profile.totalChests
        HStack(spacing: 10) {
            if dark {
                CoinLabel(amount: profile.coins, size: 15, textColor: .white)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Capsule().fill(Color.white.opacity(0.1)))
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.16), lineWidth: 1))
            } else {
                CoinLabel(amount: profile.coins, size: 16)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .cartoonCard(fill: Theme.cream, cornerRadius: 12, shadow: 3, lineWidth: 2.5)
            }
            Button(action: model.openChests) {
                HStack(spacing: 4) {
                    ChestIcon(kind: ChestKind.allCases.last { model.profile.chestCount($0) > 0 } ?? .wooden, size: dark ? 22 : 26)
                    Text(chests > 0 ? String(localized: "OPEN \(chests)") : "0")
                        .font(Theme.bodyFont(13, weight: .black))
                        .foregroundStyle(dark ? (chests > 0 ? Theme.ink : .white) : Theme.ink)
                        .lineLimit(1)
                        .fixedSize()
                }
                .padding(.horizontal, dark ? 12 : 8).padding(.vertical, dark ? 5 : 3)
                .modifier(WalletChestBackground(dark: dark, highlighted: chests > 0))
            }
            .buttonStyle(.plain)
        }
    }
}

private struct WalletChestBackground: ViewModifier {
    let dark: Bool
    let highlighted: Bool

    func body(content: Content) -> some View {
        if dark {
            content
                .background(Capsule().fill(highlighted ? Theme.yellow : Color.white.opacity(0.1)))
                .overlay(Capsule().strokeBorder(Color.white.opacity(highlighted ? 0.5 : 0.16), lineWidth: 1))
        } else {
            content.cartoonCard(fill: highlighted ? Theme.yellow : Theme.cream, cornerRadius: 12, shadow: 3, lineWidth: 2.5)
        }
    }
}
