import SwiftUI

/// The pill: listening with the live mic level, transcribing when that takes long enough to notice,
/// and notices; above it, while the user speaks, the caption of what Tony hears. Springs for motion; Reduce Motion
/// swaps movement for fades.
struct HUDView: View {
    let dictation: Dictation
    let mic: Mic
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 10) {
            if captioned {
                Caption(text: dictation.preview, listening: dictation.phase == .listening)
                    .frame(width: Caption.width)
                    .transition(reduceMotion ? .opacity : .offset(y: 6).combined(with: .scale(scale: 0.98, anchor: .bottom)).combined(with: .opacity))
            }
            if dictation.phase != .idle {
                Pill(dictation: dictation, mic: mic)
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 26)  // the pill 18 pt above the Dock, and room for its shadow
        .animation(animation, value: dictation.phase)
        .animation(reduceMotion ? .easeOut(duration: 0.15) : .spring(duration: 0.4, bounce: 0.15), value: captioned)
    }

    private var captioned: Bool {
        (dictation.phase == .listening || dictation.phase == .transcribing) && !dictation.preview.isEmpty
    }

    /// In like a bubble, quick with a little overshoot; out without one.
    private var animation: Animation {
        if reduceMotion { return .easeOut(duration: 0.15) }
        return dictation.phase == .idle ? .smooth(duration: 0.2) : .spring(duration: 0.35, bounce: 0.5)
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
                    .frame(maxWidth: 420, alignment: .leading)  // one line for "Google Chrome has secure input on…"
                if let action = notice.action {
                    Button(action.title) { dictation.perform(action) }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .buttonBorderShape(.capsule)
                }
            default:
                Dot(heat: hovered && !reduceMotion ? 1 : 0, voice: dictation.phase == .listening && !reduceMotion ? mic : nil)
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
        .frame(height: Shadow.height)
        .modifier(Glass(shape: Capsule(), radius: Shadow.height / 2, increasedContrast: contrast == .increased))
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

/// What Tony hears while the user speaks: Parakeet's latest draft, a sentence on its last three lines.
/// Each new word fades in and unblurs like the text Malini streams, a beat after the one before it, and the word
/// being said stays dim until the next draft keeps it.
struct Caption: View {
    let text: String
    let listening: Bool
    @State private var words: [Word] = []
    @State private var overflows = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    static let width = 532.0, padding = 16.0
    private static let font = NSFont.systemFont(ofSize: 14), spacing = 3.0
    /// Three lines; one is as high as the pill with its padding.
    private static let line = (font.ascender - font.descender + font.leading).rounded(.up)
    private static let height = 3 * line + 2 * spacing

    struct Word: TextAttribute {
        var text: String
        /// When it starts to fade in, and when it stopped being the word being said, on the reference date's clock.
        var born: Double
        var settled: Double?
    }

    var body: some View {
        let text = Self.text(words)
        TimelineView(.animation) { timeline in
            text.textRenderer(Reveal(now: timeline.date.timeIntervalSinceReferenceDate, reduceMotion: reduceMotion))
        }
        .font(Font(Self.font))
        .lineSpacing(Self.spacing)
        .contentTransition(.identity)
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: Bool.self) { [limit = Self.height + 1] in $0.size.height > limit } action: { overflows = $0 }
        // The last three lines, the one above them fading out; room beside them for a word's blur.
        .frame(maxHeight: Self.height, alignment: .bottom)
        .mask {
            VStack(spacing: 0) {
                LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom).frame(height: overflows ? Self.line : 0)
                Rectangle()
            }
            .padding([.horizontal, .bottom], -8)
            .padding(.top, overflows ? 0 : -8)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, Self.padding)
        .padding(.vertical, (Shadow.height - Self.line) / 2)
        .modifier(Glass(shape: RoundedRectangle(cornerRadius: Shadow.height / 2), radius: Shadow.height / 2, increasedContrast: contrast == .increased))
        .animation(reduceMotion ? nil : .spring(duration: 0.35, bounce: 0), value: words.count)
        .onChange(of: self.text, initial: true) { update() }
        .onChange(of: listening) { update() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(self.text)
    }

    private func update() {
        words = Self.words(text, after: words, at: Date.now.timeIntervalSinceReferenceDate, listening: listening)
    }

    private static func text(_ words: [Word]) -> Text {
        words.enumerated().reduce(Text(verbatim: "")) { text, item in
            Text("\(text)\(Text(verbatim: item.offset == 0 ? item.element.text : " " + item.element.text).customAttribute(item.element))")
        }
    }

    /// The words of `text`, those already shown keeping their times. Parakeet hears each draft as a sentence, so it
    /// may write a word again in another case or with other punctuation: that word stays, with its new spelling. New
    /// words come one after another, a burst within 0.4 s. While the user speaks, the last word is the one being said:
    /// dim, and without the period Parakeet ends each draft with.
    static func words(_ text: String, after old: [Word], at now: Double, listening: Bool) -> [Word] {
        var new = text.split(separator: " ").map(String.init)
        if listening, var last = new.popLast() {
            while let end = last.last, ".?!…".contains(end), last.count > 1 { last.removeLast() }
            new.append(last)
        }
        let key = { (word: String) in word.lowercased().filter { $0.isLetter || $0.isNumber } }
        var inserted = Set<Int>(), removed = Set<Int>()
        for change in new.map(key).difference(from: old.map { key($0.text) }) {
            switch change {
            case let .insert(offset, _, _): inserted.insert(offset)
            case let .remove(offset, _, _): removed.insert(offset)
            }
        }
        var kept = old.indices.filter { !removed.contains($0) }.makeIterator()
        let step = min(0.06, 0.4 / Double(max(1, inserted.count)))
        var next = max(now, (old.map(\.born).max() ?? now) + step)
        return new.indices.map { i in
            var word: Word
            if inserted.contains(i) {
                word = Word(text: new[i], born: next)
                next += step
            } else {
                word = old[kept.next()!]
                word.text = new[i]
            }
            if word.settled == nil, !listening || i < new.count - 1 { word.settled = max(now, word.born) }
            return word
        }
    }
}

/// Draws a caption's words as they arrive: each from clear, blurred and a little low to sharp in place over half a
/// second on Malini's curve, the word being said at half strength. With Reduce Motion they only fade.
private struct Reveal: TextRenderer {
    var now: Double
    var reduceMotion: Bool
    var displayPadding: EdgeInsets { EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8) }

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        for run in layout.flatMap({ $0 }) {
            guard let word = run[Caption.Word.self] else {
                context.draw(run)
                continue
            }
            let shown = Self.ease((now - word.born) / 0.5)
            var context = context
            context.opacity = shown * (0.5 + 0.5 * (word.settled.map { Self.ease((now - $0) / 0.3) } ?? 0))
            if !reduceMotion, shown < 1 {
                context.translateBy(x: 0, y: 4 * (1 - shown))
                context.addFilter(.blur(radius: 5 * (1 - shown)))
            }
            context.draw(run)
        }
    }

    /// Expo out, Malini's curve for streamed text (cubic-bezier(0.16, 1, 0.3, 1)), over 0...1.
    private static func ease(_ t: Double) -> Double { t <= 0 ? 0 : t >= 1 ? 1 : 1 - pow(2, -10 * t) }
}

/// Grip's dot, Tony's mic head: blue through red to orange, like the icon.
/// Speaking or hovering the pill sets it alight, like logdash's logo: its colors churn and rise with the voice and
/// until the pointer leaves, and it swells with the voice like the bars. One number, the heat, drives the colors;
/// a cold dot is a still gradient.
private struct Dot: View, Animatable {
    /// The pointer's heat, on a spring.
    var heat: Double
    /// The mic while listening: the voice heats the dot too.
    let voice: Mic?
    @State private var smoother = Meter.Smoother(rise: 12, fall: 3)
    @State private var swell = Meter.Smoother()
    nonisolated var animatableData: Double {
        get { heat }
        set { heat = newValue }
    }

    private static let colors: [Color] = [0x1957FA, 0x8B67A8, 0xE44730, 0xF04600, 0xFB8600].map { (hex: Int) -> Color in
        let red = Double(hex >> 16 & 0xFF), green = Double(hex >> 8 & 0xFF), blue = Double(hex & 0xFF)
        return Color(.displayP3, red: red / 255, green: green / 255, blue: blue / 255)
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let level = voice.map { Meter.loudness($0.level) } ?? 0
            Self.mesh(at: t, heat: max(heat, smoother.next(level, at: t)))
                .clipShape(Circle())
                .scaleEffect(1 + 0.3 * swell.next(level, at: t))
        }
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
        private let rise: Double, fall: Double
        private var value = 0.0
        private var last = 0.0
        init(rise: Double = 30, fall: Double = 8) {
            self.rise = rise
            self.fall = fall
        }
        func next(_ target: Double, at t: Double) -> Double {
            let dt = min(0.1, max(0, t - last))
            last = t
            let rate = target > value ? rise : fall
            value += (target - value) * (1 - exp(-rate * dt))
            return value
        }
    }
}

/// Liquid Glass where the system has it, vibrancy before that; solid with Reduce Transparency, outlined
/// with Increase Contrast. A soft shadow lifts it off whatever is under it. Clipped to its shape, whose corners are
/// `radius`: Liquid Glass draws its own shadow just past its edge, which reads as a dark outline.
private struct Glass<S: InsettableShape>: ViewModifier {
    let shape: S
    let radius: Double
    let increasedContrast: Bool

    func body(content: Content) -> some View {
        Group {
            if #available(macOS 26, *) {
                content
                    .glassEffect(.regular, in: shape)
                    .overlay(shape.strokeBorder(.primary.opacity(increasedContrast ? 0.5 : 0), lineWidth: 1))
            } else {
                content
                    .background(.regularMaterial, in: shape)
                    .overlay(shape.strokeBorder(.primary.opacity(increasedContrast ? 0.5 : 0.08), lineWidth: increasedContrast ? 1 : 0.5))
            }
        }
        .clipShape(shape)
        .background(Shadow(radius: radius))
    }
}

/// The pill's shadow, dithered. `.shadow` bands: over a dark background a soft shadow spans about five gray levels,
/// which show as rings, more so in a screen recording. Noise of about one gray level blends them.
struct Shadow: View {
    static let height = 40.0
    /// The corner radius of the shape it lifts.
    var radius: Double
    private static let sigma = 10.0, opacity = 0.2, drop = 3.0, straight = 32.0
    private static let margin = 3 * sigma
    private static var images: [String: CGImage] = [:]
    @Environment(\.displayScale) private var scale
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let corner = Self.margin + radius
        Image(decorative: Self.image(radius: radius, scale: scale, dark: colorScheme == .dark), scale: scale)
            .resizable(capInsets: EdgeInsets(top: corner, leading: corner, bottom: corner, trailing: corner), resizingMode: .tile)
            .padding(-Self.margin)
            .allowsHitTesting(false)
    }

    /// A rectangle with corners of `radius` and sides `straight` long, which the shape tiles to its size: the pill,
    /// as high as its corners, to its width. Clear under the shape, so the glass stays as light as it is.
    static func image(radius: Double, scale: Double, dark: Bool) -> CGImage {
        let key = "\(radius) \(scale) \(dark)"
        if let image = images[key] { return image }
        let side = 2 * (margin + radius) + straight, width = Int(side * scale), rows = width
        // One gray level of the background under the pill, in alpha: dark grays have few to spare.
        let level = dark ? 1.0 / 40 : 1.0 / 220
        var pixels = [UInt8](repeating: 0, count: width * rows * 4)
        var random = Xorshift()
        // Signed distance from the shape, negative inside.
        func distance(_ x: Double, _ y: Double) -> Double {
            let qx = abs(x) - straight / 2, qy = abs(y) - straight / 2
            return (max(qx, 0) * max(qx, 0) + max(qy, 0) * max(qy, 0)).squareRoot() + min(max(qx, qy), 0) - radius
        }
        for y in 0..<rows {
            for x in 0..<width {
                let px = (Double(x) + 0.5) / scale - side / 2, py = (Double(y) + 0.5) / scale - side / 2
                let inside = distance(px, py), below = distance(px, py - drop)
                let alpha = opacity * 0.5 * erfc(below / (sigma * 2.0.squareRoot())) * min(1, max(0, inside * scale + 0.5))
                let noise = (Double.random(in: -0.5...0.5, using: &random) + Double.random(in: -0.5...0.5, using: &random)) * min(level, alpha)
                pixels[(y * width + x) * 4 + 3] = UInt8((min(1, max(0, alpha + noise)) * 255).rounded())
            }
        }
        let image = CGImage(
            width: width, height: rows, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: CGDataProvider(data: Data(pixels) as CFData)!, decode: nil, shouldInterpolate: true, intent: .defaultIntent)!
        images[key] = image
        return image
    }

    /// Noise in a few nanoseconds: the system's generator costs the first pill several milliseconds.
    private struct Xorshift: RandomNumberGenerator {
        private var state: UInt64 = 0x9E37_79B9_7F4A_7C15
        mutating func next() -> UInt64 {
            state ^= state << 13
            state ^= state >> 7
            state ^= state << 17
            return state
        }
    }
}
