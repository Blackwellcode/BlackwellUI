"""Lua 5.0 / WoW 1.12 compatibility scanner.

Tokenizes Lua source (strings, long strings, comments stripped) and reports
constructs that do not exist in Lua 5.0 or the 1.12.1 FrameXML API.
Usage: python -I lua50scan.py <addon_dir>
Scans the addon folder and Locales/. A line that carries the comment
"-- lua50scan: ok" is a reviewed, guarded use and is not reported.
Exit code 1 when anything is reported (test gate).
"""
import os
import re
import sys

SKIP_FILES = {"Icons.lua", "SpellNames.lua"}


def strip_code(src):
    """Return src with strings/comments replaced by spaces (newlines kept)."""
    out = []
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        if src.startswith("--", i):
            m = re.match(r"--\[(=*)\[", src[i:])
            if m:
                close = "]" + m.group(1) + "]"
                j = src.find(close, i + len(m.group(0)))
                j = n if j < 0 else j + len(close)
            else:
                j = src.find("\n", i)
                j = n if j < 0 else j
            out.append(re.sub(r"[^\n]", " ", src[i:j]))
            i = j
            continue
        m = re.match(r"\[(=*)\[", src[i:])
        if m:
            close = "]" + m.group(1) + "]"
            j = src.find(close, i + len(m.group(0)))
            j = n if j < 0 else j + len(close)
            out.append('"' + re.sub(r"[^\n]", " ", src[i + 1:j - 1]) + '"')
            i = j
            continue
        if c in "'\"":
            j = i + 1
            while j < n and src[j] != c:
                if src[j] == "\\":
                    j += 1
                elif src[j] == "\n":
                    break
                j += 1
            j = min(j + 1, n)
            out.append(c + re.sub(r"[^\n]", " ", src[i + 1:j - 1]) + c)
            i = j
            continue
        out.append(c)
        i += 1
    return "".join(out)


RULES = [
    ("len-op #", re.compile(r"#")),
    ("modulo %", re.compile(r"%")),
    ("int-div //", re.compile(r"//")),
    ("bitwise op", re.compile(r"(?<![~<>=])(&|\||<<|>>|~(?!=))")),
    ("goto/label", re.compile(r"\bgoto\b|::\w+::")),
    ("string method call", re.compile(
        r":(find|sub|gsub|match|gmatch|format|len|lower|upper|rep|byte|reverse|split|trim)\s*\(")),
    ("5.1+ stdlib", re.compile(
        r"\b(select|wipe|strsplit|strtrim|strjoin|tContains|tinsert_unique)\s*\(|"
        r"\bstring\.(match|gmatch)\b|\bmath\.(fmod|huge|tointeger|type|ult)\b|"
        r"\btable\.(maxn|pack|unpack|wipe)\b|\bunpack\s*\(\s*\{\s*\.\.\.")),
    ("post-1.12 API", re.compile(
        r":(SetSize|SetColorTexture|HookScript|SetShown|SetAtlas|SetClipsChildren|"
        r"SetIgnoreParentScale|SetResizeBounds|SetObeyStepOnDrag|CreateAnimationGroup|"
        r"SetRotation|SetSnapToPixelGrid|SetTexelSnappingBias|SetEnabled|"
        r"SetMaxLines|SetWordWrap|SetGradientAlpha2)\s*\(|"
        r"\b(C_\w+|hooksecurefunc|UnitGUID|CombatLogGetCurrentEventInfo|UnitAura|"
        r"GetNumGroupMembers|IsInGroup|Mixin|CreateFromMixins|GetCVarBool|"
        r"GetPhysicalScreenSize|debugprofilestop|BackdropTemplateMixin|Enum)\b")),
    ("handler uses self param", re.compile(r"SetScript\s*\(\s*\"On\w+\"\s*,\s*function\s*\(\s*self")),
]

VARARG = re.compile(r"\.\.\.")
FUNC_PARAMS = re.compile(r"function\s*[\w.:]*\s*\(([^()]*)\)")


def scan_file(path):
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        src = fh.read()
    code = strip_code(src)
    lines = code.split("\n")
    raw = src.split("\n")
    hits = []
    for ln, line in enumerate(lines, 1):
        if "-- lua50scan: ok" in raw[ln - 1]:
            continue
        for name, rx in RULES:
            for m in rx.finditer(line):
                hits.append((ln, name, m.group(0), raw[ln - 1].strip()[:140]))
        if "..." in line:
            ok_spans = [m.span(1) for m in FUNC_PARAMS.finditer(line)]
            for m in VARARG.finditer(line):
                if not any(a <= m.start() < b for a, b in ok_spans):
                    hits.append((ln, "vararg outside params", "...", raw[ln - 1].strip()[:140]))
    return hits


def main():
    root = sys.argv[1]
    total = 0
    files = 0
    for sub in ("", "Locales"):
        folder = os.path.join(root, sub)
        if not os.path.isdir(folder):
            continue
        for fn in sorted(os.listdir(folder)):
            if not fn.endswith(".lua") or fn in SKIP_FILES:
                continue
            rel = os.path.join(sub, fn) if sub else fn
            hits = scan_file(os.path.join(folder, fn))
            files += 1
            total += len(hits)
            for ln, name, tok, text in hits:
                print(f"{rel}:{ln}: [{name}] {tok!r} :: {text}")
    print(f"TOTAL {total} ({files} files)")
    sys.exit(1 if total else 0)


if __name__ == "__main__":
    main()
