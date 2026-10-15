import SwiftUI

struct MenuView: View {
    let model: AppModel

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 6) {
                    HStack(spacing: 4) {
                        OutlinedText("BALL", size: 54, fill: PlayerSlot.one.color, outline: 4.5)
                            .rotationEffect(.degrees(-4))
                        OutlinedText("BRAWL!", size: 54, fill: PlayerSlot.two.color, outline: 4.5)
                            .rotationEffect(.degrees(3))
                    }
                    Text("Auto-battling cartoon balls")
                        .font(Theme.bodyFont(15, weight: .heavy))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(.top, 40)

                // Roster parade.
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 5), spacing: 6) {
                    ForEach(Array(FighterCatalog.all.prefix(15).enumerated()), id: \.element.id) { index, fighter in
                        FighterPortrait(definition: fighter, color: index.isMultiple(of: 2) ? PlayerSlot.one.color : PlayerSlot.two.color,
                                        size: 58, expression: .happy)
                            .rotationEffect(.degrees(index.isMultiple(of: 2) ? -6 : 6))
                    }
                }
                .frame(maxWidth: 360)

                VStack(spacing: 16) {
                    modeButton(title: "2 PLAYERS", subtitle: "Pass & play on one device", icon: "person.2.fill",
                               fill: PlayerSlot.one.color, action: model.openLocalSetup)
                    modeButton(title: "VS BOT", subtitle: "3v3 team series against the computer", icon: "cpu.fill",
                               fill: PlayerSlot.two.color, action: model.openBotTeamSelect)
                }
                .frame(maxWidth: 420)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }

    private func modeButton(title: String, subtitle: String, icon: String, fill: Color,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .black))
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(.white))
                    .overlay(Circle().strokeBorder(Theme.ink, lineWidth: 3))
                    .foregroundStyle(Theme.ink)
                VStack(alignment: .leading, spacing: 2) {
                    OutlinedText(title, size: 24, fill: .white, outline: 2.5)
                    Text(subtitle)
                        .font(Theme.bodyFont(13, weight: .heavy))
                        .foregroundStyle(.white.opacity(0.9))
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 6)
        }
        .buttonStyle(CartoonButtonStyle(fill: fill, foreground: .white, cornerRadius: 22))
    }
}
