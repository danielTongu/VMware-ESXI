<#
Views/VMsView.ps1

.SYNOPSIS
    Renders the Virtual Machines management screen.

.DESCRIPTION
    Displays a filterable grid of all VMs including Name, PowerState, IP address, CPU count, and Memory.
    Provides buttons to Refresh, Power On, Power Off, Restart, and Remove the selected VM.
    A text box allows filtering the grid by VM Name or State.

.PARAMETER ContentPanel
    The WinForms Panel into which the VMs view is rendered.

.EXAMPLE
    Show-VMsView -ContentPanel $split.Panel2
#>
function Show-VMsView {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Forms.Panel]$ContentPanel
    )

    # --- Load WinForms assemblies ---
    Add-Type -AssemblyName 'System.Windows.Forms'
    Add-Type -AssemblyName 'System.Drawing'

    # --- 1) Clear existing controls ---
    $ContentPanel.Controls.Clear()

    # --- 2) Title label ---
    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Text      = 'Virtual Machines'
    $lblTitle.Font      = [System.Drawing.Font]::new('Segoe UI',16,[System.Drawing.FontStyle]::Bold)
    $lblTitle.AutoSize  = $true
    $lblTitle.Location  = [System.Drawing.Point]::new(10,10)
    $ContentPanel.Controls.Add($lblTitle)

    # --- 3) Filter label & textbox ---
    $lblFilter = New-Object System.Windows.Forms.Label
    $lblFilter.Text     = 'Filter:'
    $lblFilter.AutoSize = $true
    $lblFilter.Location = [System.Drawing.Point]::new(10,45)
    $ContentPanel.Controls.Add($lblFilter)

    $txtFilter = New-Object System.Windows.Forms.TextBox
    $txtFilter.Location = [System.Drawing.Point]::new(60,42)
    $txtFilter.Width    = 200
    $ContentPanel.Controls.Add($txtFilter)

    # --- 4) Action buttons ---
    # Refresh button
    $btnRefresh = New-Object System.Windows.Forms.Button
    $btnRefresh.Text     = 'Refresh'
    $btnRefresh.Size     = [System.Drawing.Size]::new(100,30)
    $btnRefresh.Location = [System.Drawing.Point]::new(280,38)
    $ContentPanel.Controls.Add($btnRefresh)

    # Power On button
    $btnPowerOn = New-Object System.Windows.Forms.Button
    $btnPowerOn.Text     = 'Power On'
    $btnPowerOn.Size     = [System.Drawing.Size]::new(100,30)
    $btnPowerOn.Location = [System.Drawing.Point]::new(390,38)
    $btnPowerOn.Enabled  = $false
    $ContentPanel.Controls.Add($btnPowerOn)

    # Power Off button
    $btnPowerOff = New-Object System.Windows.Forms.Button
    $btnPowerOff.Text     = 'Power Off'
    $btnPowerOff.Size     = [System.Drawing.Size]::new(100,30)
    $btnPowerOff.Location = [System.Drawing.Point]::new(500,38)
    $btnPowerOff.Enabled  = $false
    $ContentPanel.Controls.Add($btnPowerOff)

    # Restart button
    $btnRestart = New-Object System.Windows.Forms.Button
    $btnRestart.Text     = 'Restart'
    $btnRestart.Size     = [System.Drawing.Size]::new(100,30)
    $btnRestart.Location = [System.Drawing.Point]::new(610,38)
    $btnRestart.Enabled  = $false
    $ContentPanel.Controls.Add($btnRestart)

    # Remove button
    $btnRemove = New-Object System.Windows.Forms.Button
    $btnRemove.Text     = 'Remove'
    $btnRemove.Size     = [System.Drawing.Size]::new(100,30)
    $btnRemove.Location = [System.Drawing.Point]::new(720,38)
    $btnRemove.Enabled  = $false
    $ContentPanel.Controls.Add($btnRemove)

    # --- 5) Data grid ---
    $grid = New-Object System.Windows.Forms.DataGridView
    $grid.Location            = [System.Drawing.Point]::new(10,80)
    $grid.Size                = [System.Drawing.Size]::new(820,380)
    $grid.ReadOnly            = $true
    $grid.AllowUserToAddRows  = $false
    $grid.SelectionMode       = 'FullRowSelect'
    $grid.MultiSelect         = $false
    $grid.AutoGenerateColumns = $false

    # Define columns
    $colName = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colName.HeaderText      = 'Name'
    $colName.DataPropertyName = 'Name'
    $colName.Width            = 200
    $grid.Columns.Add($colName)

    $colState = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colState.HeaderText      = 'State'
    $colState.DataPropertyName = 'PowerState'
    $colState.Width            = 100
    $grid.Columns.Add($colState)

    $colIP = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colIP.HeaderText      = 'IP Address'
    $colIP.DataPropertyName = 'IP'
    $colIP.Width            = 150
    $grid.Columns.Add($colIP)

    $colCPU = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colCPU.HeaderText      = 'CPU'
    $colCPU.DataPropertyName = 'CPU'
    $colCPU.Width            = 80
    $grid.Columns.Add($colCPU)

    $colMem = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colMem.HeaderText      = 'Memory (MB)'
    $colMem.DataPropertyName = 'MemoryMB'
    $colMem.Width            = 100
    $grid.Columns.Add($colMem)

    $ContentPanel.Controls.Add($grid)

    # --- 6) Data loading function ---
    function Get-VMs {
        # Ensure we are connected
        ConnectTo-VMServer

        # Retrieve VM list and select needed properties
        $vmlist = Get-VM |
            Select-Object `
              @{ n='Name';       e={ $_.Name } }, `
              @{ n='PowerState'; e={ $_.PowerState } }, `
              @{ n='IP';         e={ ($_.Guest.IPAddress)[0] } }, `
              @{ n='CPU';        e={ $_.NumCpu } }, `
              @{ n='MemoryMB';   e={ $_.MemoryMB } }

        # Bind to grid via a DataTable for filtering
        $dt = New-Object System.Data.DataTable
        foreach ($col in 'Name','PowerState','IP','CPU','MemoryMB') {
            $dt.Columns.Add($col) | Out-Null
        }
        foreach ($vm in $vmlist) {
            $row = $dt.NewRow()
            $row['Name']       = $vm.Name
            $row['PowerState'] = $vm.PowerState
            $row['IP']         = $vm.IP
            $row['CPU']        = $vm.CPU
            $row['MemoryMB']   = $vm.MemoryMB
            $dt.Rows.Add($row)
        }
        $grid.DataSource = $dt
    }

    # --- 7) Filter handler ---
    $txtFilter.Add_TextChanged({
        $filter = $txtFilter.Text.Replace("'", "''")
        if ([string]::IsNullOrWhiteSpace($filter)) {
            $grid.DataSource.DefaultView.RowFilter = ''
        }
        else {
            $grid.DataSource.DefaultView.RowFilter =
              "Name LIKE '%$filter%' OR PowerState LIKE '%$filter%'"
        }
    })

    # --- 8) Row selection handler ---
    $grid.Add_SelectionChanged({
        $hasSelection = $grid.SelectedRows.Count -gt 0
        $btnPowerOn.Enabled  = $hasSelection
        $btnPowerOff.Enabled = $hasSelection
        $btnRestart.Enabled  = $hasSelection
        $btnRemove.Enabled   = $hasSelection
    })

    # --- 9) Button click handlers ---
    $btnRefresh.Add_Click({ Get-VMs })

    $btnPowerOn.Add_Click({
        $row = $grid.SelectedRows[0]
        $vmName = $row.Cells['Name'].Value
        Start-VM -VM $vmName -Confirm:$false | Out-Null
        Get-VMs
    })

    $btnPowerOff.Add_Click({
        $row = $grid.SelectedRows[0]
        $vmName = $row.Cells['Name'].Value
        Stop-VM -VM $vmName -Confirm:$false | Out-Null
        Get-VMs
    })

    $btnRestart.Add_Click({
        $row = $grid.SelectedRows[0]
        $vmName = $row.Cells['Name'].Value
        Stop-VM    -VM $vmName -Confirm:$false | Out-Null
        Start-VM   -VM $vmName -Confirm:$false | Out-Null
        Get-VMs
    })

    $btnRemove.Add_Click({
        $row = $grid.SelectedRows[0]
        $vmName = $row.Cells['Name'].Value
        Remove-VM -VM $vmName -DeletePermanently -Confirm:$false | Out-Null
        Get-VMs
    })

    # --- 10) Initial load ---
    Get-VMs
}

Export-ModuleMember -Function Show-VMsView