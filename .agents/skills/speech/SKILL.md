---
name: speech
description: On-device speech to text. Use when changing the model, its download and loading, voice activity detection, long dictation, filler words, languages, or the user's words.
---

# Speech

Speech to text on the Neural Engine.

- NVIDIA Parakeet TDT v3 post-trained by Moondream ("Ultra", `AsrModelVersion.ultra`) through FluidAudio (Core ML): v3's languages and speed, fewer errors in every language FluidAudio measures.
  It detects 25 European languages by itself, writes punctuation and capitals, and keeps filler words.
  Other languages need a fallback model.
- The model downloads on first run while onboarding asks for permissions: in the background, resumable, verified, with real progress.
  It lives in Application Support, and a missing or corrupt model downloads again.
- The first Core ML load compiles for the Neural Engine and is slow.
  Load at launch and keep the model warm, so the first key press finds it ready.
- Trim silence at both ends with voice activity detection, and insert nothing when there is no speech.
  Speech models invent text ("Thank you.") from silence and noise.
- Long dictation transcribes in the background while the user still speaks, in overlapping chunks stitched at a pause, so key up stays fast after five minutes of talk.
  Grip learned this: Parakeet drops words cut at a chunk edge and degrades past a few minutes of audio (`native/src/transcript.rs` in Grip).
- Filler words (um, uh, and each language's equivalents) come out by default.
- The user's words (names, brands, jargon) get their spelling where Parakeet mishears them.
  Parakeet can't bias its decoding, so a second model, Parakeet CTC 110M (~100 MB, downloaded once there are words), hears the same audio alongside it, and a word replaces Parakeet's text only where it is spelled alike and the audio fits it better.
  A wrong swap costs more trust than a miss: keep FluidAudio's acoustic rescue off (it swapped "rolled it back" for Wojtek), keep the boost low, and leave an inflected form standing ("na Mokotowie" is Mokotów in Polish).
  FluidAudio's own CTC path leaves the model input uninitialized, and NaNs there make the model deaf, and it copies values through NSNumber (90 ms a call), so `Words` runs the two Core ML models itself.
  Check changes with `Tony --transcribe <file> -words '(Szymon, Supabase)'` on sentences with the words and without them.

Done when a sentence in any supported language lands correct, punctuated, and instant, and silence or a cough inserts nothing.
