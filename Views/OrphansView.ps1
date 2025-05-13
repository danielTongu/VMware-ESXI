# Required assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing



<#
    .SYNOPSIS
        Displays the Orphans view in the UI.
    .DESCRIPTION
        Initializes the Orphans view layout and populates it with data.
    .PARAMETER ContentPanel
        The Windows.Forms.Panel where this view is rendered.
#>
function Show-OrphansView {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Forms.Panel]$ContentPanel
    )

    try {
        # Build UI skeleton
        $uiRefs = New-OrphanCleanerLayout -ContentPanel $ContentPanel

        # Populate data if connected
        $data = Get-OrphanCleanerData
        if ($data) {
            Update-OrphanCleanerWithData -UiRefs $uiRefs -Data $data
        } else {
            # Show disconnected message
            $lblMessage = [System.Windows.Forms.Label]::new()
            $lblMessage.Text = 'Not connected to a server.'
            $lblMessage.Font = [System.Drawing.Font]::new('Segoe UI', 12, [System.Drawing.FontStyle]::Bold)
            $lblMessage.ForeColor = $global:Theme.Error
            $lblMessage.Location = [System.Drawing.Point]::new(20, 20)
            $lblMessage.AutoSize = $true

            $ContentPanel.Controls.Add($lblMessage)
        }
    } catch {
        Write-Verbose "Orphan cleaner initialization failed: $_"
    }
}



<#
    .SYNOPSIS
        Creates the layout for the Orphan Cleaner view.
    .DESCRIPTION
        Builds the UI skeleton with header, filters, data grid, and controls.
    .PARAMETER ContentPanel
        The Windows.Forms.Panel to populate.
    .OUTPUTS
        Hashtable of UI element references.
#>
function New-OrphanCleanerLayout {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Forms.Panel]$ContentPanel
    )

    try {
        $ContentPanel.SuspendLayout()
        $ContentPanel.Controls.Clear()
        $ContentPanel.BackColor = $global:Theme.LightGray

        # Root layout
        $root = [System.Windows.Forms.TableLayoutPanel]::new()
        $root.Dock = 'Fill'
        $root.ColumnCount = 1
        $root.RowCount = 4
        $root.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::AutoSize))   # Header
        $root.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::AutoSize))   # Filter
        $root.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Percent,100)) # Grid
        $root.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::AutoSize))   # Controls
        
        $ContentPanel.Controls.Add($root)

        # Header
        $header = [System.Windows.Forms.Panel]::new()
        $header.Dock = 'Fill'; 
        $header.Height = 60
        $header.BackColor = $global:Theme.Primary
        
        $root.Controls.Add($header, 0, 0)

        $titleLabel = [System.Windows.Forms.Label]::new()
        $titleLabel.Text = 'ORPHANED VM FILES'
        $titleLabel.Font = [System.Drawing.Font]::new('Segoe UI', 18, [System.Drawing.FontStyle]::Bold)
        $titleLabel.ForeColor = $global:Theme.White
        $titleLabel.Location = [System.Drawing.Point]::new(20,15)
        $titleLabel.AutoSize = $true
        
        $header.Controls.Add($titleLabel)

        # Filter row
        $filterPanel = [System.Windows.Forms.Panel]::new()
        $filterPanel.Dock = 'Fill'; 
        $filterPanel.Height = 50
        $filterPanel.BackColor = $global:Theme.LightGray
        
        $root.Controls.Add($filterPanel, 0, 1)

        # Datastore label
        $lblDatastore = [System.Windows.Forms.Label]::new()
        $lblDatastore.Text = 'Datastore:'
        $lblDatastore.Font = [System.Drawing.Font]::new('Segoe UI',10)
        $lblDatastore.ForeColor = $global:Theme.PrimaryDarker
        $lblDatastore.Location = [System.Drawing.Point]::new(20,15)
        $lblDatastore.AutoSize = $true

        $filterPanel.Controls.Add($lblDatastore)

        # Datastore dropdown
        $cmbDatastores = [System.Windows.Forms.ComboBox]::new()
        $cmbDatastores.DropDownStyle = 'DropDownList'
        $cmbDatastores.Width = 250
        $cmbDatastores.Font = [System.Drawing.Font]::new('Segoe UI',10)
        $cmbDatastores.Location = [System.Drawing.Point]::new(100,10)
        $cmbDatastores.BackColor = $global:Theme.White
        $cmbDatastores.ForeColor = $global:Theme.PrimaryDark

        $filterPanel.Controls.Add($cmbDatastores)

        # Search field
        $txtSearch = [System.Windows.Forms.TextBox]::new()
        $txtSearch.Width = 200; 
        $txtSearch.Height = 30
        $txtSearch.Location = [System.Drawing.Point]::new(370,10)
        $txtSearch.Font = [System.Drawing.Font]::new('Segoe UI',10)
        $txtSearch.BackColor = $global:Theme.White
        $txtSearch.ForeColor = $global:Theme.PrimaryDarker

        $filterPanel.Controls.Add($txtSearch)

        # Search button
        $btnSearch = [System.Windows.Forms.Button]::new()
        $btnSearch.Text = 'SEARCH'; 
        $btnSearch.Width = 100; 
        $btnSearch.Height = 30
        $btnSearch.Location = [System.Drawing.Point]::new(580,10)
        $btnSearch.Font = [System.Drawing.Font]::new('Segoe UI',10,[System.Drawing.FontStyle]::Bold)
        $btnSearch.BackColor = $global:Theme.Primary
        $btnSearch.ForeColor = $global:Theme.White

        $filterPanel.Controls.Add($btnSearch)

        # Data grid
        $grid = [System.Windows.Forms.DataGridView]::new()
        $grid.Name = 'gvOrphans'; 
        $grid.Dock = 'Fill'
        $grid.ReadOnly = $true;
        $grid.SelectionMode = 'FullRowSelect'; 
        $grid.MultiSelect = $true
        $grid.AutoSizeColumnsMode = 'Fill'
        $grid.BackgroundColor = $global:Theme.White
        $grid.GridColor = $global:Theme.PrimaryDark
        $grid.BorderStyle = 'FixedSingle'
        $grid.DefaultCellStyle.Font = [System.Drawing.Font]::new('Segoe UI',10)
        $grid.DefaultCellStyle.ForeColor = $global:Theme.PrimaryDarker
        $grid.ColumnHeadersDefaultCellStyle.Font = [System.Drawing.Font]::new('Segoe UI',10,[System.Drawing.FontStyle]::Bold)
        $grid.ColumnHeadersDefaultCellStyle.ForeColor = $global:Theme.PrimaryDarker
        $grid.ColumnHeadersDefaultCellStyle.BackColor = $global:Theme.LightGray

        $root.Controls.Add($grid, 0, 2)

        # Controls footer
        $controlsPanel = [System.Windows.Forms.FlowLayoutPanel]::new()
        $controlsPanel.Dock = 'Fill'; 
        $controlsPanel.Height = 50
        $controlsPanel.FlowDirection = 'LeftToRight'
        $controlsPanel.Padding = [System.Windows.Forms.Padding]::new(10)
        $controlsPanel.BackColor = $global:Theme.LightGray

        $root.Controls.Add($controlsPanel, 0, 3)

        # Refresh button
        $btnRefresh = [System.Windows.Forms.Button]::new()
        $btnRefresh.Text = 'REFRESH'; 
        $btnRefresh.Width = 120;
        $btnRefresh.Height = 35
        $btnRefresh.Font = [System.Drawing.Font]::new('Segoe UI',10,[System.Drawing.FontStyle]::Bold)
        $btnRefresh.BackColor = $global:Theme.Primary
        $btnRefresh.ForeColor = $global:Theme.White

        $controlsPanel.Controls.Add($btnRefresh)

        # Delete button
        $btnDelete = [System.Windows.Forms.Button]::new()
        $btnDelete.Text = 'DELETE SELECTED';
        $btnDelete.Width = 150;
        $btnDelete.Height = 35
        $btnDelete.Font = [System.Drawing.Font]::new('Segoe UI',10,[System.Drawing.FontStyle]::Bold)
        $btnDelete.BackColor = $global:Theme.Error
        $btnDelete.ForeColor = $global:Theme.White

        $controlsPanel.Controls.Add($btnDelete)

        # Return refs
        return @{
            DatastoreCombo = $cmbDatastores
            SearchBox      = $txtSearch
            SearchButton   = $btnSearch
            OrphansGrid    = $grid
            RefreshButton  = $btnRefresh
            DeleteButton   = $btnDelete
        }
    }
    finally {
        $ContentPanel.ResumeLayout($true)
    }
}



<#
    .SYNOPSIS
        Retrieves available datastores from vSphere.
    .DESCRIPTION
        Returns the list of datastore names and timestamp, or $null if disconnected.
    .OUTPUTS
        Hashtable with Datastores and LastUpdated.
#>
function Get-OrphanCleanerData {
    [CmdletBinding()]
    param()

    try {
        $conn = [VMServerConnection]::GetInstance().GetConnection()
        if (-not $conn) { return $null }
        return @{
            Datastores  = Get-Datastore -Server $conn | Select-Object -ExpandProperty Name
            LastUpdated = Get-Date
        }
    } catch {
        Write-Verbose "Failed to load datastores: $_"
        return $null
    }
}



<#
    .SYNOPSIS
        Updates the Orphan Cleaner view with retrieved data.
    .DESCRIPTION
        Populates dropdown, grid columns, and wires event handlers for refresh, delete, and search.
    .PARAMETER UiRefs
        Hashtable of UI element references.
    .PARAMETER Data
        Hashtable containing datastores and timestamp.
#>
function Update-OrphanCleanerWithData {
    [CmdletBinding()]
    param(
        [hashtable]$UiRefs,
        [hashtable]$Data
    )

    try {
        # Populate dropdown
        $UiRefs.DatastoreCombo.Items.Clear()
        if ($Data.Datastores) {
            $UiRefs.DatastoreCombo.Items.AddRange($Data.Datastores)
            $UiRefs.DatastoreCombo.SelectedIndex = 0
        }

        # Configure grid
        $UiRefs.OrphansGrid.Columns.Clear()
        $UiRefs.OrphansGrid.Columns.Add('Path','Path') | Out-Null
        $UiRefs.OrphansGrid.Columns.Add('Size','Size') | Out-Null
        $UiRefs.OrphansGrid.Columns.Add('Type','Type') | Out-Null

        # Refresh event
        $UiRefs.RefreshButton.Add_Click({
            try {
                $ds = $UiRefs.DatastoreCombo.SelectedItem
                if (-not $ds) { return }

                $orphans = [OrphanCleaner]::FindOrphanedFiles($ds)
                $UiRefs.OrphansGrid.Rows.Clear()

                foreach ($file in $orphans) {
                    $idx = $UiRefs.OrphansGrid.Rows.Add()
                    $row = $UiRefs.OrphansGrid.Rows[$idx]
                    $row.Cells['Path'].Value = $file.Path
                    $row.Cells['Size'].Value = $file.Size
                    $row.Cells['Type'].Value = $file.Type
                }
            } catch {
                Write-Verbose "Failed to refresh orphans: $_"
            }
        })

        # Delete event
        $UiRefs.DeleteButton.Add_Click({
            try {
                $ds = $UiRefs.DatastoreCombo.SelectedItem
                if (-not $ds) { return }

                $conn = [VMServerConnection]::GetInstance().GetConnection()
                if (-not $conn) { return }

                $dsObj = Get-Datastore -Name $ds -Server $conn -ErrorAction Stop

                foreach ($sel in $UiRefs.OrphansGrid.SelectedRows) {
                    $path = $sel.Cells['Path'].Value
                    try { Remove-DatastoreFile -Datastore $dsObj -Path $path -Confirm:$false -ErrorAction Stop } catch { }
                }
                $UiRefs.RefreshButton.PerformClick()
            } catch {
                Write-Verbose "Failed to delete selected files: $_"
            }
        })

        # Search event
        $UiRefs.SearchButton.Add_Click({
            $filter = $UiRefs.SearchBox.Text.Trim()

            foreach ($row in $UiRefs.OrphansGrid.Rows) {
                if (-not [string]::IsNullOrEmpty($filter) -and $row.Cells['Path'].Value -notmatch $filter) {
                    $row.Visible = $false
                }else {
                    $row.Visible = $true
                }
            }
        })
        $UiRefs.SearchBox.Add_KeyDown({ 
            if ($_.KeyCode -eq [System.Windows.Forms.Keys]::Enter) { 
                $UiRefs.SearchButton.PerformClick(); $_.SuppressKeyPress = $true 
            } 
        })
    } catch {
        Write-Verbose "Failed to update orphan cleaner view: $_"
    }
}
