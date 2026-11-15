import SwiftUI
import EkitapligimCore

struct HomeAgendaWelcome: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var typeSize
    let onOpen: () -> Void
    private var style: ReadingRoomStyle { ReadingRoomStyle(scheme: scheme) }

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                compact
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 0) {
                        copy.padding(26).frame(minWidth: 340)
                        artwork(height: 320).frame(minWidth: 300)
                    }
                    compact
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.agenda.welcome")
    }

    private var compact: some View {
        VStack(alignment: .leading, spacing: 0) {
            artwork(height: typeSize.isAccessibilitySize ? 170 : 144)
            copy.padding(22)
        }
    }

    private func artwork(height: CGFloat) -> some View {
        ReadingRoomArtwork(name: "agenda_reader_community", height: height)
            .overlay(alignment: .bottomLeading) {
                Label(ReadingRoomL10n.text("agenda.badge"), systemImage: "text.quote")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color(hex: 0x285F56))
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Color(hex: 0xFFFAF0).opacity(0.96), in: Capsule())
                    .padding(14)
            }
    }

    private var copy: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(ReadingRoomL10n.text("agenda.eyebrow"))
                .font(.caption2.weight(.semibold)).tracking(1.4).foregroundStyle(style.accent)
            Text(ReadingRoomL10n.text("agenda.title"))
                .font(.system(.largeTitle, design: .serif, weight: .semibold))
                .foregroundStyle(style.ink).accessibilityAddTraits(.isHeader)
            Text(ReadingRoomL10n.text("agenda.emphasis"))
                .font(.system(.title2, design: .serif).italic()).foregroundStyle(style.accent)
            Text(ReadingRoomL10n.text("agenda.body"))
                .font(.subheadline).lineSpacing(4).foregroundStyle(style.muted)
            Button(action: onOpen) {
                Label(ReadingRoomL10n.text("agenda.discover"), systemImage: "arrow.right")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(ReadingRoomButtonStyle())
            .accessibilityIdentifier("home.agenda.discover")
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
