#!/bin/bash
export PLATFORM=$(uname)
export ARCH=$(uname -m)
export SPATH="$HOME/Code/CageLab-Code"
uname -a | grep -iq "microsoft" && MOD="WSL"
uname -a | grep -iq "aarch64|armv7" && MOD="RPi"
PLATFORM=$(uname -s)$MOD
mversion="R2025b"
if [[ $PLATFORM == "Darwin" ]]; then
	mpath="/Applications/MATLAB_$mversion.app/bin/matlab"
else
	mpath="/usr/local/MATLAB/$mversion/bin/matlab"
fi

sudo apt install git
sudo apt install curl

printf "\n\n--->>> CageLab Bootstrap terminal %s setup, current directory is %s\n\n" "$SHELL" "$SPATH"
printf '\e[36m'
printf "Using %s...\n" "$PLATFORM"
printf '\e[0m'

# Create some folders
mkdir -p "$HOME/Code"
mkdir -p "$HOME/bin"
mkdir -p "$HOME/.local/bin"
mkdir -p "$HOME/.config/systemd/user"
mkdir -p "$HOME/.config/tmuxp"
sudo chown -R "$USER":"$USER" /usr/local/bin
sudo chown -R "$USER":"$USER" /usr/local/etc

# this section disables the touch screen at start
# replace with name of the touch panel device
# you can find the name by running `xinput list` in a terminal
# and looking for the device that corresponds to your touch panel
# CHANGE name TO YOUR TOUCH PANEL NAME
name="ILITEK-TP"
sd '^(ExecStart=\/usr\/local\/bin\/toggleInput [^ ]+ ).*$' '$1"'$name'"' "$SPATH/services/toggleInput.service"
sudo ln -svf "$SPATH/config/toggleInput" /usr/local/bin/toggleInput &&
	sudo chmod +x /usr/local/bin/toggleInput &&
	sudo ln -svf "$SPATH/services/toggleInput.service" "$HOME/.config/systemd/user" &&
	systemctl --user daemon-reload &&
	systemctl --user enable toggleInput.service &&
	systemctl --user start toggleInput.service

#================================================= Install Pixi (cross-platform package manager)
[[ ! -d $HOME/.pixi/bin ]] && eval curl -fsSL https://pixi.sh/install.sh | bash

#============================================== Install Netbird
# Use the setup key from our password manager or do that later
[[ ! -f $(which netbird) ]] && curl -fsSL https://pkgs.netbird.io/install.sh | sh
printf "Enter a KEY to register netbird (blank to ignore): "
read -r ans
if [[ -n $ans ]]; then
	netbird up --setup-key $ans
fi

#============================================== [Optional] Install MATLAB with MPM
printf "Shall we use MPM to get MATLAB? [y / n]:  "
read -r ans
if [[ $ans == 'y' ]]; then
	products='MATLAB Curve_Fitting_Toolbox Instrument_Control_Toolbox MATLAB_Report_Generator Optimization_Toolbox Parallel_Computing_Toolbox Signal_Processing_Toolbox Statistics_and_Machine_Learning_Toolbox'
	curl -L -o /usr/local/bin/mpm https://www.mathworks.com/mpm/glnxa64/mpm
	chmod +x /usr/local/bin/mpm
	sudo mkdir -p /usr/local/MATLAB &&
	sudo chown "$USER":"$USER" /usr/local/MATLAB &&
	sudo chmod 777 /usr/local/MATLAB &&
	/usr/local/bin/mpm install --release=$mversion --products=$products
fi
[[ -f $mpath ]] && ln -sfv /usr/local/MATLAB/$mversion/bin/matlab /usr/local/bin

#============================================== APT + snap + flatpak packages
if [ "$PLATFORM" = "Linux" ]; then
	sudo apt --fix-broken install
	sudo apt update && sudo apt -y full-upgrade
	sudo apt -my install apt-transport-https ca-certificates software-properties-common
	sudo apt -my install build-essential zsh git gparted vim curl file mc
	sudo apt -my install gawk mesa-utils exfatprogs
	sudo apt -my install freeglut3-dev 
	sudo apt -my install libglut-dev
	sudo apt -my install pipewire-pulse pulseaudio-utils
	sudo apt -my install openssh-server
	sudo apt -my install i3 rofi nitrogen xdotool
	sudo apt -my install p7zip-full p7zip-rar figlet jq htop
	sudo apt -my install libunrar5 libdc1394-25 libraw1394-11
	sudo apt -my install gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly
	sudo apt -my install synaptic zathura zathura-pdf-poppler zathura-ps
	sudo apt -my install tmux tmuxp
	sudo apt -my install snapd
	sudo apt -my install openjdk-21-jre
	sudo apt -my install flatpak
	sudo apt -my install wakeonlan etherwake
	sudo apt -my install python3-pip python3-venv
	sudo snap install core
	sudo snap install starship --edge

	# get update i3 desktop manager
	"$SPATH/config/geti3.sh"

	# Install snap packages vlc and VS Code
	[[ ! -f $(which vlc) ]] && sudo snap install vlc
	[[ ! -f $(which code) ]] && sudo snap install --classic code

	# flatpak installs OBS
	flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
	flatpak install -y flathub com.obsproject.Studio
	
fi

#============================================== install or update cogmoteGO
curl -sS https://raw.githubusercontent.com/Ccccraz/cogmoteGO/main/install.sh | sh &&
	cogmoteGO service &&
	cogmoteGO service start

#=============================================== Install NoMachine
[[ ! -f /usr/NX/bin/nxd ]] && 
	curl -L -o $HOME/Downloads/nomachine.deb https://web9001.nomachine.com/download/9.5/Linux/nomachine_9.5.7_2_amd64.deb &&
	sudo dpkg -i $HOME/Downloads/nomachine.deb

#=============================================== Install eget and get mediamtx and sunshine
[[ ! -f /usr/local/bin/eget ]] && curl https://zyedidia.github.io/eget.sh | sh && chmod +x eget && mv eget /usr/local/bin/eget
[[ ! -f /usr/local/bin/mediamtx ]] && eget bluenviron/mediamtx --to=/usr/local/bin && ln -svf /usr/local/bin/mediamtx $HOME/.local/bin

#============================================= Clone our core repos from gitee
mkdir -p "$HOME/Code"
cd "$HOME/Code" || exit
[[ ! -d 'Setup' ]] && git clone --recurse-submodules https://gitee.com/CogPlatform/Setup.git
[[ ! -d 'Psychtoolbox' ]] && git clone --recurse-submodules https://gitee.com/CogPlatform/Psychtoolbox.git
[[ ! -d 'opticka' ]] && git clone --recurse-submodules https://gitee.com/CogPlatform/opticka.git
[[ ! -d 'CageLab-Code' ]] && git clone --recurse-submodules https://gitee.com/CogPlatform/CageLab-Code.git
[[ ! -d 'matlab-jzmq' ]] && git clone --recurse-submodules https://gitee.com/CogPlatform/matlab-jzmq.git
[[ ! -d 'matmoteGO' ]] && git clone --recurse-submodules https://gitee.com/CogPlatform/matmoteGO.git
[[ ! -d 'PTBSimia' ]] && git clone --recurse-submodules https://gitee.com/CogPlatform/PTBSimia.git
cd ~ || exit

# PTB expects libglut.so.3 but this is not present in Ubuntu 24.04 and later.
# The following line creates a symlink to the libglut.so.3.12.0 file, which is the version available in Ubuntu 24.04 and later.
# This allows PTB to find the library it needs to function correctly.
[[ -f "/usr/lib/x86_64-linux-gnu/libglut.so.3.12.0" ]] && 
	sudo ln -svf /usr/lib/x86_64-linux-gnu/libglut.so.3.12.0 /usr/lib/x86_64-linux-gnu/libglut.so.3

#============================================ Setup PTB and opticka path:
if [[ -f $mpath ]]; then
	printf "Shall we try to setup the MATLAB path for PTB / opticka? [y / n]:  "
	read -r ans
	if [[ $ans == 'y' ]]; then
		cd "$HOME/Code/Psychtoolbox" || exit
		matlab -nodesktop -nosplash -r "SetupPsychToolbox; pause(1); cd ../../opticka; addOptickaToPath; pause(1); exit"
	fi
	cd "$HOME" || exit
fi

#============================================ Make sure all the symlinks are correct
"$SPATH/setup/makelinks.sh"

printf '\n\n--->>> All Done...\n'
printf '\e[m'
