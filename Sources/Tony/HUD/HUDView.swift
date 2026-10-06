import SwiftUI

/// The pill: listening with the live mic level, transcribing when that takes long enough to notice,
/// and notices. Springs for motion; Reduce Motion swaps movement for fades.
struct HUDView: View {
    let dictation: Dictation
    let mic: Mic
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .bottom) {
            if dictation.phase != .idle {
                Pill(dictation: dictation, mic: mic)
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.6, anchor: .bottom).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 14)
        .animation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.3, dampingFraction: 0.8), value: dictation.phase)
    }
}

private struct Pill: View {
    let dictation: Dictation
    let mic: Mic
    @State private var slow = false
    @State private var hovered = false
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 10) {
            switch dictation.phase {
            case let .notice(notice):
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.orange)
                Text(notice.message)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 340, alignment: .leading)
                if let action = notice.action {
                    Button(action.title) { dictation.perform(action) }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .buttonBorderShape(.capsule)
                }
            default:
                Dot(heat: hovered && !reduceMotion ? 1 : 0)
                    .animation(.spring(duration: hovered ? 0.6 : 0.9), value: hovered)
                Meter(mic: mic, working: dictation.phase == .transcribing && slow, reduceMotion: reduceMotion)
                    .frame(width: 58, height: 20)
                if dictation.handsFree {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .transition(.opacity)
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 40)
        .modifier(Glass(increasedContrast: contrast == .increased))
        .background(Hover { hovered = $0 })
        .fixedSize()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .task(id: dictation.phase) {
            // Transcribing usually takes a blink: show it only when it takes long enough to notice.
            slow = false
            guard dictation.phase == .transcribing else { return }
            try? await Task.sleep(for: .milliseconds(250))
            withAnimation(.easeInOut(duration: 0.2)) { slow = true }
        }
    }

    private var label: String {
        switch dictation.phase {
        case .listening: dictation.handsFree ? "Listening, hands-free" : "Listening"
        case .transcribing: "Transcribing"
        case let .notice(notice): notice.message
        case .idle: ""
        }
    }
}

/// Grip's dot, Tony's mic head: blue through red to orange, like the icon.
/// Hovering the pill sets it alight, like logdash's logo: its colors churn and rise until the pointer leaves.
/// One number, the heat, follows the pointer on a spring and drives it; a cold dot is a still gradient.
private struct Dot: View, Animatable {
    var heat: Double
    nonisolated var animatableData: Double {
        get { heat }
        set { heat = newValue }
    }

    private static let colors = [0x1957FA, 0x8B67A8, 0xE44730, 0xF04600, 0xFB8600].map { hex in
        Color(.displayP3, red: Double(hex >> 16 & 0xFF) / 255, green: Double(hex >> 8 & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }

    var body: some View {
        Group {
            if heat > 0.001 {
                TimelineView(.animation) { timeline in
                    Self.mesh(at: timeline.date.timeIntervalSinceReferenceDate, heat: heat)
                }
            } else {
                LinearGradient(colors: Self.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
        .clipShape(Circle())
        .frame(width: 12, height: 12)
        .accessibilityHidden(true)
    }

    /// A 4 × 4 mesh, the still gradient at no heat. Heat sets its inner points swirling and blends in colors that
    /// rise through it, the gradient running back and forth so they never jump.
    private static func mesh(at t: Double, heat: Double) -> MeshGradient {
        var points: [SIMD2<Float>] = [], colors: [Color] = []
        for row in 0...3 {
            for column in 0...3 {
                let u = Double(column) / 3, v = Double(row) / 3
                let inner = (1...2).contains(column) && (1...2).contains(row)
                let swirl = inner ? 0.14 * heat : 0
                points.append(SIMD2(Float(u + swirl * sin(t * 2.1 + v * 6)), Float(v + swirl * cos(t * 1.7 + u * 6))))
                let rising = 0.3 * u + 0.7 * v + 1.1 * t + 0.2 * sin(t * 2.7 + u * 6 - v * 5)
                colors.append(color(at: (u + v) / 2).mix(with: color(at: abs(rising.truncatingRemainder(dividingBy: 2) - 1)), by: heat))
            }
        }
        return MeshGradient(width: 4, height: 4, points: points, colors: colors)
    }

    /// The still gradient at `x` in 0...1.
    private static func color(at x: Double) -> Color {
        let position = x * Double(colors.count - 1), i = min(Int(position), colors.count - 2)
        return colors[i].mix(with: colors[i + 1], by: position - Double(i))
    }
}

/// Whether the pointer is over a view in a panel that ignores the mouse, so the pill never takes a click from the app
/// under it.
private struct Hover: NSViewRepresentable {
    let changed: (Bool) -> Void

    func makeNSView(context: Context) -> Probe { Probe(changed: changed) }
    func updateNSView(_ probe: Probe, context: Context) { probe.changed = changed }

    final class Probe: NSView {
        var changed: (Bool) -> Void
        private var monitor: Any?
        private var inside = false

        init(changed: @escaping (Bool) -> Void) {
            self.changed = changed
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) { nil }

        override func viewDidMoveToWindow() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = window == nil ? nil : NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in self?.check() }
            check()
        }

        private func check() {
            let now = window.map { bounds.contains(convert($0.convertPoint(fromScreen: NSEvent.mouseLocation), from: nil)) } ?? false
            guard now != inside else { return }
            inside = now
            changed(now)
        }
    }
}

/// Bars that follow the voice, redrawn every display frame (120 Hz on ProMotion) from the mic's level.
private struct Meter: View {
    let mic: Mic
    let working: Bool
    let reduceMotion: Bool
    @State private var smoother = Smoother()
    private static let bars = 9

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let level = smoother.next(Self.loudness(mic.level), at: t)
                let width: CGFloat = 3
                let gap = (size.width - width * CGFloat(Self.bars)) / CGFloat(Self.bars - 1)
                for i in 0..<Self.bars {
                    let center = Double(Self.bars - 1) / 2
                    let distance = (Double(i) - center) / center
                    let bell = exp(-distance * distance * 1.6)
                    var amount: Double
                    if working {
                        // A soft wave runs across while the model works.
                        amount = reduceMotion ? 0.35 : 0.2 + 0.3 * (0.5 + 0.5 * sin(t * 7 - Double(i) * 0.7))
                    } else {
                        let wobble = reduceMotion ? 1 : 0.8 + 0.2 * sin(t * 9 + Double(i) * 1.3)
                        amount = level * bell * wobble
                    }
                    let height = max(width, size.height * min(1, amount))
                    let rect = CGRect(x: CGFloat(i) * (width + gap), y: (size.height - height) / 2, width: width, height: height)
                    context.fill(Path(roundedRect: rect, cornerRadius: width / 2), with: .style(.primary.opacity(0.85)))
                }
            }
        }
        .accessibilityHidden(true)
    }

    /// RMS to 0...1 on a decibel scale: a whisper moves the bars, a shout fills them.
    static func loudness(_ rms: Float) -> Double {
        let db = 20 * log10(max(Double(rms), 1e-6))
        return min(1, max(0, (db + 55) / 40))
    }

    /// Rises fast, falls slow, per frame.
    final class Smoother {
        private var value = 0.0
        private var last = 0.0
        func next(_ target: Double, at t: Double) -> Double {
            let dt = min(0.1, max(0, t - last))
            last = t
            let rate = target > value ? 30.0 : 8.0
            value += (target - value) * (1 - exp(-rate * dt))
            return value
        }
    }
}

/// Liquid Glass where the system has it, vibrancy before that; solid with Reduce Transparency, outlined
/// with Increase Contrast. A soft shadow lifts it off whatever is under it.
private struct Glass: ViewModifier {
    let increasedContrast: Bool

    func body(content: Content) -> some View {
        Group {
            if #available(macOS 26, *) {
                content
                    .glassEffect(.regular, in: .capsule)
                    .overlay(Capsule().strokeBorder(.primary.opacity(increasedContrast ? 0.5 : 0), lineWidth: 1))
            } else {
                content
                    .background(.regularMaterial, in: Capsule())
                    .overlay(Capsule().strokeBorder(.primary.opacity(increasedContrast ? 0.5 : 0.08), lineWidth: increasedContrast ? 1 : 0.5))
            }
        }
        .shadow(color: .black.opacity(0.18), radius: 10, y: 3)
    }
}
