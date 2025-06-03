# Required assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing


function Show-OrphansView {
    <#
        .SYNOPSIS
            Displays the Orphans view in the UI.
        .DESCRIPTION
            Initializes the Orphans view layout and populates it with data.
        .PARAMETER ContentPanel
            The Windows.Forms.Panel where this view is rendered.
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Forms.Panel]$ContentPanel
    )

    # Build UI skeleton
    $script:uiRefs = New-OrphanLayout -ContentPanel $ContentPanel

    . $PSScriptRoot\DashboardView.ps1 # Ensure Set-StatusMessage is available
    if(-not $script:Connection){
        Set-StatusMessage -UiRefs $script:uiRefs -Message 'No connection to vCenter.' -Type Error
        return
    }

    Wire-UIEvents $script:uiRefs

    Set-StatusMessage -UiRefs $script:uiRefs -Message "Loading datastores..." -Type 'Info'
    $datastores = Get-Datastore -Server $script:Connection -ErrorAction SilentlyContinue
    if ($datastores) {
        Set-StatusMessage -UiRefs $script:uiRefs -Message "Scanning for orphaned files..." -Type 'Info'
        $orphans = $datastores | Get-Orphans
        Update-OrphanData -Datastores $datastores -Orphans $orphans
    } else {
        Set-StatusMessage -UiRefs $script:uiRefs -Message "Failed to retrieve datastores from vCenter." -Type 'Error'
        Update-OrphanData -Datastores @() -Orphans @()
    }
}

function New-OrphanLayout {
    <#
        .SYNOPSIS
            Creates the layout for the Orphans view.
        .DESCRIPTION
            Builds the UI skeleton with header, filters, data grid, and controls.
        .PARAMETER ContentPanel
            The Windows.Forms.Panel to populate.
        .OUTPUTS
            Hashtable of UI element references.
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Forms.Panel]$ContentPanel
    )

    $ContentPanel.Controls.Clear()
    $ContentPanel.BackColor = $script:Theme.LightGray

    # Root layout
    $root = [System.Windows.Forms.TableLayoutPanel]::new()
    $root.Dock = 'Fill'
    $root.ColumnCount = 1
    $root.RowCount = 5
    $root.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::AutoSize))   # Header
    $root.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::AutoSize))   # Filter
    $root.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Percent,100)) # Grid
    $root.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::AutoSize))  # Controls
    $root.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::AutoSize)) # Footer
    
    $ContentPanel.Controls.Add($root)

    # ------------------ Header ---------------------------------------
    $header = [System.Windows.Forms.Panel]::new()
    $header.Dock = 'Fill'; 
    $header.AutoSize = $true
    $header.BackColor = $script:Theme.Primary
    
    $root.Controls.Add($header, 0, 0)

    $titleLabel = [System.Windows.Forms.Label]::new()
    $titleLabel.Text = 'ORPHANED VM FILES'
    $titleLabel.Font = [System.Drawing.Font]::new('Segoe UI', 18, [System.Drawing.FontStyle]::Bold)
    $titleLabel.ForeColor = $script:Theme.White
    $titleLabel.Location = [System.Drawing.Point]::new(20,15)
    $titleLabel.AutoSize = $true
    
    $header.Controls.Add($titleLabel)

    # Refresh Label
    $lblLastRefresh = [System.Windows.Forms.Label]::new()
    $lblLastRefresh.Name = 'LastRefreshLabel'
    $lblLastRefresh.Text = "Last refresh: $(Get-Date -Format 'HH:mm:ss tt')"
    $lblLastRefresh.Font = [System.Drawing.Font]::new('Segoe UI', 9)
    $lblLastRefresh.ForeColor = $script:Theme.White
    $lblLastRefresh.Location = [System.Drawing.Point]::new(20,50)
    $lblLastRefresh.AutoSize = $true
    $header.Controls.Add($lblLastRefresh)

    # Filter row
    $filterPanel = [System.Windows.Forms.Panel]::new()
    $filterPanel.Dock = 'Fill'; 
    $filterPanel.AutoSize = $true
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

    # --------- Orphan Data grid -------------------------------------------
    $gridScroller = [System.Windows.Forms.Panel]::new()
    $gridScroller.Dock = 'Fill'
    $gridScroller.AutoScroll = $true
    $gridScroller.Padding = [System.Windows.Forms.Padding]::new(10)
    $gridScroller.BackColor = $script:Theme.White

    $root.Controls.Add($gridScroller, 0, 2)

    $grid = [System.Windows.Forms.DataGridView]::new()
    $grid.Name = 'gvOrphans'
    $grid.Dock = 'Fill'
    
    $grid.ReadOnly = $true
    $grid.SelectionMode = 'FullRowSelect'  # Allow full row selection
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

     # ── Footer ----------------------------------------------------------------
    $footer           = New-Object System.Windows.Forms.Panel
    $footer.Dock      = 'Fill'
    $footer.AutoSize    = $true
    $footer.BackColor = $script:Theme.LightGray

    $status           = New-Object System.Windows.Forms.Label
    $status.Name      = 'StatusLabel'
    $status.AutoSize  = $true
    $status.Font      = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
    $status.ForeColor = $script:Theme.Error
    $status.Text      = ''
    $footer.Controls.Add($status)

    $root.Controls.Add($footer, 0, 4)

    # Return refs
    return @{
        ContentPanel   = $ContentPanel
        DatastoreCombo = $cmbDatastores
        SearchBox      = $txtSearch
        SearchButton   = $btnSearch
        OrphansGrid    = $grid
        RefreshButton  = $btnRefresh
        DeleteButton   = $btnDelete
        StatusLabel    = $status
        Header         = @{ LastRefreshLabel = $lblLastRefresh }
    }
}

function Update-OrphanData {
    <#
    .SYNOPSIS
        Populates the UI with orphaned file data and updates filters.
    .DESCRIPTION
        Loads orphaned file data into the grid, updates the datastore filter dropdown,
        and sets the status message based on results.
    .PARAMETER Datastores
        Array of datastores to populate the filter dropdown.
    .PARAMETER Orphans
        Array of orphaned file objects to display in the grid.
    #>

    param(
        [Parameter(Mandatory)]
        [VMware.VimAutomation.ViCore.Types.V1.DatastoreManagement.Datastore[]]$Datastores,
        
        [Parameter(Mandatory)]
        [PSObject[]]$Orphans
    )

    # Update timestamp first
    $script:UiRefs.Header.LastRefreshLabel.Text = "Last refresh: $(Get-Date -Format 'HH:mm:ss tt')"

    # Initialize OrphansData structure
    $script:OrphansData = @{
        FullDataset = $null
        FilteredDataset = $null
    }

    # Populate datastore dropdown filter
    $UiRefs.DatastoreCombo.Items.Clear()
    $UiRefs.DatastoreCombo.Items.AddRange($Datastores.Name)
    if ($Datastores.Count -gt 0) {
        $UiRefs.DatastoreCombo.SelectedIndex = 0
    }
    
    # Flatten orphaned files into a displayable object array
    $script:OrphansData.FullDataset = $Orphans | ForEach-Object {
        if ($_.OrphanCount -gt 0) {
            foreach ($file in $_.Orphans) {
                [PSCustomObject]@{
                    Name         = $file.Name
                    Type         = $file.Type
                    SizeFormatted= Format-FileSize -Bytes $file.Size
                    Modified     = $file.Modified
                    Owner        = $file.Owner
                    Datastore    = $file.Datastore
                    FullPath     = $file.FullPath
                    RawFile      = $file.RawFile
                }
            }
        }
    }

    # Calculate total orphan count for status message
    $totalOrphans = ($Orphans | Measure-Object -Property OrphanCount -Sum).Sum
    if ($totalOrphans -gt 0) {
        Set-StatusMessage -UiRefs $UiRefs -Message "Found $totalOrphans orphaned files across $($Datastores.Count) datastores" -Type Success
        Update-OrphanGrid
    }
    else {
        Set-StatusMessage -UiRefs $UiRefs -Message "No orphaned files found" -Type Info
    }
}

function Format-FileSize {
    <#
    .SYNOPSIS
        Formats a file size in bytes into a human-readable string (KB, MB, GB).
    .DESCRIPTION
        Converts a byte value to a string with appropriate units for display.
    #>

    param([long]$Bytes)
    
    if ($Bytes -ge 1GB) {
        return "{0:N2} GB" -f ($Bytes / 1GB)
    }
    elseif ($Bytes -ge 1MB) {
        return "{0:N2} MB" -f ($Bytes / 1MB)
    }
    elseif ($Bytes -ge 1KB) {
        return "{0:N2} KB" -f ($Bytes / 1KB)
    }
    else {
        return "$Bytes B"
    }
}

function Get-Orphans {
    <#
    .SYNOPSIS
        Wrapper function for the Find-OrphanedFiles
    .OUTPUTS
        formated data so the user can see on the UI
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
        [VMware.VimAutomation.ViCore.Types.V1.DatastoreManagement.Datastore]$Datastore
    )

    process {
        Write-Verbose "Scanning datastore: $($Datastore.Name)"

        $orphans = Find-OrphanedFiles -DatastoreName $Datastore.Name

        # Format orphaned files for UI
        $orphansMapped = $orphans | ForEach-Object {
            [PSCustomObject]@{
                Name      = $_.Path
                Type      = $_.DiskType
                Size      = $_.SizeBytes
                Modified  = $_.Modification
                Owner     = $_.Owner
                Datastore = $Datastore.Name
                FullPath  = "$($Datastore.Name) $($_.Path)"
                RawFile   = $_
            }
        }

        # Output expected object
        [PSCustomObject]@{
            Datastore   = $Datastore.Name
            OrphanCount = @($orphansMapped).Count
            Orphans     = $orphansMapped
        }
    }
}


function Find-OrphanedFiles {
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


function Update-OrphanGrid {
    # Get current filter values from UI
    $selectedDs = $script:UiRefs.DatastoreCombo.SelectedItem
    $searchText = $script:UiRefs.SearchBox.Text.Trim()
    
    # Apply filters
    $filteredData = $script:OrphansData.FullDataset | Where-Object {
        ([string]::IsNullOrEmpty($selectedDs) -or ($_.Datastore -eq $selectedDs)) -and
        ([string]::IsNullOrEmpty($searchText) -or (
            $_.Name -like "*$searchText*" -or 
            $_.FullPath -like "*$searchText*" -or 
            $_.Datastore -like "*$searchText*" -or
            $_.Type -like "*$searchText*" -or
            $_.Owner -like "*$searchText*"
        ))
    }
    
    # Update grid
    $script:UiRefs.OrphansGrid.DataSource = [System.Collections.ArrayList]@($filteredData)
}

function Wire-UIEvents {
    <#
    .SYNOPSIS
        Wires up UI event handlers for the Orphans view controls.
    .DESCRIPTION
        Connects UI actions (filter, search, refresh, delete) to their respective logic.
    #>

    param([Parameter(Mandatory)]$UiRefs)

    # Store UI references at script scope
    $script:UiRefs = $UiRefs

    # Datastore filter
    $UiRefs.DatastoreCombo.Add_SelectedIndexChanged({
        . $PSScriptRoot\OrphansView.ps1
        Update-OrphanGrid
    })

    # Search filter
    $UiRefs.SearchButton.Add_Click({
        . $PSScriptRoot\OrphansView.ps1
        Update-OrphanGrid
    })

    # Refresh data
    $UiRefs.RefreshButton.Add_Click({
        . $PSScriptRoot\OrphansView.ps1
        $script:UiRefs.Header.LastRefreshLabel.Text = "Last refresh: $(Get-Date -Format 'HH:mm:ss tt')"
        Show-OrphansView -ContentPanel $script:uiRefs.ContentPanel 
    })

    # In Wire-UIEvents, update the DeleteButton click handler:
    $UiRefs.DeleteButton.Add_Click({
        . $PSScriptRoot\DashboardView.ps1 # ensure Set-StatusMessage is available
        $selectedRows = @($script:UiRefs.OrphansGrid.SelectedRows)
        
        if ($selectedRows.Count -eq 0) {
            Set-StatusMessage -UiRefs $script:UiRefs -Message "No rows selected for deletion" -Type Warning
            return
        }

        $result = [System.Windows.Forms.MessageBox]::Show(
            "Are you sure you want to delete $($selectedRows.Count) selected files?",
            "Confirm Deletion", 
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )

        if ($result -eq "Yes") {
            $deletedCount = 0
            $errors = @()
            
            foreach ($row in $selectedRows) {
                try {
                    # get the raw file info
                    $fileObj = $row.DataBoundItem.RawFile -as [string]
                    # extract folder info of the file
                    if ($fileObj -match 'Folder=([^;]+);') {
                        $folderPath = $matches[1].Trim()
                        Write-Host "Extracted Folder: $folderPath"
                        if ($folderPath -match '^\[(.+?)\]\s(.+)$') {
                            $dsName = $matches[1]
                            $dsPath = $matches[2]
                            Write-Host "Datastore: $dsName"
                            Write-Host "Path: $dsPath"

                            $datastore = Get-Datastore -Name $dsName -ErrorAction Stop
                            $dsRef = $datastore.ExtensionData.MoRef
                            $fullPath = "[$dsName] $dsPath"

                            # Get the FileManager managed object from the current vCenter connection
                            $fileMgr = Get-View (Get-View ServiceInstance).Content.FileManager

                            # Submit a deletion task for the specified file on the datastore
                            $task = $fileMgr.DeleteDatastoreFile_Task($fullPath, $null)
                            Write-Host "Deletion task submitted for: $fullPath"

                            $deletedCount++
                        } else {
                            Write-Host "Could not parse datastore and path from: $folderPath"
                        }
                    } else {
                        Write-Host "Could not extract Folder"
                    }

                }
                catch {
                    Write-Host "Exception caught: $($_.Exception.Message)"
                    $errors += "Failed to delete $($row.DataBoundItem.Name): $($_.Exception.Message)"
                }
            }

            $statusMsg = if ($errors.Count -gt 0) {
                "Deleted $deletedCount files, $($errors.Count) errors occurred"
            } else {
                "Successfully deleted $deletedCount files"
            }
            
            Set-StatusMessage -UiRefs $script:UiRefs -Message $statusMsg -Type $(if ($errors) { 'Warning' } else { 'Success' })
            
            # Refresh data after deletion
            $script:UiRefs.RefreshButton.PerformClick()
        }
    })
}
