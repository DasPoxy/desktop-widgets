#!/usr/bin/env python3
# Resolve a YouTube (or any yt-dlp supported) URL into a locally cached video
# file for the Video Player widget. QtMultimedia can't mux YouTube's separate
# video/audio DASH streams, and direct stream URLs expire after a few hours,
# so a cached local file is what keeps HD playback and looping working.
#
# Emits one JSON object per line:
#   {"status": "progress", "percent": 0-100, "title": "..."}
#   {"status": "ok", "path": "...", "title": "..."}
#   {"status": "error", "message": "..."}
import sys
import os
import re
import json
import shutil
import subprocess

CACHE_DIR = os.path.join(
    os.environ.get('XDG_CACHE_HOME') or os.path.expanduser('~/.cache'),
    'dagyr.desktop-widgets', 'youtube',
)
# Keep the cache from growing unbounded: only the most recently used videos stay.
CACHE_KEEP = 5

# Prefer H.264 (cheapest to decode, always supported by the FFmpeg backend),
# capped at 1080p; fall back to whatever combined/best format exists.
FORMAT = 'bv*[height<=1080][vcodec^=avc1]+ba[ext=m4a]/bv*[height<=1080]+ba/b'


def emit(obj):
    print(json.dumps(obj), flush=True)


def prune_cache(keep_path):
    try:
        files = [os.path.join(CACHE_DIR, f) for f in os.listdir(CACHE_DIR)]
        files = [f for f in files if os.path.isfile(f) and not f.endswith('.part')]
        files.sort(key=os.path.getmtime, reverse=True)
        for f in files[CACHE_KEEP:]:
            if os.path.realpath(f) != os.path.realpath(keep_path):
                os.remove(f)
    except Exception:
        pass


def main():
    if len(sys.argv) < 2 or not sys.argv[1].strip():
        emit({'status': 'error', 'message': 'No URL given'})
        return
    url = sys.argv[1].strip()

    ytdlp = shutil.which('yt-dlp')
    if not ytdlp:
        emit({'status': 'error', 'message': 'yt-dlp is not installed'})
        return

    os.makedirs(CACHE_DIR, exist_ok=True)
    cmd = [
        ytdlp, '-f', FORMAT, '--merge-output-format', 'mp4',
        '-o', os.path.join(CACHE_DIR, '%(id)s.%(ext)s'),
        '--no-playlist', '--newline', '--progress',
        '--progress-template', 'download:PROGRESS %(progress._percent_str)s',
        '--print', 'before_dl:INFO %(format_id)s\t%(title)s',
        '--print', 'after_move:FILE %(filepath)s',
        url,
    ]

    try:
        proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    except Exception as e:
        emit({'status': 'error', 'message': str(e)})
        return

    title = ''
    stages = 1
    stage = 0
    last_pct = 0.0
    last_emitted = -1
    path = None

    for line in proc.stdout:
        line = line.rstrip('\n')
        if line.startswith('INFO '):
            fmt, _, title = line[5:].partition('\t')
            stages = fmt.count('+') + 1
        elif line.startswith('PROGRESS '):
            m = re.search(r'([\d.]+)%', line)
            if not m:
                continue
            pct = float(m.group(1))
            # Each merged stream (video, then audio) reports its own 0-100.
            if pct + 5 < last_pct and stage + 1 < stages:
                stage += 1
            last_pct = pct
            overall = int((stage + pct / 100.0) / stages * 100)
            if overall != last_emitted:
                last_emitted = overall
                emit({'status': 'progress', 'percent': min(overall, 99), 'title': title})
        elif line.startswith('FILE '):
            path = line[5:].strip()

    stderr = proc.stderr.read()
    proc.wait()

    if proc.returncode == 0 and path and os.path.isfile(path):
        os.utime(path, None)
        prune_cache(path)
        emit({'status': 'ok', 'path': path, 'title': title or os.path.basename(path)})
        return

    msg = ''
    for l in stderr.splitlines():
        if l.startswith('ERROR:'):
            msg = l[len('ERROR:'):].strip()
    emit({'status': 'error', 'message': msg or 'Download failed'})


if __name__ == '__main__':
    main()
