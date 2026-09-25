# ============================================================================
# install.sh — One-line installer for vscreen (macOS / Linux)
#
# Auto-installs missing dependencies (BetterDisplay, python3) via the
# platform's package manager, then installs the vscreen CLI into PATH.
#
# For Windows, use install.ps1 instead (native PowerShell).
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/lichengwu/vscreen/main/install.sh | bash
#   or locally: ./install.sh
# ============================================================================

set -euo pipefail

REPO="lichengwu/vscreen"
OS="$(uname -s)"

echo "==> Platform: ${OS}"

# --- Platform dispatch ---
if [[ "$OS" == "Darwin" ]]; then
    SRC_NAME="vscreen"
    PKG_MGR="brew"
elif [[ "$OS" == MINGW* ]] || [[ "$OS" == CYGWIN* ]] || [[ "$OS" == MSYS* ]]; then
    echo "❌ Windows detected. Use install.ps1 instead:"
    echo "   powershell -ExecutionPolicy Bypass -File install.ps1"
    echo "   or: iwr https://raw.githubusercontent.com/lichengwu/vscreen/main/install.ps1 -OutFile install.ps1; powershell -File install.ps1"
    exit 1
else
    SRC_NAME="vscreen-linux"
    # Detect package manager
    if command -v apt-get >/dev/null 2>&1; then
        PKG_MGR="apt"
    elif command -v dnf >/dev/null 2>&1; then
        PKG_MGR="dnf"
    elif command -v yum >/dev/null 2>&1; then
        PKG_MGR="yum"
    elif command -v pacman >/dev/null 2>&1; then
        PKG_MGR="pacman"
    elif command -v zypper >/dev/null 2>&1; then
        PKG_MGR="zypper"
    else
        PKG_MGR="none"
    fi
fi

INST_NAME="vscreen"
RAW_URL="https://raw.githubusercontent.com/${REPO}/main/${SRC_NAME}"

# --- Dependency auto-install ---
echo "==> Checking dependencies..."

# 1. python3 (needed on macOS + Linux)
if ! command -v python3 >/dev/null 2>&1; then
    echo "  python3 not found. Installing..."
    case "$PKG_MGR" in
        brew)
            brew install python 2>&1 | tail -3
            ;;
        apt)
            sudo apt-get update -qq && sudo apt-get install -y -qq python3 2>&1 | tail -3
            ;;
        dnf|yum)
            sudo $PKG_MGR install -y -q python3 2>&1 | tail -3
            ;;
        pacman)
            sudo pacman -S --noconfirm python 2>&1 | tail -3
            ;;
        zypper)
            sudo zypper install -y python3 2>&1 | tail -3
            ;;
        none)
            echo "❌ No package manager found. Please install python3 manually." >&2
            exit 1
            ;;
    esac
    # Verify
    if ! command -v python3 >/dev/null 2>&1; then
        echo "❌ Failed to install python3" >&2
        exit 1
    fi
    echo "  ✓ python3 installed"
else
    echo "  ✓ python3"
fi

# 2. BetterDisplay (macOS only)
if [[ "$OS" == "Darwin" ]]; then
    BD_CHECK="/Applications/BetterDisplay.app/Contents/MacOS/BetterDisplay"
    if [[ ! -x "$BD_CHECK" ]]; then
        echo "  BetterDisplay not found. Installing..."
        if command -v brew >/dev/null 2>&1; then
            brew install --cask betterdisplay 2>&1 | tail -3
        else
            # Install Homebrew first if missing
            echo "  Homebrew not found. Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            # Then BetterDisplay
            if command -v brew >/dev/null 2>&1 || [[ -x /opt/homebrew/bin/brew ]] || [[ -x /usr/local/bin/brew ]]; then
                # Add brew to PATH for this session
                if [[ -x /opt/homebrew/bin/brew ]]; then
                    eval "$(/opt/homebrew/bin/brew shellenv)"
                elif [[ -x /usr/local/bin/brew ]]; then
                    eval "$(/usr/local/bin/brew shellenv)"
                fi
                brew install --cask betterdisplay 2>&1 | tail -3
            else
                echo "❌ Failed to install Homebrew" >&2
                exit 1
            fi
        fi
        # Verify
        if [[ ! -x "$BD_CHECK" ]]; then
            echo "❌ Failed to install BetterDisplay (may need manual approval in System Settings)" >&2
            echo "   Download from https://betterdisplay.pro and install manually" >&2
            echo "   Then re-run this installer" >&2
            exit 1
        fi
        echo "  ✓ BetterDisplay installed"
    else
        echo "  ✓ BetterDisplay"
    fi
fi

# --- Install script ---
# Choose install directory (prefer user-writable system bin, fallback ~/.local/bin)
DEST=""
for d in /opt/homebrew/bin /usr/local/bin; do
    if [[ -d "$d" && -w "$d" ]]; then
        DEST="$d"
        break
    fi
done
if [[ -z "${DEST}" ]]; then
    DEST="$HOME/.local/bin"
    mkdir -p "$DEST"
fi
echo "==> Installing ${INST_NAME} to ${DEST}/"

# Source: local repo if running from clone, else download from GitHub
SRC=""
SRC_LOCAL="$(cd "$(dirname "$0")" 2>/dev/null && pwd)/${SRC_NAME}"
if [[ "$0" == */install.sh && -f "$SRC_LOCAL" ]]; then
    SRC="$SRC_LOCAL"
else
    echo "  Downloading from GitHub..."
    SRC=$(mktemp)
    curl -fsSL --connect-timeout 10 --max-time 30 "$RAW_URL" -o "$SRC"
fi
install -m 0755 "$SRC" "$DEST/$INST_NAME"
rm -f "$SRC" 2>/dev/null || true

# --- PATH check ---
if [[ ":${PATH}:" != *":${DEST}:"* ]]; then
    echo ""
    echo "⚠️  ${DEST} is not in your PATH. Add it:"
    if [[ "$OS" == "Darwin" ]]; then
        echo "   echo 'export PATH=\"${DEST}:\$PATH\"' >> ~/.zshrc && source ~/.zshrc"
    else
        echo "   echo 'export PATH=\"${DEST}:\$PATH\"' >> ~/.profile && source ~/.profile"
    fi
fi

# --- Verify ---
echo ""
echo "==> Verifying installation..."
"$DEST/$INST_NAME" version 2>/dev/null || "$DEST/$INST_NAME" status 2>/dev/null || true

echo ""
echo "Installation complete! ✅"
echo ""
if [[ "$OS" == "Darwin" ]]; then
    echo "Quick start:"
    echo "  vscreen list              # supported devices & resolutions"
    echo "  vscreen mbp14             # match MacBook Pro 14 ★"
    echo "  vscreen mba13@125%        # scale factor"
    echo "  vscreen 1512x945          # raw resolution"
    echo "  vscreen off               # restore"
    echo "  vscreen update            # self-update"
elif [[ "$SRC_NAME" == "vscreen-linux" ]]; then
    echo "Quick start:"
    echo "  vscreen list              # supported devices & resolutions"
    echo "  vscreen provision         # one-time setup (sudo + passwordless)"
    echo "  vscreen mba13             # match device (after provision)"
    echo "  vscreen off               # restore"
    echo "  vscreen update            # self-update"
    echo ""
    echo "  See docs/linux-port-design.md for details"
fi
