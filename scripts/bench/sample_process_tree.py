"""Sample an app's process tree once per second.

Usage: scripts/bench/sample_process_tree.py <exact process name> <seconds> <out.json>
Reports: app RSS (min/median/max), app phys_footprint at start/end, and total CPU seconds
for the app plus every descendant seen (per-pid max cumulative CPU time, so short-lived
children like `claude` are counted if they live >= ~1s).
"""
import json, subprocess, sys, time, statistics, re

name, seconds, out = sys.argv[1], int(sys.argv[2]), sys.argv[3]

def ps():
    rows = subprocess.run(["ps", "-A", "-o", "pid=,ppid=,rss=,time=,comm="], capture_output=True, text=True).stdout
    procs = {}
    for line in rows.splitlines():
        parts = line.split(None, 4)
        if len(parts) < 5: continue
        pid, ppid, rss, t, comm = parts
        procs[int(pid)] = (int(ppid), int(rss), cpu_seconds(t), comm)
    return procs

def cpu_seconds(t):
    # [[D-]H:]M:SS.ss
    days = 0
    if "-" in t: d, t = t.split("-"); days = int(d)
    parts = [float(p) for p in t.split(":")]
    s = 0.0
    for p in parts: s = s * 60 + p
    return s + days * 86400

def footprint(pid):
    r = subprocess.run(["footprint", "-p", str(pid)], capture_output=True, text=True).stdout
    m = re.search(r"Footprint:\s*([\d.]+)\s*(KB|MB|GB)", r)
    if not m: return None
    v, u = float(m.group(1)), m.group(2)
    return v / 1024 if u == "KB" else v * 1024 if u == "GB" else v

def find_root(procs):
    for pid, (_, _, _, comm) in procs.items():
        if comm.split("/")[-1] == name: return pid
    return None

procs = ps(); root = find_root(procs)
if root is None: sys.exit(f"{name} not running")
fp_start = footprint(root)
cpu_by_pid, comm_by_pid, app_rss = {}, {}, []
baseline = {}  # CPU already used by processes alive at start
first = True
start = time.time()
while time.time() - start < seconds:
    procs = ps()
    if root not in procs: break
    tree, frontier = {root}, [root]
    while frontier:
        p = frontier.pop()
        for c, (pp, *_rest) in procs.items():
            if pp == p and c not in tree: tree.add(c); frontier.append(c)
    for p in tree:
        _, rss, cpu, comm = procs[p]
        if first: baseline[p] = cpu
        cpu_by_pid[p] = max(cpu_by_pid.get(p, 0), cpu)
        comm_by_pid[p] = comm.split("/")[-1]
    first = False
    app_rss.append(procs[root][1] / 1024)
    time.sleep(1)
elapsed = time.time() - start
fp_end = footprint(root)
cpu_by_pid = {p: c - baseline.get(p, 0) for p, c in cpu_by_pid.items()}
children = {}
for p, c in cpu_by_pid.items():
    if p == root: continue
    children.setdefault(comm_by_pid[p], [0, 0])
    children[comm_by_pid[p]][0] += 1; children[comm_by_pid[p]][1] += c
res = {
    "name": name, "seconds": round(elapsed),
    "app_cpu_s": round(cpu_by_pid.get(root, 0), 2),
    "children_cpu_s": round(sum(v[1] for v in children.values()), 2),
    "children": {k: {"count": v[0], "cpu_s": round(v[1], 2)} for k, v in sorted(children.items(), key=lambda kv: -kv[1][1])},
    "app_rss_mb": {"min": round(min(app_rss), 1), "median": round(statistics.median(app_rss), 1), "max": round(max(app_rss), 1)},
    "app_footprint_mb": {"start": fp_start, "end": fp_end},
}
json.dump(res, open(out, "w"), indent=2); print(json.dumps(res, indent=2))
