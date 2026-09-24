#!/usr/bin/env python3
# Icon glyphs available in a font (the Quick Launch glyph picker).
#   get-glyphs.sh [family]      (default: monospace, i.e. the system font)
#
# Resolves the family with fc-match, reads the font file's own character map
# and glyph names (no fontTools needed), and keeps the icon glyphs -- the
# Private Use Area, where Nerd Fonts put theirs, named like "fa-bug",
# "md-rocket", "dev-vim". Cached per font file + mtime.
#
# Prints one JSON line:
#   {"status": "ok", "family": ..., "file": ..., "glyphs": [[codepoint, name], ...]}
#   {"status": "error", "message": ...}
import os
import re
import sys
import json
import struct
import hashlib
import subprocess

CACHE_DIR = os.path.join(os.environ.get('XDG_CACHE_HOME') or os.path.expanduser('~/.cache'),
                         'dagyr.desktop-widgets', 'glyphs')


def emit(obj):
    print(json.dumps(obj, separators=(',', ':')), flush=True)


def is_icon(cp):
    return 0xE000 <= cp <= 0xF8FF or 0xF0000 <= cp <= 0xFFFFD


def read_font(path):
    with open(path, 'rb') as f:
        d = f.read()
    if d[:4] == b'ttcf':  # collection: use the first font
        d_off = struct.unpack('>I', d[12:16])[0]
    else:
        d_off = 0
    num = struct.unpack('>H', d[d_off + 4:d_off + 6])[0]
    tables = {}
    for i in range(num):
        tag, _cs, off, ln = struct.unpack('>4sIII', d[d_off + 12 + 16 * i:d_off + 28 + 16 * i])
        tables[tag.decode('latin1')] = (off, ln)

    # cmap: prefer a format 12 (full Unicode) subtable, else format 4 (BMP).
    off, _ = tables['cmap']
    n = struct.unpack('>H', d[off + 2:off + 4])[0]
    subs = []
    for i in range(n):
        _pid, _eid, so = struct.unpack('>HHI', d[off + 4 + 8 * i:off + 12 + 8 * i])
        subs.append((struct.unpack('>H', d[off + so:off + so + 2])[0], off + so))
    cmap = {}
    fmt12 = [o for fmt, o in subs if fmt == 12]
    if fmt12:
        o = fmt12[0]
        ng = struct.unpack('>I', d[o + 12:o + 16])[0]
        for g in range(ng):
            s, e, st = struct.unpack('>III', d[o + 16 + 12 * g:o + 28 + 12 * g])
            for c in range(s, e + 1):
                cmap[c] = st + c - s
    else:
        o = [o for fmt, o in subs if fmt == 4][0]
        segx2 = struct.unpack('>H', d[o + 6:o + 8])[0]
        seg = segx2 // 2
        ends = struct.unpack('>%dH' % seg, d[o + 14:o + 14 + segx2])
        starts = struct.unpack('>%dH' % seg, d[o + 16 + segx2:o + 16 + 2 * segx2])
        deltas = struct.unpack('>%dh' % seg, d[o + 16 + 2 * segx2:o + 16 + 3 * segx2])
        ro_pos = o + 16 + 3 * segx2
        ranges = struct.unpack('>%dH' % seg, d[ro_pos:ro_pos + segx2])
        for i in range(seg):
            for c in range(starts[i], ends[i] + 1):
                if c == 0xFFFF:
                    continue
                if ranges[i] == 0:
                    g = (c + deltas[i]) & 0xFFFF
                else:
                    p = ro_pos + 2 * i + ranges[i] + 2 * (c - starts[i])
                    g = struct.unpack('>H', d[p:p + 2])[0]
                    if g:
                        g = (g + deltas[i]) & 0xFFFF
                if g:
                    cmap[c] = g

    # post v2: glyph names (Nerd Fonts name their icons "fa-bug" etc.).
    names = {}
    if 'post' in tables:
        off, ln = tables['post']
        if struct.unpack('>I', d[off:off + 4])[0] == 0x20000:
            ng = struct.unpack('>H', d[off + 32:off + 34])[0]
            idx = struct.unpack('>%dH' % ng, d[off + 34:off + 34 + 2 * ng])
            p, pas = off + 34 + 2 * ng, []
            while p < off + ln:
                l = d[p]
                pas.append(d[p + 1:p + 1 + l].decode('latin1'))
                p += 1 + l
            for g, i in enumerate(idx):
                if i >= 258 and i - 258 < len(pas):
                    names[g] = pas[i - 258]

    out = []
    for cp in sorted(cmap):
        if is_icon(cp):
            nm = names.get(cmap[cp]) or ''
            if re.fullmatch(r'(uni|u)[0-9A-Fa-f]{4,6}', nm):
                nm = ''  # auto-generated, no real name
            out.append([cp, nm or 'U+%04X' % cp])
    return out


def main():
    family = sys.argv[1] if len(sys.argv) > 1 and sys.argv[1] else 'monospace'
    try:
        path = subprocess.run(['fc-match', family, '--format', '%{file}'],
                              capture_output=True, text=True, timeout=5).stdout.strip()
        if not path or not os.path.isfile(path):
            raise RuntimeError('fc-match found no font file for ' + family)
        key = hashlib.sha1(('%s:%d' % (path, os.stat(path).st_mtime_ns)).encode()).hexdigest()[:16]
        cache = os.path.join(CACHE_DIR, key + '.json')
        try:
            with open(cache, encoding='utf-8') as f:
                glyphs = json.load(f)
        except Exception:
            glyphs = read_font(path)
            os.makedirs(CACHE_DIR, exist_ok=True)
            with open(cache + '.tmp', 'w', encoding='utf-8') as f:
                json.dump(glyphs, f, separators=(',', ':'))
            os.replace(cache + '.tmp', cache)
        emit({'status': 'ok', 'family': family, 'file': path, 'glyphs': glyphs})
    except Exception as e:
        emit({'status': 'error', 'message': str(e)})


if __name__ == '__main__':
    main()
