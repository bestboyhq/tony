import CoreAudio
import IOKit

/// An input device, as CoreAudio sees it.
nonisolated struct InputDevice: Identifiable, Hashable, Sendable {
    let id: AudioDeviceID
    let uid: String
    let name: String
    let transport: UInt32

    var isBuiltIn: Bool { transport == kAudioDeviceTransportTypeBuiltIn }
    var isBluetooth: Bool { transport == kAudioDeviceTransportTypeBluetooth || transport == kAudioDeviceTransportTypeBluetoothLE }
}

nonisolated enum Devices {
    static func inputs() -> [InputDevice] {
        let ids: [AudioDeviceID] = array(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDevices)
        return ids.compactMap { id in
            var streams = address(kAudioDevicePropertyStreams, scope: kAudioObjectPropertyScopeInput)
            var size: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(id, &streams, 0, nil, &size) == noErr, size > 0,
                  let uid = string(id, kAudioDevicePropertyDeviceUID),
                  let name = string(id, kAudioObjectPropertyName) else { return nil }
            let transport: UInt32 = value(id, kAudioDevicePropertyTransportType) ?? 0
            return InputDevice(id: id, uid: uid, name: name, transport: transport)
        }
    }

    static var defaultInput: AudioDeviceID? {
        value(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDefaultInputDevice)
    }

    /// A MacBook's built-in mic is off while the lid is closed.
    static var lidClosed: Bool {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        defer { IOObjectRelease(service) }
        return IORegistryEntryCreateCFProperty(service, "AppleClamshellState" as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue() as? Bool ?? false
    }

    /// The mic to open: the one the user picked (`uid`) if it is there, else the system default, except that
    /// the built-in mic beats a Bluetooth headset. Opening an AirPods mic switches them to the call profile,
    /// drops all other audio to phone quality, and takes long enough to lose the first words.
    static func resolve(uid: String?) -> InputDevice? {
        let all = inputs()
        if let uid, let picked = all.first(where: { $0.uid == uid }) { return picked }
        let fallback = all.first { $0.id == defaultInput } ?? all.first
        let builtIn = all.first(where: \.isBuiltIn)
        let lidClosed = lidClosed
        if fallback?.isBluetooth == true, let builtIn, !lidClosed { return builtIn }
        if fallback?.isBuiltIn == true, lidClosed, let other = all.first(where: { !$0.isBuiltIn && !$0.isBluetooth }) { return other }
        return fallback
    }

    // MARK: CoreAudio plumbing

    static func address(_ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    private static func value<T: BitwiseCopyable>(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector) -> T? {
        var address = address(selector)
        var size = UInt32(MemoryLayout<T>.size)
        let pointer = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<T>.alignment)
        defer { pointer.deallocate() }
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, pointer) == noErr else { return nil }
        return pointer.load(as: T.self)
    }

    private static func string(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String? {
        var address = address(selector)
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        var string: Unmanaged<CFString>?
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &string) == noErr else { return nil }
        return string?.takeRetainedValue() as String?
    }

    private static func array<T: BitwiseCopyable>(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector) -> [T] {
        var address = address(selector)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr else { return [] }
        return Array(unsafeUninitializedCapacity: Int(size) / MemoryLayout<T>.stride) { buffer, count in
            count = AudioObjectGetPropertyData(id, &address, 0, nil, &size, buffer.baseAddress!) == noErr ? Int(size) / MemoryLayout<T>.stride : 0
        }
    }
}
