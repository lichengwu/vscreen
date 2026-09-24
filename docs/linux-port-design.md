# vscreen Linux 移植设计（linux-port-design）

> 状态：**设计定稿 + 实机验证完成**（2026-09-24，Ubuntu 25.10 VM）；阶段 1 实现进行中。
> 前置调研见本文 §2；实验原始数据见 §3。macOS 主程序（`vscreen`）不受本设计影响。

## 1. 目标

在 Linux 桌面（首发 Ubuntu/GNOME）上提供与 macOS 版一致的体验：一条命令把**当前桌面
的唯一显示器**重塑为远程客户端匹配的分辨率（设备档位 / 补偿档 / @缩放 / HiDPI 2x），
`vscreen off` 恢复原状。远程端（RustDesk）看到名为 **"vscreen"** 的显示器。

## 2. 调研结论（决定架构的三个事实）

1. **X11 桌面会话正在消亡**：GNOME 49（Ubuntu 25.10+）已移除 X11 session
   （实测 `/usr/share/xsessions/` 不存在）；26.04 LTS 也将 Wayland-only。
   → 以 xrandr 为核心的方案只覆盖 ≤24.04 / 非 GNOME 桌面（legacy）。
2. **GNOME Wayland 无用户态自定义分辨率 API**（mutter 不支持 addmode；GNOME
   Discourse/SuperUser 多方证实）。→ 一切"普通"路径无效。
3. Linux 侧无 BetterDisplay 等价物，但积木齐全：EVDI（内核虚拟显示，需源码编译）、
   vkms（内核自带但 6.17 无 configfs/EDID）、dummy driver（apt，软渲染）、
   假 HDMI 塞子（硬件）、**EDID 固件覆盖（内核原生机制）**。

## 3. 实机验证矩阵（Ubuntu 25.10 / GNOME 49 / 内核 6.17 / QEMU bochs，128MB VRAM）

| 实验 | 结果 | 关键证据 |
| --- | --- | --- |
| 自制 128B EDID（含 "vscreen" 产品名）被内核+mutter 接受 | ✅ | DisplayConfig 出现 `VSC / vscreen`，物理尺寸 310x190mm 全对 |
| **运行时免重启切换**（sysfs 参数 → detect → VT 循环） | ✅ | 主屏秒切 1470x919；`chvt 3 && chvt 2` 让 mutter 全量重探 |
| 开机参数路线（`drm.edid_firmware=`） | ✅ | kexec 带参启动即生效 |
| **HiDPI 2x**（2940x1838 @ 240DPI） | ✅ | mutter **自动 scale 2.0**，`[1.0, 2.0]`，模式通过（需 >21.6MB VRAM） |
| 档位运行时互切 | ✅ | 2940x1838 ↔ 1470x919，逻辑分辨率不变时桌面零扰动 |
| vkms 喂 EDID | ❌ | vkms connector 不走 EDID 读取路径（固定 DMT 模式表）；configfs 6.17 未合并；无 bind/unbind；模块被 mutter/logind 占用 |
| XWayland 上任何 RandR 写操作 | ❌ | addmode/切模式/scale 全被拒（BadMatch/BadAccess），连已有模式都切不了 |
| 假塞子 + xrandr 加模式（NVIDIA） | ❌（引申） | NVIDIA 专有驱动连已连接 output 都拒绝 addmode（AskUbuntu/Launchpad 实锤）→ NVIDIA 走 EDID 固件路线同可行 |
| 副作用发现 | ⚠️ | 参数设置后**不匹配的 connector 会被抑制 EDID**（bochs 曾因此丢 QEMU EDID）→ 匹配必须精确、off 必须清参数 |

插曲：实验中一次整机失联，journal 取证证明实验命令**从未执行**（无任何 sudo 记录），
为宿主侧/自发性故障，与本方案无关。

## 4. 定稿机制（已验证）

```bash
# 一次性 provision（root）
sudo mkdir -p /lib/firmware/edid          # + vscreen 生成的 EDID bin

# 每次切换（root，秒级，免重启）
echo "<conn>:edid/vscreen-<WxH>.bin" > /sys/module/drm/parameters/edid_firmware
echo detect > /sys/class/drm/<card>-<conn>/status        # 内核重读 EDID → override 生效
chvt 3 && chvt 2                                          # mutter 全量重探（真机 HPD 或可免）

# off（恢复显示器原始 EDID）
echo "" > /sys/module/drm/parameters/edid_firmware
echo detect > .../status && chvt 3 && chvt 2
```

- **身份标识**：EDID 产品名 `vscreen`（mutter/RustDesk 显示器名）——单屏不变式锚点。
- **HiDPI 2x**：物理档（W×2, H×2）+ 相同物理尺寸（mm）→ 240 DPI → mutter 自动建议
  scale 2 → 逻辑分辨率 ÷2、采集为 2x 物理帧——与 macOS HiDPI 语义等价。
- **connector 选择**：优先 `connected` 且 `edid` 非空且 `enabled` 的（自动排除 vkms 等
  无 EDID 虚拟卡）；名称取 sysfs 目录（`card0-Virtual-1` → `Virtual-1`）。
- **VT 兜底**：`detect` 不触发 mutter 重读（QEMU 无 HPD 中断）；真机 GPU 的真实热插拔
  事件应可免 VT 循环（待真机验证）。
- **已知限制**：QEMU std-vga 需 ≥32MB VRAM 才能开 2x 档；参数须精确匹配 connector 名。

## 5. 架构（阶段 1 实现）

```text
vscreen            # macOS 后端（zsh，已发布 6 个版本，不动）
vscreen-linux      # Linux 后端（bash，无 bash4 依赖：declare -A 等一律不用）
tools/gen_edid.py  # EDID 生成器 CLI（vscreen-linux 内嵌同源 python 代码）
test-linux.sh      # Linux 侧回归：设备表同步 / EDID 校验 / CLI 解析（--print 路径，免 root）
install.sh         # 平台探测：macOS 装 vscreen，Linux 装 vscreen-linux（命令名同为 vscreen）
```

- **CLI 表面与 macOS 完全一致**：设备别名[@系数] / -native / -full / WxH（x/X/空格）/ 
  空格 @ / 小数 / off / status / list / version / update / --print / -h。
- **设备表**：阶段 1 各自内嵌（macOS 版不动），`test-linux.sh` 做**双向同步断言**防漂移。
- **root 语义**：切换/off/update 需要 root；非 root 时脚本自动 `sudo` 重执行。
  `vscreen provision`（一次性）：root 安装到 /usr/local/bin（root 属主）+ 经 visudo
  校验的限定路径免密规则 + 清理 PATH 遮蔽副本 → 之后 `vscreen mba13` 免 sudo
  免密直跑。免密规则由 provision 生成、只指向 root 属主路径（用户可写文件
  配 NOPASSWD 等于送 root，构造上即不存在）。`--print` / `list` / `version` /
  `status`（只读）免 root。EDID 生成内嵌 python3（两平台共有依赖）。
- X11 会话（≤24.04）下同一 EDID 机制亦可用（内核层与 compositor 无关）；纯 xrandr
  后端列为阶段 2。

## 6. 兼容性矩阵（最终）

| 环境 | 支持路径 | 状态 |
| --- | --- | --- |
| Ubuntu 25.10+ / GNOME Wayland | EDID 固件覆盖 | ✅ 已实机验证（阶段 1） |
| Ubuntu ≤24.04 / GNOME（X11 或 Wayland） | 同上（EDID 机制会话无关） | 理论 ✓ 待验证 |
| Intel/AMD 真机 GPU | 同上 + 真实 HPD（VT 或可免） | 待真机验证 |
| NVIDIA 专有 | 同上（EDID 路线是 NVIDIA 唯一可行软件路径） | 待真机验证 |
| wlroots（sway/Hyprland 等） | 原生虚拟 output + wlr-randr | 阶段 3 |
| KDE Wayland | kscreen-doctor 能力待调研 | 阶段 4 |
| vkms 虚拟屏 | 等上游 configfs + EDID 支持落地后重估 | 搁置 |

## 7. 路线图

1. **阶段 1（本实现）**：`vscreen-linux` EDID 后端 + 生成器 + 同步测试；VM 试用。
2. **阶段 1b（已完成）**：**Docker 测试harness**（`./test-docker.sh`）——ubuntu 容器内
   跑全量 Linux 套件：注入缝（`VSCREEN_DRM_SYS` / `VSCREEN_PARAM`）指向 fake
   sysfs 树，覆盖 root 路径（md5 网关、内嵌生成器字节一致性、apply/off 全流程）
   与 provision 免密闭环；GitHub Actions 可直接复用。
3. 阶段 2：真机（Intel/AMD/NVIDIA）验证 + VT 免除判定 + x11 纯 xrandr legacy 后端。
4. 阶段 3：wlroots 后端（`swaymsg create_output` / `wlr-randr`）。
5. 阶段 4：KDE 调研。
