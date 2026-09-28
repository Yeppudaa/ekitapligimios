import SwiftUI
import EkitapligimCore

extension ReaderPaperTheme {
    var paper: Color {
        switch self {
        case .sepia: Color(red: 244/255, green: 236/255, blue: 216/255)
        case .white: .white
        case .night: Color(white: 30/255)
        }
    }
    var ink: Color {
        switch self {
        case .sepia: Color(red: 67/255, green: 52/255, blue: 34/255)
        case .white: Color(white: 17/255)
        case .night: Color(white: 225/255)
        }
    }
    var accent: Color {
        self == .night ? Color(red: 207/255, green: 180/255, blue: 132/255) : Color(red: 120/255, green: 82/255, blue: 44/255)
    }
    var panel: Color { self == .night ? Color(white: 0.16) : .white.opacity(0.94) }
    var colorScheme: ColorScheme { self == .night ? .dark : .light }
}

/// Stable modifier hierarchy: changing paper color never recreates PDFView or restores the initial page.
struct ReaderPDFPaper: ViewModifier {
    let theme: ReaderPaperTheme
    func body(content: Content) -> some View {
        content
            .overlay { Color.white.opacity(theme == .night ? 1 : 0).blendMode(.difference).allowsHitTesting(false).accessibilityHidden(true) }
            .overlay { Color(white: 30/255).opacity(theme == .night ? 1 : 0).blendMode(.screen).allowsHitTesting(false).accessibilityHidden(true) }
            .compositingGroup()
            .colorMultiply(theme == .night ? theme.ink : theme.paper)
    }
}

struct ReaderLoadingView: View {
    let title: String
    let author: String
    let phase: ReaderLoadingPhase
    let theme: ReaderPaperTheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var step: Int {
        switch phase {
        case .authorizing, .restoring: 0
        case .downloading: 1
        case .validating, .opening: 2
        }
    }
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 28) {
                    VStack(spacing: 22) {
                        Text(ReaderL10n.text("loading.eyebrow"))
                            .font(.caption2.weight(.semibold)).tracking(2.5).foregroundStyle(theme.accent)
                        ZStack {
                            Circle().fill(theme.accent.opacity(0.05)).frame(width: 168, height: 168)
                            RoundedRectangle(cornerRadius: 5).fill(theme.ink.opacity(0.1))
                                .frame(width: 94, height: 126).rotationEffect(.degrees(9)).offset(x: 7, y: 2)
                            RoundedRectangle(cornerRadius: 5)
                                .fill(LinearGradient(colors: [theme.accent, theme.accent.opacity(0.72)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 94, height: 126)
                                .shadow(color: theme.ink.opacity(0.16), radius: 12, x: 0, y: 8)
                            Rectangle().fill(.white.opacity(0.15)).frame(width: 2, height: 120).offset(x: -35)
                            VStack(spacing: 14) {
                                Image(systemName: "book.pages").font(.system(size: 29, weight: .ultraLight))
                                Rectangle().fill(.white.opacity(0.4)).frame(width: 30, height: 1)
                            }.foregroundStyle(theme.paper)
                        }.accessibilityHidden(true)
                        VStack(spacing: 8) {
                            Text(title).font(.title2.weight(.semibold)).multilineTextAlignment(.center)
                            if !author.isEmpty { Text(author).font(.subheadline).foregroundStyle(theme.ink.opacity(0.65)) }
                        }
                    }
                    VStack(spacing: 16) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(phase.title).font(.subheadline.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 8)
                            if let percent = phase.transfer?.percent {
                                Text(Double(percent) / 100, format: .percent.precision(.fractionLength(0)))
                                    .font(.title2.monospacedDigit().weight(.semibold))
                                    .contentTransition(.numericText()).accessibilityIdentifier("reader.loading.percent")
                            }
                        }
                        if let fraction = phase.transfer?.fraction {
                            ProgressView(value: fraction).tint(theme.accent).accessibilityLabel(phase.title)
                        } else {
                            HStack(spacing: 10) {
                                ProgressView().tint(theme.accent)
                                Text(ReaderL10n.text(phase.transfer == nil ? "loading.pleaseWait" : "loading.unknownSize"))
                                    .font(.caption).foregroundStyle(theme.ink.opacity(0.65))
                                Spacer(minLength: 0)
                            }
                        }
                        if let transfer = phase.transfer, transfer.receivedBytes > 0 {
                            Text(transfer.byteDescription).font(.caption.monospacedDigit()).frame(maxWidth: .infinity, alignment: .leading)
                                .foregroundStyle(theme.ink.opacity(0.65)).accessibilityIdentifier("reader.loading.bytes")
                        }
                        Rectangle().fill(theme.ink.opacity(0.08)).frame(height: 1)
                        if dynamicTypeSize.isAccessibilitySize {
                            VStack(alignment: .leading, spacing: 12) { steps }
                        } else { HStack(spacing: 0) { steps } }
                    }
                    .padding(22).background(theme.panel.opacity(0.65), in: RoundedRectangle(cornerRadius: 22))
                    .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(theme.ink.opacity(0.06)))
                    Text(ReaderL10n.text("loading.note")).font(.footnote).lineSpacing(4)
                        .foregroundStyle(theme.ink.opacity(0.65)).multilineTextAlignment(.center)
                }
                .foregroundStyle(theme.ink).padding(.horizontal, 28).padding(.vertical, 70).frame(maxWidth: 480)
                .frame(maxWidth: .infinity, minHeight: geometry.size.height)
            }.scrollBounceBehavior(.basedOnSize)
        }
        .background(theme.paper)
        .accessibilityElement(children: .contain).accessibilityIdentifier("reader.loading")
    }
    @ViewBuilder private var steps: some View {
        ForEach(0..<3) { index in
            HStack(spacing: 6) {
                Image(systemName: index < step ? "checkmark.circle.fill" : (index == step ? "circle.inset.filled" : "circle"))
                    .accessibilityHidden(true)
                Text(ReaderL10n.text("loading.step\(index)"))
                    .font(.caption2.weight(index == step ? .semibold : .regular))
            }
            .foregroundStyle(index <= step ? theme.accent : theme.ink.opacity(0.45))
            .accessibilityElement(children: .combine)
            .accessibilityValue(ReaderL10n.text(index < step ? "loading.done" : (index == step ? "loading.current" : "loading.next")))
            if index < 2 && !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 4) }
        }
    }
}
struct ReaderChrome: View {
    let title: String
    let detail: String
    let theme: ReaderPaperTheme
    let isBookmarked: Bool
    let supportsPDF: Bool
    let enabled: Bool
    let close: () -> Void
    let focus: () -> Void
    let changeTheme: () -> Void
    let bookmark: () -> Void
    let bookmarks: () -> Void
    let pages: () -> Void
    let settings: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                ReaderIconButton(icon: "chevron.left", label: L10n.commonClose, theme: theme, action: close)
                    .accessibilityIdentifier("reader.close")
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.subheadline.weight(.bold)).lineLimit(1)
                    Text(detail).font(.caption2.monospacedDigit()).foregroundStyle(theme.ink.opacity(0.65)).lineLimit(1)
                }.frame(maxWidth: .infinity, alignment: .leading)
                ReaderIconButton(icon: "arrow.up.left.and.arrow.down.right", label: ReaderL10n.text("focus"), theme: theme, action: focus)
                    .accessibilityIdentifier("reader.focus")
            }
            HStack(spacing: 6) {
                ReaderIconButton(icon: "circle.lefthalf.filled", label: ReaderL10n.text("changeTheme"), theme: theme, action: changeTheme)
                    .accessibilityValue(theme.title).accessibilityIdentifier("reader.theme")
                if supportsPDF {
                    ReaderIconButton(icon: isBookmarked ? "bookmark.fill" : "bookmark", label: isBookmarked ? L10n.readerRemoveBookmark : L10n.readerAddBookmark, theme: theme, action: bookmark).disabled(!enabled)
                    ReaderIconButton(icon: "list.bullet", label: L10n.readerBookmarks, theme: theme, action: bookmarks).disabled(!enabled)
                    ReaderIconButton(icon: "square.grid.2x2", label: L10n.readerPages, theme: theme, action: pages).disabled(!enabled)
                }
                ReaderIconButton(icon: "slider.horizontal.3", label: L10n.readerSettings, theme: theme, action: settings).disabled(!enabled)
            }
        }.padding(8).foregroundStyle(theme.ink).frame(maxWidth: 760)
            .background(theme.panel, in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(theme.ink.opacity(0.08)))
            .shadow(color: .black.opacity(0.08), radius: 16, y: 4).padding(.horizontal, 10).padding(.top, 6)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("reader.toolbar")
    }
}

struct ReaderIconButton: View {
    let icon: String
    let label: String
    let theme: ReaderPaperTheme
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 18, weight: .medium))
                .frame(width: 44, height: 44).background(theme.ink.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))
        }.buttonStyle(.plain).foregroundStyle(theme.ink).accessibilityLabel(label)
    }
}

struct ReaderPageControls: View {
    let progress: ReadingProgress
    let accessiblePageLimit: Int
    let hasLockedContent: Bool
    let detail: String
    let syncLabel: String
    let syncFailed: Bool
    let theme: ReaderPaperTheme
    let onRequestPage: (Int) -> Void
    @State private var dragPage: Double?
    private var upper: Int { max(1, hasLockedContent ? accessiblePageLimit : progress.totalPages) }
    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 6) {
                ReaderIconButton(icon: "chevron.left", label: L10n.readerPreviousPage, theme: theme) { onRequestPage(max(1, progress.currentPage - 1)) }
                    .disabled(progress.currentPage <= 1)
                Slider(value: Binding(get: { dragPage ?? Double(min(progress.currentPage, upper)) }, set: { dragPage = $0 }),
                       in: 1...Double(max(2, upper)), step: 1, onEditingChanged: { editing in
                    if !editing, let dragPage { onRequestPage(min(upper, Int(dragPage))); self.dragPage = nil }
                })
                .disabled(upper <= 1).tint(theme.accent)
                .accessibilityLabel(L10n.readerPageSlider)
                .accessibilityValue(L10n.readerPage(Int(dragPage ?? Double(progress.currentPage)), progress.totalPages))
                .accessibilityAdjustableAction { direction in
                    onRequestPage(min(upper, max(1, progress.currentPage + (direction == .increment ? 1 : -1))))
                }
                ReaderIconButton(icon: "chevron.right", label: L10n.readerNextPage, theme: theme) { onRequestPage(progress.currentPage + 1) }
                    .disabled(!hasLockedContent && progress.currentPage >= progress.totalPages)
            }
            HStack {
                Text(detail).lineLimit(2)
                Spacer(minLength: 8)
                Label(syncLabel, systemImage: syncFailed ? "icloud.slash" : "checkmark.icloud")
                    .lineLimit(1).accessibilityIdentifier("reader.sync")
            }.font(.caption2).foregroundStyle(theme.ink.opacity(0.65)).padding(.horizontal, 8).padding(.bottom, 6)
        }.padding(8).frame(maxWidth: 760).background(theme.panel, in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(theme.ink.opacity(0.08)))
            .padding(.horizontal, 10).padding(.bottom, 6)
            .accessibilityElement(children: .contain).accessibilityIdentifier("reader.controls")
    }
}

struct ReaderEPUBProgress: View {
    let percent: Double
    let detail: String
    let syncLabel: String
    let syncFailed: Bool
    let theme: ReaderPaperTheme

    var body: some View {
        VStack(spacing: 12) {
            ProgressView(value: min(100, max(0, percent)), total: 100)
                .tint(theme.accent).accessibilityLabel(detail)
            HStack {
                Text(detail).monospacedDigit().lineLimit(2)
                Spacer(minLength: 8)
                Label(syncLabel, systemImage: syncFailed ? "icloud.slash" : "checkmark.icloud")
                    .lineLimit(1).accessibilityIdentifier("reader.sync")
            }.font(.caption2).foregroundStyle(theme.ink.opacity(0.65))
        }
        .padding(16).frame(maxWidth: 760).background(theme.panel, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(theme.ink.opacity(0.08)))
        .padding(.horizontal, 10).padding(.bottom, 6)
        .accessibilityElement(children: .contain).accessibilityIdentifier("reader.controls")
    }
}

struct ReaderThemePicker: View {
    @Binding var selection: String
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: dynamicTypeSize.isAccessibilitySize ? 1 : 3), spacing: 10) {
            ForEach(ReaderPaperTheme.allCases, id: \.rawValue) { theme in
                Button { selection = theme.rawValue } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "textformat").font(.system(size: 24, weight: .regular, design: .serif)).accessibilityHidden(true)
                        Text(theme.title).font(.caption.weight(.semibold))
                        Image(systemName: selection == theme.rawValue ? "checkmark.circle.fill" : "circle")
                            .font(.caption).accessibilityHidden(true)
                    }
                    .foregroundStyle(theme.ink).padding(.vertical, 16).frame(maxWidth: .infinity)
                    .background(theme.paper, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(theme.accent.opacity(selection == theme.rawValue ? 1 : 0.15), lineWidth: selection == theme.rawValue ? 2 : 1))
                }.buttonStyle(.plain).accessibilityLabel(theme.title)
                    .accessibilityAddTraits(selection == theme.rawValue ? [.isSelected] : [])
                    .accessibilityIdentifier("reader.theme.\(theme.rawValue)")
            }
        }
    }
}
