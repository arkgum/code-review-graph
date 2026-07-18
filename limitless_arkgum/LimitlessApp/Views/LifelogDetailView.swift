import SwiftUI
import LimitlessKit

/// Detail screen: header metadata plus the structured transcript with speaker attribution.
struct LifelogDetailView: View {
    let log: Lifelog
    @StateObject private var audio: AudioDownloadModel

    /// `service` is injected by the list's navigation destination (where the environment is
    /// available), so the audio model can be built for `@StateObject` at init time.
    init(log: Lifelog, service: AudioService) {
        self.log = log
        _audio = StateObject(wrappedValue: AudioDownloadModel(lifelog: log, service: service))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                audioSection
                Divider()
                if !log.contents.isEmpty {
                    TranscriptView(nodes: log.contents)
                } else if let markdown = log.markdown, !markdown.isEmpty {
                    Text(markdown)
                        .font(.body)
                        .textSelection(.enabled)
                } else {
                    Text("No transcript content.")
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle(log.title.isEmpty ? "Lifelog" : log.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var audioSection: some View {
        switch audio.state {
        case .idle:
            if audio.canDownload {
                Button {
                    Task { await audio.download() }
                } label: {
                    Label("Download audio", systemImage: "arrow.down.circle")
                }
                .buttonStyle(.bordered)
            }
        case .downloading:
            HStack(spacing: 8) {
                ProgressView()
                Text("Downloading audio…").foregroundStyle(.secondary)
            }
        case .ready(let url):
            HStack(spacing: 12) {
                ShareLink(item: url) {
                    Label("Export audio (.ogg)", systemImage: "square.and.arrow.up")
                }
                Button(role: .destructive) {
                    audio.delete()
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Delete audio")
            }
            .font(.callout)
        case .failed(let message):
            VStack(alignment: .leading, spacing: 4) {
                Label("Audio download failed", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                Text(message).font(.caption).foregroundStyle(.secondary)
                Button("Retry") { Task { await audio.download() } }
                    .buttonStyle(.bordered)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(log.title.isEmpty ? "Untitled" : log.title)
                    .font(.title2).bold()
                if log.isStarred {
                    Image(systemName: "star.fill").foregroundStyle(.yellow)
                }
            }
            HStack(spacing: 8) {
                Label(Formatting.dayTime(log.startTime), systemImage: "calendar")
                if let dur = Formatting.duration(from: log.startTime, to: log.endTime) {
                    Label(dur, systemImage: "clock")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

/// Renders a ContentNode tree: headings, speaker-attributed blocks, and nested children.
struct TranscriptView: View {
    let nodes: [ContentNode]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(nodes.enumerated()), id: \.offset) { _, node in
                NodeView(node: node)
            }
        }
    }
}

private struct NodeView: View {
    let node: ContentNode

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            switch node.type {
            case "heading1":
                Text(node.content).font(.title3).bold()
            case "heading2":
                Text(node.content).font(.headline)
            case "heading3":
                Text(node.content).font(.subheadline).bold()
            default:
                block
            }

            if !node.children.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(node.children.enumerated()), id: \.offset) { _, child in
                        NodeView(node: child)
                    }
                }
                .padding(.leading, 8)
            }
        }
    }

    /// A paragraph/quote, prefixed with speaker + timestamp when present.
    private var block: some View {
        VStack(alignment: .leading, spacing: 2) {
            if node.speakerName != nil || Formatting.offset(node.startOffsetMs) != nil {
                HStack(spacing: 6) {
                    if let speaker = node.speakerName {
                        Text(speaker)
                            .font(.caption).bold()
                            .foregroundStyle(node.speakerIdentifier == "user" ? Color.accentColor : .primary)
                    }
                    if let ts = Formatting.offset(node.startOffsetMs) {
                        Text(ts).font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            if !node.content.isEmpty {
                Text(node.content)
                    .font(.body)
                    .textSelection(.enabled)
            }
        }
    }
}
