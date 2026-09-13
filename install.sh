#!/bin/zsh
# ============================================================================
# install.sh — 一键安装 vscreen CLI
#
# 一行安装（免 clone）：
#   curl -fsSL https://raw.githubusercontent.com/lichengwu/vscreen/main/install.sh | bash
# 或本地仓库内： ./install.sh
#
# 检查依赖（BetterDisplay / python3）→ 装进 PATH → 运行验证
# pipe 安全：不依赖 cwd 或本地文件，恒从 GitHub raw 拉取脚本。
# ============================================================================

set -euo pipefail

SCRIPT_NAME="vscreen"
REPO="lichengwu/vscreen"
RAW_URL="https://raw.githubusercontent.com/$REPO/main/$SCRIPT_NAME"

echo "==> 检查依赖 ..."

# 1. BetterDisplay
if [[ ! -x "/Applications/BetterDisplay.app/Contents/MacOS/BetterDisplay" ]]; then
  echo "❌ 未检测到 BetterDisplay，请先安装（二选一）："
  echo "   brew install --cask betterdisplay"
  echo "   或到 https://betterdisplay.pro 下载安装"
  exit 1
fi
echo "✓ BetterDisplay"

# 2. python3
if ! command -v python3 >/dev/null 2>&1; then
  echo "❌ 缺少 python3（运行 xcode-select --install 安装命令行工具）"
  exit 1
fi
echo "✓ python3"

# 3. 选择安装目录（优先 brew 的 bin，用户可写；否则 ~/.local/bin）
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
echo "==> 安装 $SCRIPT_NAME 到 $DEST/"

# 4. 脚本源：本地仓库优先（克隆场景），否则从 GitHub 下载（pipe / 一键场景）
SRC=""
SRC_LOCAL="$(cd "$(dirname "$0")" 2>/dev/null && pwd)/$SCRIPT_NAME"
if [[ -f "$SRC_LOCAL" ]]; then
  SRC="$SRC_LOCAL"
else
  echo "==> 从 GitHub 下载 ..."
  SRC=$(mktemp)
  curl -fsSL "$RAW_URL" -o "$SRC"
fi
install -m 0755 "$SRC" "$DEST/$SCRIPT_NAME"

# 5. PATH 检查
if [[ ":$PATH:" != *":$DEST:"* ]]; then
  echo "⚠️  $DEST 不在 PATH 中，请执行："
  echo "   echo 'export PATH=\"$DEST:\$PATH\"' >> ~/.zshrc && source ~/.zshrc"
fi

# 6. 运行验证
echo "==> 运行验证 ..."
"$DEST/$SCRIPT_NAME" status || true

echo
echo "安装完成 ✅"
echo "快速开始："
echo "  vscreen list              # 查看支持的设备与分辨率"
echo "  vscreen mbp14             # 匹配 MacBook Pro 14（全屏无黑边）★推荐"
echo "  vscreen 1512x945          # 或直接给分辨率"
echo "  vscreen off               # 恢复纯物理显示"
echo "  vscreen update            # 自更新"
