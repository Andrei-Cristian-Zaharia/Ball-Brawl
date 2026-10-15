import SwiftUI

struct ContentView: View {
    @State private var model = AppModel()

    var body: some View {
        ZStack {
            CartoonBackground()
            switch model.screen {
            case .menu:
                MenuView(model: model)
                    .transition(.opacity)
            case .setup:
                SetupView(model: model)
                    .transition(.opacity)
            case .teamSelect:
                TeamSelectView(model: model)
                    .transition(.opacity)
            case .roundPrep:
                if let series = model.series {
                    RoundPrepView(model: model, series: series)
                        .transition(.opacity)
                }
            case .battle:
                if let battle = model.battle {
                    BattleView(model: model, engine: battle)
                        .id(ObjectIdentifier(battle))
                        .transition(.opacity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.screen)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
}
