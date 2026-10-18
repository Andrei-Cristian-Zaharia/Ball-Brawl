import CloudKit
import Foundation

/// Voucher codes (free coins and chests), kept in the app's CloudKit public database so new ones can be
/// added from the CloudKit dashboard without an app update.
///
/// Each code is one record of type `Voucher` whose record name is the code itself (upper case), with:
/// - `coins` (Int64, optional): coins paid
/// - `chests` (String list, optional): chest kinds paid, e.g. ["gold", "silver"] (`ChestKind` raw values)
/// - `expires` (Date/Time, optional): the code stops working after this
/// - `maxUses` (Int64, optional): how many players in total can redeem it
/// Each player can redeem a code once (tracked in their saved profile).
///
/// Limited codes (`maxUses`) also save a `VoucherRedemption` record per use, named "<code>.<iCloud user>"
/// with a queryable `code` field: the count of those is the code's uses, and the name makes CloudKit refuse
/// a second use from the same iCloud account. Saving it needs the player signed in to iCloud.
final class VoucherService {
    static let containerID = "iCloud.com.andreizaharia.ballbrawl"
    static let recordType = "Voucher"
    static let redemptionType = "VoucherRedemption"

    enum Outcome: Equatable {
        case redeemed(Progression.Rewards)
        case alreadyUsed
        case notFound
        case expired
        case empty
        /// A limited code that has reached its `maxUses`.
        case usedUp
        /// Limited codes need an iCloud account to count uses.
        case needsICloud
        case unavailable
    }

    private var container: CKContainer { CKContainer(identifier: Self.containerID) }
    private var database: CKDatabase { container.publicCloudDatabase }

    /// The code as it's stored: trimmed, upper case, letters, digits and dashes only.
    static func normalize(_ raw: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-"))
        return String(raw.uppercased().unicodeScalars.filter(allowed.contains).map(Character.init))
    }

    func redeem(_ raw: String, profile: ProfileStore, now: Date = .now) async -> Outcome {
        let code = Self.normalize(raw)
        guard !code.isEmpty else { return .notFound }
        guard !profile.hasRedeemed(code) else { return .alreadyUsed }
        let record: CKRecord
        do {
            record = try await database.record(for: CKRecord.ID(recordName: code))
        } catch let error as CKError where error.code == .unknownItem {
            return .notFound
        } catch {
            return .unavailable
        }
        guard record.recordType == Self.recordType else { return .notFound }
        if let expires = record["expires"] as? Date, expires < now { return .expired }
        let coins = (record["coins"] as? Int) ?? 0
        let chests = ((record["chests"] as? [String]) ?? []).compactMap { ChestKind(rawValue: $0.lowercased()) }
        let rewards = Progression.Rewards(coins: max(0, coins), chests: chests)
        guard rewards != Progression.Rewards() else { return .empty }
        if let maxUses = record["maxUses"] as? Int, maxUses > 0 {
            if let refusal = await claimUse(of: code, maxUses: maxUses) { return refusal }
        }
        return profile.redeemVoucher(code, rewards: rewards) ? .redeemed(rewards) : .alreadyUsed
    }

    /// Counts a limited code's uses and records this player's; nil if they may have it.
    private func claimUse(of code: String, maxUses: Int) async -> Outcome? {
        do {
            guard try await container.accountStatus() == .available else { return .needsICloud }
            let user = try await container.userRecordID()
            if try await uses(of: code, upTo: maxUses) >= maxUses { return .usedUp }
            let use = CKRecord(recordType: Self.redemptionType,
                               recordID: CKRecord.ID(recordName: "\(code).\(user.recordName)"))
            use["code"] = code
            _ = try await database.save(use)
            return nil
        } catch let error as CKError where error.code == .serverRecordChanged {
            // This iCloud account already has a use of this code.
            return .alreadyUsed
        } catch let error as CKError where error.code == .notAuthenticated {
            return .needsICloud
        } catch {
            return .unavailable
        }
    }

    /// How many players have used a code, counting no further than `limit`.
    private func uses(of code: String, upTo limit: Int) async throws -> Int {
        let query = CKQuery(recordType: Self.redemptionType, predicate: NSPredicate(format: "code == %@", code))
        var page = try await database.records(matching: query, desiredKeys: [], resultsLimit: min(limit, 400))
        var count = page.matchResults.count
        while count < limit, let cursor = page.queryCursor {
            page = try await database.records(continuingMatchFrom: cursor, desiredKeys: [], resultsLimit: min(limit - count, 400))
            count += page.matchResults.count
        }
        return count
    }
}
