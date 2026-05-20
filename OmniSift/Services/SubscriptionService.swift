import Foundation
import SwiftUI
#if canImport(RevenueCat)
import RevenueCat
#endif

/// Manages subscription state and RevenueCat integration.
/// Checks the "pro" entitlement to determine premium access.
@MainActor
@Observable
class SubscriptionService {
    var isPremium = false
    var isLoading = false

    /// Entitlement identifier configured in RevenueCat dashboard
    private static let entitlementID = "pro"

    /// RevenueCat API key
    static let apiKey = "test_OGXBUulLoQSAMmt1xTfxmAFzWwK"

    /// Configure RevenueCat SDK — call once at app launch
    func configure() {
        #if canImport(RevenueCat)
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: Self.apiKey)
        // Listen for customer info changes
        Task { await listenForUpdates() }
        #endif
    }

    /// Check current subscription status
    func checkStatus() async {
        #if canImport(RevenueCat)
        isLoading = true
        defer { isLoading = false }
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            isPremium = customerInfo.entitlements[Self.entitlementID]?.isActive == true
            syncToAppGroup()
        } catch {
            // Fail silently — default to free tier
        }
        #endif
    }

    /// Restore purchases (for users who reinstall or switch devices)
    func restorePurchases() async -> Bool {
        #if canImport(RevenueCat)
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            isPremium = customerInfo.entitlements[Self.entitlementID]?.isActive == true
            syncToAppGroup()
            return true
        } catch {
            return false
        }
        #else
        return false
        #endif
    }

    // MARK: - Private

    #if canImport(RevenueCat)
    private func listenForUpdates() async {
        for await customerInfo in Purchases.shared.customerInfoStream {
            isPremium = customerInfo.entitlements[Self.entitlementID]?.isActive == true
            syncToAppGroup()
        }
    }
    #endif

    /// Sync premium status to App Group UserDefaults so Share Extension can read it
    private func syncToAppGroup() {
        UserDefaults(suiteName: appGroupID)?.set(isPremium, forKey: "isPremium")
    }
}
