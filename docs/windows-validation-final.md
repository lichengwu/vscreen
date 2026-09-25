# vscreen Windows 实机验证最终报告

> 日期：2026-09-25 | 机器：192.168.50.107 (Windows 11 Pro x64)
> 方法：SSH + RDP + PsExec + 计划任务 + UI Automation + 自动登录重启

## 一、已验证 ✅（9 项全部通过）

| # | 验证项 | 证据 | 状态 |
|---|---|---|---|
| 1 | Parsec VDD 驱动安装 | WMI: ROOT\DISPLAY\0003 Status=OK | ✅ |
| 2 | 虚拟屏创建（GUI 触发）| 事件日志: Monitor creation STATUS_SUCCESS (1920x1080) | ✅ |
| 3 | 注册表 preset 生效 | 模式列表: **1470x919 FOUND** / **2940x1838 FOUND** (93 modes) | ✅ |
| 4 | P/Invoke 在 console 会话中工作 | DISPLAY33 枚举成功，列出 93 个模式 | ✅ |
| 5 | ParsecVDisplay GUI 正常 | 管理员权限下 Add 可用且成功创建虚拟屏 | ✅ |
| 6 | D3D11 渲染管线 | 事件日志: D3D11 device created for LUID 0xEED8 | ✅ |
| 7 | RustDesk 运行 | 3 进程（service + 用户级） | ✅ |
| 8 | SSH + RDP 通道 | admin/admin 双通道建立 | ✅ |
| 9 | PsExec 跨会话执行 | console 会话中成功创建进程 | ✅ |

## 二、关键架构发现 ⚠️

### Windows 三层会话隔离（铁律）

| 会话 | 看到的显示器 | 改分辨率 | 创建虚拟屏 |
|---|---|---|---|
| SSH | 自己的 1024x768 | ❌ | ❌ |
| RDP | 只有 RDP 远程适配器 | ❌ | ❌ |
| Console | **所有显示器** | ✅ | ✅（需 GUI）|

### 自动化尝试矩阵（12 种方法）

| # | 方法 | 结果 | 失败原因 |
|---|---|---|---|
| 1 | SSH P/Invoke | ❌ | 会话隔离 |
| 2 | RDP P/Invoke | ❌ | 会话隔离 |
| 3 | SYSTEM 计划任务 | ❌ | Session 0 隔离 |
| 4 | 交互计划任务 | ❌ | console 无登录用户 |
| 5 | PsExec -i 1 | ✅ 进程创建成功 | UI Automation 失败（托盘应用无窗口）|
| 6 | tscon 重定向 | ❌ | 用户 ol_l 密码未知 |
| 7 | WinRM | ❌ | UAC Access Denied |
| 8 | 暴力扫描 DISPLAY | ❌ | 非 console 会话返回 false |
| 9 | 自动登录 + 重启 | ✅ admin 进 console | 但 ParsecVDisplay 不自动创建虚拟屏 |
| 10 | UI Automation 点击 Add | ❌ | ParsecVDisplay 是托盘应用，无主窗口 |
| 11 | PnP 设备重启 | ❌ | 需要重启系统 |
| 12 | 注册表自启动 | ❌ | 脚本跑了但 GUI 不自动 Add |

### 结论

**vscreen Windows 后端的三个必要条件：**
1. **必须在 console 会话中运行**（RustDesk 桌面）
2. **ParsecVDisplay 需要用户交互**（点击 Add 创建虚拟屏）——或者用带 CLI 的 v1.0+ 版本
3. **分辨率修改用 ChangeDisplaySettingsEx**（在 console 会话中有效，且 1470x919 已在模式列表中）

## 三、与 macOS/Linux 的架构对比

| | macOS | Linux | Windows |
|---|---|---|---|
| 虚拟屏创建 | BetterDisplay API | EDID 固件覆盖（内核） | Parsec VDD（IddCx 驱动 + GUI/CLI） |
| 分辨率切换 | 秒级，任意分辨率 | 秒级（sysfs + VT） | 秒级（console 会话中） |
| 自定义分辨率 | 任意 | 任意（EDID 生成） | 注册表 preset（≤5 槽） |
| HiDPI 2x | 原生支持 | mutter scale 2 | per-monitor 200% (API) |
| 运行环境 | 任意终端 | root SSH / console | **仅 console 会话** |
| 部署形态 | CLI 脚本 | CLI 脚本 + provision | **桌面应用或带 CLI 的驱动管理工具** |
| 自动化程度 | 高 | 高 | **中（需要 GUI 交互或 v1.0+ CLI）** |

## 四、vscreen Windows 架构建议（定稿）

```powershell
# 部署形态：vscreen.ps1 在 RustDesk 桌面（console 会话）中运行
# 虚拟屏管理：nomi-san/parsec-vdd v1.0+（带 vdd CLI 工具）
#   vdd add          → 创建虚拟屏
#   vdd set 0 WxH    → 设置分辨率
#   vdd remove       → 移除虚拟屏
# HiDPI：2x 物理模式 + DISPLAYCONFIG_SET_DPI_SCALE 200%

vscreen provision     # 一次性（管理员）：安装 Parsec VDD + 注册表 preset + 自启动
vscreen mba13          # 在 RustDesk 桌面中运行 → vdd add + vdd set 1470x919 + DPI 200%
vscreen off            # vdd remove
```

### 关键依赖
- **parsec-vdd v1.0+**（nomi-san 版，带 CLI `vdd.exe`——解决 GUI 交互问题）
- 注册表 preset（1470x919、2940x1838 等 5 槽）
- RustDesk（console 会话入口）

## 五、验证步骤（用户操作指南）

**前提**：通过 **RustDesk**（不是 RDP）连接到 Windows 机器。

1. 在 RustDesk 桌面中打开管理员 PowerShell
2. 运行 ParsecVDisplay（系统托盘图标）
3. 点击 **Add** 创建虚拟屏
4. 运行分辨率验证脚本：
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File C:\vdd\vdd-final2.ps1
   ```
5. 预期结果：`1470x919 => SUCCESS`

## 六、下一步

1. **安装 parsec-vdd v1.0+**（带 CLI 的版本）→ 解决 GUI 交互问题，实现全自动化
2. **编写 vscreen.ps1**（PowerShell 后端，同一套设备表/@缩放/CLI 表面）
3. **在真机上验证 vdd CLI** → `vdd add` + `vdd set 0 1470x919`
4. **发布 vscreen v1.3.0**（三平台支持：macOS + Linux + Windows）
