#!/usr/bin/env python3
# Lyrics for the MPRIS Player widget.
#   get-lyrics.sh <artist> <title> <album> <duration_sec> <track_url>
# Order: a sibling .lrc/.txt next to a local file:// track, then the on-disk
# cache, then LRCLIB (lrclib.net -- free, no key, time-synced LRC). Misses
# are cached too (retried after a day) so a track without lyrics doesn't hit
# the network on every replay.
#
# Prints one JSON line:
#   {"status": "ok", "synced": true, "lines": [{"t": ms, "text": "..."}], "source": "..."}
#   {"status": "ok", "synced": false, "lines": [{"t": -1, "text": "..."}], ...}
#   {"status": "instrumental"} | {"status": "none"} | {"status": "error", "message": "..."}
import os
import re
import sys
import json
import time
import hashlib
import urllib.parse
import urllib.request

CACHE_DIR = os.path.join(
    os.environ.get('XDG_CACHE_HOME') or os.path.expanduser('~/.cache'),
    'dagyr.desktop-widgets', 'lyrics',
)
MISS_RETRY_SEC = 24 * 3600
USER_AGENT = 'dagyr.desktop-widgets MPRIS Player (https://github.com/dagyr)'

# Noise that video/streaming titles carry but lyric databases don't.
TITLE_NOISE = re.compile(
    r'\s*[\(\[][^\)\]]*\b(official|lyrics?|audio|video|visuali[sz]er|remaster(ed)?|hd|hq|4k|mv|live)\b[^\)\]]*[\)\]]',
    re.IGNORECASE,
)
LRC_TAG = re.compile(r'\[(\d+):(\d+(?:\.\d+)?)\]')


def emit(obj):
    print(json.dumps(obj), flush=True)


def clean(artist, title):
    artist = re.sub(r'\s*-\s*Topic$', '', artist or '').strip()
    artist = re.sub(r'VEVO$', '', artist).strip()
    title = TITLE_NOISE.sub('', title or '').strip()
    # "Artist - Title" style titles (browsers, YouTube) with no/duplicate artist.
    if ' - ' in title:
        left, right = title.split(' - ', 1)
        if not artist or left.strip().lower() == artist.lower():
            artist, title = left.strip(), right.strip()
    title = re.sub(r'\s*\((feat|ft)\.?[^)]*\)', '', title, flags=re.IGNORECASE).strip()
    return artist, title


def parse_lrc(text):
    lines = []
    for raw in (text or '').splitlines():
        tags = LRC_TAG.findall(raw)
        if not tags:
            continue
        body = LRC_TAG.sub('', raw).strip()
        for m, s in tags:
            lines.append({'t': int((int(m) * 60 + float(s)) * 1000), 'text': body})
    lines.sort(key=lambda l: l['t'])
    return lines


def plain_lines(text):
    return [{'t': -1, 'text': l.strip()} for l in (text or '').splitlines()]


def result_from_lrclib(rec):
    if rec.get('instrumental'):
        return {'status': 'instrumental', 'source': 'LRCLIB'}
    synced = parse_lrc(rec.get('syncedLyrics'))
    if synced:
        return {'status': 'ok', 'synced': True, 'lines': synced, 'source': 'LRCLIB'}
    if rec.get('plainLyrics'):
        return {'status': 'ok', 'synced': False, 'lines': plain_lines(rec['plainLyrics']), 'source': 'LRCLIB'}
    return None


def http_json(path, params):
    url = 'https://lrclib.net' + path + '?' + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={'User-Agent': USER_AGENT})
    try:
        with urllib.request.urlopen(req, timeout=10) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return None
        raise


def usable(res):
    # LRCLIB is crowd-sourced and has a few stub/test entries (e.g. a single
    # "[00:00.00] probe" line) that would otherwise win the exact match.
    if not res:
        return False
    return res['status'] == 'instrumental' or len(res.get('lines') or []) >= 5


def from_lrclib(artist, title, album, duration):
    params = {'artist_name': artist, 'track_name': title}
    if album:
        params['album_name'] = album
    if duration > 0:
        params['duration'] = int(round(duration))
    rec = http_json('/api/get', params)
    res = result_from_lrclib(rec) if rec else None
    if usable(res):
        return res
    # Fuzzier search: album/duration from players are often missing or off.
    hits = http_json('/api/search', {'artist_name': artist, 'track_name': title}) or []
    if duration > 0:
        hits.sort(key=lambda h: abs((h.get('duration') or 0) - duration))
    candidates = [result_from_lrclib(h) for h in hits]
    for c in candidates:
        if usable(c) and c.get('synced'):
            return c
    for c in candidates:
        if usable(c):
            return c
    return None


def from_local_file(track_url):
    if not track_url.startswith('file://'):
        return None
    path = urllib.parse.unquote(urllib.parse.urlparse(track_url).path)
    base = os.path.splitext(path)[0]
    for ext, synced in (('.lrc', True), ('.txt', False)):
        candidate = base + ext
        if os.path.isfile(candidate):
            with open(candidate, 'r', encoding='utf-8', errors='ignore') as f:
                text = f.read()
            lines = parse_lrc(text) if synced else []
            if lines:
                return {'status': 'ok', 'synced': True, 'lines': lines, 'source': 'Local .lrc'}
            return {'status': 'ok', 'synced': False, 'lines': plain_lines(text), 'source': 'Local file'}
    return None


def main():
    args = sys.argv[1:] + [''] * 5
    artist, title, album, duration_s, track_url = args[:5]
    try:
        duration = float(duration_s or 0)
    except ValueError:
        duration = 0

    local = from_local_file(track_url)
    if local:
        emit(local)
        return

    artist, title = clean(artist, title)
    if not title:
        emit({'status': 'none'})
        return

    key = hashlib.sha1((artist.lower() + '\n' + title.lower()).encode()).hexdigest()
    cache_path = os.path.join(CACHE_DIR, key + '.json')
    try:
        with open(cache_path, 'r', encoding='utf-8') as f:
            cached = json.load(f)
        if cached.get('status') != 'none' or time.time() - cached.get('cachedAt', 0) < MISS_RETRY_SEC:
            cached.pop('cachedAt', None)
            emit(cached)
            return
    except Exception:
        pass

    try:
        res = from_lrclib(artist, title, album, duration) or {'status': 'none'}
    except Exception as e:
        emit({'status': 'error', 'message': str(e)})
        return

    try:
        os.makedirs(CACHE_DIR, exist_ok=True)
        tmp = cache_path + '.tmp'
        with open(tmp, 'w', encoding='utf-8') as f:
            json.dump(dict(res, cachedAt=time.time()), f)
        os.replace(tmp, cache_path)
    except Exception:
        pass
    emit(res)


if __name__ == '__main__':
    main()
