import Foundation

/// Top-level envelope for `GET /v1/lifelogs`.
///
/// Shape: `{ "data": { "lifelogs": [...] }, "meta": { "lifelogs": { "nextCursor": ..., "count": ... } } }`.
public struct LifelogsResponse: Codable, Sendable {
    public let data: DataPayload
    public let meta: Meta

    public struct DataPayload: Codable, Sendable {
        public let lifelogs: [Lifelog]
    }

    public struct Meta: Codable, Sendable {
        public let lifelogs: PageInfo

        public struct PageInfo: Codable, Sendable {
            /// Cursor for the next page, or `nil` when there are no more results.
            public let nextCursor: String?
            /// Number of entries in this page.
            public let count: Int?
        }
    }

    /// Convenience accessor for the entries in this page.
    public var lifelogs: [Lifelog] { data.lifelogs }
    /// Convenience accessor for the next-page cursor.
    public var nextCursor: String? { meta.lifelogs.nextCursor }
}
