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
    static let entitlementID = "pro"

    /// RevenueCat API key injected from Config/Local.xcconfig into Info.plist.
    static let apiKey: String? = {
        if let key = Bundle.main.configuredString(forInfoDictionaryKey: "REVENUECAT_API_KEY") {
            return key
        }
        return Bundle.main.secretPlistString(forKey: "REVENUECAT_API_KEY")
    }()

    /// Configure RevenueCat SDK — call once at app launch
    func configure() {
        #if canImport(RevenueCat)
        guard let apiKey = Self.apiKey else {
            isPremium = false
            syncToAppGroup()
            return
        }
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: apiKey)
        // Listen for customer info changes
        Task { await listenForUpdates() }
        #endif
    }

    /// Check current subscription status
    func checkStatus() async {
        #if canImport(RevenueCat)
        guard Purchases.isConfigured else {
            isPremium = false
            syncToAppGroup()
            return
        }
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
        guard Purchases.isConfigured else {
            return false
        }
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
        guard Purchases.isConfigured else {
            return
        }
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

extension Bundle {
    func configuredString(forInfoDictionaryKey key: String) -> String? {
        guard let value = object(forInfoDictionaryKey: key) as? String else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "$(\(key))" else {
            return nil
        }
        return trimmed
    }

    func secretPlistString(forKey key: String) -> String? {
        guard let url = url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let value = dict[key] as? String else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
