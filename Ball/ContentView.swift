import SwiftUI

struct ContentView: View {
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            CartoonBackground(color: background)
            // Big screens (iPad, large Mac windows) show the game zoomed in, laid out as on a large phone,
            // instead of a phone-sized layout floating in empty space.
            GeometryReader { geo in
                let zoom = Self.zoom(for: geo.size)
                game
                    .frame(width: geo.size.width / zoom, height: geo.size.height / zoom)
                    .scaleEffect(zoom)
                    .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: scenePhase) { _, phase in model.scenePhaseChanged(phase) }
    }

    /// 1 on phones; on bigger screens, enough to fill them with a layout about 440 × 900 points.
    static func zoom(for size: CGSize) -> CGFloat {
        max(1, min(size.width / 440, size.height / 900))
    }

    private var game: some View {
        ZStack {
            switch model.screen {
            case .menu:
                MenuView(model: model)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            case .setup:
                SetupView(model: model)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            case .teamSelect:
                TeamSelectView(model: model)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            case .crusade:
                CrusadeView(model: model)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            case .crusadePrep:
                CrusadePrepView(model: model)
                    .id("\(model.crusadeChapter).\(model.crusadeLevel)")
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            case .shop:
                ShopView(model: model)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            case .daily:
                DailyView(model: model)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            case .settings:
                SettingsView(model: model)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            case .arenas:
                ArenasView(model: model)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            case .collection:
                CollectionView(model: model)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            case .onlineLobby:
                OnlineLobbyView(model: model)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            case .roundPrep:
                if let series = model.series {
                    RoundPrepView(model: model, series: series)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
            case .battle:
                if let battle = model.battle {
                    BattleView(model: model, engine: battle)
                        .id(ObjectIdentifier(battle))
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
            }
        }
        .overlay {
            if let chest = model.openedChest {
                ChestOpenOverlay(opening: chest, profile: model.profile) { model.openedChest = nil }
                    .id(chest.id)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else if let levelUp = model.profile.levelUps.first {
                LevelUpOverlay(levelUp: levelUp) {
                    // By id, so a second tap while it fades out doesn't remove the next one (or crash on an empty queue).
                    model.profile.levelUps.removeAll { $0.id == levelUp.id }
                }
                    .id(levelUp.id)
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
            } else if let arena = model.newArena {
                NewArenaOverlay(tier: arena) { model.newArena = nil }
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.screen)
        .animation(.spring(duration: 0.35, bounce: 0.4), value: model.openedChest)
        .animation(.spring(duration: 0.35, bounce: 0.4), value: model.newArena?.number)
        .animation(.spring(duration: 0.35, bounce: 0.4), value: model.profile.levelUps.first?.id)
        .overlay(alignment: .top) {
            if let toast = model.shopToast {
                Text(toast)
                    .font(Theme.bodyFont(15, weight: .black))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .cartoonCard(fill: Theme.yellow, cornerRadius: 16, shadow: 4, lineWidth: 3)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
}

extension ContentView {
    /// Battles and crusade screens take on their map's colors.
    private var background: Color {
        switch model.screen {
        case .battle: return model.battle?.setup.map.background ?? Theme.background
        case .crusade, .crusadePrep: return Crusade.chapters[model.crusadeChapter].map.background
        default: return Theme.background
        }
    }
}

#Preview {
    ContentView()
}
