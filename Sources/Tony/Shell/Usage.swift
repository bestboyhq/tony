import Foundation

/// Usage counts (ADR 0013): what Tony did, like a finished dictation and how long it was, never what was said or
/// typed, the audio, which app the text went to, the user's words, or any path or name. Each count goes on its own
/// to the Bestboy platform's relay, which passes it to Logdash, so Tony talks only to bestboy.dev and holds no key.
/// On until Settings turns them off; a line of fine print in onboarding says so.
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
        guard Prefs.usageCounts, let url, JSONSerialization.isValidJSONObject(body), let data = try? JSONSerialization.data(withJSONObject: body) else { return nil }
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
