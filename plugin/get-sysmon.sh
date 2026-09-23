#!/usr/bin/env python3
# CPU / GPU / RAM utilization plus network activity + session totals, as one
# JSON object per poll. Session counters and the inter-poll rate cache are
# each kept in their own file (not the shared widget-settings JSON, which
# only the live QML process should write) so this script never races the
# running shell over a write.
import json
import os
import re
import shutil
import subprocess
import sys
import time

RUNTIME_DIR = os.environ.get('XDG_RUNTIME_DIR') or '/tmp'
RATE_CACHE_FILE = os.path.join(RUNTIME_DIR, f'omarchy_sysmon_rate_{os.getuid()}.json')
STATE_DIR = os.path.expanduser('~/.local/state/omarchy/dagyr.desktop-widgets')
SESSION_FILE = os.path.join(STATE_DIR, 'sysmon_session.json')

CPU_SAMPLE_GAP_SEC = 0.2


def read_json(path):
    try:
        with open(path, 'r') as f:
            return json.load(f)
    except Exception:
        return None


def write_json(path, data):
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, 'w') as f:
            json.dump(data, f)
    except Exception:
        pass


def format_bytes(n):
    n = float(n)
    for unit in ('B', 'KB', 'MB', 'GB', 'TB'):
        if n < 1024 or unit == 'TB':
            return (f"{n:.0f} {unit}" if unit == 'B' else f"{n:.1f} {unit}")
        n /= 1024
    return f"{n:.1f} TB"


def format_speed(bps):
    return format_bytes(bps) + "/s"


# ---------------------------------------------------------------------------
# CPU
# ---------------------------------------------------------------------------
def read_cpu_times():
    with open('/proc/stat') as f:
        parts = [int(x) for x in f.readline().split()[1:]]
    idle = parts[3] + parts[4]  # idle + iowait
    total = sum(parts)
    return idle, total


def collect_cpu():
    try:
        i1, t1 = read_cpu_times()
        time.sleep(CPU_SAMPLE_GAP_SEC)
        i2, t2 = read_cpu_times()
        idle_d = i2 - i1
        total_d = t2 - t1
        if total_d <= 0:
            return 0.0
        return round(max(0.0, min(100.0, 100.0 * (1.0 - idle_d / total_d))), 1)
    except Exception:
        return None


# ---------------------------------------------------------------------------
# RAM
# ---------------------------------------------------------------------------
def collect_ram():
    try:
        total = avail = None
        with open('/proc/meminfo') as f:
            for line in f:
                if line.startswith('MemTotal:'):
                    total = int(line.split()[1]) * 1024
                elif line.startswith('MemAvailable:'):
                    avail = int(line.split()[1]) * 1024
        if total and avail is not None:
            used = total - avail
            return {
                "pct": round(100.0 * used / total, 1),
                "used": format_bytes(used),
                "total": format_bytes(total)
            }
    except Exception:
        pass
    return None


# ---------------------------------------------------------------------------
# GPU(s)
# ---------------------------------------------------------------------------
def collect_gpus():
    gpus = []

    nvidia_smi = shutil.which('nvidia-smi')
    if nvidia_smi:
        try:
            p = subprocess.run(
                [nvidia_smi, '--query-gpu=name,utilization.gpu,memory.used,memory.total',
                 '--format=csv,noheader,nounits'],
                stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, timeout=3
            )
            for line in p.stdout.strip().splitlines():
                bits = [b.strip() for b in line.split(',')]
                if len(bits) == 4:
                    name, pct, mem_used, mem_total = bits
                    gpus.append({
                        "name": name,
                        "pct": float(pct),
                        "mem_used": format_bytes(float(mem_used) * 1024 * 1024),
                        "mem_total": format_bytes(float(mem_total) * 1024 * 1024)
                    })
        except Exception:
            pass

    # Non-NVIDIA cards (AMD amdgpu / Intel i915+) expose live utilization via
    # sysfs directly; NVIDIA's own driver does not, hence nvidia-smi above.
    try:
        for card in sorted(os.listdir('/sys/class/drm')):
            if not re.match(r'^card\d+$', card):
                continue
            device_dir = f'/sys/class/drm/{card}/device'
            vendor_path = os.path.join(device_dir, 'vendor')
            busy_path = os.path.join(device_dir, 'gpu_busy_percent')
            if not os.path.isfile(vendor_path) or not os.path.isfile(busy_path):
                continue
            with open(vendor_path) as f:
                vendor = f.read().strip()
            if vendor == '0x10de':
                continue  # already covered by nvidia-smi above
            with open(busy_path) as f:
                pct = float(f.read().strip())
            name = {'0x1002': 'AMD GPU', '0x8086': 'Intel GPU'}.get(vendor, f'GPU ({card})')
            gpus.append({"name": name, "pct": pct, "mem_used": None, "mem_total": None})
    except Exception:
        pass

    return gpus


# ---------------------------------------------------------------------------
# Network: primary interface, live rate, and a persisted session total
# ---------------------------------------------------------------------------
def read_net_dev():
    stats = {}
    try:
        with open('/proc/net/dev') as f:
            for line in f:
                if ':' not in line:
                    continue
                iface, data = line.split(':', 1)
                iface = iface.strip()
                cols = data.split()
                if len(cols) >= 9:
                    stats[iface] = {'rx': int(cols[0]), 'tx': int(cols[8])}
    except Exception:
        pass
    return stats


def get_primary_iface(stats):
    ignore_prefixes = ('lo', 'docker', 'br-', 'veth', 'virbr')
    candidates = [i for i in stats if not any(i.startswith(p) for p in ignore_prefixes)]
    if not candidates:
        return next(iter(stats), None)
    best, best_total = None, -1
    for iface in candidates:
        total = stats[iface]['rx'] + stats[iface]['tx']
        if total > best_total:
            best, best_total = iface, total
    return best


def collect_network(reset_session=False):
    stats = read_net_dev()
    iface = get_primary_iface(stats)
    if not iface:
        return None
    rx, tx = stats[iface]['rx'], stats[iface]['tx']
    now = time.time()

    # Live rate, via a short-lived cache of the previous poll.
    rx_rate = tx_rate = 0.0
    prev = read_json(RATE_CACHE_FILE)
    if prev and prev.get('iface') == iface and prev.get('ts'):
        dt = now - prev['ts']
        if 0 < dt < 30:
            rx_rate = max(0.0, (rx - prev.get('rx', rx)) / dt)
            tx_rate = max(0.0, (tx - prev.get('tx', tx)) / dt)
    write_json(RATE_CACHE_FILE, {'iface': iface, 'ts': now, 'rx': rx, 'tx': tx})

    # Session total, since this baseline was captured (persists across polls
    # and shell restarts; only a counter reset/wrap or an explicit
    # "Reset Session" starts it over).
    session = read_json(SESSION_FILE)
    if reset_session or not session or session.get('iface') != iface or rx < session.get('base_rx', 0) or tx < session.get('base_tx', 0):
        session = {'iface': iface, 'base_rx': rx, 'base_tx': tx, 'started': now}
        write_json(SESSION_FILE, session)

    session_rx = max(0, rx - session.get('base_rx', rx))
    session_tx = max(0, tx - session.get('base_tx', tx))

    return {
        "iface": iface,
        "down_rate": format_speed(rx_rate),
        "up_rate": format_speed(tx_rate),
        "down_rate_bps": rx_rate,
        "up_rate_bps": tx_rate,
        "session_down": format_bytes(session_rx),
        "session_up": format_bytes(session_tx),
        "session_started": session.get('started')
    }


def main():
    reset_session = len(sys.argv) > 1 and sys.argv[1] == 'reset_session'

    result = {
        "cpu_pct": collect_cpu(),
        "ram": collect_ram(),
        "gpus": collect_gpus(),
        "network": collect_network(reset_session=reset_session)
    }
    print(json.dumps(result), flush=True)


if __name__ == '__main__':
    main()
