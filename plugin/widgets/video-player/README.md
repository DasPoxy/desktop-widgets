# 🎬 Video Player (`VideoPlayerWidget`)

Loops a local video, or a YouTube video, right on the desktop.

## Features
- **Sources**:
  - *Browse for Video...*: Omarchy's file picker, filtered to video formats.
  - *Paste a YouTube URL...*: downloaded via yt-dlp to a local cache, so HD playback and looping keep working.
- **Playback**: Loop toggle, play/pause, volume slider and mute, scroll-wheel scrubbing, and double-click for fullscreen.
- **Hotkeys on Hover**: Space plays/pauses; M mutes.
- **Hide While Paused**: The widget fades out while paused and reappears on hover over the whole panel, its centre, or the control bar (your pick).

## Architecture
- `VideoPlayerWidget.qml`: Interactive UI inheriting `WidgetCard` (QtMultimedia playback).
- `get-video.sh`: Video file picker.
- `get-youtube.sh`: Resolves a YouTube (or any yt-dlp) URL to a cached local file and reports progress as JSON lines.
