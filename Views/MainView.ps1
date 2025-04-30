<#
.SYNOPSIS
    Main UI shell for the VMware Dashboard.
.DESCRIPTION
    Uses a SplitContainer to separate the navigation (left) and content (right).
    Navigation buttons load each view dynamically.
    Includes logout functionality and optional login enforcement.
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# -------------------------------------------------------------------
# Dynamically load a view script and render it inside the content panel
# -------------------------------------------------------------------
function Load-ViewIntoPanel {
    param (
        [string]$ScriptPath,
        [System.Windows.Forms.Panel]$TargetPanel
    )

    # Clear previous controls from the panel
    $TargetPanel.Controls.Clear()

    # Dot-source the view script
    . $ScriptPath

    # Run known view entry point (Show-View or Show-VMsView)
    if (Get-Command Show-View -ErrorAction SilentlyContinue) {
        Show-View -ParentPanel $TargetPanel
    }
    elseif (Get-Command Show-VMsView -ErrorAction SilentlyContinue) {
        Show-VMsView -ContentPanel $TargetPanel
    }
    else {
        [System.Windows.Forms.MessageBox]::Show(
            "Invalid view script: no Show-View or Show-VMsView defined.",
            "View Load Error"
        )
    }
}

# -------------------------------------------------------------------
# Wraps login logic using LoginView.ps1
# -------------------------------------------------------------------
function Show-Login {
    . "$PSScriptRoot\LoginView.ps1"
    return Show-LoginView
}

# -------------------------------------------------------------------
# Creates and displays the main UI shell with navigation and content
# -------------------------------------------------------------------
function Show-MainShell {
    # Create main application form
    $form = New-Object Windows.Forms.Form
    $form.Text            = "VMware ESXi Dashboard"
    $form.Size            = New-Object Drawing.Size(1100, 700)
    $form.StartPosition   = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox     = $false

    # Setup split container layout
    $split = New-Object Windows.Forms.SplitContainer
    $split.Dock              = 'Fill'
    $split.Orientation       = 'Vertical'
    $split.SplitterDistance  = 200
    $split.IsSplitterFixed   = $true
    $form.Controls.Add($split)

    # Style navigation panel (Panel1)
    $split.Panel1.BackColor = [Drawing.Color]::SteelBlue

    # Style content area (Panel2)
    $split.Panel2.BackColor = [Drawing.Color]::WhiteSmoke

    # Helper to create a nav button
    function New-NavButton {
        param (
            [string]$text,
            [int]$top
        )
        $btn = New-Object Windows.Forms.Button
        $btn.Text     = $text
        $btn.Size     = New-Object Drawing.Size(160, 40)
        $btn.Location = New-Object Drawing.Point(20, $top)
        $btn.Font     = New-Object Drawing.Font("Segoe UI", 10)
        return $btn
    }

    # Define all navigation buttons
    $btnDashboard = New-NavButton "Dashboard"        30
    $btnClass     = New-NavButton "Classes"          80
    $btnVMs       = New-NavButton "Virtual Machines" 130
    $btnNetwork   = New-NavButton "Networks"         180
    $btnLogout    = New-NavButton "Logout"           250
    $btnLogout.BackColor = [Drawing.Color]::IndianRed
    $btnLogout.ForeColor = [Drawing.Color]::White

    # Add buttons to the nav panel
    $split.Panel1.Controls.AddRange(@(
        $btnDashboard, $btnClass, $btnVMs, $btnNetwork, $btnLogout
    ))

    # Button click: Dashboard
    $btnDashboard.Add_Click({
        Load-ViewIntoPanel "$PSScriptRoot\DashboardView.ps1" $split.Panel2
    })

    # Button click: Class Manager
    $btnClass.Add_Click({
        Load-ViewIntoPanel "$PSScriptRoot\ClassManagerView.ps1" $split.Panel2
    })

    # Button click: VM Manager
    $btnVMs.Add_Click({
        Load-ViewIntoPanel "$PSScriptRoot\VMsView.ps1" $split.Panel2
    })

    # Button click: Network Manager
    $btnNetwork.Add_Click({
        Load-ViewIntoPanel "$PSScriptRoot\NetworkManagerView.ps1" $split.Panel2
    })

    # Button click: Logout and restart MainView
    $btnLogout.Add_Click({
        $form.Close()
        Show-MainView
    })

    # Load default view (Dashboard) on start
    Load-ViewIntoPanel "$PSScriptRoot\DashboardView.ps1" $split.Panel2

    # Show the form
    $form.Topmost = $true
    $form.Add_Shown({ $form.Activate() })
    $form.ShowDialog()
}

# -------------------------------------------------------------------
# Entry Point: show login (optional) then shell
# -------------------------------------------------------------------
function Show-MainView {
    # For production:
    # if (Show-Login) {
    #     Show-MainShell
    # } else {
    #     [System.Windows.Forms.MessageBox]::Show("Login cancelled. Exiting.","Authentication")
    # }

    # For development:
    Show-MainShell
}