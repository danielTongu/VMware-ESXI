# Required assemblies
Add-Type -AssemblyName 'System.Windows.Forms'
Add-Type -AssemblyName 'System.Drawing'



<#
    .SYNOPSIS
    Displays a list of virtual machines in a grid format with search and action buttons.
    .DESCRIPTION
    Creates a Windows Forms panel that displays VMs in a grid format.
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
        # Build UI skeleton
        $uiRefs = New-VMsLayout -ContentPanel $ContentPanel

        # Populate data if connected
        $data = Get-VMsData

        if ($data) {
            Update-VMsWithData -UiRefs $uiRefs -Data $data
        } else {
            $uiRefs.StatusLabel.Text = 'No connection to vSphere'
            $uiRefs.StatusLabel.ForeColor = $global:Theme.Error
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
    Builds the UI skeleton following the CWU theme:
        - Header with title
        - Filter controls
        - Main grid area
        - Action buttons footer
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
        $ContentPanel.BackColor = $global:Theme.LightGray

        # Root layout
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

        # Header panel
        $header = New-Object System.Windows.Forms.Panel
        $header.Dock = 'Fill'
        $header.Height = 60
        $header.BackColor = $global:Theme.Primary

        $root.Controls.Add($header, 0, 0)

        $titleLabel = New-Object System.Windows.Forms.Label
        $titleLabel.Text = 'VIRTUAL MACHINES'
        $titleLabel.Font = [System.Drawing.Font]::New('Segoe UI', 18, [System.Drawing.FontStyle]::Bold)
        $titleLabel.ForeColor = $global:Theme.White
        $titleLabel.Location = [System.Drawing.Point]::New(20, 15)
        $titleLabel.AutoSize = $true

        $header.Controls.Add($titleLabel)

        # Filter controls
        $filterPanel = New-Object System.Windows.Forms.Panel
        $filterPanel.Dock = 'Fill'
        $filterPanel.Height = 50
        $filterPanel.BackColor = $global:Theme.LightGray

        $root.Controls.Add($filterPanel, 0, 1)

        $searchBox = New-Object System.Windows.Forms.TextBox
        $searchBox.Name = 'txtFilter'
        $searchBox.Width = 300
        $searchBox.Height = 30
        $searchBox.Location = [System.Drawing.Point]::New(20, 10)
        $searchBox.Font = [System.Drawing.Font]::New('Segoe UI', 10)
        $searchBox.BackColor = $global:Theme.White
        $searchBox.ForeColor = $global:Theme.PrimaryDarker

        $filterPanel.Controls.Add($searchBox)

        $searchBtn = New-Object System.Windows.Forms.Button
        $searchBtn.Name = 'btnSearch'
        $searchBtn.Text = 'SEARCH'
        $searchBtn.Width = 100
        $searchBtn.Height = 30
        $searchBtn.Location = [System.Drawing.Point]::New(330, 10)
        $searchBtn.Font = [System.Drawing.Font]::New('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
        $searchBtn.BackColor = $global:Theme.Primary
        $searchBtn.ForeColor = $global:Theme.White

        $filterPanel.Controls.Add($searchBtn)

        # Main grid
        $grid = New-Object System.Windows.Forms.DataGridView
        $grid.Name = 'gvVMs'
        $grid.Dock = 'Fill'
        $grid.AutoSizeColumnsMode = 'Fill'
        $grid.ReadOnly = $true
        $grid.AllowUserToAddRows = $false
        $grid.SelectionMode = 'FullRowSelect'
        $grid.MultiSelect = $false
        $grid.AutoGenerateColumns = $false
        $grid.BackgroundColor = $global:Theme.White
        $grid.BorderStyle = 'FixedSingle'
        $grid.ColumnHeadersDefaultCellStyle.Font = [System.Drawing.Font]::New('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)

        $root.Controls.Add($grid, 0, 2)

        # Grid columns
        $columns = @(
            @{ Name = 'Name';       HeaderText = 'VM Name' }
            @{ Name = 'PowerState'; HeaderText = 'Status' }
            @{ Name = 'IP';         HeaderText = 'IP Address' }
            @{ Name = 'CPU';        HeaderText = 'vCPU' }
            @{ Name = 'MemoryGB';   HeaderText = 'Memory (GB)' }
        )

        foreach ($col in $columns) {
            $gridCol = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
            $gridCol.Name = $col.Name
            $gridCol.HeaderText = $col.HeaderText
            $grid.Columns.Add($gridCol) | Out-Null
        }

        # Action buttons footer
        $footer = New-Object System.Windows.Forms.FlowLayoutPanel
        $footer.Dock = 'Fill'
        $footer.Height = 50
        $footer.FlowDirection = 'LeftToRight'
        $footer.BackColor = $global:Theme.LightGray
        $footer.Padding = [System.Windows.Forms.Padding]::New(10,5,10,5)
        $root.Controls.Add($footer, 0, 3)

        $actions = @(
            @{ Name = 'Refresh';    Text = 'REFRESH' }
            @{ Name = 'PowerOn';    Text = 'POWER ON' }
            @{ Name = 'PowerOff';   Text = 'POWER OFF' }
            @{ Name = 'Restart';    Text = 'RESTART' }
        )

        $btns = @{}

        foreach ($act in $actions) {
            $btn = New-Object System.Windows.Forms.Button
            $btn.Name = "btn$($act.Name)"
            $btn.Text = $act.Text
            $btn.Width = 120
            $btn.Height = 35
            $btn.Margin = [System.Windows.Forms.Padding]::New(5)
            $btn.Font = [System.Drawing.Font]::New('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
            $btn.BackColor = $global:Theme.Primary
            $btn.ForeColor = $global:Theme.White
            $btns[$act.Name] = $btn

            $footer.Controls.Add($btn)
        }

        # Status label
        $statusLabel = New-Object System.Windows.Forms.Label
        $statusLabel.Name = 'StatusLabel'
        $statusLabel.Text = 'DISCONNECTED'
        $statusLabel.AutoSize = $true
        $statusLabel.Font = [System.Drawing.Font]::New('Segoe UI', 9)
        $statusLabel.ForeColor = $global:Theme.PrimaryDarker

        $root.Controls.Add($statusLabel, 0, 4)

        # Return UI refs
        return @{ 
            Grid = $grid 
            SearchBox = $searchBox 
            SearchButton = $searchBtn
            StatusLabel = $statusLabel
            Buttons = $btns 
        }
    }
    finally {
        $ContentPanel.ResumeLayout($true)
    }
}



<#
    .SYNOPSIS
    Retrieves VM data from vSphere connection.
    .DESCRIPTION
    Collects required VM data. Returns $null if no connection.
    .OUTPUTS
    [hashtable] - VM collection and timestamp
#>
function Get-VMsData {
    [CmdletBinding()]
    param()

    try {
        $conn = [VMServerConnection]::GetInstance().GetConnection()

        if (-not $conn) { return $null }

        $vms = Get-VM -Server $conn | Select-Object Name, PowerState,
            @{Name='IP';        Expression={($_.Guest.IPAddress -join ', ')}},
            @{Name='CPU';       Expression={$_.NumCpu}},
            @{Name='MemoryGB';  Expression={[math]::Round($_.MemoryGB,2)}}

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
    .PARAMETER UiRefs
    Hashtable of UI references
    .PARAMETER Data
    Hashtable containing VM data
#>
function Update-VMsWithData {
    [CmdletBinding()]
    param([hashtable]$UiRefs, [hashtable]$Data)

    try {
        if ($Data.VMs) {
            # Build DataTable
            $table = New-Object System.Data.DataTable

            foreach ($col in $UiRefs.Grid.Columns) { 
                $table.Columns.Add($col.Name,[string]) | Out-Null 
            }

            foreach ($vm in $Data.VMs) {
                $row = $table.NewRow()
                $row['Name']       = $vm.Name
                $row['PowerState'] = $vm.PowerState
                $row['IP']         = $vm.IP
                $row['CPU']        = $vm.CPU
                $row['MemoryGB']   = $vm.MemoryGB

                $table.Rows.Add($row)
            }

            $UiRefs.Grid.DataSource = $table
            $UiRefs.StatusLabel.Text = "Last updated: $($Data.LastUpdated.ToString('HH:mm:ss')) | $($table.Rows.Count) VMs"
        } else {
            $UiRefs.Grid.DataSource = $null
            $UiRefs.StatusLabel.Text = 'No VM data available'
        }
    }
    catch {
        Write-Verbose "Failed to update VMs view: $_"
        $UiRefs.StatusLabel.Text = 'Error loading VM data'
    }
}