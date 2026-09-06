import Foundation
import ReadiumShared
import ReadiumNavigator
import EkitapligimCore

@MainActor
final class EPUBPositionAdapter {
    let package: EPUBPackageIndex
    private let script: String
    private var fixedLayout = false

    init(asset: Asset) async throws {
        guard case .container(let asset) = asset,
              let containerEntry = asset.container.entries.first(where: { EPUBPackageIndex.normalizedPath($0.string) == "META-INF/container.xml" }),
              let containerResource = asset.container[containerEntry],
              let scriptURL = Bundle.main.url(forResource: "EPUBCFIBridge", withExtension: "js") else { throw EPUBPositionError.invalidPackage }
        let containerData = try await containerResource.read().get()
        let parserDelegate = RootfileParser()
        let parser = XMLParser(data: containerData)
        parser.shouldResolveExternalEntities = false
        parser.delegate = parserDelegate
        guard parser.parse(), let rootfile = parserDelegate.path,
              let packageEntry = asset.container.entries.first(where: { EPUBPackageIndex.normalizedPath($0.string) == EPUBPackageIndex.normalizedPath(rootfile) }),
              let resource = asset.container[packageEntry] else { throw EPUBPositionError.invalidPackage }
        package = try EPUBPackageIndex(opf: await resource.read().get(), packagePath: rootfile)
        script = try String(contentsOf: scriptURL, encoding: .utf8)
    }

    func initialLocator(_ position: ReaderPositionDTO?, publication: Publication) throws -> Locator? {
        fixedLayout = publication.metadata.layout == .fixed
        guard let position else { return nil }
        guard position.positionType == "epub", position.isValid else { throw EPUBPositionError.invalidCFI }
        let cfi = try EPUBCFI(position.positionValue)
        guard package.items.indices.contains(cfi.spineIndex) else { throw EPUBPositionError.missingResource }
        let item = package.items[cfi.spineIndex]
        guard item.cfiBase == "/\(cfi.packageSteps[0])/\(cfi.packageSteps[1])",
              let link = publication.readingOrder.first(where: { EPUBPackageIndex.normalizedPath($0.href) == item.href }) else {
            throw EPUBPositionError.missingResource
        }
        return Locator(href: link.href, mediaType: link.mediaType ?? .xhtml, locations: .init(otherLocations: ["cssSelector": .string(cfi.cssSelector)]))
    }

    func restore(_ position: ReaderPositionDTO, navigator: EPUBNavigatorViewController) async throws {
        // In fixed-layout EPUBs each spine resource is a complete page. initialLocation has
        // already selected that resource; there is no reflowable character offset to scroll.
        if fixedLayout { return }
        let cfi = try EPUBCFI(position.positionValue)
        let stepsData = try JSONEncoder().encode(cfi.contentSteps)
        guard let steps = String(data: stepsData, encoding: .utf8) else { throw EPUBPositionError.invalidCFI }
        let result = try await navigator.evaluateJavaScript(script + "\nekReaderCFI.restore(\(steps), \(cfi.textOffset));").get()
        guard result as? Bool == true else { throw EPUBPositionError.invalidCFI }
    }

    func current(locator: Locator, navigator: EPUBNavigatorViewController) async throws -> ReaderPositionDTO {
        guard let item = package.items.first(where: { $0.href == EPUBPackageIndex.normalizedPath(locator.href.string) }) else {
            throw EPUBPositionError.missingResource
        }
        let path: String
        if fixedLayout {
            path = "/4"
        } else {
            let result = try await navigator.evaluateJavaScript(script + "\nekReaderCFI.current();").get()
            guard let resolvedPath = result as? String else { throw EPUBPositionError.invalidCFI }
            path = resolvedPath
        }
        let position = ReaderPositionDTO(positionType: "epub", positionValue: "epubcfi(\(item.cfiBase)!\(path))",
            progressPercent: min(max((locator.locations.totalProgression ?? 0) * 100, 0), 100))
        guard position.isValid else { throw EPUBPositionError.invalidCFI }
        return position
    }

    private final class RootfileParser: NSObject, XMLParserDelegate {
        var path: String?
        func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
            if name.split(separator: ":").last == "rootfile", path == nil { path = attributes["full-path"] }
        }
    }
}
