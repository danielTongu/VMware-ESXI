Add-Type -AssemblyName 'System.Windows.Forms'
Add-Type -AssemblyName 'System.Drawing'



# ────────────────────────────────────────────────────────────────────────────
#                       views/VMsView.ps1
# ────────────────────────────────────────────────────────────────────────────



<#
.SYNOPSIS
    Displays a list of virtual machines in a grid format with search and action buttons.
.DESCRIPTION
    Creates a Windows Forms panel that displays VMs in a grid format.
    Follows the same pattern as the dashboard with separated UI and data loading.
.PARAMETER ContentPanel
    The Panel control where this view is rendered.
#>
function Show-VMsView {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Forms.Panel]$ContentPanel
    )

    try {
        # Build UI (empty)
        $uiRefs = New-VMsLayout -ContentPanel $ContentPanel

        # Populate with data if connected
        $data = Get-VMsData
        if ($data) {
            Update-VMsWithData -UiRefs $uiRefs -Data $data
        } else {
            $uiRefs.StatusLabel.Text = "No connection to vSphere"
            $uiRefs.StatusLabel.ForeColor = [System.Drawing.Color]::Red
            $uiRefs.Grid.DataSource = $null
        }
    }
    catch { 
        Write-Verbose "VMs view initialization failed: $_" 
    }
}




<#
.SYNOPSIS
    Creates the VMs view layout structure.
.DESCRIPTION
    Builds the UI skeleton following the same pattern as the dashboard:
    - Header with title
    - Filter controls
    - Main grid area
    - Footer with action buttons
.PARAMETER ContentPanel
    The parent Panel to build the UI in.
.OUTPUTS
    [hashtable] - References to UI elements
#>
function New-VMsLayout {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Forms.Panel]$ContentPanel
    )

    try {
        $ContentPanel.SuspendLayout()
        $ContentPanel.Controls.Clear()
        $ContentPanel.BackColor = $global:theme.Background

        # ── ROOT LAYOUT ─────────────────────────────────────────────────
        $root = New-Object System.Windows.Forms.TableLayoutPanel
        $root.Dock = 'Fill'
        $root.ColumnCount = 1
        $root.RowCount = 5
        $root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))   # Header
        $root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))   # Filter
        $root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent,100))) # Grid
        $root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))   # Actions
        $root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))   # Footer
        $ContentPanel.Controls.Add($root)



        #===== Row [1] HEADER =================================================
        $header = New-Object System.Windows.Forms.Panel
        $header.Dock = 'Fill'
        $header.Height = 60
        $header.BackColor = $global:theme.Primary
        $root.Controls.Add($header, 0, 0)

        $titleLabel = New-Object System.Windows.Forms.Label
        $titleLabel.Text = 'VIRTUAL MACHINES'
        $titleLabel.Font = New-Object System.Drawing.Font('Segoe UI', 18, [System.Drawing.FontStyle]::Bold)
        $titleLabel.ForeColor = [System.Drawing.Color]::White
        $titleLabel.Location = New-Object System.Drawing.Point(20, 15)
        $titleLabel.AutoSize = $true
        $header.Controls.Add($titleLabel)



        #===== Row [2] FILTER CONTROLS =========================================
        $filterPanel = New-Object System.Windows.Forms.Panel
        $filterPanel.Dock = 'Fill'
        $filterPanel.Height = 50
        $filterPanel.BackColor = $global:theme.Background
        $root.Controls.Add($filterPanel, 0, 1)

        $searchBox = New-Object System.Windows.Forms.TextBox
        $searchBox.Name = 'txtFilter'
        $searchBox.Width = 300
        $searchBox.Height = 30
        $searchBox.Location = New-Object System.Drawing.Point(20, 10)
        $searchBox.Font = New-Object System.Drawing.Font('Segoe UI', 10)
        $searchBox.BackColor = $global:theme.CardBackground
        $searchBox.ForeColor = $global:theme.TextPrimary
        $filterPanel.Controls.Add($searchBox)

        $searchBtn = New-Object System.Windows.Forms.Button
        $searchBtn.Name = 'btnSearch'
        $searchBtn.Text = "SEARCH"
        $searchBtn.Width = 100
        $searchBtn.Height = 30
        $searchBtn.Location = New-Object System.Drawing.Point(330, 10)
        $searchBtn.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
        $searchBtn.BackColor = $global:theme.Primary
        $searchBtn.ForeColor = [System.Drawing.Color]::White
        $filterPanel.Controls.Add($searchBtn)



        #===== Row [3]  MAIN GRID =================================================
        $gridPanel = New-Object System.Windows.Forms.DataGridView
        $gridPanel.Name = 'gvVMs'
        $gridPanel.Dock = 'Fill'
        $gridPanel.AutoSizeColumnsMode = 'Fill'
        $gridPanel.ReadOnly = $true
        $gridPanel.AllowUserToAddRows = $false
        $gridPanel.SelectionMode = 'FullRowSelect'
        $gridPanel.MultiSelect = $false
        $gridPanel.AutoGenerateColumns = $false
        $gridPanel.BackgroundColor = $global:theme.CardBackground
        $gridPanel.BorderStyle = 'FixedSingle'
        $gridPanel.ColumnHeadersDefaultCellStyle.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
        $root.Controls.Add($gridPanel, 0, 2)

        # Configure grid columns
        $columns = @(
            @{ Name = 'Name'; HeaderText = 'VM Name' }
            @{ Name = 'PowerState'; HeaderText = 'Status' }
            @{ Name = 'IP'; HeaderText = 'IP Address' }
            @{ Name = 'CPU'; HeaderText = 'vCPU' }
            @{ Name = 'MemoryGB'; HeaderText = 'Memory (GB)' }
        )

        foreach ($col in $columns) {
            $gridColumn = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
            $gridColumn.Name = $col.Name
            $gridColumn.HeaderText = $col.HeaderText
            $gridPanel.Columns.Add($gridColumn) | Out-Null
        }




        #===== Row [4] FOOTER WITH ACTION BUTTONS =================================
        $footer = New-Object System.Windows.Forms.FlowLayoutPanel
        $footer.Dock = 'Fill'
        $footer.Height = 50
        $footer.FlowDirection = 'LeftToRight'
        $footer.BackColor = $global:theme.Background
        $footer.Padding = New-Object System.Windows.Forms.Padding(10, 5, 10, 5)
        $root.Controls.Add($footer, 0, 3)

        # Action buttons
        $actions = @(
            @{ Name = 'Refresh'; Text = 'REFRESH' }
            @{ Name = 'PowerOn'; Text = 'POWER ON' }
            @{ Name = 'PowerOff'; Text = 'POWER OFF' }
            @{ Name = 'Restart'; Text = 'RESTART' }
        )

        $btns = @{}
        foreach ($action in $actions) {
            $btn = New-Object System.Windows.Forms.Button
            $btn.Name = "btn$($action.Name)"
            $btn.Text = $action.Text
            $btn.Width = 120
            $btn.Height = 35
            $btn.Margin = New-Object System.Windows.Forms.Padding(5)
            $btn.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
            $btn.BackColor = $global:theme.Primary
            $btn.ForeColor = [System.Drawing.Color]::White
            $btns[$action.Name] = $btn
            $footer.Controls.Add($btn)
        }

        # Status label
        $statusLabel = New-Object System.Windows.Forms.Label
        $statusLabel.Name = 'StatusLabel'
        $statusLabel.Text = 'DISCONNECTED'
        $statusLabel.Dock = 'Fill'
        $statusLabel.AutoSize = $true
        $statusLabel.Font = New-Object System.Drawing.Font('Segoe UI', 9)
        $statusLabel.ForeColor = $global:theme.TextSecondary
        $root.Controls.Add($statusLabel, 0, 4)

        # Return references to UI elements
        $refs = @{
            Grid = $gridPanel
            SearchBox = $searchBox
            SearchButton = $searchBtn
            StatusLabel = $statusLabel
            Buttons = $btns
        }

        return $refs
    }
    finally {
        $ContentPanel.ResumeLayout($true)
    }
}




<#
.SYNOPSIS
    Retrieves VM data from vSphere connection.
.DESCRIPTION
    Collects all required VM data from vSphere for the view.
    Handles connection errors and returns null if no connection.
.OUTPUTS
    [hashtable] - Dictionary containing VM data
#>
function Get-VMsData {
    [CmdletBinding()]
    param()

    try {
        $conn = [VMServerConnection]::GetInstance().GetConnection()
        if (-not $conn) {
            return $null
        }

        $vms = Get-VM -Server $conn | Select-Object Name, PowerState,
            @{Name='IP';Expression={($_.Guest.IPAddress -join ', ')}},
            @{Name='CPU';Expression={$_.NumCpu}},
            @{Name='MemoryGB';Expression={[math]::Round($_.MemoryGB,2)}}

        return @{
            VMs = $vms
            LastUpdated = (Get-Date)
        }
    }
    catch {
        Write-Verbose "VM data collection failed: $_"
        return $null
    }
}





<#
.SYNOPSIS
    Updates the VMs view with live data.
.DESCRIPTION
    Injects VM data into the UI controls.
.PARAMETER UiRefs
    Hashtable of UI element references
.PARAMETER Data
    Hashtable containing VM data collections
#>
function Update-VMsWithData {
    [CmdletBinding()]
    param(
        [hashtable]$UiRefs,
        [hashtable]$Data
    )

    try {
        if ($Data.VMs) {
            # Create data table
            $table = New-Object System.Data.DataTable
            foreach ($col in $UiRefs.Grid.Columns) { 
                $table.Columns.Add($col.Name, [string]) | Out-Null 
            }
            
            # Add VM data
            foreach ($vm in $Data.VMs) {
                $row = $table.NewRow()
                $row['Name'] = $vm.Name
                $row['PowerState'] = $vm.PowerState
                $row['IP'] = $vm.IP
                $row['CPU'] = $vm.CPU
                $row['MemoryGB'] = $vm.MemoryGB
                $table.Rows.Add($row)
            }

            $UiRefs.Grid.DataSource = $table
            $UiRefs.StatusLabel.Text = "Last updated: $($Data.LastUpdated.ToString('HH:mm:ss')) | $($table.Rows.Count) VMs"
        }
        else {
            $UiRefs.Grid.DataSource = $null
            $UiRefs.StatusLabel.Text = "No VM data available"
        }
    }
    catch {
        Write-Verbose "Failed to update VMs view: $_"
        $UiRefs.StatusLabel.Text = "Error loading VM data"
    }
}
