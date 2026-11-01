"""Build the BlackwellUI release zip: BlackwellUI/<files>, forward slashes.

Usage: python -I build_zip.py <addon_dir> <out_zip>
Ships what the game loads (TOC files + media) plus README.md.
"""
import os
import sys
import zipfile

EXCLUDE_DIRS = {".git", ".github", ".claude", "screenshots", "tools", "__pycache__"}
EXCLUDE_FILES = {".gitignore", "CLAUDE.md"}


def main():
    root, out = sys.argv[1], sys.argv[2]
    count = 0
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for dp, dirs, files in os.walk(root):
            dirs[:] = sorted(d for d in dirs if d not in EXCLUDE_DIRS)
            rel_dir = os.path.relpath(dp, root)
            arc_dir = "BlackwellUI" if rel_dir == "." else "BlackwellUI/" + rel_dir.replace(os.sep, "/")
            z.writestr(arc_dir + "/", "")
            for fn in sorted(files):
                if fn in EXCLUDE_FILES or fn.startswith("_"):
                    continue
                z.write(os.path.join(dp, fn), arc_dir + "/" + fn)
                count += 1
    print(f"{count} files -> {out} ({os.path.getsize(out)} bytes)")


if __name__ == "__main__":
    main()
