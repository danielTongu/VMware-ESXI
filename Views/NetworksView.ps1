# Import required assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing



<#
    .SYNOPSIS
        Displays the Network Manager UI for managing virtual networks.
    .DESCRIPTION
        Initializes the Network Manager UI with overview and operations tabs.
    .PARAMETER ContentPanel
        The Panel where the Network Manager UI is rendered.
#>
function Show-NetworksView {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Forms.Panel]$ContentPanel
    )

    try {
        $uiRefs = New-NetworkLayout -ContentPanel $ContentPanel
        $data = Get-NetworkData
        if ($data) {
            Update-NetworkWithData -UiRefs $uiRefs -Data $data
        } else {
            $uiRefs.StatusLabel.Text = 'No connection to server'
            $uiRefs.StatusLabel.ForeColor = $global:Theme.Error
        }
    } catch {
        Write-Verbose "Network view initialization failed: $_"
    }
}



<#
    .SYNOPSIS
        Creates the layout for the Network Manager UI.
    .DESCRIPTION
        Builds header, tabs, and status area using CWU theme colors.
    .PARAMETER ContentPanel
        The parent Panel to populate.
    .OUTPUTS
        Hashtable of UI references.
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
        $ContentPanel.BackColor = $global:Theme.LightGray

        # Root layout
        $root = [System.Windows.Forms.TableLayoutPanel]::new()
        $root.Dock = 'Fill'  
        $root.ColumnCount = 1  
        $root.RowCount = 3
        $root.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::AutoSize))
        $root.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Percent,100))
        $root.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::AutoSize))
        
        $ContentPanel.Controls.Add($root)

        # Header
        $header = [System.Windows.Forms.Panel]::new()
        $header.Dock = 'Fill'  
        $header.Height = 80
        $header.BackColor = $global:Theme.Primary
        $root.Controls.Add($header,0,0)

        $titleLabel = [System.Windows.Forms.Label]::new()
        $titleLabel.Text = 'NETWORK MANAGER'
        $titleLabel.Font = [System.Drawing.Font]::new('Segoe UI',18,[System.Drawing.FontStyle]::Bold)
        $titleLabel.ForeColor = $global:Theme.White
        $titleLabel.Location = [System.Drawing.Point]::new(20,20)
        $titleLabel.AutoSize = $true
        $header.Controls.Add($titleLabel)

        # Main Tab Control
        $tabControl = [System.Windows.Forms.TabControl]::new()
        $tabControl.Dock = 'Fill'
        $tabControl.SizeMode = 'Fixed'
        $tabControl.ItemSize = [System.Drawing.Size]::new(150,40)
        $tabControl.Font = [System.Drawing.Font]::new('Segoe UI',10,[System.Drawing.FontStyle]::Bold)
        $root.Controls.Add($tabControl,0,1)
        $refs = @{ TabControl = $tabControl; Tabs = @{} }

        # Overview Tab
        $tabOverview = [System.Windows.Forms.TabPage]::new('Overview')
        $tabOverview.BackColor = $global:Theme.White
        $tabControl.TabPages.Add($tabOverview)
        $refs.Tabs.Overview = @{}

        $overviewLayout = [System.Windows.Forms.TableLayoutPanel]::new()
        $overviewLayout.Dock = 'Fill'   
        $overviewLayout.RowCount = 2
        $overviewLayout.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Percent,100))
        $overviewLayout.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::AutoSize))
        $tabOverview.Controls.Add($overviewLayout)


        $gridScroller = [System.Windows.Forms.Panel]::new()
        $gridScroller.Dock = 'Fill'
        $gridScroller.AutoScroll = $true
        $gridScroller.Padding = [System.Windows.Forms.Padding]::new(10)
        $gridScroller.BackColor = $global:Theme.White
        $overviewLayout.Controls.Add($gridScroller,0,0)

        $grid = [System.Windows.Forms.DataGridView]::new()
        $grid.Name = 'grdNetworks'  
        $grid.Dock = 'Fill'
        $grid.ReadOnly = $true  
        $grid.AllowUserToAddRows = $false  
        $grid.SelectionMode = 'FullRowSelect'
        $grid.AutoSizeColumnsMode = 'Fill'  
        $grid.BackgroundColor = $global:Theme.White
        $grid.GridColor = $global:Theme.PrimaryDark  
        $grid.BorderStyle = 'Fixed3D'
        $grid.Font = [System.Drawing.Font]::new('Segoe UI',11)
        $grid.ColumnHeadersDefaultCellStyle.Font = [System.Drawing.Font]::new('Segoe UI',10,[System.Drawing.FontStyle]::Bold)
        $grid.ColumnHeadersDefaultCellStyle.ForeColor = $global:Theme.PrimaryDarker
        $grid.AlternatingRowsDefaultCellStyle.BackColor = [System.Drawing.Color]::AliceBlue
        $gridScroller.Controls.Add($grid)
        $refs.Tabs.Overview.NetworkGrid = $grid

        $cols = @(
            @{Name='Name';Header='Name'}, @{Name='Type';Header='Type'}, @{Name='vSwitch';Header='vSwitch'},
            @{Name='VLAN';Header='VLAN'}, @{Name='Ports';Header='Ports'}, @{Name='Used';Header='Used'}
        )
        foreach ($col in $cols) {
            $c = [System.Windows.Forms.DataGridViewTextBoxColumn]::new()
            $c.Name = $col.Name; 
            $c.HeaderText = $col.Header
            $grid.Columns.Add($c) | Out-Null
        }

        $overviewButtons = [System.Windows.Forms.FlowLayoutPanel]::new()
        $overviewButtons.Dock = 'Fill'   
        $overviewButtons.Padding = [System.Windows.Forms.Padding]::new(5)
        $overviewButtons.BackColor = $global:Theme.White  
        $overviewButtons.FlowDirection = 'RightToLeft'
        $overviewLayout.Controls.Add($overviewButtons,0,1)

        $btnRefresh = [System.Windows.Forms.Button]::new()
        $btnRefresh.Name = 'btnRefresh'  
        $btnRefresh.Text = 'REFRESH'
        $btnRefresh.Size = [System.Drawing.Size]::new(150,40)
        $btnRefresh.Font = [System.Drawing.Font]::new('Segoe UI',10,[System.Drawing.FontStyle]::Bold)
        $btnRefresh.BackColor = $global:Theme.Primary   
        $btnRefresh.ForeColor = $global:Theme.White
        $overviewButtons.Controls.Add($btnRefresh)
        $refs.Tabs.Overview.RefreshButton = $btnRefresh

        # Port Group Operations Tab
        $tabPortGroups = [System.Windows.Forms.TabPage]::new('Port Groups')
        $tabPortGroups.BackColor = $global:Theme.White
        $tabControl.TabPages.Add($tabPortGroups)
        $refs.Tabs.PortGroups = @{}

        $portGroupLayout = [System.Windows.Forms.TableLayoutPanel]::new()
        $portGroupLayout.Dock = 'Fill'
        $portGroupLayout.ColumnCount = 2
        $portGroupLayout.RowCount = 4
        $portGroupLayout.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Autosize))
        $portGroupLayout.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Percent,100))
        $portGroupLayout.Padding = [System.Windows.Forms.Padding]::new(10)
        $tabPortGroups.Controls.Add($portGroupLayout)

        $lblName = [System.Windows.Forms.Label]::new()
        $lblName.Text = 'Port Group Name:'
        $lblName.Autosize = $true #dont wrap
        $lblName.Font = [System.Drawing.Font]::new('Segoe UI',11)
        $lblName.Dock = 'Fill'   
        $lblName.TextAlign = 'MiddleRight'   
        $portGroupLayout.Controls.Add($lblName,0,0)

        $txtName = [System.Windows.Forms.TextBox]::new()   
        $txtName.Name = 'txtPortGroupName'   
        $txtName.Font = [System.Drawing.Font]::new('Segoe UI',11)
        $txtName.Dock = 'Fill'   
        $txtName.BackColor = $global:Theme.White  
        $portGroupLayout.Controls.Add($txtName,1,0)
        $refs.Tabs.PortGroups.NameText = $txtName

        $lblSwitch = [System.Windows.Forms.Label]::new()
        $lblSwitch.Text = 'vSwitch:'
        $lblSwitch.Font = [System.Drawing.Font]::new('Segoe UI',11)
        $lblSwitch.Dock = 'Fill'   
        $lblSwitch.TextAlign = 'MiddleRight'  
        $portGroupLayout.Controls.Add($lblSwitch,0,1)

        $cmbSwitch = [System.Windows.Forms.ComboBox]::new()   
        $cmbSwitch.Name = 'cmbSwitch'  
        $cmbSwitch.DropDownStyle = 'DropDownList'
        $cmbSwitch.Font = [System.Drawing.Font]::new('Segoe UI',11)   
        $cmbSwitch.Dock = 'Fill'  
        $cmbSwitch.BackColor = $global:Theme.White  
        $portGroupLayout.Controls.Add($cmbSwitch,1,1)
        $refs.Tabs.PortGroups.SwitchCombo = $cmbSwitch

        $lblVLAN = [System.Windows.Forms.Label]::new()
        $lblVLAN.Text = 'VLAN ID:'
        $lblVLAN.Font = [System.Drawing.Font]::new('Segoe UI',11)
        $lblVLAN.Dock = 'Fill'   
        $lblVLAN.TextAlign = 'MiddleRight'  
        $portGroupLayout.Controls.Add($lblVLAN,0,2)

        $txtVLAN = [System.Windows.Forms.TextBox]::new()   
        $txtVLAN.Name = 'txtVLAN'   
        $txtVLAN.Font = [System.Drawing.Font]::new('Segoe UI',11)
        $txtVLAN.Dock = 'Fill'   
        $txtVLAN.BackColor = $global:Theme.White   
        $portGroupLayout.Controls.Add($txtVLAN,1,2)
        $refs.Tabs.PortGroups.VLANText = $txtVLAN

        $portGroupButtons = [System.Windows.Forms.FlowLayoutPanel]::new()   
        $portGroupButtons.Dock = 'Fill'
        $portGroupLayout.Controls.Add($portGroupButtons,1,3)
        $portGroupLayout.SetColumnSpan($portGroupButtons,2)

        $btnAdd = [System.Windows.Forms.Button]::new()  
        $btnAdd.Name = 'btnAddPortGroup'  
        $btnAdd.Text = 'ADD PORT GROUP'
        $btnAdd.Size = [System.Drawing.Size]::new(180,40)   
        $btnAdd.Font = [System.Drawing.Font]::new('Segoe UI',10,[System.Drawing.FontStyle]::Bold)
        $btnAdd.BackColor = $global:Theme.Primary   
        $btnAdd.ForeColor = $global:Theme.White  
        $portGroupButtons.Controls.Add($btnAdd)
        $refs.Tabs.PortGroups.AddButton = $btnAdd

        $btnRemove = [System.Windows.Forms.Button]::new()  
        $btnRemove.Name = 'btnRemovePortGroup'  
        $btnRemove.Text = 'REMOVE PORT GROUP'
        $btnRemove.Size = [System.Drawing.Size]::new(180,40)  
        $btnRemove.Font = [System.Drawing.Font]::new('Segoe UI',10,[System.Drawing.FontStyle]::Bold)
        $btnRemove.BackColor = $global:Theme.Error  
        $btnRemove.ForeColor = $global:Theme.White  
        $portGroupButtons.Controls.Add($btnRemove)
        $refs.Tabs.PortGroups.RemoveButton = $btnRemove

        # Bulk Networks Tab
        $tabBulkNetworks = [System.Windows.Forms.TabPage]::new('Bulk Networks')
        $tabBulkNetworks.BackColor = $global:Theme.White
        $tabControl.TabPages.Add($tabBulkNetworks)
        $refs.Tabs.BulkNetworks = @{}

        $bulkLayout = [System.Windows.Forms.TableLayoutPanel]::new()   
        $bulkLayout.Dock = 'Fill'   
        $bulkLayout.ColumnCount = 2   
        $bulkLayout.RowCount = 3
        $bulkLayout.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Autosize))
        $bulkLayout.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Percent,100))
        $bulkLayout.Padding = [System.Windows.Forms.Padding]::new(10)   
        $tabBulkNetworks.Controls.Add($bulkLayout)

        $lblCourse = [System.Windows.Forms.Label]::new()
        $lblCourse.Text = 'Course Prefix:'
        $lblCourse.Font = [System.Drawing.Font]::new('Segoe UI',11)
        $lblCourse.Dock = 'Fill'   
        $lblCourse.TextAlign = 'MiddleRight'  
        $bulkLayout.Controls.Add($lblCourse,0,0)

        $txtCourse = [System.Windows.Forms.TextBox]::new()  
        $txtCourse.Name = 'txtCoursePrefix'  
        $txtCourse.Font = [System.Drawing.Font]::new('Segoe UI',11)
        $txtCourse.Dock = 'Fill'   
        $txtCourse.BackColor = $global:Theme.White  
        $bulkLayout.Controls.Add($txtCourse,1,0)
        $refs.Tabs.BulkNetworks.CoursePrefixText = $txtCourse

        $lblRange = [System.Windows.Forms.Label]::new()
        $lblRange.Text = 'Student Range:'
        $lblRange.Autosize = $true #dont wrap
        $lblRange.Font = [System.Drawing.Font]::new('Segoe UI',11)
        $lblRange.Dock = 'Fill'  
        $lblRange.TextAlign = 'TopRight'  
        $bulkLayout.Controls.Add($lblRange,0,1)

        $rangePanel = [System.Windows.Forms.FlowLayoutPanel]::new()   
        $rangePanel.Dock = 'Fill'  
        $rangePanel.WrapContents = $false
        $bulkLayout.Controls.Add($rangePanel,1,1)

        $txtStart = [System.Windows.Forms.TextBox]::new()  
        $txtStart.Name = 'txtRangeStart'  
        $txtStart.Font = [System.Drawing.Font]::new('Segoe UI',11)
        $txtStart.Size = [System.Drawing.Size]::new(50,25)  
        $txtStart.Text = '1'  
        $txtStart.BackColor = $global:Theme.White   
        $rangePanel.Controls.Add($txtStart)
        $refs.Tabs.BulkNetworks.RangeStartText = $txtStart

        $lblTo = [System.Windows.Forms.Label]::new()
        $lblTo.Text = ' to '
        $lblTo.Font = [System.Drawing.Font]::new('Segoe UI',11)  
        $lblTo.AutoSize = $true  
        $lblTo.Margin = [System.Windows.Forms.Padding]::new(5,5,0,0)
        $rangePanel.Controls.Add($lblTo)

        $txtEnd = [System.Windows.Forms.TextBox]::new()   
        $txtEnd.Name = 'txtRangeEnd'   
        $txtEnd.Font = [System.Drawing.Font]::new('Segoe UI',11)
        $txtEnd.Size = [System.Drawing.Size]::new(50,25)   
        $txtEnd.Text = '10'   
        $txtEnd.BackColor = $global:Theme.White  
        $rangePanel.Controls.Add($txtEnd)
        $refs.Tabs.BulkNetworks.RangeEndText = $txtEnd

        $bulkButtons = [System.Windows.Forms.FlowLayoutPanel]::new()  
        $bulkButtons.Dock = 'Fill'
        $bulkLayout.Controls.Add($bulkButtons,1,2)  
        $bulkLayout.SetColumnSpan($bulkButtons,2)

        $btnBulkAdd = [System.Windows.Forms.Button]::new()  
        $btnBulkAdd.Name = 'btnBulkAdd'  
        $btnBulkAdd.Text = 'CREATE NETWORKS'
        $btnBulkAdd.Size = [System.Drawing.Size]::new(180,40)  
        $btnBulkAdd.Font = [System.Drawing.Font]::new('Segoe UI',10,[System.Drawing.FontStyle]::Bold)
        $btnBulkAdd.BackColor = $global:Theme.Primary  
        $btnBulkAdd.ForeColor = $global:Theme.White  
        $bulkButtons.Controls.Add($btnBulkAdd)
        $refs.Tabs.BulkNetworks.BulkAddButton = $btnBulkAdd

        $btnBulkRem = [System.Windows.Forms.Button]::new()   
        $btnBulkRem.Name = 'btnBulkRemove'   
        $btnBulkRem.Text = 'REMOVE NETWORKS'
        $btnBulkRem.Size = [System.Drawing.Size]::new(180,40)   
        $btnBulkRem.Font = [System.Drawing.Font]::new('Segoe UI',10,[System.Drawing.FontStyle]::Bold)
        $btnBulkRem.BackColor = $global:Theme.Error   
        $btnBulkRem.ForeColor = $global:Theme.White  
        $bulkButtons.Controls.Add($btnBulkRem)
        $refs.Tabs.BulkNetworks.BulkRemoveButton = $btnBulkRem

        # Status section
        $statusPanel = [System.Windows.Forms.Panel]::new()   
        $statusPanel.Dock = 'Fill'  
        $statusPanel.Height = 30  
        $statusPanel.BackColor = $global:Theme.LightGray
        $root.Controls.Add($statusPanel,0,2)

        $statusLabel = [System.Windows.Forms.Label]::new()  
        $statusLabel.Name = 'StatusLabel'  
        $statusLabel.Text = 'Ready'
        $statusLabel.Font = [System.Drawing.Font]::new('Segoe UI',9)   
        $statusLabel.Dock = 'Fill'   
        $statusLabel.TextAlign = 'MiddleLeft'
        $statusLabel.ForeColor = $global:Theme.PrimaryDark   
        $statusPanel.Controls.Add($statusLabel)
        $refs.StatusLabel = $statusLabel

        return $refs
    } finally { 
        $ContentPanel.ResumeLayout($true) 
    }
}



<#
    .SYNOPSIS
        Retrieves network data from the server.
    .DESCRIPTION
        Gets virtual switches and port groups; returns hashtable or $null if disconnected.
#>
function Get-NetworkData {
    try {
        $conn = [VMServerConnection]::GetInstance().GetConnection()
        if (-not $conn) { return $null }

        $vs = Get-VirtualSwitch -Server $conn -ErrorAction SilentlyContinue
        $pgs = Get-VirtualPortGroup -Server $conn -ErrorAction SilentlyContinue

        return @{ 
            VirtualSwitches = $vs   
            PortGroups = $pgs   
            LastUpdated = Get-Date 
        }
    } catch {
        Write-Verbose "Network data collection failed: $_"
        return $null 
    }
}



<#
    .SYNOPSIS
        Updates the network view with new data.
    .PARAMETER UiRefs
        Hashtable of UI references.
    .PARAMETER Data
        Hashtable containing network data.
#>
function Update-NetworkWithData {
    param([hashtable]$UiRefs, [hashtable]$Data)
    try {
        $UiRefs.Tabs.Overview.NetworkGrid.DataSource = $null
        $UiRefs.Tabs.Operations.SwitchCombo.Items.Clear()

        foreach ($v in $Data.VirtualSwitches) { 
            $UiRefs.Tabs.Operations.SwitchCombo.Items.Add($v.Name) | Out-Null 
        }
        
        if ($UiRefs.Tabs.Operations.SwitchCombo.Items.Count) { 
            $UiRefs.Tabs.Operations.SwitchCombo.SelectedIndex = 0 
        }

        $list = [System.Collections.ArrayList]::new()

        foreach ($v in $Data.VirtualSwitches) {
            $list.Add([PSCustomObject]@{ 
                Name = $v.Name;
                Type = 'vSwitch'; 
                vSwitch = ''; 
                VLAN = ''; 
                Ports = $v.NumPorts; 
                Used = $v.NumPortsAvailable 
            }) | Out-Null
        }

        foreach ($p in $Data.PortGroups) {
            $list.Add([PSCustomObject]@{ 
                Name = $p.Name; 
                Type = 'Port Group'; 
                vSwitch = $p.VirtualSwitchName; 
                VLAN = $p.VLanId;
                Ports = '';
                Used = '' 
            }) | Out-Null
        }

        $UiRefs.Tabs.Overview.NetworkGrid.DataSource = $list
        $UiRefs.StatusLabel.Text = "Data loaded at $($Data.LastUpdated.ToString('HH:mm:ss'))"
    } catch {
        Write-Verbose "Failed to update network view: $_"
        $UiRefs.StatusLabel.Text = 'Error loading data'
    }
}
