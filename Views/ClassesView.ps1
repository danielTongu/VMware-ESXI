# ------------------------ Load WinForms and Drawing Assemblies ------------------------
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing


function Show-ClassesView {
    <#
    .SYNOPSIS
        Initializes and renders the Classes management UI, loads class/template/datastore/network data,
        and wires up all UI event handlers for class operations.
    .PARAMETER ContentPanel
        Panel to host the UI.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [System.Windows.Forms.Panel] $ContentPanel
    )

    $script:ClassesContentPanel = $ContentPanel
    $script:ClassesUiRefs = New-ClassManagerLayout -ContentPanel $ContentPanel
    $conn = $script:Connection

    if ($conn) {
        try {
            # Update timestamp
            $script:ClassesUiRefs.StatusLabel.Text = "Getting data..."

            $templates  = Get-Template -Server $conn -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
            $datastores = Get-Datastore -Server $conn -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
            $networks   = Get-VirtualPortGroup -Server $conn -ErrorAction SilentlyContinue | Select-Object Name, VirtualSwitch, VLanId
            $classes    = Get-Folder -Server $conn -Type VM -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name

            $data = @{ Templates=$templates; Datastores=$datastores; Networks=$networks; Classes=$classes; LastUpdated=Get-Date }
            Update-ClassManagerWithData -UiRefs $script:ClassesUiRefs -Data $data
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show("Initialization failed: $($_.Exception.Message)", 'Error','OK','Error')
        }
    }

    $ContentPanel.Refresh()
    Wire-UIEvents -UiRefs $script:ClassesUiRefs -ContentPanel $ContentPanel
}


function New-ClassManagerLayout {
    <#
    .SYNOPSIS
        Constructs the UI layout with header, tabs (Overview, Basic, Advanced), and footer.
    .PARAMETER ContentPanel
        Panel to host the UI.
    .OUTPUTS
        Hashtable of references to key UI controls (labels, buttons, tab controls, etc.)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [System.Windows.Forms.Panel] $ContentPanel
    )

    $ContentPanel.Controls.Clear()
    $ContentPanel.BackColor = $script:Theme.LightGray

    # Root layout
    $root = New-Object System.Windows.Forms.TableLayoutPanel
    $root.Dock = 'Fill'
    $root.ColumnCount = 1; $root.RowCount = 3
    $root.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle 'Percent',100))
    $root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'AutoSize'))
    $root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'Percent',100))
    $root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'AutoSize'))
    $ContentPanel.Controls.Add($root)

    # Header
    $header = New-Object System.Windows.Forms.Panel
    $header.Dock = 'Fill'
    $header.Height = 80
    $header.BackColor = $script:Theme.Primary

    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Text = 'CLASS MANAGEMENT'
    $lblTitle.Font = New-Object System.Drawing.Font('Segoe UI', 14, [System.Drawing.FontStyle]::Bold)
    $lblTitle.ForeColor = $script:Theme.White
    $lblTitle.Location = New-Object System.Drawing.Point(20, 15)
    $lblTitle.AutoSize = $true
    $header.Controls.Add($lblTitle)

    $lblLast = New-Object System.Windows.Forms.Label
    $lblLast.Name = 'LastRefreshLabel'
    $lblLast.Text = "Last refresh: $(Get-Date -Format 'HH:mm:ss')"
    $lblLast.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $lblLast.ForeColor = $script:Theme.White
    $lblLast.Location = New-Object System.Drawing.Point(20, 45)
    $lblLast.AutoSize = $true
    $header.Controls.Add($lblLast)

    $root.Controls.Add($header, 0, 0)

    # Main TabControl
    $mainPanel = New-Object System.Windows.Forms.Panel
    $mainPanel.Dock = 'Fill'
    $mainPanel.BackColor = $script:Theme.LightGray
    $root.Controls.Add($mainPanel, 0, 1)

    $tabs = New-Object System.Windows.Forms.TabControl
    $tabs.Dock = 'Fill'
    $tabs.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
    $tabs.Padding = New-Object System.Drawing.Point(20, 10)
    $mainPanel.Controls.Add($tabs)

    # Overview Tab
    $overview = New-Object System.Windows.Forms.TabPage 'Overview'
    $overview.BackColor = $script:Theme.White

    $tree = New-Object System.Windows.Forms.TreeView
    $tree.Name = 'OverviewTree'
    $tree.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $tree.Dock = 'Fill'

    $btnOvRefresh = New-Object System.Windows.Forms.Button
    $btnOvRefresh.Name = 'OverviewRefreshButton'
    $btnOvRefresh.Text = 'REFRESH'
    $btnOvRefresh.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
    $btnOvRefresh.Size = New-Object System.Drawing.Size(120, 35)
    $btnOvRefresh.BackColor = $script:Theme.Primary
    $btnOvRefresh.ForeColor = $script:Theme.White
    $btnOvRefresh.FlatStyle = 'Flat'

    $ovPanel = New-Object System.Windows.Forms.TableLayoutPanel
    $ovPanel.Dock = 'Fill'
    $ovPanel.ColumnCount = 1
    $ovPanel.RowCount = 2
    $ovPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle 'Percent', 100))
    $ovPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'Percent', 100))
    $ovPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'AutoSize'))

    $ovPanel.Controls.Add($tree, 0, 0)
    $ovPanel.Controls.Add($btnOvRefresh, 0, 1)

    $overview.Controls.Add($ovPanel)
    $tabs.TabPages.Add($overview)

    # Basic Tab
    $basic = New-Object System.Windows.Forms.TabPage 'Basic'
    $basic.BackColor = $script:Theme.White

    $lblClass = New-Object System.Windows.Forms.Label
    $lblClass.Text = 'Class Name:'
    $lblClass.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $lblClass.AutoSize = $true

    $txtClass = New-Object System.Windows.Forms.TextBox
    $txtClass.Name = 'BasicClassName'
    $txtClass.Dock = 'Fill'
    $txtClass.Font = New-Object System.Drawing.Font('Segoe UI', 9)

    $lblStu = New-Object System.Windows.Forms.Label
    $lblStu.Text = 'Students (one per line):'
    $lblStu.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $lblStu.AutoSize = $true

    $txtStu = New-Object System.Windows.Forms.TextBox
    $txtStu.Name = 'BasicStudents'
    $txtStu.Dock = 'Fill'
    $txtStu.Multiline = $true
    $txtStu.ScrollBars = 'Vertical'
    $txtStu.Font = New-Object System.Drawing.Font('Segoe UI', 9)

    $btnCreate = New-Object System.Windows.Forms.Button
    $btnCreate.Name = 'CreateFoldersButton'
    $btnCreate.Text = 'Create Folders'
    $btnCreate.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
    $btnCreate.Size = New-Object System.Drawing.Size(150, 35)
    $btnCreate.BackColor = $script:Theme.Primary
    $btnCreate.ForeColor = $script:Theme.White
    $btnCreate.FlatStyle = 'Flat'

    $bl = New-Object System.Windows.Forms.TableLayoutPanel
    $bl.Dock = 'Fill'
    $bl.ColumnCount = 2
    $bl.RowCount = 3
    $bl.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('AutoSize')))
    $bl.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Percent', 100)))
    $bl.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('AutoSize')))
    $bl.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Percent', 100)))
    $bl.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('AutoSize')))

    $bl.Controls.Add($lblClass, 0, 0)
    $bl.Controls.Add($txtClass, 1, 0)
    $bl.Controls.Add($lblStu, 0, 1)
    $bl.Controls.Add($txtStu, 1, 1)
    $bl.Controls.Add($btnCreate, 1, 2)

    $basic.Controls.Add($bl)
    $tabs.TabPages.Add($basic)

    # Advanced Tab
    $advanced = New-Object System.Windows.Forms.TabPage 'Advanced'; 
    $advanced.BackColor = $script:Theme.White; 
    $advanced.AutoScroll = $true
    $tabs.TabPages.Add($advanced)

    $advLayout = New-Object System.Windows.Forms.TableLayoutPanel
    $advLayout.Dock = 'Fill'
    $advLayout.AutoSize = $true
    $advLayout.ColumnCount = 2
    $advLayout.RowCount = 3
    $advLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Percent',50)))
    $advLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Percent',50)))
    $advLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('AutoSize')))
    $advLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Percent',100)))
    $advLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('AutoSize')))
    $advanced.Controls.Add($advLayout)

    # Advanced Tab - Class Configuration Group (Row 0, Col 0) ------
    $groupConfig = New-Object System.Windows.Forms.GroupBox
    $groupConfig.Text    = "Class Configuration"
    $groupConfig.Font    = New-Object System.Drawing.Font('Segoe UI',9,[System.Drawing.FontStyle]::Bold)
    $groupConfig.Dock    = 'Fill'
    $groupConfig.Height = 150
    $groupConfig.Padding = New-Object System.Windows.Forms.Padding(10)
    $advLayout.Controls.Add($groupConfig,0,0)

    $layoutConfig = New-Object System.Windows.Forms.TableLayoutPanel
    $layoutConfig.Dock        = 'Fill'
    $layoutConfig.ColumnCount = 2
    $layoutConfig.RowCount    = 3
    $layoutConfig.ColumnStyles.Add( (New-Object System.Windows.Forms.ColumnStyle('AutoSize')) )
    $layoutConfig.ColumnStyles.Add( (New-Object System.Windows.Forms.ColumnStyle('Percent', 100)) )
    $layoutConfig.RowStyles.Add( (New-Object System.Windows.Forms.RowStyle('AutoSize')) )
    $layoutConfig.RowStyles.Add( (New-Object System.Windows.Forms.RowStyle('AutoSize')) )
    $layoutConfig.RowStyles.Add( (New-Object System.Windows.Forms.RowStyle('AutoSize')) )
    $groupConfig.Controls.Add($layoutConfig)

    $lblClassAdv = New-Object System.Windows.Forms.Label
    $lblClassAdv.Text = 'Class:'
    $lblClassAdv.Font = New-Object System.Drawing.Font('Segoe UI',9)
    $layoutConfig.Controls.Add($lblClassAdv,0,0)

    $cmbClass = New-Object System.Windows.Forms.ComboBox
    $cmbClass.Name = 'AdvClass'
    $cmbClass.DropDownStyle = 'DropDownList'
    $cmbClass.Dock = 'Fill'
    $cmbClass.Font = New-Object System.Drawing.Font('Segoe UI',9)
    $layoutConfig.Controls.Add($cmbClass,1,0)

    $lblTpl = New-Object System.Windows.Forms.Label
    $lblTpl.Text = 'Template:'
    $lblTpl.Font = New-Object System.Drawing.Font('Segoe UI',9)
    $layoutConfig.Controls.Add($lblTpl,0,1)

    $cmbTpl = New-Object System.Windows.Forms.ComboBox
    $cmbTpl.Name = 'AdvTemplate'
    $cmbTpl.DropDownStyle = 'DropDownList'
    $cmbTpl.Dock = 'Fill'
    $cmbTpl.Font = New-Object System.Drawing.Font('Segoe UI',9)
    $layoutConfig.Controls.Add($cmbTpl,1,1)

    $lblDs = New-Object System.Windows.Forms.Label
    $lblDs.Text = 'Datastore:'
    $lblDs.Font = New-Object System.Drawing.Font('Segoe UI',9)
    $layoutConfig.Controls.Add($lblDs,0,2)

    $cmbDs = New-Object System.Windows.Forms.ComboBox
    $cmbDs.Name = 'AdvDatastore'
    $cmbDs.DropDownStyle = 'DropDownList'
    $cmbDs.Dock = 'Fill'
    $cmbDs.Font = New-Object System.Drawing.Font('Segoe UI',9)
    $layoutConfig.Controls.Add($cmbDs,1,2)
    
    # Advanced Tab Class Network Group (Row 0, Col 1) ------
    $groupNet = New-Object System.Windows.Forms.GroupBox
    $groupNet.Text    = "Check networks to enable"
    $groupNet.Font    = New-Object System.Drawing.Font('Segoe UI',9,[System.Drawing.FontStyle]::Bold)
    $groupNet.Dock    = 'Fill'
    $groupNet.Padding = New-Object System.Windows.Forms.Padding(10)
    $advLayout.Controls.Add($groupNet,1,0)

    $panelNet = New-Object System.Windows.Forms.Panel
    $panelNet.Dock       = 'Fill'
    $panelNet.AutoScroll = $true
    $groupNet.Controls.Add($panelNet)

    $clbNet = New-Object System.Windows.Forms.CheckedListBox
    $clbNet.Name = 'AdvNetwork'
    $clbNet.CheckOnClick = $true
    $clbNet.Dock = 'Fill'
    $clbNet.Font = New-Object System.Drawing.Font('Segoe UI',9)
    $panelNet.Controls.Add($clbNet)

    # Advanced Tab - Class  Server Definitions Group (Row 2, Col 0–1) ------
    $groupServers = New-Object System.Windows.Forms.GroupBox
    $groupServers.Text    = "Server Definitions (VMs to deploy per student)"
    $groupServers.Font    = New-Object System.Drawing.Font('Segoe UI',9,[System.Drawing.FontStyle]::Bold)
    $groupServers.Dock    = 'Fill'
    $groupServers.AutoSize  = $true
    $groupServers.MinimumSize = New-Object System.Drawing.Size(0,150)
    $groupServers.Padding = New-Object System.Windows.Forms.Padding(10)
    $advLayout.SetColumnSpan($groupServers,2)
    $advLayout.Controls.Add($groupServers,2,0)

    $gridScrollPanel = New-Object System.Windows.Forms.Panel
    $gridScrollPanel.Dock       = 'Fill'
    $gridScrollPanel.AutoScroll = $true
    $groupServers.Controls.Add($gridScrollPanel)

    $dgv = New-Object System.Windows.Forms.DataGridView
    $dgv.Name = 'ServersGrid'
    $dgv.Dock = 'Fill'
    $dgv.AutoSizeColumnsMode = 'Fill'
    $dgv.RowHeadersVisible = $false
    $dgv.AllowUserToAddRows = $true
    $dgv.AllowUserToDeleteRows = $true
    $gridScrollPanel.Controls.Add($dgv)

    $col1 = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $col1.Name = 'ServerName'
    $col1.HeaderText = 'Server Name'
    $dgv.Columns.Add($col1)

    $col2 = New-Object System.Windows.Forms.DataGridViewComboBoxColumn
    $col2.Name = 'Template'
    $col2.HeaderText = 'Template'
    $dgv.Columns.Add($col2)

    $col3 = New-Object System.Windows.Forms.DataGridViewComboBoxColumn
    $col3.Name = 'Network'
    $col3.HeaderText = 'Network'
    $dgv.Columns.Add($col3)

    # Advanced Tab - Class Buttons (Row 2, Col 0-1) ------
    $btnPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $btnPanel.FlowDirection = 'LeftToRight'
    $btnPanel.AutoSize = $true
    $btnPanel.Controls.AddRange(@($btnAdvRefresh,$btnCreateVM,$btnDelete))
    $advLayout.SetColumnSpan($btnPanel,2)
    $advLayout.Controls.Add($btnPanel,3,0)

    $btnAdvRefresh = New-Object System.Windows.Forms.Button
    $btnAdvRefresh.Name = 'AdvRefresh'
    $btnAdvRefresh.Text = 'REFRESH'
    $btnAdvRefresh.Font = New-Object System.Drawing.Font('Segoe UI',10,[System.Drawing.FontStyle]::Bold)
    $btnAdvRefresh.Size = New-Object System.Drawing.Size(120,35)
    $btnAdvRefresh.BackColor = $script:Theme.Primary
    $btnAdvRefresh.ForeColor = $script:Theme.White
    $btnAdvRefresh.FlatStyle = 'Flat'
    $btnPanel.Controls.Add($btnAdvRefresh)

    $btnCreateVM = New-Object System.Windows.Forms.Button
    $btnCreateVM.Name = 'CreateVMsButton'
    $btnCreateVM.Text = 'CREATE VMS'
    $btnCreateVM.Font = New-Object System.Drawing.Font('Segoe UI',10,[System.Drawing.FontStyle]::Bold)
    $btnCreateVM.Size = New-Object System.Drawing.Size(150,35)
    $btnCreateVM.BackColor = $script:Theme.Primary
    $btnCreateVM.ForeColor = $script:Theme.White
    $btnCreateVM.FlatStyle = 'Flat'
    $btnPanel.Controls.Add($btnCreateVM)

    $btnDelete = New-Object System.Windows.Forms.Button
    $btnDelete.Name = 'DeleteClassButton'
    $btnDelete.Text = 'DELETE CLASS'
    $btnDelete.Font = New-Object System.Drawing.Font('Segoe UI',10,[System.Drawing.FontStyle]::Bold)
    $btnDelete.Size = New-Object System.Drawing.Size(150,35)
    $btnDelete.BackColor = $script:Theme.Error
    $btnDelete.ForeColor = $script:Theme.White
    $btnDelete.FlatStyle = 'Flat' 
    $btnPanel.Controls.Add($btnDelete)

    # Footer
    $footer = New-Object System.Windows.Forms.Panel
    $footer.Dock = 'Fill'
    $footer.Height = 30
    $footer.BackColor = $script:Theme.LightGray
    $root.Controls.Add($footer,0,2)

    $lblStatus = New-Object System.Windows.Forms.Label
    $lblStatus.Name = 'StatusLabel'
    $lblStatus.Text = 'No Connection'
    $lblStatus.Font = New-Object System.Drawing.Font('Segoe UI',9)
    $lblStatus.ForeColor = $script:Theme.PrimaryDark
    $lblStatus.AutoSize = $true
    $lblStatus.Location = New-Object System.Drawing.Point(10,5)
    $footer.Controls.Add($lblStatus)

    # Return references
    return @{
        Header = @{
            LastRefreshLabel = $lblLast
        }
        Tabs = @{
            Overview = @{
                RefreshButton = $btnOvRefresh
                TreeView      = $tree
            }
            Basic = @{
                ClassNameTextBox    = $txtClass
                StudentsTextBox     = $txtStu
                CreateFoldersButton = $btnCreate
            }
            Advanced = @{
                RefreshButton     = $btnAdvRefresh
                ClassComboBox    = $cmbClass
                TemplateComboBox = $cmbTpl
                DatastoreComboBox= $cmbDs
                NetworkListBox   = $clbNet
                ServersGrid      = $dgv
                CreateVMsButton  = $btnCreateVM
                DeleteClassButton= $btnDelete
            }
        }
        StatusLabel = $lblStatus
    }
    
    finally { $ContentPanel.ResumeLayout($true) }
}


function Update-ClassManagerWithData {
    <#
    .SYNOPSIS
        Updates the UI controls with the latest data (classes, templates, datastores, networks).
    .PARAMETER UiRefs
        Hashtable of UI control references.
    .PARAMETER Data
        Hashtable containing data to bind to the UI.
    #>
    
    [CmdletBinding()]
    param(
        $UiRefs,
        [hashtable]$Data
    )
    try {
        $conn = $script:Connection
        # Update timestamp
        $UiRefs.Header.LastRefreshLabel.Text = "Last refresh: $($Data.LastUpdated.ToString('HH:mm:ss'))"

        # Populate Overview tree
        $tree = $UiRefs.Tabs.Overview.TreeView
        $tree.Nodes.Clear()
        foreach ($cls in $Data.Classes) {
            $nCls = $tree.Nodes.Add($cls)
            if ($conn) {
                $students = Get-Folder -Server $conn -Name $cls -ErrorAction SilentlyContinue |
                            Get-Folder -ErrorAction SilentlyContinue |
                            Select-Object -ExpandProperty Name
            } else { $students = @() }
            foreach ($stu in $students) {
                $nStu = $nCls.Nodes.Add($stu)
                if ($conn) {
                    $folder = Get-Folder -Server $conn -Name $cls -ErrorAction SilentlyContinue |
                              Get-Folder -ErrorAction SilentlyContinue |
                              Where-Object { $_.Name -eq $stu }
                    $vms = if ($folder) { Get-VM -Server $conn -Location $folder -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name } else { @() }
                } else { $vms = @() }
                foreach ($vm in $vms) { $nStu.Nodes.Add($vm) }
            }
        }
        # Clear Basic inputs
        $UiRefs.Tabs.Basic.ClassNameTextBox.Text = ''
        $UiRefs.Tabs.Basic.StudentsTextBox.Text = ''

        # Populate Advanced Tab controls
        $combo = $UiRefs.Tabs.Advanced.ClassComboBox
        $combo.Items.Clear()
        $Data.Classes | ForEach-Object { $combo.Items.Add($_) }
        if ($combo.Items.Count -gt 0) { $combo.SelectedIndex = 0 }

        $combo = $UiRefs.Tabs.Advanced.TemplateComboBox
        $combo.Items.Clear()
        $Data.Templates | ForEach-Object { $combo.Items.Add($_) }
        if ($combo.Items.Count -gt 0) { $combo.SelectedIndex = 0 }

        $combo = $UiRefs.Tabs.Advanced.DatastoreComboBox
        $combo.Items.Clear()
        $Data.Datastores | ForEach-Object { $combo.Items.Add($_) }
        if ($combo.Items.Count -gt 0) { $combo.SelectedIndex = 0 }

        $clb = $UiRefs.Tabs.Advanced.NetworkListBox
        $clb.Items.Clear()
        $Data.Networks | ForEach-Object { $clb.Items.Add($_.Name) }
        if ($clb.Items.Count -gt 0) { $clb.SetItemChecked(0, $true) }

        $dgv = $UiRefs.Tabs.Advanced.ServersGrid
        $dgv.Rows.Clear()
        $dgv.Columns['Template'].DataSource = $Data.Templates
        $dgv.Columns['Network'].DataSource = $clb.CheckedItems

        # Optional default entries
        @('DC', 'FS', 'WEB') | ForEach-Object {
            $r = $dgv.Rows.Add()
            $dgv.Rows[$r].Cells['ServerName'].Value = $_
        }

        # Auto-update networks in grid
        $clb.Add_ItemCheck({ $dgv.Columns['Network'].DataSource = $clb.CheckedItems })

        # Update status
        $UiRefs.StatusLabel.Text = "Data loaded ($($Data.Classes.Count) classes, $($Data.Networks.Count) networks)"}
    catch {
        $UiRefs.StatusLabel.Text = "Error loading data: $($_.Exception.Message)"
        Write-Error "Failed to update UI: $_"
    }
}


function Wire-UIEvents {
    <#
    .SYNOPSIS
        Wires up all UI event handlers for the Classes management view.
    .PARAMETER UiRefs
        Hashtable of UI control references.
    .PARAMETER ContentPanel
        Panel hosting the UI.
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $UiRefs,
        [Parameter(Mandatory)] [System.Windows.Forms.Panel] $ContentPanel
    )
    $conn = $script:Connection

    # Overview Refresh
    $UiRefs.Tabs.Overview.RefreshButton.Add_Click({
        if ($conn) {  Show-ClassesView -ContentPanel $ContentPanel} 
    })

    # Basic Create Folders
    $UiRefs.Tabs.Basic.CreateFoldersButton.Add_Click({
        if (-not $conn) { return }
        $className = $UiRefs.Tabs.Basic.ClassNameTextBox.Text.Trim()
        
        if ([string]::IsNullOrWhiteSpace($className)) { 
            [System.Windows.Forms.MessageBox]::Show('Enter a class name first.','Input Required','OK','Information')
            return 
        }
        try {
            $students = $UiRefs.Tabs.Basic.StudentsTextBox.Text -split "`r`n" | Where-Object { $_ }
            $script:CurrentClassStudents = $students
            $classFolder = Get-Folder -Server $conn -Name $className -ErrorAction SilentlyContinue
            
            if (-not $classFolder) { 
                $classFolder = New-Folder -Server $conn -Name $className -Location (Get-Folder -Name 'vm') 
            }

            $existing = Get-Folder -Server $conn -Name $className | Get-Folder
            
            foreach ($student in $students) { 
                if (-not ($existing | Where-Object { $_.Name -eq $student })) { 
                    New-Folder -Server $conn -Name $student -Location $classFolder | Out-Null 
                }
            }
            
            [System.Windows.Forms.MessageBox]::Show("Folders created for $className",'Success','OK','Information')
            
            Show-ClassesView -ContentPanel $ContentPanel
        } catch { 
            [System.Windows.Forms.MessageBox]::Show("Failed: $($_.Exception.Message)",'Error','OK','Error') 
        }
    })

    # Advanced Refresh
    $UiRefs.Tabs.Advanced.RefreshButton.Add_Click({ 
        if ($conn) { Show-ClassesView -ContentPanel $ContentPanel } 
    })

    # Advanced Create VMs
    $UiRefs.Tabs.Advanced.CreateVMsButton.Add_Click({
        if (-not $conn) { return }
        $cls = $UiRefs.Tabs.Advanced.ClassComboBox.SelectedItem

        if (-not $cls) { 
            [System.Windows.Forms.MessageBox]::Show('Select a class first.','Input Required','OK','Information')
            return 
        }

        if ($UiRefs.Tabs.Advanced.NetworkListBox.CheckedItems.Count -eq 0) { 
            [System.Windows.Forms.MessageBox]::Show('Select at least one network.','Input Required','OK','Information')
            return 
        }

        $servers = @()
        foreach ($row in $UiRefs.Tabs.Advanced.ServersGrid.Rows) {
            if (-not $row.IsNewRow) {
                $servers += [PSCustomObject]@{
                    Name     = $row.Cells['ServerName'].Value
                    Template = $row.Cells['Template'].Value
                    Network  = $row.Cells['Network'].Value
                }
            }
        }

        $students = if ($script:CurrentClassStudents) { 
            $script:CurrentClassStudents 
        } else { 
            Get-Folder -Server $conn -Name $cls | Get-Folder | Select-Object -ExpandProperty Name 
        }

        $datastore = $UiRefs.Tabs.Advanced.DatastoreComboBox.SelectedItem

        try {
            $classFolder = Get-Folder -Server $conn -Name $cls -ErrorAction SilentlyContinue
            if (-not $classFolder) { 
                $classFolder = New-Folder -Server $conn -Name $cls -Location (Get-Folder -Name 'vm') 
            }

            foreach ($student in $students) {
                $studentFolder = Get-Folder -Server $conn -Name $cls | Get-Folder | Where-Object Name -eq $student
                if (-not $studentFolder) { 
                    $studentFolder = New-Folder -Server $conn -Name $student -Location $classFolder 
                }
                foreach ($s in $servers) {
                    New-VM -Server $conn `
                        -Name ("{0}_{1}" -f $s.Name, $student) `
                        -Template $s.Template `
                        -Datastore $datastore `
                        -NetworkName $s.Network `
                        -Location $studentFolder `
                        -ErrorAction Stop | Out-Null
                }
            }

            [System.Windows.Forms.MessageBox]::Show('VM creation started.','Success','OK','Information')
            Start-Job -ScriptBlock { Start-Sleep -Seconds 2; Show-ClassesView -ContentPanel $script:ClassesContentPanel } | Out-Null
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Failed: $($_.Exception.Message)",'Error','OK','Error')
        }
    })

    # Advanced Delete Class
    $UiRefs.Tabs.Advanced.DeleteClassButton.Add_Click({
        if (-not $conn) { return }

        $cls = $UiRefs.Tabs.Advanced.ClassComboBox.SelectedItem
        if (-not $cls) {
            [System.Windows.Forms.MessageBox]::Show('Select a class first.','Input Required','OK','Information')
            return
        }

        $confirm = [System.Windows.Forms.MessageBox]::Show(
            "Delete ALL VMs and folders for '$cls'?",
            'Confirm',
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )

        if ($confirm -ne [System.Windows.Forms.DialogResult]::Yes) { return }

        try {
            $students = Get-Folder -Server $conn -Name $cls | Get-Folder | Select-Object -ExpandProperty Name
            foreach ($student in $students) {
                $folder = Get-Folder -Server $conn -Name $cls | Get-Folder | Where-Object Name -eq $student
                Get-VM -Server $conn -Location $folder | ForEach-Object {
                    Remove-VM -Server $conn -VM $_ -DeletePermanently -Confirm:$false
                }
                Remove-Folder -Server $conn -Folder $folder -Confirm:$false
            }
            [System.Windows.Forms.MessageBox]::Show('Deletion started.','Success','OK','Information')
            Start-Job -ScriptBlock { Start-Sleep -Seconds 2; Show-ClassesView -ContentPanel $script:ClassesContentPanel } | Out-Null
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Failed: $($_.Exception.Message)",'Error','OK','Error')
        }
    })
}
