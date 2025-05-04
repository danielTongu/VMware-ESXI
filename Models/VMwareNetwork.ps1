<#
.SYNOPSIS
    Manages VMware network components, resilient to offline or disconnected states.
.DESCRIPTION
    Provides methods to create student-specific port groups and list existing port groups.
    All operations safely handle global authentication and offline state.
.NOTES
    Uses $global:VMwareConfig.Connection, $global:IsLoggedIn, and $global:VMwareConfig.OfflineMode.
#>

class VMwareNetwork {
    <#
    .SYNOPSIS
        Retrieves a safe server connection or toggles offline mode.
    .OUTPUTS
        Connection object or $null.
    #>
    hidden static [object] GetConnectionSafe() {
        if (-not $global:IsLoggedIn) {
            Write-Warning "Not logged in: network operations disabled."
            return $null
        }
        if ($global:VMwareConfig.OfflineMode -or -not $global:VMwareConfig.Connection) {
            Write-Warning "Offline mode: cannot establish network connection."
            return $null
        }
        return $global:VMwareConfig.Connection
    }

    <#
    .SYNOPSIS
        Creates a port group for a student under a given vSwitch.
    .PARAMETER Student
        Student identifier to append to port group name.
    .PARAMETER NetworkName
        Base vSwitch name.
    #>
    static [void] CreateStudentPortGroup(
        [string]$Student,
        [string]$NetworkName
    ) {
        $conn = GetConnectionSafe
        if ($null -eq $conn) { return }

        try {
            $vmHost = Get-VMHost -Server $conn -ErrorAction Stop | Select-Object -First 1
            $portGroupName = "$NetworkName`_$Student"

            # Skip if exists
            $existing = Get-VirtualPortGroup -Name $portGroupName -Server $conn -ErrorAction SilentlyContinue
            if ($existing) { return }

            # Ensure vSwitch
            $vSwitch = Get-VirtualSwitch -Name $NetworkName -Server $conn -ErrorAction SilentlyContinue
            if (-not $vSwitch) {
                New-VirtualSwitch -Name $NetworkName -VMHost $vmHost -Server $conn | Out-Null
                $vSwitch = Get-VirtualSwitch -Name $NetworkName -Server $conn
            }

            # Create port group
            New-VirtualPortGroup -Name $portGroupName -VirtualSwitch $vSwitch -Server $conn | Out-Null
        }
        catch {
            Write-Warning "CreateStudentPortGroup failed for '$Student' on '$NetworkName': $_"
        }
    }

    <#
    .SYNOPSIS
        Lists all VMware virtual port groups.
    .OUTPUTS
        Array of objects with Name and VirtualSwitch properties.
    #>
    static [array] ListPortGroups() {
        $conn = GetConnectionSafe
        if ($null -eq $conn) {
            Write-Warning "Offline mode or not logged in: cannot list port groups."
            return @()
        }
        try {
            return Get-VirtualPortGroup -Server $conn | Select-Object Name, VirtualSwitchName
        }
        catch {
            Write-Warning "ListPortGroups failed: $_"
            return @()
        }
    }
}
