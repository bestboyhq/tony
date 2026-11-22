---
name: audio
description: Microphone capture for dictation. Use when changing the input device, mic start and stop, sample conversion, the level the HUD shows, or mic warnings.
---

# Audio

Microphone capture, from key down to the samples the model hears.

- The mic opens on key down and closes on key up.
- Capture starts first on key down, so it covers the first word.
  Measure key down to first sample on built-in, USB, and Bluetooth mics.
- Prefer the built-in mic over a Bluetooth headset by default.
  Opening an AirPods mic switches them to the call profile, drops all other audio to phone quality, and takes long enough to lose the first words.
- Keep voice processing (`setVoiceProcessingEnabled`) off: it processes what the model hears and ducks other audio its own way.
- Other audio fades out while Tony listens and back in after (`Ducking`): it ramps the default output's volume, so it covers every app and needs no permission.
  A volume the user changes meanwhile stays theirs, and a quit or crash mid-dictation never leaves the Mac silent, even on AirPods that come back after Tony relaunched.
- Once the sound is out, what plays in Now Playing (a song, a video) pauses, and plays again after, so the user misses none of it (ADR 0008).
  Only what plays pauses, and only what Tony paused plays again, so music the user had off never starts.
  MediaRemote obeys only Apple's processes since macOS 15.4, so `osascript` sends the commands; the command is sent without waiting, so the script waits for it to land.
- Leave the system input volume where the user set it.
- Convert once to what the model wants, 16 kHz mono Float32, with `AVAudioConverter`, whatever the device delivers (44.1 or 48 kHz, stereo, 24-bit).
- Capture through an IOProc on the one device Tony records, created on key down and destroyed on key up, so idle Tony holds no audio device (ADR 0018).
  Never `AVAudioEngine`: its IO unit keeps a private aggregate of the default input and output, and builds it again on each default change, so a headset that connects lands in it while Tony idles and plays in call quality.
  Its warm start bought nothing: the first sample comes about 60 ms after start either way.
- Read only 32-bit float input, the virtual format IOProcs get, at the rate it says (`Devices.inputRate`).
- Pick the device at each key down, so Tony follows the default input and plugged devices with no listener.
  A running dictation keeps its device: one unplugged mid-dictation ends the dictation cleanly and keeps what was heard, and a new rate gets a new converter.
- Detect a built-in mic muted by a closed lid, a missing device, and a mic that delivers only silence, and say so once in the HUD.
- The audio thread is real-time safe: it hands the level to the HUD and the samples to speech through lock-free buffers.

Done when the first syllable after key down is transcribed on built-in, USB, and AirPods mics, other apps' audio fades out while Tony listens and comes back at the user's volume, and a song in Spotify or Music and a video in Safari or Chrome pause and play on from the same spot, at full quality unless the user picked a Bluetooth mic, and a Bluetooth headset that connects while Tony idles keeps playing at full quality.
