import SwiftUI
#if canImport(RevenueCat)
import RevenueCat
#endif

/// Paywall screen presented when user hits free-tier limit or taps "Upgrade".
struct ProPaywallView: View {
    private static let privacyPolicyURL = URL(string: "https://omnisift.app/privacy-policy.html")!
    private static let termsOfUseURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    @Environment(\.dismiss) private var dismiss
    @Environment(SubscriptionService.self) private var subscriptionService
    @AppStorage(UserDefaultsKeys.outputLanguagePreference, store: UserDefaults(suiteName: appGroupID))
    private var outputLanguageRawValue = OutputLanguagePreference.automatic.rawValue

    #if canImport(RevenueCat)
    @State private var packages: [Package] = []
    @State private var selectedPackageIdentifier: String?
    #endif
    @State private var didLoadPackages = false
    @State private var isLoadingPackages = false
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var errorMessage: String?

    private var strings: AppStrings {
        AppStrings(rawPreferenceValue: outputLanguageRawValue)
    }

    var body: some View {
        ZStack {
            ProPaywallBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    topBar
                    ProPaywallHero(strings: strings)
                    ProBenefitPanel(strings: strings)
                    planSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 132)
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomActionBar
        }
        .task {
            await loadPackagesIfNeeded()
        }
    }

    private var topBar: some View {
        HStack {
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 34, height: 34)
                    .background(.regularMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(strings.close)
        }
    }

    @ViewBuilder
    private var planSection: some View {
        #if canImport(RevenueCat)
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text(strings.choosePlan)
                    .font(.headline)
                Spacer()
                if isLoadingPackages {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if isLoadingPackages && packages.isEmpty {
                LoadingPlanCard(text: strings.loadingPlans)
            } else if packages.isEmpty {
                EmptyPlanCard(
                    title: strings.plansUnavailable,
                    message: strings.plansUnavailableDescription,
                    retryTitle: strings.retry
                ) {
                    Task { await loadPackages(force: true) }
                }
            } else {
                ForEach(packages, id: \.identifier) { package in
                    PackageOptionCard(
                        title: planTitle(for: package),
                        subtitle: productSubtitle(for: package),
                        price: package.localizedPriceString,
                        period: billingPeriodText(for: package.storeProduct.subscriptionPeriod),
                        badge: package.packageType == .annual ? strings.bestValue : nil,
                        introOffer: introOfferText(for: package),
                        isSelected: selectedPackageIdentifier == package.identifier,
                        selectedText: strings.selectedPlan
                    ) {
                        withAnimation(.snappy(duration: 0.22)) {
                            selectedPackageIdentifier = package.identifier
                        }
                    }
                    .disabled(isPurchasing || isRestoring)
                }
            }

            if let errorMessage {
                ErrorBanner(message: errorMessage)
            }
        }
        .animation(.snappy(duration: 0.22), value: packages.count)
        .animation(.snappy(duration: 0.22), value: selectedPackageIdentifier)
        #else
        EmptyPlanCard(
            title: strings.plansUnavailable,
            message: strings.storeUnavailable,
            retryTitle: nil,
            action: nil
        )
        #endif
    }

    private var bottomActionBar: some View {
        VStack(spacing: 10) {
            Button {
                Task { await primaryAction() }
            } label: {
                HStack(spacing: 10) {
                    if isPurchasing {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(primaryButtonTitle)
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(primaryButtonBackground, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .disabled(primaryActionDisabled)

            HStack(spacing: 10) {
                Button {
                    Task { await restorePurchases() }
                } label: {
                    HStack(spacing: 6) {
                        if isRestoring {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text(isRestoring ? strings.restoringPurchases : strings.restorePurchases)
                    }
                    .font(.caption.weight(.medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .disabled(isPurchasing || isRestoring)

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(strings.purchasePrivacyNote)
                        .foregroundStyle(.tertiary)

                    HStack(spacing: 8) {
                        Link(strings.privacyPolicy, destination: Self.privacyPolicyURL)
                        Text("|")
                            .foregroundStyle(.tertiary)
                        Link(strings.termsOfUse, destination: Self.termsOfUseURL)
                    }
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                }
                .font(.caption2)
                .multilineTextAlignment(.trailing)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(.regularMaterial)
    }

    private var primaryButtonBackground: some ShapeStyle {
        if primaryActionDisabled {
            return AnyShapeStyle(Color.secondary.opacity(0.35))
        }
        return AnyShapeStyle(
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.49, blue: 0.42),
                    Color(red: 0.08, green: 0.31, blue: 0.56)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }

    private var primaryButtonTitle: String {
        if isPurchasing {
            return strings.purchaseInProgress
        }
        #if canImport(RevenueCat)
        if let selectedPackage {
            return strings.continueWithPrice(selectedPackage.localizedPriceString)
        }
        #endif
        return strings.continueButton
    }

    private var primaryActionDisabled: Bool {
        if isPurchasing || isRestoring || isLoadingPackages {
            return true
        }
        #if canImport(RevenueCat)
        return selectedPackage == nil
        #else
        return false
        #endif
    }

    @MainActor
    private func primaryAction() async {
        #if canImport(RevenueCat)
        await purchaseSelectedPackage()
        #else
        dismiss()
        #endif
    }

    @MainActor
    private func restorePurchases() async {
        guard !isPurchasing, !isRestoring else { return }
        isRestoring = true
        errorMessage = nil
        let restored = await subscriptionService.restorePurchases()
        isRestoring = false

        if restored {
            dismiss()
        } else {
            errorMessage = strings.restoreFailed
        }
    }

    @MainActor
    private func loadPackagesIfNeeded() async {
        #if canImport(RevenueCat)
        guard !didLoadPackages else { return }
        await loadPackages(force: false)
        #endif
    }

    @MainActor
    private func loadPackages(force: Bool) async {
        #if canImport(RevenueCat)
        guard force || !didLoadPackages else { return }
        didLoadPackages = true
        errorMessage = nil

        guard Purchases.isConfigured else {
            packages = []
            selectedPackageIdentifier = nil
            return
        }

        isLoadingPackages = true
        defer { isLoadingPackages = false }

        do {
            let offerings = try await Purchases.shared.offerings()
            let loadedPackages = offerings.current?.availablePackages ?? []
            packages = loadedPackages

            if let selectedPackageIdentifier,
               loadedPackages.contains(where: { $0.identifier == selectedPackageIdentifier }) {
                return
            }
            selectedPackageIdentifier = loadedPackages.first?.identifier
        } catch {
            packages = []
            selectedPackageIdentifier = nil
        }
        #endif
    }

    #if canImport(RevenueCat)
    private var selectedPackage: Package? {
        guard !packages.isEmpty else { return nil }
        if let selectedPackageIdentifier,
           let package = packages.first(where: { $0.identifier == selectedPackageIdentifier }) {
            return package
        }
        return packages.first
    }

    @MainActor
    private func purchaseSelectedPackage() async {
        guard let package = selectedPackage, !isPurchasing, !isRestoring else { return }
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }

        do {
            let result = try await Purchases.shared.purchase(package: package)
            guard !result.userCancelled else { return }

            let isActive = result.customerInfo.entitlements[SubscriptionService.entitlementID]?.isActive == true
            await subscriptionService.checkStatus()

            if isActive || subscriptionService.isPremium {
                dismiss()
            } else {
                errorMessage = strings.purchaseCompletedWithoutPro
            }
        } catch {
            if (error as NSError).asErrorCode == .purchaseCancelledError {
                return
            }
            errorMessage = strings.purchaseFailed
        }
    }

    private func planTitle(for package: Package) -> String {
        switch package.packageType {
        case .weekly:
            strings.weeklyPlan
        case .monthly:
            strings.monthlyPlan
        case .twoMonth:
            strings.twoMonthPlan
        case .threeMonth:
            strings.threeMonthPlan
        case .sixMonth:
            strings.sixMonthPlan
        case .annual:
            strings.annualPlan
        case .lifetime:
            strings.lifetimePlan
        case .custom, .unknown:
            productTitle(for: package) ?? strings.subscriptionPlan
        @unknown default:
            productTitle(for: package) ?? strings.subscriptionPlan
        }
    }

    private func productTitle(for package: Package) -> String? {
        storeProductText(package.storeProduct.localizedTitle)
    }

    private func productSubtitle(for package: Package) -> String? {
        guard let description = storeProductText(package.storeProduct.localizedDescription) else {
            return nil
        }
        if description == productTitle(for: package) {
            return nil
        }
        return description
    }

    private func storeProductText(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return strings.language == .english ? trimmed : nil
    }

    private func introOfferText(for package: Package) -> String? {
        guard let price = package.localizedIntroductoryPriceString,
              !price.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return "\(strings.introOffer): \(price)"
    }

    private func billingPeriodText(for period: SubscriptionPeriod?) -> String? {
        guard let period else { return nil }
        let value = max(period.value, 1)

        switch strings.language {
        case .english:
            switch period.unit {
            case .day:
                return value == 1 ? "per day" : "every \(value) days"
            case .week:
                return value == 1 ? "per week" : "every \(value) weeks"
            case .month:
                return value == 1 ? "per month" : "every \(value) months"
            case .year:
                return value == 1 ? "per year" : "every \(value) years"
            @unknown default:
                return nil
            }
        case .simplifiedChinese:
            switch period.unit {
            case .day:
                return value == 1 ? "每天" : "每 \(value) 天"
            case .week:
                return value == 1 ? "每周" : "每 \(value) 周"
            case .month:
                return value == 1 ? "每月" : "每 \(value) 个月"
            case .year:
                return value == 1 ? "每年" : "每 \(value) 年"
            @unknown default:
                return nil
            }
        }
    }
    #endif
}

private struct ProPaywallBackground: View {
    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.47, blue: 0.41).opacity(0.22),
                    Color(red: 0.95, green: 0.70, blue: 0.25).opacity(0.14),
                    Color(red: 0.09, green: 0.27, blue: 0.52).opacity(0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 310)
            .ignoresSafeArea(edges: .top)
        }
    }
}

private struct ProPaywallHero: View {
    let strings: AppStrings

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(.regularMaterial)
                    .frame(width: 78, height: 78)
                Circle()
                    .stroke(Color.white.opacity(0.45), lineWidth: 1)
                    .frame(width: 78, height: 78)
                Image(systemName: "crown.fill")
                    .font(.system(size: 32, weight: .bold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color(red: 0.95, green: 0.70, blue: 0.22), Color.accentColor)
            }

            VStack(spacing: 8) {
                Text(strings.proProductName)
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)

                Text(strings.proHeadline)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(strings.proDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 4)
    }
}

private struct ProBenefitPanel: View {
    let strings: AppStrings

    var body: some View {
        VStack(spacing: 12) {
            PaywallFeatureRow(icon: "calendar.badge.clock", text: strings.proDailyAIProcessing)
            PaywallFeatureRow(icon: "sparkles.rectangle.stack", text: strings.premiumCardTemplates)
            PaywallFeatureRow(icon: "square.and.arrow.up", text: strings.exportWithoutWatermark)
            PaywallFeatureRow(icon: "bolt.fill", text: strings.priorityProcessing)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(.white.opacity(0.24), lineWidth: 1)
        }
    }
}

private struct PaywallFeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color(red: 0.08, green: 0.49, blue: 0.42))
                .frame(width: 28, height: 28)
                .background(Color(red: 0.08, green: 0.49, blue: 0.42).opacity(0.12), in: Circle())

            Text(text)
                .font(.subheadline.weight(.medium))
                .lineLimit(2)
                .minimumScaleFactor(0.86)

            Spacer(minLength: 0)
        }
    }
}

private struct PackageOptionCard: View {
    let title: String
    let subtitle: String?
    let price: String
    let period: String?
    let badge: String?
    let introOffer: String?
    let isSelected: Bool
    let selectedText: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 8) {
                            Text(title)
                                .font(.headline)
                                .lineLimit(1)
                                .minimumScaleFactor(0.82)

                            if let badge {
                                Text(badge)
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(Color(red: 0.54, green: 0.33, blue: 0.02))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color(red: 1.00, green: 0.80, blue: 0.31).opacity(0.32), in: Capsule())
                                    .lineLimit(1)
                            }
                        }

                        if let subtitle {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }

                    Spacer(minLength: 8)

                    SelectionMark(isSelected: isSelected)
                }

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(price)
                        .font(.title3.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    if let period {
                        Text(period)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                    }

                    Spacer(minLength: 0)
                }

                if isSelected || introOffer != nil {
                    HStack(spacing: 8) {
                        if isSelected {
                            Label(selectedText, systemImage: "checkmark.seal.fill")
                                .foregroundStyle(Color(red: 0.08, green: 0.49, blue: 0.42))
                        }
                        if let introOffer {
                            Label(introOffer, systemImage: "tag.fill")
                                .foregroundStyle(Color(red: 0.80, green: 0.45, blue: 0.05))
                        }
                    }
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground, in: RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isSelected ? Color(red: 0.08, green: 0.49, blue: 0.42) : Color.primary.opacity(0.08), lineWidth: isSelected ? 1.6 : 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var cardBackground: some ShapeStyle {
        if isSelected {
            return AnyShapeStyle(Color(red: 0.08, green: 0.49, blue: 0.42).opacity(0.10))
        }
        return AnyShapeStyle(.regularMaterial)
    }
}

private struct SelectionMark: View {
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(isSelected ? Color.clear : Color.secondary.opacity(0.35), lineWidth: 1.2)
                .frame(width: 24, height: 24)
            if isSelected {
                Circle()
                    .fill(Color(red: 0.08, green: 0.49, blue: 0.42))
                    .frame(width: 24, height: 24)
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }
}

private struct LoadingPlanCard: View {
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct EmptyPlanCard: View {
    let title: String
    let message: String
    let retryTitle: String?
    let action: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let retryTitle, let action {
                Button(action: action) {
                    Label(retryTitle, systemImage: "arrow.clockwise")
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.bordered)
                .tint(.accentColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct ErrorBanner: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "info.circle.fill")
            .font(.caption.weight(.medium))
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    ProPaywallView()
        .environment(SubscriptionService())
}
