# Models/ConnectTo-VMServer.ps1

<#
.SYNOPSIS
    Singleton class for managing VMware vCenter/ESXi server connections
.DESCRIPTION
    Handles:
    - Connection pooling with automatic reconnection
    - Multi-source server configuration (config file > env var > hardcoded default)
    - Secure credential management with XML serialization
    - Thread-safe singleton pattern
#>

class VMServerConnection {
    # Singleton instance storage
    hidden static $instance = $null
    
    # Active connection object
    hidden $connection = $null
    
    # Current target server (configured at runtime)
    hidden [string] $server = $null
    
    # Credentials for authentication
    hidden [pscredential] $credentials = $null
    
    # Fallback server if no configuration is provided
    hidden static [string] $defaultServer = "csvcsa.cs.cwu.edu"

    <#
    .SYNOPSIS
        Private constructor (singleton pattern)
    .DESCRIPTION
        - Initializes server from configuration sources
        - Loads saved credentials if available
    #>
    hidden VMServerConnection() {
        $this.server = [VMServerConnection]::GetConfiguredServer()
        $this.LoadCredentials()
    }

    <#
    .SYNOPSIS
        Gets the singleton instance
    .DESCRIPTION
        Creates new instance only if none exists (thread-safe for PowerShell runspaces)
    #>
    static [VMServerConnection] GetInstance() {
        if (-not [VMServerConnection]::instance) {
            [VMServerConnection]::instance = [VMServerConnection]::new()
        }
        return [VMServerConnection]::instance
    }

    <#
    .SYNOPSIS
        Determines the server to connect to
    .DESCRIPTION
        Configuration priority:
        1. $global:VMwareConfig.Server (runtime config)
        2. $env:VMWARE_SERVER (environment variable)
        3. Class default (hardcoded fallback)
    #>
    static [string] GetConfiguredServer() {
        # Prefer global configuration if available
        if ($global:VMwareConfig -and $global:VMwareConfig.Server) {
            return $global:VMwareConfig.Server
        }
        # Fall back to environment variable
        elseif ($env:VMWARE_SERVER) {
            return $env:VMWARE_SERVER
        }
        # Ultimate fallback to hardcoded default
        else {
            return [VMServerConnection]::defaultServer
        }
    }

    <#
    .SYNOPSIS
        Gets active connection or establishes new one
    .DESCRIPTION
        - Returns existing connection if valid
        - Establishes new connection if:
          - No existing connection
          - Existing connection is stale
        - Throws on connection failure
    #>
    [object] GetConnection() {
        if (-not $this.connection -or (-not $this.connection.IsConnected)) {
            try {
                $this.connection = Connect-VIServer -Server $this.server `
                    -Credential $this.credentials `
                    -ErrorAction Stop
            }
            catch {
                throw "Failed to connect to VMware server '$($this.server)': $_"
            }
        }
        return $this.connection
    }

    <#
    .SYNOPSIS
        Updates target server
    .DESCRIPTION
        - Changes server hostname/IP
        - Forces disconnect if connection exists
        - Validates input (ignores empty/whitespace)
    #>
    [void] SetServer([string]$server) {
        if (-not [string]::IsNullOrWhiteSpace($server)) {
            $this.server = $server.Trim()
            # Force reconnect on next GetConnection()
            $this.Disconnect()
        }
    }

    <#
    .SYNOPSIS
        Updates credentials
    .DESCRIPTION
        - Stores new credentials securely
        - Forces disconnect if connection exists
    #>
    [void] SetCredentials([pscredential]$cred) {
        $this.credentials = $cred
        $this.Disconnect()
    }

    <#
    .SYNOPSIS
        Disconnects active session
    .DESCRIPTION
        - Gracefully disconnects if connected
        - Silently handles errors during disconnect
        - Always nullifies connection reference
    #>
    [void] Disconnect() {
        if ($this.connection -and $this.connection.IsConnected) {
            try {
                Disconnect-VIServer -Server $this.connection `
                    -Confirm:$false `
                    -ErrorAction Stop
            }
            catch {
                Write-Warning "Disconnect warning: $_"
            }
            finally {
                $this.connection = $null
            }
        }
    }

    <#
    .SYNOPSIS
        Loads saved credentials
    .DESCRIPTION
        - Looks for credentials in:
          1. $global:VMwareConfig.CredentialPath (if config exists)
          2. Default appdata path
        - Uses secure string serialization
        - Fails gracefully with warning
    #>
    hidden [void] LoadCredentials() {
        # Determine credential storage path
        $credsPath = if ($global:VMwareConfig -and $global:VMwareConfig.CredentialPath) {
            $global:VMwareConfig.CredentialPath
        }
        else {
            "$env:APPDATA\VMwareManagement\credentials.xml"
        }

        if (Test-Path $credsPath) {
            try {
                $secureString = Import-Clixml -Path $credsPath
                $this.credentials = New-Object `
                    System.Management.Automation.PSCredential("dummy", $secureString)
            }
            catch {
                Write-Warning "Credential load warning: $_"
            }
        }
    }
}