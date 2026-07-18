import Foundation
import LimitlessKit

/// Drives the audio download/export UI for a single lifelog.
///
/// Note on playback: iOS's `AVAudioPlayer`/`AVPlayer` cannot decode raw **Ogg Opus** (the format
/// the Limitless API returns) — iOS supports Opus only inside CAF/MP4 containers. So this model
/// downloads and caches the `.ogg` and exposes its file URL for export/share; true in-app
/// playback would need an Opus decoder (e.g. libopus via SwiftPM) or server-side transcoding.
@MainActor
final class AudioDownloadModel: ObservableObject {
    enum State: Equatable {
        case idle
        case downloading
        case ready(URL)
        case failed(String)
    }

    @Published private(set) var state: State

    private let lifelog: Lifelog
    private let service: AudioService

    init(lifelog: Lifelog, service: AudioService) {
        self.lifelog = lifelog
        self.service = service
        if let url = service.localURL(for: lifelog) {
            self.state = .ready(url)
        } else {
            self.state = .idle
        }
    }

    /// True when the lifelog has a time range short enough to fetch audio for.
    var canDownload: Bool {
        guard let start = lifelog.startTime, let end = lifelog.endTime, end > start else {
            return false
        }
        return end.timeIntervalSince(start) <= LimitlessClient.maxAudioRange
    }

    func download() async {
        switch state {
        case .idle, .failed:
            break
        case .downloading, .ready:
            return
        }
        state = .downloading
        do {
            let url = try await service.audioURL(for: lifelog)
            state = .ready(url)
        } catch let error as LimitlessAPIError {
            state = .failed(error.errorDescription ?? "Download failed")
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func delete() {
        try? service.deleteAudio(for: lifelog)
        state = .idle
    }
}
