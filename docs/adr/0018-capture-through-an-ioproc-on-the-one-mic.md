# 0018 - Capture through an IOProc on the one mic, never AVAudioEngine

Status: accepted

## Context

A user reported that a Bluetooth headset sounded different while Tony ran, and that its output turned bad whenever the headset connected with Tony running, idle.
Tony kept one `AVAudioEngine` for the app's life, wired and prepared between dictations, so key down only had to start it.
On macOS, `engine.inputNode` builds a private `CADefaultDeviceAggregate` of the default input and the default output, and the engine builds a new one on each default change and moves its IO unit onto it, even after Tony picked a device.
A headset that connects becomes the default input and output, so it landed in Tony's idle process, and Talkie found that this same aggregate pulls headsets into their call profile while idle (jannallenberger/Talkie#78).
The aggregate also has an input stream, so Settings listed it as a microphone.
The warm engine bought nothing: on a MacBook Pro mic its first sample came 60 to 64 ms after `start`, and an IOProc's comes 54 to 62 ms after `AudioDeviceStart`.

## Decision

- `Mic` runs an IOProc (`AudioDeviceCreateIOProcIDWithBlock`) on the one device `Devices.resolve` picks, created and started on key down, stopped and destroyed on key up.
- It picks the device at each key down, in 0.17 ms, so it follows the default input and plugged devices with no listener; `Mic.use(uid:)` only stores the user's pick.
- `Devices.inputRate` reads each input stream's virtual format, the format IOProcs get, and takes only 32-bit float, the samples Tony reads.
- Every 20 ms a dictation checks its device: one that stops running ends the dictation and keeps what was heard, and a new rate gets a new converter.
- The `TonyObjC` target, which ADR 0002 lists, goes: it only caught the exception `AVAudioEngine.connect` raised.

## Consequences

- Between dictations Tony holds no audio device, so a headset that connects keeps full quality.
- Tony opens a Bluetooth mic only when it is the mic Tony records, and only while the user dictates.
- Settings lists only real microphones.
- Tony is all Swift.
- `MicTests.hearsEveryMic` records from each wired mic and fails when an aggregate of the default devices shows in Tony's process.
  Nothing automatic checks a real Bluetooth headset; the audio skill's done check names it.
