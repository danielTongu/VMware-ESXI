# ---------------------------------------------------------------------------
# Main.ps1 — Entry point for VMware ESXi Management UI.
# Loads required assemblies, sets up theme and state, handles login, and launches main UI.
# ---------------------------------------------------------------------------


# 0) Load required .NET assemblies for UI
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName Microsoft.VisualBasic


. "$PSScriptRoot\VMwareUtils.ps1"

# 1) Load PowerCLI (if not already)
if (-not (Initialize-PowerCLI)) {
    exit 1
}

# 2) Initialize Theme (script scope)
[hashtable] $script:Theme = @{
    Primary       = [System.Drawing.Color]::FromArgb(128,   0,  32)
    PrimaryDark   = [System.Drawing.Color]::FromArgb( 37,  37,  38)
    PrimaryDarker = [System.Drawing.Color]::FromArgb( 45,  45,  48)
    LightGray     = [System.Drawing.Color]::FromArgb(192, 192, 192)
    White         = [System.Drawing.Color]::White
    Success       = [System.Drawing.Color]::FromArgb(  0, 128,   0)
    Warning       = [System.Drawing.Color]::FromArgb(192,  64,   0)
    Error         = [System.Drawing.Color]::FromArgb(180,   0,   0)
}


# 3) Declare script-scoped state for the login UI
$script:Server      = 'csvcsa.cs.cwu.edu'   # default vCenter host
$script:Username    = ''                    # set by the login form
$script:Connection  = $null                 # set by the login form (will hold the VI.ServerConnection)
$script:LoginResult = $false                # set by the login form

# 4) Load and show login UI
. "$PSScriptRoot\Views\LoginView.ps1"
if (-not (Show-LoginView)) {
    Write-Host "Login canceled or failed."
    exit 0
}

# 5) Proceed to the UI for navigating views
. "$PSScriptRoot\Views\MainView.ps1"
Show-MainView

# 6) Clean up
if ($script:Connection) { Disconnect-VIServer -Server $script:Connection -Confirm:$false -ErrorAction SilentlyContinue }

# 7) Release resources or perform any additional cleanup here if needed
exit 0