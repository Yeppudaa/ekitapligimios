import SwiftUI
import EkitapligimCore

@MainActor
struct ModernSideMenu: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var assistantAvailable = true
    let onSelect: (AppRoute) -> Void
    let onClose: () -> Void
    private let ink = Color(hex: 0x143D43)
    private let muted = Color(hex: 0x6B7F82)
    private let gold = Color(hex: 0xEAC77C)

    private var currentRoute: AppRoute {
        if let route = container.presentedRoute { return route }
        if container.isForumPresented { return .forum }
        switch container.selectedTab {
        case .home: return .home
        case .catalog: return .catalog
        case .agenda: return .bookAgenda
        case .flow: return .liveActivity
        case .requests: return .requests
        case .profile: return .profile
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 530 || dynamicTypeSize.isAccessibilitySize
            VStack(spacing: 0) {
                header(compact: compact)
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        section(ShellRefreshL10n.text("menuExplore"), items: exploration)
                        premiumCard(compact: compact)
                        section(ShellRefreshL10n.text("menuInspiration"), items: inspiration)
                        section(ShellRefreshL10n.text("menuCommunity"), items: community)
                        section(container.isSignedIn ? L10n.menuAccountSection : L10n.menuMembershipSection, items: account)
                        Label(ShellRefreshL10n.text("menuFooter"), systemImage: "sparkle")
                            .font(.caption).foregroundStyle(muted).padding(.horizontal, 8)
                    }
                    .padding(.horizontal, 13).padding(.vertical, 18).padding(.bottom, 24)
                }
                .accessibilityIdentifier("modern-menu-scroll")
            }
            .background(Color(hex: 0xFAFCF7))
        }
        .onReceive(container.assistantModel.$bootstrap) { assistantAvailable = $0?.enabled ?? true }
        .accessibilityAddTraits(.isModal)
    }

    private func header(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack(spacing: 10) {
                Image("menu_logo").resizable().scaledToFit().padding(5)
                    .frame(width: compact ? 38 : 48, height: compact ? 38 : 48)
                    .background(Color(hex: 0x082D34), in: RoundedRectangle(cornerRadius: 14))
                    .overlay { RoundedRectangle(cornerRadius: 14).stroke(gold.opacity(0.65)) }
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.menuBrandTitle).font(.headline).foregroundStyle(.white)
                    if !compact {
                        Text(ShellRefreshL10n.text("menuEyebrow")).font(.caption2.weight(.medium))
                            .tracking(0.7).foregroundStyle(Color(hex: 0xC3D9D2))
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button(action: onClose) {
                    Image(systemName: "xmark").font(.headline).foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(.white.opacity(0.13), in: Circle())
                }
                .buttonStyle(.plain).accessibilityLabel(L10n.menuClose)
                .accessibilityIdentifier("modern-menu-close")
            }
            if !compact {
                Text(ShellRefreshL10n.text("menuHeadline"))
                    .font(.system(.title, design: .serif, weight: .bold))
                    .foregroundStyle(Color(hex: 0xFFF9EB)).fixedSize(horizontal: false, vertical: true)
                Label(ShellRefreshL10n.text("menuTagline"), systemImage: "sparkles")
                    .font(.caption.weight(.semibold)).foregroundStyle(gold)
            }
        }
        .padding(17)
        .background {
            GeometryReader { geometry in
                Image("catalog_scenic_reading").resizable().scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                    .overlay(LinearGradient(colors: [Color(hex: 0x103C41).opacity(0.98), Color(hex: 0x154C50).opacity(0.86), Color(hex: 0x154C50).opacity(0.45)], startPoint: .leading, endPoint: .trailing))
                    .accessibilityHidden(true)
            }
        }
        .clipped()
        .accessibilityIdentifier("modern-menu-header")
    }

    private func section(_ title: String, items: [ModernMenuItem]) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title.uppercased()).font(.caption2.weight(.bold)).tracking(1.4)
                .foregroundStyle(muted).padding(.horizontal, 10).padding(.bottom, 3)
            ForEach(items) { item in
                if item.route != .aiAssistant(bookID: nil) || assistantAvailable { row(item) }
            }
        }
    }

    private func row(_ item: ModernMenuItem) -> some View {
        let selected = ShellMenuSelection.matches(item: item.route, current: currentRoute)
        return Button { onSelect(item.route) } label: {
            HStack(alignment: .center, spacing: 11) {
                Image(systemName: item.icon).font(.body.weight(.semibold)).foregroundStyle(selected ? .white : item.tint)
                    .frame(width: 40, height: 40)
                    .background(selected ? item.tint : item.tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 13))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title).font(.subheadline.weight(.semibold)).foregroundStyle(ink)
                    Text(item.subtitle).font(.caption).foregroundStyle(muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                if let badge = ShellMenuSelection.badge(item.badge) {
                    Text(badge).font(.caption.weight(.bold)).foregroundStyle(.white)
                        .padding(.horizontal, 7).padding(.vertical, 4)
                        .background(Color(hex: 0xD69229), in: Capsule())
                        .accessibilityHidden(true)
                }
                Image(systemName: "chevron.right").font(.caption2.weight(.bold))
                    .foregroundStyle(selected ? EKitapligimPalette.teal : muted.opacity(0.65))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 10).padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
            .background(selected ? Color(hex: 0xE6F1E9) : .clear, in: RoundedRectangle(cornerRadius: 17))
            .overlay { RoundedRectangle(cornerRadius: 17).stroke(selected ? Color(hex: 0xC8DFD2) : .clear) }
            .contentShape(RoundedRectangle(cornerRadius: 17))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.badge > 0 ? "\(item.title), \(L10n.unreadCountAccessibility(item.badge))" : item.title)
        .accessibilityValue(selected ? ShellRefreshL10n.text("selected") : "")
        .accessibilityIdentifier("modern-menu-\(item.route.nativeRoute)")
    }

    private func premiumCard(compact: Bool) -> some View {
        let presentation = PremiumMenuPresentation(isSignedIn: container.isSignedIn,
            isPremium: container.isPremium || container.isAdmin, remainingDays: container.subscription?.remainingDays)
        return Button { onSelect(.premium) } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "rosette").font(.title3).foregroundStyle(Color(hex: 0x6B4B1E))
                        .frame(width: 36, height: 36).background(gold, in: RoundedRectangle(cornerRadius: 12))
                    Text(L10n.premiumShortTitle).font(.headline).foregroundStyle(gold)
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.right").foregroundStyle(gold)
                }
                if presentation.isActive {
                    Label(ShellRefreshL10n.text("premiumActive"), systemImage: "checkmark.seal.fill")
                        .font(.subheadline.weight(.bold)).foregroundStyle(.white)
                    switch presentation.detail {
                    case .days(let days):
                        Label(ShellRefreshL10n.remainingDays(days), systemImage: "clock")
                            .font(.subheadline.weight(.bold)).foregroundStyle(gold)
                            .padding(11).frame(maxWidth: .infinity, alignment: .leading)
                            .background(gold.opacity(0.13), in: RoundedRectangle(cornerRadius: 12))
                    case .active, .promotion:
                        Text(ShellRefreshL10n.text("premiumActiveNote")).font(.caption).foregroundStyle(Color(hex: 0xDAE9E3))
                    }
                } else {
                    if !compact { Text(ShellRefreshL10n.text("premiumHeadline"))
                        .font(.system(.title2, design: .serif, weight: .bold)).foregroundStyle(.white) }
                    Text(ShellRefreshL10n.text("premiumDescription")).font(.caption).foregroundStyle(Color(hex: 0xDAE9E3))
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(17).frame(maxWidth: .infinity, alignment: .leading)
            .background {
                GeometryReader { geometry in
                    Image("audio_shelf_continue").resizable().scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                        .overlay(LinearGradient(colors: [Color(hex: 0x123F43).opacity(0.98), Color(hex: 0x145257).opacity(0.92), Color(hex: 0x145257).opacity(0.68)], startPoint: .leading, endPoint: .trailing))
                        .accessibilityHidden(true)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay { RoundedRectangle(cornerRadius: 22).stroke(gold) }
        }
        .buttonStyle(.plain).accessibilityIdentifier("modern-menu-premium")
    }

    private var exploration: [ModernMenuItem] { [
        .init(.home, L10n.menuHome, L10n.menuHomeSubtitle, "house.fill"),
        .init(.catalog, L10n.menuBooks, L10n.menuBooksSubtitle, "books.vertical.fill"),
        .init(.audiobooks, ShellRefreshL10n.text("audioTitle"), ShellRefreshL10n.text("audioSubtitle"), "headphones")
    ] }
    private var inspiration: [ModernMenuItem] { [
        .init(.aiAssistant(bookID: nil), AIL10n.text("title"), AIL10n.text("menuSubtitle"), "sparkles", tint: Color(hex: 0x74649D)),
        .init(.giftWheel, WheelL10n.text("title"), WheelL10n.text("menuSubtitle"), "gift.fill", tint: Color(hex: 0xAE7C34)),
        .init(.authors, L10n.menuAuthors, L10n.menuAuthorsSubtitle, "person.text.rectangle", tint: Color(hex: 0x9C7653)),
        .init(.publishers, L10n.menuPublishers, L10n.menuPublishersSubtitle, "building.2.fill")
    ] }
    private var community: [ModernMenuItem] { [
        .init(.bookAgenda, L10n.menuBookAgenda, L10n.menuBookAgendaSubtitle, "text.book.closed.fill"),
        .init(.chat, L10n.menuChat, L10n.menuChatSubtitle, "bubble.left.and.text.bubble.right.fill"),
        .init(.liveActivity, L10n.menuLiveActivity, L10n.menuLiveActivitySubtitle, "bolt.fill", tint: Color(hex: 0xB68232)),
        .init(.requests, L10n.menuRequests, L10n.menuRequestsSubtitle, "heart.fill", tint: Color(hex: 0xB56C66)),
        .init(.forum, L10n.menuForum, L10n.menuForumSubtitle, "bubble.left.and.bubble.right.fill"),
        .init(.members, L10n.menuMembers, L10n.menuMembersSubtitle, "person.3.fill"),
        .init(.messages, L10n.menuMessages, L10n.menuMessagesSubtitle, "envelope.fill", badge: container.unreadMessages)
    ] }
    private var account: [ModernMenuItem] {
        guard container.isSignedIn else { return [
            .init(.login, L10n.commonLogin, L10n.menuLoginSubtitle, "arrow.right.square.fill"),
            .init(.register, L10n.menuRegister, L10n.menuRegisterSubtitle, "person.badge.plus.fill")
        ] }
        return [
            .init(.profile, L10n.menuProfile, L10n.menuProfileSubtitle, "person.crop.circle.fill", badge: container.totalUnread),
            .init(.notifications, L10n.menuNotifications, L10n.menuNotificationsSubtitle, "bell.fill", badge: container.unreadNotifications),
            .init(.library(tab: 0), L10n.menuLibrary, L10n.menuLibrarySubtitle, "books.vertical.circle.fill"),
            .init(.audioLibrary(tab: "saved"), ShellRefreshL10n.text("audioLibraryTitle"), ShellRefreshL10n.text("audioLibrarySubtitle"), "headphones.circle.fill")
        ]
    }
}

private struct ModernMenuItem: Identifiable {
    let route: AppRoute
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    let badge: Int
    var id: String { route.nativeRoute }

    init(_ route: AppRoute, _ title: String, _ subtitle: String, _ icon: String,
         tint: Color = EKitapligimPalette.teal, badge: Int = 0) {
        self.route = route; self.title = title; self.subtitle = subtitle; self.icon = icon
        self.tint = tint; self.badge = badge
    }
}
