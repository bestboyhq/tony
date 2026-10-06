---
name: hud
description: The floating pill that shows Tony listening. Use when changing its panel, states, position, animation, appearance, or accessibility.
---

# HUD

The floating pill that shows Tony is listening.
It is most of what users ever see of Tony, so it carries the "beautiful".

- An `NSPanel` with `.nonactivatingPanel`, so focus stays in the user's app, where the paste must land.
  It floats above full-screen apps and shows on every Space.
- It appears in the frame the key goes down and leaves when the text lands.
  Create the panel at launch, so showing it costs one frame.
- States: listening with the live mic level, transcribing (only when it takes long enough to notice), done, and errors.
  An error is one plain sentence with at most one action.
- It sits at the bottom center of the display with the focused window, above the Dock.
- The pill pops in like a bubble, from 0.9 with a little overshoot, and leaves without one.
- Motion uses springs and stays smooth at 120 Hz on ProMotion; Reduce Motion swaps movement for fades.
- The pill never blocks a click meant for the app beneath it: only a notice's action button takes the mouse.
  The voice sets the dot's colors churning and swells it; hover churns them too, read from a global mouse monitor, not from mouse events.
- Light and dark, vibrancy that matches macOS, and Increase Contrast and Reduce Transparency respected.
- VoiceOver announces listening, done, and errors.
- Crisp at every scale factor, with a steady layout across states.

Done when the HUD appears with no perceptible delay, keeps focus in the user's app, and a designer finds nothing to fix in a screen recording of a dictation played at 0.25x.
