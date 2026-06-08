#!/bin/bash
# this script ensures cagelab scripts, symlinks and folders are 
# all correct. Run this regularly to ensure everything is in order.

# Ensure the script continues on errors and handles empty globs
set +e
shopt -s nullglob

controller=false
server=false
while getopts "cs" opt; do
	case $opt in
		c) controller=true ;;
		s) server=true ;;
		*) echo "Usage: $0 [-c] [-s]" >&2; exit 1 ;;
	esac
done

export SPATH="$HOME/Code/CageLab-Code"

# Create some folders if not already existing
mkdir -p "$HOME/Code"
mkdir -p "$HOME/bin"
mkdir -p "$HOME/.local/bin"
mkdir -p "$HOME/.config"
mkdir -p "$HOME/.config/systemd/user"
mkdir -p "$HOME/.config/tmuxp"
mkdir -p "$HOME/.config/i3"
mkdir -p "$HOME/.ssh"
[[ $controller == true ]] && mkdir -p "$HOME/.ansible" && sudo mkdir -p /etc/ansible && sudo chown -R "$USER":"$USER" /etc/ansible || true
sudo mkdir -p /usr/local/bin /usr/local/etc
sudo chown -R "$USER":"$USER" /usr/local/bin || true
sudo chown -R "$USER":"$USER" /usr/local/etc || true

# PTB expects libglut.so.3 but this is not present in Ubuntu 24.04 and later.
# The following line creates a symlink to the libglut.so.3.12.0 file, which is the version available in Ubuntu 24.04 and later.
# This allows PTB to find the library it needs to function correctly.
[[ -f "/usr/lib/x86_64-linux-gnu/libglut.so.3.12.0" ]] && 
	sudo ln -svf /usr/lib/x86_64-linux-gnu/libglut.so.3.12.0 /usr/lib/x86_64-linux-gnu/libglut.so.3

# link some cagelab stuff
ln -sfv "$SPATH/scripts/toggleInput" "/usr/local/bin"
ln -sfv "$SPATH/setup/config/mediamtx.yml" "/usr/local/etc"
ln -svf "$SPATH/scripts/"* "$HOME/bin"
ln -sfv "$SPATH/services/"*.service "$HOME/.config/systemd/user"
# Link theConductor service for newer MATLAB if present
[[ -d "/usr/local/MATLAB/R2025a" ]] && ln -sfv "$SPATH/services/theConductor2025a.dservice" "$HOME/.config/systemd/user/theConductor.service"
[[ -d "/usr/local/MATLAB/R2025b" ]] && ln -sfv "$SPATH/services/theConductor2025b.dservice" "$HOME/.config/systemd/user/theConductor.service"
[[ -d "/usr/local/MATLAB/R2026a" ]] && ln -sfv "$SPATH/services/theConductor2026a.dservice" "$HOME/.config/systemd/user/theConductor.service"
ln -svf "$SPATH/setup/config/sshconfig" "$HOME/.ssh/config"
ln -sfv "$SPATH/setup/config/.rsync-excludes" "$HOME/.config"

# Link .zshrc only for non-controllers
if [[ $controller == false ]]; then
	echo "===>>> Linking zsh configuration files..."
	[[ -f "$HOME/.zshrc" ]] && cp "$HOME/.zshrc" "$HOME/.config/.zshrc$(date -Iseconds).bak"
	ln -svf "$SPATH/setup/config/zshrc" "$HOME/.zshrc"
	ln -svf "$SPATH/setup/config/zsh-"* "$HOME/.config"
	ln -svf "$SPATH/setup/config/aliases" "$HOME/.config"
fi

# ansible config (only for controllers)
if [[ $controller == true ]]; then
	echo "===>>> Linking ansible controller files..."
	sudo ln -svf "$SPATH/ansible/ansible.cfg" "/etc/ansible/ansible.cfg"
	sudo ln -svf "$SPATH/ansible/inventory/hosts" "/etc/ansible/hosts"
	sudo ln -svf "$SPATH/ansible/playbooks" "$HOME/.ansible"
	#sudo ln -svf "$SPATH/ansible/roles" "$HOME/.ansible/roles" 
fi

# Link pixi-global.toml
mkdir -p "$HOME/.pixi/manifests"
ln -svf "$SPATH/setup/config/pixi-global.toml" "$HOME/.pixi/manifests/"

# few others
sudo cp "$SPATH/setup/config/10-libuvc.rules" "/etc/udev/rules.d/"
ln -svf "$SPATH/setup/config/i3config" "$HOME/.config/i3/config"
ln -svf "$SPATH/setup/config/Xresources" "$HOME/.Xresources"
ln -svf "$SPATH/setup/config/cagelab-monitor.yaml" "$HOME/.config/tmuxp"
if [[ ! -f "$HOME/.tmux.conf" ]]; then
	ln -svf "$SPATH/setup/config/tmux.conf" "$HOME/.tmux.conf"
fi
if [[ ! -f "$HOME/.config/starship.toml" ]]; then
	ln -svf "$SPATH/setup/config/starship.toml" "$HOME/.config/starship.toml"
fi

# Ensure user ownership for everything created in home
chown -R "$USER":"$USER" "$HOME/bin" "$HOME/.local" "$HOME/.config" "$HOME/.ssh" "$HOME/.pixi" 2>/dev/null

# Final message and exit
echo "All done!" && exit 0
