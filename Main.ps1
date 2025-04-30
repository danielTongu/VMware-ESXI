<#
.SYNOPSIS
    Entry point for the VMware ESXi Dashboard GUI.
.DESCRIPTION
    Launches login. On success, opens the main UI with navigation and view loading.
#>

# Load WinForms UI support
Add-Type -AssemblyName 'System.Windows.Forms'
Add-Type -AssemblyName 'System.Drawing'

# Import models and services
Import-Module ".\VMwareModels.psm1" -ErrorAction Stop

# Load the main view logic (navigation + view loader)
. ".\Views\MainView.ps1"

# Launch application
Show-MainView