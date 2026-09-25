# vscreen — 无头 Mac / Linux / Windows 虚拟屏，匹配远程客户端设备分辨率

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Release](https://img.shields.io/github/v/release/lichengwu/vscreen?sort=semver&display_name=tag)](https://github.com/lichengwu/vscreen/releases)
[![Platform: macOS](https://img.shields.io/badge/macOS-black?logo=apple&logoColor=white)](#macos)
[![Platform: Linux](https://img.shields.io/badge/Linux-FCC624?logo=linux&logoColor=black)](#linux)
[![Platform: Windows](https://img.shields.io/badge/Windows-0078D6?logo=windows&logoColor=white)](#windows)
[![Stars](https://img.shields.io/github/stars/lichengwu/vscreen?style=social)](https://github.com/lichengwu/vscreen/stargazers)

**[English](README.md) · [中文](README.zh-CN.md)** · [开发指南](DEVELOPMENT.md) · [Releases](https://github.com/lichengwu/vscreen/releases)

一条命令创建与你手头设备**逻辑分辨率完全匹配**的虚拟显示器，
让 RustDesk 等远程桌面获得像素级 1:1、全屏无黑边的清晰画面。

**三平台，一套 CLI，一张设备表：**

| | macOS | Linux | Windows |
|---|---|---|---|
| 后端 | BetterDisplay | EDID 固件覆盖（内核） | Parsec VDD（IddCx） |
| 安装 | `curl \| bash` | `curl \| bash` | `curl \| bash`（PowerShell） |
| 切换 | 秒级 | 秒级（免重启） | 秒级（console 会话） |
| HiDPI 2x | ✅ | ✅ | ✅（per-monitor 200%） |
| 缩放 `@` | ✅ | ✅ | ✅ |
| 状态 | 稳定 | 实验性 | 实验性 |

```bash
vscreen mbp14        # 从 MacBook Pro 14 远程 → 1512x945
vscreen mba13@125%   # 内容放大 25% → 1176x735
vscreen off          # 恢复原始显示
```

## 支持的设备（全平台通用）

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

## 缩放系数（@ 后缀）—— 全平台通用

设备或 WxH 后面都可以跟 `@系数`，等比放大/缩小远程画面：

```bash
vscreen mba13@125%        # ÷1.25 → 1176x735（内容放大 25%）
vscreen mba13@80          # ÷0.8 → 1838x1149（更小更锐）
vscreen 1470 919@125      # 直接 WxH + 系数（空格分隔，不用打 x）
```

- 系数写法 `125%` / `1.25` / `80` 等价，范围 **25%–400%**
- 宽高比由构造保持（偏差 <0.1%）
- 输入宽限：`mba13@125%` = `mba13 @125%` = `mba13 @ 125%`

---

## macOS

### 环境要求

- macOS（zsh —— 系统默认 shell）
- [BetterDisplay](https://betterdisplay.pro)（`brew install --cask betterdisplay`）
- `python3`（随 Xcode 命令行工具提供）

### 安装 & 使用

```bash
curl -fsSL https://raw.githubusercontent.com/lichengwu/vscreen/main/install.sh | bash
```

```bash
vscreen list              # 查看支持的设备与三档分辨率
vscreen mbp14             # 匹配 MacBook Pro 14 ★
vscreen mba13@125%        # 缩放系数
vscreen 1512 945          # 直接分辨率（空格分隔免切输入法）
vscreen off               # 恢复
vscreen status            # 当前状态
vscreen update            # 自更新
vscreen version | -v | --version
vscreen -h | --help
```

选项：`--no-mirror` 保持扩展桌面模式；`--print` 只预览不修改。

### 工作原理

BetterDisplay 创建一块名为 "vscreen" 的虚拟屏。切换设备复用同一块屏、
覆盖分辨率列表。补偿档减去客户端菜单栏高度（刘海 37pt / 非刘海 24pt）
消除全屏黑边。HiDPI 2x 原生支持。

> **MacBook Air（M2+）**：Air 出厂默认档是"缩放档"（1470x956，非
> 1280x832）。设备表使用出厂默认分辨率避免 ~15% 缩放。

> **老款 13.3" MBA（M1）**：2560x1600、默认 1440x900、无刘海——用
> `vscreen 1440x876` 过渡。

详见 [DEVELOPMENT.md](DEVELOPMENT.md)。

---

## Linux

### 环境要求

- Linux 桌面（GNOME/KDE/X11 或 Wayland）
- `python3`（EDID 生成）
- 内核 ≥ 6.x 带 `/sys/class/drm`

### 安装 & 使用

```bash
curl -fsSL https://raw.githubusercontent.com/lichengwu/vscreen/main/install.sh | bash
```

```bash
vscreen provision           # 一次性：root 安装 + 免密规则
vscreen mba13               # 之后直接跑——免 sudo、免密码
vscreen mba13@125% --print  # 预览（免 root）
vscreen off                 # 恢复原始 EDID
```

### 工作原理

内核 **EDID 固件覆盖**：生成自定义 EDID（产品名 "vscreen"）写入显示
connector。运行时切换 = sysfs 参数 + detect + VT 循环。已在 Ubuntu
25.10 / GNOME 49 / Wayland 上实机验证。

> **限制**：GNOME 49+ 无 X11 会话。EDID 机制在 Wayland 下可用，
> xrandr 备选不可用。

详见 [docs/linux-port-design.md](docs/linux-port-design.md)。

---

## Windows

### 环境要求

- Windows 10（19041+）或 Windows 11
- PowerShell 5.1+（系统自带）
- Parsec VDD（由 `vscreen provision` 安装）

### 安装 & 使用

```powershell
# 一次性安装（任意终端，管理员）：
curl -fsSL https://raw.githubusercontent.com/lichengwu/vscreen/main/install.sh -o install.sh
bash install.sh

# provision（在 RustDesk 桌面中，管理员）：
vscreen provision           # 安装 Parsec VDD + 注册表 preset

# 日常使用（在 RustDesk 桌面 —— console 会话中）：
vscreen mba13               # 匹配客户端设备
vscreen mba13@125% --print  # 预览
vscreen off                 # 移除虚拟屏
```

### 工作原理

**Parsec VDD**（IddCx 间接显示驱动）创建虚拟显示器。自定义分辨率通过
注册表 preset（`HKLM\SOFTWARE\Parsec\vdd`，最多 5 槽）。`ChangeDisplaySettingsEx`
设置活动分辨率。HiDPI 2x 使用 2x 物理分辨率 + per-monitor 200% 缩放。

> **重要**：Windows 显示 API 仅在 **console 会话**（RustDesk 采集的那个）
> 中有效。SSH 和 RDP 会话因 Windows 会话隔离无法操作虚拟屏。
> 请始终从 **RustDesk 桌面**运行 vscreen。

详见 [docs/windows-port-design.md](docs/windows-port-design.md)。

---

## 为什么需要"补偿档"？

macOS 全屏会在**客户端**屏幕预留菜单栏/刘海区。补偿档减去该高度：

| 档位 | 计算 |
|---|---|
| `1512x945`（MBP 14） | 1512x982 − 37pt |
| `1470x919`（MBA 13） | 1470x956 − 37pt |
| `1728x1080`（MBP 16） | 1728x1117 − 37pt |

iPad 条目 `compensated == native`（iPadOS 满血全屏）。
`-native` 用出厂默认分辨率；`-full` 用 1:1 物理像素。

---

## 客户端（RustDesk）

- 显示方式：**自适应**，全屏 ⌃⌘F（macOS）/ F11（Windows/Linux）
- 在显示器选择器里选虚拟屏

---

## 参与贡献

- 问题反馈 / 功能建议：[提个 issue](https://github.com/lichengwu/vscreen/issues)
- 增加设备/档位：按 [开发指南](DEVELOPMENT.md) 操作——每个后端加一行表项
- 提交前跑全部测试：

```bash
./test.sh           # macOS（51 项断言）
./test-linux.sh     # Linux（41 项断言）
./test-windows.sh   # Windows（27 项断言）
./test-docker.sh    # Docker（15 项断言）
```

## 许可

[MIT](LICENSE)
