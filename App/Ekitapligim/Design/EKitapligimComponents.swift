import SwiftUI
import EkitapligimCore

// MARK: - Biçimlendiriciler

enum EKitapligimFormat {
    static let locale = Locale(identifier: "tr_TR")

    /// Groups thousands the Turkish way, e.g. 15507 -> "15.507".
    static func count(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    /// Compact site statistics, e.g. 14660 -> "14K+".
    static func compactCount(_ value: Int) -> String {
        if value >= 1_000_000 { return "\(value / 1_000_000)M+" }
        if value >= 1_000 { return "\(value / 1_000)K+" }
        if value > 0 { return "\(value)+" }
        return "0"
    }

    static func date(_ timestamp: Int) -> String? {
        guard timestamp > 0 else { return nil }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(timestamp)))
    }

    static func shortDate(_ timestamp: Int) -> String {
        guard timestamp > 0 else { return "" }
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.locale = locale
        let calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = calendar.component(.year, from: date) == calendar.component(.year, from: Date())
            ? "d MMM"
            : "d MMM yyyy"
        return formatter.string(from: date)
    }

    static func clockTime(_ timestamp: Int) -> String {
        guard timestamp > 0 else { return L10n.chatTimeNow }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(timestamp)))
    }

    /// Mirrors the Android relative timestamps: Az önce / n dk önce / n sa önce / n gün önce.
    static func relativeTime(_ timestamp: Int, dayCutoff: Int = 7) -> String {
        CommunityRelativeTimeFormatting.format(timestampSeconds: timestamp, dayCutoff: dayCutoff)
    }

    /// Reading duration in the Android format, e.g. "2 sa 15 dk".
    static func readingMinutes(_ minutes: Int) -> String {
        if minutes <= 0 { return L10n.readingMinutesShort(0) }
        let hours = minutes / 60
        let remainder = minutes % 60
        if hours == 0 { return L10n.readingMinutesShort(remainder) }
        if remainder == 0 { return L10n.readingHoursShort(hours) }
        return "\(L10n.readingHoursShort(hours)) \(L10n.readingMinutesShort(remainder))"
    }

    static func badgeText(_ count: Int) -> String {
        count > 99 ? "99+" : String(count)
    }

    /// The API sometimes returns HTML fragments; feeds show plain text only.
    static func plainText(_ html: String) -> String {
        var text = html.replacingOccurrences(of: "<br />", with: "\n")
        text = text.replacingOccurrences(of: "<br>", with: "\n")
        text = text.replacingOccurrences(of: "</p>", with: "\n")
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        let entities = [
            "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"",
            "&#039;": "'", "&apos;": "'", "&nbsp;": " "
        ]
        for (entity, replacement) in entities {
            text = text.replacingOccurrences(of: entity, with: replacement)
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Küçük yapı taşları

struct EKPill: View {
    let title: String
    var systemImage: String? = nil
    var foreground: Color = EKitapligimPalette.tealDark
    var background: Color = EKitapligimPalette.tealSoft
    var borderColor: Color? = nil

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage).font(.caption2.weight(.bold))
            }
            Text(title)
                .font(.caption2.weight(.bold))
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(background, in: Capsule())
        .overlay {
            if let borderColor {
                Capsule().stroke(borderColor)
            }
        }
    }
}

struct ForumMessageBody: View {
    let message: String

    private var blocks: [ForumMessageBlock] {
        ForumMessageFormatting.blocks(from: message)
    }

    var body: some View {
        if blocks.isEmpty {
            Text(L10n.forumMessageEmpty)
                .font(.body)
                .foregroundStyle(Color(hex: 0x6E7482))
        } else {
            VStack(alignment: .leading, spacing: 11) {
                ForEach(blocks) { block in
                    if block.isSeparator {
                        Rectangle()
                            .fill(Color(hex: 0x087A80))
                            .frame(height: 1.5)
                            .padding(.vertical, 6)
                    } else if block.isHeading {
                        Text(block.text)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Color(hex: 0x0E1B2B))
                    } else if block.isBullet {
                        Text(block.text)
                            .font(.body)
                            .foregroundStyle(Color(hex: 0x242A38))
                            .padding(.leading, 4)
                    } else {
                        Text(block.text)
                            .font(.body)
                            .foregroundStyle(Color(hex: 0x242A38))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }
}

struct EKChip: View {
    let title: String
    var systemImage: String? = nil
    let isSelected: Bool
    var selectedBackground: Color = EKitapligimPalette.profileTealDeep
    var selectedForeground: Color = .white
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.caption.weight(.semibold))
                }
                Text(title)
                    .font(.subheadline.weight(.bold))
            }
            .foregroundStyle(isSelected ? selectedForeground : Color(hex: 0x425C63))
            .padding(.horizontal, 15)
            .padding(.vertical, 9)
            .background(isSelected ? AnyShapeStyle(selectedBackground) : AnyShapeStyle(Color.white), in: Capsule())
            .overlay {
                if !isSelected {
                    Capsule().stroke(Color(hex: 0xD9E5E7))
                }
            }
            .opacity(isEnabled ? 1 : 0.55)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

struct EKUnreadBadge: View {
    let count: Int
    var background: Color = EKitapligimPalette.amber

    var body: some View {
        if count > 0 {
            Text(EKitapligimFormat.badgeText(count))
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(background, in: Capsule())
                .accessibilityLabel(L10n.unreadCountAccessibility(count))
        }
    }
}

/// Remote avatar that falls back to the member's initial, matching the Android circle/rounded tiles.
struct EKAvatar: View {
    let urlString: String?
    let username: String
    var size: CGFloat = 44
    var cornerRadius: CGFloat? = nil
    var background: Color = EKitapligimPalette.tealSoft
    var foreground: Color = EKitapligimPalette.teal

    private var shape: AnyShape {
        if let cornerRadius {
            return AnyShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        return AnyShape(Circle())
    }

    private var secureURL: URL? {
        guard let urlString, !urlString.isEmpty,
              let url = URL(string: urlString),
              url.scheme?.lowercased() == "https" else { return nil }
        return url
    }

    private var initial: String {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "E" }
        return String(first).uppercased(with: EKitapligimFormat.locale)
    }

    var body: some View {
        Group {
            if let secureURL {
                AsyncImage(url: secureURL) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill()
                    default: placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .background(background)
        .clipShape(shape)
        .accessibilityLabel(L10n.profilePhotoAccessibility(username))
        .accessibilityHidden(secureURL == nil)
    }

    private var placeholder: some View {
        Text(initial)
            .font(.system(size: size * 0.42, weight: .bold))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EKProgressRing: View {
    let progress: Double
    var size: CGFloat = 70
    var lineWidth: CGFloat = 7
    var tint: Color = EKitapligimPalette.profileSuccess
    var track: Color = Color(hex: 0xE4EEEE)

    var body: some View {
        ZStack {
            Circle().stroke(track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0, min(progress, 1)))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("%\(Int((max(0, min(progress, 1)) * 100).rounded()))")
                .font(.caption.weight(.heavy))
                .foregroundStyle(EKitapligimPalette.profileInk)
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel(L10n.readingGoalProgressAccessibility(Int((max(0, min(progress, 1)) * 100).rounded())))
    }
}

/// Empty / error / offline placeholder used by the feed screens.
struct EKStateCard: View {
    let title: String
    var message: String? = nil
    var retryTitle: String? = nil
    var retry: (() -> Void)? = nil
    var systemImage: String? = nil

    var body: some View {
        VStack(spacing: 8) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 34))
                    .foregroundStyle(EKitapligimPalette.agendaPurple)
            }
            Text(title)
                .font(.headline)
                .foregroundStyle(EKitapligimPalette.agendaInk)
                .multilineTextAlignment(.center)
            if let message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(EKitapligimPalette.agendaMuted)
                    .multilineTextAlignment(.center)
            }
            if let retryTitle, let retry {
                Button(retryTitle, action: retry)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(EKitapligimPalette.teal)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(systemImage == nil ? 24 : 28)
        .ekitapligimCard()
    }
}

struct EKInlineError: View {
    let message: String
    var retryTitle: String? = nil
    var retry: (() -> Void)? = nil
    var showsIcon: Bool = true

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            if showsIcon {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(EKitapligimPalette.warningInk)
            }
            Text(message)
                .font(.caption)
                .foregroundStyle(EKitapligimPalette.warningInk)
            Spacer(minLength: 0)
            if let retryTitle, let retry {
                Button(retryTitle, action: retry)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(EKitapligimPalette.warningInk)
            }
        }
        .padding(12)
        .background(EKitapligimPalette.warningBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(EKitapligimPalette.warningBorder)
        }
    }
}

/// Gold spline decoration used on Android forum hero cards.
struct EKForumGoldDecoration: View {
    var body: some View {
        Canvas { context, size in
            let gold = Color(hex: 0xE2B866)
            for index in 0..<4 {
                let y = size.height * (0.18 + Double(index) * 0.085)
                var path = Path()
                path.move(to: CGPoint(x: size.width * 0.70, y: y))
                path.addCurve(
                    to: CGPoint(x: size.width, y: y - 24),
                    control1: CGPoint(x: size.width * 0.82, y: y - 30),
                    control2: CGPoint(x: size.width * 0.90, y: y + 28)
                )
                context.stroke(path, with: .color(gold.opacity(0.28)), lineWidth: 1)
            }
            let crossCenters: [CGPoint] = [
                CGPoint(x: size.width * 0.80, y: size.height * 0.25),
                CGPoint(x: size.width * 0.84, y: size.height * 0.17),
                CGPoint(x: size.width * 0.88, y: size.height * 0.12)
            ]
            for (index, center) in crossCenters.enumerated() {
                let radius = CGFloat(4 + index)
                var horizontal = Path()
                horizontal.move(to: CGPoint(x: center.x - radius, y: center.y))
                horizontal.addLine(to: CGPoint(x: center.x + radius, y: center.y))
                var vertical = Path()
                vertical.move(to: CGPoint(x: center.x, y: center.y - radius))
                vertical.addLine(to: CGPoint(x: center.x, y: center.y + radius))
                context.stroke(horizontal, with: .color(gold.opacity(0.65)), lineWidth: 1)
                context.stroke(vertical, with: .color(gold.opacity(0.65)), lineWidth: 1)
            }
        }
        .allowsHitTesting(false)
    }
}

extension View {
    /// Cream gradient + gold trim matching Android `ForumThreadsHero`.
    func forumHeroSurface(radius: CGFloat = 16) -> some View {
        background {
            ZStack {
                LinearGradient(
                    colors: [.white, Color(hex: 0xF2FAF9), Color(hex: 0xFFF8EC)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                EKForumGoldDecoration()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(Color(hex: 0xE4C184), lineWidth: 1)
        }
    }

    /// Caps `TextEditor` so a bottom `safeAreaInset` cannot eat the thread/message list.
    func ekPinnedReplyEditor() -> some View {
        frame(minHeight: 76, maxHeight: 128)
    }

    /// Sizes the pinned reply bar to its content instead of the remaining screen.
    func ekPinnedReplyBar() -> some View {
        fixedSize(horizontal: false, vertical: true)
    }
}

/// The feeds page with an explicit button rather than scroll-edge loading, mirroring Android.
struct EKLoadMoreButton: View {
    let isLoading: Bool
    var title: String = L10n.commonLoadMore
    var loadingTitle: String = L10n.commonLoading
    var tint: Color = EKitapligimPalette.teal
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView().tint(.white).controlSize(.small)
                }
                Text(isLoading ? loadingTitle : title)
                    .font(.subheadline.weight(.bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(tint)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}

/// The pulsing "CANLI" badge Android shows above live feeds.
struct EKLiveBadge: View {
    var title: String = L10n.liveActivityBadge
    var onDark: Bool = true
    var showsPulse: Bool = false

    @State private var pulse = false

    var body: some View {
        HStack(spacing: 5) {
            ZStack {
                if showsPulse {
                    Circle()
                        .fill(onDark ? Color.white.opacity(0.35) : EKitapligimPalette.liveDot.opacity(0.35))
                        .frame(width: pulse ? 14 : 6, height: pulse ? 14 : 6)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)
                }
                Circle()
                    .fill(onDark ? Color.white : EKitapligimPalette.liveDot)
                    .frame(width: 6, height: 6)
            }
            Text(title)
                .font(.system(size: 9, weight: .heavy))
                .tracking(0.6)
        }
        .foregroundStyle(onDark ? Color.white : EKitapligimPalette.liveBadgeInk)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(onDark ? AnyShapeStyle(Color.white.opacity(0.18)) : AnyShapeStyle(EKitapligimPalette.liveBadgeBackground), in: Capsule())
        .overlay {
            if !onDark {
                Capsule().stroke(EKitapligimPalette.liveBadgeBorder)
            }
        }
        .onAppear {
            guard showsPulse else { return }
            pulse = true
        }
    }
}

/// Cover tile used by the horizontal shelves on Home and Profile.
struct EKShelfCard: View {
    let title: String
    let subtitle: String
    let coverUrl: String
    var width: CGFloat = 124
    var badge: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ZStack(alignment: .topLeading) {
                EKitapligimRemoteCover(urlString: coverUrl)
                    .frame(width: width, height: width * 1.45)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                if let badge {
                    Text(badge)
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(EKitapligimPalette.amber, in: Capsule())
                        .padding(7)
                }
            }
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(EKitapligimPalette.ink)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(EKitapligimPalette.muted)
                    .lineLimit(1)
            }
        }
        .frame(width: width, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct EKSkeletonCard: View {
    var height: CGFloat = 120

    var body: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color(hex: 0xEDF1F3))
            .frame(height: height)
            .accessibilityHidden(true)
    }
}

// MARK: - Profil yapı taşları

struct EKStatCell: View {
    let value: String
    let label: String
    var width: CGFloat = 94

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(Color(hex: 0x153B43))
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(EKitapligimPalette.profileMuted)
                .multilineTextAlignment(.center)
        }
        .frame(width: width)
        .accessibilityElement(children: .combine)
    }
}

struct EKActionTile: View {
    let title: String
    let systemImage: String
    var badgeCount: Int = 0
    var accent: Color = EKitapligimPalette.profileTeal
    var background: Color = .white
    var borderColor: Color = EKitapligimPalette.profileBorder
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(accent)
                    .frame(width: 22)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(EKitapligimPalette.profileInk)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                EKUnreadBadge(count: badgeCount, background: accent)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(borderColor)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(badgeCount > 0 ? "\(title), \(L10n.unreadCountAccessibility(badgeCount))" : title)
    }
}

struct EKInfoRow: View {
    let label: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.subheadline)
                .foregroundStyle(Color(hex: 0x23736F))
                .frame(width: 34, height: 34)
                .background(Color(hex: 0xEAF3F3))
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(EKitapligimPalette.profileMuted)
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(EKitapligimPalette.profileInk)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(EKitapligimPalette.profileSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Daily read/download allowance card, including the unlimited admin and premium variants.
struct EKQuotaCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let trailingValue: String
    let trailingCaption: String
    let progress: Double
    let gradient: LinearGradient
    let isUnlimited: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(.white.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 2) {
                Text(trailingValue)
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(.white)
                Text(trailingCaption)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.82))
            }
        }
        .padding(14)
        .overlay(alignment: .bottom) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.22))
                    Capsule()
                        .fill(isUnlimited ? EKitapligimPalette.profileGold : Color.white)
                        .frame(width: proxy.size.width * max(0, min(progress, 1)))
                }
                .frame(height: 5)
            }
            .frame(height: 5)
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
        }
        .padding(.bottom, 8)
        .background(gradient)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
