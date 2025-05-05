Add-Type -AssemblyName 'System.Windows.Forms'
Add-Type -AssemblyName 'System.Drawing'

<##
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
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [System.Windows.Forms.Panel]$ContentPanel
    )

    # Clear existing content and apply background theme
    $ContentPanel.Controls.Clear()
    $ContentPanel.BackColor = $global:theme.Background

    # Table layout: controls row + grid row
    $layout = New-Object System.Windows.Forms.TableLayoutPanel
    $layout.Dock      = 'Fill'
    $layout.BackColor = $global:theme.Background
    $layout.RowCount  = 3
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute,50)))
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute,50)))
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent,100)))
    $ContentPanel.Controls.Add($layout)

    # Title label (font size 11 per guidelines)
    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Text      = 'Orphaned VM Files'
    $lblTitle.Font      = New-Object System.Drawing.Font('Segoe UI',11,[System.Drawing.FontStyle]::Bold)
    $lblTitle.ForeColor = $global:theme.Primary
    $lblTitle.AutoSize  = $true
    $lblTitle.BackColor = $global:theme.Background
    $layout.Controls.Add($lblTitle,0,0)

    # ---- Controls Row ----
    $controlsPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $controlsPanel.Dock          = 'Fill'
    $controlsPanel.FlowDirection = 'LeftToRight'
    $controlsPanel.WrapContents  = $false
    $controlsPanel.Padding       = '10,5,10,5'
    $controlsPanel.BackColor     = $global:theme.Background
    $layout.Controls.Add($controlsPanel,0,1)

    # Datastore label (font size 10)
    $lblDatastore = New-Object System.Windows.Forms.Label
    $lblDatastore.Text      = 'Datastore:'
    $lblDatastore.Font      = New-Object System.Drawing.Font('Segoe UI',10,[System.Drawing.FontStyle]::Regular)
    $lblDatastore.ForeColor = $global:theme.TextPrimary
    $lblDatastore.AutoSize  = $true
    $controlsPanel.Controls.Add($lblDatastore)

    # Datastore dropdown (font size 10)
    $comboDatastores = New-Object System.Windows.Forms.ComboBox
    $comboDatastores.DropDownStyle = 'DropDownList'
    $comboDatastores.Width         = 200
    $comboDatastores.Font          = New-Object System.Drawing.Font('Segoe UI',10,[System.Drawing.FontStyle]::Regular)
    $comboDatastores.BackColor     = $global:theme.CardBackground
    $comboDatastores.ForeColor     = $global:theme.TextPrimary
    $controlsPanel.Controls.Add($comboDatastores)

    # Refresh button (font size 10)
    $btnRefresh = New-Object System.Windows.Forms.Button
    $btnRefresh.Text      = 'Refresh'
    $btnRefresh.Font      = New-Object System.Drawing.Font('Segoe UI',10,[System.Drawing.FontStyle]::Regular)
    $btnRefresh.BackColor = $global:theme.Secondary
    $btnRefresh.ForeColor = $global:theme.CardBackground
    $btnRefresh.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $controlsPanel.Controls.Add($btnRefresh)

    # Delete Selected button (font size 10)
    $btnClean = New-Object System.Windows.Forms.Button
    $btnClean.Text      = 'Delete Selected'
    $btnClean.Font      = New-Object System.Drawing.Font('Segoe UI',10,[System.Drawing.FontStyle]::Regular)
    $btnClean.BackColor = $global:theme.Error
    $btnClean.ForeColor = $global:theme.CardBackground
    $btnClean.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $controlsPanel.Controls.Add($btnClean)

    # ---- Data Grid Row ----
    $grid = New-Object System.Windows.Forms.DataGridView
    $grid.Dock                = 'Fill'
    $grid.ReadOnly            = $true
    $grid.SelectionMode       = 'FullRowSelect'
    $grid.MultiSelect         = $true
    $grid.AutoSizeColumnsMode = 'Fill'
    $grid.BackgroundColor     = $global:theme.CardBackground
    $grid.GridColor           = $global:theme.Border
    $grid.BorderStyle         = 'FixedSingle'
    $grid.DefaultCellStyle.Font = New-Object System.Drawing.Font('Segoe UI',10,[System.Drawing.FontStyle]::Regular)
    $grid.DefaultCellStyle.ForeColor = $global:theme.TextPrimary
    $grid.ColumnHeadersDefaultCellStyle.Font = New-Object System.Drawing.Font('Segoe UI',10,[System.Drawing.FontStyle]::Bold)
    $grid.ColumnHeadersDefaultCellStyle.ForeColor = $global:theme.TextPrimary
    $grid.ColumnHeadersDefaultCellStyle.BackColor  = $global:theme.Background
    $layout.Controls.Add($grid,0,2)

    # Populate datastores list
    try {
        $conn = Get-ConnectionSafe
        if ($null -ne $conn) {
            $allDS = Get-Datastore -Server $conn | Select-Object -ExpandProperty Name
            $comboDatastores.Items.AddRange($allDS)
            if ($comboDatastores.Items.Count -gt 0) {
                $comboDatastores.SelectedIndex = 0
            }
        }
    }
    catch {
        Write-Warning "Failed to list datastores: $_"
    }

    <##
    .SYNOPSIS
        Loads and displays orphan files in the grid.
    #>
    function Load-Orphans {
        $grid.Rows.Clear()
        $selectedDS = $comboDatastores.SelectedItem
        if ([string]::IsNullOrEmpty($selectedDS)) { return }

        $orphans = [OrphanCleaner]::FindOrphanedFiles($selectedDS)
        # Add columns on first load
        if ($grid.ColumnCount -eq 0 -and $orphans.Count -gt 0) {
            $grid.Columns.Clear()
            $grid.Columns.Add('Path','Path') > $null
            $grid.Columns.Add('Size','Size') > $null
            $grid.Columns.Add('Type','Type') > $null
        }
        # Populate rows
        foreach ($file in $orphans) {
            $idx = $grid.Rows.Add()
            $row = $grid.Rows[$idx]
            $row.Cells['Path'].Value = $file.Path
            $row.Cells['Size'].Value = $file.Size
            $row.Cells['Type'].Value = $file.Type
        }
    }

    <##
    .SYNOPSIS
        Deletes selected orphan files from the datastore.
    #>
    function Delete-Selected {
        $selectedDS = $comboDatastores.SelectedItem
        if ([string]::IsNullOrEmpty($selectedDS)) { return }

        $conn  = Get-ConnectionSafe
        $dsObj = Get-Datastore -Name $selectedDS -Server $conn -ErrorAction Stop
        $toRemove = $grid.SelectedRows | ForEach-Object { $_.Cells['Path'].Value }
        foreach ($path in $toRemove) {
            try {
                Remove-DatastoreFile -Datastore $dsObj -Path $path -Confirm:$false -ErrorAction Stop
            } catch {
                Write-Warning "Failed to delete '$path': $_"
            }
        }
        Load-Orphans
    }

    # Event handlers
    $btnRefresh.Add_Click({ Load-Orphans })
    $btnClean.Add_Click({ Delete-Selected })

    # Initial load
    Load-Orphans
}
