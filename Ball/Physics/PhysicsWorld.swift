import Foundation

struct PhysicsBody {
    var position: Vec2
    var previousPosition: Vec2
    var velocity: Vec2
    var radius: Double
    var mass: Double
    /// Moved by game logic (e.g. while held by a Grappler): no integration, walls or collisions.
    var isKinematic = false
    /// Temporarily exempt from the max-speed cap (e.g. while thrown).
    var ignoresSpeedLimit = false
    /// Locked in place but still solid: collides as an immovable object.
    var isFrozen = false

    init(position: Vec2, radius: Double, mass: Double) {
        self.position = position
        self.previousPosition = position
        self.velocity = .zero
        self.radius = radius
        self.mass = mass
    }
}

struct BodyContact {
    var a: Int
    var b: Int
    /// Point on the surface of `a` facing `b`.
    var point: Vec2
    /// Unit normal pointing from `a` to `b`.
    var normal: Vec2
    /// Closing speed along the normal before the bounce (0 for resting contact).
    var impactSpeed: Double
    /// How fast each body was driving into the other before the bounce.
    var approachSpeedA: Double
    var approachSpeedB: Double
}

struct WallContact {
    var body: Int
    /// Center of the body at impact.
    var point: Vec2
    /// Point on the wall surface that was hit.
    var wallPoint: Vec2
    var impactSpeed: Double
}

struct PhysicsStepResult {
    var bodyContacts: [BodyContact] = []
    var wallContacts: [WallContact] = []
}

/// Top-down, gravity-free circle physics inside a rectangular arena.
///
/// Each fixed step is split into enough substeps that no body moves more than a
/// fraction of its radius per substep, so balls can't tunnel through walls or each other.
struct PhysicsWorld {
    let width: Double
    let height: Double
    var settings: PhysicsSettings
    var bodies: [PhysicsBody] = []

    init(width: Double, height: Double, settings: PhysicsSettings) {
        self.width = width
        self.height = height
        self.settings = settings
    }

    mutating func step(dt: Double) -> PhysicsStepResult {
        var result = PhysicsStepResult()
        guard !bodies.isEmpty else { return result }

        for i in bodies.indices { bodies[i].previousPosition = bodies[i].position }

        let maxTravel = bodies.map { $0.velocity.length * dt }.max() ?? 0
        let minRadius = bodies.map(\.radius).min() ?? 1
        let substeps = max(1, Int((maxTravel / (minRadius * 0.25)).rounded(.up)))
        let h = dt / Double(substeps)

        for _ in 0..<substeps {
            integrate(h)
            resolveWalls(into: &result)
            resolveBodies(into: &result)
        }

        enforceSpeedLimits()
        return result
    }

    private mutating func integrate(_ h: Double) {
        let damping = max(0, 1 - settings.linearDamping * h)
        for i in bodies.indices where !bodies[i].isKinematic && !bodies[i].isFrozen {
            bodies[i].velocity = bodies[i].velocity * damping
            bodies[i].position += bodies[i].velocity * h
        }
    }

    private mutating func resolveWalls(into result: inout PhysicsStepResult) {
        let e = settings.wallRestitution
        for i in bodies.indices where !bodies[i].isKinematic {
            var b = bodies[i]
            let r = b.radius
            var impact = 0.0
            var wallPoint = b.position
            if b.position.x - r < 0 {
                b.position.x = r
                if b.velocity.x < 0 { impact = max(impact, -b.velocity.x); b.velocity.x = -b.velocity.x * e; wallPoint = Vec2(0, b.position.y) }
            } else if b.position.x + r > width {
                b.position.x = width - r
                if b.velocity.x > 0 { impact = max(impact, b.velocity.x); b.velocity.x = -b.velocity.x * e; wallPoint = Vec2(width, b.position.y) }
            }
            if b.position.y - r < 0 {
                b.position.y = r
                if b.velocity.y < 0 { impact = max(impact, -b.velocity.y); b.velocity.y = -b.velocity.y * e; wallPoint = Vec2(b.position.x, 0) }
            } else if b.position.y + r > height {
                b.position.y = height - r
                if b.velocity.y > 0 { impact = max(impact, b.velocity.y); b.velocity.y = -b.velocity.y * e; wallPoint = Vec2(b.position.x, height) }
            }
            if impact > 0 {
                result.wallContacts.append(WallContact(body: i, point: b.position, wallPoint: wallPoint, impactSpeed: impact))
            }
            bodies[i] = b
        }
    }

    private mutating func resolveBodies(into result: inout PhysicsStepResult) {
        guard bodies.count > 1 else { return }
        let e = settings.ballRestitution
        for i in 0..<(bodies.count - 1) {
            for j in (i + 1)..<bodies.count {
                guard !bodies[i].isKinematic && !bodies[j].isKinematic else { continue }
                guard !(bodies[i].isFrozen && bodies[j].isFrozen) else { continue }
                var a = bodies[i]
                var b = bodies[j]
                let delta = b.position - a.position
                let dist = delta.length
                let minDist = a.radius + b.radius
                guard dist < minDist else { continue }

                let normal = dist > 1e-9 ? delta / dist : Vec2(1, 0)
                // Frozen bodies act as immovable (infinite mass).
                let invA = a.isFrozen ? 0 : 1 / a.mass
                let invB = b.isFrozen ? 0 : 1 / b.mass

                // Push apart so they no longer overlap.
                let correction = normal * ((minDist - dist) / (invA + invB))
                a.position -= correction * invA
                b.position += correction * invB

                let approachA = max(0, a.velocity.dot(normal))
                let approachB = max(0, -b.velocity.dot(normal))

                // Elastic impulse along the contact normal.
                let closing = (b.velocity - a.velocity).dot(normal)
                if closing < 0 {
                    let j = -(1 + e) * closing / (invA + invB)
                    a.velocity -= normal * (j * invA)
                    b.velocity += normal * (j * invB)
                }

                bodies[i] = a
                bodies[j] = b

                if !result.bodyContacts.contains(where: { $0.a == i && $0.b == j }) {
                    result.bodyContacts.append(BodyContact(
                        a: i, b: j,
                        point: a.position + normal * a.radius,
                        normal: normal,
                        impactSpeed: max(0, -closing),
                        approachSpeedA: approachA,
                        approachSpeedB: approachB
                    ))
                }
            }
        }
    }

    /// Keeps balls moving (min speed) and readable (max speed).
    mutating func enforceSpeedLimits() {
        for i in bodies.indices where !bodies[i].isKinematic && !bodies[i].isFrozen {
            let v = bodies[i].velocity
            let speed = v.length
            if speed > settings.maxSpeed && !bodies[i].ignoresSpeedLimit {
                bodies[i].velocity = v * (settings.maxSpeed / speed)
            } else if speed < settings.minSpeed {
                // A stalled ball heads away from the arena center.
                let direction = speed > 1e-6
                    ? v / speed
                    : (bodies[i].position - Vec2(width / 2, height / 2)).normalized
                let fallback = direction == .zero ? Vec2(1, 0) : direction
                bodies[i].velocity = fallback * settings.minSpeed
            }
        }
    }
}
