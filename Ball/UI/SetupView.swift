import SwiftUI

struct SetupView: View {
    @Bindable var model: AppModel

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                HStack {
                    BackButton(title: model.isVersusMatch ? "Leave" : "Menu", action: model.showMenu)
                    Spacer()
                }
                header

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 18) { panels }
                    VStack(spacing: 22) { panels }
                }

                startButton
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
            .frame(maxWidth: 980)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder private var panels: some View {
        ForEach(PlayerSlot.allCases) { slot in
            PlayerSetupPanel(model: model, slot: slot)
                .frame(minWidth: 340, maxWidth: 480)
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                OutlinedText("BALL", size: 44, fill: .white, outline: 4)
                    .fixedSize()
                OutlinedText("BRAWL", size: 44, fill: Theme.yellow, outline: 4)
                    .fixedSize()
            }
            Text(model.isVersusMatch
                 ? (model.isRankedMatch ? String(localized: "Ranked vs \(model.opponentName). Lock in to fight!")
                                        : String(localized: "Casual vs \(model.opponentName). Lock in to fight!"))
                 : String(localized: "Pick a fighter, lock in, and watch them battle!"))
                .font(Theme.bodyFont(14, weight: .heavy))
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    @ViewBuilder private var startButton: some View {
        if model.isVersusMatch {
            // The host starts automatically once both players are locked in.
            let ready = model.players[model.localSlot.rawValue].isReady
            Text(ready ? String(localized: "WAITING FOR \(model.opponentName.uppercased())…") : String(localized: "LOCK IN WHEN YOU'RE READY"))
                .font(Theme.bodyFont(16, weight: .black))
                .foregroundStyle(.white)
                .padding(.vertical, 8)
        } else {
            localStartButton
        }
    }

    private var localStartButton: some View {
        Button {
            model.startBattle()
        } label: {
            HStack(spacing: 10) {
                if model.canStart { Image(systemName: "bolt.fill") }
                Text(model.canStart ? String(localized: "START BATTLE!") : String(localized: "WAITING FOR BOTH PLAYERS"))
            }
        }
        .buttonStyle(CartoonButtonStyle(fill: Theme.yellow, fontSize: model.canStart ? 24 : 16, cornerRadius: 20))
        .frame(maxWidth: 440)
        .disabled(!model.canStart)
        .scaleEffect(model.canStart ? 1 : 0.96)
        .animation(.spring(duration: 0.35, bounce: 0.5), value: model.canStart)
    }
}

// MARK: - Player panel

private struct PlayerSetupPanel: View {
    @Bindable var model: AppModel
    let slot: PlayerSlot

    private var player: PlayerSetup { model.players[slot.rawValue] }
    /// The opponent's panel in an online match: shown, but not editable here.
    private var isRemote: Bool { !model.controlledSlots.contains(slot) }
    private var title: String {
        guard model.isVersusMatch else { return slot.title.localized }
        return isRemote ? model.opponentName : model.playerDisplayName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                OutlinedText(title.uppercased(), size: 22, fill: .white, outline: 2.5)
                Spacer()
                statusChip
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .cartoonCard(fill: slot.color, cornerRadius: 14, shadow: 0)

            // Compact roster grid; full details only for the selected fighter.
            if !player.isReady && !isRemote {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 8)], spacing: 10) {
                    ForEach(model.profile.unlockedRoster) { def in
                        rosterTile(def, selected: player.fighterID == def.id)
                    }
                }
            }

            if let fighter = model.definition(for: slot) {
                FighterCardView(definition: fighter, slot: slot, isSelected: true, isLocked: player.isReady) {}
                if fighter.requiresAim && !player.isReady && !isRemote {
                    AimPickerView(definition: fighter, slot: slot, angle: Binding(
                        get: { model.players[slot.rawValue].aimAngle },
                        set: { model.setAim($0, for: slot) }
                    ))
                }
                if !isRemote { lockButton(for: fighter) }
            } else {
                Text(isRemote ? String(localized: "Choosing a fighter…") : String(localized: "Tap a fighter to choose it!"))
                    .font(Theme.bodyFont(14, weight: .heavy))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
        }
        .padding(14)
        .cartoonCard(fill: Theme.cream, cornerRadius: 24, shadow: 7, lineWidth: 4)
        .animation(.spring(duration: 0.3, bounce: 0.35), value: player)
    }

    private func rosterTile(_ def: FighterDefinition, selected: Bool) -> some View {
        Button {
            model.select(def.id, for: slot)
        } label: {
            VStack(spacing: 2) {
                FighterPortrait(definition: def, color: slot.color, size: 54, expression: selected ? .happy : .normal)
                    .overlay(alignment: .bottomTrailing) { LevelBadge(level: model.profile.level(of: def.id), size: 8).offset(x: 6) }
                Text(def.name)
                    .font(Theme.bodyFont(11, weight: .black))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity)
            .cartoonCard(fill: selected ? slot.lightColor : def.rarity.color.mix(with: .white, by: 0.75),
                         cornerRadius: 14, shadow: selected ? 1 : 4, lineWidth: 2.5)
            .offset(y: selected ? 3 : 0)
        }
        .buttonStyle(.plain)
        .animation(.spring(duration: 0.25, bounce: 0.5), value: selected)
    }

    private var statusChip: some View {
        let text = player.isReady ? String(localized: "READY!") : (player.fighter == nil ? String(localized: "CHOOSING") : String(localized: "SETTING UP"))
        return Text(text)
            .font(Theme.bodyFont(12, weight: .black))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .cartoonCard(fill: player.isReady ? Theme.yellow : .white, cornerRadius: 10, shadow: 0, lineWidth: 2.5)
    }

    private func lockButton(for fighter: FighterDefinition) -> some View {
        Button {
            model.setReady(!player.isReady, for: slot)
        } label: {
            HStack {
                Image(systemName: player.isReady ? "pencil" : "checkmark.circle.fill")
                Text(player.isReady ? String(localized: "Edit Setup") : (fighter.requiresAim ? String(localized: "Confirm Aim") : String(localized: "Lock In \(fighter.name)")))
            }
        }
        .buttonStyle(CartoonButtonStyle(fill: player.isReady ? .white : slot.color,
                                        foreground: player.isReady ? Theme.ink : .white))
    }
}

// MARK: - Fighter card

struct FighterCardView: View {
    let definition: FighterDefinition
    let slot: PlayerSlot
    let isSelected: Bool
    let isLocked: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 12) {
                FighterPortrait(definition: definition, color: slot.color, size: 70, expression: isSelected ? .happy : .normal)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(definition.name).font(Theme.titleFont(21)).foregroundStyle(Theme.ink)
                        Text(definition.tagline.localized).font(Theme.bodyFont(11, weight: .heavy)).foregroundStyle(Theme.textSecondary)
                    }
                    HStack(spacing: 5) {
                        RarityBadge(rarity: definition.rarity)
                        LevelBadge(level: definition.level, size: 10)
                        StarRow(level: definition.level, size: 10)
                    }
                    Text(definition.attackName.localized.uppercased())
                        .font(Theme.bodyFont(11, weight: .black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(Capsule().fill(slot.color))
                        .overlay(Capsule().strokeBorder(Theme.ink, lineWidth: 2))
                    Text(definition.attackDescription.localized)
                        .font(Theme.bodyFont(12, weight: .semibold))
                        .foregroundStyle(Theme.ink.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                    statsRow.padding(.top, 3)
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .cartoonCard(fill: isSelected ? slot.lightColor : Theme.card, cornerRadius: 16, shadow: isSelected ? 1 : 4)
            .offset(y: isSelected ? 3 : 0)
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
    }

    private var statsRow: some View {
        HStack(spacing: 5) {
            ForEach(definition.stats, id: \.label) { stat in
                VStack(alignment: .leading, spacing: 0) {
                    Text(stat.value.localized).font(Theme.bodyFont(13, weight: .black)).foregroundStyle(Theme.ink)
                        .lineLimit(1).minimumScaleFactor(0.6)
                    Text(stat.label.localized).font(Theme.bodyFont(9, weight: .heavy)).foregroundStyle(Theme.textSecondary)
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
                .padding(.horizontal, 6).padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.cream))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.ink, lineWidth: 2))
            }
        }
    }
}

// MARK: - Aim picker

/// Drag (mouse or touch) anywhere in the mini-arena to set the Blaster's firing direction.
struct AimPickerView: View {
    let definition: FighterDefinition
    let slot: PlayerSlot
    @Binding var angle: Double

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("AIM DIRECTION").font(Theme.bodyFont(13, weight: .black)).foregroundStyle(Theme.ink)
                Spacer()
                Text("\(Int((-angle * 180 / .pi).truncatingRemainder(dividingBy: 360) + 360) % 360)°")
                    .font(.system(size: 14, weight: .black, design: .rounded).monospacedDigit())
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .cartoonCard(fill: Theme.yellow, cornerRadius: 8, shadow: 0, lineWidth: 2)
            }

            GeometryReader { geo in
                let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                Canvas { context, size in
                    drawPicker(in: &context, size: size)
                }
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                    let dx = value.location.x - center.x
                    let dy = value.location.y - center.y
                    guard dx * dx + dy * dy > 64 else { return }
                    angle = atan2(Double(dy), Double(dx))
                })
            }
            .aspectRatio(GameConfig.arenaWidth / GameConfig.arenaHeight * 1.35, contentMode: .fit)
            .frame(maxWidth: 320)
            .frame(maxWidth: .infinity)

            Text("Drag to aim! It stays pointed this way the whole match, no matter how it bounces.")
                .font(Theme.bodyFont(11, weight: .heavy))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(12)
        .cartoonCard(fill: .white, cornerRadius: 16, shadow: 4)
    }

    private func drawPicker(in context: inout GraphicsContext, size: CGSize) {
        let color = slot.color
        let rect = CGRect(origin: .zero, size: size).insetBy(dx: 3, dy: 3)
        let frame = Path(roundedRect: rect, cornerRadius: 14)
        context.fill(frame, with: .color(Theme.cream))
        context.stroke(frame, with: .color(Theme.ink), lineWidth: 4)

        let center = CGPoint(x: rect.midX, y: rect.midY)
        let ballRadius = min(rect.width, rect.height) * 0.15

        for i in 0..<8 {
            let a = Double(i) * .pi / 4
            var tick = Path()
            tick.move(to: FighterArt.point(center, ballRadius + 14, a))
            tick.addLine(to: FighterArt.point(center, ballRadius + 22, a))
            context.stroke(tick, with: .color(Theme.ink.opacity(0.25)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }

        let reach = hypot(rect.width, rect.height)
        var line = Path()
        line.move(to: FighterArt.point(center, ballRadius + 24, angle))
        line.addLine(to: FighterArt.point(center, reach, angle))
        context.drawLayer { layer in
            layer.clip(to: frame)
            layer.stroke(line, with: .color(Theme.ink.opacity(0.35)), style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [1, 9]))
        }

        FighterArt.draw(definition, in: &context, center: center, radius: ballRadius, team: color, aimAngle: angle,
                        look: CGVector(dx: cos(angle), dy: sin(angle)))

        let length = min(rect.width, rect.height) * 0.44
        let arrow = FighterArt.arrow(from: FighterArt.point(center, ballRadius + 26, angle), angle: angle,
                                     length: length - ballRadius - 26, headSize: 20)
        context.stroke(arrow.shaft, with: .color(Theme.ink), style: StrokeStyle(lineWidth: 11, lineCap: .round))
        context.stroke(arrow.head, with: .color(Theme.ink), style: StrokeStyle(lineWidth: 7, lineJoin: .round))
        context.stroke(arrow.shaft, with: .color(color), style: StrokeStyle(lineWidth: 5, lineCap: .round))
        context.fill(arrow.head, with: .color(color))
    }
}
