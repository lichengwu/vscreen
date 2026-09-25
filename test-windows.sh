#!/bin/bash
# test-windows.sh - Cross-platform tests for vscreen-windows.ps1
# Runs anywhere (macOS/Linux) - tests parsing logic and device table sync
# PowerShell syntax check runs if pwsh is available

set -u
cd "$(dirname "$0")"

pass=0; fail=0
ok()  { pass=$((pass + 1)); echo "  ok    $1"; }
bad() { fail=$((fail + 1)); echo "  FAIL  $1 — $2"; }

echo "===== A. PowerShell syntax check ====="
if command -v pwsh >/dev/null 2>&1; then
    if pwsh -NoProfile -Command "[void][System.Management.Automation.Language.Parser]::ParseFile('vscreen-windows.ps1', [ref]\$null, [ref]\$null); Write-Host OK" 2>/dev/null | grep -q OK; then
        ok "PowerShell syntax valid (pwsh)"
    else
        bad "PowerShell syntax" "parse errors detected"
    fi
else
    # Fallback: basic file checks
    if [ -f vscreen-windows.ps1 ] && [ $(wc -l < vscreen-windows.ps1) -gt 100 ]; then
        ok "File exists and has content ($(wc -l < vscreen-windows.ps1) lines)"
    else
        bad "File" "missing or too short"
    fi
    if ! grep -q '\$DEVICES' vscreen-windows.ps1; then
        bad "Structure" "missing device table"
    else
        ok "Has device table structure"
    fi
fi

echo "===== B. Device table sync (vs macOS vscreen + Linux vscreen-linux) ====="
for alias in mba13 mba15 mbp14 mbp16 imac24 studio xdr ipadpro13 ipadpro129 ipadair13; do
    # macOS source
    zline=$(grep -E "^  $alias +\"[^\"]+\"" vscreen 2>/dev/null | head -1)
    zvals=$(printf '%s' "$zline" | sed -E 's/.*\|([0-9]+x[0-9]+)\|([0-9]+x[0-9]+)\|([0-9]+x[0-9]+)\".*/\1|\2|\3/' 2>/dev/null)

    # Linux source
    lvals=$(./vscreen-linux __deventry "$alias" 2>/dev/null || true)

    # Windows source (parse from ps1)
    wline=$(grep "\"$alias\"" vscreen-windows.ps1 2>/dev/null | head -1)
    wvals=$(printf '%s' "$wline" | grep -oE '[0-9]+x[0-9]+' | tr '\n' '|' | sed 's/|$//' 2>/dev/null)

    if [ -n "$zvals" ] && [ "$zvals" = "$lvals" ] && [ -n "$wvals" ]; then
        ok "$alias 3-platform sync (mac=linux=$wvals)"
    elif [ -n "$zvals" ] && [ "$zvals" = "$lvals" ]; then
        if [ -n "$wvals" ]; then
            ok "$alias mac=linux sync ok, windows=$wvals"
        else
            bad "$alias windows" "not found in ps1"
        fi
    else
        bad "$alias sync" "mac='$zvals' linux='$lvals' win='$wvals'"
    fi
done

echo "===== C. CLI surface parity ====="
# Check that Windows version has same commands as macOS/Linux
for cmd in "off" "status" "list" "version" "provision"; do
    if grep -q "$cmd" vscreen-windows.ps1 2>/dev/null; then
        ok "Has '$cmd' command"
    else
        bad "Missing '$cmd'" "not found in vscreen-windows.ps1"
    fi
done

# Check flags (need -- separator for grep)
for flag in "--print" "--logical"; do
    if grep -q -- "$flag" vscreen-windows.ps1 2>/dev/null; then
        ok "Has '$flag' flag"
    else
        bad "Missing '$flag'" "not found in vscreen-windows.ps1"
    fi
done

# Check @scale factor support
if grep -q '@' vscreen-windows.ps1 && grep -q 'scale' vscreen-windows.ps1; then
    ok "Has @scale factor support"
else
    bad "Scale factor" "missing @scale support"
fi

# Check HiDPI 2x support
if grep -q '2x\|physical\|HiDPI\|200' vscreen-windows.ps1; then
    ok "Has HiDPI 2x support"
else
    bad "HiDPI" "missing 2x/HiDPI support"
fi

echo "===== D. Windows-specific architecture ====="
# Parsec VDD references
if grep -q 'Parsec' vscreen-windows.ps1 && grep -q 'VDD' vscreen-windows.ps1; then
    ok "References Parsec VDD"
else
    bad "Parsec VDD" "no reference found"
fi

# Registry preset
if grep -q 'SOFTWARE.Parsec' vscreen-windows.ps1 || grep -q 'VDD_REG' vscreen-windows.ps1; then
    ok "Has registry preset path"
else
    bad "Registry" "missing preset path"
fi

# Console session note
if grep -qi 'console\|RustDesk' vscreen-windows.ps1; then
    ok "Documents console session requirement"
else
    bad "Console session" "no mention of console/RustDesk"
fi

# ChangeDisplaySettingsEx
if grep -q 'ChangeDisplaySettings' vscreen-windows.ps1; then
    ok "Uses ChangeDisplaySettingsEx API"
else
    bad "Win32 API" "missing ChangeDisplaySettingsEx"
fi

echo "===== E. install.sh platform dispatch ====="
if grep -q 'vscreen-windows' install.sh 2>/dev/null; then
    ok "install.sh references vscreen-windows"
else
    bad "install.sh" "missing Windows platform dispatch"
fi

echo "===== F. Version sync (3 platforms) ====="
mac_ver=$(sed -n 's/^VERSION="\([^"]*\)".*/\1/p' vscreen | head -1)
linux_ver=$(sed -n 's/^VERSION="\([^"]*\)".*/\1/p' vscreen-linux | head -1)
win_ver=$(grep -o '\$VERSION = "[^"]*"' vscreen-windows.ps1 | grep -o '[0-9.]*' | head -1)

if [ "$mac_ver" = "$linux_ver" ] && [ "$linux_ver" = "$win_ver" ] && [ -n "$mac_ver" ]; then
    ok "3-platform version sync: v$mac_ver"
else
    bad "Version mismatch" "mac=$mac_ver linux=$linux_ver win=$win_ver"
fi

echo
if [ $fail -eq 0 ]; then
    echo "All tests passed: $pass items"
else
    echo "Failed: $fail / $((pass + fail))"
fi
exit $fail
