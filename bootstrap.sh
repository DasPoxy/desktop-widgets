#!/usr/bin/env bash
# One-line installer: checks that dagyr.desktop-widgets is installed, fetches
# (or updates) this repo, then runs install.sh from it.
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/DasPoxy/desktop-widgets/main/bootstrap.sh)
set -euo pipefail

UPSTREAM_URL="https://github.com/cyelis1224/omarchy-desktop-widgets"
REPO_URL="${DESKTOP_WIDGETS_REPO:-https://github.com/DasPoxy/desktop-widgets.git}"
PLUGIN="${PLUGIN_DIR:-$HOME/.config/omarchy/plugins/dagyr.desktop-widgets}"
DEST="${DESKTOP_WIDGETS_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/desktop-widgets}"

# 1. The upstream plugin has to be there first -- everything here is an
#    overlay on top of it.
if [[ ! -f $PLUGIN/manifest.json ]] || ! grep -q '"id": *"dagyr.desktop-widgets"' "$PLUGIN/manifest.json"; then
  echo "dagyr.desktop-widgets isn't installed (looked in $PLUGIN)." >&2
  echo "Install it first, then re-run this installer:" >&2
  echo "  $UPSTREAM_URL" >&2
  exit 1
fi
if [[ ! -d $PLUGIN/.git ]]; then
  echo "$PLUGIN exists but isn't a git checkout of the plugin." >&2
  echo "Reinstall it from $UPSTREAM_URL, then re-run this installer." >&2
  exit 1
fi

command -v git >/dev/null || { echo "git is required." >&2; exit 1; }

# 2. Fetch or update this repo. It's kept (not a temp dir) so layouts/ stays
#    around for importing and re-running install.sh after a plugin update is easy.
if [[ -d $DEST/.git ]]; then
  echo "Updating $DEST"
  git -C "$DEST" pull --ff-only --quiet
else
  echo "Cloning into $DEST"
  git clone --quiet "$REPO_URL" "$DEST"
fi

# 3. Install.
exec "$DEST/install.sh"
