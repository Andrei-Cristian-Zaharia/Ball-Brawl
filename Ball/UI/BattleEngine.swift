import SwiftUI
#if os(iOS)
import UIKit
#endif

/// Bridges the display clock to the fixed-timestep simulation.
///
/// The simulation itself is not observed (it changes every frame and is drawn by
/// `Canvas`); only coarse UI state like pause and the final outcome is observable.
@Observable
final class BattleEngine {
    @ObservationIgnored let setup: MatchSetup
    @ObservationIgnored private(set) var simulation: BattleSimulation
    /// 0…1 fraction between the last two physics steps, for smooth rendering.
    @ObservationIgnored private(set) var interpolation: Double = 0
    @ObservationIgnored private var lastDate: Date?
    @ObservationIgnored private var accumulator: Double = 0
    @ObservationIgnored private var outcomeScheduled = false
    @ObservationIgnored private let haptics = Haptics()
    /// Real seconds left of a hit-stop freeze (big hits briefly freeze the action).
    @ObservationIgnored private var hitStop: Double = 0
    /// Real seconds left of knockout slow motion.
    @ObservationIgnored private var slowMotion: Double = 0

    private static let hitStopDamage = 14.0
    private static let hitStopDuration = 0.07
    private static let knockoutSlowMotion = 1.1
    private static let slowMotionRate = 0.3

    private(set) var isPaused = false
    /// Held still while the VS intro plays; the countdown starts once it ends.
    private(set) var isIntroPlaying = true
    private(set) var outcome: BattleOutcome?

    let seed: UInt64
    /// Online: the slot this device locks when its countdown ends; the opponent's lock arrives over the network.
    @ObservationIgnored let onlineSlot: PlayerSlot?
    @ObservationIgnored var onLaunchLocked: ((Double) -> Void)?

    init(setup: MatchSetup, seed: UInt64 = UInt64.random(in: .min ... .max), onlineSlot: PlayerSlot? = nil) {
        self.setup = setup
        self.seed = seed
        self.onlineSlot = onlineSlot
        self.simulation = BattleSimulation(setup: setup, seed: seed)
        simulation.waitsForLaunchLock = onlineSlot != nil
    }

    /// Called once per display frame.
    func tick(_ date: Date) {
        guard !isPaused, !isIntroPlaying else { lastDate = nil; return }
        guard let last = lastDate else { lastDate = date; return }
        lastDate = date

        var frame = min(max(0, date.timeIntervalSince(last)), GameConfig.maxFrameDelta)
        // Presentation-only time warps; the simulation still advances in fixed steps.
        if hitStop > 0 {
            hitStop -= frame
            frame = 0
        } else if slowMotion > 0 {
            slowMotion -= frame
            frame *= Self.slowMotionRate
        }
        let dt = GameConfig.fixedTimeStep
        accumulator += frame
        while accumulator >= dt {
            simulation.step(dt: dt)
            accumulator -= dt
        }
        interpolation = accumulator / dt

        if let onlineSlot, simulation.isWaitingForLaunchLock, !simulation.lockedSlots.contains(onlineSlot) {
            let angle = simulation.launchVelocities[onlineSlot.rawValue].angle
            simulation.lockLaunch(onlineSlot, angle: angle)
            onLaunchLocked?(angle)
        }

        let events = simulation.drainEvents()
        for event in events {
            switch event {
            case .damage(let hit) where hit.amount >= Self.hitStopDamage:
                hitStop = max(hitStop, Self.hitStopDuration)
            case .defeated:
                hitStop = max(hitStop, Self.hitStopDuration * 2)
                slowMotion = Self.knockoutSlowMotion
            default:
                break
            }
        }
        haptics.play(events)

        if case .finished(let result) = simulation.phase,
           simulation.timeSinceFinish >= GameConfig.resultsDelay,
           !outcomeScheduled {
            outcomeScheduled = true
            // Publish outside the view update that called `tick`.
            DispatchQueue.main.async { [weak self] in
                withAnimation(.spring(duration: 0.4)) { self?.outcome = result }
            }
        }
    }

    var canPause: Bool { outcome == nil && !isIntroPlaying }

    func finishIntro() {
        isIntroPlaying = false
        lastDate = nil
    }

    func setPaused(_ paused: Bool) {
        guard canPause || !paused else { return }
        isPaused = paused
        lastDate = nil
    }
}

/// Light haptic feedback on hits (iPhone only; no-op elsewhere).
private final class Haptics {
    #if os(iOS)
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notify = UINotificationFeedbackGenerator()
    #endif

    func play(_ events: [BattleEvent]) {
        #if os(iOS)
        guard GameSettings.vibrationEnabled else { return }
        for event in events {
            switch event {
            case .damage: light.impactOccurred(intensity: 0.8)
            case .launched: heavy.impactOccurred(intensity: 0.6)
            case .defeated: notify.notificationOccurred(.success)
            case .ability(_, _, _, true): heavy.impactOccurred(intensity: 1)
            case .overtimeStarted: notify.notificationOccurred(.warning)
            default: break
            }
        }
        #endif
    }
}
