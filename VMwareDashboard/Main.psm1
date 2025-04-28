<#
.SYNOPSIS
    Provides Start-VMwareDashboard to boot the WinForms GUI.
#>

function Start-VMwareDashboard {
    [CmdletBinding()]
    param()

    # Load Views
    $views = Join-Path (Split-Path $MyInvocation.MyCommand.Path) 'Views'
    Get-ChildItem $views -Filter '*.ps1' | ForEach-Object { . $_.FullName }

    # Build form
    Add-Type -AssemblyName System.Windows.Forms, System.Drawing
    $form = [Windows.Forms.Form]::new(Text='VMware Dashboard', Size=[Drawing.Size]::new(1100,800), StartPosition='CenterScreen')

    # Menu panel
    $menu = [Windows.Forms.Panel]::new(BackColor=[Drawing.Color]::LightGray, Size=[Drawing.Size]::new(200,800), Dock='Left')
    $form.Controls.Add($menu)

    # Content panel
    $content = [Windows.Forms.Panel]::new(BackColor=[Drawing.Color]::White, Dock='Fill')
    $form.Controls.Add($content)

    # Helper for menu buttons
    function Add-MenuButton {
        param($text,$y,$action)
        $b = [Windows.Forms.Button]::new(Text=$text, Size=[Drawing.Size]::new(180,40), Location=[Drawing.Point]::new(10,$y))
        $b.Add_Click($action)
        $menu.Controls.Add($b)
    }

    # Wire up
    Add-MenuButton 'Dashboard'        20 { Show-DashboardView $content }
    Add-MenuButton 'Classes'          70 { Show-ClassesView   $content }
    Add-MenuButton 'Virtual Machines' 120{ Show-VMsView       $content }
    Add-MenuButton 'Networks'         170{ Show-NetworksView  $content }
    Add-MenuButton 'Logs'             220{ Show-LogsView      $content }
    Add-MenuButton 'Exit'             700{ $form.Close() }

    # Start
    Show-DashboardView $content
    [Windows.Forms.Application]::Run($form)
}

Export-ModuleMember -Function Start-VMwareDashboard