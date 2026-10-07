import CoreAudio
import Foundation

/// Fades the Mac's sound out while Tony listens and back in after, so music and videos go quiet for the
/// user and for the mic. It ramps the default output's volume: every app at once, with no permission.
nonisolated final class Ducking: @unchecked Sendable {
    /// Seconds for a fade over the user's whole volume.
    static let fadeOut = 0.3
    static let fadeIn = 0.6
    private static let tick = 0.01
    /// `[device UID: volume]` while faded out, so a crash mid-dictation doesn't leave the Mac silent.
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
        queue.async { Self.recover() }
    }

    func duck() {
        queue.async { [self] in
            if device == nil {
                guard let id = Devices.defaultOutput, let volume = Devices.volume(id), volume > 0 else { return }
                (device, original, level) = (id, volume, volume)
                if let uid = Devices.uid(id) { UserDefaults.standard.set([uid: Double(volume)], forKey: Self.savedKey) }
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

    private func fade(to target: Float32, over seconds: Double) {
        timer?.cancel()
        let step = original * Float32(Self.tick / seconds)
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: Self.tick)
        timer.setEventHandler { [weak self] in
            guard let self, let device else { return }
            level = level < target ? min(level + step, target) : max(level - step, target)
            guard Devices.setVolume(device, level) else { return forget() }  // the device went away
            guard level == target else { return }
            self.timer?.cancel()
            self.timer = nil
            if target == original { forget() }
        }
        timer.resume()
        self.timer = timer
    }

    private func forget() {
        timer?.cancel()
        timer = nil
        device = nil
        UserDefaults.standard.removeObject(forKey: Self.savedKey)
    }

    /// Tony quit while the sound was faded out: bring it back, unless the user already did.
    private static func recover() {
        guard let saved = (UserDefaults.standard.dictionary(forKey: savedKey) as? [String: Double])?.first else { return }
        UserDefaults.standard.removeObject(forKey: savedKey)
        if let id = Devices.device(uid: saved.key), let now = Devices.volume(id), now <= 0.01 { Devices.setVolume(id, Float32(saved.value)) }
    }
}
