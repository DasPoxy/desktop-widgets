#!/usr/bin/env python3
# Agent rate-limit usage for the System Monitor widget. Reads the records
# Omarchy's own omarchy-agent-usage-update writes (the same files the
# agents bar panel shows), so there's one source of truth and no credential
# handling here. If the newest record is older than STALE_SEC -- e.g. no
# agents bar panel is running to keep them fresh -- kicks off a background
# --limits-only refresh; the next poll picks the new data up.
import os
import sys
import json
import glob
import shutil
import subprocess
from datetime import datetime, timezone

USAGE_DIR = os.path.join(
    os.environ.get('XDG_STATE_HOME') or os.path.expanduser('~/.local/state'),
    'omarchy', 'agents', 'usage',
)
STALE_SEC = 15 * 60


def parse_time(s):
    try:
        return datetime.fromisoformat(str(s).replace('Z', '+00:00'))
    except Exception:
        return None


def main():
    now = datetime.now(timezone.utc)
    agents = []
    newest = None
    for path in sorted(glob.glob(os.path.join(USAGE_DIR, '*.json'))):
        try:
            with open(path, 'r', encoding='utf-8') as f:
                rec = json.load(f)
        except Exception:
            continue
        updated = parse_time(rec.get('updatedAt'))
        if updated and (newest is None or updated > newest):
            newest = updated
        limits = []
        for lim in rec.get('limits') or []:
            try:
                pct = float(lim.get('percent'))
            except (TypeError, ValueError):
                continue
            if pct < 0:
                continue
            resets = parse_time(lim.get('resetsAt'))
            limits.append({
                'label': lim.get('label') or '',
                'percent': pct,
                'resetsInSec': int((resets - now).total_seconds()) if resets else -1,
            })
        if not rec.get('ready') or not limits:
            continue
        agents.append({
            'id': rec.get('id') or os.path.basename(path)[:-5],
            'name': rec.get('name') or rec.get('id') or '',
            'tier': rec.get('tierLabel') or '',
            'limits': limits,
        })

    stale = newest is None or (now - newest).total_seconds() > STALE_SEC
    if stale and len(sys.argv) > 1 and sys.argv[1] == '--refresh-if-stale':
        updater = shutil.which('omarchy-agent-usage-update')
        if updater:
            try:
                subprocess.Popen([updater, '--limits-only'], stdout=subprocess.DEVNULL,
                                 stderr=subprocess.DEVNULL, start_new_session=True)
            except Exception:
                pass

    print(json.dumps({'agents': agents, 'stale': stale}), flush=True)


if __name__ == '__main__':
    main()
