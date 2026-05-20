import Foundation

/// Tracks daily AI processing usage for free tier limits.
/// Uses App Group UserDefaults so both main app and extension can read/write.
struct DailyUsageTracker {
    private static let suiteName = appGroupID
    private static let usageCountKey = "daily_usage_count"
    private static let lastResetDateKey = "daily_usage_last_reset"

    static let freeLimit = 3

    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    /// Current usage count for today
    static var todayCount: Int {
        resetIfNewDay()
        return sharedDefaults?.integer(forKey: usageCountKey) ?? 0
    }

    /// Remaining free uses for today
    static var remainingFreeUses: Int {
        max(0, freeLimit - todayCount)
    }

    /// Whether the user has exceeded their free daily limit
    static var isLimitReached: Bool {
        todayCount >= freeLimit
    }

    /// Increment the usage counter
    static func incrementUsage() {
        resetIfNewDay()
        let current = sharedDefaults?.integer(forKey: usageCountKey) ?? 0
        sharedDefaults?.set(current + 1, forKey: usageCountKey)
    }

    /// Reset counter if a new day has started
    private static func resetIfNewDay() {
        guard let defaults = sharedDefaults else { return }

        let lastReset = defaults.object(forKey: lastResetDateKey) as? Date ?? .distantPast
        if !Calendar.current.isDateInToday(lastReset) {
            defaults.set(0, forKey: usageCountKey)
            defaults.set(Date(), forKey: lastResetDateKey)
        }
    }
}
