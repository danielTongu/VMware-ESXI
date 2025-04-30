<#
.SYNOPSIS
    Core VMware models & services module with integrated WinForms login.
.DESCRIPTION
    On import, shows a login dialog (from Views/LoginView.ps1).
    If the user cancels or fails, the module throws and stops loading.
    Otherwise, exposes key classes and the ConnectTo-VMServer() helper.
#>

# -------------------------------------------------------------------
# 1) Force user to authenticate before anything else in this module
# -------------------------------------------------------------------

# Resolve paths
$RootPath  = Split-Path -Parent $MyInvocation.MyCommand.Path
$ViewsPath = Join-Path $RootPath 'Views'

# Load and display login view
. (Join-Path $ViewsPath 'LoginView.ps1')
if (-not (Show-LoginView)) {
    throw 'Authentication failed or cancelled. VMwareModels module will not load.'
}

# -------------------------------------------------------------------
# 2) ConnectTo-VMServer
# -------------------------------------------------------------------
function ConnectTo-VMServer {
    <#
    .SYNOPSIS
        Connects to vSphere using stored credentials.
    #>
    [CmdletBinding()]
    param()

    $credFile = Join-Path $HOME 'Google Drive\VMware Scripts\creds.xml'
    if (-not (Test-Path $credFile)) {
        throw "Credential file not found: $credFile"
    }

    $creds = Import-CliXml -Path $credFile
    Connect-VIServer -Server 'csvcsa.cs.cwu.edu' -Credential $creds -ErrorAction Stop | Out-Null
}

# -------------------------------------------------------------------
# 3) VMwareNetwork (Singleton)
# -------------------------------------------------------------------
class VMwareNetwork {
    [string]$VmHost
    static hidden [VMwareNetwork]$_Instance

    static [VMwareNetwork] GetInstance() {
        if (-not [VMwareNetwork]::_Instance) {
            [VMwareNetwork]::_Instance = [VMwareNetwork]::new()
        }
        return [VMwareNetwork]::_Instance
    }

    VMwareNetwork() {
        ConnectTo-VMServer
        $this.VmHost = (Get-VMHost).Name
    }

    static [string[]] ListNetworks() {
        ConnectTo-VMServer
        try {
            return Get-VirtualPortGroup -VMHost (Get-VMHost) | Select-Object -ExpandProperty Name
        } catch {
            return @()
        }
    }

    [void] AddNetwork([string]$NetworkName) {
        New-VirtualSwitch -Name $NetworkName -VMHost $this.VmHost | Out-Null
        New-VirtualPortGroup -Name $NetworkName -VirtualSwitch $NetworkName | Out-Null
    }

    [void] RemoveNetwork([string]$NetworkName) {
        Get-VirtualPortGroup -VMHost $this.VmHost -Name $NetworkName |
            Remove-VirtualPortGroup -Confirm:$false
        Get-VirtualSwitch -Name $NetworkName |
            Remove-VirtualSwitch -Confirm:$false
    }

    [void] BulkAddNetworks([string]$CourseNumber, [int]$Start, [int]$End) {
        for ($i = $Start; $i -le $End; $i++) {
            $name = "$CourseNumber`_S$i"
            if (-not (Get-VirtualSwitch -Name $name -ErrorAction SilentlyContinue)) {
                $this.AddNetwork($name)
            }
        }
    }

    [void] BulkRemoveNetworks([int]$Start, [int]$End, [string]$CourseNumber) {
        for ($i = $Start; $i -le $End; $i++) {
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

    static [PSCustomObject[]] ListPoweredOn() {
        ConnectTo-VMServer
        return Get-VM | Where-Object PowerState -eq 'PoweredOn' |
               Select-Object Name, @{n='IP'; e={$_.Guest.IPAddress[0]}}
    }

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

    [void] Build() {
        ConnectTo-VMServer
        $folderName = "$($this.ClassFolder)_$($this.Student)"
        $folder = Get-Folder -Name $folderName -ErrorAction SilentlyContinue
        if (-not $folder) {
            $parent = Get-Folder -Name $this.ClassFolder
            $folder = New-Folder -Name $folderName -Location $parent
        }

        New-VM -Name $this.Name -Datastore $this.Datastore `
               -VMHost (Get-VMHost) -Template $this.Template `
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

    [void] PowerOff() {
        ConnectTo-VMServer
        Stop-VM -VM $this.Name -Confirm:$false | Out-Null
    }

    [void] PowerOn() {
        ConnectTo-VMServer
        Start-VM -VM $this.Name -Confirm:$false | Out-Null
    }

    [void] Restart() {
        $this.PowerOff()
        Start-VM -VM $this.Name -Confirm:$false | Out-Null
    }

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
    static [string[]] ListClasses() {
        ConnectTo-VMServer
        $folders = Get-Folder -Name '*' | Select-Object -ExpandProperty Name
        return if ($folders) { $folders } else { @() }
    }

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

    static [void] RemoveCourseVMs([string]$cf, [int]$s, [int]$e) {
        for ($i = $s; $i -le $e; $i++) {
            $folder = "$cf`_S$i"
            Stop-VM -Location $folder -Confirm:$false | Out-Null
            Remove-VM -Location $folder -DeletePermanently -Confirm:$false | Out-Null
            Remove-Folder -Folder (Get-Folder -Name $folder) -Confirm:$false -DeletePermanently | Out-Null
        }
    }
}

# -------------------------------------------------------------------
# 6) SessionReporter & OrphanCleaner
# -------------------------------------------------------------------
class SessionReporter {
    static [void] ExportLoginTimes([string]$path) {
        ConnectTo-VMServer
        $mgr  = Get-View (Get-VIServer).ExtensionData.Content.SessionManager
        $curr = $mgr.CurrentSession.Key

        $list = $mgr.SessionList |
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
# 7) Export Public Members
# -------------------------------------------------------------------
Export-ModuleMember `
    -Function ConnectTo-VMServer `
    -Class VMwareNetwork, VMwareVM, CourseManager, SessionReporter, OrphanCleaner