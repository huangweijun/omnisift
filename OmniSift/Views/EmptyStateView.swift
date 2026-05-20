import SwiftUI

struct EmptyStateView: View {
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
                Text("Start Collecting")
                    .font(.title2.weight(.bold))

                Text("Share text from any app to capture\nAI insights and knowledge snippets.")
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
                    text: "Select text in any app"
                )
                InstructionRow(
                    step: "2",
                    icon: "square.and.arrow.up",
                    text: "Tap the Share button"
                )
                InstructionRow(
                    step: "3",
                    icon: "app.fill",
                    text: "Choose OmniSift"
                )
                InstructionRow(
                    step: "4",
                    icon: "sparkles",
                    text: "AI cleans & archives locally"
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
