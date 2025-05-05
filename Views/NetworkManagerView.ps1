<#
.SYNOPSIS
    VMware Network Management View, resilient to authentication and offline states.
.DESCRIPTION
    GUI for managing vSwitches and port groups with:
      - View existing networks (vSwitches and port groups)
      - Add/remove individual networks
      - Bulk operations for student networks
    Honors global login and offline state; operations are no-ops when disconnected.
.PARAMETER ContentPanel
    The Panel control where this view is rendered.
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Show-NetworkView {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)][System.Windows.Forms.Panel]$ContentPanel
    )

    # Safe connection helper
    function Get-ConnectionSafe {
        if (-not $global:IsLoggedIn) {
            Write-Warning 'Not logged in: network operations disabled.'
            return $null
        }
        if ($global:VMwareConfig.OfflineMode -or -not $global:VMwareConfig.Connection) {
            Write-Warning 'Offline mode: cannot establish network connection.'
            return $null
        }
        return $global:VMwareConfig.Connection
    }

    # Clear UI and set background
    $ContentPanel.Controls.Clear()
    $ContentPanel.BackColor = [System.Drawing.Color]::White

    # Header with improved styling
    $lblHeader = [System.Windows.Forms.Label]::new()
    $lblHeader.Text = 'Network Management'
    $lblHeader.Font = [System.Drawing.Font]::new('Segoe UI', 18, [System.Drawing.FontStyle]::Bold)
    $lblHeader.ForeColor = [System.Drawing.Color]::DarkSlateBlue
    $lblHeader.Location = [System.Drawing.Point]::new(20, 15)
    $lblHeader.AutoSize = $true
    $ContentPanel.Controls.Add($lblHeader)

    # Offline banner with improved visibility
    if (-not $global:IsLoggedIn -or $global:VMwareConfig.OfflineMode) {
        $lblOffline = [System.Windows.Forms.Label]::new()
        $lblOffline.Text = 'OFFLINE or not logged in: limited network functionality'
        $lblOffline.Font = [System.Drawing.Font]::new('Segoe UI', 12, [System.Drawing.FontStyle]::Italic)
        $lblOffline.ForeColor = [System.Drawing.Color]::DarkRed
        $lblOffline.AutoSize = $true
        $lblOffline.Location = [System.Drawing.Point]::new(300, 22)
        $ContentPanel.Controls.Add($lblOffline)
    }

    # Main tab control 
    $tabControl = [System.Windows.Forms.TabControl]::new()
    $tabControl.Location = [System.Drawing.Point]::new(20, 60)
    $tabControl.Size = [System.Drawing.Size]::new(850, 500)
    $tabControl.Font = [System.Drawing.Font]::new('Segoe UI', 12)
    $ContentPanel.Controls.Add($tabControl)

    # --- Overview Tab ---
    $tabOverview = [System.Windows.Forms.TabPage]::new()
    $tabOverview.Text = 'Network Overview'
    $tabOverview.Font = [System.Drawing.Font]::new('Segoe UI', 12)
    $tabOverview.BackColor = [System.Drawing.Color]::White
    $tabControl.Controls.Add($tabOverview)

    # Grid with improved styling
    $grid = [System.Windows.Forms.DataGridView]::new()
    $grid.Location = [System.Drawing.Point]::new(15, 15)
    $grid.Size = [System.Drawing.Size]::new(820, 380)
    $grid.ReadOnly = $true
    $grid.AllowUserToAddRows = $false
    $grid.SelectionMode = 'FullRowSelect'
    $grid.AutoSizeColumnsMode = 'Fill'
    $grid.AutoGenerateColumns = $false
    $grid.BackgroundColor = [System.Drawing.Color]::White
    $grid.BorderStyle = [System.Windows.Forms.BorderStyle]::Fixed3D
    $grid.Font = [System.Drawing.Font]::new('Segoe UI', 11)
    $grid.ColumnHeadersDefaultCellStyle.Font = [System.Drawing.Font]::new('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
    $grid.AlternatingRowsDefaultCellStyle.BackColor = [System.Drawing.Color]::AliceBlue

    # Configure grid columns
    $columns = @(
        @{Name='Name'; HeaderText='Name'},
        @{Name='Type'; HeaderText='Type'},
        @{Name='vSwitch'; HeaderText='vSwitch'},
        @{Name='VLAN'; HeaderText='VLAN'},
        @{Name='Ports'; HeaderText='Ports'},
        @{Name='Used'; HeaderText='Used'}
    )

    foreach ($col in $columns) {
        $gridCol = [System.Windows.Forms.DataGridViewTextBoxColumn]::new()
        $gridCol.Name = $col.Name
        $gridCol.HeaderText = $col.HeaderText
        $grid.Columns.Add($gridCol) | Out-Null
    }
    $tabOverview.Controls.Add($grid)

    # Refresh button with improved styling
    $btnRefresh = [System.Windows.Forms.Button]::new()
    $btnRefresh.Text = 'Refresh Data'
    $btnRefresh.Font = [System.Drawing.Font]::new('Segoe UI', 11)
    $btnRefresh.Size = [System.Drawing.Size]::new(150, 35)
    $btnRefresh.Location = [System.Drawing.Point]::new(685, 405)
    $btnRefresh.BackColor = [System.Drawing.Color]::LightSteelBlue
    $btnRefresh.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnRefresh.Add_Click({ Refresh-NetworkData })
    $tabOverview.Controls.Add($btnRefresh)

    # --- Operations Tab ---
    $tabOps = [System.Windows.Forms.TabPage]::new()
    $tabOps.Text = 'Network Operations'
    $tabOps.Font = [System.Drawing.Font]::new('Segoe UI', 12)
    $tabOps.BackColor = [System.Drawing.Color]::White
    $tabControl.Controls.Add($tabOps)

    # Section styling
    $sectionLeft = 20
    $controlLeft = 200
    $controlWidth = 250
    $verticalSpacing = 35
    $currentY = 20

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
        $tabOps.Controls.Add($lblSection)
        
        $divider = [System.Windows.Forms.Label]::new()
        $divider.BorderStyle = [System.Windows.Forms.BorderStyle]::Fixed3D
        $divider.Width = $tabOps.Width - 40
        $divider.Height = 2
        $divider.Location = [System.Drawing.Point]::new($sectionLeft, $YPos.Value + 25)
        $tabOps.Controls.Add($divider)
        
        $YPos.Value += 40
    }

    # Single Network Operations Section
    Add-SectionDivider -Title "Single Network Operations" -YPos ([ref]$currentY)

    # Network Name
    $lblName = [System.Windows.Forms.Label]::new()
    $lblName.Text = 'Network Name:'
    $lblName.Font = [System.Drawing.Font]::new('Segoe UI', 11)
    $lblName.Location = [System.Drawing.Point]::new($sectionLeft, $currentY)
    $lblName.AutoSize = $true
    $tabOps.Controls.Add($lblName)

    $txtName = [System.Windows.Forms.TextBox]::new()
    $txtName.Font = [System.Drawing.Font]::new('Segoe UI', 11)
    $txtName.Location = [System.Drawing.Point]::new($controlLeft, $currentY)
    $txtName.Size = [System.Drawing.Size]::new($controlWidth, 25)
    $tabOps.Controls.Add($txtName)
    $currentY += $verticalSpacing

    # vSwitch Selection
    $lblSwitch = [System.Windows.Forms.Label]::new()
    $lblSwitch.Text = 'vSwitch:'
    $lblSwitch.Font = [System.Drawing.Font]::new('Segoe UI', 11)
    $lblSwitch.Location = [System.Drawing.Point]::new($sectionLeft, $currentY)
    $lblSwitch.AutoSize = $true
    $tabOps.Controls.Add($lblSwitch)

    $cmbSwitch = [System.Windows.Forms.ComboBox]::new()
    $cmbSwitch.Font = [System.Drawing.Font]::new('Segoe UI', 11)
    $cmbSwitch.Location = [System.Drawing.Point]::new($controlLeft, $currentY)
    $cmbSwitch.Size = [System.Drawing.Size]::new($controlWidth, 25)
    $cmbSwitch.DropDownStyle = 'DropDownList'
    $tabOps.Controls.Add($cmbSwitch)
    $currentY += $verticalSpacing

    # VLAN ID
    $lblVLAN = [System.Windows.Forms.Label]::new()
    $lblVLAN.Text = 'VLAN ID:'
    $lblVLAN.Font = [System.Drawing.Font]::new('Segoe UI', 11)
    $lblVLAN.Location = [System.Drawing.Point]::new($sectionLeft, $currentY)
    $lblVLAN.AutoSize = $true
    $tabOps.Controls.Add($lblVLAN)

    $txtVLAN = [System.Windows.Forms.TextBox]::new()
    $txtVLAN.Font = [System.Drawing.Font]::new('Segoe UI', 11)
    $txtVLAN.Location = [System.Drawing.Point]::new($controlLeft, $currentY)
    $txtVLAN.Size = [System.Drawing.Size]::new(80, 25)
    $tabOps.Controls.Add($txtVLAN)
    $currentY += $verticalSpacing

    # Action buttons with improved styling
    $buttonStyle = @{
        Font = [System.Drawing.Font]::new('Segoe UI', 11)
        Size = [System.Drawing.Size]::new(180, 35)
        FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    }

    $btnAdd = [System.Windows.Forms.Button]::new()
    $btnAdd.Text = 'Add Port Group'
    $btnAdd.Font = $buttonStyle.Font
    $btnAdd.Size = $buttonStyle.Size
    $btnAdd.Location = [System.Drawing.Point]::new($sectionLeft, $currentY)
    $btnAdd.BackColor = [System.Drawing.Color]::LightGreen
    $btnAdd.FlatStyle = $buttonStyle.FlatStyle
    $btnAdd.Add_Click({ Add-Network })
    $tabOps.Controls.Add($btnAdd)

    $btnRemove = [System.Windows.Forms.Button]::new()
    $btnRemove.Text = 'Remove Port Group'
    $btnRemove.Font = $buttonStyle.Font
    $btnRemove.Size = $buttonStyle.Size
    $btnRemove.Location = [System.Drawing.Point]::new($controlLeft, $currentY)
    $btnRemove.BackColor = [System.Drawing.Color]::LightCoral
    $btnRemove.FlatStyle = $buttonStyle.FlatStyle
    $btnRemove.Add_Click({ Remove-Network })
    $tabOps.Controls.Add($btnRemove)
    $currentY += 50

    # Bulk Network Operations Section
    Add-SectionDivider -Title "Bulk Student Networks" -YPos ([ref]$currentY)

    # Course Prefix
    $lblCourse = [System.Windows.Forms.Label]::new()
    $lblCourse.Text = 'Course Prefix:'
    $lblCourse.Font = [System.Drawing.Font]::new('Segoe UI', 11)
    $lblCourse.Location = [System.Drawing.Point]::new($sectionLeft, $currentY)
    $lblCourse.AutoSize = $true
    $tabOps.Controls.Add($lblCourse)

    $txtCourse = [System.Windows.Forms.TextBox]::new()
    $txtCourse.Font = [System.Drawing.Font]::new('Segoe UI', 11)
    $txtCourse.Location = [System.Drawing.Point]::new($controlLeft, $currentY)
    $txtCourse.Size = [System.Drawing.Size]::new(120, 25)
    $tabOps.Controls.Add($txtCourse)
    $currentY += $verticalSpacing

    # Range Selection
    $lblRange = [System.Windows.Forms.Label]::new()
    $lblRange.Text = 'Student Range:'
    $lblRange.Font = [System.Drawing.Font]::new('Segoe UI', 11)
    $lblRange.Location = [System.Drawing.Point]::new($sectionLeft, $currentY)
    $lblRange.AutoSize = $true
    $tabOps.Controls.Add($lblRange)

    $txtStart = [System.Windows.Forms.TextBox]::new()
    $txtStart.Font = [System.Drawing.Font]::new('Segoe UI', 11)
    $txtStart.Location = [System.Drawing.Point]::new($controlLeft, $currentY)
    $txtStart.Size = [System.Drawing.Size]::new(50, 25)
    $txtStart.Text = '1'
    $tabOps.Controls.Add($txtStart)

    $lblTo = [System.Windows.Forms.Label]::new()
    $lblTo.Text = 'to'
    $lblTo.Font = [System.Drawing.Font]::new('Segoe UI', 11)
    $lblTo.Location = [System.Drawing.Point]::new($controlLeft + 60, $currentY + 5)
    $lblTo.AutoSize = $true
    $tabOps.Controls.Add($lblTo)

    $txtEnd = [System.Windows.Forms.TextBox]::new()
    $txtEnd.Font = [System.Drawing.Font]::new('Segoe UI', 11)
    $txtEnd.Location = [System.Drawing.Point]::new($controlLeft + 90, $currentY)
    $txtEnd.Size = [System.Drawing.Size]::new(50, 25)
    $txtEnd.Text = '10'
    $tabOps.Controls.Add($txtEnd)
    $currentY += $verticalSpacing

    # Bulk action buttons
    $btnBulkAdd = [System.Windows.Forms.Button]::new()
    $btnBulkAdd.Text = 'Create Networks'
    $btnBulkAdd.Font = $buttonStyle.Font
    $btnBulkAdd.Size = $buttonStyle.Size
    $btnBulkAdd.Location = [System.Drawing.Point]::new($sectionLeft, $currentY)
    $btnBulkAdd.BackColor = [System.Drawing.Color]::LightGreen
    $btnBulkAdd.FlatStyle = $buttonStyle.FlatStyle
    $btnBulkAdd.Add_Click({ Add-BulkNetworks })
    $tabOps.Controls.Add($btnBulkAdd)

    $btnBulkRem = [System.Windows.Forms.Button]::new()
    $btnBulkRem.Text = 'Remove Networks'
    $btnBulkRem.Font = $buttonStyle.Font
    $btnBulkRem.Size = $buttonStyle.Size
    $btnBulkRem.Location = [System.Drawing.Point]::new($controlLeft, $currentY)
    $btnBulkRem.BackColor = [System.Drawing.Color]::LightCoral
    $btnBulkRem.FlatStyle = $buttonStyle.FlatStyle
    $btnBulkRem.Add_Click({ Remove-BulkNetworks })
    $tabOps.Controls.Add($btnBulkRem)

    # Status bar with improved styling
    $status = [System.Windows.Forms.StatusBar]::new()
    $status.Font = [System.Drawing.Font]::new('Segoe UI', 10)
    $status.Location = [System.Drawing.Point]::new(20, 570)
    $status.Size = [System.Drawing.Size]::new(850, 24)
    $status.BackColor = [System.Drawing.Color]::WhiteSmoke
    $status.SizingGrip = $false
    $ContentPanel.Controls.Add($status)

    # --- Functions (unchanged from original) ---
    function Refresh-NetworkData {
        $status.Text='Loading...';$ContentPanel.Refresh()
        $conn=Get-ConnectionSafe
        if($null -eq $conn){ 
            $grid.DataSource=@(); 
            $status.Text='Offline/no auth'; 
            return 
        }

        try {
            $vs=Get-VirtualSwitch -Server $conn
            $pgs=Get-VirtualPortGroup -Server $conn

            $cmbSwitch.Items.Clear()
            foreach($v in $vs){
                $cmbSwitch.Items.Add($v.Name)
            }

            if($cmbSwitch.Items.Count){
                $cmbSwitch.SelectedIndex=0
            }

            $list=[System.Collections.ArrayList]::new()
            foreach($v in $vs){$list.Add([PSCustomObject]@{
                    Name=$v.Name;
                    Type='vSwitch';
                    vSwitch='';
                    VLAN='';
                    Ports=$v.NumPorts;
                    Used=$v.NumPortsAvailable
            })|Out-Null}

            foreach($p in $pgs){ $list.Add([PSCustomObject]@{
                Name=$p.Name;
                Type='Port Group';
                vSwitch=$p.VirtualSwitchName;
                VLAN=$p.VLanId;
                Ports='';Used=''
            })|Out-Null}

            $grid.DataSource=$list; 
            $status.Text='Loaded'
        } catch {
            Write-Warning "Refresh failed: $_"; $status.Text='Error'
        }
    }

    function Add-Network {
        $conn = Get-ConnectionSafe
        if ($null -eq $conn) {
            $status.Text = 'Offline/no auth'
            return
        }
        try {
            if (-not $txtName.Text) { throw 'Name empty' }
            if (-not $cmbSwitch.SelectedItem) { throw 'Select switch' }
            $status.Text = 'Adding...'
            $ContentPanel.Refresh()
            [VMwareNetwork]::CreateStudentPortGroup($txtName.Text, $cmbSwitch.SelectedItem)
            $status.Text = 'Added'
            Refresh-NetworkData
        } catch {
            Write-Warning "Add failed: $_"
            $status.Text = 'Error'
        }
    }

    function Remove-Network {
        $conn = Get-ConnectionSafe
        if ($null -eq $conn) {
            $status.Text = 'Offline/no auth'
            return
        }
        try {
            if (-not $txtName.Text) { throw 'Name empty' }
            $confirmation = [System.Windows.Forms.MessageBox]::Show(
                "Remove '$($txtName.Text)'?", 
                'Confirm', 
                [System.Windows.Forms.MessageBoxButtons]::YesNo, 
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
            if ($confirmation -ne 'Yes') { return }
            $status.Text = 'Removing...'
            $ContentPanel.Refresh()
            [VMwareNetwork]::RemovePortGroup($txtName.Text)
            $status.Text = 'Removed'
            Refresh-NetworkData
        } catch {
            Write-Warning "Remove failed: $_"
            $status.Text = 'Error'
        }
    }

    function Add-BulkNetworks {
        $conn = Get-ConnectionSafe
        if ($null -eq $conn) {
            $status.Text = 'Offline/no auth'
            return
        }
        try {
            if (-not $txtCourse.Text) { throw 'Prefix empty' }
            $s = [int]$txtStart.Text
            $e = [int]$txtEnd.Text
            if ($s -gt $e) { throw 'Invalid range' }
            $confirmation = [System.Windows.Forms.MessageBox]::Show(
                "Create ${txtCourse.Text} $s-$e?", 
                'Confirm', 
                [System.Windows.Forms.MessageBoxButtons]::YesNo, 
                [System.Windows.Forms.MessageBoxIcon]::Question
            )
            if ($confirmation -ne 'Yes') { return }
            $status.Text = 'Creating...'
            $ContentPanel.Refresh()
            [CourseManager]::CreateStudentNetworks($txtCourse.Text, $s, $e)
            $status.Text = 'Done'
            Refresh-NetworkData
        } catch {
            Write-Warning "Bulk add failed: $_"
            $status.Text = 'Error'
        }
    }

    function Remove-BulkNetworks {
        $conn = Get-ConnectionSafe
        if ($null -eq $conn) {
            $status.Text = 'Offline/no auth'
            return
        }
        try {
            if (-not $txtCourse.Text) { throw 'Prefix empty' }
            $s = [int]$txtStart.Text
            $e = [int]$txtEnd.Text
            if ($s -gt $e) { throw 'Invalid range' }
            $confirmation = [System.Windows.Forms.MessageBox]::Show(
                "Remove ${txtCourse.Text} $s-$e?", 
                'Confirm', 
                [System.Windows.Forms.MessageBoxButtons]::YesNo, 
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
            if ($confirmation -ne 'Yes') { return }
            $status.Text = 'Removing...'
            $ContentPanel.Refresh()
            [CourseManager]::RemoveStudentNetworks($txtCourse.Text, $s, $e)
            $status.Text = 'Done'
            Refresh-NetworkData
        } catch {
            Write-Warning "Bulk remove failed: $_"
            $status.Text = 'Error'
        }
    }

    # Initial load
    Refresh-NetworkData
}