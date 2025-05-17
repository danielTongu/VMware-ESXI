# ─────────────────────────  Assemblies  ──────────────────────────────────────
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing


# ─────────────────────────  Public entry point  ──────────────────────────────
# Entry point: show network view
function Show-NetworksView {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [System.Windows.Forms.Panel] $ContentPanel
    )
    try {
        $uiRefs = New-NetworkLayout -ContentPanel $ContentPanel
        $data   = Get-NetworkData

        if ($data) {
            Update-NetworkViewWithData -UiRefs $uiRefs -Data $data
            $ContentPanel.Refresh()
        } else {
            $uiRefs.StatusLabel.Text      = 'No connection to VMware server'
            $uiRefs.StatusLabel.ForeColor = $script:Theme.Error
        }
    } catch {
        Write-Verbose "Network view initialization failed: $_"
    }
}


# ─────────────────────────  Data collection  ─────────────────────────────────
# Retrieve network data
function Get-NetworkData {
    [CmdletBinding()]
    param()
    try {
        if (-not $script:Connection) { return $null }
        $conn = $script:Connection
        
        return @{
            PortGroups = Get-VirtualPortGroup -Server $conn -ErrorAction SilentlyContinue
            Hosts      = Get-VMHost            -Server $conn -ErrorAction SilentlyContinue
            Adapters   = Get-VMHostNetworkAdapter -Server $conn -ErrorAction SilentlyContinue
            Templates  = Get-Template          -Server $conn -ErrorAction SilentlyContinue
            VMs        = Get-VM                -Server $conn -ErrorAction SilentlyContinue
        }
    } catch {
        Write-Verbose "Network data collection failed: $_"
        return $null
    }
}

# ─────────────────────────  Layout builders  ─────────────────────────────────
# Build layout + controls
function New-NetworkLayout {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [System.Windows.Forms.Panel] $ContentPanel
    )
    $ContentPanel.Controls.Clear()
    $ContentPanel.BackColor = $script:Theme.LightGray

    # Root table
    $root = New-Object System.Windows.Forms.TableLayoutPanel
    $root.Dock = 'Fill' 
    $root.ColumnCount = 1
    $root.RowCount = 3
    $null = $root.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle 'Percent',100))
    $null = $root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'AutoSize'))
    $null = $root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'Percent',100))
    $null = $root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'AutoSize'))
    $ContentPanel.Controls.Add($root)

    # Header
    $root.Controls.Add((New-NetworkHeader), 0, 0)

    # TabControl
    $tabControl = New-Object System.Windows.Forms.TabControl
    $tabControl.Dock = 'Fill'
    $tabControl.Padding = New-Object System.Drawing.Point(20,10)
    $tabControl.Font = New-Object System.Drawing.Font('Segoe UI',10,[System.Drawing.FontStyle]::Bold)
    $tabControl.BackColor = $script:Theme.LightGray
    $root.Controls.Add($tabControl, 0, 1)

    # Prepare refs
    $refs = @{ TabControl = $tabControl; Tabs = @{} }

    # Overview
    $tabOv = New-Object System.Windows.Forms.TabPage 'Overview'
    $tabOv.BackColor = $script:Theme.White
    $ovWrapper = New-NetworkTable -Columns @() -Name 'dgOverview'
    $tabOv.Controls.Add($ovWrapper)
    $refs.Tabs['Overview'] = @{ DataGrid = $ovWrapper.Controls[0] }
    
    $tabControl.TabPages.Add($tabOv)

    # PortGroups
    $tabPG = New-Object System.Windows.Forms.TabPage 'Port Groups'
    $tabPG.BackColor = $script:Theme.White
    $pgCtrls = New-NetworkPortGroupControls -Parent $tabPG
    $tabPG.Controls.Add($pgCtrls.Container)
    $refs.Tabs['PortGroups'] = $pgCtrls
    $tabControl.TabPages.Add($tabPG)

    # Hosts
    $tabH = New-Object System.Windows.Forms.TabPage 'Hosts'
    $tabH.BackColor = $script:Theme.White
    $hCtrls = New-NetworkHostControls -Parent $tabH
    $tabH.Controls.Add($hCtrls.Container)
    $refs.Tabs['Hosts'] = $hCtrls
    $tabControl.TabPages.Add($tabH)

    # Adapters
    $tabA = New-Object System.Windows.Forms.TabPage 'Adapters'
    $tabA.BackColor = $script:Theme.White
    $aCtrls = New-NetworkAdapterControls -Parent $tabA
    $tabA.Controls.Add($aCtrls.Container)
    $refs.Tabs['Adapters'] = $aCtrls
    $tabControl.TabPages.Add($tabA)

    # Templates
    $tabT = New-Object System.Windows.Forms.TabPage 'Templates'
    $tabT.BackColor = $script:Theme.White
    $tCtrls = New-NetworkTemplateControls -Parent $tabT
    $tabT.Controls.Add($tCtrls.Container)
    $refs.Tabs['Templates'] = $tCtrls
    $tabControl.TabPages.Add($tabT)

    # Footer
    $footer = New-Object System.Windows.Forms.Panel
    $footer.Dock='Bottom'
    $footer.Height=30
    $footer.BackColor=$script:Theme.LightGray
    $status = New-Object System.Windows.Forms.Label
    $status.Name='StatusLabel'; $status.AutoSize=$true
    $status.Font=New-Object System.Drawing.Font('Segoe UI',9)
    $status.ForeColor=$script:Theme.Error
    $status.Text='---'
    $footer.Controls.Add($status)
    $root.Controls.Add($footer,0,2)
    $refs.StatusLabel = $status

    return $refs
}




function New-NetworkHeader {
    <#
    .SYNOPSIS
        Returns the colored network view header bar.
    #>
    $panel              = New-Object System.Windows.Forms.Panel
    $panel.Dock         = 'Top'
    $panel.Height       = 80
    $panel.BackColor    = $script:Theme.Primary

    $lblTitle           = New-Object System.Windows.Forms.Label
    $lblTitle.Text      = 'NETWORK MANAGER'
    $lblTitle.Font      = New-Object System.Drawing.Font('Segoe UI',18,[System.Drawing.FontStyle]::Bold)
    $lblTitle.ForeColor = $script:Theme.White
    $lblTitle.Location  = New-Object System.Drawing.Point(20,20)
    $lblTitle.AutoSize  = $true
    $panel.Controls.Add($lblTitle)

    return $panel
}



# Styled DataGridView container
function New-NetworkTable {
    [CmdletBinding()] param([string[]] $Columns, [string] $Name)

    $c = New-Object System.Windows.Forms.Panel
    $c.Dock='Fill'
    $c.Padding=New-Object System.Windows.Forms.Padding(10)
    $c.AutoScroll=$true
    $c.BackColor=$script:Theme.White

    $g = New-Object System.Windows.Forms.DataGridView
    $g.Name=$Name
    $g.Dock='Fill'
    $g.AutoGenerateColumns=$true
    $g.AutoSizeColumnsMode='Fill'
    $g.RowHeadersVisible=$false
    $g.ReadOnly=$true
    $g.AllowUserToAddRows=$false
    $g.AllowUserToDeleteRows=$false
    $g.AllowUserToResizeRows=$false
    $g.AutoSizeRowsMode='AllCells'
    $g.BackgroundColor=$script:Theme.White
    $g.BorderStyle='FixedSingle'
    $g.EnableHeadersVisualStyles=$false
    $g.ColumnHeadersDefaultCellStyle.Font=New-Object System.Drawing.Font('Segoe UI',9,[System.Drawing.FontStyle]::Bold)
    $g.DefaultCellStyle.Font=New-Object System.Drawing.Font('Segoe UI',9)
    $g.DefaultCellStyle.ForeColor=$script:Theme.PrimaryDark

    $c.Controls.Add($g)
    
    return $c
}





function New-NetworkPortGroupControls {
    <#
    .SYNOPSIS
        Creates the controls for Port Groups tab operations.
    #>
    param([System.Windows.Forms.Panel]$Parent)

    $container = New-Object System.Windows.Forms.TableLayoutPanel
    $container.Dock = 'Fill'
    $container.RowCount = 2
    $container.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'Percent',90))
    $container.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'Percent',10))
    $Parent.Controls.Add($container)

    $dataGrid = $Parent.Controls[0].Controls[0] # Get the grid from the parent panel

    $opPanel = New-Object System.Windows.Forms.Panel
    $opPanel.Dock = 'Fill'
    $container.Controls.Add($opPanel, 0, 1)

    $inputBox = New-Object System.Windows.Forms.TextBox
    $inputBox.Width = 180
    $inputBox.Location = New-Object System.Drawing.Point(5,5)
    $inputBox.Font = New-Object System.Drawing.Font('Segoe UI',10)
    $opPanel.Controls.Add($inputBox)

    $addBtn = New-Object System.Windows.Forms.Button
    $addBtn.Text = "Add"
    $addBtn.Font = New-Object System.Drawing.Font('Segoe UI',10)
    $addBtn.Width = 80
    $addBtn.Location = New-Object System.Drawing.Point(200,3)
    $opPanel.Controls.Add($addBtn)

    $removeBtn = New-Object System.Windows.Forms.Button
    $removeBtn.Text = "Remove"
    $removeBtn.Font = New-Object System.Drawing.Font('Segoe UI',10)
    $removeBtn.Width = 80
    $removeBtn.Location = New-Object System.Drawing.Point(285,3)
    $opPanel.Controls.Add($removeBtn)

    $statusLabel = New-Object System.Windows.Forms.Label
    $statusLabel.Text = ""
    $statusLabel.Font = New-Object System.Drawing.Font('Segoe UI',9,[System.Drawing.FontStyle]::Italic)
    $statusLabel.ForeColor = $script:Theme.Primary
    $statusLabel.Location = New-Object System.Drawing.Point(375,7)
    $statusLabel.AutoSize = $true
    $opPanel.Controls.Add($statusLabel)

    # Event handlers
    $addBtn.Add_Click({
        $networkName = $inputBox.Text.Trim()
        if (-not $networkName) {
            $statusLabel.Text = "Enter a port group name."
            return
        }
        try {
            Add-PortGroup -NetworkName $networkName
            $statusLabel.Text = "Added port group: $networkName"
            Update-PortGroupsTab -DataGrid $dataGrid
        }
        catch {
            $statusLabel.Text = "Failed: $_"
        }
    })

    $removeBtn.Add_Click({
        $networkName = $inputBox.Text.Trim()
        if (-not $networkName) {
            $statusLabel.Text = "Enter a port group name."
            return
        }
        try {
            Remove-PortGroup -NetworkName $networkName
            $statusLabel.Text = "Removed port group: $networkName"
            Update-PortGroupsTab -DataGrid $dataGrid
        }
        catch {
            $statusLabel.Text = "Failed: $_"
        }
    })

    return @{
        Container = $container
        DataGrid = $dataGrid
        InputBox = $inputBox
        AddButton = $addBtn
        RemoveButton = $removeBtn
        StatusLabel = $statusLabel
    }
}


function New-NetworkHostControls {
    <#
    .SYNOPSIS
        Creates the controls for Hosts tab operations.
    #>
    param([System.Windows.Forms.Panel]$Parent)

    $container = New-Object System.Windows.Forms.TableLayoutPanel
    $container.Dock = 'Fill'
    $container.RowCount = 2
    $container.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'Percent',90))
    $container.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'Percent',10))
    $Parent.Controls.Add($container)

    $dataGrid = $Parent.Controls[0].Controls[0] # Get the grid from the parent panel

    $opPanel = New-Object System.Windows.Forms.Panel
    $opPanel.Dock = 'Fill'
    $container.Controls.Add($opPanel, 0, 1)

    # Class Folder
    $lblClass = New-Object System.Windows.Forms.Label
    $lblClass.Text = "Class Folder:"
    $lblClass.Location = New-Object System.Drawing.Point(5,7)
    $lblClass.AutoSize = $true
    $opPanel.Controls.Add($lblClass)
    
    $inputClass = New-Object System.Windows.Forms.TextBox
    $inputClass.Width = 70
    $inputClass.Location = New-Object System.Drawing.Point(80,5)
    $opPanel.Controls.Add($inputClass)

    # Host Name
    $lblHost = New-Object System.Windows.Forms.Label
    $lblHost.Text = "Host Name:"
    $lblHost.Location = New-Object System.Drawing.Point(160,7)
    $lblHost.AutoSize = $true
    $opPanel.Controls.Add($lblHost)
    
    $inputHost = New-Object System.Windows.Forms.TextBox
    $inputHost.Width = 70
    $inputHost.Location = New-Object System.Drawing.Point(240,5)
    $opPanel.Controls.Add($inputHost)

    # Start #
    $lblStart = New-Object System.Windows.Forms.Label
    $lblStart.Text = "Start #:"
    $lblStart.Location = New-Object System.Drawing.Point(320,7)
    $lblStart.AutoSize = $true
    $opPanel.Controls.Add($lblStart)
    
    $inputStart = New-Object System.Windows.Forms.TextBox
    $inputStart.Width = 35
    $inputStart.Location = New-Object System.Drawing.Point(380,5)
    $opPanel.Controls.Add($inputStart)

    # End #
    $lblEnd = New-Object System.Windows.Forms.Label
    $lblEnd.Text = "End #:"
    $lblEnd.Location = New-Object System.Drawing.Point(420,7)
    $lblEnd.AutoSize = $true
    $opPanel.Controls.Add($lblEnd)
    
    $inputEnd = New-Object System.Windows.Forms.TextBox
    $inputEnd.Width = 35
    $inputEnd.Location = New-Object System.Drawing.Point(480,5)
    $opPanel.Controls.Add($inputEnd)

    # Buttons
    $addBtn = New-Object System.Windows.Forms.Button
    $addBtn.Text = "Add"
    $addBtn.Font = New-Object System.Drawing.Font('Segoe UI',10)
    $addBtn.Width = 60
    $addBtn.Location = New-Object System.Drawing.Point(530,3)
    $opPanel.Controls.Add($addBtn)

    $removeBtn = New-Object System.Windows.Forms.Button
    $removeBtn.Text = "Remove"
    $removeBtn.Font = New-Object System.Drawing.Font('Segoe UI',10)
    $removeBtn.Width = 80
    $removeBtn.Location = New-Object System.Drawing.Point(595,3)
    $opPanel.Controls.Add($removeBtn)

    $statusLabel = New-Object System.Windows.Forms.Label
    $statusLabel.Text = ""
    $statusLabel.Font = New-Object System.Drawing.Font('Segoe UI',9,[System.Drawing.FontStyle]::Italic)
    $statusLabel.ForeColor = $script:Theme.Primary
    $statusLabel.Location = New-Object System.Drawing.Point(680,7)
    $statusLabel.AutoSize = $true
    $opPanel.Controls.Add($statusLabel)

    # Event handlers
    $addBtn.Add_Click({
        $classFolder = $inputClass.Text.Trim()
        $hostName = $inputHost.Text.Trim()
        $start = $inputStart.Text.Trim()
        $end = $inputEnd.Text.Trim()
        
        if (-not $classFolder -or -not $hostName -or -not $start -or -not $end) {
            $statusLabel.Text = "All fields are required."
            return
        }
        
        try {
            Add-HostEntity -ClassFolder $classFolder -HostName $hostName -StartStudents $start -EndStudents $end
            $statusLabel.Text = "Hosts added."
            Update-HostsTab -DataGrid $dataGrid
        }
        catch {
            $statusLabel.Text = "Failed: $_"
        }
    })

    $removeBtn.Add_Click({
        $classFolder = $inputClass.Text.Trim()
        $hostName = $inputHost.Text.Trim()
        $start = $inputStart.Text.Trim()
        $end = $inputEnd.Text.Trim()
        
        if (-not $classFolder -or -not $hostName -or -not $start -or -not $end) {
            $statusLabel.Text = "All fields are required."
            return
        }
        
        try {
            Remove-HostEntity -ClassFolder $classFolder -HostName $hostName -StartStudents $start -EndStudents $end
            $statusLabel.Text = "Hosts removed."
            Update-HostsTab -DataGrid $dataGrid
        }
        catch {
            $statusLabel.Text = "Failed: $_"
        }
    })

    return @{
        Container = $container
        DataGrid = $dataGrid
        InputClass = $inputClass
        InputHost = $inputHost
        InputStart = $inputStart
        InputEnd = $inputEnd
        AddButton = $addBtn
        RemoveButton = $removeBtn
        StatusLabel = $statusLabel
    }
}


function New-NetworkAdapterControls {
    <#
    .SYNOPSIS
        Creates the controls for Adapters tab operations.
    #>
    param([System.Windows.Forms.Panel]$Parent)

    $container = New-Object System.Windows.Forms.TableLayoutPanel
    $container.Dock = 'Fill'
    $container.RowCount = 2
    $container.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'Percent',90))
    $container.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'Percent',10))
    $Parent.Controls.Add($container)

    $dataGrid = $Parent.Controls[0].Controls[0] # Get the grid from the parent panel

    $opPanel = New-Object System.Windows.Forms.Panel
    $opPanel.Dock = 'Fill'
    $container.Controls.Add($opPanel, 0, 1)

    # VM Name
    $lblVM = New-Object System.Windows.Forms.Label
    $lblVM.Text = "VM Name:"
    $lblVM.Location = New-Object System.Drawing.Point(5,7)
    $lblVM.AutoSize = $true
    $opPanel.Controls.Add($lblVM)
    
    $inputVM = New-Object System.Windows.Forms.TextBox
    $inputVM.Width = 110
    $inputVM.Location = New-Object System.Drawing.Point(70,5)
    $opPanel.Controls.Add($inputVM)

    # Network Name
    $lblNet = New-Object System.Windows.Forms.Label
    $lblNet.Text = "Network Name:"
    $lblNet.Location = New-Object System.Drawing.Point(190,7)
    $lblNet.AutoSize = $true
    $opPanel.Controls.Add($lblNet)
    
    $inputNet = New-Object System.Windows.Forms.TextBox
    $inputNet.Width = 110
    $inputNet.Location = New-Object System.Drawing.Point(280,5)
    $opPanel.Controls.Add($inputNet)

    # Buttons
    $addBtn = New-Object System.Windows.Forms.Button
    $addBtn.Text = "Add"
    $addBtn.Font = New-Object System.Drawing.Font('Segoe UI',10)
    $addBtn.Width = 60
    $addBtn.Location = New-Object System.Drawing.Point(400,3)
    $opPanel.Controls.Add($addBtn)

    $removeBtn = New-Object System.Windows.Forms.Button
    $removeBtn.Text = "Remove"
    $removeBtn.Font = New-Object System.Drawing.Font('Segoe UI',10)
    $removeBtn.Width = 80
    $removeBtn.Location = New-Object System.Drawing.Point(470,3)
    $opPanel.Controls.Add($removeBtn)

    $statusLabel = New-Object System.Windows.Forms.Label
    $statusLabel.Text = ""
    $statusLabel.Font = New-Object System.Drawing.Font('Segoe UI',9,[System.Drawing.FontStyle]::Italic)
    $statusLabel.ForeColor = $script:Theme.Primary
    $statusLabel.Location = New-Object System.Drawing.Point(560,7)
    $statusLabel.AutoSize = $true
    $opPanel.Controls.Add($statusLabel)

    # Event handlers
    $addBtn.Add_Click({
        $vmName = $inputVM.Text.Trim()
        $netName = $inputNet.Text.Trim()
        
        if (-not $vmName -or -not $netName) {
            $statusLabel.Text = "Both fields required."
            return
        }
        
        try {
            Add-Adapter -VMName $vmName -NetworkName $netName
            $statusLabel.Text = "Adapter added."
            Update-AdaptersTab -DataGrid $dataGrid
        }
        catch {
            $statusLabel.Text = "Failed: $_"
        }
    })

    $removeBtn.Add_Click({
        $vmName = $inputVM.Text.Trim()
        $netName = $inputNet.Text.Trim()
        
        if (-not $vmName -or -not $netName) {
            $statusLabel.Text = "Both fields required."
            return
        }
        
        try {
            Remove-Adapter -VMName $vmName -NetworkName $netName
            $statusLabel.Text = "Adapter removed."
            Update-AdaptersTab -DataGrid $dataGrid
        }
        catch {
            $statusLabel.Text = "Failed: $_"
        }
    })

    return @{
        Container = $container
        DataGrid = $dataGrid
        InputVM = $inputVM
        InputNet = $inputNet
        AddButton = $addBtn
        RemoveButton = $removeBtn
        StatusLabel = $statusLabel
    }
}

function New-NetworkTemplateControls {
    <#
    .SYNOPSIS
        Creates the controls for Templates tab operations.
    #>
    param([System.Windows.Forms.Panel]$Parent)

    $container = New-Object System.Windows.Forms.TableLayoutPanel
    $container.Dock = 'Fill'
    $container.RowCount = 2
    $container.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'Percent',90))
    $container.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'Percent',10))
    $Parent.Controls.Add($container)

    $dataGrid = $Parent.Controls[0].Controls[0] # Get the grid from the parent panel

    $opPanel = New-Object System.Windows.Forms.Panel
    $opPanel.Dock = 'Fill'
    $container.Controls.Add($opPanel, 0, 1)

    $inputBox = New-Object System.Windows.Forms.TextBox
    $inputBox.Width = 160
    $inputBox.Location = New-Object System.Drawing.Point(5,5)
    $inputBox.Font = New-Object System.Drawing.Font('Segoe UI',10)
    $opPanel.Controls.Add($inputBox)

    $addBtn = New-Object System.Windows.Forms.Button
    $addBtn.Text = "Add"
    $addBtn.Font = New-Object System.Drawing.Font('Segoe UI',10)
    $addBtn.Width = 80
    $addBtn.Location = New-Object System.Drawing.Point(180,3)
    $opPanel.Controls.Add($addBtn)

    $removeBtn = New-Object System.Windows.Forms.Button
    $removeBtn.Text = "Remove"
    $removeBtn.Font = New-Object System.Drawing.Font('Segoe UI',10)
    $removeBtn.Width = 80
    $removeBtn.Location = New-Object System.Drawing.Point(265,3)
    $opPanel.Controls.Add($removeBtn)

    $statusLabel = New-Object System.Windows.Forms.Label
    $statusLabel.Text = ""
    $statusLabel.Font = New-Object System.Drawing.Font('Segoe UI',9,[System.Drawing.FontStyle]::Italic)
    $statusLabel.ForeColor = $script:Theme.Primary
    $statusLabel.Location = New-Object System.Drawing.Point(360,7)
    $statusLabel.AutoSize = $true
    $opPanel.Controls.Add($statusLabel)

    # Event handlers
    $addBtn.Add_Click({
        $templateName = $inputBox.Text.Trim()
        if (-not $templateName) {
            $statusLabel.Text = "Enter a template name."
            return
        }
        try {
            Add-Template -TemplateName $templateName
            $statusLabel.Text = "Template created."
            Update-TemplatesTab -DataGrid $dataGrid
        }
        catch {
            $statusLabel.Text = "Failed: $_"
        }
    })

    $removeBtn.Add_Click({
        $templateName = $inputBox.Text.Trim()
        if (-not $templateName) {
            $statusLabel.Text = "Enter a template name."
            return
        }
        try {
            Remove-Template -TemplateName $templateName
            $statusLabel.Text = "Template removed."
            Update-TemplatesTab -DataGrid $dataGrid
        }
        catch {
            $statusLabel.Text = "Failed: $_"
        }
    })

    return @{
        Container = $container
        DataGrid = $dataGrid
        InputBox = $inputBox
        AddButton = $addBtn
        RemoveButton = $removeBtn
        StatusLabel = $statusLabel
    }
}



# ─────────────────────────  Data-to-UI binder  ───────────────────────────────
# Bind data to grids
function Update-NetworkViewWithData {
    [CmdletBinding()] param([hashtable] $UiRefs, [hashtable] $Data)

    if ($Data.Hosts.Count -gt 0) {
        $h=$Data.Hosts[0]
        $UiRefs.StatusLabel.Text = "CONNECTED to $($h.Name) | vSphere $($h.Version)"
        $UiRefs.StatusLabel.ForeColor=$script:Theme.Success
    }
    # Bind sources
    $UiRefs.Tabs['Overview'].DataGrid.DataSource = $Data.PortGroups
    $UiRefs.Tabs['PortGroups'].DataGrid.DataSource = $Data.PortGroups
    $UiRefs.Tabs['Hosts'].DataGrid.DataSource = $Data.Hosts
    $UiRefs.Tabs['Adapters'].DataGrid.DataSource = $Data.Adapters
    $UiRefs.Tabs['Templates'].DataGrid.DataSource = $Data.Templates
}



# ─────────────────────────  Tab-specific functions  ──────────────────────────



function Update-PortGroupsTab {
    param([System.Windows.Forms.DataGridView]$DataGrid)

    $DataGrid.Rows.Clear()
    $vmHost = Get-VMHost | Select-Object -First 1

    foreach ($pg in Get-VirtualPortGroup -VMHost $vmHost) {
        $DataGrid.Rows.Add($pg.Name, $pg.VirtualSwitchName)
    }
}



function Add-PortGroup {
    param([string]$NetworkName)
    $vmHost = Get-VMHost | Select-Object -First 1

    if (-not (Get-VirtualSwitch -Name $NetworkName -VMHost $vmHost -ErrorAction SilentlyContinue)) {
        $vSwitch = New-VirtualSwitch -Name $NetworkName -VMHost $vmHost
        $vPortGroup = New-VirtualPortGroup -Name $NetworkName -VirtualSwitch $vSwitch
    }
}

function Remove-PortGroup {
    param([string]$NetworkName)

    $vmHost = Get-VMHost | Select-Object -First 1

    $pg = Get-VirtualPortGroup -VMHost $vmHost -Name $NetworkName -ErrorAction SilentlyContinue
    if ($pg) {
        $pg | Remove-VirtualPortGroup -Confirm:$false
    }

    $vsw = Get-VirtualSwitch -Name $NetworkName -VMHost $vmHost -ErrorAction SilentlyContinue
    if ($vsw) {
        $vsw | Remove-VirtualSwitch -Confirm:$false
    }
}
