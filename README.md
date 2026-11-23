# laptop_setup

Sets up a fresh Ubuntu laptop with my git prompt, Docker and VS Code.

```bash
./setup.sh                 # everything
./setup.sh --git           # git, git-gui, gitk, ~/.sourcegit prompt, ~/.gitconfig
./setup.sh --docker        # docker-ce + compose/buildx plugins, docker without sudo
./setup.sh --vscode        # VS Code + extensions + settings.json
```

Run as your normal user (not `sudo`). Log out and back in afterwards so the `docker` group takes effect.

To refresh `dotfiles/` from the current laptop (new extensions, settings changes):

```bash
./export_current_config.sh
```
