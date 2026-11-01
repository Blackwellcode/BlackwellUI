"""BlackwellUI localisation tool.

  python -I l10n_tool.py catalog <addon_dir> <out_keys.txt>
      Collects every English key the addon shows through L[]:
        - literal keys:           L["..."]
        - Options helper labels:  AddToggle/AddSection/AddNote/AddCycler/
                                  AddStepper/AddActionButton/CreateButton/
                                  ToggleModule literal arguments
        - table values shown via L[x.label] / L[x.desc] / L[x.title]:
          label = "..." / desc = "..." / title = "..." in files that index
          L with such a field (Build.lua's spell data is excluded).
      Writes one key per line (Lua-escaped, UTF-8), sorted.

  python -I l10n_tool.py check <addon_dir> <keys.txt>
      For every Locales/<code>.lua: missing keys, unknown keys, placeholder
      mismatches (%s %d %.Nf order) and colour-code mismatches.
"""
import os
import re
import sys

sys.stdout.reconfigure(encoding="utf-8", errors="replace")

STR = r'"((?:[^"\\\n]|\\.)*)"'
LIT_L = re.compile(r"\bL\[\s*" + STR + r"\s*\]")
HELPERS = re.compile(r"\b(AddToggle|AddSection|AddNote|AddCycler|AddStepper|AddActionButton|CreateButton|ToggleModule)\s*\(")
FIELD_USE = re.compile(r"\bL\[\s*[\w.]*\.(label|desc|title|text|name)\s*\]")
FIELD_DEF = re.compile(r"\b(label|desc|title|text)\s*=\s*" + STR)
EXCLUDE_FIELD_FILES = {"Build.lua", "SpellIcons.lua", "AbilityNames.lua", "Locale.lua"}
PLACEHOLDER = re.compile(r"%[-+ #0]*\d*(?:\.\d+)?[sdfxXcgq]|%%")
COLOUR = re.compile(r"\|c[0-9a-fA-F]{8}|\|r")


def lua_unescape(s):
    return re.sub(r'\\(["\\nrt])', lambda m: {"n": "\n", "r": "\r", "t": "\t"}.get(m.group(1), m.group(1)), s)


def strip_comments(text):
    out = []
    for line in text.split("\n"):
        s = line.lstrip()
        if s.startswith("--"):
            out.append("")
            continue
        # drop trailing comment outside strings (good enough: no "--" inside our UI strings)
        idx = line.find(" --")
        out.append(line if idx < 0 else line[:idx])
    return "\n".join(out)


def helper_args(text, start):
    """Literal string arguments of the call opening at text[start-1]=='('."""
    depth, i, args = 1, start, []
    while i < len(text) and depth > 0:
        c = text[i]
        if c == '"':
            m = re.match(STR, text[i:])
            if m:
                if depth == 1:
                    args.append(m.group(1))
                i += len(m.group(0))
                continue
        if c in "({[":
            depth += 1
        elif c in ")}]":
            depth -= 1
        i += 1
    return args


# Values the game supplies at runtime and the addon shows through L[]
# (Timer.lua: L[item.state]).
EXTRA_KEYS = ["dead", "alive", "due"]
VAR_USE = re.compile(r"\bL\[\s*([A-Za-z_][A-Za-z0-9_]*)\s*\]")


def catalog(root):
    keys = set(EXTRA_KEYS)
    texts = {}
    for fn in sorted(os.listdir(root)):
        if fn.endswith(".lua"):
            with open(os.path.join(root, fn), encoding="utf-8") as fh:
                texts[fn] = strip_comments(fh.read())
    # field names shown via L[x.<field>] anywhere -> their literals in all files
    used_fields = set()
    any_field = re.compile(r"\bL\[\s*[\w.]*\.(\w+)\s*\]")
    for text in texts.values():
        used_fields.update(m.group(1) for m in any_field.finditer(text))
    # follow copies such as r.statDesc = item.desc back to the source field
    changed = True
    while changed:
        changed = False
        for text in texts.values():
            for m in re.finditer(r"\.(\w+)\s*=\s*[A-Za-z_][\w]*\.(\w+)\b", text):
                if m.group(1) in used_fields and m.group(2) not in used_fields:
                    used_fields.add(m.group(2))
                    changed = True
    for fn, text in texts.items():
        # Build.lua's spell data (name/desc/...) stays English; only its
        # tooltip section titles are shown through L[sec.title].
        fields = ("title",) if fn in EXCLUDE_FIELD_FILES else ("label", "desc", "title", "text")
        for m in re.finditer(r"\b(label|desc|title|text)\s*=\s*" + STR, text):
            if m.group(1) in fields and m.group(1) in used_fields and re.search(r"[A-Za-z]", m.group(2)):
                keys.add(m.group(2))
    # Module settings shown by the generated options pages: label / hint /
    # toggleLabel fields (option entries, choice values, mod.hint, mod.label).
    for fn, text in texts.items():
        if fn in ("SpellIcons.lua", "AbilityNames.lua", "GameStrings.lua", "Locale.lua"):
            continue
        for m in re.finditer(r"\b(label|hint|toggleLabel)\s*=\s*" + STR, text):
            if re.search(r"[A-Za-z]", m.group(2)):
                keys.add(m.group(2))
        # Value -> label tables (STYLE_LABEL, VIS_LABEL, ...) shown via L[...]
        for tm in re.finditer(r"local\s+\w+_LABEL\s*=\s*\{([^}]*)\}", text):
            for sm in re.finditer(STR, tm.group(1)):
                if re.search(r"[A-Za-z]", sm.group(1)):
                    keys.add(sm.group(1))
    for fn in sorted(texts):
        text = texts[fn]
        # variables shown via L[var] -> literals assigned to them in that file
        for var in set(m.group(1) for m in VAR_USE.finditer(text)):
            for m in re.finditer(r"\b" + re.escape(var) + r"\s*=\s*" + STR, text):
                if re.search(r"[A-Za-z]", m.group(1)):
                    keys.add(m.group(1))
            # var is a parameter of a local function -> literal call arguments
            for fm in re.finditer(r"function\s+([\w.:]+)\s*\(([^)]*)\)", text):
                params = [p.strip() for p in fm.group(2).split(",")]
                if var not in params:
                    continue
                fname = fm.group(1).split(":")[-1].split(".")[-1]
                for cm in re.finditer(r"\b" + re.escape(fname) + r"\s*\(", text):
                    if text[cm.start() - 9:cm.start()].endswith("function "):
                        continue
                    for a in helper_args(text, cm.end()):
                        if re.search(r"[A-Za-z]", a) and not re.fullmatch(r"[a-z][a-zA-Z0-9_]*", a):
                            keys.add(a)
        for m in LIT_L.finditer(text):
            keys.add(m.group(1))
        # L[(cond and "a") or "b"]: every literal inside the bracket is a key
        for m in re.finditer(r"\bL\[\s*\(", text):
            for a in helper_args(text, m.end()):
                if re.search(r"[A-Za-z]", a):
                    keys.add(a)
        for m in HELPERS.finditer(text):
            args = helper_args(text, m.end())
            if m.group(1) == "ToggleModule":
                args = args[1:2]
            for a in args:
                if re.search(r"[A-Za-z]", a) and not re.fullmatch(r"[a-z][a-zA-Z0-9_]*", a):
                    keys.add(a)
    keys ={k for k in keys if k.strip() and k not in {"<", ">", "-", "+", "x"}}
    return sorted(keys, key=lambda k: k.lower())


def load_locale(path):
    with open(path, encoding="utf-8") as fh:
        text = fh.read()
    pairs = re.findall(r"\[\s*" + STR + r"\s*\]\s*=\s*" + STR, text)
    return text, {a: b for a, b in pairs}, len(pairs)


def check(root, keys_path):
    with open(keys_path, encoding="utf-8") as fh:
        keys = [l.rstrip("\n") for l in fh if l.strip()]
    keyset = set(keys)
    ok_all = True
    locdir = os.path.join(root, "Locales")
    for fn in sorted(os.listdir(locdir)):
        if not fn.endswith(".lua"):
            continue
        text, table, npairs = load_locale(os.path.join(locdir, fn))
        missing = [k for k in keys if k not in table]
        unknown = [k for k in table if k not in keyset]
        dupes = npairs - len(table)
        bad_ph, bad_col, empty = [], [], []
        for k, v in table.items():
            if not v.strip():
                empty.append(k)
            if PLACEHOLDER.findall(lua_unescape(k)) != PLACEHOLDER.findall(lua_unescape(v)):
                bad_ph.append((k, v))
            if len(COLOUR.findall(k)) != len(COLOUR.findall(v)):
                bad_col.append((k, v))
        reg = re.search(r'RegisterLocale\(\s*"([a-z]{2})"', text)
        status = "OK" if not (missing or unknown or dupes or bad_ph or bad_col or empty) and reg else "PROBLEMS"
        ok_all = ok_all and status == "OK"
        print(f"{fn}: {status} entries={len(table)} missing={len(missing)} unknown={len(unknown)} "
              f"dupes={dupes} placeholder={len(bad_ph)} colour={len(bad_col)} empty={len(empty)} "
              f"register={'yes ' + reg.group(1) if reg else 'NO'}")
        for k in missing[:8]:
            print("    missing:", k)
        for k in unknown[:5]:
            print("    unknown:", k)
        for k, v in bad_ph[:5]:
            print("    placeholder:", k, "=>", v)
    print("ALL OK" if ok_all else "CHECK FAILED")
    return ok_all


def main():
    mode, root = sys.argv[1], sys.argv[2]
    if mode == "catalog":
        keys = catalog(root)
        with open(sys.argv[3], "w", encoding="utf-8", newline="\n") as fh:
            fh.write("\n".join(keys) + "\n")
        print("keys", len(keys), "->", sys.argv[3])
    elif mode == "check":
        sys.exit(0 if check(root, sys.argv[3]) else 1)


if __name__ == "__main__":
    main()
