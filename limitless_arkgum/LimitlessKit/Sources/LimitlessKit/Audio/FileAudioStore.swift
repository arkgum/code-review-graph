import Foundation

/// Filesystem-backed ``AudioStore``. Writes one `<lifelogID>.ogg` file per lifelog in a
/// dedicated directory. The lifelog id is sanitized so it can't escape that directory.
public final class FileAudioStore: AudioStore {
    private let directory: URL
    private let fileManager: FileManager

    public init(directory: URL, fileManager: FileManager = .default) throws {
        self.directory = directory
        self.fileManager = fileManager
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    public func localURL(for lifelogID: String) -> URL? {
        let url = fileURL(for: lifelogID)
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    public func hasAudio(for lifelogID: String) -> Bool {
        localURL(for: lifelogID) != nil
    }

    @discardableResult
    public func store(_ data: Data, for lifelogID: String) throws -> URL {
        let url = fileURL(for: lifelogID)
        try data.write(to: url, options: .atomic)
        return url
    }

    public func delete(for lifelogID: String) throws {
        let url = fileURL(for: lifelogID)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    public func totalBytes() -> Int {
        guard let items = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else { return 0 }
        return items.reduce(0) { sum, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return sum + size
        }
    }

    public func deleteAll() throws {
        let items = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        for url in items { try fileManager.removeItem(at: url) }
    }

    // MARK: - Private

    private func fileURL(for lifelogID: String) -> URL {
        directory.appendingPathComponent("\(Self.sanitize(lifelogID)).ogg")
    }

    /// Keeps only safe filename characters so an id can never traverse out of the directory.
    static func sanitize(_ id: String) -> String {
        let allowed = CharacterSet(charactersIn:
            "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")
        let cleaned = String(id.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" })
        return cleaned.isEmpty ? "audio" : String(cleaned.prefix(128))
    }
}
