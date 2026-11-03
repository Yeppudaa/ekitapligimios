import SwiftUI
import EkitapligimCore

struct GuestProfilePrompt: View {
    var statusMessage: String?
    let onLogin: () -> Void
    let onRegister: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                CommunityHero(eyebrow: text("guest.eyebrow"), title: text("guest.hero"))
                CommunityCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(text("guest.title")).font(.system(.title, design: .serif).bold())
                            .foregroundStyle(CommunityStyle.ink)
                        Text(text("guest.subtitle")).font(.subheadline).foregroundStyle(CommunityStyle.muted)
                        if let statusMessage {
                            Label(statusMessage, systemImage: "exclamationmark.circle")
                                .font(.footnote).foregroundStyle(Color(hex: 0x9A621E))
                        }
                        Button(action: onLogin) {
                            Label(text("guest.login"), systemImage: "rectangle.portrait.and.arrow.right")
                        }.buttonStyle(CommunityButtonStyle()).accessibilityIdentifier("profile.guest.login")
                        Button(action: onRegister) {
                            Label(text("guest.register"), systemImage: "person.badge.plus")
                        }.buttonStyle(CommunityButtonStyle(primary: false)).accessibilityIdentifier("profile.guest.register")
                        Text(text("guest.authNote")).font(.caption).foregroundStyle(CommunityStyle.muted)
                            .multilineTextAlignment(.center).frame(maxWidth: .infinity)
                    }.fixedSize(horizontal: false, vertical: true)
                }
                CommunityCard(padding: 18) {
                    VStack(spacing: 0) {
                        benefit("guest.shelves", icon: "books.vertical")
                        Divider().overlay(CommunityStyle.border)
                        benefit("guest.favorites", icon: "heart")
                        Divider().overlay(CommunityStyle.border)
                        benefit("guest.resume", icon: "bookmark")
                    }
                }
            }
            .frame(maxWidth: 680).padding(18).frame(maxWidth: .infinity)
        }
        .background(CommunityStyle.page.ignoresSafeArea())
        .accessibilityIdentifier("profile.guest")
    }

    private func benefit(_ key: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: icon).font(.title3).foregroundStyle(CommunityStyle.teal)
                .frame(width: 42, height: 42).background(CommunityStyle.soft, in: RoundedRectangle(cornerRadius: 14))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(text(key)).font(.subheadline.weight(.semibold)).foregroundStyle(CommunityStyle.ink)
                Text(text(key + ".detail")).font(.caption).foregroundStyle(CommunityStyle.muted)
            }.fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }.padding(.vertical, 15).accessibilityElement(children: .combine)
    }

    private func text(_ key: String) -> String { CommunityDesignL10n.text(key) }
}
