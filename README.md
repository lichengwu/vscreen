# vscreen — headless Mac virtual display, matched to your client device

[中文说明](#中文说明)

One line on your headless Mac (Mac mini, etc.) creates a virtual display that
**exactly matches the Apple device you're remoting from** — so remote desktop
tools like [RustDesk](https://rustdesk.com) render a pixel-perfect, fullscreen,
black-bar-free picture.

```bash
vscreen mbp14        # remote from a MacBook Pro 14"  -> 1512x945
vscreen mbp16        # remote from a MacBook Pro 16"  -> 1728x1080
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
`vscreen update` pulls the latest version from GitHub.

> Manual alternative: `git clone https://github.com/lichengwu/vscreen.git && cd vscreen && ./install.sh`

## Quick start

```bash
vscreen list              # show supported devices + 3 resolution tiers
vscreen mbp14             # match MacBook Pro 14" (compensated, fullscreen)
vscreen mbp14-native      # native logical resolution
vscreen mbp14-full        # 1:1 native pixels
vscreen 1512x945          # set by raw WxH (HiDPI)
vscreen off               # disconnect virtual screens, restore physical
vscreen status            # current display state
vscreen update            # self-update
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

Synonyms: `air13`→`mba13`, `air15`→`mba15`, `pro14`→`mbp14`, `pro16`→`mbp16`,
`imac`→`imac24`, `prodisplay`/`xdr6k`→`xdr`.

## Why "compensated" resolutions?

macOS fullscreen reserves the menu-bar / notch area, so a remote viewer's
effective canvas is smaller than the panel — an aspect-preserving viewer leaves
black bars. Compensated modes subtract that reserved height:

| Mode | Math | Result |
| --- | --- | --- |
| `1512x945` (MBP 14") | 1512x982 − 37pt notched menu bar | fills fullscreen exactly |
| `1280x808` (MBA 13") | 1280x832 − 24pt menu bar | fills fullscreen exactly |
| `1728x1080` (MBP 16") | 1728x1117 − 37pt notched menu bar | fills fullscreen exactly |

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

## License

[MIT](LICENSE)

---

# 中文说明

在无头 Mac（Mac mini 等）上一条命令创建与你手头苹果设备**逻辑分辨率完全匹配**的虚拟显示器，
让 RustDesk 等远程桌面获得像素级 1:1、全屏无黑边的清晰画面。

```bash
vscreen mbp14        # 从 MacBook Pro 14 远程 → 1512x945
vscreen mbp16        # 从 MacBook Pro 16 远程 → 1728x1080
vscreen 1280x808     # 或直接给分辨率
vscreen off          # 恢复纯物理显示
```

`vscreen` 只维护**一块**名为 `vscreen` 的虚拟屏（这个名字就是"本工具创建"的标识）。
切换设备时复用同一块屏、覆盖分辨率列表，绝不新建第二块，远程端永远只见一块屏。

## 一键安装（免 clone）

```bash
curl -fsSL https://raw.githubusercontent.com/lichengwu/vscreen/main/install.sh | bash
```

检查依赖（[BetterDisplay](https://betterdisplay.pro)、`python3`）→ 装进 PATH → 运行验证。
之后可用 `vscreen update` 自更新。

> 手动方式：`git clone https://github.com/lichengwu/vscreen.git && cd vscreen && ./install.sh`

## 快速上手

```bash
vscreen list              # 查看支持的设备与三档分辨率
vscreen mbp14             # 匹配 MacBook Pro 14（补偿档，全屏无黑边）★推荐
vscreen mbp14-native      # 原生逻辑分辨率
vscreen mbp14-full        # 1:1 物理档
vscreen 1512x945          # 直接按分辨率设置（HiDPI）
vscreen off               # 断开所有虚拟屏、解除镜像
vscreen status            # 当前显示器状态
vscreen update            # 自更新
vscreen -h | --help       # 帮助
```

选项：`--no-mirror` 保持扩展桌面模式（不镜像物理屏）。

## 支持的设备

| 别名 | 设备 | compensated（默认） | native | full(1:1) |
| --- | --- | --- | --- | --- |
| `mba13` | MacBook Air 13" | **1280x808** | 1280x832 | 2560x1664 |
| `mba15` | MacBook Air 15" | **1440x908** | 1440x932 | 2880x1864 |
| `mbp14` | MacBook Pro 14" | **1512x945** | 1512x982 | 3024x1964 |
| `mbp16` | MacBook Pro 16" | **1728x1080** | 1728x1117 | 3456x2234 |
| `imac24` | iMac 24" | **2240x1236** | 2240x1260 | 4480x2520 |
| `studio` | Studio Display | **2560x1416** | 2560x1440 | 5120x2880 |
| `xdr` | Pro Display XDR | **3008x1668** | 3008x1692 | 6016x3384 |

同义词：`air13`→`mba13`、`air15`→`mba15`、`pro14`→`mbp14`、`pro16`→`mbp16`、
`imac`→`imac24`、`prodisplay`/`xdr6k`→`xdr`。

## 为什么需要"补偿档"？

macOS 全屏预留菜单栏/刘海区，等比缩放的远程画面会留黑边；补偿档减去该预留高度：

| 档位 | 计算 | 效果 |
| --- | --- | --- |
| `1512x945`（MBP 14） | 1512x982 − 37pt 刘海菜单栏 | 严丝合缝填满全屏 |
| `1280x808`（MBA 13） | 1280x832 − 24pt 菜单栏 | 严丝合缝填满全屏 |
| `1728x1080`（MBP 16） | 1728x1117 − 37pt 刘海菜单栏 | 严丝合缝填满全屏 |

`-native` 用面板真实逻辑分辨率（你的远程端不预留菜单栏时用）；`-full` 用 1:1 原生像素。

## 客户端（RustDesk）

- 显示方式：**自适应**，全屏 ⌃⌘F
- 在显示器选择器里选那块虚拟屏（它是唯一的虚拟屏）

## CLI 替你处理的坑

- **永远一块屏：** 工具只拥有一块名为 `vscreen` 的屏，复用并覆盖分辨率列表，不重复创建。
- 重复运行不会产生重复虚拟屏或分辨率。
- BetterDisplay CLI 在设置已激活分辨率时返回 `Failed` —— 只在变化时才下发设置。
- 更新虚拟屏分辨率列表会重置活动档 —— 读回并恢复。

## 许可

[MIT](LICENSE)
