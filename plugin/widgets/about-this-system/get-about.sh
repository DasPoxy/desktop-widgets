#!/usr/bin/env python3
# Collects an "about this system" snapshot (fastfetch's hardware/software
# facts plus Omarchy's own branding commands) and the active theme's color
# palette, as one JSON object for the About widget to render natively.
import json
import os
import re
import shutil
import subprocess
import sys

try:
    import tomllib
except ImportError:
    tomllib = None

HOME = os.path.expanduser('~')
STATE_THEME_DIR = os.path.join(HOME, '.local/state/omarchy/current/theme')
STATE_THEME_NAME = os.path.join(HOME, '.local/state/omarchy/current/theme.name')

HEX_RE = re.compile(r'^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$')


def run(cmd, timeout=4):
    exe = shutil.which(cmd[0])
    if not exe:
        return None
    try:
        p = subprocess.run([exe] + cmd[1:], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, timeout=timeout)
        out = p.stdout.strip()
        return out if out else None
    except Exception:
        return None


def format_size(n):
    if n is None:
        return None
    n = float(n)
    for unit in ('B', 'KB', 'MB', 'GB', 'TB'):
        if n < 1024 or unit == 'TB':
            return (f"{n:.0f} {unit}" if unit == 'B' else f"{n:.1f} {unit}")
        n /= 1024
    return f"{n:.1f} TB"


def format_uptime(ms):
    if not ms:
        return None
    total_seconds = int(ms / 1000)
    days, rem = divmod(total_seconds, 86400)
    hours, rem = divmod(rem, 3600)
    minutes, _ = divmod(rem, 60)
    parts = []
    if days:
        parts.append(f"{days}d")
    if hours or days:
        parts.append(f"{hours}h")
    parts.append(f"{minutes}m")
    return " ".join(parts)


def collect_fastfetch():
    exe = shutil.which('fastfetch')
    if not exe:
        return None
    try:
        p = subprocess.run([exe, '--format', 'json'], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, timeout=6)
        modules = json.loads(p.stdout)
    except Exception:
        return None

    by_type = {}
    for m in modules:
        t = m.get('type')
        if 'error' in m:
            continue
        by_type.setdefault(t, []).append(m.get('result'))

    out = {}

    host = (by_type.get('Host') or [None])[0]
    if host:
        name = host.get('name') or ''
        vendor = host.get('vendor') or ''
        out['host'] = (f"{vendor} {name}".strip() if vendor and vendor not in name else name) or None

    cpu = (by_type.get('CPU') or [None])[0]
    if cpu:
        out['cpu'] = cpu.get('cpu')
        cores = cpu.get('cores') or {}
        if cores.get('physical') and cores.get('logical'):
            out['cpu_cores'] = f"{cores['physical']} cores / {cores['logical']} threads"

    gpus = (by_type.get('GPU') or [None])[0]
    if gpus:
        names = [g.get('name') for g in gpus if g.get('name')]
        if names:
            out['gpu'] = ", ".join(names)

    displays = (by_type.get('Display') or [None])[0]
    if displays:
        chosen = next((d for d in displays if d.get('primary')), displays[0] if displays else None)
        if chosen:
            o = chosen.get('output') or {}
            w, h, hz = o.get('width'), o.get('height'), o.get('refreshRate')
            if w and h:
                out['display'] = f"{w}x{h}" + (f" @ {round(hz)}Hz" if hz else "")

    disks = (by_type.get('Disk') or [None])[0]
    if disks:
        root = next((d for d in disks if d.get('mountpoint') == '/'), disks[0] if disks else None)
        if root:
            b = root.get('bytes') or {}
            out['disk_used'] = format_size(b.get('used'))
            out['disk_total'] = format_size(b.get('total'))

    mem = (by_type.get('Memory') or [None])[0]
    if mem:
        out['memory_used'] = format_size(mem.get('used'))
        out['memory_total'] = format_size(mem.get('total'))

    swaps = (by_type.get('Swap') or [None])[0]
    if swaps:
        total = sum(s.get('total') or 0 for s in swaps)
        used = sum(s.get('used') or 0 for s in swaps)
        if total > 0:
            out['swap_used'] = format_size(used)
            out['swap_total'] = format_size(total)

    kernel = (by_type.get('Kernel') or [None])[0]
    if kernel:
        out['kernel'] = kernel.get('release')

    wm = (by_type.get('WM') or [None])[0]
    if wm:
        pretty = wm.get('prettyName') or wm.get('processName')
        ver = wm.get('version')
        out['wm'] = f"{pretty} {ver}".strip() if pretty and ver else pretty

    de = (by_type.get('DE') or [None])[0]
    if de and de.get('prettyName'):
        out['de'] = de.get('prettyName')

    packages = (by_type.get('Packages') or [None])[0]
    if packages:
        bits = []
        if packages.get('pacman'):
            bits.append(f"{packages['pacman']} pacman")
        if packages.get('flatpakSystem'):
            bits.append(f"{packages['flatpakSystem']} flatpak")
        if packages.get('appimage'):
            bits.append(f"{packages['appimage']} appimage")
        if bits:
            out['packages'] = ", ".join(bits)

    uptime = (by_type.get('Uptime') or [None])[0]
    if uptime:
        out['uptime'] = format_uptime(uptime.get('uptime'))

    return out


def collect_omarchy_branding():
    out = {}
    version = run(['omarchy-version'])
    if version:
        out['os'] = f"Omarchy {version}"
    channel = run(['omarchy-version-channel'])
    if channel:
        out['channel'] = channel
    branch = run(['omarchy-version-branch'])
    if branch:
        out['branch'] = branch
    last_update = run(['omarchy-version-pkgs'])
    if last_update:
        out['last_update'] = last_update

    theme = run(['omarchy-theme-current'])
    if not theme and os.path.exists(STATE_THEME_NAME):
        try:
            with open(STATE_THEME_NAME, 'r') as f:
                theme = f.read().strip()
        except Exception:
            theme = None
    if theme:
        out['theme'] = theme

    try:
        birth = os.stat('/').st_birthtime
    except Exception:
        birth = None
    if birth is None:
        stat_out = run(['stat', '-c', '%W', '/'])
        try:
            birth = int(stat_out) if stat_out and stat_out != '0' else None
        except Exception:
            birth = None
    if birth:
        import time
        days = int((time.time() - birth) / 86400)
        if days >= 0:
            out['os_age'] = f"{days} days"

    return out


def collect_swatches():
    if tomllib is None:
        return []
    path = os.path.join(STATE_THEME_DIR, 'colors.toml')
    if not os.path.isfile(path):
        return []
    try:
        with open(path, 'rb') as f:
            data = tomllib.load(f)
    except Exception:
        return []

    swatches = []
    for key, val in data.items():
        if not isinstance(val, str) or not HEX_RE.match(val):
            continue
        label = re.sub(r'(\d+)$', r' \1', key.replace('_', ' ').title())
        swatches.append({"label": label, "hex": val})
    return swatches


def main():
    result = {}
    ff = collect_fastfetch()
    if ff:
        result.update(ff)
    result.update(collect_omarchy_branding())
    result['swatches'] = collect_swatches()
    print(json.dumps(result), flush=True)


if __name__ == '__main__':
    main()
