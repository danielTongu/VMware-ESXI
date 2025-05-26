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
            $lblMessage.ForeColor = $script:Theme.Error
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
        $ContentPanel.BackColor = $script:Theme.LightGray

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
        $header.BackColor = $script:Theme.Primary
        
        $root.Controls.Add($header, 0, 0)

        $titleLabel = [System.Windows.Forms.Label]::new()
        $titleLabel.Text = 'ORPHANED VM FILES'
        $titleLabel.Font = [System.Drawing.Font]::new('Segoe UI', 18, [System.Drawing.FontStyle]::Bold)
        $titleLabel.ForeColor = $script:Theme.White
        $titleLabel.Location = [System.Drawing.Point]::new(20,15)
        $titleLabel.AutoSize = $true
        
        $header.Controls.Add($titleLabel)

        # Filter row
        $filterPanel = [System.Windows.Forms.Panel]::new()
        $filterPanel.Dock = 'Fill'; 
        $filterPanel.Height = 50
        $filterPanel.BackColor = $script:Theme.LightGray
        
        $root.Controls.Add($filterPanel, 0, 1)

        # Datastore label
        $lblDatastore = [System.Windows.Forms.Label]::new()
        $lblDatastore.Text = 'Datastore:'
        $lblDatastore.Font = [System.Drawing.Font]::new('Segoe UI',10)
        $lblDatastore.ForeColor = $script:Theme.PrimaryDarker
        $lblDatastore.Location = [System.Drawing.Point]::new(20,15)
        $lblDatastore.AutoSize = $true

        $filterPanel.Controls.Add($lblDatastore)

        # Datastore dropdown
        $cmbDatastores = [System.Windows.Forms.ComboBox]::new()
        $cmbDatastores.DropDownStyle = 'DropDownList'
        $cmbDatastores.Width = 250
        $cmbDatastores.Font = [System.Drawing.Font]::new('Segoe UI',10)
        $cmbDatastores.Location = [System.Drawing.Point]::new(100,10)
        $cmbDatastores.BackColor = $script:Theme.White
        $cmbDatastores.ForeColor = $script:Theme.PrimaryDark

        $filterPanel.Controls.Add($cmbDatastores)

        # Search field
        $txtSearch = [System.Windows.Forms.TextBox]::new()
        $txtSearch.Width = 200; 
        $txtSearch.Height = 30
        $txtSearch.Location = [System.Drawing.Point]::new(370,10)
        $txtSearch.Font = [System.Drawing.Font]::new('Segoe UI',10)
        $txtSearch.BackColor = $script:Theme.White
        $txtSearch.ForeColor = $script:Theme.PrimaryDarker

        $filterPanel.Controls.Add($txtSearch)

        # Search button
        $btnSearch = [System.Windows.Forms.Button]::new()
        $btnSearch.Text = 'SEARCH'; 
        $btnSearch.Width = 100; 
        $btnSearch.Height = 30
        $btnSearch.Location = [System.Drawing.Point]::new(580,10)
        $btnSearch.Font = [System.Drawing.Font]::new('Segoe UI',10,[System.Drawing.FontStyle]::Bold)
        $btnSearch.BackColor = $script:Theme.Primary
        $btnSearch.ForeColor = $script:Theme.White

        $filterPanel.Controls.Add($btnSearch)

        # Data grid
        $gridScroller = [System.Windows.Forms.Panel]::new()
        $gridScroller.Dock = 'Fill'
        $gridScroller.AutoScroll = $true
        $gridScroller.Padding = [System.Windows.Forms.Padding]::new(10)
        $gridScroller.BackColor = $script:Theme.White
        $root.Controls.Add($gridScroller, 0, 2)

        $grid = [System.Windows.Forms.DataGridView]::new()
        $grid.Name = 'gvOrphans'; 
        $grid.Dock = 'Fill'
        $grid.ReadOnly = $true;
        $grid.SelectionMode = 'FullRowSelect'; 
        $grid.MultiSelect = $true
        $grid.AutoSizeColumnsMode = 'Fill'
        $grid.BackgroundColor = $script:Theme.White
        $grid.GridColor = $script:Theme.PrimaryDark
        $grid.BorderStyle = 'FixedSingle'
        $grid.DefaultCellStyle.Font = [System.Drawing.Font]::new('Segoe UI',10)
        $grid.DefaultCellStyle.ForeColor = $script:Theme.PrimaryDarker
        $grid.ColumnHeadersDefaultCellStyle.Font = [System.Drawing.Font]::new('Segoe UI',10,[System.Drawing.FontStyle]::Bold)
        $grid.ColumnHeadersDefaultCellStyle.ForeColor = $script:Theme.PrimaryDarker
        $grid.ColumnHeadersDefaultCellStyle.BackColor = $script:Theme.LightGray

        $gridScroller.Controls.Add($grid)

        # Controls footer
        $controlsPanel = [System.Windows.Forms.FlowLayoutPanel]::new()
        $controlsPanel.Dock = 'Fill'; 
        $controlsPanel.Height = 50
        $controlsPanel.FlowDirection = 'LeftToRight'
        $controlsPanel.Padding = [System.Windows.Forms.Padding]::new(10)
        $controlsPanel.BackColor = $script:Theme.LightGray

        $root.Controls.Add($controlsPanel, 0, 3)

        # Refresh button
        $btnRefresh = [System.Windows.Forms.Button]::new()
        $btnRefresh.Text = 'REFRESH'; 
        $btnRefresh.Width = 120;
        $btnRefresh.Height = 35
        $btnRefresh.Font = [System.Drawing.Font]::new('Segoe UI',10,[System.Drawing.FontStyle]::Bold)
        $btnRefresh.BackColor = $script:Theme.Primary
        $btnRefresh.ForeColor = $script:Theme.White

        $controlsPanel.Controls.Add($btnRefresh)

        # Delete button
        $btnDelete = [System.Windows.Forms.Button]::new()
        $btnDelete.Text = 'DELETE SELECTED';
        $btnDelete.Width = 150;
        $btnDelete.Height = 35
        $btnDelete.Font = [System.Drawing.Font]::new('Segoe UI',10,[System.Drawing.FontStyle]::Bold)
        $btnDelete.BackColor = $script:Theme.Error
        $btnDelete.ForeColor = $script:Theme.White

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

<#
    .SYNOPSIS
        Scans a datastore for orphaned files not associated with any registered VM or template.

    .DESCRIPTION
        (This function is a similiar implementaion from the client Get-VmwOrphan function) 
        searches a specified datastore and compares all discovered files against 
        those belonging to registered virtual machines and templates. Files that remain unaccounted 
        for (not linked to any VM or template) are considered orphaned. System files and folders 
        commonly found on datastores are excluded from the results.

    .PARAMETER DatastoreName
        The target datastore to scan for orphaned files.

    .OUTPUTS 
        Returns the orphan file 
        
#>
function Find-OrphanedFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DatastoreName
    )

    # Load the datastore object
    $ds = Get-Datastore -Name $DatastoreName
    if (-not $ds) {
        Write-Error "Datastore '$DatastoreName' not found."
        return
    }

    # Prepare FileQueryFlags and queries
    $flags = New-Object VMware.Vim.FileQueryFlags
    $flags.FileOwner = $true
    $flags.FileSize = $true
    $flags.FileType = $true
    $flags.Modification = $true

    $qFloppy = New-Object VMware.Vim.FloppyImageFileQuery
    $qFolder = New-Object VMware.Vim.FolderFileQuery
    $qISO = New-Object VMware.Vim.IsoImageFileQuery
    $qConfig = New-Object VMware.Vim.VmConfigFileQuery
    $qConfig.Details = New-Object VMware.Vim.VmConfigFileQueryFlags
    $qConfig.Details.ConfigVersion = $true
    $qTemplate = New-Object VMware.Vim.TemplateConfigFileQuery
    $qTemplate.Details = New-Object VMware.Vim.VmConfigFileQueryFlags
    $qTemplate.Details.ConfigVersion = $true
    $qDisk = New-Object VMware.Vim.VmDiskFileQuery
    $qDisk.Details = New-Object VMware.Vim.VmDiskFileQueryFlags
    $qDisk.Details.CapacityKB = $true
    $qDisk.Details.DiskExtents = $true
    $qDisk.Details.DiskType = $true
    $qDisk.Details.HardwareVersion = $true
    $qDisk.Details.Thin = $true
    $qLog = New-Object VMware.Vim.VmLogFileQuery
    $qRAM = New-Object VMware.Vim.VmNvramFileQuery
    $qSnap = New-Object VMware.Vim.VmSnapshotFileQuery

    $searchSpec = New-Object VMware.Vim.HostDatastoreBrowserSearchSpec
    $searchSpec.details = $flags
    $searchSpec.Query = $qFloppy, $qFolder, $qISO, $qConfig, $qTemplate, $qDisk, $qLog, $qRAM, $qSnap
    $searchSpec.sortFoldersFirst = $true

    # Get datastore browser view
    $dsBrowser = Get-View -Id $ds.ExtensionData.browser
    $rootPath = "[" + $ds.Name + "]"

    # Search all files recursively
    $searchResult = $dsBrowser.SearchDatastoreSubFolders($rootPath, $searchSpec) | Sort-Object -Property { $_.FolderPath.Length }

    # Create a hashtable of all files on the datastore
    $fileTable = @{}
    foreach ($folder in $searchResult) {
        foreach ($file in $folder.File) {
            # Add a space if folder path ends with ']'
            $key = "$($folder.FolderPath)$(if ($folder.FolderPath[-1] -eq ']') { ' ' })$($file.Path)"
            $fileTable[$key] = $file

            # Remove folder keys if any (avoid folder vs file key conflict)
            $folderKey = $folder.FolderPath.TrimEnd('/')
            if ($fileTable.ContainsKey($folderKey)) {
                $fileTable.Remove($folderKey)
            }
        }
    }

    # Remove files referenced by registered VMs on this datastore
    Get-VM -Datastore $ds | ForEach-Object {
        $_.ExtensionData.LayoutEx.File | ForEach-Object {
            if ($fileTable.ContainsKey($_.Name)) {
                $fileTable.Remove($_.Name)
            }
        }
    }

    # Remove files referenced by registered Templates on this datastore
    Get-Template | Where-Object { $_.DatastoreIdList -contains $ds.Id } | ForEach-Object {
        $_.ExtensionData.LayoutEx.File | ForEach-Object {
            if ($fileTable.ContainsKey($_.Name)) {
                $fileTable.Remove($_.Name)
            }
        }
    }

    # Remove system files
    $systemFilePatterns = @('\.vmkdump', '\.log$', '\.vswp$', '\.nvram$', '\.lck$', '\.vmsn$', '\.delta$', '\.sdd\.sf$')
    foreach ($pattern in $systemFilePatterns) {
        $keysToRemove = $fileTable.Keys | Where-Object { $_ -match $pattern }
        foreach ($key in $keysToRemove) {
            $fileTable.Remove($key)
        }
    }

    # Return the orphan files as PSObjects
    return $fileTable.GetEnumerator() | ForEach-Object {
        $file = $_.Value
        [PSCustomObject]@{
            Path         = $file.Path
            Folder       = $_.Key
            SizeBytes    = $file.FileSize
            CapacityKB   = if ($file.PSObject.Properties.Match('CapacityKB')) { $file.CapacityKB } else { $null }
            Modification = $file.Modification
            Owner        = $file.Owner
            Thin         = if ($file.PSObject.Properties.Match('Thin')) { $file.Thin } else { $null }
            DiskType     = if ($file.PSObject.Properties.Match('DiskType')) { $file.DiskType } else { $null }
            Extents      = if ($file.PSObject.Properties.Match('DiskExtents')) { ($file.DiskExtents -join ',') } else { $null }
            HWVersion    = if ($file.PSObject.Properties.Match('HardwareVersion')) { $file.HardwareVersion } else { $null }
        }
    }
}