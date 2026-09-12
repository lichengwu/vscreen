#!/bin/zsh
# ============================================================================
# install.sh — 一键安装 mbscreens CLI
# 检查依赖（BetterDisplay / python3）→ 安装到本地 bin → 运行验证
#
# 用法：
#   ./install.sh          # 优先安装仓库内脚本；本地没有则从 GitHub 下载
#   mbscreens update      # 安装后可用此命令自更新
# ============================================================================

set -euo pipefail

SCRIPT_NAME="mbscreens"
REPO="lichengwu/macbook-screens"
RAW_URL="https://raw.githubusercontent.com/$REPO/main/$SCRIPT_NAME"
SRC_LOCAL="$(cd "$(dirname "$0")" && pwd)/$SCRIPT_NAME"

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
  echo "❌ 缺少 python3（macOS 可运行 xcode-select --install 安装命令行工具）"
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

# 4. 脚本源：优先本地（克隆的仓库），否则从 GitHub 下载
SRC=""
if [[ -f "$SRC_LOCAL" ]]; then
  SRC="$SRC_LOCAL"
else
  echo "==> 本地未找到脚本，从 GitHub 下载 ..."
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
"$DEST/$SCRIPT_NAME" status

echo
echo "安装完成 ✅"
echo "常用命令："
echo "  mbscreens mbp        # 匹配 MacBook Pro 14（推荐，全屏无黑边）"
echo "  mbscreens mba13      # 匹配 MacBook Air 13"
echo "  mbscreens mba15      # 匹配 MacBook Air 15"
echo "  mbscreens off        # 恢复纯物理显示"
echo "  mbscreens update     # 自更新"
