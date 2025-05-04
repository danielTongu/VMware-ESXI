<#
.SYNOPSIS
    Reports on active VMware sessions and VMs with resilience to login/offline state.
.DESCRIPTION
    Provides methods to list powered-on VMs and VMs by folder, honoring global authentication and offline flags.
.NOTES
    Uses $global:IsLoggedIn, $global:VMwareConfig.Connection, and $global:VMwareConfig.OfflineMode.
#>

class SessionReporter {
    <#
    .SYNOPSIS
        Retrieves a safe server connection or toggles offline mode.
    .OUTPUTS
        Connection object or $null.
    #>
    hidden static [object] GetConnectionSafe() {
        if (-not $global:IsLoggedIn) {
            Write-Warning "Not logged in: cannot query sessions."
            return $null
        }
        if ($global:VMwareConfig.OfflineMode -or -not $global:VMwareConfig.Connection) {
            Write-Warning "Offline mode: cannot establish connection."
            return $null
        }
        return $global:VMwareConfig.Connection
    }

    <#
    .SYNOPSIS
        Gets all powered-on VMs.
    .OUTPUTS
        Array of objects with Name, PowerState, and IP.
    #>
    static [array] GetPoweredOnVMs() {
        $conn = [SessionReporter]::GetConnectionSafe()
        if ($null -eq $conn) { return @() }
        try {
            return Get-VM -Server $conn -ErrorAction Stop |
                   Where-Object { $_.PowerState -eq 'PoweredOn' } |
                   Select-Object Name, PowerState,
                                 @{ Name='IP'; Expression={ $_.Guest.IPAddress[0] }}
        }
        catch {
            Write-Warning "GetPoweredOnVMs failed: $_"
            return @()
        }
    }

    <#
    .SYNOPSIS
        Gets VMs by folder name.
    .PARAMETER Folder
        The folder or resource pool path.
    .OUTPUTS
        Array of objects with Name, PowerState, NumCpu, and MemoryGB.
    #>
    static [array] GetVMsByFolder([string]$Folder) {
        $conn = [SessionReporter]::GetConnectionSafe()
        if ($null -eq $conn) { return @() }
        try {
            return Get-VM -Location $Folder -Server $conn -ErrorAction Stop |
                   Select-Object Name, PowerState, NumCpu, MemoryGB
        }
        catch {
            Write-Warning "GetVMsByFolder failed for '$Folder': $_"
            return @()
        }
    }
}
