<#
.SYNOPSIS
    View Tester for ESXi Dashboard
.DESCRIPTION
    Allows testing individual views of the VMware management system in isolation.
.NOTES
    Usage: 
        1 - Open this script in PowerShell ISE or any text editor
        2 - Scroll to VIEW SELECTION, then uncomment the view you want to test
        3 - Type, .\Test.ps1 on the command line to run this script
        4 - The selected view will be displayed in a test form
        5 - Close the form to exit the test
        6 - Repeat for other views as needed
        7 - When done, comment out the view you want to test and save the script
#>


# -------------------- CONFIGURATION --------------------
$global:AppConfig = @{
    Theme = @{  
        Background     = [System.Drawing.Color]::FromArgb(250, 250, 250)
        Primary        = [System.Drawing.Color]::FromArgb(128, 0, 32)
        Secondary      = [System.Drawing.Color]::FromArgb(160, 160, 160)
        TextPrimary    = [System.Drawing.Color]::FromArgb(40, 40, 40)
        TextSecondary  = [System.Drawing.Color]::FromArgb(120, 120, 120)
        Error          = [System.Drawing.Color]::FromArgb(180, 0, 0)
        CardBackground = [System.Drawing.Color]::White
    }
    DeveloperMode = $true
}


$global:AppState = @{
    VMware = @{
        Connection = $null
        Server     = "csvcsa.cs.cwu.edu"
        User       = $null
        Session    = $null
        LastConnection = $null
    }
}


# -------------------- INITIALIZATION --------------------
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing


# -------------------- VIEW LOADING ----------------------
$viewPaths = @(
    ".\Main.ps1",
    ".\Views\LoginView.ps1",
    ".\Views\MainView.ps1",
    ".\Views\ClassesView.ps1",
    ".\Views\DashboardView.ps1",
    ".\Views\LogsView.ps1",
    ".\Views\NetworksView.ps1",
    ".\Views\OrphansView.ps1",
    ".\Views\VMsView.ps1"
)


foreach ($viewPath in $viewPaths) {
    try {
        if (Test-Path $viewPath) { . $viewPath } 
        else { Write-Warning "View not found: $viewPath"}
    } catch {
        Write-Error "Failed to load $viewPath : $_"
    }
}


# -------------------- TEST FORM SETUP --------------------
$testForm = New-Object System.Windows.Forms.Form
$testForm.Size = New-Object System.Drawing.Size(1200, 600)
$testForm.Text = "ESXi Dashboard - View Tester"
$testForm.StartPosition = 'CenterScreen'
$testForm.MinimumSize = New-Object System.Drawing.Size(800, 600)

# Add container panel
$panel = New-Object System.Windows.Forms.Panel
$panel.Dock = 'Fill'
$testForm.Controls.Add($panel)


# --------------------| VIEW SELECTION |--------------------
# ---------| Uncomment the view you want to test |----------
# ----------------------------------------------------------
# Show-LoginView -ContentPanel $panel
# Show-DashboardView -ContentPanel $panel
# Show-ClassesView -ContentPanel $panel
# Show-VMsView -ContentPanel $panel
Show-NetworksView -ContentPanel $panel
# Show-LogsView -ContentPanel $panel
# Show-OrphansView -ContentPanel $panel
# Show-MainView -ContentPanel $panel


# -------------------- APPLICATION RUN --------------------
$testForm.ShowDialog()
$testForm.Dispose()