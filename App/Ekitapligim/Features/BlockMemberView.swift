import SwiftUI
import EkitapligimCore

@MainActor
struct BlockMemberView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss

    @State private var userID = ""
    @State private var reason: UGCReportReason = .harassment
    @State private var details = ""
    @State private var statusMessage: String?
    @State private var isSubmitting = false
    @State private var didSucceed = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(L10n.blockMemberFooter)
                        .font(.subheadline)
                        .foregroundStyle(EKitapligimPalette.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    TextField(L10n.blockMemberUserIdPlaceholder, text: $userID)
                        .keyboardType(.numberPad)
                        .padding(14)
                        .background(Color(hex: 0xF5F8F9), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    Picker(L10n.reportReason, selection: $reason) {
                        ForEach(UGCReportReason.allCases, id: \.rawValue) { item in
                            Text(item.localizedBlockTitle).tag(item)
                        }
                    }
                    .pickerStyle(.menu)

                    TextField(L10n.reportMessageLabel, text: $details, axis: .vertical)
                        .lineLimit(3...6)
                        .padding(14)
                        .background(Color(hex: 0xF5F8F9), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    if let statusMessage {
                        Text(statusMessage)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(didSucceed ? EKitapligimPalette.success : EKitapligimPalette.danger)
                    }

                    Button {
                        Task { await block() }
                    } label: {
                        Group {
                            if isSubmitting {
                                ProgressView().tint(.white)
                            } else {
                                Text(L10n.membersBlockAndReport)
                                    .font(.subheadline.weight(.bold))
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(EKitapligimPalette.danger, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(Int(userID) == nil || isSubmitting)
                }
                .padding(20)
            }
            .background(EKitapligimPalette.pageGradient.ignoresSafeArea())
            .navigationTitle(L10n.blockMemberTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.commonClose) { dismiss() }
                }
            }
        }
    }

    private func block() async {
        guard let id = Int(userID) else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            _ = try await container.safety.blockMember(
                userID: id,
                reason: reason,
                details: details.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            container.rememberBlockedUser(id)
            didSucceed = true
            statusMessage = L10n.blockMemberSuccess
        } catch {
            didSucceed = false
            statusMessage = L10n.blockMemberFailure
        }
    }
}

private extension UGCReportReason {
    var localizedBlockTitle: String {
        switch self {
        case .spam: L10n.ugcReasonSpam
        case .harassment: L10n.ugcReasonHarassment
        case .hate: L10n.ugcReasonHate
        case .sexual: L10n.ugcReasonSexual
        case .violence: L10n.ugcReasonViolence
        case .privacy: L10n.ugcReasonPrivacy
        case .copyright: L10n.ugcReasonCopyright
        case .other: L10n.ugcReasonOther
        }
    }
}
