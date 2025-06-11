Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Show-AppWindow {
    <#
    .SYNOPSIS
        Displays the main application window with sidebar navigation and content area.
    .DESCRIPTION
        Initializes and shows the main UI, automatically loading the dashboard view on startup.
    #>

    [CmdletBinding()]
    param()

    New-AppWindow
    [System.Windows.Forms.Application]::DoEvents()

    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 100
    $timer.Add_Tick({
        $timer.Stop()
        $timer.Dispose()
        $script:DashboardButton.PerformClick()
    })
    $timer.Start()

    $script:Form.ShowDialog()
}

function New-AppWindow {
    <#
    .SYNOPSIS
        Builds the main application layout and declares all key controls as script-scoped variables.
    .DESCRIPTION
        Creates the main form, sidebar, navigation buttons, and content area, assigning each to $script:<Component> for global access.
    #>

    [CmdletBinding()]
    param()

    $script:ActiveButton = $null

    $script:Form = New-Object System.Windows.Forms.Form
    $script:Form.Text = 'VMware ESXi Management Console'
    $script:Form.StartPosition = 'CenterScreen'
    $script:Form.Size = New-Object System.Drawing.Size(1150, 650)
    $script:Form.MinimumSize = New-Object System.Drawing.Size(850, 650)
    $script:Form.BackColor = $script:Theme.LightGray

    $splitContainer = New-Object System.Windows.Forms.SplitContainer
    $splitContainer.Dock = 'Fill'
    $splitContainer.FixedPanel = 'Panel1'
    $splitContainer.SplitterWidth = 1
    $script:Form.Controls.Add($splitContainer)

    $sidebar = New-Object System.Windows.Forms.Panel
    $sidebar.Dock = 'Fill'
    $sidebar.Autosize = $true
    $sidebar.AutoScroll = $true
    $sidebar.BackColor = $script:Theme.PrimaryDarker
    $splitContainer.Panel1.Controls.Add($sidebar)

    $sidebarLayout = New-Object System.Windows.Forms.TableLayoutPanel
    $sidebarLayout.Dock = 'Fill'
    $sidebarLayout.Autosize = $true
    $sidebarLayout.RowCount = 4
    $sidebarLayout.ColumnCount = 1
    $sidebar.Controls.Add($sidebarLayout)

    $script:TitleLabel = New-Object System.Windows.Forms.Label
    $script:TitleLabel.Dock = 'Fill'
    $script:TitleLabel.AutoSize = $true
    $script:TitleLabel.TextAlign = 'MiddleCenter'
    $script:TitleLabel.Text = 'VMware ESXi'
    $script:TitleLabel.Font = New-Object System.Drawing.Font('Segoe UI', 16, [System.Drawing.FontStyle]::Bold)
    $script:TitleLabel.ForeColor = $script:Theme.White
    $script:TitleLabel.Padding = New-Object System.Windows.Forms.Padding(10)
    $sidebarLayout.Controls.Add($script:TitleLabel, 0, 0)

    $logoPanel = New-Object System.Windows.Forms.Panel
    $logoPanel.Dock = 'Fill'
    $logoPanel.BackColor = [System.Drawing.Color]::Transparent
    try {
        $script:Logo = New-Object System.Windows.Forms.PictureBox
        $script:Logo.Dock = 'Fill'
        $script:Logo.Size = New-Object System.Drawing.Size(100, 100)
        $script:Logo.SizeMode = 'Zoom'
        $script:Logo.Image = [System.Drawing.Image]::FromFile("$PSScriptRoot\..\Images\login.png")
        $script:Logo.Padding = New-Object System.Windows.Forms.Padding(10)
        $logoPanel.Controls.Add($script:Logo)
    } catch {
        if ($script:Logo) { $script:Logo.Dispose() }
        $script:Icon = New-Object System.Windows.Forms.Label
        $script:Icon.Text = [char]0xE77B
        $script:Icon.Font = New-Object System.Drawing.Font('Segoe MDL2 Assets', 48)
        $script:Icon.ForeColor = $script:Theme.White
        $script:Icon.TextAlign = 'MiddleCenter'
        $script:Icon.Dock = 'Fill'
        $logoPanel.Controls.Add($script:Icon)
    }
    $sidebarLayout.Controls.Add($logoPanel, 0, 1)

    $script:UserLabel = New-Object System.Windows.Forms.Label
    $script:UserLabel.Dock = 'Fill'
    $script:UserLabel.AutoSize = $true
    $script:UserLabel.TextAlign = 'MiddleCenter'
    $script:UserLabel.Text = if ($script:Connection) { "$script:Username`n$script:Server" } else { "Not logged in" }
    $script:UserLabel.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Italic)
    $script:UserLabel.ForeColor = $script:Theme.White
    $script:UserLabel.Padding = New-Object System.Windows.Forms.Padding(10)
    $sidebarLayout.Controls.Add($script:UserLabel, 0, 2)

    $navPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $navPanel.Dock = 'Fill'
    $navPanel.FlowDirection = 'TopDown'
    $navPanel.WrapContents = $false
    $navPanel.AutoScroll = $true
    $navPanel.Autosize = $true
    $navPanel.Padding = New-Object System.Windows.Forms.Padding(10)
    $navPanel.BackColor = $script:Theme.PrimaryDark
    $sidebarLayout.Controls.Add($navPanel, 0, 3)

    $script:AuthButton = New-Object System.Windows.Forms.Button
    $script:AuthButton.Text = $(if ($script:Connection) { ' Logout' } else { ' Login' })
    $script:AuthButton.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
    $script:AuthButton.ForeColor = $script:Theme.White
    $script:AuthButton.BackColor = $script:Theme.PrimaryDarker
    $script:AuthButton.FlatStyle = 'Flat'
    $script:AuthButton.FlatAppearance.BorderSize = 1
    $script:AuthButton.FlatAppearance.BorderColor = if ($script:Connection) { $script:Theme.Error } else { $script:Theme.Success }
    $script:AuthButton.Size = New-Object System.Drawing.Size(200, 40)
    $script:AuthButton.TextAlign = 'MiddleLeft'
    $script:AuthButton.Margin = New-Object System.Windows.Forms.Padding(0, 5, 0, 5)
    $script:AuthButton.Padding = New-Object System.Windows.Forms.Padding(10, 0, 0, 0)
    $navPanel.Controls.Add($script:AuthButton)

    $script:ContentPanel = New-Object System.Windows.Forms.Panel
    $script:ContentPanel.Dock = 'Fill'
    $script:ContentPanel.Autosize = $true
    $script:ContentPanel.BackColor = $script:Theme.PrimaryDarker
    $script:ContentPanel.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    $script:ContentPanel.Padding = [System.Windows.Forms.Padding]::Empty
    $splitContainer.Panel2.Controls.Add($script:ContentPanel)

    $scriptDir = "$PSScriptRoot\..\Views" # Adjust path to your views directory
    $script:DashboardButton = New-NavButton -Text 'Dashboard' -ScriptPath "$scriptDir\DashboardView.ps1" -TargetPanel $script:ContentPanel
    $script:ClassesButton = New-NavButton -Text 'Class Manager' -ScriptPath "$scriptDir\ClassesView.ps1" -TargetPanel $script:ContentPanel
    $script:VMsButton = New-NavButton -Text 'Virtual Machines' -ScriptPath "$scriptDir\VMsView.ps1" -TargetPanel $script:ContentPanel
    $script:NetworksButton = New-NavButton -Text 'Network' -ScriptPath "$scriptDir\NetworksView.ps1" -TargetPanel $script:ContentPanel
    $script:OrphansButton = New-NavButton -Text 'Orphaned Files' -ScriptPath "$scriptDir\OrphansView.ps1" -TargetPanel $script:ContentPanel
    $script:LogsButton = New-NavButton -Text 'Logs' -ScriptPath "$scriptDir\LogsView.ps1" -TargetPanel $script:ContentPanel

    $navPanel.Controls.AddRange(@(
        $script:DashboardButton,
        $script:ClassesButton,
        $script:VMsButton,
        $script:NetworksButton,
        $script:OrphansButton,
        $script:LogsButton
    ))

    $splitContainer.SplitterDistance = 225

    $script:AuthButton.Add_Click({
        if ($script:Connection) {
            Disconnect-VIServer -Server $script:Connection -Confirm:$false -ErrorAction SilentlyContinue
            $this.Text = ' Login'
            $this.FlatAppearance.BorderColor = $script:Theme.Success
            $script:Connection = $null
            $script:Username = $null
            $script:UserLabel.Text = "Not logged in"
            $script:ContentPanel.Controls.Clear()
            $script:ContentPanel.BackColor = $script:Theme.PrimaryDark
        } else {
            . "$scriptDir\LoginView.ps1"

            if (Show-LoginView) {
                $this.Text = ' Logout'
                $this.FlatAppearance.BorderColor = $script:Theme.Error
                $script:UserLabel.Text = "$script:Username`n$script:Server"
                if ($script:ActiveButton) {
                    $script:ActiveButton.PerformClick()
                } else {
                    $script:DashboardButton.PerformClick()
                }
            } else {
                $script:Form.Close()
            }
        }

        [System.Windows.Forms.Application]::DoEvents()
    })

    $script:Form.Add_FormClosing({
        $r = [System.Windows.Forms.MessageBox]::Show(
            'Exit application?', 'Confirm',
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )
        if ($r -eq [System.Windows.Forms.DialogResult]::No) {
            $_.Cancel = $true
        } else {
            if ($script:Connection) {
                Disconnect-VIServer -Server $script:Connection -Confirm:$false -ErrorAction SilentlyContinue
            }
        }
    })
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

    if (-not (Test-Path $ScriptPath)) {
        throw "Script not found: $ScriptPath"
    }

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
    $btn.Text = " $Text"
    $btn.Font = New-Object System.Drawing.Font('Segoe UI',10)
    $btn.ForeColor = $script:Theme.White
    $btn.BackColor = $script:Theme.PrimaryDarker
    $btn.FlatStyle = 'Flat'
    $btn.FlatAppearance.BorderSize = 1
    $btn.FlatAppearance.BorderColor = $script:Theme.White
    $btn.FlatAppearance.MouseOverBackColor = $script:Theme.Primary
    $btn.Size = New-Object System.Drawing.Size(200,40)
    $btn.TextAlign = 'MiddleLeft'
    $btn.Margin = New-Object System.Windows.Forms.Padding(0,5,0,5)
    $btn.Padding = New-Object System.Windows.Forms.Padding(10,0,0,0)

    $btn.Tag = @{ Script = $ScriptPath; Panel = $TargetPanel }

    $btn.Add_Click({
        [System.Windows.Forms.Application]::DoEvents()

        $script:ActiveButton = $this
        $script:Form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor

        foreach ($ctrl in $this.Parent.Controls) {
            if ($ctrl -is [System.Windows.Forms.Button] -and $ctrl -ne $script:AuthButton) {
                $ctrl.BackColor = $script:Theme.PrimaryDarker
                $ctrl.FlatAppearance.BorderColor = $script:Theme.White
                $ctrl.Font = New-Object System.Drawing.Font('Segoe UI',10)
            }
        }

        $this.Font = New-Object System.Drawing.Font('Segoe UI',11,[System.Drawing.FontStyle]::Bold)
        $info = $this.Tag
        Load-ViewIntoPanel -ScriptPath $info.Script -TargetPanel $info.Panel
        $script:Form.Cursor = [System.Windows.Forms.Cursors]::Default
    })

    return $btn
}
