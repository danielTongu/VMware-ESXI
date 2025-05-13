<#
.SYNOPSIS
    Finds and cleans orphaned VM files, resilient to authentication and offline states.
.DESCRIPTION
    Provides methods to discover orphaned VM-related files on a datastore.
    Honors global login and offline state; operations are no-ops when disconnected.
.NOTES
    Uses $global:IsLoggedIn, $global:VMwareConfig.Connection, and $global:VMwareConfig.OfflineMode.
#>

class OrphanCleaner {
    <#
    .SYNOPSIS
        Retrieves a safe server connection or toggles offline mode.
    .OUTPUTS
        Connection object or $null.
    #>
    hidden static [object] GetConnectionSafe() {
        if (-not $global:IsLoggedIn) {
            Write-Warning 'Not logged in: cannot query datastore.'
            return $null
        }
        if ($global:VMwareConfig.OfflineMode -or -not $global:VMwareConfig.Connection) {
            Write-Warning 'Offline mode: cannot establish connection.'
            return $null
        }
        return $global:VMwareConfig.Connection
    }

    <#
    .SYNOPSIS
        Finds orphaned VM files on a given datastore.
    .PARAMETER DatastoreName
        The name of the datastore to scan.
    .OUTPUTS
        Array of objects with Path, Size, and Type properties.
    #>
    static [array] FindOrphanedFiles([string]$DatastoreName) {
        $conn = [OrphanCleaner]::GetConnectionSafe()
        if ($null -eq $conn) { return @() }

        try {
            $ds = Get-Datastore -Name $DatastoreName -Server $conn -ErrorAction Stop
            $flags = New-Object VMware.Vim.FileQueryFlags
            $flags.FileOwner     = $true
            $flags.FileSize      = $true
            $flags.FileType      = $true
            $flags.Modification  = $true

            $searchSpec = New-Object VMware.Vim.HostDatastoreBrowserSearchSpec
            $searchSpec.details = $flags
            $searchSpec.Query   = @( 
                (New-Object VMware.Vim.VmDiskFileQuery), 
                (New-Object VMware.Vim.VmLogFileQuery), 
                (New-Object VMware.Vim.VmNvramFileQuery) 
            )

            $browser   = Get-View -Id $ds.ExtensionData.browser
            $rootPath  = "[$($ds.Name)]"
            $results   = $browser.SearchDatastoreSubFolders($rootPath, $searchSpec)

            $orphans = @()
            foreach ($folder in $results) {
                foreach ($file in $folder.File) {
                    $orphans += [PSCustomObject]@{
                        Path = "$($folder.FolderPath)$($file.Path)"
                        Size = $file.FileSize
                        Type = $file.GetType().Name
                    }
                }
            }
            return $orphans
        }
        catch {
            Write-Warning "FindOrphanedFiles failed for '$DatastoreName': $_"
            return @()
        }
    }
}