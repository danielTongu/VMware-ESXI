<#
.SYNOPSIS
    Main UI shell for the VMware Dashboard.
.DESCRIPTION
    Implements a two-pane WinForms layout:
    - Left: vertical navigation menu
    - Right: dynamic content panel for views (Dashboard, Classes, Networks, VMs)
    - Includes logout functionality that returns user to login screen
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# -------------------------------------------------------------------
# Loads a view script dynamically into the content panel.
# Looks for Show-View or Show-VMsView function in that script.
# -------------------------------------------------------------------
function Load-ViewIntoPanel {
    param (
        [string]$ScriptPath,
        [System.Windows.Forms.Panel]$TargetPanel
    )

    # Clear current UI elements from panel
    $TargetPanel.Controls.Clear()

    # Dot-source the target script
    . $ScriptPath

    # Check and call correct function to render view
    if (Get-Command Show-View -ErrorAction SilentlyContinue) {
        Show-View -ParentPanel $TargetPanel
    }
    elseif (Get-Command Show-VMsView -ErrorAction SilentlyContinue) {
        Show-VMsView -ContentPanel $TargetPanel
    }
    else {
        [System.Windows.Forms.MessageBox]::Show("Invalid view script: no Show-View or Show-VMsView found.","Load Error")
    }
}

# -------------------------------------------------------------------
# Wrapper for displaying the login dialog.
# Returns $true if login succeeded, $false otherwise.
# -------------------------------------------------------------------
function Show-Login {
    . "$PSScriptRoot\LoginView.ps1"
    return Show-LoginView
}

# -------------------------------------------------------------------
# Builds and displays the main navigation shell.
# Only invoked after successful login.
# -------------------------------------------------------------------
function Show-MainShell {
    # Create main window
    $form = New-Object Windows.Forms.Form
    $form.Text = "VMware ESXi Dashboard"
    $form.Size = New-Object Drawing.Size(1000, 640)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false

    # Left navigation panel
    $navPanel = New-Object Windows.Forms.Panel
    $navPanel.Dock = 'Left'
    $navPanel.Width = 180
    $navPanel.BackColor = [Drawing.Color]::SteelBlue
    $form.Controls.Add($navPanel)

    # Right dynamic content panel
    $contentPanel = New-Object Windows.Forms.Panel
    $contentPanel.Dock = 'Fill'
    $contentPanel.BackColor = [Drawing.Color]::WhiteSmoke
    $form.Controls.Add($contentPanel)

    # Reusable button factory for nav buttons
    function New-NavButton {
        param (
            [string]$text,
            [int]$top
        )

        $btn = New-Object Windows.Forms.Button
        $btn.Text = $text
        $btn.Size = New-Object Drawing.Size(150, 40)
        $btn.Location = New-Object Drawing.Point(15, $top)
        $btn.Font = New-Object Drawing.Font("Segoe UI", 10)
        return $btn
    }

    # Create all navigation buttons
    $btnDashboard = New-NavButton "Dashboard" 30
    $btnClass     = New-NavButton "Classes" 80
    $btnVMs       = New-NavButton "Virtual Machines" 130
    $btnNetwork   = New-NavButton "Networks" 180
    $btnLogout    = New-NavButton "Logout" 250
    $btnLogout.BackColor = [Drawing.Color]::IndianRed
    $btnLogout.ForeColor = [Drawing.Color]::White

    # Add buttons to nav panel
    $navPanel.Controls.AddRange(@(
        $btnDashboard, $btnClass, $btnVMs, $btnNetwork, $btnLogout
    ))

    # Event: Load Dashboard
    $btnDashboard.Add_Click({
        Load-ViewIntoPanel "$PSScriptRoot\DashboardView.ps1" $contentPanel
    })

    # Event: Load Class Manager
    $btnClass.Add_Click({
        Load-ViewIntoPanel "$PSScriptRoot\ClassManagerView.ps1" $contentPanel
    })

    # Event: Load VMs view
    $btnVMs.Add_Click({
        Load-ViewIntoPanel "$PSScriptRoot\VMsView.ps1" $contentPanel
    })

    # Event: Load Network Manager
    $btnNetwork.Add_Click({
        Load-ViewIntoPanel "$PSScriptRoot\NetworkManagerView.ps1" $contentPanel
    })

    # Event: Logout and return to login screen
    $btnLogout.Add_Click({
        $form.Close()
        Show-MainView
    })

    # Load default view (Dashboard)
    Load-ViewIntoPanel "$PSScriptRoot\DashboardView.ps1" $contentPanel

    # Display window
    $form.Topmost = $true
    $form.Add_Shown({ $form.Activate() })
    $form.ShowDialog()
}

# -------------------------------------------------------------------
# Entry Point: Show login first, then main UI if successful
# -------------------------------------------------------------------
function Show-MainView {
    if (Show-Login) {
        Show-MainShell
    } else {
        [System.Windows.Forms.MessageBox]::Show("Login cancelled. Exiting.","Authentication")
    }
}