#!/usr/bin/env zsh

# force reset submodules to the latest commit on their configured remote branch
resetSubmodules() {
	git submodule sync --recursive
	git submodule update --init --recursive --remote --force
	git submodule foreach --recursive 'git clean -fdx'
}

ensureOriginRemote() {
	local repoUrl="$1"

	if git remote get-url origin >/dev/null 2>&1; then
		git remote set-url origin "$repoUrl"
	else
		git remote add origin "$repoUrl"
	fi
}

rm -rf ~/Code/CageLab # old directory renamed to CageLab-Code, remove if it still exists to avoid confusion

repositories=(
	~/Code/CageLab-Code https://gitee.com/CogPlatform/CageLab-Code.git
	~/Code/Psychtoolbox https://gitee.com/CogPlatform/Psychtoolbox.git
	~/Code/opticka https://gitee.com/CogPlatform/opticka.git
	~/Code/matmoteGO https://gitee.com/CogPlatform/matmoteGO.git
	~/Code/PTBSimia https://gitee.com/CogPlatform/PTBSimia.git
	~/Code/matlab-jzmq https://gitee.com/CogPlatform/matlab-jzmq.git
	~/Code/PacmanTask https://gitee.com/CogPlatform/PacmanTask.git
)


for ((i = 1; i <= $#repositories; i += 2)); do
	dir=${repositories[i]}
	repoUrl=${repositories[i + 1]}

	if [[ -d $dir && -d $dir/.git ]]; then
		echo ">>> Resetting $dir"
		pushd $dir >/dev/null
		ensureOriginRemote "$repoUrl"
		git fetch origin --prune
		git remote set-head origin --auto >/dev/null 2>&1 || true
		upstream=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null)
		if [[ -z $upstream ]]; then
			upstream=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)
		fi
		if [[ -n $upstream ]]; then
			git reset --hard "$upstream"
		else
			git reset --hard
		fi
		git clean -fdx
		if [[ -f .gitmodules ]]; then
			resetSubmodules
		fi
		popd >/dev/null
	else
		echo ">>> Skipping $dir (not a git repo)"
	fi
done

