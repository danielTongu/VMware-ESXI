# Required assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Color definitions for buttons
$buttonNormalColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
$buttonHoverColor = [System.Drawing.Color]::FromArgb(62, 62, 64)
$buttonActiveColor = [System.Drawing.Color]::FromArgb(0, 122, 204)  # Blue accent
$buttonBorderColor = [System.Drawing.Color]::FromArgb(80, 80, 80)  # Subtle border
$buttonActiveBorderColor = [System.Drawing.Color]::White
$logoutModeColor = [System.Drawing.Color]::FromArgb(128, 0, 32)  # Burgundy

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
    try { return [VMServerConnection]::GetInstance().GetConnection() }
    catch {
        $global:VMwareConfig.OfflineMode = $true
        Write-Warning "Connection failed: $_"
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
    
    # Clear existing controls
    $TargetPanel.Controls.Clear()
    
    try {
        # Dot-source the script to load its functions
        . $ScriptPath
        
        # Check for common view functions
        $viewFunctions = @(
            'Show-DashboardView',
            'Show-VMsView',
            'Show-ClassManagerView',
            'Show-NetworkView',
            'Show-OrphanCleanerView',
            'Show-LogsView'
        )
        
        foreach ($func in $viewFunctions) {
            if (Get-Command $func -ErrorAction SilentlyContinue) {
                # Call the view function with the target panel
                & $func -ContentPanel $TargetPanel
                return
            }
        }
        throw "No recognized view function found in $ScriptPath"
    } catch {
        Write-Host "`n[ERROR LOADING VIEW]`nPath: $ScriptPath`nError: $_`nStack Trace:`n$($_.ScriptStackTrace)`n" -ForegroundColor Red
        
        [System.Windows.Forms.MessageBox]::Show(
            "Could not load the requested view. Please try again or contact support.",
            "View Loading Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        
        $errorLabel = New-Object System.Windows.Forms.Label
        $errorLabel.Text = "Error loading view: $_"
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
    
    # Store the parameters in the button's Tag property
    $btn.Tag = @{
        ScriptPath = $ScriptPath
        TargetPanel = $TargetPanel
    }
    
    # Add the click event handler
    $btn.Add_Click({
        # Reset all buttons to normal state
        foreach ($control in $this.Parent.Controls) {
            if ($control -is [System.Windows.Forms.Button] -and $control -ne $global:AuthButton) {
                $control.BackColor = $buttonNormalColor
                $control.FlatAppearance.BorderColor = $buttonBorderColor
                $control.Font = New-Object System.Drawing.Font('Segoe UI', 10)
            }
        }
        
        # Highlight active button
        $this.BackColor = $buttonActiveColor
        $this.FlatAppearance.BorderColor = $buttonActiveBorderColor
        $this.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
        $global:ActiveButton = $this
        
        # Load the view
        $params = $this.Tag
        Load-ViewIntoPanel -ScriptPath $params.ScriptPath -TargetPanel $params.TargetPanel
        Update-StatusBar
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
    $title.Text = 'VMWARE CONSOLE'
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
    $btnClasses = New-NavButton -Text 'Class Management' -ScriptPath "$scriptDir\ClassManagerView.ps1" -TargetPanel $contentPanel
    $btnNetworks = New-NavButton -Text 'Network Management' -ScriptPath "$scriptDir\NetworkManagerView.ps1" -TargetPanel $contentPanel
    $btnOrphans = New-NavButton -Text 'Orphan Cleaner' -ScriptPath "$scriptDir\OrphanCleanerView.ps1" -TargetPanel $contentPanel
    $btnLogs = New-NavButton -Text 'Logs' -ScriptPath "$scriptDir\LogsView.ps1" -TargetPanel $contentPanel

    $navPanel.Controls.AddRange(@($btnDashboard, $btnVMs, $btnClasses, $btnNetworks, $btnOrphans, $btnLogs))

    # Auth button (special handling)
    $global:AuthButton = New-Object System.Windows.Forms.Button
    $global:AuthButton.Text = "   $(if ($global:IsLoggedIn) { 'Logout' } else { 'Login' })"
    $global:AuthButton.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
    $global:AuthButton.ForeColor = [System.Drawing.Color]::White
    $global:AuthButton.BackColor = if ($global:IsLoggedIn) { [System.Drawing.Color]::FromArgb(76, 175, 80) } else { $logoutModeColor }
    $global:AuthButton.FlatStyle = 'Flat'
    $global:AuthButton.FlatAppearance.BorderSize = 1
    $global:AuthButton.FlatAppearance.BorderColor = if ($global:IsLoggedIn) { [System.Drawing.Color]::FromArgb(100, 200, 100) } else { [System.Drawing.Color]::FromArgb(150, 0, 50) }
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
            $this.BackColor = $logoutModeColor
            $this.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(150, 0, 50)
            $contentPanel.Controls.Clear()
            Update-StatusBar
        } else {
            . "$scriptDir\LoginView.ps1"
            if (Show-LoginView) {
                $global:IsLoggedIn = $true
                $this.Text = '  Logout'
                $this.BackColor = [System.Drawing.Color]::FromArgb(76, 175, 80)
                $this.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(100, 200, 100)
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

    function Update-StatusBar {
        $c = Get-ConnectionSafe
        if ($null -ne $c) {
            try { 
                $h = Get-VMHost -Server $c -ErrorAction Stop
                $statusPanel.Text = "Connected: $($h.Name) | Ver: $($h.Version) | User: $($c.User) | $(Get-Date -Format 'G')"
            } catch { 
                $statusPanel.Text = "Connection lost | $(Get-Date -Format 'G')"
            }
        } else { 
            $statusPanel.Text = "Offline mode | $(Get-Date -Format 'G')"
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
    Entry point: shows login then main shell.
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