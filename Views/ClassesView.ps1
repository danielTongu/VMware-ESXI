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
    param([Parameter(Mandatory)] [System.Windows.Forms.Panel] $ContentPanel)

    $script:Refs = New-ClassManagerLayout -ContentPanel $ContentPanel
    [System.Windows.Forms.Application]::DoEvents() # Force immediate UI update

    $data = Get-ClassesData

    if ($data) {
        Update-ClassManagerWithData -Data $data
        Connect-UIEvents
    }
}


function Set-StatusMessage {
    <#
    .SYNOPSIS
        Sets the status message with appropriate color coding.
    #>

    param(
        [Parameter(Mandatory)]
        [string]$Message,
        [ValidateSet('Success','Warning','Error','Info')]
        [string]$Type = 'Info'
    )
    
    $script:Refs.StatusLabel.Text = $Message
    $script:Refs.StatusLabel.ForeColor = switch ($Type) {
        'Success' { $script:Theme.Success }
        'Warning' { $script:Theme.Warning }
        'Error'   { $script:Theme.Error }
        default   { $script:Theme.PrimaryDarker }
    }

    # Force immediate UI update
    [System.Windows.Forms.Application]::DoEvents()
}


function New-ClassManagerLayout {
    <#
    .SYNOPSIS
        Constructs the UI layout with header, tabs (Overview, Create, Delete), and footer.
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
    $root.AutoSize = $true
    $root.ColumnCount = 1
    $root.RowCount = 3
    $root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'AutoSize'))
    $root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'Percent',100))
    $root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'AutoSize'))
    $ContentPanel.Controls.Add($root)

    # =========== Header ========================================
    $header = New-Object System.Windows.Forms.Panel
    $header.Dock = 'Fill'
    $header.Height = 80
    $header.BackColor = $script:Theme.Primary
    $root.Controls.Add($header, 0, 0)

    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Text = 'CLASS MANAGEMENT'
    $lblTitle.Font = New-Object System.Drawing.Font('Segoe UI', 14, [System.Drawing.FontStyle]::Bold)
    $lblTitle.ForeColor = $script:Theme.White
    $lblTitle.Location = New-Object System.Drawing.Point(20, 15)
    $lblTitle.AutoSize = $true
    $header.Controls.Add($lblTitle)

    $lblLast = New-Object System.Windows.Forms.Label
    $lblLast.Name = 'LastRefreshLabel'
    $lblLast.Text = "Last refresh: $(Get-Date -Format 'HH:mm:ss tt')"
    $lblLast.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $lblLast.ForeColor = $script:Theme.White
    $lblLast.Location = New-Object System.Drawing.Point(20, 45)
    $lblLast.AutoSize = $true
    $header.Controls.Add($lblLast)



    # ========== Main TabControl =======================================
    $mainPanel = New-Object System.Windows.Forms.Panel
    $mainPanel.Dock = 'Fill'
    $mainPanel.AutoSize = $true
    $root.Controls.Add($mainPanel, 0, 1)

    $tabs = New-Object System.Windows.Forms.TabControl
    $tabs.Dock = 'Fill'
    $tabs.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
    $tabs.Padding = New-Object System.Drawing.Point(20, 10)
    $mainPanel.Controls.Add($tabs)


    #-------------------------------------------------------------------------------------------------------
    # Overview Tab -----------------------------------------------------------------------------------------
    #-------------------------------------------------------------------------------------------------------
    $overview = New-Object System.Windows.Forms.TabPage 'Overview'
    $overview.BackColor = $script:Theme.White
    $tabs.TabPages.Add($overview)

    # Overview primary layout
    $ovRoot = [System.Windows.Forms.TableLayoutPanel]::new()
    $ovRoot.Dock = 'Fill'
    $ovRoot.ColumnCount = 1
    $ovRoot.RowCount = 2 #ovPanel (100%), refresh button (auto)
    $ovRoot.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Percent,100)) # ovPanel
    $ovRoot.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::AutoSize)) # ovPanel
    $overview.Controls.Add($ovRoot)

    # Overview content layout
    $ovPanel = New-Object System.Windows.Forms.TableLayoutPanel
    $ovPanel.Padding = New-Object System.Windows.Forms.Padding(15)
    $ovPanel.Dock = 'Fill'
    $ovPanel.ColumnCount = 2
    $ovPanel.RowCount = 3 # tree (row 0-2), label (row0), options (row1), actions (row2)
    for ($i = 0; $i -lt $ovPanel.RowCount; $i++) {
        $ovPanel.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::AutoSize))
    }
    $ovPanel.RowStyles[2] = [System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Percent, 100)
    $ovRoot.Controls.Add($ovPanel, 0,0)
    
    # the refresh button 
    $btnOvRefresh = New-Object System.Windows.Forms.Button
    $btnOvRefresh.Name = 'OverviewRefreshButton'
    $btnOvRefresh.Text = 'REFRESH'
    $btnOvRefresh.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
    $btnOvRefresh.Size = New-Object System.Drawing.Size(120, 35)
    $btnOvRefresh.BackColor = $script:Theme.Primary
    $btnOvRefresh.ForeColor = $script:Theme.White
    $btnOvRefresh.FlatStyle = 'Flat'
    $ovRoot.Controls.Add($btnOvRefresh, 0, 1)

    #  The class tree 
    $tree = New-Object System.Windows.Forms.TreeView
    $tree.Name = 'OverviewTree'
    $tree.Font = New-Object System.Drawing.Font('Segoe UI', 11)
    $tree.Dock = 'Fill'
    $tree.Width = 250
    $tree.AutoSize = $true
    $ovPanel.Controls.Add($tree, 0, 0) # begin from row 0
    $ovPanel.SetRowSpan($tree,3) # end at row 2

    # Remove | Power options label
    $lblPowerOptions = New-Object System.Windows.Forms.Label
    $lblPowerOptions.Text = 'Remove | Power Options'
    $lblPowerOptions.Font = New-Object System.Drawing.Font('Segoe UI', 14, [System.Drawing.FontStyle]::Bold)
    $lblPowerOptions.ForeColor = $script:Theme.Primary
    $lblPowerOptions.AutoSize = $true
    $ovPanel.Controls.Add($lblPowerOptions,1,0)

    # ================= PARAMETERS GROUPBOX ================
    $groupParams = New-Object System.Windows.Forms.GroupBox
    $groupParams.Text = "Selection"
    $groupParams.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
    $groupParams.AutoSize = $true
    $groupParams.Padding = New-Object System.Windows.Forms.Padding(15)
    $ovPanel.Controls.Add($groupParams,1,1)

    $paramsLayout = New-Object System.Windows.Forms.TableLayoutPanel
    $paramsLayout.Dock = 'Fill'
    $paramsLayout.AutoSize = $true
    $paramsLayout.ColumnCount = 2
    $paramsLayout.RowCount = 2
    $groupParams.Controls.Add($paramsLayout)

    # Class Folder
    $lblClass = New-Object System.Windows.Forms.Label
    $lblClass.Text = 'Class Folder:'
    $lblClass.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $paramsLayout.Controls.Add($lblClass, 0, 0)
    
    $cmbClass = New-Object System.Windows.Forms.ComboBox
    $cmbClass.Name = 'ClassComboBox'
    $cmbClass.DropDownStyle = 'DropDownList'
    $cmbClass.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $cmbClass.Width = 200
    $paramsLayout.Controls.Add($cmbClass, 1, 0)

    # Host Name
    $lblHost = New-Object System.Windows.Forms.Label
    $lblHost.Text = 'Host Name:'
    $lblHost.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $paramsLayout.Controls.Add($lblHost, 0, 3)

    $cmbHost = New-Object System.Windows.Forms.ComboBox
    $cmbHost.Name = 'HostComboBox'
    $cmbHost.DropDownStyle = 'DropDownList'
    $cmbHost.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $cmbHost.Width = 200
    $paramsLayout.Controls.Add($cmbHost, 1, 3)

    # ============================================================================
    # ===== Flow Layout to organize all actions groups ===========================
    $ovGroupFlow = New-Object System.Windows.Forms.FlowLayoutPanel
    $ovGroupFlow.Dock = 'Fill'
    $ovGroupFlow.AutoSize = $true
    $ovGroupFlow.AutoScroll = $true
    $ovGroupFlow.FlowDirection = 'TopDown'
    $ovPanel.Controls.Add($ovGroupFlow, 1,2)
    
    # ================= Remove-CourseFolder (requires classFolder) =================
    $groupRemoveCourse = New-Object System.Windows.Forms.GroupBox
    $groupRemoveCourse.AutoSize = $true
    $groupRemoveCourse.Text = "Requires: Class Folder"
    $groupRemoveCourse.AutoSizeMode = 'GrowAndShrink' # Prevent text wrapping in the GroupBox title
    $groupRemoveCourse.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
    $groupRemoveCourse.Padding = New-Object System.Windows.Forms.Padding(12)
    $ovGroupFlow.Controls.Add($groupRemoveCourse)

    $layoutRemoveCourse = New-Object System.Windows.Forms.FlowLayoutPanel
    $layoutRemoveCourse.Dock = 'Fill'
    $layoutRemoveCourse.AutoSize = $true
    $layoutRemoveCourse.FlowDirection = 'TopDown'
    $layoutRemoveCourse.WrapContents = $true
    $groupRemoveCourse.Controls.Add($layoutRemoveCourse)
    
    $btnRemoveCourseFolderVMs = New-Object System.Windows.Forms.Button
    $btnRemoveCourseFolderVMs.AutoSize = $true
    $btnRemoveCourseFolderVMs.Dock = 'Fill'
    $btnRemoveCourseFolderVMs.Name = 'RemoveCourseFolderVMsButton'
    $btnRemoveCourseFolderVMs.Text = 'Remove Course Folder VMs'
    $btnRemoveCourseFolderVMs.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
    $btnRemoveCourseFolderVMs.Size = New-Object System.Drawing.Size(220, 35)
    $btnRemoveCourseFolderVMs.BackColor = $script:Theme.Primary
    $btnRemoveCourseFolderVMs.ForeColor = $script:Theme.White
    $btnRemoveCourseFolderVMs.FlatStyle = 'Flat'
    $layoutRemoveCourse.Controls.Add($btnRemoveCourseFolderVMs)

    # ================= PowerOff-ClassVMs (classFolder only) =================
    $groupPowerOffClass = New-Object System.Windows.Forms.GroupBox
    $groupPowerOffClass.AutoSize = $true
    $groupPowerOffClass.Text = "Requires: Class Folder"
    $groupPowerOffClass.AutoSizeMode = 'GrowAndShrink' # Prevent text wrapping in the GroupBox title
    $groupPowerOffClass.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
    $groupPowerOffClass.Padding = New-Object System.Windows.Forms.Padding(12)
    $ovGroupFlow.Controls.Add($groupPowerOffClass)

    $layoutPowerOffClass = New-Object System.Windows.Forms.FlowLayoutPanel
    $layoutPowerOffClass.Dock = 'Fill'
    $layoutPowerOffClass.AutoSize = $true
    $layoutPowerOffClass.FlowDirection = 'TopDown'
    $layoutPowerOffClass.WrapContents = $true
    $groupPowerOffClass.Controls.Add($layoutPowerOffClass)
    
    $btnPowerOffClassVMs = New-Object System.Windows.Forms.Button
    $btnPowerOffClassVMs.AutoSize = $true
    $btnPowerOffClassVMs.Dock = 'Fill'
    $btnPowerOffClassVMs.Name = 'PowerOffClassVMsButton'
    $btnPowerOffClassVMs.Text = 'Power Off Class VMs'
    $btnPowerOffClassVMs.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
    $btnPowerOffClassVMs.Size = New-Object System.Drawing.Size(220, 35)
    $btnPowerOffClassVMs.BackColor = $script:Theme.Primary
    $btnPowerOffClassVMs.ForeColor = $script:Theme.White
    $btnPowerOffClassVMs.FlatStyle = 'Flat'
    $layoutPowerOffClass.Controls.Add($btnPowerOffClassVMs)
    
    # ================= Remove-Host/PowerOff-SpecificClassVMs/PowerOn-SpecificClassVMs (all params) =================
    $groupHostOps = New-Object System.Windows.Forms.GroupBox
    $groupHostOps.AutoSize = $true
    $groupHostOps.Text = "Requires: All fields"
    $groupHostOps.AutoSizeMode = 'GrowAndShrink' # Prevent text wrapping in the GroupBox title
    $groupHostOps.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
    $groupHostOps.Padding = New-Object System.Windows.Forms.Padding(12)
    $ovGroupFlow.Controls.Add($groupHostOps)

    $hostOpsLayout = New-Object System.Windows.Forms.FlowLayoutPanel
    $hostOpsLayout.Dock = 'Fill'
    $hostOpsLayout.AutoSize = $true
    $hostOpsLayout.FlowDirection = 'TopDown'
    $hostOpsLayout.WrapContents = $true
    $groupHostOps.Controls.Add($hostOpsLayout)

    # Remove host button
    $btnRemoveHost = New-Object System.Windows.Forms.Button
    $btnRemoveHost.AutoSize = $true
    $btnRemoveHost.Dock = 'Fill'
    $btnRemoveHost.Name = 'RemoveHostButton'
    $btnRemoveHost.Text = 'Remove Host VMs'
    $btnRemoveHost.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
    $btnRemoveHost.Size = New-Object System.Drawing.Size(220, 35)
    $btnRemoveHost.BackColor = $script:Theme.Primary
    $btnRemoveHost.ForeColor = $script:Theme.White
    $btnRemoveHost.FlatStyle = 'Flat'
    $hostOpsLayout.Controls.Add($btnRemoveHost)

    # Power off specific VM button
    $btnPowerOffSpecificClassVMs = New-Object System.Windows.Forms.Button
    $btnPowerOffSpecificClassVMs.AutoSize = $true
    $btnPowerOffSpecificClassVMs.Dock = 'Fill'
    $btnPowerOffSpecificClassVMs.Name = 'PowerOffSpecificClassVMsButton'
    $btnPowerOffSpecificClassVMs.Text = 'Power Off Specific Class VMs'
    $btnPowerOffSpecificClassVMs.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
    $btnPowerOffSpecificClassVMs.Size = New-Object System.Drawing.Size(180, 35)
    $btnPowerOffSpecificClassVMs.BackColor = $script:Theme.Primary
    $btnPowerOffSpecificClassVMs.ForeColor = $script:Theme.White
    $btnPowerOffSpecificClassVMs.FlatStyle = 'Flat'
    $btnPowerOffSpecificClassVMs.Margin = New-Object System.Windows.Forms.Padding(5)
    $hostOpsLayout.Controls.Add($btnPowerOffSpecificClassVMs)

    # Power on specific VM button
    $btnPowerOnSpecificClassVMs = New-Object System.Windows.Forms.Button
    $btnPowerOnSpecificClassVMs.AutoSize = $true
    $btnPowerOnSpecificClassVMs.Dock = 'Fill'
    $btnPowerOnSpecificClassVMs.Name = 'PowerOnSpecificClassVMsButton'
    $btnPowerOnSpecificClassVMs.Text = 'Power On Specific Class VMs'
    $btnPowerOnSpecificClassVMs.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
    $btnPowerOnSpecificClassVMs.Size = New-Object System.Drawing.Size(180, 35)
    $btnPowerOnSpecificClassVMs.BackColor = $script:Theme.Primary
    $btnPowerOnSpecificClassVMs.ForeColor = $script:Theme.White
    $btnPowerOnSpecificClassVMs.FlatStyle = 'Flat'
    $btnPowerOnSpecificClassVMs.Margin = New-Object System.Windows.Forms.Padding(5)
    $hostOpsLayout.Controls.Add($btnPowerOnSpecificClassVMs)


    #-------------------------------------------------------------------------------------------------------
    # Create student VMs Tab -------------------------------------------------------------------------------
    #-------------------------------------------------------------------------------------------------------
    $creatorTab = New-Object System.Windows.Forms.TabPage 'Create'
    $creatorTab.BackColor = $script:Theme.White
    $tabs.TabPages.Add($creatorTab)

    # Main container with scrollable layout
    $creatorContainer = New-Object System.Windows.Forms.Panel
    $creatorContainer.Dock = 'Fill'
    $creatorContainer.AutoSize = $true
    $creatorContainer.AutoScroll = $true
    $creatorTab.Controls.Add($creatorContainer)

    # Layout panel for all controls
    $creatorLayout = New-Object System.Windows.Forms.TableLayoutPanel
    $creatorLayout.Dock = 'Fill'
    $creatorLayout.AutoSize = $true
    $creatorLayout.AutoScroll = $true
    $creatorLayout.Padding = New-Object System.Windows.Forms.Padding(15)
    $creatorLayout.ColumnCount = 3
    $creatorLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('AutoSize')))
    $creatorLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Percent', 100)))
    $creatorLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Percent', 100)))
    $creatorLayout.RowCount = 7
    $creatorContainer.Controls.Add($creatorLayout)

    # 0 - The header label
    $lblCreatorHeader = New-Object System.Windows.Forms.Label
    $lblCreatorHeader.Text = 'Create Student Virtual Machines'
    $lblCreatorHeader.Font = New-Object System.Drawing.Font('Segoe UI', 14, [System.Drawing.FontStyle]::Bold)
    $lblCreatorHeader.ForeColor = $script:Theme.Primary
    $lblCreatorHeader.AutoSize = $true
    $creatorLayout.Controls.Add($lblCreatorHeader, 0, 0)
    $creatorLayout.SetColumnSpan($lblCreatorHeader, 3)

    # 3 - Course folder label and text box
    $lblClassFolder = New-Object System.Windows.Forms.Label
    $lblClassFolder.Text = 'Class Folder:'
    $lblClassFolder.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $creatorLayout.Controls.Add($lblClassFolder, 0, 3)

    $txtClassFolder = New-Object System.Windows.Forms.TextBox
    $txtClassFolder.Name = 'ClassFolder'
    $txtClassFolder.Text = ''
    $txtClassFolder.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $txtClassFolder.Dock = 'Fill'
    $txtClassFolder.Width = 200
    $creatorLayout.Controls.Add($txtClassFolder, 1, 3)

    # 4 - Datastore label and dropdown
    $lblDataStore = New-Object System.Windows.Forms.Label
    $lblDataStore.Text = 'Datastore:'
    $lblDataStore.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $lblDataStore.AutoSize = $true
    $creatorLayout.Controls.Add($lblDataStore, 0, 4)

    $cmbDataStore = New-Object System.Windows.Forms.ComboBox
    $cmbDataStore.Name = 'DataStoreDropdown'
    $cmbDataStore.DropDownStyle = 'DropDownList'
    $cmbDataStore.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $cmbDataStore.Dock = 'Fill'
    $cmbDataStore.Width = 200
    $creatorLayout.Controls.Add($cmbDataStore, 1, 4)

    # 5 - Groupbox for server definitions
    $groupServers = New-Object System.Windows.Forms.GroupBox
    $groupServers.Text    = "Server Definitions (VMs to deploy per student)"
    $groupServers.Font    = New-Object System.Drawing.Font('Segoe UI',9,[System.Drawing.FontStyle]::Bold)
    $groupServers.Dock    = 'Fill'
    $groupServers.Name    = 'ServerDefinitionsGroup'
    $groupServers.AutoSize  = $true
    $groupServers.MinimumSize = New-Object System.Drawing.Size(0,150)
    $groupServers.Padding = New-Object System.Windows.Forms.Padding(10)
    $creatorLayout.SetColumnSpan($groupServers, 2)
    $creatorLayout.Controls.Add($groupServers, 0, 5)

    $groupServersLayout = New-Object System.Windows.Forms.TableLayoutPanel
    $groupServersLayout.Dock = 'Fill'
    $groupServersLayout.AutoSize = $true
    $groupServersLayout.ColumnCount = 2
    $groupServersLayout.RowCount = 4
    $groupServersLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('AutoSize'))) # Labels
    $groupServersLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Percent', 50))) # Text boxes or dropdowns or group boxes
    $groupServers.Controls.Add($groupServersLayout)

    # 5-1 - Server name label and textbox
    $lblServerName = New-Object System.Windows.Forms.Label
    $lblServerName.Text = 'Server Name:'
    $lblServerName.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $lblServerName.AutoSize = $true
    $groupServersLayout.Controls.Add($lblServerName, 0, 0)

    $txtServerName = New-Object System.Windows.Forms.TextBox
    $txtServerName.Name = 'ServerName'
    $txtServerName.Text = ''
    $txtServerName.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $txtServerName.Dock = 'Fill'
    $txtServerName.Width = 200
    $groupServersLayout.Controls.Add($txtServerName, 1, 0)

    # 5-2 - Template label and dropdown
    $lblTemplate = New-Object System.Windows.Forms.Label
    $lblTemplate.Text = 'Template:'
    $lblTemplate.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $lblTemplate.AutoSize = $true
    $groupServersLayout.Controls.Add($lblTemplate, 0, 1)

    $cmbTemplate = New-Object System.Windows.Forms.ComboBox
    $cmbTemplate.Name = 'ServerTemplate'
    $cmbTemplate.DropDownStyle = 'DropDownList'
    $cmbTemplate.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $cmbTemplate.Dock = 'Fill'
    $cmbTemplate.Width = 200
    $groupServersLayout.Controls.Add($cmbTemplate, 1, 1)
    
    # 5-3 - Customization label and dropdown
    $lblCustomization = New-Object System.Windows.Forms.Label
    $lblCustomization.Text = 'Customization Script:'
    $lblCustomization.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $lblCustomization.AutoSize = $true
    $groupServersLayout.Controls.Add($lblCustomization, 0, 2)

    $cmbCustomization = New-Object System.Windows.Forms.ComboBox
    $cmbCustomization.Name = 'ServerCustomization'
    $cmbCustomization.DropDownStyle = 'DropDownList'
    $cmbCustomization.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $cmbCustomization.Dock = 'Fill'
    $cmbCustomization.Width = 200
    $cmbCustomization.Items.Add('None') # Default option
    $groupServersLayout.Controls.Add($cmbCustomization, 1, 2)

    # 5-4 - Adapters label and CheckedListBox
    $lblAdapters = New-Object System.Windows.Forms.Label
    $lblAdapters.Dock = 'Fill'
    $lblAdapters.Text = 'Network Adapters:'
    $lblAdapters.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $lblAdapters.AutoSize = $true
    $groupServersLayout.Controls.Add($lblAdapters, 0, 3)

    $clbAdapters = New-Object System.Windows.Forms.CheckedListBox
    $clbAdapters.Name = 'ServerAdapters'
    $clbAdapters.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $clbAdapters.Dock = 'Fill'
    $clbAdapters.Height = 100
    $clbAdapters.HorizontalScrollbar = $true
    $clbAdapters.CheckOnClick = $true
    $groupServersLayout.Controls.Add($clbAdapters, 1, 3)
    
    # 6 - Groupbox for student list textbox and import button
    $groupStu = New-Object System.Windows.Forms.GroupBox
    $groupStu.Text    = "Enter or import student names"
    $groupStu.Font    = New-Object System.Drawing.Font('Segoe UI',9,[System.Drawing.FontStyle]::Bold)
    $groupStu.Dock    = 'Fill'
    $groupStu.Padding = New-Object System.Windows.Forms.Padding(10)
    $creatorLayout.SetRowSpan($groupStu, 5)
    $creatorLayout.Controls.Add($groupStu, 2, 1)

    $groupStuLayout = New-Object System.Windows.Forms.TableLayoutPanel
    $groupStuLayout.Dock = 'Fill'
    $groupStuLayout.ColumnCount = 1
    $groupStuLayout.RowCount = 2
    $groupStuLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Percent', 100)))
    $groupStuLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Percent', 100))) # Textbox row
    $groupStuLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('AutoSize'))) # Import button row
    $groupStu.Controls.Add($groupStuLayout)

    # 6-1 - Textbox for student names
    $txtStu = New-Object System.Windows.Forms.TextBox
    $txtStu.Name = 'StudentNames'
    $txtStu.Dock = 'Fill'
    $txtStu.Multiline = $true
    $txtStu.ScrollBars = 'Vertical'
    $txtStu.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $groupStuLayout.Controls.Add($txtStu, 0, 0)

    # 6-2 - Import button for student names
    $btnImport = New-Object System.Windows.Forms.Button
    $btnImport.Text = 'IMPORT'
    $btnImport.Size = New-Object System.Drawing.Size(150, 35)
    $btnImport.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
    $btnImport.BackColor = $script:Theme.Primary
    $btnImport.ForeColor = $script:Theme.White
    $btnImport.FlatStyle = 'Flat'
    $btnImport.Dock = 'Right'
    $groupStuLayout.Controls.Add($btnImport, 0, 1)

    # 7 - Button to create VMs
    $btnCreateVMsPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $btnCreateVMsPanel.Dock = 'Fill'
    $btnCreateVMsPanel.FlowDirection = 'RightToLeft'
    $btnCreateVMsPanel.AutoSize = $true
    $btnCreateVMsPanel.WrapContents = $false
    $creatorLayout.Controls.Add($btnCreateVMsPanel, 0, 6)
    $creatorLayout.SetColumnSpan($btnCreateVMsPanel, 3)

    $btnCreateVMs = New-Object System.Windows.Forms.Button
    $btnCreateVMs.Name = 'CreateVMsButton'
    $btnCreateVMs.Text = 'CREATE VMS'
    $btnCreateVMs.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
    $btnCreateVMs.Size = New-Object System.Drawing.Size(150, 35)
    $btnCreateVMs.BackColor = $script:Theme.Primary
    $btnCreateVMs.ForeColor = $script:Theme.White
    $btnCreateVMs.FlatStyle = 'Flat'
    $btnCreateVMsPanel.Controls.Add($btnCreateVMs)
    

    # ========== Footer ========================================
    $footer = New-Object System.Windows.Forms.Panel
    $footer.Dock = 'Fill'
    $footer.Height = 30
    $footer.BackColor = $script:Theme.LightGray
    $root.Controls.Add($footer,0,2)

    $lblStatus = New-Object System.Windows.Forms.Label
    $lblStatus.Name = 'StatusLabel'
    $lblStatus.Text = 'No Connection'
    $lblStatus.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
    $lblStatus.ForeColor = $script:Theme.PrimaryDark
    $lblStatus.AutoSize = $true
    $lblStatus.Location = New-Object System.Drawing.Point(10,5)
    $footer.Controls.Add($lblStatus)

    # Return references
    return @{
        ContentPanel = $ContentPanel
        Header = @{ LastRefreshLabel = $lblLast }
        Tabs = @{
            Overview = @{
                RefreshButton = $btnOvRefresh
                TreeView      = $tree

                # Dropdowns (parameters)
                ClassComboBox                    = $cmbClass
                HostComboBox                     = $cmbHost

                # Buttons (requires all parameters)
                RemoveHostButton                 = $btnRemoveHost
                PowerOffSpecificClassVMsButton   = $btnPowerOffSpecificClassVMs
                PowerOnSpecificClassVMsButton    = $btnPowerOnSpecificClassVMs

                # Requires Class Folder only
                RemoveCourseFolderVMsButton      = $btnRemoveCourseFolderVMs
                PowerOffClassVMsButton           = $btnPowerOffClassVMs
            }
            Create = @{
                ClassFolder          = $txtClassFolder
                DataStoreDropdown    = $cmbDataStore
                ServerName           = $txtServerName
                ServerTemplate       = $cmbTemplate
                ServerCustomization  = $cmbCustomization
                ServerAdapters       = $clbAdapters
                StudentNames         = $txtStu
                ImportButton         = $btnImport
                CreateVMsButton      = $btnCreateVMs
            }
        }
        StatusLabel = $lblStatus
    }
    
}


function Get-ClassesData {
    <#
    .SYNOPSIS
        Retrieves all classes data
    .OUTPUTS
        [hashtable] - Complete dataset
    #>

    [CmdletBinding()] 

    $Data = @{}
    $conn = $script:Connection

    if (-not $conn) {
        Set-StatusMessage 'No connection to vCenter.' -Type 'Error'
    } else {
        # Sequential data collection for compatibility
        # Collect templates
        Set-StatusMessage -Message "Collecting templates..." -Type 'Info'
        $templates = Get-Template -Server $conn -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name

        # Get datastores
        Set-StatusMessage -Message "Retrieving datastores..." -Type 'Info'
        $datastores = Get-Datastore -Server $conn -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name

        # Get networks
        Set-StatusMessage -Message "Retrieving networks..." -Type 'Info'
        $networks = Get-VirtualPortGroup -Server $conn -ErrorAction SilentlyContinue | Select-Object Name, VirtualSwitch, VLanId

        # Get datacenter
        Set-StatusMessage -Message "Locating Datacenter..." -Type 'Info'
        $dc = Get-Datacenter -Server $conn -Name 'Datacenter'

        # Get VM folder
        Set-StatusMessage -Message "Finding 'vm' folder in Datacenter..." -Type 'Info'
        $vmFolder = Get-Folder -Server $conn -Name 'vm' -Location $dc

        # Get Classes root folder
        Set-StatusMessage -Message "Locating 'Classes' folder within VM folder..." -Type 'Info'
        $classesRoot = Get-Folder -Server $conn -Name 'Classes' -Location $vmFolder

        # Get class folders
        Set-StatusMessage -Message "Gathering class folders inside 'Classes'..." -Type 'Info'
        $classes = Get-Folder -Server $conn -Location $classesRoot -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -notmatch '_' } |
                Select-Object -ExpandProperty Name

        # Get student VM folders and VM names
        Set-StatusMessage -Message "Enumerating VMs inside class folders..." -Type 'Info'
        $classSubFolders = Get-Folder -Server $conn -Location $classesRoot -ErrorAction SilentlyContinue
        $vmNames = @()
        foreach ($classFolder in $classSubFolders) {
            $studentFolders = Get-Folder -Server $conn -Location $classFolder -ErrorAction SilentlyContinue
            foreach ($studentFolder in $studentFolders) {
                $vms = Get-VM -Server $conn -Location $studentFolder -ErrorAction SilentlyContinue
                if ($vms) {
                    $vmNames += $vms.Name
                }
            }
        }

        # Fill in the discovered data
        $Data.Templates   = $templates
        $Data.Datastores  = $datastores
        $Data.Networks    = $networks
        $Data.Classes     = $classes
        $Data.Servers     = $vmNames | Sort-Object -Unique
        $Data.LastUpdated = Get-Date

        return $Data
    }
}


function Update-ClassManagerWithData {
    <#
    .SYNOPSIS
        Updates the UI controls with the latest data.
    .PARAMETER Data
        Hashtable containing data to bind to the UI.
    #>
    
    [CmdletBinding()]
    param([hashtable]$Data)

    if (-not $Data) {
        Write-Error "Invalid parameter passed to Update-ClassManagerWithData"
        return
    }
    # Ensure we have a valid connection
    $conn = $script:Connection

    # Update timestamp
    $script:Refs.Header.LastRefreshLabel.Text = "Last refresh: $($Data.LastUpdated.ToString('HH:mm:ss tt'))"

    # Update Overview tab - Build class tree structure
    $tree = $script:Refs.Tabs.Overview.TreeView
    $tree.Nodes.Clear()
    
    if ($Data.Classes) {
        # Add root node for classes
        $tree.Nodes.Add("Classes") | Out-Null
        $tree.Nodes[0].Expand()
        # Add each class as a child node
        foreach ($cls in $Data.Classes) {
            # Add class name as top-level node
            $nCls = $tree.Nodes.Add($cls)

            # Retrieve class folder
            $classFolder = Get-Folder -Server $conn -Name $cls -Location $classesRoot -ErrorAction SilentlyContinue

            # Retrieve class subfolders
            $students    = if ($classFolder) {
                Get-Folder -Server $conn -Location $classFolder -ErrorAction SilentlyContinue |
                Select-Object -ExpandProperty Name
            } else { @() }

            foreach ($stu in $students) {
                # Add students as child nodes
                $nStu = $nCls.Nodes.Add($stu)

                # Retrieve student folder
                $studentFolder = Get-Folder -Server $conn -Location $classFolder -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq $stu }


                # Get VM object
                $vms = if ($studentFolder) {
                    Get-VM -Server $conn -Location $studentFolder -ErrorAction SilentlyContinue
                } else { @() }

                foreach ($vm in $vms) {
                    $vmNode      = New-Object System.Windows.Forms.TreeNode
                    $vmNode.Text = $vm.Name

                    if ($vm.PowerState -eq 'PoweredOn') {
                        $vmNode.ForeColor = [System.Drawing.Color]::Green
                    }

                    $nStu.Nodes.Add($vmNode)
                }


                <#
                # Retrieve VM names
                $vms = if ($studentFolder) {
                    Get-VM -Server $conn -Location $studentFolder -ErrorAction SilentlyContinue |
                    Select-Object -ExpandProperty Name
                } else { @() }

                foreach ($vm in $vms) {
                    # Add VMs as child nodes
                    $nStu.Nodes.Add($vm)
                }

                #>
            }
        }
    } else {
        $tree.Nodes.Add("No classes found") | Out-Null
    }

    # Update Create tab dropdowns
    $cmbTemplate = $script:Refs.Tabs.Create.ServerTemplate
    $cmbTemplate.Items.Clear()
    if ($Data.Templates) {
        $cmbTemplate.Items.AddRange($Data.Templates)
        if ($cmbTemplate.Items.Count -gt 0) { $cmbTemplate.SelectedIndex = 0 }
    }

    $cmbDataStore = $script:Refs.Tabs.Create.DataStoreDropdown
    $cmbDataStore.Items.Clear()
    if ($Data.Datastores) {
        $cmbDataStore.Items.AddRange($Data.Datastores)
        if ($cmbDataStore.Items.Count -gt 0) { $cmbDataStore.SelectedIndex = 0 }
    }

    $clbAdapters = $script:Refs.Tabs.Create.ServerAdapters
    $clbAdapters.Items.Clear()
    if ($Data.Networks) {
        foreach ($network in $Data.Networks) {
            $displayText = "$($network.Name) (vSwitch: $($network.VirtualSwitch), VLAN: $($network.VLanId))"
            $clbAdapters.Items.Add($displayText, $false) | Out-Null
        }
    }

    # Update Overview tab dropdowns
    $cmbClass = $script:Refs.Tabs.Overview.ClassComboBox
    $cmbClass.Items.Clear()
    if ($Data.Classes) {
        $cmbClass.Items.AddRange($Data.Classes)
        if ($cmbClass.Items.Count -gt 0) { 
            $cmbClass.SelectedIndex = 0 
        }
    }
    

    if ($script:Refs.Tabs.Overview.HostComboBox) {
        $script:Refs.Tabs.Overview.HostComboBox.Items.Clear()
        if ($Data.Servers) {
            $script:Refs.Tabs.Overview.HostComboBox.Items.AddRange(@($Data.Servers))
            if ($script:Refs.Tabs.Overview.HostComboBox.Items.Count -gt 0) { 
                $script:Refs.Tabs.Overview.HostComboBox.SelectedIndex = 0 
            }
        }
    }

    # Set status message
    Set-StatusMessage -Message "Ready" -Type 'Success'
}


function Connect-UIEvents {
    <#
    .SYNOPSIS
        Wires up event handlers for all UI controls
    #>

    [CmdletBinding()]param()

    # Overview Tab Events
    $script:Refs.Tabs.Overview.RefreshButton.Add_Click({
        . $PSScriptRoot\ClassesView.ps1
        Show-ClassesView -ContentPanel $script:Refs.ContentPanel
        Set-StatusMessage -Message "Overview refreshed" -Type 'Success'
    })

    #  ----------------------  Create Tab Events  ----------------------

    # Gather all the needed GUI components (required for Scope issues, approved by Dr. White)
    $script:className     = $script:Refs.Tabs.Create.ClassFolder                     # Class Name
    $script:textBox       = $script:Refs.Tabs.Create.StudentNames                    # Student Names
    $script:dataStore     = $script:Refs.Tabs.Create.DataStoreDropdown               # DataStore
    $script:serverName    = $script:Refs.Tabs.Create.ServerName                      # Server Name
    $script:template      = $script:Refs.Tabs.Create.ServerTemplate                  # Template
    $script:customization = $script:Refs.Tabs.Create.ServerCustomization             # Customization   
    $script:adapters      = $script:Refs.Tabs.Create.ServerAdapters                  # Adapters

    # Needed in Overview tab (Changed from Remove | Power tab)
    $script:classFolder     = $script:Refs.Tabs.Overview.ClassComboBox
    $script:hostName        = $script:Refs.Tabs.Overview.HostComboBox

    # CREATE TAB IMPORT BUTTON
    $script:Refs.Tabs.Create.ImportButton.Add_Click({

        # create an open file dialog box object from Windows Forms  
        $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
        # set the filter to only accept TXT files
        $openFileDialog.Filter = "Text files (*.txt)|*.txt"
        #set the title
        $openFileDialog.Title = "Select a TXT File"

        # open the file dialog and wait for user input
        # check if the user's actions resulted in "OK" being returned (user would've selected a file and pressed open)
        if ($openFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            # save the file path in a local variable
            $filePath = $openFileDialog.FileName
            # print statement for now
            Write-Host "You selected: $filePath"
            
            # check if the file path doesn't have an extension equal to the .txt extension
            if ([System.IO.Path]::GetExtension($filePath) -ne ".txt") {
                # display a popup to the user of the error
                [System.Windows.Forms.MessageBox]::Show(
                "Please select a valid .txt file.", # message
                "Invalid File Type", # title
                [System.Windows.Forms.MessageBoxButtons]::OK, # buttons
                [System.Windows.Forms.MessageBoxIcon]::Warning # icon
                )
                # exit early to avoid proceeding with the rest of the code
                return
            }

            # now read the content of the file into a variable (one student per line)
            $studentNames = Get-Content $filePath

            # Check if StudentsTextBox is valid before trying to update it
            if ($null -eq $script:textBox) {
                [System.Windows.Forms.MessageBox]::Show(
                    "Error: StudentsTextBox is not initialized!", # message
                    "Initialization Error",   # title
                    [System.Windows.Forms.MessageBoxButtons]::OK, # buttons
                    [System.Windows.Forms.MessageBoxIcon]::Error # icon
                )
                # exit early to avoid proceeding with the rest of the code
                return
            }


            # populate the text box with the newly acquired student names (one per line)
            $script:textBox.Text = ($studentNames -join "`r`n")

            # display a popup to the user notify the student that the names were imported correctly
            [System.Windows.Forms.MessageBox]::Show(
                "Student names imported successfully.", # message
                "Import Success",   # title
                [System.Windows.Forms.MessageBoxButtons]::OK, # buttons
                [System.Windows.Forms.MessageBoxIcon]::Information # icon
            )


        # if this point was reached then the user either closed the dialog or pressed cancel meaning the result wasn't "OK"
        } else {
            [System.Windows.Forms.MessageBox]::Show(
                "No file was selected.", # message
                "No File Selected",   # title
                [System.Windows.Forms.MessageBoxButtons]::OK, # buttons
                [System.Windows.Forms.MessageBoxIcon]::Information # icon
            )
        }
    })    


    # CREATE TAB VMS BUTTON
    $script:Refs.Tabs.Create.CreateVMsButton.Add_Click({
        
        # Needed for Set-StatusMessage function
        . $PSScriptRoot\ClassesView.ps1

        # --------------- Grab the actual user input ---------------
        # ClassName
        $className = $script:className.Text.Trim()
        # StudentNames
        $students = $script:textBox.Text
        $studentArray = $students -split "`r?`n" # store each line in an array
        # Datastore
        $datastore = $script:dataStore.SelectedItem
        # ServerName
        $serverName = $script:serverName.Text.Trim()
        # Template
        $templateName = $script:template.SelectedItem
        # Customization
        $customizationSelection = $script:customization.SelectedItem
        if ($customizationSelection -eq 'None') {
            $customization = $null
        } else {
            $customization = $customizationSelection
        }
        # Adapters
        $adapters = $script:adapters.CheckedItems
        $selectedAdapters = @()
        ForEach($item in $adapters) {
            $selectedAdapters += $item # store each checked box in an array
        }
        $trimmedAdapters = $selectedAdapters | ForEach-Object { $_ -replace '\s*\(.*\)$', '' }
        
        # --------------- Try catch block used to validate inputs ---------------
        try {
            
            # Class Name
            if ([string]::IsNullOrWhiteSpace($className)) {
                throw "Class folder name cannot be empty"
            }

            # Student Names
            if ([string]::IsNullOrWhiteSpace($students)) {
                throw "Student names cannot be empty"
            }
            
            # Datastore
            if (-not $datastore) {
                throw "Please select a datastore"
            }

            # Server Name
            if ([string]::IsNullOrWhiteSpace($serverName)) {
                throw "Server name cannot be empty"
            }
            
            # Template
            if (-not $template) {
                throw "Please select a template"
            }

            # Customization
            if (-not $customization) {
                "Please select a customization"
            }
            
            # Adapters
            if ($trimmedAdapters.Count -eq 0) {
                throw "Please select at least one network adapter"
            }
            
            # --------------- Create course info object ---------------
            # Start with ServerInfo which will be placed within the CourseInfo Object
            $serverInfo = @{
                serverName = $serverName
                template = $templateName
                customization = $customization
                adapters = $trimmedAdapters
            }
            
            # Now store values into the CourseInfo Object
            $courseInfo = [PSCustomObject]@{
                classFolder = $className    # Name of the Class
                students = $studentArray    # Array of all the Students needing a folder
                dataStore = $datastore      # Name of the DataStore
                servers = @($serverInfo)    # Info regarding the Server
            }

            # --------------- Call the VM creation function ---------------
            New-CourseVMs -courseInfo $courseInfo 
            Set-StatusMessage -Message "Successfully created VMs for class $className" -Type 'Success'
            
        } catch {
            Set-StatusMessage -Message "Error creating VMs: $_" -Type 'Error'
        }
    })


    # Overview (Remove/Power Options) Events
    $script:Refs.Tabs.Overview.RemoveCourseFolderVMsButton.Add_Click({
        # Needed for Set-StatusMessage function
        . $PSScriptRoot\ClassesView.ps1

        try {
            $classFolder = $script:classFolder.SelectedItem
            
            if (-not $classFolder) {
                throw "Please select a class folder"
            }
            
            Remove-CourseFolder -classFolder $classFolder
            Show-ClassesView -ContentPanel $script:Refs.ContentPanel # Refresh page
            Set-StatusMessage -Message "Successfully removed $classFolder" -Type 'Success'
            
        } catch {
            Set-StatusMessage -Message "Error removing $classFolder" -Type 'Error'
        }
    })

    $script:Refs.Tabs.Overview.PowerOffClassVMsButton.Add_Click({
        # Needed for Set-StatusMessage function
        . $PSScriptRoot\ClassesView.ps1

        try {
            $classFolder = $script:classFolder.SelectedItem
            
            if (-not $classFolder) {
                throw "Please select a class folder"
            }
            
            Stop-ClassVMs -classFolder $classFolder
            Show-ClassesView -ContentPanel $script:Refs.ContentPanel # Refresh page
            Set-StatusMessage -Message "Successfully powered off VMs for class $classFolder" -Type 'Success'
            
        } catch {
            Set-StatusMessage -Message "Error powering off VMs: $_" -Type 'Error'
        }
    })

    $script:Refs.Tabs.Overview.RemoveHostButton.Add_Click({
        # Needed for Set-StatusMessage function
        . $PSScriptRoot\ClassesView.ps1

        try {
            $classFolder = $script:classFolder.SelectedItem
            $hostName    = $script:hostName.SelectedItem
            
            if (-not $classFolder) {
                throw "Please select a class folder"
            }
            
            if (-not $hostName) {
                throw "Please select a server"
            }

            Remove-Host -classFolder $classFolder -hostName $hostName
            Show-ClassesView -ContentPanel $script:Refs.ContentPanel # Refresh page
            Set-StatusMessage -Message "Successfully removed host $hostName for class $classFolder" -Type 'Success'
            
        } catch {
            Set-StatusMessage -Message "Error removing host: $_" -Type 'Error'
        }
    })

    $script:Refs.Tabs.Overview.PowerOffSpecificClassVMsButton.Add_Click({
        # Needed for Set-StatusMessage function
        . $PSScriptRoot\ClassesView.ps1

        try {
            $classFolder = $script:classFolder.SelectedItem
            $hostName    = $script:hostName.SelectedItem
            
            if (-not $classFolder) {
                throw "Please select a class folder"
            }
            
            if (-not $hostName) {
                throw "Please select a server"
            }
            
            Stop-SpecificClassVMs -classFolder $classFolder -hostName $hostName
            Show-ClassesView -ContentPanel $script:Refs.ContentPanel # Refresh page
            Set-StatusMessage -Message "Successfully powered off $hostName for class $classFolder" -Type 'Success'
            
        } catch {
            Set-StatusMessage -Message "Error powering off VMs: $_" -Type 'Error'
        }
    })

    $script:Refs.Tabs.Overview.PowerOnSpecificClassVMsButton.Add_Click({
        # Needed for Set-StatusMessage function
        . $PSScriptRoot\ClassesView.ps1

        try {
            $classFolder = $script:classFolder.SelectedItem
            $hostName    = $script:hostName.SelectedItem
            
            if (-not $classFolder) {
                throw "Please select a class folder"
            }
            
            if (-not $serverName) {
                throw "Please select a server"
            }
            
            Start-SpecificClassVMs -classFolder $classFolder -hostName $hostName
            Show-ClassesView -ContentPanel $script:Refs.ContentPanel # Refresh page
            Set-StatusMessage -Message "Successfully powered on $hostName for class $classFolder" -Type 'Success'
        } catch {
            Set-StatusMessage -Message "Error powering on VMs: $_" -Type 'Error'
        }
    })
}


# ----------- Functions for VM Management ----------------------------------------


function Remove-CourseFolder {
    <#
    .SYNOPSIS
        Deletes all student folders and VMs for a course.
    .PARAMETER classFolder
        The name of the class folder.
    #>
    param (
        [string]$classFolder
    )

    if (Get-Folder $classFolder -ErrorAction Ignore) {
        # Loop through for the number of students in the class
        Remove-VMs $classFolder
    }
    else {
        #Write-Host 'Bad class folder'
        Set-StatusMessage -Message "Bad class folder" -Type 'Error'
    }
}

function Remove-Host {
    <#
    .SYNOPSIS
        Removes a host VM from student folders
    .PARAMETER classFolder
        The folder containing the class VMs.
    .PARAMETER hostName
        The name of the host VM to remove.
    #>  

    param(
        [string]$classFolder,
        [string]$hostName
    )
    BEGIN{}
    PROCESS{
        try {
            # Get the Classes folder path
            $dc          = Get-Datacenter -Server $conn -Name 'Datacenter' -ErrorAction Stop
            $vmFolder    = Get-Folder -Server $conn -Name 'vm' -Location $dc -ErrorAction Stop
            $classesRoot = Get-Folder -Server $conn -Name 'Classes' -Location $vmFolder -ErrorAction Stop
            $classPath   = Get-Folder -Server $conn -Name $classFolder -Location $classesRoot -ErrorAction Stop

            # Get student folder names
            $studentFolders = Get-Folder -Server $conn -Location $classPath -ErrorAction Stop

            # Loop through for the number of students in the class
            foreach ($student in $studentFolders) {

                $MyVM = Get-VM -Location $student -Name $hostName -ErrorAction SilentlyContinue
                if ($MyVM -and $MyVM.PowerState -eq "PoweredOn") {
                    Stop-VM -VM $MyVM -Confirm:$false
                }

                Remove-VM -DeletePermanently -VM $MyVM -Confirm:$false

                #Set-StatusMessage -Message "Removed VM $hostName from $($student.Name)" -Type 'Success'
            }
        } catch {
            Set-StatusMessage -Message "Failed to remove host VMs: $_" -Type 'Error'
        }

    }
    END{}
}

function Stop-ClassVMs {
    <#
    .SYNOPSIS
        Powers off all VMs in a specified class folder.
    .PARAMETER classFolder
        The folder containing the class VMs to power off.
    #>
    
    param (
        [string]$classFolder
    )
    try {
        # Get the Classes folder path
        $dc          = Get-Datacenter -Server $conn -Name 'Datacenter' -ErrorAction Stop
        $vmFolder    = Get-Folder -Server $conn -Name 'vm' -Location $dc -ErrorAction Stop
        $classesRoot = Get-Folder -Server $conn -Name 'Classes' -Location $vmFolder -ErrorAction Stop
        $classPath   = Get-Folder -Server $conn -Name $classFolder -Location $classesRoot -ErrorAction Stop

        # Get student folder names
        $studentFolders = Get-Folder -Server $conn -Location $classPath -ErrorAction Stop

        $MyVMs = Get-VM -Location $studentFolders | Sort-Object -Property Folder
        foreach ($MyVM in $MyVMs) {
            if ($MyVM.PowerState -eq "PoweredOn") {
                # Write-Host "Stopping " $MyVM.Folder   $MyVM.Name
                Stop-VM -VM $MyVM -Confirm:$false
            }
        }

        # Set-StatusMessage -Message "Stopped VMs from '$classFolder'" -Type 'Success'
    } catch {
        Set-StatusMessage -Message "Failed to stop VMs in '$classFolder'" -Type 'Error'
    }
}

function Stop-SpecificClassVMs {
    <#
    .SYNOPSIS
        Powers off specific VMs in a class folder.
    .PARAMETER classFolder
        The folder containing the class VMs.
    .PARAMETER serverName
        The name of the server to power off.
    #>
    param (
        [string]$classFolder,
        [string]$hostName
    )

    try {
        # Get the Classes folder path
        $dc          = Get-Datacenter -Server $conn -Name 'Datacenter' -ErrorAction Stop
        $vmFolder    = Get-Folder -Server $conn -Name 'vm' -Location $dc -ErrorAction Stop
        $classesRoot = Get-Folder -Server $conn -Name 'Classes' -Location $vmFolder -ErrorAction Stop
        $classPath   = Get-Folder -Server $conn -Name $classFolder -Location $classesRoot -ErrorAction Stop

        # Get student folder names
        $studentFolders = Get-Folder -Server $conn -Location $classPath -ErrorAction Stop

        # Loop through for the number of students in the class
        foreach ($folderName in $studentFolders) {
            # get the VM
            $MyVM = Get-VM -Location $folderName -Name $hostName -ErrorAction SilentlyContinue

            # power off the VMs
            If ($MyVM.PowerState -eq "PoweredOn") {
                    Stop-VM -VM $MyVM -Confirm:$false
            }
        
            # write messsage
            # Set-StatusMessage -Message "$folderName $hostName powered off" -Type 'Success'

        }
    } catch {
        Set-StatusMessage -Message "Failed to stop VMs in '$classFolder'" -Type 'Error'
    }
}

function Start-SpecificClassVMs {
    <#
    .SYNOPSIS
        Powers on specific VMs in a class folder.
    .PARAMETER classFolder
        The folder containing the class VMs.
    .PARAMETER serverName
        The name of the server to power off.
    #>
    param (
        [string]$classFolder,
        [string]$hostName
    )

    # Get the Classes folder path
    $dc          = Get-Datacenter -Server $conn -Name 'Datacenter' -ErrorAction Stop
    $vmFolder    = Get-Folder -Server $conn -Name 'vm' -Location $dc -ErrorAction Stop
    $classesRoot = Get-Folder -Server $conn -Name 'Classes' -Location $vmFolder -ErrorAction Stop
    $classPath   = Get-Folder -Server $conn -Name $classFolder -Location $classesRoot -ErrorAction Stop

    # Get student folder names
    $studentFolders = Get-Folder -Server $conn -Location $classPath -ErrorAction Stop

    # Loop through for the number of students in the class
    foreach ($folderName in $studentFolders) {
        # get the VM
        $MyVM = Get-VM -Location $folderName -Name $hostName -ErrorAction SilentlyContinue

        # power off the VMs
        If (($MyVM.PowerState -eq "PoweredOff") -or ($MyVM.PowerState -eq "Suspended")) {
                Start-VM -VM $MyVM -Confirm:$false
        }
    
        # write messsage
        #Set-StatusMessage -Message "$folderName $hostName powered on" -Type 'Success'

    }
}

function New-CourseVMs {
    <#
    .SYNOPSIS
        Creates student VM folders and VMs for a course, including network setup.
    .PARAMETER courseInfo
        PSCustomObject with properties: 
        - students (array of names), 
        - classFolder (string), 
        - dataStore (string),
        - servers (array of PSCustomObjects with properties: serverName, template, customization, adapters).
    #>
    param(
        [PSCustomObject]$courseInfo
    )
    BEGIN { }
    PROCESS {

        # Get the VM host
        $vmHost = Get-VMHost 2> $null

        # Get all available Port Groups on the VMHost
        $availablePortGroups = Get-VirtualPortGroup -VMHost $vmHost | Select-Object -ExpandProperty Name
        # Trim and set to Lower Case to avoid any case sensitive checks
        $normalizedPortGroups = $availablePortGroups | ForEach-Object { $_.Trim().ToLower() }

        # Print the available Port Groups
        #Write-Host "Available Port Groups on host: $($availablePortGroups -join ', ')"
        
        # Exit early for testing
        # return

        # Get the root Classes folder (will need to be changed if for whatever reason the Classes naming changes)
        $classesRoot = Get-Folder -Name 'Classes' -ErrorAction Stop

        # Get the class folder and check if the folder doesn't exist
        $classFolder = Get-Folder -Name $courseInfo.classFolder -ErrorAction SilentlyContinue
        if (-not $classFolder) {
            # Update Status Message
            Set-StatusMessage -Message "Class Folder: $($courseInfo.classFolder) doesn't exist. Will begin creating it now..." -Type 'Success' 
            # Create new folder
            $classFolder = New-Folder -Name $courseInfo.classFolder -Location $classesRoot 2> $null
            # Check now if the folder (we just created) doesn't exists
            if (-not $classFolder) {
                throw "Failed to create class folder..."
            }
        # If this point is reached then it already exists
        } else {
            # Update Status Message
            Set-StatusMessage -Message "Class Folder: $($courseInfo.classFolder) already exists." -Type 'Success' 
        }

        # Loop through each student in the array of names
        ForEach ($student in $courseInfo.students) {
            # Set up how each student will be referenced with the class folder name pre-appended
            $userAccount = $courseInfo.classFolder + "_" + $student

            # Try to get folder and check if student folder doesn't exists
            $studentFolder = Get-Folder -Name $userAccount 2> $null
            if (-not $studentFolder) {
                # Update Status Message
                Set-StatusMessage -Message "Creating folder for $userAccount" -Type 'Success' 
        
                # Create new folder
                $studentFolder = New-Folder -Name $userAccount -Location $classFolder 2> $null

                # Setup permissions using CWU accounts
                $account = Get-VIAccount -Name $userAccount -Domain "CWU" 2> $null
                $role = Get-VIRole -Name StudentUser 2> $null
                if ($account -and $role) {
                    New-VIPermission -Entity $studentFolder -Principal $account -Role $role > $null 2>&1
                }

            # If this point was reached then the student folder already exists
            } else {
                # Update Status Message
                Set-StatusMessage -Message "Folder for $userAccount exists" -Type 'Success' 
            }

            # Loop over every VM that was declared to create each VM for the student
            foreach ($server in $courseInfo.servers) {
                # Set up how each student VM will be referenced with the VM name appended
                $studentVMName = $courseInfo.classFolder + "_" + $student.ToLower() + "_" + $($server.serverName)
                # Update Status Message
                Set-StatusMessage -Message "Building VM $studentVMName" -Type 'Success' 
                
                # Try catch to check creation of VM
                try {
                    if ($server.customization) {
                        New-VM -Name $studentVMName -Datastore $courseInfo.dataStore -VMHost $vmHost -Template $server.template -Location $studentFolder -OSCustomizationSpec $server.customization -ErrorAction Stop
                    } else {
                        New-VM -Name $studentVMName -Datastore $courseInfo.dataStore -VMHost $vmHost -Template $server.template -Location $studentFolder -ErrorAction Stop
                    }
                    # Update Status Message
                    Set-StatusMessage -Message "Success in creating $studentVMName" -Type 'Success'
                
                    # Allow time for the VM inventory to update
                    Start-Sleep -Seconds 10
                } catch {
                    # Update Status Message
                    Set-StatusMessage -Message "Failed to create $studentVMName" -Type 'Error'
                    continue
                }

                # Configure the network adapters
                $adapterNumber = 1 # Set up counter
                # Loop over each adapter that was chosen
                foreach ($adapter in $server.adapters) {
                    # Set up how each adapter will be referenced
                    # Trim and set to Lower Case to avoid any case sensitive checks
                    $adapterName = $adapter.Trim()
                    $normalizedAdapterName = $adapterName.ToLower()
                    $networkAdapterName = "Network Adapter $adapterNumber"

                    # Check if the array of available Port Groups (we normalized) contains the Adapter the user chose (remember we also normalized this)
                    if ($normalizedPortGroups -contains $normalizedAdapterName) {
                        # Try catch to check connection between VM and Port
                        try {
                            # Update Status Message
                            Set-StatusMessage -Message "Connecting $networkAdapterName on $studentVMName to port group $adapterName" -Type 'Success'
                
                            Get-VM -Name $studentVMName -Location $studentFolder |
                                Get-NetworkAdapter -Name $networkAdapterName |
                                Set-NetworkAdapter -PortGroup $adapterName -Confirm:$false -ErrorAction Stop
                        } catch {
                            # Update Status Message
                            Set-StatusMessage -Message "Failed to connect $networkAdapterName on $studentVMName to port group $adapterName" -Type 'Error'
                        }
                    # If this point was reached then the Port Group doesn't exist on the host.
                    } else {
                        # Update Status Message
                        Set-StatusMessage -Message "Port group $adapterName doesn't exist on host. Will skip $networkAdapterName for $studentVMName" -Type 'Success'
                    }

                    # Increment the counter
                    $adapterNumber++
                }

                # Try catch to check powering on the VM
                try {

                    # Update Status Message
                    Set-StatusMessage -Message "Powering on $studentVMName" -Type 'Success'
                   
                    Get-VM -Name $studentVMName -Location $studentFolder | Start-VM -Confirm:$false -ErrorAction Stop
                } catch {
                    # Update Status Message
                    Set-StatusMessage -Message "Failed to power on VM $studentVMName" -Type 'Error'
                }
            }

            # Update Status Message
            Set-StatusMessage -Message "Finished processing student: $student" -Type 'Success'
        }
    }
    END { }
}

function Remove-VMs {
    param( 
        [string]$classFolder
    )
    BEGIN{}
    PROCESS{

        # Get the Classes folder path
        $dc          = Get-Datacenter -Server $conn -Name 'Datacenter' -ErrorAction Stop
        $vmFolder    = Get-Folder -Server $conn -Name 'vm' -Location $dc -ErrorAction Stop
        $classesRoot = Get-Folder -Server $conn -Name 'Classes' -Location $vmFolder -ErrorAction Stop
        $classPath   = Get-Folder -Server $conn -Name $classFolder -Location $classesRoot -ErrorAction Stop

        # Get student folder names
        $studentFolders = Get-Folder -Server $conn -Location $classPath -ErrorAction Stop

        # Loop through for the number of students in the class
        foreach ($folderName in $studentFolders) {
            # power off the VMs
            Stop-VMs  $foldername 
    
            # remove the student folder
            Get-Folder -Name $folderName | Remove-Folder -Confirm:$false -DeletePermanently

            # write messsage
            # Write-Host $folderName " removed"
            # Set-StatusMessage -Message "$folderName removed" -Type 'Success'

        } 
    }
    END{}
}

function Stop-VMs {
    <#
    .SYNOPSIS
        Stops all VMs in a specified location.
    .PARAMETER location
        The location where the VMs are located.
    #>

    param(
        [string]$location
    )
    BEGIN{}
    PROCESS{
        $MyVMs = Get-VM -Location $location 
        ForEach ($MyVM in $MyVMs) {
            If ($MyVM.PowerState -eq "PoweredOn") {
                Stop-VM -VM $MyVM -Confirm:$false
            }
        }
    }
    END{}
}
