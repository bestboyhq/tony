import CoreAudio
import Foundation

/// Fades the Mac's sound out while Tony listens and back in after, so music and videos go quiet for the
/// user and for the mic. It ramps the default output's volume: every app at once, with no permission.
/// Once the sound is out it pauses what plays in Now Playing (a song, a video) and plays it again after,
/// so the user misses none of it.
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

    /// `pause` or `play` for the Now Playing app; true when `pause` paused something.
    private let nowPlaying: @Sendable (String) -> Bool
    /// Runs one command at a time, so a play waits for the pause before it.
    private let media = DispatchQueue(label: "com.bestboyhq.tony.media", qos: .userInitiated)
    /// Tony paused the Now Playing app, so it plays it again. Confined to `media`.
    private var paused = false

    init(nowPlaying: @escaping @Sendable (String) -> Bool = Ducking.nowPlaying) {
        self.nowPlaying = nowPlaying
        queue.async { [self] in recover() }
        var address = Devices.address(kAudioHardwarePropertyDevices)
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, queue) { [weak self] _, _ in
            self?.recover()
        }
    }

    func duck() {
        queue.async { [self] in
            if device == nil, let id = Devices.defaultOutput, let volume = Devices.volume(id), volume > 0 {
                (device, original, level) = (id, volume, volume)
                if let uid = Devices.uid(id) { Self.saved[uid] = Double(volume) }
            }
            device == nil ? pause() : fade(to: 0, over: Self.fadeOut)  // no volume to fade: pause at once
        }
    }

    func restore() {
        queue.async { [self] in
            media.async { [self] in play() }
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
        media.sync { play() }
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
            if target == 0 { pause() } else if target == original { forget() }
        }
        timer.resume()
        self.timer = timer
    }

    private func pause() {
        media.async { [self] in paused = nowPlaying("pause") }
    }

    /// On `media`.
    private func play() {
        guard paused else { return }
        paused = false
        _ = nowPlaying("play")
    }

    /// MediaRemote takes commands and says what plays only for Apple's own processes since macOS 15.4, so
    /// Apple's `osascript` asks it. It pauses only what plays, so a play after never starts music that was off.
    /// The command is sent without waiting, so the script waits for it to land: quitting at once drops it.
    // ponytail: needs MRNowPlayingRequest (macOS 15.4+); on 15.0-15.3 nothing pauses and the fade alone hushes it.
    static func nowPlaying(_ command: String) -> Bool {
        let script = """
            function run([command]) {
              $.NSBundle.bundleWithPath('/System/Library/PrivateFrameworks/MediaRemote.framework').load
              const request = $.NSClassFromString('MRNowPlayingRequest'), pause = command == 'pause'
              if (request.localIsPlaying != pause) return ''
              ObjC.bindFunction('MRMediaRemoteSendCommand', ['bool', ['unsigned int', 'id']])
              $.MRMediaRemoteSendCommand(pause ? 1 : 0, $())  // kMRPause, kMRPlay
              for (let i = 0; i < 20 && request.localIsPlaying == pause; i++) delay(0.05)
              return command
            }
            """
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/osascript")
        process.arguments = ["-l", "JavaScript", "-e", script, command]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return false }
        let said = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()
        return said.hasPrefix("pause")
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
