Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing



# ────────────────────────────────────────────────────────────────────────────
#                       views/ClassManagerView.ps1
# ────────────────────────────────────────────────────────────────────────────



<#
    .SYNOPSIS
        Class Manager View for Course Manager

    .DESCRIPTION
        This script creates a UI for managing classes in VMware Course Manager.
        It includes tabs for Dashboard, Basic Setup, and Advanced settings.

    .PARAMETER ContentPanel
        The panel where the class manager UI will be displayed.

    .EXAMPLE
        Show-ClassManagerView -ContentPanel $mainPanel
        Displays the class manager UI in the specified content panel.
#>
function Show-ClassManagerView {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Forms.Panel]$ContentPanel
    )

    try {
        # Build UI (empty)
        $uiRefs = New-ClassManagerLayout -ContentPanel $ContentPanel

        # Populate with data if connected
        $data = Get-ClassManagerData
        if ($data) { Update-ClassManagerWithData -UiRefs $uiRefs -Data $data 
        } else {
            $uiRefs.StatusLabel.Text = "No connection to VMware server"
            $uiRefs.StatusLabel.ForeColor = $global:theme.Error
        }
    } catch { 
        Write-Verbose "Class manager initialization failed: $_" 
    }
}





<#
    .SYNOPSIS
        Creates the layout for the Class Manager UI.

    .DESCRIPTION
        This function sets up the layout for the Class Manager UI, including tabs,
        buttons, and labels. It returns a hashtable of UI references for further use.

    .PARAMETER ContentPanel
        The panel where the class manager UI will be displayed.

    .EXAMPLE
        $uiRefs = New-ClassManagerLayout -ContentPanel $mainPanel
        Creates the class manager layout and stores references in $uiRefs.
#>
function New-ClassManagerLayout {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Forms.Panel]$ContentPanel
    )

    try {
        $ContentPanel.SuspendLayout()
        $ContentPanel.Controls.Clear()
        $ContentPanel.BackColor = $global:theme.Background

        # ── ROOT LAYOUT (3 rows) ──────────────────────────────────────────────
        $root = New-Object System.Windows.Forms.TableLayoutPanel
        $root.Dock = 'Fill'
        $root.ColumnCount = 1
        $root.RowCount = 3
        $root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))   # Header
        $root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent,100))) # Tabs
        $root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))   # Status
        $ContentPanel.Controls.Add($root)


        
        #===== Row [1️] HEADER ==================================================
        $header = New-Object System.Windows.Forms.Panel
        $header.Dock = 'Fill'
        $header.Height = 80
        $header.BackColor = $global:theme.Primary
        $root.Controls.Add($header, 0, 0)

        $titleLabel = New-Object System.Windows.Forms.Label
        $titleLabel.Text = 'COURSE MANAGER'
        $titleLabel.Font = New-Object System.Drawing.Font('Segoe UI', 18, [System.Drawing.FontStyle]::Bold)
        $titleLabel.ForeColor = [System.Drawing.Color]::White
        $titleLabel.Location = New-Object System.Drawing.Point(20, 20)
        $titleLabel.AutoSize = $true
        $header.Controls.Add($titleLabel)



        #===== Row [2] TABCONTROL =============================================

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


        # ----------------------------------------------------------------
        # --- Dashboard Tab ----------------------------------------------
        # ----------------------------------------------------------------
        $tabDashboard = New-Object System.Windows.Forms.TabPage
        $tabDashboard.Text = "Dashboard"
        $tabDashboard.BackColor = $global:theme.Background
        $tabControl.TabPages.Add($tabDashboard)
        $refs.Tabs.Dashboard = @{}

        # Dashboard layout
        $dashboardLayout = New-Object System.Windows.Forms.TableLayoutPanel
        $dashboardLayout.Dock = 'Fill'
        $dashboardLayout.RowCount = 2
        $dashboardLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent,100)))
        $dashboardLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
        $tabDashboard.Controls.Add($dashboardLayout)

        # Class tree view
        $treeClasses = New-Object System.Windows.Forms.TreeView
        $treeClasses.Dock = 'Fill'
        $treeClasses.Font = New-Object System.Drawing.Font('Segoe UI', 10)
        $treeClasses.BackColor = $global:theme.CardBackground
        $treeClasses.ForeColor = $global:theme.TextPrimary
        $dashboardLayout.Controls.Add($treeClasses, 0, 0)
        $refs.Tabs.Dashboard.ClassTree = $treeClasses

        # Dashboard buttons panel
        $dashboardButtons = New-Object System.Windows.Forms.FlowLayoutPanel
        $dashboardButtons.Dock = 'Fill'
        $dashboardButtons.Padding = New-Object System.Windows.Forms.Padding(5)
        $dashboardButtons.BackColor = $global:theme.Background
        $dashboardLayout.Controls.Add($dashboardButtons, 0, 1)

        # Refresh button
        $btnRefresh = New-Object System.Windows.Forms.Button
        $btnRefresh.Name = 'btnRefresh'
        $btnRefresh.Text = 'REFRESH'
        $btnRefresh.Size = New-Object System.Drawing.Size(120, 40)
        $btnRefresh.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
        $btnRefresh.BackColor = $global:theme.Secondary
        $btnRefresh.ForeColor = [System.Drawing.Color]::White
        $dashboardButtons.Controls.Add($btnRefresh)
        $refs.Tabs.Dashboard.RefreshButton = $btnRefresh


        # -----------------------------------------------------------------
        # ---- Basic Tab --------------------------------------------------
        # -----------------------------------------------------------------
        $tabBasic = New-Object System.Windows.Forms.TabPage
        $tabBasic.Text = "Basic Setup"
        $tabBasic.BackColor = $global:theme.Background
        $tabControl.TabPages.Add($tabBasic)
        $refs.Tabs.Basic = @{}

        # Basic layout
        $basicLayout = New-Object System.Windows.Forms.TableLayoutPanel
        $basicLayout.Dock = 'Fill'
        $basicLayout.RowCount = 3
        $basicLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
        $basicLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent,100)))
        $basicLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
        $tabBasic.Controls.Add($basicLayout)

        # Basic content
        $basicContent = New-Object System.Windows.Forms.TableLayoutPanel
        $basicContent.Dock = 'Fill'
        $basicContent.ColumnCount = 2
        $basicContent.RowCount = 2
        $basicContent.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent,30)))
        $basicContent.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent,70)))
        $basicContent.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
        $basicContent.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent,100)))
        $basicLayout.Controls.Add($basicContent, 0, 1)

        # New class name
        $lblNewClass = New-Object System.Windows.Forms.Label
        $lblNewClass.Text = 'Class Name:'
        $lblNewClass.Font = New-Object System.Drawing.Font('Segoe UI', 10)
        $lblNewClass.Dock = 'Fill'
        $lblNewClass.TextAlign = 'MiddleRight'
        $basicContent.Controls.Add($lblNewClass, 0, 0)

        $txtNewClass = New-Object System.Windows.Forms.TextBox
        $txtNewClass.Font = New-Object System.Drawing.Font('Segoe UI', 10)
        $txtNewClass.Dock = 'Fill'
        $txtNewClass.BackColor = $global:theme.CardBackground
        $basicContent.Controls.Add($txtNewClass, 1, 0)
        $refs.Tabs.Basic.NewClassTextBox = $txtNewClass

        # Students list
        $lblStudents = New-Object System.Windows.Forms.Label
        $lblStudents.Text = 'Students:'
        $lblStudents.Font = New-Object System.Drawing.Font('Segoe UI', 10)
        $lblStudents.Dock = 'Fill'
        $lblStudents.TextAlign = 'MiddleRight'
        $basicContent.Controls.Add($lblStudents, 0, 1)

        $txtStudents = New-Object System.Windows.Forms.TextBox
        $txtStudents.Multiline = $true
        $txtStudents.ScrollBars = 'Vertical'
        $txtStudents.Font = New-Object System.Drawing.Font('Segoe UI', 10)
        $txtStudents.Dock = 'Fill'
        $txtStudents.BackColor = $global:theme.CardBackground
        $basicContent.Controls.Add($txtStudents, 1, 1)
        $refs.Tabs.Basic.StudentsTextBox = $txtStudents

        # Basic buttons panel
        $basicButtons = New-Object System.Windows.Forms.FlowLayoutPanel
        $basicButtons.Dock = 'Fill'
        $basicButtons.Padding = New-Object System.Windows.Forms.Padding(5)
        $basicButtons.BackColor = $global:theme.Background
        $basicLayout.Controls.Add($basicButtons, 0, 2)

        # Create Folders button
        $btnCreateFolders = New-Object System.Windows.Forms.Button
        $btnCreateFolders.Name = 'btnCreateFolders'
        $btnCreateFolders.Text = 'CREATE FOLDERS'
        $btnCreateFolders.Size = New-Object System.Drawing.Size(150, 40)
        $btnCreateFolders.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
        $btnCreateFolders.BackColor = $global:theme.Primary
        $btnCreateFolders.ForeColor = [System.Drawing.Color]::White
        $basicButtons.Controls.Add($btnCreateFolders)
        $refs.Tabs.Basic.CreateFoldersButton = $btnCreateFolders


        # -------------------------------------------------------------------
        # ---- Advanced Tab -------------------------------------------------
        # -------------------------------------------------------------------
        $tabAdvanced = New-Object System.Windows.Forms.TabPage
        $tabAdvanced.Text = "Advanced"
        $tabAdvanced.BackColor = $global:theme.Background
        $tabControl.TabPages.Add($tabAdvanced)
        $refs.Tabs.Advanced = @{}

        # Advanced layout
        $advancedLayout = New-Object System.Windows.Forms.TableLayoutPanel
        $advancedLayout.Dock = 'Fill'
        $advancedLayout.RowCount = 3
        $advancedLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
        $advancedLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent,100)))
        $advancedLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
        $tabAdvanced.Controls.Add($advancedLayout)

        # Advanced content
        $advancedContent = New-Object System.Windows.Forms.TableLayoutPanel
        $advancedContent.Dock = 'Fill'
        $advancedContent.ColumnCount = 2
        $advancedContent.RowCount = 4
        $advancedContent.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent,30)))
        $advancedContent.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent,70)))
        $advancedContent.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
        $advancedContent.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
        $advancedContent.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
        $advancedContent.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent,100)))
        $advancedLayout.Controls.Add($advancedContent, 0, 1)

        # Class selector
        $lblClassSelect = New-Object System.Windows.Forms.Label
        $lblClassSelect.Text = 'Class:'
        $lblClassSelect.Font = New-Object System.Drawing.Font('Segoe UI', 10)
        $lblClassSelect.Dock = 'Fill'
        $lblClassSelect.TextAlign = 'MiddleRight'
        $advancedContent.Controls.Add($lblClassSelect, 0, 0)

        $cmbClasses = New-Object System.Windows.Forms.ComboBox
        $cmbClasses.DropDownStyle = 'DropDownList'
        $cmbClasses.Font = New-Object System.Drawing.Font('Segoe UI', 10)
        $cmbClasses.Dock = 'Fill'
        $advancedContent.Controls.Add($cmbClasses, 1, 0)
        $refs.Tabs.Advanced.ClassComboBox = $cmbClasses

        # Template selector
        $lblTemplate = New-Object System.Windows.Forms.Label
        $lblTemplate.Text = 'Template:'
        $lblTemplate.Font = New-Object System.Drawing.Font('Segoe UI', 10)
        $lblTemplate.Dock = 'Fill'
        $lblTemplate.TextAlign = 'MiddleRight'
        $advancedContent.Controls.Add($lblTemplate, 0, 1)

        $cmbTemplate = New-Object System.Windows.Forms.ComboBox
        $cmbTemplate.DropDownStyle = 'DropDownList'
        $cmbTemplate.Font = New-Object System.Drawing.Font('Segoe UI', 10)
        $cmbTemplate.Dock = 'Fill'
        $advancedContent.Controls.Add($cmbTemplate, 1, 1)
        $refs.Tabs.Advanced.TemplateComboBox = $cmbTemplate

        # Datastore selector
        $lblDatastore = New-Object System.Windows.Forms.Label
        $lblDatastore.Text = 'Datastore:'
        $lblDatastore.Font = New-Object System.Drawing.Font('Segoe UI', 10)
        $lblDatastore.Dock = 'Fill'
        $lblDatastore.TextAlign = 'MiddleRight'
        $advancedContent.Controls.Add($lblDatastore, 0, 2)

        $cmbDatastore = New-Object System.Windows.Forms.ComboBox
        $cmbDatastore.DropDownStyle = 'DropDownList'
        $cmbDatastore.Font = New-Object System.Drawing.Font('Segoe UI', 10)
        $cmbDatastore.Dock = 'Fill'
        $advancedContent.Controls.Add($cmbDatastore, 1, 2)
        $refs.Tabs.Advanced.DatastoreComboBox = $cmbDatastore

        # Network adapters
        $lblNetworks = New-Object System.Windows.Forms.Label
        $lblNetworks.Text = 'Networks:'
        $lblNetworks.Font = New-Object System.Drawing.Font('Segoe UI', 10)
        $lblNetworks.Dock = 'Fill'
        $lblNetworks.TextAlign = 'MiddleRight'
        $advancedContent.Controls.Add($lblNetworks, 0, 3)

        $clbNetworks = New-Object System.Windows.Forms.CheckedListBox
        $clbNetworks.CheckOnClick = $true
        $clbNetworks.Font = New-Object System.Drawing.Font('Segoe UI', 10)
        $clbNetworks.Dock = 'Fill'
        $clbNetworks.BackColor = $global:theme.CardBackground
        $advancedContent.Controls.Add($clbNetworks, 1, 3)
        $refs.Tabs.Advanced.NetworkListBox = $clbNetworks

        # Advanced buttons panel
        $advancedButtons = New-Object System.Windows.Forms.FlowLayoutPanel
        $advancedButtons.Dock = 'Fill'
        $advancedButtons.Padding = New-Object System.Windows.Forms.Padding(5)
        $advancedButtons.BackColor = $global:theme.Background
        $advancedLayout.Controls.Add($advancedButtons, 0, 2)

        # Create VMs button
        $btnCreateVMs = New-Object System.Windows.Forms.Button
        $btnCreateVMs.Name = 'btnCreateVMs'
        $btnCreateVMs.Text = 'CREATE VMs'
        $btnCreateVMs.Size = New-Object System.Drawing.Size(150, 40)
        $btnCreateVMs.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
        $btnCreateVMs.BackColor = $global:theme.Primary
        $btnCreateVMs.ForeColor = [System.Drawing.Color]::White
        $advancedButtons.Controls.Add($btnCreateVMs)
        $refs.Tabs.Advanced.CreateVMsButton = $btnCreateVMs

        # Delete Class button
        $btnDeleteClass = New-Object System.Windows.Forms.Button
        $btnDeleteClass.Name = 'btnDeleteClass'
        $btnDeleteClass.Text = 'DELETE CLASS'
        $btnDeleteClass.Size = New-Object System.Drawing.Size(150, 40)
        $btnDeleteClass.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
        $btnDeleteClass.BackColor = $global:theme.Error
        $btnDeleteClass.ForeColor = [System.Drawing.Color]::White
        $advancedButtons.Controls.Add($btnDeleteClass)
        $refs.Tabs.Advanced.DeleteClassButton = $btnDeleteClass


        
        #===== Row [3] STATUS SECTION ====================================

        $statusPanel = New-Object System.Windows.Forms.Panel
        $statusPanel.Dock = 'Fill'
        $statusPanel.Height = 30
        $statusPanel.BackColor = $global:theme.Background
        $root.Controls.Add($statusPanel, 0, 2)

        $statusLabel = New-Object System.Windows.Forms.Label
        $statusLabel.Name = 'StatusLabel'
        $statusLabel.Text = 'DISCONNECTED'
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
        Fetches class manager data from VMware and CourseManager.

    .DESCRIPTION
        This function retrieves data such as templates, datastores, networks,
        and classes from the VMware server and CourseManager.

    .EXAMPLE
        $data = Get-ClassManagerData
        Retrieves class manager data and stores it in the $data variable.
#>
function Get-ClassManagerData {
    [CmdletBinding()]
    param()

    try {
        $conn = [VMServerConnection]::GetInstance().GetConnection()
        if (-not $conn) { return $null}
        
        # Initialize data structure
        $data = @{
            Templates = @()
            Datastores = @()
            Networks = @()
            Classes = @()
            LastUpdated = $null
        }

        # Fetch data from VMware and CourseManager
        $data.Templates = try { Get-Template -Server $conn | Select-Object -ExpandProperty Name } catch { @() }
        $data.Datastores = try { Get-Datastore -Server $conn | Select-Object -ExpandProperty Name } catch { @() }
        $data.Networks = try { [VMwareNetwork]::ListPortGroups() | Select-Object -ExpandProperty Name } catch { @() }
        $data.Classes = try { [CourseManager]::ListClasses() } catch { @() }
        $data.LastUpdated = (Get-Date)

        return $data
    } catch {
        Write-Verbose "Class manager data collection failed: $_"
        return $null
    }
}




<#
    .SYNOPSIS
        Updates the Class Manager UI with new data.

    .DESCRIPTION
        This function updates the dropdowns and tree view in the Class Manager UI
        with the latest data from VMware and CourseManager.

    .PARAMETER UiRefs
        A hashtable containing references to UI elements.

    .PARAMETER Data
        A hashtable containing the latest data for templates, datastores, networks,
        and classes.

    .EXAMPLE
        Update-ClassManagerWithData -UiRefs $uiRefs -Data $data
        Updates the class manager UI with the provided data.
#>
function Update-ClassManagerWithData {
    [CmdletBinding()]
    param(
        [hashtable]$UiRefs,
        [hashtable]$Data
    )

    try {
        # Update dropdowns in Advanced tab
        $UiRefs.Tabs.Advanced.TemplateComboBox.Items.Clear()
        $UiRefs.Tabs.Advanced.TemplateComboBox.Items.AddRange($Data.Templates)
        
        $UiRefs.Tabs.Advanced.DatastoreComboBox.Items.Clear()
        $UiRefs.Tabs.Advanced.DatastoreComboBox.Items.AddRange($Data.Datastores)
        
        $UiRefs.Tabs.Advanced.NetworkListBox.Items.Clear()
        $UiRefs.Tabs.Advanced.NetworkListBox.Items.AddRange($Data.Networks)
        
        $UiRefs.Tabs.Advanced.ClassComboBox.Items.Clear()
        $UiRefs.Tabs.Advanced.ClassComboBox.Items.AddRange($Data.Classes)

        # Update class tree in Dashboard tab
        $UiRefs.Tabs.Dashboard.ClassTree.Nodes.Clear()
        foreach ($class in $Data.Classes) {
            $classNode = New-Object System.Windows.Forms.TreeNode($class)
            $students = try { [CourseManager]::GetClassStudents($class) } catch { @() }
            
            foreach ($student in $students) {
                $studentNode = New-Object System.Windows.Forms.TreeNode($student)
                $vms = try { [CourseManager]::GetStudentVMs($class, $student) } catch { @() }
                
                foreach ($vm in $vms) {
                    $vmNode = New-Object System.Windows.Forms.TreeNode($vm)
                    $studentNode.Nodes.Add($vmNode)
                }
                
                $classNode.Nodes.Add($studentNode)
            }
            
            $UiRefs.Tabs.Dashboard.ClassTree.Nodes.Add($classNode)
        }

        $UiRefs.StatusLabel.Text = "Data loaded at $($Data.LastUpdated.ToString('HH:mm:ss'))"
    }
    catch {
        Write-Verbose "Failed to update class manager view: $_"
        $UiRefs.StatusLabel.Text = "Error loading data"
    }
}
