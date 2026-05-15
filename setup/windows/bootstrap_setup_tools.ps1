param(
    [Parameter(Mandatory = $true)]
    [string]$SetupKey
)
function Write-Info($msg) { Write-Host "[INFO]  $msg" -ForegroundColor Cyan }
function Write-OK($msg) { Write-Host "[OK]    $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "[WARN]  $msg" -ForegroundColor Yellow }
function Write-ErrorMsg($msg) { Write-Host "[ERROR] $msg" -ForegroundColor Red }

#region setup mediamtx
$mediamtxService = "mediamtx"

Write-Info "Checking if $mediamtxService service already exists..."
if (Get-Service -Name $mediamtxService -ErrorAction SilentlyContinue) {
    Write-Warn "$mediamtxService service already exists. Skipping installation."
}
else {
    Write-Info "Installing $mediamtxService service with NSSM..."
    try {
        nssm install $mediamtxService (Join-Path $HOME "scoop/shims/mediamtx.exe")
        nssm set $mediamtxService AppDirectory (Join-Path $HOME "scoop/persist/mediamtx")
        Write-OK "$mediamtxService service installed and configured."
    }
    catch {
        Write-ErrorMsg "Failed to install $mediamtxService service: $_"
    }
}

Write-Info "Starting $mediamtxService service..."
try {
    Start-Service -Name $mediamtxService -ErrorAction Stop
    Write-OK "$mediamtxService service started."
}
catch {
    Write-ErrorMsg "Failed to start $mediamtxService service: $_"
}
#endregion

#region setup obs-studio
$obsSource = Join-Path $HOME "Code\Setup\.dotfile\obs\start.ps1"
$taskName  = "OBS-StartupMonitor"

Write-Info "Checking if scheduled task '$taskName' exists..."
if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
    Write-Warn "Scheduled task '$taskName' already exists. Updating..."
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
}

try {
    $action   = New-ScheduledTaskAction -Execute "pwsh.exe" -Argument "-WindowStyle Hidden -File `"$obsSource`""
    $trigger  = New-ScheduledTaskTrigger -AtLogOn
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -RunLevel Highest | Out-Null
    Write-OK "Scheduled task '$taskName' registered."

    Write-Info "Running scheduled task '$taskName' immediately..."
    Start-ScheduledTask -TaskName $taskName
    Write-OK "Scheduled task '$taskName' started."
}
catch {
    Write-ErrorMsg "Failed to configure OBS scheduled task: $_"
}
#endregion

#region setup netbird
Write-Info "Checking if netbird service is installed..."
if (Get-Service -Name "netbird" -ErrorAction SilentlyContinue) {
    Write-Warn "netbird service already installed."
}
else {
    Write-Info "Installing netbird service..."
    try {
        netbird service install
        Write-OK "netbird service installed."
    }
    catch {
        Write-ErrorMsg "Failed to install netbird service: $_"
    }
}

Write-Info "Starting netbird service..."
try {
    netbird service start
    Write-OK "netbird service started."
}
catch {
    Write-ErrorMsg "Failed to start netbird service: $_"
}

Write-Info "Running netbird up with setup key..."
try {
    netbird up --setup-key $SetupKey
    Write-OK "netbird configured successfully."
}
catch {
    Write-ErrorMsg "Failed to configure netbird: $_"
}
#endregion

#region setup cogmoteGO
Write-Info "Checking if cogmoteGO service is installed..."
if (Get-Service -Name "cogmoteGO" -ErrorAction SilentlyContinue) {
    Write-Warn "cogmoteGO service already exists."
}
else {
    Write-Info "Installing cogmoteGO service..."
    try {
        cogmoteGO service
        Write-OK "cogmoteGO service installed."
    }
    catch {
        Write-ErrorMsg "Failed to install cogmoteGO service: $_"
    }
}

Write-Info "Starting cogmoteGO service..."
try {
    cogmoteGO service start
    Write-OK "cogmoteGO service started."
}
catch {
    Write-ErrorMsg "Failed to start cogmoteGO service: $_"
}
#endregion
