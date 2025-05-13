<#
.SYNOPSIS
    Represents a VMware virtual machine with management capabilities, resilient to offline or disconnected states.
.DESCRIPTION
    Provides methods to create, configure network, power on/off, remove, and query power state of a VM.
    Each operation safely handles offline mode by checking $global:VMwareConfig.OfflineMode and using the shared connection.
.NOTES
    Uses $global:VMwareConfig.Connection and $global:VMwareConfig.OfflineMode flags.
#>

class VMwareVM {
    [string]$Name
    [string]$Folder
    [string]$Template
    [string]$Datastore
    [string[]]$Adapters
    [string]$Customization

    <#
    .SYNOPSIS
        Initializes a new VMwareVM object.
    .PARAMETER Name
        The VM name.
    .PARAMETER Folder
        The target folder or resource pool path.
    .PARAMETER Template
        Template to clone from.
    .PARAMETER Datastore
        Datastore name.
    .PARAMETER Adapters
        Network port groups.
    .PARAMETER Customization
        OS customization spec (optional).
    #>
    VMwareVM(
        [string]$Name,
        [string]$Folder,
        [string]$Template,
        [string]$Datastore,
        [string[]]$Adapters,
        [string]$Customization = $null
    ) {
        $this.Name          = $Name
        $this.Folder        = $Folder
        $this.Template      = $Template
        $this.Datastore     = $Datastore
        $this.Adapters      = $Adapters
        $this.Customization = $Customization
    }

    <#
    .SYNOPSIS
        Retrieves the shared server connection or sets offline mode.
    .OUTPUTS
        VMware vSphere server connection, or $null if offline.
    #>
    hidden [object] GetConnectionSafe() {
        if ($null -ne $global:VMwareConfig.Connection) {
            return $global:VMwareConfig.Connection
        }
        try {
            # Fallback to singleton if needed
            $conn = [VMServerConnection]::GetInstance().GetConnection()
            $global:VMwareConfig.Connection = $conn
            return $conn
        }
        catch {
            $global:VMwareConfig.OfflineMode = $true
            Write-Warning "Connection failed: $_"
            return $null
        }
    }

    <#
    .SYNOPSIS
        Creates the VM from a template and configures its network.
    #>
    [void] Create() {
        $conn = GetConnectionSafe
        if ($null -eq $conn) { return }
        try {
            $vmHost = Get-VMHost -Server $conn -ErrorAction Stop | Select-Object -First 1
            $params = @{
                Name            = $this.Name
                Datastore       = $this.Datastore
                VMHost          = $vmHost
                Template        = $this.Template
                Location        = $this.Folder
                Server          = $conn
            }
            if ($this.Customization) { $params.OSCustomizationSpec = $this.Customization }

            New-VM @params | Out-Null
            $this.ConfigureNetwork()
        }
        catch {
            Write-Warning "Create VM failed for '$($this.Name)': $_"
        }
    }

    <#
    .SYNOPSIS
        Configures network adapters on the VM.
    #>
    hidden [void] ConfigureNetwork() {
        $conn = GetConnectionSafe
        if ($null -eq $conn) { return }
        try {
            $vm = Get-VM -Name $this.Name -Server $conn -ErrorAction Stop
            $i = 1
            foreach ($pg in $this.Adapters) {
                $adapterName = "Network Adapter $i"
                $adapter = Get-NetworkAdapter -VM $vm -Name $adapterName -Server $conn -ErrorAction SilentlyContinue
                if ($adapter) {
                    Set-NetworkAdapter -NetworkAdapter $adapter -PortGroup $pg -Confirm:$false -Server $conn | Out-Null
                }
                $i++
            }
        }
        catch {
            Write-Warning "ConfigureNetwork failed for '$($this.Name)': $_"
        }
    }

    <#
    .SYNOPSIS
        Powers on the VM.
    #>
    [void] PowerOn() {
        $conn = GetConnectionSafe
        if ($null -eq $conn) { return }
        try {
            Start-VM -VM $this.Name -Server $conn -Confirm:$false | Out-Null
        }
        catch {
            Write-Warning "PowerOn failed for '$($this.Name)': $_"
        }
    }

    <#
    .SYNOPSIS
        Powers off the VM.
    #>
    [void] PowerOff() {
        $conn = GetConnectionSafe
        if ($null -eq $conn) { return }
        try {
            Stop-VM -VM $this.Name -Server $conn -Confirm:$false | Out-Null
        }
        catch {
            Write-Warning "PowerOff failed for '$($this.Name)': $_"
        }
    }

    <#
    .SYNOPSIS
        Removes the VM, powering off first if necessary.
    #>
    [void] Remove() {
        $conn = GetConnectionSafe
        if ($null -eq $conn) { return }
        try {
            $vm = Get-VM -Name $this.Name -Server $conn -ErrorAction SilentlyContinue
            if ($vm) {
                if ($vm.PowerState -eq 'PoweredOn') { $this.PowerOff() }
                Remove-VM -VM $vm -DeletePermanently -Confirm:$false -Server $conn | Out-Null
            }
        }
        catch {
            Write-Warning "Remove VM failed for '$($this.Name)': $_"
        }
    }

    <#
    .SYNOPSIS
        Returns the current power state, or 'NotFound'.
    .OUTPUTS
        String
    #>
    [string] GetPowerState() {
        $conn = GetConnectionSafe
        if ($null -eq $conn) { return 'Offline' }
        try {
            $vm = Get-VM -Name $this.Name -Server $conn -ErrorAction SilentlyContinue
            if ($vm) { return $vm.PowerState.ToString() }
        }
        catch {
            Write-Warning "GetPowerState failed for '$($this.Name)': $_"
        }
        return 'NotFound'
    }
}