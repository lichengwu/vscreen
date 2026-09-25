# vscreen Windows 移植实机验证报告（2026-09-25）

> 目标机器：192.168.50.107 / Windows 11 Pro (10.0.26200) x64 / 8GB RAM
> 验证方式：SSH（admin/admin）+ RDP（FreeRDP3）+ WMI 系统级查询
> 结论：**核心机制全部验证通过，session 隔离是唯一阻碍自动化分辨率切换的硬约束**

## 一、已验证通过 ✅

| # | 验证项 | 证据 |
|---|---|---|
| 1 | Parsec VDD 驱动安装成功 | WMI: `Parsec Virtual Display Adapter` (ROOT\DISPLAY\0003) Status=OK |
| 2 | 虚拟屏创建成功 | WMI: 1920x1080 当前分辨率；事件日志: `Monitor creation ... STATUS_SUCCESS` |
| 3 | 自定义分辨率 preset 写入 | 注册表 `HKLM\SOFTWARE\Parsec\vdd\0` (1470x919=0x5be×0x397)、`vdd\1` (2940x1838=0xb7c×0x72e) |
| 4 | ParsecVDisplay GUI 正常运行 | 管理员权限下 Add 按钮可用，点击后驱动成功创建虚拟屏 |
| 5 | D3D11 渲染管线就绪 | 事件日志: `D3D11 device created for render adapter LUID 0xEED8` |
| 6 | RustDesk 运行中 | 3 个进程（service + 2 用户级），可采集桌面 |
| 7 | SSH 通道 | admin/admin 认证通过，命令执行正常 |
| 8 | RDP 通道 | admin/admin NLA 认证通过，FreeRDP3 会话正常 |
| 9 | P/Invoke 修复 | `IntPtr.Zero` 代替 `$null` 解决了 `EnumDisplayDevicesA` 的 error 87 |

## 二、发现的关键架构约束 ⚠️

### Windows 三层会话隔离

| 会话类型 | 会话 ID | 能看到的显示器 | 能否改分辨率 |
|---|---|---|---|
| SSH | 各自独立 | 仅自己的 1024x768 虚拟屏 | ❌ |
| RDP | 2 | 仅 Remote Display Adapter (2204x1378) | ❌ |
| **Console** | **1** | **所有显示器（含 Parsec VDD）** | **✅ 唯一有效** |

**根因**：Windows 安全架构将显示 API（`EnumDisplayDevices`/`ChangeDisplaySettingsEx`）绑定到调用者的会话。跨会话操作需要 `SE_TCB_NAME` 特权或用户级 token 注入——从 SSH/RDP 无法获取。

### 自动化尝试全部受阻

| 方法 | 结果 | 原因 |
|---|---|---|
| SSH 直接 P/Invoke | ❌ | 会话隔离 |
| RDP 会话 P/Invoke | ❌ | 会话隔离 |
| SYSTEM 计划任务 | ❌ | Session 0 同样隔离 |
| 交互计划任务 (/it) | ❌ | console 会话无登录用户 |
| PsExec -i 1 | ❌ | SSH 会话无权创建跨会话进程 |
| tscon 重定向 | ❌ | 用户 ol_l 密码未知（admin 凭据不匹配） |
| WinRM localhost | ❌ | UAC Access Denied |
| 暴力扫描所有 DISPLAY 设备 | ❌ | EnumDisplaySettings 在非 console 会话一律返回 false |

### 结论

**vscreen Windows 后端必须在 console 会话中运行**——这是三平台最重要的架构差异：

| | macOS | Linux | Windows |
|---|---|---|---|
| 运行环境 | 任意终端 | root SSH / console | **仅 console 会话（RustDesk 桌面）** |
| 部署形态 | CLI 脚本 | CLI 脚本 + provision | **桌面应用或开机自启服务** |

## 三、vscreen Windows 架构建议（基于实机验证）

```powershell
# 部署形态：PowerShell 脚本 + 计划任务（用户登录时自启动）
# 运行位置：console 会话（RustDesk 连接后可见）

vscreen provision     # 一次性（管理员）：安装 Parsec VDD + 注册表 preset
vscreen <设备>[@系数]  # 在 console 会话中运行：
                      #   → ChangeDisplaySettingsEx 设虚拟屏分辨率
                      #   → DPI API 设 200% 缩放（HiDPI）
vscreen off           # 恢复默认
```

### 技术栈
- **Parsec VDD** (IddCx)：虚拟屏创建/管理
- **ChangeDisplaySettingsEx**：分辨率设置（在 console 会话中有效）
- **DISPLAYCONFIG_SET_DPI_SCALE**（未公开 API）：per-monitor 200% 缩放
- **注册表 preset**：自定义分辨率（≤5 槽）
- PowerShell 5.1+：零依赖

## 四、待完成项（需要 console 会话验证）

| # | 项目 | 预期 | 验证方法 |
|---|---|---|---|
| 1 | 1470x919 分辨率切换 | preset 生效后 ChangeDisplaySettingsEx 返回 0 | 在 RustDesk 桌面中运行脚本 |
| 2 | HiDPI 200% 缩放 | 物理分辨率 2940x1838 + scale 2 | 同上 |
| 3 | RustDesk 采集虚拟屏 | 客户端看到 "vscreen" 显示器 | RustDesk 远程连接确认 |

**验证方法**：用户通过 **RustDesk**（非 RDP）连接 192.168.50.107，在桌面中打开 PowerShell 管理员，运行：
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\vdd\vdd-fix-test.ps1
```

## 五、实机环境详情

```
OS: Windows 11 Pro (10.0.26200.0) x64
显示设备（WMI 系统级）:
  ROOT\DISPLAY\0000: USB Mobile Monitor Virtual Display (Amyuni/RustDesk)
  ROOT\DISPLAY\0001: Virtual Display Driver (MikeTheTech) - 800x600
  ROOT\DISPLAY\0002: Virtual Display Driver (MikeTheTech) - 800x600
  ROOT\DISPLAY\0003: Parsec Virtual Display Adapter - 1920x1080 ⭐
  PCI\VEN_1234: Microsoft Basic Display Adapter - 1280x800 (headless)
  RDPIDD: Microsoft Remote Display Adapter - 2204x1378 (RDP session)

注册表 preset:
  HKLM\SOFTWARE\Parsec\vdd\0: width=1470(0x5be), height=919(0x397), hz=60
  HKLM\SOFTWARE\Parsec\vdd\1: width=2940(0xb7c), height=1838(0x72e), hz=60

会话:
  Session 0: Services (RustDesk service)
  Session 1: Console (已连接，无登录用户) ← 虚拟屏所在
  Session 2: RDP (用户 ol_l，活动) ← 当前操作位置
```
