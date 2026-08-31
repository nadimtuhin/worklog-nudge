#!/bin/bash
set -euo pipefail

PLUGIN_DIR="$HOME/.swiftbar-plugins"
CONFIG_DIR="$HOME/.config/jira-worklog-nudge"
SRC="$(cd "$(dirname "$0")" && pwd)"

say() { printf '\n▸ %s\n' "$1"; }

[ "$(uname)" = Darwin ] || { echo "macOS only — SwiftBar is a macOS app."; exit 1; }

if ! command -v brew >/dev/null; then
  say "Installing Homebrew"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"

command -v jq >/dev/null || { say "Installing jq"; brew install jq; }
command -v acli >/dev/null || { say "Installing acli"; brew install atlassian/acli/acli; }
[ -d /Applications/SwiftBar.app ] || { say "Installing SwiftBar"; brew install --cask swiftbar; }

if ! acli jira auth status >/dev/null 2>&1; then
  say "Logging in to Jira"
  acli jira auth login
fi

status=$(acli jira auth status 2>/dev/null)
site=$(echo "$status" | awk '/Site:/{print $2}')
email=$(echo "$status" | awk '/Email:/{print $2}')

mkdir -p "$CONFIG_DIR"
if [ -f "$CONFIG_DIR/config.env" ]; then
  say "Keeping existing config at $CONFIG_DIR/config.env"
else
  say "Writing config for $email on $site"
  sed -e "s|^JIRA_SITE=.*|JIRA_SITE=$site|" -e "s|^JIRA_EMAIL=.*|JIRA_EMAIL=$email|" \
    "$SRC/config.env.example" > "$CONFIG_DIR/config.env"
fi

say "Installing plugin into $PLUGIN_DIR"
mkdir -p "$PLUGIN_DIR"
cp "$SRC/worklog.30m.sh" "$PLUGIN_DIR/"
chmod +x "$PLUGIN_DIR/worklog.30m.sh"

defaults write com.ameba.SwiftBar PluginDirectory -string "$PLUGIN_DIR"
open -a SwiftBar

say "Done — look for ⏱ in the menu bar."
echo "  Config:  $CONFIG_DIR/config.env"
echo "  Plugin:  $PLUGIN_DIR/worklog.30m.sh"
echo "  First refresh takes about a minute; it shows ⏱ … until then."
