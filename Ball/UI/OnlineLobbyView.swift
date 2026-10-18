import SwiftUI

/// Game Center sign-in and matchmaking: quick match with anyone, or a private room code for friends.
struct OnlineLobbyView: View {
    let model: AppModel
    @State private var roomCode = ""

    private var online: OnlineSession { model.online }
    private var code: Int? { Int(roomCode).flatMap { (1...9999).contains($0) ? $0 : nil } }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                HStack {
                    BackButton(title: "Menu", action: model.showMenu)
                    Spacer()
                }

                VStack(spacing: 6) {
                    ScreenTitle("ONLINE")
                }

                if let notice = model.onlineNotice {
                    noticeCard(notice)
                }

                VStack(spacing: 16) { content }
                    .padding(18)
                    .frame(maxWidth: 420)
                    .cartoonCard(fill: Theme.cream, cornerRadius: 24, shadow: 7, lineWidth: 4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .animation(.spring(duration: 0.3, bounce: 0.35), value: online.status)
        .animation(.spring(duration: 0.3, bounce: 0.35), value: online.auth)
    }

    @ViewBuilder private var content: some View {
        switch online.auth {
        case .signedOut, .signingIn:
            ProgressView().controlSize(.large).tint(Theme.ink)
            caption("Signing in to Game Center…")
        case .unavailable(let reason):
            Image(systemName: "gamecontroller.fill").font(.system(size: 40, weight: .black)).foregroundStyle(Theme.ink)
            caption(reason)
            Button("Try Again", action: online.authenticate)
                .buttonStyle(CartoonButtonStyle(fill: Theme.yellow))
        case .signedIn:
            switch online.status {
            case .searching(let code):
                ProgressView().controlSize(.large).tint(Theme.ink)
                caption(code.map { String(localized: "Waiting in room \(String(format: "%04d", $0)) for your friend…") }
                        ?? (online.isRanked ? rankedSearchText : String(localized: "Looking for an opponent…")))
                searchTimer
                Button("Cancel", action: online.cancelSearch)
                    .buttonStyle(CartoonButtonStyle(fill: .white))
            case .inviting(let name):
                ProgressView().controlSize(.large).tint(Theme.ink)
                caption(String(localized: "Invite sent to \(name). Waiting for them to accept…"))
                Button("Cancel", action: online.cancelSearch)
                    .buttonStyle(CartoonButtonStyle(fill: .white))
            case .connected:
                ProgressView().controlSize(.large).tint(Theme.ink)
                caption("Connected! Getting ready…")
            case .idle, .failed:
                if case .failed(let reason) = online.status, model.onlineNotice != reason {
                    caption(reason)
                }
                matchButtons
                friendsSection
            }
        }
    }

    @ViewBuilder private var matchButtons: some View {
        Button(action: model.playRanked) {
            VStack(spacing: 2) {
                Label("RANKED BATTLE", systemImage: "trophy.fill")
                Text("Win or lose trophies").font(Theme.bodyFont(12, weight: .heavy))
            }
        }
        .buttonStyle(CartoonButtonStyle(fill: Theme.yellow, fontSize: 22, cornerRadius: 20))

        Button {
            model.findOnlineMatch()
        } label: {
            VStack(spacing: 2) {
                Label("QUICK MATCH", systemImage: "bolt.fill")
                Text("Casual · no rewards").font(Theme.bodyFont(12, weight: .heavy))
            }
        }
        .buttonStyle(CartoonButtonStyle(fill: .white, fontSize: 18, cornerRadius: 20))

        VStack(spacing: 10) {
            Text("PLAY A FRIEND")
                .font(Theme.bodyFont(12, weight: .black))
                .foregroundStyle(Theme.ink.opacity(0.7))
            caption("Both enter the same 4-digit room code.")
            HStack(spacing: 10) {
                TextField("0000", text: $roomCode)
                    .font(.system(size: 26, weight: .black, design: .rounded).monospacedDigit())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.ink)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                    .padding(.vertical, 8)
                    .cartoonCard(fill: .white, cornerRadius: 14, shadow: 0, lineWidth: 3)
                    .frame(maxWidth: 130)
                    .onChange(of: roomCode) { _, value in
                        let digits = String(value.filter(\.isNumber).prefix(4))
                        if digits != value { roomCode = digits }
                    }
                Button("JOIN") {
                    if let code { model.findOnlineMatch(roomCode: code) }
                }
                .buttonStyle(CartoonButtonStyle(fill: PlayerSlot.one.color, foreground: .white))
                .disabled(code == nil)
            }
        }
        .padding(.top, 6)
    }

    // MARK: Friends

    @ViewBuilder private var friendsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("FRIENDS")
                    .font(Theme.bodyFont(12, weight: .black))
                    .foregroundStyle(Theme.ink.opacity(0.7))
                Spacer()
                Button(action: online.presentAddFriend) {
                    Label("Add", systemImage: "person.badge.plus")
                        .font(Theme.bodyFont(13, weight: .black))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Capsule().fill(.white))
                        .overlay(Capsule().strokeBorder(Theme.ink, lineWidth: 2))
                }
                .buttonStyle(.plain)
            }
            switch online.friendsState {
            case .notLoaded, .loading:
                HStack(spacing: 8) {
                    ProgressView().tint(Theme.ink)
                    caption("Loading your Game Center friends…")
                }
                .frame(maxWidth: .infinity)
            case .denied:
                caption("Allow Ball Brawl to see your friends in Settings › Game Center to invite them here.")
            case .failed(let reason):
                caption(reason)
                Button("Try Again", action: online.loadFriends)
                    .buttonStyle(CartoonButtonStyle(fill: .white, fontSize: 15))
            case .loaded where online.friends.isEmpty:
                caption("No Game Center friends yet. Tap Add to send a friend request, or share a room code.")
            case .loaded:
                VStack(spacing: 8) {
                    ForEach(online.friends) { friend in
                        friendRow(friend)
                    }
                }
            }
        }
        .padding(.top, 8)
        .onAppear(perform: online.loadFriends)
    }

    private func friendRow(_ friend: OnlineSession.Friend) -> some View {
        HStack(spacing: 10) {
            Text(String(friend.name.prefix(1)).uppercased())
                .font(Theme.titleFont(18))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(Circle().fill(avatarColor(friend.id)))
                .overlay(Circle().strokeBorder(Theme.ink, lineWidth: 2.5))
            Text(friend.name)
                .font(Theme.bodyFont(15, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
            Spacer(minLength: 0)
            Button {
                model.inviteFriend(friend)
            } label: {
                Label("Invite", systemImage: "paperplane.fill")
                    .font(Theme.bodyFont(13, weight: .black))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Capsule().fill(PlayerSlot.one.color))
                    .overlay(Capsule().strokeBorder(Theme.ink, lineWidth: 2))
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .cartoonCard(fill: .white, cornerRadius: 14, shadow: 3, lineWidth: 2.5)
    }

    /// A stable color per friend for their initial badge.
    private func avatarColor(_ id: String) -> Color {
        let palette = [PlayerSlot.one.color, PlayerSlot.two.color, Theme.overtime, Rarity.epic.color, Color(red: 0.22, green: 0.66, blue: 0.38)]
        let hash = id.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
        return palette[hash % palette.count]
    }

    /// Time searched so far and the estimated wait, ticking every second.
    @ViewBuilder private var searchTimer: some View {
        if let started = online.searchStartedAt {
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                let elapsed = max(0, timeline.date.timeIntervalSince(started))
                HStack(spacing: 10) {
                    Label(Self.clock(elapsed), systemImage: "hourglass")
                        .foregroundStyle(Theme.ink)
                    if let estimate = online.estimatedWait {
                        Text(elapsed < estimate ? String(localized: "Estimated \(Self.clock(estimate))") : String(localized: "Almost there…"))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .font(Theme.bodyFont(14, weight: .black))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Capsule().fill(.white))
                .overlay(Capsule().strokeBorder(Theme.ink, lineWidth: 2))
            }
        }
    }

    private static func clock(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.down))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// What the widening ranked search is doing right now.
    private var rankedSearchText: String {
        switch online.rankedStage {
        case .arena: return String(localized: "Finding a ranked opponent in \(model.profile.arena.name.localized)…")
        case .nearby: return String(localized: "Widening the search to nearby arenas…")
        case .everyone: return String(localized: "Searching all ranked players…")
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text.localized)
            .font(Theme.bodyFont(14, weight: .heavy))
            .foregroundStyle(Theme.ink)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func noticeCard(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
        .font(Theme.bodyFont(14, weight: .heavy))
        .foregroundStyle(Theme.ink)
        .padding(12)
        .frame(maxWidth: 420)
        .cartoonCard(fill: Theme.yellow, cornerRadius: 16, shadow: 4, lineWidth: 3)
    }
}
