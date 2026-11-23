#!/usr/bin/env bash
# Refresh dotfiles/ from THIS laptop (run after adding extensions or changing settings).
set -euo pipefail
DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/dotfiles"
mkdir -p "${DOTFILES}/vscode"

cp ~/.sourcegit "${DOTFILES}/sourcegit"
cp ~/.gitconfig "${DOTFILES}/gitconfig"
cp ~/.config/Code/User/settings.json "${DOTFILES}/vscode/settings.json"
[[ -f ~/.config/Code/User/keybindings.json ]] && cp ~/.config/Code/User/keybindings.json "${DOTFILES}/vscode/keybindings.json"
code --list-extensions > "${DOTFILES}/vscode/extensions.txt"

echo "Exported to ${DOTFILES}:"
ls -R "${DOTFILES}"
