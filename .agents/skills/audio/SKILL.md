---
name: audio
description: Microphone capture for dictation. Use when changing the input device, mic start and stop, sample conversion, the level the HUD shows, or mic warnings.
---

# Audio

Microphone capture, from key down to the samples the model hears.

- The mic opens on key down and closes on key up.
- Capture starts first on key down, from an engine kept prepared, so it covers the first word.
  Measure key down to first sample on built-in, USB, and Bluetooth mics.
- Prefer the built-in mic over a Bluetooth headset by default.
  Opening an AirPods mic switches them to the call profile, drops all other audio to phone quality, and takes long enough to lose the first words.
- Keep voice processing (`setVoiceProcessingEnabled`) off: it processes what the model hears and ducks other audio its own way.
- Other audio fades out while Tony listens and back in after (`Ducking`): it ramps the default output's volume, so it covers every app and needs no permission.
  A volume the user changes meanwhile stays theirs, and a quit or crash mid-dictation never leaves the Mac silent, even on AirPods that come back after Tony relaunched.
- Leave the system input volume where the user set it.
- Convert once to what the model wants, 16 kHz mono Float32, with `AVAudioConverter`, whatever the device delivers (44.1 or 48 kHz, stereo, 24-bit).
- Keep one `AVAudioEngine` for the app's life and rewire it on each device change, connecting with the input's hardware format (`inputFormat(forBus: 0)`) through `tonyConnect`.
  Freeing an engine while a device change settles crashes inside AVFAudio, the input's output format lags a device switch, and `connect` raises an Objective-C exception, which Swift can't catch, when the hardware's rate changes under it.
- Follow the default input device as it changes.
  A device unplugged mid-dictation ends the dictation cleanly and keeps what was heard.
  A configuration change stops the engine, even the one a device selection posts a moment later: a dictation restarts it while its device and format hold.
- Detect a built-in mic muted by a closed lid, a missing device, and a mic that delivers only silence, and say so once in the HUD.
- The audio thread is real-time safe: it hands the level to the HUD and the samples to speech through lock-free buffers.

Done when the first syllable after key down is transcribed on built-in, USB, and AirPods mics, and other apps' audio fades out while Tony listens and comes back at the user's volume, at full quality unless the user picked a Bluetooth mic.
