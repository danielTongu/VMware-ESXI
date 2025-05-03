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
    $form = New-Object Windows.Forms.Form
    $form.Text            = "VMware ESXi Dashboard"
    $form.Size            = New-Object Drawing.Size(1100, 700)
    $form.StartPosition   = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox     = $false

    $split = New-Object Windows.Forms.SplitContainer
    $split.Dock              = 'Fill'
    $split.Orientation       = 'Vertical'
    $split.SplitterDistance  = 30 # << NARROWER LEFT NAVIGATION
    $split.IsSplitterFixed   = $true
    $form.Controls.Add($split)

    # Style navigation panel
    $split.Panel1.BackColor = [Drawing.Color]::LightGray

    # Replace Panel2 with a scrollable panel
    $scrollableContent = New-Object Windows.Forms.Panel
    $scrollableContent.Dock        = 'Fill'
    $scrollableContent.AutoScroll  = $true
    $scrollableContent.BackColor   = [Drawing.Color]::WhiteSmoke

    # Remove Panel2 controls and add scrollable content panel
    $split.Panel2.Controls.Clear()
    $split.Panel2.Controls.Add($scrollableContent)

    # Navigation button helper
    function New-NavButton {
        param ([string]$text, [int]$top)
        $btn = New-Object Windows.Forms.Button
        $btn.Text     = $text
        $btn.Size     = New-Object Drawing.Size(130, 40)
        $btn.Location = New-Object Drawing.Point(15, $top)
        $btn.Font     = New-Object Drawing.Font("Segoe UI", 9)
        return $btn
    }

    # Buttons
    $btnDashboard = New-NavButton "Dashboard"        30
    $btnClass     = New-NavButton "Classes"          80
    $btnVMs       = New-NavButton "Virtual Machines" 130
    $btnNetwork   = New-NavButton "Networks"         180
    $btnLogout    = New-NavButton "Logout"           250
    $btnLogout.BackColor = [Drawing.Color]::IndianRed
    $btnLogout.ForeColor = [Drawing.Color]::White

    $split.Panel1.Controls.AddRange(@(
        $btnDashboard, $btnClass, $btnVMs, $btnNetwork, $btnLogout
    ))

    # View navigation
    $btnDashboard.Add_Click({
        Load-ViewIntoPanel "$PSScriptRoot\DashboardView.ps1" $scrollableContent
    })
    $btnClass.Add_Click({
        Load-ViewIntoPanel "$PSScriptRoot\ClassManagerView.ps1" $scrollableContent
    })
    $btnVMs.Add_Click({
        Load-ViewIntoPanel "$PSScriptRoot\VMsView.ps1" $scrollableContent
    })
    $btnNetwork.Add_Click({
        Load-ViewIntoPanel "$PSScriptRoot\NetworkManagerView.ps1" $scrollableContent
    })
    $btnLogout.Add_Click({
        $form.Close()
        Show-MainView
    })

    # Default view
    Load-ViewIntoPanel "$PSScriptRoot\DashboardView.ps1" $scrollableContent

    $form.Topmost = $true
    $form.Add_Shown({ $form.Activate() })
    $form.ShowDialog()
}

# -------------------------------------------------------------------
# Entry Point: show login (optional) then shell
# -------------------------------------------------------------------
function Show-MainView {
    # For production 
     if (Show-Login) {
         Show-MainShell
     } else {
         [System.Windows.Forms.MessageBox]::Show("Login cancelled. Exiting.","Authentication")
    }

    # Uncomment the following line to skip login for development and directly show the main shell.
    #Show-MainShell
}