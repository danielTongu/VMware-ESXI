<#
.SYNOPSIS
    Provides Start-VMwareDashboard to bootstrap and run the WinForms GUI.

.DESCRIPTION
    - Loads all view scripts from the Views folder.
    - Builds the main form with a left-side menu, content panel, and status strip.
    - Declares and configures all controls before wiring event handlers.
    - Highlights the active menu button.
    - Initializes the Dashboard view on startup.
#>
function Start-VMwareDashboard {
    [CmdletBinding()]
    param()

    # ----------------------------------------
    # 1) Load View Scripts
    # ----------------------------------------
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $viewsDir  = Join-Path $scriptDir 'Views'
    Get-ChildItem -Path $viewsDir -Filter '*.ps1' | ForEach-Object { . $_.FullName }

    # ----------------------------------------
    # 2) Add WinForms Assemblies
    # ----------------------------------------
    Add-Type -AssemblyName System.Windows.Forms, System.Drawing

    # ----------------------------------------
    # 3) Declare UI Controls
    # ----------------------------------------
    # Main window
    $form          = New-Object System.Windows.Forms.Form

    # Left navigation panel
    $menuPanel     = New-Object System.Windows.Forms.Panel

    # Central content panel
    $contentPanel  = New-Object System.Windows.Forms.Panel

    # Status strip at bottom
    $statusStrip   = New-Object System.Windows.Forms.StatusStrip
    $statusLabel   = New-Object System.Windows.Forms.ToolStripStatusLabel

    # ----------------------------------------
    # 4) Configure Control Properties
    # ----------------------------------------

    ## 4.1 Main form
    $form.Text              = 'VMware Dashboard'
    $form.Size              = [System.Drawing.Size]::new(1100, 800)
    $form.StartPosition     = 'CenterScreen'
    $form.MinimumSize       = [System.Drawing.Size]::new(800, 600)

    ## 4.2 Menu panel
    $menuPanel.BackColor    = [System.Drawing.Color]::LightGray
    $menuPanel.Dock         = 'Left'
    $menuPanel.Width        = 200

    ## 4.3 Content panel
    $contentPanel.BackColor = [System.Drawing.Color]::White
    $contentPanel.Dock      = 'Fill'

    ## 4.4 Status strip
    $statusLabel.Text       = 'Ready'
    $statusStrip.Items.Add($statusLabel) | Out-Null
    $statusStrip.Dock       = 'Bottom'

    # ----------------------------------------
    # 5) Helper: Highlight Active Menu Button
    # ----------------------------------------
    function Set-ActiveMenuButton {
        param([System.Windows.Forms.Button]$activeButton)
        foreach ($ctrl in $menuPanel.Controls) {
            if ($ctrl -is [System.Windows.Forms.Button]) {
                # Default and active colors
                $ctrl.BackColor = if ($ctrl -eq $activeButton) {
                    [System.Drawing.Color]::DarkGray
                } else {
                    [System.Drawing.Color]::LightGray
                }
            }
        }
    }

    # ----------------------------------------
    # 6) Helper: Add Menu Button
    # ----------------------------------------
    function Add-MenuButton {
        param(
            [string]$Text,
            [int]$Top,
            [ScriptBlock]$OnClick
        )
        $btn = New-Object System.Windows.Forms.Button
        $btn.Text       = $Text
        $btn.Size       = [System.Drawing.Size]::new(180, 40)
        $btn.Location   = [System.Drawing.Point]::new(10, $Top)
        $btn.FlatStyle  = 'System'
        # Wire up click: highlight + run view + update status
        $btn.Add_Click({
            Set-ActiveMenuButton $btn
            & $OnClick
            $statusLabel.Text = "Viewing: $Text"
        })
        $menuPanel.Controls.Add($btn)
        return $btn
    }

    # ----------------------------------------
    # 7) Create Menu Buttons and Wire Views
    # ----------------------------------------
    # Each block passes a scriptblock that calls the appropriate Show-*View
    Add-MenuButton 'Dashboard'        20  { Show-DashboardView $contentPanel }
    Add-MenuButton 'Classes'          70  { Show-ClassesView   $contentPanel }
    Add-MenuButton 'Virtual Machines' 120 { Show-VMsView       $contentPanel }
    Add-MenuButton 'Networks'         170 { Show-NetworksView  $contentPanel }
    Add-MenuButton 'Logs'             220 { Show-LogsView      $contentPanel }
    Add-MenuButton 'Exit'             700 { $form.Close() }

    # ----------------------------------------
    # 8) Assemble Form
    # ----------------------------------------
    $form.Controls.AddRange(@(
        $menuPanel,
        $contentPanel,
        $statusStrip
    ))

    # ----------------------------------------
    # 9) Initialize and Run
    # ----------------------------------------
    # Activate Dashboard tab on startup
    Set-ActiveMenuButton ($menuPanel.Controls | Where-Object { $_.Text -eq 'Dashboard' })
    Show-DashboardView $contentPanel
    $statusLabel.Text = 'Viewing: Dashboard'

    [System.Windows.Forms.Application]::EnableVisualStyles()
    [System.Windows.Forms.Application]::Run($form)
}

Export-ModuleMember -Function Start-VMwareDashboard