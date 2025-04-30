<#
.SYNOPSIS
    Renders the Virtual Machines management screen.
.DESCRIPTION
    Displays a filterable grid of all VMs including Name, Class, Student, PowerState, IP, CPU, and Memory.
    Allows filtering, powering on/off, restarting, and removing selected VMs.
.PARAMETER ContentPanel
    The Panel control where this view is rendered.
.EXAMPLE
    Show-VMsView -ContentPanel $split.Panel2
#>

# Load WinForms types
Add-Type -AssemblyName 'System.Windows.Forms'
Add-Type -AssemblyName 'System.Drawing'

# Ensure models are available
if (-not (Get-Command ConnectTo-VMServer -ErrorAction SilentlyContinue)) {
    Import-Module "$PSScriptRoot\..\VMwareModels.psm1" -ErrorAction Stop
}

function Show-VMsView {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Forms.Panel]$ContentPanel
    )

    # Clear previous controls
    $ContentPanel.Controls.Clear()

    # Title label
    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Text = 'Virtual Machines'
    $lblTitle.Font = New-Object System.Drawing.Font('Segoe UI', 16, [System.Drawing.FontStyle]::Bold)
    $lblTitle.AutoSize = $true
    $lblTitle.Location = New-Object System.Drawing.Point(10, 10)
    $ContentPanel.Controls.Add($lblTitle)

    # Filter input
    $lblFilter = New-Object System.Windows.Forms.Label
    $lblFilter.Text = 'Filter:'
    $lblFilter.Location = [System.Drawing.Point]::new(10, 45)
    $lblFilter.AutoSize = $true
    $ContentPanel.Controls.Add($lblFilter)

    $txtFilter = New-Object System.Windows.Forms.TextBox
    $txtFilter.Location = [System.Drawing.Point]::new(60, 42)
    $txtFilter.Width = 200
    $ContentPanel.Controls.Add($txtFilter)

    # Action buttons
    $btns = @{}
    $buttonDefs = @(
        @{ Id='Refresh'; Text='Refresh'; X=280 },
        @{ Id='PowerOn'; Text='Power On'; X=390 },
        @{ Id='PowerOff';Text='Power Off';X=500 },
        @{ Id='Restart'; Text='Restart'; X=610 },
        @{ Id='Remove';  Text='Remove';  X=720 }
    )

    foreach ($def in $buttonDefs) {
        $btn = New-Object System.Windows.Forms.Button
        $btn.Text = $def.Text
        $btn.Size = [System.Drawing.Size]::new(100, 30)
        $btn.Location = [System.Drawing.Point]::new($def.X, 38)
        $btn.Enabled = ($def.Id -eq 'Refresh')
        $ContentPanel.Controls.Add($btn)
        $btns[$def.Id] = $btn
    }

    # DataGridView setup
    $grid = New-Object System.Windows.Forms.DataGridView
    $grid.Location = [System.Drawing.Point]::new(10, 80)
    $grid.Size = [System.Drawing.Size]::new(940, 400)
    $grid.ReadOnly = $true
    $grid.AllowUserToAddRows = $false
    $grid.SelectionMode = 'FullRowSelect'
    $grid.MultiSelect = $false
    $grid.AutoGenerateColumns = $false

    # Define grid columns
    $columns = @(
        @{ Name='Name';       Width=160 },
        @{ Name='Class';      Width=100 },
        @{ Name='Student';    Width=100 },
        @{ Name='PowerState'; Width=100 },
        @{ Name='IP';         Width=150 },
        @{ Name='CPU';        Width=60  },
        @{ Name='MemoryMB';   Width=90  }
    )

    foreach ($col in $columns) {
        $column = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
        $column.HeaderText = $col.Name
        $column.DataPropertyName = $col.Name
        $column.Width = $col.Width
        $grid.Columns.Add($column)
    }

    $ContentPanel.Controls.Add($grid)

    # Helper: parse class/student from name (e.g., "CS101_S5_DB1")
    function Split-ClassStudent {
        param([string]$name)

        if ($name -match '^([A-Za-z]+\d+)_((?:S)?\d+)_?') {
            return @{ Class = $matches[1]; Student = $matches[2] }
        }
        return @{ Class = ""; Student = "" }
    }

    # Load VMs into grid
    function Get-VMs {
        ConnectTo-VMServer

        $vmlist = Get-VM | Select-Object `
            @{ n='Name';       e={ $_.Name }},
            @{ n='PowerState'; e={ $_.PowerState }},
            @{ n='IP';         e={ ($_.Guest.IPAddress)[0] }},
            @{ n='CPU';        e={ $_.NumCpu }},
            @{ n='MemoryMB';   e={ $_.MemoryMB } }

        $dt = New-Object System.Data.DataTable
        foreach ($col in 'Name','Class','Student','PowerState','IP','CPU','MemoryMB') {
            $dt.Columns.Add($col) | Out-Null
        }

        foreach ($vm in $vmlist) {
            $parsed = Split-ClassStudent -name $vm.Name
            $row = $dt.NewRow()
            $row['Name']       = $vm.Name
            $row['Class']      = $parsed.Class
            $row['Student']    = $parsed.Student
            $row['PowerState'] = $vm.PowerState
            $row['IP']         = $vm.IP
            $row['CPU']        = $vm.CPU
            $row['MemoryMB']   = $vm.MemoryMB
            $dt.Rows.Add($row)
        }

        $grid.DataSource = $dt
    }

    # Filter support
    $txtFilter.Add_TextChanged({
        $filter = $txtFilter.Text.Replace("'", "''")
        if ([string]::IsNullOrWhiteSpace($filter)) {
            $grid.DataSource.DefaultView.RowFilter = ''
        } else {
            $grid.DataSource.DefaultView.RowFilter =
                "Name LIKE '%$filter%' OR PowerState LIKE '%$filter%' OR Class LIKE '%$filter%' OR Student LIKE '%$filter%'"
        }
    })

    # Grid selection toggles action buttons
    $grid.Add_SelectionChanged({
        $has = $grid.SelectedRows.Count -gt 0
        $btns['PowerOn'].Enabled  = $has
        $btns['PowerOff'].Enabled = $has
        $btns['Restart'].Enabled  = $has
        $btns['Remove'].Enabled   = $has
    })

    # Button actions
    $btns['Refresh'].Add_Click({ Get-VMs })

    $btns['PowerOn'].Add_Click({
        $name = $grid.SelectedRows[0].Cells['Name'].Value
        Start-VM -VM $name -Confirm:$false | Out-Null
        Get-VMs
    })

    $btns['PowerOff'].Add_Click({
        $name = $grid.SelectedRows[0].Cells['Name'].Value
        Stop-VM -VM $name -Confirm:$false | Out-Null
        Get-VMs
    })

    $btns['Restart'].Add_Click({
        $name = $grid.SelectedRows[0].Cells['Name'].Value
        Stop-VM -VM $name -Confirm:$false | Out-Null
        Start-VM -VM $name -Confirm:$false | Out-Null
        Get-VMs
    })

    $btns['Remove'].Add_Click({
        $name = $grid.SelectedRows[0].Cells['Name'].Value
        Remove-VM -VM $name -DeletePermanently -Confirm:$false | Out-Null
        Get-VMs
    })

    # Initial load
    Get-VMs
}

Export-ModuleMember -Function Show-VMsView