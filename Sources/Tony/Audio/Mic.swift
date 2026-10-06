import AVFoundation
import CoreAudio
import OSLog
import Synchronization

/// Microphone capture for one dictation at a time. The mic opens on `start` and closes on `stop`, so the
/// orange dot shows only while Tony listens. The engine is built and prepared between dictations, so
/// `start` only has to open the device. Samples reach `onSamples` as 16 kHz mono Float32, what the model
/// wants, whatever the device delivers.
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
    /// Called on the mic queue when the device goes away or changes mid-dictation: what was heard is kept.
    var onInterrupted: (@Sendable () -> Void)?

    private let queue = DispatchQueue(label: "com.bestboyhq.tony.mic", qos: .userInteractive)
    private let capture = Capture()
    private let log = Logger(subsystem: "com.bestboyhq.tony", category: "mic")

    // Confined to `queue`.
    private var engine: AVAudioEngine?
    private var device: InputDevice?
    private var converter: AVAudioConverter?
    private var deviceFormat: AVAudioFormat?
    private var timer: DispatchSourceTimer?
    private var onSamples: (@Sendable ([Float]) -> Void)?
    private var running = false
    private var startedAt: UInt64 = 0
    private var preferredUID: String?
    private var configObserver: NSObjectProtocol?

    init() {
        // Follow the default input and plugged devices; a running dictation keeps its device.
        for selector in [kAudioHardwarePropertyDefaultInputDevice, kAudioHardwarePropertyDevices] {
            var address = Devices.address(selector)
            AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, queue) { [weak self] _, _ in
                guard let self, !self.running else { return }
                self.rebuild()
            }
        }
    }

    /// `uid` nil picks automatically: the default input, but the built-in mic over a Bluetooth headset.
    func use(uid: String?) {
        queue.async { [self] in
            preferredUID = uid
            if !running { rebuild() }
        }
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

    private func rebuild() {
        dispatchPrecondition(condition: .onQueue(queue))
        if let configObserver { NotificationCenter.default.removeObserver(configObserver) }
        engine?.stop()
        engine = nil
        // Touching the input before the user said yes would raise the system prompt out of context.
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .authorized else { return }
        guard let device = Devices.resolve(uid: preferredUID) else {
            log.error("no input device")
            return
        }
        let engine = AVAudioEngine()
        let input = engine.inputNode
        var id = device.id
        // Selecting a device reconfigures the engine: only when it isn't the default already.
        if device.id != Devices.defaultInput, let unit = input.audioUnit {
            let status = AudioUnitSetProperty(unit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0, &id, UInt32(MemoryLayout<AudioDeviceID>.size))
            if status != noErr { log.error("can't select \(device.name, privacy: .public): \(status)") }
        }
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0,
              let mono = AVAudioFormat(standardFormatWithSampleRate: format.sampleRate, channels: 1) else {
            log.error("\(device.name, privacy: .public) has no usable format")
            return
        }
        let sink = AVAudioSinkNode { [capture] _, frames, list in
            // The real-time thread: no locks, no allocation, no Objective-C.
            let buffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: list))
            let count = Int(frames)
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
            return noErr
        }
        engine.attach(sink)
        engine.connect(input, to: sink, format: format)
        engine.prepare()
        configObserver = NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: nil) { [weak self] _ in
            guard let self else { return }
            self.queue.async {
                self.log.notice("audio configuration changed")
                if self.running {
                    self.onInterrupted?()
                } else if Devices.resolve(uid: self.preferredUID)?.id != self.device?.id
                    || self.engine?.inputNode.inputFormat(forBus: 0).sampleRate != self.deviceFormat?.sampleRate {
                    // Selecting a device posts a change too: rebuilding for that one would never end.
                    self.rebuild()
                }
            }
        }
        self.engine = engine
        self.device = device
        deviceFormat = mono
        converter = AVAudioConverter(from: mono, to: Self.format)
        log.info("prepared \(device.name, privacy: .public) at \(format.sampleRate) Hz, \(format.channelCount) ch")
    }

    private func startOnQueue(onSamples: @escaping @Sendable ([Float]) -> Void) throws {
        if engine == nil { rebuild() }
        guard engine != nil else { throw Failure.noDevice }
        capture.ring.reset()
        capture.peak.store(0, ordering: .relaxed)
        capture.firstSample.store(0, ordering: .relaxed)
        converter?.reset()
        self.onSamples = onSamples
        do {
            try engine?.start()
        } catch {
            // The device changed under the prepared engine: build it again once.
            log.error("start failed, rebuilding: \(error.localizedDescription, privacy: .public)")
            rebuild()
            do {
                guard let engine else { throw Failure.noDevice }
                try engine.start()
            } catch {
                self.onSamples = nil
                throw Failure.start(error)
            }
        }
        running = true
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + .milliseconds(20), repeating: .milliseconds(20), leeway: .milliseconds(5))
        timer.setEventHandler { [weak self] in self?.drain(end: false) }
        timer.resume()
        self.timer = timer
    }

    private func stopOnQueue() -> Summary {
        guard running else { return Summary(silent: false, device: device) }
        engine?.stop()
        running = false
        timer?.cancel()
        timer = nil
        drain(end: true)
        capture.level.store(0, ordering: .relaxed)
        let first = capture.firstSample.load(ordering: .relaxed)
        if first > startedAt, startedAt > 0 {
            var info = mach_timebase_info()
            mach_timebase_info(&info)
            let ms = Double(first - startedAt) * Double(info.numer) / Double(info.denom) / 1_000_000
            log.info("key down to first sample: \(ms, format: .fixed(precision: 1)) ms on \(self.device?.name ?? "?", privacy: .public)")
        }
        let summary = Summary(silent: first > 0 && Float(bitPattern: capture.peak.load(ordering: .relaxed)) == 0, device: device)
        onSamples = nil
        // Prepared for the next key down, after the summary is out: key up must not wait for it.
        queue.async { [self] in
            guard !running else { return }
            if let engine, Devices.resolve(uid: preferredUID)?.id == device?.id,
               engine.inputNode.inputFormat(forBus: 0).sampleRate == deviceFormat?.sampleRate {
                engine.prepare()
            } else {
                rebuild()  // the device changed meanwhile
            }
        }
        return summary
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
