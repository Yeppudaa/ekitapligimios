import SwiftUI
import EkitapligimCore

@MainActor
struct HomeView: View {
    @EnvironmentObject private var container: AppContainer
    @State private var stats: SiteStatsDTO?
    @State private var isLoadingStats = true
    @State private var statsError: String?

    var body: some View {
        NavigationStack {
            List {
                statsSection
                Section(L10n.homeExploreSection) {
                    Button {
                        container.selectedTab = .catalog
                    } label: {
                        Label(L10n.homeOpenCatalog, systemImage: "books.vertical")
                    }
                    Button {
                        container.selectedTab = .library
                    } label: {
                        Label(L10n.homeContinueReading, systemImage: "bookmark")
                    }
                    NavigationLink {
                        DirectoryView(kind: .author)
                    } label: {
                        Label(L10n.directoryAuthorsTitle, systemImage: "person.text.rectangle")
                    }
                    NavigationLink {
                        DirectoryView(kind: .publisher)
                    } label: {
                        Label(L10n.directoryPublishersTitle, systemImage: "building.2")
                    }
                    NavigationLink {
                        BookRequestsView()
                    } label: {
                        Label(L10n.bookRequestsTitle, systemImage: "text.badge.plus")
                    }
                }
            }
            .navigationTitle(L10n.homeTitle)
            .refreshable { await loadStats() }
            .task { await loadStatsIfNeeded() }
        }
    }

    @ViewBuilder
    private var statsSection: some View {
        Section(L10n.homeStatsSection) {
            if let stats {
                Grid(horizontalSpacing: 20, verticalSpacing: 16) {
                    GridRow {
                        HomeStat(value: stats.totalBooks, label: L10n.homeBooks, systemImage: "books.vertical")
                        HomeStat(value: stats.totalAuthors, label: L10n.homeAuthors, systemImage: "person.2")
                    }
                    GridRow {
                        HomeStat(value: stats.totalPublishers, label: L10n.homePublishers, systemImage: "building.2")
                        HomeStat(value: stats.totalCategories, label: L10n.homeCategories, systemImage: "square.grid.2x2")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .accessibilityElement(children: .contain)
            } else if isLoadingStats {
                HStack {
                    Spacer()
                    ProgressView(L10n.homeStatsLoading)
                    Spacer()
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Label(statsError ?? L10n.homeStatsLoadFailed, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.secondary)
                    Button(L10n.commonRetry) {
                        Task { await loadStats() }
                    }
                }
            }
        }
    }

    private func loadStatsIfNeeded() async {
        guard stats == nil else { return }
        await loadStats()
    }

    private func loadStats() async {
        isLoadingStats = true
        statsError = nil
        defer { isLoadingStats = false }
        do {
            stats = try await container.site.stats()
        } catch {
            statsError = L10n.homeStatsLoadFailed
        }
    }
}

@MainActor
private struct HomeStat: View {
    let value: Int
    let label: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text(value, format: .number.notation(.compactName))
                .font(.headline.monospacedDigit())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 68)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.homeStatAccessibility(label, value))
    }
}
