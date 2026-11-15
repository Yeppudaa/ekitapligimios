import SwiftUI
import EkitapligimCore

/// Information only: its actions open existing destinations. No StoreKit dependency.
struct BookRequestAccessView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var typeSize
    let presentation: BookRequestAccessPresentation
    let onClose: () -> Void
    let onPremium: () -> Void
    let onCatalog: () -> Void
    let onAudio: () -> Void
    private var style: ReadingRoomStyle { ReadingRoomStyle(scheme: scheme) }
    private var exhausted: Bool { presentation.quota != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    lead
                    if !exhausted { benefits }
                }
                .frame(maxWidth: 800).padding(18).frame(maxWidth: .infinity)
            }
            .background(style.page.ignoresSafeArea())
            .navigationTitle(ReadingRoomL10n.text("request.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(style.page, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(scheme, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: onClose) {
                        Image(systemName: "xmark").frame(width: 44, height: 44)
                    }
                    .foregroundStyle(style.muted)
                    .accessibilityLabel(L10n.commonClose)
                    .accessibilityIdentifier("requests.access.close")
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button(action: exhausted ? onCatalog : onPremium) {
                    HStack(spacing: 12) {
                        Text(ReadingRoomL10n.text(exhausted ? "request.catalog" : "request.upgrade"))
                        Spacer(minLength: 8)
                        Image(systemName: "arrow.right").accessibilityHidden(true)
                    }.frame(maxWidth: .infinity)
                }
                .buttonStyle(ReadingRoomButtonStyle(gold: !exhausted))
                .accessibilityIdentifier("requests.access.primary")
                .frame(maxWidth: 800).padding(.horizontal, 20).padding(.vertical, 12)
                .frame(maxWidth: .infinity).background(style.page)
            }
        }
        .accessibilityIdentifier("requests.access")
    }

    private var lead: some View {
        VStack(alignment: .leading, spacing: 0) {
            ReadingRoomArtwork(name: exhausted ? "request_quota_reading" : "request_premium_reading", height: 200)
            VStack(alignment: .leading, spacing: 20) {
                Label(ReadingRoomL10n.text("request.membership"), systemImage: "crown")
                    .font(.caption.weight(.semibold)).tracking(1.5)
                    .foregroundStyle(exhausted ? style.accent : ReadingRoomStyle.gold)
                VStack(alignment: .leading, spacing: 0) {
                    Text(ReadingRoomL10n.text(exhausted ? "request.exhausted" : "request.lead"))
                        .foregroundStyle(exhausted ? style.ink : .white)
                    Text(ReadingRoomL10n.text(exhausted ? "request.exhaustedEmphasis" : "request.emphasis"))
                        .foregroundStyle(exhausted ? style.accent : ReadingRoomStyle.gold)
                }
                .font(.system(.largeTitle, design: .serif, weight: .semibold))
                .accessibilityElement(children: .combine).accessibilityAddTraits(.isHeader)
                Text(ReadingRoomL10n.text(exhausted ? "request.exhaustedBody" : "request.body"))
                    .font(.body).lineSpacing(5).foregroundStyle(exhausted ? style.muted : Color(hex: 0xE6EFE4))
                if let quota = presentation.quota {
                    quotaCard(quota)
                    Button(action: onAudio) {
                        Label(ReadingRoomL10n.text("request.audio"), systemImage: "headphones")
                            .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 48)
                    }.buttonStyle(.plain).foregroundStyle(style.accent)
                        .accessibilityIdentifier("requests.access.audio")
                } else {
                    Label(ReadingRoomL10n.text("request.renew"), systemImage: "calendar")
                        .font(.caption).foregroundStyle(ReadingRoomStyle.gold)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(24).frame(maxWidth: .infinity, alignment: .leading)
            .background(exhausted ? style.card : Color(hex: 0x1D4C43))
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 24).strokeBorder(style.border) }
    }

    private func quotaCard(_ quota: BookRequestQuotaDTO) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Label(ReadingRoomL10n.text("request.quota"), systemImage: "hourglass")
                .font(.caption.weight(.semibold)).tracking(1)
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 8) { quotaValue(quota); remainingLabel }
                VStack(alignment: .leading, spacing: 6) { quotaValue(quota); remainingLabel }
            }
            ProgressView(value: Double(max(0, min(quota.used, quota.limit))), total: Double(max(1, quota.limit)))
                .tint(style.accent)
                .accessibilityLabel(ReadingRoomL10n.text("request.quota"))
            if let renewal = presentation.renewalLabel() {
                Label {
                    Text("\(ReadingRoomL10n.text("request.renewal")) · \(renewal)")
                } icon: { Image(systemName: "calendar") }
                .font(.caption).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("requests.access.renewal")
            }
        }
        .foregroundStyle(style.ink).padding(18).frame(maxWidth: .infinity, alignment: .leading)
        .background(style.soft, in: RoundedRectangle(cornerRadius: 20))
        .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(style.border) }
    }

    private func quotaValue(_ quota: BookRequestQuotaDTO) -> some View {
        Text("\(max(0, quota.remaining)) / \(max(0, quota.limit))")
            .font(.system(.largeTitle, design: .serif)).monospacedDigit()
    }
    private var remainingLabel: some View {
        Text(ReadingRoomL10n.text("request.remaining")).font(.caption).foregroundStyle(style.muted)
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(ReadingRoomL10n.text("request.benefits"))
                .font(.system(.title2, design: .serif, weight: .semibold))
                .foregroundStyle(style.ink).accessibilityAddTraits(.isHeader)
            LazyVGrid(columns: typeSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.adaptive(minimum: 250), spacing: 14)], spacing: 14) {
                benefit("requests", artwork: "request_quota_reading")
                benefit("downloads", artwork: "request_premium_reading")
                benefit("audio", artwork: "request_audio_journey")
                benefit("profile", artwork: nil)
            }
        }
    }

    private func benefit(_ key: String, artwork: String?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let artwork {
                ReadingRoomArtwork(name: artwork, height: 140)
            } else {
                Image(systemName: "crown.fill")
                    .font(.system(size: 30)).foregroundStyle(ReadingRoomStyle.gold)
                    .padding(22).background(.white.opacity(0.1), in: Circle())
                    .frame(maxWidth: .infinity).frame(height: 140)
                    .background(Color(hex: 0x1D4C43))
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(ReadingRoomL10n.text("request.benefit.\(key)"))
                    .font(.headline).foregroundStyle(style.ink)
                Text(ReadingRoomL10n.text("request.benefit.\(key)Body"))
                    .font(.subheadline).foregroundStyle(style.muted).lineSpacing(3)
            }.fixedSize(horizontal: false, vertical: true).padding(18)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(style.card, in: RoundedRectangle(cornerRadius: 20))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(style.border) }
    }
}
