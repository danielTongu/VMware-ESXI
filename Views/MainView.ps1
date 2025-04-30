<#
.SYNOPSIS
    Main VMware Shell UI with navigation and logout.
    
.DESCRIPTION
    Hosts Dashboard, Class Manager, Network Manager, and VMs view.
    Includes logout button that brings user back to login screen.
#>



Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing



# -------------------------------------------------------------------
# Helper: Load and invoke view function from external script
# -------------------------------------------------------------------
function Load-ViewIntoPanel {
    param (
        [string]$ScriptPath,
        [System.Windows.Forms.Panel]$TargetPanel
    )


    # Clear panel before loading
    $TargetPanel.Controls.Clear()


    # Dot-source and call entry-point
    . $ScriptPath
    if (Get-Command Show-View -ErrorAction SilentlyContinue) {
        Show-View -ParentPanel $TargetPanel
    } elseif (Get-Command Show-VMsView -ErrorAction SilentlyContinue) {
        Show-VMsView -ContentPanel $TargetPanel
    } else {
        [System.Windows.Forms.MessageBox]::Show("View script missing 'Show-View' function.","Error")
    }
}



# -------------------------------------------------------------------
# Show login prompt and return success/failure
# -------------------------------------------------------------------
function Show-Login {
    . "$PSScriptRoot\LoginView.ps1"
    return Show-LoginView
}



# -------------------------------------------------------------------
# Main UI shell logic
# -------------------------------------------------------------------
function Show-MainShell {
    # Create form
    $form = New-Object Windows.Forms.Form
    $form.Text = "VMware Management Shell"
    $form.Size = New-Object Drawing.Size(1000, 640)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false


    # Navigation panel (left)
    $navPanel = New-Object Windows.Forms.Panel
    $navPanel.Dock = 'Left'
    $navPanel.Width = 180
    $navPanel.BackColor = [Drawing.Color]::SteelBlue
    $form.Controls.Add($navPanel)


    # Content panel (right)
    $contentPanel = New-Object Windows.Forms.Panel
    $contentPanel.Dock = 'Fill'
    $contentPanel.BackColor = [Drawing.Color]::WhiteSmoke
    $form.Controls.Add($contentPanel)


    # Reusable button creator
    function New-NavButton {
        param ([string]$text, [int]$top)
        $btn = New-Object Windows.Forms.Button
        $btn.Text = $text
        $btn.Size = New-Object Drawing.Size(150, 40)
        $btn.Location = New-Object Drawing.Point(15, $top)
        $btn.Font = New-Object Drawing.Font("Segoe UI", 10)
        return $btn
    }


    # Navigation buttons
    $btnDashboard = New-NavButton "Dashboard" 30
    $btnClassMgr  = New-NavButton "Class Manager" 80
    $btnNetMgr    = New-NavButton "Network Manager" 130
    $btnVMs       = New-NavButton "VMs" 180
    $btnLogout    = New-NavButton "Logout" 250
    $btnLogout.BackColor = [System.Drawing.Color]::IndianRed
    $btnLogout.ForeColor = [System.Drawing.Color]::White

    $navPanel.Controls.AddRange(@(
        $btnDashboard, $btnClassMgr, $btnNetMgr, $btnVMs, $btnLogout
    ))


    # Button event handlers
    $btnDashboard.Add_Click({
        Load-ViewIntoPanel "$PSScriptRoot\DashboardView.ps1" $contentPanel
    })

    $btnClassMgr.Add_Click({
        Load-ViewIntoPanel "$PSScriptRoot\ClassManagerView.ps1" $contentPanel
    })

    $btnNetMgr.Add_Click({
        Load-ViewIntoPanel "$PSScriptRoot\NetworkManagerView.ps1" $contentPanel
    })

    $btnVMs.Add_Click({
        Load-ViewIntoPanel "$PSScriptRoot\VMsView.ps1" $contentPanel
    })

    $btnLogout.Add_Click({
        $form.Close()
        Show-MainView
    })


    # Load default view (Dashboard)
    Load-ViewIntoPanel "$PSScriptRoot\DashboardView.ps1" $contentPanel

    $form.Topmost = $true
    $form.Add_Shown({ $form.Activate() })
    $form.ShowDialog()
}



# -------------------------------------------------------------------
# Entry point: Show login, then main shell if successful
# -------------------------------------------------------------------
function Show-MainView {
    if (Show-Login) {
        Show-MainShell
    } else {
        [System.Windows.Forms.MessageBox]::Show("Authentication required. Closing.","Login Cancelled")
    }
}



# Start the app
Show-MainView