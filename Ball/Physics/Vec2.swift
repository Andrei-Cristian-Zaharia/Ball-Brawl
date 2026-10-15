import Foundation

/// Minimal 2D vector used by physics and game logic (y points down, like the screen).
struct Vec2: Equatable {
    var x: Double
    var y: Double

    init(_ x: Double, _ y: Double) {
        self.x = x
        self.y = y
    }

    static let zero = Vec2(0, 0)

    static func fromAngle(_ angle: Double, length: Double = 1) -> Vec2 {
        Vec2(cos(angle) * length, sin(angle) * length)
    }

    var lengthSquared: Double { x * x + y * y }
    var length: Double { lengthSquared.squareRoot() }
    var angle: Double { atan2(y, x) }

    var normalized: Vec2 {
        let len = length
        return len > 1e-9 ? Vec2(x / len, y / len) : .zero
    }

    func dot(_ other: Vec2) -> Double { x * other.x + y * other.y }

    func lerp(to other: Vec2, _ t: Double) -> Vec2 { self + (other - self) * t }

    static func + (a: Vec2, b: Vec2) -> Vec2 { Vec2(a.x + b.x, a.y + b.y) }
    static func - (a: Vec2, b: Vec2) -> Vec2 { Vec2(a.x - b.x, a.y - b.y) }
    static func * (a: Vec2, s: Double) -> Vec2 { Vec2(a.x * s, a.y * s) }
    static func / (a: Vec2, s: Double) -> Vec2 { Vec2(a.x / s, a.y / s) }
    static prefix func - (a: Vec2) -> Vec2 { Vec2(-a.x, -a.y) }
    static func += (a: inout Vec2, b: Vec2) { a = a + b }
    static func -= (a: inout Vec2, b: Vec2) { a = a - b }

    /// Closest distance from the origin to the segment `a`→`b`.
    /// Used for swept (anti-tunneling) hit tests.
    static func segmentDistanceToOrigin(_ a: Vec2, _ b: Vec2) -> Double {
        let ab = b - a
        let lenSq = ab.lengthSquared
        guard lenSq > 1e-12 else { return a.length }
        let t = min(1, max(0, -a.dot(ab) / lenSq))
        return (a + ab * t).length
    }
}
