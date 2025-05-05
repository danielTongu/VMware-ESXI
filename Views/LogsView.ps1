Add-Type -AssemblyName 'System.Windows.Forms'
Add-Type -AssemblyName 'System.Drawing'

<##
.SYNOPSIS
    UI view for displaying VMware events/logs, resilient to auth/offline states.
.DESCRIPTION
    Provides a PowerShell Forms interface to:
      - Refresh and view the latest events from the vCenter or ESXi host
      - Display logs in a multiline, scrollable text box with timestamp and user
    Honors global login and offline state; no-ops when disconnected.
.PARAMETER ContentPanel
    The Panel control in which to render this view.
.EXAMPLE
    Show-LogsView -ContentPanel $split.Panel2
#>
function Show-LogsView {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [System.Windows.Forms.Panel]$ContentPanel
    )

    <#
    .SYNOPSIS
        Returns a valid VMware connection or $null if offline/not authenticated.
    #>
    function Get-ConnectionSafe {
        if (-not $global:IsLoggedIn) {
            Write-Warning 'Not logged in: cannot load logs.'
            return $null
        }
        if ($global:VMwareConfig.OfflineMode -or -not $global:VMwareConfig.Connection) {
            Write-Warning 'Offline mode: cannot establish connection.'
            return $null
        }
        return $global:VMwareConfig.Connection
    }

    # Clear existing UI and apply background theme
    $ContentPanel.Controls.Clear()
    $ContentPanel.BackColor = $global:theme.Background

    # Setup layout panel: title, controls, log display
    $layout = New-Object System.Windows.Forms.TableLayoutPanel
    $layout.Dock      = 'Fill'
    $layout.BackColor = $global:theme.Background
    $layout.RowCount  = 3
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 30)))
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 40)))
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    $ContentPanel.Controls.Add($layout)

    # Title label
    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Text      = 'Event Logs'
    $lblTitle.Dock      = 'Fill'
    $lblTitle.Font      = New-Object System.Drawing.Font('Segoe UI',14,[System.Drawing.FontStyle]::Bold)
    $lblTitle.ForeColor = $global:theme.Primary
    $lblTitle.TextAlign = 'MiddleCenter'
    $lblTitle.BackColor = $global:theme.Background
    $layout.Controls.Add($lblTitle,0,0)

    # Controls panel for buttons
    $controls = New-Object System.Windows.Forms.FlowLayoutPanel
    $controls.Dock          = 'Fill'
    $controls.FlowDirection = 'LeftToRight'
    $controls.WrapContents  = $false
    $controls.Padding       = '10,5,10,5'
    $controls.BackColor     = $global:theme.Background
    $layout.Controls.Add($controls,0,1)

    # Refresh Logs button
    $btnRefresh = New-Object System.Windows.Forms.Button
    $btnRefresh.Text      = 'Refresh Logs'
    $btnRefresh.Font      = New-Object System.Drawing.Font('Segoe UI',11)
    $btnRefresh.BackColor = $global:theme.Secondary
    $btnRefresh.ForeColor = $global:theme.CardBackground
    $btnRefresh.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $controls.Controls.Add($btnRefresh)

    # Clear Logs button
    $btnClear = New-Object System.Windows.Forms.Button
    $btnClear.Text      = 'Clear'
    $btnClear.Font      = New-Object System.Drawing.Font('Segoe UI',11)
    $btnClear.BackColor = $global:theme.Secondary
    $btnClear.ForeColor = $global:theme.CardBackground
    $btnClear.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $controls.Controls.Add($btnClear)

    # Log display textbox
    $txtLogs = New-Object System.Windows.Forms.TextBox
    $txtLogs.Dock       = 'Fill'
    $txtLogs.Multiline  = $true
    $txtLogs.ScrollBars = 'Vertical'
    $txtLogs.ReadOnly   = $true
    $txtLogs.BackColor  = $global:theme.CardBackground
    $txtLogs.ForeColor  = $global:theme.TextPrimary
    $txtLogs.Font       = New-Object System.Drawing.Font('Segoe UI',10)
    $layout.Controls.Add($txtLogs,0,2)

    <#
    .SYNOPSIS
        Loads the latest VMware events into the log textbox.
    .NOTES
        Retrieves up to 100 events; formats timestamp, user, and message.
    #>
    function Load-Logs {
        $txtLogs.Clear()
        $conn = Get-ConnectionSafe
        if ($null -eq $conn) {
            $txtLogs.Text = "Offline or not logged in."
            return
        }
        try {
            # Retrieve the latest 100 events
            $events = Get-VIEvent -Server $conn -MaxSamples 100 -ErrorAction Stop
            foreach ($ev in $events) {
                $timestamp = $ev.CreatedTime.ToString('G')
                $user      = if ($ev.UserName) { $ev.UserName } else { 'N/A' }
                $message   = $ev.FullFormattedMessage
                $txtLogs.AppendText("[$timestamp] ($user) $message`r`n")
            }
        }
        catch {
            $txtLogs.AppendText("Failed to load logs: $_`r`n")
        }
    }

    # Wire up button events
    $btnRefresh.Add_Click({ Load-Logs })
    $btnClear.Add_Click({ $txtLogs.Clear() })

    # Initial log load
    Load-Logs
}
