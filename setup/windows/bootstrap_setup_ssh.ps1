function Write-Info($msg) { Write-Host "[INFO]  $msg" -ForegroundColor Cyan }
function Write-OK($msg) { Write-Host "[OK]    $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "[WARN]  $msg" -ForegroundColor Yellow }
function Write-ErrorMsg($msg) { Write-Host "[ERROR] $msg" -ForegroundColor Red }

#region setup power plan
# High Performance plan GUID
$highPerf = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"

# Switch to High Performance power plan
Write-Info "Setting power plan to High Performance..."
try {
    powercfg -setactive $highPerf
    Write-OK "Power plan set to High Performance."
}
catch {
    Write-ErrorMsg "Failed to set power plan: $_"
}

# Disable display turn off (AC/DC)
Write-Info "Setting display to never turn off..."
powercfg -change monitor-timeout-ac 0
powercfg -change monitor-timeout-dc 0
Write-OK "Display timeout set to Never."

# Disable sleep (AC/DC)
Write-Info "Disabling sleep..."
powercfg -change standby-timeout-ac 0
powercfg -change standby-timeout-dc 0
Write-OK "Sleep disabled."

# Disable hibernate
Write-Info "Disabling hibernate..."
try {
    powercfg -hibernate off
    Write-OK "Hibernate disabled."
}
catch {
    Write-ErrorMsg "Failed to disable hibernate: $_"
}

# Confirm current plan
Write-Info "Confirming active power plan..."
$activePlan = powercfg -getactivescheme
Write-OK "Current active power plan: $activePlan"
#endregion

#region setup network to private
Write-Info "Checking current network profiles..."
$netProfiles = Get-NetConnectionProfile
$changed = $false

foreach ($netProfile in $netProfiles) {
    if ($netProfile.NetworkCategory -ne 'Private') {
        Write-Warn "Network '$($netProfile.Name)' is set to '$($netProfile.NetworkCategory)'. Changing to 'Private'..."
        try {
            Set-NetConnectionProfile -Name $netProfile.Name -NetworkCategory Private -ErrorAction Stop
            Write-OK "Network '$($netProfile.Name)' successfully changed to 'Private'."
            $changed = $true
        }
        catch {
            Write-ErrorMsg "Failed to change network '$($netProfile.Name)': $_"
        }
    }
    else {
        Write-OK "Network '$($netProfile.Name)' is already 'Private'."
    }
}

if (-not $changed) {
    Write-Info "No network profiles required changes."
}
#endregion

#region setup OpenSSH Server
Write-Info "Checking OpenSSH Server capability..."
$capability = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*'

if ($capability.State -eq 'Installed') {
    Write-OK "OpenSSH Server is already installed."
}
else {
    Write-Warn "OpenSSH Server not found. Installing..."
    try {
        Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0 -ErrorAction Stop
        Write-OK "OpenSSH Server installation completed."
    }
    catch {
        Write-ErrorMsg "Failed to install OpenSSH Server: $_"
        exit 1
    }
}

Write-Info "Ensuring sshd service is running..."
try {
    Start-Service sshd -ErrorAction SilentlyContinue
    Set-Service -Name sshd -StartupType Automatic
    Write-OK "sshd service is running and set to Automatic."
}
catch {
    Write-ErrorMsg "Failed to configure sshd service: $_"
}

Write-Info "Checking Firewall rule for OpenSSH..."
if (!(Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue)) {
    Write-Warn "Firewall Rule not found. Creating..."
    try {
        New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' `
            -DisplayName 'OpenSSH Server (sshd)' `
            -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
        Write-OK "Firewall Rule created."
    }
    catch {
        Write-ErrorMsg "Failed to create Firewall Rule: $_"
    }
}
else {
    Write-OK "Firewall Rule already exists."
}
#endregion
