# ---------------------------------------------------------------------------
# Load WinForms assemblies
# ---------------------------------------------------------------------------
Add-Type -AssemblyName 'System.Windows.Forms'
Add-Type -AssemblyName 'System.Drawing'



function Show-VMsView {
<#
.SYNOPSIS
    Renders the “Virtual Machines” view into the supplied WinForms panel.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Forms.Panel] $ContentPanel
    )

    try {
        # 1 ─ Build UI and retrieve control references -----------------------------
        $uiRefs = New-VMsLayout -ContentPanel $ContentPanel

        # 2 ─ Collect VM data ------------------------------------------------------
        $data = Get-VMsData

        # 3 ─ Always add OriginalData property so the filter can access it ---------
        Add-Member -InputObject $uiRefs -MemberType NoteProperty `
                   -Name 'OriginalData' -Value $data -Force

        # 4 ─ Populate grid (may be empty when disconnected) -----------------------
        if ($data) {
            Update-VMsWithData -UiRefs $uiRefs -Data $data
        }
        else {
            $uiRefs.StatusLabel.Text      = 'No connection to vSphere'
            $uiRefs.StatusLabel.ForeColor = $script:Theme.Error
            $uiRefs.Grid.Rows.Clear()
        }

        # 5 ─ Wire up filter behaviour (SEARCH click + Enter key) ------------------
        Register-VMsFilter -UiRefs $uiRefs
    }
    catch {
        Write-Verbose "VMs view initialisation failed: $_"
    }
}





function New-VMsLayout {
<#
.SYNOPSIS
    Builds the WinForms layout and returns references to key controls.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Forms.Panel] $ContentPanel
    )

    try {
        $ContentPanel.SuspendLayout()
        $ContentPanel.Controls.Clear()
        $ContentPanel.BackColor = $script:Theme.LightGray

        # ----- Root TableLayoutPanel ---------------------------------------------
        $root              = New-Object System.Windows.Forms.TableLayoutPanel
        $root.Dock         = 'Fill'
        $root.ColumnCount  = 1
        $root.RowCount     = 5
        $root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
        $root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
        $root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent,100)))
        $root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
        $root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
        $ContentPanel.Controls.Add($root)

        # ----- Header ------------------------------------------------------------
        $header            = New-Object System.Windows.Forms.Panel
        $header.Dock       = 'Fill'
        $header.Height     = 60
        $header.BackColor  = $script:Theme.Primary
        $root.Controls.Add($header, 0, 0)

        $titleLabel                 = New-Object System.Windows.Forms.Label
        $titleLabel.Text            = 'VIRTUAL MACHINES'
        $titleLabel.Font            = New-Object System.Drawing.Font('Segoe UI',18,[System.Drawing.FontStyle]::Bold)
        $titleLabel.ForeColor       = $script:Theme.White
        $titleLabel.Location        = New-Object System.Drawing.Point(20,15)
        $titleLabel.AutoSize        = $true
        $header.Controls.Add($titleLabel)

        # ----- Filter bar --------------------------------------------------------
        $filterPanel                = New-Object System.Windows.Forms.Panel
        $filterPanel.Dock           = 'Fill'
        $filterPanel.Height         = 50
        $filterPanel.BackColor      = $script:Theme.LightGray
        $root.Controls.Add($filterPanel, 0, 1)

        $searchBox                  = New-Object System.Windows.Forms.TextBox
        $searchBox.Name             = 'txtFilter'
        $searchBox.Width            = 300
        $searchBox.Height           = 30
        $searchBox.Location         = New-Object System.Drawing.Point(20,10)
        $searchBox.Font             = New-Object System.Drawing.Font('Segoe UI',10)
        $searchBox.BackColor        = $script:Theme.White
        $searchBox.ForeColor        = $script:Theme.PrimaryDarker
        $filterPanel.Controls.Add($searchBox)

        $searchBtn                  = New-Object System.Windows.Forms.Button
        $searchBtn.Name             = 'btnSearch'
        $searchBtn.Text             = 'SEARCH'
        $searchBtn.Size             = New-Object System.Drawing.Size(100,30)
        $searchBtn.Location         = New-Object System.Drawing.Point(330,10)
        $searchBtn.Font             = New-Object System.Drawing.Font('Segoe UI',10,[System.Drawing.FontStyle]::Bold)
        $searchBtn.BackColor        = $script:Theme.Primary
        $searchBtn.ForeColor        = $script:Theme.White
        $filterPanel.Controls.Add($searchBtn)

        # ----- Grid container ----------------------------------------------------
        $gridContainer              = New-Object System.Windows.Forms.Panel
        $gridContainer.Dock         = 'Fill'
        $gridContainer.AutoScroll   = $true
        $gridContainer.Padding      = New-Object System.Windows.Forms.Padding(10)
        $gridContainer.BackColor    = $script:Theme.White
        $root.Controls.Add($gridContainer, 0, 2)

        # ----- DataGridView ------------------------------------------------------
        $grid                       = New-Object System.Windows.Forms.DataGridView
        $grid.Name                  = 'gvVMs'
        $grid.Dock                  = 'Fill'
        $grid.AutoSizeColumnsMode   = 'Fill'
        $grid.ReadOnly              = $true
        $grid.AllowUserToAddRows    = $false
        $grid.SelectionMode         = 'FullRowSelect'
        $grid.MultiSelect           = $false
        $grid.AutoGenerateColumns   = $false
        $grid.BackgroundColor       = $script:Theme.White
        $grid.BorderStyle           = 'FixedSingle'
        $grid.ColumnHeadersDefaultCellStyle.Font =
            New-Object System.Drawing.Font('Segoe UI',10,[System.Drawing.FontStyle]::Bold)
        $gridContainer.Controls.Add($grid)

        # ----- Numbering column (#) ---------------------------------------------
        $numCol                     = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
        $numCol.Name                = 'No'
        $numCol.HeaderText          = '#'
        $numCol.Width               = 50
        $numCol.ReadOnly            = $true
        $numCol.SortMode            = 'NotSortable'
        $grid.Columns.Add($numCol) | Out-Null

        # ----- Explicit VM columns ----------------------------------------------
        $columns = @(
            @{ Name='Name'      ; Header='VM Name'     },
            @{ Name='PowerState'; Header='Status'      },
            @{ Name='IP'        ; Header='IP Address'  },
            @{ Name='CPU'       ; Header='vCPU'        },
            @{ Name='MemoryGB'  ; Header='Memory (GB)' }
        )

        foreach ($col in $columns) {
            $gridCol                       = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
            $gridCol.Name                  = $col.Name
            $gridCol.HeaderText            = $col.Header
            $gridCol.DataPropertyName      = $col.Name
            $gridCol.ReadOnly              = $true
            $grid.Columns.Add($gridCol) | Out-Null
        }

        # ----- Action buttons ----------------------------------------------------
        $actions                    = New-Object System.Windows.Forms.FlowLayoutPanel
        $actions.Dock               = 'Fill'
        $actions.Height             = 50
        $actions.FlowDirection      = 'LeftToRight'
        $actions.BackColor          = $script:Theme.LightGray
        $actions.Padding            = New-Object System.Windows.Forms.Padding(10,5,10,5)
        $root.Controls.Add($actions, 0, 3)

        $actionDefs = @(
            @{ Key='Refresh' ; Text='REFRESH'  },
            @{ Key='PowerOn' ; Text='POWER ON' },
            @{ Key='PowerOff'; Text='POWER OFF'},
            @{ Key='Restart' ; Text='RESTART'  }
        )

        $btns = @{}
        foreach ($def in $actionDefs) {
            $b                     = New-Object System.Windows.Forms.Button
            $b.Name                = "btn$($def.Key)"
            $b.Text                = $def.Text
            $b.Size                = New-Object System.Drawing.Size(120,35)
            $b.Margin              = New-Object System.Windows.Forms.Padding(5)
            $b.Font                = New-Object System.Drawing.Font('Segoe UI',10,[System.Drawing.FontStyle]::Bold)
            $b.BackColor           = $script:Theme.Primary
            $b.ForeColor           = $script:Theme.White
            $actions.Controls.Add($b)
            $btns[$def.Key]        = $b
        }

        # ----- Footer status label ----------------------------------------------
        $statusLabel                = New-Object System.Windows.Forms.Label
        $statusLabel.Name           = 'StatusLabel'
        $statusLabel.Text           = 'DISCONNECTED'
        $statusLabel.AutoSize       = $true
        $statusLabel.Font           = New-Object System.Drawing.Font('Segoe UI',9)
        $statusLabel.ForeColor      = $script:Theme.PrimaryDarker
        $root.Controls.Add($statusLabel, 0, 4)

        # ----- Return handles ----------------------------------------------------
        return [PSCustomObject]@{
            Grid         = $grid
            SearchBox    = $searchBox
            SearchButton = $searchBtn
            StatusLabel  = $statusLabel
            Buttons      = $btns
        }
    }
    finally {
        $ContentPanel.ResumeLayout($true)
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

    if (-not $script:Connection) { return $null }

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
        return $vms
    }
    catch {
        Write-Verbose "Failed to acquire VM data: $_"
        return $null
    }
}





function Update-VMsWithData {
<#
.SYNOPSIS
    Populates the grid in un-bound mode using the supplied VM list.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [psobject]   $UiRefs,
        [Parameter(Mandatory)] [psobject[]] $Data
    )

    try {
        # Clear previous rows
        $UiRefs.Grid.Rows.Clear()

        # Insert one row per VM
        foreach ($vm in $Data) {
            $rowIndex = $UiRefs.Grid.Rows.Add()
            $row      = $UiRefs.Grid.Rows[$rowIndex]

            $row.Cells['No'        ].Value = $rowIndex + 1
            $row.Cells['Name'      ].Value = $vm.Name
            $row.Cells['PowerState'].Value = $vm.PowerState
            $row.Cells['IP'        ].Value = $vm.IP
            $row.Cells['CPU'       ].Value = $vm.CPU
            $row.Cells['MemoryGB'  ].Value = $vm.MemoryGB

            if ($vm.PowerState -eq 'PoweredOn') {
                $row.Cells['PowerState'].Style.ForeColor = [System.Drawing.Color]::Green
            }
            else {
                $row.Cells['PowerState'].Style.ForeColor = [System.Drawing.Color]::Red
            }
        }

        # Update footer
        $UiRefs.StatusLabel.Text      = "$($Data.Count) VMs found"
        $UiRefs.StatusLabel.ForeColor = $script:Theme.Success

        # Resize columns for readability
        $UiRefs.Grid.AutoResizeColumns()
    }
    catch {
        Write-Verbose "Grid update failed: $_"
        $UiRefs.StatusLabel.Text      = 'Error displaying VM data'
        $UiRefs.StatusLabel.ForeColor = $script:Theme.Error
    }
}





function Register-VMsFilter {
<#
.SYNOPSIS
    Hooks up SEARCH button and Enter key so the user can filter the grid.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject] $UiRefs
    )

    # --- Local helper: performs the actual filter -------------------------------
    $filterAction = {
        try {
            $needle = $UiRefs.SearchBox.Text.Trim()

            # No filter text → show all
            if ([string]::IsNullOrWhiteSpace($needle)) {
                $filtered = $UiRefs.OriginalData
            }
            else {
                $filtered = @()

                foreach ($vm in $UiRefs.OriginalData) {
                    $nameMatch  = $vm.Name       -like "*$needle*"
                    $ipMatch    = $vm.IP         -like "*$needle*"
                    $stateMatch = $vm.PowerState -like "*$needle*"

                    if ($nameMatch -or $ipMatch -or $stateMatch) {
                        $filtered += $vm
                    }
                }
            }

            Update-VMsWithData -UiRefs $UiRefs -Data $filtered
        }
        catch {
            Write-Verbose "Filter error: $_"
        }
    }

    # --- SEARCH button click -----------------------------------------------------
    $null = $UiRefs.SearchButton.Add_Click($filterAction)

    # --- Enter key inside the search box ----------------------------------------
    $null = $UiRefs.SearchBox.Add_KeyDown({
        param($sender,$args)
        if ($args.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
            $UiRefs.SearchButton.PerformClick()
            $args.Handled        = $true
            $args.SuppressKeyPress= $true
        }
    })
}