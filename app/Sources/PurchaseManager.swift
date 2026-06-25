import Foundation
import RevenueCat

// RevenueCat wrapper. Configures the SDK, exposes the current offering + pro state,
// and runs purchase/restore. No-ops cleanly when the key isn't set yet (dev/sim).
@MainActor
final class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()

    @Published var offering: Offering?
    @Published var isPro = false
    private(set) var configured = false

    func configure(appUserID: String? = nil) {
        guard Config.revenueCatConfigured, !configured else { return }
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: Config.revenueCatKey, appUserID: appUserID)
        configured = true
        Task { await loadOffering(); await refresh() }
    }

    // Tie purchases to the signed-in Supabase user once we know it.
    func identify(_ appUserID: String) async {
        guard configured else { return }
        _ = try? await Purchases.shared.logIn(appUserID)
        await refresh()
    }

    func loadOffering() async {
        guard configured else { return }
        offering = try? await Purchases.shared.offerings().current
    }

    func refresh() async {
        guard configured, let info = try? await Purchases.shared.customerInfo() else { return }
        isPro = info.entitlements[Config.entitlementID]?.isActive == true
    }

    var annual: Package? { offering?.annual }
    var weekly: Package? { offering?.weekly }

    // Returns true if the purchase unlocked the entitlement.
    func purchase(_ package: Package) async -> Bool {
        guard configured else { return false }
        guard let result = try? await Purchases.shared.purchase(package: package) else { return false }
        isPro = result.customerInfo.entitlements[Config.entitlementID]?.isActive == true
        return isPro
    }

    func restore() async -> Bool {
        guard configured, let info = try? await Purchases.shared.restorePurchases() else { return false }
        isPro = info.entitlements[Config.entitlementID]?.isActive == true
        return isPro
    }
}
