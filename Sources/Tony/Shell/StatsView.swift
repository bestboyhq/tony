import AppKit
import SwiftUI

/// How much Tony typed for the user, how fast, and where.
struct StatsView: View {
    let stats: Stats
    let key: String

    /// Tony's orange, the warm end of its mark: one hue, so more reads as more.
    static let tint = Color(.displayP3, red: 0xF0 / 255, green: 0x46 / 255, blue: 0)

    var body: some View {
        let total = stats.total
        if total.dictations == 0 {
            VStack(spacing: 4) {
                Text("Your stats show up here").font(.headline)
                Text("Hold \(key), speak, and let go.").foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .card()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Figure(total.words.formatted(), "words dictated")
                    Spacer()
                    Figure(Self.duration(stats.secondsSaved), "saved over typing", trailing: true)
                        .help("Typing at \(Int(Stats.typingWPM)) words a minute, an average speed.")
                }
                .padding(.horizontal, 4)

                HStack(spacing: 8) {
                    Tile(stats.wordsPerMinute.map(String.init) ?? "-", "wpm", "Speaking pace")
                    Tile(stats.medianLatency.map(String.init) ?? "-", "ms", "Key up to text")
                        .help("How long your text takes to land after you let go, on a typical dictation.")
                    let streak = stats.streak()
                    Tile("\(streak)", streak == 1 ? "day" : "days", "Streak")
                        .help("Your longest: \(stats.longestStreak) \(stats.longestStreak == 1 ? "day" : "days").")
                }

                Activity(stats: stats)
                    .padding(12)
                    .card()

                if !stats.apps.isEmpty {
                    Apps(apps: stats.apps)
                        .padding(12)
                        .card()
                }

                Text(footnote(total))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
        }
    }

    private func footnote(_ total: Stats.Day) -> String {
        var parts = ["\(total.dictations.formatted()) \(total.dictations == 1 ? "dictation" : "dictations")"]
        if total.fillers > 0 { parts.append("\(total.fillers.formatted()) \(total.fillers == 1 ? "filler" : "fillers") removed") }
        if total.yourWords > 0 { parts.append("your words used \(total.yourWords.formatted()) \(total.yourWords == 1 ? "time" : "times")") }
        return parts.joined(separator: " · ")
    }

    static func duration(_ seconds: Double) -> String {
        Duration.seconds(seconds.rounded()).formatted(.units(allowed: [.hours, .minutes, .seconds], width: .narrow, maximumUnitCount: 2))
    }
}

/// A headline number over its label.
private struct Figure: View {
    let value: String
    let label: String
    let trailing: Bool

    init(_ value: String, _ label: String, trailing: Bool = false) {
        (self.value, self.label, self.trailing) = (value, label, trailing)
    }

    var body: some View {
        VStack(alignment: trailing ? .trailing : .leading, spacing: 0) {
            Text(value)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(label).font(.callout).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct Tile: View {
    let value: String
    let unit: String
    let label: String

    init(_ value: String, _ unit: String, _ label: String) {
        (self.value, self.unit, self.label) = (value, unit, label)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(unit).font(.callout).foregroundStyle(.secondary)
            }
            Text(label).font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .card()
        .accessibilityElement(children: .combine)
    }
}

/// Words by day for the last 6 months, a week per column, like a contributions graph.
private struct Activity: View {
    let stats: Stats
    static let weeks = 26

    var body: some View {
        let calendar = Calendar.current
        let today = Stats.day()
        let start = today - (calendar.component(.weekday, from: .now) - calendar.firstWeekday + 7) % 7 - (Self.weeks - 1) * 7
        let range = start...today
        let peak = range.compactMap { stats.days[$0]?.words }.max() ?? 1
        let active = range.count { stats.days[$0] != nil }
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(active) \(active == 1 ? "day" : "days") in the last 6 months").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 3) {
                    Text("Less")
                    ForEach(0..<5) { Cell(level: $0) }
                    Text("More")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 3) {
                    ForEach(0..<Self.weeks, id: \.self) { week in
                        let first = date(start + week * 7, today)
                        let month = calendar.component(.month, from: first)
                        Color.clear
                            .frame(width: 10, height: 12)
                            .overlay(alignment: .leading) {
                                if week > 0, month != calendar.component(.month, from: date(start + week * 7 - 7, today)) {
                                    Text(first.formatted(.dateTime.month(.abbreviated)))
                                        .font(.system(size: 9))
                                        .foregroundStyle(.secondary)
                                        .fixedSize()
                                }
                            }
                    }
                }
                HStack(spacing: 3) {
                    ForEach(0..<Self.weeks, id: \.self) { week in
                        VStack(spacing: 3) {
                            ForEach(0..<7, id: \.self) { weekday in
                                let day = start + week * 7 + weekday
                                let words = stats.days[day]?.words ?? 0
                                Cell(level: day > today ? nil : words == 0 ? 0 : max(1, Int((Double(words) / Double(peak)).squareRoot() * 4)))
                                    .help(day > today ? "" : "\(date(day, today).formatted(.dateTime.weekday().month().day())): \(words.formatted()) \(words == 1 ? "word" : "words")")
                            }
                        }
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Dictated on \(active) of the last \(range.count) days")
        }
    }

    private func date(_ day: Int, _ today: Int) -> Date {
        Stats.calendar.date(byAdding: .day, value: day - today, to: .now) ?? .now
    }

    /// A day: empty at level 0, then four steps of Tony's orange; nil is a day yet to come.
    private struct Cell: View {
        let level: Int?

        var body: some View {
            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                .fill(level.map { $0 == 0 ? AnyShapeStyle(.primary.opacity(0.1)) : AnyShapeStyle(StatsView.tint.opacity([0.3, 0.5, 0.75, 1][min($0, 4) - 1])) } ?? AnyShapeStyle(.clear))
                .frame(width: 10, height: 10)
        }
    }
}

/// The apps that got the most words.
private struct Apps: View {
    let apps: [String: Int]

    var body: some View {
        let top = apps.sorted { $0.value > $1.value }.prefix(4)
        let peak = Double(top.first?.value ?? 1)
        VStack(alignment: .leading, spacing: 8) {
            Text("Where you dictate").font(.caption.weight(.medium)).foregroundStyle(.secondary)
            ForEach(Array(top), id: \.key) { app in
                let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.key)
                HStack(spacing: 8) {
                    Image(nsImage: url.map { NSWorkspace.shared.icon(forFile: $0.path) } ?? NSWorkspace.shared.icon(for: .application))
                        .resizable()
                        .frame(width: 16, height: 16)
                    Text(url.map { FileManager.default.displayName(atPath: $0.path) } ?? app.key)
                        .lineLimit(1)
                        .frame(width: 110, alignment: .leading)
                    GeometryReader { geometry in
                        Capsule()
                            .fill(StatsView.tint)
                            .frame(width: max(6, geometry.size.width * Double(app.value) / peak))
                    }
                    .frame(height: 6)
                    Text(app.value.formatted())
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 52, alignment: .trailing)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(url.map { FileManager.default.displayName(atPath: $0.path) } ?? app.key): \(app.value) words")
            }
        }
    }
}
