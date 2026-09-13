# 开发指南 / Development Guide

**[English](#english) · [中文](#中文)**

本文档面向想给 vscreen 增改设备、改行为或发版的开发者。

---

<a id="中文"></a>

## 中文

### 1. 项目结构

```
vscreen        # 主程序（zsh 单文件），含设备表 + BetterDisplay 交互逻辑
install.sh     # pipe 安全的一键安装器（curl | bash 可用）
README.md      # 英文说明
README.zh-CN.md# 中文说明
DEVELOPMENT.md # 本文件
```

整个工具就是一个 zsh 脚本，没有构建步骤。依赖：[BetterDisplay](https://betterdisplay.pro)（虚拟屏后端）、`python3`（解析 BetterDisplay 的 JSON 输出）。

### 2. 设备 → 分辨率映射表

在 `vscreen` 里有三张表（顶部 `# --- 设备 → 分辨率映射表 ---` 段落）：

```zsh
# 格式：别名="设备名|native 逻辑|compensated 补偿|full 1:1"
typeset -A DEVICES
DEVICES=(
  mbp14     "MacBook Pro 14|1512x982|1512x945|3024x1964"
  ...
)

typeset -A SYNONYMS      # 别名同义词（归一到主别名）
SYNONYMS=( pro14 mbp14 ... )

DEVICE_ORDER=(mba13 ... )  # list 命令展示用的稳定顺序
```

每条设备四个字段，用 `|` 分隔：

| 字段 | 含义 |
| --- | --- |
| 设备名 | 显示在 BetterDisplay / macOS 显示设置里的名字（仅展示，不影响匹配） |
| **native** | 面板原生**逻辑**分辨率 = 原生像素 ÷ scale（Retina 一般 ÷2） |
| **compensated** | 全屏补偿档 = native 高度 − 客户端菜单栏预留；这是默认档 |
| **full** | 1:1 原生像素档 |

apply 时，传给 BetterDisplay 的 `resolutionList` = `compensated,native,full`（覆盖式），
活动档由 CLI 别名决定：`vscreen mbp14`→compensated，`-native`→native，`-full`→full。

### 3. 三档语义与补偿计算

**为什么有 compensated？** 远程客户端全屏时，macOS 在客户端屏幕预留菜单栏/刘海区，
等比缩放的远程画面会留黑边。补偿档减去这个预留高度，让画面严丝合缝：

```
compensated = native_height − menubar
```

- 刘海机型（MacBook Pro 14/16）：menubar = **37pt**（24 菜单栏 + 13 刘海）
- 普通机型（MacBook Air / iMac / Studio / XDR）：menubar = **24pt**
- iPad：iPadOS 全屏满血无菜单栏 → menubar = **0**，故 `compensated == native`

### 4. 如何新增一台设备（示例：加一台 27" 5K 显示器）

1. **查分辨率**：从 Apple 官方规格页或厂商手册拿到原生像素。假设 5120×2880。
2. **算三档**：
   - native 逻辑 = 5120÷2 × 2880÷2 = `2560x1440`
   - menubar = 24（普通显示器）→ compensated = `2560x1416`（1440−24）
   - full = `5120x2880`
3. **加进 DEVICES**：

   ```zsh
   mydisp  "My Display 27|2560x1440|2560x1416|5120x2880"
   ```

4. **（可选）加同义词**到 `SYNONYMS`，如 `my27 mydisp`。
5. **加进 `DEVICE_ORDER`** 让 `vscreen list` 展示。
6. **更新文档**：`README.md` 和 `README.zh-CN.md` 的设备表各加一行。
7. **验证**（见下节）。

### 5. 验证流程

```bash
zsh -n vscreen                      # 语法检查
./vscreen list                      # 看新设备是否在表里、三档对不对
./vscreen <你的别名>                 # 端到端：应路由到 apply 并设分辨率
./vscreen <你的别名>-native          # native 档
./vscreen <你的别名>-full            # full 档
./vscreen status                    # 看活动档是否正确
```

> 注意：本机装了 BetterDisplay 时，`vscreen <别名>` 会**真实改屏**。只想验解析路径
> 又不想动屏，可临时 `BD=/bin/echo ./vscreen <别名>`（do_apply 会停在 ensure_bd 之前
> 的解析阶段——但 status/off 仍会调 BD，慎用）。最稳是先 `vscreen off` 再测。

### 6. 单虚拟屏设计（核心不变量）

- 工具**永远只拥有一块**名为 `vscreen` 的虚拟屏。这个名字是身份标识，固定不变。
- apply 时按名查找：找到就**复用**并整体覆盖 `resolutionList`；没找到才 `create`。
- 切换设备 = 同一块屏、列表覆盖、活动档更新，**绝不新建第二块**。
- 每次把除 `vscreen` 外的虚拟屏**断开**（connected=off，非删除），远程端只见一块。
- 旧版遗留的 "MacBook Pro"/"MacBook Air" 屏会被自动断开（非破坏性）。

改这个不变量前想清楚：单屏 + 复用是需求第 4 条的核心，破坏它会让远程端看到多块屏。

### 7. CLI 已替你处理的坑（改逻辑时别踩）

- BetterDisplay CLI 在设置**已激活**分辨率时返回 `Failed` → 代码只在 `cur != S_RES` 时才下发。
- 覆盖 `resolutionList` 会**重置活动档** → 设列表后读回当前档再校正（见 `get_current_res`）。
- 镜像语义：`set -tagID=X -mirror=on -targetTagID=Y` 让 **X** 当主镜像源、Y 当硬件镜像。
- 被命令替换 `$(...)` 捕获的函数（list_displays/find_tag 等）只能向 stdout 输出返回值，
  所有日志一律走 stderr，否则会污染返回值。

### 8. 发布与一键安装

- 仓库：`github.com/lichengwu/vscreen`，默认分支 `main`。
- 一键安装走 GitHub raw：

  ```
  curl -fsSL https://raw.githubusercontent.com/lichengwu/vscreen/main/install.sh | bash
  ```

- `vscreen update` 从同一 raw URL 拉新版本覆盖 `$0`。
- 改了脚本直接 push 到 `main` 即可生效（无构建/打包）。如要版本化可打 git tag。

---

<a id="english"></a>

## English

### 1. Project layout

```
vscreen        # main program (single zsh file): device table + BetterDisplay glue
install.sh     # pipe-safe one-line installer (curl | bash friendly)
README.md      # English docs
README.zh-CN.md# Chinese docs
DEVELOPMENT.md # this file
```

One zsh script, no build step. Depends on [BetterDisplay](https://betterdisplay.pro)
(virtual-screen backend) and `python3` (parses BetterDisplay JSON output).

### 2. Device → resolution table

Three tables near the top of `vscreen` (`# --- 设备 → 分辨率映射表 ---`):

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
(overwrite). The active tier is picked by the CLI alias: `vscreen mbp14`→compensated,
`-native`→native, `--full`→full.

### 3. Tier semantics & compensation math

**Why compensated?** When the remote client goes fullscreen, macOS reserves the
menu-bar / notch area on the **client**'s screen, so an aspect-preserving viewer
letterboxes. Compensated subtracts that reserved height:

```
compensated = native_height − menubar
```

- Notched Macs (MBP 14/16): menubar = **37pt** (24 bar + 13 notch)
- Non-notched (MBA / iMac / Studio / XDR): menubar = **24pt**
- iPad: iPadOS fullscreen is full-bleed → menubar = **0**, so `compensated == native`

### 4. Add a device (example: a 27" 5K monitor)

1. **Find the native pixels** from Apple's spec page or the vendor. Say 5120×2880.
2. **Compute the tiers:**
   - native logical = 5120÷2 × 2880÷2 = `2560x1440`
   - menubar = 24 → compensated = `2560x1416` (1440−24)
   - full = `5120x2880`
3. **Add to `DEVICES`:** `mydisp "My Display 27|2560x1440|2560x1416|5120x2880"`
4. **(Optional) synonyms** in `SYNONYMS`, e.g. `my27 mydisp`.
5. **Add to `DEVICE_ORDER`** so `vscreen list` shows it.
6. **Update docs:** add a row to both `README.md` and `README.zh-CN.md`.
7. **Verify** (next section).

### 5. Verification

```bash
zsh -n vscreen                      # syntax check
./vscreen list                      # new device present, tiers correct
./vscreen <your-alias>              # end-to-end: routes to apply and sets res
./vscreen <your-alias>-native
./vscreen <your-alias>-full
./vscreen status                    # active tier correct
```

> Note: with BetterDisplay installed, `vscreen <alias>` **mutates the display**.
> To test only parsing without touching screens, `vscreen off` first, or run
> `list`/`--help` (no BD needed).

### 6. Single-screen design (core invariant)

- The tool owns **exactly one** virtual screen named `vscreen` — the identity marker.
- On apply it looks up by name: reuse + overwrite `resolutionList` if found, else `create`.
- Switching devices = same screen, list overwritten, active tier updated — **never a second screen**.
- Every other virtual screen is **disconnected** (connected=off, not deleted).
- Legacy "MacBook Pro"/"MacBook Air" screens from the old `mbscreens` are auto-disconnected.

### 7. CLI quirks already handled

- BetterDisplay CLI returns `Failed` when setting the **already-active** resolution → code only sets when `cur != S_RES`.
- Overwriting `resolutionList` **resets the active mode** → read back current and re-correct (see `get_current_res`).
- Mirror semantics: `set -tagID=X -mirror=on -targetTagID=Y` makes **X** the master mirror source, Y the hardware mirror.
- Functions captured by `$(...)` (list_displays/find_tag/…) must only return via stdout;
  all logging goes to stderr or it pollutes the return value.

### 8. Release & one-line install

- Repo: `github.com/lichengwu/vscreen`, default branch `main`.
- One-line install via GitHub raw:

  ```
  curl -fsSL https://raw.githubusercontent.com/lichengwu/vscreen/main/install.sh | bash
  ```

- `vscreen update` pulls the same raw URL and overwrites `$0`.
- Pushing to `main` is live immediately (no build/packaging). Use git tags for versioning.
