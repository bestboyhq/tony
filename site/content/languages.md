---
title: Dictation in 25 languages, detected as you speak
nav: Languages
description: Tony dictates in 25 European languages, from English, German, and Polish to Ukrainian and Greek. It detects the language as you speak, and you can switch mid-dictation.
---

Tony speaks the 25 languages of Parakeet, the speech model it runs.
It detects the language as you speak, so you switch between them without touching a setting.

## The 25 languages

| Language | Alphabet |
| --- | --- |
| Bulgarian | Cyrillic |
| Croatian | Latin |
| Czech | Latin |
| Danish | Latin |
| Dutch | Latin |
| English | Latin |
| Estonian | Latin |
| Finnish | Latin |
| French | Latin |
| German | Latin |
| Greek | Greek |
| Hungarian | Latin |
| Italian | Latin |
| Latvian | Latin |
| Lithuanian | Latin |
| Maltese | Latin |
| Polish | Latin |
| Portuguese | Latin |
| Romanian | Latin |
| Russian | Cyrillic |
| Slovak | Latin |
| Slovenian | Latin |
| Spanish | Latin |
| Swedish | Latin |
| Ukrainian | Cyrillic |

Across these 25 languages (the FLEURS benchmark), Parakeet Ultra cuts the word error rate from 11.6% to 9.6%.
See [Speed and accuracy](/tony/docs/speed-and-accuracy.md).

## Pick the languages you speak

Settings has a Languages menu: Any language, or the ones you speak, as many as you like.
Until you pick, Tony starts with the languages your Mac is set up for: the ones in your language list and your keyboards.

Picking keeps every word in the letters of the languages you speak.
Without it, the model can write Polish "Tak" in Cyrillic, as "Так", and where the audio is unclear, drift into a language you don't speak, like Czech "pořád" or Hungarian "részünk" in the middle of Polish.
Pick Polish and English, and "deploy" stays while "ř" never lands; pick Polish and Ukrainian, and both alphabets stay.
Pick Any language, and the model is free to choose.

The menu also lists Belarusian, Bosnian, and Serbian.
They are not among the 25 languages Parakeet was trained on, so picking one only keeps the text in its letters.

## Switch languages mid-dictation

Start in English and finish in Polish.
Where the model loses track of the switch, Tony transcribes each language on its own, so neither comes out garbled.
It splits the dictation at the pauses, and keeps the split only where it makes the model sure of its words.

## Punctuation, capitals, and fillers

- **Punctuation and capitals included.** The model writes them, so the text reads like you typed it.
- **No "um".** Filler words come out: um and uh in English, äh and ähm in German, euh in French, ehm in Italian, Spanish, and Dutch, yyy in Polish, and э in Russian and Ukrainian.
  The sentence around them keeps its commas and capitals.

## Related

- [Your words](/tony/docs/your-words.md): names and jargon in any of these languages, spelled your way.
- [Settings](/tony/docs/settings.md): where the Languages menu lives.
