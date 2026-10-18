import StoreKit
import SwiftUI

/// The shop: free rewards for watching ads, a one-time starter pack, chest bundles and coin packs.
struct ShopView: View {
    let model: AppModel
    @Environment(\.purchase) private var purchase

    private var profile: ProfileStore { model.profile }
    private var store: StoreService { model.store }
    private var ads: AdService { model.ads }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                HStack {
                    BackButton(title: "Menu", action: model.showMenu)
                    Spacer()
                    WalletBar(model: model)
                }

                ScreenTitle("SHOP")

                if ads.isAvailable {
                    section("FREE REWARDS", icon: "play.rectangle.fill") {
                        HStack(spacing: 12) {
                            adCard(.coins, title: String(localized: "+\(Shop.AdReward.coins.contents.coins) Coins"), art: AnyView(CoinLabel(amount: 60, size: 20)))
                            adCard(.chest, title: "Free Chest", art: AnyView(ChestIcon(kind: Shop.AdReward.chest.contents.chests.first ?? .silver, size: 48)))
                        }
                    }
                }

                if !profile.ownsStarterPack {
                    starterPackCard
                }

                section("CHESTS", icon: "shippingbox.fill") {
                    HStack(spacing: 12) {
                        ForEach(Shop.chestOffers, id: \.productID) { offer in
                            offerCard(offer, art: AnyView(chestStack(offer.contents.chests)))
                        }
                    }
                }

                section("COINS", icon: "dollarsign.circle.fill") {
                    HStack(spacing: 10) {
                        ForEach(Array(Shop.coinOffers.enumerated()), id: \.offset) { index, offer in
                            offerCard(offer, art: AnyView(coinPile(index + 1)),
                                      subtitle: String(localized: "\(Shop.contents(of: offer, arena: profile.bestArena.number).coins.formatted()) coins"))
                        }
                    }
                }

                VStack(spacing: 6) {
                    Button("Restore Purchases") { Task { await store.restorePurchases() } }
                        .font(Theme.bodyFont(13, weight: .black))
                        .foregroundStyle(.white)
                        .buttonStyle(.plain)
                    if store.loadFailed {
                        Text("The store couldn't be reached. Check your connection and try again.")
                            .font(Theme.bodyFont(12, weight: .heavy))
                            .foregroundStyle(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .task { if store.products.isEmpty { await store.loadProducts() } }
    }

    // MARK: Sections

    private func section<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title.localized, systemImage: icon)
                .font(Theme.bodyFont(14, weight: .black))
                .foregroundStyle(.white)
                .shadow(color: Theme.ink.opacity(0.6), radius: 0, x: 0, y: 1.5)
            content()
        }
    }

    // MARK: Free rewards

    private func adCard(_ reward: Shop.AdReward, title: String, art: AnyView) -> some View {
        let left = profile.adsLeft(reward)
        let ready = ads.isReady && left > 0
        return VStack(spacing: 8) {
            art.frame(height: 48)
            Text(title.localized)
                .font(Theme.titleFont(17))
                .foregroundStyle(Theme.ink)
            Text(left > 0 ? String(localized: "\(left) left today") : String(localized: "Come back tomorrow"))
                .font(Theme.bodyFont(11, weight: .heavy))
                .foregroundStyle(Theme.textSecondary)
            Button {
                model.watchAd(for: reward)
            } label: {
                Label(left == 0 ? String(localized: "Done") : ads.isReady ? String(localized: "Watch") : String(localized: "Loading…"), systemImage: "play.fill")
            }
            .buttonStyle(CartoonButtonStyle(fill: Theme.go, foreground: .white, fontSize: 15, cornerRadius: 12))
            .disabled(!ready)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .cartoonCard(fill: Theme.cream, cornerRadius: 20, shadow: 5, lineWidth: 3)
    }

    // MARK: Purchases

    private var starterPackCard: some View {
        let offer = Shop.starterPack
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("SPECIAL OFFER")
                    .font(Theme.bodyFont(11, weight: .black))
                    .tracking(1.5)
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(Theme.yellow))
                    .overlay(Capsule().strokeBorder(Theme.ink, lineWidth: 2))
                Spacer()
                Text("ONE TIME ONLY")
                    .font(Theme.bodyFont(11, weight: .black))
                    .foregroundStyle(.white)
            }
            OutlinedText(offer.title.localized.uppercased(), size: 28, fill: .white, outline: 3)
                .fixedSize()
            HStack(spacing: 14) {
                contentsItem(AnyView(CoinLabel(amount: offer.contents.coins, size: 18, textColor: .white)), caption: "coins")
                contentsItem(AnyView(HStack(spacing: 4) {
                    ChestIcon(kind: offer.contents.chests.max() ?? .wooden, size: 30)
                    Text("×\(offer.contents.chests.count)").font(Theme.titleFont(18)).foregroundStyle(.white)
                }), caption: "chests")
                ForEach(Array(offer.contents.cards.keys.sorted()), id: \.self) { id in
                    if let base = FighterCatalog.definition(id: id) {
                        contentsItem(AnyView(HStack(spacing: 4) {
                            FighterPortrait(definition: base, color: base.rarity.color, size: 32, expression: .happy)
                            Text("×\(offer.contents.cards[id] ?? 0)").font(Theme.titleFont(18)).foregroundStyle(.white)
                        }), caption: String(localized: "\(base.name) cards"))
                    }
                }
            }
            buyButton(offer, fill: Theme.yellow)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22).fill(LinearGradient(
                colors: [Rarity.epic.color, Rarity.epic.color.mix(with: Theme.ink, by: 0.35)], startPoint: .top, endPoint: .bottom))
        )
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Theme.ink, lineWidth: 3.5))
        .background(RoundedRectangle(cornerRadius: 22).fill(Theme.ink).offset(y: 6))
        .padding(.bottom, 6)
    }

    private func contentsItem(_ art: AnyView, caption: String) -> some View {
        VStack(spacing: 2) {
            art.frame(height: 34)
            Text(caption.localized.uppercased())
                .font(Theme.bodyFont(9, weight: .black))
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    /// `subtitle` replaces the offer's own (coin packs show what they give at the player's arena).
    private func offerCard(_ offer: Shop.Offer, art: AnyView, subtitle: String? = nil) -> some View {
        VStack(spacing: 6) {
            art.frame(height: 56)
            Text(offer.title.localized)
                .font(Theme.titleFont(15))
                .foregroundStyle(Theme.ink)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(subtitle ?? offer.subtitle.localized)
                .font(Theme.bodyFont(11, weight: .heavy))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1).minimumScaleFactor(0.7)
            buyButton(offer, fill: Theme.go)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .cartoonCard(fill: Theme.cream, cornerRadius: 18, shadow: 5, lineWidth: 3)
        .overlay(alignment: .top) {
            if let tag = offer.tag {
                Text(tag.localized)
                    .font(Theme.bodyFont(9, weight: .black))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Capsule().fill(Theme.blood))
                    .overlay(Capsule().strokeBorder(Theme.ink, lineWidth: 2))
                    .fixedSize()
                    .offset(y: -9)
            }
        }
    }

    /// Price from the App Store; a spinner while buying.
    private func buyButton(_ offer: Shop.Offer, fill: Color) -> some View {
        let product = store.product(for: offer)
        let busy = store.purchasing == offer.productID
        return Button {
            Task { await store.buy(offer, using: purchase) }
        } label: {
            Group {
                if busy || product == nil {
                    // Buying, or prices still loading from the App Store.
                    ProgressView().tint(fill == Theme.yellow ? Theme.ink : .white)
                } else {
                    Text(product?.displayPrice ?? "")
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(CartoonButtonStyle(fill: fill, foreground: fill == Theme.yellow ? Theme.ink : .white, fontSize: 16, cornerRadius: 12))
        .allowsHitTesting(product != nil && store.purchasing == nil)
    }

    // MARK: Art

    /// Up to three of the bundle's best chests, plus the total.
    private func chestStack(_ chests: [ChestKind]) -> some View {
        let count = chests.count
        let best = Array(chests.sorted(by: >).prefix(3))
        return ZStack {
            // The best chest in the middle, in front; the next two either side.
            ForEach(0..<best.count, id: \.self) { i in
                ChestIcon(kind: best[i], size: i == 0 ? 44 : 36)
                    .offset(x: [0, -18, 18][i], y: i == 0 ? -4 : 4)
                    .zIndex(i == 0 ? 1 : 0)
            }
            if count > 3 {
                Text("×\(count)")
                    .font(Theme.titleFont(14))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .background(Capsule().fill(Theme.blood))
                    .overlay(Capsule().strokeBorder(Theme.ink, lineWidth: 1.5))
                    .offset(x: 26, y: 18)
                    .zIndex(2)
            }
        }
    }

    /// A pile of coins that grows with the pack size.
    private func coinPile(_ size: Int) -> some View {
        ZStack {
            ForEach(0..<(size * 2 + 1), id: \.self) { i in
                Circle()
                    .fill(LinearGradient(colors: [Theme.yellow.mix(with: .white, by: 0.3), Theme.yellow, Theme.overtime],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay(Circle().strokeBorder(Theme.ink, lineWidth: 2))
                    .overlay(Text("$").font(.system(size: 11, weight: .black, design: .rounded)).foregroundStyle(Theme.ink.opacity(0.6)))
                    .frame(width: 24, height: 24)
                    .offset(x: CGFloat((i % 3) - 1) * 12, y: CGFloat(-(i / 3)) * 9 + 10)
            }
        }
    }
}
