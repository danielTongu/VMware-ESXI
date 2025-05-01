<#
.SYNOPSIS
    Dashboard overview inside the content panel.
.DESCRIPTION
    Shows a welcome, connection status, and key vSphere stats.
    Always defines Show-View so Load-ViewIntoPanel will find it.
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Ensure core functions exist
Import-Module "$PSScriptRoot\..\VMwareModels.psm1" -ErrorAction Stop -Force

function Get-DashboardStats {
    <#
    .SYNOPSIS
        Retrieves vSphere stats or throws on failure.
    #>
    ConnectTo-VMServer

    return [PSCustomObject]@{
        Host      = (Get-VMHost).Name
        TotalVMs  = (Get-VM).Count
        PoweredOn = (Get-VM | Where-Object PowerState -eq 'PoweredOn').Count
        Networks  = [VMwareNetwork]::ListNetworks().Count
    }
}

function Show-View {
    <#
    .SYNOPSIS
        Renders the dashboard into the provided panel.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Forms.Panel]$ParentPanel
    )

    # Clear panel
    $ParentPanel.Controls.Clear()

    # Welcome
    $lblWelcome = New-Object System.Windows.Forms.Label
    $lblWelcome.Text     = "Welcome to the VMware ESXi Dashboard"
    $lblWelcome.Font     = New-Object System.Drawing.Font("Segoe UI",14,[System.Drawing.FontStyle]::Bold)
    $lblWelcome.AutoSize = $true
    $lblWelcome.Location = New-Object System.Drawing.Point(20,20)
    $ParentPanel.Controls.Add($lblWelcome)

    # Attempt to get stats
    $connected = $true
    try {
        $stats = Get-DashboardStats
    } catch {
        $connected = $false
        $stats = [PSCustomObject]@{
            Host      = "--"
            TotalVMs  = 0
            PoweredOn = 0
            Networks  = 0
        }
    }

    # Connection status
    $lblStatus = New-Object System.Windows.Forms.Label
    $lblStatus.Text      = "Connection Status: " + ($connected ? "Connected" : "Not Connected")
    $lblStatus.Font      = New-Object System.Drawing.Font("Segoe UI",11,[System.Drawing.FontStyle]::Italic)
    $lblStatus.ForeColor = ($connected ? [System.Drawing.Color]::DarkGreen : [System.Drawing.Color]::DarkRed)
    $lblStatus.AutoSize  = $true
    $lblStatus.Location  = New-Object System.Drawing.Point(20,60)
    $ParentPanel.Controls.Add($lblStatus)

    # Stats header
    $lblHeader = New-Object System.Windows.Forms.Label
    $lblHeader.Text     = "Environment Summary"
    $lblHeader.Font     = New-Object System.Drawing.Font("Segoe UI",12,[System.Drawing.FontStyle]::Bold)
    $lblHeader.AutoSize = $true
    $lblHeader.Location = New-Object System.Drawing.Point(20,100)
    $ParentPanel.Controls.Add($lblHeader)

    # Stats lines
    $lines = @(
        "Connected Host:    $($stats.Host)",
        "Total VMs:         $($stats.TotalVMs)",
        "Powered-On VMs:    $($stats.PoweredOn)",
        "Available Networks:$($stats.Networks)"
    )

    $y = 140
    foreach ($line in $lines) {
        $lbl = New-Object System.Windows.Forms.Label
        $lbl.Text     = $line
        $lbl.Font     = New-Object System.Drawing.Font("Segoe UI",11)
        $lbl.AutoSize = $true
        $lbl.Location = New-Object System.Drawing.Point(30,$y)
        $ParentPanel.Controls.Add($lbl)
        $y += 30
    }
}

# No Export-ModuleMember: MainView will dot-source this and call Show-View