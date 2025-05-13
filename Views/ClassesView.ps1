# Required assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing



<#
    .SYNOPSIS
        Class Manager View for Course Manager.
    .DESCRIPTION
        Initializes the Class Manager UI with tabs for Dashboard, Basic Setup, and Advanced settings.
    .PARAMETER ContentPanel
        The Windows.Forms.Panel where this view is rendered.
#>
function Show-ClassesView {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Forms.Panel]$ContentPanel
    )
    try {
        $uiRefs = New-ClassManagerLayout -ContentPanel $ContentPanel
        $data = Get-ClassManagerData
        if ($data) {
            Update-ClassManagerWithData -UiRefs $uiRefs -Data $data
        } else {
            $uiRefs.StatusLabel.Text = 'No connection to VMware server'
            $uiRefs.StatusLabel.ForeColor = $global:Theme.Error
        }
    } catch {
        Write-Verbose "Class manager initialization failed: $_"
    }
}



<#
    .SYNOPSIS
        Creates the layout for the Class Manager UI.
    .DESCRIPTION
        Builds header, TabControl, and status panel using CWU theme colors.
    .PARAMETER ContentPanel
        The Windows.Forms.Panel to populate.
    .OUTPUTS
        Hashtable of UI element references.
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
        $ContentPanel.BackColor = $global:Theme.LightGray

        # Root layout: Header, Tabs, Status
        $root = [System.Windows.Forms.TableLayoutPanel]::new()
        $root.Dock = 'Fill'; 
        $root.ColumnCount = 1; 
        $root.RowCount = 3
        $root.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::AutoSize))   # Header
        $root.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Percent,100)) # Tabs
        $root.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::AutoSize))   # Status
        
        $ContentPanel.Controls.Add($root)

        # Header panel
        $header = [System.Windows.Forms.Panel]::new()
        $header.Dock = 'Fill'; 
        $header.Height = 80; 
        $header.BackColor = $global:Theme.Primary

        $root.Controls.Add($header,0,0)

        $title = [System.Windows.Forms.Label]::new()
        $title.Text = 'COURSE MANAGER'; 
        $title.Font = [System.Drawing.Font]::new('Segoe UI',18,[System.Drawing.FontStyle]::Bold)
        $title.ForeColor = $global:Theme.White; 
        $title.AutoSize = $true; 
        $title.Location = [System.Drawing.Point]::new(20,20)
        
        $header.Controls.Add($title)

        # TabControl for Dashboard, Basic, Advanced
        $tabControl = [System.Windows.Forms.TabControl]::new()
        $tabControl.Dock = 'Fill'; 
        $tabControl.ItemSize = [System.Drawing.Size]::new(150,40)
        $tabControl.SizeMode = 'Fixed'; 
        $tabControl.Font = [System.Drawing.Font]::new('Segoe UI',10,[System.Drawing.FontStyle]::Bold)
        
        $root.Controls.Add($tabControl,0,1)
        $refs = @{ TabControl = $tabControl; Tabs = @{} }

        # Dashboard Tab
        $tabDash = [System.Windows.Forms.TabPage]::new('Dashboard');
        $tabDash.BackColor = $global:Theme.White

        $tabControl.TabPages.Add($tabDash);
        $refs.Tabs.Dashboard = @{}

        # Tree view for classes
        $dashLayout = [System.Windows.Forms.TableLayoutPanel]::new(); 
        $dashLayout.Dock = 'Fill';
        $dashLayout.RowCount = 2
        $dashLayout.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Percent,100))
        $dashLayout.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::AutoSize))
        
        $tabDash.Controls.Add($dashLayout)
        
        $tree = [System.Windows.Forms.TreeView]::new(); 
        $tree.Dock = 'Fill'; 
        $tree.BackColor = $global:Theme.White; 
        $tree.ForeColor = $global:Theme.PrimaryDark

        $dashLayout.Controls.Add($tree,0,0); 
        $refs.Tabs.Dashboard.ClassTree = $tree

        $dashButtons = [System.Windows.Forms.FlowLayoutPanel]::new(); 
        $dashButtons.Dock='Fill'; 
        $dashButtons.BackColor = $global:Theme.White; 
        $dashButtons.Padding = [System.Windows.Forms.Padding]::new(5)

        $dashLayout.Controls.Add($dashButtons,0,1)

        $btnRefresh = [System.Windows.Forms.Button]::new(); 
        $btnRefresh.Text = 'REFRESH'; 
        $btnRefresh.Size = [System.Drawing.Size]::new(120,40)
        $btnRefresh.Font = [System.Drawing.Font]::new('Segoe UI',10,[System.Drawing.FontStyle]::Bold); 
        $btnRefresh.BackColor = $global:Theme.Primary; 
        $btnRefresh.ForeColor = $global:Theme.White
        $dashButtons.Controls.Add($btnRefresh); 
        $refs.Tabs.Dashboard.RefreshButton = $btnRefresh

        # Basic Setup Tab
        $tabBasic = [System.Windows.Forms.TabPage]::new('Basic Setup'); 
        $tabBasic.BackColor = $global:Theme.White
        $tabControl.TabPages.Add($tabBasic); 

        $refs.Tabs.Basic = @{}

        $basicLayout = [System.Windows.Forms.TableLayoutPanel]::new(); 
        $basicLayout.Dock = 'Fill'; 
        $basicLayout.RowCount = 3
        $basicLayout.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::AutoSize))
        $basicLayout.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Percent,100))
        $basicLayout.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::AutoSize))
        
        $tabBasic.Controls.Add($basicLayout)

        # Inputs panel
        $basicContent = [System.Windows.Forms.TableLayoutPanel]::new(); 
        $basicContent.Dock = 'Fill'; 
        $basicContent.ColumnCount = 2; 
        $basicContent.RowCount = 2
        $basicContent.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Percent,30))
        $basicContent.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Percent,70))
        
        $basicLayout.Controls.Add($basicContent,0,1)

        # Class name
        $lblNew = [System.Windows.Forms.Label]::new(); 
        $lblNew.Text = 'Class Name:'; 
        $lblNew.Font = [System.Drawing.Font]::new('Segoe UI',10)
        $lblNew.Dock = 'Fill'; 
        $lblNew.TextAlign = 'MiddleRight';

        $basicContent.Controls.Add($lblNew,0,0)

        $txtNew = [System.Windows.Forms.TextBox]::new(); 
        $txtNew.Dock = 'Fill'; 
        $txtNew.BackColor = $global:Theme.White; 

        $basicContent.Controls.Add($txtNew,1,0); 
        $refs.Tabs.Basic.NewClassTextBox = $txtNew

        # Students list
        $lblStud = [System.Windows.Forms.Label]::new(); 
        $lblStud.Text = 'Students:'; 
        $lblStud.Font = [System.Drawing.Font]::new('Segoe UI',10)
        $lblStud.Dock = 'Fill'; 
        $lblStud.TextAlign = 'MiddleRight'; 

        $basicContent.Controls.Add($lblStud,0,1)

        $txtStud = [System.Windows.Forms.TextBox]::new(); 
        $txtStud.Multiline = $true; 
        $txtStud.ScrollBars = 'Vertical'; 
        $txtStud.Dock = 'Fill'; 
        $txtStud.BackColor = $global:Theme.White
        
        $basicContent.Controls.Add($txtStud,1,1); 
        $refs.Tabs.Basic.StudentsTextBox = $txtStud

        # Basic buttons
        $basicButtons = [System.Windows.Forms.FlowLayoutPanel]::new(); 
        $basicButtons.Dock = 'Fill'; 
        $basicButtons.BackColor = $global:Theme.White; 
        $basicButtons.Padding = [System.Windows.Forms.Padding]::new(5)
        
        $basicLayout.Controls.Add($basicButtons,0,2)
        
        $btnCreate = [System.Windows.Forms.Button]::new(); 
        $btnCreate.Text = 'CREATE FOLDERS'; 
        $btnCreate.Size = [System.Drawing.Size]::new(150,40)
        $btnCreate.Font = [System.Drawing.Font]::new('Segoe UI',10,[System.Drawing.FontStyle]::Bold); 
        $btnCreate.BackColor = $global:Theme.Primary; 
        $btnCreate.ForeColor = $global:Theme.White
        
        $basicButtons.Controls.Add($btnCreate); 
        $refs.Tabs.Basic.CreateFoldersButton = $btnCreate

        # Advanced Tab
        $tabAdv = [System.Windows.Forms.TabPage]::new('Advanced'); 
        $tabAdv.BackColor = $global:Theme.White

        $tabControl.TabPages.Add($tabAdv); 
        $refs.Tabs.Advanced = @{}

        $advLayout = [System.Windows.Forms.TableLayoutPanel]::new(); 
        $advLayout.Dock = 'Fill'; 
        $advLayout.RowCount = 3
        $advLayout.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::AutoSize))
        $advLayout.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Percent,100))
        $advLayout.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::AutoSize))
        
        $tabAdv.Controls.Add($advLayout)

        # Advanced content
        $advContent = [System.Windows.Forms.TableLayoutPanel]::new(); 
        $advContent.Dock = 'Fill'; 
        $advContent.ColumnCount = 2; 
        $advContent.RowCount = 4
        $advContent.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Percent,30))
        $advContent.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Percent,70))
        
        $advLayout.Controls.Add($advContent,0,1)

        # Class combo
        $lblClass = [System.Windows.Forms.Label]::new(); 
        $lblClass.Text = 'Class:'; 
        $lblClass.Font = [System.Drawing.Font]::new('Segoe UI',10)
        $lblClass.Dock = 'Fill'; 
        $lblClass.TextAlign = 'MiddleRight';

        $advContent.Controls.Add($lblClass,0,0)

        $cmbClass = [System.Windows.Forms.ComboBox]::new(); 
        $cmbClass.Dock = 'Fill'; 
        $cmbClass.BackColor = $global:Theme.White; 

        $advContent.Controls.Add($cmbClass,1,0)
        $refs.Tabs.Advanced.ClassComboBox = $cmbClass

        # Template combo
        $lblTemp = [System.Windows.Forms.Label]::new(); 
        $lblTemp.Text = 'Template:'; 
        $lblTemp.Font = [System.Drawing.Font]::new('Segoe UI',10)
        $lblTemp.Dock = 'Fill'; 
        $lblTemp.TextAlign = 'MiddleRight'; 

        $advContent.Controls.Add($lblTemp,0,1)

        $cmbTemp = [System.Windows.Forms.ComboBox]::new(); 
        $cmbTemp.Dock = 'Fill'; 
        $cmbTemp.BackColor = $global:Theme.White;

        $advContent.Controls.Add($cmbTemp,1,1)
        $refs.Tabs.Advanced.TemplateComboBox = $cmbTemp

        # Datastore combo
        $lblStore = [System.Windows.Forms.Label]::new(); 
        $lblStore.Text = 'Datastore:'; 
        $lblStore.Font = [System.Drawing.Font]::new('Segoe UI',10)
        $lblStore.Dock = 'Fill'; 
        $lblStore.TextAlign = 'MiddleRight';

        $advContent.Controls.Add($lblStore,0,2)

        $cmbStore = [System.Windows.Forms.ComboBox]::new(); 
        $cmbStore.Dock = 'Fill'; 
        $cmbStore.BackColor = $global:Theme.White;

        $advContent.Controls.Add($cmbStore,1,2)
        $refs.Tabs.Advanced.DatastoreComboBox = $cmbStore

        # Networks list
        $lblNet = [System.Windows.Forms.Label]::new(); 
        $lblNet.Text = 'Networks:'; 
        $lblNet.Font = [System.Drawing.Font]::new('Segoe UI',10)
        $lblNet.Dock = 'Fill'; 
        $lblNet.TextAlign = 'MiddleRight';

        $advContent.Controls.Add($lblNet,0,3)

        $clbNet = [System.Windows.Forms.CheckedListBox]::new(); 
        $clbNet.CheckOnClick = $true; 
        $clbNet.BackColor = $global:Theme.White;

        $advContent.Controls.Add($clbNet,1,3)
        $refs.Tabs.Advanced.NetworkListBox = $clbNet

        # Advanced buttons
        $advButtons = [System.Windows.Forms.FlowLayoutPanel]::new(); 
        $advButtons.Dock = 'Fill'; 
        $advButtons.BackColor = $global:Theme.White; 
        $advButtons.Padding = [System.Windows.Forms.Padding]::new(5)

        $advLayout.Controls.Add($advButtons,0,2)

        $btnCreateVMs = [System.Windows.Forms.Button]::new();
        $btnCreateVMs.Text = 'CREATE VMs';
        $btnCreateVMs.Size = [System.Drawing.Size]::new(150,40)
        $btnCreateVMs.Font = [System.Drawing.Font]::new('Segoe UI',10,[System.Drawing.FontStyle]::Bold);
        $btnCreateVMs.BackColor = $global:Theme.Primary; 
        $btnCreateVMs.ForeColor = $global:Theme.White

        $advButtons.Controls.Add($btnCreateVMs);
        $refs.Tabs.Advanced.CreateVMsButton = $btnCreateVMs

        $btnDelete = [System.Windows.Forms.Button]::new();
        $btnDelete.Text = 'DELETE CLASS';
        $btnDelete.Size = [System.Drawing.Size]::new(150,40)
        $btnDelete.Font = [System.Drawing.Font]::new('Segoe UI',10,[System.Drawing.FontStyle]::Bold);
        $btnDelete.BackColor = $global:Theme.Error; 
        $btnDelete.ForeColor = $global:Theme.White

        $advButtons.Controls.Add($btnDelete);
        $refs.Tabs.Advanced.DeleteClassButton = $btnDelete

        # Status panel
        $statusPanel = [System.Windows.Forms.Panel]::new();
        $statusPanel.Dock = 'Fill'; $statusPanel.Height = 30;
        $statusPanel.BackColor = $global:Theme.LightGray

        $root.Controls.Add($statusPanel,0,2)

        $statusLabel = [System.Windows.Forms.Label]::new();
        $statusLabel.Name = 'StatusLabel'; 
        $statusLabel.Text = 'DISCONNECTED'
        $statusLabel.Font = [System.Drawing.Font]::new('Segoe UI',9);
        $statusLabel.ForeColor = $global:Theme.PrimaryDark;
        $statusLabel.Dock = 'Fill';
        $statusLabel.TextAlign = 'MiddleLeft'

        $statusPanel.Controls.Add($statusLabel); 
        $refs.StatusLabel = $statusLabel

        return $refs
    } finally { 
        $ContentPanel.ResumeLayout($true) 
    }
}



<#
    .SYNOPSIS
        Fetches class manager data from VMware and CourseManager.
    .DESCRIPTION
        Retrieves templates, datastores, networks, and classes.
    .OUTPUTS
        Hashtable with data and LastUpdated timestamp.
#>
function Get-ClassManagerData {
    [CmdletBinding()]
    param()
    try {
        $conn = [VMServerConnection]::GetInstance().GetConnection()
        if(-not $conn){return $null}

        $data = @{ Templates = @(); Datastores = @(); Networks = @(); Classes = @(); LastUpdated = Get-Date }

        $data.Templates = (Get-Template -Server $conn -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name)
        $data.Datastores = (Get-Datastore -Server $conn -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name)
        $data.Networks = [VMwareNetwork]::ListPortGroups() | Select-Object -ExpandProperty Name
        $data.Classes = [CourseManager]::ListClasses()

        return $data

    } catch { 
        Write-Verbose "Class manager data collection failed: $_"; 
        return $null 
    }
}



<#
.SYNOPSIS
    Updates the Class Manager UI with new data.
.PARAMETER UiRefs
    Hashtable of UI references.
.PARAMETER Data
    Hashtable containing the latest data.
#>
function Update-ClassManagerWithData {
    [CmdletBinding()]
    param([hashtable]$UiRefs,[hashtable]$Data)

    try {
        # Populate Advanced dropdowns
        $UiRefs.Tabs.Advanced.TemplateComboBox.Items.Clear(); 
        $UiRefs.Tabs.Advanced.TemplateComboBox.Items.AddRange($Data.Templates)

        $UiRefs.Tabs.Advanced.DatastoreComboBox.Items.Clear();
        $UiRefs.Tabs.Advanced.DatastoreComboBox.Items.AddRange($Data.Datastores)

        $UiRefs.Tabs.Advanced.NetworkListBox.Items.Clear(); 
        $UiRefs.Tabs.Advanced.NetworkListBox.Items.AddRange($Data.Networks)

        $UiRefs.Tabs.Advanced.ClassComboBox.Items.Clear(); 
        $UiRefs.Tabs.Advanced.ClassComboBox.Items.AddRange($Data.Classes)

        # Populate Dashboard tree
        $UiRefs.Tabs.Dashboard.ClassTree.Nodes.Clear()

        foreach($class in $Data.Classes){
            $classNode = [System.Windows.Forms.TreeNode]::new($class)
            $students = [CourseManager]::GetClassStudents($class) -as [string[]]

            foreach($student in $students){
                $studNode = [System.Windows.Forms.TreeNode]::new($student)
                $vms = [CourseManager]::GetStudentVMs($class,$student) -as [string[]]

                foreach($vm in $vms){ $studNode.Nodes.Add($vm) }

                $classNode.Nodes.Add($studNode)
            }

            $UiRefs.Tabs.Dashboard.ClassTree.Nodes.Add($classNode)
        }
        $UiRefs.StatusLabel.Text = "Data loaded at $($Data.LastUpdated.ToString('HH:mm:ss'))"

    } catch { 
        Write-Verbose "Failed to update class manager view: $_"; 
        $UiRefs.StatusLabel.Text = 'Error loading data' 
    }
}