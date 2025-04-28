<#
.SYNOPSIS
    Renders the Dashboard screen.
#>
function Show-DashboardView {
    Param(
        [Parameter(Mandatory)][System.Windows.Forms.Panel]$ContentPanel
    )
    $ContentPanel.Controls.Clear()

    $lbl = [System.Windows.Forms.Label]::new()
    $lbl.Text     = 'Welcome to VMware Dashboard'
    $lbl.Font     = [System.Drawing.Font]::new('Segoe UI',24,[System.Drawing.FontStyle]::Bold)
    $lbl.AutoSize = $true
    $lbl.Location = [System.Drawing.Point]::new(30,30)
    $ContentPanel.Controls.Add($lbl)
}

Export-ModuleMember -Function Show-DashboardView