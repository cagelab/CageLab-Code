function Write-Info($msg) { Write-Host "[INFO]  $msg" -ForegroundColor Cyan }
function Write-OK($msg) { Write-Host "[OK]    $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "[WARN]  $msg" -ForegroundColor Yellow }
function Write-ErrorMsg($msg) { Write-Host "[ERROR] $msg" -ForegroundColor Red }

#region by package manager
Write-Info "Installing core packages via winget..."
try {
    winget install Microsoft.PowerShell --accept-source-agreements --accept-package-agreements
    winget install NoMachine.NoMachine --accept-source-agreements --accept-package-agreements
    Write-OK "winget packages installed."
}
catch {
    Write-ErrorMsg "Failed to install winget packages: $_"
}

Write-Info "Setting execution policy to RemoteSigned for CurrentUser..."
try {
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    Write-OK "Execution policy set to RemoteSigned."
}
catch {
    Write-ErrorMsg "Failed to set execution policy: $_"
}

Write-Info "Installing Scoop..."
try {
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        Write-Warn "Scoop is already installed. Skipping installation."
    }
    else {
        Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
        Write-OK "Scoop installed."
    }
}
catch {
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        Write-Warn "Scoop appears to be already installed despite error. Skipping."
    }
    else {
        Write-ErrorMsg "Failed to install Scoop: $_"
    }
}

Write-Info "Adding Scoop buckets..."
try {
    scoop install git
    scoop bucket add extras
    scoop bucket add nerd-fonts
    Write-OK "Scoop buckets added."
}
catch {
    Write-ErrorMsg "Failed to add Scoop buckets: $_"
}

Write-Info "Installing packages via Scoop..."
$packages = @("netbird", "starship", "Maple-Mono-NF-CN", "nssm", "mediamtx", "obs-studio", "sunshine")
foreach ($pkg in $packages) {
    Write-Info "Installing $pkg..."
    try {
        scoop install $pkg
        Write-OK "$pkg installed."
    }
    catch {
        Write-ErrorMsg "Failed to install ${pkg}: $_"
    }
}

Write-Info "Installing cogmoteGO..."
try {
    Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/Ccccraz/cogmoteGO/main/install.ps1' | Invoke-Expression
    Write-OK "cogmoteGO installed."
}
catch {
    Write-ErrorMsg "Failed to install cogmoteGO: $_"
}
#endregion

#region by git clone
$parentDir = Join-Path $HOME "Code"

Write-Info "Ensuring code directory exists..."
if (!(Test-Path $parentDir)) {
    try {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        Write-OK "Created directory: $parentDir"
    }
    catch {
        Write-ErrorMsg "Failed to create directory ${parentDir}: $_"
    }
}
else {
    Write-OK "Directory already exists: $parentDir"
}

Write-Info "Preparing repositories list..."
$repos = @(
    "https://gitee.com/CogPlatform/Setup.git",
    "https://gitee.com/CogPlatform/Psychtoolbox.git",
    "https://gitee.com/CogPlatform/opticka.git",
    "https://gitee.com/CogPlatform/CageLab.git",
    "https://gitee.com/CogPlatform/matlab-jzmq.git",
    "https://gitee.com/CogPlatform/matmoteGO.git",
    "https://gitee.com/CogPlatform/PTBSimia.git"
)
foreach ($repo in $repos) {
    $repoName = [System.IO.Path]::GetFileNameWithoutExtension($repo)
    Write-Info "  - $repoName"
}

Write-Info "Starting clone process..."
foreach ($repo in $repos) {
    $repoName = [System.IO.Path]::GetFileNameWithoutExtension($repo)
    $targetPath = Join-Path $parentDir $repoName

    if (Test-Path $targetPath) {
        Write-Warn "Skipping $repoName (directory already exists)."
    }
    else {
        Write-Info "Cloning $repoName..."
        git clone --recurse-submodules --depth 1 $repo $targetPath
        if ($LASTEXITCODE -eq 0) {
            Write-OK "Successfully cloned $repoName."
        }
        else {
            Write-ErrorMsg "Failed to clone $repoName."
        }
    }
}

Write-OK "Clone process completed."
#endregion
