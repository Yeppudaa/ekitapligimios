import SwiftUI
import EkitapligimCore

struct BlockMemberView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss

    @State private var userID = ""
    @State private var statusMessage: String?
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L10n.blockMemberUserIdPlaceholder, text: $userID)
                        .keyboardType(.numberPad)
                } footer: {
                    Text(L10n.blockMemberFooter)
                }

                if let statusMessage {
                    Section {
                        Text(statusMessage)
                    }
                }

                Section {
                    Button(L10n.blockMemberSubmit, role: .destructive) {
                        Task { await block() }
                    }
                    .disabled(Int(userID) == nil || isSubmitting)
                }
            }
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
            try await container.safety.blockMember(userID: id)
            statusMessage = L10n.blockMemberSuccess
        } catch {
            statusMessage = L10n.blockMemberFailure
        }
    }
}
