import Foundation

/// A single lifelog entry: one recorded/transcribed segment from the Pendant.
///
/// This mirrors the `Lifelog` object returned by `GET /v1/lifelogs`. `markdown` is the
/// flattened transcript; `contents` is the same content as a structured tree with speaker
/// attribution and timing. `updatedAt` is the key used for incremental sync.
public struct Lifelog: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    /// Flattened markdown transcript. Absent when `includeMarkdown=false` was requested.
    public let markdown: String?
    public let startTime: Date?
    public let endTime: Date?
    public let isStarred: Bool
    /// Server-side last-modified timestamp. Drives delta sync.
    public let updatedAt: Date?
    /// Structured transcript tree (headings, paragraphs, speaker blocks).
    public let contents: [ContentNode]

    public init(
        id: String,
        title: String,
        markdown: String? = nil,
        startTime: Date? = nil,
        endTime: Date? = nil,
        isStarred: Bool = false,
        updatedAt: Date? = nil,
        contents: [ContentNode] = []
    ) {
        self.id = id
        self.title = title
        self.markdown = markdown
        self.startTime = startTime
        self.endTime = endTime
        self.isStarred = isStarred
        self.updatedAt = updatedAt
        self.contents = contents
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, markdown, startTime, endTime, isStarred, updatedAt, contents
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        markdown = try c.decodeIfPresent(String.self, forKey: .markdown)
        startTime = try c.decodeIfPresent(Date.self, forKey: .startTime)
        endTime = try c.decodeIfPresent(Date.self, forKey: .endTime)
        isStarred = try c.decodeIfPresent(Bool.self, forKey: .isStarred) ?? false
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt)
        contents = try c.decodeIfPresent([ContentNode].self, forKey: .contents) ?? []
    }
}
