#!/usr/bin/env python3
import sys
import os
import json
import shutil
import subprocess

VIDEO_EXTENSIONS = ('.mp4', '.mkv', '.webm', '.avi', '.mov', '.m4v', '.ogv', '.wmv', '.flv', '.ts')

def pick_video_dialog():
    omarchy_select = shutil.which('omarchy-file-select')
    if omarchy_select:
        try:
            exts = ' '.join(e.lstrip('.') for e in VIDEO_EXTENSIONS)
            p = subprocess.run(
                [omarchy_select, '--title', 'Select a Video', '--extensions', exts],
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
            filt = 'Video Files | ' + ' '.join('*' + e for e in VIDEO_EXTENSIONS)
            p = subprocess.run(
                [zenity, '--file-selection', '--title=Select a Video', '--file-filter=' + filt],
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
            filt = ' '.join('*' + e for e in VIDEO_EXTENSIONS) + ' | Video Files'
            p = subprocess.run(
                [kdialog, '--title', 'Select a Video', '--getopenfilename', os.path.expanduser('~'), filt],
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                text=True
            )
            if p.returncode == 0 and p.stdout.strip():
                return p.stdout.strip()
        except Exception:
            pass

    return None

def main():
    chosen = pick_video_dialog()
    if chosen and os.path.isfile(chosen):
        print(json.dumps({
            "status": "ok",
            "path": chosen,
            "filename": os.path.basename(chosen)
        }), flush=True)
    else:
        print(json.dumps({"status": "cancelled"}), flush=True)

if __name__ == '__main__':
    main()
