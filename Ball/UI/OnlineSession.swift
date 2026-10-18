import GameKit
import SwiftUI

/// What the two devices tell each other. Battles are deterministic (seeded, fixed timestep, no
/// inputs once the balls launch), so only setup choices, the seed and launch directions are sent;
/// each device then simulates the same fight on its own.
nonisolated enum OnlineMessage: Codable {
    /// Sent on connect; both sides must run the same rules or their fights would drift apart.
    case hello(version: Int, rules: UInt64, name: String)
    case setup(fighterID: String?, level: Int, trophies: Int, aimAngle: Double, isReady: Bool)
    /// Host → client: start a battle with this seed, in this arena (`ArenaMap` raw value).
    case start(seed: UInt64, arena: String)
    /// Live launch direction while dragging during the countdown.
    case launchAim(seed: UInt64, angle: Double)
    /// Final launch direction, sent when the sender's countdown runs out.
    case launchLock(seed: UInt64, angle: Double)
    /// Ranked: this player's battle team (3 ball ids at their levels) and trophies, sent on connect.
    case team(fighterIDs: [String], levels: [Int], trophies: Int)
    /// Ranked: who this player sends into the next round of the series.
    case roundPick(index: Int, aimAngle: Double)
    /// Client → host: please start a rematch.
    case rematch
    case changeFighters
}

/// Game Center sign-in, matchmaking and the connection to one opponent.
@Observable
final class OnlineSession: NSObject {
    enum AuthState: Equatable {
        case signedOut
        case signingIn
        case signedIn(name: String)
        case unavailable(String)
    }

    enum Status: Equatable {
        case idle
        /// `code` is the private room number, nil for quick match.
        case searching(code: Int?)
        /// Waiting for an invited friend to accept.
        case inviting(name: String)
        case connected
        case failed(String)
    }

    enum Event {
        case signedIn
        /// Sign-in failed or was declined; the game carries on without Game Center.
        case signInFailed
        case connected
        case message(OnlineMessage)
        case disconnected(String)
        case inviteAccepted
        /// Searched long enough without finding anyone (quick match or ranked).
        case noOpponentFound(ranked: Bool)
    }

    /// A Game Center friend who can be invited to a match.
    struct Friend: Identifiable {
        let id: String
        let name: String
        fileprivate let player: GKPlayer
    }

    enum FriendsState: Equatable {
        case notLoaded
        case loading
        case loaded
        /// The player hasn't allowed the game to see their friends list.
        case denied
        case failed(String)
    }

    static let protocolVersion = 8

    private(set) var auth: AuthState = .signedOut
    private(set) var status: Status = .idle
    /// The host (lower player ID) is slot one; the other device is slot two.
    private(set) var localSlot: PlayerSlot = .one
    private(set) var opponentName = "RIVAL"

    var remoteSlot: PlayerSlot { localSlot.opponent }
    var isHost: Bool { localSlot == .one }
    var isSignedIn: Bool { if case .signedIn = auth { return true }; return false }
    /// Searching for an opponent or waiting on an invited friend.
    var isLookingForMatch: Bool {
        switch status {
        case .searching, .inviting: return true
        default: return false
        }
    }

    private(set) var friends: [Friend] = []
    private(set) var friendsState: FriendsState = .notLoaded

    @ObservationIgnored var onEvent: ((Event) -> Void)?
    /// The name this player shows to opponents (their chosen name, else Game Center's).
    @ObservationIgnored var localName: () -> String = { GKLocalPlayer.local.displayName }
    @ObservationIgnored private var match: GKMatch?
    @ObservationIgnored private var listenerRegistered = false
    @ObservationIgnored private var greeted = false

    // MARK: Sign-in

    func authenticate() {
        guard auth == .signedOut || { if case .unavailable = auth { return true }; return false }() else { return }
        auth = .signingIn
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            Task { @MainActor in self?.handleAuthentication(viewController, error) }
        }
    }

    #if canImport(UIKit)
    private func handleAuthentication(_ viewController: UIViewController?, _ error: Error?) {
        if let viewController {
            present(viewController)
            return
        }
        finishAuthentication(error)
    }

    /// Shows Game Center's sign-in screen, waiting for the window if the app is still launching.
    private func present(_ viewController: UIViewController, attempt: Int = 0) {
        if let top = Self.topViewController() {
            top.present(viewController, animated: true)
        } else if attempt < 40 {
            Task {
                try? await Task.sleep(for: .seconds(0.25))
                present(viewController, attempt: attempt + 1)
            }
        }
    }

    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        var top = scenes.flatMap(\.windows).first(where: \.isKeyWindow)?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
    #else
    private func handleAuthentication(_ viewController: NSViewController?, _ error: Error?) {
        if let viewController {
            present(viewController)
            return
        }
        finishAuthentication(error)
    }

    /// Shows Game Center's sign-in sheet, waiting for the window if the app is still launching.
    private func present(_ viewController: NSViewController, attempt: Int = 0) {
        if let host = (NSApp.keyWindow ?? NSApp.windows.first)?.contentViewController {
            host.presentAsSheet(viewController)
        } else if attempt < 40 {
            Task {
                try? await Task.sleep(for: .seconds(0.25))
                present(viewController, attempt: attempt + 1)
            }
        }
    }
    #endif

    private func finishAuthentication(_ error: Error?) {
        let player = GKLocalPlayer.local
        if player.isAuthenticated {
            auth = .signedIn(name: player.displayName)
            onEvent?(.signedIn)
            if !listenerRegistered {
                player.register(self)
                listenerRegistered = true
            }
        } else {
            auth = .unavailable(Self.explain(error))
            authErrorDetail = error.map { "\(($0 as NSError).domain) \(($0 as NSError).code): \($0.localizedDescription)" }
            onEvent?(.signInFailed)
        }
    }

    /// The raw error from the last failed sign-in, shown small for troubleshooting.
    private(set) var authErrorDetail: String?

    /// What went wrong signing in, in plain words.
    private static func explain(_ error: Error?) -> String {
        guard let error = error as? GKError else {
            return String(localized: "You're not signed in to Game Center. Open Settings › Game Center and sign in, then come back.")
        }
        switch error.code {
        case .cancelled, .userDenied:
            return String(localized: "Game Center sign-in was closed. Open Settings › Game Center and sign in, then come back.")
        case .notAuthenticated, .notAuthorized:
            return String(localized: "You're not signed in to Game Center. Open Settings › Game Center and sign in, then come back.")
        case .gameUnrecognized:
            return String(localized: "Game Center doesn't recognise this app yet. Game Center must be enabled for it in App Store Connect.")
        case .notSupported, .apiNotAvailable:
            return String(localized: "Game Center isn't available on this device.")
        case .communicationsFailure, .connectionTimeout:
            return String(localized: "Couldn't reach Game Center. Check your internet connection and try again.")
        case .parentalControlsBlocked:
            return String(localized: "Game Center is blocked by Screen Time or parental controls on this device.")
        default:
            return String(localized: "Game Center sign-in failed. Check Settings › Game Center and try again.")
        }
    }

    // MARK: Leaderboard

    /// The trophy leaderboard in App Store Connect (most recent score, high to low).
    static let trophyLeaderboardID = "ballbrawl_trophies"

    /// Posts the player's current trophies. Quietly does nothing when not signed in.
    func submitTrophies(_ trophies: Int) {
        guard isSignedIn else { return }
        Task {
            try? await GKLeaderboard.submitScore(trophies, context: 0, player: GKLocalPlayer.local,
                                                 leaderboardIDs: [Self.trophyLeaderboardID])
        }
    }

    /// Opens Game Center's leaderboard view (signing in first if needed).
    func showLeaderboard() {
        guard isSignedIn else {
            authenticate()
            return
        }
        GKAccessPoint.shared.trigger(leaderboardID: Self.trophyLeaderboardID, playerScope: .global, timeScope: .allTime)
    }

    // MARK: Matchmaking

    /// Quick match with anyone, or a private room: players who enter the same code are matched together.
    /// Ranked players only meet other ranked players; quick match, rooms and invites are casual.
    private static let rankedPlayerGroup = 1_000_000

    /// Ranked search widens in steps, so players meet others near their trophies first.
    /// (Game Center only matches equal player groups, so each step is a wider group.)
    enum RankedStage {
        /// Only players in the same arena.
        case arena
        /// Players in the same pair of arenas (1–2, 3–4, 5–6).
        case nearby
        /// Any ranked player.
        case everyone
    }

    private static let stageDuration: Duration = .seconds(10)
    /// How long the last ranked stage, or a quick match, searches before giving up.
    private static let finalSearchDuration: Duration = .seconds(10)
    private static let quickMatchDuration: Duration = .seconds(20)

    /// Whether the current match (or search) is ranked, i.e. counts for trophies.
    private(set) var isRanked = false
    private(set) var rankedStage: RankedStage = .arena
    @ObservationIgnored private var rankedArena = 1
    /// Bumped by every new search; results of older (cancelled) searches are ignored.
    @ObservationIgnored private var searchID = 0

    /// Quick match, a private room, or (with `ranked`) a ranked match starting from the player's `arena`.
    /// When the current search began, and roughly how long it should take (nil when unknown, e.g. a room).
    private(set) var searchStartedAt: Date?
    private(set) var estimatedWait: TimeInterval?

    func findMatch(roomCode: Int? = nil, ranked: Bool = false, arena: Int = 1) {
        guard isSignedIn, match == nil else { return }
        isRanked = ranked && roomCode == nil
        status = .searching(code: roomCode)
        searchStartedAt = .now
        estimatedWait = nil
        if isRanked {
            rankedArena = arena
            startRankedStage(.arena)
            estimateWait(group: Self.rankedPlayerGroup + arena, limit: Self.rankedSearchLimit)
        } else {
            search(group: roomCode)
            // Quick match gives up after a while; rooms wait for the friend.
            if roomCode == nil {
                giveUp(after: Self.quickMatchDuration, ranked: false)
                estimateWait(group: 0, limit: Self.quickMatchDuration.seconds)
            }
        }
    }

    /// Longest a ranked search runs before a stand-in steps in (all stages).
    private static var rankedSearchLimit: TimeInterval { stageDuration.seconds * 2 + finalSearchDuration.seconds }

    /// Estimates the wait from how many players searched in this group recently: busy groups match fast.
    /// Never more than `limit`, since a stand-in opponent arrives by then.
    private func estimateWait(group: Int, limit: TimeInterval) {
        estimatedWait = limit
        let id = searchID
        Task {
            let recent = (try? await GKMatchmaker.shared().queryPlayerGroupActivity(group)) ?? 0
            guard id == searchID else { return }
            let guess: TimeInterval = recent >= 10 ? 5 : recent >= 3 ? 10 : recent >= 1 ? 18 : limit
            estimatedWait = min(limit, guess)
        }
    }

    /// If this search is still running after `delay`, cancel it and report that nobody was found.
    private func giveUp(after delay: Duration, ranked: Bool) {
        let id = searchID
        Task {
            try? await Task.sleep(for: delay)
            guard id == searchID, case .searching = status else { return }
            cancelSearch()
            onEvent?(.noOpponentFound(ranked: ranked))
        }
    }

    private func search(group: Int?) {
        searchID += 1
        let id = searchID
        let request = GKMatchRequest()
        request.minPlayers = 2
        request.maxPlayers = 2
        if let group { request.playerGroup = group }
        Task {
            do {
                let found = try await GKMatchmaker.shared().findMatch(for: request)
                guard id == searchID else { found.disconnect(); return }
                attach(found)
            } catch {
                if id == searchID, isLookingForMatch { status = .failed(error.localizedDescription) }
            }
        }
    }

    private func startRankedStage(_ stage: RankedStage) {
        rankedStage = stage
        let base = Self.rankedPlayerGroup
        switch stage {
        case .arena: search(group: base + rankedArena)
        case .nearby: search(group: base + 100 + (rankedArena + 1) / 2)
        case .everyone: search(group: base)
        }
        guard stage != .everyone else {
            giveUp(after: Self.finalSearchDuration, ranked: true)
            return
        }
        let id = searchID
        Task {
            try? await Task.sleep(for: Self.stageDuration)
            guard id == searchID, isRanked, case .searching = status else { return }
            // No one close enough yet: cancel and look a little wider.
            GKMatchmaker.shared().cancel()
            startRankedStage(stage == .arena ? .nearby : .everyone)
        }
    }

    func cancelSearch() {
        searchID += 1
        searchStartedAt = nil
        estimatedWait = nil
        GKMatchmaker.shared().cancel()
        if isLookingForMatch { status = .idle }
    }

    // MARK: Friends

    /// Loads the player's Game Center friends (asks for permission the first time).
    func loadFriends() {
        guard isSignedIn, friendsState != .loading else { return }
        friendsState = .loading
        Task {
            do {
                let players = try await GKLocalPlayer.local.loadFriends()
                friends = players
                    .map { Friend(id: $0.gamePlayerID, name: $0.displayName, player: $0) }
                    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                friendsState = .loaded
            } catch {
                let access = try? await GKLocalPlayer.local.loadFriendsAuthorizationStatus()
                friendsState = access == .denied || access == .restricted ? .denied : .failed(error.localizedDescription)
            }
        }
    }

    /// Sends a Game Center invite; the match starts when the friend accepts.
    func invite(_ friend: Friend) {
        guard isSignedIn, match == nil, !isLookingForMatch else { return }
        let name = friend.name
        isRanked = false
        status = .inviting(name: name)
        let request = GKMatchRequest()
        request.minPlayers = 2
        request.maxPlayers = 2
        request.recipients = [friend.player]
        request.inviteMessage = String(localized: "Let's brawl!")
        request.recipientResponseHandler = { [weak self] _, response in
            Task { @MainActor in self?.inviteAnswered(response, name: name) }
        }
        Task {
            do {
                attach(try await GKMatchmaker.shared().findMatch(for: request))
            } catch {
                if isLookingForMatch { status = .failed(error.localizedDescription) }
            }
        }
    }

    private func inviteAnswered(_ response: GKInviteRecipientResponse, name: String) {
        guard case .inviting = status, response != .accepted else { return }
        GKMatchmaker.shared().cancel()
        switch response {
        case .declined: status = .failed(String(localized: "\(name) declined your invite."))
        case .noAnswer: status = .failed(String(localized: "\(name) didn't answer in time."))
        case .incompatible: status = .failed(String(localized: "\(name) has a different version of the game."))
        default: status = .failed(String(localized: "Couldn't reach \(name)."))
        }
    }

    /// Opens Apple's screen for sending a Game Center friend request.
    func presentAddFriend() {
        #if canImport(UIKit)
        guard let viewController = Self.topViewController() else { return }
        try? GKLocalPlayer.local.presentFriendRequestCreator(from: viewController)
        #else
        guard let window = NSApp.keyWindow else { return }
        try? GKLocalPlayer.local.presentFriendRequestCreator(from: window)
        #endif
    }

    /// Leaves the current match (or search) and forgets the opponent.
    func leave() {
        cancelSearch()
        match?.delegate = nil
        match?.disconnect()
        match = nil
        status = .idle
    }

    private func attach(_ newMatch: GKMatch) {
        guard isLookingForMatch else {
            newMatch.disconnect()
            return
        }
        match = newMatch
        greeted = false
        newMatch.delegate = self
        if newMatch.expectedPlayerCount == 0, let remote = newMatch.players.first {
            greet(remote)
        }
    }

    private func greet(_ remote: GKPlayer) {
        guard !greeted else { return }
        greeted = true
        localSlot = GKLocalPlayer.local.gamePlayerID < remote.gamePlayerID ? .one : .two
        opponentName = String(remote.displayName.prefix(16))
        send(.hello(version: Self.protocolVersion, rules: Self.rulesFingerprint, name: localName()))
    }

    // MARK: Messages

    func send(_ message: OnlineMessage, reliable: Bool = true) {
        guard let match, let data = try? JSONEncoder().encode(message) else { return }
        try? match.sendData(toAllPlayers: data, with: reliable ? .reliable : .unreliable)
    }

    private func receive(_ message: OnlineMessage) {
        if case .hello(let version, let rules, let name) = message {
            guard version == Self.protocolVersion, rules == Self.rulesFingerprint else {
                drop(String(localized: "Your opponent has a different version of the game. Both players need the latest update."))
                return
            }
            let chosen = PlayerNames.sanitized(name)
            if let remote = match?.players.first { greet(remote) }
            if let chosen { opponentName = chosen }
            guard status != .connected else { return }
            if let remote = match?.players.first { greet(remote) }
            guard greeted else { return }
            status = .connected
            onEvent?(.connected)
            return
        }
        guard status == .connected else { return }
        onEvent?(.message(message))
    }

    private func drop(_ reason: String) {
        leave()
        status = .failed(reason)
        onEvent?(.disconnected(reason))
    }

    /// Hash of every balance value (every ball at every level); two devices only match if their fights
    /// would play out identically.
    private static let rulesFingerprint: UInt64 = {
        let levels = (1...Progression.maxLevel).flatMap { level in FighterCatalog.all.map { Progression.leveled($0, level: level) } }
        let text = String(describing: levels) + String(describing: GameConfig.physics)
            + String(describing: GameConfig.overtime)
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return hash
    }()
}

// MARK: - GameKit callbacks

extension OnlineSession: GKMatchDelegate {
    nonisolated func match(_ match: GKMatch, didReceive data: Data, fromRemotePlayer player: GKPlayer) {
        guard let message = try? JSONDecoder().decode(OnlineMessage.self, from: data) else { return }
        Task { @MainActor in
            guard match === self.match else { return }
            self.receive(message)
        }
    }

    nonisolated func match(_ match: GKMatch, player: GKPlayer, didChange state: GKPlayerConnectionState) {
        Task { @MainActor in
            guard match === self.match else { return }
            switch state {
            case .connected:
                if match.expectedPlayerCount == 0 { self.greet(player) }
            case .disconnected:
                self.drop(String(localized: "Your opponent left the match."))
            default:
                break
            }
        }
    }

    nonisolated func match(_ match: GKMatch, didFailWithError error: Error?) {
        let reason = error?.localizedDescription ?? String(localized: "The connection was lost.")
        Task { @MainActor in
            guard match === self.match else { return }
            self.drop(reason)
        }
    }
}

extension OnlineSession: GKLocalPlayerListener {
    /// Accepting a Game Center invite (from Messages or the Game Center app) joins that match.
    nonisolated func player(_ player: GKPlayer, didAccept invite: GKInvite) {
        Task { @MainActor in
            self.leave()
            self.isRanked = false
            self.status = .searching(code: nil)
            self.onEvent?(.inviteAccepted)
            do {
                self.attach(try await GKMatchmaker.shared().match(for: invite))
            } catch {
                self.status = .failed(error.localizedDescription)
            }
        }
    }
}

private extension Duration {
    /// The duration in seconds.
    var seconds: TimeInterval { Double(components.seconds) + Double(components.attoseconds) / 1e18 }
}
