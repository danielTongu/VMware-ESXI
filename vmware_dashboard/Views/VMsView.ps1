<#
.SYNOPSIS
    Renders the VM Tasks screen.
#>
function Show-VMsView {
    Param(
        [Parameter(Mandatory)][System.Windows.Forms.Panel]$ContentPanel
    )
    $ContentPanel.Controls.Clear()

    # Title
    $lbl = [System.Windows.Forms.Label]::new(
        Text     = 'Virtual Machines',
        Font     = [System.Drawing.Font]::new('Segoe UI',20,[System.Drawing.FontStyle]::Bold),
        AutoSize = $true,
        Location = [System.Drawing.Point]::new(30,20)
    )
    $ContentPanel.Controls.Add($lbl)

    # Refresh
    $btnRef = [System.Windows.Forms.Button]::new(Text='Refresh',Location=[System.Drawing.Point]::new(30,80),Size=[System.Drawing.Size]::new(120,30))
    $btnRef.Add_Click({ On-RefreshVMsClick })
    $ContentPanel.Controls.Add($btnRef)

    # Grid
    $grid = [System.Windows.Forms.DataGridView]::new(
        Location = [System.Drawing.Point]::new(30,130),
        Size     = [System.Drawing.Size]::new(820,400),
        AutoSizeColumnsMode = 'Fill'
    )
    foreach ($col in 'Class','Student','Name','State','IP','CPU','MemoryMB') {
        $grid.Columns.Add($col,$col) | Out-Null
    }
    $grid.Tag = 'VMGrid'
    $ContentPanel.Controls.Add($grid)
}

Export-ModuleMember -Function Show-VMsView