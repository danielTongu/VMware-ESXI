<#
.SYNOPSIS
    VMware Management System - Main Entry Point
.DESCRIPTION
    Initializes the application environment and starts the user interface.
.NOTES
    Version: 1.0
    Author: Daniel Tongu
    Date: $(Get-Date -Format 'yyyy-MM-dd')
#>

# REQUIREMENTS CHECK
# Ensure PowerShell version 5.1 or later
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Error "This application requires PowerShell 5.1 or later. Current version: $($PSVersionTable.PSVersion)"
    exit 1
}

# Load required assemblies
try {
    Add-Type -AssemblyName 'System.Drawing'
    Add-Type -AssemblyName 'System.Windows.Forms'
} catch {
    Write-Error "Failed to load required .NET assemblies: $_"
    exit 1
}

# GLOBAL APPLICATION CONFIGURATION

$global:Theme = @{
    Primary       = [System.Drawing.Color]::FromArgb(128, 0, 32)  # Primary color (Burgundy)
    PrimaryDark   = [System.Drawing.Color]::FromArgb(37, 37, 38) # Primary dark variant (very dark gray)
    PrimaryDarker = [System.Drawing.Color]::FromArgb(45, 45, 48) # Primary darker variant (darkest gray)
    LightGray     = [System.Drawing.Color]::FromArgb(211, 211, 211)
    White         = [System.Drawing.Color]::White # Pure white (for backgrounds, highlights, text)
    Success       = [System.Drawing.Color]::FromArgb(0, 128, 0) # Green for success messages
    Warning       = [System.Drawing.Color]::FromArgb(192, 64, 0) # Dark orange for warnings
    Error         = [System.Drawing.Color]::FromArgb(180, 0, 0) # Dark red for errors
}


$global:Paths = @{
    ScriptRoot = $PSScriptRoot
    Credentials = "$env:APPDATA\VMwareManagement\credentials.xml"
}

$global:DeveloperMode = $true  # Set to $true to enable developer features

# GLOBAL APPLICATION STATE
$global:AppState = @{
    VMware = @{
        Connection = $null
        Server     = "csvcsa.cs.cwu.edu"  # Default server
        User       = $null
        Session    = $null
        LastConnection = $null
    }
    UI = @{
        MainForm = $null
    }
}

# LOAD DEPENDENCIES
$dependencyFiles = @(
    "$PSScriptRoot\Models\ConnectTo-VMServer.ps1",
    "$PSScriptRoot\Views\LoginView.ps1",
    "$PSScriptRoot\Views\MainView.ps1"
)

foreach ($file in $dependencyFiles) {
    try {
        if (Test-Path $file) {
            . $file
        } else {
            throw "File not found"
        }
    } catch {
        Write-Error "Failed to load dependency: $file - $_"
        exit 1
    }
}

# APPLICATION INITIALIZATION
function Initialize-Application {
    [CmdletBinding()]
    param()

    # Set console encoding to UTF-8
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

    # Create required directories
    $credDir = Split-Path $global:Paths.Credentials -Parent
    if (-not (Test-Path $credDir)) {
        try {
            New-Item -ItemType Directory -Path $credDir -Force | Out-Null
        } catch {
            Write-Warning "Failed to create credentials directory: $_"
        }
    }

    # Set TLS security protocol (required for some API connections)
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    } catch {
        Write-Warning "Failed to set TLS 1.2 protocol: $_"
    }
}

# MAIN EXECUTION FLOW
try {
    # Initialize application environment
    Initialize-Application

    # Launch main view, which handles login/logout and shell
    Show-MainView
} catch {
    # Handle any uncaught exceptions
    $errorMsg = "An unexpected error occurred: `n$($_.Exception.Message)`n`n$($_.ScriptStackTrace)"
    Write-Error $errorMsg
    
    [System.Windows.Forms.MessageBox]::Show(
        $errorMsg,
        "Critical Error",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    )
} finally {
    # Cleanup resources if needed
    if ($null -ne $global:AppState.VMware.Connection) {
        try {
            Disconnect-VIServer -Server $global:AppState.VMware.Connection -Confirm:$false
        } catch {
            Write-Warning "Failed to disconnect from VMware server: $_"
        }
    }
}

exit 0