<#
.SYNOPSIS
    Enhanced Main UI Shell for resilient VMware Management System, with dynamic login/logout button
.DESCRIPTION
    Provides a professional interface:
      - Sidebar auto-sizes exactly to its logo + nav buttons width
      - Status bar with connection info and offline awareness
      - Dynamic Login/Logout button (red when logged out, green when logged in)
      - Logs button to view VMware events
      - Responsive layout
      - Enhanced session management
#>

# Required assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

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
    $TargetPanel.Controls.Clear()
    try {
        . $ScriptPath
        $cmds = 'Show-DashboardView','Show-VMsView','Show-ClassManagerView','Show-NetworkView','Show-OrphanCleanerView','Show-LogsView'
        foreach ($c in $cmds) {
            if (Get-Command $c -ErrorAction SilentlyContinue) {
                & $c -ContentPanel $TargetPanel
                return
            }
        }
        throw "No view entry point found in $ScriptPath"
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to load view: $_", 'Error', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

<#
.SYNOPSIS
    Displays the main application shell with auto-sizing sidebar.
.DESCRIPTION
    Sidebar auto-sizes exactly to logo + nav buttons. Content panel and status bar accompany.
#>
function Show-MainShell {
    $global:IsLoggedIn = $true

    # Main form
    $form = [System.Windows.Forms.Form]::new()
    $form.Text = 'VMware ESXi Management Console'
    $form.StartPosition = 'CenterScreen'
    $form.Size = [System.Drawing.Size]::new(1200,400)
    $form.MinimumSize = [System.Drawing.Size]::new(800,600)

    # Main layout container
    $mainLayout = New-Object System.Windows.Forms.TableLayoutPanel
    $mainLayout.Dock = 'Fill'
    $mainLayout.RowCount = 2
    $mainLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'Percent', 100))
    $mainLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'Absolute', 28))
    $form.Controls.Add($mainLayout)

    # Split container
    $splitContainer = New-Object System.Windows.Forms.SplitContainer
    $splitContainer.Dock = 'Fill'
    $splitContainer.FixedPanel = 'Panel1'
    $splitContainer.SplitterWidth = 1
    $mainLayout.Controls.Add($splitContainer, 0, 0)

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
    $sidebarLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'Absolute', 100))  # Header height
    $sidebarLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'Percent', 100))   # Remaining nav
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
    $title.Location = New-Object System.Drawing.Point(20, 20)
    $title.AutoSize = $true
    $sidebarHeader.Controls.Add($title)

    # Logo
    $logo = New-Object System.Windows.Forms.PictureBox
    $logo.Width = 100
    $logo.Height = 100
    $logo.Location = New-Object System.Drawing.Point(20, 70)
    $logo.SizeMode = 'Zoom'
    try {
        $logo.Image = [System.Drawing.Image]::FromFile("$PSScriptRoot\..\Images\login.png")
    } catch {
        $logo.BackColor = [System.Drawing.Color]::LightGray
    }
    $sidebarHeader.Controls.Add($logo)

    # Navigation panel (fills remaining vertical space)
    $navPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $navPanel.Dock = 'Fill'
    $navPanel.FlowDirection = 'TopDown'
    $navPanel.WrapContents = $false
    $navPanel.AutoScroll = $true
    $navPanel.Padding = New-Object System.Windows.Forms.Padding(10, 20, 10, 20)
    $sidebarLayout.Controls.Add($navPanel, 0, 1)

    # Button style
    $buttonStyle = @{ 
        Size=[System.Drawing.Size]::new(180,40); 
        FlatStyle='Flat'; 
        Font=[System.Drawing.Font]::new('Segoe UI',10); 
        ForeColor=[System.Drawing.Color]::White; 
        BackColor=[System.Drawing.Color]::FromArgb(45,45,48); 
        TextAlign='MiddleLeft'; 
        ImageAlign='MiddleLeft'; 
        Margin=[System.Windows.Forms.Padding]::new(0,5,0,5) 
    }

    # Button creation function
    function New-NavButton {
        param([string]$Text, [string]$IconPath)
        
        $btn = New-Object System.Windows.Forms.Button
        $btn.Text = "   $Text"
        $btn.Font = New-Object System.Drawing.Font('Segoe UI', 10)
        $btn.ForeColor = [System.Drawing.Color]::White
        $btn.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
        $btn.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $btn.FlatAppearance.BorderSize = 0
        $btn.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(62, 62, 64)
        $btn.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::FromArgb(27, 27, 28)
        $btn.Size = New-Object System.Drawing.Size(200, 40)
        $btn.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
        $btn.Margin = New-Object System.Windows.Forms.Padding(0, 5, 0, 5)
        $btn.Padding = New-Object System.Windows.Forms.Padding(10, 0, 0, 0)
        
        if (Test-Path $IconPath) {
            $btn.Image = [System.Drawing.Image]::FromFile($IconPath)
            $btn.ImageAlign = [System.Drawing.ContentAlignment]::MiddleLeft
        }
        
        return $btn
    }

    $assets = "$PSScriptRoot\..\Images"
    $btnDashboard = New-NavButton 'Dashboard' "$assets\dashboard_icon.png"
    $btnVMs       = New-NavButton 'Virtual Machines' "$assets\vm_icon.png"
    $btnClasses   = New-NavButton 'Class Management' "$assets\class_icon.png"
    $btnNetworks  = New-NavButton 'Network Management' "$assets\network_icon.png"
    $btnOrphans   = New-NavButton 'Orphan Cleaner' "$assets\cleaner_icon.png"
    $btnLogs      = New-NavButton 'Logs' "$assets\logs_icon.png"

    $navPanel.Controls.AddRange(@($btnDashboard,$btnVMs,$btnClasses,$btnNetworks,$btnOrphans,$btnLogs))

    # Auth button
    $authBtn = New-NavButton $(if ($global:IsLoggedIn) { 'Logout' } else { 'Login' }) `
        $(if ($global:IsLoggedIn) { "$assets\logout_icon.png" } else { "$assets\login_icon.png" })
    $authBtn.BackColor = if ($global:IsLoggedIn) { [System.Drawing.Color]::FromArgb(76, 175, 80) } else { [System.Drawing.Color]::FromArgb(244, 67, 54) }
    $authBtn.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
    $navPanel.Controls.Add($authBtn)

    # Content panel
    $contentPanel = New-Object System.Windows.Forms.Panel
    $contentPanel.Dock = 'Fill'
    $contentPanel.BackColor = [System.Drawing.Color]::White
    $splitContainer.Panel2.Controls.Add($contentPanel)

    # Status bar
    $statusBar = New-Object System.Windows.Forms.StatusBar
    $statusBar.Dock = 'Fill'
    $statusBar.SizingGrip = $false
    $statusBar.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
    $statusBar.ForeColor = [System.Drawing.Color]::White
    $statusBar.Font = New-Object System.Drawing.Font('Segoe UI', 9)

    $statusPanel = New-Object System.Windows.Forms.StatusBarPanel
    $statusPanel.AutoSize = [System.Windows.Forms.StatusBarPanelAutoSize]::Spring
    $statusPanel.BorderStyle = [System.Windows.Forms.StatusBarPanelBorderStyle]::None
    $statusBar.Panels.Add($statusPanel)
    $mainLayout.Controls.Add($statusBar, 0, 1)

    function Update-StatusBar {
        $c=Get-ConnectionSafe
        if ($null -ne $c) {
            try { 
                $h=Get-VMHost -Server $c -ErrorAction Stop; 
                $statusPanel.Text="Connected: $($h.Name) | Ver: $($h.Version) | User: $($c.User) | $(Get-Date -Format 'G')" }
            catch { 
                $statusPanel.Text="Connection lost | $(Get-Date -Format 'G')"
             }
        } else { 
            $statusPanel.Text="Offline mode | $(Get-Date -Format 'G')" 
        }
    }

    # Handlers
    $btnDashboard.Add_Click({ Load-ViewIntoPanel "$PSScriptRoot\DashboardView.ps1" $contentPanel; Update-StatusBar })
    $btnVMs.Add_Click({ Load-ViewIntoPanel "$PSScriptRoot\VMsView.ps1" $contentPanel; Update-StatusBar })
    $btnClasses.Add_Click({ Load-ViewIntoPanel "$PSScriptRoot\ClassManagerView.ps1" $contentPanel; Update-StatusBar })
    $btnNetworks.Add_Click({ Load-ViewIntoPanel "$PSScriptRoot\NetworkManagerView.ps1" $contentPanel; Update-StatusBar })
    $btnOrphans.Add_Click({ Load-ViewIntoPanel "$PSScriptRoot\OrphanCleanerView.ps1" $contentPanel; Update-StatusBar })
    $btnLogs.Add_Click({ Load-ViewIntoPanel "$PSScriptRoot\LogsView.ps1" $contentPanel; Update-StatusBar })
    $authBtn.Add_Click({
        if ($global:IsLoggedIn) {
            try{[VMServerConnection]::GetInstance().Disconnect()}catch{}
            $global:IsLoggedIn=$false; 
            $authBtn.Text='  Login'; 
            $authBtn.Image=[System.Drawing.Image]::FromFile("$assets\login_icon.png"); 
            $authBtn.BackColor=[System.Drawing.Color]::Red
            $contentPanel.Controls.Clear(); Update-StatusBar
        } else {
            . "$PSScriptRoot\LoginView.ps1"
            if (Show-LoginView) {
                $global:IsLoggedIn=$true; 
                $authBtn.Text='  Logout'; 
                $authBtn.Image=[System.Drawing.Image]::FromFile("$assets\logout_icon.png"); 
                $authBtn.BackColor=[System.Drawing.Color]::Green
                $btnDashboard.PerformClick(); 
                Update-StatusBar
            } else { $form.Close() }
        }
    })

    # Set initial splitter distance
    $splitContainer.SplitterDistance = 220

    # Form events
    $form.Add_Load({ $btnDashboard.PerformClick(); Update-StatusBar })
    $form.Add_FormClosing({
        $r=[System.Windows.Forms.MessageBox]::Show(
            'Exit?',
            'Confirm',[System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )
        if ($r -eq [System.Windows.Forms.DialogResult]::No) { 
            $_.Cancel=$true 
        } else { 
            try{
                [VMServerConnection]::GetInstance().Disconnect()
            } catch{} 
        }
    })

    [System.Windows.Forms.Application]::EnableVisualStyles()
    $form.ShowDialog()
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
