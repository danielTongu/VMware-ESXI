# Main.ps1
<#
.SYNOPSIS
    VMware Management Console - Main Entry Point
.DESCRIPTION
    Always shows UI even when:
      - Connection fails
      - Login is cancelled
      - Components fail to load
    Integrates dynamic login/logout state and persists connection info.
#>



# UI Theme Configuration - Grayscale with Burgundy accent
Add-Type -AssemblyName 'System.Drawing'

$global:theme = @{  
    Background     = [System.Drawing.Color]::FromArgb(250, 250, 250)  # Very light gray
    Primary        = [System.Drawing.Color]::FromArgb(128, 0, 32)     # Burgundy accent
    Secondary      = [System.Drawing.Color]::FromArgb(160, 160, 160)  # Medium gray
    TextPrimary    = [System.Drawing.Color]::FromArgb(40, 40, 40)     # Dark gray text
    TextSecondary  = [System.Drawing.Color]::FromArgb(120, 120, 120) # Medium gray text
    Success        = [System.Drawing.Color]::FromArgb(80, 80, 80)    # Dark gray (unused)
    Warning        = [System.Drawing.Color]::FromArgb(192, 64, 0)    # Dark orange (unused)
    Error          = [System.Drawing.Color]::FromArgb(180, 0, 0)     # Dark red accent
    CardBackground = [System.Drawing.Color]::White                 # White for panels
    Border         = [System.Drawing.Color]::FromArgb(220, 220, 220) # Light gray border
}



#region CONFIGURATION
# Global configuration and state
$global:VMwareConfig = @{
    Server          = "csvcsa.cs.cwu.edu"
    CredentialPath  = "$env:APPDATA\VMwareManagement\credentials.xml"
    OfflineMode     = $false         # True if connection fails
    Connection      = $null          # Will hold the VIServer connection
    User            = $null          # Logged‐in username
}

# Track authentication state for dynamic login/logout
$global:IsLoggedIn = $false
#endregion




#region DEPENDENCY LOADING
try {
    # Load core models and views (will work in offline mode)
    . "$PSScriptRoot\Models\ConnectTo-VMServer.ps1"
    . "$PSScriptRoot\Views\MainView.ps1"
    . "$PSScriptRoot\Views\LoginView.ps1"

    # Attempt initial connection if credentials exist
    if (Test-Path $global:VMwareConfig.CredentialPath) {
        try {
            $conn = [VMServerConnection]::GetInstance().GetConnection()
            $global:VMwareConfig.Connection = $conn
            $global:VMwareConfig.User       = $conn.User
            Write-Host "Connected to $($conn.Name)" -ForegroundColor Green
        }
        catch {
            $global:VMwareConfig.OfflineMode = $true
            Write-Warning "Initial connection failed: $_ (Continuing in offline mode)"
        }
    }
}
catch {
    Write-Warning "Component load warning: $_ (Some features may be limited)"
}
#endregion





#region APPLICATION START
try {
    # Launch main view, which handles login/logout and shell
    Show-MainView
}
catch {
    # Fallback UI if errors occur
    [System.Windows.Forms.MessageBox]::Show(
        "Limited functionality available:`n$_",
        "Fallback Mode Activated",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )
    # Attempt to show shell directly
    try { Show-MainShell } catch {}
}






finally {
    # Safe cleanup on exit
    try { 
        if ($global:VMwareConfig.Connection) {
            Disconnect-VIServer -Server $global:VMwareConfig.Connection -Confirm:$false
        }
    } catch {}
}
#endregion