Add-Type -AssemblyName 'System.Windows.Forms'
Add-Type -AssemblyName 'System.Drawing'



# ────────────────────────────────────────────────────────────────────────────
#                       Views/OrphansView.ps1
# ────────────────────────────────────────────────────────────────────────────



<#
    .SYNOPSIS
        Displays the Orphan Cleaner view in the UI.

    .DESCRIPTION
        This function initializes the Orphan Cleaner view, populating it with data and setting up event handlers.

    .PARAMETER ContentPanel
        The panel where the Orphan Cleaner view will be displayed.

    .EXAMPLE
        Show-OrphansView -ContentPanel $mainPanel
#>
function Show-OrphansView {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Forms.Panel]$ContentPanel
    )

    try {
        # Build UI (empty)
        $uiRefs = New-OrphanCleanerLayout -ContentPanel $ContentPanel

        # Populate with data if connected
        $data = Get-OrphanCleanerData
        if ($data) {
            Update-OrphanCleanerWithData -UiRefs $uiRefs -Data $data
        } else {
            # show user message if not connected
            $lblMessage = New-Object System.Windows.Forms.Label
            $lblMessage.Text = 'Not connected to a server.'
            $lblMessage.Font = New-Object System.Drawing.Font('Segoe UI', 12, [System.Drawing.FontStyle]::Bold) 
            $lblMessage.ForeColor = [System.Drawing.Color]::Red
            $lblMessage.Location = New-Object System.Drawing.Point(20, 20)
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
        This function sets up the layout for the Orphan Cleaner view, including header, filter controls, data grid, and action buttons.

    .PARAMETER ContentPanel
        The panel where the Orphan Cleaner layout will be created.

    .EXAMPLE
        $layout = New-OrphanCleanerLayout -ContentPanel $mainPanel
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
        $ContentPanel.BackColor = $global:theme.Background

        # ── ROOT LAYOUT ─────────────────────────────────────────────────
        $root = New-Object System.Windows.Forms.TableLayoutPanel
        $root.Dock = 'Fill'
        $root.ColumnCount = 1
        $root.RowCount = 4
        $root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))   # Header
        $root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))   # Filter
        $root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent,100))) # Grid
        $root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))   # Controls
        $ContentPanel.Controls.Add($root)



        #===== Row [1] HEADER ===============================================
        $header = New-Object System.Windows.Forms.Panel
        $header.Dock = 'Fill'
        $header.Height = 60
        $header.BackColor = $global:theme.Primary
        $root.Controls.Add($header, 0, 0)

        $titleLabel = New-Object System.Windows.Forms.Label
        $titleLabel.Text = 'ORPHANED VM FILES'
        $titleLabel.Font = New-Object System.Drawing.Font('Segoe UI', 18, [System.Drawing.FontStyle]::Bold)
        $titleLabel.ForeColor = [System.Drawing.Color]::White
        $titleLabel.Location = New-Object System.Drawing.Point(20, 15)
        $titleLabel.AutoSize = $true
        $header.Controls.Add($titleLabel)



        #===== Row [2] FILTER ===============================================
        $filterPanel = New-Object System.Windows.Forms.Panel
        $filterPanel.Dock = 'Fill'
        $filterPanel.Height = 50
        $filterPanel.BackColor = $global:theme.Background
        $root.Controls.Add($filterPanel, 0, 1)

        # Datastore label
        $lblDatastore = New-Object System.Windows.Forms.Label
        $lblDatastore.Text = 'Datastore:'
        $lblDatastore.Font = New-Object System.Drawing.Font('Segoe UI', 10)
        $lblDatastore.Location = New-Object System.Drawing.Point(20, 15)
        $lblDatastore.AutoSize = $true
        $filterPanel.Controls.Add($lblDatastore)

        # Datastore dropdown
        $cmbDatastores = New-Object System.Windows.Forms.ComboBox
        $cmbDatastores.Name = 'cmbDatastores'
        $cmbDatastores.DropDownStyle = 'DropDownList'
        $cmbDatastores.Width = 250
        $cmbDatastores.Font = New-Object System.Drawing.Font('Segoe UI', 10)
        $cmbDatastores.Location = New-Object System.Drawing.Point(100, 10)
        $cmbDatastores.BackColor = $global:theme.CardBackground
        $filterPanel.Controls.Add($cmbDatastores)

        # Search field
        $txtSearch = New-Object System.Windows.Forms.TextBox
        $txtSearch.Name = 'txtSearch'
        $txtSearch.Width = 200
        $txtSearch.Height = 30
        $txtSearch.Location = New-Object System.Drawing.Point(370, 10)
        $txtSearch.Font = New-Object System.Drawing.Font('Segoe UI', 10)
        $txtSearch.BackColor = $global:theme.CardBackground
        $filterPanel.Controls.Add($txtSearch)

        # Search button
        $btnSearch = New-Object System.Windows.Forms.Button
        $btnSearch.Name = 'btnSearch'
        $btnSearch.Text = "SEARCH"
        $btnSearch.Width = 100
        $btnSearch.Height = 30
        $btnSearch.Location = New-Object System.Drawing.Point(580, 10)
        $btnSearch.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
        $btnSearch.BackColor = $global:theme.Primary
        $btnSearch.ForeColor = [System.Drawing.Color]::White
        $filterPanel.Controls.Add($btnSearch)




        #===== Row [3] DATA GRID ===========================================
        $grid = New-Object System.Windows.Forms.DataGridView
        $grid.Name = 'gvOrphans'
        $grid.Dock = 'Fill'
        $grid.ReadOnly = $true
        $grid.SelectionMode = 'FullRowSelect'
        $grid.MultiSelect = $true
        $grid.AutoSizeColumnsMode = 'Fill'
        $grid.BackgroundColor = $global:theme.CardBackground
        $grid.GridColor = $global:theme.Border
        $grid.BorderStyle = 'FixedSingle'
        $grid.DefaultCellStyle.Font = New-Object System.Drawing.Font('Segoe UI', 10)
        $grid.DefaultCellStyle.ForeColor = $global:theme.TextPrimary
        $grid.ColumnHeadersDefaultCellStyle.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
        $grid.ColumnHeadersDefaultCellStyle.ForeColor = $global:theme.TextPrimary
        $grid.ColumnHeadersDefaultCellStyle.BackColor = $global:theme.Background
        $root.Controls.Add($grid, 0, 2)



        #===== Row [4] CONTROLS ============================================
        $controlsPanel = New-Object System.Windows.Forms.FlowLayoutPanel
        $controlsPanel.Dock = 'Fill'
        $controlsPanel.Height = 50
        $controlsPanel.FlowDirection = 'LeftToRight'
        $controlsPanel.Padding = New-Object System.Windows.Forms.Padding(10)
        $controlsPanel.BackColor = $global:theme.Background
        $root.Controls.Add($controlsPanel, 0, 3)

        # Refresh button
        $btnRefresh = New-Object System.Windows.Forms.Button
        $btnRefresh.Name = 'btnRefresh'
        $btnRefresh.Text = 'REFRESH'
        $btnRefresh.Width = 120
        $btnRefresh.Height = 35
        $btnRefresh.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
        $btnRefresh.BackColor = $global:theme.Secondary
        $btnRefresh.ForeColor = [System.Drawing.Color]::White
        $controlsPanel.Controls.Add($btnRefresh)

        # Delete Selected button
        $btnDelete = New-Object System.Windows.Forms.Button
        $btnDelete.Name = 'btnDelete'
        $btnDelete.Text = 'DELETE SELECTED'
        $btnDelete.Width = 150
        $btnDelete.Height = 35
        $btnDelete.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
        $btnDelete.BackColor = $global:theme.Error
        $btnDelete.ForeColor = [System.Drawing.Color]::White
        $controlsPanel.Controls.Add($btnDelete)

        # Return references to UI elements
        $refs = @{
            DatastoreCombo = $cmbDatastores
            SearchBox = $txtSearch
            SearchButton = $btnSearch
            OrphansGrid = $grid
            RefreshButton = $btnRefresh
            DeleteButton = $btnDelete
        }

        return $refs
    }
    finally {
        $ContentPanel.ResumeLayout($true)
    }
}




<#
    .SYNOPSIS
        Retrieves the list of datastores from the server.

    .DESCRIPTION
        This function connects to the server and retrieves the list of datastores available.

    .EXAMPLE
        $datastoreData = Get-OrphanCleanerData
        # This will return a hashtable with the datastores and the last updated time.
#>
function Get-OrphanCleanerData {
    [CmdletBinding()]
    param()

    try {
        $conn = [VMServerConnection]::GetInstance().GetConnection()
        if (-not $conn) {
            return $null
        }

        return @{
            Datastores = Get-Datastore -Server $conn | Select-Object -ExpandProperty Name
            LastUpdated = (Get-Date)
        }
    }
    catch {
        Write-Verbose "Failed to load datastores: $_"
        return $null
    }
}




<#
    .SYNOPSIS
        Updates the Orphan Cleaner view with data.

    .DESCRIPTION
        This function populates the Orphan Cleaner view with data and sets up event handlers for user interactions.

    .PARAMETER UiRefs
        A hashtable containing references to UI elements.

    .PARAMETER Data
        A hashtable containing the data to be displayed in the Orphan Cleaner view.

    .EXAMPLE
        Update-OrphanCleanerWithData -UiRefs $uiRefs -Data $data
        # This will update the Orphan Cleaner view with the provided data and set up event handlers.
#>
function Update-OrphanCleanerWithData {
    [CmdletBinding()]
    param(
        [hashtable]$UiRefs,
        [hashtable]$Data
    )

    try {
        # Populate datastores dropdown
        $UiRefs.DatastoreCombo.Items.Clear()
        if ($Data.Datastores) {
            $UiRefs.DatastoreCombo.Items.AddRange($Data.Datastores)
            if ($UiRefs.DatastoreCombo.Items.Count -gt 0) {
                $UiRefs.DatastoreCombo.SelectedIndex = 0
            }
        }

        # Configure grid columns
        $UiRefs.OrphansGrid.Columns.Clear()
        $UiRefs.OrphansGrid.Columns.Add('Path','Path') > $null
        $UiRefs.OrphansGrid.Columns.Add('Size','Size') > $null
        $UiRefs.OrphansGrid.Columns.Add('Type','Type') > $null

        # Add event handlers
        $UiRefs.RefreshButton.Add_Click({
            try {
                $selectedDS = $UiRefs.DatastoreCombo.SelectedItem
                if (-not $selectedDS) { return }

                $orphans = [OrphanCleaner]::FindOrphanedFiles($selectedDS)
                $UiRefs.OrphansGrid.Rows.Clear()
                foreach ($file in $orphans) {
                    $idx = $UiRefs.OrphansGrid.Rows.Add()
                    $row = $UiRefs.OrphansGrid.Rows[$idx]
                    $row.Cells['Path'].Value = $file.Path
                    $row.Cells['Size'].Value = $file.Size
                    $row.Cells['Type'].Value = $file.Type
                }
            }
            catch {
                Write-Verbose "Failed to refresh orphans: $_"
            }
        })

        $UiRefs.DeleteButton.Add_Click({
            try {
                $selectedDS = $UiRefs.DatastoreCombo.SelectedItem
                if (-not $selectedDS) { return }

                $conn = [VMServerConnection]::GetInstance().GetConnection()
                if (-not $conn) {
                    Write-Verbose "Not connected - cannot delete files"
                    return
                }

                $dsObj = Get-Datastore -Name $selectedDS -Server $conn -ErrorAction Stop
                $toRemove = $UiRefs.OrphansGrid.SelectedRows | ForEach-Object { $_.Cells['Path'].Value }
                
                foreach ($path in $toRemove) {
                    try {
                        Remove-DatastoreFile -Datastore $dsObj -Path $path -Confirm:$false -ErrorAction Stop
                    } 
                    catch {
                        Write-Verbose "Failed to delete '$path': $_"
                    }
                }

                # Refresh after deletion
                $UiRefs.RefreshButton.PerformClick()
            }
            catch {
                Write-Verbose "Failed to delete selected files: $_"
            }
        })

        $UiRefs.SearchButton.Add_Click({
            $filterText = $UiRefs.SearchBox.Text.Trim()
            if ([string]::IsNullOrEmpty($filterText)) {
                return
            }

            foreach ($row in $UiRefs.OrphansGrid.Rows) {
                if ($row.Cells['Path'].Value -match $filterText) {
                    $row.Visible = $true
                }
                else {
                    $row.Visible = $false
                }
            }
        })

        # Enable search on Enter key
        $UiRefs.SearchBox.Add_KeyDown({
            if ($_.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
                $UiRefs.SearchButton.PerformClick()
                $_.SuppressKeyPress = $true
            }
        })
    }
    catch {
        Write-Verbose "Failed to update orphan cleaner view: $_"
    }
}