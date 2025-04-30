<#
.SYNOPSIS
    Core VMware models & services module with integrated WinForms login.
.DESCRIPTION
    On import, shows a login dialog (from LoginView.ps1).
    If the user cancels or fails, the module throws and stops loading.
    Otherwise, exports:
      - ConnectTo-VMServer()
      - VMwareNetwork (singleton)
      - VMwareVM
      - CourseManager
      - SessionReporter
      - OrphanCleaner
#>

# -------------------------------------------------------------------
# 1) Force user to authenticate before anything else in this module
# -------------------------------------------------------------------

# Load the AuthModel (must export AuthModel.ValidateUser)
Import-Module (Join-Path $PSScriptRoot 'AuthModel.psm1') -ErrorAction Stop

# Load the Login view UI
. (Join-Path $PSScriptRoot '..\Views\LoginView.ps1')

# Show the dialog; if it returns $false, abort the module import
if (-not (Show-LoginView)) {
    throw 'Authentication failed or cancelled. VMwareModels module will not load.'
}

# -------------------------------------------------------------------
# 2) Connection helper
# -------------------------------------------------------------------

function ConnectTo-VMServer {
    <#
    .SYNOPSIS
        Connects to the vSphere server using stored credentials.
    .DESCRIPTION
        Reads a CLI‐XML credential file from Google Drive, then
        calls Connect-VIServer. Throws on failure.
    #>
    [CmdletBinding()]
    param()

    $credFile = Join-Path $HOME 'Google Drive\VMware Scripts\creds.xml'
    if (-not (Test-Path $credFile)) {
        throw "Credential file not found: $credFile"
    }

    $creds = Import-CliXml -Path $credFile
    Connect-VIServer -Server 'csvcsa.cs.cwu.edu' `
                     -Credential $creds `
                     -ErrorAction Stop | Out-Null
}

# -------------------------------------------------------------------
# 3) VMwareNetwork (Singleton)
# -------------------------------------------------------------------

class VMwareNetwork {
    [string]$VmHost

    static [VMwareNetwork]$Instance = $null

    <#
    .SYNOPSIS
        Returns the single shared VMwareNetwork instance.
    #>
    static [VMwareNetwork] GetInstance() {
        if (-not [VMwareNetwork]::$Instance) {
            [VMwareNetwork]::$Instance = [VMwareNetwork]::new()
        }
        return [VMwareNetwork]::$Instance
    }

    <#
    .SYNOPSIS
        Constructor: ensures a live connection and caches the host name.
    #>
    VMwareNetwork() {
        ConnectTo-VMServer
        $this.VmHost = (Get-VMHost).Name
    }

    <#
    .SYNOPSIS
        Lists all port‐groups on the host.
    .OUTPUTS
        String[]
    #>
    static [string[]] ListNetworks() {
        ConnectTo-VMServer
        try {
            return Get-VirtualPortGroup -VMHost (Get-VMHost) |
                   Select-Object -ExpandProperty Name
        } catch {
            return @() # Return an empty array if an error occurs
        }
    }

    <#
    .SYNOPSIS
        Creates a vSwitch + port‐group.
    .PARAMETER NetworkName
        Name of switch + port‐group.
    #>
    [void] AddNetwork([string]$NetworkName) {
        New-VirtualSwitch   -Name $NetworkName -VMHost $this.VmHost       | Out-Null
        New-VirtualPortGroup -Name $NetworkName -VirtualSwitch $NetworkName | Out-Null
    }

    <#
    .SYNOPSIS
        Removes a port‐group + vSwitch.
    .PARAMETER NetworkName
        Name to delete.
    #>
    [void] RemoveNetwork([string]$NetworkName) {
        Get-VirtualPortGroup -VMHost $this.VmHost -Name $NetworkName |
          Remove-VirtualPortGroup -Confirm:$false
        Get-VirtualSwitch -Name $NetworkName |
          Remove-VirtualSwitch -Confirm:$false
    }

    <#
    .SYNOPSIS
        Bulk‐creates student networks for a course.
    #>
    [void] BulkAddNetworks(
        [string]$CourseNumber,
        [int]   $Start,
        [int]   $End
    ) {
        for ($i=$Start; $i -le $End; $i++) {
            $name = "$CourseNumber`_S$i"
            if (-not (Get-VirtualSwitch -Name $name -ErrorAction SilentlyContinue)) {
                $this.AddNetwork($name)
            }
        }
    }

    <#
    .SYNOPSIS
        Bulk‐deletes student networks for a course.
    #>
    [void] BulkRemoveNetworks(
        [int]   $Start,
        [int]   $End,
        [string]$CourseNumber
    ) {
        for ($i=$Start; $i -le $End; $i++) {
            $name = "$CourseNumber`_S$i"
            $this.RemoveNetwork($name)
        }
    }
}

# -------------------------------------------------------------------
# 4) VMwareVM
# -------------------------------------------------------------------

class VMwareVM {
    [string]  $Name
    [string]  $ClassFolder
    [string]  $Student
    [string]  $Template
    [string]  $Datastore
    [string[]]$Adapters

    <#
    .SYNOPSIS
        Lists all powered-on VMs (Name + IP).
    .OUTPUTS
        PSCustomObject[]
    #>
    static [PSCustomObject[]] ListPoweredOn() {
        ConnectTo-VMServer
        $poweredOnVMs = Get-VM | Where-Object PowerState -eq 'PoweredOn' |
                        Select-Object Name,@{n='IP';e={$_.Guest.IPAddress[0]}}
        return $poweredOnVMs
    }

    <#
    .SYNOPSIS
        Constructor: sets all identifying properties.
    #>
    VMwareVM(
        [string]  $Name,
        [string]  $ClassFolder,
        [string]  $Student,
        [string]  $Template,
        [string]  $Datastore,
        [string[]]$Adapters
    ) {
        $this.Name        = $Name
        $this.ClassFolder = $ClassFolder
        $this.Student     = $Student
        $this.Template    = $Template
        $this.Datastore   = $Datastore
        $this.Adapters    = $Adapters
    }

    <#
    .SYNOPSIS
        Builds (creates & powers on) this VM under the student’s folder.
    #>
    [void] Build() {
        ConnectTo-VMServer
        $folderName = "$($this.ClassFolder)_$($this.Student)"
        $folder = Get-Folder -Name $folderName -ErrorAction SilentlyContinue
        if (-not $folder) {
            $parent = Get-Folder -Name $this.ClassFolder
            $folder = New-Folder -Name $folderName -Location $parent
        }
        New-VM -Name $this.Name `
               -Datastore $this.Datastore `
               -VMHost (Get-VMHost) `
               -Template $this.Template `
               -Location $folder | Out-Null

        $i = 1
        foreach ($pg in $this.Adapters) {
            Get-VM -Name $this.Name -Location $folder |
              Get-NetworkAdapter -Name "Network Adapter $i" |
              Set-NetworkAdapter -PortGroup $pg -Confirm:$false | Out-Null
            $i++
        }

        Start-VM -VM $this.Name -Confirm:$false | Out-Null
    }

    <#
    .SYNOPSIS
        Powers off this VM.
    #>
    [void] PowerOff() {
        ConnectTo-VMServer
        Stop-VM -VM $this.Name -Confirm:$false | Out-Null
    }

    <#
    .SYNOPSIS
        Powers on this VM.
    #>
    [void] PowerOn() {
        ConnectTo-VMServer
        Start-VM -VM $this.Name -Confirm:$false | Out-Null
    }

    <#
    .SYNOPSIS
        Restarts this VM.
    #>
    [void] Restart() {
        $this.PowerOff()
        Start-VM -VM $this.Name -Confirm:$false | Out-Null
    }

    <#
    .SYNOPSIS
        Deletes this VM and its student folder.
    #>
    [void] Remove() {
        ConnectTo-VMServer
        Stop-VM -VM $this.Name -Confirm:$false | Out-Null
        Remove-VM -VM $this.Name -DeletePermanently -Confirm:$false | Out-Null
        Remove-Folder -Folder (Get-Folder -Name "$($this.ClassFolder)_$($this.Student)") `
                      -Confirm:$false -DeletePermanently | Out-Null
    }
}

# -------------------------------------------------------------------
# 5) CourseManager
# -------------------------------------------------------------------

class CourseManager {
    <#
    .SYNOPSIS
        Lists all class folders.
    .OUTPUTS
        String[]
    #>
    static [string[]] ListClasses() {
        ConnectTo-VMServer
        $folders = Get-Folder -Name '*' | Select-Object -ExpandProperty Name
        return $folders -ne $null ? $folders : @()
    }

    <#
    .SYNOPSIS
        Builds VMs for every student in a course.
    #>
    static [void] NewCourseVMs([PSCustomObject]$info) {
        foreach ($student in $info.students) {
            $vm = [VMwareVM]::new(
                "$($info.classFolder)_$student",
                $info.classFolder,
                $student,
                $info.servers[0].template,
                $info.dataStore,
                $info.servers[0].adapters
            )
            $vm.Build()
        }
    }

    <#
    .SYNOPSIS
        Deletes all VMs & folders for a class.
    #>
    static [void] RemoveCourseVMs([string]$cf,[int]$s,[int]$e) {
        for ($i=$s; $i -le $e; $i++) {
            $folder = "$cf`_S$i"
            Stop-VM -Location $folder -Confirm:$false | Out-Null
            Remove-VM -Location $folder -DeletePermanently -Confirm:$false | Out-Null
            Remove-Folder -Folder (Get-Folder -Name $folder) `
                          -Confirm:$false -DeletePermanently | Out-Null
        }
    }
}

# -------------------------------------------------------------------
# 6) SessionReporter & OrphanCleaner
# -------------------------------------------------------------------

class SessionReporter {
    static [void] ExportLoginTimes([string]$path) {
        ConnectTo-VMServer
        $mgr   = Get-View (Get-VIServer).ExtensionData.Content.SessionManager
        $curr  = $mgr.CurrentSession.Key
        $list  = $mgr.SessionList |
                 Where-Object { $_.UserName -notmatch 'vpxd-extension' -and $_.Key -ne $curr } |
                 ForEach-Object {
                     [PSCustomObject]@{
                         Username  = $_.UserName
                         IpAddress = $_.IpAddress
                         LoginTime = $_.LoginTime
                     }
                 }
        $list | Export-Csv -Path $path -NoTypeInformation
    }
}

class OrphanCleaner {
    static [PSCustomObject[]] GetOrphans([string]$dsName) {
        ConnectTo-VMServer
        $ds = Get-Datastore -Name $dsName
        return Get-VmwOrphan -Datastore $ds
    }
}

# -------------------------------------------------------------------
# 7) Export
# -------------------------------------------------------------------

Export-ModuleMember `
  -Function ConnectTo-VMServer `
  -Class VMwareNetwork,VMwareVM,CourseManager,SessionReporter,OrphanCleaner