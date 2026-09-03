import SwiftUI
import EkitapligimCore

/// Horizontally scrollable bottom navigation for six primary destinations on iPhone.
@MainActor
struct PrimaryTabBar: View {
    @Binding var selection: AppTab
    var profileBadgeCount: Int = 0

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(AppTab.allCases) { tab in
                    tabButton(tab)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .background {
            Rectangle()
                .fill(Color(red: 251 / 255, green: 254 / 255, blue: 254 / 255))
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color(red: 226 / 255, green: 232 / 255, blue: 234 / 255))
                        .frame(height: 1)
                }
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private func tabButton(_ tab: AppTab) -> some View {
        let isSelected = selection == tab
        let accessibilityTitle = tab == .profile && profileBadgeCount > 0
            ? "\(tab.title), \(L10n.unreadCountAccessibility(profileBadgeCount))"
            : tab.title
        return Button {
            selection = tab
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: tab.systemImage)
                        .font(.system(size: 18, weight: isSelected ? .semibold : .regular))
                        .accessibilityHidden(true)
                    if tab == .profile, profileBadgeCount > 0 {
                        Text(profileBadgeCount > 9 ? "9+" : "\(profileBadgeCount)")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(EKitapligimPalette.amber, in: Capsule())
                            .offset(x: 8, y: -6)
                    }
                }
                Text(tab.title)
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(isSelected ? EKitapligimPalette.teal : EKitapligimPalette.muted)
            .frame(minWidth: 58)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                isSelected ? EKitapligimPalette.tealSoft.opacity(0.65) : Color.clear,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(tab.accessibilityIdentifier)
        .accessibilityLabel(accessibilityTitle)
    }
}

extension AppTab: Identifiable {
    var id: Self { self }
}
