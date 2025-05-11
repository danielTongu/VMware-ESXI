Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing



# ────────────────────────────────────────────────────────────────────────────
#                       Views/NetworksView.ps1
# ────────────────────────────────────────────────────────────────────────────



<#
.SYNOPSIS
    Displays the Network Manager UI for managing virtual networks.
.DESCRIPTION
    This function initializes the Network Manager UI, including tabs for overview and operations.
    It populates the UI with data from the server if connected.
.PARAMETER ContentPanel
    The panel where the Network Manager UI will be displayed.
.EXAMPLE
    Show-NetworksView -ContentPanel $mainPanel
    Initializes the Network Manager UI in the specified content panel.
#>
function Show-NetworksView {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Forms.Panel]$ContentPanel
    )

    try {
        # Build UI (empty)
        $uiRefs = New-NetworkLayout -ContentPanel $ContentPanel

        # Populate with data if connected
        $data = Get-NetworkData
        if ($data) {
            Update-NetworkWithData -UiRefs $uiRefs -Data $data
        } else {
            $uiRefs.StatusLabel.Text = "No connection to server"
            $uiRefs.StatusLabel.ForeColor = $global:theme.Error
        }
    } catch { 
        Write-Verbose "Network view initialization failed: $_" 
    }
}





<#
.SYNOPSIS
    Creates the layout for the Network Manager UI.
.DESCRIPTION
    This function sets up the layout for the Network Manager UI, including tabs for overview and operations.
    It initializes the controls and sets their properties.
#>
function New-NetworkLayout {
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
        $root.RowCount = 3
        $root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))   # Header
        $root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent,100))) # Tabs
        $root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))   # Status
        $ContentPanel.Controls.Add($root)



        #===== Row [1] HEADER ===========================================
        $header = New-Object System.Windows.Forms.Panel
        $header.Dock = 'Fill'
        $header.Height = 80
        $header.BackColor = $global:theme.Primary
        $root.Controls.Add($header, 0, 0)

        $titleLabel = New-Object System.Windows.Forms.Label
        $titleLabel.Text = 'NETWORK MANAGER'
        $titleLabel.Font = New-Object System.Drawing.Font('Segoe UI', 18, [System.Drawing.FontStyle]::Bold)
        $titleLabel.ForeColor = [System.Drawing.Color]::White
        $titleLabel.Location = New-Object System.Drawing.Point(20, 20)
        $titleLabel.AutoSize = $true
        $header.Controls.Add($titleLabel)



        #===== Row [2] TABCONTROL =========================================
        $tabControl = New-Object System.Windows.Forms.TabControl
        $tabControl.Dock = 'Fill'
        $tabControl.SizeMode = 'Fixed'
        $tabControl.ItemSize = New-Object System.Drawing.Size(150, 40)
        $tabControl.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
        $root.Controls.Add($tabControl, 0, 1)

        # Hashtable for UI references
        $refs = @{
            TabControl = $tabControl
            Tabs = @{}
        }

        #    Overview Tab ------------------------------------------------
        $tabOverview = New-Object System.Windows.Forms.TabPage
        $tabOverview.Text = "Overview"
        $tabOverview.BackColor = $global:theme.Background
        $tabControl.TabPages.Add($tabOverview)
        $refs.Tabs.Overview = @{}

        # Overview layout
        $overviewLayout = New-Object System.Windows.Forms.TableLayoutPanel
        $overviewLayout.Dock = 'Fill'
        $overviewLayout.RowCount = 2
        $overviewLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent,100)))
        $overviewLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
        $tabOverview.Controls.Add($overviewLayout)

        # Network grid
        $grid = New-Object System.Windows.Forms.DataGridView
        $grid.Name = 'grdNetworks'
        $grid.Dock = 'Fill'
        $grid.ReadOnly = $true
        $grid.AllowUserToAddRows = $false
        $grid.SelectionMode = 'FullRowSelect'
        $grid.AutoSizeColumnsMode = 'Fill'
        $grid.BackgroundColor = $global:theme.CardBackground
        $grid.GridColor = $global:theme.Border
        $grid.BorderStyle = 'Fixed3D'
        $grid.Font = New-Object System.Drawing.Font('Segoe UI', 11)
        $grid.ColumnHeadersDefaultCellStyle.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
        $grid.ColumnHeadersDefaultCellStyle.ForeColor = $global:theme.TextPrimary
        $grid.AlternatingRowsDefaultCellStyle.BackColor = [System.Drawing.Color]::AliceBlue
        $overviewLayout.Controls.Add($grid, 0, 0)
        $refs.Tabs.Overview.NetworkGrid = $grid

        # Define overview columns
        $columns = @(
            @{Name='Name';    Header='Name'},
            @{Name='Type';    Header='Type'},
            @{Name='vSwitch'; Header='vSwitch'},
            @{Name='VLAN';    Header='VLAN'},
            @{Name='Ports';   Header='Ports'},
            @{Name='Used';    Header='Used'}
        )
        foreach ($col in $columns) {
            $gridCol = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
            $gridCol.Name = $col.Name
            $gridCol.HeaderText = $col.Header
            $grid.Columns.Add($gridCol) | Out-Null
        }

        # Overview buttons panel
        $overviewButtons = New-Object System.Windows.Forms.FlowLayoutPanel
        $overviewButtons.Dock = 'Fill'
        $overviewButtons.Padding = New-Object System.Windows.Forms.Padding(5)
        $overviewButtons.BackColor = $global:theme.Background
        $overviewButtons.FlowDirection = 'RightToLeft'
        $overviewLayout.Controls.Add($overviewButtons, 0, 1)

        # Refresh button
        $btnRefresh = New-Object System.Windows.Forms.Button
        $btnRefresh.Name = 'btnRefresh'
        $btnRefresh.Text = 'REFRESH'
        $btnRefresh.Size = New-Object System.Drawing.Size(150, 40)
        $btnRefresh.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
        $btnRefresh.BackColor = $global:theme.Secondary
        $btnRefresh.ForeColor = [System.Drawing.Color]::White
        $overviewButtons.Controls.Add($btnRefresh)
        $refs.Tabs.Overview.RefreshButton = $btnRefresh

        #    Operations Tab ----------------------------------------------
        $tabOperations = New-Object System.Windows.Forms.TabPage
        $tabOperations.Text = "Operations"
        $tabOperations.BackColor = $global:theme.Background
        $tabControl.TabPages.Add($tabOperations)
        $refs.Tabs.Operations = @{}

        # Operations layout
        $operationsLayout = New-Object System.Windows.Forms.TableLayoutPanel
        $operationsLayout.Dock = 'Fill'
        $operationsLayout.RowCount = 3
        $operationsLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent,100)))
        $operationsLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent,100)))
        $operationsLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
        $tabOperations.Controls.Add($operationsLayout)

        # Single Network Operations
        $singleNetworkGroup = New-Object System.Windows.Forms.GroupBox
        $singleNetworkGroup.Text = "Single Network Operations"
        $singleNetworkGroup.Dock = 'Fill'
        $singleNetworkGroup.Font = New-Object System.Drawing.Font('Segoe UI', 12, [System.Drawing.FontStyle]::Bold)
        $singleNetworkGroup.ForeColor = $global:theme.Primary
        $operationsLayout.Controls.Add($singleNetworkGroup, 0, 0)

        $singleNetworkPanel = New-Object System.Windows.Forms.TableLayoutPanel
        $singleNetworkPanel.Dock = 'Fill'
        $singleNetworkPanel.ColumnCount = 2
        $singleNetworkPanel.RowCount = 4
        $singleNetworkPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent,30)))
        $singleNetworkPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent,70)))
        $singleNetworkPanel.Padding = New-Object System.Windows.Forms.Padding(10)
        $singleNetworkGroup.Controls.Add($singleNetworkPanel)

        # Network Name
        $lblName = New-Object System.Windows.Forms.Label
        $lblName.Text = 'Network Name:'
        $lblName.Font = New-Object System.Drawing.Font('Segoe UI', 11)
        $lblName.Dock = 'Fill'
        $lblName.TextAlign = 'MiddleRight'
        $singleNetworkPanel.Controls.Add($lblName, 0, 0)

        $txtName = New-Object System.Windows.Forms.TextBox
        $txtName.Name = 'txtNetworkName'
        $txtName.Font = New-Object System.Drawing.Font('Segoe UI', 11)
        $txtName.Dock = 'Fill'
        $txtName.BackColor = $global:theme.CardBackground
        $singleNetworkPanel.Controls.Add($txtName, 1, 0)
        $refs.Tabs.Operations.NetworkNameText = $txtName

        # vSwitch
        $lblSwitch = New-Object System.Windows.Forms.Label
        $lblSwitch.Text = 'vSwitch:'
        $lblSwitch.Font = New-Object System.Drawing.Font('Segoe UI', 11)
        $lblSwitch.Dock = 'Fill'
        $lblSwitch.TextAlign = 'MiddleRight'
        $singleNetworkPanel.Controls.Add($lblSwitch, 0, 1)

        $cmbSwitch = New-Object System.Windows.Forms.ComboBox
        $cmbSwitch.Name = 'cmbSwitch'
        $cmbSwitch.DropDownStyle = 'DropDownList'
        $cmbSwitch.Font = New-Object System.Drawing.Font('Segoe UI', 11)
        $cmbSwitch.Dock = 'Fill'
        $singleNetworkPanel.Controls.Add($cmbSwitch, 1, 1)
        $refs.Tabs.Operations.SwitchCombo = $cmbSwitch

        # VLAN ID
        $lblVLAN = New-Object System.Windows.Forms.Label
        $lblVLAN.Text = 'VLAN ID:'
        $lblVLAN.Font = New-Object System.Drawing.Font('Segoe UI', 11)
        $lblVLAN.Dock = 'Fill'
        $lblVLAN.TextAlign = 'MiddleRight'
        $singleNetworkPanel.Controls.Add($lblVLAN, 0, 2)

        $txtVLAN = New-Object System.Windows.Forms.TextBox
        $txtVLAN.Name = 'txtVLAN'
        $txtVLAN.Font = New-Object System.Drawing.Font('Segoe UI', 11)
        $txtVLAN.Dock = 'Fill'
        $txtVLAN.BackColor = $global:theme.CardBackground
        $singleNetworkPanel.Controls.Add($txtVLAN, 1, 2)
        $refs.Tabs.Operations.VLANText = $txtVLAN

        # Single Network Buttons
        $singleNetworkButtons = New-Object System.Windows.Forms.FlowLayoutPanel
        $singleNetworkButtons.Dock = 'Fill'
        $singleNetworkButtons.Padding = New-Object System.Windows.Forms.Padding(5)
        $singleNetworkButtons.BackColor = $global:theme.Background
        $singleNetworkPanel.Controls.Add($singleNetworkButtons, 0, 3)
        $singleNetworkPanel.SetColumnSpan($singleNetworkButtons, 2)

        $btnAdd = New-Object System.Windows.Forms.Button
        $btnAdd.Name = 'btnAddPortGroup'
        $btnAdd.Text = 'ADD PORT GROUP'
        $btnAdd.Size = New-Object System.Drawing.Size(180, 40)
        $btnAdd.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
        $btnAdd.BackColor = $global:theme.Primary
        $btnAdd.ForeColor = [System.Drawing.Color]::White
        $singleNetworkButtons.Controls.Add($btnAdd)
        $refs.Tabs.Operations.AddButton = $btnAdd

        $btnRemove = New-Object System.Windows.Forms.Button
        $btnRemove.Name = 'btnRemovePortGroup'
        $btnRemove.Text = 'REMOVE PORT GROUP'
        $btnRemove.Size = New-Object System.Drawing.Size(180, 40)
        $btnRemove.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
        $btnRemove.BackColor = $global:theme.Error
        $btnRemove.ForeColor = [System.Drawing.Color]::White
        $singleNetworkButtons.Controls.Add($btnRemove)
        $refs.Tabs.Operations.RemoveButton = $btnRemove

        # Bulk Student Networks
        $bulkNetworkGroup = New-Object System.Windows.Forms.GroupBox
        $bulkNetworkGroup.Text = "Bulk Student Networks"
        $bulkNetworkGroup.Dock = 'Fill'
        $bulkNetworkGroup.Font = New-Object System.Drawing.Font('Segoe UI', 12, [System.Drawing.FontStyle]::Bold)
        $bulkNetworkGroup.ForeColor = $global:theme.Primary
        $operationsLayout.Controls.Add($bulkNetworkGroup, 0, 1)

        $bulkNetworkPanel = New-Object System.Windows.Forms.TableLayoutPanel
        $bulkNetworkPanel.Dock = 'Fill'
        $bulkNetworkPanel.ColumnCount = 2
        $bulkNetworkPanel.RowCount = 3
        $bulkNetworkPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent,30)))
        $bulkNetworkPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent,70)))
        $bulkNetworkPanel.Padding = New-Object System.Windows.Forms.Padding(10)
        $bulkNetworkGroup.Controls.Add($bulkNetworkPanel)

        # Course Prefix
        $lblCourse = New-Object System.Windows.Forms.Label
        $lblCourse.Text = 'Course Prefix:'
        $lblCourse.Font = New-Object System.Drawing.Font('Segoe UI', 11)
        $lblCourse.Dock = 'Fill'
        $lblCourse.TextAlign = 'MiddleRight'
        $bulkNetworkPanel.Controls.Add($lblCourse, 0, 0)

        $txtCourse = New-Object System.Windows.Forms.TextBox
        $txtCourse.Name = 'txtCoursePrefix'
        $txtCourse.Font = New-Object System.Drawing.Font('Segoe UI', 11)
        $txtCourse.Dock = 'Fill'
        $txtCourse.BackColor = $global:theme.CardBackground
        $bulkNetworkPanel.Controls.Add($txtCourse, 1, 0)
        $refs.Tabs.Operations.CoursePrefixText = $txtCourse

        # Student Range
        $lblRange = New-Object System.Windows.Forms.Label
        $lblRange.Text = 'Student Range:'
        $lblRange.Font = New-Object System.Drawing.Font('Segoe UI', 11)
        $lblRange.Dock = 'Fill'
        $lblRange.TextAlign = 'MiddleRight'
        $bulkNetworkPanel.Controls.Add($lblRange, 0, 1)

        $rangePanel = New-Object System.Windows.Forms.FlowLayoutPanel
        $rangePanel.Dock = 'Fill'
        $rangePanel.WrapContents = $false
        $bulkNetworkPanel.Controls.Add($rangePanel, 1, 1)

        $txtStart = New-Object System.Windows.Forms.TextBox
        $txtStart.Name = 'txtRangeStart'
        $txtStart.Font = New-Object System.Drawing.Font('Segoe UI', 11)
        $txtStart.Size = New-Object System.Drawing.Size(50, 25)
        $txtStart.Text = '1'
        $txtStart.BackColor = $global:theme.CardBackground
        $rangePanel.Controls.Add($txtStart)
        $refs.Tabs.Operations.RangeStartText = $txtStart

        $lblTo = New-Object System.Windows.Forms.Label
        $lblTo.Text = ' to '
        $lblTo.Font = New-Object System.Drawing.Font('Segoe UI', 11)
        $lblTo.AutoSize = $true
        $lblTo.Margin = New-Object System.Windows.Forms.Padding(5, 5, 0, 0)
        $rangePanel.Controls.Add($lblTo)

        $txtEnd = New-Object System.Windows.Forms.TextBox
        $txtEnd.Name = 'txtRangeEnd'
        $txtEnd.Font = New-Object System.Drawing.Font('Segoe UI', 11)
        $txtEnd.Size = New-Object System.Drawing.Size(50, 25)
        $txtEnd.Text = '10'
        $txtEnd.BackColor = $global:theme.CardBackground
        $rangePanel.Controls.Add($txtEnd)
        $refs.Tabs.Operations.RangeEndText = $txtEnd

        # Bulk Network Buttons
        $bulkNetworkButtons = New-Object System.Windows.Forms.FlowLayoutPanel
        $bulkNetworkButtons.Dock = 'Fill'
        $bulkNetworkButtons.Padding = New-Object System.Windows.Forms.Padding(5)
        $bulkNetworkButtons.BackColor = $global:theme.Background
        $bulkNetworkPanel.Controls.Add($bulkNetworkButtons, 0, 2)
        $bulkNetworkPanel.SetColumnSpan($bulkNetworkButtons, 2)

        $btnBulkAdd = New-Object System.Windows.Forms.Button
        $btnBulkAdd.Name = 'btnBulkAdd'
        $btnBulkAdd.Text = 'CREATE NETWORKS'
        $btnBulkAdd.Size = New-Object System.Drawing.Size(180, 40)
        $btnBulkAdd.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
        $btnBulkAdd.BackColor = $global:theme.Primary
        $btnBulkAdd.ForeColor = [System.Drawing.Color]::White
        $bulkNetworkButtons.Controls.Add($btnBulkAdd)
        $refs.Tabs.Operations.BulkAddButton = $btnBulkAdd

        $btnBulkRem = New-Object System.Windows.Forms.Button
        $btnBulkRem.Name = 'btnBulkRemove'
        $btnBulkRem.Text = 'REMOVE NETWORKS'
        $btnBulkRem.Size = New-Object System.Drawing.Size(180, 40)
        $btnBulkRem.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
        $btnBulkRem.BackColor = $global:theme.Error
        $btnBulkRem.ForeColor = [System.Drawing.Color]::White
        $bulkNetworkButtons.Controls.Add($btnBulkRem)
        $refs.Tabs.Operations.BulkRemoveButton = $btnBulkRem



        #===== Row [3] STATUS SECTION =======================================
        $statusPanel = New-Object System.Windows.Forms.Panel
        $statusPanel.Dock = 'Fill'
        $statusPanel.Height = 30
        $statusPanel.BackColor = $global:theme.Background
        $root.Controls.Add($statusPanel, 0, 2)

        $statusLabel = New-Object System.Windows.Forms.Label
        $statusLabel.Name = 'StatusLabel'
        $statusLabel.Text = 'Ready'
        $statusLabel.Font = New-Object System.Drawing.Font('Segoe UI', 9)
        $statusLabel.Dock = 'Fill'
        $statusLabel.TextAlign = 'MiddleLeft'
        $statusLabel.ForeColor = $global:theme.TextSecondary
        $statusPanel.Controls.Add($statusLabel)
        $refs.StatusLabel = $statusLabel

        return $refs
    }
    finally {
        $ContentPanel.ResumeLayout($true)
    }
}




<#
.SYNOPSIS
    Retrieves network data from the server.
.DESCRIPTION
    This function connects to the server and retrieves data about virtual switches and port groups.
    It returns a hashtable containing the data.
.PARAMETER ServerConnection
    The server connection object used to retrieve network data.
.EXAMPLE
    $networkData = Get-NetworkData -ServerConnection $conn
    Retrieves network data from the specified server connection.
#>
function Get-NetworkData {
    [CmdletBinding()]
    param()

    try {
        $conn = [VMServerConnection]::GetInstance().GetConnection()
        if (-not $conn) {
            return $null
        }

        $vs = try { Get-VirtualSwitch -Server $conn } catch {
            Write-Verbose "Failed to get virtual switches: $_"
            @()
        }

        $pgs = try { Get-VirtualPortGroup -Server $conn } catch {
            Write-Verbose "Failed to get port groups: $_"
            @()
        }

        return @{
            VirtualSwitches = $vs
            PortGroups = $pgs
            LastUpdated = (Get-Date)
        }
    }
    catch {
        Write-Verbose "Network data collection failed: $_"
        return $null
    }
}





<#
.SYNOPSIS
    Updates the network view with new data.
.DESCRIPTION
    This function updates the network view with new data from the server.
    It clears existing data and populates the UI with the latest information.
.PARAMETER UiRefs
    A hashtable containing references to UI controls.
.PARAMETER Data
    A hashtable containing the network data to be displayed.
.EXAMPLE
    Update-NetworkWithData -UiRefs $uiRefs -Data $networkData
    Updates the network view with the specified data.
#>
function Update-NetworkWithData {
    [CmdletBinding()]
    param(
        [hashtable]$UiRefs,
        [hashtable]$Data
    )

    try {
        # Clear existing data
        $UiRefs.Tabs.Overview.NetworkGrid.DataSource = $null
        $UiRefs.Tabs.Operations.SwitchCombo.Items.Clear()

        # Populate vSwitch dropdown
        foreach ($v in $Data.VirtualSwitches) {
            $UiRefs.Tabs.Operations.SwitchCombo.Items.Add($v.Name)
        }
        if ($UiRefs.Tabs.Operations.SwitchCombo.Items.Count -gt 0) {
            $UiRefs.Tabs.Operations.SwitchCombo.SelectedIndex = 0
        }

        # Create combined data for grid
        $list = [System.Collections.ArrayList]::new()
        foreach ($v in $Data.VirtualSwitches) {
            $list.Add([PSCustomObject]@{
                Name = $v.Name
                Type = 'vSwitch'
                vSwitch = ''
                VLAN = ''
                Ports = $v.NumPorts
                Used = $v.NumPortsAvailable
            }) | Out-Null
        }

        foreach ($p in $Data.PortGroups) { 
            $list.Add([PSCustomObject]@{
                Name = $p.Name
                Type = 'Port Group'
                vSwitch = $p.VirtualSwitchName
                VLAN = $p.VLanId
                Ports = ''
                Used = ''
            }) | Out-Null
        }

        $UiRefs.Tabs.Overview.NetworkGrid.DataSource = $list
        $UiRefs.StatusLabel.Text = "Data loaded at $($Data.LastUpdated.ToString('HH:mm:ss'))"
    }
    catch {
        Write-Verbose "Failed to update network view: $_"
        $UiRefs.StatusLabel.Text = "Error loading data"
    }
}
