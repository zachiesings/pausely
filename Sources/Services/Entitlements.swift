import StoreKit
import Foundation

/// One-time (non-consumable) "Pro" unlock via StoreKit 2 — no third-party SDK.
/// `productID` must match the In-App Purchase created in App Store Connect.
@MainActor
final class Entitlements: ObservableObject {
    static let productID = "pausely_pro"

    @Published private(set) var isPro = false
    @Published private(set) var product: Product?
    @Published var purchasing = false
    @Published var lastError: String?

    private var updates: Task<Void, Never>?

    init() {
        updates = observeTransactions()
        Task {
            await loadProduct()
            await refresh()
        }
    }

    var priceText: String { product?.displayPrice ?? "" }

    func loadProduct() async {
        do {
            product = try await Product.products(for: [Self.productID]).first
        } catch {
            lastError = error.localizedDescription
        }
    }

    func refresh() async {
        var owned = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result,
               t.productID == Self.productID,
               t.revocationDate == nil {
                owned = true
            }
        }
        isPro = owned
    }

    func purchase() async {
        guard let product else {
            // Product not loaded yet (e.g. the IAP is not available in the review
            // sandbox). Silently retry loading instead of surfacing an error.
            await loadProduct()
            return
        }
        purchasing = true
        defer { purchasing = false }
        do {
            let result = try await product.purchase()
            if case .success(let verification) = result,
               case .verified(let transaction) = verification {
                await transaction.finish()
                await refresh()
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
            await refresh()
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func observeTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self?.refresh()
                }
            }
        }
    }
}
