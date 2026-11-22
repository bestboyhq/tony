---
name: hud
description: The floating pill that shows Tony listening. Use when changing its panel, states, position, animation, appearance, or accessibility.
---

# HUD

The floating pill that shows Tony is listening.
It is most of what users ever see of Tony, so it carries the "beautiful".

- An `NSPanel` with `.nonactivatingPanel`, so focus stays in the user's app, where the paste must land.
  It floats above full-screen apps and shows on every Space.
  Between dictations it stays ordered in at alpha 0: once a full-screen Space closes, macOS pins a hidden panel to one Space for good.
- It appears in the frame the key goes down and leaves when the text lands.
  Create the panel at launch, so showing it costs one frame.
- States: listening with the live mic level, transcribing (only when it takes long enough to notice), done, and errors.
  An error is one plain sentence with at most one action.
- It sits at the bottom center of the display with the focused window, above the Dock.
- While the user speaks, a caption above the pill shows Parakeet's latest draft, at most three lines (ADR 0019).
  Each word is a view of its own, named by the time it arrived, so a word the next draft keeps never moves on its own.
  One transaction moves the card and every word per draft: a card that springs while its words snap, or the reverse, reads as a jolt.
  A new word waits until the card has room (`Caption.lead`), then fades in from blurred and a little low; the word being said stays dim and without Parakeet's period.
  A dropped word blurs out where it was, and a word that wraps onto another line crossfades: one that glides across the card to its new line looks broken.
  The line that scrolls out fades before it reaches the card's edge, or the edge cuts it.
  The mask's fade is linear in alpha, which looks steep on dark glass: check the top line over a dark backdrop.
- The pill pops in like a bubble, from 0.9 with a little overshoot, and leaves without one.
- Motion uses springs and stays smooth at 120 Hz on ProMotion; Reduce Motion swaps movement for fades.
- Its frames hold the main thread: each one waits for WindowServer to show the last, which on a busy Mac takes tens of milliseconds.
  So the work after key up (mic, voice activity, speech) runs off the main thread and steps onto it once, to paste: four steps through it cost 150 ms of a 380 ms key up.
- The pill never blocks a click meant for the app beneath it: only a notice's action button takes the mouse.
  The voice sets the dot's colors churning and swells it; hover churns them too, read from a global mouse monitor, not from mouse events.
- Light and dark, vibrancy that matches macOS, and Increase Contrast and Reduce Transparency respected.
  Clip the glass to its capsule: past its edge Liquid Glass draws its own shadow, which reads as a dark outline.
- Dither the pill's shadow: over a dark background a soft shadow spans about five gray levels, which `.shadow` draws as rings, and a screen recording sharpens them.
- VoiceOver announces listening, done, and errors.
- Crisp at every scale factor, with a steady layout across states.

Check motion in a recording of the real view on real drafts, never with the user's screen: `Tony --transcribe <file> -realtime YES -hud YES` draws the HUD in a window under the desktop picture, and ScreenCaptureKit records it with a display filter that includes only that window (the window filter samples a hidden window at about 25 fps).
Step through it frame by frame at 120 fps around each draft: a word that jumps, a ghost that lingers, or a line the edge cuts shows there and not at full speed.

Done when the HUD appears with no perceptible delay, keeps focus in the user's app, and a designer finds nothing to fix in a screen recording of a dictation played at 0.25x.
