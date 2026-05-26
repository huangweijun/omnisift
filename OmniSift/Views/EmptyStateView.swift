import SwiftUI

struct EmptyStateView: View {
    @AppStorage(UserDefaultsKeys.outputLanguagePreference, store: UserDefaults(suiteName: appGroupID))
    private var outputLanguageRawValue = OutputLanguagePreference.automatic.rawValue

    private var strings: AppStrings {
        AppStrings(rawPreferenceValue: outputLanguageRawValue)
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Illustration
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.08))
                    .frame(width: 120, height: 120)

                Image(systemName: "square.and.arrow.up.on.square")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.accentColor)
            }

            // Text
            VStack(spacing: 8) {
                Text(strings.startCollecting)
                    .font(.title2.weight(.bold))

                Text(strings.emptyStateDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            // Instructions
            VStack(alignment: .leading, spacing: 16) {
                InstructionRow(
                    step: "1",
                    icon: "hand.tap",
                    text: strings.instructionOpen
                )
                InstructionRow(
                    step: "2",
                    icon: "square.and.arrow.up",
                    text: strings.instructionShare
                )
                InstructionRow(
                    step: "3",
                    icon: "app.fill",
                    text: strings.instructionChooseApp
                )
                InstructionRow(
                    step: "4",
                    icon: "sparkles",
                    text: strings.instructionAI
                )
            }
            .padding(20)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
    }
}

struct InstructionRow: View {
    let step: String
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Text(step)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Color.accentColor, in: Circle())

            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)

            Text(text)
                .font(.subheadline)
        }
    }
}

#Preview {
    EmptyStateView()
}
