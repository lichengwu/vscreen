# vscreen Windows 移植设计（windows-port-design）

> 状态：**调研完成，待实机验证**（2026-09-24）。目标平台仅 Windows 10 19041+ / Windows 11。
> 姊妹篇：[linux-port-design.md](linux-port-design.md)（机制对照见 §4）。

## 1. 调研结论

1. **Windows 没有内核级 EDID 覆盖**：`ChangeDisplaySettingsEx` 对物理屏只能选
   驱动已支持的模式，任意分辨率返回 `DISP_CHANGE_BADMODE`（官方文档 + 实践双确认）。
   → Linux 的 EDID 固件路线不可移植。
2. **但 Windows 有三平台最成熟的虚拟显示生态**：IddCx（间接显示驱动框架）。
   代表作 **Parsec VDD**（Parsec 官方签名驱动 + nomi-san 开源 wrapper，MIT，5k★）：
   CLI 可控（`vdd add/remove/list/set X WxH@R`）、注册表自定义分辨率（≤5 槽，
   `HKLM\SOFTWARE\Parsec\vdd`，`{width,height,hz}`，add 前读取）。
3. **HiDPI 2x 有可编程路径**：按显示器设 200% 缩放 —— 未公开但稳定的
   `DISPLAYCONFIG_DEVICE_INFO_SET_DPI_SCALE`（系统设置面板同款，SetDPI /
   windows-DPI-scaling-sample 逆向实现）。
4. **RustDesk 生态兼容性已证**：RustDesk 自带同机制（`virtual_display_manager`：
   rustdesk_idd/amyuni_idd 双实现、`plug_in_monitor(idx, modes)`，要求 Win10≥19041），
   只是无 CLI 暴露。VDD 虚拟屏对 RustDesk 就是普通显示器。
5. 无头 Windows 的 "No Display" 问题被 VDD 直接解决。

## 2. 工具矩阵

| 方案 | 机制 | 任意分辨率 | CLI | 签名 | 许可 | 定位 |
| --- | --- | --- | --- | --- | --- | --- |
| Parsec VDD + nomi-san wrapper | IddCx | ✅（注册表 preset ≤5） | ✅（add/remove/list/set/version） | ✅ | MIT | **推荐后端** |
| RustDesk 内置 IDD | IddCx | ✅ | ❌（仅 App UI） | ✅ | GPL | 生态证明，不可编程 |
| Amyuni usbmmidd | IddCx | 部分 | ✅ | ✅ | 个人免费/商用收费 | 备选 |
| ChangeDisplaySettingsEx / SetDisplayConfig | Win32 | ❌（驱动模式集内） | — | — | — | 设模式/拓扑的配套 API |
| DISPLAYCONFIG_..._SET_DPI_SCALE（未公开） | Win32 | —（缩放） | — | — | — | HiDPI 200% |
| HDMI 假塞子 | 硬件 | 固定 EDID | — | — | — | 兜底 |

## 3. 架构（`vscreen.ps1`，PowerShell 5.1+，零依赖）

```powershell
vscreen provision     # 一次性（管理员）：静默安装 parsec-vdd setup（已签名驱动 + vdd CLI）
vscreen <设备>[@系数]  # 档位表/@缩放计算 → vdd remove all → 写注册表 5 个 preset 槽
                      # （comp/native/full/2x 物理/当前缩放档）→ vdd add → vdd set 0 WxH@60
                      # →（默认 2x 档）DPI API 设 200%
vscreen off           # vdd remove all
vscreen status        # vdd list + EnumDisplayDevices
```

- 设备表 / 补偿档 / @缩放语义与 macOS/Linux 完全共用（纯数据）。
- 注意：① `@` 在 PowerShell 是特殊字符（vdd CLI 自己都用 `r` 代替，如
  `vdd set 1 1920x1080 r120`）——CLI 解析需处理转义；② Windows 无预装
  python，但 VDD 路线**无需生成 EDID**（驱动内置），PowerShell 即可零依赖；
  ③ 权限模型：HKLM + 驱动操作 → 切换需管理员（Windows 无路径限定的 sudoers，
  文档明示即可）。

## 4. 三平台机制对照

| | macOS | Linux | Windows |
| --- | --- | --- | --- |
| 后端 | BetterDisplay | EDID 固件覆盖（内核） | Parsec VDD（IddCx） |
| 虚拟屏身份 | 屏名 "vscreen" | EDID 产品名 | VDD 显示器 |
| 任意分辨率 | ✅ | ✅（自生成 EDID） | ✅（preset ≤5 槽） |
| HiDPI 2x | ✅ | ✅（240DPI→scale2） | ✅（2x 模式 + 200%） |
| 切换权限 | 无 | provision 后免密 | 每次需管理员 |
| 一次性 provision | 装 app | root+免密规则 | 管理员静默装驱动 |

## 5. 验证环境结论（为什么不在 Mac 的 Docker 里测）

- Mac（Apple Silicon，Docker 无 /dev/kvm）：Windows 容器需 Windows 宿主（不可能）；
  `dockur/windows`（x64）= QEMU-in-Docker，无 KVM 时 TCG 模拟装系统需数小时，
  且在 arm 上跑 amd64 镜像 = 模拟套模拟——不可行；
  `dockur/windows-arm`（ARM Windows）可跑，**但 Parsec VDD 仅有 x64 驱动
  （IddCx 驱动无 ARM64 构建、驱动不能模拟运行）→ 测不了后端**。
- **正解：在有 KVM 的 x64 Linux 宿主上跑 `dockur/windows`**（该镜像就是为此设计，
  KVM 下 ~10-30 分钟装好）——候选：Ubuntu 验证机（若其 QEMU 宿主开启了嵌套
  虚拟化，即 `/dev/kvm` 存在）；或任何 x64 Windows 实机/云 VM。

## 6. 待实机验证清单

1. `vdd set` 接受注册表 preset 的任意分辨率（1470x919 / 2940x1838）与切换时序
   （是否需 remove→add 循环）
2. DPI 200% API 在 Win10/Win11 的行为
3. RustDesk 采集 VDD 虚拟屏（画面/多屏选择器）
4. parsec-vdd setup 静默安装/卸载
5. 2x 物理模式 + 200% 缩放 = macOS HiDPI 语义的端到端对齐
