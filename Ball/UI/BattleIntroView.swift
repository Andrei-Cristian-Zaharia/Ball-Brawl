import SwiftUI

/// The "VS" intro before a fight: both fighters slide in on their team banners, the VS badge slams down,
/// then everything flies out and the countdown begins. Tap to skip.
struct BattleIntroView: View {
    let setup: MatchSetup
    /// Called as the intro starts leaving: the fight's countdown can begin.
    let onStart: () -> Void
    /// Called once the intro has fully left the screen.
    let onDone: () -> Void

    private enum Stage { case hidden, banners, slam, leaving }
    @State private var stage: Stage = .hidden
    @State private var shake = false
    @State private var flash = 0.0
    @State private var started = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Theme.ink.opacity(stage == .leaving || stage == .hidden ? 0 : 0.6)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    banner(.one, width: geo.size.width)
                        .offset(x: bannerOffset(.one, width: geo.size.width))
                    Spacer(minLength: 0)
                    banner(.two, width: geo.size.width)
                        .offset(x: bannerOffset(.two, width: geo.size.width))
                }
                .frame(height: min(geo.size.height * 0.62, 460))

                vsBadge
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .offset(x: shake ? -7 : 0, y: shake ? 4 : 0)
            .overlay(Color.white.opacity(flash).ignoresSafeArea().allowsHitTesting(false))
        }
        .contentShape(Rectangle())
        .onTapGesture { leave() }
        .task { await play() }
    }

    // MARK: Pieces

    private func banner(_ slot: PlayerSlot, width: CGFloat) -> some View {
        let loadout = setup.loadouts[slot.rawValue]
        let label = setup.labels.indices.contains(slot.rawValue) ? setup.labels[slot.rawValue] : slot.label
        let leading = slot == .one
        let portrait = FighterPortrait(definition: loadout.definition, color: slot.color, size: 104, expression: .normal)
            .rotationEffect(.degrees(leading ? -8 : 8))
        let text = VStack(alignment: leading ? .leading : .trailing, spacing: 2) {
            OutlinedText(label, size: 30, fill: .white, outline: 3)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            HStack(spacing: 6) {
                Text(loadout.definition.name.uppercased())
                    .font(Theme.titleFont(18))
                    .foregroundStyle(Theme.yellow)
                Text("LV \(loadout.definition.level)")
                    .font(Theme.bodyFont(12, weight: .black))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 6).padding(.vertical, 1)
                    .background(Capsule().fill(.white))
                    .overlay(Capsule().strokeBorder(Theme.ink, lineWidth: 1.5))
            }
        }
        return HStack(spacing: 12) {
            if leading { portrait; text; Spacer(minLength: 0) } else { Spacer(minLength: 0); text; portrait }
        }
        .padding(.horizontal, 24)
        .frame(width: width + 40, height: 140)
        .background(
            LinearGradient(colors: [slot.color.mix(with: .white, by: 0.15), slot.color.mix(with: Theme.ink, by: 0.3)],
                           startPoint: .top, endPoint: .bottom)
        )
        .overlay(Rectangle().strokeBorder(Theme.ink, lineWidth: 4))
        .background(Rectangle().fill(Theme.ink).offset(y: 7))
        .rotationEffect(.degrees(-6))
    }

    private var vsBadge: some View {
        let shown = stage == .slam
        return VStack(spacing: 6) {
            OutlinedText("VS", size: 84, fill: Theme.yellow, outline: 6)
                .fixedSize()
            Text(setup.map.name.localized.uppercased())
                .font(Theme.bodyFont(13, weight: .black))
                .tracking(1.5)
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Capsule().fill(Theme.cream))
                .overlay(Capsule().strokeBorder(Theme.ink, lineWidth: 2.5))
                .opacity(shown ? 1 : 0)
        }
        .scaleEffect(stage == .slam ? 1 : stage == .leaving ? 1.6 : 3.2)
        .rotationEffect(.degrees(stage == .slam ? -6 : -24))
        .opacity(stage == .slam ? 1 : 0)
    }

    private func bannerOffset(_ slot: PlayerSlot, width: CGFloat) -> CGFloat {
        let away = width * 1.3
        switch stage {
        case .hidden: return slot == .one ? -away : away
        case .banners, .slam: return 0
        case .leaving: return slot == .one ? away : -away
        }
    }

    // MARK: Timing

    private func play() async {
        withAnimation(.spring(duration: 0.45, bounce: 0.3)) { stage = .banners }
        try? await Task.sleep(for: .seconds(0.45))
        guard stage == .banners else { return }
        withAnimation(.spring(duration: 0.3, bounce: 0.5)) { stage = .slam }
        try? await Task.sleep(for: .seconds(0.12))
        flash = 0.7
        withAnimation(.easeOut(duration: 0.35)) { flash = 0 }
        withAnimation(.spring(duration: 0.08, bounce: 0.8).repeatCount(3, autoreverses: true)) { shake = true }
        try? await Task.sleep(for: .seconds(0.25))
        shake = false
        try? await Task.sleep(for: .seconds(1.1))
        leave()
    }

    private func leave() {
        guard !started else { return }
        started = true
        onStart()
        withAnimation(.easeIn(duration: 0.35)) { stage = .leaving }
        Task {
            try? await Task.sleep(for: .seconds(0.4))
            onDone()
        }
    }
}
