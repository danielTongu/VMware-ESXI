<#
.SYNOPSIS
    UI view for finding and cleaning orphaned VM files on a datastore.
.DESCRIPTION
    Provides a PowerShell Forms interface to:
      - Select a datastore
      - Discover orphaned VM files via OrphanCleaner.FindOrphanedFiles()
      - Display orphan list in a DataGridView
      - Remove selected orphan files using Remove-DatastoreFile
    Honors global login and offline state; no-ops when disconnected.
.PARAMETER ContentPanel
    The Panel control in which to render this view.
#>
function Show-OrphanCleanerView {
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.Forms.Panel]$ContentPanel
    )

    # Clear existing content
    $ContentPanel.Controls.Clear()

    # Table layout: controls row + grid row
    $layout = New-Object System.Windows.Forms.TableLayoutPanel
    $layout.Dock      = 'Fill'
    $layout.RowCount  = 2
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'absolute', 50))
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'Absolute', 50))
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'Percent', 100))
    $ContentPanel.Controls.Add($layout)

    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Text = 'Orphaned VM Files'
    $lblTitle.Font = New-Object System.Drawing.Font('Segoe UI', 18, [System.Drawing.FontStyle]::Bold)
    $lblTitle.ForeColor = [System.Drawing.Color]::DarkSlateBlue
    $lblTitle.AutoSize = $true
    $layout.Controls.Add($lblTitle, 0, 0)

    # ---- Controls Row ----
    $controlsPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $controlsPanel.Dock          = 'Fill'
    $controlsPanel.FlowDirection = 'LeftToRight'
    $controlsPanel.WrapContents  = $false
    $controlsPanel.Padding       = '10,5,10,5'
    $layout.Controls.Add($controlsPanel, 0, 1)

    # Datastore label
    $lblDatastore = New-Object System.Windows.Forms.Label
    $lblDatastore.Text  = 'Datastore:'
    $lblDatastore.AutoSize = $true
    $lblDatastore.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Regular)
    $lblDatastore.TextAlign = 'MiddleLeft'
    $controlsPanel.Controls.Add($lblDatastore)

    # Datastore dropdown
    $comboDatastores = New-Object System.Windows.Forms.ComboBox
    $comboDatastores.DropDownStyle = 'DropDownList'
    $comboDatastores.Width         = 200
    $comboDatastores.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Regular)
    $controlsPanel.Controls.Add($comboDatastores)

    # Refresh button
    $btnRefresh = New-Object System.Windows.Forms.Button
    $btnRefresh.Text      = 'Refresh'
    $btnRefresh.AutoSize  = $true
    $btnRefresh.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Regular)
    $controlsPanel.Controls.Add($btnRefresh)

    # Clean button
    $btnClean = New-Object System.Windows.Forms.Button
    $btnClean.Text      = 'Delete Selected'
    $btnClean.AutoSize  = $true
    $btnClean.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Regular)
    $controlsPanel.Controls.Add($btnClean)

    # ---- Data Grid Row ----
    $grid = New-Object System.Windows.Forms.DataGridView
    $grid.Dock               = 'Fill'
    $grid.ReadOnly           = $true
    $grid.SelectionMode      = 'FullRowSelect'
    $grid.MultiSelect        = $true
    $grid.AutoSizeColumnsMode= 'Fill'
    $layout.Controls.Add($grid, 0, 2)

    # Populate datastores list
    try {
        $connection = [OrphanCleaner]::GetConnectionSafe()
        if ($null -ne $connection) {
            $allDS = Get-Datastore -Server $connection | Select-Object -ExpandProperty Name
            $comboDatastores.Items.AddRange($allDS)
            if ($comboDatastores.Items.Count -gt 0) {
                $comboDatastores.SelectedIndex = 0
            }
        }
    }
    catch {
        Write-Warning "Failed to list datastores: $_"
    }

    <#
    .SYNOPSIS
        Loads and displays orphan files in the grid.
    #>
    function Load-Orphans {
        $grid.Rows.Clear()
        $selectedDS = $comboDatastores.SelectedItem
        if ([string]::IsNullOrEmpty($selectedDS)) { return }

        $orphans = [OrphanCleaner]::FindOrphanedFiles($selectedDS)
        foreach ($file in $orphans) {
            $index = $grid.Rows.Add()
            $row   = $grid.Rows[$index]
            $row.Cells.Add((New-Object System.Windows.Forms.DataGridViewTextBoxCell -Property @{ Value = $file.Path })) | Out-Null
            $row.Cells.Add((New-Object System.Windows.Forms.DataGridViewTextBoxCell -Property @{ Value = $file.Size })) | Out-Null
            $row.Cells.Add((New-Object System.Windows.Forms.DataGridViewTextBoxCell -Property @{ Value = $file.Type })) | Out-Null
        }
        # Add column headers if first load
        if ($grid.ColumnCount -eq 0 -and $orphans.Count -gt 0) {
            $grid.Columns.Clear()
            $grid.Columns.Add('Path','Path') > $null
            $grid.Columns.Add('Size','Size') > $null
            $grid.Columns.Add('Type','Type') > $null
        }
    }

    <#
    .SYNOPSIS
        Deletes selected orphan files from the datastore.
    #>
    function Delete-Selected {
        $selectedDS = $comboDatastores.SelectedItem
        if ([string]::IsNullOrEmpty($selectedDS)) { return }

        $conn   = [OrphanCleaner]::GetConnectionSafe()
        $dsObj  = Get-Datastore -Name $selectedDS -Server $conn -ErrorAction Stop
        $toRemove = $grid.SelectedRows | ForEach-Object { $_.Cells['Path'].Value }
        foreach ($path in $toRemove) {
            try {
                Remove-DatastoreFile -Datastore $dsObj -Path $path -Confirm:$false -ErrorAction Stop
            }
            catch {
                Write-Warning "Failed to delete '$path': $_"
            }
        }
        # Refresh view
        Load-Orphans
    }

    # Event handlers
    $btnRefresh.Add_Click({ Load-Orphans })
    $btnClean.Add_Click({ Delete-Selected })

    # Initial load
    Load-Orphans
}
