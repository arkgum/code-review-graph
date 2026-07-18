import Foundation

/// Local storage for downloaded Ogg Opus audio, keyed by lifelog id.
public protocol AudioStore: Sendable {
    /// On-disk location of the audio for `lifelogID`, or `nil` if not downloaded.
    func localURL(for lifelogID: String) -> URL?
    /// Whether audio for `lifelogID` is present locally.
    func hasAudio(for lifelogID: String) -> Bool
    /// Persists `data` for `lifelogID`, returning its on-disk URL.
    @discardableResult
    func store(_ data: Data, for lifelogID: String) throws -> URL
    /// Removes the audio for `lifelogID` (no-op if absent).
    func delete(for lifelogID: String) throws
    /// Total bytes used by all stored audio.
    func totalBytes() -> Int
    /// Removes all stored audio.
    func deleteAll() throws
}
