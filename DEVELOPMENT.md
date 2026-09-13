# Development Guide

> User docs: [English](README.md) · [中文](README.zh-CN.md)

This guide is for anyone who wants to add a device, change behavior, or cut a
release of vscreen.

## 1. Project layout

```
vscreen         # main program (single zsh file): device table + BetterDisplay glue
install.sh      # pipe-safe one-line installer (curl | bash friendly)
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
| **native** | panel's native **logical** resolution = native pixels ÷ scale (Retina usually ÷2) |
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
- Non-notched (MacBook Air / iMac / Studio / XDR): menubar = **24pt**
- iPad: iPadOS fullscreen is full-bleed → menubar = **0**, so `compensated == native`

## 4. Add a device (example: a 27" 5K monitor)

1. **Find the native pixels** from Apple's spec page or the vendor. Say 5120×2880.
2. **Compute the tiers:**
   - native logical = 5120÷2 × 2880÷2 = `2560x1440`
   - menubar = 24 → compensated = `2560x1416` (1440−24)
   - full = `5120x2880`
3. **Add to `DEVICES`:** `mydisp "My Display 27|2560x1440|2560x1416|5120x2880"`
4. **(Optional) synonyms** in `SYNONYMS`, e.g. `my27 mydisp`.
5. **Add to `DEVICE_ORDER`** so `vscreen list` shows it.
6. **Update user docs:** add a row to both `README.md` and `README.zh-CN.md`.
7. **Verify** (next section).

## 5. Verification

```bash
zsh -n vscreen                # syntax check
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

## 8. Versioning & release

### Version string

A single `VERSION="x.y.z"` constant lives near the top of `vscreen`.
`vscreen version` (or `-v` / `--version`) prints it.

### Self-update with version check

`vscreen update` downloads the latest `vscreen` from GitHub raw, extracts its
`VERSION=` line, and compares to the running copy:

- **Same version** → discard the download, print `已是最新版本 vX.Y.Z`, do nothing.
- **Newer version** → install over `$0`, print `已更新 vOld -> vNew`.
- **Cannot parse remote version** → skip (fail-safe, never clobber with an
  unknown payload).

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
