---
name: app-shell
description: The native macOS app shell. Use when changing the menu bar panel and menu, stats, onboarding and permissions, settings, launch at login, updates, About, the app icon, or crash reporting.
---

# App shell

The native macOS app around everything else.

- Menu bar app (`LSUIElement`); the dock icon shows only while the onboarding window is open.
- A click on the menu bar icon opens a panel: status, the last dictation, stats, and settings and About as pages of their own.
  A right click (or a Control-click) opens a menu instead: About, Settings, updates, Quit.
  Like the HUD it is non-activating, so the user's app stays active: its fields still type, the first click in it works, and focus is back in the user's app the moment it closes.
  A click elsewhere or Esc closes it; Esc goes through a key monitor, since a focused text field takes it first.
  A click on the icon also arrives as a click in another app, since the menu bar draws it, and takes the keyboard from the panel: both close paths skip it, or the click closes the panel and opens it again.
  A `nonactivatingPanel` style set after creation still activates Tony on a click: create the panel with it.
  Clip the glass to its shape: past its edge Liquid Glass draws its own shadow, which reads as a dark outline.
  The panel's shadow is SwiftUI's, in a clear margin that clicks pass through: a window shadow outlines the panel in a dark line.
- Stats are counts by day (words, time spoken, key up to text, fillers, the user's words, words per app) in `Application Support/Tony/stats.json`, never the text.
- Onboarding goes from install to a first dictation in a minute, without docs.
  It asks for Microphone and Accessibility, each just in time with a one-line reason and one system prompt per request.
  Status is live: Accessibility has no callback, so poll `AXIsProcessTrusted`.
  The model downloads in parallel, an optional field takes the user's words (names, jargon), and a practice field ends onboarding with a first dictation.
- A grant can need a relaunch or a fresh event tap before it works: detect that before claiming success.
  A revoked permission is detected and explained in the HUD and the panel.
- Launch at login through `SMAppService`, offered in onboarding and on by default.
- Updates with Sparkle 2.
  Check at launch, every 4 hours, and on wake: a menu bar app runs for weeks, and the timer stops while the Mac sleeps.
  Nobody quits a menu bar app, so an available update puts a dot on the menu bar icon, a banner in the panel, and Restart to Update in the menu.
  Checks only find the update: Sparkle keeps a download until the app quits, ignoring newer releases, so Restart to Update checks again and installs the latest in one go, never a release in between.
  Sparkle's gentle reminders for background apps (`SPUStandardUserDriverDelegate`) replace its default alert, which steals focus.
  Installs wait until Tony is idle.
- Sparkle cannot replace an app running from the disk image or from Downloads (App Translocation): on first launch, offer to move Tony to Applications.
- Full updates only: the app is a few MB, and the model downloads separately.
- A development build (version 0.0.0) never checks: it would replace itself with the latest release.
- The app icon is `build/Tony.icon` (Icon Composer), its one source: a capsule mic head in the color sweep of Grip's dot, over a grey glass smile on a short stem, so the two read as siblings.
  `scripts/icon.ts` draws its artwork; change the numbers there, not the SVGs.
  The menu bar icon is a template image of the same mark.
- Crash reports stay on disk, and system error codes become plain-language messages.
- Quitting during a dictation inserts it first.

Done when a new user goes from download, through permissions, to a first dictation without reading docs, and a signed build updates itself to the latest release while focus stays in the user's app.
