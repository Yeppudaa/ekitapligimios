import SwiftUI

enum EKitapligimPalette {
    static let page = Color(red: 250 / 255, green: 252 / 255, blue: 252 / 255)
    static let paper = Color.white
    static let ink = Color(red: 16 / 255, green: 33 / 255, blue: 47 / 255)
    static let muted = Color(red: 114 / 255, green: 128 / 255, blue: 142 / 255)
    static let teal = Color(red: 7 / 255, green: 134 / 255, blue: 139 / 255)
    static let tealDark = Color(red: 0 / 255, green: 110 / 255, blue: 115 / 255)
    static let tealSoft = Color(red: 232 / 255, green: 247 / 255, blue: 247 / 255)
    static let cream = Color(red: 255 / 255, green: 248 / 255, blue: 234 / 255)
    static let amber = Color(red: 224 / 255, green: 154 / 255, blue: 18 / 255)
    static let amberSoft = Color(red: 255 / 255, green: 243 / 255, blue: 214 / 255)
    static let border = Color(red: 226 / 255, green: 232 / 255, blue: 234 / 255)

    static let pageGradient = LinearGradient(
        colors: [Color(red: 252 / 255, green: 254 / 255, blue: 254 / 255),
                 Color(red: 242 / 255, green: 250 / 255, blue: 250 / 255),
                 Color(red: 255 / 255, green: 251 / 255, blue: 242 / 255),
                 .white],
        startPoint: .top,
        endPoint: .bottom
    )
}

struct EKitapligimPageBackground: View {
    var body: some View {
        EKitapligimPalette.pageGradient
            .ignoresSafeArea()
    }
}

struct EKitapligimBrandLogo: View {
    var body: some View {
        Image("EKitapligimWideLogo")
            .resizable()
            .scaledToFit()
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(EKitapligimPalette.paper)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(red: 240 / 255, green: 223 / 255, blue: 194 / 255))
            }
            .accessibilityLabel("E-Kitaplığım")
    }
}

struct EKitapligimSectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(EKitapligimPalette.ink)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(EKitapligimPalette.muted)
                }
            }
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(EKitapligimPalette.tealDark)
            }
        }
    }
}

struct EKitapligimRemoteCover: View {
    let urlString: String

    var body: some View {
        Group {
            if let url = secureURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill()
                    case .empty: ProgressView().tint(EKitapligimPalette.teal)
                    default: placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(EKitapligimPalette.tealSoft)
        .clipped()
    }

    private var secureURL: URL? {
        guard let url = URL(string: urlString), url.scheme?.lowercased() == "https" else { return nil }
        return url
    }

    private var placeholder: some View {
        Image(systemName: "book.closed.fill")
            .font(.title2)
            .foregroundStyle(EKitapligimPalette.teal)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct EKitapligimCardModifier: ViewModifier {
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(EKitapligimPalette.paper)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(EKitapligimPalette.border)
            }
    }
}

extension View {
    func ekitapligimCard(radius: CGFloat = 18) -> some View {
        modifier(EKitapligimCardModifier(radius: radius))
    }
}
