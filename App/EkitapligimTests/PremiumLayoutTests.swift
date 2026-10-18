import SwiftUI
import UIKit
import XCTest
@testable import Ekitapligim

/// Hosted rendering checks. Run on an iOS simulator; review the attached images for text clipping.
@MainActor
final class PremiumLayoutTests: XCTestCase {
    private let widths: [CGFloat] = [320, 375, 390, 393, 414]
    private let sizes: [DynamicTypeSize] = [.large, .xLarge, .accessibility3, .accessibility5]

    func testCardsFitNarrowScreensAndGrowWithDynamicType() {
        for card in Card.allCases {
            for width in widths {
                for darkAndDisabled in [false, true] {
                    var standardHeight: CGFloat = 0
                    for size in sizes {
                        let host = makeHost(card.view(availableWidth: width - 32), width: width, size: size,
                                            darkAndDisabled: darkAndDisabled)
                        let fitted = fittingSize(host, width: width)
                        let context = "\(card.rawValue), \(width)pt, \(size), dark/disabled=\(darkAndDisabled)"
                        XCTAssertTrue(fitted.width.isFinite && fitted.height.isFinite, context)
                        XCTAssertGreaterThan(fitted.width, 0, context)
                        XCTAssertLessThanOrEqual(fitted.width, width + 0.5, context)
                        XCTAssertGreaterThan(fitted.height, 0, context)
                        XCTAssertLessThan(fitted.height, 20_000, context)
                        if size == .large { standardHeight = fitted.height }
                        if size == .accessibility5 {
                            XCTAssertGreaterThan(fitted.height, standardHeight, context)
                        }
                    }
                }
            }
        }
    }

    func testLongTurkishAndEnglishPlanLabelsExpandVertically() {
        let longNames = [
            "Bir yıl boyunca bütün kitaplarını yanında taşıyabileceğin Premium üyelik planı",
            "Premium membership for a whole year of reading and listening wherever you go"
        ]
        for width in widths {
            for size in [DynamicTypeSize.large, .accessibility5] {
                let short = fittingSize(makeHost(plan(name: "Premium"), width: width, size: size), width: width)
                for name in longNames {
                    let long = fittingSize(makeHost(plan(name: name), width: width, size: size), width: width)
                    XCTAssertLessThanOrEqual(long.width, width + 0.5)
                    XCTAssertGreaterThan(long.height, short.height, "\(width)pt, \(size), \(name)")
                }
            }
        }
    }

    func testRenderNarrowLayoutReviewAttachments() {
        let scenarios: [(CGFloat, DynamicTypeSize, Bool)] = [
            (320, .large, false), (375, .xLarge, false), (393, .large, false),
            (393, .accessibility3, true), (320, .accessibility5, true)
        ]
        for (width, size, darkAndDisabled) in scenarios {
            let page = VStack(alignment: .leading, spacing: 24) {
                PremiumHeroCard(membershipStatus: "Premium üyeliğiniz etkin") {}
                PremiumAudioBenefitCard()
                PremiumQuotaCards(availableWidth: width - 32)
                PremiumExtraBenefitsCard()
                plan(name: "Yıllık Premium / Annual Premium")
            }
            let host = makeHost(AnyView(page), width: width, size: size,
                                darkAndDisabled: darkAndDisabled)
            let fitted = fittingSize(host, width: width)
            guard fitted.width.isFinite, fitted.height.isFinite,
                  fitted.height > 0, fitted.height < 20_000 else {
                XCTFail("Cannot render invalid fitted size: \(fitted)")
                continue
            }
            let bounds = CGRect(origin: .zero, size: CGSize(width: width, height: ceil(fitted.height)))
            let window = UIWindow(frame: bounds)
            window.overrideUserInterfaceStyle = darkAndDisabled ? .dark : .light
            window.rootViewController = host
            window.isHidden = false
            defer { window.isHidden = true; window.rootViewController = nil }
            host.view.frame = bounds
            host.view.setNeedsLayout()
            host.view.layoutIfNeeded()
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            let renderer = UIGraphicsImageRenderer(bounds: bounds, format: format)
            var rendered = false
            let image = renderer.image { _ in
                rendered = host.view.drawHierarchy(in: bounds, afterScreenUpdates: true)
            }
            XCTAssertTrue(rendered, "UIKit did not finish rendering the hosted Premium content")
            XCTAssertEqual(image.size.width, width, accuracy: 0.5)
            let attachment = XCTAttachment(image: image)
            attachment.name = "Premium-\(Int(width))pt-\(size)-\(darkAndDisabled ? "dark-disabled" : "light")"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    private func makeHost(_ view: AnyView, width: CGFloat, size: DynamicTypeSize,
                          darkAndDisabled: Bool = false) -> UIHostingController<AnyView> {
        let content = view
            .fixedSize(horizontal: false, vertical: true)
            .padding(16)
            .background(PremiumStyle.page)
            .environment(\.dynamicTypeSize, size)
            .environment(\.colorScheme, darkAndDisabled ? .dark : .light)
            .disabled(darkAndDisabled)
        let host = UIHostingController(rootView: AnyView(content))
        host.safeAreaRegions = []
        host.overrideUserInterfaceStyle = darkAndDisabled ? .dark : .light
        host.view.frame = CGRect(x: 0, y: 0, width: width, height: 1)
        return host
    }

    private func fittingSize(_ host: UIHostingController<AnyView>, width: CGFloat) -> CGSize {
        host.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))
    }

    private func plan(name: String) -> AnyView {
        AnyView(Button {} label: {
            PremiumPlanCard(name: name, price: "₺ 123.456,78", period: "12 ay / 12 months",
                            tagline: "Kitaplarını yanında taşı. Take your library with you.", isYearly: true)
        }.buttonStyle(PremiumPressStyle()))
    }

    private enum Card: String, CaseIterable {
        case hero, audio, reading, downloads, quotas, extras, plan

        @MainActor func view(availableWidth: CGFloat) -> AnyView {
            switch self {
            case .hero:
                AnyView(PremiumHeroCard(membershipStatus: "Premium üyeliğiniz etkin") {})
            case .audio:
                AnyView(PremiumAudioBenefitCard())
            case .reading:
                AnyView(PremiumQuotaCard(kind: "reading", artwork: "audio_shelf_continue", systemImage: "book.fill"))
            case .downloads:
                AnyView(PremiumQuotaCard(kind: "downloads", artwork: "catalog_scenic_reading", systemImage: "icloud.and.arrow.down.fill"))
            case .quotas:
                AnyView(PremiumQuotaCards(availableWidth: availableWidth))
            case .extras:
                AnyView(PremiumExtraBenefitsCard())
            case .plan:
                AnyView(Button {} label: {
                    PremiumPlanCard(name: "Yıllık Premium / Annual Premium", price: "₺ 123.456,78",
                                    period: "12 ay / 12 months", tagline: "Kitaplığın yanında.", isYearly: true)
                }.buttonStyle(PremiumPressStyle()))
            }
        }
    }
}
