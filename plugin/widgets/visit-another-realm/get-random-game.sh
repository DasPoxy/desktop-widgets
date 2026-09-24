#!/usr/bin/env python3
import sys
import os
import re
import json
import random
import sqlite3
import subprocess

STEAM_ROOTS = (
    os.path.expanduser('~/.local/share/Steam'),
    os.path.expanduser('~/.steam/steam'),
)

HEROIC_CACHE = os.path.expanduser('~/.config/heroic/store_cache')
HEROIC_ICONS = os.path.expanduser('~/.config/heroic/icons')
LUTRIS_DB = os.path.expanduser('~/.local/share/lutris/pga.db')
LUTRIS_COVERART = os.path.expanduser('~/.local/share/lutris/coverart')
LUTRIS_BANNERS = os.path.expanduser('~/.local/share/lutris/banners')

# Installed-but-not-really-a-game noise seen on real libraries (runtimes,
# redistributables, mod managers) -- filtered by name since there's no
# reliable installed-games flag that excludes these otherwise.
NON_GAME_KEYWORDS = (
    'redistributable', 'steam linux runtime', 'proton', 'steamvr',
    'steam controller', 'mod manager', 'mod organizer',
)


def is_probably_a_game(name):
    lname = name.lower()
    return not any(kw in lname for kw in NON_GAME_KEYWORDS)


def find_steam_root():
    for root in STEAM_ROOTS:
        if os.path.isdir(root):
            return root
    return None


def steam_library_paths(steam_root):
    paths = [os.path.join(steam_root, 'steamapps')]
    vdf_path = os.path.join(steam_root, 'steamapps', 'libraryfolders.vdf')
    try:
        with open(vdf_path, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
        for m in re.finditer(r'"path"\s+"([^"]+)"', content):
            candidate = os.path.join(m.group(1), 'steamapps')
            if candidate not in paths:
                paths.append(candidate)
    except Exception:
        pass
    return paths


def collect_steam_games():
    games = []
    steam_root = find_steam_root()
    if not steam_root:
        return games
    library_cache = os.path.join(steam_root, 'appcache', 'librarycache')
    for steamapps_dir in steam_library_paths(steam_root):
        if not os.path.isdir(steamapps_dir):
            continue
        try:
            entries = os.listdir(steamapps_dir)
        except Exception:
            continue
        for entry in entries:
            if not (entry.startswith('appmanifest_') and entry.endswith('.acf')):
                continue
            try:
                with open(os.path.join(steamapps_dir, entry), 'r', encoding='utf-8', errors='ignore') as f:
                    content = f.read()
                appid_m = re.search(r'"appid"\s+"(\d+)"', content)
                name_m = re.search(r'"name"\s+"([^"]*)"', content)
                if not appid_m or not name_m:
                    continue
                name = name_m.group(1)
                if not is_probably_a_game(name):
                    continue
                appid = appid_m.group(1)
                image = os.path.join(library_cache, appid, 'library_600x900.jpg')
                games.append({
                    'key': 'steam:' + appid,
                    'name': name,
                    'source': 'Steam',
                    'launch': ['xdg-open', 'steam://rungameid/' + appid],
                    'image': image if os.path.isfile(image) else None,
                })
            except Exception:
                continue
    return games


def collect_heroic_games():
    games = []
    sources = [
        ('legendary_library.json', 'library', 'Heroic (Epic)'),
        ('nile_library.json', 'library', 'Heroic (Amazon)'),
        ('gog_library.json', 'games', 'Heroic (GOG)'),
    ]
    for filename, list_key, label in sources:
        path = os.path.join(HEROIC_CACHE, filename)
        if not os.path.isfile(path):
            continue
        try:
            with open(path, 'r', encoding='utf-8') as f:
                data = json.load(f)
        except Exception:
            continue
        for g in data.get(list_key, []) or []:
            if not g.get('is_installed'):
                continue
            if g.get('install', {}).get('is_dlc'):
                continue
            title = g.get('title') or g.get('app_name')
            app_name = g.get('app_name')
            runner = g.get('runner')
            if not title or not app_name or not runner:
                continue
            if not is_probably_a_game(title):
                continue
            image = None
            for ext in ('.jpg', '.png'):
                candidate = os.path.join(HEROIC_ICONS, app_name + ext)
                if os.path.isfile(candidate):
                    image = candidate
                    break
            games.append({
                'key': 'heroic:' + app_name,
                'name': title,
                'source': label,
                'launch': ['xdg-open', 'heroic://launch?appName=' + app_name + '&runner=' + runner],
                'image': image,
            })
    return games


def collect_lutris_games():
    games = []
    if not os.path.isfile(LUTRIS_DB):
        return games
    try:
        conn = sqlite3.connect(LUTRIS_DB)
        cur = conn.cursor()
        cur.execute("SELECT id, name, slug FROM games WHERE installed = 1")
        rows = cur.fetchall()
        conn.close()
    except Exception:
        return games
    for game_id, name, slug in rows:
        if not name or not is_probably_a_game(name):
            continue
        image = None
        for base_dir in (LUTRIS_COVERART, LUTRIS_BANNERS):
            candidate = os.path.join(base_dir, str(slug) + '.jpg')
            if slug and os.path.isfile(candidate):
                image = candidate
                break
        games.append({
            'key': 'lutris:' + str(game_id),
            'name': name,
            'source': 'Lutris',
            'launch': ['lutris', 'lutris:rungameid/' + str(game_id)],
            'image': image,
        })
    return games


def collect_all_games(excluded=()):
    games = collect_steam_games() + collect_heroic_games() + collect_lutris_games()
    if excluded:
        games = [g for g in games if g['key'] not in excluded]
    return games


def run_list():
    games = sorted(collect_all_games(), key=lambda g: g['name'].lower())
    print(json.dumps({
        'status': 'ok',
        'games': [{'key': g['key'], 'name': g['name'], 'source': g['source']} for g in games],
    }), flush=True)


def run_thumbnails(count, excluded=()):
    games = [g for g in collect_all_games(excluded) if g.get('image')]
    if not games:
        print(json.dumps({'status': 'empty'}), flush=True)
        return
    picked = random.sample(games, min(count, len(games)))
    print(json.dumps({
        'status': 'ok',
        'games': [{'name': g['name'], 'source': g['source'], 'image': g['image']} for g in picked],
    }), flush=True)


def pop_excluded(args):
    # `--exclude '<json list of game keys>'` may appear anywhere; strip it out
    # so the positional mode/count parsing below stays unchanged.
    excluded = set()
    if '--exclude' in args:
        i = args.index('--exclude')
        try:
            excluded = set(json.loads(args[i + 1]))
        except (IndexError, ValueError, TypeError):
            pass
        del args[i:i + 2]
    return excluded


def main():
    args = sys.argv[1:]
    excluded = pop_excluded(args)

    if args and args[0] == 'list':
        run_list()
        return

    if args and args[0] == 'thumbnails':
        count = 4
        if len(args) >= 2:
            try:
                count = max(1, int(args[1]))
            except ValueError:
                pass
        run_thumbnails(count, excluded)
        return

    games = collect_all_games(excluded)
    if not games:
        print(json.dumps({'status': 'empty'}), flush=True)
        return

    chosen = random.choice(games)
    try:
        subprocess.Popen(
            chosen['launch'],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
    except Exception as e:
        print(json.dumps({'status': 'error', 'message': str(e)}), flush=True)
        return

    print(json.dumps({
        'status': 'ok',
        'name': chosen['name'],
        'source': chosen['source'],
        'count': len(games),
    }), flush=True)


if __name__ == '__main__':
    main()
