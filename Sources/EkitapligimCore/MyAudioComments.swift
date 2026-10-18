import Foundation

public protocol MyAudioCommentsServing: Sendable {
    func audioComments(page: Int) async throws -> MyAudioCommentsPageDTO
}

extension ProfileRepository: MyAudioCommentsServing {}

/// The explicit scope prevents an older server's generic forum history from being shown as audio comments.
public struct MyAudioCommentsPageDTO: Decodable, Equatable, Sendable {
    public let comments: [ForumPostDTO]
    public let currentPage: Int
    public let lastPage: Int
    public let total: Int?

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard try container.decode(String.self, forKey: .scope) == "audio" else {
            throw DecodingError.dataCorruptedError(forKey: .scope, in: container, debugDescription: "Expected personal audio comments")
        }
        let result = try MyCommentsPageDTO(from: decoder)
        guard let page = result.currentPage, page > 0,
              let pages = result.lastPage, pages >= page,
              result.total.map({ $0 >= 0 }) ?? true,
              result.comments.allSatisfy({ Int($0.id).map { $0 > 0 } == true && Int($0.threadId).map { $0 > 0 && $0 <= Int32.max } == true }) else {
            throw DecodingError.dataCorruptedError(forKey: .scope, in: container, debugDescription: "Invalid personal audio comment page")
        }
        comments = result.comments
        currentPage = page
        lastPage = pages
        total = result.total
    }

    private enum CodingKeys: String, CodingKey { case scope }
}
