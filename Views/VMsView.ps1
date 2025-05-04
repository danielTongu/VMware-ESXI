<#
.SYNOPSIS
    Renders the Virtual Machines management screen, resilient against connection failures.
.DESCRIPTION
    Displays a filterable grid of all VMs including Name, Folder, Status, IP, CPU, Memory, Template, and Datastore.
    Allows filtering, powering on/off, restarting, and removing selected VMs.
    Remains functional in offline mode or when errors occur.
.PARAMETER ContentPanel
    The Panel control where this view is rendered.
.NOTES
    Resilient design based on Main.ps1: always shows UI even if connection fails.
.EXAMPLE
    Show-VMsView -ContentPanel $split.Panel2
#>

Add-Type -AssemblyName 'System.Windows.Forms'
Add-Type -AssemblyName 'System.Drawing'


function Show-VMsView {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.Forms.Panel]$ContentPanel
    )

    # Clear any existing UI controls
    $ContentPanel.Controls.Clear()

    # Title label
    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Text = 'Virtual Machines'
    $lblTitle.Font = New-Object System.Drawing.Font('Segoe UI', 16, [System.Drawing.FontStyle]::Bold)
    $lblTitle.AutoSize = $true
    $lblTitle.Location = New-Object System.Drawing.Point(10, 10)
    $ContentPanel.Controls.Add($lblTitle)


    # Offline mode indicator
    if ($global:VMwareConfig.OfflineMode) {
        $lblOffline = New-Object System.Windows.Forms.Label
        $lblOffline.Text = 'OFFLINE MODE - Live data unavailable'
        $lblOffline.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Italic)
        $lblOffline.ForeColor = [System.Drawing.Color]::DarkRed
        $lblOffline.AutoSize = $true
        $lblOffline.Location = New-Object System.Drawing.Point(220, 16)
        $ContentPanel.Controls.Add($lblOffline)
    }


    # Filter controls
    $lblFilter = New-Object System.Windows.Forms.Label
    $lblFilter.Text = 'Filter:'
    $lblFilter.Location = [System.Drawing.Point]::new(10, 45)
    $lblFilter.AutoSize = $true
    $ContentPanel.Controls.Add($lblFilter)

    $txtFilter = New-Object System.Windows.Forms.TextBox
    $txtFilter.Location = [System.Drawing.Point]::new(60, 42)
    $txtFilter.Width = 200
    $ContentPanel.Controls.Add($txtFilter)


    # Define action buttons
    $btns = @{}
    $buttonDefinitions = @(
        @{ Id = 'Refresh'; Text = 'Refresh'; X = 280 }
        @{ Id = 'PowerOn'; Text = 'Power On'; X = 390 }
        @{ Id = 'PowerOff'; Text = 'Power Off'; X = 500 }
        @{ Id = 'Restart'; Text = 'Restart'; X = 610 }
        @{ Id = 'Remove'; Text = 'Remove'; X = 720 }
    )

    foreach ($def in $buttonDefinitions) {
        $btn = New-Object System.Windows.Forms.Button
        $btn.Name = "btn$($def.Id)"
        $btn.Text = $def.Text
        $btn.Size = [System.Drawing.Size]::new(100, 30)
        $btn.Location = [System.Drawing.Point]::new($def.X, 38)
        # Only Refresh is enabled by default
        if ($def.Id -eq 'Refresh') {
            $btn.Enabled = $true
        } else {
            $btn.Enabled = $false
        }
        $ContentPanel.Controls.Add($btn)
        $btns[$def.Id] = $btn
    }


    # Setup DataGridView
    $grid = New-Object System.Windows.Forms.DataGridView
    $grid.Name = 'gvVMs'
    $grid.Location = [System.Drawing.Point]::new(10, 80)
    $grid.Size = [System.Drawing.Size]::new(940, 400)
    $grid.ReadOnly = $true
    $grid.AllowUserToAddRows = $false
    $grid.SelectionMode = 'FullRowSelect'
    $grid.MultiSelect = $false
    $grid.AutoGenerateColumns = $false


    # Define grid columns
    $columnDefinitions = @(
        @{ Name = 'Name'; HeaderText = 'VM Name';   Width = 160; Type = 'System.String' }
        @{ Name = 'Folder'; HeaderText = 'Folder';    Width = 150; Type = 'System.String' }
        @{ Name = 'PowerState'; HeaderText = 'Status'; Width = 80;  Type = 'System.String' }
        @{ Name = 'IP'; HeaderText = 'IP';           Width = 120; Type = 'System.String' }
        @{ Name = 'CPU'; HeaderText = 'vCPUs';        Width = 60;  Type = 'System.Int32' }
        @{ Name = 'MemoryGB'; HeaderText = 'Memory(GB)'; Width = 80; Type = 'System.Decimal' }
        @{ Name = 'Template'; HeaderText = 'Template'; Width = 120; Type = 'System.String' }
        @{ Name = 'Datastore'; HeaderText = 'Datastore'; Width = 120; Type = 'System.String' }
    )

    foreach ($colDef in $columnDefinitions) {
        $col = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
        $col.Name = $colDef.Name
        $col.HeaderText = $colDef.HeaderText
        $col.Width = $colDef.Width
        $col.ValueType = [Type]::GetType($colDef.Type)
        $grid.Columns.Add($col) | Out-Null
    }



    $ContentPanel.Controls.Add($grid)



    <#
    .SYNOPSIS
        Parses class and student from folder path.
    .PARAMETER folderPath
        The full folder path string.
    .OUTPUTS
        Hashtable with Class and Student keys.
    #>
    function Get-ClassStudentFromFolder {
        param(
            [string]$folderPath
        )
        $result = @{ Class = ''; Student = '' }
        try {
            if ($folderPath -match '\[(.*?)\]\s*(.*?)\\?$') {
                $parts = $matches[2] -split '_'
                if ($parts.Count -ge 2) {
                    $result.Class = $parts[0]
                    $result.Student = $parts[1]
                }
            }
        } catch {
            # Ignore parse errors
        }
        return $result
    }




    <#
    .SYNOPSIS
        Refreshes the VM list in the grid.
    .DESCRIPTION
        Fetches VM data when online, or clears grid in offline mode.
    #>
    function Refresh-VMList {
        try {
            if (-not $global:VMwareConfig.OfflineMode) {
                # Attempt to get connection
                $conn = [VMServerConnection]::GetInstance().GetConnection()

                # Retrieve VM data
                $vms = Get-VM -Server $conn | Select-Object -Property Name, Folder, PowerState,
                    @{ Name = 'IP'; Expression = { ($_.Guest.IPAddress -join ', ') } },
                    @{ Name = 'CPU'; Expression = { $_.NumCpu } },
                    @{ Name = 'MemoryGB'; Expression = { [math]::Round($_.MemoryGB, 2) } },
                    @{ Name = 'Template'; Expression = { $_.ExtensionData.Config.Template } },
                    @{ Name = 'Datastore'; Expression = { (Get-Datastore -Id $_.DatastoreIdList[0] -Server $conn).Name } }

                # Build DataTable
                $table = New-Object System.Data.DataTable
                foreach ($colDef in $columnDefinitions) {
                    $table.Columns.Add($colDef.Name, [Type]::GetType($colDef.Type)) | Out-Null
                }

                # Populate rows
                foreach ($vm in $vms) {
                    $row = $table.NewRow()
                    $row['Name'] = $vm.Name
                    $row['Folder'] = $vm.Folder.Name
                    $cs = Get-ClassStudentFromFolder -folderPath $vm.Folder.Path
                    if ($cs.Class) {
                        $row['Folder'] = "${cs.Class} [${cs.Student}]"
                    }
                    $row['PowerState'] = $vm.PowerState
                    $row['IP'] = $vm.IP
                    $row['CPU'] = $vm.CPU
                    $row['MemoryGB'] = $vm.MemoryGB
                    $row['Template'] = if ($vm.Template) { 'Yes' } else { 'No' }
                    $row['Datastore'] = $vm.Datastore
                    $table.Rows.Add($row)
                }

                $grid.DataSource = $table
            } else {
                # Offline: clear grid
                $grid.DataSource = $null
            }
        } catch {
            [System.Windows.Forms.MessageBox]::Show(
                "Failed to load VMs: $_",
                'Error',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
            # On error, clear data to keep UI responsive
            $grid.DataSource = $null
            $global:VMwareConfig.OfflineMode = $true
        } finally {
            # Reset selection and buttons
            if ($grid.DataSource -is [System.Data.DataTable]) {
                $grid.ClearSelection()
            }
            $btns['PowerOn'].Enabled = $false
            $btns['PowerOff'].Enabled = $false
            $btns['Restart'].Enabled = $false
            $btns['Remove'].Enabled = $false
        }
    }



    # Text filter logic
    $txtFilter.Add_TextChanged({
        try {
            if (-not $grid.DataSource) { return }
            $filterText = $txtFilter.Text.Replace("'", "''")
            if ([string]::IsNullOrWhiteSpace($filterText)) {
                $grid.DataSource.DefaultView.RowFilter = ''
            } else {
                $criteria = "Name LIKE '%$filterText%' OR `Folder LIKE '%$filterText%' OR `PowerState LIKE '%$filterText%' OR IP LIKE '%$filterText%' OR `Datastore LIKE '%$filterText%'"
                $grid.DataSource.DefaultView.RowFilter = $criteria
            }
        } catch {
            Write-Warning "Filter error: $_"
        }
    })


    # Selection change updates button state
    $grid.Add_SelectionChanged({
        $has = $false
        if ($grid.SelectedRows.Count -gt 0) { $has = $true }
        $btns['PowerOn'].Enabled = $has
        $btns['PowerOff'].Enabled = $has
        $btns['Restart'].Enabled = $has
        $btns['Remove'].Enabled = $has
    })


    # Button click handlers
    $btns['Refresh'].Add_Click({ Refresh-VMList })


    # Power On VM with error handling
    $btns['PowerOn'].Add_Click({
        try {
            $vmName = $grid.SelectedRows[0].Cells['Name'].Value
            $vmObj = [VMwareVM]::new($vmName, $null, $null, $null, $null)
            $vmObj.PowerOn()
            Refresh-VMList
        } catch {
            [System.Windows.Forms.MessageBox]::Show(
                "Failed to power on VM: $_",
                'Error',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
        }
    })


    # Power Off VM with error handling
    $btns['PowerOff'].Add_Click({
        try {
            $vmName = $grid.SelectedRows[0].Cells['Name'].Value
            $vmObj = [VMwareVM]::new($vmName, $null, $null, $null, $null)
            $vmObj.PowerOff()
            Refresh-VMList
        } catch {
            [System.Windows.Forms.MessageBox]::Show(
                "Failed to power off VM: $_",
                'Error',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
        }
    })


    # Restart VM with error handling
    $btns['Restart'].Add_Click({
        try {
            $vmName = $grid.SelectedRows[0].Cells['Name'].Value
            $vmObj = [VMwareVM]::new($vmName, $null, $null, $null, $null)
            $vmObj.PowerOff()
            Start-Sleep -Seconds 2
            $vmObj.PowerOn()
            Refresh-VMList
        } catch {
            [System.Windows.Forms.MessageBox]::Show(
                "Failed to restart VM: $_",
                'Error',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
        }
    })

    # Remove VM with confirmation
    $btns['Remove'].Add_Click({
        $vmName = $grid.SelectedRows[0].Cells['Name'].Value
        $confirm = [System.Windows.Forms.MessageBox]::Show(
            "Are you sure you want to permanently delete '$vmName'?",
            'Confirm Delete',
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        if ($confirm -eq [System.Windows.Forms.DialogResult]::Yes) {
            try {
                $vmObj = [VMwareVM]::new($vmName, $null, $null, $null, $null)
                $vmObj.Remove()
                Refresh-VMList
            } catch {
                [System.Windows.Forms.MessageBox]::Show(
                    "Failed to remove VM: $_",
                    'Error',
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Error
                )
            }
        }
    })
    
    # Load initial data
    Refresh-VMList
}
