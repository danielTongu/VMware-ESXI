<#
.SYNOPSIS
    Dashboard overview inside the content panel.
.DESCRIPTION
    Shows a welcome, connection status, key vSphere stats, and system time.
    Always defines Show-View so Load-ViewIntoPanel will find it.
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Load VMware core models
Import-Module "$PSScriptRoot\..\VMwareModels.psm1" -ErrorAction Stop -Force

function Get-DashboardStats {
    ConnectTo-VMServer

    return [PSCustomObject]@{
        Host      = (Get-VMHost).Name
        TotalVMs  = (Get-VM).Count
        PoweredOn = (Get-VM | Where-Object PowerState -eq 'PoweredOn').Count
        Networks  = [VMwareNetwork]::ListNetworks().Count
    }
}

function Show-View {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Forms.Panel]$ParentPanel
    )

    # Clear and prepare
    $ParentPanel.Controls.Clear()

    # Title
    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Text     = "Welcome to the VMware ESXi Dashboard"
    $lblTitle.Font     = New-Object System.Drawing.Font("Segoe UI",14,[System.Drawing.FontStyle]::Bold)
    $lblTitle.AutoSize = $true
    $lblTitle.Location = New-Object System.Drawing.Point(20,20)
    $ParentPanel.Controls.Add($lblTitle)

    # Try fetching environment stats
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

    # Connection Status
    $lblStatus = New-Object System.Windows.Forms.Label
    $lblStatus.Text      = "Connection Status: " + ($(if ($connected) { "Connected" } else { "Not Connected" }))
    $lblStatus.Font      = New-Object System.Drawing.Font("Segoe UI",11,[System.Drawing.FontStyle]::Italic)
    if ($connected) {
        $lblStatus.ForeColor = [System.Drawing.Color]::DarkGreen
    } else {
        $lblStatus.ForeColor = [System.Drawing.Color]::DarkRed
    }
    $lblStatus.AutoSize  = $true
    $lblStatus.Location  = New-Object System.Drawing.Point(20,60)
    $ParentPanel.Controls.Add($lblStatus)

    # Section Header
    $lblHeader = New-Object System.Windows.Forms.Label
    $lblHeader.Text     = "Environment Summary"
    $lblHeader.Font     = New-Object System.Drawing.Font("Segoe UI",12,[System.Drawing.FontStyle]::Bold)
    $lblHeader.AutoSize = $true
    $lblHeader.Location = New-Object System.Drawing.Point(20,100)
    $ParentPanel.Controls.Add($lblHeader)

    # Key Stats
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

    # System Clock
    $lblTime = New-Object System.Windows.Forms.Label
    $lblTime.Text     = "System Time: " + (Get-Date -Format "f")
    $lblTime.Font     = New-Object System.Drawing.Font("Segoe UI",10,[System.Drawing.FontStyle]::Italic)
    $lblTime.AutoSize = $true
    $lblTime.Location = New-Object System.Drawing.Point(30, $y + 10)
    $ParentPanel.Controls.Add($lblTime)
}
