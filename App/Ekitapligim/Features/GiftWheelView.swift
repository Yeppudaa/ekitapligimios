import SwiftUI
import UIKit
import EkitapligimCore

@MainActor struct GiftWheelView: View {
    @ObservedObject var model: GiftWheelModel
    let isSignedIn: Bool
    let onLogin: () -> Void
    let onLiveActivity: () -> Void
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var fontScale: CGFloat = 1
    private var state: GiftWheelState { model.state }
    private var login: Bool { !isSignedIn || state.needsLogin }
    private var retryLoad: Bool { state.error != nil && (!state.pendingRetry || state.status == nil) }
    private var canAct: Bool { !state.busy && (login || retryLoad || (state.pendingRetry && state.status != nil) || state.status?.canSpin == true) }

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { scroll in
                ScrollView {
                    VStack(spacing: 0) {
                        hero.id("top")
                        stage(wide: geometry.size.width >= 720 && !dynamicTypeSize.isAccessibilitySize, scroll: scroll)
                        legend.padding(.top, 36)
                        winners.padding(.top, 32)
                        instructions.padding(.top, 32)
                        history.padding(.top, 28)
                        Button(WheelL10n.text("backToWheel")) {
                            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) { scroll.scrollTo("top", anchor: .top) }
                        }
                        .font(font(13, .semibold)).frame(minHeight: 44).padding(.top, 16)
                    }
                    .frame(maxWidth: 960)
                    .padding(.horizontal, 16).padding(.top, 18).padding(.bottom, 40)
                    .frame(maxWidth: .infinity)
                }
                .onChange(of: state.prize) { _, prize in
                    if let prize {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.35)) { scroll.scrollTo("result", anchor: .center) }
                        UIAccessibility.post(notification: .announcement, argument: prize.message)
                    }
                }
            }
        }
        .background(GiftWheelPalette.paper.ignoresSafeArea())
        .tint(GiftWheelPalette.violet)
        .navigationTitle(WheelL10n.text("title"))
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("gift-wheel-screen")
        .onAppear { model.setVisible(scenePhase == .active) }
        .onDisappear { model.setVisible(false) }
        .onChange(of: scenePhase) { _, phase in
            model.setVisible(phase == .active)
            if phase == .active { Task { await model.controller.tick() } }
        }
        .task(id: isSignedIn) { await model.controller.refresh() }
        .task {
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(1)) } catch { break }
                if scenePhase == .active { await model.controller.tick() }
            }
        }
    }
    private func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font { .system(size: size * fontScale, weight: weight) }
    private func kicker(_ key: String) -> some View {
        Text(WheelL10n.text(key)).font(font(9, .bold)).tracking(1.4)
            .foregroundStyle(GiftWheelPalette.color(0x80738F)).fixedSize(horizontal: false, vertical: true)
    }
    private var hero: some View {
        VStack(spacing: 0) {
            kicker("club").padding(.bottom, 27)
            kicker("eyebrow")
            (Text(WheelL10n.text("heroFirst")).foregroundColor(GiftWheelPalette.ink)
                + Text("\n" + WheelL10n.text("heroSecond")).foregroundColor(GiftWheelPalette.violet))
                .font(font(34, .heavy)).tracking(-1.2).padding(.top, 15).padding(.bottom, 14)
                .accessibilityAddTraits(.isHeader)
            Text(LocalizedStringKey(WheelL10n.text("intro"))).font(font(13)).lineSpacing(6)
                .foregroundStyle(GiftWheelPalette.muted).frame(maxWidth: 530)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 18) { perks }
                VStack(spacing: 8) { perks }
            }.font(font(10)).foregroundStyle(GiftWheelPalette.color(0x776687)).padding(.vertical, 22)
        }.multilineTextAlignment(.center)
    }
    @ViewBuilder private var perks: some View {
        Label(WheelL10n.text("freeSpin"), systemImage: "gift")
        Label(WheelL10n.text("premiumSurprises"), systemImage: "crown")
    }
    private func stage(wide: Bool, scroll: ScrollViewProxy) -> some View {
        Group {
            if wide {
                HStack(spacing: 24) {
                    wheelStage.frame(maxWidth: .infinity)
                    spinCard(scroll: scroll).frame(maxWidth: .infinity)
                }
            } else {
                VStack(spacing: 22) { wheelStage; spinCard(scroll: scroll) }
            }
        }
        .padding(14)
        .background(LinearGradient(colors: [GiftWheelPalette.color(0xF7F0F8), GiftWheelPalette.color(0xFCF5E9)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(GiftWheelPalette.color(0xEEE3EC), lineWidth: 1))
        .font(font(10)).foregroundStyle(GiftWheelPalette.color(0x776687))
    }
    private var wheelStage: some View {
        VStack(spacing: 18) {
            GiftWheelDisc(rotation: reduceMotion ? GiftWheelMotion.initialRotation : state.rotation, segments: state.segments)
                .frame(maxWidth: 490).padding(.top, 22).id("wheel")
                .accessibilityValue(state.spinning ? WheelL10n.text("spinning") : WheelL10n.text("discIdle"))
            if reduceMotion && state.spinning {
                ProgressView(value: state.elapsed, total: GiftWheelMotion.duration)
                    .accessibilityLabel(WheelL10n.text("spinning")).tint(GiftWheelPalette.violet)
            }
            Text(WheelL10n.text("wish")).font(font(10)).foregroundStyle(GiftWheelPalette.color(0x9076A5))
                .multilineTextAlignment(.center).padding(.bottom, 2)
        }.frame(maxWidth: .infinity)
    }
    private func spinCard(scroll: ScrollViewProxy) -> some View {
        VStack(spacing: 0) {
            Text("●  " + WheelL10n.text(state.spinning ? "surpriseComing" : "welcome"))
                .font(font(9, .bold)).tracking(0.6).foregroundStyle(GiftWheelPalette.color(0x84689F))
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(GiftWheelPalette.color(0xF3EDF9), in: Capsule())
            Image(systemName: "gift").font(.system(size: 32)).foregroundStyle(GiftWheelPalette.color(0xC08A29))
                .frame(width: 64, height: 64)
                .background(LinearGradient(colors: [GiftWheelPalette.color(0xFFF2BE), GiftWheelPalette.color(0xFFE6A3)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 20))
                .padding(.top, 22).padding(.bottom, 18).accessibilityHidden(true)
            Text(WheelL10n.text(state.spinning ? "spinningTitle" : "cardTitle"))
                .font(font(27, .bold)).tracking(-0.8).foregroundStyle(GiftWheelPalette.ink)
            Text(WheelL10n.text("cardDescription")).font(font(12)).lineSpacing(5).foregroundStyle(GiftWheelPalette.muted).padding(.top, 12)
            if isSignedIn, !state.loading, let status = state.status {
                Text(availability(status)).font(font(11)).foregroundStyle(GiftWheelPalette.muted).padding(.top, 10)
            }
            if state.waitSeconds > 0 && !state.spinning { countdown.padding(.top, 16) }
            if let prize = state.prize { result(prize).padding(.top, 16).id("result") }
            if let error = state.error {
                Text(error).font(font(12)).foregroundStyle(GiftWheelPalette.color(0xAE3C4D)).padding(.top, 14)
                    .accessibilityIdentifier("gift-wheel-error")
            }
            Button {
                if login { onLogin() }
                else if retryLoad { Task { await model.controller.refresh() } }
                else {
                    // Position the wheel before starting its first timed frame.
                    scroll.scrollTo("wheel", anchor: .top)
                    Task { await model.controller.spin() }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(actionTitle).font(font(13, .bold)).frame(maxWidth: .infinity, alignment: .leading)
                    if state.loading || state.submitting { ProgressView().tint(GiftWheelPalette.violet) }
                    else { Image(systemName: "arrow.right").accessibilityHidden(true) }
                }
                .padding(16).frame(minHeight: 52)
                .foregroundStyle(canAct ? Color.white : GiftWheelPalette.color(0x82768F))
                .background(LinearGradient(colors: canAct ? [GiftWheelPalette.color(0x6945A5), GiftWheelPalette.color(0x9970C7)] : [GiftWheelPalette.color(0xEFEBF4)], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 12))
            }.buttonStyle(.plain).disabled(!canAct).padding(.top, 18).accessibilityIdentifier("gift-wheel-spin")
            Text(WheelL10n.text("cardFootnote")).font(font(10)).foregroundStyle(GiftWheelPalette.color(0x898191)).padding(.top, 13).padding(.bottom, 22)
            Rectangle().fill(GiftWheelPalette.color(0xEEE8F2)).frame(height: 1)
            HStack(alignment: .firstTextBaseline) {
                Text(WheelL10n.text("walletTitle")).font(font(11)).frame(maxWidth: .infinity, alignment: .leading)
                Text(state.wallet.label).font(font(22, .bold)).foregroundStyle(GiftWheelPalette.color(0x6B4B91))
            }.foregroundStyle(GiftWheelPalette.color(0x84728F)).padding(.top, 18)
            Text(state.wallet.description).font(font(10)).foregroundStyle(GiftWheelPalette.color(0x8C8195))
                .frame(maxWidth: .infinity, alignment: .leading).multilineTextAlignment(.leading).padding(.top, 5)
        }
        .multilineTextAlignment(.center).padding(20).frame(maxWidth: .infinity)
        .background(.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(.white, lineWidth: 1))
    }
    private var countdown: some View {
        VStack(spacing: 6) {
            Text(WheelL10n.text("countdown")).font(font(10))
            Text(String(format: "%02d : %02d : %02d", state.waitSeconds / 3600, state.waitSeconds % 3600 / 60, state.waitSeconds % 60))
                .font(font(26, .bold)).monospacedDigit().foregroundStyle(GiftWheelPalette.color(0x665084))
                .minimumScaleFactor(0.7).lineLimit(1)
        }.padding(13).frame(maxWidth: .infinity).background(GiftWheelPalette.color(0xF6F2FA), in: RoundedRectangle(cornerRadius: 12))
    }
    private func result(_ prize: GiftWheelSpinDTO) -> some View {
        VStack(spacing: 6) {
            if prize.result.days > 0 {
                Text(WheelL10n.format("prizeHeading", prize.result.days)).font(font(16, .bold)).foregroundStyle(GiftWheelPalette.color(0x967022))
            }
            Text(prize.message).font(font(12)).lineSpacing(4).foregroundStyle(GiftWheelPalette.ink)
        }.padding(15).frame(maxWidth: .infinity)
            .background(GiftWheelPalette.color(prize.result.days > 0 ? 0xFFF4D6 : 0xF3EDF9), in: RoundedRectangle(cornerRadius: 14))
            .accessibilityElement(children: .combine).accessibilityIdentifier("gift-wheel-result")
    }
    private func sectionTitle(_ eyebrow: String, _ title: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            kicker(eyebrow)
            Text(WheelL10n.text(title)).font(font(23, .bold)).tracking(-0.5).foregroundStyle(GiftWheelPalette.ink).accessibilityAddTraits(.isHeader)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, 17)
    }
    private var legend: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTitle("legendKicker", "legendTitle")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: dynamicTypeSize.isAccessibilitySize ? 2 : 3), spacing: 10) {
                ForEach(Array(GiftWheelSegmentDTO.defaults.prefix(6)), id: \.index) { segment in
                    VStack(spacing: 0) {
                        Rectangle().fill(GiftWheelPalette.color(segment.colorHex)).frame(height: 3)
                        Image(systemName: segment.days == 0 ? "arrow.clockwise" : "crown")
                            .font(.system(size: 23)).foregroundStyle(segment.days == 0 ? GiftWheelPalette.violet : GiftWheelPalette.color(segment.colorHex))
                            .padding(.top, 17).padding(.bottom, 10).accessibilityHidden(true)
                        Text(segment.label).font(font(12, .bold)).foregroundStyle(GiftWheelPalette.ink)
                        Text(WheelL10n.text(segment.days == 0 ? "noReward" : "premiumMembership")).font(font(9))
                            .foregroundStyle(GiftWheelPalette.muted).padding(.top, 5).padding(.bottom, 15)
                    }.frame(maxWidth: .infinity).multilineTextAlignment(.center)
                        .background(.white).clipShape(RoundedRectangle(cornerRadius: 15))
                        .overlay(RoundedRectangle(cornerRadius: 15).strokeBorder(GiftWheelPalette.border, lineWidth: 1))
                        .accessibilityElement(children: .combine)
                }
            }
            Text(WheelL10n.text("legendNote")).font(font(11)).lineSpacing(5).foregroundStyle(GiftWheelPalette.muted).padding(.top, 13)
        }
    }
    private var winners: some View {
        VStack(spacing: 0) {
            sectionTitle("winnersKicker", "winnersTitle")
            VStack(spacing: 8) {
                if state.winners.isEmpty {
                    Image(systemName: "gift").font(.system(size: 28)).foregroundStyle(GiftWheelPalette.gold).accessibilityHidden(true)
                    Text(WheelL10n.text(!isSignedIn ? "winnersLogin" : (state.winnersError ? "winnersError" : (state.loading ? "winnersLoading" : "winnersEmpty"))))
                        .font(font(14, .semibold)).foregroundStyle(GiftWheelPalette.ink).padding(.top, 4)
                    Text(WheelL10n.text("winnersDescription")).font(font(11)).lineSpacing(5).foregroundStyle(GiftWheelPalette.muted)
                } else { entries(state.winners, history: false) }
                if isSignedIn {
                    Button(WheelL10n.text("refresh")) { Task { await model.controller.refresh() } }.disabled(state.busy).frame(minHeight: 44)
                }
                Button(WheelL10n.text("liveActivity"), action: onLiveActivity).frame(minHeight: 44)
            }.font(font(13)).multilineTextAlignment(.center).padding(20).frame(maxWidth: .infinity)
                .background(.white, in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(GiftWheelPalette.border, lineWidth: 1))
        }
    }
    private var instructions: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTitle("howKicker", "howTitle")
            ForEach(1...3, id: \.self) { step in
                HStack(alignment: .top, spacing: 13) {
                    Text(String(step)).font(font(12, .bold)).foregroundStyle(GiftWheelPalette.violet)
                        .frame(minWidth: 29, minHeight: 29).background(GiftWheelPalette.color(0xF0EAF8), in: Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text(WheelL10n.text("step\(step)Title")).font(font(13, .bold)).foregroundStyle(GiftWheelPalette.ink)
                        Text(WheelL10n.text("step\(step)Body")).font(font(12)).lineSpacing(5).foregroundStyle(GiftWheelPalette.muted)
                    }
                }.padding(.bottom, 17).accessibilityElement(children: .combine)
            }
        }
    }
    private var history: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTitle("historyKicker", "historyTitle")
            if let history = state.status?.history, !history.isEmpty {
                entries(history, history: true).padding(16).background(.white, in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(GiftWheelPalette.border, lineWidth: 1))
            } else { Text(WheelL10n.text("historyEmpty")).font(font(12)).foregroundStyle(GiftWheelPalette.muted) }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func entries(_ entries: [GiftWheelEntryDTO], history: Bool) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
                HStack(spacing: 12) {
                    Image(systemName: entry.days > 0 ? "crown" : "arrow.clockwise").font(.system(size: 22))
                        .foregroundStyle(entry.days > 0 ? GiftWheelPalette.gold : GiftWheelPalette.violet).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(history ? (entry.days > 0 ? WheelL10n.format("daysPremium", entry.days) : WheelL10n.text("tryAgain")) : (entry.username ?? ""))
                            .font(font(13, .semibold)).foregroundStyle(GiftWheelPalette.ink)
                        Text(Date(timeIntervalSince1970: entry.createdAt), format: .dateTime.day().month(.abbreviated).year().hour().minute())
                            .font(font(10)).foregroundStyle(GiftWheelPalette.muted)
                        if entry.refunded == true { Text(WheelL10n.text("refunded")).font(font(10)).foregroundStyle(GiftWheelPalette.muted) }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    if !history { Text(WheelL10n.format("days", entry.days)).font(font(14, .bold)).foregroundStyle(GiftWheelPalette.violet) }
                }.padding(.vertical, 10).multilineTextAlignment(.leading).accessibilityElement(children: .combine)
            }
        }
    }
    private var actionTitle: String {
        let key: String
        if state.loading { key = "loading" }
        else if state.submitting { key = "submitting" }
        else if state.spinning { key = "spinning" }
        else if isSignedIn && state.needsLogin { key = "profile" }
        else if login { key = "login" }
        else if retryLoad { key = "retryLoad" }
        else if state.pendingRetry { key = "recover" }
        else if state.status?.canSpin == true { key = "spin" }
        else { key = "waiting" }
        return WheelL10n.text(key)
    }
    private func availability(_ status: GiftWheelStatusDTO) -> String {
        switch status.availability {
        case "paused": WheelL10n.text("paused")
        case "account_wait": WheelL10n.text("accountWait")
        case "not_allowed": WheelL10n.text("notAllowed")
        default: status.quota.remaining < 0 ? WheelL10n.text("unlimited") : (status.quota.remaining > 0 ? WheelL10n.format("remaining", status.quota.remaining) : WheelL10n.text("exhausted"))
        }
    }
}
