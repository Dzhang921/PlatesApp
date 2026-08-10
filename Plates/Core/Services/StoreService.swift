import Foundation
import StoreKit

/// StoreKit 2 wrapper for the one-time Pro unlock.
///
/// Free accounts may collect up to `freeRestaurantLimit` restaurants; the
/// non-consumable `com.dxzhang.plates.pro` product lifts the cap forever.
/// `isPro` is mirrored to UserDefaults so a relaunch — even offline — starts
/// with the correct answer instantly, then StoreKit confirms in the background.
@Observable
@MainActor
final class StoreService {

    static let shared = StoreService()

    static let freeRestaurantLimit = 10
    static let proProductID = "com.dxzhang.plates.pro"

    private static let cacheKey = "isProCached"

    /// Whether the lifetime Pro unlock is owned. Seeded from the local cache,
    /// kept current by entitlement checks and the transaction listener.
    private(set) var isPro: Bool

    /// The Pro product, once loaded from the App Store.
    private(set) var proProduct: Product?

    /// Localized price for paywall CTAs, with a sensible fallback while the
    /// product is still loading (or the store is unreachable).
    var priceText: String {
        proProduct?.displayPrice ?? "$6.99"
    }

    private var updatesTask: Task<Void, Never>?

    private init() {
        isPro = UserDefaults.standard.bool(forKey: Self.cacheKey)
    }

    // MARK: - Gating

    /// Free users can add new restaurants while under the limit; Pro is unlimited.
    /// Repeat visits to an already-collected restaurant are never gated.
    func canAddRestaurant(currentCount: Int) -> Bool {
        isPro || currentCount < Self.freeRestaurantLimit
    }

    // MARK: - Lifecycle

    /// Loads the product, reconciles the current entitlement, and starts the
    /// transaction listener. Safe to call more than once.
    func start() async {
        if proProduct == nil {
            proProduct = try? await Product.products(for: [Self.proProductID]).first
        }
        await refreshEntitlement(allowDowngrade: false)
        startListeningIfNeeded()
    }

    private func startListeningIfNeeded() {
        guard updatesTask == nil else { return }
        updatesTask = Task.detached(priority: .background) { [weak self] in
            for await update in Transaction.updates {
                guard case .verified(let transaction) = update else { continue }
                if transaction.productID == StoreService.proProductID {
                    await self?.setPro(transaction.revocationDate == nil)
                }
                await transaction.finish()
            }
        }
    }

    // MARK: - Purchase

    /// Runs the App Store purchase flow for Pro.
    /// - Returns: `true` when the purchase completed and Pro is now unlocked;
    ///   `false` when the user cancelled or the purchase is pending approval
    ///   (Ask to Buy) — in the pending case the transaction listener will flip
    ///   `isPro` if it is later approved.
    func purchasePro() async throws -> Bool {
        if proProduct == nil {
            proProduct = try await Product.products(for: [Self.proProductID]).first
        }
        guard let product = proProduct else { return false }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            guard case .verified(let transaction) = verification else { return false }
            setPro(true)
            await transaction.finish()
            Haptics.celebrate()
            return true
        case .userCancelled:
            return false
        case .pending:
            return false
        @unknown default:
            return false
        }
    }

    /// Syncs with the App Store and re-checks entitlements. Only a successful
    /// sync is allowed to revoke a cached unlock, so a flaky connection can
    /// never lock a paying user out.
    func restorePurchases() async {
        var synced = false
        do {
            try await AppStore.sync()
            synced = true
        } catch {
            // Sync failed (offline, cancelled sign-in) — fall through and
            // re-check locally without downgrading.
        }
        await refreshEntitlement(allowDowngrade: synced)
    }

    // MARK: - Entitlements

    /// Walks `Transaction.currentEntitlements` for a verified, unrevoked Pro
    /// purchase. Finding one always upgrades; finding none only downgrades when
    /// `allowDowngrade` is set (i.e. after a definitive App Store sync).
    private func refreshEntitlement(allowDowngrade: Bool) async {
        var ownsPro = false
        for await entitlement in Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement else { continue }
            if transaction.productID == Self.proProductID, transaction.revocationDate == nil {
                ownsPro = true
            }
        }
        if ownsPro {
            setPro(true)
        } else if allowDowngrade {
            setPro(false)
        }
    }

    private func setPro(_ value: Bool) {
        isPro = value
        UserDefaults.standard.set(value, forKey: Self.cacheKey)
    }
}
