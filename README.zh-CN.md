# vscreen — 无头 Mac 虚拟屏，匹配远程客户端设备

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Release](https://img.shields.io/github/v/release/lichengwu/vscreen?sort=semver&display_name=tag)](https://github.com/lichengwu/vscreen/releases)
[![Platform: macOS](https://img.shields.io/badge/Platform-macOS-black?logo=apple&logoColor=white)](#环境要求)
[![Shell: zsh](https://img.shields.io/badge/Shell-zsh-89e051)](https://www.zsh.org/)
[![Stars](https://img.shields.io/github/stars/lichengwu/vscreen?style=social)](https://github.com/lichengwu/vscreen/stargazers)

**[English](README.md) · [中文](README.zh-CN.md)** · [开发指南](DEVELOPMENT.md) · [Releases](https://github.com/lichengwu/vscreen/releases)

在无头 Mac（Mac mini 等）上一条命令创建与你手头苹果设备**逻辑分辨率完全匹配**的虚拟显示器，
让 RustDesk 等远程桌面获得像素级 1:1、全屏无黑边的清晰画面。

```bash
vscreen mbp14        # 从 MacBook Pro 14 远程 → 1512x945
vscreen ipadpro13    # 从 iPad Pro 13 远程 → 1376x1032
vscreen 1470x919     # 或直接给分辨率
vscreen off          # 恢复纯物理显示
```

`vscreen` 只维护**一块**名为 `vscreen` 的虚拟屏（这个名字就是"本工具创建"的标识）。
切换设备时复用同一块屏、覆盖分辨率列表，绝不新建第二块，远程端永远只见一块屏。

## 环境要求

- macOS（zsh —— 系统默认 shell）
- [BetterDisplay](https://betterdisplay.pro)：虚拟屏后端（`brew install --cask betterdisplay`）
- `python3`：随 Xcode 命令行工具提供（`xcode-select --install`）

运行 `vscreen` 之前不会创建任何虚拟屏；除 PATH 里一个脚本外不装任何东西。

## 一键安装（免 clone）

```bash
curl -fsSL https://raw.githubusercontent.com/lichengwu/vscreen/main/install.sh | bash
```

检查依赖（[BetterDisplay](https://betterdisplay.pro)、`python3`）→ 装进 PATH → 运行验证。
之后可用 `vscreen update` 自更新（已是最新则跳过）。

> 手动方式：`git clone https://github.com/lichengwu/vscreen.git && cd vscreen && ./install.sh`

## 快速上手

```bash
vscreen list              # 查看支持的设备与三档分辨率
vscreen mbp14             # 匹配 MacBook Pro 14（补偿档，全屏无黑边）★推荐
vscreen mbp14-native      # 原生逻辑分辨率
vscreen mbp14-full        # 1:1 物理档
vscreen ipadpro13         # 匹配 iPad Pro 13（满血 4:3）
vscreen mba13@125%        # 缩放：内容放大 25%（1470x919 → 1176x735）
vscreen 1512x945          # 直接按分辨率设置（HiDPI）
vscreen 1512 945          # 空格分隔，等价 1512x945（免切输入法）
vscreen off               # 断开所有虚拟屏、解除镜像
vscreen status            # 当前显示器状态
vscreen update            # 自更新（已是最新则跳过）
vscreen version | -v | --version    # 查看版本号
vscreen -h | --help       # 帮助
```

选项：`--no-mirror` 保持扩展桌面模式（不镜像物理屏）；`--print` 只预览换算结果、不修改显示器。

## 支持的设备

| 别名 | 设备 | compensated（默认） | native | full(1:1) |
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

同义词：`air13`→`mba13`、`air15`→`mba15`、`pro14`→`mbp14`、`pro16`→`mbp16`、
`imac`→`imac24`、`prodisplay`/`xdr6k`→`xdr`、`pro13`→`ipadpro13`、
`pro129`→`ipadpro129`、`ipadair`/`ipad13`→`ipadair13`。

> **老款 13.3" MacBook Air（M1，2020）说明：** 面板不同——2560x1600、出厂默认
> 1440x900、无刘海——暂未入表。可先用 `vscreen 1440x876`（补偿档）或
> `vscreen 1440x900`（原生档）。

## 为什么需要"补偿档"？

macOS 全屏会在**客户端**屏幕预留菜单栏/刘海区，等比缩放的远程画面会留黑边；
补偿档减去该预留高度：

| 档位 | 计算 | 效果 |
| --- | --- | --- |
| `1512x945`（MBP 14） | 1512x982 − 37pt 刘海菜单栏 | 严丝合缝填满全屏 |
| `1470x919`（MBA 13） | 1470x956 − 37pt 刘海菜单栏 | 严丝合缝填满全屏 |
| `1728x1080`（MBP 16） | 1728x1117 − 37pt 刘海菜单栏 | 严丝合缝填满全屏 |

> **iPad 说明：** iPadOS 全屏满血无菜单栏，故 iPad 条目 `compensated == native`（不减）。
> `-full` 给 1:1 面板像素。

`-native` 用设备出厂默认逻辑分辨率（你的远程端不预留菜单栏时用）；`-full` 用 1:1 原生像素。

> **MacBook Air（M2+）注意：** Air 出厂默认档是“缩放档”，不是 2x 逻辑分辨率——
> MBA 13.6" 默认 `1470x956`（非 1280x832），MBA 15.3" 默认 `1710x1107`（非 1440x932）。
> 所以 Air 条目的 `native` 采用出厂默认档，远程画面才能 1:1 不缩放。

## 缩放系数（@ 后缀）

设备或 WxH 后面都可以跟 `@系数`，等比放大/缩小远程画面：

```bash
vscreen mba13@125%        # 补偿档 ÷1.25 → 1176x735（内容放大 25%）
vscreen mba13@80          # ÷0.8 → 1838x1149（内容更小，超采样更锐）
vscreen mbp14-native@1.5  # 1512x982 ÷1.5 → 1008x655
vscreen 1470 919@125      # 直接 WxH + 系数
```

- 系数写法 `125%` / `1.25` / `80` 等价（无 `%` 且数值 >3 时按百分数），范围 **25%–400%**
- `125%` 是 Windows 式“内容放大”：逻辑分辨率**等比 ÷1.25**，宽高比不变（常规分辨率下取整误差 <0.1%）
- 输入宽限：`mba13@125%`、`mba13 @125%`、`mba13 @ 125%` 等价；WxH 带小数自动就近取整（`1336.36x835.45` → `1336x835`）
- >100% 客户端上采样（画面略软），<100% 超采样（更锐）
- 直接分辨率时 `W H` 空格分隔等价 `WxH`——不用切输入法打 `x`
- `--print` 只打印换算结果，不修改显示器（试系数神器）

## 客户端（RustDesk）

- 显示方式：**自适应**，全屏 ⌃⌘F
- 在显示器选择器里选那块虚拟屏（它是唯一的虚拟屏）

## CLI 替你处理的坑

- **永远一块屏：** 工具只拥有一块名为 `vscreen` 的屏，复用并覆盖分辨率列表，不重复创建。
- 重复运行不会产生重复虚拟屏或分辨率。
- BetterDisplay CLI 在设置已激活分辨率时返回 `Failed` —— 只在变化时才下发设置。
- 更新虚拟屏分辨率列表会重置活动档 —— 读回并恢复。

要适配自己的设备分辨率，看 [开发指南](DEVELOPMENT.md)。

## Linux（实验性）

同一套 CLI（设备档位 / @缩放 / 宽限输入 / --print）已支持 Linux 桌面——基于
内核 **EDID 固件覆盖**机制，已在 Ubuntu 25.10 / GNOME 49 / Wayland 上实机验证；
运行时切换（免重启），需要 sudo。机制、实验数据与兼容性矩阵见
[docs/linux-port-design.md](docs/linux-port-design.md)。

```bash
vscreen provision           # 一次性授权：root 安装 + 免密规则（只输一次密码）
vscreen mba13               # 之后直接跑——免 sudo、免密码
vscreen mba13@125% --print  # 预览换算（免 root）
vscreen off                 # 恢复显示器原始 EDID
```

## 参与贡献

- 问题反馈 / 功能建议：[提个 issue](https://github.com/lichengwu/vscreen/issues)
- 增加设备/档位：按 [开发指南](DEVELOPMENT.md) 操作——就是加一行表项
- 提交前请跑 `./test.sh`（50 项黑盒断言，不改显示器、不依赖 BetterDisplay）

## 许可

[MIT](LICENSE)
