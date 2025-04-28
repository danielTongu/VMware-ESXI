<#
.SYNOPSIS
    Bootstrap script: imports modules & views, builds MainForm, and runs the WinForms loop.
#>

# Load the Model module
Import-Module ".\Modules\VMwareScripts.psm1"

# Load each View
. ".\Views\DashboardView.ps1"
. ".\Views\ClassesView.ps1"
. ".\Views\VMsView.ps1"
. ".\Views\NetworksView.ps1"
. ".\Views\LogsView.ps1"

Add-Type -AssemblyName System.Windows.Forms, System.Drawing

# Main form and panels
$form         = New-Object System.Windows.Forms.Form
$form.Text    = 'VMware Dashboard'
$form.Size    = [System.Drawing.Size]::new(1100,800)
$form.StartPosition = 'CenterScreen'

# Left menu
$menuPanel    = New-Object System.Windows.Forms.Panel
$menuPanel.Size      = [System.Drawing.Size]::new(200,800)
$menuPanel.BackColor = [System.Drawing.Color]::LightGray
$menuPanel.Dock      = 'Left'
$form.Controls.Add($menuPanel)

# Right content
$contentPanel = New-Object System.Windows.Forms.Panel
$contentPanel.Dock      = 'Fill'
$contentPanel.BackColor = [System.Drawing.Color]::White
$form.Controls.Add($contentPanel)

# Helper to add menu buttons
function Add-MenuButton {
    Param($text, $y, [ScriptBlock]$action)
    $btn = [System.Windows.Forms.Button]::new(Text=$text,
        Size=[System.Drawing.Size]::new(180,40),
        Location=[System.Drawing.Point]::new(10,$y))
    $btn.Add_Click($action)
    $menuPanel.Controls.Add($btn)
}

# Menu definitions
Add-MenuButton 'Dashboard'        20 { Show-DashboardView $contentPanel }
Add-MenuButton 'Classes'          70 { Show-ClassesView    $contentPanel }
Add-MenuButton 'Virtual Machines' 120{ Show-VMsView        $contentPanel; On-RefreshVMsClick }
Add-MenuButton 'Networks'         170{ Show-NetworksView   $contentPanel }
Add-MenuButton 'Logs'             220{ Show-LogsView       $contentPanel }
Add-MenuButton 'Exit'             700{ $form.Close() }

# Controller handler for refreshing the VM grid
function On-RefreshVMsClick {
    $grid = $contentPanel.Controls | Where-Object { $_.Tag -eq 'VMGrid' }
    if ($grid) {
        $grid.Rows.Clear()
        $vms = Invoke-ShowPoweredOnVMs ''
        foreach ($line in $vms -split "`n") {
            $parts = $line -split '\|'
            if ($parts.Length -eq 7) {
                $grid.Rows.Add($parts)
            }
        }
    }
}

# Launch
Show-DashboardView $contentPanel
[System.Windows.Forms.Application]::Run($form)