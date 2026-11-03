import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Android's cover/paper geometry, independent of the renderer and executable on every Core platform.
public struct ReaderOpeningLayout: Sendable {
    public let viewport: CGSize
    public let coverSize: CGSize
    public let cornerRadius: CGFloat
    public let source: CGRect?
    public var isRenderable: Bool { viewport.width > 0 && viewport.height > 0 && coverSize.width > 0 }

    public init(viewport: CGSize, source: CGRect?, displayScale: CGFloat) {
        let viewport = CGSize(width: viewport.width.isFinite ? max(0, viewport.width) : 0,
                              height: viewport.height.isFinite ? max(0, viewport.height) : 0)
        self.viewport = viewport
        let bounds = CGRect(origin: .zero, size: viewport)
        self.source = source.flatMap { rect in
            guard !rect.isNull, !rect.isInfinite, !rect.isEmpty,
                  rect.width.isFinite, rect.height.isFinite, rect.width > 0, rect.height > 0,
                  rect.minX.isFinite, rect.minY.isFinite, rect.maxX.isFinite, rect.maxY.isFinite,
                  (rect.height / rect.width).isFinite, rect.height / rect.width > 0,
                  bounds.contains(rect) else { return nil }
            return rect
        }
        let aspect = self.source.map { $0.height / $0.width } ?? (250.0 / 170.0)
        let referenceScale = min(viewport.width / 390, 1.15)
        let pixels = displayScale.isFinite ? max(1, displayScale) : 1
        let referenceWidth = ((220 * referenceScale * pixels).rounded() / pixels).rounded()
        let width = min(max(1, referenceWidth), viewport.width * 0.72, viewport.height * 0.65 / aspect)
        coverSize = CGSize(width: width, height: width * aspect)
        cornerRadius = ((6 * referenceScale * pixels).rounded() / pixels).rounded()
    }

    public func coverRect(at frame: ReaderOpeningFrame) -> CGRect {
        guard isRenderable else { return .zero }
        let target = CGPoint(x: viewport.width / 2, y: viewport.height / 2 - 12)
        let origin = source.map { CGPoint(x: $0.midX, y: $0.midY) } ?? target
        let initialScale = source.map { $0.width / coverSize.width } ?? 0.76
        let scale = initialScale + (1 - initialScale) * frame.lift
        let center = CGPoint(x: origin.x + (target.x - origin.x) * frame.lift,
                             y: origin.y + (target.y - origin.y) * frame.lift)
        let size = CGSize(width: coverSize.width * scale, height: coverSize.height * scale)
        return CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2,
                      width: size.width, height: size.height)
    }

    public func paperRect(at frame: ReaderOpeningFrame) -> CGRect {
        guard isRenderable else { return .zero }
        let expansion = frame.paperExpansion
        let size = CGSize(width: coverSize.width + (viewport.width - coverSize.width) * expansion,
                          height: coverSize.height + (viewport.height - coverSize.height) * expansion)
        return CGRect(x: (viewport.width - size.width) / 2,
                      y: (viewport.height - size.height) / 2 - 12 * (1 - expansion),
                      width: size.width, height: size.height)
    }
}
