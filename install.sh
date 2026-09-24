#!/bin/zsh
# ============================================================================
# install.sh — 一键安装 vscreen CLI（macOS / Linux）
#
# 一行安装（免 clone）：
#   curl -fsSL https://raw.githubusercontent.com/lichengwu/vscreen/main/install.sh | bash
# 或本地仓库内： ./install.sh
#
# 平台分发：macOS 安装 vscreen（BetterDisplay 后端）；
#           Linux 安装 vscreen-linux（EDID 固件后端）——命令名统一为 vscreen。
# 检查依赖 → 装进 PATH → 运行验证
# pipe 安全：不依赖 cwd 或本地文件，恒从 GitHub raw 拉取脚本。
# ============================================================================

set -euo pipefail

REPO="lichengwu/vscreen"
OS="$(uname -s)"

if [[ "$OS" == "Darwin" ]]; then
  SRC_NAME="vscreen"              # macOS 后端（zsh + BetterDisplay）
else
  SRC_NAME="vscreen-linux"        # Linux 后端（bash + EDID 固件覆盖）
fi
INST_NAME="vscreen"
RAW_URL="https://raw.githubusercontent.com/$REPO/main/$SRC_NAME"

echo "==> 平台：${OS}（安装 $SRC_NAME → 命令名 vscreen）"

echo "==> 检查依赖 ..."

# 1. BetterDisplay（仅 macOS）
if [[ "$OS" == "Darwin" ]]; then
  if [[ ! -x "/Applications/BetterDisplay.app/Contents/MacOS/BetterDisplay" ]]; then
    echo "❌ 未检测到 BetterDisplay，请先安装（二选一）："
    echo "   brew install --cask betterdisplay"
    echo "   或到 https://betterdisplay.pro 下载安装"
    exit 1
  fi
  echo "✓ BetterDisplay"
fi

# 2. python3（两平台都需要：EDID 生成 / BetterDisplay 输出解析）
if ! command -v python3 >/dev/null 2>&1; then
  if [[ "$OS" == "Darwin" ]]; then
    echo "❌ 缺少 python3（运行 xcode-select --install 安装命令行工具）"
  else
    echo "❌ 缺少 python3（sudo apt install python3 / dnf install python3 / pacman -S python）"
  fi
  exit 1
fi
echo "✓ python3"

# 3. 选择安装目录（优先用户可写的系统 bin；否则 ~/.local/bin）
DEST=""
for d in /opt/homebrew/bin /usr/local/bin; do
  if [[ -d "$d" && -w "$d" ]]; then
    DEST="$d"
    break
  fi
done
if [[ -z "$DEST" ]]; then
  DEST="$HOME/.local/bin"
  mkdir -p "$DEST"
fi
echo "==> 安装 $INST_NAME 到 $DEST/"

# 4. 脚本源：以脚本路径运行（克隆场景 ./install.sh）时用本地仓库；
#    pipe 场景（curl | bash，$0 是 "bash"）恒从 GitHub 下载，不受当前目录影响
SRC=""
SRC_LOCAL="$(cd "$(dirname "$0")" 2>/dev/null && pwd)/$SRC_NAME"
if [[ "$0" == */install.sh && -f "$SRC_LOCAL" ]]; then
  SRC="$SRC_LOCAL"
else
  echo "==> 从 GitHub 下载 ..."
  SRC=$(mktemp)
  curl -fsSL --connect-timeout 10 --max-time 30 "$RAW_URL" -o "$SRC"
fi
install -m 0755 "$SRC" "$DEST/$INST_NAME"

# 5. PATH 检查
if [[ ":$PATH:" != *":$DEST:"* ]]; then
  echo "⚠️  $DEST 不在 PATH 中，请执行："
  if [[ "$OS" == "Darwin" ]]; then
    echo "   echo 'export PATH=\"$DEST:\$PATH\"' >> ~/.zshrc && source ~/.zshrc"
  else
    echo "   echo 'export PATH=\"$DEST:\$PATH\"' >> ~/.profile && source ~/.profile"
  fi
fi

# 6. 运行验证（macOS 走 status；Linux 用 version，无需桌面/DRM）
echo "==> 运行验证 ..."
if [[ "$OS" == "Darwin" ]]; then
  "$DEST/$INST_NAME" status || true
else
  "$DEST/$INST_NAME" version || true
fi

echo
echo "安装完成 ✅"
echo "快速开始："
if [[ "$OS" == "Darwin" ]]; then
  echo "  vscreen list              # 查看支持的设备与分辨率"
  echo "  vscreen mbp14             # 匹配 MacBook Pro 14（全屏无黑边）★推荐"
  echo "  vscreen 1512x945          # 或直接给分辨率"
  echo "  vscreen off               # 恢复纯物理显示"
  echo "  vscreen update            # 自更新"
else
  echo "  vscreen list                      # 查看支持的设备与分辨率"
  echo "  sudo vscreen mba13                # 匹配客户端设备（EDID 覆盖，需 root）"
  echo "  vscreen mba13@125% --print        # 预览缩放换算（免 root）"
  echo "  sudo vscreen off                  # 恢复显示器原始 EDID"
  echo "  vscreen update                    # 自更新"
  echo " 详见 docs/linux-port-design.md（机制与兼容性）"
fi
