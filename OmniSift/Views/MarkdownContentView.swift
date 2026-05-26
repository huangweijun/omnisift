import SwiftUI

struct MarkdownContentView: View {
    let markdown: String

    var body: some View {
        Group {
            if let attributed = makeAttributedString(from: markdown) {
                Text(attributed)
            } else {
                Text(markdown)
            }
        }
        .font(.body)
        .lineSpacing(4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
    }

    private func makeAttributedString(from markdown: String) -> AttributedString? {
        let prepared = ContentStructure.preprocessMarkdownForDisplay(markdown)
        return try? AttributedString(
            markdown: prepared,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .full)
        )
    }
}
