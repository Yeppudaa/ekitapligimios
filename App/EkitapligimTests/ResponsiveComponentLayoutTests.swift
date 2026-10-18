import SwiftUI
import UIKit
import XCTest
import EkitapligimCore
@testable import Ekitapligim

/// Real shared UI measured at narrow iPhone widths. No network or model mutation occurs.
/// Passing fitting bounds is necessary, but screenshots still need glyph/overlap review.
@MainActor
final class ResponsiveComponentLayoutTests: XCTestCase {
    private let widths: [CGFloat] = [320, 375, 390, 414]
    private let sizes: [DynamicTypeSize] = [.large, .xxxLarge, .accessibility3, .accessibility5]
    private let longText = "Kitaplığında yeni hikâyeler keşfet ve sevdiğin kitaplarla okumaya devam et."

    func testSharedCardsFitAndAccessibilityContentCanGrow() {
        for (name, view) in samples {
            for width in widths {
                var standardHeight: CGFloat = 0
                for size in sizes {
                    let host = host(view, size: size)
                    let fitted = host.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))
                    let context = "\(name), \(width)pt, \(size)"
                    XCTAssertTrue(fitted.width.isFinite && fitted.height.isFinite, context)
                    XCTAssertGreaterThan(fitted.height, 0, context)
                    XCTAssertLessThanOrEqual(fitted.width, width + 0.5, context)
                    if size == .large { standardHeight = fitted.height }
                    if size == .accessibility5 {
                        XCTAssertGreaterThan(fitted.height, standardHeight, context)
                    }
                }
            }
        }
    }

    func testSharedCardsRenderForNarrowWidthReview() {
        for (width, size) in [(CGFloat(390), DynamicTypeSize.large), (414, .large), (320, .accessibility5)] {
            let page = VStack(alignment: .leading, spacing: 20) {
                ForEach(Array(samples.enumerated()), id: \.offset) { _, sample in sample.1 }
            }
            let controller = host(AnyView(page), size: size)
            let fitted = controller.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))
            guard fitted.height.isFinite, fitted.height > 0, fitted.height < 30_000 else {
                XCTFail("Invalid fitted height: \(fitted)")
                continue
            }
            let bounds = CGRect(x: 0, y: 0, width: width, height: ceil(fitted.height))
            let window = UIWindow(frame: bounds)
            window.rootViewController = controller
            window.isHidden = false
            defer { window.isHidden = true; window.rootViewController = nil }
            controller.view.frame = bounds
            controller.view.setNeedsLayout()
            controller.view.layoutIfNeeded()
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            var rendered = false
            let image = UIGraphicsImageRenderer(bounds: bounds, format: format).image { _ in
                rendered = controller.view.drawHierarchy(in: bounds, afterScreenUpdates: true)
            }
            XCTAssertTrue(rendered)
            let attachment = XCTAttachment(image: image)
            attachment.name = "shared-layout-\(Int(width))pt-\(size)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    private func host(_ content: AnyView, size: DynamicTypeSize) -> UIHostingController<AnyView> {
        let view = content.fixedSize(horizontal: false, vertical: true).padding(16)
            .environment(\.dynamicTypeSize, size).environment(\.colorScheme, .light)
        let controller = UIHostingController(rootView: AnyView(view))
        controller.safeAreaRegions = []
        return controller
    }

    private var samples: [(String, AnyView)] {
        [
            ("sectionHeading", AnyView(EKitapligimSectionHeader(title: longText, subtitle: longText,
                                                                 actionTitle: "Bütün kitapları incele", action: {}))),
            ("modernHeading", AnyView(ModernSectionHeading(title: longText, subtitle: longText,
                                                          actionTitle: "Daha fazlasını keşfet", action: {}))),
            ("info", AnyView(EKInfoRow(label: "Kitap bilgileri", value: longText, systemImage: "book"))),
            ("quota", AnyView(EKQuotaCard(title: "Günlük okuma hakkınız", subtitle: longText, systemImage: "book",
                                          trailingValue: "10 / 10", trailingCaption: "Bugün kalan haklarınız", progress: 0.5,
                                          gradient: EKitapligimPalette.quotaReadGradient, isUnlimited: false))),
            ("inlineError", AnyView(EKInlineError(message: longText, retryTitle: "Yeniden deneyin", retry: {}))),
            ("shelfTile", AnyView(ModernShelfTile(title: longText, value: "1.234", icon: "books.vertical", action: {}))),
            ("forum", AnyView(EKForumListCard(forum: ForumDTO(id: "1", title: longText,
                                                              description: longText, threadCount: 1234)))),
            ("thread", AnyView(EKForumThreadRow(thread: ForumThreadDTO(id: "1", title: longText,
                                                                      username: "Kitaplarla yeni dünyalar keşfeden okur",
                                                                      replyCount: 9999, viewCount: 99999, postDate: 1)))),
            ("readerProgress", AnyView(ReaderEPUBProgress(percent: 37, detail: longText,
                                                         syncLabel: "Okuma ilerlemesi eşitleniyor", syncFailed: false, theme: .sepia))),
            ("collapsibleHero", AnyView(EKCollapsibleHero(progress: 0) {
                Text(self.longText).font(.title).padding(16)
            } collapsed: {
                Text("Kitap").font(.headline)
            }))
        ]
    }
}
