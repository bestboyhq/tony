# 0008 - Pause Now Playing through osascript

Status: accepted

## Context

`Ducking` faded the Mac's output to silence while Tony listened, but the song or video ran on, so the user missed part of it.
The user asked that it be "gently paused for the time of recording and then resumed" instead.
No public API pauses another app's media or says whether one plays: the play/pause media key only toggles, so pressing it when nothing plays starts music the user had off.
Core Audio's per-process "running output" can't tell either: Spotify keeps its output running while paused, and Electron apps keep silent streams open.
The private MediaRemote framework pauses, plays, and says what plays, but since macOS 15.4 it obeys only Apple's own processes: from Tony, `MRMediaRemoteSendCommand` returns true and does nothing, and `MRNowPlayingRequest.localIsPlaying` reads false.
`/usr/bin/osascript` is Apple's own and reaches MediaRemote from JavaScript, with no permission prompt.

## Decision

- `Ducking` still fades the default output's volume out over 0.3 s and back in over 0.6 s, covering every app and audio that can't pause.
- Once the volume reaches 0, or at once when there is no volume to fade, `Ducking.nowPlaying("pause")` runs `osascript -l JavaScript` with a script that loads MediaRemote and sends `MRMediaRemoteSendCommand(kMRPause)` only when `MRNowPlayingRequest.localIsPlaying` says something plays.
- On restore, and on quit, `nowPlaying("play")` sends `kMRPlay` only if Tony paused something and it is still paused.
- The command is sent without waiting, so the script waits up to 1 s for the playing state to flip: `osascript` quitting at once drops it.
- Commands run one at a time on their own queue, so a play waits for the pause before it.

## Consequences

- A song or video waits where it was while the user dictates, and music the user had off never starts.
- Each command costs an `osascript` launch of about 100 ms, only around a dictation, so idle stays free.
- Tony depends on a private framework: a macOS update can stop it, and then nothing pauses while the fade still hushes the sound.
  Before macOS 15.4 `MRNowPlayingRequest` doesn't exist, so nothing pauses there either.
- A crash mid-dictation leaves the media paused; the user presses play.
- `DuckingTests` checks with a recorder that a tap shorter than the fade pauses nothing and that only what Tony paused plays again.
  Nothing automatic checks that MediaRemote still obeys `osascript`; the audio skill's done check names it.
