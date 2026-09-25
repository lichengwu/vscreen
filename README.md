# vscreen — Match remote client device resolution on macOS, Linux & Windows

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Release](https://img.shields.io/github/v/release/lichengwu/vscreen?sort=semver&display_name=tag)](https://github.com/lichengwu/vscreen/releases)
[![Platform: macOS](https://img.shields.io/badge/macOS-black?logo=apple&logoColor=white)](#macos)
[![Platform: Linux](https://img.shields.io/badge/Linux-FCC624?logo=linux&logoColor=black)](#linux)
[![Platform: Windows](https://img.shields.io/badge/Windows-0078D6?logo=windows&logoColor=white)](#windows)
[![Stars](https://img.shields.io/github/stars/lichengwu/vscreen?style=social)](https://github.com/lichengwu/vscreen/stargazers)

**[English](README.md) · [中文](README.zh-CN.md)** · [Development guide](DEVELOPMENT.md) · [Releases](https://github.com/lichengwu/vscreen/releases)

One command creates a virtual display that **exactly matches the device
you're remoting from** — so remote desktop tools like [RustDesk](https://rustdesk.com)
render a pixel-perfect, fullscreen, black-bar-free picture.

**Three platforms, one CLI, one device table:**

| | macOS | Linux | Windows |
|---|---|---|---|
| Backend | BetterDisplay | EDID firmware (kernel) | Parsec VDD (IddCx) |
| Install | `curl \| bash` | `curl \| bash` | `curl \| bash` (PowerShell) |
| Switch | seconds | seconds (no reboot) | seconds (console session) |
| HiDPI 2x | ✅ | ✅ | ✅ (per-monitor 200%) |
| Scale `@` | ✅ | ✅ | ✅ |
| Status | stable | experimental | experimental |

```bash
vscreen mbp14        # remote from MacBook Pro 14"  -> 1512x945
vscreen mba13@125%   # content 25% bigger           -> 1176x735
vscreen off          # restore original display
```

## Supported devices (all platforms)

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

## Scale factor (`@`) — all platforms

Append `@<factor>` to any device or resolution to zoom proportionally:

```bash
vscreen mba13@125%        # / 1.25 -> 1176x735 (content 25% bigger)
vscreen mba13@80          # / 0.8  -> 1838x1149 (sharper)
vscreen 1470 919@125      # raw WxH + factor (space-separated, no "x" needed)
```

- `125%`, `1.25`, `80` normalize identically; range **25%–400%**
- Aspect ratio preserved by construction (< 0.1% drift)
- Input tolerance: `mba13@125%` = `mba13 @125%` = `mba13 @ 125%`

---

## macOS

### Requirements

- macOS (zsh — default shell)
- [BetterDisplay](https://betterdisplay.pro) (`brew install --cask betterdisplay`)
- `python3` (Xcode Command Line Tools)

### Install

```bash
curl -fsSL https://raw.githubusercontent.com/lichengwu/vscreen/main/install.sh | bash
```

This auto-installs missing dependencies (Homebrew → BetterDisplay →
python3) and places the `vscreen` CLI into your PATH.

### Usage

Options: `--no-mirror` (extended desktop), `--print` (preview only).

### How it works

BetterDisplay creates one virtual screen named `vscreen`. Switching devices
reuses the same screen and overwrites its resolution list. Compensated modes
subtract the client's menu-bar height (37pt notched / 24pt non-notched) for
black-bar-free fullscreen. HiDPI 2x is native (backing store doubled).

> **MacBook Air (M2+)**: Airs default to a *scaled* mode (1470x956, not
> 1280x832). The device table uses factory-default resolutions to avoid
> a ~15% zoom.

> **Older 13.3" MBA (M1)**: 2560x1600, default 1440x900, no notch — use
> `vscreen 1440x876` meanwhile.

See [DEVELOPMENT.md](DEVELOPMENT.md) for the full macOS architecture.

---

## Linux

### Requirements

- Linux desktop (GNOME/KDE/X11 or Wayland)
- `python3` (for EDID generation)
- Kernel ≥ 6.x with `/sys/class/drm`

### Install

```bash
curl -fsSL https://raw.githubusercontent.com/lichengwu/vscreen/main/install.sh | bash
```

This auto-installs missing dependencies (python3 via apt/dnf/pacman)
and places the `vscreen` CLI into your PATH.

### Usage

```bash
vscreen provision           # one-time: root install + passwordless rule
vscreen mba13               # afterwards — no sudo, no password
vscreen mba13@125% --print  # preview (no root needed)
vscreen off                 # restore original EDID
```

### How it works

Kernel **EDID-firmware override**: generates a custom EDID (product name
"vscreen") and writes it to the display connector via sysfs. Switching at
runtime requires `detect` + VT cycle. Validated live on Ubuntu 25.10 /
GNOME 49 / Wayland.

> **Limitation**: On GNOME Wayland (GNOME 49+), X11 session is no longer
> available. The EDID mechanism works on Wayland but the xrandr fallback
> does not.

See [docs/linux-port-design.md](docs/linux-port-design.md) for the full
architecture, validation data, and compatibility matrix.

---

## Windows

### Requirements

- Windows 10 (19041+) or Windows 11
- PowerShell 5.1+ (pre-installed)
- [Parsec VDD](https://github.com/nomi-san/parsec-vdd) (installed via `vscreen provision`)

### Install

```powershell
# One-liner (from PowerShell):
iwr https://raw.githubusercontent.com/lichengwu/vscreen/main/install.ps1 -OutFile install.ps1
powershell -ExecutionPolicy Bypass -File install.ps1
```

This auto-installs Parsec VDD driver (if missing) and registry presets
(requires admin for the driver, works without admin for the CLI).

### Usage

```powershell
# Provision (one-time, from RustDesk desktop as Administrator):
vscreen provision           # installs Parsec VDD + registry presets

# Daily usage (from RustDesk desktop — console session):
vscreen mba13               # match client device
vscreen mba13@125% --print  # preview
vscreen off                 # remove virtual display
```

### How it works

**Parsec VDD** (IddCx indirect display driver) creates virtual displays.
Custom resolutions are defined via registry presets
(`HKLM\SOFTWARE\Parsec\vdd`, up to 5 slots). `ChangeDisplaySettingsEx`
sets the active resolution. HiDPI 2x uses 2x physical resolution +
per-monitor 200% DPI scaling.

> **Critical**: Windows display APIs only work in the **console session**
> (where RustDesk captures). SSH and RDP sessions cannot see or modify
> virtual displays due to Windows session isolation.
> Always run vscreen from the **RustDesk desktop**.

See [docs/windows-port-design.md](docs/windows-port-design.md) for the full
architecture, validation data, and session-isolation analysis.

---

## Why "compensated" resolutions?

macOS fullscreen reserves the menu-bar / notch area on the **client**'s screen.
Compensated modes subtract that height for black-bar-free fullscreen:

| Mode | Math |
|---|---|
| `1512x945` (MBP 14") | 1512x982 − 37pt |
| `1470x919` (MBA 13") | 1470x956 − 37pt |
| `1728x1080` (MBP 16") | 1728x1117 − 37pt |

iPad entries have `compensated == native` (iPadOS is full-bleed).
`-native` uses factory-default resolution; `-full` uses 1:1 pixels.

---

## Client side (RustDesk)

- View style: **Adaptive**, fullscreen: ⌃⌘F (macOS) / F11 (Windows/Linux)
- Pick the virtual screen in the display selector

---

## Contributing

- Bugs & feature requests: [open an issue](https://github.com/lichengwu/vscreen/issues)
- Add a device or a tier: follow [DEVELOPMENT.md](DEVELOPMENT.md) — it's a
  one-line table entry in each backend
- Run all tests before submitting:

```bash
./test.sh           # macOS (51 assertions)
./test-linux.sh     # Linux  (41 assertions)
./test-windows.sh   # Windows (27 assertions)
./test-docker.sh    # Docker (15 assertions)
```

## License

[MIT](LICENSE)
