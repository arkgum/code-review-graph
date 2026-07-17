import Foundation

enum Formatting {
    /// e.g. "Jul 17, 09:00".
    static func dayTime(_ date: Date?) -> String {
        guard let date else { return "—" }
        return dayTimeFormatter.string(from: date)
    }

    /// Duration between two instants as "12m 30s" / "1h 05m".
    static func duration(from start: Date?, to end: Date?) -> String? {
        guard let start, let end, end > start else { return nil }
        let seconds = Int(end.timeIntervalSince(start))
        let h = seconds / 3600, m = (seconds % 3600) / 60, s = seconds % 60
        if h > 0 { return String(format: "%dh %02dm", h, m) }
        if m > 0 { return String(format: "%dm %02ds", m, s) }
        return "\(s)s"
    }

    /// Offset in ms → "mm:ss" relative to the recording start.
    static func offset(_ ms: Int?) -> String? {
        guard let ms else { return nil }
        let total = ms / 1000
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    private static let dayTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, HH:mm"
        return f
    }()
}
