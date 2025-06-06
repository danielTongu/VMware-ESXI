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

    $script:Refs = New-VMsLayout -ContentPanel $ContentPanel
    [System.Windows.Forms.Application]::DoEvents()

    $data = Get-VMsData

    if ($data) {
        Update-VMData -Data $data
        Wire-UIEvents
    }
}


function New-VMsLayout {
    <#
    .SYNOPSIS
        Builds the WinForms layout and returns references to key controls.
        Returns the UI references.
    #>

    [CmdletBinding()]
    param([Parameter(Mandatory)] [System.Windows.Forms.Panel] $ContentPanel)

    $ContentPanel.Controls.Clear()
    $ContentPanel.BackColor = $script:Theme.LightGray
    $Refs = @{ ContentPanel = $ContentPanel }

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
    $header.Height = 90
    $header.BackColor = $script:Theme.Primary
    $root.Controls.Add($header, 0, 0)

    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = 'VIRTUAL MACHINES'
    $titleLabel.Font = New-Object System.Drawing.Font('Segoe UI', 18, [System.Drawing.FontStyle]::Bold)
    $titleLabel.ForeColor = $script:Theme.White
    $titleLabel.Location = New-Object System.Drawing.Point(20, 15)
    $titleLabel.AutoSize = $true
    $header.Controls.Add($titleLabel)

    # Last Refresh Label
    $refreshLabel = New-Object System.Windows.Forms.Label
    $refreshLabel.Name = 'LastRefreshLabel'
    $refreshLabel.Text = "Last refresh: $(Get-Date -Format 'HH:mm:ss tt')"
    $refreshLabel.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $refreshLabel.ForeColor = $script:Theme.White
    $refreshLabel.Location = New-Object System.Drawing.Point(20, 50)  # Positioned below title
    $refreshLabel.AutoSize = $true
    $header.Controls.Add($refreshLabel)
    $Refs['RefreshLabel'] = $refreshLabel

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
    $filterPanel.BackColor = $script:Theme.LightGray
    $filterPanel.Padding = New-Object System.Windows.Forms.Padding(10, 5, 10, 5)
    $mainLayout.Controls.Add($filterPanel, 0, 0)

    $searchBox = New-Object System.Windows.Forms.TextBox
    $searchBox.Dock = 'Fill'
    $searchBox.Name = 'txtFilter'
    $searchBox.Width = 300
    $searchBox.Margin = New-Object System.Windows.Forms.Padding(5)
    $searchBox.Font = New-Object System.Drawing.Font('Segoe UI', 12)
    $searchBox.BackColor = $script:Theme.White
    $searchBox.ForeColor = $script:Theme.PrimaryDarker
    $filterPanel.Controls.Add($searchBox)
    $Refs['SearchBox'] = $searchBox

    $searchBtn = New-FormButton -Name 'btnSearch' -Text 'SEARCH' -Size (New-Object System.Drawing.Size(100, 30))
    $filterPanel.Controls.Add($searchBtn)
    $Refs['SearchButton'] = $searchBtn

    $clearBtn = New-FormButton -Name 'btnClear' -Text 'CLEAR' -Size (New-Object System.Drawing.Size(100, 30))
    $filterPanel.Controls.Add($clearBtn)
    $Refs['ClearButton'] = $clearBtn


    $refreshBtn = New-FormButton -Name 'btnRefresh' -Text 'REFRESH' -Size (New-Object System.Drawing.Size(100, 30))
    $filterPanel.Controls.Add($refreshBtn)
    $Refs['RefreshButton'] = $refreshBtn

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
    $Refs['Grid'] = $grid

    # Hidden ID Column (For using VMs ID instead of their names for power operations)
    $idCol = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $idCol.Name = 'Id'
    $idCol.HeaderText = 'ID'
    $idCol.Visible = $false 
    $grid.Columns.Add($idCol) | Out-Null

    $numCol = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $numCol.Name = 'No'
    $numCol.HeaderText = '#'
    $numCol.Width = 50
    $numCol.ReadOnly = $true
    $numCol.SortMode = 'NotSortable'
    $grid.Columns.Add($numCol) | Out-Null

    $columns = @(
        @{ Name = 'Folder'; Header = 'Folder'; Width = 80},        # New Folder Column
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

    $Refs['Buttons'] = $btns

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
    $statusLabel.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
    $statusLabel.ForeColor = $script:Theme.PrimaryDarker
    $footer.Controls.Add($statusLabel)
    $Refs['StatusLabel'] =  $statusLabel

    # ----- Return handles ------------------------------------------------
    return $Refs
}

function Set-StatusMessage {
    <#
    .SYNOPSIS
        Sets the status message with appropriate color coding.
    #>

    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('Success','Warning','Error','Info')][string]$Type = 'Info'
    )
    
    $script:Refs.StatusLabel.Text = $Message
    $script:Refs.StatusLabel.ForeColor = switch ($Type) {
        'Success' { $script:Theme.Success }
        'Warning' { $script:Theme.Warning }
        'Error'   { $script:Theme.Error }
        default   { $script:Theme.PrimaryDarker }
    }

    [System.Windows.Forms.Application]::DoEvents()
}


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


function Get-VMsData {
    <#
    .SYNOPSIS
        Returns VM information from the active vSphere connection.

    .OUTPUTS
        Array of PSObjects or $null when disconnected.
    #>

    [CmdletBinding()] param()

    if (-not $script:Connection) {
        Set-StatusMessage -Message "No connection to vCenter." -Type Error
        Write-Verbose "No vSphere connection available"
        return $null 
    }

    try {
        Set-StatusMessage -Message "Loading VMs list..." -Type Info
        $vms = Get-VM -Server $script:Connection -ErrorAction Stop | Select-Object `
            Name,
            Id,
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
            @{ Name='MemoryGB' ; Expression={ [math]::Round($_.MemoryGB,2) } },
            @{ Name='Folder'    ; Expression={ 
                    $folder = $_.Folder
                    $pathParts = @()
                    
                    # Walk up the folder hierarchy
                    while ($folder) {
                        $pathParts += $folder.Name
                        $folder = $folder.Parent
                    }
                    
                    # Reverse to get top-down path
                    $fullPath = ($pathParts[-1..-($pathParts.Count)] -join '\')
                    Write-Verbose "VM: $($_.Name) - Full Path: $fullPath"
                    
                    # Look for class folder (CS followed by 3 digits)
                    if ($fullPath -match '\\(CS\d{3})\\') {
                        return $matches[1]
                    }
                    # Look for other identifiable folders
                    elseif ($fullPath -match '\\(GoldImages)\\') {
                        return $matches[1]
                    }
                    # Default case
                    else {
                        return 'Root'
                    }
                }
            }
            
        Set-StatusMessage -Message "Retrieved data for $($vms.Count) VMs" -Type Success
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
    param([Parameter(Mandatory)]$Data)

    # Update refresh time
    $script:Refs.RefreshLabel.Text = "Last refresh: $(Get-Date -Format 'HH:mm:ss tt')"

    Set-StatusMessage -Message "Refreshing VM data..." -Type Info
    
    # Clear previous rows
    $script:Refs.Grid.Rows.Clear()

    # Prepare for data display
    if (-not $Data) {
        Set-StatusMessage -Message "No Data Found" -Type Error
        return
    }

    # Insert one row per VM
    foreach ($vm in $Data) {
        $rowIndex = $script:Refs.Grid.Rows.Add()
        $row = $script:Refs.Grid.Rows[$rowIndex]

        $row.Cells['Id'].Value = $vm.Id
        $row.Cells['No'].Value = $rowIndex + 1
        $row.Cells['Folder'].Value = $vm.Folder
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
    $script:Refs.Grid.AutoResizeColumns()

    Set-StatusMessage -Message "$($Data.Count) VMs found" -Type Success
}


function Apply-Filter {
    <#
    .SYNOPSIS
        Applies filter to the grid across all VM fields (columns), case-insensitively.
    #>

    param(
        [Parameter(Mandatory)]$Sender,
        $EventArgs
    )

    # If triggered by key, only proceed on Enter
    if ($EventArgs -is [System.Windows.Forms.KeyEventArgs] -and $EventArgs.KeyCode -ne [System.Windows.Forms.Keys]::Enter) {
        return
    }

    if ($EventArgs -is [System.Windows.Forms.KeyEventArgs]) {
        $EventArgs.Handled = $true
        $EventArgs.SuppressKeyPress = $true
    }

    $needle = $script:Refs.SearchBox.Text.Trim()
    $hasFilter = -not [string]::IsNullOrWhiteSpace($needle)
    $needleLC = $needle.ToLower()
    $visibleCount = 0

    foreach ($row in $script:Refs.Grid.Rows) {
        $row.Visible = $false

        if (-not $hasFilter) {
            $row.Visible = $true
        } else {
            foreach ($cell in $row.Cells) {
                if ($cell.Value -and $cell.Value.ToString().ToLower().Contains($needleLC)) {
                    $row.Visible = $true
                    break
                }
            }
        }

        if ($row.Visible) { $visibleCount++ }
    }

    $total = $script:Refs.Grid.Rows.Count

    if (-not $hasFilter) {
        Set-StatusMessage -Message "Filter cleared: showing all $total VMs" -Type Success
    } else {
        $message = "Filter applied: showing $visibleCount of $total VMs"
        $type = if ($visibleCount -gt 0) { 'Success' } else { 'Warning' }
        Set-StatusMessage -Message $message -Type $type
    }
}



function Invoke-PowerOperation {
    <#
    .SYNOPSIS
        Performs power operations on selected VMs.
    #>

    param(
        [Parameter(Mandatory)][ValidateSet('On','Off','AllOn','AllOff','Restart')][string]$Operation,
        [bool]$Force = $false
    )

    $script:Form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor

    $result = $false
    $targetVMIds = @()  # Changed from targetVMs to targetVMIds
    $successCount = 0

    # Determine target VMs by ID
    if ($Operation -like 'All*') {
        $targetVMIds = $script:Refs.Grid.Rows | Where-Object { $_.Visible } | ForEach-Object { $_.Cells['Id'].Value }
        $Operation = $Operation -replace 'All', ''
    } else {
        $selectedRows = @($script:Refs.Grid.SelectedRows)
        if ($selectedRows.Count -gt 0) {
            $targetVMIds = $selectedRows | ForEach-Object { $_.Cells['Id'].Value }
        }
    }

    if ($targetVMIds.Count -gt 0) {
        # Get confirmation unless forced
        $shouldProceed = $Force
        if (-not $Force) {
            $confirmMessage = switch ($Operation) {
                'On'     { "Power ON selected VMs?" }
                'Off'    { "Power OFF selected VMs?" }
                'Restart'{ "RESTART selected VMs?" }
            }

            $dialogResult = [System.Windows.Forms.MessageBox]::Show(
                $confirmMessage,
                "Confirm",
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Question
            )

            $shouldProceed = ($dialogResult -eq [System.Windows.Forms.DialogResult]::Yes)
        }

        if ($shouldProceed) {
            Set-StatusMessage -Message "Performing $Operation operation..." -Type Info

            # Execute operation using VM IDs
            foreach ($vmId in $targetVMIds) {
                try {
                    $vm = Get-VM -Id $vmId -Server $script:Connection -ErrorAction Stop
                    if ($vm) {
                        switch ($Operation) {
                            'On'     { $vm | Start-VM -Confirm:$false -ErrorAction SilentlyContinue }
                            'Off'    { $vm | Stop-VM -Confirm:$false -Kill:$true -ErrorAction SilentlyContinue }
                            'Restart' { $vm | Restart-VM -Confirm:$false -Kill:$true -ErrorAction SilentlyContinue }
                        }
                        $successCount++
                    }
                } catch {
                    Write-Verbose ("Failed to {0} VM ID {1}: {2}" -f $Operation, $vmId, $_)
                }
            }
            
            
            # Simulate clicking the Refresh button to reload data and update status
            $script:Refs.RefreshButton.PerformClick()
            Set-StatusMessage -Message "Completed $Operation operation on $successCount of $($targetVMIds.Count) VMs" -Type Success
            $result = $true
        } else {
            Set-StatusMessage -Message "Operation cancelled" -Type Info
        }
    } else {
        $message = if ($targetVMIds.Count -eq 0) { "No VMs to operate on" } else { "No VMs selected" }
        Set-StatusMessage -Message $message -Type Warning
    }

    
    $script:Form.Cursor = [System.Windows.Forms.Cursors]::Default

    return $result
}

function Wire-UIEvents {
    <#
    .SYNOPSIS
        Hooks up all UI events with properly captured Refs.
    #>

    # Search button click event
    $script:Refs.SearchButton.Add_Click({
        param($sender, $e)
        . $PSScriptRoot\VMsView.ps1
        Apply-Filter -Sender $sender -EventArgs $e
    })

    # Search box key down event (Enter key)
    $script:Refs.SearchBox.Add_KeyDown({
        param($sender, $e)
        if ($e.KeyCode -eq 'Enter') {
            . $PSScriptRoot\VMsView.ps1
            Apply-Filter -Sender $sender -EventArgs $e
        }
    })

    $script:Refs.ClearButton.Add_Click({
        $script:Refs.SearchBox.Text = ''
        . $PSScriptRoot\VMsView.ps1
        Apply-Filter -Sender $script:Refs.SearchBox -EventArgs $null
    })


    # Refresh button click event
    $script:Refs.RefreshButton.Add_Click({
        . $PSScriptRoot\VMsView.ps1
        Show-VMsView -ContentPanel $script:Refs.ContentPanel
    })

    # Power operation buttons
    $script:Refs.Buttons.PowerOn.Add_Click({
        . $PSScriptRoot\VMsView.ps1
        Invoke-PowerOperation -Operation 'On'
    })

    $script:Refs.Buttons.PowerOff.Add_Click({
        . $PSScriptRoot\VMsView.ps1
        Invoke-PowerOperation -Operation 'Off'
    })

    $script:Refs.Buttons.PowerAllOn.Add_Click({
        . $PSScriptRoot\VMsView.ps1
        Invoke-PowerOperation -Operation 'AllOn'
    })

    $script:Refs.Buttons.PowerAllOff.Add_Click({
        . $PSScriptRoot\VMsView.ps1
        Invoke-PowerOperation -Operation 'AllOff'
    })

    $script:Refs.Buttons.Restart.Add_Click({
        . $PSScriptRoot\VMsView.ps1
        Invoke-PowerOperation -Operation 'Restart'
    })
}