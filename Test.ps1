<#
.SYNOPSIS
    ESXi Dashboard — View Tester.

.DESCRIPTION
    Loads and displays a single dashboard view or controller in a test harness form,
    initializing theme and global state, with hardcoded credentials.

.PARAMETER View
    The view or controller to load. If 'Main', loads the controller directly.
    Otherwise, wraps the view in a host form with a content panel.

.EXAMPLE
    .\Test-Views.ps1 -View Login
    .\Test-Views.ps1 -View Dashboard
    .\Test-Views.ps1 -View Main
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('Login', 'Main', 'Dashboard', 'Classes', 'Logs', 'Networks', 'Orphans', 'VMs')]
    [string]$View = 'Main'
)

# -------------------------------
# 1) Load Required Assemblies
# -------------------------------
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# -------------------------------
# 2) Initialize Theme
# -------------------------------
function Initialize-Theme {
    <#
    .SYNOPSIS
        Defines script-global UI theme colors.
    #>
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

# -------------------------------
# 3) Hardcoded Credentials (for testing)
# -------------------------------
$script:Username    = ''
$script:Password    = ''

# -------------------------------
# 4) Global State
# -------------------------------
$script:Server      = 'csvcsa.cs.cwu.edu'
$script:Connection  = $null
$script:LoginResult = $false

# -------------------------------
# 5) Resolve File Path
# -------------------------------
$fileName = $View -replace '\.ps1$', ''

# -------------------------------
# 6) Main = Controller, others = Views
# -------------------------------
if ($View -eq 'Main') {
    $controllersDir = Join-Path $PSScriptRoot 'Views'
    $controllerPath = Join-Path $controllersDir "$($fileName)View.ps1"

    # Ensure the controller script exists
    if (-not (Test-Path $controllerPath)) {
        Write-Error "❌ Controller script not found: $controllerPath"
        exit 1
    }

    # Load the main controller script
    . $controllerPath

    # Check if the New-AppWindow function exists
    if (Get-Command -Name New-AppWindow -ErrorAction SilentlyContinue) {
        $form = New-AppWindow # creates a form with a content panel, and stores it in $script:Form
        if (-not $form) {
            Write-Error "❌ Failed to create form in New-AppWindow"
            exit 1
        }

        $form.ShowDialog() | Out-Null
        $form.Dispose()

    } else {
        Write-Warning "ℹ️ 'New-AppWindow' not found in MainView.ps1"
    }

} elseif($View -eq 'Login') {
    $viewsDir       = Join-Path $PSScriptRoot 'Views'
    $viewPath       = Join-Path $viewsDir "$($fileName)View.ps1"

    # Ensure the view script exists
    if (-not (Test-Path $viewPath)) {
        Write-Error "❌ View script not found: $viewPath"
        exit 1
    }

    # Load the login view script
    . $viewPath

    # Check if the function exists
    $funcName = "Show-${fileName}View"
    if (-not (Get-Command -Name $funcName -ErrorAction SilentlyContinue)) {
        Write-Error "❌ Function '$funcName' not found in $viewPath"
        exit 1
    }

    # Invoke the login view function
    & $funcName

} else {
    $viewsDir       = Join-Path $PSScriptRoot 'Views'
    $viewPath       = Join-Path $viewsDir "$($fileName)View.ps1"

    # Ensure the view script exists
    if (-not (Test-Path $viewPath)) {
        Write-Error "❌ View script not found: $viewPath"
        exit 1
    }

    # Load the view script
    . $viewPath

    # Check if the function exists
    $funcName = "Show-${fileName}View"
    if (-not (Get-Command -Name $funcName -ErrorAction SilentlyContinue)) {
        Write-Error "❌ Function '$funcName' not found in $viewPath"
        exit 1
    }

    # Create test host form
    $Form = [System.Windows.Forms.Form]::new()
    $Form.Text = "Test View: $fileName"
    $Form.Size = [System.Drawing.Size]::new(1200, 600)
    $Form.MinimumSize = [System.Drawing.Size]::new(800, 600)
    $Form.StartPosition = 'CenterScreen'
    $Form.BackColor = $script:Theme.PrimaryDark

    # Create content panel
    $ContentPanel = [System.Windows.Forms.Panel]::new()
    $ContentPanel.Dock = 'Fill'
    $ContentPanel.BackColor = $script:Theme.PrimaryDarker
    $Form.Controls.Add($ContentPanel)

    # Invoke view function with injected panel
    & $funcName -ContentPanel $ContentPanel

    # Show the form
    try {
        $Form.ShowDialog() | Out-Null
    } finally {
        $Form.Dispose()
    }
}