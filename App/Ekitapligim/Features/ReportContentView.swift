import SwiftUI
import EkitapligimCore

enum ReportKind: Equatable {
    case book(bookID: Int)
    case post(postID: Int)
}

struct ReportContentView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss

    let kind: ReportKind

    @State private var reportType = "objectionable"
    @State private var message = ""
    @State private var statusMessage: String?
    @State private var isSubmitting = false
    private let contentSafety = ContentSafety()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(L10n.reportReason, selection: $reportType) {
                        Text(L10n.reportObjectionable).tag("objectionable")
                        Text(L10n.reportCopyright).tag("copyright")
                        Text(L10n.reportBrokenFile).tag("broken_file")
                        Text(L10n.reportOther).tag("other")
                    }
                    TextEditor(text: $message)
                        .frame(minHeight: 120)
                        .accessibilityLabel(L10n.reportMessageLabel)
                } footer: {
                    Text(L10n.reportFooter)
                }

                if let statusMessage {
                    Section {
                        Text(statusMessage)
                    }
                }

                Section {
                    Button(L10n.reportSubmit) {
                        Task { await submit() }
                    }
                    .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).count < 8 || isSubmitting)
                }
            }
            .navigationTitle(L10n.reportTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.commonClose) { dismiss() }
                }
            }
        }
    }

    private func submit() async {
        switch contentSafety.validateUserGeneratedText(message) {
        case .accepted:
            break
        case .rejected(let reason):
            statusMessage = reason.userMessage
            return
        }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            switch kind {
            case .book(let bookID):
                try await container.safety.reportBookIssue(bookID: bookID, type: reportType, message: message)
            case .post(let postID):
                try await container.safety.reportForumPost(postID: postID, message: message)
            }
            statusMessage = L10n.reportSubmitted
        } catch {
            statusMessage = L10n.reportSubmitFailed
        }
    }
}
