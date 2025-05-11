# Views\LoginView.ps1

# View that shows up after successful login.

# Required assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Color definitions for buttons
$buttonNormalColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
$buttonHoverColor = [System.Drawing.Color]::FromArgb(62, 62, 64)
$buttonBorderColor = $global:theme.Success #[System.Drawing.Color]::FromArgb(80, 80, 80)  # Subtle border
$buttonActiveBorderColor = $global:theme.CardBackground #white
$logoutModeColor = $global:theme.Primary  # Burgundy

# Store the currently active button
$global:ActiveButton = $null

<#
.SYNOPSIS
    Safely obtains a server connection or toggles offline mode.
.OUTPUTS
    Connection object or $null.
#>
function Get-ConnectionSafe {
    if ($global:VMwareConfig.OfflineMode) {
        Write-Warning "Offline mode: skipping connection attempt."
        return $null
    }
    try {
        return [VMServerConnection]::GetInstance().GetConnection()
    } catch {
        Write-Warning "Connection failed. Switching to offline mode."
        Write-Host "Error during Get-ConnectionSafe:`n$($_.Exception.Message)`n$($_.ScriptStackTrace)" -ForegroundColor Red
        $global:VMwareConfig.OfflineMode = $true
        return $null
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

        $viewFunctions = @(
            'Show-DashboardView',
            'Show-ClassesView',
            'Show-VMsView',
            'Show-NetworksView',
            'Show-OrphansView',
            'Show-LogsView'
        )

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
        # Log detailed info for developer
        Write-Host "`n[ERROR LOADING VIEW]`nScriptPath: $ScriptPath`nError: $($_.Exception.Message)`n$($_.ScriptStackTrace)`n" -ForegroundColor Red

        # Display user-friendly message
        [System.Windows.Forms.MessageBox]::Show(
            "Unable to load view. Please try again or contact support.",
            "View Load Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )

        # Show error label in UI
        $errorLabel = New-Object System.Windows.Forms.Label
        $errorLabel.Text = "Error loading view."
        $errorLabel.ForeColor = [System.Drawing.Color]::Red
        $errorLabel.AutoSize = $true
        $errorLabel.Location = New-Object System.Drawing.Point(20, 20)
        $TargetPanel.Controls.Add($errorLabel)
    }
}



<#
.SYNOPSIS
    Creates a navigation button with proper event handling.
.PARAMETER Text
    Button text.
.PARAMETER ScriptPath
    Path to the view script to load.
.PARAMETER TargetPanel
    The content panel to load the view into.
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
    $btn.ForeColor = [System.Drawing.Color]::White
    $btn.BackColor = $buttonNormalColor
    $btn.FlatStyle = 'Flat'
    $btn.FlatAppearance.BorderSize = 1
    $btn.FlatAppearance.BorderColor = $buttonBorderColor
    $btn.FlatAppearance.MouseOverBackColor = $buttonHoverColor
    $btn.Size = New-Object System.Drawing.Size(200, 40)
    $btn.TextAlign = 'MiddleLeft'
    $btn.Margin = New-Object System.Windows.Forms.Padding(0, 5, 0, 5)
    $btn.Padding = New-Object System.Windows.Forms.Padding(10, 0, 0, 0)

    $btn.Tag = @{
        ScriptPath  = $ScriptPath
        TargetPanel = $TargetPanel
    }

    $btn.Add_Click({
        try {
            # Reset all buttons
            foreach ($control in $this.Parent.Controls) {
                if ($control -is [System.Windows.Forms.Button] -and $control -ne $global:AuthButton) {
                    $control.BackColor = $buttonNormalColor
                    $control.FlatAppearance.BorderColor = $buttonBorderColor
                    $control.Font = New-Object System.Drawing.Font('Segoe UI', 10)
                }
            }

            # Highlight the active button
            $this.FlatAppearance.BorderColor = $buttonActiveBorderColor
            $this.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
            $global:ActiveButton = $this

            # Load the view
            $params = $this.Tag
            Load-ViewIntoPanel -ScriptPath $params.ScriptPath -TargetPanel $params.TargetPanel
            Update-StatusBar
        } catch {
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
    $global:IsLoggedIn = $true

    # Main form
    $main = New-Object System.Windows.Forms.Form
    $main.Text = 'VMware ESXi Management Console'
    $main.StartPosition = 'CenterScreen'
    $main.Size = New-Object System.Drawing.Size(1150, 650)
    $main.MinimumSize = New-Object System.Drawing.Size(850, 650)

    # Split container
    $splitContainer = New-Object System.Windows.Forms.SplitContainer
    $splitContainer.Dock = 'Fill'
    $splitContainer.FixedPanel = 'Panel1'
    $splitContainer.SplitterWidth = 1
    $main.Controls.Add($splitContainer)

    # Sidebar panel
    $sidebar = New-Object System.Windows.Forms.Panel
    $sidebar.Dock = 'Fill'
    $sidebar.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
    $splitContainer.Panel1.Controls.Add($sidebar)

    # Sidebar layout manager
    $sidebarLayout = New-Object System.Windows.Forms.TableLayoutPanel
    $sidebarLayout.Dock = 'Fill'
    $sidebarLayout.RowCount = 2
    $sidebarLayout.ColumnCount = 1
    $sidebarLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'Absolute', 150))
    $sidebarLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'Percent', 100))
    $sidebar.Controls.Add($sidebarLayout)

    # Sidebar header (logo + title)
    $sidebarHeader = New-Object System.Windows.Forms.Panel
    $sidebarHeader.Dock = 'Fill'
    $sidebarHeader.BackColor = [System.Drawing.Color]::FromArgb(37, 37, 38)
    $sidebarLayout.Controls.Add($sidebarHeader, 0, 0)

    # Title
    $title = New-Object System.Windows.Forms.Label
    $title.Text = 'VMware ESXi'
    $title.Font = New-Object System.Drawing.Font('Segoe UI', 12, [System.Drawing.FontStyle]::Bold)
    $title.ForeColor = [System.Drawing.Color]::White
    $title.Location = New-Object System.Drawing.Point(10, 10)
    $title.AutoSize = $true
    $sidebarHeader.Controls.Add($title)

    # Logo
    $logo = New-Object System.Windows.Forms.PictureBox
    $logo.Width = 100
    $logo.Height = 100
    $logo.Location = New-Object System.Drawing.Point(10, 40)
    $logo.SizeMode = 'Zoom'
    try {
        $logo.Image = [System.Drawing.Image]::FromFile("$PSScriptRoot\..\Images\login.png")
    } catch {
        $logo.BackColor = [System.Drawing.Color]::LightGray
    }
    $sidebarHeader.Controls.Add($logo)

    # Navigation panel
    $navPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $navPanel.Dock = 'Fill'
    $navPanel.FlowDirection = 'TopDown'
    $navPanel.WrapContents = $false
    $navPanel.AutoScroll = $true
    $navPanel.Padding = New-Object System.Windows.Forms.Padding(10, 20, 10, 20)
    $sidebarLayout.Controls.Add($navPanel, 0, 1)

    # Content panel
    $contentPanel = New-Object System.Windows.Forms.Panel
    $contentPanel.Dock = 'Fill'
    $contentPanel.BackColor = [System.Drawing.Color]::White
    $splitContainer.Panel2.Controls.Add($contentPanel)

    # Create navigation buttons
    $scriptDir = $PSScriptRoot
    
    $btnDashboard = New-NavButton -Text 'Dashboard' -ScriptPath "$scriptDir\DashboardView.ps1" -TargetPanel $contentPanel
    $btnVMs = New-NavButton -Text 'Virtual Machines' -ScriptPath "$scriptDir\VMsView.ps1" -TargetPanel $contentPanel
    $btnClasses = New-NavButton -Text 'Class Management' -ScriptPath "$scriptDir\ClassesView.ps1" -TargetPanel $contentPanel
    $btnNetworks = New-NavButton -Text 'Network Management' -ScriptPath "$scriptDir\NetworksView.ps1" -TargetPanel $contentPanel
    $btnOrphans = New-NavButton -Text 'Orphan Cleaner' -ScriptPath "$scriptDir\OrphansView.ps1" -TargetPanel $contentPanel
    $btnLogs = New-NavButton -Text 'Logs' -ScriptPath "$scriptDir\LogsView.ps1" -TargetPanel $contentPanel

    $navPanel.Controls.AddRange(@($btnDashboard, $btnVMs, $btnClasses, $btnNetworks, $btnOrphans, $btnLogs))

    # Auth button (special handling)
    $global:AuthButton = New-Object System.Windows.Forms.Button
    $global:AuthButton.Text = "   $(if ($global:IsLoggedIn) { 'Logout' } else { 'Login' })"
    $global:AuthButton.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
    $global:AuthButton.ForeColor = [System.Drawing.Color]::White
    $global:AuthButton.FlatStyle = 'Flat'
    $global:AuthButton.FlatAppearance.BorderSize = 1
    $global:AuthButton.FlatAppearance.BorderColor = if ($global:IsLoggedIn) { $global:theme.Error } else { $global:theme.Success }
    $global:AuthButton.Size = New-Object System.Drawing.Size(200, 40)
    $global:AuthButton.TextAlign = 'MiddleLeft'
    $global:AuthButton.Margin = New-Object System.Windows.Forms.Padding(0, 5, 0, 5)
    $global:AuthButton.Padding = New-Object System.Windows.Forms.Padding(10, 0, 0, 0)
    $global:AuthButton.ImageAlign = 'MiddleLeft'

    $global:AuthButton.Add_Click({
        if ($global:IsLoggedIn) {
            try { [VMServerConnection]::GetInstance().Disconnect() } catch {}
            $global:IsLoggedIn = $false
            $this.Text = '  Login'
            $this.FlatAppearance.BorderColor = $global:theme.Success
            $contentPanel.Controls.Clear()
            Update-StatusBar
        } else {
            . "$scriptDir\LoginView.ps1"
            if (Show-LoginView) {
                $global:IsLoggedIn = $true
                $this.Text = '  Logout'
                $this.FlatAppearance.BorderColor = $global:theme.Error
                if ($global:ActiveButton) {
                    $global:ActiveButton.PerformClick()
                } else {
                    $btnDashboard.PerformClick()
                }
                Update-StatusBar
            } else { $main.Close() }
        }
    })
    $navPanel.Controls.Add($global:AuthButton)

    # Status bar
    $statusBar = New-Object System.Windows.Forms.StatusBar
    $statusBar.Dock = 'Bottom'
    $statusBar.SizingGrip = $false
    $statusBar.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
    $statusBar.ForeColor = [System.Drawing.Color]::White
    $statusBar.Font = New-Object System.Drawing.Font('Segoe UI', 9)

    $statusPanel = New-Object System.Windows.Forms.StatusBarPanel
    $statusPanel.AutoSize = [System.Windows.Forms.StatusBarPanelAutoSize]::Spring
    $statusPanel.BorderStyle = [System.Windows.Forms.StatusBarPanelBorderStyle]::None
    $statusBar.Panels.Add($statusPanel)
    $main.Controls.Add($statusBar)



    <#
    .SYNOPSIS
        Updates the status bar with connection and host information.
    .DESCRIPTION
        This function retrieves the current connection and host information,
        updating the status bar accordingly. It handles errors gracefully,
        providing feedback in case of issues.
    .OUTPUTS
        None. Updates the status bar text directly.
    #>
    function Update-StatusBar {
        try {
            $c = Get-ConnectionSafe
            if ($null -ne $c) {
                try {
                    $h = Get-VMHost -Server $c -ErrorAction Stop
                    $statusPanel.Text = "Connected: $($h.Name) | Ver: $($h.Version) | User: $($c.User) | $(Get-Date -Format 'G')"
                } catch {
                    Write-Host "Error retrieving host info: $($_.Exception.Message)" -ForegroundColor Red
                    $statusPanel.Text = "Connected, but host data failed | $(Get-Date -Format 'G')"
                }
            } else {
                $statusPanel.Text = "Offline mode | $(Get-Date -Format 'G')"
            }
        } catch {
            Write-Host "Unexpected error in Update-StatusBar: $($_.Exception.Message)" -ForegroundColor Red
            $statusPanel.Text = "Status error | $(Get-Date -Format 'G')"
        }
    }    

    # Set initial splitter distance
    $splitContainer.SplitterDistance = 220

    # Form events
    $main.Add_Load({ 
        $btnDashboard.PerformClick()
        Update-StatusBar
    })

    $main.Add_FormClosing({
        $r = [System.Windows.Forms.MessageBox]::Show(
            'Exit?',
            'Confirm',
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )
        if ($r -eq [System.Windows.Forms.DialogResult]::No) { 
            $_.Cancel = $true 
        } else { 
            try { [VMServerConnection]::GetInstance().Disconnect() } catch {} 
        }
    })

    [System.Windows.Forms.Application]::EnableVisualStyles()
    $main.ShowDialog()
}



<#
.SYNOPSIS
    Displays the main view after successful login.
.DESCRIPTION
    This function loads the login view and, upon successful authentication,
    initializes and displays the main application shell.
.PARAMETER ScriptPath
    Path to the login view script.
.PARAMETER TargetPanel
    The content panel where the login view will be rendered.
#>
function Show-MainView {
    . "$PSScriptRoot\LoginView.ps1"
    if (Show-LoginView) { 
        Show-MainShell 
    } else { 
        [System.Windows.Forms.MessageBox]::Show(
            'Login cancelled or failed.',
            'Authentication',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) 
    }
}