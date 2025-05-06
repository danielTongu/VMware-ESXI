Add-Type -AssemblyName 'System.Windows.Forms'
Add-Type -AssemblyName 'System.Drawing'

<##
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
function Show-VMsView {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.Forms.Panel]$ContentPanel
    )

    # Clear existing controls and apply background theme
    $ContentPanel.Controls.Clear()
    $ContentPanel.BackColor = $global:theme.Background

    # Setup main layout panel
    $layout = New-Object System.Windows.Forms.TableLayoutPanel
    $layout.Dock = 'Fill'
    $layout.RowCount = 4
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 60)))
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 50)))
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 30)))
    $ContentPanel.Controls.Add($layout)

    # Title row
    $titlePanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $titlePanel.Dock = 'Fill'
    $titlePanel.FlowDirection = 'LeftToRight'
    $titlePanel.WrapContents = $false
    $titlePanel.Padding = '10,5,10,5'
    $layout.Controls.Add($titlePanel, 0, 0)

    # Title label with accent color
    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Text = 'Virtual Machines'
    $lblTitle.Font = New-Object System.Drawing.Font('Segoe UI', 18, [System.Drawing.FontStyle]::Bold)
    $lblTitle.ForeColor = $global:theme.Primary
    $lblTitle.AutoSize = $true
    $titlePanel.Controls.Add($lblTitle)

    # Offline mode indicator
    if ($global:VMwareConfig.OfflineMode) {
        $lblOffline = New-Object System.Windows.Forms.Label
        $lblOffline.Text = 'OFFLINE MODE - Live data unavailable'
        $lblOffline.Font = New-Object System.Drawing.Font('Segoe UI', 12, [System.Drawing.FontStyle]::Italic)
        $lblOffline.ForeColor = $global:theme.Primary
        $lblOffline.AutoSize = $true
        $titlePanel.Controls.Add($lblOffline)
    }

    # Controls row
    $controlsPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $controlsPanel.Dock = 'Fill'
    $controlsPanel.FlowDirection = 'LeftToRight'
    $controlsPanel.WrapContents = $false
    $controlsPanel.Padding = '10,5,10,5'
    $layout.Controls.Add($controlsPanel, 0, 1)

    # Filter label
    $lblFilter = New-Object System.Windows.Forms.Label
    $lblFilter.Text = 'Filter:'
    $lblFilter.Font = New-Object System.Drawing.Font('Segoe UI', 11)
    $lblFilter.ForeColor = $global:theme.TextPrimary
    $controlsPanel.Controls.Add($lblFilter)

    # Filter textbox
    $txtFilter = New-Object System.Windows.Forms.TextBox
    $txtFilter.Font = New-Object System.Drawing.Font('Segoe UI', 11)
    $txtFilter.BackColor = $global:theme.CardBackground
    $txtFilter.ForeColor = $global:theme.TextPrimary
    $txtFilter.BorderStyle = 'FixedSingle'
    $txtFilter.Width = 300
    $controlsPanel.Controls.Add($txtFilter)

    # Button style template
    $buttonFont = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)

    # Define action buttons
    $buttonDefinitions = @(
        @{ Id = 'Refresh'; Text = 'Refresh' }
        @{ Id = 'PowerOn'; Text = 'Power On' }
        @{ Id = 'PowerOff'; Text = 'Power Off' }
        @{ Id = 'Restart'; Text = 'Restart' }
        @{ Id = 'Remove'; Text = 'Remove' }
    )

    # Create buttons using theme colors
    $btns = @{}
    foreach ($def in $buttonDefinitions) {
        # Initialize button
        $btn = New-Object System.Windows.Forms.Button
        $btn.Name  = "btn$($def.Id)"
        $btn.Text  = $def.Text
        $btn.Font  = $buttonFont
        $btn.Size  = New-Object System.Drawing.Size(100, 30)
        $btn.BackColor   = $global:theme.Secondary
        $btn.ForeColor   = $global:theme.CardBackground
        $btn.FlatStyle   = [System.Windows.Forms.FlatStyle]::Flat
        $btn.FlatAppearance.BorderColor = $global:theme.Border

        # Only enable Refresh by default
        $btn.Enabled = ($def.Id -eq 'Refresh')
        $controlsPanel.Controls.Add($btn)
        $btns[$def.Id] = $btn
    }

    # Grid row
    $gridPanel = New-Object System.Windows.Forms.DataGridView
    $gridPanel.Name                   = 'gvVMs'
    $gridPanel.Dock                   = 'Fill'
    $gridPanel.AutoSizeColumnsMode   = 'Fill'
    $gridPanel.ReadOnly              = $true
    $gridPanel.AllowUserToAddRows    = $false
    $gridPanel.SelectionMode         = 'FullRowSelect'
    $gridPanel.MultiSelect           = $false
    $gridPanel.AutoGenerateColumns   = $false
    $gridPanel.Font                  = New-Object System.Drawing.Font('Segoe UI', 11)
    $gridPanel.BackgroundColor       = $global:theme.CardBackground
    $gridPanel.GridColor             = $global:theme.Border
    $gridPanel.BorderStyle           = 'FixedSingle'

    # Header and row styles
    $gridPanel.ColumnHeadersDefaultCellStyle.Font     = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
    $gridPanel.ColumnHeadersDefaultCellStyle.ForeColor = $global:theme.TextPrimary
    $gridPanel.AlternatingRowsDefaultCellStyle.BackColor = $global:theme.Secondary
    $gridPanel.RowHeadersVisible = $false
    $layout.Controls.Add($gridPanel, 0, 2)

    # Define columns
    $columnDefinitions = @(
        @{ Name='Name';       Header='VM Name';     Type='System.String' }
        @{ Name='Folder';     Header='Folder';      Type='System.String' }
        @{ Name='PowerState'; Header='Status';      Type='System.String' }
        @{ Name='IP';         Header='IP Address';  Type='System.String' }
        @{ Name='CPU';        Header='vCPUs';       Type='System.Int32'  }
        @{ Name='MemoryGB';   Header='Memory (GB)'; Type='System.Decimal'}
        @{ Name='Template';   Header='Template';    Type='System.String'}
        @{ Name='Datastore';  Header='Datastore';   Type='System.String'}
    )

    foreach ($colDef in $columnDefinitions) {
        # Create text column
        $col = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
        $col.Name            = $colDef.Name
        $col.HeaderText      = $colDef.Header
        $col.ValueType       = [Type]::GetType($colDef.Type)
        $col.DefaultCellStyle = New-Object System.Windows.Forms.DataGridViewCellStyle
        # Apply text color theme
        $col.DefaultCellStyle.ForeColor = $global:theme.TextPrimary
        $col.DefaultCellStyle.Font = New-Object System.Drawing.Font('Segoe UI', 11)
        $gridPanel.Columns.Add($col) | Out-Null
    }

    # Status bar at bottom
    $statusBar = New-Object System.Windows.Forms.StatusBar
    $statusBar.Text      = 'Ready'
    $statusBar.Font      = New-Object System.Drawing.Font('Segoe UI', 10)
    $statusBar.BackColor = $global:theme.CardBackground
    $statusBar.ForeColor = $global:theme.TextSecondary
    $statusBar.Dock      = 'Bottom'
    $layout.Controls.Add($statusBar, 0, 3)

    # Parses class and student from folder path
    function Get-ClassStudentFromFolder {
        param([string]$folderPath)
        <# Returns a hashtable with Class and Student extracted from folder naming convention #>
        $result = @{ Class = ''; Student = '' }
        try {
            if ($folderPath -match '\[(.*?)\]\s*(.*?)\\?$') {
                $parts = $matches[2] -split '_'
                if ($parts.Count -ge 2) {
                    $result.Class   = $parts[0]
                    $result.Student = $parts[1]
                }
            }
        } catch {}
        return $result
    }

    # Refreshes the VM list and updates grid
    function Refresh-VMList {
        <# Updates the DataGridView with current VM data #>
        try {
            $statusBar.Text = 'Loading VM data...'
            $ContentPanel.Refresh()

            if (-not $global:VMwareConfig.OfflineMode) {
                $conn = [VMServerConnection]::GetInstance().GetConnection()
                if (-not $conn) { throw 'Not connected to vCenter' }

                # Retrieve VM info
                $vms = Get-VM -Server $conn | Select Name, Folder, PowerState,
                    @{Name='IP';Expression={($_.Guest.IPAddress -join ', ')}},
                    @{Name='CPU';Expression={$_.NumCpu}},
                    @{Name='MemoryGB';Expression={[math]::Round($_.MemoryGB,2)}},
                    @{Name='Template';Expression={if ($_.ExtensionData.Config.Template) {'Yes'} else {'No'}}},
                    @{Name='Datastore';Expression={(Get-Datastore -Id $_.DatastoreIdList[0] -Server $conn).Name}}

                # Build DataTable
                $table = New-Object System.Data.DataTable
                foreach ($c in $gridPanel.Columns) { $table.Columns.Add($c.Name, $c.ValueType) | Out-Null }
                
                foreach ($vm in $vms) {
                    $row = $table.NewRow()
                    $row['Name']       = $vm.Name
                    
                    # Format folder
                    $cs = Get-ClassStudentFromFolder -folderPath $vm.Folder.Path
                    $row['Folder']     = if ($cs.Class) { "${cs.Class} [${cs.Student}]" } else { $vm.Folder.Name }
                    
                    $row['PowerState'] = $vm.PowerState
                    $row['IP']         = $vm.IP
                    $row['CPU']        = $vm.CPU
                    $row['MemoryGB']   = $vm.MemoryGB
                    $row['Template']   = $vm.Template
                    $row['Datastore']  = $vm.Datastore
                    $table.Rows.Add($row)
                }

                $gridPanel.DataSource = $table
                $statusBar.Text = "Loaded $($table.Rows.Count) VMs"
            } else {
                $gridPanel.DataSource = $null
                $statusBar.Text = 'Offline mode - no live data available'
            }
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Failed to load VMs: $_", 'Error', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            $gridPanel.DataSource = $null
            $statusBar.Text = "Error: $_"
        } finally {
            if ($gridPanel.DataSource -is [System.Data.DataTable]) { $gridPanel.ClearSelection() }
            # Disable action buttons until a row is selected
            $btns['PowerOn'].Enabled = $false
            $btns['PowerOff'].Enabled = $false
            $btns['Restart'].Enabled = $false
            $btns['Remove'].Enabled = $false
        }
    }

    # Filter textbox logic
    $txtFilter.Add_TextChanged({
        try {
            if (-not $gridPanel.DataSource) { return }
            $filterText = $txtFilter.Text.Replace("'","''")
            $gridPanel.DataSource.DefaultView.RowFilter = if ([string]::IsNullOrWhiteSpace($filterText)) { '' } else { "Name LIKE '%$filterText%' OR Folder LIKE '%$filterText%' OR PowerState LIKE '%$filterText%' OR IP LIKE '%$filterText%' OR Datastore LIKE '%$filterText%'" }
        } catch { $statusBar.Text = "Filter error: $_" }
    })

    # Grid selection changes
    $gridPanel.Add_SelectionChanged({
        $hasSelection = $gridPanel.SelectedRows.Count -gt 0
        $btns['PowerOn'].Enabled  = $hasSelection
        $btns['PowerOff'].Enabled = $hasSelection
        $btns['Restart'].Enabled  = $hasSelection
        $btns['Remove'].Enabled   = $hasSelection
    })

    # Button click handlers
    $btns['Refresh'].Add_Click({ Refresh-VMList })
    $btns['PowerOn'].Add_Click({
        try {
            $vmName = $gridPanel.SelectedRows[0].Cells['Name'].Value
            $statusBar.Text = "Powering on $vmName..."
            $ContentPanel.Refresh()
            $vmObj = [VMwareVM]::new($vmName,$null,$null,$null,$null)
            $vmObj.PowerOn()
            Refresh-VMList
            $statusBar.Text = "$vmName powered on successfully"
        } catch { $statusBar.Text = "Failed to power on VM: $_"; [System.Windows.Forms.MessageBox]::Show("Failed to power on VM: $_",'Error',[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error) }
    })
    $btns['PowerOff'].Add_Click({
        try {
            $vmName = $gridPanel.SelectedRows[0].Cells['Name'].Value
            $statusBar.Text = "Powering off $vmName..."
            $ContentPanel.Refresh()
            $vmObj = [VMwareVM]::new($vmName,$null,$null,$null,$null)
            $vmObj.PowerOff()
            Refresh-VMList
            $statusBar.Text = "$vmName powered off successfully"
        } catch { $statusBar.Text = "Failed to power off VM: $_"; [System.Windows.Forms.MessageBox]::Show("Failed to power off VM: $_",'Error',[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error) }
    })
    $btns['Restart'].Add_Click({
        try {
            $vmName = $gridPanel.SelectedRows[0].Cells['Name'].Value
            $statusBar.Text = "Restarting $vmName..."
            $ContentPanel.Refresh()
            $vmObj = [VMwareVM]::new($vmName,$null,$null,$null,$null)
            $vmObj.PowerOff()
            Start-Sleep -Seconds 2
            $vmObj.PowerOn()
            Refresh-VMList
            $statusBar.Text = "$vmName restarted successfully"
        } catch { $statusBar.Text = "Failed to restart VM: $_"; [System.Windows.Forms.MessageBox]::Show("Failed to restart VM: $_",'Error',[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error) }
    })
    $btns['Remove'].Add_Click({
        $vmName = $gridPanel.SelectedRows[0].Cells['Name'].Value
        $confirm = [System.Windows.Forms.MessageBox]::Show("Are you sure you want to permanently delete '$vmName'?", 'Confirm Delete', [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
        if ($confirm -eq [System.Windows.Forms.DialogResult]::Yes) {
            try {
                $statusBar.Text = "Deleting $vmName..."
                $ContentPanel.Refresh()
                $vmObj = [VMwareVM]::new($vmName,$null,$null,$null,$null)
                $vmObj.Remove()
                Refresh-VMList
                $statusBar.Text = "$vmName deleted successfully"
            } catch { $statusBar.Text = "Failed to delete VM: $_"; [System.Windows.Forms.MessageBox]::Show("Failed to delete VM: $_",'Error',[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error) }
        }
    })

    # Load initial data
    Refresh-VMList
}
