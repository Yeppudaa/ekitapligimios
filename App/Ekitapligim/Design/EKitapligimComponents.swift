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
                .foregroundStyle(EKitapligimPalette.forumMuted)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(blocks) { block in
                    if block.isSeparator {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [EKitapligimPalette.forumTeal.opacity(0.15), EKitapligimPalette.forumGold.opacity(0.35)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(height: 1.5)
                            .padding(.vertical, 4)
                    } else if block.isHeading {
                        Text(block.text)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(EKitapligimPalette.forumInk)
                    } else if block.isBullet {
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(EKitapligimPalette.forumTeal)
                                .frame(width: 6, height: 6)
                                .padding(.top, 7)
                            Text(block.text)
                                .font(.body)
                                .foregroundStyle(EKitapligimPalette.forumInk.opacity(0.92))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        Text(block.text)
                            .font(.body)
                            .foregroundStyle(EKitapligimPalette.forumInk.opacity(0.92))
                            .lineSpacing(3)
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

    /// Warm cream forum background used by community and thread screens.
    func forumPageBackground() -> some View {
        background(EKitapligimPalette.forumPageGradient.ignoresSafeArea())
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

// MARK: - Okur Sohbeti

/// Compact message row used by the home-screen chat preview card.
struct EKChatPreviewMessageRow: View {
    let message: ChatMessageDTO

    private var previewBubbleShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 12,
            bottomLeadingRadius: 4,
            bottomTrailingRadius: 12,
            topTrailingRadius: 12,
            style: .continuous
        )
    }

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            EKAvatar(
                urlString: message.avatarUrl,
                username: message.username,
                size: 30,
                background: message.isMine ? EKitapligimPalette.chatTealSoft : Color(hex: 0xEDF4F4),
                foreground: EKitapligimPalette.chatTeal
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(message.username)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(message.isBot ? Color(hex: 0x95610A) : EKitapligimPalette.chatTeal)
                        .lineLimit(1)
                    if message.isAdmin || message.isModerator || message.isStaff {
                        Text(roleLabel)
                            .font(.system(size: 7, weight: .heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(EKitapligimPalette.chatAmber, in: Capsule())
                    }
                    Spacer(minLength: 0)
                    Text(EKitapligimFormat.relativeTime(message.messageDate))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(EKitapligimPalette.chatMuted)
                }

                Text(EKitapligimFormat.plainText(message.message))
                    .font(.caption)
                    .foregroundStyle(EKitapligimPalette.chatInk)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(previewBubbleColor, in: previewBubbleShape)
                    .overlay {
                        if !message.isMine {
                            previewBubbleShape.stroke(EKitapligimPalette.chatBorder, lineWidth: 0.75)
                        }
                    }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var roleLabel: String {
        if message.isAdmin { return L10n.chatRoleAdmin }
        return L10n.chatRoleModerator
    }

    private var previewBubbleColor: Color {
        if message.isMine { return EKitapligimPalette.chatTealSoft }
        if message.isBot { return EKitapligimPalette.chatBotBubble }
        return .white
    }
}

/// Home-screen chat preview with a gradient header and live message snippets.
struct EKChatHomePreviewCard: View {
    let roomName: String
    let roomDescription: String
    let onlineCount: Int
    let messages: [ChatMessageDTO]
    let emptyMessage: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                header
                Divider().overlay(EKitapligimPalette.chatBorder)
                messageSection
                footer
            }
            .background(
                LinearGradient(
                    colors: [.white, Color(hex: 0xF4FBFB), Color(hex: 0xFFFCF6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [EKitapligimPalette.chatTeal.opacity(0.28), Color(hex: 0xE4C184).opacity(0.35)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: EKitapligimPalette.chatTeal.opacity(0.10), radius: 14, y: 6)
        }
        .buttonStyle(.plain)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(
                    LinearGradient(
                        colors: [EKitapligimPalette.chatTeal, Color(hex: 0x046B70)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(roomName)
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(EKitapligimPalette.chatInk)
                    .lineLimit(1)
                Text(roomDescription)
                    .font(.caption2)
                    .foregroundStyle(EKitapligimPalette.chatMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            EKLiveBadge(title: L10n.chatLiveBadge, onDark: false, showsPulse: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private var messageSection: some View {
        if messages.isEmpty {
            HStack(spacing: 10) {
                Image(systemName: "ellipsis.bubble.fill")
                    .font(.title3)
                    .foregroundStyle(EKitapligimPalette.chatTeal.opacity(0.55))
                Text(emptyMessage)
                    .font(.caption)
                    .foregroundStyle(EKitapligimPalette.chatMuted)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        } else {
            VStack(spacing: 10) {
                ForEach(Array(messages.suffix(2))) { message in
                    EKChatPreviewMessageRow(message: message)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            if onlineCount > 0 {
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color(hex: 0x1CB879))
                        .frame(width: 6, height: 6)
                    Text(L10n.chatOnlineCount(onlineCount))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color(hex: 0x08734E))
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color(hex: 0xE5FAF1), in: Capsule())
            }

            Spacer(minLength: 0)

            HStack(spacing: 5) {
                Text(actionTitle)
                    .font(.caption.weight(.bold))
                Image(systemName: "arrow.right")
                    .font(.caption2.weight(.bold))
            }
            .foregroundStyle(EKitapligimPalette.chatTeal)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(EKitapligimPalette.chatTealSoft, in: Capsule())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.72))
    }
}

// MARK: - Kitap İstekleri

/// Generated book cover tile used across request lists and the home preview card.
struct EKBookRequestCover: View {
    let title: String
    let author: String
    let seed: String
    var width: CGFloat = 82
    var height: CGFloat = 116

    private static let palettes: [(Color, Color)] = [
        (Color(hex: 0xE9D2A0), Color(hex: 0x9D7444)),
        (Color(hex: 0x7A1E1E), Color(hex: 0x2B1012)),
        (Color(hex: 0x8FB2BE), Color(hex: 0x183140)),
        (Color(hex: 0x102D5A), Color(hex: 0x051326)),
        (Color(hex: 0xE5ECE9), Color(hex: 0x8A948D))
    ]

    var body: some View {
        let palette = Self.palettes[abs(seed.hashValue) % Self.palettes.count]
        ZStack {
            RoundedRectangle(cornerRadius: width > 70 ? 8 : 7, style: .continuous)
                .fill(LinearGradient(colors: [palette.0, palette.1], startPoint: .top, endPoint: .bottom))
            Canvas { context, size in
                let glowRect = CGRect(
                    x: size.width * 0.28,
                    y: -size.height * 0.32,
                    width: size.width,
                    height: size.width
                )
                context.fill(Path(ellipseIn: glowRect), with: .color(.white.opacity(0.13)))
                var highlight = Path()
                highlight.move(to: CGPoint(x: 0, y: size.height * 0.72))
                highlight.addLine(to: CGPoint(x: size.width, y: size.height * 0.52))
                context.stroke(highlight, with: .color(.white.opacity(0.18)), lineWidth: 1)
            }
            .allowsHitTesting(false)
            VStack(spacing: width > 70 ? 8 : 5) {
                Text(String(title.uppercased().prefix(width > 70 ? 38 : 24)))
                    .font(.system(width > 70 ? .subheadline : .caption2, design: .serif).weight(.heavy))
                    .foregroundStyle(.white.opacity(0.94))
                    .multilineTextAlignment(.center)
                    .lineLimit(width > 70 ? 4 : 3)
                Spacer(minLength: 0)
                Text(String(author.uppercased().prefix(width > 70 ? 20 : 14)))
                    .font(width > 70 ? .caption.weight(.bold) : .system(size: 8, weight: .bold))
                    .foregroundStyle(.white.opacity(0.80))
                    .lineLimit(1)
            }
            .padding(width > 70 ? 8 : 6)
        }
        .frame(width: width, height: height)
        .shadow(color: palette.1.opacity(0.28), radius: 6, y: 3)
        .accessibilityHidden(true)
    }
}

struct EKBookRequestStatusPill: View {
    let status: String
    var compact: Bool = false
    var showsBookHint: Bool = false

    private var tone: Color {
        switch status.uppercased() {
        case "ACQUIRED": Color(hex: 0x07968E)
        case "REJECTED": Color(hex: 0xD34B4B)
        default: Color(hex: 0x3C73E8)
        }
    }

    private var iconName: String {
        switch status.uppercased() {
        case "ACQUIRED": "checkmark.circle.fill"
        case "REJECTED": "xmark.circle.fill"
        default: "circle.fill"
        }
    }

    var body: some View {
        HStack(spacing: compact ? 4 : 6) {
            Image(systemName: iconName)
                .font(.system(size: compact ? 10 : 15, weight: .bold))
            Text(L10n.bookRequestsStatus(status))
                .font(compact ? .caption2.weight(.bold) : .subheadline.weight(.bold))
                .lineLimit(1)
            if showsBookHint {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
            }
        }
        .foregroundStyle(tone)
        .padding(.horizontal, compact ? 7 : 10)
        .padding(.vertical, compact ? 4 : 5)
        .background(tone.opacity(0.14), in: RoundedRectangle(cornerRadius: compact ? 7 : 8, style: .continuous))
    }
}

/// Compact featured request row for the home preview card.
struct EKBookRequestPreviewRow: View {
    let request: BookRequestDTO
    var compact: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: compact ? 10 : 12) {
            EKBookRequestCover(
                title: request.title,
                author: request.author,
                seed: request.id + request.title,
                width: compact ? 52 : 68,
                height: compact ? 74 : 96
            )

            VStack(alignment: .leading, spacing: compact ? 4 : 6) {
                if !compact {
                    Text(L10n.homeRequestCenterLatestLabel)
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(Color(hex: 0xD45F7A))
                        .textCase(.uppercase)
                        .tracking(0.4)
                }

                Text(request.title)
                    .font(compact ? .caption.weight(.bold) : .subheadline.weight(.heavy))
                    .foregroundStyle(EKitapligimPalette.ink)
                    .lineLimit(compact ? 1 : 2)
                    .multilineTextAlignment(.leading)

                Text(L10n.bookRequestsAuthorLine(request.author))
                    .font(compact ? .caption2 : .caption)
                    .foregroundStyle(EKitapligimPalette.muted)
                    .lineLimit(1)

                if !compact, !request.requestedBy.isEmpty {
                    Text(L10n.bookRequestsRequestedBy(request.requestedBy))
                        .font(.caption2)
                        .foregroundStyle(EKitapligimPalette.muted)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    EKBookRequestStatusPill(
                        status: request.status,
                        compact: true,
                        showsBookHint: request.fulfilledBookID != nil
                    )
                    HStack(spacing: 4) {
                        Image(systemName: "hand.thumbsup.fill")
                            .font(.caption2.weight(.semibold))
                        Text(L10n.bookRequestsVoteCount(request.voteCount))
                            .font(.caption2.weight(.bold))
                    }
                    .foregroundStyle(Color(hex: 0x1954C8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(hex: 0xF1F5FF), in: Capsule())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Home-screen book request center preview with the latest community requests.
struct EKBookRequestHomePreviewCard: View {
    let requests: [BookRequestDTO]
    let title: String
    let subtitle: String
    let emptyMessage: String
    let actionTitle: String
    let action: () -> Void

    private let accent = Color(hex: 0xD45F7A)
    private let accentDeep = Color(hex: 0xB84562)

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                header
                Divider().overlay(Color(hex: 0xF0D8DF))
                requestSection
                footer
            }
            .background(
                LinearGradient(
                    colors: [.white, Color(hex: 0xFFF7F9), Color(hex: 0xFFFCF8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [accent.opacity(0.30), Color(hex: 0xE4C184).opacity(0.28)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: accent.opacity(0.12), radius: 14, y: 6)
        }
        .buttonStyle(.plain)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "heart.text.square.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(
                    LinearGradient(
                        colors: [accent, accentDeep],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(EKitapligimPalette.ink)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(EKitapligimPalette.muted)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 0)

            EKPill(
                title: L10n.homeDiscoveryRequestsBadge,
                foreground: accentDeep,
                background: accent.opacity(0.12)
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private var requestSection: some View {
        if let latest = requests.first {
            VStack(spacing: 10) {
                EKBookRequestPreviewRow(request: latest)

                if requests.count > 1 {
                    ForEach(Array(requests.dropFirst().prefix(1))) { request in
                        EKBookRequestPreviewRow(request: request, compact: true)
                            .padding(.top, 2)
                            .overlay(alignment: .top) {
                                Rectangle()
                                    .fill(Color(hex: 0xF0D8DF))
                                    .frame(height: 0.5)
                                    .offset(y: -5)
                            }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        } else {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: 0xF8E8EC), Color(hex: 0xF2D4DC)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "book.closed.fill")
                        .font(.title3)
                        .foregroundStyle(accent.opacity(0.55))
                }
                .frame(width: 52, height: 74)

                Text(emptyMessage)
                    .font(.caption)
                    .foregroundStyle(EKitapligimPalette.muted)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            if !requests.isEmpty {
                HStack(spacing: 5) {
                    Image(systemName: "person.3.fill")
                        .font(.caption2.weight(.semibold))
                    Text(L10n.homeRequestCenterCommunityFeed)
                        .font(.caption2.weight(.bold))
                }
                .foregroundStyle(accentDeep)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(accent.opacity(0.10), in: Capsule())
            }

            Spacer(minLength: 0)

            HStack(spacing: 5) {
                Text(actionTitle)
                    .font(.caption.weight(.bold))
                Image(systemName: "plus")
                    .font(.caption2.weight(.bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                LinearGradient(
                    colors: [Color(hex: 0xFFA122), Color(hex: 0xE07700)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: Capsule()
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.72))
    }
}

// MARK: - Forum

struct EKForumMetricPill: View {
    let systemImage: String
    let value: Int
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: compact ? 10 : 13, weight: .semibold))
            Text(EKitapligimFormat.count(value))
                .font(.system(size: compact ? 9 : 10, weight: .bold))
        }
        .foregroundStyle(EKitapligimPalette.forumTeal)
        .padding(.horizontal, compact ? 6 : 7)
        .padding(.vertical, compact ? 3 : 4)
        .background(EKitapligimPalette.forumGoldSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(hex: 0xE8E2D2), lineWidth: 0.75)
        }
    }
}

/// Forum category card used on the community tab.
struct EKForumListCard: View {
    let forum: ForumDTO

    private var iconName: String {
        forum.isBookForum == true ? "books.vertical.fill" : "text.bubble.fill"
    }

    private var accent: Color {
        forum.isBookForum == true ? EKitapligimPalette.forumBlue : EKitapligimPalette.forumTeal
    }

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [accent, accent.opacity(0.55)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 4, height: 58)

            Image(systemName: iconName)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(
                    LinearGradient(
                        colors: [accent, accent.opacity(0.78)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .shadow(color: accent.opacity(0.22), radius: 6, y: 3)

            VStack(alignment: .leading, spacing: 5) {
                Text(forum.title)
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(EKitapligimPalette.forumInk)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if !forum.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(forum.description)
                        .font(.caption)
                        .foregroundStyle(EKitapligimPalette.forumMuted)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                if let count = forum.threadCount, count > 0 {
                    HStack(spacing: 5) {
                        Image(systemName: "text.alignleft")
                            .font(.caption2.weight(.semibold))
                        Text(L10n.forumThreadsHeroMetricLabel)
                            .font(.caption2.weight(.bold))
                        Text(EKitapligimFormat.count(count))
                            .font(.caption2.weight(.heavy))
                    }
                    .foregroundStyle(accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(accent.opacity(0.10), in: Capsule())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(EKitapligimPalette.forumMuted.opacity(0.8))
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [.white, accent.opacity(0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(EKitapligimPalette.forumBorder, lineWidth: 1)
        }
        .shadow(color: accent.opacity(0.08), radius: 10, y: 4)
    }
}

/// Thread row card used in forum thread lists.
struct EKForumThreadRow: View {
    let thread: ForumThreadDTO

    private var displayUsername: String {
        ForumMessageFormatting.displayUsername(thread.username)
    }

    private var initial: String {
        String(displayUsername.prefix(1)).uppercased(with: EKitapligimFormat.locale)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(initial)
                .font(.system(.title3, design: .serif).weight(.heavy))
                .foregroundStyle(EKitapligimPalette.forumTeal)
                .frame(width: 48, height: 48)
                .background(
                    LinearGradient(
                        colors: [EKitapligimPalette.forumTealSoft, Color(hex: 0xFFF8EA)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(EKitapligimPalette.forumBorder, lineWidth: 0.75)
                }

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 6) {
                    if thread.isSticky {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 5)
                            .background(EKitapligimPalette.forumGold, in: Capsule())
                            .accessibilityLabel(L10n.forumThreadsSticky)
                    }
                    Text(thread.title)
                        .font(.system(.headline, design: .serif).weight(.bold))
                        .foregroundStyle(EKitapligimPalette.forumInk)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(spacing: 6) {
                    Text(displayUsername)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(EKitapligimPalette.forumMuted)
                        .lineLimit(1)
                    if thread.postDate > 0 {
                        Text("·")
                            .foregroundStyle(EKitapligimPalette.forumMuted.opacity(0.6))
                        Text(EKitapligimFormat.relativeTime(thread.postDate))
                            .font(.caption2)
                            .foregroundStyle(EKitapligimPalette.forumMuted)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    EKForumMetricPill(systemImage: "bubble.left", value: thread.replyCount, compact: true)
                    EKForumMetricPill(systemImage: "eye", value: thread.viewCount, compact: true)
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(EKitapligimPalette.forumMuted.opacity(0.75))
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [.white, EKitapligimPalette.forumTealSoft.opacity(0.35)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(EKitapligimPalette.forumBorder, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)
    }
}

/// Compact action row for community shortcuts.
struct EKForumActionRow: View {
    let title: String
    let systemImage: String
    var tint: Color = EKitapligimPalette.forumTeal

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 38, height: 38)
                .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(EKitapligimPalette.forumInk)
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.bold))
                .foregroundStyle(EKitapligimPalette.forumMuted)
        }
        .padding(14)
        .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(EKitapligimPalette.forumBorder, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.03), radius: 6, y: +2)
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
