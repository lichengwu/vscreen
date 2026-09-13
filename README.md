# vscreen — headless Mac virtual display, matched to your client device

**[English](README.md) · [中文](README.zh-CN.md)** · [Development guide](DEVELOPMENT.md)

One line on your headless Mac (Mac mini, etc.) creates a virtual display that
**exactly matches the Apple device you're remoting from** — so remote desktop
tools like [RustDesk](https://rustdesk.com) render a pixel-perfect, fullscreen,
black-bar-free picture.

```bash
vscreen mbp14        # remote from a MacBook Pro 14"  -> 1512x945
vscreen ipadpro13    # remote from an iPad Pro 13"   -> 1376x1032
vscreen 1280x808     # or just give a resolution directly
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
vscreen 1512x945          # set by raw WxH (HiDPI)
vscreen off               # disconnect virtual screens, restore physical
vscreen status            # current display state
vscreen update            # self-update (skips if already latest)
vscreen version           # print version
vscreen -h | --help       # help
```

Options: `--no-mirror` keeps extended-desktop mode (don't mirror physical screens).

## Supported devices

| Alias | Device | compensated (default) | native | full (1:1) |
| --- | --- | --- | --- | --- |
| `mba13` | MacBook Air 13" | **1280x808** | 1280x832 | 2560x1664 |
| `mba15` | MacBook Air 15" | **1440x908** | 1440x932 | 2880x1864 |
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
| `1280x808` (MBA 13") | 1280x832 − 24pt menu bar | fills fullscreen exactly |
| `1728x1080` (MBP 16") | 1728x1117 − 37pt notched menu bar | fills fullscreen exactly |

> **iPad note:** iPadOS fullscreen is full-bleed (no persistent menu bar), so
> iPad entries have `compensated == native` — no subtraction. `-full` gives 1:1
> panel pixels.

`-native` variants use the panel's true logical resolution — pick those if your
viewer doesn't reserve the menu-bar area. `-full` uses 1:1 native pixels.

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
