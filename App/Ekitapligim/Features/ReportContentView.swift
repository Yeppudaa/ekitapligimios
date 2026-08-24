import SwiftUI
import EkitapligimCore

enum ReportKind: Equatable {
    case book(bookID: Int)
    case post(postID: Int)
}

@MainActor
struct ReportContentView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss

    let kind: ReportKind
    var initialType: String = "objectionable"
    var onCompleted: ((Bool) -> Void)? = nil

    @State private var reportType: String

    init(kind: ReportKind, initialType: String = "objectionable", onCompleted: ((Bool) -> Void)? = nil) {
        self.kind = kind
        self.initialType = initialType
        self.onCompleted = onCompleted
        _reportType = State(initialValue: initialType)
    }
    @State private var message = ""
    @State private var statusMessage: String?
    @State private var isSubmitting = false
    private let contentSafety = ContentSafety()

    var body: some View {
        NavigationStack {
            Form {
                reportDetailsSection
                reportStatusSection
                submitSection
            }
            .navigationTitle(screenTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.commonDismiss) { dismiss() }
                }
            }
        }
    }

    private var reportDetailsSection: some View {
        Section(footer: Text(L10n.reportFooter)) {
            if case .book = kind {
                Text(lockedTypeLabel)
            }
            Text(screenDescription)
                .font(.footnote)
                .foregroundStyle(Color(hex: descriptionInk))
            ZStack(alignment: .topLeading) {
                if message.isEmpty {
                    Text(screenPlaceholder)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $message)
                    .frame(minHeight: 120)
                    .scrollContentBackground(.hidden)
                    .accessibilityLabel(L10n.reportMessageLabel)
            }
        }
    }

    private var lockedTypeLabel: String {
        switch reportType {
        case "broken_link": L10n.bookDetailIssueBrokenLink
        case "missing_cover": L10n.bookDetailIssueMissingCover
        case "copyright": L10n.bookDetailIssueCopyright
        default: L10n.reportReason
        }
    }

    private var screenTitle: String {
        switch kind {
        case .post:
            return L10n.forumThreadReportPost
        case .book:
            switch reportType {
            case "broken_link": return L10n.bookDetailIssueBrokenLinkReportTitle
            case "missing_cover": return L10n.bookDetailIssueMissingCoverReportTitle
            case "copyright": return L10n.bookDetailIssueCopyrightReportTitle
            default: return L10n.reportTitle
            }
        }
    }

    private var screenDescription: String {
        switch kind {
        case .post:
            return L10n.forumThreadReportDescription
        case .book:
            switch reportType {
            case "broken_link": return L10n.bookDetailIssueBrokenLinkReportDescription
            case "missing_cover": return L10n.bookDetailIssueMissingCoverReportDescription
            case "copyright": return L10n.bookDetailIssueCopyrightReportDescription
            default: return L10n.reportFooter
            }
        }
    }

    private var screenPlaceholder: String {
        switch kind {
        case .post:
            return L10n.forumThreadReportPlaceholder
        case .book:
            switch reportType {
            case "broken_link": return L10n.bookDetailIssueBrokenLinkReportPlaceholder
            case "missing_cover": return L10n.bookDetailIssueMissingCoverReportPlaceholder
            case "copyright": return L10n.bookDetailIssueCopyrightReportPlaceholder
            default: return L10n.reportMessageLabel
            }
        }
    }

    private var submitTitle: String {
        switch kind {
        case .book: L10n.commonSubmit
        case .post: L10n.forumThreadReportSubmit
        }
    }

    @ViewBuilder
    private var reportStatusSection: some View {
        if let statusMessage {
            Section { Text(statusMessage) }
        }
    }

    private var submitSection: some View {
        Section {
            Button(submitTitle) { Task { await submit() } }
                .disabled(!canSubmit)
        }
    }

    private var trimmedMessage: String {
        message.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmit: Bool {
        if isSubmitting { return false }
        switch kind {
        case .book: return true
        case .post: return !trimmedMessage.isEmpty
        }
    }

    private func validatePayload(_ payload: String, allowEmpty: Bool) -> Bool {
        if allowEmpty && payload.isEmpty {
            return true
        }
        switch contentSafety.validateUserGeneratedText(payload) {
        case .accepted:
            return true
        case .rejected(let reason):
            statusMessage = reason.userMessage
            return false
        }
    }


    private var descriptionInk: UInt32 {
        switch kind {
        case .post: 0x5E6775
        case .book: 0x475467
        }
    }

    private func submit() async {
        let payload = trimmedMessage
        switch kind {
        case .book:
            guard validatePayload(payload, allowEmpty: true) else { return }
        case .post:
            guard !payload.isEmpty, validatePayload(payload, allowEmpty: false) else { return }
        }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            switch kind {
            case .book(let bookID):
                try await container.safety.reportBookIssue(bookID: bookID, type: reportType, message: payload)
            case .post(let postID):
                try await container.safety.reportForumPost(postID: postID, message: payload)
            }
            statusMessage = L10n.reportSubmitted
            onCompleted?(true)
            if case .book = kind { dismiss() }
        } catch {
            statusMessage = L10n.reportSubmitFailed
            onCompleted?(false)
        }
    }
}
