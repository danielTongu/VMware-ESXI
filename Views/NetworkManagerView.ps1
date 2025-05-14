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

    # Clear UI
    $ContentPanel.Controls.Clear()

    # Header and offline banner
    $lblHeader = [System.Windows.Forms.Label]::new()
    $lblHeader.Text = 'Network Management'
    $lblHeader.Font = [System.Drawing.Font]::new('Segoe UI',16,[System.Drawing.FontStyle]::Bold)
    $lblHeader.Location = [System.Drawing.Point]::new(10,10)
    $lblHeader.AutoSize = $true
    $ContentPanel.Controls.Add($lblHeader)

    if (-not $global:IsLoggedIn -or $global:VMwareConfig.OfflineMode) {
        $lblOffline = [System.Windows.Forms.Label]::new()
        $lblOffline.Text = 'OFFLINE or not logged in: limited network functionality'
        $lblOffline.Font = [System.Drawing.Font]::new('Segoe UI',10,[System.Drawing.FontStyle]::Italic)
        $lblOffline.ForeColor = [System.Drawing.Color]::DarkRed
        $lblOffline.AutoSize = $true
        $lblOffline.Location = [System.Drawing.Point]::new(260,16)
        $ContentPanel.Controls.Add($lblOffline)
    }

    # Tab control
    $tabControl = [System.Windows.Forms.TabControl]::new()
    $tabControl.Location = [System.Drawing.Point]::new(10,40)
    $tabControl.Size     = [System.Drawing.Size]::new(780,450)
    $ContentPanel.Controls.Add($tabControl)

    # --- Overview Tab ---
    $tabOverview = [System.Windows.Forms.TabPage]::new()
    $tabOverview.Text = 'Overview'
    $tabControl.Controls.Add($tabOverview)

    
    # Grid
    $grid = [System.Windows.Forms.DataGridView]::new()
    $grid.Location = [System.Drawing.Point]::new(10,10)
    $grid.Size     = [System.Drawing.Size]::new(750,350)
    $grid.ReadOnly = $true; $grid.AllowUserToAddRows = $false
    $grid.SelectionMode = 'FullRowSelect'; $grid.AutoSizeColumnsMode = 'Fill'
    $grid.AutoGenerateColumns = $false
    foreach ($colName in 'Name','Type','vSwitch','VLAN','Ports','Used') {
        $col = [System.Windows.Forms.DataGridViewTextBoxColumn]::new()
        $col.Name = $colName; $col.HeaderText = $colName
        $grid.Columns.Add($col) | Out-Null
    }
    $tabOverview.Controls.Add($grid)



    # Refresh button
    $btnRefresh = [System.Windows.Forms.Button]::new()
    $btnRefresh.Text = 'Refresh'
    $btnRefresh.Size = [System.Drawing.Size]::new(100,30)
    $btnRefresh.Location = [System.Drawing.Point]::new(660,370)
    $btnRefresh.Add_Click({ Refresh-NetworkData })
    $tabOverview.Controls.Add($btnRefresh)



    # --- Operations Tab ---
    $tabOps = [System.Windows.Forms.TabPage]::new(); $tabOps.Text = 'Operations'; $tabControl.Controls.Add($tabOps)



    # Single network controls
    $lblName = [System.Windows.Forms.Label]::new(); 
    $lblName.Text='Network Name:'; 
    $lblName.Location=[System.Drawing.Point]::new(10,10); 
    $lblName.AutoSize=$true; 
    $tabOps.Controls.Add($lblName)

    $txtName = [System.Windows.Forms.TextBox]::new(); 
    $txtName.Location=[System.Drawing.Point]::new(120,10); 
    $txtName.Size=[System.Drawing.Size]::new(200,20); 
    $tabOps.Controls.Add($txtName)

    $lblSwitch=[System.Windows.Forms.Label]::new();
    $lblSwitch.Text='vSwitch:';
    $lblSwitch.Location=[System.Drawing.Point]::new(10,40);
    $lblSwitch.AutoSize=$true;
    $tabOps.Controls.Add($lblSwitch)

    $cmbSwitch=[System.Windows.Forms.ComboBox]::new();
    $cmbSwitch.Location=[System.Drawing.Point]::new(120,40);
    $cmbSwitch.Size=[System.Drawing.Size]::new(200,20);
    $tabOps.Controls.Add($cmbSwitch)

    $lblVLAN=[System.Windows.Forms.Label]::new();
    $lblVLAN.Text='VLAN ID:';
    $lblVLAN.Location=[System.Drawing.Point]::new(10,70);
    $lblVLAN.AutoSize=$true;
    $tabOps.Controls.Add($lblVLAN)

    $txtVLAN=[System.Windows.Forms.TextBox]::new();
    $txtVLAN.Location=[System.Drawing.Point]::new(120,70);
    $txtVLAN.Size=[System.Drawing.Size]::new(60,20);
    $tabOps.Controls.Add($txtVLAN)

    $btnAdd=[System.Windows.Forms.Button]::new();
    $btnAdd.Text='Add Port Group';
    $btnAdd.Size=[System.Drawing.Size]::new(120,30);
    $btnAdd.Location=[System.Drawing.Point]::new(10,100);
    $btnAdd.Add_Click({ Add-Network });
    $tabOps.Controls.Add($btnAdd)

    $btnRemove=[System.Windows.Forms.Button]::new();
    $btnRemove.Text='Remove Port Group';
    $btnRemove.Size=[System.Drawing.Size]::new(120,30);
    $btnRemove.Location=[System.Drawing.Point]::new(140,100);
    $btnRemove.Add_Click({ Remove-Network });
    $tabOps.Controls.Add($btnRemove)



    # Bulk
    $lblBulk=[System.Windows.Forms.Label]::new();
    $lblBulk.Text='Bulk Student Networks';
    $lblBulk.Font=[System.Drawing.Font]::new('Segoe UI',12,[System.Drawing.FontStyle]::Bold);
    $lblBulk.Location=[System.Drawing.Point]::new(10,150);
    $lblBulk.AutoSize=$true;
    $tabOps.Controls.Add($lblBulk)

    $lblCourse=[System.Windows.Forms.Label]::new();
    $lblCourse.Text='Course Prefix:';
    $lblCourse.Location=[System.Drawing.Point]::new(10,180);
    $lblCourse.AutoSize=$true;
    $tabOps.Controls.Add($lblCourse)

    $txtCourse=[System.Windows.Forms.TextBox]::new();
    $txtCourse.Location=[System.Drawing.Point]::new(120,180);
    $txtCourse.Size=[System.Drawing.Size]::new(100,20);
    $tabOps.Controls.Add($txtCourse)

    $lblRange=[System.Windows.Forms.Label]::new();
    $lblRange.Text='Range:';
    $lblRange.Location=[System.Drawing.Point]::new(10,210);
    $lblRange.AutoSize=$true;

    $tabOps.Controls.Add($lblRange)
    $txtStart=[System.Windows.Forms.TextBox]::new();
    $txtStart.Location=[System.Drawing.Point]::new(120,210);
    $txtStart.Size=[System.Drawing.Size]::new(40,20);
    $txtStart.Text='1';
    $tabOps.Controls.Add($txtStart)

    $lblTo=[System.Windows.Forms.Label]::new();
    $lblTo.Text='to';
    $lblTo.Location=[System.Drawing.Point]::new(170,210);
    $lblTo.AutoSize=$true;
    $tabOps.Controls.Add($lblTo)

    $txtEnd=[System.Windows.Forms.TextBox]::new();
    $txtEnd.Location=[System.Drawing.Point]::new(200,210);
    $txtEnd.Size=[System.Drawing.Size]::new(40,20);
    $txtEnd.Text='10';
    $tabOps.Controls.Add($txtEnd)
    
    $btnBulkAdd=[System.Windows.Forms.Button]::new();
    $btnBulkAdd.Text='Create';
    $btnBulkAdd.Size=[System.Drawing.Size]::new(180,30);
    $btnBulkAdd.Location=[System.Drawing.Point]::new(10,240);
    $btnBulkAdd.Add_Click({ Add-BulkNetworks });
    $tabOps.Controls.Add($btnBulkAdd)

    $btnBulkRem=[System.Windows.Forms.Button]::new();
    $btnBulkRem.Text='Remove';
    $btnBulkRem.Size=[System.Drawing.Size]::new(180,30);
    $btnBulkRem.Location=[System.Drawing.Point]::new(200,240);
    $btnBulkRem.Add_Click({ Remove-BulkNetworks });
    $tabOps.Controls.Add($btnBulkRem)


    # Status bar
    $status=[System.Windows.Forms.StatusBar]::new();
    $status.Location=[System.Drawing.Point]::new(10,500);
    $status.Size=[System.Drawing.Size]::new(780,22);
    $ContentPanel.Controls.Add($status)



    function Refresh-NetworkData {
        # Update the status bar to indicate loading
        $status.Text='Loading...';$ContentPanel.Refresh()
        
        # Get a safe connection object
        $conn=Get-ConnectionSafe

        # If no connection is available, clear the grid and update the status
        if($null -eq $conn){ 
            $grid.DataSource=@(); 
            $status.Text='Offline/no auth'; 
            return 
        }

        try {
            # Retrieve virtual switches and port groups from the server
            $vs=Get-VirtualSwitch -Server $conn
            $pgs=Get-VirtualPortGroup -Server $conn

            # Clear and populate the vSwitch combo box
            $cmbSwitch.Items.Clear()
            foreach($v in $vs){
                $cmbSwitch.Items.Add($v.Name)
            }

            # Set the first item as selected if there are items in the combo box
            if($cmbSwitch.Items.Count){
                $cmbSwitch.SelectedIndex=0
            }

            # Create a list to hold network data
            $list=[System.Collections.ArrayList]::new()

            # Add virtual switch data to the list
            foreach($v in $vs){$list.Add([PSCustomObject]@{
                    Name=$v.Name;
                    Type='vSwitch';
                    vSwitch='';
                    VLAN='';
                    Ports=$v.NumPorts;
                    Used=$v.NumPortsAvailable
            })|Out-Null}

            # Add port group data to the list
            foreach($p in $pgs){ $list.Add([PSCustomObject]@{
                Name=$p.Name;
                Type='Port Group';
                vSwitch=$p.VirtualSwitchName;
                VLAN=$p.VLanId;
                Ports='';Used=''
            })|Out-Null}

            # Bind the list to the grid and update the status
            $grid.DataSource=$list; 
            $status.Text='Loaded'
        } catch {
            # Handle errors during data refresh
            Write-Warning "Refresh failed: $_"; $status.Text='Error'
        }
    }

    function Add-Network {
        # Get a safe connection object
        $conn = Get-ConnectionSafe
        if ($null -eq $conn) {
            # Update the status bar if offline or no authentication
            $status.Text = 'Offline/no auth'
            return
        }
        try {
            # Validate that the network name is not empty
            if (-not $txtName.Text) {
                throw 'Name empty'
            }
            # Validate that a vSwitch is selected
            if (-not $cmbSwitch.SelectedItem) {
                throw 'Select switch'
            }
            # Update the status bar to indicate the addition process
            $status.Text = 'Adding...'
            $ContentPanel.Refresh()
            # Call the VMwareNetwork method to create the port group
            [VMwareNetwork]::CreateStudentPortGroup($txtName.Text, $cmbSwitch.SelectedItem)
            # Update the status bar to indicate success
            $status.Text = 'Added'
            # Refresh the network data to reflect changes
            Refresh-NetworkData
        } catch {
            # Handle errors during the addition process
            Write-Warning "Add failed: $_"
            $status.Text = 'Error'
        }
    }

    function Remove-Network {
        # Get a safe connection object
        $conn = Get-ConnectionSafe
        if ($null -eq $conn) {
            # Update the status bar if offline or no authentication
            $status.Text = 'Offline/no auth'
            return
        }
        try {
            # Validate that the network name is not empty
            if (-not $txtName.Text) {
                throw 'Name empty'
            }
            # Confirm the removal of the port group
            $confirmation = [System.Windows.Forms.MessageBox]::Show(
                "Remove '$($txtName.Text)'?", 
                'Confirm', 
                [System.Windows.Forms.MessageBoxButtons]::YesNo, 
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
            if ($confirmation -ne 'Yes') {
                return
            }
            # Update the status bar to indicate the removal process
            $status.Text = 'Removing...'
            $ContentPanel.Refresh()
            # Call the VMwareNetwork method to remove the port group
            [VMwareNetwork]::RemovePortGroup($txtName.Text)
            # Update the status bar to indicate success
            $status.Text = 'Removed'
            # Refresh the network data to reflect changes
            Refresh-NetworkData
        } catch {
            # Handle errors during the removal process
            Write-Warning "Remove failed: $_"
            $status.Text = 'Error'
        }
    }

    
    function Add-BulkNetworks {
        # Get a safe connection object
        $conn = Get-ConnectionSafe
        if ($null -eq $conn) {
            # Update the status bar if offline or no authentication
            $status.Text = 'Offline/no auth'
            return
        }
        try {
            # Validate that the course prefix is not empty
            if (-not $txtCourse.Text) {
                throw 'Prefix empty'
            }
            # Parse the start and end range as integers
            $s = [int]$txtStart.Text
            $e = [int]$txtEnd.Text
            # Validate that the start range is less than or equal to the end range
            if ($s -gt $e) {
                throw 'Invalid range'
            }
            # Confirm the creation of bulk networks
            $confirmation = [System.Windows.Forms.MessageBox]::Show(
                "Create ${txtCourse.Text} $s-$e?", 
                'Confirm', 
                [System.Windows.Forms.MessageBoxButtons]::YesNo, 
                [System.Windows.Forms.MessageBoxIcon]::Question
            )
            if ($confirmation -ne 'Yes') {
                return
            }
            # Update the status bar to indicate the creation process
            $status.Text = 'Creating...'
            $ContentPanel.Refresh()
            # Call the CourseManager method to create the student networks
            [CourseManager]::CreateStudentNetworks($txtCourse.Text, $s, $e)
            # Update the status bar to indicate success
            $status.Text = 'Done'
            # Refresh the network data to reflect changes
            Refresh-NetworkData
        } catch {
            # Handle errors during the bulk addition process
            Write-Warning "Bulk add failed: $_"
            $status.Text = 'Error'
        }
    }

    
    function Remove-BulkNetworks {
        # Get a safe connection object
        $conn = Get-ConnectionSafe
        if ($null -eq $conn) {
            # Update the status bar if offline or no authentication
            $status.Text = 'Offline/no auth'
            return
        }
        try {
            # Validate that the course prefix is not empty
            if (-not $txtCourse.Text) {
                throw 'Prefix empty'
            }
            # Parse the start and end range as integers
            $s = [int]$txtStart.Text
            $e = [int]$txtEnd.Text
            # Validate that the start range is less than or equal to the end range
            if ($s -gt $e) {
                throw 'Invalid range'
            }
            # Confirm the removal of bulk networks
            $confirmation = [System.Windows.Forms.MessageBox]::Show(
                "Remove ${txtCourse.Text} $s-$e?", 
                'Confirm', 
                [System.Windows.Forms.MessageBoxButtons]::YesNo, 
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
            if ($confirmation -ne 'Yes') {
                return
            }
            # Update the status bar to indicate the removal process
            $status.Text = 'Removing...'
            $ContentPanel.Refresh()
            # Call the CourseManager method to remove the student networks
            [CourseManager]::RemoveStudentNetworks($txtCourse.Text, $s, $e)
            # Update the status bar to indicate success
            $status.Text = 'Done'
            # Refresh the network data to reflect changes
            Refresh-NetworkData
        } catch {
            # Handle errors during the bulk removal process
            Write-Warning "Bulk remove failed: $_"
            $status.Text = 'Error'
        }
    }

    # Initial load
    Refresh-NetworkData
}
