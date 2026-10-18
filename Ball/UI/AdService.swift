import SwiftUI
#if os(iOS) && canImport(GoogleMobileAds)
import AppTrackingTransparency
import GoogleMobileAds
import UserMessagingPlatform
#endif

/// Rewarded video ads (Google AdMob). Players choose to watch one for a reward; nothing is forced.
/// AdMob only runs on iOS, so on Mac and Vision Pro `isAvailable` is false and ad offers are hidden.
///
/// Before any ad loads, Google's consent form is shown where the law asks for it (EU, UK, ...), then
/// Apple's tracking prompt. Ads start only once consent allows them; without tracking they're non-personalized.
@Observable
final class AdService: NSObject {
    /// The "Reward" rewarded unit in AdMob. Debug builds use Google's sample unit instead, which always
    /// serves test ads, so testing never touches real ads (tapping your own live ads breaks AdMob policy).
    #if DEBUG
    static let rewardedUnitID = "ca-app-pub-3940256099942544/1712485313"
    #else
    static let rewardedUnitID = "ca-app-pub-8505602361918016/5232668386"
    #endif

    private(set) var isReady = false
    private(set) var isShowing = false
    /// The player's region lets them change their ad consent later (Settings › Ad Privacy Choices).
    private(set) var hasPrivacyOptions = false

    #if os(iOS) && canImport(GoogleMobileAds)
    var isAvailable: Bool { true }
    @ObservationIgnored private var rewardedAd: RewardedAd?
    @ObservationIgnored private var earned = false
    @ObservationIgnored private var finished: CheckedContinuation<Bool, Never>?
    @ObservationIgnored private var started = false

    @ObservationIgnored private var adsStarted = false

    func start() {
        guard !started else { return }
        started = true
        Task { await gatherConsent() }
    }

    /// Consent first (Google's form, only where required), then Apple's tracking prompt, then ads.
    private func gatherConsent() async {
        let consent = ConsentInformation.shared
        // Consent given in an earlier session still counts while the update runs.
        if consent.canRequestAds { startAds() }
        do {
            try await consent.requestConsentInfoUpdate(with: RequestParameters())
            let root = await Self.waitForActiveWindow()
            try await ConsentForm.loadAndPresentIfRequired(from: root)
        } catch {
            // Offline or a config problem: carry on with whatever consent there already is.
        }
        hasPrivacyOptions = consent.privacyOptionsRequirementStatus == .required
        if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
            _ = await Self.waitForActiveWindow()
            _ = await ATTrackingManager.requestTrackingAuthorization()
        }
        if consent.canRequestAds { startAds() }
    }

    private func startAds() {
        guard !adsStarted else { return }
        adsStarted = true
        MobileAds.shared.start(completionHandler: nil)
        Task { await load() }
    }

    /// Lets the player review or change their ad consent (shown in Settings when their region requires it).
    func showPrivacyOptions() {
        guard let root = Self.topViewController() else { return }
        Task {
            try? await ConsentForm.presentPrivacyOptionsForm(from: root)
            if ConsentInformation.shared.canRequestAds { startAds() }
        }
    }

    /// The top view controller once the app is in the foreground (prompts are ignored before that).
    private static func waitForActiveWindow() async -> UIViewController {
        while true {
            if UIApplication.shared.applicationState == .active, let top = topViewController() { return top }
            try? await Task.sleep(for: .seconds(0.3))
        }
    }

    private func load() async {
        guard rewardedAd == nil else { return }
        do {
            let ad = try await RewardedAd.load(with: Self.rewardedUnitID, request: Request())
            ad.fullScreenContentDelegate = self
            rewardedAd = ad
            isReady = true
        } catch {
            isReady = false
            // Try again a bit later (no fill, offline, ...).
            try? await Task.sleep(for: .seconds(30))
            await load()
        }
    }

    /// Shows a rewarded ad. Returns true only if the player watched long enough to earn the reward.
    func showRewarded() async -> Bool {
        guard let ad = rewardedAd, let root = Self.topViewController() else { return false }
        rewardedAd = nil
        isReady = false
        isShowing = true
        earned = false
        let result = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            finished = continuation
            ad.present(from: root) { [weak self] in self?.earned = true }
        }
        isShowing = false
        Task { await load() }
        return result
    }

    private func finish() {
        finished?.resume(returning: earned)
        finished = nil
    }

    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        var top = scenes.flatMap(\.windows).first(where: \.isKeyWindow)?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
    #else
    var isAvailable: Bool { false }
    func start() {}
    func showPrivacyOptions() {}
    func showRewarded() async -> Bool { false }
    #endif
}

#if os(iOS) && canImport(GoogleMobileAds)
extension AdService: FullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        finish()
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        finish()
    }
}
#endif
