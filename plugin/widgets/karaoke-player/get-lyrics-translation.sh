#!/usr/bin/env python3
# Lyric translations for the Karaoke (MPRIS) Player widget.
#   get-lyrics-translation.sh <target_lang> <json array of line texts>
# Lyric databases (LRCLIB) carry no translations, and Musixmatch's won't
# hand out an anonymous token, so this is machine translation: Google's
# free Chrome-extension endpoint (one batched request per ~4k chars, with
# per-line language detection), falling back to MyMemory. Cached on disk by
# target language + lyrics, so a replay costs nothing.
#
# Prints one JSON line:
#   {"status": "ok", "lines": ["...", ""], "from": "ja", "source": "..."}
#     one entry per input line; "" where the line is blank or already in the
#     target language (so mixed-language songs don't echo themselves)
#   {"status": "same", "from": "en"}   whole song is already in the target
#   {"status": "error", "message": "..."}
import os
import sys
import json
import hashlib
import collections
import urllib.parse
import urllib.request

CACHE_DIR = os.path.join(
    os.environ.get('XDG_CACHE_HOME') or os.path.expanduser('~/.cache'),
    'dagyr.desktop-widgets', 'lyrics-translations',
)
UA = 'Mozilla/5.0 (X11; Linux x86_64) dagyr.desktop-widgets Karaoke Player'
CHUNK_CHARS = 4000


def emit(obj):
    print(json.dumps(obj, ensure_ascii=False), flush=True)


def base_lang(code):
    return (code or '').lower().split('-')[0]


def google(texts, target):
    """[(translation, detected_lang)] for each text, batched."""
    out = []
    i = 0
    while i < len(texts):
        chunk, size = [], 0
        while i < len(texts) and (not chunk or size + len(texts[i]) < CHUNK_CHARS):
            chunk.append(texts[i])
            size += len(texts[i]) + 1
            i += 1
        url = 'https://clients5.google.com/translate_a/t?' + urllib.parse.urlencode(
            {'client': 'dict-chrome-ex', 'sl': 'auto', 'tl': target})
        body = urllib.parse.urlencode([('q', t) for t in chunk]).encode()
        req = urllib.request.Request(url, data=body, headers={'User-Agent': UA})
        with urllib.request.urlopen(req, timeout=15) as r:
            res = json.load(r)
        if not isinstance(res, list) or len(res) != len(chunk):
            raise ValueError('unexpected Google response')
        for item in res:
            # One text -> ["translation", "lang"]; very old shape -> "translation".
            if isinstance(item, list):
                out.append((str(item[0]), str(item[1]) if len(item) > 1 else ''))
            else:
                out.append((str(item), ''))
    return out


def mymemory(texts, target):
    """Fallback: newline-joined chunks under MyMemory's 500-char limit."""
    out = []
    i = 0
    while i < len(texts):
        chunk, size = [], 0
        while i < len(texts) and (not chunk or size + len(texts[i]) + 1 < 480):
            chunk.append(texts[i].replace('\n', ' '))
            size += len(texts[i]) + 1
            i += 1
        url = 'https://api.mymemory.translated.net/get?' + urllib.parse.urlencode(
            {'q': '\n'.join(chunk), 'langpair': 'autodetect|' + target})
        req = urllib.request.Request(url, headers={'User-Agent': UA})
        with urllib.request.urlopen(req, timeout=15) as r:
            res = json.load(r)
        if res.get('responseStatus') != 200:
            raise ValueError(res.get('responseDetails') or 'MyMemory error')
        data = res.get('responseData') or {}
        parts = str(data.get('translatedText') or '').split('\n')
        if len(parts) != len(chunk):
            raise ValueError('MyMemory changed the line count')
        lang = str(data.get('detectedLanguage') or '')
        out.extend((p.strip(), lang) for p in parts)
    return out


def main():
    if len(sys.argv) < 3:
        emit({'status': 'error', 'message': 'usage: <lang> <json lines>'})
        return
    target = sys.argv[1].strip()
    try:
        lines = [str(t) for t in json.loads(sys.argv[2])]
    except Exception as e:
        emit({'status': 'error', 'message': 'bad lines: %s' % e})
        return

    key = hashlib.sha1((target + '\n' + '\n'.join(lines)).encode()).hexdigest()
    cache_path = os.path.join(CACHE_DIR, key + '.json')
    try:
        with open(cache_path, 'r', encoding='utf-8') as f:
            emit(json.load(f))
        return
    except Exception:
        pass

    # Translate each distinct non-blank line once (choruses repeat).
    uniq = list(dict.fromkeys(t.strip() for t in lines if t.strip()))
    if not uniq:
        emit({'status': 'same', 'from': ''})
        return
    try:
        pairs, source = google(uniq, target), 'Google Translate'
    except Exception:
        try:
            pairs, source = mymemory(uniq, target), 'MyMemory'
        except Exception as e:
            emit({'status': 'error', 'message': str(e)})
            return

    tbase = base_lang(target)
    table = {}
    langs = collections.Counter()
    for src, (tr, lang) in zip(uniq, pairs):
        if lang:
            langs[base_lang(lang)] += 1
        same = base_lang(lang) == tbase or tr.strip().lower() == src.lower()
        table[src] = '' if same else tr.strip()
    main_lang = langs.most_common(1)[0][0] if langs else ''

    if not any(table.values()):
        res = {'status': 'same', 'from': main_lang or tbase}
    else:
        res = {'status': 'ok', 'lines': [table.get(t.strip(), '') for t in lines],
               'from': main_lang, 'source': source}
    try:
        os.makedirs(CACHE_DIR, exist_ok=True)
        tmp = cache_path + '.tmp'
        with open(tmp, 'w', encoding='utf-8') as f:
            json.dump(res, f, ensure_ascii=False)
        os.replace(tmp, cache_path)
    except Exception:
        pass
    emit(res)


if __name__ == '__main__':
    main()
