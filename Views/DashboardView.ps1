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
    
    # 1 ─ Build the empty UI ----------------------------------------------------
    $script:uiRefs = New-DashboardLayout -ContentPanel $ContentPanel
    $script:uiRefs["ContentPanel"] = $ContentPanel
    Set-StatusMessage -UiRefs $script:uiRefs -Message "Initializing dashboard..." -Type 'Info'

    # 2 ─ Gather data (may be $null when disconnected) --------------------------
    Set-StatusMessage -UiRefs $script:uiRefs -Message "Loading data from vSphere..." -Type 'Info'
    $data = Get-DashboardData

    # 3 ─ Populate or warn ------------------------------------------------------
    if ($data) {
        Set-StatusMessage -UiRefs $script:uiRefs -Message "Rendering dashboard..." -Type 'Info'
        Update-DashboardWithData -UiRefs $script:uiRefs -Data $data
        $ContentPanel.Refresh()
        Set-StatusMessage -UiRefs $script:uiRefs -Message "Dashboard ready" -Type 'Success'
    }
    else {
        Set-StatusMessage -UiRefs $script:uiRefs -Message "No connection to VMware server" -Type 'Error'
    }

}


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

    # ── Actions bar -----------------------------------------------------------
    $actionsPanel     = New-DashboardActions -Refs ([ref]$refs) -ParentPanel $ContentPanel
    $root.Controls.Add($actionsPanel, 0, 2)

    # ── Footer ----------------------------------------------------------------
    $footer           = New-Object System.Windows.Forms.Panel
    $footer.Dock      = 'Fill'
    $footer.AutoSize    = $true
    $footer.BackColor = $script:Theme.LightGray

    $status           = New-Object System.Windows.Forms.Label
    $status.Name      = 'StatusLabel'
    $status.AutoSize  = $true
    $status.Font      = New-Object System.Drawing.Font('Segoe UI',9)
    $status.ForeColor = $script:Theme.Error
    $status.Text      = ''
    $footer.Controls.Add($status)

    $root.Controls.Add($footer, 0, 3)
    $refs['StatusLabel'] = $status

    return $refs
}

# ─────────────────────────  Data collection  ─────────────────────────────────

function Get-DashboardData {
    <#
    .SYNOPSIS
        Retrieves all dashboard data including VMs, hosts, datastores, events, and network info
    .OUTPUTS
        [hashtable] - Complete dashboard dataset
    #>
    [CmdletBinding()] 
    param()

    try {
        $conn = $script:Connection
        if (-not $conn) { 
            Write-Verbose "No active VMware connection"
            return @{
                Error = "Not connected to vSphere server"
                Timestamp = [datetime]::Now
            }
        }

        # Sequential data collection for compatibility
        $data = @{}
        Set-StatusMessage -UiRefs $script:uiRefs -Message "Loading host information..." -Type 'Info'
        $data['Get-VMHost'] = Get-VMHost -Server $conn -ErrorAction SilentlyContinue
        
        Set-StatusMessage -UiRefs $script:uiRefs -Message "Loading virtual machines..." -Type 'Info'
        $data['Get-VM'] = Get-VM -Server $conn -ErrorAction SilentlyContinue
        
        Set-StatusMessage -UiRefs $script:uiRefs -Message "Loading datastores..." -Type 'Info'
        $data['Get-Datastore'] = Get-Datastore -Server $conn -ErrorAction SilentlyContinue
        
        Set-StatusMessage -UiRefs $script:uiRefs -Message "Loading recent events..." -Type 'Info'
        $data['Get-VIEvent'] = Get-VIEvent -Server $conn -MaxSamples 10 -ErrorAction SilentlyContinue
        
        Set-StatusMessage -UiRefs $script:uiRefs -Message "Loading network adapters..." -Type 'Info'
        $data['Get-VMHostNetworkAdapter'] = Get-VMHostNetworkAdapter -Server $conn -ErrorAction SilentlyContinue
        
        Set-StatusMessage -UiRefs $script:uiRefs -Message "Loading templates..." -Type 'Info'
        $data['Get-Template'] = Get-Template -Server $conn -ErrorAction SilentlyContinue

        # Add network and orphan data
        Set-StatusMessage -UiRefs $script:uiRefs -Message "Analyzing network configuration..." -Type 'Info'
        $data.PortGroups = Get-VMwarePortGroups
        
        Set-StatusMessage -UiRefs $script:uiRefs -Message "Checking for orphaned files..." -Type 'Info'
        $data.OrphanedFiles = $data['Get-Datastore'] | Get-Orphans 

        return @{
            HostInfo     = $data['Get-VMHost']
            VMs          = $data['Get-VM']
            Datastores   = $data['Get-Datastore']
            Events       = $data['Get-VIEvent']
            Adapters     = $data['Get-VMHostNetworkAdapter']
            Templates    = $data['Get-Template']
            PortGroups   = $data.PortGroups
            OrphanedFiles = $data.OrphanedFiles
            Timestamp    = [datetime]::Now
        }
    }
    catch {
        Write-Verbose "Dashboard data collection failed: $_"
        return @{
            Error = $_.Exception.Message
            Timestamp = [datetime]::Now
        }
    }
}

function Get-VMwarePortGroups {
    <#
    .SYNOPSIS
        Retrieves all port groups with their associated vSwitches
    .OUTPUTS
        [PSCustomObject[]] - Port group information
    #>
    [CmdletBinding()]
    param()

    try {
        $portGroups = @()
        $hostSystems = Get-VMHost | Sort-Object Name

        foreach ($vmHost in $hostSystems) {
            $networkSystem = $vmHost.ExtensionData.ConfigManager.NetworkSystem
            $hostPgInfo = $networkSystem.NetworkInfo.Portgroup
            
            foreach ($pg in $hostPgInfo) {
                $portGroups += [PSCustomObject]@{
                    Host        = $vmHost.Name
                    PortGroup   = $pg.Spec.Name
                    vSwitch     = $pg.Spec.VswitchName
                    VLAN        = $pg.Spec.VlanId
                    HostSystem  = $vmHost
                    Key         = "$($vmHost.Name)|$($pg.Spec.Name)"
                }
            }
        }

        return $portGroups | Sort-Object Host, PortGroup
    }
    catch {
        Write-Warning "Failed to retrieve port groups: $_"
        Set-StatusMessage -UiRefs $script:uiRefs -Message "Warning: Some port group data unavailable" -Type 'Warning'
        return @()
    }
}


function Get-Orphans {
    <#
    .SYNOPSIS
        Enhanced orphan detection using vSphere API
    .DESCRIPTION
        Combines the efficiency of direct API calls with modern PowerShell practices
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [VMware.VimAutomation.ViCore.Types.V1.DatastoreManagement.Datastore[]]$Datastore
    )

    Begin {
        # Initialize search specification (like Get-VmwOrphan)
        $flags = [VMware.Vim.FileQueryFlags]@{
            FileOwner = $true
            FileSize = $true
            FileType = $true
            Modification = $true
        }

        $searchSpec = [VMware.Vim.HostDatastoreBrowserSearchSpec]@{
            details = $flags
            sortFoldersFirst = $true
        }

        # Initialize file queries
        $searchSpec.Query = @(
            [VMware.Vim.FloppyImageFileQuery]::new(),
            [VMware.Vim.FolderFileQuery]::new(),
            [VMware.Vim.IsoImageFileQuery]::new(),
            [VMware.Vim.VmConfigFileQuery]::new(),
            [VMware.Vim.TemplateConfigFileQuery]::new(),
            [VMware.Vim.VmDiskFileQuery]::new(),
            [VMware.Vim.VmLogFileQuery]::new(),
            [VMware.Vim.VmNvramFileQuery]::new(),
            [VMware.Vim.VmSnapshotFileQuery]::new()
        )
    }

    Process {
        foreach ($ds in $Datastore) {
            try {
                Write-Verbose "Scanning datastore $($ds.Name)..."
                $startTime = Get-Date

                # Get all files from datastore
                $dsBrowser = Get-View -Id $ds.ExtensionData.browser
                $rootPath = "[$($ds.Name)]"
                $searchResult = $dsBrowser.SearchDatastoreSubFolders($rootPath, $searchSpec)

                # Create file table
                $fileTable = @{}
                foreach ($folder in $searchResult) {
                    foreach ($file in $folder.File) {
                        $key = "$($folder.FolderPath)$(if($folder.FolderPath[-1] -eq ']'){' '})$($file.Path)"
                        $fileTable[$key] = $file
                    }
                }

                # Remove registered VM files
                Get-VM -Datastore $ds | ForEach-Object {
                    $_.ExtensionData.LayoutEx.File | ForEach-Object {
                        if ($fileTable.ContainsKey($_.Name)) {
                            $fileTable.Remove($_.Name)
                        }
                    }
                }

                # Remove registered template files
                Get-Template | Where-Object { $_.DatastoreIdList -contains $ds.Id } | ForEach-Object {
                    $_.ExtensionData.LayoutEx.File | ForEach-Object {
                        if ($fileTable.ContainsKey($_.Name)) {
                            $fileTable.Remove($_.Name)
                        }
                    }
                }

                # Filter out system files
                $systemFiles = $fileTable.Keys | Where-Object { $_ -match '\] \.|vmkdump' }
                $systemFiles | ForEach-Object { $fileTable.Remove($_) }

                # Prepare output
                $orphans = foreach ($entry in $fileTable.GetEnumerator()) {
                    [PSCustomObject]@{
                        Name         = $entry.Value.Path
                        FullPath     = $entry.Key
                        Size         = $entry.Value.FileSize
                        Modified     = $entry.Value.Modification
                        Owner        = $entry.Value.Owner
                        Type         = $entry.Value.GetType().Name.Replace('FileInfo','')
                        Datastore    = $ds.Name
                    }
                }

                $duration = (Get-Date) - $startTime
                Write-Verbose "Scan completed in $($duration.TotalSeconds.ToString('0.00')) seconds. Found $($orphans.Count) orphans."

                [PSCustomObject]@{
                    Datastore   = $ds.Name
                    OrphanCount = $orphans.Count
                    Orphans     = $orphans
                    ScanTime    = $duration.TotalSeconds
                }
            }
            catch {
                Write-Warning "Error scanning $($ds.Name): $_"
                [PSCustomObject]@{
                    Datastore   = $ds.Name
                    OrphanCount = -1
                    Orphans     = @()
                    Error       = $_.Exception.Message
                }
            }
        }
    }
}


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
        OrphanedFiles = ($Data.OrphanedFiles | Measure-Object -Property OrphanCount -Sum).Sum
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
}


# --------------------------- Helpers --------------------------------------


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

    $btnRefresh               = New-Object System.Windows.Forms.Button
    $btnRefresh.Text          = 'REFRESH'
    $btnRefresh.Font          = New-Object System.Drawing.Font('Segoe UI',10,[System.Drawing.FontStyle]::Bold)
    $btnRefresh.Size          = New-Object System.Drawing.Size(120,35)
    $btnRefresh.BackColor     = $script:Theme.Primary
    $btnRefresh.ForeColor     = $script:Theme.White
    $btnRefresh.FlatStyle     = 'Flat'

    # Event handler: reload script and re-render view
    $btnRefresh.Add_Click({
        . "$PSScriptRoot\DashboardView.ps1"
        Show-DashboardView -ContentPanel $script:uiRefs.ContentPanel
    })

    $flow.Controls.Add($btnRefresh)
    return $flow
}


function Set-StatusMessage {
    <#
    .SYNOPSIS
        Sets the status message with appropriate color coding.
    .DESCRIPTION
        Displays user-friendly status messages in the dashboard footer while
        detailed errors are logged to the console for developers.
    .PARAMETER UiRefs
        Hashtable containing UI control references (must include 'StatusLabel')
    .PARAMETER Message
        The message text to display to the user
    .PARAMETER Type
        Message type that determines color (Success, Warning, Error, Info)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject] $UiRefs,
        [Parameter(Mandatory)]
        [string]$Message,
        [ValidateSet('Success','Warning','Error','Info')]
        [string]$Type = 'Info'
    )
    
    try {
        # Log detailed message to console for debugging
        Write-Verbose "[STATUS] $Type`: $Message"
        
        # Update UI
        $UiRefs.StatusLabel.Text = $Message
        $UiRefs.StatusLabel.ForeColor = switch ($Type) {
            'Success' { $script:Theme.Success }
            'Warning' { $script:Theme.Warning }
            'Error'   { $script:Theme.Error }
            default    { $script:Theme.PrimaryDarker }
        }
        
        # Force immediate UI update
        [System.Windows.Forms.Application]::DoEvents()
    }
    catch {
        Write-Warning "Failed to update status message: $_"
    }
}