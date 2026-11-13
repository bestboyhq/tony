import Foundation

/// Usage counts (ADR 0016): what Tony did, like a finished dictation and how long it was, never what was said or
/// typed, the audio, which app the text went to, the user's words, or any path or name. Each count goes on its own
/// to the Bestboy platform's relay, which passes it to Logdash, so Tony talks only to bestboy.dev and holds no key.
/// On until turned off in Settings; onboarding's description says so.
enum Usage {
    static let relay = URL(string: "https://bestboy.dev/api/events")!
    /// A development build (0.0.0) sends only to `TONY_EVENTS_URL`, a local stand-in for the relay.
    static let url = ProcessInfo.processInfo.environment["TONY_EVENTS_URL"].flatMap(URL.init(string:)) ?? (Bundle.main.version == "0.0.0" ? nil : relay)

    /// Logdash drops a script's User-Agent, URLSession's own included.
    static let userAgent: String = {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        return "Tony/\(Bundle.main.version) (Macintosh; Mac OS X \(os.majorVersion).\(os.minorVersion).\(os.patchVersion))"
    }()

    /// No cookies, no cache, and a slow call gives up.
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 5
        configuration.timeoutIntervalForResource = 10
        return URLSession(configuration: configuration)
    }()

    /// Counts a `tony_<name>` event now, unless counts are off. Never waits: a failed or slow call is dropped.
    // ponytail: a count made offline is lost, since Logdash drops stale ones anyway; queue them if gaps skew the numbers.
    @discardableResult static func count(_ name: String, _ props: [String: Any] = [:], to url: URL? = url) -> URLRequest? {
        guard let request = request(name, props, to: url) else { return nil }
        session.dataTask(with: request).resume()
        return request
    }

    /// Sends a `tony_<name>` event and answers whether the relay took it, false while counts are off.
    static func send(_ name: String, _ props: [String: Any]) async -> Bool {
        guard let request = request(name, props), let (_, response) = try? await session.data(for: request) else { return false }
        return (response as? HTTPURLResponse).map { 200..<300 ~= $0.statusCode } ?? false
    }

    /// Where each person is on their way with Tony (ADR 0016).
    static let journey = Journey(send: send)

    /// `DO_NOT_TRACK` set to anything but "", "0", or "false" turns counts off, like the switch.
    static let doNotTrack = ProcessInfo.processInfo.environment["DO_NOT_TRACK"].map { !["", "0", "false"].contains($0.lowercased()) } ?? false

    /// The Settings switch. Turning it off sends one last `tony_stats_off`, while still on, so the numbers know how
    /// many people they leave out; turning it on sends nothing extra.
    @discardableResult static func share(_ on: Bool, to url: URL? = url) -> URLRequest? {
        defer { UserDefaults.standard.set(on, forKey: Prefs.usageCountsKey) }
        return on ? nil : count("stats_off", to: url)
    }

    /// The call that counts it, or nil while counts are off or a development build has nowhere to send them.
    static func request(_ name: String, _ props: [String: Any], to url: URL? = url) -> URLRequest? {
        let body: [String: Any] = ["app": "tony", "version": Bundle.main.version, "events": [["name": "tony_\(name)", "props": props]]]
        // A NaN would throw an Objective-C exception, not an error.
        guard Prefs.usageCounts, !doNotTrack, let url, JSONSerialization.isValidJSONObject(body), let data = try? JSONSerialization.data(withJSONObject: body) else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = data
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        return request
    }

    // MARK: Events that see what they must never send, so a test proves they don't

    /// A dictation that landed: how long, how many words, and how fast, never what was said or where it went.
    static func dictation(text: String, seconds: Double, latency: Int, handsFree: Bool) -> [String: Any] {
        ["seconds": Int(seconds.rounded()), "words": rounded(Stats.count(text)), "latency_ms": latency / 10 * 10, "hands_free": handsFree]
    }

    /// The user's words: how many, never which.
    static func words(_ list: [String]) -> [String: Any] { ["count": list.count] }

    /// Down to one significant digit: 7, 20, 100, 1000.
    static func rounded(_ count: Int) -> Int {
        var scale = 1
        while count / scale >= 10 { scale *= 10 }
        return count / scale * scale
    }
}

/// The install journey, active days, and active months, as Malini sends them (ADR 0016). Each event goes once: it is
/// stored as sent only once the relay answers OK, so one that fails goes again at the next launch or dictation. While
/// counts are off it notes nothing, so turning them back on sends nothing from that time. Journey markers go only for a
/// fresh install, with its `cohort`, the local day of the first open, and `days`, whole local days since then.
final class Journey {
    private let defaults: UserDefaults
    private let now: () -> Date
    private let send: @MainActor (String, [String: Any]) async -> Bool
    private let on: () -> Bool
    private var sending: Set<String> = []
    private static let firstOpen = "usageFirstOpen", sentMarkers = "usageSent", pendingMarkers = "usagePending"
    private static let setupStarted = "usageSetupStarted", lastDay = "usageLastDay", activeDays = "usageActiveDays", lastMonth = "usageMonth"

    init(defaults: UserDefaults = .standard, now: @escaping () -> Date = Date.init, on: @escaping () -> Bool = { Prefs.usageCounts && !Usage.doNotTrack }, send: @escaping @MainActor (String, [String: Any]) async -> Bool) {
        self.defaults = defaults
        self.on = on
        self.now = now
        self.send = send
    }

    /// First thing at launch: a Mac with no Tony data yet is a fresh install, and today is its cohort.
    func opened(fresh: Bool) {
        if fresh, cohort == nil { defaults.set(Self.day(now()), forKey: Self.firstOpen) }
    }

    /// At launch and after each dictation: what failed before, the first open, a return, the month before, and the day.
    func active() async {
        guard on() else { return }
        for (marker, props) in pending { await deliver(marker, props) }
        await mark("first_open")
        if let days = daysSinceFirstOpen {
            if 1...7 ~= days { await mark("returned_week_1") }
            if 8...30 ~= days { await mark("returned_month_1") }
        }
        let today = Self.day(now())
        let days = defaults.stringArray(forKey: Self.activeDays) ?? []
        if !days.contains(today) { defaults.set(days + [today], forKey: Self.activeDays) }
        await month(today)
        await day(today)
    }

    /// An onboarding step the user reached, timed from the first one.
    func setup(_ step: String) async {
        if defaults.object(forKey: Self.setupStarted) == nil { defaults.set(now(), forKey: Self.setupStarted) }
        await mark("setup_\(step)", setupSeconds)
    }

    func setupFinished() async { await mark("setup_finished", setupSeconds) }

    /// A journey marker, once, with its props taken now, so a retry sends what was true when it happened.
    func mark(_ marker: String, _ extra: [String: Any] = [:]) async {
        guard on(), let cohort, let days = daysSinceFirstOpen, pending[marker] == nil, !sent.contains(marker) else { return }
        let props = extra.merging(["cohort": cohort, "days": days]) { $1 }
        defaults.set(pending.merging([marker: props]) { $1 }, forKey: Self.pendingMarkers)
        await deliver(marker, props)
    }

    private func deliver(_ marker: String, _ props: [String: Any]) async {
        await once(marker, props) {
            defaults.set(sent + [marker], forKey: Self.sentMarkers)
            defaults.set(pending.filter { $0.key != marker }, forKey: Self.pendingMarkers)
        }
    }

    /// Once per local day: whether it is the first of its ISO week (Monday first) and of its month, and how long since the first open.
    private func day(_ today: String) async {
        let last = defaults.string(forKey: Self.lastDay)
        guard last != today else { return }
        var iso = Calendar(identifier: .iso8601)
        iso.timeZone = .current
        let weekFirst = last.flatMap(Self.date).map { !iso.isDate($0, equalTo: now(), toGranularity: .weekOfYear) } ?? true
        let age = switch daysSinceFirstOpen ?? .max { case ..<1: "day_1" case ..<7: "week_1" case ..<30: "month_1" default: "later" }
        let props = ["week_first": weekFirst ? "yes" : "no", "month_first": last?.prefix(7) != today.prefix(7) ? "yes" : "no", "age": age]
        await once("day", props) { defaults.set(today, forKey: Self.lastDay) }
    }

    /// In a new month, the last earlier month Tony was active in, and on how many days.
    private func month(_ today: String) async {
        let current = String(today.prefix(7))
        let earlier = (defaults.stringArray(forKey: Self.activeDays) ?? []).filter { $0.prefix(7) < current }
        guard let month = earlier.max().map({ String($0.prefix(7)) }), defaults.string(forKey: Self.lastMonth) != month else { return }
        await once("month", ["month": month, "active_days": earlier.filter { $0.hasPrefix(month) }.count]) {
            defaults.set(month, forKey: Self.lastMonth)
            defaults.set((defaults.stringArray(forKey: Self.activeDays) ?? []).filter { $0.prefix(7) >= current }, forKey: Self.activeDays)
        }
    }

    /// Sends unless the same event is on its way, and records it only once the relay took it.
    private func once(_ name: String, _ props: [String: Any], record: () -> Void) async {
        guard sending.insert(name).inserted else { return }
        defer { sending.remove(name) }
        if await send(name, props) { record() }
    }

    private var cohort: String? { defaults.string(forKey: Self.firstOpen) }
    private var sent: [String] { defaults.stringArray(forKey: Self.sentMarkers) ?? [] }
    private var pending: [String: [String: Any]] { defaults.dictionary(forKey: Self.pendingMarkers) as? [String: [String: Any]] ?? [:] }
    private var daysSinceFirstOpen: Int? {
        cohort.flatMap(Self.date).flatMap { Calendar.current.dateComponents([.day], from: $0, to: Calendar.current.startOfDay(for: now())).day }
    }
    private var setupSeconds: [String: Any] {
        (defaults.object(forKey: Self.setupStarted) as? Date).map { ["setup_seconds": max(0, Int(now().timeIntervalSince($0).rounded()))] } ?? [:]
    }

    private static func day(_ date: Date) -> String { date.formatted(Date.ISO8601FormatStyle(timeZone: .current).year().month().day()) }
    private static func date(_ day: String) -> Date? { try? Date(day, strategy: Date.ISO8601FormatStyle(timeZone: .current).year().month().day()) }
}
