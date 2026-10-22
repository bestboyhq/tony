---
title: Your words, spelled your way
nav: Your words
description: Teach Tony the names, brands, and jargon you use, so "super base" lands as Supabase. A second, on-device model checks each word against your voice before it swaps in.
---

Speech models know everyday words, and guess at the rest.
Add the names, brands, and jargon you use, and Tony writes them your way: "super base" lands as Supabase.

## Add your words

Open [Settings](/tony/docs/settings.md) from the menu bar panel and type into Your words.
Press Return or type a comma after each one, and click the × on a word to remove it.
The welcome window offers the same field when you first open Tony.

A word can be a phrase, and Tony keeps it in the capitals you typed.
Adding the same word twice, in any capitals, keeps the first.

## How Tony listens for them

Parakeet Ultra can't be told which words to expect, so a second, small model listens to the same audio: Parakeet CTC 110M, on the Neural Engine.
One of your words replaces what Parakeet wrote only where all three hold:

- Parakeet was unsure of the word it wrote.
- Your word is spelled alike.
- The audio fits your word better.

A wrong swap costs more trust than a miss, so Tony leaves alone the everyday words Parakeet is sure of.
Punctuation around a swapped word stays as it was.

- **Endings stay.** A word with an ending, like "Tailscales" for Tailscale, is left alone, so the sentence doesn't break.
- **Capitals, your way.** A word that isn't everyday English is written in your capitals wherever Parakeet heard it: "tailscale" becomes Tailscale.
  An everyday English word in your list keeps its normal capitals mid-sentence.
- **Mid-sentence.** Dictate into the middle of a sentence and Tony lowercases the first word, unless it is one of yours.

## What it costs

The model for your words, about 100 MB, downloads once, the first time you add any.
While it downloads and warms up, Settings says "Getting ready to listen for them…".
It runs alongside Parakeet on the same audio, so a dictation with your words still lands about as fast.

The word model knows English letters only, so it can't listen for a word with other letters, like Mokotów.
Tony still writes such a word in your capitals wherever Parakeet heard it.

## See it work

The [menu bar panel](/tony/docs/menu-bar.md) counts how often Tony spelled your words your way, under your stats.

## Related

- [Languages](/tony/docs/languages.md)
- [Privacy and offline use](/tony/docs/privacy.md): your words stay in Tony's preferences on your Mac.
