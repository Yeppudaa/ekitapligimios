import SwiftUI
import EkitapligimCore

enum AudioStyle {
    static let ink = Color(red: 0.075, green: 0.247, blue: 0.278)
    static let teal = Color(red: 0.02, green: 0.52, blue: 0.52)
    static let muted = Color(red: 0.35, green: 0.45, blue: 0.49)
    static let line = Color(red: 0.82, green: 0.89, blue: 0.88)
    static let paper = Color(red: 0.95, green: 0.97, blue: 0.96)
    static let cream = Color(red: 0.99, green: 0.95, blue: 0.87)
    static let gold = Color(red: 0.67, green: 0.47, blue: 0.17)
    static let gradient = LinearGradient(colors: [teal, ink], startPoint: .leading, endPoint: .trailing)
}

@MainActor
struct AudioArtwork: View {
    let name: String
    var body: some View { Image(name).resizable().scaledToFill().accessibilityHidden(true) }
}
@MainActor
struct AudioCoverView: View {
    let book: AudioBookDTO
    var width: CGFloat = 112
    var body: some View {
        EKitapligimRemoteCover(urlString: book.coverURL, title: book.title, author: book.author)
            .frame(width: width, height: width * 1.45).clipShape(RoundedRectangle(cornerRadius: 9))
            .shadow(color: AudioStyle.ink.opacity(0.16), radius: 12, x: 0, y: 7)
    }
}
@MainActor
struct AudioActionButton: View {
    let title: String
    let icon: String
    var prominent = false
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon).font(.subheadline.weight(.semibold)).multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 46).padding(.horizontal, 10).padding(.vertical, 4)
                .foregroundStyle(prominent ? Color.white : AudioStyle.ink)
                .background { if prominent { AudioStyle.gradient } else { Color.white.opacity(0.85) } }
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .overlay(RoundedRectangle(cornerRadius: 15).stroke(prominent ? Color.clear : AudioStyle.line, lineWidth: 1))
        }.buttonStyle(.plain)
    }
}
@MainActor
struct AudioCardView: View {
    let book: AudioBookDTO
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack { Spacer(minLength: 0); AudioCoverView(book: book, width: 104); Spacer(minLength: 0) }
                    .padding(.vertical, 20).frame(maxWidth: .infinity).background(AudioStyle.paper).clipShape(RoundedRectangle(cornerRadius: 13))
                    .overlay(alignment: .topTrailing) { Image(systemName: "headphones").font(.caption).foregroundStyle(AudioStyle.teal).padding(8).background(.white.opacity(0.95)).clipShape(Circle()).padding(7) }
                Text(book.title).font(.subheadline.weight(.semibold)).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                Text(book.author).font(.caption).foregroundStyle(AudioStyle.muted).lineLimit(1)
                Label(book.durationLabel.isEmpty ? AudioL10n.duration(book.duration) : book.durationLabel, systemImage: "headphones")
                    .font(.caption2).foregroundStyle(AudioStyle.teal)
            }.padding(12).foregroundStyle(AudioStyle.ink).background(.white).clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(AudioStyle.line.opacity(0.7), lineWidth: 1))
        }.buttonStyle(.plain)
    }
}
@MainActor
struct AudioShelfView: View {
    let title: String
    var hint = ""
    let books: [AudioBookDTO]
    var artwork: String? = nil
    var onBook: (Int) -> Void
    var onBrowse: (() -> Void)? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.system(.title2, design: .serif, weight: .bold)).foregroundStyle(AudioStyle.ink).fixedSize(horizontal: false, vertical: true)
                if !hint.isEmpty { Text(hint).font(.subheadline).foregroundStyle(AudioStyle.muted).fixedSize(horizontal: false, vertical: true) }
                if let onBrowse { Button(action: onBrowse) { Label(AudioL10n.text("seeAll"), systemImage: "arrow.right").font(.caption.weight(.semibold)).padding(.horizontal, 13).frame(minHeight: 44).background(.white.opacity(0.9)).clipShape(Capsule()) }.buttonStyle(.plain).foregroundStyle(AudioStyle.ink) }
            }.padding(21).frame(maxWidth: .infinity, minHeight: 115, alignment: .leading)
                .background {
                    GeometryReader { geometry in
                        AudioArtwork(name: artwork ?? AudioPresentationPolicy.shelfArtwork(title)).frame(width: geometry.size.width, height: geometry.size.height).clipped()
                        LinearGradient(colors: [AudioStyle.cream.opacity(0.98), AudioStyle.cream.opacity(0.76), AudioStyle.cream.opacity(0.1)], startPoint: .leading, endPoint: .trailing)
                    }
                }.clipShape(RoundedRectangle(cornerRadius: 21))
            ScrollView(.horizontal, showsIndicators: false) {
                Group {
                    // Small shelves have a known natural height before the vertical page scrolls.
                    // Keep large author collections lazy and retain every received book.
                    if books.count <= 8 {
                        HStack(alignment: .top, spacing: 12) { shelfCards }
                    } else {
                        LazyHStack(alignment: .top, spacing: 12) { shelfCards }
                    }
                }.padding(.bottom, 5)
            }
        }
    }
    private var shelfCards: some View {
        ForEach(books) { book in AudioCardView(book: book) { onBook(book.id) }.frame(width: 162) }
    }
}
@MainActor
struct AudioErrorView: View {
    let message: String
    var retry: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(message, systemImage: "wifi.exclamationmark").font(.subheadline).fixedSize(horizontal: false, vertical: true)
            Button(AudioL10n.text("retry"), action: retry).font(.subheadline.weight(.semibold)).frame(minHeight: 44)
        }.foregroundStyle(AudioStyle.ink).padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(AudioStyle.cream).clipShape(RoundedRectangle(cornerRadius: 18))
    }
}
@MainActor
struct AudioEmptyView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "headphones").font(.largeTitle).foregroundStyle(AudioStyle.teal)
            Text(AudioL10n.text("empty")).font(.system(.title3, design: .serif, weight: .bold))
            Text(AudioL10n.text("emptyHint")).font(.subheadline).foregroundStyle(AudioStyle.muted).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(28).foregroundStyle(AudioStyle.ink)
    }
}
@MainActor
struct AudioResumeCard: View {
    let book: AudioBookDTO
    var action: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(AudioL10n.text("resume"), systemImage: "headphones").font(.system(.title3, design: .serif, weight: .bold))
            Text(AudioL10n.text("resumeHint")).font(.caption).foregroundStyle(AudioStyle.muted)
            HStack(spacing: 16) {
                AudioCoverView(book: book, width: 72)
                VStack(alignment: .leading, spacing: 9) {
                    Text(book.title).font(.headline).fixedSize(horizontal: false, vertical: true)
                    Text(book.author).font(.caption).foregroundStyle(AudioStyle.muted)
                    ProgressView(value: book.state.progress, total: 100).tint(AudioStyle.teal)
                    Text(AudioL10n.format("percentListened", Int(book.state.progress))).font(.caption2).foregroundStyle(AudioStyle.teal)
                }
            }
            AudioActionButton(title: AudioL10n.text("resume"), icon: "play.fill", prominent: true, action: action)
        }.padding(20).foregroundStyle(AudioStyle.ink)
            .background(LinearGradient(colors: [.white, Color(red: 0.88, green: 0.96, blue: 0.93)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(RoundedRectangle(cornerRadius: 24)).overlay(RoundedRectangle(cornerRadius: 24).stroke(AudioStyle.line, lineWidth: 1))
    }
}
@MainActor
struct AudioPremiumAccessView: View {
    @Environment(\.dismiss) private var dismiss
    var onPremium: () -> Void
    var onLogin: (() -> Void)? = nil
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Label(AudioL10n.text("premiumEyebrow"), systemImage: "crown.fill")
                    .font(.caption.weight(.bold)).tracking(1.5)
                    .foregroundStyle(AudioStyle.cream).padding(24)
                    .frame(maxWidth: .infinity, minHeight: 220, alignment: .bottomLeading)
                    .background {
                        GeometryReader { geometry in
                            AudioArtwork(name: "audio_story_landscape")
                                .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                                .overlay {
                                    LinearGradient(colors: [.clear, AudioStyle.ink.opacity(0.95)], startPoint: .top, endPoint: .bottom)
                                }
                        }.accessibilityHidden(true)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .contentShape(.accessibility, RoundedRectangle(cornerRadius: 24))
                    .accessibilityIdentifier("audio.premium.hero")
                Text(AudioL10n.text("premiumTitle")).font(.system(.largeTitle, design: .serif, weight: .bold))
                Text(AudioL10n.text("premiumMessage")).font(.body).foregroundStyle(AudioStyle.muted)
                ForEach([("headphones", "premiumListen"), ("arrow.down.circle", "premiumDownload"), ("book.pages", "premiumReader")], id: \.1) { feature in
                    Label(AudioL10n.text(feature.1), systemImage: feature.0).font(.subheadline.weight(.semibold)).padding(.vertical, 5)
                }
                AudioActionButton(title: AudioL10n.text("viewPremium"), icon: "crown.fill", prominent: true) { dismiss(); onPremium() }
                if let onLogin { AudioActionButton(title: AudioL10n.text("signIn"), icon: "person.crop.circle") { dismiss(); onLogin() } }
                Button(AudioL10n.text("notNow")) { dismiss() }.frame(maxWidth: .infinity, minHeight: 44).foregroundStyle(AudioStyle.muted)
            }.padding(22)
        }.background(AudioStyle.cream).foregroundStyle(AudioStyle.ink).presentationDragIndicator(.visible)
    }
}
