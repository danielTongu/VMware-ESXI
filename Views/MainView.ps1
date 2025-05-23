# Required assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Show-MainView {
    <#
    .SYNOPSIS
        Displays the main application shell with auto-sized sidebar and content area.
    #>

    [CmdletBinding()]
    param()

    $script:ActiveButton = $null

    # Main window
    $main = New-Object System.Windows.Forms.Form
    $main.Text          = 'VMware ESXi Management Console'
    $main.StartPosition = 'CenterScreen'
    $main.Size          = New-Object System.Drawing.Size(1150,650)
    $main.MinimumSize   = New-Object System.Drawing.Size(850,650)
    $main.BackColor     = $script:Theme.LightGray

    # SplitContainer: Panel1 = sidebar, Panel2 = content
    $splitContainer = New-Object System.Windows.Forms.SplitContainer
    $splitContainer.Dock            = 'Fill'
    $splitContainer.FixedPanel      = 'Panel1'
    $splitContainer.SplitterWidth   = 1
    
    $main.Controls.Add($splitContainer)

    # -- Sidebar (Panel1) --
    $sidebar = New-Object System.Windows.Forms.Panel
    $sidebar.Dock      = 'Fill'
    $sidebar.BackColor = $script:Theme.PrimaryDarker
    $splitContainer.Panel1.Controls.Add($sidebar)

    # TableLayout: header + nav
    $sidebarLayout = New-Object System.Windows.Forms.TableLayoutPanel
    $sidebarLayout.Dock        = 'Fill'
    $sidebarLayout.RowCount    = 2
    $sidebarLayout.ColumnCount = 1
    $sidebarLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'Absolute',150))
    $sidebarLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'Percent',100))
    $sidebar.Controls.Add($sidebarLayout)

    # Header panel
    $sidebarHeader = New-Object System.Windows.Forms.Panel
    $sidebarHeader.Dock      = 'Fill'
    $sidebarHeader.BackColor = $script:Theme.PrimaryDark
    $sidebarLayout.Controls.Add($sidebarHeader,0,0)

    # Title label
    $title = New-Object System.Windows.Forms.Label
    $title.Text      = 'VMware ESXi'
    $title.Font      = New-Object System.Drawing.Font('Segoe UI',12,[System.Drawing.FontStyle]::Bold)
    $title.ForeColor = $script:Theme.White
    $title.AutoSize  = $true
    $title.Location  = New-Object System.Drawing.Point(10,10)
    $sidebarHeader.Controls.Add($title)

    # Logo
    $logo = New-Object System.Windows.Forms.PictureBox
    $logo.Size      = New-Object System.Drawing.Size(100,100)
    $logo.Location  = New-Object System.Drawing.Point(10,40)
    $logo.SizeMode  = 'Zoom'
    try {
        $logo.Image = [System.Drawing.Image]::FromFile("$PSScriptRoot\..\Images\login.png")
    } catch {
        $logo.BackColor = $script:Theme.LightGray
    }
    $sidebarHeader.Controls.Add($logo)

    # Navigation panel
    $navPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $navPanel.Dock          = 'Fill'
    $navPanel.FlowDirection = 'TopDown'
    $navPanel.WrapContents  = $false
    $navPanel.AutoScroll    = $true
    $navPanel.Padding       = New-Object System.Windows.Forms.Padding(10,20,10,20)
    $sidebarLayout.Controls.Add($navPanel,0,1)

    # set spliiter distance after finishing adding everything for panel1
    $splitContainer.SplitterDistance= 225

    # -- Content panel (Panel2) --
    $contentPanel = New-Object System.Windows.Forms.Panel
    $contentPanel.Dock      = 'Fill'
    $contentPanel.BackColor = $script:Theme.LightGray
    $splitContainer.Panel2.Controls.Add($contentPanel)

    # Load nav buttons
    $scriptDir = $PSScriptRoot
    $btnDashboard = New-NavButton -Text 'Dashboard'         -ScriptPath "$scriptDir\DashboardView.ps1" -TargetPanel $contentPanel
    $btnClasses   = New-NavButton -Text 'Class Manager'     -ScriptPath "$scriptDir\ClassesView.ps1"   -TargetPanel $contentPanel
    $btnVMs       = New-NavButton -Text 'Virtual Machines'  -ScriptPath "$scriptDir\VMsView.ps1"       -TargetPanel $contentPanel
    $btnNetworks  = New-NavButton -Text 'Network        '   -ScriptPath "$scriptDir\NetworksView.ps1"  -TargetPanel $contentPanel
    $btnOrphans   = New-NavButton -Text 'Orphaned Files'    -ScriptPath "$scriptDir\OrphansView.ps1"   -TargetPanel $contentPanel
    $btnLogs      = New-NavButton -Text 'Logs'              -ScriptPath "$scriptDir\LogsView.ps1"      -TargetPanel $contentPanel

    $navPanel.Controls.AddRange(@( $btnDashboard, $btnClasses, $btnVMs, $btnNetworks, $btnOrphans, $btnLogs ))

    # Authentication button
    $script:AuthButton = New-Object System.Windows.Forms.Button
    $script:AuthButton.Text      = $(if ($script:Connection) { ' Logout' } else {  'Login' })
    $script:AuthButton.Font      = New-Object System.Drawing.Font('Segoe UI',10,[System.Drawing.FontStyle]::Bold)
    $script:AuthButton.ForeColor = $script:Theme.White
    $script:AuthButton.BackColor = $script:Theme.PrimaryDarker
    $script:AuthButton.FlatStyle = 'Flat'
    $script:AuthButton.FlatAppearance.BorderSize  = 1
    $script:AuthButton.FlatAppearance.BorderColor = if ($script:Connection) { $script:Theme.Error } else { $script:Theme.Success }
    $script:AuthButton.Size      = New-Object System.Drawing.Size(200,40)
    $script:AuthButton.TextAlign = 'MiddleLeft'
    $script:AuthButton.Margin    = New-Object System.Windows.Forms.Padding(0,5,0,5)
    $script:AuthButton.Padding   = New-Object System.Windows.Forms.Padding(10,0,0,0)

    $navPanel.Controls.Add($script:AuthButton)

    # Auth button click handler
    $script:AuthButton.Add_Click({
        if ($script:Connection) {
            try { Disconnect-VIServer -Server $script:Connection -Confirm:$false -ErrorAction SilentlyContinue } catch {}
            $script:Connection = $null
            $this.Text = '   Login'
            $this.FlatAppearance.BorderColor = $script:Theme.Success
            $contentPanel.Controls.Clear()
        } else {
            . "$scriptDir\LoginView.ps1"

            if (Show-LoginView) {
                $this.Text = '   Logout'
                $this.FlatAppearance.BorderColor = $script:Theme.Error

                if ($script:ActiveButton) { 
                    $script:ActiveButton.PerformClick() 
                } else { 
                    $btnDashboard.PerformClick() 
                }
            } else {
                $main.Close()
            }
        }
    })

    # On load: show Dashboard
    $main.Add_Load({
        $btnDashboard.PerformClick()
    })

    # Confirm on close
    $main.Add_FormClosing({
        $r = [System.Windows.Forms.MessageBox]::Show(
            'Exit application?', 'Confirm',
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )
        if ($r -eq [System.Windows.Forms.DialogResult]::No) {
            $_.Cancel = $true
        } else {
            if ($script:Connection) {
                try { Disconnect-VIServer -Server $script:Connection -Confirm:$false -ErrorAction SilentlyContinue } catch {}
            }
        }
    })

    [System.Windows.Forms.Application]::EnableVisualStyles()
    $main.ShowDialog() | Out-Null
}


function Load-ViewIntoPanel {
    <#
    .SYNOPSIS
        Loads a view script into the content panel.
    .PARAMETER ScriptPath
        Full path to the .ps1 view script.
    .PARAMETER TargetPanel
        The panel where the view will render.
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ScriptPath,
        [Parameter(Mandatory)][System.Windows.Forms.Panel]$TargetPanel
    )

    $TargetPanel.Controls.Clear()
    
    if (-not (Test-Path $ScriptPath)) { throw "Script not found: $ScriptPath" }
    . $ScriptPath
    $viewFuncs = @('Show-DashboardView','Show-VMsView','Show-ClassesView','Show-NetworksView','Show-OrphansView','Show-LogsView')
    
    foreach ($f in $viewFuncs) {
        if (Get-Command $f -ErrorAction SilentlyContinue) {
            & $f -ContentPanel $TargetPanel
            return
        }
    }

    throw "No view function found in $ScriptPath"
}


function New-NavButton {
    <#
    .SYNOPSIS
        Creates a navigation button that loads a view when clicked.
    .PARAMETER Text
        The button label.
    .PARAMETER ScriptPath
        Path to associated view script.
    .PARAMETER TargetPanel
        The panel to load the view into.
    .OUTPUTS
        System.Windows.Forms.Button
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][string]$ScriptPath,
        [Parameter(Mandatory)][System.Windows.Forms.Panel]$TargetPanel
    )

    $btn = New-Object System.Windows.Forms.Button
    $btn.Text      = "   $Text"
    $btn.Font      = New-Object System.Drawing.Font('Segoe UI',10)
    $btn.ForeColor = $script:Theme.White
    $btn.BackColor = $script:Theme.PrimaryDarker
    $btn.FlatStyle= 'Flat'
    $btn.FlatAppearance.BorderSize      = 1
    $btn.FlatAppearance.BorderColor     = $script:Theme.White
    $btn.FlatAppearance.MouseOverBackColor = $script:Theme.Primary
    $btn.Size      = New-Object System.Drawing.Size(200,40)
    $btn.TextAlign = 'MiddleLeft'
    $btn.Margin    = New-Object System.Windows.Forms.Padding(0,5,0,5)
    $btn.Padding   = New-Object System.Windows.Forms.Padding(10,0,0,0)

    # Store script and panel
    $btn.Tag = @{ Script = $ScriptPath; Panel = $TargetPanel }

    # Click handler
    $btn.Add_Click({
        foreach ($ctrl in $this.Parent.Controls) {
            if ($ctrl -is [System.Windows.Forms.Button] -and $ctrl -ne $script:AuthButton) {
                $ctrl.BackColor = $script:Theme.PrimaryDarker
                $ctrl.FlatAppearance.BorderColor = $script:Theme.White
                $ctrl.Font = New-Object System.Drawing.Font('Segoe UI',10)
            }
        }
        $this.FlatAppearance.BorderColor = $script:Theme.White
        $this.Font = New-Object System.Drawing.Font('Segoe UI',10,[System.Drawing.FontStyle]::Bold)
        $script:ActiveButton = $this

        $info = $this.Tag
        Load-ViewIntoPanel -ScriptPath $info.Script -TargetPanel $info.Panel
    })

    return $btn
}
