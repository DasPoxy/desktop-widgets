# 👁️ Abyss Warden (`AbyssWardenWidget`)

An anime eye for Omarchy and Hyprland that only shows itself while your screen is being recorded, or all the time as a desktop buddy.

## Features
- **Recording Watcher**: Wakes up for Omarchy's recorder, wf-recorder / wl-screenrec, and any portal screen capture (OBS, Discord, browser screen share), then goes back to sleep.
- **Buddy Mode**: Keeps it out all the time instead; while you record, the irises glow (stalk eyes included).
- **Lively Gaze**:
  - Follows the mouse, glances at windows whose title changes, stares out at the viewer, and blinks.
  - Freezes, then chases rapid mouse movement.
  - Now and then traces a window's edge or checks the bar.
- **Reactions** (each toggleable under *Behaviour*):
  - *Examine Clicks*: narrows in and scans the window you clicked.
  - *Dance to Music*: sways along while an MPRIS player is playing.
  - *Jump When Windows Close*, *Read Notifications*, *Check the Clock*, *Tap on the Screen*.
- **Buddy Types**: One eye, a pair, a mini Beholder with eyestalks, Jellyfish, Flying Saucer (with an alien and a tractor beam), Ghost, Djinn, Floating Skull, Handsome, Smug Unicorn, and a Robot.
- **Eye & Iris Styles**: Dozens of eye shapes and iris patterns, mixable freely (including Naruto's Sharingan, Mangekyō, Rinnegan and Byakugan), in foldable menu sections.
- **Look**: Flat cel-shaded riso-print style with halftone shadows, coloured ink lines, paper grain, and an offset print colour.
- **Eye Themes**: Preset themes or the system theme, with a *Full Theme Palette* toggle (all theme hues vs. accent only).
- **Free-Floating Mode**: Click-through overlay that drifts around the screen.
- **Sizing**: *Buddy Size* slider down to 40px, plus a card background toggle and a 15s preview.

## Setup
Click reactions need one non-consuming bind in `~/.config/hypr/bindings.lua` (clicks still reach your apps):

```lua
hl.bind("mouse:272", hl.dsp.event("abyss-click"), { non_consuming = true })
```

## Architecture
- `AbyssWardenWidget.qml`: Widget UI, gaze/motion springs, reactions, and settings, inheriting `WidgetCard`.
- `AbyssEyes.qml`: Picks the Buddy Type and keeps its eyes moving as one.
- `AbyssEye.qml`: One eye drawn on a Canvas: eye styles, iris styles, glow.
- `AbyssBeholder.qml` / `AbyssCreature.qml`: The Beholder and the other creature bodies.
- `get-abyss-watch.sh`: Long-running Python watcher. It streams recording state, cursor, window activity, clicks, closed windows, and notifications as JSON lines.
