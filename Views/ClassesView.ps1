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

    $script:ClassesUiRefs = New-ClassManagerLayout -ContentPanel $ContentPanel

    $script:ClassesContentPanel = $ContentPanel

    $conn = $script:Connection

    if ($conn) {
        Set-StatusMessage -Refs $script:ClassesUiRefs -Message "Connected to $($conn.Name)" -Type 'Success'
        $templates  = Get-Template -Server $conn -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
        $datastores = Get-Datastore -Server $conn -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
        $networks   = Get-VirtualPortGroup -Server $conn -ErrorAction SilentlyContinue | Select-Object Name, VirtualSwitch, VLanId
        $dc          = Get-Datacenter -Server $conn -Name 'Datacenter'
        $vmFolder    = Get-Folder -Server $conn -Name 'vm' -Location $dc
        $classesRoot = Get-Folder -Server $conn -Name 'Classes' -Location $vmFolder
        $classes     = Get-Folder -Server $conn -Location $classesRoot -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name

        $data = @{ Templates=$templates; Datastores=$datastores; Networks=$networks; Classes=$classes; LastUpdated=Get-Date }
        Update-ClassManagerWithData -UiRefs $script:ClassesUiRefs -Data $data
        Wire-UIEvents -UiRefs $script:ClassesUiRefs -ContentPanel $ContentPanel
    } else {
        Set-StatusMessage -Refs $script:ClassesUiRefs -Message "No connection established" -Type 'Error'
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
    $tree.Font = New-Object System.Drawing.Font('Segoe UI', 9)
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



    # ----------- Tab for Delete operation ----------------------------------------
    $deleteTab = New-Object System.Windows.Forms.TabPage 'Delete'
    $deleteTab.BackColor = $script:Theme.White
    $tabs.TabPages.Add($deleteTab)

    $deleteLayout = New-Object System.Windows.Forms.TableLayoutPanel
    $deleteLayout.Dock = 'Fill'
    $deleteLayout.ColumnCount = 2
    $deleteLayout.RowCount = 6
    $deleteLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle 'AutoSize'))
    $deleteLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle 'Percent', 100))
    $deleteLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'AutoSize')) # Class label and dropdown
    $deleteLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'AutoSize')) # Class server label and dropdown
    $deleteLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'AutoSize')) # Start student number label and numeric up-down control
    $deleteLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'AutoSize')) # End student number label and numeric up-down control
    $deleteLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'AutoSize')) # Buttons panel
    $deleteTab.Controls.Add($deleteLayout)

    # 1 - class folder label and dropdown
    $lblClass = New-Object System.Windows.Forms.Label
    $lblClass.Text = 'Select Class Folder:'
    $lblClass.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $lblClass.AutoSize = $true
    $deleteLayout.Controls.Add($lblClass, 0, 0)
    
    $cmbClass = New-Object System.Windows.Forms.ComboBox
    $cmbClass.Name = 'ClassComboBox'
    $cmbClass.DropDownStyle = 'DropDownList'
    $cmbClass.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $cmbClass.Dock = 'Top'
    $cmbClass.Width = 200
    $deleteLayout.Controls.Add($cmbClass, 1, 0)

    # 2 - Class server label and dropdown
    $lblServer = New-Object System.Windows.Forms.Label
    $lblServer.Text = 'Select Class Server:'
    $lblServer.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $lblServer.AutoSize = $true
    $deleteLayout.Controls.Add($lblServer, 0, 1)

    $cmbServer = New-Object System.Windows.Forms.ComboBox
    $cmbServer.Name = 'ServerComboBox'
    $cmbServer.DropDownStyle = 'DropDownList'
    $cmbServer.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $cmbServer.Dock = 'Top'
    $cmbServer.Width = 200
    $deleteLayout.Controls.Add($cmbServer, 1, 1)

    # 3 - Start student number label and numeric up-down control
    $lblStartStuDel = New-Object System.Windows.Forms.Label
    $lblStartStuDel.Text = 'Start Student Number:'
    $lblStartStuDel.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $lblStartStuDel.AutoSize = $true
    $deleteLayout.Controls.Add($lblStartStuDel, 0, 2)
    
    $numStartStuDel = New-Object System.Windows.Forms.NumericUpDown
    $numStartStuDel.Name = 'StartStudentNumberDel'
    $numStartStuDel.Minimum = 1
    $numStartStuDel.Maximum = 1000
    $numStartStuDel.Value = 1
    $numStartStuDel.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $numStartStuDel.Dock = 'Fill'
    $numStartStuDel.Width = 100
    $deleteLayout.Controls.Add($numStartStuDel, 1, 2)

    # 4 - End student number label and numeric up-down control
    $lblEndStuDel = New-Object System.Windows.Forms.Label
    $lblEndStuDel.Text = 'End Student Number:'
    $lblEndStuDel.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $lblEndStuDel.AutoSize = $true
    $deleteLayout.Controls.Add($lblEndStuDel, 0, 3)

    $numEndStuDel = New-Object System.Windows.Forms.NumericUpDown
    $numEndStuDel.Dock = 'Fill'
    $numEndStuDel.Name = 'EndStudentNumberDel'
    $numEndStuDel.Minimum = 1
    $numEndStuDel.Maximum = 1000
    $numEndStuDel.Value = 1
    $numEndStuDel.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $numEndStuDel.Dock = 'Fill'
    $numEndStuDel.Width = 100
    $deleteLayout.Controls.Add($numEndStuDel, 1, 3)

    # 5 - Buttons flow layout panel
    $btnPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $btnPanel.Dock = 'Fill'
    $btnPanel.FlowDirection = 'LeftToRight'
    $btnPanel.AutoSize = $true
    $btnPanel.WrapContents = $false
    $deleteLayout.Controls.Add($btnPanel, 0, 4)
    $deleteLayout.SetColumnSpan($btnPanel, 2)

    # 5-1 - Remove course folder VMs button
    $btnRemoveCourseVMs = New-Object System.Windows.Forms.Button
    $btnRemoveCourseVMs.Name = 'RemoveCourseVMsButton'
    $btnRemoveCourseVMs.Text = 'Remove Course Folder VMs'
    $btnRemoveCourseVMs.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
    $btnRemoveCourseVMs.Size = New-Object System.Drawing.Size(200, 35)
    $btnRemoveCourseVMs.BackColor = $script:Theme.Primary
    $btnRemoveCourseVMs.ForeColor = $script:Theme.White
    $btnRemoveCourseVMs.FlatStyle = 'Flat'
    $btnPanel.Controls.Add($btnRemoveCourseVMs)


    # 5-2 - Remove Host button
    $btnRemoveHost = New-Object System.Windows.Forms.Button
    $btnRemoveHost.Name = 'RemoveHostButton'
    $btnRemoveHost.Text = 'Remove Hosts'
    $btnRemoveHost.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
    $btnRemoveHost.Size = New-Object System.Drawing.Size(200, 35)
    $btnRemoveHost.BackColor = $script:Theme.Primary
    $btnRemoveHost.ForeColor = $script:Theme.White
    $btnRemoveHost.FlatStyle = 'Flat'
    $btnPanel.Controls.Add($btnRemoveHost)

    # 5-3 - Power off specific Class VMS button
    $btnPowerOffVMs = New-Object System.Windows.Forms.Button
    $btnPowerOffVMs.Name = 'PowerOffVMsButton'
    $btnPowerOffVMs.Text = 'Power Off Specific Class VMs'
    $btnPowerOffVMs.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
    $btnPowerOffVMs.Size = New-Object System.Drawing.Size(200, 35)
    $btnPowerOffVMs.BackColor = $script:Theme.Primary
    $btnPowerOffVMs.ForeColor = $script:Theme.White
    $btnPowerOffVMs.FlatStyle = 'Flat'
    $btnPanel.Controls.Add($btnPowerOffVMs)

    # 5-4 - Power on specific class VMs button
    $btnPowerOnVMs = New-Object System.Windows.Forms.Button
    $btnPowerOnVMs.Name = 'PowerOnVMsButton'
    $btnPowerOnVMs.Text = 'Power On Specific Class VMs'
    $btnPowerOnVMs.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
    $btnPowerOnVMs.Size = New-Object System.Drawing.Size(200, 35)
    $btnPowerOnVMs.BackColor = $script:Theme.Primary
    $btnPowerOnVMs.ForeColor = $script:Theme.White
    $btnPowerOnVMs.FlatStyle = 'Flat'
    $btnPanel.Controls.Add($btnPowerOnVMs)

    # 5-5 - Power off class VMs button
    $btnPowerOffVMs = New-Object System.Windows.Forms.Button
    $btnPowerOffVMs.Name = 'PowerOffVMsButton'
    $btnPowerOffVMs.Text = 'Power Off Class VMs'
    $btnPowerOffVMs.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
    $btnPowerOffVMs.Size = New-Object System.Drawing.Size(200, 35)
    $btnPowerOffVMs.BackColor = $script:Theme.Primary
    $btnPowerOffVMs.ForeColor = $script:Theme.White
    $btnPowerOffVMs.FlatStyle = 'Flat'
    $btnPanel.Controls.Add($btnPowerOffVMs)

    

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
                ClassComboBox        = $cmbClass
                ServerComboBox       = $cmbServer
                StartStudentNumber   = $numStartStuDel
                EndStudentNumber     = $numEndStuDel
                RemoveCourseVMsButton= $btnRemoveCourseVMs
                RemoveHostButton     = $btnRemoveHost
                PowerOffVMsButton    = $btnPowerOffVMs
                PowerOnVMsButton     = $btnPowerOnVMs
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
            # Add class node
            $nCls = $tree.Nodes.Add($cls)
            $students = Get-Folder -Server $conn -Name $cls -ErrorAction SilentlyContinue |
                        Get-Folder -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
            
            # Add students to class node
            foreach ($stu in $students) {
                $nStu = $nCls.Nodes.Add($stu)
                $folder =   Get-Folder -Server $conn -Name $cls -ErrorAction SilentlyContinue |
                            Get-Folder -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq $stu }

                $vms = if ($folder) { Get-VM -Server $conn -Location $folder -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name } else { @() }
                # Add VMs to student node
                foreach ($vm in $vms) { $nStu.Nodes.Add($vm) }
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
        . $PSScriptRoot\ClassesViews.ps1
        Show-ClassesView -ContentPanel $script:ClassesUiRefs.ContentPanel -Refs $UiRefs
        Set-StatusMessage -Refs $UiRefs -Message "Overview refreshed" -Type 'Success'
    })

    # Create Tab Events
    $UiRefs.Tabs.Create.ImportButton.Add_Click({
         . $PSScriptRoot\ClassesViews.ps1
        $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
        $openFileDialog.Filter = "Text Files (*.txt)|*.txt|CSV Files (*.csv)|*.csv|All Files (*.*)|*.*"
        $openFileDialog.Title = "Select Student List File"
        
        if ($openFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            try {
                $content = Get-Content -Path $openFileDialog.FileName -Raw
                $UiRefs.Tabs.Create.StudentNames.Text = $content
                Set-StatusMessage -Refs $UiRefs -Message "Student list imported successfully" -Type 'Success'
            } catch {
                Set-StatusMessage -Refs $UiRefs -Message "Failed to import student list: $_" -Type 'Error'
            }
        }
    })

    $UiRefs.Tabs.Create.CreateVMsButton.Add_Click({
        . $PSScriptRoot\ClassesViews.ps1
        try {
            # Gather all the input values
            $startNum = $UiRefs.Tabs.Create.StartStudentNumber.Value
            $endNum = $UiRefs.Tabs.Create.EndStudentNumber.Value
            $className = $UiRefs.Tabs.Create.ClassFolder.Text.Trim()
            $datastore = $UiRefs.Tabs.Create.DataStoreDropdown.SelectedItem
            $serverName = $UiRefs.Tabs.Create.ServerName.Text.Trim()
            $template = $UiRefs.Tabs.Create.ServerTemplate.SelectedItem
            $customization = $UiRefs.Tabs.Create.ServerCustomization.SelectedItem
            $studentNames = $UiRefs.Tabs.Create.StudentNames.Text -split "`n" | Where-Object { $_.Trim() -ne '' }
            $selectedAdapters = $UiRefs.Tabs.Create.ServerAdapters.CheckedItems
            
            # Validate inputs
            if ([string]::IsNullOrWhiteSpace($className)) {
                throw "Class folder name cannot be empty"
            }
            
            if ($startNum -gt $endNum) {
                throw "Start student number cannot be greater than end student number"
            }
            
            if ([string]::IsNullOrWhiteSpace($serverName)) {
                throw "Server name cannot be empty"
            }
            
            if (-not $template) {
                throw "Please select a template"
            }
            
            if ($selectedAdapters.Count -eq 0) {
                throw "Please select at least one network adapter"
            }
            
            # Create course info object
            $serverInfo = @{
                serverName = $serverName
                template = $template
                customization = if ($customization -ne "None") { $customization } else { $null }
                adapters = $selectedAdapters
            }
            
            $courseInfo = [PSCustomObject]@{
                startStudents = $startNum
                endStudents = $endNum
                classFolder = $className
                dataStore = $datastore
                servers = @($serverInfo)
            }
            
            # Call the VM creation function
            New-CourseVMs -courseInfo $courseInfo
            Set-StatusMessage -Refs $UiRefs -Message "Successfully created VMs for class $className" -Type 'Success'
            
        } catch {
            Set-StatusMessage -Refs $UiRefs -Message "Error creating VMs: $_" -Type 'Error'
        }
    })

    # Delete Tab Events
    $UiRefs.Tabs.Delete.RemoveCourseVMsButton.Add_Click({
         . $PSScriptRoot\ClassesViews.ps1
        try {
            $classFolder = $UiRefs.Tabs.Delete.ClassComboBox.SelectedItem
            $startNum = $UiRefs.Tabs.Delete.StartStudentNumber.Value
            $endNum = $UiRefs.Tabs.Delete.EndStudentNumber.Value
            
            if (-not $classFolder) {
                throw "Please select a class folder"
            }
            
            Remove-CourseFolder -classFolder $classFolder -startStudents $startNum -endStudents $endNum
            Set-StatusMessage -Refs $UiRefs -Message "Successfully removed VMs for class $classFolder" -Type 'Success'
            
        } catch {
            Set-StatusMessage -Refs $UiRefs -Message "Error removing VMs: $_" -Type 'Error'
        }
    })

    $UiRefs.Tabs.Delete.RemoveHostButton.Add_Click({
         . $PSScriptRoot\ClassesViews.ps1
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
            Set-StatusMessage -Refs $UiRefs -Message "Successfully removed host $serverName for class $classFolder" -Type 'Success'
            
        } catch {
            Set-StatusMessage -Refs $UiRefs -Message "Error removing host: $_" -Type 'Error'
        }
    })

    $UiRefs.Tabs.Delete.PowerOffVMsButton.Add_Click({
         . $PSScriptRoot\ClassesViews.ps1

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
            Set-StatusMessage -Refs $UiRefs -Message "Successfully powered off $serverName for class $classFolder" -Type 'Success'
            
        } catch {
            Set-StatusMessage -Refs $UiRefs -Message "Error powering off VMs: $_" -Type 'Error'
        }
    })

    $UiRefs.Tabs.Delete.PowerOnVMsButton.Add_Click({
         . $PSScriptRoot\ClassesViews.ps1
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
            Set-StatusMessage -Refs $UiRefs -Message "Successfully powered on $serverName for class $classFolder" -Type 'Success'
            
        } catch {
            Set-StatusMessage -Refs $UiRefs -Message "Error powering on VMs: $_" -Type 'Error'
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
        # Connect to the server
        ConnectTo-VMServer

        # Get the VM host
        $vmHost = Get-VMHost 2> $null

        # Loop through each student number
        for ($i = $courseInfo.startStudents; $i -le $courseInfo.endStudents; $i++) {
            $userAccount = $courseInfo.classFolder + "_" + $i

            # Ensure student folder exists
            $studentFolder = Get-Folder -Name $userAccount 2> $null
            if (-not $studentFolder) {
                Write-Host "Creating folder for $userAccount"
                $studentFolder = New-Folder -Name $userAccount -Location (Get-Folder -Name $courseInfo.classFolder) 2> $null

                $account = Get-VIAccount -Name $userAccount -Domain "CWU" 2> $null
                $role = Get-VIRole -Name StudentUser 2> $null
                if ($account -and $role) {
                    New-VIPermission -Entity $studentFolder -Principal $account -Role $role > $null 2>&1
                }
            } else {
                Write-Host "Folder for $userAccount exists"
            }

            # Create servers for the student
            foreach ($server in $courseInfo.servers) {
                Write-Host "Building $($server.serverName)"
                if ($server.customization) {
                    New-VM -Name $server.serverName -Datastore $courseInfo.dataStore -VMHost $vmHost -Template $server.template -Location $studentFolder -OSCustomizationSpec $server.customization > $null 2>&1
                } else {
                    New-VM -Name $server.serverName -Datastore $courseInfo.dataStore -VMHost $vmHost -Template $server.template -Location $studentFolder > $null 2>&1
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
                            $adapterName = $adapter + $i
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
                    Get-VM -Name $server.serverName -Location $studentFolder |
                        Get-NetworkAdapter -Name $networkAdapter |
                        Set-NetworkAdapter -PortGroup $adapterName -Confirm:$false > $null 2>&1
                    $adapterNumber++
                }

                # Power on the VM
                Write-Host "Powering on"
                Get-VM -Name $server.serverName -Location $studentFolder | Start-VM -Confirm:$false > $null 2>&1
            }
            Write-Host ""
        }
    }
    END { }
}