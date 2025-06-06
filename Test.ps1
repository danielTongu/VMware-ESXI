<#
.SYNOPSIS
    ESXi Dashboard — View Tester.
.DESCRIPTION
    Loads and displays a single dashboard “view” or the login dialog in a WinForms host form,
    with hardcoded credentials and theme initialization for testing.
.PARAMETER View
    Name of the view to load and display.
    Valid options: Login, Dashboard, Classes, Logs, Networks, Orphans, VMs.
.EXAMPLE
    # Test the Login dialog:
    .\Test-Views.ps1 -View Login
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('Login', 'Main', 'Dashboard','Classes','Logs','Networks','Orphans','VMs')]
    [string]$View = 'Main'
)


# 1) Load WinForms assemblies
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


# 3) Hardcoded credentials for test
$script:username    = ''   # optional pre-fill
$script:password    = ''   # optional pre-fill


# 4) Script-scoped state
$script:Server      = 'csvcsa.cs.cwu.edu'
$script:Connection  = $null
$script:LoginResult = $false


# 5) Configure view directory & mapping
$script:ViewDirectory = Join-Path $PSScriptRoot 'Views'
$script:ViewMap = @{
    Login     = 'LoginView.ps1'
    Main      = 'MainView.ps1'
    Dashboard = 'DashboardView.ps1'
    Classes   = 'ClassesView.ps1'
    Logs      = 'LogsView.ps1'
    Networks  = 'NetworksView.ps1'
    Orphans   = 'OrphansView.ps1'
    VMs       = 'VMsView.ps1'
}


# 6) Dot-source the selected view script into this script scope
$viewScript = Join-Path $script:ViewDirectory $script:ViewMap[$View]
if (-not (Test-Path $viewScript)) {
    Write-Error "View script not found: $viewScript"
    exit 1
}
. $viewScript


# 7) Show the selected view
$fn = "Show-${View}View"

if ($View -eq 'Login' -or $View -eq 'Main') {
    # For Login or Main, call the view function directly (these manage their own forms)
    if (Get-Command $fn -ErrorAction SilentlyContinue) {
        & $fn
    } else {
        Write-Error "Function $fn not found in view script."
        exit 1
    }
} else {
    # For other views, create a host form and panel, then inject the view into the panel
    $testForm = [System.Windows.Forms.Form]::new()
    $testForm.Text          = "ESXi Dashboard — Testing '$View' View"
    $testForm.StartPosition = 'CenterScreen'
    $testForm.MinimumSize   = [System.Drawing.Size]::new(800,600)
    $testForm.Size          = [System.Drawing.Size]::new(1200,600)

    $panel = [System.Windows.Forms.Panel]::new()
    $panel.Dock = 'Fill'
    $testForm.Controls.Add($panel)

    if (Get-Command $fn -ErrorAction SilentlyContinue) {
        & $fn -ContentPanel $panel
    } else {
        Write-Error "Function $fn not found in view script."
        exit 1
    }
    # Show the form and clean up after closing
    $testForm.ShowDialog() | Out-Null
    $testForm.Dispose()
}
