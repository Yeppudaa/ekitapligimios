import SwiftUI
import EkitapligimCore

/// İstatistikler — reading analytics with the daily goal slider.
@MainActor
struct StatsView: View {
    @EnvironmentObject private var container: AppContainer

    @State private var goalMinutes: Double = 45
    @State private var isSavingGoal = false
    @State private var noticeMessage: String?
    @State private var hasLoadedGoal = false

    private var stats: ReadingStatsDTO {
        container.readingStats ?? container.profileState?.readingStats ?? ReadingStatsDTO()
    }

    var body: some View {
        ZStack {
            EKitapligimPageBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    if let noticeMessage {
                        EKInlineError(message: noticeMessage)
                    }
                    todayCard
                    goalCard
                    totalsGrid
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
            }
        }
        .navigationTitle(L10n.profileActionStats)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.statsTitle)
                .font(.title3.weight(.heavy))
                .foregroundStyle(.white)
            Text(L10n.statsSubtitle)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(EKitapligimPalette.profileHeroGradient)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var todayCard: some View {
        HStack(spacing: 16) {
            EKProgressRing(progress: Double(stats.goalProgressPercent) / 100, size: 84, lineWidth: 8)
            VStack(alignment: .leading, spacing: 5) {
                Text(L10n.statsTodayTitle)
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(EKitapligimPalette.profileInk)
                Text(EKitapligimFormat.readingMinutes(stats.todayMinutes))
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(EKitapligimPalette.profileTealDeep)
                Text(L10n.readingGoalPageCount(stats.todayPages))
                    .font(.caption)
                    .foregroundStyle(EKitapligimPalette.profileMuted)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ekitapligimCard()
    }

    private var goalCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.statsGoalSectionTitle)
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(EKitapligimPalette.profileInk)
                Spacer(minLength: 0)
                Text(L10n.statsGoalMinutes(Int(goalMinutes)))
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(EKitapligimPalette.profileTealDeep)
            }

            Slider(value: $goalMinutes, in: 10...240, step: 5) {
                Text(L10n.statsGoalSectionTitle)
            }
            .tint(EKitapligimPalette.profileSuccess)
            .disabled(isSavingGoal || !isGoalEditable)
            .onChange(of: goalMinutes) { _, _ in
                guard hasLoadedGoal, isGoalEditable else { return }
                scheduleGoalSave()
            }

            if isSavingGoal {
                Text(L10n.commonSaving)
                    .font(.caption2)
                    .foregroundStyle(EKitapligimPalette.profileMuted)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ekitapligimCard()
    }

    private var totalsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            totalCell(L10n.statsTotalPages, value: EKitapligimFormat.count(stats.totalPages), systemImage: "doc.text.fill")
            totalCell(L10n.statsTotalDuration, value: EKitapligimFormat.readingMinutes(stats.totalMinutes), systemImage: "hourglass")
            totalCell(L10n.statsStreak, value: L10n.readingGoalDayCount(stats.streakCount), systemImage: "flame.fill")
            totalCell(L10n.readingGoalTodayPill, value: EKitapligimFormat.readingMinutes(stats.todayMinutes), systemImage: "sun.max.fill")
        }
    }

    private func totalCell(_ label: String, value: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: systemImage)
                .font(.subheadline)
                .foregroundStyle(EKitapligimPalette.profileTeal)
            Text(value)
                .font(.title3.weight(.heavy))
                .foregroundStyle(EKitapligimPalette.profileInk)
            Text(label)
                .font(.caption)
                .foregroundStyle(EKitapligimPalette.profileMuted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .ekitapligimCard(radius: 15)
        .accessibilityElement(children: .combine)
    }

    /// The slider is inert until we know the dedicated reading-stats route is deployed.
    private var isGoalEditable: Bool { container.readingStats != nil }

    private func load() async {
        await container.refreshSessionData()
        goalMinutes = Double(stats.dailyGoalMinutes)
        if container.readingStats == nil {
            noticeMessage = L10n.statsGoalUnavailable
        }
        hasLoadedGoal = true
    }

    private func scheduleGoalSave() {
        Task {
            let target = Int(goalMinutes)
            // Debounce so dragging the slider does not fire a request per step.
            try? await Task.sleep(for: .milliseconds(600))
            guard Int(goalMinutes) == target, !isSavingGoal else { return }
            await saveGoal(minutes: target)
        }
    }

    private func saveGoal(minutes: Int) async {
        isSavingGoal = true
        defer { isSavingGoal = false }
        do {
            if let updated = try await container.readingStatsRepository.setDailyGoal(minutes: minutes) {
                container.updateReadingStats(updated)
                noticeMessage = nil
            } else {
                noticeMessage = L10n.statsGoalUnavailable
            }
        } catch {
            noticeMessage = L10n.statsGoalSaveFailed
        }
    }
}
