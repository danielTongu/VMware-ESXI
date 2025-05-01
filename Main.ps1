<#
.SYNOPSIS
    Entry point for the VMware ESXi Dashboard GUI.
.DESCRIPTION
    Launches login (if enabled) and loads the main split-view UI with navigation and content panel.
#>

# -------------------------------------------------------------------
# Load required UI libraries
# -------------------------------------------------------------------
Add-Type -AssemblyName 'System.Windows.Forms'
Add-Type -AssemblyName 'System.Drawing'

# -------------------------------------------------------------------
# Import backend models and services
# -------------------------------------------------------------------
Import-Module ".\VMwareModels.psm1" -ErrorAction Stop

# -------------------------------------------------------------------
# Load the MainView.ps1 script that defines Show-MainView
# -------------------------------------------------------------------
. ".\Views\MainView.ps1"

# -------------------------------------------------------------------
# Launch the UI (Main shell or login + shell)
# -------------------------------------------------------------------
Show-MainView