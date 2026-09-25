# ============================================================================
# install.ps1 — One-line installer for vscreen on Windows
#
# Auto-installs Parsec VDD (virtual display driver) and places the
# vscreen CLI into PATH. Run from PowerShell (any session).
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File install.ps1
#
# One-liner (from PowerShell):
#   iwr https://raw.githubusercontent.com/lichengwu/vscreen/main/install.ps1 -OutFile install.ps1; powershell -ExecutionPolicy Bypass -File install.ps1
# ============================================================================

$ErrorActionPreference = "Stop"

$REPO = "lichengwu/vscreen"
$RAW_URL = "https://raw.githubusercontent.com/$REPO/main/vscreen-windows.ps1"
$INSTALL_DIR = "$env:LOCALAPPDATA\Programs\vscreen"
$INSTALL_PATH = "$INSTALL_DIR\vscreen.ps1"
$CMD_PATH = "$INSTALL_DIR\vscreen.cmd"

Write-Host "==> vscreen Windows installer" -ForegroundColor Cyan

# --- Step 1: Check PowerShell version ---
$psVer = $PSVersionTable.PSVersion
if ($psVer -lt [version]"5.1") {
    Write-Host "[ERROR] PowerShell 5.1+ required (current: $psVer)" -ForegroundColor Red
    exit 1
}
Write-Host "  PowerShell $($psVer) OK"

# --- Step 2: Create install directory ---
if (-not (Test-Path $INSTALL_DIR)) {
    New-Item -ItemType Directory -Path $INSTALL_DIR -Force | Out-Null
}
Write-Host "  Install directory: $INSTALL_DIR"

# --- Step 3: Download or copy vscreen-windows.ps1 ---
$localFile = Join-Path (Split-Path $PSScriptRoot -Parent) "vscreen-windows.ps1"
if (Test-Path $localFile) {
    # Running from cloned repo
    Copy-Item $localFile $INSTALL_PATH -Force
    Write-Host "  Installed from local repo"
} else {
    # Download from GitHub
    Write-Host "  Downloading from GitHub..."
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $RAW_URL -OutFile $INSTALL_PATH -UseBasicParsing
        Write-Host "  Downloaded OK"
    } catch {
        Write-Host "[ERROR] Download failed: $_" -ForegroundColor Red
        exit 1
    }
}

# --- Step 4: Create cmd wrapper (so 'vscreen' works from cmd/PowerShell) ---
$cmdContent = @"
@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0vscreen.ps1" %*
"@
Set-Content -Path $CMD_PATH -Value $cmdContent -Encoding ASCII
Write-Host "  Created cmd wrapper: $CMD_PATH"

# --- Step 5: Add to user PATH ---
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$INSTALL_DIR*") {
    [Environment]::SetEnvironmentVariable("Path", "$userPath;$INSTALL_DIR", "User")
    Write-Host "  Added to user PATH: $INSTALL_DIR"
    Write-Host "  (New terminals will pick this up automatically)"
} else {
    Write-Host "  Already in PATH"
}

# --- Step 6: Install Parsec VDD (if not present) ---
$vddInstalled = Get-PnpDevice | Where-Object { $_.FriendlyName -match "Parsec Virtual Display" } | Select-Object -First 1

if ($vddInstalled -and $vddInstalled.Status -eq "OK") {
    Write-Host "  Parsec VDD driver: already installed"
} else {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if ($isAdmin) {
        Write-Host "  Installing Parsec VDD driver..."
        $setupUrl = "https://github.com/nomi-san/parsec-vdd/releases/latest/download/ParsecVDisplay-setup.exe"
        $setupFile = "$env:TEMP\ParsecVDisplay-setup.exe"
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -Uri $setupUrl -OutFile $setupFile -UseBasicParsing
            Start-Process $setupFile -ArgumentList "/VERYSILENT","/SUPPRESSMSGBOXES","/NORESTART" -Wait
            Remove-Item $setupFile -Force -ErrorAction SilentlyContinue
            Write-Host "  Parsec VDD driver installed"
        } catch {
            Write-Host "  [WARN] VDD driver install failed: $_" -ForegroundColor Yellow
            Write-Host "  Run 'vscreen provision' later from the RustDesk desktop" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  [INFO] Parsec VDD driver not installed" -ForegroundColor Yellow
        Write-Host "  Run 'vscreen provision' from an elevated PowerShell to install it" -ForegroundColor Yellow
    }
}

# --- Step 7: Write default registry presets ---
$regBase = "HKLM:\SOFTWARE\Parsec\vdd"
$presets = @(
    @{w=1470; h=919},   # mba13 compensated
    @{w=2940; h=1838},  # mba13 HiDPI 2x
    @{w=1512; h=945},   # mbp14 compensated
    @{w=1376; h=1032},  # iPad Pro 13
    @{w=1710; h=1069}   # mba15 compensated
)

$isAdmin2 = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isAdmin2) {
    for ($i = 0; $i -lt $presets.Count; $i++) {
        $path = "$regBase\$i"
        if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
        Set-ItemProperty -Path $path -Name "width" -Value $presets[$i].w -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $path -Name "height" -Value $presets[$i].h -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $path -Name "hz" -Value 60 -Type DWord -ErrorAction SilentlyContinue
    }
    Write-Host "  Registry presets written (5 resolutions)"
} else {
    Write-Host "  [INFO] Registry presets require admin (run 'vscreen provision' later)" -ForegroundColor Yellow
}

# --- Verify ---
Write-Host ""
Write-Host "==> Verifying..."
if (Test-Path $INSTALL_PATH) {
    Write-Host "  Installation OK" -ForegroundColor Green
} else {
    Write-Host "  [ERROR] Installation verification failed" -ForegroundColor Red
    exit 1
}

# --- Done ---
Write-Host ""
Write-Host "Installation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Quick start (from RustDesk desktop — console session):"
Write-Host "  vscreen list              # supported devices"
Write-Host "  vscreen mba13             # match MacBook Air 13"
Write-Host "  vscreen mba13@125% --print # preview scale factor"
Write-Host "  vscreen off               # remove virtual display"
Write-Host ""
Write-Host "IMPORTANT: vscreen on Windows must run in the console session"
Write-Host "(the RustDesk desktop). SSH/RDP sessions cannot access displays."
Write-Host ""
Write-Host "Project: https://github.com/lichengwu/vscreen"
