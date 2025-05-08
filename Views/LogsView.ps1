<#
.SYNOPSIS
    UI view for displaying VMware events/logs.
.DESCRIPTION
    Provides a PowerShell Forms interface to:
      - Refresh and view the latest events from the vCenter or ESXi host
      - Display logs in a multiline text box with timestamp and message
    Honors global login and offline state; no-ops when disconnected.
.PARAMETER ContentPanel
    The Panel control in which to render this view.
#>
function Show-LogsView {
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.Forms.Panel]$ContentPanel
    )

    # Clear existing content
    $ContentPanel.Controls.Clear()

    # Layout: title, controls, log display
    $layout = New-Object System.Windows.Forms.TableLayoutPanel
    $layout.Dock      = 'Fill'
    $layout.RowCount  = 3
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'Absolute', 30))  # Title
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'Absolute', 40))  # Controls
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle 'Percent', 100))  # Log text box
    $ContentPanel.Controls.Add($layout)

    # Title label
    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Text      = 'Event Logs'
    $lblTitle.Dock      = 'Fill'
    $lblTitle.Font      = New-Object System.Drawing.Font('Segoe UI',14,[System.Drawing.FontStyle]::Bold)
    $lblTitle.ForeColor = [System.Drawing.Color]::Black
    $lblTitle.TextAlign = 'MiddleCenter'
    $layout.Controls.Add($lblTitle,0,0)

    # Controls panel
    $controls = New-Object System.Windows.Forms.FlowLayoutPanel
    $controls.Dock          = 'Fill'
    $controls.FlowDirection = 'LeftToRight'
    $controls.WrapContents  = $false
    $controls.Padding       = '10,5,10,5'
    $layout.Controls.Add($controls,0,1)

    # Refresh button
    $btnRefresh = New-Object System.Windows.Forms.Button
    $btnRefresh.Text     = 'Refresh Logs'
    $btnRefresh.AutoSize = $true
    $controls.Controls.Add($btnRefresh)

    # Clear button
    $btnClear = New-Object System.Windows.Forms.Button
    $btnClear.Text     = 'Clear'
    $btnClear.AutoSize = $true
    $controls.Controls.Add($btnClear)

    # Log display text box
    $txtLogs = New-Object System.Windows.Forms.TextBox
    $txtLogs.Dock       = 'Fill'
    $txtLogs.Multiline  = $true
    $txtLogs.ScrollBars = 'Vertical'
    $txtLogs.ReadOnly   = $true
    $layout.Controls.Add($txtLogs,0,2)

    <#
    .SYNOPSIS
        Loads the latest VMware events into the text box.
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

    # Event handlers
    $btnRefresh.Add_Click({ Load-Logs })
    $btnClear.Add_Click({ $txtLogs.Clear() })

    # Initial load
    Load-Logs
}
