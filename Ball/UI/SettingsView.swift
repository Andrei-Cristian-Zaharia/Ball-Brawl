import SwiftUI

/// Sound and vibration preferences, kept on this device.
@Observable
final class GameSettings {
    static let shared = GameSettings()

    var soundEffects: Bool { didSet { defaults.set(soundEffects, forKey: Keys.soundEffects) } }
    var music: Bool { didSet { defaults.set(music, forKey: Keys.music) } }
    /// 0...1 for sound effects and music.
    var volume: Double { didSet { defaults.set(volume, forKey: Keys.volume) } }
    var vibration: Bool { didSet { defaults.set(vibration, forKey: Keys.vibration) } }

    /// The game's languages (codes match the .lproj folders), with each one's own name.
    static let languages: [(code: String, name: String)] = [
        ("en", "English"), ("es", "Español"), ("pt-BR", "Português"), ("de", "Deutsch"), ("fr", "Français"), ("ro", "Română"),
        ("ja", "日本語"), ("zh-Hans", "简体中文"), ("ko", "한국어"),
    ]

    /// The language picked in Settings, or nil to follow the device. Saved as the app's own language
    /// preference (the same one iOS's per-app language setting uses), so it applies from the next launch.
    var language: String? {
        didSet {
            defaults.set(language, forKey: Keys.language)
            if let language { defaults.set([language], forKey: "AppleLanguages") } else { defaults.removeObject(forKey: "AppleLanguages") }
        }
    }

    /// The language the game is showing right now (fixed for this launch).
    let activeLanguage = Bundle.main.preferredLocalizations.first ?? "en"

    /// Read from anywhere (the battle's haptics run off the main view tree).
    nonisolated static var vibrationEnabled: Bool {
        UserDefaults.standard.object(forKey: Keys.vibration) as? Bool ?? true
    }

    private nonisolated enum Keys {
        static let soundEffects = "settings.soundEffects"
        static let music = "settings.music"
        static let volume = "settings.volume"
        static let vibration = "settings.vibration"
        static let language = "settings.language"
    }

    private let defaults = UserDefaults.standard

    private init() {
        soundEffects = defaults.object(forKey: Keys.soundEffects) as? Bool ?? true
        music = defaults.object(forKey: Keys.music) as? Bool ?? true
        volume = defaults.object(forKey: Keys.volume) as? Double ?? 0.8
        vibration = defaults.object(forKey: Keys.vibration) as? Bool ?? true
        language = defaults.string(forKey: Keys.language)
    }
}

/// Settings: sounds, about, and resetting progress.
struct SettingsView: View {
    let model: AppModel
    @State private var confirmingReset = false
    @State private var voucherCode = ""
    @State private var redeeming = false
    @State private var voucherResult: VoucherService.Outcome?

    private var settings: GameSettings { model.settings }

    var body: some View {
        @Bindable var settings = settings
        ScrollView {
            VStack(spacing: 18) {
                HStack {
                    BackButton(title: "Menu", action: model.showMenu)
                    Spacer()
                }

                ScreenTitle("SETTINGS")

                section("LANGUAGE", icon: "globe") {
                    VStack(spacing: 8) {
                        HStack(spacing: 12) {
                            rowIcon("character.bubble.fill")
                            Text("Language")
                                .font(Theme.bodyFont(15, weight: .black))
                                .foregroundStyle(Theme.ink)
                            Spacer()
                            Picker("Language", selection: $settings.language) {
                                Text("System").tag(String?.none)
                                ForEach(GameSettings.languages, id: \.code) { language in
                                    Text(verbatim: language.name).tag(Optional(language.code))
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(Theme.ink)
                        }
                        if (settings.language ?? Self.deviceLanguage) != settings.activeLanguage {
                            Text("The new language will be used the next time you open the game.")
                                .font(Theme.bodyFont(12, weight: .heavy))
                                .foregroundStyle(Theme.go)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .cartoonCard(fill: Theme.cream, cornerRadius: 18, shadow: 4, lineWidth: 3)
                }

                section("SOUNDS", icon: "speaker.wave.2.fill") {
                    VStack(spacing: 0) {
                        toggleRow("Sound Effects", icon: "speaker.wave.2.fill", isOn: $settings.soundEffects)
                        divider
                        toggleRow("Music", icon: "music.note", isOn: $settings.music)
                        divider
                        HStack(spacing: 12) {
                            rowIcon("speaker.fill")
                            Text("Volume")
                                .font(Theme.bodyFont(15, weight: .black))
                                .foregroundStyle(Theme.ink)
                            Slider(value: $settings.volume, in: 0...1)
                                .tint(Theme.go)
                            Text("\(Int((settings.volume * 100).rounded()))%")
                                .font(Theme.bodyFont(13, weight: .black).monospacedDigit())
                                .foregroundStyle(Theme.textSecondary)
                                .frame(width: 40, alignment: .trailing)
                        }
                        .padding(.vertical, 10)
                        .disabled(!settings.soundEffects && !settings.music)
                        .opacity(settings.soundEffects || settings.music ? 1 : 0.45)
                        divider
                        toggleRow("Vibration", icon: "iphone.radiowaves.left.and.right", isOn: $settings.vibration)
                    }
                    .padding(.horizontal, 14)
                    .cartoonCard(fill: Theme.cream, cornerRadius: 18, shadow: 4, lineWidth: 3)
                }

                section("REDEEM CODE", icon: "ticket.fill") {
                    VStack(spacing: 10) {
                        HStack(spacing: 10) {
                            TextField(text: $voucherCode, prompt: Text("Enter code").foregroundStyle(Theme.ink.opacity(0.4))) { Text("Enter code") }
                                .font(Theme.bodyFont(16, weight: .black).monospaced())
                                .foregroundStyle(Theme.ink)
                                .autocorrectionDisabled()
                                #if os(iOS)
                                .textInputAutocapitalization(.characters)
                                #endif
                                .submitLabel(.go)
                                .onSubmit(redeem)
                                .padding(.horizontal, 12).padding(.vertical, 10)
                                .background(RoundedRectangle(cornerRadius: 12).fill(.white))
                                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.ink, lineWidth: 2))
                            Button(action: redeem) {
                                if redeeming {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Redeem")
                                }
                            }
                            .buttonStyle(CartoonButtonStyle(fill: Theme.go, foreground: .white, fontSize: 15))
                            .frame(width: 104)
                            .disabled(redeeming || VoucherService.normalize(voucherCode).isEmpty)
                        }
                        if let voucherResult {
                            voucherMessage(voucherResult)
                        }
                    }
                    .padding(14)
                    .cartoonCard(fill: Theme.cream, cornerRadius: 18, shadow: 4, lineWidth: 3)
                }

                section("ABOUT", icon: "info.circle.fill") {
                    VStack(spacing: 10) {
                        HStack(spacing: 8) {
                            OutlinedText("BALL", size: 28, fill: .white, outline: 2.5).fixedSize()
                            OutlinedText("BRAWL", size: 28, fill: Theme.yellow, outline: 2.5).fixedSize()
                        }
                        Text("Pick your balls, aim the launch and watch them brawl. Climb the arenas, beat the daily Crusade and battle friends online.")
                            .font(Theme.bodyFont(13, weight: .heavy))
                            .foregroundStyle(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                        VStack(spacing: 0) {
                            infoRow("Version", value: Self.version)
                            divider
                            infoRow("Player", value: model.playerDisplayName)
                            divider
                            infoRow("Level", value: "\(model.profile.playerLevel)")
                            if let url = Self.privacyPolicyURL {
                                divider
                                Link(destination: url) { linkRow("Privacy Policy", icon: "hand.raised.fill") }
                            }
                            if model.ads.hasPrivacyOptions {
                                divider
                                Button(action: model.ads.showPrivacyOptions) { linkRow("Ad Privacy Choices", icon: "slider.horizontal.3") }
                                    .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(14)
                    .cartoonCard(fill: Theme.cream, cornerRadius: 18, shadow: 4, lineWidth: 3)
                }

                section("PROGRESS", icon: "arrow.counterclockwise") {
                    VStack(spacing: 10) {
                        Text("Start over as a new player: balls, levels, cards, coins, chests, trophies and Crusade stars are all wiped, here and in iCloud. Your name and purchases stay.")
                            .font(Theme.bodyFont(12, weight: .heavy))
                            .foregroundStyle(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                        Button("Reset Progress") { confirmingReset = true }
                            .buttonStyle(CartoonButtonStyle(fill: Theme.blood, foreground: .white, fontSize: 18))
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity)
                    .cartoonCard(fill: Theme.cream, cornerRadius: 18, shadow: 4, lineWidth: 3)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .alert("Reset all progress?", isPresented: $confirmingReset) {
            Button("Reset", role: .destructive, action: model.resetProgress)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This can't be undone. You'll start again from level 1 in the first arena.")
        }
    }

    private func redeem() {
        let code = voucherCode
        guard !redeeming, !VoucherService.normalize(code).isEmpty else { return }
        redeeming = true
        voucherResult = nil
        Task {
            let outcome = await model.redeemVoucher(code)
            redeeming = false
            withAnimation(.spring(duration: 0.3)) { voucherResult = outcome }
            if case .redeemed = outcome { voucherCode = "" }
        }
    }

    @ViewBuilder private func voucherMessage(_ outcome: VoucherService.Outcome) -> some View {
        switch outcome {
        case .redeemed(let rewards):
            VStack(spacing: 6) {
                Text("Code redeemed!")
                    .font(Theme.bodyFont(14, weight: .black))
                    .foregroundStyle(Theme.go)
                RewardsLine(rewards: rewards)
            }
        case .alreadyUsed: voucherNote("You've already used this code.")
        case .notFound: voucherNote("That code doesn't exist. Check it and try again.")
        case .expired: voucherNote("This code has expired.")
        case .empty: voucherNote("This code has no rewards.")
        case .usedUp: voucherNote("This code has been used up.")
        case .needsICloud: voucherNote("Sign in to iCloud in Settings to redeem this code.")
        case .unavailable: voucherNote("Couldn't check the code. Make sure you're online and try again.")
        }
    }

    private func voucherNote(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(Theme.bodyFont(13, weight: .heavy))
            .foregroundStyle(Theme.blood)
            .multilineTextAlignment(.center)
    }

    /// The device's own choice among the game's languages.
    private static var deviceLanguage: String {
        Bundle.preferredLocalizations(from: GameSettings.languages.map(\.code), forPreferences: Locale.preferredLanguages).first ?? "en"
    }

    /// The hosted privacy policy (also entered in App Store Connect). The row is hidden until it's set.
    static let privacyPolicyURL: URL? = nil

    private static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    private func section<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title.localized, systemImage: icon)
                .font(Theme.bodyFont(14, weight: .black))
                .foregroundStyle(.white)
                .shadow(color: Theme.ink.opacity(0.6), radius: 0, x: 0, y: 1.5)
            content()
        }
    }

    private var divider: some View {
        Rectangle().fill(Theme.ink.opacity(0.12)).frame(height: 1.5)
    }

    private func rowIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(RoundedRectangle(cornerRadius: 9).fill(Theme.background))
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Theme.ink, lineWidth: 2))
    }

    private func toggleRow(_ title: String, icon: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 12) {
                rowIcon(icon)
                Text(title.localized)
                    .font(Theme.bodyFont(15, weight: .black))
                    .foregroundStyle(Theme.ink)
            }
        }
        .tint(Theme.go)
        .padding(.vertical, 10)
    }

    private func linkRow(_ title: String, icon: String) -> some View {
        HStack {
            Text(title.localized)
                .font(Theme.bodyFont(14, weight: .black))
                .foregroundStyle(Theme.ink)
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.vertical, 9)
        .contentShape(Rectangle())
    }

    private func infoRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title.localized)
                .font(Theme.bodyFont(14, weight: .black))
                .foregroundStyle(Theme.ink)
            Spacer()
            Text(value)
                .font(Theme.bodyFont(14, weight: .heavy))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
        }
        .padding(.vertical, 9)
    }
}
