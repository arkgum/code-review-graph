import Foundation

/// Downloads and caches Pendant audio for a lifelog.
///
/// Ties ``LimitlessClient/downloadAudio(start:end:)`` to an ``AudioStore``: if the audio is
/// already on disk it's returned immediately; otherwise it's fetched for the lifelog's time
/// range and stored. Lifelogs longer than ``LimitlessClient/maxAudioRange`` are rejected (the
/// caller would need to chunk the range).
public struct AudioService: Sendable {
    private let client: LimitlessClient
    private let store: AudioStore

    public init(client: LimitlessClient, store: AudioStore) {
        self.client = client
        self.store = store
    }

    public func localURL(for lifelog: Lifelog) -> URL? {
        store.localURL(for: lifelog.id)
    }

    /// Returns the local audio URL, downloading and caching it first if necessary.
    public func audioURL(for lifelog: Lifelog) async throws -> URL {
        if let existing = store.localURL(for: lifelog.id) { return existing }

        guard let start = lifelog.startTime, let end = lifelog.endTime else {
            throw LimitlessAPIError.invalidParameter("lifelog has no time range for audio")
        }
        let data = try await client.downloadAudio(start: start, end: end)
        return try store.store(data, for: lifelog.id)
    }

    public func deleteAudio(for lifelog: Lifelog) throws {
        try store.delete(for: lifelog.id)
    }
}
