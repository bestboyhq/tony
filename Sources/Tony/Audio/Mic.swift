import AVFAudio
import CoreAudio
import OSLog
import Synchronization

/// Microphone capture for one dictation at a time. The mic opens on `start` and closes on `stop`, so the
/// orange dot shows only while Tony listens, and between dictations Tony holds no audio device at all.
/// Samples reach `onSamples` as 16 kHz mono Float32, what the model wants, whatever the device delivers.
///
/// An IOProc on the one device Tony records, never `AVAudioEngine`: the engine's IO unit keeps a private
/// aggregate of the default input and output and builds it again on each default change, so a Bluetooth
/// headset that connects lands in it while Tony idles and drops to call quality (ADR 0018).
nonisolated final class Mic: @unchecked Sendable {
    struct Summary: Sendable {
        /// The mic delivered digital silence: muted, or a built-in mic with the lid closed.
        var silent: Bool
        var device: InputDevice?
    }

    enum Failure: LocalizedError {
        case noDevice, start(Error)
        var errorDescription: String? {
            switch self {
            case .noDevice: "Tony can't find a microphone."
            case .start: "Tony can't open the microphone."
            }
        }
    }

    static let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!

    /// RMS of the latest audio callback (about 10 ms): the HUD reads it every frame.
    var level: Float { Float(bitPattern: capture.level.load(ordering: .relaxed)) }

    /// Shows the level of `samples` as if the mic heard them: for `Tony --transcribe -hud YES`, which has no mic.
    func show(_ samples: [Float]) {
        let rms = (samples.reduce(0) { $0 + $1 * $1 } / Float(max(1, samples.count))).squareRoot()
        capture.level.store(rms.bitPattern, ordering: .relaxed)
    }
    /// Called on the mic queue when the device goes away mid-dictation: what was heard is kept.
    var onInterrupted: (@Sendable () -> Void)?

    private let queue = DispatchQueue(label: "com.bestboyhq.tony.mic", qos: .userInteractive)
    private let capture = Capture()
    private let log = Logger(subsystem: "com.bestboyhq.tony", category: "mic")
    private let io: AudioDeviceIOBlock

    // Confined to `queue`.
    /// The device of this dictation, or of the last one.
    private var device: InputDevice?
    /// Set while the mic is open.
    private var proc: AudioDeviceIOProcID?
    private var converter: AVAudioConverter?
    private var deviceFormat: AVAudioFormat?
    private var timer: DispatchSourceTimer?
    private var onSamples: (@Sendable ([Float]) -> Void)?
    private var startedAt: UInt64 = 0
    private var preferredUID: String?

    init() {
        io = { [capture] _, list, _, _, _ in
            // The real-time thread: no locks, no allocation, no Objective-C.
            let buffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: list))
            guard let first = buffers.first, first.mNumberChannels > 0 else { return }
            let count = Int(first.mDataByteSize) / MemoryLayout<Float>.size / Int(first.mNumberChannels)
            var squares: Float = 0
            var loudest: Float = 0
            capture.ring.write(count) { i in
                var sum: Float = 0
                var channels = 0
                for buffer in buffers {
                    guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
                    let stride = Int(buffer.mNumberChannels)
                    for channel in 0..<stride { sum += data[i * stride + channel] }
                    channels += stride
                }
                let sample = channels > 0 ? sum / Float(channels) : 0
                squares += sample * sample
                loudest = max(loudest, abs(sample))
                return sample
            }
            capture.level.store(count > 0 ? (squares / Float(count)).squareRoot().bitPattern : 0, ordering: .relaxed)
            if loudest > Float(bitPattern: capture.peak.load(ordering: .relaxed)) { capture.peak.store(loudest.bitPattern, ordering: .relaxed) }
            if capture.firstSample.load(ordering: .relaxed) == 0 { capture.firstSample.store(mach_absolute_time(), ordering: .relaxed) }
        }
    }

    /// `uid` nil picks automatically: the default input, but the built-in mic over a Bluetooth headset.
    func use(uid: String?) {
        queue.async { [self] in preferredUID = uid }
    }

    /// Opens the mic. Queued at once, so a `stop` called after it always runs after it.
    /// `keyDownAt` (mach time) is only for the latency log.
    func start(keyDownAt: UInt64, onSamples: @escaping @Sendable ([Float]) -> Void, onError: @escaping @Sendable (Error) -> Void) {
        queue.async { [self] in
            do {
                try startOnQueue(onSamples: onSamples)
                startedAt = keyDownAt
            } catch {
                onError(error)
            }
        }
    }

    /// Closes the mic: queued at once, and the task ends after the last samples reached `onSamples`.
    func stop() -> Task<Summary, Never> {
        let (result, continuation) = AsyncStream.makeStream(of: Summary.self)
        queue.async { [self] in
            continuation.yield(stopOnQueue())
            continuation.finish()
        }
        return Task { await result.first { _ in true } ?? Summary(silent: false, device: nil) }
    }

    // MARK: On the queue

    private func startOnQueue(onSamples: @escaping @Sendable ([Float]) -> Void) throws {
        guard proc == nil else { return }
        // Picked at each key down, so it follows the default input and plugged devices with no listener.
        guard let device = Devices.resolve(uid: preferredUID) else { throw Failure.noDevice }
        guard let rate = Devices.inputRate(device.id) else {
            log.error("\(device.name, privacy: .public) has no usable format")
            throw Failure.noDevice
        }
        if deviceFormat?.sampleRate != rate { convert(from: rate) } else { converter?.reset() }
        capture.ring.reset()
        capture.peak.store(0, ordering: .relaxed)
        capture.firstSample.store(0, ordering: .relaxed)
        var proc: AudioDeviceIOProcID?
        var status = AudioDeviceCreateIOProcIDWithBlock(&proc, device.id, nil, io)
        if status == noErr, let proc {
            status = AudioDeviceStart(device.id, proc)
            if status != noErr { AudioDeviceDestroyIOProcID(device.id, proc) }
        }
        guard status == noErr, let proc else {
            log.error("can't open \(device.name, privacy: .public): \(status)")
            throw Failure.start(NSError(domain: NSOSStatusErrorDomain, code: Int(status)))
        }
        self.device = device
        self.proc = proc
        self.onSamples = onSamples
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + .milliseconds(20), repeating: .milliseconds(20), leeway: .milliseconds(5))
        timer.setEventHandler { [weak self] in self?.tick() }
        timer.resume()
        self.timer = timer
    }

    private func stopOnQueue() -> Summary {
        guard let device, let proc else { return Summary(silent: false, device: device) }
        AudioDeviceStop(device.id, proc)
        AudioDeviceDestroyIOProcID(device.id, proc)
        self.proc = nil
        timer?.cancel()
        timer = nil
        drain(end: true)
        capture.level.store(0, ordering: .relaxed)
        let first = capture.firstSample.load(ordering: .relaxed)
        if first > startedAt, startedAt > 0 {
            var info = mach_timebase_info()
            mach_timebase_info(&info)
            let ms = Double(first - startedAt) * Double(info.numer) / Double(info.denom) / 1_000_000
            log.info("key down to first sample: \(ms, format: .fixed(precision: 1)) ms on \(device.name, privacy: .public)")
        }
        onSamples = nil
        return Summary(silent: first > 0 && Float(bitPattern: capture.peak.load(ordering: .relaxed)) == 0, device: device)
    }

    /// Every 20 ms of a dictation.
    private func tick() {
        guard let device else { return }
        // The device went away, or now sends what Tony can't read: end the dictation, keeping what was heard.
        guard Devices.isRunning(device.id), let rate = Devices.inputRate(device.id) else {
            timer?.cancel()
            onInterrupted?()
            return
        }
        // Its rate changed under the dictation, as a Bluetooth headset's can: convert from the new one on.
        if rate != deviceFormat?.sampleRate {
            drain(end: true)
            convert(from: rate)
        }
        drain(end: false)
    }

    private func convert(from rate: Double) {
        deviceFormat = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1)
        converter = deviceFormat.flatMap { AVAudioConverter(from: $0, to: Self.format) }
    }

    private func drain(end: Bool) {
        var samples: [Float] = []
        capture.ring.drain(into: &samples)
        guard let converter, let deviceFormat, !samples.isEmpty || end else { return }
        // Unsafe-shared with convert's input block (as is `given`): it is @Sendable but runs synchronously inside convert.
        nonisolated(unsafe) let input = AVAudioPCMBuffer(pcmFormat: deviceFormat, frameCapacity: AVAudioFrameCount(max(samples.count, 1)))!
        samples.withUnsafeBufferPointer { input.floatChannelData![0].update(from: $0.baseAddress!, count: samples.count) }
        input.frameLength = AVAudioFrameCount(samples.count)
        let capacity = AVAudioFrameCount(Double(samples.count) * Self.format.sampleRate / deviceFormat.sampleRate) + 1024
        let output = AVAudioPCMBuffer(pcmFormat: Self.format, frameCapacity: capacity)!
        nonisolated(unsafe) var given = samples.isEmpty
        var error: NSError?
        converter.convert(to: output, error: &error) { _, status in
            if given {
                status.pointee = end ? .endOfStream : .noDataNow
                return nil
            }
            given = true
            status.pointee = .haveData
            return input
        }
        if let error { log.error("conversion failed: \(error.localizedDescription, privacy: .public)") }
        guard output.frameLength > 0 else { return }
        onSamples?(Array(UnsafeBufferPointer(start: output.floatChannelData![0], count: Int(output.frameLength))))
    }
}

/// What the real-time audio thread shares with the rest of the app: lock-free only.
nonisolated final class Capture: Sendable {
    let ring = SampleRing(capacity: 1 << 20)  // 21 s at 48 kHz; drained every 20 ms
    let level = Atomic<UInt32>(0)  // Float bits
    let peak = Atomic<UInt32>(0)  // Float bits
    let firstSample = Atomic<UInt64>(0)  // mach time
}

/// A lock-free single-producer, single-consumer ring of samples: the real-time audio thread writes,
/// the mic queue reads.
nonisolated final class SampleRing: @unchecked Sendable {
    private let buffer: UnsafeMutablePointer<Float>
    private let capacity: Int
    private let written = Atomic<Int>(0)
    private let read = Atomic<Int>(0)

    init(capacity: Int) {
        self.capacity = capacity
        buffer = .allocate(capacity: capacity)
        buffer.initialize(repeating: 0, count: capacity)
    }

    deinit { buffer.deallocate() }

    /// Producer side. Drops what does not fit, which only happens if the consumer stalls for seconds.
    func write(_ count: Int, _ sample: (Int) -> Float) {
        let w = written.load(ordering: .relaxed)
        let free = capacity - (w - read.load(ordering: .acquiring))
        let n = min(count, free)
        for i in 0..<n { buffer[(w + i) % capacity] = sample(i) }
        written.store(w + n, ordering: .releasing)
    }

    /// Consumer side.
    func drain(into samples: inout [Float]) {
        let r = read.load(ordering: .relaxed)
        let w = written.load(ordering: .acquiring)
        samples.reserveCapacity(samples.count + w - r)
        for i in r..<w { samples.append(buffer[i % capacity]) }
        read.store(w, ordering: .releasing)
    }

    /// Only while no producer runs.
    func reset() {
        read.store(written.load(ordering: .relaxed), ordering: .relaxed)
    }
}
