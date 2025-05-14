# Required assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing


$global:ActiveButton = $null



<#
    .SYNOPSIS
    Displays the main view after successful login.
    .DESCRIPTION
    Loads and shows the login dialog, then the main shell on success.
#>
function Show-MainView {
    . "$PSScriptRoot\LoginView.ps1"

    # If not already logged in, show the login form
    if (-not $global:IsLoggedIn) {
        if (-not (Show-LoginView)) {
            [System.Windows.Forms.MessageBox]::Show(
                'Login cancelled or failed.',
                'Authentication',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
            return
        }
    }

    # If login succeeded or already logged in, show main shell
    Show-MainShell
}




<#
.SYNOPSIS
  Updates the status bar with connection info.
.PARAMETER StatusPanel
  The StatusBarPanel to update.
#>
function Update-StatusBar {
    param(
        [Parameter(Mandatory)]
        [System.Windows.Forms.StatusBarPanel]$StatusPanel
    )
    try {
        $c = [VMServerConnection]::GetInstance().GetConnection()
        if ($null -ne $c) {
            try {
                $h = Get-VMHost -Server $c -ErrorAction Stop
                $StatusPanel.Text = "Connected: $($h.Name) | Ver: $($h.Version) | User: $($c.User) | $(Get-Date -Format 'G')"
            } catch {
                Write-Host "Error retrieving host info: $($_.Exception.Message)" -ForegroundColor Red
                $StatusPanel.Text = "Connected, but host data failed | $(Get-Date -Format 'G')"
            }
        } else {
            $StatusPanel.Text = "Offline mode | $(Get-Date -Format 'G')"
        }
    } catch {
        Write-Host "Unexpected error in Update-StatusBar: $($_.Exception.Message)" -ForegroundColor Red
        $StatusPanel.Text = "Status error | $(Get-Date -Format 'G')"
    }
}



<#
    .SYNOPSIS
    Loads a view script into the content panel.
    .PARAMETER ScriptPath
    Path to the view script (.ps1).
    .PARAMETER TargetPanel
    Panel where the view will be rendered.
#>
function Load-ViewIntoPanel {
    param(
        [Parameter(Mandatory)][string]$ScriptPath,
        [Parameter(Mandatory)][System.Windows.Forms.Panel]$TargetPanel
    )

    $TargetPanel.Controls.Clear()

    try {
        if (-not (Test-Path $ScriptPath)) {
            throw "Script not found: $ScriptPath"
        }

        . $ScriptPath

        $viewFunctions = @('Show-DashboardView','Show-ClassesView','Show-VMsView','Show-NetworksView','Show-OrphansView','Show-LogsView')
        $matched = $false

        foreach ($func in $viewFunctions) {
            if (Get-Command $func -ErrorAction SilentlyContinue) {
                & $func -ContentPanel $TargetPanel
                $matched = $true
                break
            }
        }

        if (-not $matched) { 
            throw "No recognized view function found in: $ScriptPath" 
        }
    } catch {
        Write-Host "`n[ERROR LOADING VIEW]`nScriptPath: $ScriptPath`nError: $($_.Exception.Message)`n$($_.ScriptStackTrace)`n" -ForegroundColor Red
        
        [System.Windows.Forms.MessageBox]::Show(
            "Unable to load view. Please try again or contact support.",
            "View Load Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )

        $errorLabel = New-Object System.Windows.Forms.Label
        $errorLabel.Text = "Error loading view."
        $errorLabel.ForeColor = $global:Theme.Error
        $errorLabel.AutoSize = $true
        $errorLabel.Location = New-Object System.Drawing.Point(20, 20)

        $TargetPanel.Controls.Add($errorLabel)
    }
}



<#
    .SYNOPSIS
    Creates a navigation button with event handling.
    .PARAMETER Text
    Button text.
    .PARAMETER ScriptPath
    Path to the view script.
    .PARAMETER TargetPanel
    Panel to load content.
#>
function New-NavButton {
    param(
        [string]$Text,
        [string]$ScriptPath,
        [System.Windows.Forms.Panel]$TargetPanel
    )

    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = "   $Text"
    $btn.Font = New-Object System.Drawing.Font('Segoe UI', 10)
    $btn.ForeColor = $global:Theme.White
    $btn.BackColor = $global:Theme.PrimaryDarker
    $btn.FlatStyle = 'Flat'
    $btn.FlatAppearance.BorderSize = 1
    $btn.FlatAppearance.BorderColor = $global:Theme.White
    $btn.FlatAppearance.MouseOverBackColor = $global:Theme.Primary
    $btn.Size = New-Object System.Drawing.Size(200, 40)
    $btn.TextAlign = 'MiddleLeft'
    $btn.Margin = New-Object System.Windows.Forms.Padding(0, 5, 0, 5)
    $btn.Padding = New-Object System.Windows.Forms.Padding(10, 0, 0, 0)
    $btn.Tag = @{ ScriptPath = $ScriptPath; TargetPanel = $TargetPanel }
    $btn.Add_Click({
        try {
            foreach ($control in $this.Parent.Controls) {
                if ($control -is [System.Windows.Forms.Button] -and $control -ne $global:AuthButton) {
                    $control.BackColor = $global:Theme.PrimaryDarker
                    $control.FlatAppearance.BorderColor = $global:Theme.White
                    $control.Font = New-Object System.Drawing.Font('Segoe UI',10)
                }
            }

            $this.FlatAppearance.BorderColor = $global:Theme.White
            $this.Font = New-Object System.Drawing.Font('Segoe UI',10,[System.Drawing.FontStyle]::Bold)
            $global:ActiveButton = $this
            $params = $this.Tag

            Load-ViewIntoPanel -ScriptPath $params.ScriptPath -TargetPanel $params.TargetPanel

            Update-StatusBar -StatusPanel $global:StatusPanel
        } 
        catch {
            Write-Host "[ERROR] Navigation button action failed: $($_.Exception.Message)" -ForegroundColor Red
            
            [System.Windows.Forms.MessageBox]::Show(
                "An unexpected error occurred while navigating. Please try again.",
                "Navigation Error",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
        }
    })
    return $btn
}



<#
    .SYNOPSIS
        Displays the main application shell with auto-sizing sidebar.
#>
function Show-MainShell {
    $main = New-Object System.Windows.Forms.Form
    $main.Text = 'VMware ESXi Management Console'
    $main.StartPosition = 'CenterScreen'
    $main.Size = New-Object System.Drawing.Size(1150, 650)
    $main.MinimumSize = New-Object System.Drawing.Size(850, 650)

    $splitContainer = New-Object System.Windows.Forms.SplitContainer
    $splitContainer.Dock = 'Fill'
    $splitContainer.FixedPanel = 'Panel1'
    $splitContainer.SplitterWidth = 1

    $main.Controls.Add($splitContainer)

    # Sidebar panel
    $sidebar = New-Object System.Windows.Forms.Panel
    $sidebar.Dock = 'Fill'
    $sidebar.BackColor = $global:Theme.PrimaryDarker

    $splitContainer.Panel1.Controls.Add($sidebar)

    # Sidebar layout
    $sidebarLayout = New-Object System.Windows.Forms.TableLayoutPanel
    $sidebarLayout.Dock = 'Fill'
    $sidebarLayout.RowCount = 2
    $sidebarLayout.ColumnCount = 1
    $sidebarLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'Absolute',150))
    $sidebarLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'Percent',100))

    $sidebar.Controls.Add($sidebarLayout)

    # Header
    $sidebarHeader = New-Object System.Windows.Forms.Panel
    $sidebarHeader.Dock = 'Fill'
    $sidebarHeader.BackColor = $global:Theme.PrimaryDark
    $sidebarLayout.Controls.Add($sidebarHeader,0,0)

    # Title label
    $title = New-Object System.Windows.Forms.Label
    $title.Text = 'VMware ESXi'
    $title.Font = New-Object System.Drawing.Font('Segoe UI',12,[System.Drawing.FontStyle]::Bold)
    $title.ForeColor = $global:Theme.White
    $title.Location = New-Object System.Drawing.Point(10,10)
    $title.AutoSize = $true

    $sidebarHeader.Controls.Add($title)

    # Logo
    $logo = New-Object System.Windows.Forms.PictureBox
    $logo.Size = New-Object System.Drawing.Size(100,100)
    $logo.Location = New-Object System.Drawing.Point(10,40)
    $logo.SizeMode = 'Zoom'
    try { $logo.Image = [System.Drawing.Image]::FromFile("$PSScriptRoot\..\Images\login.png") } catch { $logo.BackColor = $global:Theme.LightGray }
    
    $sidebarHeader.Controls.Add($logo)

    # Nav panel
    $navPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $navPanel.Dock = 'Fill'
    $navPanel.FlowDirection = 'TopDown'
    $navPanel.WrapContents = $false
    $navPanel.AutoScroll = $true
    $navPanel.Padding = New-Object System.Windows.Forms.Padding(10,20,10,20)
    
    $sidebarLayout.Controls.Add($navPanel,0,1)

    # Content panel
    $contentPanel = New-Object System.Windows.Forms.Panel
    $contentPanel.Dock = 'Fill'
    $contentPanel.BackColor = $global:Theme.LightGray
    $contentPanel.BorderStyle = [System.Windows.Forms.BorderStyle]::None


    
    $splitContainer.Panel2.Controls.Add($contentPanel)

    # Navigation buttons
    $scriptDir = $PSScriptRoot
    $btnDashboard = New-NavButton -Text 'Dashboard' -ScriptPath "$scriptDir\DashboardView.ps1" -TargetPanel $contentPanel
    $btnVMs       = New-NavButton -Text 'Virtual Machines' -ScriptPath "$scriptDir\VMsView.ps1" -TargetPanel $contentPanel
    $btnClasses   = New-NavButton -Text 'Class Management' -ScriptPath "$scriptDir\ClassesView.ps1" -TargetPanel $contentPanel
    $btnNetworks  = New-NavButton -Text 'Network Management' -ScriptPath "$scriptDir\NetworksView.ps1" -TargetPanel $contentPanel
    $btnOrphans   = New-NavButton -Text 'Orphaned Files' -ScriptPath "$scriptDir\OrphansView.ps1" -TargetPanel $contentPanel
    $btnLogs      = New-NavButton -Text 'Logs' -ScriptPath "$scriptDir\LogsView.ps1" -TargetPanel $contentPanel
    
    $navPanel.Controls.AddRange(@($btnDashboard,$btnVMs,$btnClasses,$btnNetworks,$btnOrphans,$btnLogs))

    # Auth button
    $global:AuthButton = New-Object System.Windows.Forms.Button
    $global:AuthButton.Text = "   $(if ($global:IsLoggedIn){'Logout'}else{'Login'})"
    $global:AuthButton.Font = New-Object System.Drawing.Font('Segoe UI',10,[System.Drawing.FontStyle]::Bold)
    $global:AuthButton.ForeColor = $global:Theme.White
    $global:AuthButton.FlatStyle = 'Flat'
    $global:AuthButton.FlatAppearance.BorderSize = 1
    $global:AuthButton.FlatAppearance.BorderColor = if ($global:IsLoggedIn){$global:Theme.Error}else{$global:Theme.Success}
    $global:AuthButton.Size = New-Object System.Drawing.Size(200,40)
    $global:AuthButton.TextAlign = 'MiddleLeft'
    $global:AuthButton.Margin = New-Object System.Windows.Forms.Padding(0,5,0,5)
    $global:AuthButton.Padding = New-Object System.Windows.Forms.Padding(10,0,0,0)
    $global:AuthButton.Add_Click({
        if ($global:AppState.VMware.Connection -ne $null) {
            try { [VMServerConnection]::GetInstance().Disconnect() } catch {}
            $global:AppState.VMware.Connection = $null
            $global:AppState.VMware.User = $null
            $this.Text = '  Login'
            $this.FlatAppearance.BorderColor = $global:Theme.Success
            $contentPanel.Controls.Clear()
            Update-StatusBar -StatusPanel $global:StatusPanel
        } else {
            . "$scriptDir\LoginView.ps1"
            if (Show-LoginView) {
                $global:IsLoggedIn = $true
                $this.Text = '  Logout'
                $this.FlatAppearance.BorderColor = $global:Theme.Error
                if ($global:ActiveButton) { $global:ActiveButton.PerformClick() } else { $btnDashboard.PerformClick() }
                Update-StatusBar -StatusPanel $global:StatusPanel
            } else { $main.Close() }
        }
    })

    $navPanel.Controls.Add($global:AuthButton)

    # Status bar
    $statusBar = New-Object System.Windows.Forms.StatusBar
    $statusBar.Dock = 'Bottom'
    $statusBar.SizingGrip = $false
    $statusBar.BackColor = $global:Theme.PrimaryDarker
    $statusBar.ForeColor = $global:Theme.White
    $statusBar.Font = New-Object System.Drawing.Font('Segoe UI',9)
    $global:StatusPanel = New-Object System.Windows.Forms.StatusBarPanel
    $global:StatusPanel.AutoSize = [System.Windows.Forms.StatusBarPanelAutoSize]::Spring
    $global:StatusPanel.BorderStyle = [System.Windows.Forms.StatusBarPanelBorderStyle]::None
    $statusBar.Panels.Add($global:StatusPanel)

    $main.Controls.Add($statusBar)

    $splitContainer.SplitterDistance = 220

    $main.Add_Load({ $btnDashboard.PerformClick(); Update-StatusBar -StatusPanel $global:StatusPanel })

    $main.Add_FormClosing({
        $r = [System.Windows.Forms.MessageBox]::Show(
            'Exit?','Confirm',[System.Windows.Forms.MessageBoxButtons]::YesNo,[System.Windows.Forms.MessageBoxIcon]::Question
        )
        if ($r -eq [System.Windows.Forms.DialogResult]::No) { $_.Cancel = $true } else { try { [VMServerConnection]::GetInstance().Disconnect() } catch {} }
    })

    [System.Windows.Forms.Application]::EnableVisualStyles()
    
    $main.ShowDialog()
}
