# 🎤 Karaoke Player (`MprisPlayerWidget`)

A wireframe spinning-record player for any MPRIS source, with karaoke-style synced lyrics and a live audio spectrum.

## Features
- **Player Controls**: Seekable progress bar, prev/play/next, shuffle/loop, and source chips (scroll to cycle players).
- **Spinning Record**: Wireframe record with optional album art on the label.
- **Synced Lyrics**:
  - From a local `.lrc` beside the track, else LRCLIB (free, no key), cached on disk.
  - Shown beside or below the controls.
  - Per-track timing nudge, lyric size S–XXL, and a refresh button to re-fetch past the cache.
- **Lyric Translation**: Machine-translates lines into English, 日本語, 한국어, Español, Français, Deutsch, Italiano, Português, Nederlands, or Русский, or *Auto*.
- **Audio Spectrum Visualizer**: Live cava bars.
- **Hotkeys on Hover**: Space plays/pauses; M mutes that app's own audio stream without touching its volume slider.
- **Scales**: From 260×150 to wall-sized.

## Architecture
- `MprisPlayerWidget.qml`: Interactive UI inheriting `WidgetCard` (uses `Quickshell.Services.Mpris` and cava).
- `get-lyrics.sh`: Finds lyrics (sibling `.lrc`/`.txt`, cache, then LRCLIB) and prints them as JSON.
- `get-lyrics-translation.sh`: Batched machine translation (Google, falling back to MyMemory), cached per language.
- `get-mute.sh`: Maps an MPRIS bus name to the app's PipeWire streams and reads or toggles their mute.
