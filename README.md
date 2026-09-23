# Desktop Widgets

Backup of the custom widgets built on top of
[dagyr.desktop-widgets](https://github.com/cyelis1224/omarchy-desktop-widgets)
(Omarchy's desktop widget plugin). Everything here lives inside that plugin's
folder, `~/.config/omarchy/plugins/dagyr.desktop-widgets/`. This repo is an
overlay: only the files that are new or changed relative to upstream.

## Widgets

| Widget | File | What it does |
| --- | --- | --- |
| **Karaoke Player** | `MprisPlayerWidget.qml` + `get-lyrics.sh`, `get-mute.sh` | Wireframe spinning-record player for any MPRIS source. Seekable progress, prev/play/next, live cava spectrum, source chips (scroll to cycle), synced karaoke-style lyrics from a local `.lrc` or LRCLIB, beside or below the controls. Per-track timing nudge, lyric size S–XXL. Space/M hotkeys on hover (M mutes that app's own audio stream). Scales from 260×150 to wall-sized. |
| **Video Player** | `VideoPlayerWidget.qml` + `get-video.sh`, `get-youtube.sh` | Loops a local video, or a YouTube URL downloaded via yt-dlp to a cache. Volume/mute, scroll-wheel scrubbing, Space/M hotkeys on hover, double-click fullscreen. |
| **Visit Another Realm** | `RealmPortalWidget.qml` + `get-random-game.sh` | One button launches a random installed game from Steam, Heroic or Lutris, over shuffling cover-art swatches (angle: ╲ │ ╱). Custom title/button text, icon picker, per-game exclusion list. |
| **System Monitor** | `SystemMonitorWidget.qml` + `get-sysmon.sh`, `get-agents.sh` | CPU/RAM/GPU meters, network rates and session totals, and AI agent usage-limit bars (from Omarchy's agent-usage data). |
| **About This System** | `SystemAboutWidget.qml` + `get-about.sh` | fastfetch-style summary plus the active theme's colour swatches. |
| **Quick Launch Grid** | `AppGridWidget.qml` | Paged 3×3 / 4×4 / 5×5 grid of pinned apps. |

Edits to upstream files (in `patches/upstream-edits.patch`, full copies in
`plugin/`):

- `widgets/WidgetRegistry.qml` registers all of the above in Add Widgets.
- `widgets/quick-notes/QuickNotesWidget.qml` reloads live when `notes.json`
  changes on disk.

## Install / restore

1. Install the upstream plugin first. `UPSTREAM` records the repo and commit
   these were built on.
2. Run `./install.sh`. It copies the new files in. For the two edited upstream
   files, it copies them outright if the plugin is at the recorded commit, and
   otherwise applies just our edits as a patch, so a newer upstream isn't
   overwritten. Anything it replaces is backed up under
   `~/.local/state/omarchy/`. Re-running it is safe.
3. Reload: `rm -rf ~/.cache/quickshell/qmlcache && omarchy-restart-shell`
4. Layout presets are in `layouts/`. Import them from the desktop
   right-click → layout presets → Import.

A plugin update (`git pull` in the plugin) leaves the new files alone but may
revert the two upstream edits. Re-run `./install.sh` afterwards.

## Keeping this backup current

```sh
./sync.sh        # pulls every new/changed file from the live plugin + exports custom layouts
git add -A && git commit -m "..." && git push
```

`sync.sh` works out the file list from the plugin's own `git status`, so new
widgets are picked up automatically.

## Runtime dependencies

`python3`, `yt-dlp` + `ffmpeg` (YouTube), `cava` (spectrum, optional), `pactl`
+ `busctl` (per-app mute), `sqlite3` Python module (Lutris), and
`omarchy-agent-usage-update` (agent bars, ships with Omarchy).
