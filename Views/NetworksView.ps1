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

    $script:Refs = New-NetworksLayout -ContentPanel $ContentPanel
    [System.Windows.Forms.Application]::DoEvents()

    $data = Get-NetworksData

    if ($data) {
        $script:Refs.Data = $data
        Update-NetworksWithData -Data $data
        Wire-UIEvents
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

    $ContentPanel.Controls.Clear()
    $ContentPanel.BackColor = $script:Theme.LightGray
    $refs = @{ ContentPanel = $ContentPanel }

    $margin = New-Object System.Windows.Forms.Padding(0,5,5,10)

    # ── Root table ------------------------------------------------------------
    $root              = New-Object System.Windows.Forms.TableLayoutPanel
    $root.Dock         = 'Fill'
    $root.ColumnCount  = 1
    $root.RowCount     = 4
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
    $tabs.TabPages.Add($tabManage)
    
    $manageLayout = New-Object System.Windows.Forms.TableLayoutPanel
    $manageLayout.Dock = 'Fill'
    $manageLayout.RowCount = 2
    $null = $manageLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'AutoSize'))
    $null = $manageLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'Percent',100))
    $tabManage.Controls.Add($manageLayout)

    # Description
    $tabNetDescription = New-Object System.Windows.Forms.Label
    $tabNetDescription.Text = "Manages Standard switches and their associated port groups.`n"
    $tabNetDescription.ForeColor = $script:Theme.PrimaryDark
    $tabNetDescription.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $tabNetDescription.Anchor = 'Left'
    $tabNetDescription.AutoSize = $true
    $tabNetDescription.Margin = New-Object System.Windows.Forms.Padding(10,10,10,5)
    $manageLayout.Controls.Add($tabNetDescription,0,0)

    $manageFlow = New-Object System.Windows.Forms.FlowLayoutPanel
    $manageFlow.Dock = 'Fill'
    $manageFlow.AutoScroll = $true
    $manageFlow.Padding = New-Object System.Windows.Forms.Padding(10)
    $manageFlow.WrapContents = $false
    $manageFlow.FlowDirection = 'LeftToRight'
    $manageFlow.AutoSize = $false
    $manageFlow.BackColor = $script:Theme.White
    $manageLayout.Controls.Add($manageFlow,0,1)

    #── Left Panel: Add Single Network ───────────────────────────────────────────
    $grNetAdd = New-Object System.Windows.Forms.GroupBox
    $grNetAdd.Text = 'Single Network'
    $grNetAdd.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
    $grNetAdd.Margin = New-Object System.Windows.Forms.Padding(10)
    $grNetAdd.Padding = New-Object System.Windows.Forms.Padding(10)
    $grNetAdd.Width = 300
    $grNetAdd.AutoSize = $true
    $manageFlow.Controls.Add($grNetAdd)

    $grNetAddLayout = New-Object System.Windows.Forms.TableLayoutPanel
    $grNetAddLayout.ColumnCount = 4
    $grNetAddLayout.RowCount = 2 
    $grNetAddLayout.Dock = 'Fill'
    $grNetAddLayout.AutoSize = $true
    $grNetAdd.Controls.Add($grNetAddLayout)

    # Network name
    $lblAddNet = New-Object System.Windows.Forms.Label
    $lblAddNet.Dock = 'Top'
    $lblAddNet.Text = "Network Name:"
    $lblAddNet.Anchor = 'Right'
    $lblAddNet.TextAlign = 'MiddleRight'
    $grNetAddLayout.Controls.Add($lblAddNet, 0, 0)

    $txtNewNetwork = New-Object System.Windows.Forms.TextBox
    $txtNewNetwork.Dock = 'Fill'
    $txtNewNetwork.AutoSize = $true
    $txtNewNetwork.Margin = $margin
    $grNetAddLayout.Controls.Add($txtNewNetwork, 1, 0)
    $grNetAddLayout.SetColumnSpan($txtNewNetwork,2)
    $refs["TxtNetwork"] = $txtNewNetwork

    # Delete button
    $btnDelNet = New-Object System.Windows.Forms.Button
    $btnDelNet.Text = "Delete"
    $btnDelNet.Dock = 'Top'
    $btnDelNet.AutoSize = $true
    $btnDelNet.Margin = $margin
    $btnDelNet.BackColor = $script:Theme.Error
    $btnDelNet.ForeColor = $script:Theme.White
    $grNetAddLayout.Controls.Add($btnDelNet, 1, 1)
    $refs['BtnDelNet'] = $btnDelNet

    # Add button
    $btnAddNet = New-Object System.Windows.Forms.Button
    $btnAddNet.Text = "Add"
    $btnAddNet.Dock = 'Top'
    $btnAddNet.AutoSize = $true
    $btnAddNet.Margin = $margin
    $btnAddNet.BackColor = $script:Theme.Primary
    $btnAddNet.ForeColor = $script:Theme.White
    $grNetAddLayout.Controls.Add($btnAddNet, 2, 1)
    $refs['BtnAddNet'] = $btnAddNet
    
    #── Right Panel: Multiple Networks ────────────────────────────────────
    $grMult = New-Object System.Windows.Forms.GroupBox
    $grMult.Text = 'Multiple Networks'
    $grMult.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
    $grMult.Margin = New-Object System.Windows.Forms.Padding(10)
    $grMult.Padding = New-Object System.Windows.Forms.Padding(10)
    $grMult.Width = 400
    $grMult.AutoSize = $true
    $manageFlow.Controls.Add($grMult)

    $layoutMult = New-Object System.Windows.Forms.TableLayoutPanel
    $layoutMult.Dock = 'Fill'
    $layoutMult.ColumnCount = 4
    $layoutMult.RowCount = 5
    $layoutMult.AutoSize = $true
    $grMult.Controls.Add($layoutMult)

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
    $refs['CmbMultClasses'] = $cmbMultClasses

     # Start student number
    $labelStartNum = New-Object System.Windows.Forms.Label
    $labelStartNum.Text = "Start Student:"
    $labelStartNum.AutoSize = $true
    $labelStartNum.Anchor = 'Right'
    $labelStartNum.TextAlign = 'MiddleRight'
    $layoutMult.Controls.Add($labelStartNum, 0, 1)

    $inputStartNum = New-Object System.Windows.Forms.NumericUpDown
    $inputStartNum.Margin = $margin
    $inputStartNum.Minimum = 1
    $inputStartNum.Maximum = 1000
    $layoutMult.Controls.Add($inputStartNum, 1, 1)
    $refs['InputStartNum'] = $inputStartNum

     # End Student number
    $labelEndNum = New-Object System.Windows.Forms.Label
    $labelEndNum.Text = "End Student:"
    $labelEndNum.AutoSize = $true
    $labelEndNum.Anchor = 'Right'
    $labelEndNum.TextAlign = 'MiddleRight'
    $layoutMult.Controls.Add($labelEndNum, 0, 2)

    $inputEndNum = New-Object System.Windows.Forms.NumericUpDown
    $inputEndNum.Margin = $margin
    $inputEndNum.Minimum = 1
    $inputEndNum.Maximum = 1000
    $layoutMult.Controls.Add($inputEndNum, 1, 2)
    $refs['InputEndNum'] = $inputEndNum

    # Delete selected class network button
    $btnDelMult = New-Object System.Windows.Forms.Button
    $btnDelMult.Margin = $margin
    $btnDelMult.Dock = 'Fill'
    $btnDelMult.Text = "Delete Networks"
    $btnDelMult.AutoSize = $true
    $btnDelMult.BackColor = $script:Theme.Error
    $btnDelMult.ForeColor = $script:Theme.White
    $layoutMult.Controls.Add($btnDelMult, 1, 3)
    $refs['BtnDelMult'] = $btnDelMult

    # Add class network button
    $btnAddMult = New-Object System.Windows.Forms.Button
    $btnAddMult.Margin = $margin
    $btnAddMult.Text = "Add Networks"
    $btnAddMult.Dock = 'Fill'
    $btnAddMult.AutoSize = $true
    $btnAddMult.BackColor = $script:Theme.Primary
    $btnAddMult.ForeColor = $script:Theme.White
    $layoutMult.Controls.Add($btnAddMult, 2, 3)
    $refs['BtnAddMult'] = $btnAddMult

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
    $footer.Dock      = 'Fill'
    $footer.AutoSize  = $true
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
        [string]$Message,
        [ValidateSet('Success','Warning','Error','Info')][string]$Type = 'Info'
    )
    
    if ($script:Refs -and $script:Refs.ContainsKey('StatusLabel')) {
        $script:Refs.StatusLabel.Text = $Message
        $script:Refs.StatusLabel.ForeColor = switch ($Type) {
            'Success' { $script:Theme.Success }
            'Warning' { $script:Theme.Warning }
            'Error'   { $script:Theme.Error }
            default   { $script:Theme.PrimaryDarker }
        }
    }

    [System.Windows.Forms.Application]::DoEvents()
}


function Get-NetworksData {
    <#
    .SYNOPSIS
        Collects vSphere network data .\s
    #>

    [CmdletBinding()]
    param()
    
    # 1. Ensure connection
    if (-not $script:Connection) {
        Set-StatusMessage -Message 'No connection to vCenter' -Type Error
        return $null
    }

    $data = @{}

    # 2. Find all classes
    Set-StatusMessage -Message "Discovering classes..." -Type Info
    $dc          = Get-Datacenter  -Server $script:Connection -Name 'Datacenter'
    $vmFolder    = Get-Folder      -Server $script:Connection -Name 'vm'        -Location $dc
    $classesRoot = Get-Folder      -Server $script:Connection -Name 'Classes'   -Location $vmFolder

    $classFolders = Get-Folder -Server $script:Connection -Location $classesRoot -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -notmatch '_' }

    # Create a mapping of classes to student counts
    $classStudentCount = @{}
    
    foreach ($classFolder in $classFolders) {
        $className = $classFolder.Name
        $studentFolders = Get-Folder -Server $conn -Location $classFolder -ErrorAction SilentlyContinue
        $stuCount = 0
        if($studentFolders) { $stuCount = $studentFolders.Count }
        $classStudentCount[$className] = $stuCount
        Set-StatusMessage -Message "$className - $stuCount students" -Type Info
    }

    $data.Classes = $classFolders
    $data.ClassStudentCount = $classStudentCount

    # 3. Retrieve all port-groups
    Set-StatusMessage -Message "Collecting port groups from hosts..." -Type Info
    $vmHosts    = Get-VMHost -Server $script:Connection -ErrorAction SilentlyContinue
    $portGroups = $vmHosts | Get-VirtualPortGroup -Server $script:Connection
    $data.AllNetworks = $portGroups.Name | Sort-Object

    # 4. Build StudentsMap
    $studentsMap = @{}
    foreach ($cls in $classes) {
        $nums = @()
        if ($classMap.ContainsKey($cls)) {
            $nums = $classMap[$cls].Keys | Sort-Object {[int]$_}
        }
        $studentsMap[$cls] = $nums | ForEach-Object { "Student $_" }
    }
    $data.StudentsMap = $studentsMap

    # 5. Host Info
    Set-StatusMessage -Message "Collecting host information..." -Type Info
    $data.HostInfo = Get-VMHost -Server $script:Connection |
        Select-Object Name,
            @{N='CPU Total (GHz)';E={[math]::Round($_.CpuTotalMhz/1000,1)}},
            @{N='Memory (GB)';    E={[math]::Round($_.MemoryTotalGB,1)}},
            Model, Version, ConnectionState, PowerState

    # 6. Adapters
    Set-StatusMessage -Message "Collecting network adapters..." -Type Info
    $data.Adapters = Get-VMHostNetworkAdapter -Server $script:Connection |
        Select-Object VMHost, Name, Mac, IP, SubnetMask,
            @{N='Speed (Gbps)';E={[math]::Round($_.SpeedMb/1000,1)}},
            FullDuplex, MTU, Connected

    # 7. Templates
    Set-StatusMessage -Message "Collecting VM templates..." -Type Info
    $data.Templates = Get-Template -Server $script:Connection |
        Select-Object Name,
            @{N='OS';           E={$_.Guest}},
            NumCpu,
            @{N='Memory (GB)';  E={$_.MemoryGB}},
            @{N='Provisioned (GB)';E={[math]::Round($_.ProvisionedSpaceGB,1)}},
            @{N='Used (GB)';    E={[math]::Round($_.UsedSpaceGB,1)}},
            Version,
            @{N='Folder';       E={$_.Folder.Name}},
            Notes,
            PersistentId

    # 8. Port Groups detail
    Set-StatusMessage -Message "Collecting port group details..." -Type Info
    $data.PortGroups = $portGroups |
        Select-Object Name, VlanId,
            @{N='vSwitch';         E={$_.VirtualSwitchName}},
            @{N='Host';            E={(Get-VMHost -Id $_.VirtualSwitch.VMHostId).Name}},
            @{N='Security Policy'; E={
                "Promiscuous:$($_.SecurityPolicy.AllowPromiscuous)," +
                " MAC:$($_.SecurityPolicy.MacChanges)," +
                " Forged:$($_.SecurityPolicy.ForgedTransmits)"
            }},
            @{N='Active Ports';    E={($_.ExtensionData.Port | Where-Object {$_.Connected}).Count}}

    Set-StatusMessage -Message "Data collection complete." -Type Success
    return $data
}


function Update-NetworksWithData {
    <#
    .SYNOPSIS
        Updates the entire UI after data-refresh.
    .DESCRIPTION
        - Fills the "Multiple Networks" class dropdown.
        - Clears the single‐network textbox.
        - Resets numeric inputs.
        - Populates all four DataGridViews (Hosts, Adapters, Templates, Port Groups).
    .PARAMETER Data
        Hashtable from Get-NetworksData.
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable] $Data
    )

    if (-not $script:Refs -or -not $Data) {
        Write-Verbose "Refs or Data missing, skipping UI update."
        return
    }

    # Refresh timestamp
    $script:Refs['LastRefreshLabel'].Text = "Last refresh: $(Get-Date -Format 'HH:mm:ss tt')"
    Set-StatusMessage -Message 'Updating UI with data...' -Type Info

    # ─── Multiple Networks: Classes dropdown ────────────────────────
    $cmbMult = $script:Refs['CmbMultClasses']
    $cmbMult.Items.Clear()
    foreach ($cls in ($Data.Classes | Sort-Object)) { $cmbMult.Items.Add($cls) | Out-Null }
    if ($cmbMult.Items.Count -gt 0) { $cmbMult.SelectedIndex = 0 }

    # ─── Single Network: clear textbox ────────────────────────────
    $script:Refs['TxtNetwork'].Text = ''

    # ─── Multiple Networks: reset numeric range ───────────────────
    $script:Refs['InputStartNum'].Value = $script:Refs['InputStartNum'].Minimum
    $script:Refs['InputEndNum'].Value   = $script:Refs['InputStartNum'].Minimum

    foreach ($cls in ($Data.ClassStudentCount.Keys | Sort-Object)) { $cmbMult.Items.Add($cls) | Out-Null }

    # ─── Hosts Table ──────────────────────────────────────────────
    $grid = $script:Refs['HostsTable']
    $grid.Rows.Clear(); $grid.Columns.Clear()
    if ($Data.HostInfo) {
        $first = $Data.HostInfo[0]
        foreach ($prop in $first.PSObject.Properties.Name) {
            $grid.Columns.Add($prop, $prop) | Out-Null
        }
        foreach ($rowObj in $Data.HostInfo) {
            $r = $grid.Rows.Add()
            foreach ($prop in $rowObj.PSObject.Properties.Name) {
                $grid.Rows[$r].Cells[$prop].Value = $rowObj.$prop
            }
        }
    } else {
        $grid.Columns.Add('Status','Status') | Out-Null
        $grid.Rows.Add('No host data available') | Out-Null
    }

    # ─── Adapters Table ───────────────────────────────────────────
    $grid = $script:Refs['NicsTable']
    $grid.Rows.Clear(); $grid.Columns.Clear()
    if ($Data.Adapters) {
        $first = $Data.Adapters[0]
        foreach ($prop in $first.PSObject.Properties.Name) {
            $grid.Columns.Add($prop, $prop) | Out-Null
        }
        foreach ($rowObj in $Data.Adapters) {
            $r = $grid.Rows.Add()
            foreach ($prop in $rowObj.PSObject.Properties.Name) {
                $grid.Rows[$r].Cells[$prop].Value = $rowObj.$prop
            }
            if (-not $rowObj.Connected) {
                $grid.Rows[$r].DefaultCellStyle.ForeColor = 'Red'
            }
        }
    } else {
        $grid.Columns.Add('Status','Status') | Out-Null
        $grid.Rows.Add('No adapter data available') | Out-Null
    }

    # ─── Templates Table ──────────────────────────────────────────
    $grid = $script:Refs['TemplatesTable']
    $grid.Rows.Clear(); $grid.Columns.Clear()
    if ($Data.Templates) {
        $first = $Data.Templates[0]
        foreach ($prop in $first.PSObject.Properties.Name) {
            $grid.Columns.Add($prop, $prop) | Out-Null
        }
        foreach ($rowObj in $Data.Templates) {
            $r = $grid.Rows.Add()
            foreach ($prop in $rowObj.PSObject.Properties.Name) {
                $grid.Rows[$r].Cells[$prop].Value = $rowObj.$prop
            }
        }
    } else {
        $grid.Columns.Add('Status','Status') | Out-Null
        $grid.Rows.Add('No template data available') | Out-Null
    }

    # ─── Port Groups Table ────────────────────────────────────────
    $grid = $script:Refs['PortGroupsTable']
    $grid.Rows.Clear(); $grid.Columns.Clear()
    if ($Data.PortGroups) {
        $first = $Data.PortGroups[0]
        foreach ($prop in $first.PSObject.Properties.Name) {
            $grid.Columns.Add($prop, $prop) | Out-Null
        }
        foreach ($rowObj in $Data.PortGroups) {
            $r = $grid.Rows.Add()
            foreach ($prop in $rowObj.PSObject.Properties.Name) {
                $grid.Rows[$r].Cells[$prop].Value = $rowObj.$prop
            }
        }
    } else {
        $grid.Columns.Add('Status','Status') | Out-Null
        $grid.Rows.Add('No port group data available') | Out-Null
    }

    Set-StatusMessage -Message 'UI updated with data.' -Type Success
}



function Wire-UIEvents {
    <#
    .SYNOPSIS
        Hooks up all button‐click handlers based on the updated single-network UI.
    #>

    if (-not $script:Refs) {
        Write-Error "Refs is null"; return
    }


    # ── Refresh ───────────────────────────────────────────────────────
    $script:Refs['RefreshButton'].Add_Click({
        . $PSScriptRoot\NetworksView.ps1
        Show-NetworksView -ContentPanel $script:Refs.ContentPanel
        Set-StatusMessage -Message "Data refreshed." -Type Success
    })


    # ── Add Single Network ───────────────────────────────────────────
    $script:Refs['BtnAddNet'].Add_Click({
        param($sender,$e)

        . $PSScriptRoot\NetworksView.ps1

        $name = $script:Refs['TxtNetwork'].Text.Trim()
        if ([string]::IsNullOrWhiteSpace($name)) {
            Set-StatusMessage -Message "Please enter a network name." -Type Warning
            return
        }

        $confirm = [System.Windows.Forms.MessageBox]::Show(
            "Are you sure you want to add network '$name'?",
            "Confirm Add",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )
        if ($confirm -ne [System.Windows.Forms.DialogResult]::Yes) {
            Set-StatusMessage -Message "Add cancelled." -Type Info
            return
        }

        Set-StatusMessage -Message "Adding network '$name'..." -Type Info
        try {
            addNetwork -networkName $name
            Set-StatusMessage -Message "Network '$name' added." -Type Success
        } catch {
            Set-StatusMessage -Message "Failed to add network: $_" -Type Error
        }

        # Refresh data/UI
        $data = Get-NetworksData
        if ($data) {
            $script:Refs.Data = $data
            Update-NetworksWithData -Data $data
            Wire-UIEvents
        }
    })


    # ── Delete Single Network ────────────────────────────────────────
    $script:Refs['BtnDelNet'].Add_Click({
        param($sender,$e)

        . $PSScriptRoot\NetworksView.ps1

        $name = $script:Refs['TxtNetwork'].Text.Trim()
        if ([string]::IsNullOrWhiteSpace($name)) {
            Set-StatusMessage -Message "Please enter a network name to delete." -Type Warning
            return
        }

        $confirm = [System.Windows.Forms.MessageBox]::Show(
            "Are you sure you want to delete network '$name'?",
            "Confirm Delete",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        if ($confirm -ne [System.Windows.Forms.DialogResult]::Yes) {
            Set-StatusMessage -Message "Delete cancelled." -Type Info
            return
        }

        Set-StatusMessage -Message "Deleting network '$name'..." -Type Info
        try {
            deleteNetwork -networkName $name
            Set-StatusMessage -Message "Network '$name' deleted." -Type Success
        } catch {
            Set-StatusMessage -Message "Failed to delete network: $_" -Type Error
        }

        # Refresh data/UI
        $data = Get-NetworksData
        if ($data) {
            $script:Refs.Data = $data
            Update-NetworksWithData -Data $data
            Wire-UIEvents
        }
    })


    # ── Class selector for Multiple Networks ─────────────────────────────────────
    $script:Refs['CmbMultClasses'].Add_SelectedIndexChanged({
        param($sender, $e)

        . $PSScriptRoot\NetworksView.ps1

        $class = $sender.SelectedItem
        if ($class) {
            [int] $studentCount = $script:Refs.Data.ClassStudentCount[$class]
            
            # Update the NumericUpDown controls
            $maxStudents = [math]::Max(1, $studentCount)  # Ensure at least 1
            $script:Refs['InputStartNum'].Maximum = $maxStudents
            $script:Refs['InputEndNum'].Maximum = $maxStudents
            $script:Refs['InputStartNum'].Value = 1
            $script:Refs['InputEndNum'].Value = $maxStudents
            
            # Update status message
            Set-StatusMessage -Message "Selected class '$($class)' with $studentCount students" -Type Info
        } else {
            # Reset to defaults if no valid selection
            $script:Refs['InputStartNum'].Maximum = 1
            $script:Refs['InputEndNum'].Maximum = 1
            $script:Refs['InputStartNum'].Value = 1
            $script:Refs['InputEndNum'].Value = 1
        }
    })


     # ── Add Multiple Networks ────────────────────────────────────────
    $script:Refs['BtnAddMult'].Add_Click({
        param($sender,$e)

        . $PSScriptRoot\NetworksView.ps1

        $class    = $script:Refs['CmbMultClasses'].SelectedItem
        $startNum = [int]$script:Refs['InputStartNum'].Value
        $endNum   = [int]$script:Refs['InputEndNum'].Value

        if (-not $class) {
            Set-StatusMessage -Message "Please select a class." -Type Warning; return
        }
        if ($startNum -gt $endNum) {
            Set-StatusMessage -Message "Start must be ≤ end." -Type Warning; return
        }
        
        # Get the maximum allowed student number for this class
        $maxStudent = $script:Refs['InputEndNum'].Maximum
        if ($endNum -gt $maxStudent) {
            Set-StatusMessage -Message "End student cannot exceed $maxStudent for this class." -Type Warning; return
        }

        $count = ($endNum - $startNum) + 1
        $msg   = "Create $count networks from ${class}_S$('{0:00}' -f $startNum) to ${class}_S$('{0:00}' -f $endNum)?"
        $confirm = [System.Windows.Forms.MessageBox]::Show(
            $msg, "Confirm Add Multiple",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )
        if ($confirm -ne [System.Windows.Forms.DialogResult]::Yes) {
            Set-StatusMessage -Message "Add cancelled." -Type Info; return
        }

        Set-StatusMessage -Message "Adding $count networks..." -Type Info
        try {
            addNetworks -courseNumber $class -startStudents $startNum -endStudents $endNum
            Set-StatusMessage -Message "Added $count networks." -Type Success
        } catch {
            Set-StatusMessage -Message "Failed to add networks: $_" -Type Error
        }
        
        # Refresh the data to update the maximum student numbers
        $data = Get-NetworksData
        if ($data) {
            $script:Refs.Data = $data
            Update-NetworksWithData -Data $data
            Wire-UIEvents
        }
    })


    # ── Delete Multiple Networks ─────────────────────────────────────
    $script:Refs['BtnDelMult'].Add_Click({
        param($sender,$e)

        . $PSScriptRoot\NetworksView.ps1

        $class    = $script:Refs['CmbMultClasses'].SelectedItem
        $startNum = [int]$script:Refs['InputStartNum'].Value
        $endNum   = [int]$script:Refs['InputEndNum'].Value

        if (-not $class) {
            Set-StatusMessage -Message "Please select a class." -Type Warning; return
        }
        if ($startNum -gt $endNum) {
            Set-StatusMessage -Message "Start must be ≤ end." -Type Warning; return
        }

        $count = ($endNum - $startNum) + 1
        $msg   = "Delete $count networks from ${class}_S$('{0:00}' -f $startNum) to ${class}_S$('{0:00}' -f $endNum)?"
        $confirm = [System.Windows.Forms.MessageBox]::Show(
            $msg, "Confirm Delete Multiple",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        if ($confirm -ne [System.Windows.Forms.DialogResult]::Yes) {
            Set-StatusMessage -Message "Delete cancelled." -Type Info; return
        }

        Set-StatusMessage -Message "Deleting $count networks..." -Type Info
        try {
            deleteNetworks -courseNumber $class -startStudents $startNum -endStudents $endNum
            Set-StatusMessage -Message "Deleted $count networks." -Type Success
        } catch {
            Set-StatusMessage -Message "Failed to delete networks: $_" -Type Error
        }
    })

}




function deleteNetwork {
    param ([string]$networkName)
    # remove the port group
    Get-VirtualPortGroup -VMHost (Get-VMHost) -Name $networkName | Remove-VirtualPortGroup  -Confirm:$false
    # remove the switch
    Get-VirtualSwitch -Name $networkName | Remove-VirtualSwitch -Confirm:$false
}


function deleteNetworks {
    param(
        [int]$startStudents,
        [int]$endStudents,
        [string]$courseNumber
    )
    BEGIN{}
    PROCESS{
        # Get the VM host name
        $vmHost = Get-VMHost 
            
        # loop through each student
        for ($i=$startStudents; $i -le $endStudents; $i++) {
            # set the adapter name
            $adapterName = $courseNumber+'_S'+$i
            # remove the port group
            Get-VirtualPortGroup -VMHost $vmHost -Name $adapterName | Remove-VirtualPortGroup  -Confirm:$false
            # remove the switch
            Get-VirtualSwitch -Name $adapterName | Remove-VirtualSwitch -Confirm:$false
        }
    }
    END{}
}


function addNetwork {
    param (
        [string]$networkName
    )
     # Get the VM host name
    $vmHost = Get-VMHost 
    # create the virtual switch for this user
    $vSwitch = New-VirtualSwitch -Name $networkName -VMHost $vmHost
    # create the virtual port group for this user
    $vPortGroup = New-VirtualPortGroup -Name $networkName -VirtualSwitch $vSwitch 
}


function addNetworks {
    param(
        [string]$courseNumber,
        [int]$startStudents,
        [int]$endStudents
    )
    BEGIN{}
    PROCESS{
        # Get the VM host name
        $vmHost = Get-VMHost 

        # loop through each student
        for ($i=$startStudents; $i -le $endStudents; $i++) {
            $adapterName=$courseNumber+"_S"+$i

            if (Get-VirtualSwitch -Name $adapterName 2> $null) {
                Write-Host 'adapter exists'
            } else {
                # create the virtual switch for this user
                $vSwitch = New-VirtualSwitch -Name $adapterName -VMHost $vmHost
                # create the virtual port group for this user
                $vPortGroup = New-VirtualPortGroup -Name $adapterName -VirtualSwitch $vSwitch 
            } 
        }
    }
    END{}
}

