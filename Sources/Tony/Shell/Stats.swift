import Foundation

/// What Tony did for the user, by day. Counts only, never what was said: the text stays in memory.
nonisolated struct Stats: Codable, Equatable {
    struct Day: Codable, Equatable {
        var dictations = 0
        var words = 0
        /// Key down to key up.
        var seconds = 0.0
        var fillers = 0
        /// The user's words, spelled their way.
        var yourWords = 0
    }

    /// By day number: days since 1 AD in the Mac's time zone.
    var days: [Int: Day] = [:]
    /// Words by the bundle ID of the app they went into.
    var apps: [String: Int] = [:]
    /// Key up to text landed, in milliseconds, for the latest dictations.
    var latencies: [Int] = []

    /// An average typing speed, for the time saved.
    static let typingWPM = 40.0
    static let calendar = Calendar(identifier: .gregorian)

    static func day(_ date: Date = .now) -> Int { calendar.ordinality(of: .day, in: .era, for: date) ?? 0 }

    /// Counts a dictation: `raw` as the model wrote it, `text` after cleanup, `seconds` spoken.
    mutating func record(raw: String, text: String, yourWords: [String], seconds: Double, latency: Int?, app: String?, on day: Int = day()) {
        let words = Self.count(text)
        days[day, default: Day()].dictations += 1
        days[day]!.words += words
        days[day]!.seconds += seconds
        days[day]!.fillers += Self.count(raw) - words
        days[day]!.yourWords += yourWords.reduce(0) { $0 + text.ranges(of: $1).count }
        if let app { apps[app, default: 0] += words }
        if let latency { latencies = (latencies + [latency]).suffix(100) }
    }

    var total: Day {
        days.values.reduce(into: Day()) { total, day in
            total.dictations += day.dictations
            total.words += day.words
            total.seconds += day.seconds
            total.fillers += day.fillers
            total.yourWords += day.yourWords
        }
    }

    /// Words per minute spoken; nil before a full second of it.
    var wordsPerMinute: Int? {
        let total = total
        return total.seconds < 1 ? nil : Int((Double(total.words) / total.seconds * 60).rounded())
    }

    /// Typing the words at `typingWPM`, less the time spent saying them.
    var secondsSaved: Double {
        let total = total
        return max(0, Double(total.words) / Self.typingWPM * 60 - total.seconds)
    }

    var medianLatency: Int? { latencies.isEmpty ? nil : latencies.sorted()[latencies.count / 2] }

    /// Days in a row with a dictation, up to `today`; a streak lives on until a whole day passes without one.
    func streak(on today: Int = day()) -> Int {
        var day = days[today] == nil ? today - 1 : today
        var count = 0
        while days[day] != nil {
            count += 1
            day -= 1
        }
        return count
    }

    var longestStreak: Int {
        var longest = 0, run = 0, last = Int.min
        for day in days.keys.sorted() {
            run = day == last + 1 ? run + 1 : 1
            longest = max(longest, run)
            last = day
        }
        return longest
    }

    static func count(_ text: String) -> Int { text.split(whereSeparator: \.isWhitespace).count }

    // MARK: Disk

    private static let url = URL.applicationSupportDirectory.appending(path: "Tony/stats.json")

    // ponytail: a file that doesn't decode starts over, so a new field must decode as optional or the stats are lost.
    static func load() -> Stats {
        (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode(Stats.self, from: $0) } ?? Stats()
    }

    func save() {
        try? FileManager.default.createDirectory(at: Self.url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(self).write(to: Self.url, options: .atomic)
    }
}
