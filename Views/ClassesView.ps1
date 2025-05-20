# ─────────────────────────  Assemblies  ──────────────────────────────────────
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing



# ─────────────────────────  VMware Helper Classes  ───────────────────────────
class VMwareNetwork {
    static [array] ListPortGroups() {
        try {
            $conn = $script:Connection
            if (-not $conn) { return @() }
            
            $portGroups = Get-VirtualPortGroup -Server $conn -ErrorAction SilentlyContinue | 
                Select-Object Name, VirtualSwitch, VLanId
            return $portGroups
        }
        catch {
            Write-Verbose "Failed to list port groups: $_"
            return @()
        }
    }
}



class CourseManager {
    static [array] ListClasses() {
        try {
            $conn = $script:Connection
            if (-not $conn) { return @() }
            
            # Get all folders that match the pattern "CS###" (course folders)
            $folders = Get-Folder -Server $conn -Type VM -ErrorAction SilentlyContinue | 
                Where-Object { $_.Name -match '^CS\d{3}$' } | 
                Select-Object -ExpandProperty Name
            return $folders
        }
        catch {
            Write-Verbose "Failed to list classes: $_"
            return @()
        }
    }

    static [array] GetClassStudents([string]$className) {
        try {
            $conn = $script:Connection
            if (-not $conn) { return @() }
            
            # Get all student folders under the class folder
            $students = Get-Folder -Server $conn -Name $className -Location (Get-Folder -Name 'vm') -ErrorAction SilentlyContinue | 
                Get-Folder -ErrorAction SilentlyContinue | 
                Select-Object -ExpandProperty Name
            
            # Extract student IDs (format: ClassName_StudentID)
            return $students -replace "^${className}_", ""
        }
        catch {
            Write-Verbose "Failed to get class students: $_"
            return @()
        }
    }

    static [array] GetStudentVMs([string]$className, [string]$studentId) {
        try {
            $conn = $script:Connection
            if (-not $conn) { return @() }
            
            $folderName = "${className}_${studentId}"
            $vms = Get-VM -Server $conn -Location $folderName -ErrorAction SilentlyContinue | 
                Select-Object -ExpandProperty Name
            return $vms
        }
        catch {
            Write-Verbose "Failed to get student VMs: $_"
            return @()
        }
    }

    static [PSCustomObject] GetCourseConfig([string]$className) {
        try {
            $conn = $script:Connection
            if (-not $conn) { return $null }
            
            # Get first VM in class to determine config
            $sampleVM = Get-VM -Server $conn -Location "${className}_*" -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $sampleVM) { return $null }
            
            # Get VM details
            $template = $sampleVM.ExtensionData.Config.Template
            $datastore = $sampleVM.DatastoreIdList | ForEach-Object { 
                Get-Datastore -Server $conn -Id $_ | Select-Object -ExpandProperty Name 
            } | Select-Object -First 1
            
            # Get network adapters
            $adapters = $sampleVM | Get-NetworkAdapter | 
                Select-Object -ExpandProperty NetworkName | 
                Where-Object { $_ -ne $null }
            
            # Get all VMs in class (assuming same config for all)
            $servers = Get-VM -Server $conn -Location "${className}_*" -ErrorAction SilentlyContinue | 
                ForEach-Object {
                    [PSCustomObject]@{
                        serverName = $_.Name
                        template = $template
                        adapters = $adapters
                        customization = $null
                    }
                }
            
            return [PSCustomObject]@{
                classFolder = $className
                dataStore = $datastore
                servers = $servers
                students = [CourseManager]::GetClassStudents($className)
            }
        }
        catch {
            Write-Verbose "Failed to get course config: $_"
            return $null
        }
    }

    static [void] CreateCourseVMs([PSCustomObject]$courseInfo) {
        try {
            $conn = $script:Connection
            if (-not $conn) { throw "Not connected to VMware server" }

            $vmHost = Get-VMHost -Server $conn -ErrorAction Stop | Select-Object -First 1
            if (-not $vmHost) { throw "No available VM host found" }

            foreach ($student in $courseInfo.students) {

                # Create folder name (e.g., "CS361_Student1")
                $folderName = "$($courseInfo.classFolder)_$student"

                # Create or get student folder
                $studentFolder = Get-Folder -Server $conn -Name $folderName -ErrorAction SilentlyContinue
                if (-not $studentFolder) {
                    $studentFolder = New-Folder -Server $conn -Name $folderName -Location (Get-Folder -Name $courseInfo.classFolder) -ErrorAction Stop
                    
                    # Set permissions if needed
                    $account = Get-VIAccount -Server $conn -Name $folderName -Domain "CWU" -ErrorAction SilentlyContinue
                    if ($account) {
                        $role = Get-VIRole -Server $conn -Name "StudentUser" -ErrorAction SilentlyContinue
                        if ($role) {
                            New-VIPermission -Server $conn -Entity $studentFolder -Principal $account -Role $role -ErrorAction SilentlyContinue | Out-Null
                        }
                    }
                }
                
                # Create VMs for this student
                foreach ($server in $courseInfo.servers) {
                    $vmName = $server.serverName
                    
                    # Create VM from template
                    if ($server.customization) {
                        New-VM -Server $conn -Name $vmName -Datastore $courseInfo.dataStore -VMHost $vmHost `
                            -Template $server.template -Location $studentFolder `
                            -OSCustomizationSpec $server.customization -ErrorAction Stop | Out-Null
                    }
                    else {
                        New-VM -Server $conn -Name $vmName -Datastore $courseInfo.dataStore -VMHost $vmHost `
                            -Template $server.template -Location $studentFolder -ErrorAction Stop | Out-Null
                    }
                    
                    # Configure network adapters
                    $adapterNumber = 1
                    foreach ($adapter in $server.adapters) {
                        $networkAdapter = "Network Adapter $adapterNumber"
                        
                        Get-VM -Server $conn -Name $vmName -Location $studentFolder | 
                            Get-NetworkAdapter -Name $networkAdapter | 
                            Set-NetworkAdapter -PortGroup $adapter -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
                        $adapterNumber++
                    }
                    
                    # Start VM
                    Get-VM -Server $conn -Name $vmName -Location $studentFolder | 
                        Start-VM -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
                }
            }
        }
        catch {
            Write-Error "Failed to create course VMs: $_"
            throw
        }
    }

    static [void] RemoveCourseVMs([string]$className, [array]$studentList) {
        try {
            $conn = $script:Connection
            if (-not $conn) { throw "Not connected to VMware server" }
            
            foreach ($student in $studentList) {
                $folderName = "${className}_${student}"
                
                # Stop and remove all VMs in folder
                $vms = Get-VM -Server $conn -Location $folderName -ErrorAction SilentlyContinue
                foreach ($vm in $vms) {
                    if ($vm.PowerState -eq "PoweredOn") {
                        Stop-VM -Server $conn -VM $vm -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
                    }
                    Remove-VM -Server $conn -VM $vm -DeletePermanently -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
                }
                
                # Remove folder
                Get-Folder -Server $conn -Name $folderName -ErrorAction SilentlyContinue | 
                    Remove-Folder -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
            }
        }
        catch {
            Write-Verbose "Failed to remove course VMs: $_"
            throw $_
        }
    }
}





# ─────────────────────────  Public entry point  ──────────────────────────────
function Show-ClassesView {
    <#
    .SYNOPSIS
        Renders the Course Manager view in the supplied WinForms panel.
    .PARAMETER ContentPanel
        The host panel into which the view is drawn.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Forms.Panel] $ContentPanel
    )

    # Keep panel reference for refresh
    $script:ClassesContentPanel = $ContentPanel

    try {
        # 1 ─ Build the empty UI
        $uiRefs = New-ClassManagerLayout -ContentPanel $ContentPanel

        # 2 ─ Gather data (may be $null when disconnected)
        $data = Get-ClassManagerData

        # 3 ─ Populate or warn
        if ($data) {
            Update-ClassManagerWithData -UiRefs $uiRefs -Data $data
            $ContentPanel.Refresh()
        }
        else {
            $uiRefs['StatusLabel'].Text = 'No connection to VMware server'
            $uiRefs['StatusLabel'].ForeColor = $script:Theme.Error
        }
    }
    catch {
        Write-Verbose "Class manager initialization failed: $_"
    }
}





# ─────────────────────────  Data collection  ─────────────────────────────────
function Get-ClassManagerData {
    <#
    .SYNOPSIS
        Retrieves templates, datastores, networks and course list.
    .OUTPUTS
        [hashtable] - Keys: Templates, Datastores, Networks, Classes
    #>
    [CmdletBinding()] param()

    try {
        $conn = $script:Connection
        if (-not $conn) { return $null }

        $data = @{
            Templates   = @()
            Datastores  = @()
            Networks    = @()
            Classes     = @()
            LastUpdated = Get-Date
        }

        # Each section isolated - one failure doesn't break everything
        try { $data.Templates  = Get-Template -Server $conn -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name }
        catch { $data.Templates = @() }

        try { $data.Datastores = Get-Datastore -Server $conn -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name }
        catch { $data.Datastores = @() }

        try { $data.Networks   = [VMwareNetwork]::ListPortGroups() | Select-Object -ExpandProperty Name }
        catch { $data.Networks = @() }

        try { $data.Classes    = [CourseManager]::ListClasses() }
        catch { $data.Classes = @() }

        return $data
    }
    catch {
        Write-Verbose "Data collection failed: $_"
        return $null
    }
}





# ─────────────────────────  Layout builders  ─────────────────────────────────
function New-ClassManagerLayout {
    <#
    .SYNOPSIS
        Builds the Course Manager UI (header, tab-control, status bar).
    .OUTPUTS
        [hashtable] - references to frequently accessed controls.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Forms.Panel] $ContentPanel
    )

    try {
        $ContentPanel.SuspendLayout()
        $ContentPanel.Controls.Clear()
        $ContentPanel.BackColor = $script:Theme.LightGray


        # ── Root table ───────────────────────────────────────────────────────
        $root = New-Object System.Windows.Forms.TableLayoutPanel
        $root.Dock = 'Fill'
        $root.ColumnCount = 1
        $root.RowCount = 3
        $root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'AutoSize'))
        $root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'Percent',100))
        $root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'AutoSize'))
        $ContentPanel.Controls.Add($root)


        # ── Header ───────────────────────────────────────────────────────────
        $header = New-Object System.Windows.Forms.Panel
        $header.Dock = 'Fill'
        $header.Height = 80
        $header.BackColor = $script:Theme.Primary
        $root.Controls.Add($header, 0, 0)

        $title = New-Object System.Windows.Forms.Label
        $title.Text = 'COURSE MANAGER'
        $title.Font = New-Object System.Drawing.Font('Segoe UI',18,[System.Drawing.FontStyle]::Bold)
        $title.ForeColor = $script:Theme.White
        $title.AutoSize = $true
        $title.Location = New-Object System.Drawing.Point(20,20)
        $header.Controls.Add($title)


        # ── TabControl ────────────────────────────────────────────────────────
        $tabs = New-Object System.Windows.Forms.TabControl
        $tabs.Dock = 'Fill'
        $tabs.SizeMode = 'Fixed'
        $tabs.ItemSize = New-Object System.Drawing.Size(150,40)
        $tabs.Font = New-Object System.Drawing.Font('Segoe UI',10,[System.Drawing.FontStyle]::Bold)
        $root.Controls.Add($tabs, 0, 1)

        $refs = @{ TabControl = $tabs; Tabs = @{} }


        # 1. Overview Tab ─────────────────────────────────────────────────────
        $tabOverview = New-Object System.Windows.Forms.TabPage 'Overview'
        $tabOverview.BackColor = $script:Theme.White
        $tabs.TabPages.Add($tabOverview)
        $refs.Tabs['Overview'] = @{}

        $ovLayout = New-Object System.Windows.Forms.TableLayoutPanel
        $ovLayout.Dock = 'Fill'
        $ovLayout.RowCount = 2
        $ovLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'Percent',100))
        $ovLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'AutoSize'))
        $tabOverview.Controls.Add($ovLayout)

        # Tree view
        $treePanel = New-Object System.Windows.Forms.Panel
        $treePanel.Dock = 'Fill'
        $treePanel.Padding = New-Object System.Windows.Forms.Padding(10)
        $treePanel.BackColor = $script:Theme.White
        $ovLayout.Controls.Add($treePanel, 0, 0)

        $tree = New-Object System.Windows.Forms.TreeView
        $tree.Dock = 'Fill'
        $tree.BackColor = $script:Theme.White
        $tree.ForeColor = $script:Theme.PrimaryDark
        $treePanel.Controls.Add($tree)
        $refs.Tabs['Overview']['ClassTree'] = $tree

        # Refresh button
        $btnRefresh = New-Object System.Windows.Forms.Button
        $btnRefresh.Text = 'REFRESH'
        $btnRefresh.Size = New-Object System.Drawing.Size(120,40)
        $btnRefresh.Font = New-Object System.Drawing.Font('Segoe UI',10,[System.Drawing.FontStyle]::Bold)
        $btnRefresh.BackColor = $script:Theme.Primary
        $btnRefresh.ForeColor = $script:Theme.White

        $flowButtons = New-Object System.Windows.Forms.FlowLayoutPanel
        $flowButtons.Dock = 'Fill'
        $flowButtons.Padding = New-Object System.Windows.Forms.Padding(5)
        $flowButtons.Controls.Add($btnRefresh)
        $ovLayout.Controls.Add($flowButtons, 0, 1)
        $refs.Tabs['Overview']['RefreshButton'] = $btnRefresh


        # 2. Basic Setup Tab ──────────────────────────────────────────────────
        $tabBasic = New-Object System.Windows.Forms.TabPage 'Basic Setup'
        $tabBasic.BackColor = $script:Theme.White
        $tabs.TabPages.Add($tabBasic)
        $refs.Tabs['Basic'] = @{}

        $basicLayout = New-Object System.Windows.Forms.TableLayoutPanel
        $basicLayout.Dock = 'Fill'
        $basicLayout.RowCount = 3
        $basicLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'AutoSize'))
        $basicLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'Percent',100))
        $basicLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'AutoSize'))
        $tabBasic.Controls.Add($basicLayout)

        # Input grid
        $inputGrid = New-Object System.Windows.Forms.TableLayoutPanel
        $inputGrid.Dock = 'Fill'
        $inputGrid.ColumnCount = 2
        $inputGrid.RowCount = 2
        $inputGrid.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle 'AutoSize'))
        $inputGrid.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle 'Percent',100))
        $basicLayout.Controls.Add($inputGrid, 0, 1)

        # Class name
        $lblClassName = New-Object System.Windows.Forms.Label
        $lblClassName.Text = 'Class Name:'
        $lblClassName.Font = New-Object System.Drawing.Font('Segoe UI',10)
        $lblClassName.Dock = 'Fill'
        $lblClassName.TextAlign = 'MiddleRight'
        $lblClassName.AutoSize = $true
        $inputGrid.Controls.Add($lblClassName, 0, 0)

        $txtClassName = New-Object System.Windows.Forms.TextBox
        $txtClassName.Dock = 'Fill'
        $txtClassName.BackColor = $script:Theme.White
        $inputGrid.Controls.Add($txtClassName, 1, 0)
        $refs.Tabs['Basic']['ClassNameTextBox'] = $txtClassName

        # Student list
        $lblStudents = New-Object System.Windows.Forms.Label
        $lblStudents.Text = 'Students (ID per line):'
        $lblStudents.Font = New-Object System.Drawing.Font('Segoe UI',10)
        $lblStudents.Dock = 'Fill'
        $lblStudents.TextAlign = 'TopRight'
        $lblStudents.AutoSize = $true
        $inputGrid.Controls.Add($lblStudents, 0, 1)

        $txtStudents = New-Object System.Windows.Forms.TextBox
        $txtStudents.Multiline = $true
        $txtStudents.ScrollBars = 'Vertical'
        $txtStudents.Dock = 'Fill'
        $txtStudents.BackColor = $script:Theme.White
        $inputGrid.Controls.Add($txtStudents, 1, 1)
        $refs.Tabs['Basic']['StudentsTextBox'] = $txtStudents

        # Create folders button
        $btnCreateFolders = New-Object System.Windows.Forms.Button
        $btnCreateFolders.Text = 'CREATE FOLDERS'
        $btnCreateFolders.Size = New-Object System.Drawing.Size(150,40)
        $btnCreateFolders.Font = New-Object System.Drawing.Font('Segoe UI',10,[System.Drawing.FontStyle]::Bold)
        $btnCreateFolders.BackColor = $script:Theme.Primary
        $btnCreateFolders.ForeColor = $script:Theme.White

        $flowButtons = New-Object System.Windows.Forms.FlowLayoutPanel
        $flowButtons.Dock = 'Fill'
        $flowButtons.Padding = New-Object System.Windows.Forms.Padding(5)
        $flowButtons.Controls.Add($btnCreateFolders)
        $basicLayout.Controls.Add($flowButtons, 0, 2)
        $refs.Tabs['Basic']['CreateFoldersButton'] = $btnCreateFolders


        # 3. Advanced Tab ─────────────────────────────────────────────────────
        $tabAdvanced = New-Object System.Windows.Forms.TabPage 'Advanced'
        $tabAdvanced.BackColor = $script:Theme.White
        $tabs.TabPages.Add($tabAdvanced)
        $refs.Tabs['Advanced'] = @{}

        $advLayout = New-Object System.Windows.Forms.TableLayoutPanel
        $advLayout.Dock = 'Fill'
        $advLayout.RowCount = 3
        $advLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'AutoSize'))
        $advLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'Percent',100))
        $advLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'AutoSize'))
        $tabAdvanced.Controls.Add($advLayout)


        # Input grid
        $inputGrid = New-Object System.Windows.Forms.TableLayoutPanel
        $inputGrid.Dock = 'Fill'
        $inputGrid.ColumnCount = 2
        $inputGrid.RowCount = 5
        $inputGrid.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle 'AutoSize'))
        $inputGrid.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle 'Percent',100))
        $advLayout.Controls.Add($inputGrid, 0, 1)



        # Class combo
        $lblClass = New-Object System.Windows.Forms.Label
        $lblClass.Text = 'Class:'
        $lblClass.Font = New-Object System.Drawing.Font('Segoe UI',10)
        $lblClass.Dock = 'Fill'
        $lblClass.TextAlign = 'MiddleRight'
        $lblClass.AutoSize = $true
        $inputGrid.Controls.Add($lblClass, 0, 0)

        $cmbClass = New-Object System.Windows.Forms.ComboBox
        $cmbClass.Dock = 'Fill'
        $cmbClass.DropDownStyle = 'DropDownList'
        $inputGrid.Controls.Add($cmbClass, 1, 0)
        $refs.Tabs['Advanced']['ClassComboBox'] = $cmbClass


        # Template combo
        $lblTemplate = New-Object System.Windows.Forms.Label
        $lblTemplate.Text = 'Template:'
        $lblTemplate.Font = New-Object System.Drawing.Font('Segoe UI',10)
        $lblTemplate.Dock = 'Fill'
        $lblTemplate.TextAlign = 'MiddleRight'
        $lblTemplate.AutoSize = $true
        $inputGrid.Controls.Add($lblTemplate, 0, 1)

        $cmbTemplate = New-Object System.Windows.Forms.ComboBox
        $cmbTemplate.Dock = 'Fill'
        $cmbTemplate.DropDownStyle = 'DropDownList'
        $inputGrid.Controls.Add($cmbTemplate, 1, 1)
        $refs.Tabs['Advanced']['TemplateComboBox'] = $cmbTemplate


        # Datastore combo
        $lblDatastore = New-Object System.Windows.Forms.Label
        $lblDatastore.Text = 'Datastore:'
        $lblDatastore.Font = New-Object System.Drawing.Font('Segoe UI',10)
        $lblDatastore.Dock = 'Fill'
        $lblDatastore.TextAlign = 'MiddleRight'
        $lblDatastore.AutoSize = $true
        $inputGrid.Controls.Add($lblDatastore, 0, 2)

        $cmbDatastore = New-Object System.Windows.Forms.ComboBox
        $cmbDatastore.Dock = 'Fill'
        $cmbDatastore.DropDownStyle = 'DropDownList'
        $inputGrid.Controls.Add($cmbDatastore, 1, 2)
        $refs.Tabs['Advanced']['DatastoreComboBox'] = $cmbDatastore


        # Networks checklist
        $lblNetworks = New-Object System.Windows.Forms.Label
        $lblNetworks.Text = 'Networks:'
        $lblNetworks.Font = New-Object System.Drawing.Font('Segoe UI',10)
        $lblNetworks.Dock = 'Fill'
        $lblNetworks.TextAlign = 'TopRight'
        $lblNetworks.AutoSize = $true
        $inputGrid.Controls.Add($lblNetworks, 0, 3)

        $clbNetworks = New-Object System.Windows.Forms.CheckedListBox
        $clbNetworks.CheckOnClick = $true
        $clbNetworks.Dock = 'Fill'
        $inputGrid.Controls.Add($clbNetworks, 1, 3)
        $refs.Tabs['Advanced']['NetworkListBox'] = $clbNetworks


        # Servers grid
        $lblServers = New-Object System.Windows.Forms.Label
        $lblServers.Text = 'Servers:'
        $lblServers.Font = New-Object System.Drawing.Font('Segoe UI',10)
        $lblServers.Dock = 'Fill'
        $lblServers.TextAlign = 'TopRight'
        $lblServers.AutoSize = $true
        $inputGrid.Controls.Add($lblServers, 0, 4)

        $gridServers = New-Object System.Windows.Forms.DataGridView
        $gridServers.Dock = 'Fill'
        $gridServers.RowHeadersVisible = $false
        $gridServers.AllowUserToAddRows = $true
        $gridServers.AllowUserToDeleteRows = $true
        $gridServers.AutoSizeColumnsMode = 'Fill'


        # Add columns
        foreach ($hdr in @('Server Name','Template','Adapters')) {
            $col = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
            $col.HeaderText = $hdr
            $col.SortMode = 'NotSortable'
            $gridServers.Columns.Add($col) | Out-Null
        }
        $inputGrid.Controls.Add($gridServers, 1, 4)
        $refs.Tabs['Advanced']['ServersGrid'] = $gridServers


        # Buttons
        $btnCreateVMs = New-Object System.Windows.Forms.Button
        $btnCreateVMs.Text = 'CREATE VMs'
        $btnCreateVMs.Size = New-Object System.Drawing.Size(150,40)
        $btnCreateVMs.Font = New-Object System.Drawing.Font('Segoe UI',10,[System.Drawing.FontStyle]::Bold)
        $btnCreateVMs.BackColor = $script:Theme.Primary
        $btnCreateVMs.ForeColor = $script:Theme.White

        $btnDeleteClass = New-Object System.Windows.Forms.Button
        $btnDeleteClass.Text = 'DELETE CLASS'
        $btnDeleteClass.Size = New-Object System.Drawing.Size(150,40)
        $btnDeleteClass.Font = New-Object System.Drawing.Font('Segoe UI',10,[System.Drawing.FontStyle]::Bold)
        $btnDeleteClass.BackColor = $script:Theme.Error
        $btnDeleteClass.ForeColor = $script:Theme.White

        $flowButtons = New-Object System.Windows.Forms.FlowLayoutPanel
        $flowButtons.Dock = 'Fill'
        $flowButtons.Padding = New-Object System.Windows.Forms.Padding(5)
        $flowButtons.Controls.AddRange(@($btnCreateVMs, $btnDeleteClass))
        $advLayout.Controls.Add($flowButtons, 0, 2)

        $refs.Tabs['Advanced']['CreateVMsButton'] = $btnCreateVMs
        $refs.Tabs['Advanced']['DeleteClassButton'] = $btnDeleteClass


        # ── Status bar ───────────────────────────────────────────────────────
        $statusPanel = New-Object System.Windows.Forms.Panel
        $statusPanel.Dock = 'Fill'
        $statusPanel.Height = 30
        $statusPanel.BackColor = $script:Theme.LightGray
        $root.Controls.Add($statusPanel, 0, 2)

        $statusLabel = New-Object System.Windows.Forms.Label
        $statusLabel.Name = 'StatusLabel'
        $statusLabel.Text = 'DISCONNECTED'
        $statusLabel.Font = New-Object System.Drawing.Font('Segoe UI',9)
        $statusLabel.ForeColor = $script:Theme.PrimaryDark
        $statusLabel.Dock = 'Fill'
        $statusLabel.TextAlign = 'MiddleLeft'
        $statusPanel.Controls.Add($statusLabel)
        $refs['StatusLabel'] = $statusLabel


        # ── Event hooks ──────────────────────────────────────────────────────
        Register-ClassManagerEvents -UiRefs $refs -ContentPanel $ContentPanel

        return $refs
    }
    finally {
        $ContentPanel.ResumeLayout($true)
    }
}





# ─────────────────────────  Data-to-UI binder  ───────────────────────────────
function Update-ClassManagerWithData {
    <#
    .SYNOPSIS
        Pushes all collected data sets into the corresponding UI controls.
    #>
    [CmdletBinding()]
    param(
        [hashtable] $UiRefs,
        [hashtable] $Data
    )


    # Populate combos/lists
    $UiRefs.Tabs['Advanced']['TemplateComboBox'].Items.Clear()
    $UiRefs.Tabs['Advanced']['TemplateComboBox'].Items.AddRange($Data.Templates)

    $UiRefs.Tabs['Advanced']['DatastoreComboBox'].Items.Clear()
    $UiRefs.Tabs['Advanced']['DatastoreComboBox'].Items.AddRange($Data.Datastores)

    $clb = $UiRefs.Tabs['Advanced']['NetworkListBox']
    $clb.Items.Clear()
    $clb.Items.AddRange($Data.Networks)

    $cmb = $UiRefs.Tabs['Advanced']['ClassComboBox']
    $cmb.Items.Clear()
    $cmb.Items.AddRange($Data.Classes)


    # Build overview tree
    $tree = $UiRefs.Tabs['Overview']['ClassTree']
    $tree.Nodes.Clear()

    foreach ($cls in $Data.Classes) {
        $clsNode = New-Object System.Windows.Forms.TreeNode($cls)

        $students = [CourseManager]::GetClassStudents($cls) -as [string[]]
        foreach ($stu in $students) {
            $stuNode = New-Object System.Windows.Forms.TreeNode($stu)

            $vms = [CourseManager]::GetStudentVMs($cls, $stu) -as [string[]]
            foreach ($vm in $vms) {
                $stuNode.Nodes.Add($vm) | Out-Null
            }

            $clsNode.Nodes.Add($stuNode) | Out-Null
        }

        $tree.Nodes.Add($clsNode) | Out-Null
    }

    # Update status
    $UiRefs['StatusLabel'].Text = "Data loaded at $($Data.LastUpdated.ToString('HH:mm:ss'))"
    $UiRefs['StatusLabel'].ForeColor = $script:Theme.Success
}





# ─────────────────────────  Event hooks  ─────────────────────────────────────
function Register-ClassManagerEvents {
    <#
    .SYNOPSIS
        Connects buttons & combo events to their handlers.
    #>
    [CmdletBinding()]
    param(
        $UiRefs,
        [System.Windows.Forms.Panel] $ContentPanel
    )



    # REFRESH button
    $UiRefs.Tabs['Overview']['RefreshButton'].Add_Click({
        Show-ClassesView -ContentPanel $ContentPanel
    })



    # CREATE FOLDERS button
    $UiRefs.Tabs['Basic']['CreateFoldersButton'].Add_Click({
        $className = $UiRefs.Tabs['Basic']['ClassNameTextBox'].Text.Trim()
        if ([string]::IsNullOrWhiteSpace($className)) {
            [System.Windows.Forms.MessageBox]::Show(
                'Please enter a class name first.',
                'Input Required',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
            return
        }

        try {
            $studentsText = $UiRefs.Tabs['Basic']['StudentsTextBox'].Text
            $students = $studentsText -split "`r`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
            
            # Create folders for each student
            $conn = $script:Connection
            if (-not $conn) { throw "Not connected to VMware server" }
            
            $parentFolder = Get-Folder -Server $conn -Name $className -ErrorAction SilentlyContinue
            if (-not $parentFolder) {
                $parentFolder = New-Folder -Server $conn -Name $className -Location (Get-Folder -Name 'vm') -ErrorAction Stop
            }
            
            foreach ($student in $students) {
                $folderName = "${className}_${student}"
                $studentFolder = Get-Folder -Server $conn -Name $folderName -ErrorAction SilentlyContinue
                if (-not $studentFolder) {
                    $studentFolder = New-Folder -Server $conn -Name $folderName -Location $parentFolder -ErrorAction Stop
                    
                    # Set permissions (if needed)
                    $account = Get-VIAccount -Server $conn -Name $folderName -Domain "CWU" -ErrorAction SilentlyContinue
                    if ($account) {
                        $role = Get-VIRole -Server $conn -Name "StudentUser" -ErrorAction SilentlyContinue
                        if ($role) {
                            New-VIPermission -Server $conn -Entity $studentFolder -Principal $account -Role $role -ErrorAction SilentlyContinue | Out-Null
                        }
                    }
                }
            }
            
            [System.Windows.Forms.MessageBox]::Show(
                "Folders created for $className",
                'Success',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
            
            # Refresh view
            Show-ClassesView -ContentPanel $ContentPanel
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show(
                "Failed to create folders: $($_.Exception.Message)",
                'Error',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
        }
    })




    # CLASS selection changed
    $UiRefs.Tabs['Advanced']['ClassComboBox'].Add_SelectedIndexChanged({
        $className = $UiRefs.Tabs['Advanced']['ClassComboBox'].SelectedItem
        if (-not $className) { return }

        try {
            $cfg = [CourseManager]::GetCourseConfig($className)
            if (-not $cfg) { throw "No configuration found for class $className" }
            
            # Update template and datastore
            $UiRefs.Tabs['Advanced']['TemplateComboBox'].SelectedItem = $cfg.servers[0].template
            $UiRefs.Tabs['Advanced']['DatastoreComboBox'].SelectedItem = $cfg.dataStore
            
            # Update networks
            $clb = $UiRefs.Tabs['Advanced']['NetworkListBox']
            for ($i = 0; $i -lt $clb.Items.Count; $i++) {
                $item = $clb.Items[$i]
                $clb.SetItemChecked($i, ($cfg.servers[0].adapters -contains $item))
            }
            
            # Update servers grid
            $grid = $UiRefs.Tabs['Advanced']['ServersGrid']
            $grid.Rows.Clear()
            
            foreach ($server in $cfg.servers) {
                $row = $grid.Rows.Add()
                $grid.Rows[$row].Cells[0].Value = $server.serverName
                $grid.Rows[$row].Cells[1].Value = $server.template
                $grid.Rows[$row].Cells[2].Value = ($server.adapters -join ',')
            }
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show(
                "Failed to load course configuration: $($_.Exception.Message)",
                'Error',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
        }
    })




    # CREATE VMs button
    $UiRefs.Tabs['Advanced']['CreateVMsButton'].Add_Click({
        $className = $UiRefs.Tabs['Advanced']['ClassComboBox'].SelectedItem
        if (-not $className) {
            [System.Windows.Forms.MessageBox]::Show('Please select a class first.', 'Input Required')
            return
        }

        # Build servers array from grid
        $servers = @()
        $grid = $UiRefs.Tabs['Advanced']['ServersGrid']
        
        foreach ($row in $grid.Rows) {
            if (-not $row.IsNewRow) {
                $servers += [PSCustomObject]@{
                    serverName = $row.Cells[0].Value
                    template = $row.Cells[1].Value
                    adapters = ($row.Cells[2].Value -split '\s*,\s*')
                    customization = $null
                }
            }
        }

        $courseInfo = [PSCustomObject]@{
            classFolder = $className
            dataStore = $UiRefs.Tabs['Advanced']['DatastoreComboBox'].SelectedItem
            servers = $servers
            students = [CourseManager]::GetClassStudents($className)
        }

        try {
            [CourseManager]::CreateCourseVMs($courseInfo)
            [System.Windows.Forms.MessageBox]::Show('VM creation started.', 'Success')
            
            # Refresh view after operation completes
            Start-Job -ScriptBlock {
                Start-Sleep -Seconds 5
                [System.Windows.Forms.Application]::DoEvents()
                Show-ClassesView -ContentPanel $script:ClassesContentPanel
            } | Out-Null
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show(
                "Failed to create VMs: $($_.Exception.Message)",
                'Error',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
        }
    })



    # DELETE CLASS button
    $UiRefs.Tabs['Advanced']['DeleteClassButton'].Add_Click({
        $className = $UiRefs.Tabs['Advanced']['ClassComboBox'].SelectedItem
        if (-not $className) {
            [System.Windows.Forms.MessageBox]::Show('Please select a class first.', 'Input Required')
            return
        }

        $confirm = [System.Windows.Forms.MessageBox]::Show(
            "Delete ALL VMs for class '$className'?",
            'Confirm Deletion',
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )

        if ($confirm -eq 'Yes') {
            try {
                [CourseManager]::RemoveCourseVMs($className, [CourseManager]::GetClassStudents($className))
                [System.Windows.Forms.MessageBox]::Show('Class deletion started.', 'Success')
                
                # Refresh view after operation completes
                Start-Job -ScriptBlock {
                    Start-Sleep -Seconds 5
                    [System.Windows.Forms.Application]::DoEvents()
                    Show-ClassesView -ContentPanel $script:ClassesContentPanel
                } | Out-Null
            }
            catch {
                [System.Windows.Forms.MessageBox]::Show(
                    "Failed to delete class: $($_.Exception.Message)",
                    'Error',
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Error
                )
            }
        }
    })
}