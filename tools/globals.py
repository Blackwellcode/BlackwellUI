"""Global read/write inventory via `luac -l -l` bytecode listing (Lua 5.4).

GETTABUP/SETTABUP on _ENV are global accesses. Reports globals written by the
addon (namespace pollution) and globals read but never written by the addon
(engine API, or typos / undefined names).
Usage: python -I globals.py <addon_dir>
"""
import os
import re
import subprocess
import sys
from collections import defaultdict

SKIP = {"Icons.lua", "SpellNames.lua"}
RX = re.compile(r"\b(GETTABUP|SETTABUP)\b.*?;\s*_ENV\s+\"([^\"]+)\"")


def main():
    root = sys.argv[1]
    reads = defaultdict(set)
    writes = defaultdict(set)
    for fn in sorted(os.listdir(root)):
        if not fn.endswith(".lua"):
            continue
        out = subprocess.run(["luac", "-l", "-l", "-p", os.path.join(root, fn)],
                             capture_output=True, text=True, check=True).stdout
        for line in out.splitlines():
            m = RX.search(line)
            if not m:
                continue
            ln = re.search(r"\[(\d+)\]", line)
            loc = f"{fn}:{ln.group(1) if ln else '?'}"
            (writes if m.group(1) == "SETTABUP" else reads)[m.group(2)].add(loc)
    print("=== WRITTEN GLOBALS ===")
    for k in sorted(writes):
        if True:
            locs = sorted(writes[k])
            print(f"{k}  ({len(locs)}) {', '.join(locs[:3])}")
    print("=== READ, NEVER WRITTEN BY ADDON ===")
    for k in sorted(reads):
        if k not in writes:
            locs = sorted(reads[k])
            print(f"{k}  ({len(locs)}) {', '.join(locs[:2])}")


if __name__ == "__main__":
    main()
