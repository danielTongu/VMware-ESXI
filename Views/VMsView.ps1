# ---------------------------------------------------------------------------
# Load WinForms assemblies
# ---------------------------------------------------------------------------
Add-Type -AssemblyName 'System.Windows.Forms'
Add-Type -AssemblyName 'System.Drawing'



function Show-VMsView {
    <#
    .SYNOPSIS
        Renders the "Virtual Machines" view into the supplied WinForms panel.
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Forms.Panel] $ContentPanel
    )

    $script:uiRefs = New-VMsLayout -ContentPanel $ContentPanel

    $data = Get-VMsData

    if ($data) {
        Update-VMData -UiRefs $script:uiRefs -Data $data
        Wire-UIEvents -UiRefs $script:uiRefs
    }
}


function New-VMsLayout {
    <#
    .SYNOPSIS
        Builds the WinForms layout and returns references to key controls.
    #>

    [CmdletBinding()]
    param([Parameter(Mandatory)] [System.Windows.Forms.Panel] $ContentPanel)

    $ContentPanel.Controls.Clear()
    $ContentPanel.BackColor = $script:Theme.LightGray

    # ----- Root TableLayoutPanel ---------------------------------------------
    $root = New-Object System.Windows.Forms.TableLayoutPanel
    $root.Dock = 'Fill'
    $root.ColumnCount = 1
    $root.RowCount = 3
    $root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
    $root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    $root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
    $ContentPanel.Controls.Add($root)

    # ----- Header ------------------------------------------------------------
    $header = New-Object System.Windows.Forms.Panel
    $header.Dock = 'Fill'
    $header.Height = 60
    $header.BackColor = $script:Theme.Primary
    $root.Controls.Add($header, 0, 0)

    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = 'VIRTUAL MACHINES'
    $titleLabel.Font = New-Object System.Drawing.Font('Segoe UI', 18, [System.Drawing.FontStyle]::Bold)
    $titleLabel.ForeColor = $script:Theme.White
    $titleLabel.Location = New-Object System.Drawing.Point(20, 15)
    $titleLabel.AutoSize = $true
    $header.Controls.Add($titleLabel)

    # ----- Main Layout --------------------------------------------------------
    $mainLayout = New-Object System.Windows.Forms.TableLayoutPanel
    $mainLayout.Dock = 'Fill'
    $mainLayout.ColumnCount = 1
    $mainLayout.RowCount = 3
    $mainLayout.BackColor = $script:Theme.White
    $mainLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
    $mainLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    $mainLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
    $root.Controls.Add($mainLayout, 0, 1)

    # ----- Main Layout - Filter bar -------------------------------------------
    $filterPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $filterPanel.Dock = 'Fill'
    $filterPanel.Autosize = $true
    $filterPanel.FlowDirection = 'LeftToRight'
    $filterPanel.Padding = New-Object System.Windows.Forms.Padding(10, 5, 10, 5)
    $mainLayout.Controls.Add($filterPanel, 0, 0)

    $searchBox = New-Object System.Windows.Forms.TextBox
    $searchBox.Dock = 'Fill'
    $searchBox.Name = 'txtFilter'
    $searchBox.Width = 300
    $searchBox.FlatStyle = 'Flat'
    $searchBox.Margin = New-Object System.Windows.Forms.Padding(5)
    $searchBox.Font = New-Object System.Drawing.Font('Segoe UI', 12)
    $searchBox.BackColor = $script:Theme.White
    $searchBox.ForeColor = $script:Theme.PrimaryDarker
    $filterPanel.Controls.Add($searchBox)

    $searchBtn = New-FormButton -Name 'btnSearch' -Text 'SEARCH' -Size (New-Object System.Drawing.Size(100, 30))
    $filterPanel.Controls.Add($searchBtn)

    $refreshBtn = New-FormButton -Name 'btnRefresh' -Text 'REFRESH' -Size (New-Object System.Drawing.Size(100, 30))
    $filterPanel.Controls.Add($refreshBtn)

    # ----- Main Layout - Grid ------------------------------------------------
    $gridContainer = New-Object System.Windows.Forms.Panel
    $gridContainer.Dock = 'Fill'
    $gridContainer.Autosize = $true
    $gridContainer.AutoScroll = $true
    $gridContainer.Padding = New-Object System.Windows.Forms.Padding(10)
    $gridContainer.BackColor = $script:Theme.White
    $mainLayout.Controls.Add($gridContainer, 0, 1)

    $grid = New-Object System.Windows.Forms.DataGridView
    $grid.Name = 'gvVMs'
    $grid.Dock = 'Fill'
    $grid.AutoSizeColumnsMode = 'Fill'
    $grid.ReadOnly = $true
    $grid.AllowUserToAddRows = $false
    $grid.SelectionMode = 'FullRowSelect'
    $grid.MultiSelect = $false
    $grid.AutoGenerateColumns = $false
    $grid.BackgroundColor = $script:Theme.White
    $grid.BorderStyle = 'FixedSingle'
    $grid.ColumnHeadersDefaultCellStyle.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
    $gridContainer.Controls.Add($grid)

    $numCol = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $numCol.Name = 'No'
    $numCol.HeaderText = '#'
    $numCol.Width = 50
    $numCol.ReadOnly = $true
    $numCol.SortMode = 'NotSortable'
    $grid.Columns.Add($numCol) | Out-Null

    $columns = @(
        @{ Name = 'Name'; Header = 'VM Name' },
        @{ Name = 'PowerState'; Header = 'Status' },
        @{ Name = 'IP'; Header = 'IP Address' },
        @{ Name = 'CPU'; Header = 'vCPU' },
        @{ Name = 'MemoryGB'; Header = 'Memory (GB)' }
    )

    foreach ($col in $columns) {
        $gridCol = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
        $gridCol.Name = $col.Name
        $gridCol.HeaderText = $col.Header
        $gridCol.DataPropertyName = $col.Name
        $gridCol.ReadOnly = $true
        $grid.Columns.Add($gridCol) | Out-Null
    }

    # ----- Main Layout - Action buttons -------------------------------------
    $actions = New-Object System.Windows.Forms.FlowLayoutPanel
    $actions.Dock = 'Fill'
    $actions.Autosize = $true
    $actions.FlowDirection = 'LeftToRight'
    $actions.Padding = New-Object System.Windows.Forms.Padding(10, 5, 10, 5)
    $mainLayout.Controls.Add($actions, 0, 2)

    $btns = @{}

    # Single VM actions
    $singleVMActions = @(
        @{ Key = 'PowerOff'; Text = 'POWER OFF' },
        @{ Key = 'PowerOn'; Text = 'POWER ON' },
        @{ Key = 'Restart'; Text = 'RESTART' }
    )

    New-ButtonGroup -ParentPanel $actions -GroupTitle "Selected Virtual Machine" `
        -ButtonDefinitions $singleVMActions -ButtonsHashTable $btns

    # Multiple VM actions
    $multipleVMActions = @(
        @{ Key = 'PowerAllOff'; Text = 'POWER OFF' },
        @{ Key = 'PowerAllOn'; Text = 'POWER ON' }
    )

    New-ButtonGroup -ParentPanel $actions -GroupTitle "All Virtual Machines" `
        -ButtonDefinitions $multipleVMActions -ButtonsHashTable $btns

    # ----- Footer status label --------------------------------------------
    $footer = New-Object System.Windows.Forms.Panel
    $footer.Dock = 'Fill'
    $footer.Autosize = $true
    $footer.AutoScroll = $true
    $root.Controls.Add($footer, 0, 2)

    $statusLabel = New-Object System.Windows.Forms.Label
    $statusLabel.AutoSize = $true
    $statusLabel.Name = 'StatusLabel'
    $statusLabel.Text = 'Ready'
    $statusLabel.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $statusLabel.ForeColor = $script:Theme.PrimaryDarker
    $footer.Controls.Add($statusLabel)

    # ----- Return handles ------------------------------------------------
    return @{
        ContentPanel  = $ContentPanel
        Grid          = $grid
        SearchBox     = $searchBox
        SearchButton  = $searchBtn
        RefreshButton = $refreshBtn
        StatusLabel   = $statusLabel
        Buttons       = $btns
    }
}


function Get-VMsData {
    <#
    .SYNOPSIS
        Returns VM information from the active vSphere connection.

    .OUTPUTS
        Array of PSObjects or $null when disconnected.
    #>

    [CmdletBinding()] param()

    if (-not $script:Connection) {
        Set-StatusMessage -UiRefs $UiRefs -Message "No vSphere connection available" -Type Error
        Write-Verbose "No vSphere connection available"
        return $null 
    }

    try {
        $vms = Get-VM -Server $script:Connection -ErrorAction Stop | Select-Object `
            Name,
            PowerState,
            @{ Name='IP'
               Expression={
                   if ($_.Guest.IPAddress -and $_.Guest.IPAddress.Count -gt 0) {
                       $_.Guest.IPAddress[0]
                   }
                   else { '' }
               }
            },
            @{ Name='CPU'      ; Expression={ $_.NumCpu } },
            @{ Name='MemoryGB' ; Expression={ [math]::Round($_.MemoryGB,2) } }
        
        Write-Verbose "Retrieved data for $($vms.Count) VMs"
        return $vms
    }
    catch {
        Write-Verbose "Failed to acquire VM data: $_"
        return $null
    }
}


function Update-VMData {
    <#
    .SYNOPSIS
        Refreshes VM data and updates the UI, handling all status messages.
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][psobject] $UiRefs,
        $Data
    )

    Set-StatusMessage -UiRefs $UiRefs -Message "Refreshing VM data..." -Type Info  
    
    # Clear previous rows
    $UiRefs.Grid.Rows.Clear()

    # Prepare for data display
    if (-not $Data) {
        Set-StatusMessage -UiRefs $UiRefs -Message "No Data Found" -Type Error
        return
    }

    # Insert one row per VM
    foreach ($vm in $Data) {
        $rowIndex = $UiRefs.Grid.Rows.Add()
        $row = $UiRefs.Grid.Rows[$rowIndex]

        $row.Cells['No'].Value = $rowIndex + 1
        $row.Cells['Name'].Value = $vm.Name
        $row.Cells['PowerState'].Value = $vm.PowerState
        $row.Cells['IP'].Value = $vm.IP
        $row.Cells['CPU'].Value = $vm.CPU
        $row.Cells['MemoryGB'].Value = $vm.MemoryGB

        if ($vm.PowerState -eq 'PoweredOn') {
            $row.Cells['PowerState'].Style.ForeColor = [System.Drawing.Color]::Green
        }
        else {
            $row.Cells['PowerState'].Style.ForeColor = [System.Drawing.Color]::Red
        }
    }

    # Resize columns for readability
    $UiRefs.Grid.AutoResizeColumns()

    Set-StatusMessage -UiRefs $UiRefs -Message "$($Data.Count) VMs found" -Type Success
}


function Wire-UIEvents {
    <#
    .SYNOPSIS
        Hooks up all UI events with properly captured UiRefs.
    #>

    param(
        [Parameter(Mandatory)]
        [psobject] $UiRefs
    )

    # Search button click event
    $UiRefs.SearchButton.Add_Click({
        param($sender, $e)
        . $PSScriptRoot\VMsView.ps1
        Apply-Filter -UiRefs $UiRefs -Sender $sender -EventArgs $e
    })

    # Search box key down event (Enter key)
    $UiRefs.SearchBox.Add_KeyDown({
        param($sender, $e)
        if ($e.KeyCode -eq 'Enter') {
            . $PSScriptRoot\VMsView.ps1
            Apply-Filter -UiRefs $UiRefs -Sender $sender -EventArgs $e
        }
    })

    # Refresh button click event
    $UiRefs.RefreshButton.Add_Click({
        . $PSScriptRoot\VMsView.ps1
        Show-VMsView -ContentPanel $UiRefs.ContentPanel
    })

    # Power operation buttons
    $UiRefs.Buttons.PowerOn.Add_Click({
        . $PSScriptRoot\VMsView.ps1
        Invoke-PowerOperation -UiRefs $UiRefs -Operation 'On'
    })

    $UiRefs.Buttons.PowerOff.Add_Click({
        . $PSScriptRoot\VMsView.ps1
        Invoke-PowerOperation -UiRefs $UiRefs -Operation 'Off'
    })

    $UiRefs.Buttons.PowerAllOn.Add_Click({
        . $PSScriptRoot\VMsView.ps1
        Invoke-PowerOperation -UiRefs $UiRefs -Operation 'AllOn'
    })

    $UiRefs.Buttons.PowerAllOff.Add_Click({
        . $PSScriptRoot\VMsView.ps1
        Invoke-PowerOperation -UiRefs $UiRefs -Operation 'AllOff'
    })

    $UiRefs.Buttons.Restart.Add_Click({
        . $PSScriptRoot\VMsView.ps1
        Invoke-PowerOperation -UiRefs $UiRefs -Operation 'Restart'
    })
}


#------------------------- Helper functions ---------------------------------


function New-FormButton {
    <#
    .SYNOPSIS
        Creates a consistently styled form button.
    .DESCRIPTION
        Creates a button with standardized styling based on the application theme.
    #>

    param(
        [Parameter(Mandatory)][string] $Name,
        [Parameter(Mandatory)][string] $Text,
        [System.Drawing.Size] $Size,
        [System.Windows.Forms.Padding] $Margin,
        [System.Drawing.Font] $Font = $null
    )

    $button = New-Object System.Windows.Forms.Button
    $button.Name = $Name
    $button.Text = $Text
    $button.FlatStyle     = 'Flat'
    
    if ($Size) {$button.Size = $Size} 
    else { $button.Size = New-Object System.Drawing.Size(120, 35)}
    
    if ($Margin) {$button.Margin = $Margin}
    else { $button.Margin = New-Object System.Windows.Forms.Padding(5)}
    
    if ($Font) {$button.Font = $Font} 
    else { $button.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)}
    
    $button.BackColor = $script:Theme.Primary
    $button.ForeColor = $script:Theme.White
    
    return $button
}


function New-ButtonGroup {
    <#
    .SYNOPSIS
        Creates a grouped set of buttons in a FlowLayoutPanel.
    #>

    param(
        [Parameter(Mandatory)][System.Windows.Forms.FlowLayoutPanel] $ParentPanel,
        [Parameter(Mandatory)][string] $GroupTitle,
        [Parameter(Mandatory)][array] $ButtonDefinitions,
        [Parameter(Mandatory)][hashtable] $ButtonsHashTable
    )

    $group = New-Object System.Windows.Forms.GroupBox
    $group.Text = $GroupTitle
    $group.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
    $group.Dock = 'Fill'
    $group.Autosize = $true
    $group.Padding = New-Object System.Windows.Forms.Padding(10)
    $ParentPanel.Controls.Add($group)

    $panel = New-Object System.Windows.Forms.FlowLayoutPanel
    $panel.Dock = 'Fill'
    $panel.FlowDirection = 'LeftToRight'
    $panel.Autosize = $true
    $group.Controls.Add($panel)

    foreach ($def in $ButtonDefinitions) {
        $btn = New-FormButton -Name "btn$($def.Key)" -Text $def.Text
        $panel.Controls.Add($btn)
        $ButtonsHashTable[$def.Key] = $btn
    }
}

function Apply-Filter {
    <#
    .SYNOPSIS
        Applies filter to the grid based on search text.
    #>

    param(
        [Parameter(Mandatory)]
        [psobject] $UiRefs,
        $Sender,
        $EventArgs
    )
    
    # If invoked via KeyDown, bail out on non-Enter
    if ($EventArgs -is [System.Windows.Forms.KeyEventArgs] -and $EventArgs.KeyCode -ne [System.Windows.Forms.Keys]::Enter) {
        return
    }
    
    if ($EventArgs -is [System.Windows.Forms.KeyEventArgs]) {
        $EventArgs.Handled = $true
        $EventArgs.SuppressKeyPress = $true
    }

    $needle = $UiRefs.SearchBox.Text.Trim()
    $hasFilter = -not [string]::IsNullOrWhiteSpace($needle)
    $visibleCount = 0

    foreach ($row in $UiRefs.Grid.Rows) {
        $name  = $row.Cells['Name'].Value
        $ip    = $row.Cells['IP'].Value
        $state = $row.Cells['PowerState'].Value

        $row.Visible = -not $hasFilter -or 
                        ($name -like "*$needle*") -or 
                        ($ip -like "*$needle*") -or 
                        ($state -like "*$needle*")
        
        if ($row.Visible) { $visibleCount++ }
    }

    $total = $UiRefs.Grid.Rows.Count
    if (-not $hasFilter) {
        Set-StatusMessage -UiRefs $UiRefs -Message "Filter cleared: showing all $total VMs" -Type Success
    }
    else {
        $message = "Filter applied: showing $visibleCount of $total VMs"
        $type = if ($visibleCount -gt 0) { 'Success' } else { 'Warning' }
        Set-StatusMessage -UiRefs $UiRefs -Message $message -Type $type
    }
}


function Invoke-PowerOperation {
    <#
    .SYNOPSIS
        Performs power operations on selected VMs.
    #>

    param(
        [Parameter(Mandatory)]
        [psobject] $UiRefs,
        [ValidateSet('On','Off','AllOn','AllOff','Restart')]
        [string]$Operation,
        [bool]$Force = $false
    )

    try {
        # Determine target VMs
        if ($Operation -like 'All*') {
            $targetVMs = $UiRefs.Grid.Rows | Where-Object { $_.Visible } | ForEach-Object { $_.Cells['Name'].Value }
            $Operation = $Operation -replace 'All', ''
        }
        else {
            $selectedRows = @($UiRefs.Grid.SelectedRows)
            if ($selectedRows.Count -eq 0) {
                Set-StatusMessage -UiRefs $UiRefs -Message "No VMs selected" -Type Warning
                return
            }
            $targetVMs = $selectedRows | ForEach-Object { $_.Cells['Name'].Value }
        }

        if (-not $targetVMs) {
            Set-StatusMessage -UiRefs $UiRefs -Message "No VMs to operate on" -Type Warning
            return
        }

        # Get confirmation unless forced
        if (-not $Force) {
            $confirmMessage = switch ($Operation) {
                'On'     { "Power ON selected VMs?" }
                'Off'    { "Power OFF selected VMs?" }
                'Restart'{ "RESTART selected VMs?" }
            }

            $result = [System.Windows.Forms.MessageBox]::Show(
                $confirmMessage,
                "Confirm",
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Question
            )

            if ($result -ne [System.Windows.Forms.DialogResult]::Yes) {
                Set-StatusMessage -UiRefs $UiRefs -Message "Operation cancelled" -Type Info
                return
            }
        }

        Set-StatusMessage -UiRefs $UiRefs -Message "Performing $Operation operation..." -Type Info

        # Execute operation
        $successCount = 0
        foreach ($vmName in $targetVMs) {
            try {
                $vm = Get-VM -Name $vmName -Server $script:Connection -ErrorAction Stop
                switch ($Operation) {
                    'On'     { $vm | Start-VM -Confirm:$false }
                    'Off'    { $vm | Stop-VM -Confirm:$false -Kill:$true }
                    'Restart' { $vm | Restart-VM -Confirm:$false -Kill:$true }
                }
                $successCount++
            }
            catch {
                Write-Verbose ("Failed to {0} VM {1}: {2}" -f $Operation, $vmName, $_)
            }
        }

        # Refresh and show status
        Update-VMData -UiRefs $UiRefs -Data Get-VMsData
        Set-StatusMessage -UiRefs $UiRefs -Message "Completed $Operation operation on $successCount of $($targetVMs.Count) VMs" -Type Success
    }
    catch {
        Write-Verbose "Power operation error: $_"
        Set-StatusMessage -UiRefs $UiRefs -Message "Error performing $Operation operation" -Type Error
    }
}


function Set-StatusMessage {
    <#
    .SYNOPSIS
        Sets the status message with appropriate color coding.
    #>

    param(
        [Parameter(Mandatory)]
        [psobject] $UiRefs,
        [string]$Message,
        [ValidateSet('Success','Warning','Error','Info')]
        [string]$Type = 'Info'
    )
    
    $UiRefs.StatusLabel.Text = $Message
    $UiRefs.StatusLabel.ForeColor = switch ($Type) {
        'Success' { $script:Theme.Success }
        'Warning' { $script:Theme.Warning }
        'Error'   { $script:Theme.Error }
        default   { $script:Theme.PrimaryDarker }
    }
}