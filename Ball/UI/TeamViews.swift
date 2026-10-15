import SwiftUI

/// Small procedurally drawn fighter, for menus and team lists.
struct FighterPortrait: View {
    let definition: FighterDefinition
    let color: Color
    var size: CGFloat = 56
    var expression: FighterArt.Expression = .normal

    var body: some View {
        Canvas { context, canvasSize in
            let scale = CGFloat(definition.visualRadius / definition.radius)
            let r = min(canvasSize.width, canvasSize.height) / 2 / (scale + 0.12) - 2
            FighterArt.draw(definition, in: &context,
                            center: CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2 + r * 0.08),
                            radius: r, team: color, spin: 0.3,
                            aimAngle: definition.requiresAim ? -.pi / 4 : nil,
                            expression: expression)
        }
        .frame(width: size, height: size)
    }
}

/// Chunky health bar for team lists. Overheal shows as a green segment from the far end.
struct HealthPill: View {
    let fraction: Double
    let color: Color
    var overheal: Double = 0
    var height: CGFloat = 12

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.ink.mix(with: .white, by: 0.15))
                Capsule().fill(color).frame(width: geo.size.width * max(0, min(1, fraction)))
                if overheal > 0 {
                    Rectangle().fill(Theme.heal)
                        .frame(width: geo.size.width * min(1, overheal))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(Theme.ink, lineWidth: 2))
        }
        .frame(height: height)
    }
}

/// One team member: portrait, name and remaining health. Knocked-out members are greyed.
struct TeamMemberTile: View {
    let member: TeamMember
    let color: Color
    var isSelected = false
    var tag: String? = nil

    var body: some View {
        VStack(spacing: 4) {
            FighterPortrait(definition: member.definition, color: member.isAlive ? color : Theme.disabled,
                            size: 58, expression: member.isAlive ? (isSelected ? .happy : .normal) : .knockedOut)
            Text(member.definition.name)
                .font(Theme.bodyFont(13, weight: .black))
                .foregroundStyle(Theme.ink)
                .lineLimit(1).minimumScaleFactor(0.7)
            HealthPill(fraction: member.healthFraction, color: member.isAlive ? color : Theme.disabled,
                       overheal: max(0, member.health - member.definition.maxHealth) / member.definition.maxHealth)
            Text(member.isAlive ? "\(Int(member.health.rounded(.up))) HP" : "K.O.")
                .font(Theme.bodyFont(11, weight: .black))
                .foregroundStyle(member.isAlive ? Theme.ink : Theme.ink.opacity(0.5))
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .cartoonCard(fill: isSelected ? color.mix(with: .white, by: 0.65) : .white, cornerRadius: 14,
                     shadow: isSelected ? 1 : 4, lineWidth: 2.5)
        .offset(y: isSelected ? 3 : 0)
        .overlay(alignment: .top) {
            if let tag {
                Text(tag)
                    .font(Theme.bodyFont(10, weight: .black))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .cartoonCard(fill: Theme.yellow, cornerRadius: 7, shadow: 0, lineWidth: 2)
                    .offset(y: -9)
            }
        }
        .opacity(member.isAlive ? 1 : 0.6)
    }
}

/// Compact row showing a whole team's status.
struct TeamStatusRow: View {
    let title: String
    let members: [TeamMember]
    let color: Color
    var activeIndex: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(Theme.bodyFont(12, weight: .black))
                .foregroundStyle(Theme.ink.opacity(0.7))
            HStack(spacing: 8) {
                ForEach(members) { member in
                    TeamMemberTile(member: member, color: color, isSelected: member.id == activeIndex)
                }
            }
        }
    }
}
