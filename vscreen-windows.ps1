# ============================================================================
# vscreen-windows.ps1 - vscreen Windows backend (Parsec VDD + Win32 API)
#
# Mechanism (validated on Windows 11 Pro, 2026-09-25):
#   1. Parsec VDD (IddCx) creates virtual displays
#   2. Registry presets (HKLM\SOFTWARE\Parsec\vdd) define custom resolutions
#   3. ChangeDisplaySettingsEx sets resolution (console session only)
#   4. DISPLAYCONFIG_SET_DPI_SCALE for per-monitor 200% scaling (HiDPI)
#
# IMPORTANT: This script must run in the CONSOLE session (RustDesk desktop).
# SSH/RDP sessions cannot access display APIs (Windows session isolation).
#
# See docs/windows-port-design.md for full architecture.
# ============================================================================

# --print / --logical flags (also accepted as string args)
# PowerShell switch params can't use -- prefix, so we check $Args too
param(
    [switch]$PrintFlag,
    [switch]$LogicalFlag,
    [switch]$NoVTFlag,
    [switch]$NoMirrorFlag,
    [switch]$HelpFlag,
    [switch]$VersionFlag,
    [Parameter(Position=0, ValueFromRemainingArguments)]
    [string[]]$Args
)

# Also check for --print / --logical in string args
if ($Args -contains "--print") { $script:PrintFlag = $true; $Args = @($Args | Where-Object { $_ -ne "--print" }) }
if ($Args -contains "--logical") { $script:LogicalFlag = $true; $Args = @($Args | Where-Object { $_ -ne "--logical" }) }

$ErrorActionPreference = "Stop"
$VERSION = "1.2.0"

# --- Device table (sync with macOS vscreen / Linux vscreen-linux) ---
# Format: "alias" -> @{Name="..."; Native="WxH"; Comp="WxH"; Full="WxH"}
$DEVICES = @{
    "mba13"      = @{Name="MacBook Air 13";    Native="1470x956";  Comp="1470x919";  Full="2560x1664"}
    "mba15"      = @{Name="MacBook Air 15";    Native="1710x1107"; Comp="1710x1069"; Full="2880x1864"}
    "mbp14"      = @{Name="MacBook Pro 14";    Native="1512x982";  Comp="1512x945";  Full="3024x1964"}
    "mbp16"      = @{Name="MacBook Pro 16";    Native="1728x1117"; Comp="1728x1080"; Full="3456x2234"}
    "imac24"     = @{Name="iMac 24";           Native="2240x1260"; Comp="2240x1236"; Full="4480x2520"}
    "studio"     = @{Name="Studio Display";    Native="2560x1440"; Comp="2560x1416"; Full="5120x2880"}
    "xdr"        = @{Name="Pro Display XDR";   Native="3008x1692"; Comp="3008x1668"; Full="6016x3384"}
    "ipadpro13"  = @{Name="iPad Pro 13";       Native="1376x1032"; Comp="1376x1032"; Full="2752x2064"}
    "ipadpro129" = @{Name="iPad Pro 12.9";     Native="1366x1024"; Comp="1366x1024"; Full="2732x2048"}
    "ipadair13"  = @{Name="iPad Air 13";       Native="1366x1024"; Comp="1366x1024"; Full="2732x2048"}
}

$SYNONYMS = @{
    "air13"="mba13"; "air15"="mba15"; "pro14"="mbp14"; "pro16"="mbp16"
    "imac"="imac24"; "prodisplay"="xdr"; "xdr6k"="xdr"
    "pro13"="ipadpro13"; "pro129"="ipadpro129"; "ipadair"="ipadair13"; "ipad13"="ipadair13"
}

$DEV_ORDER = @("mba13","mba15","mbp14","mbp16","imac24","studio","xdr","ipadpro13","ipadpro129","ipadair13")

# --- Registry paths ---
$VDD_REG = "HKLM:\SOFTWARE\Parsec\vdd"
$VDD_CLI = "$env:ProgramFiles\ParsecVDisplay\ParsecVDisplay.exe"

# --- Helper functions ---
function Write-DeviceInfo([string]$msg) { Write-Host "  $msg" }

function Get-DeviceEntry([string]$alias) {
    $key = $alias
    if ($SYNONYMS.ContainsKey($key)) { $key = $SYNONYMS[$key] }
    if ($DEVICES.ContainsKey($key)) { return $DEVICES[$key] }
    return $null
}

function ScaleResolution([string]$res, [double]$k) {
    $parts = $res -split 'x'
    $w = [math]::Round([double]$parts[0] / $k, [MidpointRounding]::AwayFromZero)
    $h = [math]::Round([double]$parts[1] / $k, [MidpointRounding]::AwayFromZero)
    return "$w`x$h"
}

function RoundResolution([string]$res) {
    $parts = $res -split 'x'
    $w = [math]::Round([double]$parts[0], [MidpointRounding]::AwayFromZero)
    $h = [math]::Round([double]$parts[1], [MidpointRounding]::AwayFromZero)
    return "$w`x$h"
}

function Get-PhysicalRes([string]$logical, [bool]$isLogical) {
    if ($isLogical) { return $logical }
    $parts = $logical -split 'x'
    $w = [int]$parts[0] * 2
    $h = [int]$parts[1] * 2
    return "$w`x$h"
}

function Write-Presets([string[]]$resolutions) {
    # Write up to 5 registry presets for Parsec VDD
    for ($i = 0; $i -lt [Math]::Min($resolutions.Count, 5); $i++) {
        $parts = $resolutions[$i] -split 'x'
        $path = "$VDD_REG\$i"
        if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
        Set-ItemProperty -Path $path -Name "width" -Value ([int]$parts[0]) -Type DWord
        Set-ItemProperty -Path $path -Name "height" -Value ([int]$parts[1]) -Type DWord
        Set-ItemProperty -Path $path -Name "hz" -Value 60 -Type DWord
    }
}

function Show-Status {
    Write-Host "vscreen v$VERSION (windows) status:"
    Write-Host "  Presets:"
    if (Test-Path $VDD_REG) {
        for ($i = 0; $i -lt 5; $i++) {
            $p = "$VDD_REG\$i"
            if (Test-Path $p) {
                $w = (Get-ItemProperty $p -Name width -ErrorAction SilentlyContinue).width
                $h = (Get-ItemProperty $p -Name height -ErrorAction SilentlyContinue).height
                if ($w) { Write-Host "    [$i] ${w}x${h}" }
            }
        }
    }
    Write-Host "  Displays:"
    Get-CimInstance Win32_VideoController | ForEach-Object {
        $res = if ($_.CurrentHorizontalResolution) { "$($_.CurrentHorizontalResolution)x$($_.CurrentVerticalResolution)" } else { "-" }
        Write-Host "    $($_.Caption): $res"
    }
}

function Show-List {
    Write-Host "Supported devices (compensated tier by default):"
    Write-Host ""
    foreach ($key in $DEV_ORDER) {
        $d = $DEVICES[$key]
        Write-Host ("  {0,-12} {1,-22} {2,-16} {3,-16} {4}" -f $key, $d.Name, $d.Comp, $d.Native, $d.Full)
    }
    Write-Host ""
    Write-Host "Usage: vscreen <alias> | <alias>-native | <alias>-full | <WxH>"
}

function Do-Provision {
    # One-time setup: install Parsec VDD driver + registry presets
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host "ERROR: provision requires Administrator" -ForegroundColor Red
        exit 1
    }

    Write-Host "Installing Parsec VDD driver..."

    # Check if driver already installed
    $driver = Get-PnpDevice | Where-Object { $_.FriendlyName -match "Parsec Virtual Display" } | Select-Object -First 1
    if ($driver) {
        Write-Host "  Driver already installed (Status: $($driver.Status))"
    } else {
        # Download and install
        $url = "https://github.com/nomi-san/parsec-vdd/releases/latest/download/ParsecVDisplay-setup.exe"
        $tmp = "$env:TEMP\ParsecVDisplay-setup.exe"
        Write-Host "  Downloading from GitHub..."
        Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing
        Write-Host "  Installing (silent)..."
        Start-Process $tmp -ArgumentList "/VERYSILENT","/SUPPRESSMSGBOXES","/NORESTART" -Wait
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    }

    # Write default presets (all device tiers)
    $allRes = @()
    foreach ($key in $DEV_ORDER) {
        $d = $DEVICES[$key]
        $allRes += $d.Comp
        $allRes += $d.Native
    }
    # Add HiDPI physical resolutions
    $allRes += "2940x1838"
    $allRes += "3024x1890"

    Write-Host "  Writing registry presets..."
    Write-Presets ($allRes | Select-Object -Unique | Select-Object -First 5)

    Write-Host ""
    Write-Host "Provision complete."
    Write-Host "  Now run 'vscreen <device>' from the RustDesk desktop (console session)."
}

function Do-Apply([string]$device, [string]$scale, [bool]$isPrint, [bool]$isLogical) {
    # Resolve device
    $entry = $null
    $tier = "comp"
    $desc = ""

    if ($device -match '^(\d+)x(\d+)$') {
        # Raw resolution
        $S_RES = $device
        $S_DESC = "Custom"
    } else {
        # Device alias
        $key = $device
        if ($key -match '-native$') { $tier = "native"; $key = $key -replace '-native$','' }
        elseif ($key -match '-full$') { $tier = "full"; $key = $key -replace '-full$','' }

        $entry = Get-DeviceEntry $key
        if (-not $entry) {
            Write-Host "ERROR: Unknown device '$device'" -ForegroundColor Red
            Show-List
            exit 1
        }

        switch ($tier) {
            "native" { $S_RES = $entry.Native; $S_DESC = "$key native" }
            "full"   { $S_RES = $entry.Full;   $S_DESC = "$key full" }
            default  { $S_RES = $entry.Comp;   $S_DESC = "$key compensated" }
        }
    }

    # Apply scale factor
    $S_BASE = $S_RES
    if ($scale) {
        $k = [double]$scale -replace '%',''
        if ($k -gt 3) { $k = $k / 100 }
        if ($k -lt 0.25 -or $k -gt 4) {
            Write-Host "ERROR: Scale factor out of range (25%-400%)" -ForegroundColor Red
            exit 1
        }
        $S_RES = ScaleResolution $S_RES $k
    }

    # Calculate physical resolution (2x for HiDPI by default)
    $phys = Get-PhysicalRes $S_RES $isLogical

    if ($isPrint) {
        $tag = if ($isLogical) { "(EDID logical, scale 1)" } else { "(EDID 2x physical, mutter scale 2)" }
        if ($scale) {
            Write-Host "$S_DESC $S_BASE @ $scale -> $S_RES (logical) -> $phys $tag"
        } else {
            Write-Host "$S_DESC -> $S_RES (logical) -> $phys $tag"
        }
        return
    }

    # --- Actual apply (requires console session) ---
    Write-Host "Setting resolution: $phys (logical $S_RES)"

    # Step 1: Write preset if not already there
    $found = $false
    for ($i = 0; $i -lt 5; $i++) {
        $p = "$VDD_REG\$i"
        if (Test-Path $p) {
            $w = (Get-ItemProperty $p -Name width -ErrorAction SilentlyContinue).width
            $h = (Get-ItemProperty $p -Name height -ErrorAction SilentlyContinue).height
            if ($w -and "$w`x$h" -eq $phys) { $found = $true; break }
        }
    }
    if (-not $found) {
        Write-Host "  Writing preset for $phys..."
        # Find a free slot or overwrite slot 0
        Write-Presets @($phys, $S_RES, $S_BASE) | Out-Null
    }

    # Step 2: Use ParsecVDisplay CLI if available, otherwise GUI instructions
    $vddCli = Get-Command "vdd" -ErrorAction SilentlyContinue
    if ($vddCli) {
        Write-Host "  Using vdd CLI..."
        & vdd remove all 2>$null
        & vdd add
        & vdd set 0 $phys
    } else {
        Write-Host "  vdd CLI not found. Using Win32 API..."
        # Try ChangeDisplaySettingsEx on the Parsec VDD display
        # This only works in the console session
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class DisplayChange {
    [DllImport("user32.dll", CharSet = CharSet.Ansi, SetLastError = true)]
    public static extern int ChangeDisplaySettingsExA(
        string deviceName, ref DEVMODEA dm, IntPtr hwnd, uint flags, IntPtr lParam);

    [DllImport("user32.dll", CharSet = CharSet.Ansi, SetLastError = true)]
    public static extern bool EnumDisplaySettingsA(
        string deviceName, int modeNum, ref DEVMODEA dm);

    [DllImport("user32.dll", CharSet = CharSet.Ansi, SetLastError = true)]
    public static extern bool EnumDisplayDevicesA(
        IntPtr lpDevice, uint iDevNum, ref DISPLAY_DEVICEA lpDD, uint dwFlags);

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Ansi)]
    public struct DEVMODEA {
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=32)]
        public string dmDeviceName;
        public short dmSpecVersion; public short dmDriverVersion;
        public short dmSize; public short dmDriverExtra;
        public int dmFields;
        public int dmPositionX; public int dmPositionY;
        public int dmDisplayOrientation; public int dmDisplayFixedOutput;
        public short dmColor; public short dmDuplex; public short dmYResolution; public short dmTTOption;
        public short dmCollate;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=32)]
        public string dmFormName;
        public short dmLogPixels;
        public int dmBitsPerPel;
        public int dmPelsWidth; public int dmPelsHeight;
        public int dmDisplayFlags; public int dmDisplayFrequency;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Ansi)]
    public struct DISPLAY_DEVICEA {
        public uint cb;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=32)]
        public string DeviceName;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=128)]
        public string DeviceString;
        public uint StateFlags;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=128)]
        public string DeviceID;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=128)]
        public string DeviceKey;
    }
}
"@

        # Find Parsec VDD display
        $targetDev = $null
        $targetDM = $null

        for ($i = 0; $i -lt 10; $i++) {
            $dd = New-Object DisplayChange+DISPLAY_DEVICEA
            $dd.cb = [System.Runtime.InteropServices.Marshal]::SizeOf([type][DisplayChange+DISPLAY_DEVICEA])
            if ([DisplayChange]::EnumDisplayDevicesA([IntPtr]::Zero, [uint32]$i, [ref]$dd, 0)) {
                $active = ($dd.StateFlags -band 1) -ne 0
                if ($active -and $dd.DeviceString -match "Parsec") {
                    $targetDev = $dd.DeviceName
                    # Find the target mode
                    $dm = New-Object DisplayChange+DEVMODEA
                    $dm.dmSize = [System.Runtime.InteropServices.Marshal]::SizeOf([type][DisplayChange+DEVMODEA])
                    for ($m = 0; $m -lt 200; $m++) {
                        if ([DisplayChange]::EnumDisplaySettingsA($targetDev, $m, [ref]$dm)) {
                            $pw = $phys -split 'x'
                            if ($dm.dmPelsWidth -eq [int]$pw[0] -and $dm.dmPelsHeight -eq [int]$pw[1]) {
                                $targetDM = $dm
                                break
                            }
                        }
                    }
                    if ($targetDM) { break }
                }
            }
        }

        if ($targetDev -and $targetDM) {
            Write-Host "  Found display: $targetDev, applying $phys..."
            $result = [DisplayChange]::ChangeDisplaySettingsExA($targetDev, [ref]$targetDM,
                [IntPtr]::Zero, 1, [IntPtr]::Zero)
            if ($result -eq 0) {
                Write-Host "  SUCCESS: Resolution set to $phys"
            } else {
                Write-Host "  FAILED: ChangeDisplaySettingsEx returned $result" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  WARNING: No Parsec VDD display found." -ForegroundColor Yellow
            Write-Host "  Make sure virtual display is created (ParsecVDisplay > Add)" -ForegroundColor Yellow
            Write-Host "  and this script runs in the console session (RustDesk)." -ForegroundColor Yellow
        }
    }

    # Step 3: HiDPI scaling (if physical 2x)
    if (-not $isLogical -and -not $scale) {
        # TODO: Set per-monitor DPI scale to 200% using DISPLAYCONFIG API
        # This is an undocumented API - implement with care
        Write-Host "  Note: HiDPI 200% scaling should be set manually in Display Settings" -ForegroundColor DarkGray
    }

    Write-Host ""
    Write-Host "Done: $phys (logical $S_RES) [vscreen]"
    Show-Status
}

function Do-Off {
    # Remove virtual display / restore original
    Write-Host "Removing virtual display..."

    $vddCli = Get-Command "vdd" -ErrorAction SilentlyContinue
    if ($vddCli) {
        & vdd remove all
        Write-Host "Done: all virtual displays removed"
    } else {
        Write-Host "Note: Use ParsecVDisplay to remove virtual displays manually"
        Write-Host "  (right-click tray icon > Remove)"
    }
}

# --- Main ---
if ($Help -or ($Args -contains "-h") -or ($Args -contains "--help")) {
    Write-Host "vscreen v$VERSION (windows) - Match remote client device resolution"
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  vscreen <device>[@scale]          Match device (compensated tier)"
    Write-Host "  vscreen <device>-native[@scale]   Native logical resolution"
    Write-Host "  vscreen <device>-full[@scale]     1:1 physical tier"
    Write-Host "  vscreen <WxH>[@scale]             Direct resolution"
    Write-Host "  vscreen off                       Remove virtual display"
    Write-Host "  vscreen status                    Show current state"
    Write-Host "  vscreen list                      List supported devices"
    Write-Host "  vscreen provision                 One-time setup (install VDD)"
    Write-Host "  vscreen version                   Print version"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  --print                           Preview only (no changes)"
    Write-Host "  --logical                         Logical resolution (scale 1)"
    Write-Host ""
    Write-Host "Scale factor: 125% / 1.25 / 80 (range 25%-400%)"
    Write-Host "  125% = content 25% bigger: resolution / 1.25 proportionally"
    Write-Host ""
    Write-Host "IMPORTANT: Run from RustDesk desktop (console session)."
    Write-Host "Project: https://github.com/lichengwu/vscreen"
    exit 0
}

if ($Version -or ($Args -contains "-v") -or ($Args -contains "--version") -or ($Args -contains "version")) {
    Write-Host "vscreen v$VERSION (windows)"
    exit 0
}

# Parse arguments
$device = ""
$scale = ""

if ($Args) {
    $allArgs = $Args -join " "

    # Handle commands
    switch ($Args[0]) {
        "list" { Show-List; exit 0 }
        "status" { Show-Status; exit 0 }
        "provision" { Do-Provision; exit 0 }
        "off" { Do-Off; exit 0 }
        default {
            # Device or WxH
            $device = $Args[0]

            # Extract @scale factor
            if ($device -match '@(.+)$') {
                $scale = $Matches[1]
                $device = $device -replace '@(.+)$',''
            }

            # Space-separated scale ("mba13 @125%")
            if ($Args.Count -gt 1) {
                $next = $Args[1]
                if ($next -match '^@') {
                    $scale = $next -replace '^@',''
                    # Check for spaced number after @
                    if ($scale -eq '' -and $Args.Count -gt 2) {
                        $scale = $Args[2]
                    }
                } elseif ($next -match '^\d+\.?\d*%?$' -and $device -match '^\d+$') {
                    # Space-separated WxH ("1512 945")
                    $device = "$device`x$next"
                }
            }
        }
    }
}

if (-not $device) {
    Write-Host "ERROR: Missing argument (device | WxH | off | status | list | provision | version)" -ForegroundColor Red
    exit 1
}

# Normalize scale
if ($scale) {
    $scale = $scale -replace '%',''
    if ($scale -match '^\d+$' -and [double]$scale -gt 3) {
        # It's a percentage, convert to multiplier
        $k = [double]$scale / 100
        $scale = "$k"
    }
}

# Run apply
Do-Apply -device $device -scale $scale -isPrint:($PrintFlag.IsPresent -or $script:PrintFlag) -isLogical:($LogicalFlag.IsPresent -or $script:LogicalFlag)
