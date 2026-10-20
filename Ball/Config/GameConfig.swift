import Foundation

// MARK: - Players

enum PlayerSlot: Int, CaseIterable, Identifiable, Hashable {
    case one = 0
    case two = 1

    var id: Int { rawValue }
    var label: String { self == .one ? "P1" : "P2" }
    var title: String { self == .one ? String(localized: "Player 1") : String(localized: "Player 2") }
    var opponent: PlayerSlot { self == .one ? .two : .one }
}

// MARK: - Global game settings
//
// Everything that affects the feel of a match lives here or in `FighterCatalog`
// (see FighterCatalog.swift for per-fighter balance values).

enum GameConfig {
    /// Logical arena size in physics units. The view scales this to fit the screen,
    /// so the simulation behaves identically on every device.
    static let arenaWidth: Double = 480
    static let arenaHeight: Double = 600
    /// The floor is a chessboard of these squares (8 × 10). Gambit's moves use it.
    static let boardTile: Double = 60

    /// Physics runs at a fixed 120 Hz regardless of display refresh rate.
    static let fixedTimeStep: Double = 1.0 / 120.0
    /// Frame time is clamped so a hitch never causes a huge catch-up burst.
    static let maxFrameDelta: Double = 0.25

    static let countdownDuration: Double = 3.0
    /// Delay between the final blow and the results screen, so the KO is visible.
    static let resultsDelay: Double = 1.1
    /// Online: away from a fight (app in the background) longer than this counts as leaving it.
    static let onlineAwayLimit: Double = 30

    /// Spawn positions as a fraction of arena height (P1 top, P2 bottom).
    static let spawnHeightFraction: Double = 0.25
    /// Launch angles avoid being within this many radians of the arena axes,
    /// which would otherwise produce long, boring straight-line bounces.
    static let launchAxisAvoidance: Double = 12 * .pi / 180

    static let physics = PhysicsSettings(
        launchSpeed: 300,
        minSpeed: 210,
        maxSpeed: 500,
        ballRestitution: 1.0,
        wallRestitution: 1.0,
        linearDamping: 0.0
    )

    static let overtime = OvertimeSettings(
        startTime: 60,
        rampPerSecond: 0.05,
        maxMultiplier: 3.0
    )
}

struct PhysicsSettings: Equatable {
    /// Speed every ball receives at launch.
    var launchSpeed: Double
    /// Balls are sped back up to this if they slow down.
    var minSpeed: Double
    /// Balls are capped at this so the action stays readable.
    var maxSpeed: Double
    var ballRestitution: Double
    var wallRestitution: Double
    /// Fraction of velocity lost per second (0 = frictionless).
    var linearDamping: Double
}

struct OvertimeSettings: Equatable {
    /// Seconds of battle time before overtime begins.
    var startTime: Double
    /// Damage multiplier added per second of overtime.
    var rampPerSecond: Double
    var maxMultiplier: Double

    func damageMultiplier(at battleTime: Double) -> Double {
        guard battleTime > startTime else { return 1 }
        return min(maxMultiplier, 1 + (battleTime - startTime) * rampPerSecond)
    }

    func isActive(at battleTime: Double) -> Bool { battleTime > startTime }
}
