import Foundation
import RevenueCat

/// Thin wrapper around RevenueCat. The "pro" entitlement unlocks all paid
/// features across the app. One-time (non-consumable) purchase.
@MainActor
final class Entitlements: ObservableObject {
    static let entitlementID = "pro"

    @Published private(set) var isPro = false
    @Published private(set) var offering: Offering?
    @Published var purchasing = false
    @Published var lastError: String?

    init() {
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: Secrets.revenueCatKey)
        Task {
            await refresh()
            await loadOffering()
        }
    }

    var priceText: String {
        offering?.availablePackages.first?.storeProduct.localizedPriceString ?? ""
    }

    func refresh() async {
        if let info = try? await Purchases.shared.customerInfo() {
            isPro = info.entitlements[Self.entitlementID]?.isActive == true
        }
    }

    func loadOffering() async {
        offering = try? await Purchases.shared.offerings().current
    }

    func purchase() async {
        guard let package = offering?.availablePackages.first else {
            lastError = "Product not available yet. Please try again."
            return
        }
        purchasing = true
        defer { purchasing = false }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            isPro = result.customerInfo.entitlements[Self.entitlementID]?.isActive == true
        } catch {
            lastError = (error as NSError).localizedDescription
        }
    }

    func restore() async {
        do {
            let info = try await Purchases.shared.restorePurchases()
            isPro = info.entitlements[Self.entitlementID]?.isActive == true
        } catch {
            lastError = (error as NSError).localizedDescription
        }
    }
}
