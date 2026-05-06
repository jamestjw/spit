#!/usr/bin/env bash
#
# Spit Installer
#
# Usage: curl -s {{SPIT_URL}}/install | sh
#

set -euo pipefail

SPIT_URL="{{SPIT_URL}}"

# Determine where to install
if [[ "$OSTYPE" == "linux-gnu"* ]] || [[ "$OSTYPE" == "darwin"* ]]; then
  if [ -w "/usr/local/bin" ]; then
    INSTALL_DIR="/usr/local/bin"
  else
    INSTALL_DIR="$HOME/.local/bin"
    mkdir -p "$INSTALL_DIR"
    # Suggest adding to PATH if not present
    if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
      printf "\n  \033[1;33mWarning: %s is not in your PATH.\033[0m\n" "$INSTALL_DIR"
      printf "  You might need to add it to your .bashrc or .zshrc:\n"
      printf "  export PATH=\"\$PATH:%s\"\n" "$INSTALL_DIR"
    fi
  fi
else
  printf "  Error: Unsupported OS type: %s\n" "$OSTYPE" >&2
  exit 1
fi

printf "  Downloading spit from %s...\n" "$SPIT_URL"

curl -sL "$SPIT_URL/spit" -o "$INSTALL_DIR/spit"
chmod +x "$INSTALL_DIR/spit"

printf "\n  \033[1;32mDone! spit has been installed to %s/spit\033[0m\n" "$INSTALL_DIR"
printf "  Try it out:\n\n"
printf "  echo \"Hello, world!\" | spit\n\n"
