Add-Type -AssemblyName 'System.Windows.Forms'
Add-Type -AssemblyName 'System.Drawing'

<##
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
.NOTES
    Resilient design based on Main.ps1: always shows UI even if offline or unauthenticated.
.EXAMPLE
    Show-NetworkView -ContentPanel $split.Panel2
#>
function Show-NetworkView {

    param (
        [Parameter(Mandatory=$true)]
        [System.Windows.Forms.Panel]$ContentPanel
    )

    # Helper: safe connection under auth/offline conditions
    function Get-ConnectionSafe {
        <#
        .SYNOPSIS
            Returns a VMware connection or $null if offline/not authenticated.
        #>
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

    # Clear and theme the content panel
    $ContentPanel.Controls.Clear()
    $ContentPanel.BackColor = $global:theme.Background

    # Header label
    $lblHeader = New-Object System.Windows.Forms.Label
    $lblHeader.Text = 'Network Management'
    $lblHeader.Font = New-Object System.Drawing.Font('Segoe UI', 18, [System.Drawing.FontStyle]::Bold)
    $lblHeader.ForeColor = $global:theme.Primary
    $lblHeader.AutoSize = $true
    $lblHeader.Location = [System.Drawing.Point]::new(20, 15)
    $ContentPanel.Controls.Add($lblHeader)

    # Offline/auth banner
    if (-not $global:IsLoggedIn -or $global:VMwareConfig.OfflineMode) {
        $lblOffline = New-Object System.Windows.Forms.Label
        $lblOffline.Text = 'OFFLINE or not logged in: limited network functionality'
        $lblOffline.Font = New-Object System.Drawing.Font('Segoe UI', 12, [System.Drawing.FontStyle]::Italic)
        $lblOffline.ForeColor = $global:theme.Error
        $lblOffline.AutoSize = $true
        $lblOffline.Location = [System.Drawing.Point]::new(300, 22)
        $ContentPanel.Controls.Add($lblOffline)
    }

    # Tab control setup
    $tabControl = New-Object System.Windows.Forms.TabControl
    $tabControl.Font = New-Object System.Drawing.Font('Segoe UI', 12)
    $tabControl.Location = [System.Drawing.Point]::new(20, 60)
    $tabControl.Size = [System.Drawing.Size]::new(850, 500)
    $ContentPanel.Controls.Add($tabControl)

    # --- Overview Tab ---
    $tabOverview = New-Object System.Windows.Forms.TabPage 'Network Overview'
    $tabOverview.BackColor = $global:theme.CardBackground
    $tabControl.Controls.Add($tabOverview)

    # Data grid for networks
    $grid = New-Object System.Windows.Forms.DataGridView
    $grid.ReadOnly = $true
    $grid.AllowUserToAddRows = $false
    $grid.SelectionMode = 'FullRowSelect'
    $grid.AutoSizeColumnsMode = 'Fill'
    $grid.Location = [System.Drawing.Point]::new(15, 15)
    $grid.Size = [System.Drawing.Size]::new(820, 380)
    $grid.BackgroundColor = $global:theme.CardBackground
    $grid.GridColor = $global:theme.Border
    $grid.BorderStyle = 'Fixed3D'
    $grid.Font = New-Object System.Drawing.Font('Segoe UI', 11)
    $grid.ColumnHeadersDefaultCellStyle.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
    $grid.ColumnHeadersDefaultCellStyle.ForeColor = $global:theme.TextPrimary
    $grid.AlternatingRowsDefaultCellStyle.BackColor = [System.Drawing.Color]::AliceBlue
    $tabOverview.Controls.Add($grid)

    # Refresh button
    $btnRefresh = New-Object System.Windows.Forms.Button
    $btnRefresh.Text = 'Refresh Data'
    $btnRefresh.Font = New-Object System.Drawing.Font('Segoe UI', 11)
    $btnRefresh.Size = New-Object System.Drawing.Size(150, 35)
    $btnRefresh.Location = [System.Drawing.Point]::new(685, 405)
    $btnRefresh.BackColor = $global:theme.Secondary
    $btnRefresh.ForeColor = $global:theme.CardBackground
    $btnRefresh.FlatStyle = 'Flat'
    $btnRefresh.Add_Click({ Refresh-NetworkData })
    $tabOverview.Controls.Add($btnRefresh)

    # Define overview columns
    $columns = @(
        @{Name='Name';    Header='Name'},
        @{Name='Type';    Header='Type'},
        @{Name='vSwitch'; Header='vSwitch'},
        @{Name='VLAN';    Header='VLAN'},
        @{Name='Ports';   Header='Ports'},
        @{Name='Used';    Header='Used'}
    )
    foreach ($col in $columns) {
        $gridCol = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
        $gridCol.Name = $col.Name
        $gridCol.HeaderText = $col.Header
        $grid.Columns.Add($gridCol) | Out-Null
    }

    # --- Operations Tab ---
    $tabOps = New-Object System.Windows.Forms.TabPage 'Network Operations'
    $tabOps.BackColor = $global:theme.CardBackground
    $tabControl.Controls.Add($tabOps)

    # Layout anchors
    $secX = 20; $ctlX = 200; $ctlW = 250; $spacingY = 35; $yPos = 20

    # Section divider function
    function Add-SectionDivider {
        param([string]$Title, [ref]$Y)
        $lbl = New-Object System.Windows.Forms.Label
        $lbl.Text = $Title
        $lbl.Font = New-Object System.Drawing.Font('Segoe UI', 14, [System.Drawing.FontStyle]::Bold)
        $lbl.ForeColor = $global:theme.Primary
        $lbl.Location = [System.Drawing.Point]::new($secX, $Y.Value)
        $lbl.AutoSize = $true
        $tabOps.Controls.Add($lbl)

        $line = New-Object System.Windows.Forms.Label
        $line.BorderStyle = 'Fixed3D'
        $line.Location = [System.Drawing.Point]::new($secX, $Y.Value + 25)
        $line.Size = [System.Drawing.Size]::new($tabOps.Width - 40, 2)
        $tabOps.Controls.Add($line)

        $Y.Value += 40
    }

    # Single network ops
    Add-SectionDivider -Title 'Single Network Operations' -Y ([ref]$yPos)
    # Name label
    $lblName = New-Object System.Windows.Forms.Label
    $lblName.Text = 'Network Name:'
    $lblName.Font = New-Object System.Drawing.Font('Segoe UI', 11)
    $lblName.ForeColor = $global:theme.TextPrimary
    $lblName.Location = [System.Drawing.Point]::new($secX, $yPos)
    $lblName.AutoSize = $true
    $tabOps.Controls.Add($lblName)
    # Name textbox
    $txtName = New-Object System.Windows.Forms.TextBox
    $txtName.Font = New-Object System.Drawing.Font('Segoe UI', 11)
    $txtName.ForeColor = $global:theme.TextPrimary
    $txtName.BackColor = $global:theme.CardBackground
    $txtName.Location = [System.Drawing.Point]::new($ctlX, $yPos)
    $txtName.Size = [System.Drawing.Size]::new($ctlW, 25)
    $tabOps.Controls.Add($txtName)
    $yPos += $spacingY

    # vSwitch selector
    $lblSwitch = New-Object System.Windows.Forms.Label
    $lblSwitch.Text = 'vSwitch:'
    $lblSwitch.Font = New-Object System.Drawing.Font('Segoe UI', 11)
    $lblSwitch.Location = [System.Drawing.Point]::new($secX, $yPos)
    $lblSwitch.AutoSize = $true
    $tabOps.Controls.Add($lblSwitch)
    $cmbSwitch = New-Object System.Windows.Forms.ComboBox
    $cmbSwitch.Font = New-Object System.Drawing.Font('Segoe UI', 11)
    $cmbSwitch.Location = [System.Drawing.Point]::new($ctlX, $yPos)
    $cmbSwitch.Size = [System.Drawing.Size]::new($ctlW, 25)
    $cmbSwitch.DropDownStyle = 'DropDownList'
    $tabOps.Controls.Add($cmbSwitch)
    $yPos += $spacingY

    # VLAN textbox
    $lblVLAN = New-Object System.Windows.Forms.Label
    $lblVLAN.Text = 'VLAN ID:'
    $lblVLAN.Font = New-Object System.Drawing.Font('Segoe UI', 11)
    $lblVLAN.Location = [System.Drawing.Point]::new($secX, $yPos)
    $lblVLAN.AutoSize = $true
    $tabOps.Controls.Add($lblVLAN)
    $txtVLAN = New-Object System.Windows.Forms.TextBox
    $txtVLAN.Font = New-Object System.Drawing.Font('Segoe UI', 11)
    $txtVLAN.Location = [System.Drawing.Point]::new($ctlX, $yPos)
    $txtVLAN.Size = [System.Drawing.Size]::new(80, 25)
    $txtVLAN.BackColor = $global:theme.CardBackground
    $txtVLAN.ForeColor = $global:theme.TextPrimary
    $tabOps.Controls.Add($txtVLAN)
    $yPos += 50

    # Single action buttons
    $btnAdd = New-Object System.Windows.Forms.Button
    $btnAdd.Text = 'Add Port Group'
    $btnAdd.Font = New-Object System.Drawing.Font('Segoe UI', 11)
    $btnAdd.Size = New-Object System.Drawing.Size(180,35)
    $btnAdd.Location = [System.Drawing.Point]::new($secX, $yPos)
    $btnAdd.BackColor = $global:theme.Primary
    $btnAdd.ForeColor = $global:theme.CardBackground
    $btnAdd.FlatStyle = 'Flat'
    $btnAdd.Add_Click({ Add-Network })
    $tabOps.Controls.Add($btnAdd)

    $btnRemove = New-Object System.Windows.Forms.Button
    $btnRemove.Text = 'Remove Port Group'
    $btnRemove.Font = New-Object System.Drawing.Font('Segoe UI', 11)
    $btnRemove.Size = New-Object System.Drawing.Size(180,35)
    $btnRemove.Location = [System.Drawing.Point]::new($ctlX, $yPos)
    $btnRemove.BackColor = $global:theme.Error
    $btnRemove.ForeColor = $global:theme.CardBackground
    $btnRemove.FlatStyle = 'Flat'
    $btnRemove.Add_Click({ Remove-Network })
    $tabOps.Controls.Add($btnRemove)
    $yPos += 50

    # Bulk student networks
    Add-SectionDivider -Title 'Bulk Student Networks' -Y ([ref]$yPos)
    # Course prefix
    $lblCourse = New-Object System.Windows.Forms.Label
    $lblCourse.Text = 'Course Prefix:'
    $lblCourse.Font = New-Object System.Drawing.Font('Segoe UI', 11)
    $lblCourse.Location = [System.Drawing.Point]::new($secX, $yPos)
    $lblCourse.AutoSize = $true
    $tabOps.Controls.Add($lblCourse)
    $txtCourse = New-Object System.Windows.Forms.TextBox
    $txtCourse.Font = New-Object System.Drawing.Font('Segoe UI', 11)
    $txtCourse.Location = [System.Drawing.Point]::new($ctlX, $yPos)
    $txtCourse.Size = [System.Drawing.Size]::new(120,25)
    $txtCourse.BackColor = $global:theme.CardBackground
    $txtCourse.ForeColor = $global:theme.TextPrimary
    $tabOps.Controls.Add($txtCourse)
    $yPos += $spacingY

    # Range inputs
    $lblRange = New-Object System.Windows.Forms.Label
    $lblRange.Text = 'Student Range:'
    $lblRange.Font = New-Object System.Drawing.Font('Segoe UI', 11)
    $lblRange.Location = [System.Drawing.Point]::new($secX, $yPos)
    $lblRange.AutoSize = $true
    $tabOps.Controls.Add($lblRange)
    $txtStart = New-Object System.Windows.Forms.TextBox
    $txtStart.Font = New-Object System.Drawing.Font('Segoe UI', 11)
    $txtStart.Location = [System.Drawing.Point]::new($ctlX, $yPos)
    $txtStart.Size = New-Object System.Drawing.Size(50,25)
    $txtStart.BackColor = $global:theme.CardBackground
    $txtStart.ForeColor = $global:theme.TextPrimary
    $txtStart.Text = '1'
    $tabOps.Controls.Add($txtStart)
    $lblTo = New-Object System.Windows.Forms.Label
    $lblTo.Text = ' to '
    $lblTo.Font = New-Object System.Drawing.Font('Segoe UI', 11)
    $lblTo.Location = [System.Drawing.Point]::new($ctlX+60, $yPos)
    $lblTo.AutoSize = $true
    $tabOps.Controls.Add($lblTo)
    $txtEnd = New-Object System.Windows.Forms.TextBox
    $txtEnd.Font = New-Object System.Drawing.Font('Segoe UI', 11)
    $txtEnd.Location = [System.Drawing.Point]::new($ctlX+90, $yPos)
    $txtEnd.Size = New-Object System.Drawing.Size(50,25)
    $txtEnd.BackColor = $global:theme.CardBackground
    $txtEnd.ForeColor = $global:theme.TextPrimary
    $txtEnd.Text = '10'
    $tabOps.Controls.Add($txtEnd)
    $yPos += 50

    # Bulk action buttons
    $btnBulkAdd = New-Object System.Windows.Forms.Button
    $btnBulkAdd.Text = 'Create Networks'
    $btnBulkAdd.Font = New-Object System.Drawing.Font('Segoe UI', 11)
    $btnBulkAdd.Size = New-Object System.Drawing.Size(180,35)
    $btnBulkAdd.Location = [System.Drawing.Point]::new($secX, $yPos)
    $btnBulkAdd.BackColor = $global:theme.Primary
    $btnBulkAdd.ForeColor = $global:theme.CardBackground
    $btnBulkAdd.FlatStyle = 'Flat'
    $btnBulkAdd.Add_Click({ Add-BulkNetworks })
    $tabOps.Controls.Add($btnBulkAdd)

    $btnBulkRem = New-Object System.Windows.Forms.Button
    $btnBulkRem.Text = 'Remove Networks'
    $btnBulkRem.Font = New-Object System.Drawing.Font('Segoe UI', 11)
    $btnBulkRem.Size = New-Object System.Drawing.Size(180,35)
    $btnBulkRem.Location = [System.Drawing.Point]::new($ctlX, $yPos)
    $btnBulkRem.BackColor = $global:theme.Error
    $btnBulkRem.ForeColor = $global:theme.CardBackground
    $btnBulkRem.FlatStyle = 'Flat'
    $btnBulkRem.Add_Click({ Remove-BulkNetworks })
    $tabOps.Controls.Add($btnBulkRem)

    # Status bar
    $status = New-Object System.Windows.Forms.StatusBar
    $status.Font = New-Object System.Drawing.Font('Segoe UI', 10)
    $status.BackColor = $global:theme.CardBackground
    $status.ForeColor = $global:theme.TextSecondary
    $status.SizingGrip = $false
    $status.Dock = 'Bottom'
    $ContentPanel.Controls.Add($status)

    # --- Functions ---
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