import SwiftUI
#if canImport(RevenueCatUI)
import RevenueCatUI
#endif

/// Paywall screen presented when user hits free-tier limit or taps "Upgrade"
struct ProPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SubscriptionService.self) private var subscriptionService

    var body: some View {
        #if canImport(RevenueCatUI)
        PaywallView(displayCloseButton: true)
            .onPurchaseCompleted { _ in
                Task { await subscriptionService.checkStatus() }
                dismiss()
            }
            .onRestoreCompleted { _ in
                Task { await subscriptionService.checkStatus() }
                dismiss()
            }
        #else
        // Placeholder for development without RevenueCat
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "crown.fill")
                .font(.system(size: 56))
                .foregroundStyle(.yellow)

            Text("OmniSift Pro")
                .font(.title.bold())

            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(icon: "infinity", text: "Unlimited AI processing")
                FeatureRow(icon: "rectangle.stack.fill", text: "Premium card templates")
                FeatureRow(icon: "photo", text: "Export without watermark")
                FeatureRow(icon: "arrow.clockwise", text: "Priority processing")
            }
            .padding(.horizontal, 32)

            Text("$2.99/month or $19.99/year")
                .font(.headline)
                .foregroundStyle(Color.accentColor)

            Button {
                dismiss()
            } label: {
                Text("Subscribe")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 32)

            Button("Restore Purchases") {
                Task { await subscriptionService.restorePurchases() }
                dismiss()
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Spacer()
        }
        #endif
    }
}

private struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
        }
    }
}

#Preview {
    ProPaywallView()
        .environment(SubscriptionService())
}
