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

    # Clear any existing UI controls and set background
    $ContentPanel.Controls.Clear()
    $ContentPanel.BackColor = [System.Drawing.Color]::White

    # Table layout: title row + controls row + grid row
    $layout = New-Object System.Windows.Forms.TableLayoutPanel
    $layout.Dock      = 'Fill'
    $layout.RowCount  = 4
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 60)))
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 50)))
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 30)))
    $ContentPanel.Controls.Add($layout)

    # title row
    $titlePanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $titlePanel.Dock          = 'Fill'
    $titlePanel.FlowDirection = 'LeftToRight'
    $titlePanel.WrapContents  = $false
    $titlePanel.Padding       = '10,5,10,5'
    $layout.Controls.Add($titlePanel, 0, 0)

    # Title label with improved styling
    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Text = 'Virtual Machines Management'
    $lblTitle.Font = New-Object System.Drawing.Font('Segoe UI', 18, [System.Drawing.FontStyle]::Bold)
    $lblTitle.ForeColor = [System.Drawing.Color]::DarkSlateBlue
    $lblTitle.AutoSize = $true
    $titlePanel.Controls.Add($lblTitle)

    # Offline mode indicator with better visibility
    if ($global:VMwareConfig.OfflineMode) {
        $lblOffline = New-Object System.Windows.Forms.Label
        $lblOffline.Text = 'OFFLINE MODE - Live data unavailable'
        $lblOffline.Font = New-Object System.Drawing.Font('Segoe UI', 12, [System.Drawing.FontStyle]::Italic)
        $lblOffline.ForeColor = [System.Drawing.Color]::DarkRed
        $lblOffline.AutoSize = $true
        $titlePanel.Controls.Add($lblOffline)
    }

    #controls row
    $controlsPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $controlsPanel.Dock          = 'Fill'
    $controlsPanel.FlowDirection = 'LeftToRight'
    $controlsPanel.WrapContents  = $false
    $controlsPanel.Padding       = '10,5,10,5'
    $controlsPanel.Location = [System.Drawing.Point]::new(0, 40)
    $layout.Controls.Add($controlsPanel, 0, 1)

    # Filter controls with improved layout
    $lblFilter = New-Object System.Windows.Forms.Label
    $lblFilter.Text = 'Filter:'
    $lblFilter.Font = New-Object System.Drawing.Font('Segoe UI', 11)
    $controlsPanel.Controls.Add($lblFilter)

    $txtFilter = New-Object System.Windows.Forms.TextBox
    $txtFilter.Font = New-Object System.Drawing.Font('Segoe UI', 11)
    $txtFilter.BorderStyle = 'FixedSingle'
    $txtFilter.Width = 300
    $txtFilter.Location = [System.Drawing.Point]::new(20, 0) 
    $controlsPanel.Controls.Add($txtFilter)

    # Action buttons with consistent styling
    $buttonStyle = @{
        Font = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)
        Size = New-Object System.Drawing.Size(100, 30)
        FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        foreColor = [System.Drawing.Color]::Black
    }

    $btns = @{}
    $buttonDefinitions = @(
        @{ Id = 'Refresh'; Text = 'Refresh'; X = 340; BackColor = [System.Drawing.Color]::LightSteelBlue }
        @{ Id = 'PowerOn'; Text = 'Power On'; X = 450; BackColor = [System.Drawing.Color]::LightGreen }
        @{ Id = 'PowerOff'; Text = 'Power Off'; X = 560; BackColor = [System.Drawing.Color]::LightCoral }
        @{ Id = 'Restart'; Text = 'Restart'; X = 670; BackColor = [System.Drawing.Color]::LightGoldenrodYellow }
        @{ Id = 'Remove'; Text = 'Remove'; X = 780; BackColor = [System.Drawing.Color]::LightCoral }
    )

    foreach ($def in $buttonDefinitions) {
        $btn = New-Object System.Windows.Forms.Button
        $btn.Name = "btn$($def.Id)"
        $btn.Text = $def.Text
        $btn.Font = $buttonStyle.Font
        $btn.Size = $buttonStyle.Size
        $btn.BackColor = $def.BackColor
        $btn.FlatStyle = $buttonStyle.FlatStyle
        $btn.ForeColor = $buttonStyle.foreColor
        
        # Only Refresh is enabled by default
        $btn.Enabled = $def.Id -eq 'Refresh'
        $controlsPanel.Controls.Add($btn)
        $btns[$def.Id] = $btn
    }

    #grid row
    $gridPanel = New-Object System.Windows.Forms.DataGridView
    $gridPanel.Name = 'gvVMs'
    $gridPanel.ColumnHeadersHeightSizeMode = 'AutoSize'
    $gridPanel.Dock = 'Fill'
    $gridPanel.AutoSizeColumnsMode = 'Fill'
    $gridPanel.Location = [System.Drawing.Point]::new(15, 150)
    $gridPanel.ReadOnly = $true
    $gridPanel.AllowUserToAddRows = $false
    $gridPanel.SelectionMode = 'FullRowSelect'
    $gridPanel.MultiSelect = $false
    $gridPanel.AutoGenerateColumns = $false
    $gridPanel.Font = New-Object System.Drawing.Font('Segoe UI', 11)
    $gridPanel.BackgroundColor = [System.Drawing.Color]::White
    $gridPanel.BorderStyle = 'FixedSingle'
    
    $gridPanel.ColumnHeadersDefaultCellStyle = @{
        Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
        ForeColor = [System.Drawing.Color]::Black
    }
    $gridPanel.AlternatingRowsDefaultCellStyle.BackColor = [System.Drawing.Color]::AliceBlue
    $gridPanel.RowHeadersVisible = $false
    $layout.Controls.Add($gridPanel, 0, 2)

    # Define grid columns with improved formatting
    $columnDefinitions = @(
        @{ Name = 'Name'; HeaderText = 'VM Name'; Width = 180; Type = 'System.String' }
        @{ Name = 'Folder'; HeaderText = 'Folder'; Width = 180; Type = 'System.String' }
        @{ Name = 'PowerState'; HeaderText = 'Status'; Width = 100; Type = 'System.String' }
        @{ Name = 'IP'; HeaderText = 'IP Address'; Width = 150; Type = 'System.String' }
        @{ Name = 'CPU'; HeaderText = 'vCPUs'; Width = 70; Type = 'System.Int32'; Alignment = 'MiddleRight' }
        @{ Name = 'MemoryGB'; HeaderText = 'Memory (GB)'; Width = 90; Type = 'System.Decimal'; Alignment = 'MiddleRight' }
        @{ Name = 'Template'; HeaderText = 'Template'; Width = 80; Type = 'System.String' }
        @{ Name = 'Datastore'; HeaderText = 'Datastore'; Width = 150; Type = 'System.String' }
    )

    foreach ($colDef in $columnDefinitions) {
        $col = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
        $col.Name = $colDef.Name
        $col.HeaderText = $colDef.HeaderText
        $col.Width = $colDef.Width
        $col.ValueType = [Type]::GetType($colDef.Type)
        $col.DefaultCellStyle = New-Object System.Windows.Forms.DataGridViewCellStyle
        $col.DefaultCellStyle.Font = New-Object System.Drawing.Font('Segoe UI', 11)
        
        if ($colDef.Alignment) {
            $col.DefaultCellStyle.Alignment = [System.Windows.Forms.DataGridViewContentAlignment]::$($colDef.Alignment)
        }
        
        $gridPanel.Columns.Add($col) | Out-Null
    }

    # Status bar at bottom
    $statusBar = New-Object System.Windows.Forms.StatusBar
    $statusBar.Text = 'Ready'
    $statusBar.Font = New-Object System.Drawing.Font('Segoe UI', 10)
    $statusBar.Dock = 'Bottom'
    $layout.Controls.Add($statusBar, 0, 3)

    # Function to parse class and student from folder path
    function Get-ClassStudentFromFolder {
        param([string]$folderPath)
        $result = @{ Class = ''; Student = '' }
        try {
            if ($folderPath -match '\[(.*?)\]\s*(.*?)\\?$') {
                $parts = $matches[2] -split '_'
                if ($parts.Count -ge 2) {
                    $result.Class = $parts[0]
                    $result.Student = $parts[1]
                }
            }
        } catch {}
        return $result
    }

    # Function to refresh the VM list in the grid
    function Refresh-VMList {
        try {
            $statusBar.Text = 'Loading VM data...'
            $mainContainer.Refresh()

            if (-not $global:VMwareConfig.OfflineMode) {
                $conn = [VMServerConnection]::GetInstance().GetConnection()
                if (-not $conn) { throw "Not connected to vCenter" }

                $vms = Get-VM -Server $conn | Select-Object -Property Name, Folder, PowerState,
                    @{ Name = 'IP'; Expression = { ($_.Guest.IPAddress -join ', ') } },
                    @{ Name = 'CPU'; Expression = { $_.NumCpu } },
                    @{ Name = 'MemoryGB'; Expression = { [math]::Round($_.MemoryGB, 2) } },
                    @{ Name = 'Template'; Expression = { if ($_.ExtensionData.Config.Template) { 'Yes' } else { 'No' } } },
                    @{ Name = 'Datastore'; Expression = { (Get-Datastore -Id $_.DatastoreIdList[0] -Server $conn).Name } }

                $table = New-Object System.Data.DataTable
                foreach ($colDef in $columnDefinitions) {
                    $table.Columns.Add($colDef.Name, [Type]::GetType($colDef.Type)) | Out-Null
                }

                foreach ($vm in $vms) {
                    $row = $table.NewRow()
                    $row['Name'] = $vm.Name
                    
                    # Format folder with class/student info if available
                    $cs = Get-ClassStudentFromFolder -folderPath $vm.Folder.Path
                    $row['Folder'] = if ($cs.Class) { "${cs.Class} [${cs.Student}]" } else { $vm.Folder.Name }
                    
                    $row['PowerState'] = $vm.PowerState
                    $row['IP'] = $vm.IP
                    $row['CPU'] = $vm.CPU
                    $row['MemoryGB'] = $vm.MemoryGB
                    $row['Template'] = $vm.Template
                    $row['Datastore'] = $vm.Datastore
                    $table.Rows.Add($row)
                }

                $gridPanel.DataSource = $table
                $statusBar.Text = "Loaded $($table.Rows.Count) VMs"
            } else {
                $gridPanel.DataSource = $null
                $statusBar.Text = 'Offline mode - no live data available'
            }
        } catch {
            [System.Windows.Forms.MessageBox]::Show(
                "Failed to load VMs: $_",
                'Error',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
            $gridPanel.DataSource = $null
            $statusBar.Text = "Error: $_"
        } finally {
            if ($gridPanel.DataSource -is [System.Data.DataTable]) {
                $gridPanel.ClearSelection()
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
            if (-not $gridPanel.DataSource) { return }
            $filterText = $txtFilter.Text.Replace("'", "''")
            $gridPanel.DataSource.DefaultView.RowFilter = if ([string]::IsNullOrWhiteSpace($filterText)) {
                ''
            } else {
                "Name LIKE '%$filterText%' OR Folder LIKE '%$filterText%' OR PowerState LIKE '%$filterText%' OR IP LIKE '%$filterText%' OR Datastore LIKE '%$filterText%'"
            }
        } catch {
            $statusBar.Text = "Filter error: $_"
        }
    })

    # Selection change updates button state
    $gridPanel.Add_SelectionChanged({
        $hasSelection = $gridPanel.SelectedRows.Count -gt 0
        $btns['PowerOn'].Enabled = $hasSelection
        $btns['PowerOff'].Enabled = $hasSelection
        $btns['Restart'].Enabled = $hasSelection
        $btns['Remove'].Enabled = $hasSelection
    })

    # Button click handlers with improved feedback
    $btns['Refresh'].Add_Click({ Refresh-VMList })

    $btns['PowerOn'].Add_Click({
        try {
            $vmName = $gridPanel.SelectedRows[0].Cells['Name'].Value
            $statusBar.Text = "Powering on $vmName..."
            $mainContainer.Refresh()
            
            $vmObj = [VMwareVM]::new($vmName, $null, $null, $null, $null)
            $vmObj.PowerOn()
            Refresh-VMList
            $statusBar.Text = "$vmName powered on successfully"
        } catch {
            $statusBar.Text = "Failed to power on VM: $_"
            [System.Windows.Forms.MessageBox]::Show(
                "Failed to power on VM: $_",
                'Error',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
        }
    })

    $btns['PowerOff'].Add_Click({
        try {
            $vmName = $gridPanel.SelectedRows[0].Cells['Name'].Value
            $statusBar.Text = "Powering off $vmName..."
            $mainContainer.Refresh()
            
            $vmObj = [VMwareVM]::new($vmName, $null, $null, $null, $null)
            $vmObj.PowerOff()
            Refresh-VMList
            $statusBar.Text = "$vmName powered off successfully"
        } catch {
            $statusBar.Text = "Failed to power off VM: $_"
            [System.Windows.Forms.MessageBox]::Show(
                "Failed to power off VM: $_",
                'Error',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
        }
    })

    $btns['Restart'].Add_Click({
        try {
            $vmName = $grid.SelectedRows[0].Cells['Name'].Value
            $statusBar.Text = "Restarting $vmName..."
            $mainContainer.Refresh()
            
            $vmObj = [VMwareVM]::new($vmName, $null, $null, $null, $null)
            $vmObj.PowerOff()
            Start-Sleep -Seconds 2
            $vmObj.PowerOn()
            Refresh-VMList
            $statusBar.Text = "$vmName restarted successfully"
        } catch {
            $statusBar.Text = "Failed to restart VM: $_"
            [System.Windows.Forms.MessageBox]::Show(
                "Failed to restart VM: $_",
                'Error',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
        }
    })

    $btns['Remove'].Add_Click({
        $vmName = $gridPanel.SelectedRows[0].Cells['Name'].Value
        $confirm = [System.Windows.Forms.MessageBox]::Show(
            "Are you sure you want to permanently delete '$vmName'?",
            'Confirm Delete',
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        if ($confirm -eq [System.Windows.Forms.DialogResult]::Yes) {
            try {
                $statusBar.Text = "Deleting $vmName..."
                $mainContainer.Refresh()
                
                $vmObj = [VMwareVM]::new($vmName, $null, $null, $null, $null)
                $vmObj.Remove()
                Refresh-VMList
                $statusBar.Text = "$vmName deleted successfully"
            } catch {
                $statusBar.Text = "Failed to delete VM: $_"
                [System.Windows.Forms.MessageBox]::Show(
                    "Failed to delete VM: $_",
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