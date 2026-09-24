#!/usr/bin/env python3
import sys
import os
import json
import shutil
import subprocess
import urllib.parse

IMAGE_EXTENSIONS = ('.jpg', '.jpeg', '.png', '.webp', '.avif', '.gif')
STATE_DIR = os.path.expanduser('~/.local/state/omarchy')
STATE_FILE = os.path.join(STATE_DIR, 'dagyr.desktop-widgets.json')
LEGACY_CONFIG = os.path.expanduser('~/.config/omarchy/plugins/dagyr.desktop-widgets/settings.json')

# --- Safe state-file access -------------------------------------------------
# Several scripts read-modify-write the same state file. Without this, two
# saves landing together could let one read a half-written file, fall back
# to defaults and save those -- wiping every layout preset (it happened).
# So: one writer at a time (flock), writes are atomic (temp file + rename),
# and a file that exists but won't parse is never replaced with defaults.
import fcntl
import time

_state_lock = None


def _lock_state():
    global _state_lock
    if _state_lock is None:
        os.makedirs(STATE_DIR, exist_ok=True)
        _state_lock = open(STATE_FILE + '.lock', 'a')
        fcntl.flock(_state_lock, fcntl.LOCK_EX)


def _read_state_file():
    last = None
    for _ in range(10):
        try:
            with open(STATE_FILE, 'r') as f:
                return json.load(f)
        except FileNotFoundError:
            return None
        except Exception as e:
            last = e
            time.sleep(0.05)
    raise RuntimeError('state file unreadable, refusing to overwrite it: %s' % last)


def _write_state_file(data):
    os.makedirs(STATE_DIR, exist_ok=True)
    tmp = '%s.tmp.%d' % (STATE_FILE, os.getpid())
    with open(tmp, 'w') as f:
        json.dump(data, f, indent=2)
        f.flush()
        os.fsync(f.fileno())
    os.replace(tmp, STATE_FILE)


DEFAULT_DIRS = [
    os.path.expanduser('~/.config/omarchy/plugins/dagyr.desktop-widgets/photos'),
    os.path.expanduser('~/Wallpapers'),
    os.path.expanduser('~/.config/omarchy/backgrounds'),
    os.path.expanduser('~/Pictures')
]

def load_settings():
    _lock_state()
    if os.path.exists(STATE_FILE):
        return _read_state_file()  # raises rather than fall back to defaults
    elif os.path.exists(LEGACY_CONFIG):
        try:
            with open(LEGACY_CONFIG, 'r') as f:
                return json.load(f)
        except Exception:
            pass
    return {"gallery_folder": "ALL"}

def save_settings(settings):
    try:
        _write_state_file(settings)
    except Exception:
        pass

def pick_folder_dialog():
    omarchy_select = shutil.which('omarchy-file-select')
    if omarchy_select:
        try:
            p = subprocess.run(
                [omarchy_select, '--title', 'Select Photo Gallery Folder', '--directory'],
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                text=True
            )
            if p.returncode == 0 and p.stdout.strip():
                return p.stdout.strip().splitlines()[0]
            elif p.returncode != 0:
                return None
        except Exception:
            pass

    zenity = shutil.which('zenity')
    if zenity:
        try:
            p = subprocess.run(
                [zenity, '--file-selection', '--directory', '--title=Select Photo Gallery Folder'],
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                text=True
            )
            if p.returncode == 0 and p.stdout.strip():
                return p.stdout.strip()
        except Exception:
            pass

    kdialog = shutil.which('kdialog')
    if kdialog:
        try:
            p = subprocess.run(
                [kdialog, '--title', 'Select Photo Gallery Folder', '--getexistingdirectory'],
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                text=True
            )
            if p.returncode == 0 and p.stdout.strip():
                return p.stdout.strip()
        except Exception:
            pass

    return None

def find_images(target_dir):
    images = []
    seen = set()

    if target_dir == "ALL" or not target_dir:
        search_dirs = DEFAULT_DIRS
    else:
        search_dirs = [os.path.expanduser(target_dir)]

    for d in search_dirs:
        if not os.path.exists(d):
            continue
        try:
            for root, _, files in os.walk(d):
                for f in sorted(files):
                    ext = os.path.splitext(f)[1].lower()
                    if ext in IMAGE_EXTENSIONS:
                        full_path = os.path.join(root, f)
                        try:
                            if not os.path.isfile(full_path):
                                continue
                            size = os.path.getsize(full_path)
                            if size < 5000:
                                continue
                        except Exception:
                            continue

                        if full_path not in seen:
                            seen.add(full_path)
                            base_name = os.path.splitext(f)[0].replace('_', ' ').replace('-', ' ')
                            title = ' '.join(word.capitalize() for word in base_name.split()[:4])
                            images.append({
                                "path": "file://" + urllib.parse.quote(full_path),
                                "raw_path": full_path,
                                "title": title,
                                "filename": f
                            })
        except Exception:
            pass

    return images

def main():
    settings = load_settings()
    current_folder = settings.get("gallery_folder", "ALL")

    if len(sys.argv) > 1:
        arg = sys.argv[1].strip()
        if arg == "pick_dialog":
            chosen = pick_folder_dialog()
            if chosen:
                current_folder = chosen
                settings["gallery_folder"] = current_folder
                save_settings(settings)
        elif arg:
            current_folder = arg
            settings["gallery_folder"] = current_folder
            save_settings(settings)

    imgs = find_images(current_folder)
    print(json.dumps({"type": "init", "folder": current_folder, "total": len(imgs)}), flush=True)
    for img in imgs:
        payload = {"type": "photo"}
        payload.update(img)
        print(json.dumps(payload), flush=True)
    print(json.dumps({"type": "done"}), flush=True)

if __name__ == '__main__':
    main()
