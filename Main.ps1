<#
.SYNOPSIS
    VMware Management — Main Entry.
.DESCRIPTION
    Checks for PowerCLI installation, prompts to install if needed,
    loads assemblies & theme, declares script-scoped state,
    dot-sources the login UI, invokes login, then proceeds if authenticated.
#>



# ---------------------------------------------------------------------------
# Check and Install PowerCLI if needed
# ---------------------------------------------------------------------------
function Install-PowerCLIIfNeeded {
    # Check if PowerCLI is already installed
    if (Get-Module -Name VMware.PowerCLI -ListAvailable) {
        return $true
    }

    # Create GUI prompt to ask for installation
    Add-Type -AssemblyName System.Windows.Forms
    $result = [System.Windows.Forms.MessageBox]::Show(
        "VMware PowerCLI is not installed. Would you like to install it now?",
        "Install PowerCLI",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )

    if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
        try {
            Write-Host "Installing VMware PowerCLI..."
            Install-Module -Name VMware.PowerCLI -Force -AllowClobber -Scope CurrentUser -ErrorAction Stop
            Import-Module -Name VMware.PowerCLI -ErrorAction Stop
            Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false | Out-Null
            return $true
        } catch {
            [System.Windows.Forms.MessageBox]::Show(
                "Failed to install PowerCLI: $_",
                "Installation Error",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
            return $false
        }
    }
    
    return $false
}

# Check and install PowerCLI if needed
if (-not (Install-PowerCLIIfNeeded)) {
    exit 1
}



# ---------------------------------------------------------------------------
# Main Script Execution
# ---------------------------------------------------------------------------

# 1) Load Required Assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# 2) Initialize Theme (script scope)
function Initialize-Theme {
    <# .SYNOPSIS Defines UI color palette #>
    $script:Theme = @{
        Primary       = [System.Drawing.Color]::FromArgb(128,   0,  32)
        PrimaryDark   = [System.Drawing.Color]::FromArgb( 37,  37,  38)
        PrimaryDarker = [System.Drawing.Color]::FromArgb( 45,  45,  48)
        LightGray     = [System.Drawing.Color]::FromArgb(192, 192, 192)
        White         = [System.Drawing.Color]::White
        Success       = [System.Drawing.Color]::FromArgb(  0, 128,   0)
        Warning       = [System.Drawing.Color]::FromArgb(192,  64,   0)
        Error         = [System.Drawing.Color]::FromArgb(180,   0,   0)
    }
}
Initialize-Theme

# 3) Declare script-scoped state for the login UI
$script:Server      = 'csvcsa.cs.cwu.edu'  # default vCenter host
$script:username    = ''                   # optional pre-fill
$script:password    = ''                   # optional pre-fill
$script:Connection  = $null                # will hold the VI.ServerConnection
$script:LoginResult = $false               # set by the login form

# 4) Dot-source and invoke the login UI
. "$PSScriptRoot\Views\LoginView.ps1"
if (-not (Show-LoginView)) {
    Write-Host "Login canceled or failed."
    exit 0
}

# 5) If we get here, $script:Connection is live
Write-Host "✅ Connected to $script:Server as $($script:Connection.UserName)"

# 6) Proceed to the UI for navigating views
. "$PSScriptRoot\Views\MainView.ps1"
Show-MainView

# 7) Clean up
if ($script:Connection) {
    Disconnect-VIServer -Server $script:Connection -Confirm:$false -ErrorAction SilentlyContinue
}
exit 0