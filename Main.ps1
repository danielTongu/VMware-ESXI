<#
.SYNOPSIS
    Entry point for the VMware ESXi Dashboard GUI.
.DESCRIPTION
    Launches the login screen. If login succeeds, opens the main UI shell.
    All views and logic are loaded from the Views/ and VMwareModels.psm1 module.
#>

# Ensure required assemblies
Add-Type -AssemblyName 'System.Windows.Forms'
Add-Type -AssemblyName 'System.Drawing'

# Import core logic
Import-Module "$PSScriptRoot\VMwareModels.psm1" -ErrorAction Stop

# Launch main UI logic from Views/MainView.ps1
. "$PSScriptRoot\Views\MainView.ps1"

# Start the app
Show-MainView