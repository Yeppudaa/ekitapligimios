import SwiftUI

/// Repeated cards reserve the same text space, including when a field is missing.
/// Accessibility text keeps its full intrinsic height.
struct UniformCardText: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let value: String
    let lines: Int

    init(_ value: String, lines: Int) {
        self.value = value
        self.lines = lines
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                Text(value).lineLimit(nil)
            } else {
                // A fixed sample reserves identical font metrics for empty, short and
                // accented text. reservesSpace alone still varies with fallback glyphs.
                Text(Array(repeating: "ÂĞİŞgj", count: max(1, lines)).joined(separator: "\n"))
                    .lineLimit(lines)
                    .hidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .topLeading) {
                        Text(value)
                            .lineLimit(lines)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(value))
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
