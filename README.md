# vscreen — headless Mac virtual display, matched to your client device

**[English](README.md) · [中文](README.zh-CN.md)** · [Development guide](DEVELOPMENT.md)

One line on your headless Mac (Mac mini, etc.) creates a virtual display that
**exactly matches the Apple device you're remoting from** — so remote desktop
tools like [RustDesk](https://rustdesk.com) render a pixel-perfect, fullscreen,
black-bar-free picture.

```bash
vscreen mbp14        # remote from a MacBook Pro 14"  -> 1512x945
vscreen ipadpro13    # remote from an iPad Pro 13"   -> 1376x1032
vscreen 1470x919     # or just give a resolution directly
vscreen off          # back to physical displays only
```

`vscreen` manages **exactly one** virtual screen named `vscreen` (that name is
its identity marker). Switching devices reuses the same screen and overwrites
its resolution list — it never creates a second one, so the remote side always
sees a single display.

## Install (one line, no clone)

```bash
curl -fsSL https://raw.githubusercontent.com/lichengwu/vscreen/main/install.sh | bash
```

This checks dependencies ([BetterDisplay](https://betterdisplay.pro), `python3`),
installs the `vscreen` CLI into your PATH, and runs a verification. Later,
`vscreen update` pulls the latest version from GitHub (and skips if already latest).

> Manual alternative: `git clone https://github.com/lichengwu/vscreen.git && cd vscreen && ./install.sh`

## Quick start

```bash
vscreen list              # show supported devices + 3 resolution tiers
vscreen mbp14             # match MacBook Pro 14" (compensated, fullscreen)
vscreen mbp14-native      # native logical resolution
vscreen mbp14-full        # 1:1 native pixels
vscreen ipadpro13         # match iPad Pro 13" (full-bleed, 4:3)
vscreen mba13@125%        # scale: content 25% bigger (1470x919 -> 1176x735)
vscreen 1512x945          # set by raw WxH (HiDPI)
vscreen 1512 945          # spaces work too — no input-method switch for "x"
vscreen off               # disconnect virtual screens, restore physical
vscreen status            # current display state
vscreen update            # self-update (skips if already latest)
vscreen version | -v | --version   # print version
vscreen -h | --help       # help
```

Options: `--no-mirror` keeps extended-desktop mode (don't mirror physical screens);
`--print` previews the computed resolution without touching displays.

## Supported devices

| Alias | Device | compensated (default) | native | full (1:1) |
| --- | --- | --- | --- | --- |
| `mba13` | MacBook Air 13" | **1470x919** | 1470x956 | 2560x1664 |
| `mba15` | MacBook Air 15" | **1710x1069** | 1710x1107 | 2880x1864 |
| `mbp14` | MacBook Pro 14" | **1512x945** | 1512x982 | 3024x1964 |
| `mbp16` | MacBook Pro 16" | **1728x1080** | 1728x1117 | 3456x2234 |
| `imac24` | iMac 24" | **2240x1236** | 2240x1260 | 4480x2520 |
| `studio` | Studio Display | **2560x1416** | 2560x1440 | 5120x2880 |
| `xdr` | Pro Display XDR | **3008x1668** | 3008x1692 | 6016x3384 |
| `ipadpro13` | iPad Pro 13" | **1376x1032** | 1376x1032 | 2752x2064 |
| `ipadpro129` | iPad Pro 12.9" | **1366x1024** | 1366x1024 | 2732x2048 |
| `ipadair13` | iPad Air 13" | **1366x1024** | 1366x1024 | 2732x2048 |

Synonyms: `air13`→`mba13`, `air15`→`mba15`, `pro14`→`mbp14`, `pro16`→`mbp16`,
`imac`→`imac24`, `prodisplay`/`xdr6k`→`xdr`, `pro13`→`ipadpro13`,
`pro129`→`ipadpro129`, `ipadair`/`ipad13`→`ipadair13`.

## Why "compensated" resolutions?

macOS fullscreen reserves the menu-bar / notch area on the **client**'s screen,
so a remote viewer's effective canvas is smaller than the panel — an
aspect-preserving viewer leaves black bars. Compensated modes subtract that
reserved height:

| Mode | Math | Result |
| --- | --- | --- |
| `1512x945` (MBP 14") | 1512x982 − 37pt notched menu bar | fills fullscreen exactly |
| `1470x919` (MBA 13") | 1470x956 − 37pt notched menu bar | fills fullscreen exactly |
| `1728x1080` (MBP 16") | 1728x1117 − 37pt notched menu bar | fills fullscreen exactly |

> **iPad note:** iPadOS fullscreen is full-bleed (no persistent menu bar), so
> iPad entries have `compensated == native` — no subtraction. `-full` gives 1:1
> panel pixels.

`-native` variants use the device's factory-default logical resolution — pick those
if your viewer doesn't reserve the menu-bar area. `-full` uses 1:1 native pixels.

> **MacBook Air (M2+) note:** Airs default to a *scaled* mode, not the 2x logical
> resolution — MBA 13.6" defaults to `1470x956` (not 1280x832), MBA 15.3" to
> `1710x1107` (not 1440x932). The Air entries use the factory-default mode so the
> remote picture stays 1:1 instead of being scaled up ~15%.

## Scale factor (`@`)

Append `@<factor>` to any device or raw resolution to zoom the remote
picture while keeping the aspect ratio:

```bash
vscreen mba13@125%        # compensated / 1.25 -> 1176x735 (content 25% bigger)
vscreen mba13@80          # / 0.8 -> 1838x1149 (smaller, supersampled = sharper)
vscreen mbp14-native@1.5  # 1512x982 / 1.5 -> 1008x655
vscreen 1470 919@125      # raw WxH + factor
```

- `125%`, `1.25`, and `80` normalize identically (no `%` and value >3
  means percent); valid range **25%–400%**
- `125%` uses Windows-style semantics: the logical resolution is divided
  by 1.25 **proportionally** — the aspect ratio is preserved (rounding
  error < 0.1%)
- Input tolerance: `mba13@125%`, `mba13 @125%`, and `mba13 @ 125%` are
  all equivalent; decimal WxH values are rounded to the nearest integer
  (`1336.36x835.45` → `1336x835`)
- >100% is upscaled by the client (slightly softer); <100% is
  supersampled (sharper)
- Raw resolutions accept a space between W and H — no input-method
  switching just to type `x`
- `--print` shows the computed resolution without changing anything

## Client side (RustDesk)

- View style: **Adaptive**, fullscreen: ⌃⌘F
- Pick the virtual screen in the display selector (it's the only virtual one)

## CLI quirks handled (so you don't have to)

- **One screen, always:** the tool owns a single screen named `vscreen`; it
  reuses it and overwrites the resolution list instead of duplicating screens.
- Re-running never duplicates virtual screens or resolutions.
- BetterDisplay CLI returns `Failed` when setting the already-active resolution —
  changes are only issued when needed.
- Updating a virtual screen's resolution list can reset its active mode — it is
  read back and restored.

See the [development guide](DEVELOPMENT.md) to add your own device resolutions.

## License

[MIT](LICENSE)
