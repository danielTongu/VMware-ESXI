<#
.SYNOPSIS
    Renders everything to do with Networks.
#>
function Show-NetworksView {
    Param(
        [Parameter(Mandatory)][System.Windows.Forms.Panel]$ContentPanel
    )
    $ContentPanel.Controls.Clear()

    # Title
    $lbl = [System.Windows.Forms.Label]::new(
        Text     = 'Networks',
        Font     = [System.Drawing.Font]::new('Segoe UI',20,[System.Drawing.FontStyle]::Bold),
        AutoSize = $true,
        Location = [System.Drawing.Point]::new(30,20)
    )
    $ContentPanel.Controls.Add($lbl)

    # List of networks (ListBox)
    $lst = [System.Windows.Forms.ListBox]::new(
        Location = [System.Drawing.Point]::new(30,80),
        Size     = [System.Drawing.Size]::new(300,300)
    )
    # TODO: populate $lst.Items with existing networks
    $ContentPanel.Controls.Add($lst)

    # Add Network
    $btnAdd = [System.Windows.Forms.Button]::new(
        Text     = 'Add Network',
        Location = [System.Drawing.Point]::new(360,80),
        Size     = [System.Drawing.Size]::new(120,30)
    )
    $btnAdd.Add_Click({
        $name = Read-Host 'Network name to add'
        $res  = Invoke-AddNetwork "-NetworkName '$name'"
        [System.Windows.Forms.MessageBox]::Show($res,'Add Network')
    })
    $ContentPanel.Controls.Add($btnAdd)

    # Delete Network
    $btnDel = [System.Windows.Forms.Button]::new(
        Text     = 'Delete Network',
        Location = [System.Drawing.Point]::new(360,130),
        Size     = [System.Drawing.Size]::new(120,30)
    )
    $btnDel.Add_Click({
        $name = Read-Host 'Network name to delete'
        $res  = Invoke-DeleteNetwork "-NetworkName '$name'"
        [System.Windows.Forms.MessageBox]::Show($res,'Delete Network')
    })
    $ContentPanel.Controls.Add($btnDel)

    # Bulk Add
    $btnAddAll = [System.Windows.Forms.Button]::new(
        Text     = 'Add Networks (CSV)',
        Location = [System.Drawing.Point]::new(360,180),
        Size     = [System.Drawing.Size]::new(120,30)
    )
    $btnAddAll.Add_Click({
        $path = [System.Windows.Forms.OpenFileDialog]::new().ShowDialog()
        # TODO: read CSV and call Invoke-AddNetworks
    })
    $ContentPanel.Controls.Add($btnAddAll)

    # Bulk Delete
    $btnDelAll = [System.Windows.Forms.Button]::new(
        Text     = 'Delete Networks (CSV)',
        Location = [System.Drawing.Point]::new(360,230),
        Size     = [System.Drawing.Size]::new(120,30)
    )
    $btnDelAll.Add_Click({
        # TODO: similar CSV logic + Invoke-DeleteNetworks
    })
    $ContentPanel.Controls.Add($btnDelAll)
}

Export-ModuleMember -Function Show-NetworksView