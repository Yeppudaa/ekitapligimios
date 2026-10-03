import Foundation

/// XenForo's CSS sprite cell. Kept separate from rendering so all dimensions can be validated.
public struct ChatReactionSpriteDTO: Decodable, Equatable, Sendable {
    public let width: Double
    public let height: Double
    public let x: Double
    public let y: Double
    public let backgroundSize: String

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        func number(_ key: CodingKeys) -> Double {
            if let value = try? values.decode(Double.self, forKey: key) { return value }
            if let text = try? values.decode(String.self, forKey: key), let value = Double(text) { return value }
            return .nan
        }
        width = number(.w)
        height = number(.h)
        x = number(.x)
        y = number(.y)
        backgroundSize = (try? values.decode(String.self, forKey: .bs)) ?? ""
    }

    private enum CodingKeys: String, CodingKey { case w, h, x, y, bs }

    public struct Viewport: Equatable, Sendable {
        public let sheetWidth: Double
        public let sheetHeight: Double
        public let offsetX: Double
        public let offsetY: Double
        public let cellWidth: Double
        public let cellHeight: Double
        public let insetX: Double
        public let insetY: Double
    }

    /// Converts web background-size and pixel offsets to a centered, clipped native cell.
    public func viewport(imageWidth: Double, imageHeight: Double, size: Double) -> Viewport? {
        guard [width, height, imageWidth, imageHeight, size].allSatisfy({ $0.isFinite && $0 > 0 }),
              x.isFinite, y.isFinite else { return nil }
        let specification = backgroundSize.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var sheetWidth = imageWidth, sheetHeight = imageHeight
        switch specification {
        case "", "auto", "auto auto": break
        case "contain", "cover":
            let ratio = specification == "contain" ? min(width / imageWidth, height / imageHeight)
                : max(width / imageWidth, height / imageHeight)
            sheetWidth *= ratio
            sheetHeight *= ratio
        default:
            let parts = specification.split(whereSeparator: { $0.isWhitespace }).map(String.init)
            guard (1...2).contains(parts.count) else { return nil }
            func dimension(_ value: String, extent: Double) -> Double? {
                if value == "auto" { return nil }
                if value.hasSuffix("px"), let number = Double(value.dropLast(2)) { return number }
                if value.hasSuffix("%"), let number = Double(value.dropLast()) { return extent * number / 100 }
                return .nan
            }
            let requestedWidth = dimension(parts[0], extent: width)
            let requestedHeight = dimension(parts.count == 2 ? parts[1] : "auto", extent: height)
            guard [requestedWidth, requestedHeight].compactMap({ $0 }).allSatisfy({ $0.isFinite && $0 > 0 }) else { return nil }
            if let requestedWidth { sheetWidth = requestedWidth }
            if let requestedHeight { sheetHeight = requestedHeight }
            if requestedWidth != nil && requestedHeight == nil { sheetHeight = imageHeight * sheetWidth / imageWidth }
            if requestedHeight != nil && requestedWidth == nil { sheetWidth = imageWidth * sheetHeight / imageHeight }
        }
        let scale = min(size / width, size / height)
        let insetX = (size - width * scale) / 2, insetY = (size - height * scale) / 2
        let result = Viewport(sheetWidth: sheetWidth * scale, sheetHeight: sheetHeight * scale,
                              offsetX: insetX + x * scale, offsetY: insetY + y * scale,
                              cellWidth: width * scale, cellHeight: height * scale, insetX: insetX, insetY: insetY)
        guard [result.sheetWidth, result.sheetHeight, result.offsetX, result.offsetY].allSatisfy(\.isFinite) else { return nil }
        return result
    }
}
