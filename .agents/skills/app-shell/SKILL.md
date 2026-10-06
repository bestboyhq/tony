---
name: app-shell
description: The native macOS app shell. Use when changing the menu bar item, onboarding and permissions, settings, launch at login, updates, the About window, the app icon, or crash reporting.
---

# App shell

The native macOS app around everything else.

- Menu bar app (`LSUIElement`); the dock icon shows only while a window (onboarding, settings) is open.
- Onboarding goes from install to a first dictation in a minute, without docs.
  It asks for Microphone and Accessibility, each just in time with a one-line reason and one system prompt per request.
  Status is live: Accessibility has no callback, so poll `AXIsProcessTrusted`.
  The model downloads in parallel, and a practice field ends onboarding with a first dictation.
- A grant can need a relaunch or a fresh event tap before it works: detect that before claiming success.
  A revoked permission is detected and explained in the HUD and the menu.
- Launch at login through `SMAppService`, offered in onboarding and on by default.
- Updates with Sparkle 2.
  Check at launch, every 4 hours, and on wake: a menu bar app runs for weeks, and the timer stops while the Mac sleeps.
  Download in the background and install on quit.
  Nobody quits a menu bar app, so the menu offers Restart to Update, and Sparkle's gentle reminders for background apps (`SPUStandardUserDriverDelegate`) replace its default alert, which steals focus.
  Installs wait until Tony is idle.
- Sparkle cannot replace an app running from the disk image or from Downloads (App Translocation): on first launch, offer to move Tony to Applications.
- Full updates only: the app is a few MB, and the model downloads separately.
- The app icon is `build/Tony.icon` (Icon Composer), its one source: Grip's gradient dot as the mic head over a grey glass cradle, so the two read as siblings.
  The menu bar icon is a template image of the same mark.
- Crash reports stay on disk, and system error codes become plain-language messages.
- Quitting during a dictation inserts it first.

Done when a new user goes from download, through permissions, to a first dictation without reading docs, and a signed build updates itself while focus stays in the user's app.
