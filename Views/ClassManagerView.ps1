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
    $main.Dock = 'Fill'
    $main.AutoScroll = $true
    $main.BackColor = [System.Drawing.Color]::White
    $ContentPanel.Controls.Add($main)

    # Header with better styling
    $lblHeader = [System.Windows.Forms.Label]::new()
    $lblHeader.Text = 'Class Management'
    $lblHeader.Font = [System.Drawing.Font]::new('Segoe UI', 18, [System.Drawing.FontStyle]::Bold)
    $lblHeader.Location = [System.Drawing.Point]::new(30, 20)
    $lblHeader.AutoSize = $true
    $lblHeader.ForeColor = [System.Drawing.Color]::DarkSlateBlue
    $main.Controls.Add($lblHeader)

    # Offline/banner
    if (-not $global:IsLoggedIn -or $global:VMwareConfig.OfflineMode) {
        $lblOffline = [System.Windows.Forms.Label]::new()
        $lblOffline.Text = 'OFFLINE or not logged in: operations disabled'
        $lblOffline.Font = [System.Drawing.Font]::new('Segoe UI', 12, [System.Drawing.FontStyle]::Italic)
        $lblOffline.ForeColor = [System.Drawing.Color]::DarkRed
        $lblOffline.AutoSize = $true
        $lblOffline.Location = [System.Drawing.Point]::new(300, 28)
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

    # Section styling variables
    $sectionLeft = 30
    $controlLeft = 250
    $controlWidth = 300
    $verticalSpacing = 35
    $currentY = 70

    # Add section divider function
    function Add-SectionDivider {
        param(
            [string]$Title,
            [ref]$YPos
        )
        
        $lblSection = [System.Windows.Forms.Label]::new()
        $lblSection.Text = $Title
        $lblSection.Font = [System.Drawing.Font]::new('Segoe UI', 14, [System.Drawing.FontStyle]::Bold)
        $lblSection.ForeColor = [System.Drawing.Color]::DarkSlateBlue
        $lblSection.Location = [System.Drawing.Point]::new($sectionLeft, $YPos.Value)
        $lblSection.AutoSize = $true
        $main.Controls.Add($lblSection)
        
        $divider = [System.Windows.Forms.Label]::new()
        $divider.BorderStyle = [System.Windows.Forms.BorderStyle]::Fixed3D
        $divider.Width = $main.Width - 60
        $divider.Height = 2
        $divider.Location = [System.Drawing.Point]::new($sectionLeft, $YPos.Value + 25)
        $main.Controls.Add($divider)
        
        $YPos.Value += 50
    }

    # Class Information Section
    Add-SectionDivider -Title "Class Information" -YPos ([ref]$currentY)

    # Existing class selector
    $lblExist = [System.Windows.Forms.Label]::new()
    $lblExist.Text = 'Select Class:'
    $lblExist.Font = [System.Drawing.Font]::new('Segoe UI', 12)
    $lblExist.Location = [System.Drawing.Point]::new($sectionLeft, $currentY)
    $lblExist.AutoSize = $true
    $main.Controls.Add($lblExist)

    $cmbClasses = [System.Windows.Forms.ComboBox]::new()
    $cmbClasses.Font = [System.Drawing.Font]::new('Segoe UI', 12)
    $cmbClasses.Location = [System.Drawing.Point]::new($controlLeft, $currentY - 3)
    $cmbClasses.Size = [System.Drawing.Size]::new($controlWidth, 30)
    $cmbClasses.DropDownStyle = 'DropDownList'
    $cmbClasses.Items.AddRange($classes)
    $main.Controls.Add($cmbClasses)
    $currentY += $verticalSpacing

    # New class name
    $lblNew = [System.Windows.Forms.Label]::new()
    $lblNew.Text = 'New Class Name:'
    $lblNew.Font = [System.Drawing.Font]::new('Segoe UI', 12)
    $lblNew.Location = [System.Drawing.Point]::new($sectionLeft, $currentY)
    $lblNew.AutoSize = $true
    $main.Controls.Add($lblNew)

    $txtNew = [System.Windows.Forms.TextBox]::new()
    $txtNew.Font = [System.Drawing.Font]::new('Segoe UI', 12)
    $txtNew.Location = [System.Drawing.Point]::new($controlLeft, $currentY - 3)
    $txtNew.Size = [System.Drawing.Size]::new($controlWidth, 30)
    $main.Controls.Add($txtNew)
    $currentY += $verticalSpacing

    # Students list
    $lblStud = [System.Windows.Forms.Label]::new()
    $lblStud.Text = 'Students (one per line):'
    $lblStud.Font = [System.Drawing.Font]::new('Segoe UI', 12)
    $lblStud.Location = [System.Drawing.Point]::new($sectionLeft, $currentY)
    $lblStud.AutoSize = $true
    $main.Controls.Add($lblStud)

    $txtStud = [System.Windows.Forms.TextBox]::new()
    $txtStud.Font = [System.Drawing.Font]::new('Segoe UI', 12)
    $txtStud.Location = [System.Drawing.Point]::new($controlLeft, $currentY - 3)
    $txtStud.Size = [System.Drawing.Size]::new($controlWidth, 100)
    $txtStud.Multiline = $true
    $txtStud.ScrollBars = 'Vertical'
    $main.Controls.Add($txtStud)
    $currentY += 120

    # VM Configuration Section
    Add-SectionDivider -Title "VM Configuration" -YPos ([ref]$currentY)

    # Template selection
    $lblTemp = [System.Windows.Forms.Label]::new()
    $lblTemp.Text = 'Template:'
    $lblTemp.Font = [System.Drawing.Font]::new('Segoe UI', 12)
    $lblTemp.Location = [System.Drawing.Point]::new($sectionLeft, $currentY)
    $lblTemp.AutoSize = $true
    $main.Controls.Add($lblTemp)

    $cmbTemp = [System.Windows.Forms.ComboBox]::new()
    $cmbTemp.Font = [System.Drawing.Font]::new('Segoe UI', 12)
    $cmbTemp.Location = [System.Drawing.Point]::new($controlLeft, $currentY - 3)
    $cmbTemp.Size = [System.Drawing.Size]::new($controlWidth, 30)
    $cmbTemp.DropDownStyle = 'DropDownList'
    $cmbTemp.Items.AddRange($templates)
    $main.Controls.Add($cmbTemp)
    $currentY += $verticalSpacing

    # Datastore selection 
    $lblDs = [System.Windows.Forms.Label]::new()
    $lblDs.Text = 'Datastore:'
    $lblDs.Font = [System.Drawing.Font]::new('Segoe UI', 12)
    $lblDs.Location = [System.Drawing.Point]::new($sectionLeft, $currentY)
    $lblDs.AutoSize = $true
    $main.Controls.Add($lblDs)

    $cmbDs = [System.Windows.Forms.ComboBox]::new()
    $cmbDs.Font = [System.Drawing.Font]::new('Segoe UI', 12)
    $cmbDs.Location = [System.Drawing.Point]::new($controlLeft, $currentY - 3)
    $cmbDs.Size = [System.Drawing.Size]::new($controlWidth, 30)
    $cmbDs.DropDownStyle = 'DropDownList'
    $cmbDs.Items.AddRange($datastores)
    $main.Controls.Add($cmbDs)
    $currentY += $verticalSpacing

    # Network adapters
    $lblNet = [System.Windows.Forms.Label]::new()
    $lblNet.Text = 'Network Adapters:'
    $lblNet.Font = [System.Drawing.Font]::new('Segoe UI', 12)
    $lblNet.Location = [System.Drawing.Point]::new($sectionLeft, $currentY)
    $lblNet.AutoSize = $true
    $main.Controls.Add($lblNet)

    $clb = [System.Windows.Forms.CheckedListBox]::new()
    $clb.Font = [System.Drawing.Font]::new('Segoe UI', 12)
    $clb.Location = [System.Drawing.Point]::new($controlLeft, $currentY - 3)
    $clb.Size = [System.Drawing.Size]::new($controlWidth, 100)
    $clb.CheckOnClick = $true
    $clb.Items.AddRange($networks)
    $main.Controls.Add($clb)
    $adapters = @($clb)

    # Add adapter button
    $btnAddA = [System.Windows.Forms.Button]::new()
    $btnAddA.Text = 'Add Adapter'
    $btnAddA.Font = [System.Drawing.Font]::new('Segoe UI', 12)
    $btnAddA.Location = [System.Drawing.Point]::new($controlLeft + $controlWidth + 10, $currentY)
    $btnAddA.Size = [System.Drawing.Size]::new(120, 30)
    $btnAddA.BackColor = [System.Drawing.Color]::LightSteelBlue
    $btnAddA.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnAddA.Add_Click({
        $nb = [System.Windows.Forms.CheckedListBox]::new()
        $nb.Font = [System.Drawing.Font]::new('Segoe UI', 12)
        $nb.Location = [System.Drawing.Point]::new($controlLeft, $adapters[-1].Bottom + 10)
        $nb.Size = $clb.Size
        $nb.CheckOnClick = $true
        $nb.Items.AddRange($networks)
        $main.Controls.Add($nb)
        $adapters += $nb
    })
    $main.Controls.Add($btnAddA)
    $currentY += 110

    # Actions Section
    Add-SectionDivider -Title "Actions" -YPos ([ref]$currentY)

    # Action buttons
    $buttonStyle = @{
        Font = [System.Drawing.Font]::new('Segoe UI', 12)
        Size = [System.Drawing.Size]::new(150, 40)
        FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    }

    $btnCreateF = [System.Windows.Forms.Button]::new()
    $btnCreateF.Text = 'Create Folders'
    $btnCreateF.Font = $buttonStyle.Font
    $btnCreateF.Size = $buttonStyle.Size
    $btnCreateF.Location = [System.Drawing.Point]::new($sectionLeft, $currentY)
    $btnCreateF.BackColor = [System.Drawing.Color]::LightGreen
    $btnCreateF.FlatStyle = $buttonStyle.FlatStyle
    $main.Controls.Add($btnCreateF)

    $btnCreateV = [System.Windows.Forms.Button]::new()
    $btnCreateV.Text = 'Create VMs'
    $btnCreateV.Font = $buttonStyle.Font
    $btnCreateV.Size = $buttonStyle.Size
    $btnCreateV.Location = [System.Drawing.Point]::new($sectionLeft + 160, $currentY)
    $btnCreateV.BackColor = [System.Drawing.Color]::LightGreen
    $btnCreateV.FlatStyle = $buttonStyle.FlatStyle
    $main.Controls.Add($btnCreateV)

    $btnDeleteC = [System.Windows.Forms.Button]::new()
    $btnDeleteC.Text = 'Delete Class'
    $btnDeleteC.Font = $buttonStyle.Font
    $btnDeleteC.Size = $buttonStyle.Size
    $btnDeleteC.Location = [System.Drawing.Point]::new($sectionLeft + 320, $currentY)
    $btnDeleteC.BackColor = [System.Drawing.Color]::LightCoral
    $btnDeleteC.FlatStyle = $buttonStyle.FlatStyle
    $main.Controls.Add($btnDeleteC)

    $btnRefresh = [System.Windows.Forms.Button]::new()
    $btnRefresh.Text = 'Refresh'
    $btnRefresh.Font = $buttonStyle.Font
    $btnRefresh.Size = $buttonStyle.Size
    $btnRefresh.Location = [System.Drawing.Point]::new($sectionLeft + 480, $currentY)
    $btnRefresh.BackColor = [System.Drawing.Color]::LightSteelBlue
    $btnRefresh.FlatStyle = $buttonStyle.FlatStyle
    $main.Controls.Add($btnRefresh)
    $currentY += 60

    # Status label
    $lblStatus = [System.Windows.Forms.Label]::new()
    $lblStatus.Text = 'Ready'
    $lblStatus.Font = [System.Drawing.Font]::new('Segoe UI', 12, [System.Drawing.FontStyle]::Italic)
    $lblStatus.ForeColor = [System.Drawing.Color]::DarkSlateGray
    $lblStatus.Location = [System.Drawing.Point]::new($sectionLeft, $currentY)
    $lblStatus.AutoSize = $true
    $main.Controls.Add($lblStatus)

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