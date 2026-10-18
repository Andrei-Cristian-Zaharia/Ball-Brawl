import SwiftUI

/// Polished toy-arcade look: an electric indigo-to-violet stage, warm off-white panels with soft ink
/// outlines, glossy buttons outlined in a deeper shade of themselves, and the comic outlined font kept
/// for the logo and big moments (Battle, Victory, chests).
enum Theme {
    static let ink = Color(red: 0.09, green: 0.07, blue: 0.24)
    static let background = Color(red: 0.2, green: 0.3, blue: 0.88)
    /// The violet the stage fades into at the bottom.
    static let backgroundDeep = Color(red: 0.25, green: 0.12, blue: 0.55)
    static let cream = Color(red: 0.995, green: 0.97, blue: 0.925)
    static let creamDark = Color(red: 0.94, green: 0.905, blue: 0.84)
    static let card = Color.white
    static let yellow = Color(red: 1.0, green: 0.82, blue: 0.25)
    static let overtime = Color(red: 1.0, green: 0.54, blue: 0.12)
    static let spark = yellow
    static let heal = Color(red: 0.35, green: 0.9, blue: 0.4)
    /// A deep green that white text reads well on (buttons like Watch, Upgrade, Shop). `heal` is
    /// for effects and bars, too light for white labels.
    static let go = Color(red: 0.13, green: 0.58, blue: 0.3)
    static let blood = Color(red: 0.72, green: 0.06, blue: 0.16)
    static let disabled = Color(red: 0.72, green: 0.7, blue: 0.78)
    static let textSecondary = ink.opacity(0.6)
    /// Used by a few shared drawings (snake tail shading).
    static let shadowHue = ink

    static let outlineWidth: CGFloat = 2.5
    static let shadowDepth: CGFloat = 4

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
        // Outlines stay fine and slightly soft, whatever a caller asks for.
        let lineWidth = min(lineWidth, 2.5)
        let shadow = min(shadow, 5)
        content
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius).fill(Theme.ink.opacity(0.8)).offset(y: shadow)
                    RoundedRectangle(cornerRadius: cornerRadius).fill(LinearGradient(
                        colors: [fill.mix(with: .white, by: 0.25), fill, fill.mix(with: Theme.ink, by: 0.08)],
                        startPoint: .top, endPoint: .bottom))
                    // Inner rim light, like a glossy plastic panel.
                    RoundedRectangle(cornerRadius: max(0, cornerRadius - lineWidth))
                        .strokeBorder(.white.opacity(0.55), lineWidth: 1.5)
                        .padding(lineWidth)
                    RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(Theme.ink.opacity(0.85), lineWidth: lineWidth)
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
    /// Drop shadow under white labels. Off for labels that style their own text (art would get smudged).
    var labelShadow = true
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed && isEnabled
        let depth: CGFloat = pressed ? 1 : Theme.shadowDepth
        let base = isEnabled ? fill : Theme.disabled
        let edge = base.mix(with: Theme.ink, by: 0.62)
        let lightText = isEnabled && foreground == .white && labelShadow
        configuration.label
            .font(Theme.titleFont(fontSize))
            // Longer translations shrink to fit instead of wrapping.
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .foregroundStyle(isEnabled ? foreground : Theme.ink.opacity(0.45))
            // White labels get a hard drop shadow so they pop off any color.
            .shadow(color: lightText ? edge.opacity(0.9) : .clear, radius: 0, x: 0, y: 2)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .padding(.horizontal, 10)
            .background {
                ZStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: cornerRadius).fill(LinearGradient(
                        colors: [base.mix(with: .white, by: 0.3), base, base.mix(with: Theme.ink, by: 0.12)],
                        startPoint: .top, endPoint: .bottom))
                    // Hard-edged gloss band across the top half.
                    RoundedRectangle(cornerRadius: max(0, cornerRadius - 4))
                        .fill(LinearGradient(stops: [.init(color: .white.opacity(0.22), location: 0),
                                                     .init(color: .white.opacity(0.08), location: 0.47),
                                                     .init(color: .clear, location: 0.5)],
                                             startPoint: .top, endPoint: .bottom))
                        .padding(4)
                    // Outlined in a deep shade of its own color: crisp without a black cartoon border.
                    RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(edge, lineWidth: Theme.outlineWidth)
                }
            }
            .offset(y: Theme.shadowDepth - depth)
            .background {
                // The 3D lip: a darker shade of the button.
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius).fill(base.mix(with: Theme.ink, by: 0.45))
                    RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(edge, lineWidth: Theme.outlineWidth)
                }
                .offset(y: Theme.shadowDepth)
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
        let label = Text(text.localized).font(Theme.titleFont(size))
        ZStack {
            // Deep drop shadow, then a solid outline all around, then the fill with a soft top-down gradient.
            label.foregroundStyle(Theme.ink).offset(y: outline * 1.8)
            ForEach(0..<12, id: \.self) { i in
                let a = Double(i) * .pi / 6
                label.foregroundStyle(Theme.ink).offset(x: cos(a) * outline, y: sin(a) * outline)
            }
            label.foregroundStyle(LinearGradient(colors: [fill.mix(with: .white, by: 0.35), fill, fill.mix(with: Theme.ink, by: 0.1)],
                                                 startPoint: .top, endPoint: .bottom))
        }
    }
}

/// The stage behind every screen: an electric indigo-to-violet gradient, a soft spotlight from above,
/// and a faint arena-tile floor in perspective (echoing the battle floor), with a gentle vignette.
struct CartoonBackground: View {
    var color: Color = Theme.background

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            let w = size.width, h = size.height
            context.fill(Path(rect), with: .linearGradient(
                Gradient(colors: [color.mix(with: .white, by: 0.1), color, color.mix(with: Theme.backgroundDeep, by: 0.75)]),
                startPoint: CGPoint(x: w * 0.3, y: 0), endPoint: CGPoint(x: w * 0.7, y: h)))

            // Spotlight from above.
            let spot = CGPoint(x: w / 2, y: h * 0.1)
            context.fill(Path(rect), with: .radialGradient(
                Gradient(colors: [.white.opacity(0.2), .white.opacity(0)]),
                center: spot, startRadius: 0, endRadius: max(w, h) * 0.65))

            // Tile floor in perspective, fading in from the horizon.
            let horizon = h * 0.58
            let vanish = CGPoint(x: w / 2, y: horizon - h * 0.3)
            let fade = GraphicsContext.Shading.linearGradient(
                Gradient(colors: [.white.opacity(0), .white.opacity(0.14)]),
                startPoint: CGPoint(x: 0, y: horizon), endPoint: CGPoint(x: 0, y: h))
            var floor = Path()
            let rows = 9
            for i in 1...rows {
                let t = Double(i) / Double(rows)
                let y = horizon + (h - horizon) * t * t
                floor.move(to: CGPoint(x: 0, y: y))
                floor.addLine(to: CGPoint(x: w, y: y))
            }
            let columns = 12
            for i in -columns...columns {
                let bottomX = w / 2 + Double(i) * w / 5
                // Only the part below the horizon.
                let t = (horizon - vanish.y) / (h - vanish.y)
                floor.move(to: CGPoint(x: vanish.x + (bottomX - vanish.x) * t, y: horizon))
                floor.addLine(to: CGPoint(x: bottomX, y: h))
            }
            context.stroke(floor, with: fade, lineWidth: 1.5)

            // Vignette.
            context.fill(Path(rect), with: .radialGradient(
                Gradient(colors: [.clear, Theme.ink.opacity(0.35)]),
                center: CGPoint(x: w / 2, y: h * 0.45), startRadius: min(w, h) * 0.45, endRadius: max(w, h) * 0.85))
        }
        .ignoresSafeArea()
    }
}

/// A screen's heading: clean white type with a soft drop, leaving the outlined comic font for big moments.
struct ScreenTitle: View {
    let title: String
    var subtitle: String?

    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(title.localized)
                .font(Theme.titleFont(30))
                .tracking(1.5)
                .foregroundStyle(.white)
                .shadow(color: Theme.ink.opacity(0.45), radius: 0, x: 0, y: 3)
            Capsule()
                .fill(LinearGradient(colors: [Theme.yellow, Theme.overtime], startPoint: .leading, endPoint: .trailing))
                .frame(width: 44, height: 4)
            if let subtitle {
                Text(subtitle.localized)
                    .font(Theme.bodyFont(13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.top, 2)
            }
        }
    }
}

/// Frosted tile on the stage: a translucent glass panel with a soft white rim. Squashes when pressed.
struct GlassTileStyle: ButtonStyle {
    var cornerRadius: CGFloat = 18

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(LinearGradient(colors: [.white.opacity(0.2), .white.opacity(0.07)], startPoint: .top, endPoint: .bottom))
                    .background(RoundedRectangle(cornerRadius: cornerRadius).fill(Theme.ink.opacity(0.25)))
                    .overlay(RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(.white.opacity(0.22), lineWidth: 1.5))
            }
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(duration: 0.15, bounce: 0.5), value: configuration.isPressed)
    }
}

/// Canvas helper: comic-style outlined text.
enum CartoonText {
    /// With `maxWidth`, text too wide for the space shrinks (outline too) until it fits.
    static func draw(_ string: String, size: CGFloat, fill: Color, outline: CGFloat = 3,
                     at point: CGPoint, anchor: UnitPoint = .center, maxWidth: CGFloat? = nil,
                     in context: inout GraphicsContext) {
        let string = string.localized
        if let maxWidth {
            let width = context.resolve(Text(string).font(Theme.titleFont(size))).measure(in: CGSize(width: 10_000, height: 1_000)).width
            if width > maxWidth, width > 0 {
                let scale = max(0.5, maxWidth / width)
                draw(string, size: size * scale, fill: fill, outline: outline * scale, at: point, anchor: anchor, in: &context)
                return
            }
        }
        let back = context.resolve(Text(string).font(Theme.titleFont(size)).foregroundStyle(Theme.ink))
        let front = context.resolve(Text(string).font(Theme.titleFont(size)).foregroundStyle(fill))
        context.draw(back, at: CGPoint(x: point.x, y: point.y + outline * 1.5), anchor: anchor)
        for i in 0..<12 {
            let a = Double(i) * .pi / 6
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
                Text(title.localized)
            }
            .font(Theme.bodyFont(15, weight: .black))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .cartoonCard(fill: Theme.cream, cornerRadius: 12, shadow: 3, lineWidth: 2.5)
        }
        .buttonStyle(.plain)
    }
}
