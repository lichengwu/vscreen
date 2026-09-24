# Development Guide

> User docs: [English](README.md) · [中文](README.zh-CN.md)

This guide is for anyone who wants to add a device, change behavior, or cut a
release of vscreen.

## 1. Project layout

```
vscreen         # main program (single zsh file): device table + BetterDisplay glue
install.sh      # pipe-safe one-line installer (curl | bash friendly)
test.sh         # black-box regression tests (CLI paths only, no BetterDisplay needed)
README.md       # English user docs
README.zh-CN.md # Chinese user docs
DEVELOPMENT.md  # this file
```

One zsh script, no build step. Runtime deps:
[BetterDisplay](https://betterdisplay.pro) (virtual-screen backend) and
`python3` (parses BetterDisplay JSON output).

## 2. Device → resolution table

Three tables near the top of `vscreen` (look for `# --- 设备 → 分辨率映射表 ---`):

```zsh
# format: alias="name|native|compensated|full"
typeset -A DEVICES
DEVICES=( mbp14 "MacBook Pro 14|1512x982|1512x945|3024x1964" ... )

typeset -A SYNONYMS      # alias synonyms, normalized to a main alias
SYNONYMS=( pro14 mbp14 ... )

DEVICE_ORDER=(mba13 ...)  # stable display order for `vscreen list`
```

Each device has four `|`-separated fields:

| Field | Meaning |
| --- | --- |
| name | Display name shown in BetterDisplay / macOS settings (display only) |
| **native** | the device's factory-default **logical** resolution (what macOS "looks like" by default). For most Retina Macs that's native pixels ÷ 2 — **except MacBook Air (M2+)**, which defaults to a *scaled* mode: 1470x956 (13.6") / 1710x1107 (15.3"), NOT pixels ÷ 2 |
| **compensated** | fullscreen-compensated tier = native height − client menu-bar; the default |
| **full** | 1:1 native pixels |

On apply, the `resolutionList` sent to BetterDisplay = `compensated,native,full`
(overwrite). The active tier is picked by the CLI alias: `vscreen mbp14`
→ compensated, `mbp14-native` → native, `mbp14-full` → full.

## 3. Tier semantics & compensation math

**Why compensated?** When the remote client goes fullscreen, macOS reserves
the menu-bar / notch area on the **client**'s screen, so an aspect-preserving
viewer letterboxes. Compensated subtracts that reserved height:

```
compensated = native_height − menubar
```

- Notched Macs (MBP 14/16): menubar = **37pt** (24 bar + 13 notch)
- MacBook Air (M2+): also notched — notch band is 64 physical px above the
  16:10 frame; in logical points at the default scaled mode that's ≈ **37pt**
  (13.6") / ≈ **38pt** (15.3")
- Non-notched (iMac / Studio / XDR): menubar = **24pt**
- iPad: iPadOS fullscreen is full-bleed → menubar = **0**, so `compensated == native`

### Scale factor (`@`)

Any resolution-setting argument accepts an `@<factor>` suffix:

```text
parse:  pre-join adjacent numeric args        "1512 945"      -> "1512x945"  (x is awkward in CJK IMEs)
        merge @factor into last positional     "mba13 @ 125%"  -> "mba13@125%"
        strip @factor from ARG                 mba13@125%      -> mba13 + 125
        validate / normalize                   125% / 1.25 / 80 -> 1.25  (no % and >3 means percent)
        dispatch, round decimal WxH, then scale  S_RES = round(W/k) x round(H/k)
```

- Both dimensions divide by the same k, then round-half-up — the aspect
  ratio is preserved by construction (each dimension off by ≤ 0.5 px,
  < 0.1% ratio drift). No candidate-list search is needed: virtual
  screens accept arbitrary resolutions.
- Valid range 0.25–4.0 (25%–400%); anything else dies with a usage hint.
- With a factor, `S_LIST` becomes the single scaled resolution (same as
  the raw-WxH path) — the single-screen invariant is untouched.
- `--print` prints the computed resolution and exits before any
  BetterDisplay call; `test.sh` rides on it.

## 4. Add a device (example: a 27" 5K monitor)

1. **Find the native pixels** from Apple's spec page or the vendor. Say 5120×2880.
2. **Find the factory-default "looks like" resolution** for that device. For most
   Retina Macs it's simply pixels ÷ 2, but **MacBook Airs (M2+) ship a scaled
   default** (1470x956 / 1710x1107). `native` must be the *default* mode — not
   blind pixels ÷ 2 — or the remote picture gets zoomed ~15% (that was the
   mba13/mba15 bug fixed in v1.0.1).
3. **Compute the tiers:**
   - native logical = the default "looks like" resolution, e.g. `2560x1440`
   - menubar = 24 → compensated = `2560x1416` (1440−24)
   - full = `5120x2880`
4. **Add to `DEVICES`:** `mydisp "My Display 27|2560x1440|2560x1416|5120x2880"`
5. **(Optional) synonyms** in `SYNONYMS`, e.g. `my27 mydisp`.
6. **Add to `DEVICE_ORDER`** so `vscreen list` shows it.
7. **Update user docs:** add a row to both `README.md` and `README.zh-CN.md`.
8. **Verify** (next section).

## 5. Verification

```bash
zsh -n vscreen                # syntax check
./test.sh                     # black-box regression (no display changes)
./test-linux.sh               # Linux backend regression (runs anywhere, incl. macOS)
./test-docker.sh              # full Linux suite in an ubuntu container: root paths
                              #   via fake-sysfs seams (VSCREEN_DRM_SYS/VSCREEN_PARAM),
                              #   EDID byte-parity, provision passwordless loop
./vscreen list                # new device present, tiers correct
./vscreen <your-alias>        # end-to-end: routes to apply and sets res
./vscreen <your-alias>-native
./vscreen <your-alias>-full
./vscreen status              # active tier correct
```

> Note: with BetterDisplay installed, `vscreen <alias>` **mutates the display**.
> To test only parsing without touching screens, `vscreen off` first, or run
> `list` / `--help` / `version` (no BD needed).

## 6. Single-screen design (core invariant)

- The tool owns **exactly one** virtual screen named `vscreen` — the identity
  marker. The name is fixed and never changes.
- On apply it looks up by name: reuse + overwrite `resolutionList` if found,
  else `create`.
- Switching devices = same screen, list overwritten, active tier updated —
  **never a second screen**.
- Every other virtual screen is **disconnected** (`connected=off`, not deleted),
  so the remote side always sees one display.
- Legacy "MacBook Pro"/"MacBook Air" screens from the old `mbscreens` are
  auto-disconnected (non-destructive).

Think carefully before changing this invariant: single-screen + reuse is the
core of requirement #4; breaking it makes the remote side see multiple screens.

## 7. CLI quirks already handled

- BetterDisplay CLI returns `Failed` when setting the **already-active**
  resolution → code only sets when `cur != S_RES`.
- Overwriting `resolutionList` **resets the active mode** → read back current
  and re-correct (see `get_current_res`).
- Mirror semantics: `set -tagID=X -mirror=on -targetTagID=Y` makes **X** the
  master mirror source, Y the hardware mirror.
- Functions captured by `$(...)` (list_displays / find_tag / …) must only
  return via stdout; all logging goes to stderr or it pollutes the return value.
- Numeric args are pre-joined into WxH (`"1512 945"`, decimals ok) and
  `@<factor>` tokens merge into the last positional (`"mba13 @ 125%"` →
  `mba13@125%`) — all before the flag loop, so spaces never split commands.
- `@<factor>` is stripped after the flag loop, normalized/validated up front,
  and applied to `S_RES` after dispatch; a factor is only legal on
  resolution-setting arguments (`off@125%` dies).
- **zsh quirk: inside a function `$0` is the *function name*, not the script
  path** — `mv "$tmp" "$0"` in `do_update` wrote a stray `do_update` file
  instead of updating the script (self-update never worked before v1.1.1).
  `SCRIPT_PATH="$0"` is captured at top level and used as the mv target.
- zsh flag-argument gotcha: `(s/./)` splits on `.` while `(s./.)` splits on
  `/` — the enclosure character is a delimiter, not the separator.
  `ver_newer` initially split on the wrong char and rejected every update.
- **zsh does NOT word-split unquoted `$var`** (unlike bash/sh): `for t in $tags`
  iterated once over a newline blob, silently breaking the disconnect /
  unmirror / mirror loops on any multi-display host (a single display masked
  it). All tag loops use `${(f)var}` (split on newlines); `$(cmd)` in word
  position does split, which is why `get_current_res` was always fine.
- Only **one positional argument** is accepted — a second one dies with a
  hint. Previously "last positional wins" silently dropped a leading
  `@factor` (`vscreen @125% mba13` applied 1470x919 with exit 0).

## 8. Versioning & release

### Version string

A single `VERSION="x.y.z"` constant lives near the top of `vscreen`.
`vscreen version` (or `-v` / `--version`) prints it.

### Self-update with version check

`vscreen update` downloads the latest `vscreen` from GitHub raw (10s connect
/ 30s total timeout — a stalled TLS handshake used to hang update forever),
extracts its `VERSION=` line, and compares:

- **Same version** → discard, print `已是最新版本 vX.Y.Z`, do nothing.
- **Strictly newer** (`ver_newer`: 1–4 numeric segments, zero-padded —
  `"2.0"` ≡ `"2.0.0.0"`) → replace `SCRIPT_PATH`, print `已更新 vOld -> vNew`.
- **Older / equal / uncomparable** (non-numeric segments like `1.2.0-beta`)
  → skip with its own message (fail-safe, never clobber).
- **Download failure** → fast, clean error; mv failure → clean error and
  temp cleanup.
- If `vscreen` is invoked through a symlink, update replaces the *symlink*,
  not its target (install.sh never symlinks; relevant only for manual
  setups).

`VSCREEN_RAW_URL` overrides the raw URL — the test seam `test.sh` uses to
point update at `file://` fake remotes and exercise upgrade/downgrade
behavior without touching the network.

So bumping `VERSION` and pushing to `main` is what makes `vscreen update`
actually upgrade users. No bump, no churn.

### Cutting a release

1. Bump `VERSION` in `vscreen` if it changed.
2. Commit & push to `main`.
3. Tag + release:

   ```bash
   git tag -a vX.Y.Z -m " vX.Y.Z"
   git push origin vX.Y.Z
   gh release create vX.Y.Z --generate-notes \
     --notes "Install: curl -fsSL https://raw.githubusercontent.com/lichengwu/vscreen/main/install.sh | bash"
   ```

Pushing to `main` alone is enough for `vscreen update` to work (it reads the
raw file, not the release). Tags/releases are for humans who want a pinned
version or a changelog.
