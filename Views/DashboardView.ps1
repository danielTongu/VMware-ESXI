
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms.DataVisualization



# ────────────────────────────────────────────────────────────────────────────
#                         Views/DashboardView.ps1
# ────────────────────────────────────────────────────────────────────────────



<#
.SYNOPSIS
    Renders the ESXi dashboard into a WinForms panel.
.DESCRIPTION
    1. Builds the UI skeleton (header → TabControl → actions → footer)
    2. Queries vSphere objects when connected
    3. Injects data into the UI
.PARAMETER ContentPanel
    The parent WinForms Panel (usually the Form's main area)
#>
function Show-DashboardView {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Forms.Panel]$ContentPanel
    )

    try {
        # Build UI (empty)
        $uiRefs = New-DashboardLayout -ContentPanel $ContentPanel

        # Populate with data if connected
        $data = Get-DashboardData
        if ($data) { 
            Update-DashboardWithData -UiRefs $uiRefs -Data $data 
        } else {
            $uiRefs['StatusLabel'].Text = "No connection to VMware server"
            $uiRefs['StatusLabel'].ForeColor = $global:theme.Error
        }
    } catch { 
        Write-Verbose "Dashboard initialization failed: $_" 
    }
}




<#
.SYNOPSIS
    Retrieves dashboard data from vSphere connection.
.DESCRIPTION
    Collects all required data from vSphere for the dashboard display.
    Handles connection errors and returns null if no connection.
.OUTPUTS
    [hashtable] - Dictionary containing all dashboard data collections
#>
function Get-DashboardData {
    [CmdletBinding()]
    param()

    try {
        $conn = [VMServerConnection]::GetInstance().GetConnection()
        if (-not $conn) {
            return $null
        }

        # Main data collections
        $data = @{
            HostInfo   = Get-VMHost -Server $conn -ErrorAction SilentlyContinue
            VMs        = Get-VM -Server $conn -ErrorAction SilentlyContinue
            Datastores = Get-Datastore -Server $conn -ErrorAction SilentlyContinue
            Events     = Get-VIEvent -Server $conn -MaxSamples 10 -ErrorAction SilentlyContinue
            Adapters   = Get-VMHostNetworkAdapter -Server $conn -ErrorAction SilentlyContinue
            Templates  = Get-Template -Server $conn -ErrorAction SilentlyContinue
        }

        # Additional derived data
        $data.PortGroups = try { 
            [VMwareNetwork]::ListPortGroups() 
        } catch { 
            @() 
        }

        $data.OrphanedFiles = try {
            if ($data.Datastores) { 
                [OrphanCleaner]::FindOrphanedFiles($data.Datastores[0].Name) 
            } else { 
                @() 
            }
        } catch { 
            @() 
        }

        return $data
    } catch {
        Write-Verbose "Data collection failed: $_"
        return $null
    }
}




# ────────────────────────────────────────────────────────────────────────────
#                            LAYOUT CONSTRUCTION
# ────────────────────────────────────────────────────────────────────────────




<#
.SYNOPSIS
    Creates the full dashboard layout: header, tabs, action bar, footer.
.DESCRIPTION
    The body is split into a TabControl (Stats, Alerts, Storage) and a
    FlowLayoutPanel with Refresh button.
.PARAMETER ContentPanel
    Panel into which the layout is rendered.
.OUTPUTS
    [hashtable] – references to dynamically created UI elements.
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
        $ContentPanel.BackColor = $global:theme.Background

        
        # ── ROOT LAYOUT : Header | Tabs | Actions | Footer ─────────
        $root = New-Object System.Windows.Forms.TableLayoutPanel
        $root.Dock = 'Fill'
        $root.ColumnCount = 1
        $root.RowCount = 4
        $root.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent,100)))
        $root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))   # Header
        $root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent,100))) # Tabs
        $root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))   # Actions
        $root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))   # Footer
        $ContentPanel.Controls.Add($root)


        #===== Row [1️] HEADER ========================================
        $root.Controls.Add((New-DashboardHeader), 0, 0)


        #===== Row [2] TABCONTROL ====================================
        $tabs = New-Object System.Windows.Forms.TabControl
        $tabs.Dock = 'Fill'
        $tabs.SizeMode = 'Fixed'
        $tabs.ItemSize = New-Object System.Drawing.Size(250, 40)
        $tabs.Font = [System.Drawing.Font]::new('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
        $tabs.BackColor = $global:theme.Background
        $root.Controls.Add($tabs, 0, 1)

        # Hashtable for UI references
        $refs = @{}


        # --------------------------------------------------------------
        # ----- Stats Tab ----------------------------------------------
        # --------------------------------------------------------------
        $tabStats = New-Object System.Windows.Forms.TabPage
        $tabStats.Text = "Host Statistics"
        $tabStats.BackColor = $global:theme.Background
        $statsPanel = New-DashboardStats -Refs ([ref]$refs)
        $tabStats.Controls.Add($statsPanel)
        $tabs.TabPages.Add($tabStats)

        # --------------------------------------------------------------
        # ----- Alerts Tab ---------------------------------------------
        # --------------------------------------------------------------
        $tabAlerts = New-Object System.Windows.Forms.TabPage
        $tabAlerts.Text = "Recent Alerts and Events"
        $tabAlerts.BackColor = $global:theme.Background
        $alertsTable = New-DashboardTable -Columns @('Time','Severity','Message','Object') -Name 'AlertsTable' -Refs ([ref]$refs)
        $tabAlerts.Controls.Add($alertsTable)
        $tabs.TabPages.Add($tabAlerts)

        # --------------------------------------------------------------
        # ----- Storage Tab --------------------------------------------
        # --------------------------------------------------------------
        $tabStorage = New-Object System.Windows.Forms.TabPage
        $tabStorage.Text = "Storage Overview"
        $tabStorage.BackColor = $global:theme.Background
        $storageTable = New-DashboardTable -Columns @('Datastore','Capacity (GB)','Used (GB)','Free (GB)','Usage') -Name 'StorageTable' -Refs ([ref]$refs)
        $tabStorage.Controls.Add($storageTable)
        $tabs.TabPages.Add($tabStorage)

        #===== Row [3] ACTION BAR ======================================
        $actions = New-DashboardActions -Refs ([ref]$refs) -ParentPanel $ContentPanel
        $root.Controls.Add($actions, 0, 2)

        #===== Row [4️] FOOTER ==========================================
        $footer = New-Object System.Windows.Forms.Panel
        $footer.Dock = 'Bottom'
        $footer.Height = 30
        $footer.BackColor = $global:theme.Background

        $status = New-Object System.Windows.Forms.Label
        $status.Name = 'StatusLabel'
        $status.AutoSize = $true
        $status.Font = New-Object System.Drawing.Font('Segoe UI', 9)
        $status.ForeColor = $global:theme.Error
        $status.Text = 'DISCONNECTED'

        $footer.Controls.Add($status)
        $root.Controls.Add($footer, 0, 3)

        # Reference map -------------------------------------------------
        $refs['StatusLabel'] = $status
        
        return $refs

    } finally {
        $ContentPanel.ResumeLayout($true)
    }
}




# ────────────────────────────────────────────────────────────────────────────
#                            HEADER / STATS / TABLES
# ────────────────────────────────────────────────────────────────────────────




<#
.SYNOPSIS
    Creates the colored header bar with title and last-refresh time.
#>
function New-DashboardHeader {
    $p = New-Object System.Windows.Forms.Panel
    $p.Dock = 'Top'
    $p.Height = 100
    $p.BackColor = $global:theme.Primary

    # Title label
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = 'DASHBOARD'
    $lbl.Font = New-Object System.Drawing.Font('Segoe UI', 18, [System.Drawing.FontStyle]::Bold)
    $lbl.ForeColor = [System.Drawing.Color]::White
    $lbl.Location = New-Object System.Drawing.Point(20, 20)
    $lbl.AutoSize = $true
    $p.Controls.Add($lbl)

    # Last refresh label
    $ref = New-Object System.Windows.Forms.Label
    $ref.Name = 'LastRefreshLabel'
    $ref.Text = "Last refresh: $(Get-Date -Format 'HH:mm:ss')"
    $ref.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $ref.ForeColor = [System.Drawing.Color]::WhiteSmoke
    $ref.Location = New-Object System.Drawing.Point(20, 60)
    $ref.AutoSize = $true
    $p.Controls.Add($ref)

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

    $p = New-Object System.Windows.Forms.FlowLayoutPanel
    $p.Dock = 'Top'
    $p.AutoSize = $true
    $p.Padding = 10
    $p.WrapContents = $true
    $p.AutoScroll = $true
    $p.BackColor = $global:theme.Background

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
        # Card container
        $card = New-Object System.Windows.Forms.Panel
        $card.Size = New-Object System.Drawing.Size(150, 100)
        $card.Padding = 5
        $card.Margin = 5
        $card.BackColor = $global:theme.CardBackground
        $card.BorderStyle = 'FixedSingle'

        # Title
        $t = New-Object System.Windows.Forms.Label
        $t.Text = $c.Title
        $t.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
        $t.Location = New-Object System.Drawing.Point(5, 5)
        $t.TextAlign = 'MiddleCenter'
        $card.Controls.Add($t)

        # Value
        $v = New-Object System.Windows.Forms.Label
        $v.Name = "$($c.Key)Value"
        $v.Text = '--'
        $v.Font = New-Object System.Drawing.Font('Segoe UI', 14)
        $v.Location = New-Object System.Drawing.Point(5, 25)
        $v.TextAlign = 'MiddleCenter'
        $card.Controls.Add($v)

        # Icon
        $i = New-Object System.Windows.Forms.Label
        $i.Text = $c.Icon
        $i.Font = New-Object System.Drawing.Font('Segoe MDL2 Assets', 20)
        $i.AutoSize = $true
        $i.TextAlign = 'MiddleCenter'
        $i.Location = New-Object System.Drawing.Point(5, 65)
        $i.ForeColor = $global:theme.Primary
        $card.Controls.Add($i)

        $p.Controls.Add($card)
        $Refs.Value["$($c.Key)Value"] = $v
    }
    return $p
}




<#
.SYNOPSIS
    Builds a DataGridView wrapped in a panel.
.DESCRIPTION
    Creates a DataGridView with specified columns and styling.
    A placeholder row is added so the user never sees an empty grid.
.PARAMETER Columns
    Array of column names to create
.PARAMETER Name
    Control name for reference
.PARAMETER Refs
    Reference hashtable to store control reference
#>
function New-DashboardTable {
    param(
        [string[]]$Columns,
        [string]$Name,
        [ref]$Refs
    )

    # Main container
    $container = New-Object System.Windows.Forms.Panel
    $container.Dock = 'Fill'
    $container.BackColor = $global:theme.Background
    $container.Padding = New-Object System.Windows.Forms.Padding(10)

    # DataGridView
    $grid = New-Object System.Windows.Forms.DataGridView
    $grid.Name = $Name
    $grid.Dock = 'Fill'
    $grid.AutoSizeColumnsMode = 'Fill'
    $grid.RowHeadersVisible = $false
    $grid.ReadOnly = $true
    $grid.AllowUserToAddRows = $false
    $grid.AllowUserToDeleteRows = $false
    $grid.AllowUserToResizeRows = $false
    $grid.AutoSizeRowsMode = 'AllCells'
    $grid.BackgroundColor = $global:theme.CardBackground
    $grid.BorderStyle = 'FixedSingle'

    # Header style
    $grid.EnableHeadersVisualStyles = $false
    $grid.ColumnHeadersDefaultCellStyle.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

    # Cell style
    $grid.DefaultCellStyle.BackColor = $global:theme.CardBackground
    $grid.DefaultCellStyle.ForeColor = $global:theme.TextPrimary
    $grid.DefaultCellStyle.Font = New-Object System.Drawing.Font('Segoe UI', 9)

    # Add columns
    foreach ($col in $Columns) {
        $safe = 'col_' + ($col -replace '[^a-zA-Z0-9_]', '')
        $c = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
        $c.Name = $safe
        $c.HeaderText = $col
        $c.SortMode = 'NotSortable'
        [void]$grid.Columns.Add($c)
    }

    # Add placeholder row
    $row = $grid.Rows.Add()
    for ($i = 0; $i -lt $Columns.Count; $i++) {
        $grid.Rows[$row].Cells[$i].Value = if ($i -eq 0) { 'No data available' } else { '--' }
        $grid.Rows[$row].Cells[$i].Style.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Italic)
    }

    $container.Controls.Add($grid)

    # Store reference
    $Refs.Value[$Name] = $grid
    
    return $container
}




<#
.SYNOPSIS
    Creates the Refresh button action bar.
.PARAMETER Refs
    Reference hashtable for UI elements
.PARAMETER ParentPanel
    The main content panel to refresh
#>
function New-DashboardActions {
    param(
        [ref]$Refs,
        [System.Windows.Forms.Panel]$ParentPanel
    )

    $flow = New-Object System.Windows.Forms.FlowLayoutPanel
    $flow.Dock = 'Fill'
    $flow.Padding = 10
    $flow.AutoSize = $true
    $flow.BackColor = $global:theme.Background

    # Refresh button
    $btnRefresh = New-Object System.Windows.Forms.Button
    $btnRefresh.Text = 'REFRESH'
    $btnRefresh.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
    $btnRefresh.Size = New-Object System.Drawing.Size(120, 35)
    $btnRefresh.BackColor = $global:theme.Primary
    $btnRefresh.ForeColor = [System.Drawing.Color]::White
    $btnRefresh.FlatStyle = 'Flat'
    $btnRefresh.Add_Click({
        Show-DashboardView -ContentPanel $ParentPanel
    })

    $flow.Controls.Add($btnRefresh)
    return $flow
}



# ────────────────────────────────────────────────────────────────────────────
#                                DATA BINDING
# ────────────────────────────────────────────────────────────────────────────




<#
.SYNOPSIS
    Injects live VMware data into the UI controls.
.DESCRIPTION
    Updates all dashboard elements with current data from vSphere.
.PARAMETER UiRefs
    Hashtable of UI element references
.PARAMETER Data
    Hashtable containing collections fetched from vSphere
#>
function Update-DashboardWithData {
    [CmdletBinding()]
    param(
        [hashtable]$UiRefs,
        [hashtable]$Data
    )

    # Update stats cards
    $map = @{
        TotalVMs      = $Data.VMs.Count
        RunningVMs    = ($Data.VMs | Where-Object PowerState -eq 'PoweredOn').Count
        Datastores    = $Data.Datastores.Count
        Adapters      = $Data.Adapters.Count
        Templates     = $Data.Templates.Count
        PortGroups    = $Data.PortGroups.Count
        OrphanedFiles = $Data.OrphanedFiles.Count
    }

    foreach ($k in $map.Keys) {
        $UiRefs["${k}Value"].Text = $map[$k]
        $UiRefs["${k}Value"].ForeColor = $global:theme.Primary
    }

    # Update connection status
    if ($Data.HostInfo) {
        $h = $Data.HostInfo
        $UiRefs['StatusLabel'].Text = "CONNECTED to $($h.Name) | vSphere $($h.Version)"
        $UiRefs['StatusLabel'].ForeColor = $global:theme.Success
    }

    # Update last refresh time
    $UiRefs['LastRefreshLabel'].Text = "Last refresh: $(Get-Date -Format 'HH:mm:ss')"

    # Populate Alerts table
    if ($Data.Events) {
        $g = $UiRefs['AlertsTable']
        $g.Rows.Clear()
        foreach ($e in $Data.Events) {
            $row = $g.Rows.Add()
            $g.Rows[$row].Cells['Time'].Value = $e.CreatedTime
            $g.Rows[$row].Cells['Severity'].Value = $e.GetType().Name
            $g.Rows[$row].Cells['Message'].Value = $e.FullFormattedMessage
            $g.Rows[$row].Cells['Object'].Value = $e.ObjectName
            
            # Color coding for severity
            if ($e.GetType().Name -match 'Error|Warning') {
                $g.Rows[$row].Cells['Severity'].Style.ForeColor = $global:theme.Error
            }
        }
    }

    # Populate Storage table
    if ($Data.Datastores) {
        $g = $UiRefs['StorageTable']
        $g.Rows.Clear()
        foreach ($d in $Data.Datastores) {
            $row = $g.Rows.Add()
            $g.Rows[$row].Cells['Datastore'].Value = $d.Name
            $cap = [math]::Round($d.CapacityGB, 1)
            $free = [math]::Round($d.FreeSpaceGB, 1)
            $used = $cap - $free
            $pct = 100 - $d.PercentFree

            $g.Rows[$row].Cells['Capacity (GB)'].Value = $cap
            $g.Rows[$row].Cells['Used (GB)'].Value = $used
            $g.Rows[$row].Cells['Free (GB)'].Value = $free
            $g.Rows[$row].Cells['Usage'].Value = "$pct%"

            # Highlight low storage
            if ($d.PercentFree -lt 15) {
                $g.Rows[$row].Cells['Usage'].Style.ForeColor = $global:theme.Error
                $g.Rows[$row].Cells['Usage'].Style.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
            }
        }
    }
}
