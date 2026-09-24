#!/usr/bin/env bash
# Install these widgets into the dagyr.desktop-widgets plugin.
#
# New files are copied in. The two upstream files we edit (WidgetRegistry.qml,
# QuickNotesWidget.qml) are copied wholesale only when the plugin is at the
# exact upstream commit they were made against (see UPSTREAM); otherwise just
# our edits are applied as a patch, so a newer upstream version isn't
# clobbered. Anything overwritten is backed up first.
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
PLUGIN="${PLUGIN_DIR:-$HOME/.config/omarchy/plugins/dagyr.desktop-widgets}"
BACKUP="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/desktop-widgets-install-backup-$(date +%Y%m%d-%H%M%S)"

if [[ ! -d $PLUGIN/.git ]]; then
  echo "install: $PLUGIN isn't a checkout of the upstream plugin." >&2
  echo "Install it first (upstream: $(sed -n 's/^remote=//p' "$REPO/UPSTREAM")), then re-run." >&2
  exit 1
fi

want=$(sed -n 's/^commit=//p' "$REPO/UPSTREAM")
have=$(git -C "$PLUGIN" rev-parse HEAD)
mapfile -t edited < <(sed -n -E 's|^\+\+\+ [^/]+/||p' "$REPO/patches/upstream-edits.patch")
backed_up=0

backup() {
  local f=$1
  [[ -e $PLUGIN/$f ]] || return 0
  mkdir -p "$BACKUP/$(dirname "$f")"
  cp -p "$PLUGIN/$f" "$BACKUP/$f"
  backed_up=1
}

is_edited() {
  local f=$1 e
  for e in "${edited[@]}"; do [[ $e == "$f" ]] && return 0; done
  return 1
}

# 1. New files (process substitution, not a pipe, so backed_up survives)
while read -r f; do
  is_edited "$f" && continue
  if [[ -e $PLUGIN/$f ]] && cmp -s "$REPO/plugin/$f" "$PLUGIN/$f"; then continue; fi
  backup "$f"
  mkdir -p "$PLUGIN/$(dirname "$f")"
  cp -p "$REPO/plugin/$f" "$PLUGIN/$f"
  echo "  added   $f"
done < <(cd "$REPO/plugin" && find . -type f | sed 's|^\./||' | sort)

# 2. Edits to upstream files
if [[ $have == "$want" ]]; then
  for f in "${edited[@]}"; do
    cmp -s "$REPO/plugin/$f" "$PLUGIN/$f" && continue
    backup "$f"
    cp -p "$REPO/plugin/$f" "$PLUGIN/$f"
    echo "  updated $f"
  done
elif git -C "$PLUGIN" apply --reverse --check "$REPO/patches/upstream-edits.patch" 2>/dev/null; then
  echo "  upstream edits already applied"
elif git -C "$PLUGIN" apply --check "$REPO/patches/upstream-edits.patch" 2>/dev/null; then
  for f in "${edited[@]}"; do backup "$f"; done
  git -C "$PLUGIN" apply "$REPO/patches/upstream-edits.patch"
  echo "  patched ${edited[*]} (plugin is at ${have:0:7}, edits were made on ${want:0:7})"
else
  echo "  !! patches/upstream-edits.patch doesn't apply cleanly to upstream ${have:0:7}." >&2
  echo "     Merge it by hand -- the edited files are in plugin/ for reference." >&2
  echo "     Everything else was installed." >&2
fi

# 3. Old flat locations from before each widget got its own widgets/<slug>/
# folder (upstream's layout). Left behind they'd be dead duplicates, so move
# them into the backup -- but never touch a path upstream itself tracks.
LEGACY=(
  get-about.sh get-abyss-watch.sh get-agents.sh get-lyrics-translation.sh
  get-lyrics.sh get-mute.sh get-random-game.sh get-suite-update.sh
  get-sysmon.sh get-video.sh get-youtube.sh
  widgets/AbyssBeholder.qml widgets/AbyssCreature.qml widgets/AbyssEye.qml
  widgets/AbyssEyes.qml widgets/AbyssWardenWidget.qml widgets/AppGridWidget.qml
  widgets/GridLines.qml widgets/HeaderEditor.qml widgets/HorizonClockWidget.qml
  widgets/MprisPlayerWidget.qml widgets/RealmPortalWidget.qml
  widgets/SuiteUpdateItem.qml widgets/SystemAboutWidget.qml
  widgets/SystemMonitorWidget.qml widgets/ThemePalette.qml
  widgets/VideoPlayerWidget.qml
)
for f in "${LEGACY[@]}"; do
  [[ -e $PLUGIN/$f ]] || continue
  git -C "$PLUGIN" ls-files --error-unmatch -- "$f" >/dev/null 2>&1 && continue
  backup "$f"
  rm -f "$PLUGIN/$f"
  echo "  moved   $f (now under widgets/<widget>/, shared/ or scripts/)"
done

chmod +x "$PLUGIN"/get-*.sh "$PLUGIN"/scripts/*.sh "$PLUGIN"/widgets/*/*.sh 2>/dev/null || true

# Record what's installed, for the widgets' "Check for Updates" menu item.
VERSION_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/desktop-widgets-version"
if sha=$(git -C "$REPO" rev-parse HEAD 2>/dev/null); then
  mkdir -p "$(dirname "$VERSION_FILE")"
  echo "$sha" > "$VERSION_FILE"
fi
(( backed_up )) && echo "replaced files backed up to $BACKUP"
echo
echo "Done. Reload the shell to pick it up:"
echo "  rm -rf ~/.cache/quickshell/qmlcache && omarchy-restart-shell"
echo "Layout presets are in $REPO/layouts/ -- import them from the desktop right-click menu."
