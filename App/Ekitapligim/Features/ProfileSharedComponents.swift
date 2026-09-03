import SwiftUI
import EkitapligimCore

// MARK: - Shared profile section chrome

struct ProfileSectionHeading: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.headline)
                .foregroundStyle(EKitapligimPalette.profileInk)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(EKitapligimPalette.profileMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ProfileEmptyState: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.subheadline)
            .foregroundStyle(EKitapligimPalette.profileMuted)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 26)
            .padding(.horizontal, 16)
            .background(EKitapligimPalette.profileSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct LibraryShelfCard: View {
    let title: String
    let count: Int
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(EKitapligimPalette.profileTeal)
                    .frame(width: 36, height: 36)
                    .background(EKitapligimPalette.profileTealSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text(EKitapligimFormat.count(count))
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(EKitapligimPalette.profileInk)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(EKitapligimPalette.profileMuted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .ekitapligimCard(radius: 16)
            .shadow(color: EKitapligimPalette.profileTeal.opacity(0.08), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}

struct ProfileBookRow: View {
    let item: LibraryItemDTO

    private var progress: Int { min(max(item.progressPercent, 0), 100) }

    var body: some View {
        HStack(spacing: 12) {
            EKitapligimRemoteCover(urlString: item.coverUrl)
                .frame(width: 48, height: 70)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .shadow(color: EKitapligimPalette.ink.opacity(0.12), radius: 6, y: 3)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title.isEmpty ? L10n.commonBookNumber(item.bookId) : item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(EKitapligimPalette.profileInk)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if !item.author.isEmpty {
                    Text(item.author)
                        .font(.caption)
                        .foregroundStyle(EKitapligimPalette.profileMuted)
                        .lineLimit(1)
                }
                HStack(spacing: 8) {
                    ProgressView(value: Double(progress), total: 100)
                        .tint(EKitapligimPalette.profileSuccess)
                    Text(L10n.commonPercent(progress))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(EKitapligimPalette.profileTealDeep)
                        .monospacedDigit()
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(EKitapligimPalette.profileTeal)
                .accessibilityHidden(true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ekitapligimCard(radius: 14)
    }
}

/// Live activity feed filtered to a single member.
@MainActor
struct ProfileActivityList: View {
    @EnvironmentObject private var container: AppContainer
    let userID: String?

    @State private var items: [LiveActivityItemDTO] = []
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 10) {
            if isLoading && items.isEmpty {
                EKSkeletonCard(height: 66)
                EKSkeletonCard(height: 66)
            } else if items.isEmpty {
                ProfileEmptyState(message: L10n.profileActivityEmpty)
            } else {
                ForEach(items) { item in
                    LiveActivityRow(item: item)
                }
            }
        }
        .task { await load() }
    }

    private func load() async {
        guard let userID, !userID.isEmpty, items.isEmpty, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        items = (try? await container.liveActivity.activity(limit: 12, userID: userID).items) ?? []
    }
}
