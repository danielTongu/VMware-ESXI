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

    $script:Refs = New-ClassManagerLayout -ContentPanel $ContentPanel

    $conn = $script:Connection

    if ($conn) {
        Set-StatusMessage -Refs $script:Refs -Message "Connected to $($conn.Name)" -Type 'Success'
        $templates  = Get-Template -Server $conn -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
        $datastores = Get-Datastore -Server $conn -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
        $networks   = Get-VirtualPortGroup -Server $conn -ErrorAction SilentlyContinue | Select-Object Name, VirtualSwitch, VLanId
        $dc          = Get-Datacenter -Server $conn -Name 'Datacenter'
        $vmFolder    = Get-Folder -Server $conn -Name 'vm' -Location $dc
        $classesRoot = Get-Folder -Server $conn -Name 'Classes' -Location $vmFolder
        $classes     = Get-Folder -Server $conn -Location $classesRoot -ErrorAction SilentlyContinue |
                       Where-Object { $_.Name -notmatch '_' } |
                       Select-Object -ExpandProperty Name

        $data = @{ Templates=$templates; Datastores=$datastores; Networks=$networks; Classes=$classes; LastUpdated=Get-Date }
        Update-ClassManagerWithData -UiRefs $script:Refs -Data $data
        Wire-UIEvents -UiRefs $script:Refs -ContentPanel $ContentPanel
    } else {
        Set-StatusMessage -Refs $script:Refs -Message "No connection established" -Type 'Error'
    }

}

function Set-StatusMessage {
    <#
    .SYNOPSIS
        Sets the status message with appropriate color coding.
    #>

    param(
        [Parameter(Mandatory)]
        [psobject] $Refs,
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
    $root.ColumnCount = 1; $root.RowCount = 3
    $root.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle 'Percent',100))
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
    $mainPanel.BackColor = $script:Theme.LightGray
    $root.Controls.Add($mainPanel, 0, 1)

    $tabs = New-Object System.Windows.Forms.TabControl
    $tabs.Dock = 'Fill'
    $tabs.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
    $tabs.Padding = New-Object System.Drawing.Point(20, 10)
    $mainPanel.Controls.Add($tabs)



    # ---------- Overview Tab ----------------------------------------
    $overview = New-Object System.Windows.Forms.TabPage 'Overview'
    $overview.BackColor = $script:Theme.White
    $tabs.TabPages.Add($overview)

    $ovPanel = New-Object System.Windows.Forms.TableLayoutPanel
    $ovPanel.Dock = 'Fill'
    $ovPanel.AutoSize = $true
    $ovPanel.AutoScroll = $true
    $ovPanel.AutoSizeMode = 'GrowAndShrink'
    $ovPanel.ColumnCount = 1
    $ovPanel.RowCount = 2
    $ovPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle 'Percent', 100))
    $ovPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'Percent', 100))
    $ovPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'AutoSize'))
    $overview.Controls.Add($ovPanel)

    $tree = New-Object System.Windows.Forms.TreeView
    $tree.Name = 'OverviewTree'
    $tree.Font = New-Object System.Drawing.Font('Segoe UI', 11)
    $tree.Dock = 'Fill'
    $ovPanel.Controls.Add($tree, 0, 0)

    $btnOvRefresh = New-Object System.Windows.Forms.Button
    $btnOvRefresh.Name = 'OverviewRefreshButton'
    $btnOvRefresh.Text = 'REFRESH'
    $btnOvRefresh.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
    $btnOvRefresh.Size = New-Object System.Drawing.Size(120, 35)
    $btnOvRefresh.BackColor = $script:Theme.Primary
    $btnOvRefresh.ForeColor = $script:Theme.White
    $btnOvRefresh.FlatStyle = 'Flat'
    $ovPanel.Controls.Add($btnOvRefresh, 0, 1)


    # ---------- Create student VMs Tab ----------------------------------------
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

    # 1 - The start student numeric up-down control
    $lblStartStu = New-Object System.Windows.Forms.Label
    $lblStartStu.Text = 'Start Student Number:'
    $lblStartStu.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $lblStartStu.AutoSize = $true
    $creatorLayout.Controls.Add($lblStartStu, 0, 1)

    $numStartStu = New-Object System.Windows.Forms.NumericUpDown
    $numStartStu.Name = 'StartStudentNumber'
    $numStartStu.Minimum = 1
    $numStartStu.Maximum = 1000
    $numStartStu.Value = 1
    $numStartStu.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $numStartStu.Dock = 'Fill'
    $numStartStu.Width = 100
    $creatorLayout.Controls.Add($numStartStu, 1, 1)

    # 2 - The end student numeric up-down control
    $lblEndStu = New-Object System.Windows.Forms.Label
    $lblEndStu.Text = 'End Student Number:'
    $lblEndStu.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $lblEndStu.AutoSize = $true
    $numEndStu = New-Object System.Windows.Forms.NumericUpDown
    $creatorLayout.Controls.Add($lblEndStu, 0, 2)

    $numEndStu.Name = 'EndStudentNumber'
    $numEndStu.Minimum = 1
    $numEndStu.Maximum = 1000
    $numEndStu.Value = 1
    $numEndStu.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $numEndStu.Dock = 'Fill'
    $numEndStu.Width = 100
    $creatorLayout.Controls.Add($numEndStu, 1, 2)

    # 3 - Course folder label and text box
    $lblClassFolder = New-Object System.Windows.Forms.Label
    $lblClassFolder.Text = 'Class Folder:'
    $lblClassFolder.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $creatorLayout.Controls.Add($lblClassFolder, 0, 3)

    $txtClassFolder = New-Object System.Windows.Forms.TextBox
    $txtClassFolder.Name = 'ClassFolder'
    $txtClassFolder.Text = 'CS370'
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
    $groupServersLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('AutoSize'))) # Server name row
    $groupServersLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('AutoSize'))) # Template row
    $groupServersLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('AutoSize'))) # customization row
    $groupServersLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('AutoSize'))) # Adapters CheckedListBox row
    $groupServers.Controls.Add($groupServersLayout)

    # 5-1 - Server name label and textbox
    $lblServerName = New-Object System.Windows.Forms.Label
    $lblServerName.Text = 'Server Name:'
    $lblServerName.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $lblServerName.AutoSize = $true
    $groupServersLayout.Controls.Add($lblServerName, 0, 0)

    $txtServerName = New-Object System.Windows.Forms.TextBox
    $txtServerName.Name = 'ServerName'
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



    # ----------- Tab for Remove/Power operation ----------------------------------------
    $deleteTab = New-Object System.Windows.Forms.TabPage 'Remove | Power'
    $deleteTab.BackColor = $script:Theme.White
    $tabs.TabPages.Add($deleteTab)

    # Main container with scrollable layout
    $deleteContainer = New-Object System.Windows.Forms.Panel
    $deleteContainer.Dock = 'Fill'
    $deleteContainer.AutoSize = $true
    $deleteContainer.AutoScroll = $true
    $deleteTab.Controls.Add($deleteContainer)

    # Flow layout for the entire tab
    $deleteFlowLayout = New-Object System.Windows.Forms.FlowLayoutPanel
    $deleteFlowLayout.Dock = 'Fill'
    $deleteFlowLayout.AutoSize = $true
    $deleteFlowLayout.WrapContents = $true
    $deleteFlowLayout.FlowDirection = 'LeftToRight'
    $deleteContainer.Controls.Add($deleteFlowLayout)

    # ================= PARAMETERS GROUPBOX =================
    $groupParams = New-Object System.Windows.Forms.GroupBox
    $groupParams.Text = "Parameters"
    $groupParams.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
    $groupParams.AutoSize = $true
    $groupParams.Padding = New-Object System.Windows.Forms.Padding(15)
    $deleteFlowLayout.Controls.Add($groupParams)

    $paramsLayout = New-Object System.Windows.Forms.TableLayoutPanel
    $paramsLayout.Dock = 'Fill'
    $paramsLayout.AutoSize = $true
    $paramsLayout.ColumnCount = 2
    $paramsLayout.RowCount = 3
    $paramsLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('AutoSize')))
    $paramsLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('AutoSize')))
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

    # Start Student Number
    $lblStart = New-Object System.Windows.Forms.Label
    $lblStart.Text = 'Start Student:'
    $lblStart.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $paramsLayout.Controls.Add($lblStart, 0, 1)
    
    $numStart = New-Object System.Windows.Forms.NumericUpDown
    $numStart.Name = 'StartStudentNumberDel'
    $numStart.Minimum = 1
    $numStart.Maximum = 1000
    $numStart.Value = 1
    $numStart.Width = 80
    $paramsLayout.Controls.Add($numStart, 1, 1)

    # End Student Number
    $lblEnd = New-Object System.Windows.Forms.Label
    $lblEnd.Text = 'End Student:'
    $lblEnd.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $paramsLayout.Controls.Add($lblEnd, 0, 2)

    $numEnd = New-Object System.Windows.Forms.NumericUpDown
    $numEnd.Name = 'EndStudentNumberDel'
    $numEnd.Minimum = 1
    $numEnd.Maximum = 1000
    $numEnd.Value = 1
    $numEnd.Width = 80
    $paramsLayout.Controls.Add($numEnd, 1, 2)

    # Host Name
    $lblHost = New-Object System.Windows.Forms.Label
    $lblHost.Text = 'Host Name:'
    $lblHost.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $paramsLayout.Controls.Add($lblHost, 0, 3)

    $cmbHost = New-Object System.Windows.Forms.ComboBox
    $cmbHost.Name = 'ServerComboBox'
    $cmbHost.DropDownStyle = 'DropDownList'
    $cmbHost.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $cmbHost.Width = 200
    $paramsLayout.Controls.Add($cmbHost, 1, 3)

    # ================= ACTION GROUPBOXES =================
    # Grouped by parameter requirements

    # 1. Remove-CourseFolder (classFolder + start/end students)
    $groupRemoveCourse = New-Object System.Windows.Forms.GroupBox
    $groupRemoveCourse.Dock = 'Top'
    $groupRemoveCourse.AutoSize = $true
    $groupRemoveCourse.Text = "Requires: Class Folder + Student Range"
    $groupRemoveCourse.AutoSizeMode = 'GrowAndShrink' # Prevent text wrapping in the GroupBox title
    $groupRemoveCourse.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
    $groupRemoveCourse.Padding = New-Object System.Windows.Forms.Padding(12)
    $deleteFlowLayout.Controls.Add($groupRemoveCourse)

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

    # 2. PowerOff-ClassVMs (classFolder only)
    $groupPowerOffClass = New-Object System.Windows.Forms.GroupBox
    $groupPowerOffClass.Dock = 'Top'
    $groupPowerOffClass.Text = "Requires: Class Folder"
    $groupPowerOffClass.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
    $groupPowerOffClass.AutoSize = $true
    $groupPowerOffClass.Padding = New-Object System.Windows.Forms.Padding(12)
    $deleteFlowLayout.Controls.Add($groupPowerOffClass)

    $layoutPowerOffClass = New-Object System.Windows.Forms.FlowLayoutPanel
    $layoutPowerOffClass.Dock = 'Fill'
    $layoutPowerOffClass.FlowDirection = 'TopDown'
    $layoutPowerOffClass.AutoSize = $true
    $layoutPowerOffClass.WrapContents = $true
    $groupPowerOffClass.Controls.Add($layoutPowerOffClass)

    $btnPowerOffClassVMs = New-Object System.Windows.Forms.Button
    $btnPowerOffClassVMs.Name = 'PowerOffClassVMsButton'
    $btnPowerOffClassVMs.Text = 'Power Off Class VMs'
    $btnPowerOffClassVMs.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
    $btnPowerOffClassVMs.Size = New-Object System.Drawing.Size(220, 35)
    $btnPowerOffClassVMs.BackColor = $script:Theme.Primary
    $btnPowerOffClassVMs.ForeColor = $script:Theme.White
    $btnPowerOffClassVMs.FlatStyle = 'Flat'
    $layoutPowerOffClass.Controls.Add($btnPowerOffClassVMs)

    # 3. Remove-Host/PowerOff-SpecificClassVMs/PowerOn-SpecificClassVMs (all params)
    $groupHostOps = New-Object System.Windows.Forms.GroupBox
    $groupHostOps.Dock = 'Fill'
    $groupHostOps.Text = "Requires: All Parameters"
    $groupHostOps.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
    $groupHostOps.AutoSize = $true
    $groupHostOps.Padding = New-Object System.Windows.Forms.Padding(12)
    $deleteFlowLayout.Controls.Add($groupHostOps)

    $hostOpsLayout = New-Object System.Windows.Forms.FlowLayoutPanel
    $hostOpsLayout.Dock = 'Fill'
    $hostOpsLayout.AutoSize = $true
    $hostOpsLayout.FlowDirection = 'TopDown'
    $hostOpsLayout.Margin = New-Object System.Windows.Forms.Padding(0, 10, 0, 0)
    $hostOpsLayout.WrapContents = $true
    $groupHostOps.Controls.Add($hostOpsLayout)

    $btnRemoveHost = New-Object System.Windows.Forms.Button
    $btnRemoveHost.AutoSize = $true
    $btnRemoveHost.Dock = 'Fill'
    $btnRemoveHost.Name = 'RemoveHostButton'
    $btnRemoveHost.Text = 'Remove Host VMs'
    $btnRemoveHost.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
    $btnRemoveHost.Size = New-Object System.Drawing.Size(180, 35)
    $btnRemoveHost.BackColor = $script:Theme.Primary
    $btnRemoveHost.ForeColor = $script:Theme.White
    $btnRemoveHost.FlatStyle = 'Flat'
    $btnRemoveHost.Margin = New-Object System.Windows.Forms.Padding(5)
    $hostOpsLayout.Controls.Add($btnRemoveHost)

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

    

    # ========== Footer ========================================
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
        ContentPanel = $ContentPanel
        Header = @{ LastRefreshLabel = $lblLast }
        Tabs = @{
            Overview = @{
                RefreshButton = $btnOvRefresh
                TreeView      = $tree
            }
            Create = @{
                StartStudentNumber   = $numStartStu
                EndStudentNumber     = $numEndStu
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
            Delete = @{
                # Parameters
                ClassComboBox        = $cmbClass
                ServerComboBox       = $cmbServer
                StartStudentNumber   = $numStartStuDel
                EndStudentNumber     = $numEndStuDel
                # Requires all parameters
                RemoveHostButton            = $btnRemoveHost
                PowerOffSpecificClassVMsButton   = $btnPowerOffSpecificVMs
                PowerOnSpecificClassVMsButton    = $btnPowerOnSpecificVMs
                # Requires Class Folder + Start/End Students
                RemoveCourseFolderVMsButton       = $btnRemoveCourseFolderVMs
                # Requires Class Folder only
                PowerOffClassVMsButton    = $btnPowerOffClassVMs
            }
        }
        StatusLabel = $lblStatus
    }
    
}


function Update-ClassManagerWithData {
    <#
    .SYNOPSIS
        Updates the UI controls with the latest data.
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

    if (-not $UiRefs -or -not $Data) {
        Write-Error "Invalid parameters passed to Update-ClassManagerWithData"
        return
    }
    # Ensure we have a valid connection
    $conn = $script:Connection

    # Update timestamp
    $UiRefs.Header.LastRefreshLabel.Text = "Last refresh: $($Data.LastUpdated.ToString('HH:mm:ss tt'))"

    # Update Overview tab - Build class tree structure
    $tree = $UiRefs.Tabs.Overview.TreeView
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
                $studentFolder = Get-Folder -Server $conn -Location $classFolder -ErrorAction SilentlyContinue |
                                 Where-Object { $_.Name -eq $stu }

                # Retrieve VM names
                $vms = if ($studentFolder) {
                    Get-VM -Server $conn -Location $studentFolder -ErrorAction SilentlyContinue |
                    Select-Object -ExpandProperty Name
                } else { @() }

                foreach ($vm in $vms) {
                    # Add VMs as child nodes
                    $nStu.Nodes.Add($vm)
                }
            }
        }
    } else {
        $tree.Nodes.Add("No classes found") | Out-Null
    }

    # Update Create tab dropdowns
    $cmbTemplate = $UiRefs.Tabs.Create.ServerTemplate
    $cmbTemplate.Items.Clear()
    if ($Data.Templates) {
        $cmbTemplate.Items.AddRange($Data.Templates)
        if ($cmbTemplate.Items.Count -gt 0) { $cmbTemplate.SelectedIndex = 0 }
    }

    $cmbDataStore = $UiRefs.Tabs.Create.DataStoreDropdown
    $cmbDataStore.Items.Clear()
    if ($Data.Datastores) {
        $cmbDataStore.Items.AddRange($Data.Datastores)
        if ($cmbDataStore.Items.Count -gt 0) { $cmbDataStore.SelectedIndex = 0 }
    }

    $clbAdapters = $UiRefs.Tabs.Create.ServerAdapters
    $clbAdapters.Items.Clear()
    if ($Data.Networks) {
        foreach ($network in $Data.Networks) {
            $displayText = "$($network.Name) (vSwitch: $($network.VirtualSwitch), VLAN: $($network.VLanId))"
            $clbAdapters.Items.Add($displayText, $true) | Out-Null
        }
    }

    # Update Delete tab dropdowns
    $cmbClass = $UiRefs.Tabs.Delete.ClassComboBox
    $cmbClass.Items.Clear()
    if ($Data.Classes) {
        $cmbClass.Items.AddRange($Data.Classes)
        if ($cmbClass.Items.Count -gt 0) { $cmbClass.SelectedIndex = 0 }
    }

    $cmbServer = $UiRefs.Tabs.Delete.ServerComboBox
    $cmbServer.Items.Clear()
    if ($Data.Servers) {
        $cmbServer.Items.AddRange($Data.Servers)
        if ($cmbServer.Items.Count -gt 0) { $cmbServer.SelectedIndex = 0 }
    }
    # Set status message
    Set-StatusMessage -Refs $UiRefs -Message "UI updated with latest data" -Type 'Success'

    # Ensure the UI is responsive
    [System.Windows.Forms.Application]::DoEvents()
    Write-Verbose "UI updated with latest data"

}


function Wire-UIEvents {
    <#
    .SYNOPSIS
        Wires up event handlers for all UI controls.
    .PARAMETER UiRefs
        Hashtable of UI control references.
    .PARAMETER ContentPanel
        The main content panel hosting the UI.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $UiRefs,
        [Parameter(Mandatory)] [System.Windows.Forms.Panel] $ContentPanel
    )

    # Overview Tab Events
    $UiRefs.Tabs.Overview.RefreshButton.Add_Click({
        . $PSScriptRoot\ClassesView.ps1
        Show-ClassesView -ContentPanel $script:Refs.ContentPanel -UiRefs $UiRefs
        Set-StatusMessage -Refs $script:Refs -Message "Overview refreshed" -Type 'Success'
    })

    #  ----------------------  Create Tab Events  ----------------------

    # Gather all the needed GUI components (required for Scope issues, approved by Dr. White)
    $script:className = $UiRefs.Tabs.Create.ClassFolder                     # Class Name
    $script:textBox = $UiRefs.Tabs.Create.StudentNames                      # Student Names
    $script:dataStore = $UiRefs.Tabs.Create.DataStoreDropdown               # DataStore
    $script:serverName = $UiRefs.Tabs.Create.ServerName                     # Server Name
    $script:template = $UiRefs.Tabs.Create.ServerTemplate                   # Template
    $script:customization = $UiRefs.Tabs.Create.ServerCustomization         # Customization   
    $script:adapters = $UiRefs.Tabs.Create.ServerAdapters                   # Adapters

    # CREATE TAB IMPORT BUTTON
    $UiRefs.Tabs.Create.ImportButton.Add_Click({

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
    $UiRefs.Tabs.Create.CreateVMsButton.Add_Click({
        
        # Needed for Set-StatusMessage function
        . $PSScriptRoot\ClassesView.ps1

        # --------------- Check if null before trying to update ---------------
        if ($null -eq $script:adapters) { # Swapped in each of the input values and all have passed
            [System.Windows.Forms.MessageBox]::Show(
                "Error: Adapters were not initialized!", # message
                "Initialization Error",   # title
                [System.Windows.Forms.MessageBoxButtons]::OK, # buttons
                [System.Windows.Forms.MessageBoxIcon]::Error # icon
            )
            # exit early to avoid proceeding with the rest of the code
            return
        } else {
            [System.Windows.Forms.MessageBox]::Show(
                "Adapters were initialized!", # message
                "Initialization Successful",   # title
                [System.Windows.Forms.MessageBoxButtons]::OK, # buttons
                [System.Windows.Forms.MessageBoxIcon]::Information # icon
            )

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
            $customization = $script:customization.SelectedItem
            # Adapters
            $adapters = $script:adapters.CheckedItems
            $selectedAdapters = @()
            ForEach($item in $adapters) {
                $selectedAdapters += $item # store each checked box in an array
            }

            # --------------- Print statements to test if user input was gathered correctly ---------------
            # ClassName
            Write-Host "Class Name: $className"
            # StudentNames
            ForEach($studentName in $studentArray) {
                Write-Host "Student Name: $studentName"
            }
            # Datastore
            Write-Host "DataStore: $dataStore"
            # ServerName
            Write-Host "Server Name: $serverName"
            # Template
            Write-Host "Template Name: $templateName"
            # Customization
            Write-Host "Customization: $customization"
            # Adapters
            ForEach($item in $selectedAdapters) {
                Write-Host "Adapter: $item"
            }

            # exit early to avoid proceeding with the rest of the code
            # return
        }
        

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
            if ($selectedAdapters.Count -eq 0) {
                throw "Please select at least one network adapter"
            }
            
            # --------------- Create course info object ---------------
            # Start with ServerInfo which will be placed within the CourseInfo Object
            $serverInfo = @{
                serverName = $serverName
                template = $templateName
                customization = $customization
                adapters = $selectedAdapters
            }
            
            # Now store values into the CourseInfo Object
            $courseInfo = [PSCustomObject]@{
                classFolder = $className    # Name of the Class
                students = $studentArray    # Array of all the Students needing a folder
                dataStore = $datastore      # Name of the DataStore
                servers = @($serverInfo)    # Info regarding the Server
            }

            # Print statements to test if the Object was created properly and we can access the data
            Write-Host "`n"

            # Class Name
            Write-Host "Class Name: $($courseInfo.classFolder)"
            # Student Names
            ForEach($studentName in $courseInfo.students) {
                Write-Host "Student Name: $studentName"
            }
            # DataStore
            Write-Host "DataStore: $($courseInfo.datastore)"
            # ServerName
            Write-Host "Server Name: $($courseInfo.servers.serverName)"
            # Template
            Write-Host "Template: $($courseInfo.servers.template)"
            # Customization
            Write-Host "Customization: $($courseInfo.servers.customization)"
            # Adapters
            ForEach($item in $courseInfo.servers.adapters) {
                Write-Host "Adapters: $item"
            }

            # --------------- Call the VM creation function ---------------
            New-CourseVMs -courseInfo $courseInfo 
            Set-StatusMessage -Refs $script:Refs -Message "Successfully created VMs for class $className" -Type 'Success'
            
        } catch {
            Set-StatusMessage -Refs $script:Refs -Message "Error creating VMs: $_" -Type 'Error'
        }
    })


    # Delete Tab Events
    $UiRefs.Tabs.Delete.RemoveCourseFolderVMsButton.Add_Click({
        try {
            $classFolder = $UiRefs.Tabs.Delete.ClassComboBox.SelectedItem
            $startNum = $UiRefs.Tabs.Delete.StartStudentNumber.Value
            $endNum = $UiRefs.Tabs.Delete.EndStudentNumber.Value
            
            if (-not $classFolder) {
                throw "Please select a class folder"
            }
            
            Remove-CourseFolder -classFolder $classFolder -startStudents $startNum -endStudents $endNum
            Set-StatusMessage -Refs $script:Refs -Message "Successfully removed VMs for class $classFolder" -Type 'Success'
            
        } catch {
            Set-StatusMessage -Refs $script:Refs -Message "Error removing VMs: $_" -Type 'Error'
        }
    })

    $UiRefs.Tabs.Delete.PowerOffClassVMsButton.Add_Click({
        try {
            $classFolder = $UiRefs.Tabs.Delete.ClassComboBox.SelectedItem
            
            if (-not $classFolder) {
                throw "Please select a class folder"
            }
            
            PowerOff-ClassVMs -classFolder $classFolder
            Set-StatusMessage -Refs $script:Refs -Message "Successfully powered off VMs for class $classFolder" -Type 'Success'
            
        } catch {
            Set-StatusMessage -Refs $script:Refs -Message "Error powering off VMs: $_" -Type 'Error'
        }
    })

    $UiRefs.Tabs.Delete.RemoveHostButton.Add_Click({
        try {
            $classFolder = $UiRefs.Tabs.Delete.ClassComboBox.SelectedItem
            $serverName = $UiRefs.Tabs.Delete.ServerComboBox.SelectedItem
            $startNum = $UiRefs.Tabs.Delete.StartStudentNumber.Value
            $endNum = $UiRefs.Tabs.Delete.EndStudentNumber.Value
            
            if (-not $classFolder) {
                throw "Please select a class folder"
            }
            
            if (-not $serverName) {
                throw "Please select a server"
            }
            
            Remove-Host -classFolder $classFolder -hostName $serverName -startStudents $startNum -endStudents $endNum
            Set-StatusMessage -Refs $script:Refs -Message "Successfully removed host $serverName for class $classFolder" -Type 'Success'
            
        } catch {
            Set-StatusMessage -Refs $script:Refs -Message "Error removing host: $_" -Type 'Error'
        }
    })

    $UiRefs.Tabs.Delete.PowerOffSpecificClassVMsButton.Add_Click({
        try {
            $classFolder = $UiRefs.Tabs.Delete.ClassComboBox.SelectedItem
            $serverName = $UiRefs.Tabs.Delete.ServerComboBox.SelectedItem
            $startNum = $UiRefs.Tabs.Delete.StartStudentNumber.Value
            $endNum = $UiRefs.Tabs.Delete.EndStudentNumber.Value
            
            if (-not $classFolder) {
                throw "Please select a class folder"
            }
            
            if (-not $serverName) {
                throw "Please select a server"
            }
            
            PowerOff-SpecificClassVMs -classFolder $classFolder -serverName $serverName -startStudents $startNum -endStudents $endNum
            Set-StatusMessage -Refs $script:Refs -Message "Successfully powered off $serverName for class $classFolder" -Type 'Success'
            
        } catch {
            Set-StatusMessage -Refs $script:Refs -Message "Error powering off VMs: $_" -Type 'Error'
        }
    })

    $UiRefs.Tabs.Delete.PowerOnSpecificClassVMsButton.Add_Click({
        try {
            $classFolder = $UiRefs.Tabs.Delete.ClassComboBox.SelectedItem
            $serverName = $UiRefs.Tabs.Delete.ServerComboBox.SelectedItem
            $startNum = $UiRefs.Tabs.Delete.StartStudentNumber.Value
            $endNum = $UiRefs.Tabs.Delete.EndStudentNumber.Value
            
            if (-not $classFolder) {
                throw "Please select a class folder"
            }
            
            if (-not $serverName) {
                throw "Please select a server"
            }
            
            PowerOn-SpecificClassVMs -classFolder $classFolder -serverName $serverName -startStudents $startNum -endStudents $endNum
            Set-StatusMessage -Refs $script:Refs -Message "Successfully powered on $serverName for class $classFolder" -Type 'Success'
            
        } catch {
            Set-StatusMessage -Refs $script:Refs -Message "Error powering on VMs: $_" -Type 'Error'
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
    .PARAMETER startStudents
        The starting student number.
    .PARAMETER endStudents
        The ending student number.
    #>
    param (
        [string]$classFolder,
        [int]$startStudents = 1,
        [int]$endStudents = 1
    )

    # Import common functions if needed
    Import-Module $HOME'\Google Drive\VMware Scripts\VmFunctions.psm1' -ErrorAction SilentlyContinue

    ConnectTo-VMServer

    if (Get-Folder $classFolder -ErrorAction Ignore) {
        # Loop through for the number of students in the class
        Remove-VMs $classFolder $startStudents $endStudents
    }
    else {
        Write-Host 'Bad class folder'
    }
}

function Remove-Host {
    <#
    .SYNOPSIS
        Removes a host VM and its associated student folders.
    .PARAMETER classFolder
        The folder containing the class VMs.
    .PARAMETER hostName
        The name of the host VM to remove.
    .PARAMETER startStudents
        The starting student number.
    .PARAMETER endStudents
        The ending student number.
    #>  

    param(
        [string]$classFolder,
        [string]$hostName,
        [int]$startStudents,
        [int]$endStudents
    )
    BEGIN{}
    PROCESS{
        # Loop through for the number of students in the class
        for ($i=$startStudents; $i -le $endStudents; $i++) {
            $userAccount = $classFolder+'_S'+$i
    
            # set the folder name
            $folderName = $classFolder+'_S'+$i

            $MyVM = Get-VM -Location $folderName -Name $hostName
            If ($MyVM.PowerState -eq "PoweredOn") {
                Stop-VM -VM $MyVM -Confirm:$false
            }
            
            Remove-VM -DeletePermanently -VM $MyVM -Confirm:$false

        }

    }
    END{}
}

function PowerOff-ClassVMs {
    <#
    .SYNOPSIS
        Powers off all VMs in a specified class folder.
    .PARAMETER classFolder
        The folder containing the class VMs to power off.
    #>
    
    param (
        [string]$classFolder
    )

    $MyVMs = Get-VM -Location $classFolder 2> $null | Sort-Object -Property Folder
    ForEach ($MyVM in $MyVMs) {
        If ($MyVM.PowerState -eq "PoweredOn") {
            Write-Host "Stopping " $MyVM.Folder   $MyVM.Name
            Stop-VM -VM $MyVM -Confirm:$false > $null 2>&1
        }
    } # ForEach ($MyVM in $MyVMs)
}

function PowerOff-SpecificClassVMs {
    <#
    .SYNOPSIS
        Powers off specific VMs in a class folder based on student numbers.
    .PARAMETER startStudents
        The starting student number.
    .PARAMETER endStudents
        The ending student number.
    .PARAMETER classFolder
        The folder containing the class VMs.
    .PARAMETER serverName
        The name of the server to power off.
    #>

    param (
        [int]$startStudents = 1,
        [int]$endStudents = 1,
        [string]$classFolder,
        [string]$serverName
    )

    # import common functions
    Import-Module $HOME'\Google Drive\VMware Scripts\VmFunctions.psm1'

    ConnectTo-VMServer

    # Loop through for the number of students in the class
    for ($i=$startStudents; $i -le $endStudents; $i++) {
        # set the folder name
        $folderName = $classFolder+'_S'+$i
        
        # get the VM
        $MyVM = Get-VM -Location $folderName -Name $serverName 2> $null 

        # power off the VMs
        If ($MyVM.PowerState -eq "PoweredOn") {
                Stop-VM -VM $MyVM -Confirm:$false > $null 2>&1
        }
    
        # write messsage
        Write-Host $folderName " " $serverName " powered off"

    } # for ($i=$startStudents; $i -le $endStudents; $i++)
}

function PowerOn-SpecificClassVMs {
    <#
    .SYNOPSIS
        Powers on specific VMs in a class folder based on student numbers.
    .PARAMETER startStudents
        The starting student number.
    .PARAMETER endStudents
        The ending student number.
    .PARAMETER classFolder
        The folder containing the class VMs.
    .PARAMETER serverName
        The name of the server to power on.
    #>
    

    param (
        [int]$startStudents = 1,
        [int]$endStudents = 1,
        [string]$classFolder,
        [string]$serverName
    )

    # Loop through for the number of students in the class
    for ($i=$startStudents; $i -le $endStudents; $i++) {
        # set the folder name
        $folderName = $classFolder+'_S'+$i
        
        # get the VM
        $MyVM = Get-VM -Location $folderName -Name $serverName 2> $null 

        # power off the VMs
        If (($MyVM.PowerState -eq "PoweredOff") -or ($MyVM.PowerState -eq "Suspended")) {
                Start-VM -VM $MyVM -Confirm:$false > $null 2>&1
        }
    
        # write messsage
        Write-Host $folderName " " $serverName " powered on"

    } # for ($i=$startStudents; $i -le $endStudents; $i++)
}

function New-CourseVMs {
    <#
    .SYNOPSIS
        Creates student VM folders and VMs for a course, including network setup.
    .PARAMETER courseInfo
        PSCustomObject with properties: startStudents, endStudents, classFolder, dataStore, servers (array).
    #>
    param(
        [PSCustomObject]$courseInfo
    )
    BEGIN { }
    PROCESS {

        # import common functions
        # Import-Module $HOME'\Google Drive\VMware Scripts\VmFunctions.psm1'

        # Connect to the server
        # ConnectTo-VMServer

        # Get the VM host
        $vmHost = Get-VMHost 2> $null

        # Get the root Classes folder
        $classesRoot = Get-Folder -Name 'Classes'

        # Check if the class folder already exists
        $classFolder = Get-Folder -Name $courseInfo.classFolder -ErrorAction SilentlyContinue
        if (-not $classFolder) {
            # Print statement
            Write-Host "Class Folder: $($courseInfo.classFolder) doesn't exist. Will begin creating it now..."
            # Create new folder
            $classFolder = New-Folder -Name $courseInfo.classFolder -Location $classesRoot 2> $null
            # Check now if the folder (we just created) exists
            if (-not $classFolder) {
                throw "Failed to create class folder..."
            }
        # If this point is reached then it already exists
        } else {
            # Print statement
            Write-Host "Class Folder: $($courseInfo.classFolder) already exists."
        }

        # Loop through each student in the array of names
        ForEach ($student in $courseInfo.students) {
            $userAccount = $courseInfo.classFolder + "_" + $student

            # Ensure student folder exists
            $studentFolder = Get-Folder -Name $userAccount 2> $null
            if (-not $studentFolder) {
                Write-Host "Creating folder for $userAccount"
                $studentFolder = New-Folder -Name $userAccount -Location $classFolder 2> $null

                # Commenting out the Permissions for now...
                # $account = Get-VIAccount -Name $userAccount -Domain "CWU" 2> $null
                # $role = Get-VIRole -Name StudentUser 2> $null
                # if ($account -and $role) {
                #    New-VIPermission -Entity $studentFolder -Principal $account -Role $role > $null 2>&1
                # }
            } else {
                Write-Host "Folder for $userAccount exists"
            }

            # Create servers for the student
            foreach ($server in $courseInfo.servers) {
                $studentVMName = "$student" + "_" + "$($server.serverName)"
                Write-Host "Building VM $studentVMName"
                if ($server.customization) {
                    New-VM -Name $studentVMName -Datastore $courseInfo.dataStore -VMHost $vmHost -Template $server.template -Location $studentFolder -OSCustomizationSpec $server.customization > $null 2>&1
                } else {
                    New-VM -Name $studentVMName -Datastore $courseInfo.dataStore -VMHost $vmHost -Template $server.template -Location $studentFolder > $null 2>&1
                }

                # Configure network adapters
                $adapterNumber = 1
                foreach ($adapter in $server.adapters) {
                    $networkAdapter = "Network Adapter $adapterNumber"
                    switch ($adapter) {
                        'Instructor' { $adapterName = $courseInfo.classFolder + '_In' }
                        'NATswitch'  { $adapterName = $adapter }
                        'inside'     { $adapterName = $adapter }
                        default {
                            $adapterName = "$adapter" + "_" + "$student"
                            if (-not (Get-VirtualSwitch -Name $adapterName 2> $null)) {
                                Write-Host "Creating network adapter $adapterName"
                                $vSwitch = New-VirtualSwitch -Name $adapterName -VMHost $vmHost 2> $null
                                $vPortGroup = New-VirtualPortGroup -Name $adapterName -VirtualSwitch $vSwitch 2> $null
                            } else {
                                Write-Host "$adapterName exists"
                            }
                        }
                    }

                    Write-Host "Connecting to $adapterName"
                    Get-VM -Name $studentVMName -Location $studentFolder |
                        Get-NetworkAdapter -Name $networkAdapter |
                        Set-NetworkAdapter -PortGroup $adapterName -Confirm:$false > $null 2>&1
                    $adapterNumber++
                }

                # Power on the VM
                Write-Host "Powering on"
                Get-VM -Name $studentVMName -Location $studentFolder | Start-VM -Confirm:$false > $null 2>&1
            }
            Write-Host "Finished processing student: $student`n"
        }
    }
    END { }
}

function Remove-VMs {
    param( 
        [string]$classFolder,
        [int]$startStudents,
        [int]$endStudents
    )
    BEGIN{}
    PROCESS{
        # Loop through for the number of students in the class
        for ($i=$startStudents; $i -le $endStudents; $i++) {
            $userAccount = $classFolder+'_S'+$i

    
            # set the folder name
            $folderName = $classFolder+'_S'+$i
    
            # power off the VMs
            Stop-VMs  $foldername 
    
            # remove the student folder
            Get-Folder -Name $folderName | Remove-Folder -Confirm:$false -DeletePermanently

            # write messsage
            Write-Host $folderName " removed"

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