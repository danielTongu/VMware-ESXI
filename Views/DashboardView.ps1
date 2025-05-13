# Import required assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms.DataVisualization



<#
    .SYNOPSIS
        Renders the ESXi dashboard into a WinForms panel.
    .DESCRIPTION
        Builds layout, retrieves vSphere data, and injects into UI.
    .PARAMETER ContentPanel
        The parent WinForms Panel for rendering.
#>
function Show-DashboardView {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Forms.Panel]$ContentPanel
    )

    try {
        # Build UI skeleton
        $uiRefs = New-DashboardLayout -ContentPanel $ContentPanel

        # Populate with data if connected
        $data = Get-DashboardData
        if ($data) {
            Update-DashboardWithData -UiRefs $uiRefs -Data $data
        } else {
            $uiRefs['StatusLabel'].Text = 'No connection to VMware server'
            $uiRefs['StatusLabel'].ForeColor = $global:Theme.Error
        }
    } catch {
        Write-Verbose "Dashboard initialization failed: $_"
    }
}



<#
    .SYNOPSIS
        Retrieves dashboard data from vSphere.
    .DESCRIPTION
        Gathers host, VM, datastore, event, adapter, template, port group, and orphan file info.
    .OUTPUTS
        Hashtable of data collections or $null if disconnected.
#>
function Get-DashboardData {
    [CmdletBinding()]
    param()

    try {
        $conn = [VMServerConnection]::GetInstance().GetConnection()
        if (-not $conn) { return $null }

        $data = @{
            HostInfo   = Get-VMHost -Server $conn -ErrorAction SilentlyContinue
            VMs        = Get-VM -Server $conn -ErrorAction SilentlyContinue
            Datastores = Get-Datastore -Server $conn -ErrorAction SilentlyContinue
            Events     = Get-VIEvent -Server $conn -MaxSamples 10 -ErrorAction SilentlyContinue
            Adapters   = Get-VMHostNetworkAdapter -Server $conn -ErrorAction SilentlyContinue
            Templates  = Get-Template -Server $conn -ErrorAction SilentlyContinue
        }

        $data.PortGroups   = try { [VMwareNetwork]::ListPortGroups() } catch { @() }

        $data.OrphanedFiles = try { 
            if ($data.Datastores) { [OrphanCleaner]::FindOrphanedFiles($data.Datastores[0].Name) } 
            else { @() } 
        } catch { @() }

        return $data
    } catch {
        Write-Verbose "Data collection failed: $_"
        return $null
    }
}



<#
    .SYNOPSIS
        Creates the dashboard layout: header, tabs, actions, footer.
    .PARAMETER ContentPanel
        Panel into which the layout is rendered.
    .OUTPUTS
        Hashtable of UI element references.
#>
function New-DashboardLayout {
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
        $root = [System.Windows.Forms.TableLayoutPanel]::new()
        $root.Dock = 'Fill'; 
        $root.ColumnCount = 1; 
        $root.RowCount = 4
        $root.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Percent,100))
        $root.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::AutoSize))   # Header
        $root.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Percent,100)) # Tabs
        $root.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::AutoSize))   # Actions
        $root.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::AutoSize))   # Footer
        
        $ContentPanel.Controls.Add($root)

        # Header
        $root.Controls.Add((New-DashboardHeader), 0, 0)

        # Tabs
        $tabs = [System.Windows.Forms.TabControl]::new()
        $tabs.Dock = 'Fill'; 
        $tabs.SizeMode = 'Fixed'; 
        $tabs.ItemSize = [System.Drawing.Size]::new(250,40)
        $tabs.Font = [System.Drawing.Font]::new('Segoe UI',10,[System.Drawing.FontStyle]::Bold)
        $tabs.BackColor = $global:Theme.LightGray
        
        $root.Controls.Add($tabs,0,1)
        $refs = @{}

        # Stats Tab
        $tabStats = [System.Windows.Forms.TabPage]::new('Host Statistics')
        $statsPanel = New-DashboardStats -Refs ([ref]$refs)
        $tabStats.Controls.Add($statsPanel)
        
        $tabs.TabPages.Add($tabStats)

        # Alerts Tab
        $tabAlerts = [System.Windows.Forms.TabPage]::new('Recent Alerts and Events')
        $tabAlerts.BackColor = $global:Theme.LightGray
        $alertsTable = New-DashboardTable -Columns @('Time','Severity','Message','Object') -Name 'AlertsTable' -Refs ([ref]$refs)
        $tabAlerts.Controls.Add($alertsTable)
        
        $tabs.TabPages.Add($tabAlerts)

        # Storage Tab
        $tabStorage = [System.Windows.Forms.TabPage]::new('Storage Overview')
        $tabStorage.BackColor = $global:Theme.LightGray
        $storageTable = New-DashboardTable -Columns @('Datastore','Capacity (GB)','Used (GB)','Free (GB)','Usage') -Name 'StorageTable' -Refs ([ref]$refs)
        $tabStorage.Controls.Add($storageTable)
        $tabs.TabPages.Add($tabStorage)

        # Actions bar
        $actions = New-DashboardActions -Refs ([ref]$refs) -ParentPanel $ContentPanel
        $root.Controls.Add($actions,0,2)

        # Footer
        $footer = [System.Windows.Forms.Panel]::new()
        $footer.Dock = 'Bottom'; 
        $footer.Height = 30; 
        $footer.BackColor = $global:Theme.LightGray

        $status = [System.Windows.Forms.Label]::new()
        $status.Name = 'StatusLabel'; 
        $status.AutoSize = $true
        $status.Font = [System.Drawing.Font]::new('Segoe UI',9)
        $status.ForeColor = $global:Theme.Error
        $status.Text = 'DISCONNECTED'

        $footer.Controls.Add($status)
        $root.Controls.Add($footer,0,3)

        $refs['StatusLabel'] = $status

        return $refs

    } finally { 
        $ContentPanel.ResumeLayout($true)
    }
}


<#
    .SYNOPSIS
        Creates the colored header bar with title and last-refresh time.
#>
function New-DashboardHeader {
    $p = [System.Windows.Forms.Panel]::new()
    $p.Dock = 'Top'; 
    $p.Height = 100; 
    $p.BackColor = $global:Theme.Primary

    $lbl = [System.Windows.Forms.Label]::new()
    $lbl.Text = 'DASHBOARD';
    $lbl.Font = [System.Drawing.Font]::new('Segoe UI',18,[System.Drawing.FontStyle]::Bold)
    $lbl.ForeColor = $global:Theme.White; 
    $lbl.Location = [System.Drawing.Point]::new(20,20)
    $lbl.AutoSize = $true; 
    
    $p.Controls.Add($lbl)

    $ref = [System.Windows.Forms.Label]::new()
    $ref.Name = 'LastRefreshLabel'; 
    $ref.Text = "Last refresh: $(Get-Date -Format 'HH:mm:ss')"
    $ref.Font = [System.Drawing.Font]::new('Segoe UI',9)
    $ref.ForeColor = $global:Theme.White; 
    $ref.Location = [System.Drawing.Point]::new(20,60)
    $ref.AutoSize = $true; $p.Controls.Add($ref)

    return $p
}



<#
    .SYNOPSIS
        Generates the stats card panel.
    .PARAMETER Refs
        Reference hashtable for card value labels.
#>
function New-DashboardStats {
    param([ref]$Refs)

    $p = [System.Windows.Forms.FlowLayoutPanel]::new()
    $p.Dock = 'Top'; 
    $p.AutoSize = $true; 
    $p.Padding = 10; 
    $p.WrapContents = $true; 
    $p.AutoScroll = $true
    $p.BackColor = $global:Theme.White

    $cards = @(
        @{Key='TotalVMs';      Title='TOTAL VMS';     Icon=[char]0xE8F1},
        @{Key='RunningVMs';    Title='RUNNING VMS';   Icon=[char]0xE768},
        @{Key='Datastores';    Title='DATASTORES';    Icon=[char]0xE958},
        @{Key='Adapters';      Title='ADAPTERS';      Icon=[char]0xE8EF},
        @{Key='Templates';     Title='TEMPLATES';     Icon=[char]0xE8A5},
        @{Key='PortGroups';    Title='PORT GROUPS';   Icon=[char]0xE8EE},
        @{Key='OrphanedFiles'; Title='ORPHAN FILES';  Icon=[char]0xE7BA}
    )

    foreach ($c in $cards) {
        $card = [System.Windows.Forms.Panel]::new()
        $card.Size = [System.Drawing.Size]::new(150,100); 
        $card.Padding = 5; $card.Margin = 5
        $card.BackColor = $global:Theme.White; 
        $card.BorderStyle = 'FixedSingle'

        $t = [System.Windows.Forms.Label]::new()
        $t.Text = $c.Title; 
        $t.Font = [System.Drawing.Font]::new('Segoe UI',9,[System.Drawing.FontStyle]::Bold)
        $t.Location = [System.Drawing.Point]::new(5,5); 
        $t.AutoSize = $true; 
        
        $card.Controls.Add($t)

        $v = [System.Windows.Forms.Label]::new()
        $v.Name = "${($c.Key)}Value";
        $v.Text = '--'
        $v.Font = [System.Drawing.Font]::new('Segoe UI',14)
        $v.Location = [System.Drawing.Point]::new(5,25); 
        $v.AutoSize = $true; 
        
        $card.Controls.Add($v)

        $i = [System.Windows.Forms.Label]::new()
        $i.Text = $c.Icon; 
        $i.Font = [System.Drawing.Font]::new('Segoe MDL2 Assets',20)
        $i.Location = [System.Drawing.Point]::new(5,65); 
        $i.AutoSize = $true
        $i.ForeColor = $global:Theme.Primary; 
        
        $card.Controls.Add($i)
        $p.Controls.Add($card)

        $Refs.Value["${($c.Key)}Value"] = $v
    }
    return $p
}



<#
    .SYNOPSIS
        Builds a DataGridView wrapped in a panel.
    .PARAMETER Columns
        Array of column names to create.
    .PARAMETER Name
        Control name for reference.
    .PARAMETER Refs
        Reference hashtable to store control reference.
#>
function New-DashboardTable {
    param(
        [string[]]$Columns,
        [string]$Name,
        [ref]$Refs
    )

    $container = [System.Windows.Forms.Panel]::new()
    $container.Dock = 'Fill'; 
    $container.Padding = [System.Windows.Forms.Padding]::new(10)
    $container.BackColor = $global:Theme.White

    $grid = [System.Windows.Forms.DataGridView]::new()
    $grid.Name = $Name; 
    $grid.Dock = 'Fill'
    $grid.AutoSizeColumnsMode = 'Fill'; 
    $grid.RowHeadersVisible = $false
    $grid.ReadOnly = $true; 
    $grid.AllowUserToAddRows = $false
    $grid.AllowUserToDeleteRows = $false; 
    $grid.AllowUserToResizeRows = $false
    $grid.AutoSizeRowsMode = 'AllCells'; 
    $grid.BackgroundColor = $global:Theme.White
    $grid.BorderStyle = 'FixedSingle'; 
    $grid.EnableHeadersVisualStyles = $false
    $grid.ColumnHeadersDefaultCellStyle.Font = [System.Drawing.Font]::new('Segoe UI',9,[System.Drawing.FontStyle]::Bold)
    $grid.DefaultCellStyle.BackColor = $global:Theme.White
    $grid.DefaultCellStyle.ForeColor = $global:Theme.PrimaryDark
    $grid.DefaultCellStyle.Font = [System.Drawing.Font]::new('Segoe UI',9)

    foreach ($col in $Columns) {
        $safe = 'col_' + ($col -replace '[^a-zA-Z0-9_]','')

        $c = [System.Windows.Forms.DataGridViewTextBoxColumn]::new()
        $c.Name = $safe;
        $c.HeaderText = $col; 
        $c.SortMode = 'NotSortable'

        [void]$grid.Columns.Add($c)
    }

    # Placeholder row
    $rowIndex = $grid.Rows.Add()

    for ($i = 0; $i -lt $Columns.Count; $i++) {
        $cell = $grid.Rows[$rowIndex].Cells[$i]
        $cell.Value = if ($i -eq 0) { 'No data available' } else { '--' }
        $cell.Style.Font = [System.Drawing.Font]::new('Segoe UI',9,[System.Drawing.FontStyle]::Italic)
    }

    $container.Controls.Add($grid)
    $Refs.Value[$Name] = $grid

    return $container
}



<#
    .SYNOPSIS
        Creates the Refresh button action bar.
    .PARAMETER Refs
        Reference hashtable for UI elements.
    .PARAMETER ParentPanel
        The main content panel to refresh.
#>
function New-DashboardActions {
    param([ref]$Refs, [System.Windows.Forms.Panel]$ParentPanel)

    $flow = [System.Windows.Forms.FlowLayoutPanel]::new()
    $flow.Dock = 'Fill'; 
    $flow.Padding = 10; 
    $flow.AutoSize = $true
    $flow.BackColor = $global:Theme.LightGray

    $btnRefresh = [System.Windows.Forms.Button]::new()
    $btnRefresh.Text = 'REFRESH'; 
    $btnRefresh.Font = [System.Drawing.Font]::new('Segoe UI',10,[System.Drawing.FontStyle]::Bold)
    $btnRefresh.Size = [System.Drawing.Size]::new(120,35)
    $btnRefresh.BackColor = $global:Theme.Primary; 
    $btnRefresh.ForeColor = $global:Theme.White
    $btnRefresh.FlatStyle = 'Flat'
    $btnRefresh.Add_Click({ Show-DashboardView -ContentPanel $ParentPanel })

    $flow.Controls.Add($btnRefresh)

    return $flow
}



<#
    .SYNOPSIS
        Injects live VMware data into the UI controls.
    .PARAMETER UiRefs
        Hashtable of UI element references.
    .PARAMETER Data
        Hashtable containing collections fetched from vSphere.
#>
function Update-DashboardWithData {
    [CmdletBinding()]
    param(
        [hashtable]$UiRefs,
        [hashtable]$Data
    )

    # Update stats
    $map = @{ 
        TotalVMs = $Data.VMs.Count; 
        RunningVMs = ($Data.VMs|Where-Object PowerState -eq 'PoweredOn').Count;
        Datastores = $Data.Datastores.Count; 
        Adapters = $Data.Adapters.Count;
        Templates = $Data.Templates.Count; 
        PortGroups = $Data.PortGroups.Count;
        OrphanedFiles = $Data.OrphanedFiles.Count 
    }

    foreach ($k in $map.Keys) {
        $UiRefs["${k}Value"].Text = $map[$k]
        $UiRefs["${k}Value"].ForeColor = $global:Theme.Primary
    }

    # Connection status
    if ($Data.HostInfo) {
        $h = $Data.HostInfo
        $UiRefs['StatusLabel'].Text = "CONNECTED to $($h.Name) | vSphere $($h.Version)"
        $UiRefs['StatusLabel'].ForeColor = $global:Theme.Success
    }

    # Last refresh
    $UiRefs['LastRefreshLabel'].Text = "Last refresh: $(Get-Date -Format 'HH:mm:ss')"

    # Alerts table
    if ($Data.Events) {
        $g = $UiRefs['AlertsTable']; $g.Rows.Clear()

        foreach ($e in $Data.Events) {
            $idx = $g.Rows.Add()
            
            $g.Rows[$idx].Cells['col_Time'].Value     = $e.CreatedTime
            $g.Rows[$idx].Cells['col_Severity'].Value = $e.GetType().Name
            $g.Rows[$idx].Cells['col_Message'].Value  = $e.FullFormattedMessage
            $g.Rows[$idx].Cells['col_Object'].Value   = $e.ObjectName

            if ($e.GetType().Name -match 'Error|Warning') {
                $g.Rows[$idx].Cells['col_Severity'].Style.ForeColor = $global:Theme.Error
            }
        }
    }

    # Storage table
    if ($Data.Datastores) {
        $g = $UiRefs['StorageTable']; $g.Rows.Clear()

        foreach ($d in $Data.Datastores) {
            $idx = $g.Rows.Add()

            $cap  = [math]::Round($d.CapacityGB,1)
            $free = [math]::Round($d.FreeSpaceGB,1)
            $used = $cap - $free; 
            $pct = 100 - $d.PercentFree

            $g.Rows[$idx].Cells['col_Datastore'].Value       = $d.Name
            $g.Rows[$idx].Cells['col_CapacityGB'].Value      = $cap
            $g.Rows[$idx].Cells['col_UsedGB'].Value          = $used
            $g.Rows[$idx].Cells['col_FreeGB'].Value          = $free
            $g.Rows[$idx].Cells['col_Usage'].Value           = "${pct}%"
            
            if ($d.PercentFree -lt 15) {
                $g.Rows[$idx].Cells['col_Usage'].Style.ForeColor = $global:Theme.Error
                $g.Rows[$idx].Cells['col_Usage'].Style.Font     = [System.Drawing.Font]::new('Segoe UI',9,[System.Drawing.FontStyle]::Bold)
            }
        }
    }
}