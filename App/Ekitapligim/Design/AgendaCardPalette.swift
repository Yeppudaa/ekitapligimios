import SwiftUI

/// Shared post-type colors for home previews and full agenda cards.
struct AgendaCardPalette {
    let type: String

    var accent: Color {
        switch type {
        case "quotation": Color(hex: 0x684399)
        case "review": Color(hex: 0x8A5A12)
        case "progress": Color(hex: 0x22744F)
        case "book": Color(hex: 0x087A7D)
        case "quote": Color(hex: 0x5A67B7)
        default: Color(hex: 0x286798)
        }
    }

    var paper: Color {
        switch type {
        case "quotation": Color(hex: 0xF6F2FF)
        case "review": Color(hex: 0xFFF8E9)
        case "progress": Color(hex: 0xEFF9F2)
        case "book": Color(hex: 0xEDF9F8)
        case "quote": Color(hex: 0xF2F3FC)
        default: Color(hex: 0xEFF6FC)
        }
    }

    var badge: Color { accent.opacity(0.10) }
    var border: Color { accent.opacity(0.20) }
    var ink: Color { Color(hex: 0x252139) }
    var muted: Color { Color(hex: 0x596573) }
}
