#!/usr/bin/env python3
# Self-updater for the custom desktop-widgets suite (the "Check for Updates"
# item in each custom widget's right-click menu).
#
#   get-suite-update.sh check   -> is the repo ahead of what's installed?
#   get-suite-update.sh apply   -> pull the repo, run its install.sh, then
#                                  reload the shell so the new QML loads
#
# Prints one JSON line:
#   {"status": "current", "local": sha}
#   {"status": "available", "local": sha|null, "remote": sha, "count": n|null,
#    "commits": ["subject", ...]}
#   {"status": "updated", "local": old|null, "remote": sha, "log": [...]}
#   {"status": "error", "message": "..."}
#
# The installed version is whatever install.sh last recorded in
# ~/.local/state/omarchy/desktop-widgets-version. The repo is kept at the
# same place the one-line bootstrap installer uses, so both stay in step.
import os
import sys
import json
import shutil
import subprocess
import urllib.request

REPO_URL = os.environ.get('DESKTOP_WIDGETS_REPO', 'https://github.com/DasPoxy/desktop-widgets.git')
BRANCH = 'main'
STATE = os.path.join(os.environ.get('XDG_STATE_HOME') or os.path.expanduser('~/.local/state'),
                     'omarchy', 'desktop-widgets-version')
DEST = os.environ.get('DESKTOP_WIDGETS_DIR') or os.path.join(
    os.environ.get('XDG_DATA_HOME') or os.path.expanduser('~/.local/share'), 'desktop-widgets')
PLUGIN = os.environ.get('PLUGIN_DIR') or os.path.expanduser('~/.config/omarchy/plugins/dagyr.desktop-widgets')


def emit(obj):
    print(json.dumps(obj), flush=True)


def git(*args, cwd=None, timeout=60):
    r = subprocess.run(['git', *args], cwd=cwd, capture_output=True, text=True, timeout=timeout)
    if r.returncode != 0:
        raise RuntimeError((r.stderr or r.stdout).strip().splitlines()[-1] if (r.stderr or r.stdout).strip() else 'git ' + args[0] + ' failed')
    return r.stdout


def installed():
    try:
        with open(STATE, encoding='utf-8') as f:
            sha = f.read().strip()
        return sha or None
    except OSError:
        return None


def remote_head():
    out = git('ls-remote', REPO_URL, 'refs/heads/' + BRANCH, timeout=20)
    if not out.strip():
        raise RuntimeError('branch ' + BRANCH + ' not found on ' + REPO_URL)
    return out.split()[0]


def github_compare(base, head):
    # Commit subjects between two SHAs (public repos only; best effort).
    if 'github.com/' not in REPO_URL:
        return None, []
    slug = REPO_URL.split('github.com/', 1)[1].removesuffix('.git').strip('/')
    url = 'https://api.github.com/repos/%s/compare/%s...%s' % (slug, base, head)
    try:
        req = urllib.request.Request(url, headers={'Accept': 'application/vnd.github+json',
                                                   'User-Agent': 'desktop-widgets-updater'})
        with urllib.request.urlopen(req, timeout=10) as r:
            data = json.load(r)
        commits = [c['commit']['message'].splitlines()[0] for c in data.get('commits', [])]
        return data.get('ahead_by'), list(reversed(commits))[:6]
    except Exception:
        return None, []


def check():
    local = installed()
    remote = remote_head()
    if local == remote:
        emit({'status': 'current', 'local': local})
        return
    count, commits = github_compare(local, remote) if local else (None, [])
    emit({'status': 'available', 'local': local, 'remote': remote, 'count': count, 'commits': commits})


def apply():
    if not os.path.isfile(os.path.join(PLUGIN, 'manifest.json')) or not os.path.isdir(os.path.join(PLUGIN, '.git')):
        raise RuntimeError('dagyr.desktop-widgets plugin not found at ' + PLUGIN)
    local = installed()
    if os.path.isdir(os.path.join(DEST, '.git')):
        git('fetch', '--quiet', 'origin', BRANCH, cwd=DEST)
        git('reset', '--hard', '--quiet', 'origin/' + BRANCH, cwd=DEST)
    else:
        if os.path.exists(DEST):
            shutil.rmtree(DEST)
        git('clone', '--quiet', REPO_URL, DEST, timeout=120)
    r = subprocess.run([os.path.join(DEST, 'install.sh')], capture_output=True, text=True, timeout=120)
    log = [l for l in (r.stdout + r.stderr).splitlines() if l.strip()]
    if r.returncode != 0:
        raise RuntimeError('install.sh failed: ' + (log[-1] if log else 'exit %d' % r.returncode))
    remote = git('rev-parse', 'HEAD', cwd=DEST).strip()
    emit({'status': 'updated', 'local': local, 'remote': remote, 'log': log[-12:]})
    # Reload the shell (detached, so it survives this widget going away) with
    # a fresh QML cache -- plugin QML edits otherwise tend to stay stale.
    if os.environ.get('DESKTOP_WIDGETS_NO_RELOAD'):
        return
    subprocess.Popen(['setsid', '-f', 'sh', '-c',
                      'sleep 1.5; rm -rf "$HOME/.cache/quickshell/qmlcache"; omarchy-restart-shell'],
                     stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


if __name__ == '__main__':
    try:
        {'check': check, 'apply': apply}[sys.argv[1] if len(sys.argv) > 1 else 'check']()
    except KeyError:
        emit({'status': 'error', 'message': 'usage: get-suite-update.sh check|apply'})
    except Exception as e:
        emit({'status': 'error', 'message': str(e)})
