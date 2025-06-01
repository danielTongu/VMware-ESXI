# ─────────────────────────  Assemblies  ──────────────────────────────────────
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms.DataVisualization


# ─────────────────────────  Public entry point  ──────────────────────────────
function Show-NetworksView {
    <#
    .SYNOPSIS
        Displays the networks view in the specified content panel.
    .PARAMETER ContentPanel
        The panel where the networks view will be displayed.
    .OUTPUTS
        [hashtable] – Contains references to UI controls for further interaction.
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Forms.Panel] $ContentPanel
    )

    $script:uiRefs = New-NetworksLayout -ContentPanel $ContentPanel
    $data = Get-NetworksData -Refs $script:uiRefs

    if ($data) {
        $script:uiRefs['Data'] = $data  # Store the data in uiRefs for later access
        Update-NetworksWithData -Refs $script:uiRefs -Data $data
        Wire-UIEvents -Refs $script:uiRefs
    } 
}



# ─────────────────────────  Layout builders  ─────────────────────────────────
function New-NetworksLayout {
    <#
    .SYNOPSIS
        Creates the layout for the networks view.
    .PARAMETER ContentPanel
        The host panel into which the networks view is drawn.
    .OUTPUTS
        [hashtable] – Contains references to UI controls for further interaction.
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Forms.Panel] $ContentPanel
    )

    try {
        $ContentPanel.Controls.Clear()
        $ContentPanel.BackColor = $script:Theme.LightGray
        $refs = @{ ContentPanel = $ContentPanel }

        # ── Root table ------------------------------------------------------------
        $root              = New-Object System.Windows.Forms.TableLayoutPanel
        $root.Dock         = 'Fill'
        $root.ColumnCount  = 1
        $root.RowCount     = 4
        $null = $root.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle 'Percent',100))
        $null = $root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'AutoSize'))
        $null = $root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'Percent',100))
        $null = $root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'AutoSize'))
        $null = $root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'AutoSize'))
        $ContentPanel.Controls.Add($root)

        # ── Header ----------------------------------------------------------------
        $headerPanel      = New-NetworksHeader
        $root.Controls.Add($headerPanel, 0, 0)
        $lblRefresh       = $headerPanel.Controls.Find('LastRefreshLabel', $true)[0]
        $refs['LastRefreshLabel'] = $lblRefresh

        # ── Tab-control -----------------------------------------------------------
        $tabs             = New-Object System.Windows.Forms.TabControl
        $tabs.Dock        = 'Fill'
        $tabs.SizeMode    = 'Normal'
        $tabs.Padding = New-Object System.Drawing.Point(20, 10)
        $tabs.Font        = New-Object System.Drawing.Font('Segoe UI',10,[System.Drawing.FontStyle]::Bold)
        $tabs.BackColor   = $script:Theme.LightGray
        $root.Controls.Add($tabs, 0, 1)

        # 1. Networks Manager Tab ──────────────────────────────────────────────────
        $tabManage = New-Object System.Windows.Forms.TabPage 'Manage'
        $tabManage.BackColor = $script:Theme.White
        
        $manageLayout = New-Object System.Windows.Forms.TableLayoutPanel
        $manageLayout.Dock = 'Fill'
        $manageLayout.ColumnCount = 2
        $manageLayout.RowCount = 2
        $null = $manageLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle 'Percent',50))
        $null = $manageLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle 'Percent',50))
        $tabManage.Controls.Add($manageLayout)

        # Description
        $tabNetDescription = New-Object System.Windows.Forms.Label
        $tabNetDescription.Text = "Manages Standard switches and their associated port groups.`n"
        $tabNetDescription.ForeColor = $script:Theme.PrimaryDark
        $tabNetDescription.Font = New-Object System.Drawing.Font('Segoe UI', 9)
        $tabNetDescription.Anchor = 'Left'
        $tabNetDescription.AutoSize = $true
        $manageLayout.Controls.Add($tabNetDescription,0,0)
        $manageLayout.SetColumnSpan($tabNetDescription,2)

        #── Left Panel: Add Single Network ───────────────────────────────────────────
        $grNetAdd = New-Object System.Windows.Forms.GroupBox
        $grNetAdd.Text = 'Single Network'
        $grNetAdd.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
        $grNetAdd.Dock = 'Fill'
        $grNetAdd.Margin = New-Object System.Windows.Forms.Padding(5)
        $grNetAdd.Padding = New-Object System.Windows.Forms.Padding(10)

        $layoutNetAdd = New-Object System.Windows.Forms.TableLayoutPanel
        $layoutNetAdd.Dock = 'Fill'
        $layoutNetAdd.ColumnCount = 4 # label, dropdown or field, button, empty
        $layoutNetAdd.RowCount = 5    # class, student, delete, add, empty
        
        $margin = New-Object System.Windows.Forms.Padding(0,5,5,10)

        # Select class
        $lblClass = New-Object System.Windows.Forms.Label
        $lblClass.Text = "Class:"
        $lblClass.Anchor = 'Right'
        $lblClass.TextAlign = 'MiddleRight'
        $layoutNetAdd.Controls.Add($lblClass, 0, 0)

        $cmbClasses = New-Object System.Windows.Forms.ComboBox
        $cmbClasses.DropDownStyle = 'DropDownList'
        $cmbClasses.Margin = $margin
        $layoutNetAdd.Controls.Add($cmbClasses, 1, 0)
        $layoutNetAdd.SetColumnSpan($cmbClasses, 2)

        # Select Student
        $lblStudent = New-Object System.Windows.Forms.Label
        $lblStudent.Text = "Student:"
        $lblStudent.Anchor = 'Right'
        $lblStudent.TextAlign = 'MiddleRight'
        $layoutNetAdd.Controls.Add($lblStudent, 0, 1)

        $cmbStudents = New-Object System.Windows.Forms.ComboBox
        $cmbStudents.DropDownStyle = 'DropDownList'
        $cmbStudents.Margin = $margin
        $layoutNetAdd.Controls.Add($cmbStudents, 1, 1)
        $layoutNetAdd.SetColumnSpan($cmbStudents, 2)

        # Delete Network
        $lblDeleteNet = New-Object System.Windows.Forms.Label
        $lblDeleteNet.Text = "Delete Network:"
        $lblDeleteNet.Anchor = 'Right'
        $lblDeleteNet.TextAlign = 'MiddleRight'
        $layoutNetAdd.Controls.Add($lblDeleteNet, 0, 2)

        $cmbStudentNetworks = New-Object System.Windows.Forms.ComboBox
        $cmbStudentNetworks.Dock = 'Fill'
        $cmbStudentNetworks.AutoSize = $true
        $cmbStudentNetworks.Margin = $margin
        $cmbStudentNetworks.DropDownStyle = 'DropDownList'
        $layoutNetAdd.Controls.Add($cmbStudentNetworks, 1, 2)
        $refs['NetworkNameInput'] = $cmbStudentNetworks

        $btnDelNet = New-Object System.Windows.Forms.Button
        $btnDelNet.Text = "Delete"
        $btnDelNet.Dock = 'Top'
        $btnDelNet.AutoSize = $true
        $btnDelNet.Margin =$margin
        $btnDelNet.BackColor = $script:Theme.Error
        $btnDelNet.ForeColor = $script:Theme.White
        $layoutNetAdd.Controls.Add($btnDelNet, 2, 2)
        $refs['DeleteNetworkButton'] = $btnDelNet

        # Add Network
        $lblAddNet = New-Object System.Windows.Forms.Label
        $lblAddNet.Dock = 'Top'
        $lblAddNet.Text = "Add Network:"
        $lblAddNet.Anchor = 'Right'
        $lblAddNet.TextAlign = 'MiddleRight'
        $layoutNetAdd.Controls.Add($lblAddNet, 0, 3)

        $txtNewNetwork = New-Object System.Windows.Forms.TextBox
        $txtNewNetwork.Dock = 'Fill'
        $txtNewNetwork.AutoSize = $true
        $txtNewNetwork.Margin = $margin
        $layoutNetAdd.Controls.Add($txtNewNetwork, 1, 3)

        $btnAddNet = New-Object System.Windows.Forms.Button
        $btnAddNet.Text = "Add"
        $btnAddNet.Dock = 'Fill'
        $btnAddNet.AutoSize = $true
        $btnAddNet.Margin = $margin
        $btnAddNet.BackColor = $script:Theme.Primary
        $btnAddNet.ForeColor = $script:Theme.White
        $layoutNetAdd.Controls.Add($btnAddNet, 2, 3)
        $refs['AddNetworkButton'] = $btnAddNet
        
        # $grNetAdd = New-Object System.Windows.Forms.GroupBox
        # $grNetAdd.Text = 'Single Network'
        # $grNetAdd.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
        # $grNetAdd.Dock = 'Fill'
        # $grNetAdd.Margin = New-Object System.Windows.Forms.Padding(5)
        # $grNetAdd.Padding = New-Object System.Windows.Forms.Padding(10)

        # $layoutNetAdd = New-Object System.Windows.Forms.TableLayoutPanel
        # $layoutNetAdd.Dock = 'Fill'
        # $layoutNetAdd.ColumnCount = 3
        # $layoutNetAdd.RowCount = 2
        # $null = $layoutNetAdd.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle 'AutoSize'))
        # $null = $layoutNetAdd.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle 'Percent',100))
        # $null = $layoutNetAdd.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle 'Percent',100))

        # # Network Name Label
        # $labelNetworkName = New-Object System.Windows.Forms.Label
        # $labelNetworkName.Text = "Network Name:"
        # $labelNetworkName.Anchor = 'Left'
        # $labelNetworkName.AutoSize = $true
        # $layoutNetAdd.Controls.Add($labelNetworkName, 0, 0)
        
        # # Network Name Input
        # $txtNewNetwork = New-Object System.Windows.Forms.TextBox
        # $txtNewNetwork.Dock = 'Fill'
        # $txtNewNetwork.Margin = New-Object System.Windows.Forms.Padding(0,0,0,5)
        # $layoutNetAdd.Controls.Add($txtNewNetwork, 1, 0)
        # $refs['NetworkNameInput'] = $txtNewNetwork
        
        # # Add Button
        # $btnAddNet = New-Object System.Windows.Forms.Button
        # $btnAddNet.Text = "Add Network"
        # $btnAddNet.Dock = 'Top'
        # $btnAddNet.Size = New-Object System.Drawing.Size(0, 35)
        # $btnAddNet.Margin = New-Object System.Windows.Forms.Padding(0,5,5,0)
        # $btnAddNet.BackColor = $script:Theme.Primary
        # $btnAddNet.ForeColor = $script:Theme.White
        # $layoutNetAdd.Controls.Add($btnAddNet, 1, 1)
        # $refs['AddNetworkButton'] = $btnAddNet
        
        # # Delete Button
        # $btnDelNet = New-Object System.Windows.Forms.Button
        # $btnDelNet.Text = "Delete Network"
        # $btnDelNet.Dock = 'Top'
        # $btnDelNet.Size = New-Object System.Drawing.Size(0, 35)
        # $btnDelNet.Margin = New-Object System.Windows.Forms.Padding(0,5,5,0)
        # $btnDelNet.BackColor = $script:Theme.Error
        # $btnDelNet.ForeColor = $script:Theme.White
        # $layoutNetAdd.Controls.Add($btnDelNet, 2, 1)
        # $refs['DeleteNetworkButton'] = $btnDelNet
        
        $grNetAdd.Controls.Add($layoutNetAdd)
        $manageLayout.Controls.Add($grNetAdd, 0, 1)
        
        #── Right Panel: Multiple Networks ────────────────────────────────────
        $grMult = New-Object System.Windows.Forms.GroupBox
        $grMult.Text = 'Multiple Networks'
        $grMult.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
        $grMult.Dock = 'Fill'
        $grMult.Margin = New-Object System.Windows.Forms.Padding(5)
        $grMult.Padding = New-Object System.Windows.Forms.Padding(10)

        $layoutMult = New-Object System.Windows.Forms.TableLayoutPanel
        $layoutMult.Dock = 'Fill'
        $layoutMult.ColumnCount = 4 # label, dropdown or field or NumericUpDown, NumericUpDown or button, empty
        $layoutMult.RowCount = 5 # class, start, end, empty

        # Select class label
        $lblMultClass = New-Object System.Windows.Forms.Label
        $lblMultClass.Text = "Class:"
        $lblMultClass.Anchor = 'Right'
        $lblMultClass.TextAlign = 'MiddleRight'
        $layoutMult.Controls.Add($lblMultClass, 0, 0)

        # Select class dropdown
        $cmbMultClasses = New-Object System.Windows.Forms.ComboBox
        $cmbMultClasses.Margin = $margin
        $cmbMultClasses.DropDownStyle = 'DropDownList'
        $layoutMult.Controls.Add($cmbMultClasses, 1, 0)
        $layoutMult.SetColumnSpan($cmbMultClasses, 3)
        $refs['CoursePrefixInput'] = $cmbMultClasses

        # Range label start
        $labelStartNum = New-Object System.Windows.Forms.Label
        $labelStartNum.Text = "Start Student:"
        $labelStartNum.AutoSize = $true
        $labelStartNum.Anchor = 'Right'
        $labelStartNum.TextAlign = 'MiddleRight'
        $layoutMult.Controls.Add($labelStartNum, 0, 1)

        # Start NumericUpDown
        $inputStartNum = New-Object System.Windows.Forms.NumericUpDown
        $inputStartNum.Margin = $margin
        $inputStartNum.Minimum = 1
        $inputStartNum.Maximum = 1000
        $layoutMult.Controls.Add($inputStartNum, 1, 1)
        $refs['StartNumberInput'] = $inputStartNum

        # Range label end
        $labelEndNum = New-Object System.Windows.Forms.Label
        $labelEndNum.Text = "End Student:"
        $labelEndNum.AutoSize = $true
        $labelEndNum.Anchor = 'Right'
        $labelEndNum.TextAlign = 'MiddleRight'
        $layoutMult.Controls.Add($labelEndNum, 0, 2)

        # End NumericUpDown
        $inputEndNum = New-Object System.Windows.Forms.NumericUpDown
        $inputEndNum.Margin = $margin
        $inputEndNum.Minimum = 1
        $inputEndNum.Maximum = 1000
        $layoutMult.Controls.Add($inputEndNum, 1, 2)
        $refs['EndNumberInput'] = $inputEndNum

        # Delete selected class network button
        $btnDelMult = New-Object System.Windows.Forms.Button
        $btnDelMult.Margin = $margin
        $btnDelMult.Dock = 'Fill'
        $btnDelMult.Text = "Delete Networks"
        $btnDelMult.AutoSize = $true
        $btnDelMult.BackColor = $script:Theme.Error
        $btnDelMult.ForeColor = $script:Theme.White
        $layoutMult.Controls.Add($btnDelMult, 1, 3)

        # Add class network button
        $btnAddMult = New-Object System.Windows.Forms.Button
        $btnAddMult.Margin = $margin
        $btnAddMult.Text = "Add Networks"
        $btnAddMult.Dock = 'Fill'
        $btnAddMult.AutoSize = $true
        $btnAddMult.BackColor = $script:Theme.Primary
        $btnAddMult.ForeColor = $script:Theme.White
        $layoutMult.Controls.Add($btnAddMult, 2, 3)
        
        $grMult.Controls.Add($layoutMult)
        $manageLayout.Controls.Add($grMult, 1, 1)
        $tabs.TabPages.Add($tabManage)

        # 2. Hosts -----------------------------------------------------------------
        $tabHosts = New-Object System.Windows.Forms.TabPage 'Hosts'
        $tabHosts.BackColor = $script:Theme.White
        $hostsTable = New-NetworksTable -Name 'HostsTable' -Refs ([ref]$refs)
        $tabHosts.Controls.Add($hostsTable)
        $tabs.TabPages.Add($tabHosts)

        # 3. Network Adapters ------------------------------------------------------
        $tabNics = New-Object System.Windows.Forms.TabPage 'Adapters'
        $tabNics.BackColor = $script:Theme.White
        $nicsTable = New-NetworksTable -Name 'NicsTable' -Refs ([ref]$refs)
        $tabNics.Controls.Add($nicsTable)
        $tabs.TabPages.Add($tabNics)

        # 4. Templates -------------------------------------------------------------
        $tabTpl = New-Object System.Windows.Forms.TabPage 'Templates'
        $tabTpl.BackColor = $script:Theme.White
        $tplTable = New-NetworksTable -Name 'TemplatesTable' -Refs ([ref]$refs)
        $tabTpl.Controls.Add($tplTable)
        $tabs.TabPages.Add($tabTpl)

        # 5. Port Groups -----------------------------------------------------------
        $tabPg = New-Object System.Windows.Forms.TabPage 'Port Groups'
        $tabPg.BackColor = $script:Theme.White
        $pgTable = New-NetworksTable -Name 'PortGroupsTable' -Refs ([ref]$refs)
        $tabPg.Controls.Add($pgTable)
        $tabs.TabPages.Add($tabPg)

        # ── Actions bar -----------------------------------------------------------
        $actionsPanel                     = New-Object System.Windows.Forms.FlowLayoutPanel
        $actionsPanel.Dock                = 'Fill'
        $actionsPanel.Padding             = 10
        $actionsPanel.AutoSize            = $true
        $actionsPanel.BackColor           = $script:Theme.LightGray

        $root.Controls.Add($actionsPanel, 0, 2)

        $btnRefresh               = New-Object System.Windows.Forms.Button
        $btnRefresh.Text          = 'REFRESH'
        $btnRefresh.Font          = New-Object System.Drawing.Font('Segoe UI',10,[System.Drawing.FontStyle]::Bold)
        $btnRefresh.Size          = New-Object System.Drawing.Size(120,35)
        $btnRefresh.BackColor     = $script:Theme.Primary
        $btnRefresh.ForeColor     = $script:Theme.White
        $btnRefresh.FlatStyle     = 'Flat'

        $refs['RefreshButton'] = $btnRefresh
        $actionsPanel.Controls.Add($btnRefresh)

        # ── Footer ----------------------------------------------------------------
        $footer           = New-Object System.Windows.Forms.Panel
        $footer.Dock      = 'Bottom'
        $footer.Height    = 30
        $footer.BackColor = $script:Theme.LightGray

        $status           = New-Object System.Windows.Forms.Label
        $status.Name      = 'StatusLabel'
        $status.AutoSize  = $true
        $status.Font      = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
        $status.ForeColor = $script:Theme.Error
        $status.Text      = '---'
        $footer.Controls.Add($status)

        $root.Controls.Add($footer, 0, 3)
        $refs['StatusLabel'] = $status

        return $refs
    }
    finally {
        $ContentPanel.ResumeLayout($true)
    }
}

function New-NetworksHeader {
    <#
    .SYNOPSIS
        Creates the header panel for the networks view.
    .OUTPUTS
        [System.Windows.Forms.Panel] – Header panel with title and last refresh label.
    #>

    $panel              = New-Object System.Windows.Forms.Panel
    $panel.Dock         = 'Top'
    $panel.Height       = 100
    $panel.BackColor    = $script:Theme.Primary

    $lblTitle           = New-Object System.Windows.Forms.Label
    $lblTitle.Text      = 'NETWORK'
    $lblTitle.Font      = New-Object System.Drawing.Font('Segoe UI',18,[System.Drawing.FontStyle]::Bold)
    $lblTitle.ForeColor = $script:Theme.White
    $lblTitle.Location  = New-Object System.Drawing.Point(20,20)
    $lblTitle.AutoSize  = $true
    $panel.Controls.Add($lblTitle)

    $lblRefresh         = New-Object System.Windows.Forms.Label
    $lblRefresh.Name    = 'LastRefreshLabel'
    $lblRefresh.Text    = "Last refresh: $(Get-Date -Format 'HH:mm:ss tt')"
    $lblRefresh.Font    = New-Object System.Drawing.Font('Segoe UI',9)
    $lblRefresh.ForeColor = $script:Theme.White
    $lblRefresh.Location  = New-Object System.Drawing.Point(20,60)
    $lblRefresh.AutoSize  = $true
    $panel.Controls.Add($lblRefresh)

    return $panel
}

function New-NetworksTable {
    <#
    .SYNOPSIS
        Returns a panel that wraps an empty DataGridView.
    .PARAMETER Name
        Control name (also used in Refs).
    .PARAMETER Refs
        Hashtable reference to store the grid.
    #>

    param(
        [string] $Name,
        [ref] $Refs,
        [string[]] $PriorityFields = @()  # Fields to show first
    )

    $container = New-Object System.Windows.Forms.Panel
    $container.Dock = 'Fill'
    $container.BackColor = $script:Theme.White

    $grid = New-Object System.Windows.Forms.DataGridView
    $grid.Name = $Name
    $grid.Dock = 'Fill'
    $grid.AutoSizeColumnsMode = 'Fill'
    $grid.RowHeadersVisible = $false
    $grid.ReadOnly = $true
    $grid.AllowUserToAddRows = $false
    $grid.BackgroundColor = $script:Theme.White
    $grid.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $grid.ColumnHeadersDefaultCellStyle.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
    
    $container.Controls.Add($grid)
    $Refs.Value[$Name] = $grid

    return $container
}

function Set-StatusMessage {
    <#
    .SYNOPSIS
        Sets the status message with appropriate color coding.
    #>

    param(
        [hashtable] $Refs,
        [string]$Message,
        [ValidateSet('Success','Warning','Error','Info')][string]$Type = 'Info'
    )
    
    if ($Refs -and $Refs.ContainsKey('StatusLabel')) {
        $Refs.StatusLabel.Text = $Message
        $Refs.StatusLabel.ForeColor = switch ($Type) {
            'Success' { $script:Theme.Success }
            'Warning' { $script:Theme.Warning }
            'Error'   { $script:Theme.Error }
            default   { $script:Theme.PrimaryDarker }
        }
    }
}



# ─────────────────────────  Data collection  ─────────────────────────────────
function Get-NetworksData {
    <#
    .SYNOPSIS
        Collects data from vSphere for the networks view including class/student/network relationships.
        Handles both:
        1. Bulk-created networks (CLASS_S##)
        2. Manually added networks (any format)
    #>

    param([hashtable] $Refs)

    try {
        $conn = $script:Connection
        if (-not $conn) { 
            Set-StatusMessage -Refs $Refs -Message 'No connection to VMware server' -Type Error
            return $null 
        }

        $data = @{}
        
        # ─── Class > Student > Networks Mapping ──────────────────────────────
        Set-StatusMessage -Refs $Refs -Message "Collecting class/student/network relationships..." -Type Info
        
        $portGroups = Get-VirtualPortGroup -Server $conn
        $classMap = @{}
        $allNetworks = @{}
        
        foreach ($pg in $portGroups) {
            $networkName = $pg.Name
            $regex = '^([A-Za-z0-9]+)_S(\d{2})$' # Try to parse bulk-created networks (CLASS_S##)

            if ($networkName -match $regex) {
                $className = $matches[1]
                $studentNumber = $matches[2]
                
                if (-not $classMap.ContainsKey($className)) {
                    $classMap[$className] = @{}
                }

                if (-not $classMap[$className].ContainsKey($studentNumber)) {
                    $classMap[$className][$studentNumber] = @()
                }
                
                $classMap[$className][$studentNumber] += $networkName
            }

            # Track all networks regardless of format
            $allNetworks[$networkName] = $true
        }
        
        $data.ClassMap = $classMap
        $data.AllNetworks = $allNetworks.Keys | Sort-Object

        # ─── Host Info ──────────────────────────────────────────
        Set-StatusMessage -Refs $Refs -Message "Collecting host information..." -Type Info
        $data.HostInfo = Get-VMHost -Server $conn | Select-Object Name, 
            @{N='CPU Total (GHz)';E={[math]::Round($_.CpuTotalMhz/1000,1)}},
            @{N='Memory (GB)';E={[math]::Round($_.MemoryTotalGB,1)}},
            Model, Version, ConnectionState, PowerState

        # ─── Network Adapters ───────────────────────────────────
        Set-StatusMessage -Refs $Refs -Message "Collecting network adapters..." -Type Info
        $data.Adapters = Get-VMHostNetworkAdapter -Server $conn | Select-Object VMHost, Name, 
            Mac, IP, SubnetMask, @{N='Speed (Gbps)';E={[math]::Round($_.SpeedMb/1000,1)}}, FullDuplex, MTU, Connected

        # ─── Templates ──────────────────────────────────────────
        Set-StatusMessage -Refs $Refs -Message "Collecting templates..." -Type Info
        $data.Templates = Get-Template -Server $conn | Select-Object Name, 
            @{N='OS';E={$_.Guest}},  # Using .Guest instead of .GuestId for readability
            NumCpu, 
            @{N='Memory (GB)';E={$_.MemoryGB}},
            @{N='Provisioned (GB)';E={[math]::Round($_.ProvisionedSpaceGB,1)}},
            @{N='Used (GB)';E={[math]::Round($_.UsedSpaceGB,1)}},
            Version,
            @{N='Folder';E={$_.Folder.Name}},
            Notes,
            PersistentId

        # ─── Port Groups ────────────────────────────────────────
        Set-StatusMessage -Refs $Refs -Message "Collecting port groups..." -Type Info
        $data.PortGroups = Get-VirtualPortGroup -Server $conn | Select-Object Name, VlanId, 
            @{N='vSwitch';E={$_.VirtualSwitchName}},
            @{N='Host';E={(Get-VMHost -Id $_.VirtualSwitch.VMHostId).Name}},
            @{N='Security Policy';E={
                "Promiscuous:$($_.SecurityPolicy.AllowPromiscuous), " +
                "MAC:$($_.SecurityPolicy.MacChanges), " +
                "Forged:$($_.SecurityPolicy.ForgedTransmits)"
            }},
            @{N='Active Ports';E={($_.ExtensionData.Port | Where-Object {$_.Connected}).Count}}
        
        # ─── Set status message ─────────────────────────────────
        Set-StatusMessage -Refs $Refs -Message "Data collection complete." -Type Success

        return $data
    }
    catch {
        Write-Verbose "Data collection failed: $_"
        Set-StatusMessage -Refs $Refs -Message "Data error: $($_.Exception.Message)" -Type Error
        return $null
    }
}


# function Get-NetworksData {
#     <#
#     .SYNOPSIS
#         Collects data from vSphere for the networks view.
#     .PARAMETER Refs
#         Hashtable containing references to UI controls.
#     #>

#     param([hashtable] $Refs)

#     try {
#         $conn = $script:Connection
#         if (-not $conn) { 
#             Set-StatusMessage -Refs $Refs -Message 'No connection to VMware server' -Type Error
#             return $null 
#         }

#         $data = @{}

#         # ─── Host Info ──────────────────────────────────────────
#         Set-StatusMessage -Refs $Refs -Message "Collecting host information..." -Type Info
#         $data.HostInfo = Get-VMHost -Server $conn | Select-Object Name, 
#             @{N='CPU Total (GHz)';E={[math]::Round($_.CpuTotalMhz/1000,1)}},
#             @{N='Memory (GB)';E={[math]::Round($_.MemoryTotalGB,1)}},
#             Model, Version, ConnectionState, PowerState

#         # ─── Network Adapters ───────────────────────────────────
#         Set-StatusMessage -Refs $Refs -Message "Collecting network adapters..." -Type Info
#         $data.Adapters = Get-VMHostNetworkAdapter -Server $conn | Select-Object VMHost, Name, 
#             Mac, IP, SubnetMask, @{N='Speed (Gbps)';E={[math]::Round($_.SpeedMb/1000,1)}}, FullDuplex, MTU, Connected

#         # ─── Templates ──────────────────────────────────────────
#         Set-StatusMessage -Refs $Refs -Message "Collecting templates..." -Type Info
#         $data.Templates = Get-Template -Server $conn | Select-Object Name, 
#             @{N='OS';E={$_.Guest}},  # Using .Guest instead of .GuestId for readability
#             NumCpu, 
#             @{N='Memory (GB)';E={$_.MemoryGB}},
#             @{N='Provisioned (GB)';E={[math]::Round($_.ProvisionedSpaceGB,1)}},
#             @{N='Used (GB)';E={[math]::Round($_.UsedSpaceGB,1)}},
#             Version,
#             @{N='Folder';E={$_.Folder.Name}},
#             Notes,
#             PersistentId

#         # ─── Port Groups ────────────────────────────────────────
#         Set-StatusMessage -Refs $Refs -Message "Collecting port groups..." -Type Info
#         $data.PortGroups = Get-VirtualPortGroup -Server $conn | Select-Object Name, VlanId, 
#             @{N='vSwitch';E={$_.VirtualSwitchName}},
#             @{N='Host';E={(Get-VMHost -Id $_.VirtualSwitch.VMHostId).Name}},
#             @{N='Security Policy';E={
#                 "Promiscuous:$($_.SecurityPolicy.AllowPromiscuous), " +
#                 "MAC:$($_.SecurityPolicy.MacChanges), " +
#                 "Forged:$($_.SecurityPolicy.ForgedTransmits)"
#             }},
#             @{N='Active Ports';E={($_.ExtensionData.Port | Where-Object {$_.Connected}).Count}}
        
#         # ─── Set status message ─────────────────────────────────
#         Set-StatusMessage -Refs $Refs -Message "Data collection complete." -Type Success

#         # ─── Return collected data ─────────────────────────────
#         return $data
#     }
#     catch {
#         Write-Verbose "Data collection failed: $_"
#         Set-StatusMessage -Refs $Refs -Message "Data error: $($_.Exception.Message)" -Type Error
#         return $null
#     }
# }


# ─────────────────────────  Data-to-UI binder  ───────────────────────────────
function Update-NetworksWithData {
    <#
    .SYNOPSIS
        Updates the UI with collected data including populating dropdowns.
        Handles both bulk and individual networks.
    #>

    param(
        [hashtable] $Refs,
        [hashtable] $Data
    )

    if (-not $Refs -or -not $Data) {
        Write-Verbose "Refs or Data is null"
        return
    }

    Set-StatusMessage -Refs $Refs -Message "Updating UI with collected data..." -Type Info
    $Refs['LastRefreshLabel'].Text = "Last refresh: $(Get-Date -Format 'HH:mm:ss tt')"

    # ─── Populate Class Dropdowns ───────────────────────────────
    if ($Data.ClassMap) {
        $classNames = $Data.ClassMap.Keys | Sort-Object
        $Refs['cmbClasses'].Items.Clear()
        $Refs['cmbMultClasses'].Items.Clear()
        
        foreach ($className in $classNames) {
            $Refs['cmbClasses'].Items.Add($className)
            $Refs['cmbMultClasses'].Items.Add($className)
        }

        if ($classNames.Count -gt 0) {
            $Refs['cmbClasses'].SelectedIndex = 0
            $Refs['cmbMultClasses'].SelectedIndex = 0
        }
    }
    

    # ─── Wire Class Selection Change Events ─────────────────────
    $Refs['cmbClasses'].Add_SelectedIndexChanged({
        param($sender, $e)
        
        $selectedClass = $sender.SelectedItem
        if (-not $selectedClass -or -not $script:uiRefs.Data.ClassMap.ContainsKey($selectedClass)) { return }
        
        $studentNumbers = $script:uiRefs.Data.ClassMap[$selectedClass].Keys | Sort-Object { [int]$_ }
        $cmbStudents = $script:uiRefs['cmbStudents']
        $cmbStudents.Items.Clear()
        
        foreach ($studentNum in $studentNumbers) {
            $cmbStudents.Items.Add("Student $studentNum")
        }
        
        if ($studentNumbers.Count -gt 0) {
            $cmbStudents.SelectedIndex = 0
        }
    })


    # ─── Update Network List When Student Changes ────────────────
    $Refs['cmbStudents'].Add_SelectedIndexChanged({
        param($sender, $e)
        
        $selectedClass = $script:uiRefs['cmbClasses'].SelectedItem
        $selectedStudent = $sender.SelectedItem -replace 'Student ',''
        
        if (-not $selectedClass -or -not $selectedStudent) { return }
        
        # Get both the automatically created network and any additional ones
        $baseNetwork = "${selectedClass}_S${selectedStudent}"
        $allNetworks = @($baseNetwork)  # Start with the base network
        
        # Add any other networks that start with the student identifier
        foreach ($net in $script:uiRefs.Data.AllNetworks) {
            if ($net -ne $baseNetwork -and $net -like "${baseNetwork}_*") {
                $allNetworks += $net
            }
        }
        
        $cmbStudentNetworks = $script:uiRefs['cmbStudentNetworks']
        $cmbStudentNetworks.Items.Clear()
        
        foreach ($net in $allNetworks) {
            $cmbStudentNetworks.Items.Add($net)
        }
        
        if ($allNetworks.Count -gt 0) {
            $cmbStudentNetworks.SelectedIndex = 0
        }
    })

    # ─── Hosts Tab ──────────────────────────────────────────────
    $grid = $Refs['HostsTable']
    $grid.Rows.Clear()
    $grid.Columns.Clear()

    if ($Data.HostInfo) {
        $Data.HostInfo[0].PSObject.Properties.Name | ForEach-Object {
            $grid.Columns.Add($_, $_) | Out-Null
        }

        foreach ($info in $Data.HostInfo) {
            $row = $grid.Rows.Add()
            foreach ($prop in $info.PSObject.Properties.Name) {
                $grid.Rows[$row].Cells[$prop].Value = $info.$prop
            }
        }
    }
    else {
        $grid.Columns.Add('Status', 'Status') | Out-Null
        $grid.Rows.Add("No host data available") | Out-Null
    }

    # ─── Adapters Tab ───────────────────────────────────────────
    $grid = $Refs['NicsTable']
    $grid.Rows.Clear()
    $grid.Columns.Clear()

    if ($Data.Adapters) {
        $Data.Adapters[0].PSObject.Properties.Name | ForEach-Object {
            $grid.Columns.Add($_, $_) | Out-Null
        }

        foreach ($nic in $Data.Adapters) {
            $row = $grid.Rows.Add()
            foreach ($prop in $nic.PSObject.Properties.Name) {
                $grid.Rows[$row].Cells[$prop].Value = $nic.$prop
            }
            
            if (-not $nic.Connected) {
                $grid.Rows[$row].DefaultCellStyle.ForeColor = 'Red'
            }
        }
    }
    else {
        $grid.Columns.Add('Status', 'Status') | Out-Null
        $grid.Rows.Add("No adapter data available") | Out-Null
    }

    # ─── Templates Tab ──────────────────────────────────────────
    $grid = $Refs['TemplatesTable']
    $grid.Rows.Clear()
    $grid.Columns.Clear()

    if ($Data.Templates) {
        $Data.Templates[0].PSObject.Properties.Name | ForEach-Object {
            $grid.Columns.Add($_, $_) | Out-Null
        }

        foreach ($tpl in $Data.Templates) {
            $row = $grid.Rows.Add()
            foreach ($prop in $tpl.PSObject.Properties.Name) {
                $grid.Rows[$row].Cells[$prop].Value = $tpl.$prop
            }
        }
    }
    else {
        $grid.Columns.Add('Status', 'Status') | Out-Null
        $grid.Rows.Add("No template data available") | Out-Null
    }

    # ─── Port Groups Tab ────────────────────────────────────────
    $grid = $Refs['PortGroupsTable']
    $grid.Rows.Clear()
    $grid.Columns.Clear()

    if ($Data.PortGroups) {
        $Data.PortGroups[0].PSObject.Properties.Name | ForEach-Object {
            $grid.Columns.Add($_, $_) | Out-Null
        }

        foreach ($pg in $Data.PortGroups) {
            $row = $grid.Rows.Add()
            foreach ($prop in $pg.PSObject.Properties.Name) {
                $grid.Rows[$row].Cells[$prop].Value = $pg.$prop
            }
        }
    }
    else {
        $grid.Columns.Add('Status', 'Status') | Out-Null
        $grid.Rows.Add("No port group data available") | Out-Null
    }

    Set-StatusMessage -Refs $Refs -Message "UI updated with data." -Type Success
    $Refs.ContentPanel.ScrollControlIntoView($Refs.ContentPanel.Controls[0])
    $Refs.ContentPanel.PerformLayout()
}

# function Update-NetworksWithData {
#     <#
#     .SYNOPSIS
#         Updates the UI with collected data.
#     .PARAMETER Refs
#         Hashtable containing references to UI controls.
#     .PARAMETER Data
#         Hashtable containing collected data from vSphere.
#     #>

#     param(
#         [hashtable] $Refs,
#         [hashtable] $Data
#     )

#     if (-not $Refs -or -not $Data) {
#         Write-Verbose "Refs or Data is null"
#         return
#     }

#     Set-StatusMessage -Refs $Refs -Message "Updating UI with collected data..." -Type Info

#     # ─── Update Last Refresh Time ───────────────────────────────
#     $Refs['LastRefreshLabel'].Text = "Last refresh: $(Get-Date -Format 'HH:mm:ss tt')"


#     # ─── Hosts Tab ──────────────────────────────────────────────
#     $grid = $Refs['HostsTable']
#     $grid.Rows.Clear()
#     $grid.Columns.Clear()

#     if ($Data.HostInfo) {
#         # Create columns from first object's properties
#         $Data.HostInfo[0].PSObject.Properties.Name | ForEach-Object {
#             $grid.Columns.Add($_, $_) | Out-Null
#         }

#         # Populate data
#         foreach ($info in $Data.HostInfo) {
#             $row = $grid.Rows.Add()
#             foreach ($prop in $info.PSObject.Properties.Name) {
#                 $grid.Rows[$row].Cells[$prop].Value = $info.$prop
#             }
#         }
#     }
#     else {
#         $grid.Columns.Add('Status', 'Status') | Out-Null
#         $grid.Rows.Add("No host data available") | Out-Null
#     }

#     # ─── Adapters Tab ───────────────────────────────────────────
#     $grid = $Refs['NicsTable']
#     $grid.Rows.Clear()
#     $grid.Columns.Clear()

#     if ($Data.Adapters) {
#         $Data.Adapters[0].PSObject.Properties.Name | ForEach-Object {
#             $grid.Columns.Add($_, $_) | Out-Null
#         }

#         foreach ($nic in $Data.Adapters) {
#             $row = $grid.Rows.Add()
#             foreach ($prop in $nic.PSObject.Properties.Name) {
#                 $grid.Rows[$row].Cells[$prop].Value = $nic.$prop
#             }
            
#             # Highlight disconnected adapters
#             if (-not $nic.Connected) {
#                 $grid.Rows[$row].DefaultCellStyle.ForeColor = 'Red'
#             }
#         }
#     }
#     else {
#         $grid.Columns.Add('Status', 'Status') | Out-Null
#         $grid.Rows.Add("No adapter data available") | Out-Null
#     }

#     # ─── Templates Tab ──────────────────────────────────────────
#     $grid = $Refs['TemplatesTable']
#     $grid.Rows.Clear()
#     $grid.Columns.Clear()

#     if ($Data.Templates) {
#         $Data.Templates[0].PSObject.Properties.Name | ForEach-Object {
#             $grid.Columns.Add($_, $_) | Out-Null
#         }

#         foreach ($tpl in $Data.Templates) {
#             $row = $grid.Rows.Add()
#             foreach ($prop in $tpl.PSObject.Properties.Name) {
#                 $grid.Rows[$row].Cells[$prop].Value = $tpl.$prop
#             }
#         }
#     }
#     else {
#         $grid.Columns.Add('Status', 'Status') | Out-Null
#         $grid.Rows.Add("No template data available") | Out-Null
#     }

#     # ─── Port Groups Tab ────────────────────────────────────────
#     $grid = $Refs['PortGroupsTable']
#     $grid.Rows.Clear()
#     $grid.Columns.Clear()

#     if ($Data.PortGroups) {
#         $Data.PortGroups[0].PSObject.Properties.Name | ForEach-Object {
#             $grid.Columns.Add($_, $_) | Out-Null
#         }

#         foreach ($pg in $Data.PortGroups) {
#             $row = $grid.Rows.Add()
#             foreach ($prop in $pg.PSObject.Properties.Name) {
#                 $grid.Rows[$row].Cells[$prop].Value = $pg.$prop
#             }
#         }
#     }
#     else {
#         $grid.Columns.Add('Status', 'Status') | Out-Null
#         $grid.Rows.Add("No port group data available") | Out-Null
#     }

#     # ─── Set status message ──────────────────────────────────────
#     Set-StatusMessage -Refs $Refs -Message "UI updated with data." -Type Success

#     # ─── Scroll to top ──────────────────────────────────────────
#     $Refs.ContentPanel.ScrollControlIntoView($Refs.ContentPanel.Controls[0])
#     $Refs.ContentPanel.PerformLayout()

# }


# function Wire-UIEvents {
#     <#
#     .SYNOPSIS
#         Wires up UI events for the networks view.
#     .PARAMETER Refs
#         Hashtable containing references to UI controls.
#     #>

#     param([hashtable] $Refs)

#     if (-not $Refs -or -not $Refs.ContainsKey('RefreshButton')) {
#         Write-Error "Refs is null or missing required controls"
#         return
#     }

#     # Refresh Button Click
#     $Refs.RefreshButton.Add_Click({
#         . $PSScriptRoot\NetworksView.ps1
#         Show-NetworksView -ContentPanel $script:uiRefs.ContentPanel
#         Set-StatusMessage -Refs $script:uiRefs -Message "Data refreshed." -Type Success
#     })

#     # Delete Network Button Click
#     $Refs.DeleteNetworkButton.Add_Click({
#         . $PSScriptRoot\NetworksView.ps1
        
#         $networkName = $script:uiRefs.NetworkNameInput.Text.Trim()
#         if ([string]::IsNullOrWhiteSpace($networkName)) {
#             Set-StatusMessage -Refs $script:uiRefs -Message "Please enter a network name." -Type Warning
#             return
#         }

#         $result = [System.Windows.Forms.MessageBox]::Show(
#             "Are you sure you want to delete the network '$networkName' and its associated switch?",
#             "Confirm Delete",
#             [System.Windows.Forms.MessageBoxButtons]::YesNo,
#             [System.Windows.Forms.MessageBoxIcon]::Warning
#         )

#         if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
#             Set-StatusMessage -Refs $script:uiRefs -Message "Deleting network '$networkName'..." -Type Info
#             Get-VirtualPortGroup -VMHost (Get-VMHost) -Name $networkName | Remove-VirtualPortGroup -Confirm:$false
#             Get-VirtualSwitch -Name $networkName | Remove-VirtualSwitch -Confirm:$false
#             Set-StatusMessage -Refs $script:uiRefs -Message "Deleted successfully." -Type Success
#         } 
#         else {
#             Set-StatusMessage -Refs $script:uiRefs -Message "Delete cancelled." -Type Info
#         }
#     })

#     # Delete Multiple Button Click
#     $Refs.DeleteMultipleButton.Add_Click({
#         . $PSScriptRoot\NetworksView.ps1
    
#         $courseNumber = $script:uiRefs.CoursePrefixInput.Text.Trim()
#         $startStudents = [int]$script:uiRefs.StartNumberInput.Value
#         $endStudents = [int]$script:uiRefs.EndNumberInput.Value

#         if ([string]::IsNullOrWhiteSpace($courseNumber)) {
#             Set-StatusMessage -Refs $script:uiRefs -Message "Please enter a course prefix." -Type Warning
#         } 
#         elseif ($startStudents -gt $endStudents) {
#             Set-StatusMessage -Refs $script:uiRefs -Message "Start number must be less than or equal to end number." -Type Warning
#         } 
#         else {
#             $msg = "Are you sure you want to delete networks '$courseNumber`_S$startStudents' to '$courseNumber`_S$endStudents' and their associated switches?"
#             $result = [System.Windows.Forms.MessageBox]::Show(
#                 $msg,
#                 "Confirm Delete",
#                 [System.Windows.Forms.MessageBoxButtons]::YesNo,
#                 [System.Windows.Forms.MessageBoxIcon]::Warning
#             )
#             if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
#                 Set-StatusMessage -Refs $script:uiRefs -Message "Deleting..." -Type Info

#                 $vmHost = Get-VMHost
#                 for ($i = $startStudents; $i -le $endStudents; $i++) {
#                     $adapterName = $courseNumber + '_S' + $i
#                     Get-VirtualPortGroup -VMHost $vmHost -Name $adapterName | Remove-VirtualPortGroup -Confirm:$false
#                     Get-VirtualSwitch -Name $adapterName | Remove-VirtualSwitch -Confirm:$false
#                 }
#                 Set-StatusMessage -Refs $script:uiRefs -Message "Deleted successfully." -Type Success
#             } 
#             else {
#                 Set-StatusMessage -Refs $script:uiRefs -Message "Delete cancelled." -Type Info
#             }
#         }
#     })

#     # Add Network Button Click
#     $Refs.AddNetworkButton.Add_Click({
#         . $PSScriptRoot\NetworksView.ps1
    
#         $networkName = $script:uiRefs.NetworkNameInput.Text.Trim()
#         if ([string]::IsNullOrWhiteSpace($networkName)) {
#             Set-StatusMessage -Refs $script:uiRefs -Message "Please enter a network name." -Type Warning
#             return
#         }

#         $result = [System.Windows.Forms.MessageBox]::Show(
#             "Are you sure you want to add the network '$networkName' and its associated switch?",
#             "Confirm Add",
#             [System.Windows.Forms.MessageBoxButtons]::YesNo,
#             [System.Windows.Forms.MessageBoxIcon]::Question
#         )

#         if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
#             Set-StatusMessage -Refs $script:uiRefs -Message "Adding '$networkName'..." -Type Info
#             $vmHost = Get-VMHost
#             $vSwitch = New-VirtualSwitch -Name $networkName -VMHost $vmHost
#             $vPortGroup = New-VirtualPortGroup -Name $networkName -VirtualSwitch $vSwitch
#             Set-StatusMessage -Refs $script:uiRefs -Message "Added '$networkName' successfully." -Type Success
#         } 
#         else {
#             Set-StatusMessage -Refs $script:uiRefs -Message "Add cancelled." -Type Info
#         }
#     })

#     # Add Multiple Button Click
#     $Refs.AddMultipleButton.Add_Click({
#         . $PSScriptRoot\NetworksView.ps1
    
#         $courseNumber = $script:uiRefs.CoursePrefixInput.Text.Trim()
#         $startStudents = [int]$script:uiRefs.StartNumberInput.Value
#         $endStudents = [int]$script:uiRefs.EndNumberInput.Value

#         if ([string]::IsNullOrWhiteSpace($courseNumber)) {
#             Set-StatusMessage -Refs $script:uiRefs -Message "Please enter a course prefix." -Type Warning
#         } 
#         elseif ($startStudents -gt $endStudents) {
#             Set-StatusMessage -Refs $script:uiRefs -Message "Start number must be less than or equal to end number." -Type Warning
#         } 
#         else {
#             $msg = "Are you sure you want to add networks '$courseNumber`_S$startStudents' to '$courseNumber`_S$endStudents' and their associated switches?"
#             $result = [System.Windows.Forms.MessageBox]::Show(
#                 $msg,
#                 "Confirm Add",
#                 [System.Windows.Forms.MessageBoxButtons]::YesNo,
#                 [System.Windows.Forms.MessageBoxIcon]::Question
#             )

#             if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
#                 Set-StatusMessage -Refs $script:uiRefs -Message "Adding..." -Type Info
#                 $vmHost = Get-VMHost

#                 for ($i = $startStudents; $i -le $endStudents; $i++) {
#                     $adapterName = $courseNumber + "_S" + $i
#                     if (Get-VirtualSwitch -Name $adapterName -ErrorAction SilentlyContinue) {
#                         Write-Host "Adapter '$adapterName' already exists."
#                     } 
#                     else {
#                         try {
#                             $vSwitch = New-VirtualSwitch -Name $adapterName -VMHost $vmHost
#                             $vPortGroup = New-VirtualPortGroup -Name $adapterName -VirtualSwitch $vSwitch
#                         }
#                         catch {
#                             Write-Error "Failed to create network '$adapterName': $_"
#                         }
#                     }
#                 }
#                 Set-StatusMessage -Refs $script:uiRefs -Message "Added successfully." -Type Success
#             } 
#             else {
#                 Set-StatusMessage -Refs $script:uiRefs -Message "Add cancelled." -Type Info
#             }
#         }
#     })

    
# }
