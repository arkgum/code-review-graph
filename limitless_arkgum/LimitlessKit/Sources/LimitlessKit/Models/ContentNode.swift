import Foundation

/// A single node in a lifelog's structured transcript tree.
///
/// The Limitless API returns transcript content as a nested tree of nodes: headings,
/// paragraphs, and speaker-attributed blocks. Timing is expressed both as absolute
/// timestamps and as offsets (in milliseconds) from the start of the recording.
public struct ContentNode: Codable, Hashable, Sendable {
    /// Node type, e.g. `"heading1"`, `"heading2"`, `"blockquote"`, `"paragraph"`.
    public let type: String
    /// Rendered text content of this node.
    public let content: String
    /// Absolute start time of this node, if known.
    public let startTime: Date?
    /// Absolute end time of this node, if known.
    public let endTime: Date?
    /// Offset from the start of the recording, in milliseconds.
    public let startOffsetMs: Int?
    /// Offset from the start of the recording to this node's end, in milliseconds.
    public let endOffsetMs: Int?
    /// Display name of the speaker attributed to this node (diarization).
    public let speakerName: String?
    /// Stable identifier for the speaker, e.g. `"user"` for the pendant's owner.
    public let speakerIdentifier: String?
    /// Nested child nodes.
    public let children: [ContentNode]

    public init(
        type: String,
        content: String,
        startTime: Date? = nil,
        endTime: Date? = nil,
        startOffsetMs: Int? = nil,
        endOffsetMs: Int? = nil,
        speakerName: String? = nil,
        speakerIdentifier: String? = nil,
        children: [ContentNode] = []
    ) {
        self.type = type
        self.content = content
        self.startTime = startTime
        self.endTime = endTime
        self.startOffsetMs = startOffsetMs
        self.endOffsetMs = endOffsetMs
        self.speakerName = speakerName
        self.speakerIdentifier = speakerIdentifier
        self.children = children
    }

    private enum CodingKeys: String, CodingKey {
        case type, content, startTime, endTime
        case startOffsetMs, endOffsetMs
        case speakerName, speakerIdentifier, children
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        type = try c.decode(String.self, forKey: .type)
        content = try c.decodeIfPresent(String.self, forKey: .content) ?? ""
        startTime = try c.decodeIfPresent(Date.self, forKey: .startTime)
        endTime = try c.decodeIfPresent(Date.self, forKey: .endTime)
        startOffsetMs = try c.decodeIfPresent(Int.self, forKey: .startOffsetMs)
        endOffsetMs = try c.decodeIfPresent(Int.self, forKey: .endOffsetMs)
        speakerName = try c.decodeIfPresent(String.self, forKey: .speakerName)
        speakerIdentifier = try c.decodeIfPresent(String.self, forKey: .speakerIdentifier)
        // `children` is omitted for leaf nodes; treat missing as empty.
        children = try c.decodeIfPresent([ContentNode].self, forKey: .children) ?? []
    }
}
