<#
.SYNOPSIS
    Displays a welcome dashboard with environment stats.
.DESCRIPTION
    This view summarizes the vSphere environment:
      - Connected host
      - Number of total & powered-on VMs
      - Count of virtual networks (port groups)
    It renders inside the provided panel — not a standalone window.
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Import core models if not already present
if (-not (Get-Command ConnectTo-VMServer -ErrorAction SilentlyContinue)) {
    Import-Module "$PSScriptRoot\..\VMwareModels.psm1" -ErrorAction Stop
}

# -------------------------------------------------------------------
# Helper: Gathers and returns environment statistics
# -------------------------------------------------------------------
function Get-DashboardStats {
    ConnectTo-VMServer

    $hostName     = (Get-VMHost).Name
    $totalVMs     = (Get-VM).Count
    $poweredOnVMs = (Get-VM | Where-Object PowerState -eq 'PoweredOn').Count
    $networkCount = [VMwareNetwork]::ListNetworks().Count

    return [PSCustomObject]@{
        Host      = $hostName
        TotalVMs  = $totalVMs
        PoweredOn = $poweredOnVMs
        Networks  = $networkCount
    }
}

# -------------------------------------------------------------------
# Renders the dashboard view inside the given UI panel
# -------------------------------------------------------------------
function Show-View {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [System.Windows.Forms.Panel]$ParentPanel
    )

    # Clear any previous controls
    $ParentPanel.Controls.Clear()

    try {
        $stats = Get-DashboardStats
    } catch {
        $errLabel = New-Object Windows.Forms.Label
        $errLabel.Text = "Failed to retrieve stats: $_"
        $errLabel.ForeColor = 'Red'
        $errLabel.AutoSize = $true
        $errLabel.Location = New-Object Drawing.Point(20, 20)
        $ParentPanel.Controls.Add($errLabel)
        return
    }

    # Header
    $header = New-Object Windows.Forms.Label
    $header.Text = "VMware Dashboard Overview"
    $header.Font = New-Object Drawing.Font("Segoe UI", 16, [Drawing.FontStyle]::Bold)
    $header.AutoSize = $true
    $header.Location = New-Object Drawing.Point(20, 20)
    $ParentPanel.Controls.Add($header)

    # Info display
    $lines = @(
        "Connected Host:   $($stats.Host)",
        "Total VMs:        $($stats.TotalVMs)",
        "Powered-On VMs:   $($stats.PoweredOn)",
        "Available Networks: $($stats.Networks)"
    )

    $y = 70
    foreach ($line in $lines) {
        $lbl = New-Object Windows.Forms.Label
        $lbl.Text = $line
        $lbl.Font = New-Object Drawing.Font("Segoe UI", 11)
        $lbl.Location = New-Object Drawing.Point(30, $y)
        $lbl.AutoSize = $true
        $ParentPanel.Controls.Add($lbl)
        $y += 35
    }
}

Export-ModuleMember -Function Show-View