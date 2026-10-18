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
                Text(value).lineLimit(lines, reservesSpace: true)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
