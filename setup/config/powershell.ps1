# PowerShell profile helpers mirroring the zsh update workflow
# Install:
#  New-Item -ItemType Directory -Path (Split-Path $PROFILE) -Force | Out-Null
#  Copy-Item -Path "C:\Code\Setup\config\powershell.psh" -Destination $PROFILE -Force

$ENV:HOME=$ENV:USERPROFILE
$ENV:USER=$ENV:USERNAME
$ENV:XDG_CONFIG_HOME=$ENV:USERPROFILE+"\.config"

$RepoPaths = @(
	"$HOME/.dotfiles",
	"$HOME/Code/Setup",
	"$HOME/Code/opticka",
	"$HOME/Code/PTBSimia",
	"$HOME/Code/matlab-jzmq",
	"$HOME/Code/matmoteGO",
	"$HOME/Code/CageLab",
	"$HOME/Code/Psychtoolbox",
	"$HOME/Code/Training",
	"$HOME/Code/Palamedes"
)

function update {
	Write-Host "`n=====>>> Start Update @ $(Get-Date) <<<=====" -ForegroundColor Cyan

	foreach ($repo in $RepoPaths) {
		if (-not (Test-Path (Join-Path $repo '.git'))) {
			continue
		}

		Write-Host "`n---> Updating $repo..." -ForegroundColor Green
		Push-Location $repo

		try {
			$currentBranch = (& git rev-parse --abbrev-ref HEAD).Trim()

			$dirty = (& git status --porcelain)
			if ($dirty) {
				$stashMessage = "Auto-stashed by PowerShell update $(Get-Date -Format 's')"
				& git stash push -u -m $stashMessage | Out-Null
				Write-Host "    Stashed local changes: $stashMessage" -ForegroundColor Yellow
			}

			if ($currentBranch -notmatch '^(master|main)$') {
				if ($repo -match 'fieldtrip') {
					& git checkout umaster | Out-Null
				} elseif ($repo -match 'Palamedes') {
					& git checkout main | Out-Null
				} else {
					& git checkout master | Out-Null
				}
			}

			& git pull
			& git status

			$remotes = (& git remote 2>$null)
			if ($remotes -and ($remotes -contains 'upstream')) {
				Write-Host "        ---> Fetching upstream..." -ForegroundColor Green
				& git fetch -v upstream
				if ($repo -notmatch 'Psychtoolbox') {
					& git merge --ff-only -v upstream/master
				}
			}

			if ($currentBranch -notmatch '^master$') {
				& git checkout $currentBranch | Out-Null
			}
		} catch {
			Write-Warning "Failed to update $($repo): $($_)"
		} finally {
			Pop-Location
		}
	}

	if (Get-Command winget -ErrorAction SilentlyContinue) {
		Write-Host "`n---> Updating system packages with winget..." -ForegroundColor Green
		winget upgrade --all --include-unknown --accept-source-agreements --accept-package-agreements
	} else {
		Write-Warning "winget not found; skipping system package updates."
	}

	Write-Host "`n=====>>> Finish Update @ $(Get-Date) <<<=====" -ForegroundColor Cyan
}

# ----- Convenience aliases mirroring Linux names (non-invasive) -----
Set-Alias ip a -ErrorAction SilentlyContinue  # placeholder to avoid muscle memory confusion
Set-Alias lsblk disks
Set-Alias df dfw
Set-Alias ifconfig netif

# ----- Basic quality-of-life -----
Set-PSReadLineOption -EditMode Emacs -HistoryNoDuplicates:$true -PredictionSource History
Set-Alias which Get-Command
Set-Alias ll Get-ChildItem
Set-Alias la 'Get-ChildItem -Force'

# ----- Version peek -----
function wver { $PSVersionTable; wsl -l -v 2>$null }
