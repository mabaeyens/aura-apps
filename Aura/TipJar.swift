import Foundation
import StoreKit
import AuraKit

/// The tip jar's StoreKit 2 store. Loads the three consumable "tónica" tips, runs a purchase,
/// verifies and finishes the transaction, and publishes a small state machine the sheet reads.
///
/// Tips are **consumables** — repeatable, unlock nothing — so there's no entitlement to track and
/// no restore flow. We still listen to `Transaction.updates` so a purchase approved out of band
/// (Ask to Buy, an interrupted flow) gets finished instead of lingering in the queue.
///
/// iPhone-only, like the rest of the app UI; kept in the app target (not `AuraKit`) since StoreKit
/// purchasing isn't shared with the widgets or the Watch.
@MainActor
final class TipJar: ObservableObject {

    /// The three consumable product identifiers, defined in `Aura.storekit` for local testing and in
    /// App Store Connect for release. Ordered small → large; the UI re-sorts by real price anyway.
    static let productIDs = [
        "com.mab.Aura.tip.small",
        "com.mab.Aura.tip.medium",
        "com.mab.Aura.tip.large",
    ]

    /// How the product list is doing — drives the loading / retry states in the sheet.
    enum LoadState: Equatable {
        case loading
        case loaded
        case failed
    }

    /// Where a purchase is in its lifecycle. `success` and `pending` are terminal-ish states the
    /// sheet shows a confirmation for; `failed` carries a Spanish, user-facing message.
    enum PurchaseState: Equatable {
        case ready
        case purchasing(productID: String)
        case success
        case pending
        case failed(String)
    }

    /// The loaded tips, sorted by ascending price so the sheet always renders small → large.
    @Published private(set) var products: [Product] = []
    @Published private(set) var loadState: LoadState = .loading
    @Published private(set) var purchaseState: PurchaseState = .ready

    /// The background listener for transactions approved outside the direct `purchase()` call.
    private var updatesTask: Task<Void, Never>?

    init() {
        // Start listening before loading, so a transaction that arrives mid-launch is still finished.
        updatesTask = listenForTransactions()
    }

    deinit {
        updatesTask?.cancel()
    }

    /// True while a purchase is in flight for `product`, so the sheet can show a spinner on that row.
    func isPurchasing(_ product: Product) -> Bool {
        purchaseState == .purchasing(productID: product.id)
    }

    /// Load the three tips from StoreKit. Safe to call again (e.g. a retry after a failure).
    func loadProducts() async {
        loadState = .loading
        do {
            let loaded = try await Product.products(for: Self.productIDs)
            products = loaded.sorted { $0.price < $1.price }
            loadState = loaded.isEmpty ? .failed : .loaded
        } catch {
            products = []
            loadState = .failed
        }
    }

    /// Buy a tip. Verifies the signed transaction, finishes it (consumables are delivered instantly —
    /// there's nothing to persist), and moves the state machine. Never throws to the caller: cancel,
    /// pending and failure all resolve into a published state the sheet renders.
    func purchase(_ product: Product) async {
        purchaseState = .purchasing(productID: product.id)
        do {
            let result = try await product.purchase()
            switch result {
            case let .success(verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                purchaseState = .success
            case .userCancelled:
                purchaseState = .ready
            case .pending:
                // Deferred (e.g. Ask to Buy): the eventual approval arrives via Transaction.updates.
                purchaseState = .pending
            @unknown default:
                purchaseState = .ready
            }
        } catch {
            purchaseState = .failed(auraString("tip.error.failed"))
        }
    }

    /// Return the state machine to `ready` — called when the sheet's confirmation or error is dismissed.
    func resetPurchaseState() {
        purchaseState = .ready
    }

    // MARK: - StoreKit plumbing

    /// Watch for transactions completed outside the direct purchase flow (Ask to Buy approvals,
    /// interrupted purchases, other devices) and finish each verified one. Consumables need no
    /// entitlement bookkeeping, so finishing is all that's required to clear the queue.
    private func listenForTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                if let transaction = try? self.checkVerified(update) {
                    await transaction.finish()
                    // If a deferred purchase finally lands, reflect it as a success.
                    if self.purchaseState == .pending { self.purchaseState = .success }
                }
            }
        }
    }

    /// Unwrap StoreKit's `VerificationResult`, throwing when the signature check fails.
    nonisolated private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case let .unverified(_, error):
            throw error
        case let .verified(safe):
            return safe
        }
    }
}
