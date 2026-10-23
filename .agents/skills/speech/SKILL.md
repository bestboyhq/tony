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
  FluidAudio reports a model's download as the first half of its fraction and compiling as the second: scale the download to fill the bar.
- The first Core ML load compiles for the Neural Engine and is slow.
  Load at launch and keep the model warm, so the first key press finds it ready.
- Trim silence at both ends with voice activity detection, and insert nothing when there is no speech.
  Speech models invent text ("Thank you.") from silence and noise.
- Dictation transcribes in the background while the user still speaks: the first pause after ten seconds of talk closes a segment, so key up only transcribes what came after the last one, after a sentence or five minutes of talk.
  A pause is two quiet voice activity windows, half a second; one is a breath, often mid-sentence.
  Parakeet hears each segment alone and ends it as a sentence, so short segments cost words: cutting at each breath after five seconds made 16% more word errors in English than 30 s segments, and ten seconds to a pause made none more.
  Ten seconds also keeps a segment within the model's one 15 s window, which costs about the same at any length up to it.
  At each breath, the rest of the segment is drafted, and when the user lets go without saying more, the draft is the text: key up took 2 ms (median) against 58 ms for five-second segments.
  The draft covers the same windows key up would, so it changes no word.
  Cut inside the pause, never in speech: Grip learned that Parakeet drops words cut at a chunk edge and degrades past a few minutes of audio (`native/src/transcript.rs` in Grip).
  Check changes there on real speech fed in real time (`Tony --transcribe <files> -realtime YES`) with release builds, against references with punctuation: LibriSpeech test-clean with LibriSpeech-PC, and FLEURS for Polish.
  Join clips into dictations at one loudness: FLEURS speakers range down to -69 dB, and the voice activity detection misses a quiet speaker right after a loud one.
- Parakeet writes `<unk>` for what it can't spell, such as quotes and brackets: it comes out (`Cleanup.dropUnknown`).
- Parakeet picks its language per clip by itself, and short clips can come out in the wrong alphabet (Polish "Tak." as "Так.").
  The user's languages, by default the Mac's languages and the first language of each keyboard, keep it to their alphabet through FluidAudio's language hint (`Speech.hint`).
  The hint only filters by alphabet (and keeps English out of French alone): it can't tell Polish from Czech, and languages in two alphabets leave Parakeet free.
  Where the audio is unclear (noise, a far mic), Parakeet drifts into another Latin-alphabet language mid-clip: FLEURS Polish under pink noise came out with Czech "pořád", Hungarian "részünk", and whole Lithuanian sentences.
  Keeping its tokens to the letters of the user's languages removed every such word in a FluidAudio patch, at the same word error rate: the words were wrong either way, now in the user's letters.
- Parakeet hears one language per clip, and reports none.
  When the user switches language mid-dictation, it garbles one language or drops it ("Can you send me the report, do końca dnia" came out Polish only).
  Where part of a clip comes out unsure or wordless, each run is transcribed on its own (`Segments.languages`), and kept only if Parakeet is sure of it.
  Check changes with mixed clips: `say -v Samantha` for English and `say -v Zosia` for Polish, joined with ffmpeg.
- Filler words (um, uh, and each language's equivalents) come out by default.
- The user's words (names, brands, jargon) get their spelling where Parakeet mishears them.
  Parakeet can't bias its decoding, so a second model, Parakeet CTC 110M (~100 MB, downloaded once there are words), hears the same audio alongside it, and a word replaces Parakeet's text only where Parakeet was unsure of it, it is spelled alike, and the audio fits it better.
  A wrong swap costs more trust than a miss: keep FluidAudio's acoustic rescue off (it swapped "rolled it back" for Wojtek), keep the boost low, and leave an inflected form standing ("na Mokotowie" is Mokotów in Polish).
  The word model's opinion alone over-fires: its score is an average per token, so a boost of 3 lets a word win that is 20 times less likely in every token, and it hears English only ("group" became Grip, "Szymon" Szymeo, "Malina" Malini).
  So only a word Parakeet was unsure of can change (`Words.sure`): it is sure of the words it knows and unsure of the names it doesn't, and a word with letters the word model can't spell ("grypę") is never judged.
  FluidAudio's own CTC path leaves the model input uninitialized, and NaNs there make the model deaf, and it copies values through NSNumber (90 ms a call), so `Words` runs the two Core ML models itself.
  Check changes with `Tony --transcribe <file> -words '(Szymon, Supabase)'` on sentences with the words and without them, in English and Polish, with words spelled close to them ("group" for Grip, "Szymon" for Szymeo).

Done when a sentence in any supported language lands correct, punctuated, and instant, and silence or a cough inserts nothing.
