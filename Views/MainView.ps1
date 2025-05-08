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
    $form.Size = [System.Drawing.Size]::new(1200,800)
    $form.MinimumSize = [System.Drawing.Size]::new(800,600)

    # Top-level layout
    $layout = [System.Windows.Forms.TableLayoutPanel]::new()
    $layout.Dock = 'Fill'; $layout.RowCount = 2
    $layout.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Percent,100))
    $layout.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Absolute,25))
    $form.Controls.Add($layout)

    # Split container
    $split = [System.Windows.Forms.SplitContainer]::new()
    $split.Dock = 'Fill'; $split.FixedPanel = 'Panel1'; $split.IsSplitterFixed = $false
    $layout.Controls.Add($split,0,0)

    # Sidebar
    $sidebar = [System.Windows.Forms.Panel]::new()
    $sidebar.AutoSize = $true
    $sidebar.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
    $sidebar.BackColor = [System.Drawing.Color]::FromArgb(45,45,48)
    $split.Panel1.Controls.Add($sidebar)

    # Logo
    $logo = [System.Windows.Forms.Panel]::new()
    $logo.Dock = 'Top'; $logo.Height = 80; $logo.BackColor = [System.Drawing.Color]::FromArgb(0,122,204)
    $lblLogo = [System.Windows.Forms.Label]::new()
    $lblLogo.Text = 'VMware Console'; $lblLogo.Dock = 'Fill'
    $lblLogo.Font = [System.Drawing.Font]::new('Segoe UI',12,[System.Drawing.FontStyle]::Bold)
    $lblLogo.ForeColor = [System.Drawing.Color]::White; $lblLogo.TextAlign = 'MiddleCenter'
    $logo.Controls.Add($lblLogo)
    $sidebar.Controls.Add($logo)

    # Navigation panel
    $navPanel = [System.Windows.Forms.FlowLayoutPanel]::new()
    $navPanel.AutoSize = $true
    $navPanel.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
    $navPanel.FlowDirection = 'TopDown'; $navPanel.WrapContents = $false
    $navPanel.AutoScroll = $true; $navPanel.Padding = [System.Windows.Forms.Padding]::new(5)
    $navPanel.Location = [System.Drawing.Point]::new(0,$logo.Height)
    $sidebar.Controls.Add($navPanel)

    # Button style
    $buttonStyle = @{ Size=[System.Drawing.Size]::new(180,40); FlatStyle='Flat'; Font=[System.Drawing.Font]::new('Segoe UI',10); ForeColor=[System.Drawing.Color]::White; BackColor=[System.Drawing.Color]::FromArgb(45,45,48); TextAlign='MiddleLeft'; ImageAlign='MiddleLeft'; Margin=[System.Windows.Forms.Padding]::new(0,5,0,5) }

    function New-NavButton { param([string]$Text,[string]$Icon)
        $btn=[System.Windows.Forms.Button]::new(); $btn.Text="  $Text"
        if (Test-Path $Icon) { $btn.Image=[System.Drawing.Image]::FromFile($Icon) }
        foreach ($p in $buttonStyle.Keys) { $btn.$p=$buttonStyle[$p] }
        return $btn
    }

    $assets = "$PSScriptRoot\..\Assets"
    $btnDashboard = New-NavButton 'Dashboard' "$assets\dashboard_icon.png"
    $btnVMs       = New-NavButton 'Virtual Machines' "$assets\vm_icon.png"
    $btnClasses   = New-NavButton 'Class Management' "$assets\class_icon.png"
    $btnNetworks  = New-NavButton 'Network Management' "$assets\network_icon.png"
    $btnOrphans   = New-NavButton 'Orphan Cleaner' "$assets\cleaner_icon.png"
    $btnLogs      = New-NavButton 'Logs' "$assets\logs_icon.png"
    $navPanel.Controls.AddRange(@($btnDashboard,$btnVMs,$btnClasses,$btnNetworks,$btnOrphans,$btnLogs))

    # Auth button with color
    $authText = if ($global:IsLoggedIn){ 'Logout' }else{ 'Login' }
    $authIcon = if ($global:IsLoggedIn){ "$assets\logout_icon.png" }else{ "$assets\login_icon.png" }
    $authBtn  = New-NavButton $authText $authIcon
    $authBtn.BackColor = if ($global:IsLoggedIn){ [System.Drawing.Color]::Green }else{ [System.Drawing.Color]::Red }
    $navPanel.Controls.Add($authBtn)

    # Content panel
    $content = [System.Windows.Forms.Panel]::new(); $content.Dock='Fill'; $content.BackColor=[System.Drawing.Color]::White
    $split.Panel2.Controls.Add($content)

    # Status bar
    $status = [System.Windows.Forms.StatusBar]::new(); $status.Dock='Bottom'; $status.SizingGrip=$false
    $panel = [System.Windows.Forms.StatusBarPanel]::new(); $panel.AutoSize=[System.Windows.Forms.StatusBarPanelAutoSize]::Spring
    $status.Panels.Add($panel); $layout.Controls.Add($status,0,1)

    function Update-StatusBar {
        $c=Get-ConnectionSafe
        if ($null -ne $c) {
            try { $h=Get-VMHost -Server $c -ErrorAction Stop; $panel.Text="Connected: $($h.Name) | Ver: $($h.Version) | User: $($c.User) | $(Get-Date -Format 'G')" }
            catch { $panel.Text="Connection lost | $(Get-Date -Format 'G')" }
        } else { $panel.Text="Offline mode | $(Get-Date -Format 'G')" }
    }

    # Handlers
    $btnDashboard.Add_Click({ Load-ViewIntoPanel "$PSScriptRoot\DashboardView.ps1" $content; Update-StatusBar })
    $btnVMs.Add_Click({ Load-ViewIntoPanel "$PSScriptRoot\VMsView.ps1"       $content; Update-StatusBar })
    $btnClasses.Add_Click({ Load-ViewIntoPanel "$PSScriptRoot\ClassManagerView.ps1" $content; Update-StatusBar })
    $btnNetworks.Add_Click({ Load-ViewIntoPanel "$PSScriptRoot\NetworkManagerView.ps1" $content; Update-StatusBar })
    $btnOrphans.Add_Click({ Load-ViewIntoPanel "$PSScriptRoot\OrphanCleanerView.ps1" $content; Update-StatusBar })
    $btnLogs.Add_Click({ Load-ViewIntoPanel "$PSScriptRoot\LogsView.ps1"          $content; Update-StatusBar })
    $authBtn.Add_Click({
        if ($global:IsLoggedIn) {
            try{[VMServerConnection]::GetInstance().Disconnect()}catch{}
            $global:IsLoggedIn=$false; $authBtn.Text='  Login'; $authBtn.Image=[System.Drawing.Image]::FromFile("$assets\login_icon.png"); $authBtn.BackColor=[System.Drawing.Color]::Red
            $content.Controls.Clear(); Update-StatusBar
        } else {
            . "$PSScriptRoot\LoginView.ps1"
            if (Show-LoginView) {
                $global:IsLoggedIn=$true; $authBtn.Text='  Logout'; $authBtn.Image=[System.Drawing.Image]::FromFile("$assets\logout_icon.png"); $authBtn.BackColor=[System.Drawing.Color]::Green
                $btnDashboard.PerformClick(); Update-StatusBar
            } else { $form.Close() }
        }
    })

    # Resize sidebar
    $sidebar.PerformLayout(); $split.SplitterDistance=$sidebar.PreferredSize.Width

    # Form events
    $form.Add_Load({ $btnDashboard.PerformClick(); Update-StatusBar })
    $form.Add_FormClosing({
        $r=[System.Windows.Forms.MessageBox]::Show('Exit?','Confirm',[System.Windows.Forms.MessageBoxButtons]::YesNo,[System.Windows.Forms.MessageBoxIcon]::Question)
        if ($r -eq [System.Windows.Forms.DialogResult]::No) { $_.Cancel=$true } else { try{[VMServerConnection]::GetInstance().Disconnect()}catch{} }
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
    if (Show-LoginView) { Show-MainShell } else { [System.Windows.Forms.MessageBox]::Show('Login cancelled or failed.','Authentication',[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Information) }
}
