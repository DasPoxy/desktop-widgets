#!/usr/bin/env bash
# Refresh this repo from the live plugin: copies every file that differs from
# the upstream dagyr.desktop-widgets checkout (new + locally edited), the
# upstream-edits patch, the upstream commit it's based on, and exports any
# user-created layout presets. Run it after changing a widget, then commit.
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
PLUGIN="${PLUGIN_DIR:-$HOME/.config/omarchy/plugins/dagyr.desktop-widgets}"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/dagyr.desktop-widgets.json"

[[ -d $PLUGIN/.git ]] || { echo "sync: $PLUGIN is not the upstream git checkout" >&2; exit 1; }

rm -rf "$REPO/plugin" && mkdir -p "$REPO/plugin" "$REPO/patches" "$REPO/layouts"

# New (untracked) + modified tracked files, minus caches.
git -C "$PLUGIN" status --porcelain --untracked-files=all |
  sed -E 's/^.. //' | grep -v -E '(__pycache__|\.pyc$)' |
  while read -r f; do
    mkdir -p "$REPO/plugin/$(dirname "$f")"
    cp -p "$PLUGIN/$f" "$REPO/plugin/$f"
    echo "  $f"
  done

# Standard a/ b/ prefixes regardless of the user's diff.mnemonicPrefix etc.
git -C "$PLUGIN" -c diff.mnemonicPrefix=false -c diff.noprefix=false diff --src-prefix=a/ --dst-prefix=b/ > "$REPO/patches/upstream-edits.patch"
{
  echo "remote=$(git -C "$PLUGIN" remote get-url origin)"
  echo "commit=$(git -C "$PLUGIN" rev-parse HEAD)"
  echo "describe=$(git -C "$PLUGIN" log -1 --format='%h %ad %s' --date=short)"
} > "$REPO/UPSTREAM"

# User-created presets listed in PUBLISH_LAYOUTS, in the plugin's own export
# format so they can be re-imported from the desktop menu. Other presets stay
# private.
PUBLISH_LAYOUTS="${PUBLISH_LAYOUTS:-AniPop}"
if [[ -f $STATE ]]; then
  python3 - "$STATE" "$REPO/layouts" "$PUBLISH_LAYOUTS" <<'PY'
import json, sys, os, re
state, out = sys.argv[1], sys.argv[2]
PUBLISH = {n.strip() for n in sys.argv[3].split(",") if n.strip()}
d = json.load(open(state))
for f in os.listdir(out):
    if f.endswith(".json"): os.remove(os.path.join(out, f))
for name, prof in (d.get("layout_profiles") or {}).items():
    if name not in PUBLISH: continue
    prof = dict(prof)
    # The active preset's live values are newer than its last explicit save.
    if name == d.get("active_profile"):
        for k in ("positions", "enabled_widgets", "widget_settings", "monitor_positions", "monitor_enabled_widgets"):
            if k in d: prof[k] = d[k]
    # Machine-local paths would point other users at files they don't have.
    prof = json.loads(json.dumps(prof))
    vp = (prof.get("widget_settings") or {}).get("video_player")
    if isinstance(vp, dict): vp.pop("videoPath", None)
    home = os.path.expanduser("~")
    if home in json.dumps(prof):
        sys.exit(f"sync: preset '{name}' still contains a path under {home}; strip it before publishing")
    fn = re.sub(r"[^A-Za-z0-9._-]+", "_", name) + ".json"
    json.dump({"version": "1.0", "type": "omarchy-desktop-widgets-profile", "profile": prof},
              open(os.path.join(out, fn), "w"), indent=2)
    print("  layouts/" + fn)
PY
fi
echo "synced from $PLUGIN"
