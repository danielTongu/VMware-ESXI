# ─────────────────────────  Assemblies  ──────────────────────────────────────
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms.DataVisualization

# ─────────────────────────  Public entry point  ──────────────────────────────
function Show-NetworksView {
    <#
    .SYNOPSIS
        Renders the vSphere networks view in the supplied WinForms panel.
    .PARAMETER ContentPanel
        The host panel into which the networks view is drawn.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Forms.Panel] $ContentPanel
    )

    $script:Refs = New-NetworksLayout -ContentPanel $ContentPanel

    $data = Get-NetworksData
    if ($data) {
        Update-NetworksWithData -Refs $script:Refs -Data $data
        Wire-UIEvents -Refs $script:Refs
    }
}

function Set-StatusMessage {
    <#
    .SYNOPSIS
        Sets the status message with appropriate color coding.
    #>

    param(
        [Parameter(Mandatory)]
        [psobject]$Refs,
        [string]$Message,
        [ValidateSet('Success','Warning','Error','Info')]
        [string]$Type = 'Info'
    )
    
    $Refs.StatusLabel.Text = $Message
    $Refs.StatusLabel.ForeColor = switch ($Type) {
        'Success' { $script:Theme.Success }
        'Warning' { $script:Theme.Warning }
        'Error'   { $script:Theme.Error }
        default   { $script:Theme.PrimaryDarker }
    }
}

# ─────────────────────────  Data collection  ─────────────────────────────────
function Get-NetworksData {
    <#
    .SYNOPSIS
        Retrieves every data set the networks view will display.
    .OUTPUTS
        [hashtable] – Keys: HostInfo, Datastores, Adapters, Templates,
                    PortGroups.
    #>
    [CmdletBinding()] param()

    $conn = $script:Connection
    if (-not $conn) { 
        Set-StatusMessage -Refs $Refs -Message "No vSphere connection available" -Type Error
        return $null 
    }

    Set-StatusMessage -Refs $Refs -Message "Loading data..." -Type Info

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
    catch { $data.PortGroups    = @()                            }

    Set-StatusMessage -Refs $Refs -Message "Ready" -Type Info

    return $data
}

# ─────────────────────────  Layout builders  ─────────────────────────────────
function New-NetworksLayout {
    <#
    .SYNOPSIS
        Builds the networks UI (header, tab-control, actions, footer).
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

    $Refs = @{ ContentPanel = $ContentPanel }
    
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
    $headerPanel      = New-NetworksHeader
    $root.Controls.Add($headerPanel, 0, 0)
    $lblRefresh       = $headerPanel.Controls.Find('LastRefreshLabel', $true)[0]
    $Refs.Add('LastRefreshLabel', $lblRefresh)

    # ── Tab-control -----------------------------------------------------------
    $tabs             = New-Object System.Windows.Forms.TabControl
    $tabs.Dock        = 'Fill'
    $tabs.SizeMode    = 'Normal'
    $tabs.Padding = New-Object System.Drawing.Point(20, 10)
    $tabs.Font        = New-Object System.Drawing.Font('Segoe UI',10,[System.Drawing.FontStyle]::Bold)
    $tabs.BackColor   = $script:Theme.LightGray
    $root.Controls.Add($tabs, 0, 1)

    # 1. Networks Manager -----------------------------------------------------------------
    $tabManage = New-Object System.Windows.Forms.TabPage 'Manage'
    $tabManage.BackColor = $script:Theme.White
    
    # Main layout for the Manage tab
    $manageLayout = New-Object System.Windows.Forms.TableLayoutPanel
    $manageLayout.Dock = 'Fill'
    $manageLayout.ColumnCount = 2
    $manageLayout.RowCount = 2
    $manageLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle 'Percent',50))
    $manageLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle 'Percent',50))
    $tabManage.Controls.Add($manageLayout)

    # Top label to describe what this tab does.
    $tabNetDescription = New-Object System.Windows.Forms.Label
    $tabNetDescription.Text = "Manages Standard switches and their associated port groups.`n"
    $tabNetDescription.ForeColor = $script:Theme.PrimaryDark
    $tabNetDescription.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $tabNetDescription.Anchor = 'Left'
    $tabNetDescription.AutoSize = $true
    $manageLayout.Controls.Add($tabNetDescription,0,0)
    $manageLayout.SetColumnSpan($tabNetDescription,2)

    #── Left Panel: Add Single Network ────────────────────────────────────────
    $grNetAdd = New-Object System.Windows.Forms.GroupBox
    $grNetAdd.Text = 'Single Network'
    $grNetAdd.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
    $grNetAdd.Dock = 'Fill'
    $grNetAdd.Margin = New-Object System.Windows.Forms.Padding(5)
    $grNetAdd.Padding = New-Object System.Windows.Forms.Padding(10)
    
    $layoutNetAdd = New-Object System.Windows.Forms.TableLayoutPanel
    $layoutNetAdd.Dock = 'Fill'
    $layoutNetAdd.ColumnCount = 3
    $layoutNetAdd.RowCount = 2
    $layoutNetAdd.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle 'AutoSize'))
    $layoutNetAdd.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle 'Percent',100))
    $layoutNetAdd.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle 'Percent',100))
    
    # Network Name Label
    $labelNetworkName = New-Object System.Windows.Forms.Label
    $labelNetworkName.Text = "Network Name:"
    $labelNetworkName.Anchor = 'Left'
    $labelNetworkName.AutoSize = $true
    $layoutNetAdd.Controls.Add($labelNetworkName, 0, 0)
    
    # Network Name Input
    $inputNetworkName = New-Object System.Windows.Forms.TextBox
    $inputNetworkName.Dock = 'Fill'
    $inputNetworkName.Margin = New-Object System.Windows.Forms.Padding(0,0,0,5)
    $layoutNetAdd.Controls.Add($inputNetworkName, 1, 0)
    $Refs.Add('NetworkNameInput', $inputNetworkName)
    
    # Add Button
    $btnAddNet = New-Object System.Windows.Forms.Button
    $btnAddNet.Text = "Add Network"
    $btnAddNet.Dock = 'Top'
    $btnAddNet.Size = New-Object System.Drawing.Size(0, 35)
    $btnAddNet.Margin = New-Object System.Windows.Forms.Padding(0,5,5,0)
    $btnAddNet.BackColor = $script:Theme.Primary
    $btnAddNet.ForeColor = $script:Theme.White
    $layoutNetAdd.Controls.Add($btnAddNet, 1, 1)
    $Refs.Add('AddNetworkButton', $btnAddNet)
    
    # Delete Button
    $btnDelNet = New-Object System.Windows.Forms.Button
    $btnDelNet.Text = "Delete Network"
    $btnDelNet.Dock = 'Top'
    $btnDelNet.Size = New-Object System.Drawing.Size(0, 35)
    $btnDelNet.Margin = New-Object System.Windows.Forms.Padding(0,5,5,0)
    $btnDelNet.BackColor = $script:Theme.Error
    $btnDelNet.ForeColor = $script:Theme.White
    $layoutNetAdd.Controls.Add($btnDelNet, 2, 1)
    $Refs.Add('DeleteNetworkButton', $btnDelNet)
    
    $grNetAdd.Controls.Add($layoutNetAdd)
    $manageLayout.Controls.Add($grNetAdd, 0, 1)
    
    #── Right Panel: Multiple Networks ──────────────────────────────────────────
    $grMult = New-Object System.Windows.Forms.GroupBox
    $grMult.Text = 'Multiple Networks'
    $grMult.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
    $grMult.Dock = 'Fill'
    $grMult.Margin = New-Object System.Windows.Forms.Padding(5)
    $grMult.Padding = New-Object System.Windows.Forms.Padding(10)
    
    $layoutMult = New-Object System.Windows.Forms.TableLayoutPanel
    $layoutMult.Dock = 'Fill'
    $layoutMult.ColumnCount = 3
    $layoutMult.RowCount = 4
    $layoutMult.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle 'AutoSize'))
    $layoutMult.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle 'Percent',50))
    $layoutMult.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle 'Percent',50))
    $layoutMult.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'AutoSize'))
    $layoutMult.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'AutoSize'))
    $layoutMult.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'AutoSize'))
    $layoutMult.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'AutoSize'))
    
    # Course Label
    $labelCourse = New-Object System.Windows.Forms.Label
    $labelCourse.Text = "Course Prefix:"
    $labelCourse.Anchor = 'Left'
    $labelCourse.AutoSize = $true
    $layoutMult.Controls.Add($labelCourse, 0, 0)
    
    # Course Input
    $inputCourseID = New-Object System.Windows.Forms.TextBox
    $inputCourseID.Dock = 'Fill'
    $inputCourseID.Margin = New-Object System.Windows.Forms.Padding(0,0,0,5)
    $layoutMult.Controls.Add($inputCourseID, 1, 0)
    $Refs.Add('CoursePrefixInput', $inputCourseID)
    
    # Start Number Label
    $labelStartNum = New-Object System.Windows.Forms.Label
    $labelStartNum.Text = "Start Number:"
    $labelStartNum.Anchor = 'Left'
    $labelStartNum.AutoSize = $true
    $layoutMult.Controls.Add($labelStartNum, 0, 1)
    
    # Start Number Input
    $inputStartNum = New-Object System.Windows.Forms.NumericUpDown
    $inputStartNum.Dock = 'Fill'
    $inputStartNum.Margin = New-Object System.Windows.Forms.Padding(0,0,0,5)
    $inputStartNum.Minimum = 1
    $inputStartNum.Maximum = 999
    $layoutMult.Controls.Add($inputStartNum, 1, 1)
    $Refs.Add('StartNumberInput', $inputStartNum)
    
    # End Number Label
    $labelEndNum = New-Object System.Windows.Forms.Label
    $labelEndNum.Text = "End Number:"
    $labelEndNum.Anchor = 'Left'
    $labelEndNum.AutoSize = $true
    $layoutMult.Controls.Add($labelEndNum, 0, 2)
    
    # End Number Input
    $inputEndNum = New-Object System.Windows.Forms.NumericUpDown
    $inputEndNum.Dock = 'Fill'
    $inputEndNum.Margin = New-Object System.Windows.Forms.Padding(0,0,0,5)
    $inputEndNum.Minimum = 1
    $inputEndNum.Maximum = 999
    $layoutMult.Controls.Add($inputEndNum, 1, 2)
    $Refs.Add('EndNumberInput', $inputEndNum)
    
    # Add Multiple Button
    $btnAddMult = New-Object System.Windows.Forms.Button
    $btnAddMult.Text = "Add Networks"
    $btnAddMult.Dock = 'Top'
    $btnAddMult.Size = New-Object System.Drawing.Size(0, 35)
    $btnAddMult.Margin = New-Object System.Windows.Forms.Padding(0,10,5,0)
    $btnAddMult.BackColor = $script:Theme.Primary
    $btnAddMult.ForeColor = $script:Theme.White
    $layoutMult.Controls.Add($btnAddMult, 1, 3)
    $Refs.Add('AddMultipleButton', $btnAddMult)
    
    # Delete Multiple Button
    $btnDelMult = New-Object System.Windows.Forms.Button
    $btnDelMult.Text = "Delete Networks"
    $btnDelMult.Dock = 'Top'
    $btnDelMult.Size = New-Object System.Drawing.Size(0, 35)
    $btnDelMult.Margin = New-Object System.Windows.Forms.Padding(0,10,5,0)
    $btnDelMult.BackColor = $script:Theme.Error
    $btnDelMult.ForeColor = $script:Theme.White
    $layoutMult.Controls.Add($btnDelMult, 2, 3)
    $Refs.Add('DeleteMultipleButton', $btnDelMult)
    
    $grMult.Controls.Add($layoutMult)
    $manageLayout.Controls.Add($grMult, 1, 1)
    
    $tabs.TabPages.Add($tabManage)

    # 2. Hosts -----------------------------------------------------------------
    $tabHosts = New-Object System.Windows.Forms.TabPage 'Hosts'
    $tabHosts.BackColor = $script:Theme.White
    $hostsTable = New-NetworksTable `
                    -Columns @('Host','CPU Total','Memory GB','Model','Version') `
                    -Name 'HostsTable' `
                    -Refs ([ref]$Refs)
    $tabHosts.Controls.Add($hostsTable)
    $tabs.TabPages.Add($tabHosts)

    # 3. Network Adapters ------------------------------------------------------
    $tabNics = New-Object System.Windows.Forms.TabPage 'Adapters'
    $tabNics.BackColor = $script:Theme.White
    $nicsTable = New-NetworksTable `
                    -Columns @('Host','Name','MAC','Speed (Mbps)','Connected') `
                    -Name 'NicsTable' `
                    -Refs ([ref]$Refs)
    $tabNics.Controls.Add($nicsTable)
    $tabs.TabPages.Add($tabNics)

    # 4. Templates -------------------------------------------------------------
    $tabTpl = New-Object System.Windows.Forms.TabPage 'Templates'
    $tabTpl.BackColor = $script:Theme.White
    $tplTable = New-NetworksTable `
                    -Columns @('Template','Guest OS','CPU','Memory GB','Disk GB') `
                    -Name 'TemplatesTable' `
                    -Refs ([ref]$Refs)
    $tabTpl.Controls.Add($tplTable)
    $tabs.TabPages.Add($tabTpl)

    # 5. Port Groups -----------------------------------------------------------
    $tabPg = New-Object System.Windows.Forms.TabPage 'Port Groups'
    $tabPg.BackColor = $script:Theme.White
    $pgTable = New-NetworksTable `
                    -Columns @('Name','VLAN','vSwitch','Active Ports') `
                    -Name 'PortGroupsTable' `
                    -Refs ([ref]$Refs)
    $tabPg.Controls.Add($pgTable)
    $tabs.TabPages.Add($tabPg)

    # ── Actions bar -----------------------------------------------------------
    $actionsPanel = New-NetworksActions -Refs ([ref]$Refs) -ParentPanel $ContentPanel
    $root.Controls.Add($actionsPanel, 0, 2)

    # ── Footer ----------------------------------------------------------------
    $footer = New-Object System.Windows.Forms.Panel
    $footer.Dock = 'Bottom'
    $footer.Height = 30
    $footer.BackColor = $script:Theme.LightGray

    $status = New-Object System.Windows.Forms.Label
    $status.Name = 'StatusLabel'
    $status.AutoSize = $true
    $status.Font = New-Object System.Drawing.Font('Segoe UI',9)
    $status.ForeColor = $script:Theme.Error
    $status.Text = '---'
    $footer.Controls.Add($status)

    $root.Controls.Add($footer, 0, 3)
    $Refs['StatusLabel'] = $status
    
    return $Refs
}

function New-NetworksHeader {
    <#
    .SYNOPSIS
        Returns the coloured networks header bar.
    #>

    $panel              = New-Object System.Windows.Forms.Panel
    $panel.Dock         = 'Top'
    $panel.Height       = 100
    $panel.BackColor    = $script:Theme.Primary

    $lblTitle           = New-Object System.Windows.Forms.Label
    $lblTitle.Text      = 'NETWORK'
    $lblTitle.Font      = New-Object System.Drawing.Font('Segoe UI',18,[System.Drawing.FontStyle]::Bold)
    $lblTitle.ForeColor = $script:Theme.White
    $lblTitle.Location  = New-Object System.Drawing.Point(20,20)
    $lblTitle.AutoSize  = $true
    $panel.Controls.Add($lblTitle)

    $lblRefresh         = New-Object System.Windows.Forms.Label
    $lblRefresh.Name    = 'LastRefreshLabel'
    $lblRefresh.Text    = "Last refresh: $(Get-Date -Format 'HH:mm:ss tt')"
    $lblRefresh.Font    = New-Object System.Drawing.Font('Segoe UI',9)
    $lblRefresh.ForeColor = $script:Theme.White
    $lblRefresh.Location  = New-Object System.Drawing.Point(20,60)
    $lblRefresh.AutoSize  = $true
    $panel.Controls.Add($lblRefresh)

    return $panel
}

function New-NetworksTable {
    <#
    .SYNOPSIS
        Returns a panel that wraps an empty DataGridView.
    .PARAMETER Columns
        Column headers.
    .PARAMETER Name
        Control name (also used in Refs).
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

function New-NetworksActions {
    <#
    .SYNOPSIS
        Builds the actions bar (REFRESH button).
    #>

    [CmdletBinding()]
    param(
        [ref] $Refs,
        [System.Windows.Forms.Panel] $ParentPanel
    )

    # Added refrence for the Parent panel
    $script:NetworkViewPanel = $ParentPanel

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
        . "$PSScriptRoot\NetworksView.ps1"
        Show-NetworksView -ContentPanel $script:NetworkViewPanel
    })

    $flow.Controls.Add($btnRefresh)
    return $flow
}

# ─────────────────────────  Data-to-UI binder  ───────────────────────────────
function Update-NetworksWithData {
    <#
    .SYNOPSIS
        Pushes all collected data sets into the corresponding UI controls.
    #>

    [CmdletBinding()]
    param(
        [hashtable] $Refs,
        [hashtable] $Data
    )

    Set-StatusMessage -Refs $Refs -Message "Displaying data..." -Type Info

    # ── Connection status --------------------------------------------------------
    if ($Data.HostInfo) {
        $firstHost          = $Data.HostInfo[0]
        message = "CONNECTED to $($firstHost.Name) | vSphere $($firstHost.Version)"
        Set-StatusMessage -Refs $Refs -Message message -Type Success
    }

    # ── Last-refresh -------------------------------------------------------------
    $Refs['LastRefreshLabel'].Text = "Last refresh: $(Get-Date -Format 'HH:mm:ss tt')"

    # ── Hosts --------------------------------------------------------------------
    $grid = $Refs['HostsTable']
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
    $grid = $Refs['NicsTable']
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
    $grid = $Refs['TemplatesTable']
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
    $grid = $Refs['PortGroupsTable']
    $grid.Rows.Clear()
    foreach ($pg in $Data.PortGroups) {
        $rowIdx = $grid.Rows.Add()
        $grid.Rows[$rowIdx].Cells['col_Name'       ].Value = $pg.Name
        $grid.Rows[$rowIdx].Cells['col_VLAN'       ].Value = $pg.VlanId
        $grid.Rows[$rowIdx].Cells['col_vSwitch'    ].Value = $pg.VSwitch
        $grid.Rows[$rowIdx].Cells['col_ActivePorts'].Value = $pg.ActivePorts
    }
}


function Wire-UIEvents {
    <#
    .SYNOPSIS
        Hooks up all UI events with properly captured Refs.
    #>

    param([Parameter(Mandatory)][psobject]$Refs)

    $Refs.RefreshButton.Add_Click({
        . $PSScriptRoot\NetworksView.ps1
        Set-StatusMessage -Refs $Refs -Message "Refreshing..." -Type Info
        Show-NetworksView -ContentPanel $Refs.ContentPanel
    })

    $Refs.DeleteNetworkButton.Add_Click({
        . $PSScriptRoot\NetworksView.ps1
        $networkName = $Refs.NetworkNameInput.Text.Trim()
        if ([string]::IsNullOrWhiteSpace($networkName)) {
            Set-StatusMessage -Refs $Refs -Message "Please enter a network name." -Type Warning
            return
        }

        $result = [System.Windows.Forms.MessageBox]::Show(
            "Are you sure you want to delete the network '$networkName' and its associated switch?",
            "Confirm Delete",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )

        if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
            Set-StatusMessage -Refs $Refs -Message "Deleting network '$networkName'..." -Type Info
            Get-VirtualPortGroup -VMHost (Get-VMHost) -Name $networkName | Remove-VirtualPortGroup -Confirm:$false
            Get-VirtualSwitch -Name $networkName | Remove-VirtualSwitch -Confirm:$false
            Set-StatusMessage -Refs $Refs -Message "Deleted successfully." -Type Success
        } else {
            Set-StatusMessage -Refs $Refs -Message "Delete cancelled." -Type Info
        }
    })

    $Refs.DeleteMultipleButton.Add_Click({
        . $PSScriptRoot\NetworksView.ps1
        $courseNumber = $Refs.CoursePrefixInput.Text.Trim()
        $startStudents = [int]$Refs.StartNumberInput.Value
        $endStudents = [int]$Refs.EndNumberInput.Value

        if ([string]::IsNullOrWhiteSpace($courseNumber)) {
            Set-StatusMessage -Refs $Refs -Message "Please enter a course prefix." -Type Warning
        } elseif ($startStudents -gt $endStudents) {
            Set-StatusMessage -Refs $Refs -Message "Start number must be less than or equal to end number." -Type Warning
        } else {
            $msg = "Are you sure you want to delete networks '$courseNumber\_S$startStudents' to '$courseNumber\_S$endStudents' and their associated switches?"
            $result = [System.Windows.Forms.MessageBox]::Show(
                $msg,
                "Confirm Delete",
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
            if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
                Set-StatusMessage -Refs $Refs -Message "Deleting..." -Type Info

                $vmHost = Get-VMHost
                for ($i = $startStudents; $i -le $endStudents; $i++) {
                    $adapterName = $courseNumber + '_S' + $i
                    Get-VirtualPortGroup -VMHost $vmHost -Name $adapterName | Remove-VirtualPortGroup -Confirm:$false
                    Get-VirtualSwitch -Name $adapterName | Remove-VirtualSwitch -Confirm:$false
                }
                Set-StatusMessage -Refs $Refs -Message "Deleted successfully." -Type Success
            } else {
                Set-StatusMessage -Refs $Refs -Message "Delete cancelled." -Type Info
            }
        }
    })

    $Refs.AddNetworkButton.Add_Click({
        . $PSScriptRoot\NetworksView.ps1
        $networkName = $Refs.NetworkNameInput.Text.Trim()
        if ([string]::IsNullOrWhiteSpace($networkName)) {
            Set-StatusMessage -Refs $Refs -Message "Please enter a network name." -Type Warning
            return
        }
        
        $result = [System.Windows.Forms.MessageBox]::Show(
            "Are you sure you want to add the network '$networkName' and its associated switch?",
            "Confirm Add",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )

        if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
            Set-StatusMessage -Refs $Refs -Message "Adding '$networkName'..." -Type Info
            $vmHost = Get-VMHost
            $vSwitch = New-VirtualSwitch -Name $networkName -VMHost $vmHost
            $vPortGroup = New-VirtualPortGroup -Name $networkName -VirtualSwitch $vSwitch
            Set-StatusMessage -Refs $Refs -Message "Added '$networkName' successfully." -Type Success
        } else {
            Set-StatusMessage -Refs $Refs -Message "Add cancelled." -Type Info
        }
    })

    $Refs.AddMultipleButton.Add_Click({
        . $PSScriptRoot\NetworksView.ps1
        $courseNumber = $Refs.CoursePrefixInput.Text.Trim()
        $startStudents = [int]$Refs.StartNumberInput.Value
        $endStudents = [int]$Refs.EndNumberInput.Value

        if ([string]::IsNullOrWhiteSpace($courseNumber)) {
            Set-StatusMessage -Refs $Refs -Message "Please enter a course prefix." -Type Warning
        } elseif ($startStudents -gt $endStudents) {
            Set-StatusMessage -Refs $Refs -Message "Start number must be less than or equal to end number." -Type Warning
        } else {
            $msg = "Are you sure you want to add networks '$courseNumber`_S$startStudents' to '$courseNumber`_S$endStudents' and their associated switches?"
            $result = [System.Windows.Forms.MessageBox]::Show(
                $msg,
                "Confirm Add",
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Question
            )

            if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
                Set-StatusMessage -Refs $Refs -Message "Adding..." -Type Info
                $vmHost = Get-VMHost

                for ($i = $startStudents; $i -le $endStudents; $i++) {
                    $adapterName = $courseNumber + "_S" + $i
                    if (Get-VirtualSwitch -Name $adapterName 2> $null) {
                        Write-Host "Adapter '$adapterName' already exists."
                    } else {
                        $vSwitch = New-VirtualSwitch -Name $adapterName -VMHost $vmHost
                        $vPortGroup = New-VirtualPortGroup -Name $adapterName -VirtualSwitch $vSwitch
                    }
                }
                Set-StatusMessage -Refs $Refs -Message "Added successfully." -Type Success
            } else {
                Set-StatusMessage -Refs $Refs -Message "Add cancelled." -Type Info
            }
        }
    })
}
