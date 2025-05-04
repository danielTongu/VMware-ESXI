<#
.SYNOPSIS
    Enhanced Class Management View, resilient to authentication and offline state.
.DESCRIPTION
    Provides comprehensive class VM management with:
      - Template and datastore selection
      - Multiple network adapter configuration
      - Batch VM creation and deletion for classes
      - Class folder management
    Honors global login and offline flags; operations are disabled when disconnected.
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

    # Main scrollable panel
    $main = [System.Windows.Forms.Panel]::new()
    $main.Dock = 'Fill'; $main.AutoScroll = $true
    $ContentPanel.Controls.Add($main)

    # Header
    $lblHeader = [System.Windows.Forms.Label]::new()
    $lblHeader.Text = 'Class Management'
    $lblHeader.Font = [System.Drawing.Font]::new('Segoe UI',16,[System.Drawing.FontStyle]::Bold)
    $lblHeader.Location = [System.Drawing.Point]::new(20,20)
    $lblHeader.AutoSize = $true
    $main.Controls.Add($lblHeader)

    # Offline/banner
    if (-not $global:IsLoggedIn -or $global:VMwareConfig.OfflineMode) {
        $lblOffline = [System.Windows.Forms.Label]::new()
        $lblOffline.Text = 'OFFLINE or not logged in: operations disabled'
        $lblOffline.Font = [System.Drawing.Font]::new('Segoe UI',10,[System.Drawing.FontStyle]::Italic)
        $lblOffline.ForeColor = [System.Drawing.Color]::DarkRed
        $lblOffline.AutoSize = $true
        $lblOffline.Location = [System.Drawing.Point]::new(300,24)
        $main.Controls.Add($lblOffline)
    }

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

    $y = 60
    # Existing class selector
    $lblExist = [System.Windows.Forms.Label]::new(); $lblExist.Text='Select Class:'; $lblExist.Location=[System.Drawing.Point]::new(20,$y); $lblExist.AutoSize=$true; $main.Controls.Add($lblExist)
    $cmbClasses = [System.Windows.Forms.ComboBox]::new(); $cmbClasses.Location=[System.Drawing.Point]::new(150,$y); $cmbClasses.Size=[System.Drawing.Size]::new(200,30); $cmbClasses.DropDownStyle='DropDownList'
    $cmbClasses.Items.AddRange($classes); $main.Controls.Add($cmbClasses)

    $y += 40
    # New class name
    $lblNew = [System.Windows.Forms.Label]::new(); $lblNew.Text='New Class Name:'; $lblNew.Location=[System.Drawing.Point]::new(20,$y); $lblNew.AutoSize=$true; $main.Controls.Add($lblNew)
    $txtNew = [System.Windows.Forms.TextBox]::new(); $txtNew.Location=[System.Drawing.Point]::new(150,$y); $txtNew.Size=[System.Drawing.Size]::new(200,30); $main.Controls.Add($txtNew)

    $y += 40
    # Students list
    $lblStud=[System.Windows.Forms.Label]::new(); $lblStud.Text='Students (one per line):'; $lblStud.Location=[System.Drawing.Point]::new(20,$y); $lblStud.AutoSize=$true; $main.Controls.Add($lblStud)
    $txtStud=[System.Windows.Forms.TextBox]::new(); $txtStud.Location=[System.Drawing.Point]::new(150,$y); $txtStud.Size=[System.Drawing.Size]::new(200,100); $txtStud.Multiline=$true; $txtStud.ScrollBars='Vertical'; $main.Controls.Add($txtStud)

    $y += 120
    # VM configuration header
    $lblCfg=[System.Windows.Forms.Label]::new(); $lblCfg.Text='VM Configuration'; $lblCfg.Location=[System.Drawing.Point]::new(20,$y); $lblCfg.Font=[System.Drawing.Font]::new('Segoe UI',10,[System.Drawing.FontStyle]::Bold); $lblCfg.AutoSize=$true; $main.Controls.Add($lblCfg)

    $y += 30
    # Template
    $lblTemp=[System.Windows.Forms.Label]::new(); $lblTemp.Text='Template:'; $lblTemp.Location=[System.Drawing.Point]::new(20,$y); $lblTemp.AutoSize=$true; $main.Controls.Add($lblTemp)
    $cmbTemp=[System.Windows.Forms.ComboBox]::new(); $cmbTemp.Location=[System.Drawing.Point]::new(150,$y); $cmbTemp.Size=[System.Drawing.Size]::new(200,30); $cmbTemp.DropDownStyle='DropDownList'; $cmbTemp.Items.AddRange($templates); $main.Controls.Add($cmbTemp)

    $y += 40
    # Datastore
    $lblDs=[System.Windows.Forms.Label]::new(); $lblDs.Text='Datastore:'; $lblDs.Location=[System.Drawing.Point]::new(20,$y); $lblDs.AutoSize=$true; $main.Controls.Add($lblDs)
    $cmbDs=[System.Windows.Forms.ComboBox]::new(); $cmbDs.Location=[System.Drawing.Point]::new(150,$y); $cmbDs.Size=[System.Drawing.Size]::new(200,30); $cmbDs.DropDownStyle='DropDownList'; $cmbDs.Items.AddRange($datastores); $main.Controls.Add($cmbDs)

    $y += 40
    # Network adapters
    $lblNet=[System.Windows.Forms.Label]::new(); $lblNet.Text='Network Adapters:'; $lblNet.Location=[System.Drawing.Point]::new(20,$y); $lblNet.AutoSize=$true; $main.Controls.Add($lblNet)
    $clb=[System.Windows.Forms.CheckedListBox]::new(); $clb.Location=[System.Drawing.Point]::new(150,$y); $clb.Size=[System.Drawing.Size]::new(200,80); $clb.CheckOnClick=$true; $clb.Items.AddRange($networks); $main.Controls.Add($clb)
    $adapters = @($clb)

    # Add adapter button
    $btnAddA=[System.Windows.Forms.Button]::new(); $btnAddA.Text='Add Adapter'; $btnAddA.Location=[System.Drawing.Point]::new(360,$y); $btnAddA.Size=[System.Drawing.Size]::new(100,30)
    $btnAddA.Add_Click({ $nb=[System.Windows.Forms.CheckedListBox]::new(); $nb.Location=[System.Drawing.Point]::new(150,$adapters[-1].Bottom+10); $nb.Size=$clb.Size; $nb.CheckOnClick=$true; $nb.Items.AddRange($networks); $main.Controls.Add($nb); $adapters+=$nb })
    $main.Controls.Add($btnAddA)

    $y += 100
    # Action buttons
    $btnCreateF=[System.Windows.Forms.Button]::new(); $btnCreateF.Text='Create Folders'; $btnCreateF.Location=[System.Drawing.Point]::new(20,$y); $btnCreateF.Size=[System.Drawing.Size]::new(120,40); $main.Controls.Add($btnCreateF)
    $btnCreateV=[System.Windows.Forms.Button]::new(); $btnCreateV.Text='Create VMs'; $btnCreateV.Location=[System.Drawing.Point]::new(150,$y); $btnCreateV.Size=[System.Drawing.Size]::new(120,40); $main.Controls.Add($btnCreateV)
    $btnDeleteC=[System.Windows.Forms.Button]::new(); $btnDeleteC.Text='Delete Class'; $btnDeleteC.Location=[System.Drawing.Point]::new(280,$y); $btnDeleteC.Size=[System.Drawing.Size]::new(120,40); $main.Controls.Add($btnDeleteC)
    $btnRefresh=[System.Windows.Forms.Button]::new(); $btnRefresh.Text='Refresh'; $btnRefresh.Location=[System.Drawing.Point]::new(410,$y); $btnRefresh.Size=[System.Drawing.Size]::new(120,40); $main.Controls.Add($btnRefresh)

    $y += 60
    $lblStatus=[System.Windows.Forms.Label]::new(); $lblStatus.Text='Ready'; $lblStatus.Location=[System.Drawing.Point]::new(20,$y); $lblStatus.AutoSize=$true; $main.Controls.Add($lblStatus)

    # -- Event handlers --
    $btnCreateF.Add_Click({
        $conn=Get-ConnectionSafe; if(!$conn){$lblStatus.Text='Offline/no auth';return}
        try{
            $name=$txtNew.Text.Trim(); $stud=$txtStud.Lines|Where{$_.Trim()}
            if(-not $name){throw 'Name empty'}; if(-not $stud){throw 'No students'}
            $lblStatus.Text='Creating folders...'; $main.Refresh()
            [CourseManager]::CreateClassFolders($name,$stud)
            if(-not $cmbClasses.Items.Contains($name)){ $cmbClasses.Items.Add($name) }
            $lblStatus.Text='Folders created'
        }catch{Write-Warning"CreateFolders failed: $_"; $lblStatus.Text='Error'}
    })
    $btnCreateV.Add_Click({
        $conn=Get-ConnectionSafe; if(!$conn){$lblStatus.Text='Offline/no auth';return}
        try{
            $name=$cmbClasses.SelectedItem; $stud=$txtStud.Lines|Where{$_.Trim()}
            if(-not $name){throw 'Select class'}; if(-not $stud){throw 'No students'}
            $tmpl=$cmbTemp.SelectedItem; $ds=$cmbDs.SelectedItem
            if(-not $tmpl -or -not $ds){throw 'Select template/datastore'}
            $nets=@(); foreach($a in $adapters){$nets+=$a.CheckedItems}
            if(-not $nets){throw 'No networks'}
            $lblStatus.Text='Creating VMs...'; $main.Refresh()
            $config=[PSCustomObject]@{classFolder=$name;students=$stud;dataStore=$ds;servers=@(@{serverName="$name`_VM";template=$tmpl;adapters=$nets})}
            [CourseManager]::CreateCourseVMs($config)
            $lblStatus.Text='VMs created'
        }catch{Write-Warning"CreateVMs failed: $_"; $lblStatus.Text='Error'}
    })
    $btnDeleteC.Add_Click({
        $conn=Get-ConnectionSafe; if(!$conn){$lblStatus.Text='Offline/no auth';return}
        try{
            $name=$cmbClasses.SelectedItem; if(-not $name){throw 'Select class'}
            $c=[System.Windows.Forms.MessageBox]::Show("Delete '$name'?",'Confirm',[System.Windows.Forms.MessageBoxButtons]::YesNo,[System.Windows.Forms.MessageBoxIcon]::Warning)
            if($c -ne 'Yes'){return}
            $stud=$txtStud.Lines|Where{$_.Trim()}
            $lblStatus.Text='Deleting...'; $main.Refresh()
            [CourseManager]::RemoveCourseVMs($name,$stud)
            $cmbClasses.Items.Remove($name); $lblStatus.Text='Deleted'
        }catch{Write-Warning"DeleteClass failed: $_"; $lblStatus.Text='Error'}
    })
    $btnRefresh.Add_Click({
        $conn=Get-ConnectionSafe; if($conn){
            try{
                $templates=Get-Template -Server $conn|Select-Object -Expand Name; $cmbTemp.Items.Clear(); $cmbTemp.Items.AddRange($templates)
                $datastores=Get-Datastore -Server $conn|Select-Object -Expand Name; $cmbDs.Items.Clear(); $cmbDs.Items.AddRange($datastores)
                $nets=[VMwareNetwork]::ListPortGroups()|Select-Object -Expand Name; foreach($clb in $adapters){$clb.Items.Clear(); $clb.Items.AddRange($nets)}
                $classes=[CourseManager]::ListClasses(); $cmbClasses.Items.Clear(); $cmbClasses.Items.AddRange($classes)
                $lblStatus.Text='Refreshed'
            }catch{Write-Warning"Refresh failed: $_"; $lblStatus.Text='Error'}
        } else { $lblStatus.Text='Offline/no auth' }
    })

    # Load selected class into new class text box
    $cmbClasses.Add_SelectedIndexChanged({ $txtNew.Text=$cmbClasses.SelectedItem.ToString() })
}
