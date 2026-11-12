#!/usr/bin/env bash
# Test gate for BlackwellUI. Every step must pass before a commit is merged
# into main (and before main goes to the live worktree).
#   1. luac -p over every tracked .lua file (syntax)
#   2. tools/lua50scan.py (constructs that Lua 5.0 / the 1.12 API lack)
#   3. toc_check.py of the domain-wow-dev skill, when installed (TOC references)
#   4. tools/l10n_tool.py catalog + check (13 locales complete, placeholders)
#   5. tools/harness.lua (core: SavedVariables, stock state, ticker, locales)
#   6. tools/harness_modules.lua (all TOC files, event-driven module paths)
# Needs lua/luac (5.4 runs the 5.0 code through polyfills) and python.
# Usage: bash tools/check.sh
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
WORK="$ROOT/_work/check"
mkdir -p "$WORK"
FAILED=0
step() { printf '\n== %s\n' "$1"; }
result() {
    if [ "$1" -eq 0 ]; then echo "-> OK"; else echo "-> FEHLER (Exit $1)"; FAILED=1; fi
}

step "luac -p"
BAD=0
COUNT=0
while IFS= read -r f; do
    COUNT=$((COUNT + 1))
    luac -p "$f" || BAD=1
done < <(git ls-files '*.lua')
echo "$COUNT Dateien"
result $BAD

step "lua50scan"
python -I tools/lua50scan.py . | tail -n 5
result "${PIPESTATUS[0]}"

TOC_CHECK="$HOME/.claude/skills/domain-wow-dev/scripts/toc_check.py"
step "toc_check"
if [ -f "$TOC_CHECK" ]; then
    python -I "$TOC_CHECK" . | tail -n 6
    result "${PIPESTATUS[0]}"
else
    echo "toc_check.py nicht installiert, Schritt übersprungen"
fi

step "l10n"
python -I tools/l10n_tool.py catalog . "$WORK/l10n-keys.txt" && python -I tools/l10n_tool.py check . "$WORK/l10n-keys.txt" | tail -n 2
result "${PIPESTATUS[0]}"

step "harness (Core)"
lua tools/harness.lua Core.lua
result $?

step "harness (Module)"
lua tools/harness_modules.lua .
result $?

echo
if [ "$FAILED" -eq 0 ]; then echo "GATE: OK"; else echo "GATE: FEHLER"; fi
exit $FAILED
