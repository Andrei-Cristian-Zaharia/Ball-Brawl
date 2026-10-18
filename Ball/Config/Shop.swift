import Foundation

// MARK: - Shop catalog (edit these to change offers)

/// In-app purchases and rewarded-ad offers. Product IDs must match App Store Connect
/// (and the local `Ball.storekit` test file).
nonisolated enum Shop {
    /// What a purchase or an ad grants.
    struct Contents: Equatable {
        var coins = 0
        var chests: [ChestKind] = []
        /// Cards for specific balls.
        var cards: [String: Int] = [:]
    }

    struct Offer {
        let productID: String
        let title: String
        let subtitle: String
        let contents: Contents
        /// Shown on the card ("Best value").
        let tag: String?
        /// Bought once (the starter pack); everything else is consumable.
        let oneTime: Bool
    }

    private static let prefix = "com.andreizaharia.ballbrawl."

    static let starterPack = Offer(productID: prefix + "starter", title: "Starter Pack",
                                   subtitle: "One time only: coins, chests and Spike cards",
                                   contents: Contents(coins: 1000, chests: [.magic, .gold, .gold, .silver, .silver],
                                                      cards: ["spike": 6]),
                                   tag: "ONE TIME", oneTime: true)

    static let chestOffers: [Offer] = [
        Offer(productID: prefix + "chests.3", title: "3 Gold Chests", subtitle: "Epic cards guaranteed",
              contents: Contents(chests: [.gold, .gold, .gold]), tag: nil, oneTime: false),
        Offer(productID: prefix + "chests.10", title: "Mega Bundle", subtitle: "Legendary + Magic + 8 more",
              contents: Contents(chests: [.legendary, .magic, .magic, .gold, .gold, .gold, .gold, .silver, .silver, .silver]),
              tag: "BEST VALUE", oneTime: false),
    ]

    static let coinOffers: [Offer] = [
        Offer(productID: prefix + "coins.small", title: "Pouch of Coins", subtitle: "500 coins",
              contents: Contents(coins: 500), tag: nil, oneTime: false),
        Offer(productID: prefix + "coins.medium", title: "Bag of Coins", subtitle: "1,500 coins",
              contents: Contents(coins: 1500), tag: "POPULAR", oneTime: false),
        Offer(productID: prefix + "coins.large", title: "Chest of Coins", subtitle: "5,000 coins",
              contents: Contents(coins: 5000), tag: "BEST VALUE", oneTime: false),
    ]

    static var allOffers: [Offer] { [starterPack] + chestOffers + coinOffers }

    /// Coin packs grow with the best arena reached, since upgrades cost more higher up
    /// (Training Camp 1×, then 1.5×, 2×, 3×, 4× and 5× in the Royal Arena).
    static let coinPackMultipliers: [Double] = [1, 1.5, 2, 3, 4, 5]

    /// What an offer gives a player whose best arena is `arena` (coin packs scale; everything else is fixed).
    static func contents(of offer: Offer, arena: Int) -> Contents {
        guard coinOffers.contains(where: { $0.productID == offer.productID }) else { return offer.contents }
        let multiplier = coinPackMultipliers[min(max(arena, 1), coinPackMultipliers.count) - 1]
        var contents = offer.contents
        contents.coins = Int((Double(contents.coins) * multiplier / 50).rounded()) * 50
        return contents
    }

    static func offer(for productID: String) -> Offer? { allOffers.first { $0.productID == productID } }

    // MARK: Rewarded ads

    /// Things a player can earn by choosing to watch an ad, each with a daily limit.
    enum AdReward: String, CaseIterable {
        case coins
        case chest
        /// Bring a ball that fell in today's crusade back to fight.
        case crusadeRevive

        var dailyLimit: Int {
            switch self {
            case .coins: return 5
            case .chest: return 1
            case .crusadeRevive: return 1
            }
        }

        var contents: Contents {
            switch self {
            case .coins: return Contents(coins: 60)
            case .chest: return Contents(chests: [.silver])
            case .crusadeRevive: return Contents()
            }
        }
    }
}
