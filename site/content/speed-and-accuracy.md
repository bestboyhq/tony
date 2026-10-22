---
title: Fast, accurate speech to text on the Neural Engine
nav: Speed and accuracy
description: Tony transcribes a sentence in about 50 ms on your Mac's Neural Engine, with Parakeet Ultra at a 5.8% English word error rate, fewer errors than Whisper large-v3.
---

Tony runs Parakeet Ultra on the Neural Engine of your Mac.
A sentence takes about 50 ms, and its English word error rate is 5.8%.

## Fast

| You speak for | Tony transcribes it in |
| --- | --- |
| 5 seconds | **49 ms** |
| 13 seconds | **70 ms** |
| 26 seconds | **147 ms** |

Parakeet Ultra on the Neural Engine of a MacBook Pro with M5 Pro, median of 5 runs.
The clips were read by a macOS voice, and every one came out word for word.

- **Your first word counts.** The audio engine stays prepared between dictations, so capture starts on key down, not a beat later.
- **Warm from the first press.** The model loads at launch and pays its Neural Engine setup up front, so the first dictation of the day is as quick as the hundredth.
- **Talk for five minutes, wait for none.** Past half a minute, Tony transcribes in the background at each pause while you keep talking, so letting go is as instant after a long ramble as after one sentence.
- **Back to back.** Press the key again while your last dictation is still landing: it lands first, and the new one follows it.
- **Idle is free.** Between dictations the mic is closed, so no orange dot, and the CPU rests.

The [menu bar panel](/tony/docs/menu-bar.md) shows your own number: Key up to text, how long your text takes to land after you let go, on a typical dictation.

## Accurate

Tony runs Parakeet Ultra: NVIDIA's Parakeet TDT v3, post-trained by Moondream to make fewer errors on every benchmark they report.

| Model | English word error rate | Parameters |
| --- | --- | --- |
| Whisper large-v3 | 7.44% | 1.55 B |
| Parakeet TDT v3 | 6.26% | 0.6 B |
| **Parakeet Ultra, in Tony** | **5.80%** | **0.6 B** |

Lower is better.
Averages over the [Open ASR Leaderboard](https://huggingface.co/spaces/hf-audio/open_asr_leaderboard) English sets: Parakeet from [Moondream's model card](https://huggingface.co/moondream/parakeet-ultra), Whisper from the [leaderboard paper](https://arxiv.org/abs/2510.06961).

Across 25 languages (FLEURS), Ultra cuts the error rate from 11.6% to 9.6%, and in background noise from 6.7% to 5.8%.

## What makes the text read right

- **Punctuation and capitals included.** The model writes them, so the text reads like you typed it.
- **No "um".** Filler words come out, and the sentence around them keeps its commas and capitals.
- **Fits the cursor.** Tony reads the text before the cursor: a space after a word, none after an opening bracket, and no capital in the middle of a sentence.
- **Silence types nothing.** Voice activity detection trims the quiet, so a cough or a quiet room never turns into a phantom sentence.
- **Switch languages mid-dictation.** Where the model loses track of a switch, Tony transcribes each language on its own.
  See [Languages](/tony/docs/languages.md).
- **Your words, spelled your way.** Names and jargon the model doesn't know.
  See [Your words](/tony/docs/your-words.md).

## Under the hood

- **Parakeet Ultra**, 0.6 B parameters, writes the text.
- **Silero VAD** finds where you spoke.
- **Parakeet CTC 110M** listens for your words.

All three run through Core ML with [FluidAudio](https://github.com/FluidInference/FluidAudio), on your Mac, with no server in the loop.
See [Privacy and offline use](/tony/docs/privacy.md).
