#!/usr/bin/env bash
# MLZ UI: all checks in one go (local, pre-commit hook and CI)
# 1. Lua 5.1 syntax  2. luacheck  3. repo rules (tools/check.lua)  4. load test (tests/load.lua)
# Needs luacheck and a Lua 5.1 interpreter (lua5.1 or luajit). macOS: brew install luajit luacheck
set -euo pipefail

cd "$(dirname "$0")/.."

fail=0
step() { printf '\n== %s\n' "$1"; }

# Lua 5.1 is what the client runs. Newer Lua parses some 5.1 code differently, so prefer 5.1.
LUA51=""
for c in lua5.1 luajit lua-5.1; do
    if command -v "$c" >/dev/null 2>&1; then LUA51="$c"; break; fi
done
LUA="${LUA51:-lua}"
if ! command -v "$LUA" >/dev/null 2>&1; then
    echo "No Lua found. Install Lua 5.1 or LuaJIT (macOS: brew install luajit)." >&2
    exit 2
fi

FILES=()
while IFS= read -r f; do FILES+=("$f"); done < <(git ls-files --cached --others --exclude-standard '*.lua')

step "Syntax"
if command -v luac5.1 >/dev/null 2>&1; then
    luac5.1 -p "${FILES[@]}" || fail=1
elif [ "$LUA" = "luajit" ]; then
    for f in "${FILES[@]}"; do luajit -bl "$f" >/dev/null || fail=1; done
elif [ -n "$LUA51" ]; then
    for f in "${FILES[@]}"; do "$LUA" -e "assert(loadfile('$f'))" || fail=1; done
else
    echo "skipped: no Lua 5.1 (CI checks it). brew install luajit to check locally."
fi
[ -n "$LUA51" ] && [ $fail -eq 0 ] && echo "OK (${#FILES[@]} files)"

step "Luacheck"
if command -v luacheck >/dev/null 2>&1; then
    luacheck . --quiet || fail=1
    [ $fail -eq 0 ] && echo "OK"
else
    echo "luacheck is not installed (brew install luacheck)." >&2
    fail=1
fi

step "Repo rules"
"$LUA" tools/check.lua || fail=1

step "Load test"
if [ -z "$LUA51" ]; then
    echo "note: running on $("$LUA" -v 2>&1 | head -1), CI uses Lua 5.1"
fi
"$LUA" tests/load.lua || fail=1

echo
if [ $fail -ne 0 ]; then
    echo "Checks failed."
    exit 1
fi
echo "All checks passed."
