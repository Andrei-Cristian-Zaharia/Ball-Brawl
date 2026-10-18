import Foundation

/// Purely cosmetic state: particles, damage numbers and screen shake.
/// Uses its own random source so visuals never affect gameplay.
struct EffectsState {
    enum Tint {
        case player(PlayerSlot)
        case white
        case spark
        case heal
    }

    struct Particle {
        var position: Vec2
        var velocity: Vec2
        var life: Double
        let maxLife: Double
        let size: Double
        let tint: Tint
    }

    struct FloatingText {
        var position: Vec2
        var life: Double
        let maxLife: Double
        let text: String
        let tint: Tint
        var size: Double = 24
    }

    /// Comic "POW" starbursts at hit points.
    struct ImpactStar {
        let position: Vec2
        var life: Double
        let maxLife: Double
        let size: Double
        let rotation: Double
        let tint: Tint
    }

    var particles: [Particle] = []
    var stars: [ImpactStar] = []
    var texts: [FloatingText] = []
    /// 0…1 shake intensity; offset scales with trauma² for a soft falloff.
    var trauma: Double = 0
    var shakeOffset: Vec2 = .zero

    private static let maxParticles = 260
    private static let maxShake = 7.0

    mutating func update(dt: Double) {
        for i in particles.indices {
            particles[i].position += particles[i].velocity * dt
            particles[i].velocity = particles[i].velocity * max(0, 1 - 4 * dt)
            particles[i].life -= dt
        }
        particles.removeAll { $0.life <= 0 }

        for i in texts.indices {
            texts[i].position.y -= 38 * dt
            texts[i].life -= dt
        }
        texts.removeAll { $0.life <= 0 }

        for i in stars.indices { stars[i].life -= dt }
        stars.removeAll { $0.life <= 0 }

        trauma = max(0, trauma - 1.8 * dt)
        let magnitude = Self.maxShake * trauma * trauma
        shakeOffset = magnitude > 0.01
            ? Vec2(Double.random(in: -1...1) * magnitude, Double.random(in: -1...1) * magnitude)
            : .zero
    }

    mutating func burst(at point: Vec2, count: Int, tint: Tint, speed: ClosedRange<Double>,
                        direction: Vec2? = nil, spread: Double = .pi, life: ClosedRange<Double> = 0.25...0.5,
                        size: ClosedRange<Double> = 2...4) {
        let base = direction?.angle ?? 0
        for _ in 0..<count where particles.count < Self.maxParticles {
            let angle = direction == nil ? Double.random(in: 0..<(2 * .pi)) : base + Double.random(in: -spread...spread)
            let l = Double.random(in: life)
            particles.append(Particle(
                position: point,
                velocity: Vec2.fromAngle(angle, length: Double.random(in: speed)),
                life: l, maxLife: l,
                size: Double.random(in: size),
                tint: tint
            ))
        }
    }

    mutating func addShake(_ amount: Double) {
        trauma = min(1, trauma + amount)
    }

    mutating func addStar(at point: Vec2, size: Double, tint: Tint) {
        stars.append(ImpactStar(position: point, life: 0.28, maxLife: 0.28, size: size,
                                rotation: Double.random(in: 0..<(2 * .pi)), tint: tint))
    }

    mutating func addText(_ text: String, at point: Vec2, tint: Tint, size: Double = 24, life: Double = 0.8) {
        // Keep long callouts inside the arena (roughly half the text's width from each side wall).
        let half = min(GameConfig.arenaWidth / 2 - 4, Double(text.count) * size * 0.34)
        let x = min(max(point.x, half + 4), GameConfig.arenaWidth - half - 4)
        texts.append(FloatingText(position: Vec2(x, point.y), life: life, maxLife: life, text: text, tint: tint, size: size))
    }

    /// Translates gameplay events into visuals.
    mutating func react(to event: BattleEvent) {
        switch event {
        case .launched, .overtimeStarted:
            break
        case .projectileFired(let owner, let position, let direction):
            burst(at: position, count: 5, tint: .player(owner), speed: 60...160,
                  direction: direction, spread: 0.5, life: 0.12...0.22, size: 1.5...3)
        case .projectileHitWall(let owner, let position):
            burst(at: position, count: 6, tint: .player(owner), speed: 40...140, life: 0.15...0.3, size: 1.5...2.5)
        case .pulseReleased:
            break
        case .grabbed(let by, let position):
            addStar(at: position, size: 20, tint: .player(by))
            addShake(0.15)
        case .thrown(let by, let position):
            burst(at: position, count: 6, tint: .player(by), speed: 60...160, life: 0.15...0.3, size: 2.5...4)
        case .webSpun(_, let anchor):
            burst(at: anchor, count: 5, tint: .white, speed: 30...90, life: 0.15...0.3, size: 2...3)
        case .latched(let by, let position):
            addStar(at: position, size: 18, tint: .player(by))
        case .healed(_, let amount, let position):
            if amount >= 0.5 {
                addText("+\(Int(amount.rounded()))", at: position + Vec2(0, -30), tint: .heal)
                burst(at: position, count: 4, tint: .heal, speed: 30...90, life: 0.25...0.45, size: 2.5...4)
            }
        case .chessPlanned:
            break
        case .totality:
            addShake(0.7)
        case .hazardPlaced(let owner, let position):
            burst(at: position, count: 4, tint: .player(owner), speed: 30...90, life: 0.15...0.3, size: 2...3)
        case .explosion(_, let position, let radius, let icy):
            burst(at: position, count: icy ? 12 : 22, tint: icy ? .white : .spark, speed: 120...(radius * 4), size: 3...6)
            addStar(at: position, size: min(70, radius * 0.6), tint: icy ? .white : .spark)
            addShake(icy ? 0.3 : 0.6)
        case .held(let slot, let position):
            addStar(at: position, size: 24, tint: .player(slot))
            addShake(0.2)
        case .poisoned(_, let position):
            burst(at: position, count: 5, tint: .heal, speed: 30...80, life: 0.3...0.6, size: 2.5...4)
        case .trainDeparted:
            addShake(0.25)
        case .chessLanded(let slot, let position):
            burst(at: position, count: 8, tint: .player(slot), speed: 60...160, life: 0.15...0.3, size: 2.5...4)
            addShake(0.1)
        case .webSnapped(_, let point):
            burst(at: point, count: 8, tint: .white, speed: 60...180, life: 0.2...0.4, size: 2...3.5)
        case .ballCollision(let point, let impactSpeed):
            if impactSpeed > 60 {
                burst(at: point, count: 4, tint: .white, speed: 40...120, life: 0.12...0.25, size: 1.5...2.5)
            }
        case .wallBounce:
            break
        case .damage(let hit):
            let tint: Tint = .player(hit.target)
            switch hit.source {
            case .projectile:
                burst(at: hit.point, count: 8, tint: tint, speed: 80...240, direction: hit.direction, spread: 1.0, size: 2.5...4.5)
                addStar(at: hit.point, size: 22, tint: .white)
                addShake(0.28)
            case .contact:
                burst(at: hit.point, count: 10, tint: .spark, speed: 100...300, size: 2.5...4.5)
                addStar(at: hit.point, size: 30, tint: .spark)
                addShake(0.4)
            case .pulse:
                burst(at: hit.point, count: 10, tint: tint, speed: 90...260, direction: hit.direction, spread: 0.9, size: 2.5...4.5)
                addStar(at: hit.point, size: 26, tint: .white)
                addShake(0.35)
            case .slam:
                burst(at: hit.point, count: 14, tint: .spark, speed: 120...340, size: 3...5)
                addStar(at: hit.point, size: 40, tint: .spark)
                addShake(0.6)
            case .drain:
                burst(at: hit.point, count: 3, tint: tint, speed: 30...90, life: 0.2...0.35, size: 2...3.5)
            case .eclipse:
                burst(at: hit.point, count: 18, tint: .spark, speed: 120...360, size: 3...5)
                addStar(at: hit.point, size: 48, tint: .spark)
            case .chess:
                burst(at: hit.point, count: 12, tint: .spark, speed: 100...300, size: 3...5)
                addStar(at: hit.point, size: 34, tint: .white)
                addShake(0.45)
            case .web:
                burst(at: hit.point, count: 8, tint: tint, speed: 60...200, size: 2.5...4)
                addStar(at: hit.point, size: 20, tint: .white)
                addShake(0.2)
            case .poison:
                burst(at: hit.point, count: 2, tint: .heal, speed: 20...60, life: 0.3...0.5, size: 2...3)
            case .hazard, .shard, .tail:
                burst(at: hit.point, count: 6, tint: tint, speed: 60...200, size: 2.5...4)
                addStar(at: hit.point, size: 20, tint: .white)
                addShake(0.2)
            case .shock:
                burst(at: hit.point, count: 12, tint: .spark, speed: 100...280, size: 2.5...4)
                addStar(at: hit.point, size: 30, tint: .spark)
                addShake(0.35)
            case .explosion:
                addShake(0.3)
            case .train:
                burst(at: hit.point, count: 16, tint: .spark, speed: 120...360, size: 3...5)
                addStar(at: hit.point, size: 44, tint: .spark)
                addShake(0.7)
            }
            addText("-\(Int(hit.amount.rounded()))", at: hit.point + Vec2(0, -14), tint: .white)
        case .ability(let slot, let name, let position, let ultimate):
            addText(ultimate ? "\(name.localized.uppercased())!" : name.localized.uppercased(), at: position + Vec2(0, -58),
                    tint: ultimate ? .spark : .player(slot), size: ultimate ? 30 : 20, life: ultimate ? 1.3 : 0.9)
            burst(at: position, count: ultimate ? 26 : 10, tint: .spark, speed: 100...320, life: 0.3...0.7, size: 3...5)
            if ultimate {
                addStar(at: position, size: 56, tint: .spark)
                addShake(0.45)
            }
        case .defeated(let slot, let position):
            burst(at: position, count: 40, tint: .player(slot), speed: 120...420, life: 0.5...1.1, size: 3...6)
            burst(at: position, count: 14, tint: .spark, speed: 80...260, life: 0.3...0.7, size: 3...5)
            addStar(at: position, size: 60, tint: .spark)
            addShake(0.9)
        }
    }
}
