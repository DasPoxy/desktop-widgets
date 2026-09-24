#!/usr/bin/env python3
# Watcher for the Abyss Warden widget. Long-running; prints one JSON object
# per line:
#   {"type": "monitors", "list": {"DP-3": {"x", "y", "w", "h", "reserved": [l, t, r, b]}}}
#   {"type": "rec", "recording": bool, "sources": ["Omarchy recorder", ...]}
#   {"type": "cursor", "x": int, "y": int}              (global, only while active)
#   {"type": "activity", "kind": str, "x": int, "y": int, "title": str}
#                                                        (window centre, only while active)
#
# Recording = Omarchy's recorder (gpu-screen-recorder), other CLI recorders,
# or any screen capture going through xdg-desktop-portal (OBS, Discord,
# browser screen share...), which shows up as a PipeWire Video/Source node
# that isn't a camera.
#
# stdin commands: "active 1" / "active 0" -- cursor + window activity are
# only sampled while the eye is awake, so an idle widget costs one cheap
# poll every couple of seconds.
import os
import re
import sys
import json
import time
import socket
import threading
import subprocess

HYPR_DIR = os.path.join(os.environ.get('XDG_RUNTIME_DIR', '/tmp'), 'hypr',
                        os.environ.get('HYPRLAND_INSTANCE_SIGNATURE', ''))
REC_POLL_SEC = 2.0
CURSOR_HZ = 20
ACTIVITY_EVENTS = {'openwindow', 'windowtitlev2', 'activewindowv2', 'urgent', 'movewindowv2'}
TITLE_COOLDOWN_SEC = 1.2   # terminals/browsers can spam title changes
CLI_RECORDERS = [
    ('^gpu-screen-recorder', 'Omarchy recorder'),
    ('^wf-recorder', 'wf-recorder'),
    ('^wl-screenrec', 'wl-screenrec'),
]
CAMERA_NODE = re.compile(r'^(v4l2_|libcamera_|api\.v4l2|api\.libcamera)')

active = False
out_lock = threading.Lock()


def emit(obj):
    with out_lock:
        try:
            print(json.dumps(obj), flush=True)
        except BrokenPipeError:
            os._exit(0)


def hypr(cmd):
    try:
        s = socket.socket(socket.AF_UNIX)
        s.settimeout(1.0)
        s.connect(os.path.join(HYPR_DIR, '.socket.sock'))
        s.sendall(cmd.encode())
        buf = b''
        while True:
            d = s.recv(65536)
            if not d:
                break
            buf += d
        s.close()
        return json.loads(buf.decode(errors='replace'))
    except Exception:
        return None


def monitors():
    out = {}
    for m in hypr('j/monitors') or []:
        scale = m.get('scale') or 1
        out[m.get('name', '')] = {
            'x': m.get('x', 0), 'y': m.get('y', 0),
            'w': round(m.get('width', 0) / scale), 'h': round(m.get('height', 0) / scale),
            'reserved': m.get('reserved', [0, 0, 0, 0]),
            'workspace': (m.get('activeWorkspace') or {}).get('id'),
        }
    return out


def portal_capture():
    # Video sources that aren't cameras = a live portal screencast.
    try:
        txt = subprocess.run(['pw-cli', 'ls', 'Node'], capture_output=True, text=True, timeout=2).stdout
    except Exception:
        return False
    for block in re.split(r'\n\s*id \d+, type ', txt):
        cls = re.search(r'media\.class = "([^"]*)"', block)
        if not cls or cls.group(1) != 'Video/Source':
            continue
        name = re.search(r'node\.name = "([^"]*)"', block)
        if name and CAMERA_NODE.match(name.group(1)):
            continue
        return True
    return False


def recording_sources():
    found = []
    for pattern, label in CLI_RECORDERS:
        if subprocess.run(['pgrep', '--quiet', '-f', pattern]).returncode == 0:
            found.append(label)
    if portal_capture():
        found.append('Screen capture (portal)')
    return found


def rec_loop():
    last = None
    while True:
        sources = recording_sources()
        state = (bool(sources), tuple(sources))
        if state != last:
            last = state
            emit({'type': 'rec', 'recording': bool(sources), 'sources': sources})
        time.sleep(REC_POLL_SEC)


def cursor_loop():
    last = None
    while True:
        if active:
            pos = hypr('j/cursorpos')
            if pos:
                cur = (pos.get('x', 0), pos.get('y', 0))
                if cur != last:
                    last = cur
                    emit({'type': 'cursor', 'x': cur[0], 'y': cur[1]})
            time.sleep(1.0 / CURSOR_HZ)
        else:
            last = None
            time.sleep(0.25)


def window_centre(address):
    mons = monitors()
    visible_ws = {m['workspace'] for m in mons.values()}
    for c in hypr('j/clients') or []:
        if not c.get('address', '').endswith(address.replace('0x', '')):
            continue
        if (c.get('workspace') or {}).get('id') not in visible_ws or c.get('hidden'):
            return None
        (x, y), (w, h) = c.get('at', [0, 0]), c.get('size', [0, 0])
        return {'x': x + w // 2, 'y': y + h // 2, 'title': c.get('title', '')}
    return None


def event_loop():
    last_title = {}
    while True:
        try:
            s = socket.socket(socket.AF_UNIX)
            s.connect(os.path.join(HYPR_DIR, '.socket2.sock'))
            f = s.makefile('r', encoding='utf-8', errors='replace')
            for line in f:
                name, _, data = line.strip().partition('>>')
                if name.startswith('monitor'):
                    emit({'type': 'monitors', 'list': monitors()})
                    continue
                if not active or name not in ACTIVITY_EVENTS:
                    continue
                address = data.split(',', 1)[0]
                if not address:
                    continue
                if name == 'windowtitlev2':
                    now = time.time()
                    if now - last_title.get(address, 0) < TITLE_COOLDOWN_SEC:
                        continue
                    last_title[address] = now
                centre = window_centre(address)
                if centre:
                    emit(dict(centre, type='activity', kind=name))
        except Exception:
            pass
        time.sleep(2)


def stdin_loop():
    global active
    for line in sys.stdin:
        parts = line.split()
        if len(parts) == 2 and parts[0] == 'active':
            active = parts[1] == '1'
    os._exit(0)  # widget went away


if __name__ == '__main__':
    emit({'type': 'monitors', 'list': monitors()})
    for fn in (rec_loop, cursor_loop, event_loop):
        threading.Thread(target=fn, daemon=True).start()
    stdin_loop()
