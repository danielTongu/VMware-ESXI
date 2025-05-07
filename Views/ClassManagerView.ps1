<#
.SYNOPSIS
    Enhanced Class Management View with tabbed interface.
.DESCRIPTION
    Provides comprehensive class VM management with:
      - Dashboard view of existing classes
      - Basic class creation tab
      - Advanced VM configuration tab
      - Batch VM creation and deletion
    Honors global login and offline flags.
.PARAMETER ContentPanel
    The Panel control where this view is rendered.
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Show-ClassManagerView {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][System.Windows.Forms.Panel]$ContentPanel
    )

    # Safe connection helper
    function Get-ConnectionSafe {
        if (-not $global:IsLoggedIn) {
            Write-Warning 'Not logged in: class operations disabled.'
            return $null
        }
        if ($global:VMwareConfig.OfflineMode -or -not $global:VMwareConfig.Connection) {
            Write-Warning 'Offline mode: cannot establish connection.'
            return $null
        }
        return $global:VMwareConfig.Connection
    }

    # Clear UI
    $ContentPanel.Controls.Clear()
    $ContentPanel.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle

    # Main tab control
    $tabControl = [System.Windows.Forms.TabControl]::new()
    $tabControl.Dock = 'Fill'
    $tabControl.Font = [System.Drawing.Font]::new('Segoe UI', 12)
    $tabControl.BackColor = $global:theme.Background
    $ContentPanel.Controls.Add($tabControl)

    # Initialize dropdown data safely
    $conn = Get-ConnectionSafe
    $templates = @(); $datastores = @(); $networks = @(); $classes = @()
    if ($conn) {
        try {
            $templates = Get-Template -Server $conn | Select-Object -ExpandProperty Name
            $datastores = Get-Datastore -Server $conn | Select-Object -ExpandProperty Name
            $networks = [VMwareNetwork]::ListPortGroups() | Select-Object -ExpandProperty Name
            $classes  = [CourseManager]::ListClasses()
        } catch {
            Write-Warning "Initialization failed: $_"
        }
    }

    # --- Dashboard Tab ---
    $tabDashboard = [System.Windows.Forms.TabPage]::new()
    $tabDashboard.Text = "Dashboard"
    $tabDashboard.BackColor = $global:theme.Background
    
    $tabControl.Controls.Add($tabDashboard)

    # Dashboard scrollable panel
    $dashboardPanel = [System.Windows.Forms.Panel]::new()
    $dashboardPanel.Dock = 'Fill'
    $dashboardPanel.AutoScroll = $true
    $dashboardPanel.BackColor = $global:theme.Background
    $tabDashboard.Controls.Add($dashboardPanel)

    # Dashboard header
    $lblDashboardHeader = [System.Windows.Forms.Label]::new()
    $lblDashboardHeader.Text = 'Class Dashboard'
    $lblDashboardHeader.Font = [System.Drawing.Font]::new('Segoe UI', 18, [System.Drawing.FontStyle]::Bold)
    $lblDashboardHeader.Location = [System.Drawing.Point]::new(20, 20)
    $lblDashboardHeader.AutoSize = $true
    $lblDashboardHeader.ForeColor = $global:theme.Primary
    $dashboardPanel.Controls.Add($lblDashboardHeader)

    # Offline/banner
    if (-not $global:IsLoggedIn -or $global:VMwareConfig.OfflineMode) {
        $lblOffline = [System.Windows.Forms.Label]::new()
        $lblOffline.Text = 'OFFLINE or not logged in: operations disabled'
        $lblOffline.Font = [System.Drawing.Font]::new('Segoe UI', 12, [System.Drawing.FontStyle]::Italic)
        $lblOffline.ForeColor = $global:theme.Warning
        $lblOffline.AutoSize = $true
        $lblOffline.Location = [System.Drawing.Point]::new(250, 28)
        $dashboardPanel.Controls.Add($lblOffline)
    }

    # Class tree view
    $treeClasses = [System.Windows.Forms.TreeView]::new()
    $treeClasses.Location = [System.Drawing.Point]::new(20, 70)
    $treeClasses.Size = [System.Drawing.Size]::new(400, 400)
    $treeClasses.Font = [System.Drawing.Font]::new('Segoe UI', 10)
    $treeClasses.BackColor = [System.Drawing.Color]::White
    $treeClasses.ForeColor = $global:theme.TextPrimary
    $dashboardPanel.Controls.Add($treeClasses)

    # Populate tree view
    foreach ($class in $classes) {
        $classNode = [System.Windows.Forms.TreeNode]::new($class)
        $students = [CourseManager]::GetClassStudents($class)
        
        foreach ($student in $students) {
            $studentNode = [System.Windows.Forms.TreeNode]::new($student)
            $vms = [CourseManager]::GetStudentVMs($class, $student)
            
            foreach ($vm in $vms) {
                $vmNode = [System.Windows.Forms.TreeNode]::new($vm)
                $studentNode.Nodes.Add($vmNode)
            }
            
            $classNode.Nodes.Add($studentNode)
        }
        
        $treeClasses.Nodes.Add($classNode)
    }

    # Refresh button for dashboard
    $btnRefreshDashboard = [System.Windows.Forms.Button]::new()
    $btnRefreshDashboard.Text = 'Refresh'
    $btnRefreshDashboard.Font = [System.Drawing.Font]::new('Segoe UI', 12)
    $btnRefreshDashboard.Size = [System.Drawing.Size]::new(120, 40)
    $btnRefreshDashboard.Location = [System.Drawing.Point]::new(20, 480)
    $btnRefreshDashboard.BackColor = $global:theme.Background
    $btnRefreshDashboard.ForeColor = $global:theme.Primary
    $btnRefreshDashboard.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnRefreshDashboard.FlatAppearance.BorderColor = $global:theme.Primary
    $btnRefreshDashboard.FlatAppearance.BorderSize = 1
    $btnRefreshDashboard.Add_Click({
        $treeClasses.Nodes.Clear()
        $classes = [CourseManager]::ListClasses()
        foreach ($class in $classes) {
            $classNode = [System.Windows.Forms.TreeNode]::new($class)
            $students = [CourseManager]::GetClassStudents($class)
            
            foreach ($student in $students) {
                $studentNode = [System.Windows.Forms.TreeNode]::new($student)
                $vms = [CourseManager]::GetStudentVMs($class, $student)
                
                foreach ($vm in $vms) {
                    $vmNode = [System.Windows.Forms.TreeNode]::new($vm)
                    $studentNode.Nodes.Add($vmNode)
                }
                
                $classNode.Nodes.Add($studentNode)
            }
            
            $treeClasses.Nodes.Add($classNode)
        }
    })
    $dashboardPanel.Controls.Add($btnRefreshDashboard)

    # --- Basic Tab ---
    $tabBasic = [System.Windows.Forms.TabPage]::new()
    $tabBasic.Text = "Basic"
    $tabBasic.BackColor = $global:theme.Background
    $tabControl.Controls.Add($tabBasic)

    # Basic scrollable panel
    $basicPanel = [System.Windows.Forms.Panel]::new()
    $basicPanel.Dock = 'Fill'
    $basicPanel.AutoScroll = $true
    $basicPanel.BackColor = $global:theme.Background
    $tabBasic.Controls.Add($basicPanel)

    # Basic header
    $lblBasicHeader = [System.Windows.Forms.Label]::new()
    $lblBasicHeader.Text = 'Basic Class Setup'
    $lblBasicHeader.Font = [System.Drawing.Font]::new('Segoe UI', 18, [System.Drawing.FontStyle]::Bold)
    $lblBasicHeader.Location = [System.Drawing.Point]::new(20, 20)
    $lblBasicHeader.AutoSize = $true
    $lblBasicHeader.ForeColor = $global:theme.Primary
    $basicPanel.Controls.Add($lblBasicHeader)

    # Section styling variables
    $sectionLeft = 20
    $controlLeft = 200
    $controlWidth = 300
    $verticalSpacing = 35
    $currentY = 70

    # New class name
    $lblNew = [System.Windows.Forms.Label]::new()
    $lblNew.Text = 'New Class Name:'
    $lblNew.Font = [System.Drawing.Font]::new('Segoe UI', 12)
    $lblNew.Location = [System.Drawing.Point]::new($sectionLeft, $currentY)
    $lblNew.AutoSize = $true
    $lblNew.ForeColor = $global:theme.TextPrimary
    $basicPanel.Controls.Add($lblNew)

    $txtNew = [System.Windows.Forms.TextBox]::new()
    $txtNew.Font = [System.Drawing.Font]::new('Segoe UI', 12)
    $txtNew.Location = [System.Drawing.Point]::new($controlLeft, $currentY - 3)
    $txtNew.Size = [System.Drawing.Size]::new($controlWidth, 30)
    $txtNew.BackColor = [System.Drawing.Color]::White
    $txtNew.ForeColor = $global:theme.TextPrimary
    $basicPanel.Controls.Add($txtNew)
    $currentY += $verticalSpacing

    # Students list
    $lblStud = [System.Windows.Forms.Label]::new()
    $lblStud.Text = 'Students (one per line):'
    $lblStud.Font = [System.Drawing.Font]::new('Segoe UI', 12)
    $lblStud.Location = [System.Drawing.Point]::new($sectionLeft, $currentY)
    $lblStud.AutoSize = $true
    $lblStud.ForeColor = $global:theme.TextPrimary
    $basicPanel.Controls.Add($lblStud)

    $txtStud = [System.Windows.Forms.TextBox]::new()
    $txtStud.Font = [System.Drawing.Font]::new('Segoe UI', 12)
    $txtStud.Location = [System.Drawing.Point]::new($controlLeft, $currentY - 3)
    $txtStud.Size = [System.Drawing.Size]::new($controlWidth, 150)
    $txtStud.Multiline = $true
    $txtStud.ScrollBars = 'Vertical'
    $txtStud.BackColor = [System.Drawing.Color]::White
    $txtStud.ForeColor = $global:theme.TextPrimary
    $basicPanel.Controls.Add($txtStud)
    $currentY += 160

    # Create Folders button
    $btnCreateF = [System.Windows.Forms.Button]::new()
    $btnCreateF.Text = 'Create Folders'
    $btnCreateF.Font = [System.Drawing.Font]::new('Segoe UI', 12)
    $btnCreateF.Size = [System.Drawing.Size]::new(150, 40)
    $btnCreateF.Location = [System.Drawing.Point]::new($sectionLeft, $currentY)
    $btnCreateF.BackColor = $global:theme.Background
    $btnCreateF.ForeColor = $global:theme.Primary
    $btnCreateF.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnCreateF.FlatAppearance.BorderColor = $global:theme.Primary
    $btnCreateF.FlatAppearance.BorderSize = 1
    $btnCreateF.Add_Click({
        $conn = Get-ConnectionSafe
        if (!$conn) { 
            [System.Windows.Forms.MessageBox]::Show('Offline or not authenticated', 'Error', 'OK', 'Error')
            return 
        }
        try {
            $name = $txtNew.Text.Trim()
            $stud = $txtStud.Lines | Where { $_.Trim() }
            if (-not $name) { throw 'Class name cannot be empty' }
            if (-not $stud) { throw 'No students provided' }
            
            [CourseManager]::CreateClassFolders($name, $stud)
            [System.Windows.Forms.MessageBox]::Show("Folders created successfully for class '$name'", 'Success', 'OK', 'Information')
            
            # Update dashboard
            $treeClasses.Nodes.Clear()
            $classes = [CourseManager]::ListClasses()
            foreach ($class in $classes) {
                $classNode = [System.Windows.Forms.TreeNode]::new($class)
                $students = [CourseManager]::GetClassStudents($class)
                
                foreach ($student in $students) {
                    $studentNode = [System.Windows.Forms.TreeNode]::new($student)
                    $classNode.Nodes.Add($studentNode)
                }
                
                $treeClasses.Nodes.Add($classNode)
            }
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Error creating folders: $_", 'Error', 'OK', 'Error')
        }
    })
    $basicPanel.Controls.Add($btnCreateF)

    # --- Advanced Tab ---
    $tabAdvanced = [System.Windows.Forms.TabPage]::new()
    $tabAdvanced.Text = "Advanced"
    $tabAdvanced.BackColor = $global:theme.Background
    $tabControl.Controls.Add($tabAdvanced)

    # Advanced scrollable panel
    $advancedPanel = [System.Windows.Forms.Panel]::new()
    $advancedPanel.Dock = 'Fill'
    $advancedPanel.AutoScroll = $true
    $advancedPanel.BackColor = $global:theme.Background
    $tabAdvanced.Controls.Add($advancedPanel)

    # Advanced header
    $lblAdvancedHeader = [System.Windows.Forms.Label]::new()
    $lblAdvancedHeader.Text = 'Advanced VM Configuration'
    $lblAdvancedHeader.Font = [System.Drawing.Font]::new('Segoe UI', 18, [System.Drawing.FontStyle]::Bold)
    $lblAdvancedHeader.Location = [System.Drawing.Point]::new(20, 20)
    $lblAdvancedHeader.AutoSize = $true
    $lblAdvancedHeader.ForeColor = $global:theme.Primary
    $advancedPanel.Controls.Add($lblAdvancedHeader)

    $currentY = 70

    # Class selector
    $lblExist = [System.Windows.Forms.Label]::new()
    $lblExist.Text = 'Select Class:'
    $lblExist.Font = [System.Drawing.Font]::new('Segoe UI', 12)
    $lblExist.Location = [System.Drawing.Point]::new($sectionLeft, $currentY)
    $lblExist.AutoSize = $true
    $lblExist.ForeColor = $global:theme.TextPrimary
    $advancedPanel.Controls.Add($lblExist)

    $cmbClasses = [System.Windows.Forms.ComboBox]::new()
    $cmbClasses.Font = [System.Drawing.Font]::new('Segoe UI', 12)
    $cmbClasses.Location = [System.Drawing.Point]::new($controlLeft, $currentY - 3)
    $cmbClasses.Size = [System.Drawing.Size]::new($controlWidth, 30)
    $cmbClasses.DropDownStyle = 'DropDownList'
    $cmbClasses.Items.AddRange($classes)
    $advancedPanel.Controls.Add($cmbClasses)
    $currentY += $verticalSpacing

    # Template selection
    $lblTemp = [System.Windows.Forms.Label]::new()
    $lblTemp.Text = 'Template:'
    $lblTemp.Font = [System.Drawing.Font]::new('Segoe UI', 12)
    $lblTemp.Location = [System.Drawing.Point]::new($sectionLeft, $currentY)
    $lblTemp.AutoSize = $true
    $lblTemp.ForeColor = $global:theme.TextPrimary
    $advancedPanel.Controls.Add($lblTemp)

    $cmbTemp = [System.Windows.Forms.ComboBox]::new()
    $cmbTemp.Font = [System.Drawing.Font]::new('Segoe UI', 12)
    $cmbTemp.Location = [System.Drawing.Point]::new($controlLeft, $currentY - 3)
    $cmbTemp.Size = [System.Drawing.Size]::new($controlWidth, 30)
    $cmbTemp.DropDownStyle = 'DropDownList'
    $cmbTemp.Items.AddRange($templates)
    $advancedPanel.Controls.Add($cmbTemp)
    $currentY += $verticalSpacing

    # Datastore selection 
    $lblDs = [System.Windows.Forms.Label]::new()
    $lblDs.Text = 'Datastore:'
    $lblDs.Font = [System.Drawing.Font]::new('Segoe UI', 12)
    $lblDs.Location = [System.Drawing.Point]::new($sectionLeft, $currentY)
    $lblDs.AutoSize = $true
    $lblDs.ForeColor = $global:theme.TextPrimary
    $advancedPanel.Controls.Add($lblDs)

    $cmbDs = [System.Windows.Forms.ComboBox]::new()
    $cmbDs.Font = [System.Drawing.Font]::new('Segoe UI', 12)
    $cmbDs.Location = [System.Drawing.Point]::new($controlLeft, $currentY - 3)
    $cmbDs.Size = [System.Drawing.Size]::new($controlWidth, 30)
    $cmbDs.DropDownStyle = 'DropDownList'
    $cmbDs.Items.AddRange($datastores)
    $advancedPanel.Controls.Add($cmbDs)
    $currentY += $verticalSpacing

    # Network adapters
    $lblNet = [System.Windows.Forms.Label]::new()
    $lblNet.Text = 'Network Adapters:'
    $lblNet.Font = [System.Drawing.Font]::new('Segoe UI', 12)
    $lblNet.Location = [System.Drawing.Point]::new($sectionLeft, $currentY)
    $lblNet.AutoSize = $true
    $lblNet.ForeColor = $global:theme.TextPrimary
    $advancedPanel.Controls.Add($lblNet)

    $clb = [System.Windows.Forms.CheckedListBox]::new()
    $clb.Font = [System.Drawing.Font]::new('Segoe UI', 12)
    $clb.Location = [System.Drawing.Point]::new($controlLeft, $currentY - 3)
    $clb.Size = [System.Drawing.Size]::new($controlWidth, 100)
    $clb.CheckOnClick = $true
    $clb.Items.AddRange($networks)
    $clb.BackColor = [System.Drawing.Color]::White
    $clb.ForeColor = $global:theme.TextPrimary
    $advancedPanel.Controls.Add($clb)
    $adapters = @($clb)
    $currentY += 110

    # Create VMs button
    $btnCreateV = [System.Windows.Forms.Button]::new()
    $btnCreateV.Text = 'Create VMs'
    $btnCreateV.Font = [System.Drawing.Font]::new('Segoe UI', 12)
    $btnCreateV.Size = [System.Drawing.Size]::new(150, 40)
    $btnCreateV.Location = [System.Drawing.Point]::new($sectionLeft, $currentY)
    $btnCreateV.BackColor = $global:theme.Background
    $btnCreateV.ForeColor = $global:theme.Primary
    $btnCreateV.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnCreateV.FlatAppearance.BorderColor = $global:theme.Primary
    $btnCreateV.FlatAppearance.BorderSize = 1
    $btnCreateV.Add_Click({
        $conn = Get-ConnectionSafe
        if (!$conn) { 
            [System.Windows.Forms.MessageBox]::Show('Offline or not authenticated', 'Error', 'OK', 'Error')
            return 
        }
        try {
            $name = $cmbClasses.SelectedItem
            if (-not $name) { throw 'Please select a class' }
            
            $stud = [CourseManager]::GetClassStudents($name)
            if (-not $stud) { throw 'No students found for this class' }
            
            $tmpl = $cmbTemp.SelectedItem
            $ds = $cmbDs.SelectedItem
            if (-not $tmpl -or -not $ds) { throw 'Please select both template and datastore' }
            
            $nets = @()
            foreach ($a in $adapters) { $nets += $a.CheckedItems }
            if (-not $nets) { throw 'Please select at least one network adapter' }
            
            $config = [PSCustomObject]@{
                classFolder = $name
                students = $stud
                dataStore = $ds
                servers = @(@{
                    serverName = "$name`_VM"
                    template = $tmpl
                    adapters = $nets
                })
            }
            
            [CourseManager]::CreateCourseVMs($config)
            [System.Windows.Forms.MessageBox]::Show("VMs created successfully for class '$name'", 'Success', 'OK', 'Information')
            
            # Update dashboard
            $treeClasses.Nodes.Clear()
            $classes = [CourseManager]::ListClasses()
            foreach ($class in $classes) {
                $classNode = [System.Windows.Forms.TreeNode]::new($class)
                $students = [CourseManager]::GetClassStudents($class)
                
                foreach ($student in $students) {
                    $studentNode = [System.Windows.Forms.TreeNode]::new($student)
                    $vms = [CourseManager]::GetStudentVMs($class, $student)
                    
                    foreach ($vm in $vms) {
                        $vmNode = [System.Windows.Forms.TreeNode]::new($vm)
                        $studentNode.Nodes.Add($vmNode)
                    }
                    
                    $classNode.Nodes.Add($studentNode)
                }
                
                $treeClasses.Nodes.Add($classNode)
            }
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Error creating VMs: $_", 'Error', 'OK', 'Error')
        }
    })
    $advancedPanel.Controls.Add($btnCreateV)

    # Delete Class button
    $btnDeleteC = [System.Windows.Forms.Button]::new()
    $btnDeleteC.Text = 'Delete Class'
    $btnDeleteC.Font = [System.Drawing.Font]::new('Segoe UI', 12)
    $btnDeleteC.Size = [System.Drawing.Size]::new(150, 40)
    $btnDeleteC.Location = [System.Drawing.Point]::new($sectionLeft + 160, $currentY)
    $btnDeleteC.BackColor = $global:theme.Background
    $btnDeleteC.ForeColor = $global:theme.Error
    $btnDeleteC.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnDeleteC.FlatAppearance.BorderColor = $global:theme.Error
    $btnDeleteC.FlatAppearance.BorderSize = 1
    $btnDeleteC.Add_Click({
        $conn = Get-ConnectionSafe
        if (!$conn) { 
            [System.Windows.Forms.MessageBox]::Show('Offline or not authenticated', 'Error', 'OK', 'Error')
            return 
        }
        try {
            $name = $cmbClasses.SelectedItem
            if (-not $name) { throw 'Please select a class to delete' }
            
            $confirm = [System.Windows.Forms.MessageBox]::Show(
                "Are you sure you want to delete the entire class '$name' and all its VMs?",
                'Confirm Deletion',
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
            
            if ($confirm -eq 'Yes') {
                [CourseManager]::RemoveCourseVMs($name, $null)
                $cmbClasses.Items.Remove($name)
                
                # Update dashboard
                $treeClasses.Nodes.Clear()
                $classes = [CourseManager]::ListClasses()
                foreach ($class in $classes) {
                    $classNode = [System.Windows.Forms.TreeNode]::new($class)
                    $students = [CourseManager]::GetClassStudents($class)
                    
                    foreach ($student in $students) {
                        $studentNode = [System.Windows.Forms.TreeNode]::new($student)
                        $vms = [CourseManager]::GetStudentVMs($class, $student)
                        
                        foreach ($vm in $vms) {
                            $vmNode = [System.Windows.Forms.TreeNode]::new($vm)
                            $studentNode.Nodes.Add($vmNode)
                        }
                        
                        $classNode.Nodes.Add($studentNode)
                    }
                    
                    $treeClasses.Nodes.Add($classNode)
                }
                
                [System.Windows.Forms.MessageBox]::Show("Class '$name' deleted successfully", 'Success', 'OK', 'Information')
            }
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Error deleting class: $_", 'Error', 'OK', 'Error')
        }
    })
    $advancedPanel.Controls.Add($btnDeleteC)
}