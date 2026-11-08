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
    /// Real seconds the simulation still has to catch up on.
    @ObservationIgnored private var owed: Double = 0
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
    /// Most real time played per frame; after a trip to the background an online fight fast-forwards at this rate.
    private static let maxCatchUpPerFrame = 0.5

    private(set) var isPaused = false
    /// Held still while the VS intro plays; the countdown starts once it ends.
    private(set) var isIntroPlaying = true
    private(set) var outcome: BattleOutcome?

    let seed: UInt64
    /// Online: the slot this device locks when its countdown ends; the opponent's lock arrives over the network.
    @ObservationIgnored let onlineSlot: PlayerSlot?
    @ObservationIgnored var onLaunchLocked: ((Double) -> Void)?
    #if DEBUG
    /// App Store screenshots: the fight is held still at a chosen moment.
    @ObservationIgnored private(set) var isHeldForStoreDemo = false
    #endif

    init(setup: MatchSetup, seed: UInt64 = UInt64.random(in: .min ... .max), onlineSlot: PlayerSlot? = nil) {
        self.setup = setup
        self.seed = seed
        self.onlineSlot = onlineSlot
        self.simulation = BattleSimulation(setup: setup, seed: seed)
        simulation.waitsForLaunchLock = onlineSlot != nil
    }

    /// Called once per display frame.
    func tick(_ date: Date) {
        #if DEBUG
        if isHeldForStoreDemo { return }
        #endif
        guard !isPaused, !isIntroPlaying else { lastDate = nil; return }
        guard let last = lastDate else { lastDate = date; return }
        lastDate = date

        let delta = max(0, date.timeIntervalSince(last))
        // Online, no time is dropped: a hitch or a trip to the background is caught up, so both devices
        // stay at the same moment of the fight. Offline, a long frame is just clamped.
        owed += onlineSlot == nil ? min(delta, GameConfig.maxFrameDelta) : delta

        // Hit-stop and slow motion are counted per step rather than per frame, so they last exactly as
        // long on every device whatever its frame rate.
        let dt = GameConfig.fixedTimeStep
        var budget = Self.maxCatchUpPerFrame
        var events: [BattleEvent] = []
        while budget > 0 {
            if hitStop > 0 {
                let frozen = min(hitStop, owed, budget)
                hitStop -= frozen
                owed -= frozen
                budget -= frozen
                if hitStop > 0 { break }
                continue
            }
            let cost = stepCost
            guard owed >= cost, budget >= cost else { break }
            owed -= cost
            budget -= cost
            if slowMotion > 0 { slowMotion = max(0, slowMotion - cost) }
            simulation.step(dt: dt)
            lockLaunchIfDue()
            let stepEvents = simulation.drainEvents()
            startTimeWarps(for: stepEvents)
            events += stepEvents
        }
        interpolation = hitStop > 0 ? 0 : min(1, owed / stepCost)
        // No buzzing through a fast-forward.
        if budget > Self.maxCatchUpPerFrame - GameConfig.maxFrameDelta { haptics.play(events) }

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

    /// Real seconds one simulation step takes (longer during knockout slow motion).
    private var stepCost: Double {
        slowMotion > 0 ? GameConfig.fixedTimeStep / Self.slowMotionRate : GameConfig.fixedTimeStep
    }

    private func startTimeWarps(for events: [BattleEvent]) {
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
    }

    /// Online: lock this device's launch as its countdown runs out.
    private func lockLaunchIfDue() {
        if simulation.isWaitingForLaunchLock { lockLaunchNow() }
    }

    /// Online: fixes this device's launch direction now and tells the opponent. Also used when the app
    /// leaves the screen mid-countdown, so the opponent isn't kept waiting for it.
    func lockLaunchNow() {
        guard let onlineSlot, simulation.phase == .countdown, !simulation.lockedSlots.contains(onlineSlot) else { return }
        let angle = simulation.launchVelocities[onlineSlot.rawValue].angle
        simulation.lockLaunch(onlineSlot, angle: angle)
        onLaunchLocked?(angle)
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

#if DEBUG
extension BattleEngine {
    /// App Store screenshots: plays the fight (without its intro) up to `time` seconds and holds it there.
    func holdForStoreDemo(at time: Double) {
        isIntroPlaying = false
        let dt = GameConfig.fixedTimeStep
        for _ in 0..<Int(time / dt) {
            simulation.step(dt: dt)
            _ = simulation.drainEvents()
        }
        isHeldForStoreDemo = true
    }
}
#endif

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
