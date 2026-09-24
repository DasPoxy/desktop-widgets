#!/usr/bin/env python3
# Per-app mute for the Karaoke Player widget.
#   get-mute.sh status|toggle <mpris dbus name>
# Resolves the MPRIS bus name to its owning PID, then finds that app's
# PipeWire/Pulse sink-inputs -- including ones owned by child processes
# (Chromium plays audio from a separate audio-service subprocess) -- and
# reads or toggles their mute. MPRIS Volume isn't supported by many players
# (browsers especially), and muting the stream leaves the app's own volume
# slider untouched.
#
# Prints: {"status": "ok", "muted": bool, "streams": n} | {"status": "nostream"}
import sys
import json
import subprocess


def emit(obj):
    print(json.dumps(obj), flush=True)


def owner_pid(bus_name):
    try:
        out = subprocess.run(
            ['busctl', '--user', 'call', 'org.freedesktop.DBus', '/', 'org.freedesktop.DBus',
             'GetConnectionUnixProcessID', 's', bus_name],
            capture_output=True, text=True, timeout=3).stdout.split()
        return int(out[1]) if len(out) >= 2 and out[0] == 'u' else None
    except Exception:
        return None


def descends_from(pid, ancestor):
    seen = 0
    while pid and pid > 1 and seen < 64:
        if pid == ancestor:
            return True
        try:
            with open(f'/proc/{pid}/stat') as f:
                # comm may contain spaces/parens; ppid is the 2nd field after ')'
                pid = int(f.read().rsplit(')', 1)[1].split()[1])
        except Exception:
            return False
        seen += 1
    return False


def pactl_json(*what):
    try:
        return json.loads(subprocess.run(['pactl', '-f', 'json', 'list', *what],
                                         capture_output=True, text=True, timeout=3).stdout or '[]')
    except Exception:
        return []


def matching_streams(root_pid):
    data = pactl_json('sink-inputs')
    # Native PipeWire clients (mpv, ...) only carry the PID on the client
    # object behind the stream, not on the stream itself.
    client_pids = {}
    for c in pactl_json('clients'):
        client_pids[str(c.get('index'))] = c.get('properties', {}).get('application.process.id')
    out = []
    for s in data:
        raw = s.get('properties', {}).get('application.process.id') or client_pids.get(str(s.get('client')))
        try:
            pid = int(raw or 0)
        except (TypeError, ValueError):
            continue
        if pid and descends_from(pid, root_pid):
            out.append(s)
    return out


def main():
    if len(sys.argv) < 3:
        emit({'status': 'nostream'})
        return
    action, bus_name = sys.argv[1], sys.argv[2]
    if not bus_name.startswith('org.mpris.MediaPlayer2.'):
        bus_name = 'org.mpris.MediaPlayer2.' + bus_name
    pid = owner_pid(bus_name)
    streams = matching_streams(pid) if pid else []
    if not streams:
        emit({'status': 'nostream'})
        return

    muted = all(s.get('mute') for s in streams)
    if action == 'toggle':
        target = not muted
        for s in streams:
            subprocess.run(['pactl', 'set-sink-input-mute', str(s['index']), '1' if target else '0'],
                           capture_output=True, timeout=3)
        muted = target
    emit({'status': 'ok', 'muted': muted, 'streams': len(streams)})


if __name__ == '__main__':
    main()
