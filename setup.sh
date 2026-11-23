#!/usr/bin/env bash
# Set up a fresh Ubuntu laptop with git (+ prompt, git gui), Docker (+ compose) and VS Code (+ extensions).
#
# Usage: ./setup.sh [--git] [--docker] [--vscode]   (no flags = everything)
# Run as your normal user (NOT with sudo); it asks for sudo when needed.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES="${SCRIPT_DIR}/dotfiles"

log()  { echo -e "\n\e[1;32m==> $*\e[0m"; }
warn() { echo -e "\e[1;33m[warn] $*\e[0m"; }

if [[ "${EUID}" -eq 0 ]]; then
  echo "Run this as your normal user, not root/sudo." >&2
  exit 1
fi

# Copy a file, keeping a timestamped backup if the destination exists and differs.
install_file() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "${dst}")"
  if [[ -f "${dst}" ]] && ! cmp -s "${src}" "${dst}"; then
    cp "${dst}" "${dst}.bak.$(date +%Y%m%d%H%M%S)"
    warn "Backed up existing ${dst}"
  fi
  cp "${src}" "${dst}"
}

setup_git() {
  log "Installing git, git-gui and gitk"
  sudo apt-get update
  sudo apt-get install -y git git-gui gitk

  log "Installing ~/.sourcegit (branch/status in the prompt + gitgraph alias)"
  install_file "${DOTFILES}/sourcegit" "${HOME}/.sourcegit"
  if ! grep -qE '^\s*(source|\.)\s+~/\.sourcegit' "${HOME}/.bashrc"; then
    printf '\nsource ~/.sourcegit\n' >> "${HOME}/.bashrc"
  fi

  log "Installing ~/.gitconfig"
  if [[ -f "${HOME}/.gitconfig" ]]; then
    warn "~/.gitconfig already exists, leaving it untouched (reference copy: ${DOTFILES}/gitconfig)"
  else
    install_file "${DOTFILES}/gitconfig" "${HOME}/.gitconfig"
  fi
}

setup_docker() {
  log "Installing Docker Engine + compose/buildx plugins (official Docker apt repo)"
  # Remove conflicting distro packages if present.
  for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
    sudo apt-get remove -y "${pkg}" >/dev/null 2>&1 || true
  done

  sudo apt-get update
  sudo apt-get install -y ca-certificates curl
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc

  local codename
  codename="$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")"
  sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${codename}
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

  sudo apt-get update
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  sudo systemctl enable --now docker

  log "Allowing ${USER} to use docker without sudo"
  getent group docker >/dev/null || sudo groupadd docker
  # gpasswd works for domain (AD/sssd) users too; usermod -aG fails if the user is not in /etc/passwd.
  sudo gpasswd -a "${USER}" docker
  warn "Log out and back in (or reboot) for the docker group to apply. Until then: 'newgrp docker'."
}

setup_vscode() {
  log "Installing VS Code (official Microsoft apt repo)"
  sudo apt-get install -y wget gpg apt-transport-https
  if [[ ! -f /usr/share/keyrings/microsoft.gpg ]]; then
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/microsoft.gpg
    sudo install -D -o root -g root -m 644 /tmp/microsoft.gpg /usr/share/keyrings/microsoft.gpg
    rm -f /tmp/microsoft.gpg
  fi
  sudo tee /etc/apt/sources.list.d/vscode.sources >/dev/null <<EOF
Types: deb
URIs: https://packages.microsoft.com/repos/code
Suites: stable
Components: main
Architectures: amd64
Signed-By: /usr/share/keyrings/microsoft.gpg
EOF
  # Avoid the duplicate-repo prompt the .deb would otherwise create.
  echo "code code/add-microsoft-repo boolean false" | sudo debconf-set-selections
  sudo apt-get update
  sudo apt-get install -y code

  log "Installing VS Code extensions"
  local ext failed=()
  while IFS= read -r ext; do
    [[ -z "${ext}" || "${ext}" == \#* ]] && continue
    code --install-extension "${ext}" --force >/dev/null || failed+=("${ext}")
  done < "${DOTFILES}/vscode/extensions.txt"
  ((${#failed[@]})) && warn "Failed extensions: ${failed[*]}"

  log "Installing VS Code user settings"
  install_file "${DOTFILES}/vscode/settings.json" "${HOME}/.config/Code/User/settings.json"
}

DO_GIT=0; DO_DOCKER=0; DO_VSCODE=0
if [[ $# -eq 0 ]]; then
  DO_GIT=1; DO_DOCKER=1; DO_VSCODE=1
fi
for arg in "$@"; do
  case "${arg}" in
    --git) DO_GIT=1 ;;
    --docker) DO_DOCKER=1 ;;
    --vscode) DO_VSCODE=1 ;;
    -h|--help) sed -n '2,5p' "$0"; exit 0 ;;
    *) echo "Unknown option: ${arg}" >&2; exit 1 ;;
  esac
done

((DO_GIT))    && setup_git
((DO_DOCKER)) && setup_docker
((DO_VSCODE)) && setup_vscode

log "Done. Open a new terminal (or 'source ~/.bashrc'); log out/in for docker group membership."
