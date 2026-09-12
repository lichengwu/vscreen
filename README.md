# mbscreens — headless Mac virtual display, matched to your client device

[中文说明](#中文说明)

One command on your headless Mac (Mac mini, etc.) creates a virtual display
that **exactly matches the MacBook you're remoting from** — so remote desktop
tools like [RustDesk](https://rustdesk.com) render a pixel-perfect, fullscreen,
black-bar-free picture.

```bash
mbscreens mbp        # remote from a MacBook Pro 14"  -> 1512x945 virtual main display
mbscreens mba13      # remote from a MacBook Air 13"  -> 1280x808
mbscreens mba15      # remote from a MacBook Air 15"  -> 1440x908
mbscreens off        # back to physical displays only
mbscreens update     # self-update from GitHub
```

Selecting a device automatically:

1. **Creates / connects** the matching virtual screen (any other virtual
   screen is disconnected, so the remote side sees exactly one display)
2. **Sets the resolution** — HiDPI, including a *fullscreen-compensated* mode
3. **Makes it the main display** and mirrors physical displays onto it
   (opt out with `--no-mirror` for extended-desktop mode)

## Why "compensated" resolutions?

macOS fullscreen reserves the menu-bar / notch area, so a remote viewer's
effective canvas is smaller than the panel — an aspect-preserving viewer
leaves black bars. Compensated modes subtract that reserved height:

| Mode | Math | Result |
|---|---|---|
| `1512x945` (MBP 14") | 1512x982 − 37pt notched menu bar | fills fullscreen exactly |
| `1280x808` (MBA 13") | 1280x832 − 24pt menu bar | fills fullscreen exactly |
| `1440x908` (MBA 15") | 1440x932 − 24pt menu bar | fills fullscreen exactly |

`-native` variants (`mbscreens mbp-native`, `mba13-native`, `mba15-native`)
use the panel's true logical resolution instead — use those if your viewer
doesn't reserve the menu-bar area.

## Install

```bash
git clone https://github.com/lichengwu/macbook-screens.git
cd macbook-screens
./install.sh
```

`install.sh` checks dependencies ([BetterDisplay](https://betterdisplay.pro),
`python3`), installs the `mbscreens` CLI into your local bin, and runs a
verification. Later, `mbscreens update` pulls the latest version from GitHub.

## Client side (RustDesk)

- View style: **Adaptive**, fullscreen: ⌃⌘F
- Pick the virtual screen in the display selector (it's the only virtual one)

## CLI quirks handled (so you don't have to)

- Re-running never duplicates virtual screens or resolutions (name-based
  matching, resolution lists fully overwritten each run)
- BetterDisplay CLI returns `Failed` when setting the already-active
  resolution — changes are only issued when needed
- Updating a virtual screen's resolution list can reset its active mode —
  it is read back and restored
- Mirror semantics: `set -tagID=X -mirror=on -targetTagID=Y` makes **X** the
  master mirror source and Y the hardware mirror

## License

[MIT](LICENSE)

---

<a id="中文说明"></a>
# 中文说明

在无头 Mac（Mac mini 等）上一条命令创建与你手头 MacBook **逻辑分辨率完全匹配的虚拟显示器**，
让 RustDesk 等远程桌面获得像素级 1:1、全屏无黑边的清晰画面。

选定客户端设备后自动完成：创建/连接对应虚拟屏（断开其他虚拟屏，远程端只见一块屏）→
设置匹配分辨率（HiDPI 全屏补偿档）→ 设为主显示器并把物理屏镜像到它（`--no-mirror` 关闭）。

解决的问题：
1. **分辨率模糊** —— 无头 Mac 默认只有 1080p 虚拟显示
2. **全屏黑边** —— macOS 全屏预留菜单栏/刘海区，等比缩放的远程画面会留黑边；
   补偿档（如 1512x945 = 1512x982 − 37pt 刘海菜单栏）让画面严丝合缝

安装：

```bash
git clone https://github.com/lichengwu/macbook-screens.git
cd macbook-screens && ./install.sh
```

用法与原理详见上方英文部分。
