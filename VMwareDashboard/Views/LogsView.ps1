<#
.SYNOPSIS
    Renders the Logs screen.
#>
function Show-LogsView {
    Param(
        [Parameter(Mandatory)][System.Windows.Forms.Panel]$ContentPanel
    )
    $ContentPanel.Controls.Clear()
    $tb = [System.Windows.Forms.TextBox]::new(
        Multiline   = $true,
        ScrollBars  = 'Vertical',
        Dock        = 'Fill'
    )
    $ContentPanel.Controls.Add($tb)
}

Export-ModuleMember -Function Show-LogsView