import StoreKit
import SwiftUI

/// In-app purchases with StoreKit 2: loads the shop's products, buys them, and delivers each verified
/// transaction to the profile exactly once (including ones that finish later, e.g. after Ask to Buy).
@Observable
final class StoreService {
    private(set) var products: [String: Product] = [:]
    /// Product being bought right now (for spinners).
    private(set) var purchasing: String?
    private(set) var loadFailed = false

    /// Called with what a purchase granted, for a celebration.
    @ObservationIgnored var onDelivered: ((Shop.Offer) -> Void)?

    @ObservationIgnored private let profile: ProfileStore
    @ObservationIgnored private var updates: Task<Void, Never>?

    init(profile: ProfileStore) {
        self.profile = profile
        updates = Task { [weak self] in
            for await result in StoreKit.Transaction.updates {
                await self?.handle(result)
            }
        }
        Task { [weak self] in
            await self?.loadProducts()
            await self?.restoreOwned()
        }
    }

    func product(for offer: Shop.Offer) -> Product? { products[offer.productID] }

    func loadProducts() async {
        do {
            let loaded = try await Product.products(for: Shop.allOffers.map(\.productID))
            products = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0) })
            loadFailed = loaded.isEmpty
        } catch {
            loadFailed = true
        }
    }

    /// Buys with SwiftUI's purchase action (from the view's environment), which shows the payment sheet
    /// in the right window on every platform.
    func buy(_ offer: Shop.Offer, using purchase: PurchaseAction) async {
        guard purchasing == nil, let product = product(for: offer) else { return }
        purchasing = offer.productID
        defer { purchasing = nil }
        do {
            if case .success(let verification) = try await purchase(product) {
                await handle(verification)
            }
            // .pending (Ask to Buy) arrives later through `Transaction.updates`; .userCancelled needs nothing.
        } catch {
            // Purchase failed (network, store unavailable); the button simply stays available.
        }
    }

    /// Re-syncs with the App Store, e.g. on a new device.
    func restorePurchases() async {
        try? await AppStore.sync()
        await restoreOwned()
    }

    private func handle(_ result: VerificationResult<StoreKit.Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        if transaction.revocationDate == nil,
           profile.deliverPurchase(productID: transaction.productID, transactionID: String(transaction.id)) != nil,
           let offer = Shop.offer(for: transaction.productID) {
            onDelivered?(offer)
        }
        await transaction.finish()
    }

    /// The starter pack is bought once; mark it owned if the App Store says so (without granting it twice).
    private func restoreOwned() async {
        for await result in StoreKit.Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.productID == Shop.starterPack.productID,
               transaction.revocationDate == nil {
                profile.restoreStarterPack()
            }
        }
    }
}
