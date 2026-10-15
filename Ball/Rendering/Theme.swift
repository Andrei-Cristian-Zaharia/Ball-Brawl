import SwiftUI

/// Chunky-cartoon look: ink outlines, hard offset shadows, flat saturated colors.
enum Theme {
    static let ink = Color(red: 0.106, green: 0.071, blue: 0.188)
    static let background = Color(red: 0.29, green: 0.19, blue: 0.58)
    static let backgroundDot = Color.white.opacity(0.06)
    static let cream = Color(red: 1.0, green: 0.957, blue: 0.863)
    static let creamDark = Color(red: 0.955, green: 0.89, blue: 0.75)
    static let card = Color.white
    static let yellow = Color(red: 1.0, green: 0.82, blue: 0.25)
    static let overtime = Color(red: 1.0, green: 0.54, blue: 0.12)
    static let spark = yellow
    static let heal = Color(red: 0.35, green: 0.9, blue: 0.4)
    static let blood = Color(red: 0.72, green: 0.06, blue: 0.16)
    static let disabled = Color(red: 0.72, green: 0.7, blue: 0.78)
    static let textSecondary = ink.opacity(0.6)
    /// Used by a few shared drawings (snake tail shading).
    static let shadowHue = ink

    static let outlineWidth: CGFloat = 3
    static let shadowDepth: CGFloat = 5

    static func titleFont(_ size: CGFloat) -> Font { .system(size: size, weight: .black, design: .rounded) }
    static func bodyFont(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

extension PlayerSlot {
    var color: Color {
        switch self {
        case .one: return Color(red: 0.18, green: 0.62, blue: 1.0)
        case .two: return Color(red: 1.0, green: 0.3, blue: 0.37)
        }
    }

    var lightColor: Color { color.mix(with: .white, by: 0.7) }
}

extension EffectsState.Tint {
    var color: Color {
        switch self {
        case .player(let slot): return slot.color
        case .white: return .white
        case .spark: return Theme.spark
        case .heal: return Theme.heal
        }
    }
}

extension Vec2 {
    var cgPoint: CGPoint { CGPoint(x: x, y: y) }
}

// MARK: - Reusable cartoon pieces

/// Rounded panel with an ink outline and a hard drop shadow.
struct CartoonCard: ViewModifier {
    var fill: Color = Theme.cream
    var cornerRadius: CGFloat = 18
    var shadow: CGFloat = Theme.shadowDepth
    var lineWidth: CGFloat = Theme.outlineWidth

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius).fill(Theme.ink).offset(y: shadow)
                    RoundedRectangle(cornerRadius: cornerRadius).fill(fill)
                    RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(Theme.ink, lineWidth: lineWidth)
                }
            }
    }
}

extension View {
    func cartoonCard(fill: Color = Theme.cream, cornerRadius: CGFloat = 18,
                     shadow: CGFloat = Theme.shadowDepth, lineWidth: CGFloat = Theme.outlineWidth) -> some View {
        modifier(CartoonCard(fill: fill, cornerRadius: cornerRadius, shadow: shadow, lineWidth: lineWidth))
    }
}

/// Chunky button that squashes down into its shadow when pressed.
struct CartoonButtonStyle: ButtonStyle {
    var fill: Color = Theme.yellow
    var foreground: Color = Theme.ink
    var fontSize: CGFloat = 18
    var cornerRadius: CGFloat = 14
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed && isEnabled
        let depth: CGFloat = pressed ? 1 : Theme.shadowDepth
        configuration.label
            .font(Theme.titleFont(fontSize))
            .foregroundStyle(isEnabled ? foreground : Theme.ink.opacity(0.45))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .padding(.horizontal, 10)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius).fill(isEnabled ? fill : Theme.disabled)
                    RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(Theme.ink, lineWidth: Theme.outlineWidth)
                }
            }
            .offset(y: Theme.shadowDepth - depth)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius).fill(Theme.ink).offset(y: Theme.shadowDepth)
            }
            .padding(.bottom, Theme.shadowDepth)
            .animation(.spring(duration: 0.15, bounce: 0.5), value: pressed)
    }
}

/// Bold text with an ink outline and a hard drop shadow, like a comic title.
struct OutlinedText: View {
    let text: String
    var size: CGFloat
    var fill: Color = .white
    var outline: CGFloat = 3

    init(_ text: String, size: CGFloat, fill: Color = .white, outline: CGFloat = 3) {
        self.text = text
        self.size = size
        self.fill = fill
        self.outline = outline
    }

    var body: some View {
        let label = Text(text).font(Theme.titleFont(size))
        ZStack {
            label.foregroundStyle(Theme.ink).offset(y: outline * 1.8)
            ForEach(0..<8, id: \.self) { i in
                let a = Double(i) * .pi / 4
                label.foregroundStyle(Theme.ink).offset(x: cos(a) * outline, y: sin(a) * outline)
            }
            label.foregroundStyle(fill)
        }
    }
}

/// Purple polka-dot backdrop.
struct CartoonBackground: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Theme.background))
            let spacing: CGFloat = 34
            var row = 0
            var y: CGFloat = 0
            while y < size.height + spacing {
                var x: CGFloat = row.isMultiple(of: 2) ? 0 : spacing / 2
                while x < size.width + spacing {
                    context.fill(Path(ellipseIn: CGRect(x: x - 4, y: y - 4, width: 8, height: 8)),
                                 with: .color(Theme.backgroundDot))
                    x += spacing
                }
                y += spacing * 0.866
                row += 1
            }
        }
        .ignoresSafeArea()
    }
}

/// Canvas helper: comic-style outlined text.
enum CartoonText {
    static func draw(_ string: String, size: CGFloat, fill: Color, outline: CGFloat = 3,
                     at point: CGPoint, anchor: UnitPoint = .center, in context: inout GraphicsContext) {
        let back = context.resolve(Text(string).font(Theme.titleFont(size)).foregroundStyle(Theme.ink))
        let front = context.resolve(Text(string).font(Theme.titleFont(size)).foregroundStyle(fill))
        context.draw(back, at: CGPoint(x: point.x, y: point.y + outline * 1.8), anchor: anchor)
        for i in 0..<8 {
            let a = Double(i) * .pi / 4
            context.draw(back, at: CGPoint(x: point.x + cos(a) * outline, y: point.y + sin(a) * outline), anchor: anchor)
        }
        context.draw(front, at: point, anchor: anchor)
    }
}

/// Back button used at the top of setup screens.
struct BackButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                Text(title)
            }
            .font(Theme.bodyFont(15, weight: .black))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .cartoonCard(fill: Theme.cream, cornerRadius: 12, shadow: 3, lineWidth: 2.5)
        }
        .buttonStyle(.plain)
    }
}
