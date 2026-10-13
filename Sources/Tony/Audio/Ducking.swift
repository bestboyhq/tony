import CoreAudio
import Foundation

/// Fades the Mac's sound out while Tony listens and back in after, so music and videos go quiet for the
/// user and for the mic. It ramps the default output's volume: every app at once, with no permission.
nonisolated final class Ducking: @unchecked Sendable {
    /// Seconds for a fade over the user's whole volume.
    static let fadeOut = 0.3
    static let fadeIn = 0.6
    private static let tick = 0.01
    /// `[device UID: volume]` of each device faded out, so a crash mid-dictation doesn't leave it silent.
    static let savedKey = "ducked"

    private let queue = DispatchQueue(label: "com.bestboyhq.tony.ducking", qos: .userInitiated)

    // Confined to `queue`.
    private var device: AudioDeviceID?
    /// Where the user had the volume.
    private var original: Float32 = 0
    /// What Tony set last.
    private var level: Float32 = 0
    private var timer: DispatchSourceTimer?

    init() {
        queue.async { [self] in recover() }
        var address = Devices.address(kAudioHardwarePropertyDevices)
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, queue) { [weak self] _, _ in
            self?.recover()
        }
    }

    func duck() {
        queue.async { [self] in
            if device == nil {
                guard let id = Devices.defaultOutput, let volume = Devices.volume(id), volume > 0 else { return }
                (device, original, level) = (id, volume, volume)
                if let uid = Devices.uid(id) { Self.saved[uid] = Double(volume) }
            }
            fade(to: 0, over: Self.fadeOut)
        }
    }

    func restore() {
        queue.async { [self] in
            guard device != nil else { return }
            if userChanged { return forget() }
            fade(to: original, over: Self.fadeIn)
        }
    }

    /// Quitting: the user's volume back at once.
    func restoreNow() {
        queue.sync { [self] in
            if let device, !userChanged { Devices.setVolume(device, original) }
            forget()
        }
    }

    /// Faded all the way out, and the user turned it up since: the volume is theirs again.
    private var userChanged: Bool {
        timer == nil && (device.flatMap(Devices.volume) ?? 0) > 0.01
    }

    /// Follows the clock, not the tick count, so late ticks on a busy Mac don't stretch the fade.
    private func fade(to target: Float32, over seconds: Double) {
        timer?.cancel()
        let from = level, start = DispatchTime.now().uptimeNanoseconds
        let duration = seconds * Double(abs(target - from) / original)  // part of the volume, part of the time
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: Self.tick)
        timer.setEventHandler { [weak self] in
            guard let self, let device else { return }
            let done = duration > 0 ? Double(DispatchTime.now().uptimeNanoseconds - start) / 1e9 / duration : 1
            level = done >= 1 ? target : from + (target - from) * Float32(done)
            guard Devices.setVolume(device, level) else { return forget() }  // the device went away
            guard level == target else { return }
            self.timer?.cancel()
            self.timer = nil
            if target == original { forget() }
        }
        timer.resume()
        self.timer = timer
    }

    /// A device that went away mid-fade keeps its saved volume: `recover` brings it back with the device.
    private func forget() {
        timer?.cancel()
        timer = nil
        if let device, let uid = Devices.uid(device) { Self.saved[uid] = nil }
        device = nil
    }

    private static var saved: [String: Double] {
        get { UserDefaults.standard.dictionary(forKey: savedKey) as? [String: Double] ?? [:] }
        set { newValue.isEmpty ? UserDefaults.standard.removeObject(forKey: savedKey) : UserDefaults.standard.set(newValue, forKey: savedKey) }
    }

    /// Tony quit, crashed, or lost the device while it was faded out: bring the volume back, unless the user
    /// already did. A device that isn't plugged in gets it when it is: AirPods come back at the volume they left with.
    private func recover() {
        for (uid, volume) in Self.saved {
            guard let id = Devices.device(uid: uid), id != device else { continue }
            if let now = Devices.volume(id), now <= 0.01 { Devices.setVolume(id, Float32(volume)) }
            Self.saved[uid] = nil
        }
    }
}
