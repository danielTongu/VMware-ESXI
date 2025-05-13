<#
.SYNOPSIS
    Manages course-related VM operations, resilient to authentication and offline states.
.DESCRIPTION
    Provides methods to create and remove VMs for all students in a course.
    Honors global login and offline state; operations are no-ops when disconnected.
.NOTES
    Uses $global:IsLoggedIn, $global:VMwareConfig.Connection, and $global:VMwareConfig.OfflineMode.
#>

class CourseManager {
    <#
    .SYNOPSIS
        Retrieves a safe server connection or toggles offline mode.
    .OUTPUTS
        Connection object or $null.
    #>
    hidden static [object] GetConnectionSafe() {
        if (-not $global:IsLoggedIn) {
            Write-Warning 'Not logged in: course operations disabled.'
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
        Creates VMs for all students in a course.
    .PARAMETER CourseInfo
        Course configuration object with properties:
          - classFolder: base folder name
          - students: array of student identifiers
          - servers: array of server specs (serverName, template, adapters, customization)
          - dataStore: target datastore name
    #>
    static [void] CreateCourseVMs([PSCustomObject]$CourseInfo) {
        $conn = [CourseManager]::GetConnectionSafe()
        if ($null -eq $conn) { return }
        try {
            foreach ($student in $CourseInfo.students) {
                $folderName = "$($CourseInfo.classFolder)_$student"
                $folder = Get-Folder -Name $folderName -Server $conn -ErrorAction SilentlyContinue
                if (-not $folder) {
                    $parent = Get-Folder -Name $CourseInfo.classFolder -Server $conn -ErrorAction Stop
                    $folder = New-Folder -Name $folderName -Location $parent -Server $conn
                }
                foreach ($spec in $CourseInfo.servers) {
                    $vm = [VMwareVM]::new(
                        $spec.serverName,
                        $folderName,
                        $spec.template,
                        $CourseInfo.dataStore,
                        $spec.adapters,
                        $spec.customization
                    )
                    $vm.Create()
                    $vm.PowerOn()
                }
            }
        }
        catch {
            Write-Warning "CreateCourseVMs failed: $_"
        }
    }

    <#
    .SYNOPSIS
        Removes all VMs for a course and deletes their folders.
    .PARAMETER ClassFolder
        The base folder name for the course.
    .PARAMETER Students
        Array of student identifiers.
    #>
    static [void] RemoveCourseVMs([string]$ClassFolder, [string[]]$Students) {
        $conn = [CourseManager]::GetConnectionSafe()
        if ($null -eq $conn) { return }
        try {
            foreach ($student in $Students) {
                $folderName = "$ClassFolder`_$student"
                $folder = Get-Folder -Name $folderName -Server $conn -ErrorAction SilentlyContinue
                if ($folder) {
                    $vms = Get-VM -Location $folder -Server $conn
                    foreach ($vm in $vms) {
                        if ($vm.PowerState -eq 'PoweredOn') {
                            Stop-VM -VM $vm -Server $conn -Confirm:$false | Out-Null
                        }
                        Remove-VM -VM $vm -DeletePermanently -Server $conn -Confirm:$false | Out-Null
                    }
                    Remove-Folder -Folder $folder -Server $conn -Confirm:$false | Out-Null
                }
            }
        }
        catch {
            Write-Warning "RemoveCourseVMs failed: $_"
        }
    }
}