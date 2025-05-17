# ─────────────────────────  Assemblies  ──────────────────────────────────────
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms.DataVisualization



# ─────────────────────────  Public entry point  ──────────────────────────────
function Show-DashboardView {
    <#
    .SYNOPSIS
        Renders the vSphere dashboard in the supplied WinForms panel.
    .PARAMETER ContentPanel
        The host panel into which the dashboard is drawn.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Forms.Panel] $ContentPanel
    )

    # Keep the panel in a global so REFRESH can call us again.
    $script:DashboardContentPanel = $ContentPanel

    try {
        # 1 ─ Build the empty UI ----------------------------------------------------
        $uiRefs = New-DashboardLayout -ContentPanel $ContentPanel

        # 2 ─ Gather data (may be $null when disconnected) --------------------------
        $data = Get-DashboardData

        # 3 ─ Populate or warn ------------------------------------------------------
        if ($data) {
            Update-DashboardWithData -UiRefs $uiRefs -Data $data
            $ContentPanel.Refresh()
        }
        else {
            $uiRefs['StatusLabel'].Text      = 'No connection to VMware server'
            $uiRefs['StatusLabel'].ForeColor = $script:Theme.Error
        }
    }
    catch {
        Write-Verbose "Dashboard initialisation failed: $_"
    }
}



# ─────────────────────────  Data collection  ─────────────────────────────────
function Get-DashboardData {
    <#
    .SYNOPSIS
        Retrieves every data set the dashboard will display.
    .OUTPUTS
        [hashtable] – Keys: HostInfo, VMs, Datastores, Events, Adapters, Templates,
                    PortGroups, OrphanedFiles.
    #>
    [CmdletBinding()] param()

    try {
        $conn = $script:Connection
        if (-not $conn) { return $null }

        $data = @{}

        # ‒‒‒ Core objects (PowerCLI) ---------------------------------------------
        $data.HostInfo   = Get-VMHost                -Server $conn -ErrorAction SilentlyContinue
        $data.VMs        = Get-VM                    -Server $conn -ErrorAction SilentlyContinue
        $data.Datastores = Get-Datastore             -Server $conn -ErrorAction SilentlyContinue
        $data.Events     = Get-VIEvent               -Server $conn -MaxSamples 10 -ErrorAction SilentlyContinue
        $data.Adapters   = Get-VMHostNetworkAdapter  -Server $conn -ErrorAction SilentlyContinue
        $data.Templates  = Get-Template              -Server $conn -ErrorAction SilentlyContinue

        # ‒‒‒ Custom helpers (may throw) -------------------------------------------
        try   { $data.PortGroups    = [VMwareNetwork]::ListPortGroups() }
        catch { $data.PortGroups    = @()                               }

        try {
            if ($data.Datastores.Count -gt 0) {
                $firstDs              = $data.Datastores[0].Name
                $data.OrphanedFiles   = [OrphanCleaner]::FindOrphanedFiles($firstDs)
            }
            else { $data.OrphanedFiles = @() }
        }
        catch { $data.OrphanedFiles   = @() }

        return $data
    }
    catch {
        Write-Verbose "Data collection failed: $_"
        return $null
    }
}



# ─────────────────────────  Layout builders  ─────────────────────────────────
function New-DashboardLayout {
    <#
    .SYNOPSIS
        Builds the dashboard UI (header, tab-control, actions, footer).
    .OUTPUTS
        [hashtable] – references to frequently accessed controls.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Forms.Panel] $ContentPanel
    )

    try {
        #$ContentPanel.SuspendLayout()
        $ContentPanel.Controls.Clear()
        $ContentPanel.BackColor = $script:Theme.LightGray

        # ── Root table ------------------------------------------------------------
        $root              = New-Object System.Windows.Forms.TableLayoutPanel
        $root.Dock         = 'Fill'
        $root.ColumnCount  = 1
        $root.RowCount     = 4
        $null = $root.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle 'Percent',100))
        $null = $root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'AutoSize'))
        $null = $root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'Percent',100))
        $null = $root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'AutoSize'))
        $null = $root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'AutoSize'))
        $ContentPanel.Controls.Add($root)

        # ── Header ----------------------------------------------------------------
        $headerPanel      = New-DashboardHeader
        $root.Controls.Add($headerPanel, 0, 0)
        $lblRefresh       = $headerPanel.Controls.Find('LastRefreshLabel', $true)[0]
        $refs             = @{ LastRefreshLabel = $lblRefresh }

        # ── Tab-control -----------------------------------------------------------
        $tabs             = New-Object System.Windows.Forms.TabControl
        $tabs.Dock        = 'Fill'
        $tabs.SizeMode    = 'Normal'
        $tabs.Padding = New-Object System.Drawing.Point(20, 10)
        $tabs.Font        = New-Object System.Drawing.Font('Segoe UI',10,[System.Drawing.FontStyle]::Bold)
        $tabs.BackColor   = $script:Theme.LightGray
        $root.Controls.Add($tabs, 0, 1)

        # 1. Host statistics cards -------------------------------------------------
        $tabStats         = New-Object System.Windows.Forms.TabPage 'Host Statistics'
        $tabStats.BackColor = $script:Theme.White
        $statsPanel       = New-DashboardStats -Refs ([ref]$refs)
        $tabStats.Controls.Add($statsPanel)
        $tabs.TabPages.Add($tabStats)

        # 2. Alerts ----------------------------------------------------------------
        $tabAlerts        = New-Object System.Windows.Forms.TabPage 'Recent Alerts and Events'
        $tabAlerts.BackColor = $script:Theme.White
        $alertsTable      = New-DashboardTable `
                                -Columns  @('Time','Severity','Message','Object') `
                                -Name     'AlertsTable' `
                                -Refs     ([ref]$refs)
        $tabAlerts.Controls.Add($alertsTable)
        $tabs.TabPages.Add($tabAlerts)

        # 3. Storage ---------------------------------------------------------------
        $tabStorage       = New-Object System.Windows.Forms.TabPage 'Storage Overview'
        $tabStorage.BackColor = $script:Theme.White
        $storageTable     = New-DashboardTable `
                                -Columns  @('Datastore','Capacity (GB)','Used (GB)','Free (GB)','Usage') `
                                -Name     'StorageTable' `
                                -Refs     ([ref]$refs)
        $tabStorage.Controls.Add($storageTable)
        $tabs.TabPages.Add($tabStorage)

        # 4. Hosts -----------------------------------------------------------------
        $tabHosts         = New-Object System.Windows.Forms.TabPage 'Hosts'
        $tabHosts.BackColor = $script:Theme.White
        $hostsTable       = New-DashboardTable `
                                -Columns  @('Host','CPU Total','Memory GB','Model','Version') `
                                -Name     'HostsTable' `
                                -Refs     ([ref]$refs)
        $tabHosts.Controls.Add($hostsTable)
        $tabs.TabPages.Add($tabHosts)

        # 5. Network Adapters ------------------------------------------------------
        $tabNics          = New-Object System.Windows.Forms.TabPage 'Network Adapters'
        $tabNics.BackColor = $script:Theme.White
        $nicsTable        = New-DashboardTable `
                                -Columns  @('Host','Name','MAC','Speed (Mbps)','Connected') `
                                -Name     'NicsTable' `
                                -Refs     ([ref]$refs)
        $tabNics.Controls.Add($nicsTable)
        $tabs.TabPages.Add($tabNics)

        # 6. Templates -------------------------------------------------------------
        $tabTpl           = New-Object System.Windows.Forms.TabPage 'Templates'
        $tabTpl.BackColor = $script:Theme.White
        $tplTable         = New-DashboardTable `
                                -Columns  @('Template','Guest OS','CPU','Memory GB','Disk GB') `
                                -Name     'TemplatesTable' `
                                -Refs     ([ref]$refs)
        $tabTpl.Controls.Add($tplTable)
        $tabs.TabPages.Add($tabTpl)

        # 7. Port Groups -----------------------------------------------------------
        $tabPg            = New-Object System.Windows.Forms.TabPage 'Port Groups'
        $tabPg.BackColor  = $script:Theme.White
        $pgTable          = New-DashboardTable `
                                -Columns  @('Name','VLAN','vSwitch','Active Ports') `
                                -Name     'PortGroupsTable' `
                                -Refs     ([ref]$refs)
        $tabPg.Controls.Add($pgTable)
        $tabs.TabPages.Add($tabPg)

        # 8. Orphaned files --------------------------------------------------------
        $tabOrphan        = New-Object System.Windows.Forms.TabPage 'Orphaned Files'
        $tabOrphan.BackColor = $script:Theme.White
        $orphTable        = New-DashboardTable `
                                -Columns  @('File','Size (MB)','Datastore') `
                                -Name     'OrphansTable' `
                                -Refs     ([ref]$refs)
        $tabOrphan.Controls.Add($orphTable)
        $tabs.TabPages.Add($tabOrphan)

        # ── Actions bar -----------------------------------------------------------
        $actionsPanel     = New-DashboardActions -Refs ([ref]$refs) -ParentPanel $ContentPanel
        $root.Controls.Add($actionsPanel, 0, 2)

        # ── Footer ----------------------------------------------------------------
        $footer           = New-Object System.Windows.Forms.Panel
        $footer.Dock      = 'Bottom'
        $footer.Height    = 30
        $footer.BackColor = $script:Theme.LightGray

        $status           = New-Object System.Windows.Forms.Label
        $status.Name      = 'StatusLabel'
        $status.AutoSize  = $true
        $status.Font      = New-Object System.Drawing.Font('Segoe UI',9)
        $status.ForeColor = $script:Theme.Error
        $status.Text      = '---'
        $footer.Controls.Add($status)

        $root.Controls.Add($footer, 0, 3)
        $refs['StatusLabel'] = $status

        return $refs
    }
    finally {
        $ContentPanel.ResumeLayout($true)
    }
}




function New-DashboardHeader {
    <#
    .SYNOPSIS
        Returns the coloured dashboard header bar.
    #>
    $panel              = New-Object System.Windows.Forms.Panel
    $panel.Dock         = 'Top'
    $panel.Height       = 100
    $panel.BackColor    = $script:Theme.Primary

    $lblTitle           = New-Object System.Windows.Forms.Label
    $lblTitle.Text      = 'DASHBOARD'
    $lblTitle.Font      = New-Object System.Drawing.Font('Segoe UI',18,[System.Drawing.FontStyle]::Bold)
    $lblTitle.ForeColor = $script:Theme.White
    $lblTitle.Location  = New-Object System.Drawing.Point(20,20)
    $lblTitle.AutoSize  = $true
    $panel.Controls.Add($lblTitle)

    $lblRefresh         = New-Object System.Windows.Forms.Label
    $lblRefresh.Name    = 'LastRefreshLabel'
    $lblRefresh.Text    = "Last refresh: $(Get-Date -Format 'HH:mm:ss')"
    $lblRefresh.Font    = New-Object System.Drawing.Font('Segoe UI',9)
    $lblRefresh.ForeColor = $script:Theme.White
    $lblRefresh.Location  = New-Object System.Drawing.Point(20,60)
    $lblRefresh.AutoSize  = $true
    $panel.Controls.Add($lblRefresh)

    return $panel
}




function New-DashboardStats {
    <#
    .SYNOPSIS
        Creates eight statistic “cards” and stores their value labels in $Refs.
    #>
    [CmdletBinding()] param([ref]$Refs)

    $panel                 = New-Object System.Windows.Forms.FlowLayoutPanel
    $panel.Dock            = 'Fill'
    $panel.AutoScroll      = $true
    $panel.Padding         = 10
    $panel.WrapContents    = $true
    $panel.BackColor       = $script:Theme.White

    $cards = @(
        @{ Key='HostCount'    ; Title='TOTAL HOSTS'    ; Icon=[char]0xE774 },
        @{ Key='TotalVMs'     ; Title='TOTAL VMS'      ; Icon=[char]0xE8F1 },
        @{ Key='RunningVMs'   ; Title='RUNNING VMS'    ; Icon=[char]0xE768 },
        @{ Key='Datastores'   ; Title='DATASTORES'     ; Icon=[char]0xE958 },
        @{ Key='Adapters'     ; Title='ADAPTERS'       ; Icon=[char]0xE8EF },
        @{ Key='Templates'    ; Title='TEMPLATES'      ; Icon=[char]0xE8A5 },
        @{ Key='PortGroups'   ; Title='PORT GROUPS'    ; Icon=[char]0xE8EE },
        @{ Key='OrphanedFiles'; Title='ORPHAN FILES'   ; Icon=[char]0xE7BA }
    )

    foreach ($c in $cards) {
        # Card container
        $card            = New-Object System.Windows.Forms.Panel
        $card.Size       = New-Object System.Drawing.Size(150,100)
        $card.Padding    = 5
        $card.Margin     = 5
        $card.BackColor  = $script:Theme.White
        $card.BorderStyle= 'FixedSingle'

        # Card title
        $lblTitle        = New-Object System.Windows.Forms.Label
        $lblTitle.Text   = $c.Title
        $lblTitle.Font   = New-Object System.Drawing.Font('Segoe UI',9,[System.Drawing.FontStyle]::Bold)
        $lblTitle.Location = New-Object System.Drawing.Point(5,5)
        $lblTitle.AutoSize  = $true
        $card.Controls.Add($lblTitle)

        # Card value (will be filled later)
        $lblValue        = New-Object System.Windows.Forms.Label
        $lblValue.Name   = "$($c.Key)Value"
        $lblValue.Text   = '--'
        $lblValue.Font   = New-Object System.Drawing.Font('Segoe UI',14)
        $lblValue.Location = New-Object System.Drawing.Point(5,25)
        $lblValue.AutoSize  = $true
        $card.Controls.Add($lblValue)

        # Icon
        $lblIcon         = New-Object System.Windows.Forms.Label
        $lblIcon.Text    = $c.Icon
        $lblIcon.Font    = New-Object System.Drawing.Font('Segoe MDL2 Assets',20)
        $lblIcon.Location  = New-Object System.Drawing.Point(5,65)
        $lblIcon.AutoSize  = $true
        $lblIcon.ForeColor = $script:Theme.Primary
        $card.Controls.Add($lblIcon)

        $panel.Controls.Add($card)
        $Refs.Value["$($c.Key)Value"] = $lblValue
    }

    return $panel
}




function New-DashboardTable {
    <#
    .SYNOPSIS
        Returns a panel that wraps an empty DataGridView.
    .PARAMETER Columns
        Column headers.
    .PARAMETER Name
        Control name (also used in UiRefs).
    .PARAMETER Refs
        Hashtable reference to store the grid.
    #>
    [CmdletBinding()]
    param(
        [string[]] $Columns,
        [string]   $Name,
        [ref]      $Refs
    )

    $container                = New-Object System.Windows.Forms.Panel
    $container.Dock           = 'Fill'
    $container.AutoScroll     = $true
    $container.Padding        = New-Object System.Windows.Forms.Padding(10)
    $container.BackColor      = $script:Theme.White

    $grid                     = New-Object System.Windows.Forms.DataGridView
    $grid.Name                = $Name
    $grid.Dock                = 'Fill'
    $grid.AutoSizeColumnsMode = 'Fill'
    $grid.RowHeadersVisible   = $false
    $grid.ReadOnly            = $true
    $grid.AllowUserToAddRows    = $false
    $grid.AllowUserToDeleteRows = $false
    $grid.AllowUserToResizeRows = $false
    $grid.AutoSizeRowsMode      = 'AllCells'
    $grid.BackgroundColor       = $script:Theme.White
    $grid.BorderStyle           = 'FixedSingle'
    $grid.EnableHeadersVisualStyles = $false
    $grid.ColumnHeadersDefaultCellStyle.Font = New-Object System.Drawing.Font('Segoe UI',9,[System.Drawing.FontStyle]::Bold)
    $grid.DefaultCellStyle.Font             = New-Object System.Drawing.Font('Segoe UI',9)
    $grid.DefaultCellStyle.ForeColor        = $script:Theme.PrimaryDark

    for ($i = 0; $i -lt $Columns.Count; $i++) {
        $col               = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
        $col.Name          = 'col_' + ($Columns[$i] -replace '[^\w]','')
        $col.HeaderText    = $Columns[$i]
        $col.SortMode      = 'NotSortable'
        [void] $grid.Columns.Add($col)
    }

    # Placeholder row
    $rowIndex = $grid.Rows.Add()
    for ($i = 0; $i -lt $Columns.Count; $i++) {
        $cell            = $grid.Rows[$rowIndex].Cells[$i]
        $cell.Value      = if ($i -eq 0) { 'No data available' } else { '--' }
        $cell.Style.Font = New-Object System.Drawing.Font('Segoe UI',9,[System.Drawing.FontStyle]::Italic)
    }

    $container.Controls.Add($grid)
    $Refs.Value[$Name] = $grid

    return $container
}




function New-DashboardActions {
    <#
    .SYNOPSIS
        Builds the actions bar (REFRESH button).
    #>
    [CmdletBinding()]
    param(
        [ref] $Refs,
        [System.Windows.Forms.Panel] $ParentPanel
    )

    $flow                     = New-Object System.Windows.Forms.FlowLayoutPanel
    $flow.Dock                = 'Fill'
    $flow.Padding             = 10
    $flow.AutoSize            = $true
    $flow.BackColor           = $script:Theme.LightGray

    $btnRefresh               = New-Object System.Windows.Forms.Button
    $btnRefresh.Text          = 'REFRESH'
    $btnRefresh.Font          = New-Object System.Drawing.Font('Segoe UI',10,[System.Drawing.FontStyle]::Bold)
    $btnRefresh.Size          = New-Object System.Drawing.Size(120,35)
    $btnRefresh.BackColor     = $script:Theme.Primary
    $btnRefresh.ForeColor     = $script:Theme.White
    $btnRefresh.FlatStyle     = 'Flat'

    # Event handler: reload script and re-render view
    $btnRefresh.Add_Click({
        try {
            . "$PSScriptRoot\DashboardView.ps1"
            Show-DashboardView -ContentPanel $ParentPanel
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show(
                "Failed to refresh dashboard:`n$($_.Exception.Message)",
                "Refresh Error",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
        }
    })

    $flow.Controls.Add($btnRefresh)
    return $flow
}




# ─────────────────────────  Data-to-UI binder  ───────────────────────────────
function Update-DashboardWithData {
    <#
    .SYNOPSIS
        Pushes all collected data sets into the corresponding UI controls.
    #>
    [CmdletBinding()]
    param(
        [hashtable] $UiRefs,
        [hashtable] $Data
    )

    # ── Statistic cards ----------------------------------------------------------
    $cardValues = @{
        HostCount     = $Data.HostInfo.Count
        TotalVMs      = $Data.VMs.Count
        RunningVMs    = ($Data.VMs | Where-Object PowerState -eq 'PoweredOn').Count
        Datastores    = $Data.Datastores.Count
        Adapters      = $Data.Adapters.Count
        Templates     = $Data.Templates.Count
        PortGroups    = $Data.PortGroups.Count
        OrphanedFiles = $Data.OrphanedFiles.Count
    }

    foreach ($key in $cardValues.Keys) {
        $label              = $UiRefs["$($key)Value"]
        $label.Text         = $cardValues[$key]
        $label.ForeColor    = $script:Theme.Primary
    }

    # ── Connection status --------------------------------------------------------
    if ($Data.HostInfo) {
        $firstHost          = $Data.HostInfo[0]
        $UiRefs['StatusLabel'].Text      = "CONNECTED to $($firstHost.Name) | vSphere $($firstHost.Version)"
        $UiRefs['StatusLabel'].ForeColor = $script:Theme.Success
    }

    # ── Last-refresh -------------------------------------------------------------
    $UiRefs['LastRefreshLabel'].Text = "Last refresh: $(Get-Date -Format 'HH:mm:ss')"

    # ── Alerts & events ----------------------------------------------------------
    $grid = $UiRefs['AlertsTable']
    $grid.Rows.Clear()
    foreach ($evt in $Data.Events) {
        $rowIdx = $grid.Rows.Add()
        $grid.Rows[$rowIdx].Cells['col_Time'    ].Value = $evt.CreatedTime
        $grid.Rows[$rowIdx].Cells['col_Severity'].Value = $evt.GetType().Name
        $grid.Rows[$rowIdx].Cells['col_Message' ].Value = $evt.FullFormattedMessage
        $grid.Rows[$rowIdx].Cells['col_Object'  ].Value = $evt.ObjectName

        if ($evt.GetType().Name -match 'Error|Warning') {
            $grid.Rows[$rowIdx].Cells['col_Severity'].Style.ForeColor = $script:Theme.Error
        }
    }

    # ── Storage overview ---------------------------------------------------------
    $grid = $UiRefs['StorageTable']
    $grid.Rows.Clear()
    foreach ($ds in $Data.Datastores) {
        $capGB  = [math]::Round($ds.CapacityGB,1)
        $freeGB = [math]::Round($ds.FreeSpaceGB,1)
        $usedGB = $capGB - $freeGB
        $pct    = if ($capGB -gt 0) { [math]::Round(($usedGB / $capGB)*100,1) } else { 0 }

        $rowIdx = $grid.Rows.Add()
        $grid.Rows[$rowIdx].Cells['col_Datastore' ].Value = $ds.Name
        $grid.Rows[$rowIdx].Cells['col_CapacityGB'].Value = $capGB
        $grid.Rows[$rowIdx].Cells['col_UsedGB'    ].Value = $usedGB
        $grid.Rows[$rowIdx].Cells['col_FreeGB'    ].Value = $freeGB
        $grid.Rows[$rowIdx].Cells['col_Usage'     ].Value = "$pct`%"

        if ($pct -gt 85) {
            $cell        = $grid.Rows[$rowIdx].Cells['col_Usage']
            $cell.Style.ForeColor = $script:Theme.Error
            $cell.Style.Font      = New-Object System.Drawing.Font('Segoe UI',9,[System.Drawing.FontStyle]::Bold)
        }
    }

    # ── Hosts --------------------------------------------------------------------
    $grid = $UiRefs['HostsTable']
    $grid.Rows.Clear()
    foreach ($h in $Data.HostInfo) {
        $rowIdx = $grid.Rows.Add()
        $grid.Rows[$rowIdx].Cells['col_Host'     ].Value = $h.Name
        $grid.Rows[$rowIdx].Cells['col_CPUTotal' ].Value = $h.CpuTotalMhz
        $grid.Rows[$rowIdx].Cells['col_MemoryGB' ].Value = [math]::Round($h.MemoryTotalGB,1)
        $grid.Rows[$rowIdx].Cells['col_Model'    ].Value = $h.Model
        $grid.Rows[$rowIdx].Cells['col_Version'  ].Value = $h.Version

        # Highlight high memory utilisation
        $memPct = if ($h.MemoryTotalGB -gt 0) { [math]::Round(($h.MemoryUsageGB / $h.MemoryTotalGB)*100,1) } else { 0 }
        if ($memPct -ge 90) {
            $grid.Rows[$rowIdx].DefaultCellStyle.ForeColor = $script:Theme.Error
        }
    }

    # ── Network adapters ---------------------------------------------------------
    $grid = $UiRefs['NicsTable']
    $grid.Rows.Clear()
    foreach ($nic in $Data.Adapters) {
        $rowIdx = $grid.Rows.Add()
        $grid.Rows[$rowIdx].Cells['col_Host'       ].Value = $nic.VMHost.Name
        $grid.Rows[$rowIdx].Cells['col_Name'       ].Value = $nic.Name
        $grid.Rows[$rowIdx].Cells['col_MAC'        ].Value = $nic.Mac
        $grid.Rows[$rowIdx].Cells['col_SpeedMbps'  ].Value = $nic.SpeedMb
        $grid.Rows[$rowIdx].Cells['col_Connected'  ].Value = $nic.Connected

        if ($nic.SpeedMb -eq 0) {
            $grid.Rows[$rowIdx].DefaultCellStyle.ForeColor = $script:Theme.Error
        }
    }

    # ── Templates ----------------------------------------------------------------
    $grid = $UiRefs['TemplatesTable']
    $grid.Rows.Clear()
    foreach ($tpl in $Data.Templates) {
        $rowIdx = $grid.Rows.Add()
        $grid.Rows[$rowIdx].Cells['col_Template' ].Value = $tpl.Name
        $grid.Rows[$rowIdx].Cells['col_GuestOS'  ].Value = $tpl.Guest
        $grid.Rows[$rowIdx].Cells['col_CPU'      ].Value = $tpl.NumCPU
        $grid.Rows[$rowIdx].Cells['col_MemoryGB' ].Value = $tpl.MemoryGB
        $grid.Rows[$rowIdx].Cells['col_DiskGB'   ].Value = [math]::Round($tpl.ProvisionedSpaceGB,1)
    }

    # ── Port groups --------------------------------------------------------------
    $grid = $UiRefs['PortGroupsTable']
    $grid.Rows.Clear()
    foreach ($pg in $Data.PortGroups) {
        $rowIdx = $grid.Rows.Add()
        $grid.Rows[$rowIdx].Cells['col_Name'       ].Value = $pg.Name
        $grid.Rows[$rowIdx].Cells['col_VLAN'       ].Value = $pg.VlanId
        $grid.Rows[$rowIdx].Cells['col_vSwitch'    ].Value = $pg.VSwitch
        $grid.Rows[$rowIdx].Cells['col_ActivePorts'].Value = $pg.ActivePorts
    }

    # ── Orphaned files -----------------------------------------------------------
    $grid = $UiRefs['OrphansTable']
    $grid.Rows.Clear()
    foreach ($file in $Data.OrphanedFiles) {
        $rowIdx = $grid.Rows.Add()
        $grid.Rows[$rowIdx].Cells['col_File'     ].Value = $file.Path
        $grid.Rows[$rowIdx].Cells['col_SizeMB'   ].Value = [math]::Round($file.SizeMB,1)
        $grid.Rows[$rowIdx].Cells['col_Datastore'].Value = $file.Datastore

        if ($file.SizeMB -gt 1024) {
            $grid.Rows[$rowIdx].DefaultCellStyle.ForeColor = $script:Theme.Error
        }
    }
}
