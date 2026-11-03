import SwiftUI
import UIKit
import EkitapligimCore

/// Transient pixels from the current window only; never written to disk or uploaded.
struct ReaderOpeningSnapshot {
    let background: UIImage
    let cover: UIImage?
    let coverFrame: CGRect?
    let windowSize: CGSize
}

@MainActor
final class ReaderOpeningSource {
    weak var anchor: UIView?

    func capture() -> ReaderOpeningSnapshot? {
        guard let anchor, let window = anchor.window,
              window.bounds.width > 0, window.bounds.height > 0 else { return nil }
        let bounds = window.bounds
        let format = UIGraphicsImageRendererFormat()
        format.scale = window.screen.scale
        format.opaque = true
        var didCapture = false
        let background = UIGraphicsImageRenderer(size: bounds.size, format: format).image { context in
            context.cgContext.translateBy(x: -bounds.minX, y: -bounds.minY)
            didCapture = window.drawHierarchy(in: bounds, afterScreenUpdates: false)
        }
        guard didCapture else { return nil }
        let frame = anchor.convert(anchor.bounds, to: window).offsetBy(dx: -bounds.minX, dy: -bounds.minY)
        let viewport = CGRect(origin: .zero, size: bounds.size)
        var visibleBounds = viewport
        var ancestor = anchor.superview
        while let view = ancestor {
            if view.clipsToBounds {
                let clip = view.convert(view.bounds, to: window).offsetBy(dx: -bounds.minX, dy: -bounds.minY)
                visibleBounds = visibleBounds.intersection(clip)
            }
            ancestor = view.superview
        }
        // A scrolled-off or partially clipped hero cannot supply an intact cover image.
        let visible = frame.width > 0 && frame.height > 0 && visibleBounds.contains(frame)
        let pixels = CGRect(x: frame.minX * background.scale, y: frame.minY * background.scale,
                            width: frame.width * background.scale, height: frame.height * background.scale)
        let cover: UIImage?
        if visible, let pixels = background.cgImage?.cropping(to: pixels) {
            cover = UIImage(cgImage: pixels, scale: background.scale, orientation: .up)
        } else { cover = nil }
        return ReaderOpeningSnapshot(background: background, cover: cover,
                                     coverFrame: cover == nil ? nil : frame, windowSize: bounds.size)
    }
}

/// Measures in the presenting window, including when book detail is inside a sheet.
struct ReaderOpeningAnchor: UIViewRepresentable {
    let source: ReaderOpeningSource
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = false
        source.anchor = view
        return view
    }
    func updateUIView(_ view: UIView, context: Context) { source.anchor = view }
}

/// An explicit 1,400-point camera and left-edge hinge match the Android transform.
private struct ReaderCoverHinge: GeometryEffect {
    let degrees: Double
    func effectValue(size: CGSize) -> ProjectionTransform {
        var rotation = CATransform3DIdentity
        rotation.m34 = -1 / 1_400
        rotation = CATransform3DRotate(rotation, degrees * .pi / 180, 0, 1, 0)
        return ProjectionTransform(CGAffineTransform(translationX: 0, y: -size.height / 2))
            .concatenating(ProjectionTransform(rotation))
            .concatenating(ProjectionTransform(CGAffineTransform(translationX: 0, y: size.height / 2)))
    }
}

/// Stateless rendering also allows native tests to capture exact Android reference times.
struct ReaderOpeningArtwork: View {
    let book: BookDTO
    let snapshot: ReaderOpeningSnapshot?
    let theme: ReaderPaperTheme
    let frame: ReaderOpeningFrame
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        GeometryReader { geometry in
            let source = sourceFrame(in: geometry.size)
            let layout = ReaderOpeningLayout(viewport: geometry.size, source: source, displayScale: displayScale)
            let cover = layout.coverRect(at: frame)
            let paper = layout.paperRect(at: frame)
            ZStack(alignment: .topLeading) {
                Color(red: 17 / 255, green: 17 / 255, blue: 19 / 255)
                    .opacity(frame.backdropOpacity)
                if frame.paperVisible && layout.isRenderable {
                    theme.paper
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipShape(RoundedRectangle(cornerRadius: layout.cornerRadius))
                        .scaleEffect(x: paper.width / max(1, geometry.size.width),
                                     y: paper.height / max(1, geometry.size.height))
                        .position(x: paper.midX, y: paper.midY)
                        .accessibilityIdentifier("reader.opening.paper")
                }
                if layout.isRenderable {
                    coverArtwork
                        .frame(width: layout.coverSize.width, height: layout.coverSize.height)
                        .clipShape(RoundedRectangle(cornerRadius: layout.cornerRadius))
                        .shadow(color: .black.opacity(0.3), radius: 30, y: 12)
                        .modifier(ReaderCoverHinge(degrees: frame.coverAngle))
                        .opacity(frame.coverOpacity)
                        .scaleEffect(cover.width / layout.coverSize.width)
                        .position(x: cover.midX, y: cover.midY)
                        .accessibilityIdentifier("reader.opening.cover")
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
            .opacity(frame.overlayOpacity)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder private var coverArtwork: some View {
        if frame.coverAngle <= -90 {
            LinearGradient(stops: [
                .init(color: Color(red: 230 / 255, green: 221 / 255, blue: 204 / 255), location: 0),
                .init(color: theme.paper, location: 0.3), .init(color: theme.paper, location: 1)
            ], startPoint: .leading, endPoint: .trailing)
            .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0), perspective: 0)
        } else {
            Group {
                if let image = snapshot?.cover {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    EKitapligimRemoteCover(urlString: book.coverUrl, title: book.title, author: book.author)
                }
            }
            .overlay {
                LinearGradient(colors: [.clear, .black.opacity(frame.coverShadeOpacity)],
                               startPoint: .leading, endPoint: .trailing)
            }
        }
    }

    private func sourceFrame(in size: CGSize) -> CGRect? {
        guard size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0,
              let snapshot, let frame = snapshot.coverFrame,
              snapshot.windowSize.width > 0, snapshot.windowSize.height > 0 else { return nil }
        let x = size.width / snapshot.windowSize.width
        let y = size.height / snapshot.windowSize.height
        return CGRect(x: frame.minX * x, y: frame.minY * y, width: frame.width * x, height: frame.height * y)
    }
}

/// The cover owns the existing full-screen reader presentation. The normal modal
/// slide is suppressed at the call site, so it cannot compete with this animation.
@MainActor
struct ReaderOpeningPresentation<Reader: View>: View {
    let book: BookDTO
    @Binding var snapshot: ReaderOpeningSnapshot?
    let onCancel: () -> Void
    let reader: () -> Reader
    private let reduceMotionOverride: Bool?
    @AppStorage("reader.paperTheme") private var paperThemeRaw = ReaderPaperTheme.sepia.rawValue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var sequence: ReaderOpeningSequence
    @State private var phase: ReaderOpeningSequence.Phase = .idle
    @State private var didRequestDismissal = false

    init(book: BookDTO, snapshot: Binding<ReaderOpeningSnapshot?>, onCancel: @escaping () -> Void,
         sequence: ReaderOpeningSequence? = nil, reduceMotionOverride: Bool? = nil,
         @ViewBuilder reader: @escaping () -> Reader) {
        self.book = book
        _snapshot = snapshot
        self.onCancel = onCancel
        _sequence = State(initialValue: sequence ?? ReaderOpeningSequence())
        self.reduceMotionOverride = reduceMotionOverride
        self.reader = reader
    }

    private var theme: ReaderPaperTheme { ReaderPaperTheme(rawValue: paperThemeRaw) ?? .sepia }
    private var effectiveReduceMotion: Bool { reduceMotionOverride ?? reduceMotion }

    var body: some View {
        ZStack {
            if phase.showsReader {
                reader()
                    .allowsHitTesting(phase == .finished)
                    .accessibilityHidden(phase != .finished)
            } else if let background = snapshot?.background {
                GeometryReader { geometry in
                    Image(uiImage: background).resizable()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }
                .ignoresSafeArea()
                .accessibilityHidden(true)
            } else {
                theme.paper.ignoresSafeArea()
            }
            if phase != .finished && phase != .cancelled {
                TimelineView(.animation) { _ in
                    let elapsed = sequence.elapsedMilliseconds
                    if sequence.reducesMotion || effectiveReduceMotion {
                        theme.paper.opacity(max(0, 1 - elapsed / ReaderOpeningFrame.reducedMotionMilliseconds))
                    } else {
                        ReaderOpeningArtwork(book: book, snapshot: snapshot, theme: theme,
                                             frame: ReaderOpeningFrame(elapsedMilliseconds: elapsed))
                    }
                }
                .ignoresSafeArea()
                .statusBarHidden(true)
                .persistentSystemOverlays(.hidden)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(ReaderL10n.text("opening.title"))
                .accessibilityValue(book.title)
                .accessibilityIdentifier("reader.opening.transition")
                VStack {
                    HStack {
                        Button(action: cancel) {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .semibold))
                                .frame(width: 44, height: 44)
                                .background(theme.panel.opacity(0.95), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(theme.ink)
                        .accessibilityLabel(L10n.commonClose)
                        .accessibilityIdentifier("reader.opening.cancel")
                        Spacer(minLength: 0)
                    }
                    Spacer(minLength: 0)
                }.padding(.horizontal, 12).padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            GeometryReader { geometry in
                Color.clear.onChange(of: geometry.size.width) { previous, current in
                    if previous > 0, abs(current - previous) > 1,
                       phase == .opening || phase == .revealing { sequence.finish() }
                }
            }.ignoresSafeArea()
        }
        .presentationBackground(.clear)
        .interactiveDismissDisabled(phase != .finished)
        .accessibilityAction(.escape, cancel)
        .task {
            await sequence.run(reduceMotion: effectiveReduceMotion) { next in
                phase = next
                if next == .finished || next == .cancelled { snapshot = nil }
                if next == .cancelled { dismissPresentation() }
            }
        }
        .onChange(of: effectiveReduceMotion) { _, enabled in if enabled { sequence.finish() } }
        .onChange(of: scenePhase) { _, next in if next == .background { sequence.finish() } }
        .onDisappear { sequence.presentationDisappeared() }
    }

    private func cancel() {
        sequence.cancel()
        dismissPresentation()
    }

    private func dismissPresentation() {
        guard !didRequestDismissal else { return }
        didRequestDismissal = true
        snapshot = nil
        onCancel()
    }
}
