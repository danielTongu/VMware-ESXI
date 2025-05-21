# =============================================================================
# LogsView.ps1   –   CLEAN IMPLEMENTATION
# =============================================================================
#  Prerequisites (defined elsewhere in your application):
#    $script:IsLoggedIn      – Boolean
#    $script:Connection      – Active VIServer (same one used by Dashboard)
#    $script:Theme           – Object with colours: Primary, PrimaryDark,
#                              LightGray, White
# -----------------------------------------------------------------------------

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing



# ---------------------------------------------------------------------------
function Get-LogsData {
<#
.SYNOPSIS
    Retrieve the 100 most-recent vCenter events.

.OUTPUTS
    @{ Events = <array>; LastUpdated = <DateTime> }  —or—  $null
#>
    [CmdletBinding()] param()

    $conn = $script:Connection
    if (-not $conn)             { return $null }

    try   { $events = Get-VIEvent -Server $conn -MaxSamples 100 -ErrorAction Stop }
    catch { Write-Verbose "LogsView: $($_.Exception.Message)"; return $null }

    return @{ Events=$events; LastUpdated=Get-Date }
}



# ---------------------------------------------------------------------------
function New-LogsLayout {
<#
.SYNOPSIS
    Build the EVENT LOGS UI and return all control references.

.OUTPUTS
    Hashtable  (no stray output).
#>
    [CmdletBinding()]
    param([Parameter(Mandatory)][System.Windows.Forms.Panel]$ContentPanel)

    [void]$ContentPanel.SuspendLayout()
    $ContentPanel.Controls.Clear()
    $ContentPanel.BackColor = $script:Theme.LightGray

    # ── root ────────────────────────────────────────────────────────────────
    $root             = [System.Windows.Forms.TableLayoutPanel]::new()
    $root.Dock        = 'Fill'; $root.ColumnCount=1; $root.RowCount=4
    [void]$root.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::AutoSize))
    [void]$root.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::AutoSize))
    [void]$root.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Percent,100))
    [void]$root.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::AutoSize))
    [void]$ContentPanel.Controls.Add($root)

    # ── header ──────────────────────────────────────────────────────────────
    $hdr               = [System.Windows.Forms.Panel]::new()
    $hdr.Height        = 60; $hdr.BackColor=$script:Theme.Primary; $hdr.Dock='Fill'
    [void]$root.Controls.Add($hdr,0,0)

    $title             = [System.Windows.Forms.Label]::new()
    $title.Text        = 'EVENT LOGS'
    $title.Font        = [System.Drawing.Font]::new('Segoe UI',18,[System.Drawing.FontStyle]::Bold)
    $title.ForeColor   = $script:Theme.White; $title.AutoSize=$true
    $title.Location    = [System.Drawing.Point]::new(20,15)
    [void]$hdr.Controls.Add($title)

    # ── filter row ──────────────────────────────────────────────────────────
    $flt               = [System.Windows.Forms.Panel]::new()
    $flt.Height        = 50; $flt.BackColor=$script:Theme.LightGray; $flt.Dock='Fill'
    [void]$root.Controls.Add($flt,0,1)

    $txtFind           = [System.Windows.Forms.TextBox]::new()
    $txtFind.Width     = 300; $txtFind.Height=30
    $txtFind.Location  = [System.Drawing.Point]::new(20,10)
    $txtFind.Font      = [System.Drawing.Font]::new('Segoe UI',10)
    $txtFind.BackColor = $script:Theme.White; $txtFind.ForeColor=$script:Theme.PrimaryDark
    [void]$flt.Controls.Add($txtFind)

    $btnSearch         = [System.Windows.Forms.Button]::new()
    $btnSearch.Text    = 'SEARCH'; $btnSearch.Width=100; $btnSearch.Height=30
    $btnSearch.Font    = [System.Drawing.Font]::new('Segoe UI',10,[System.Drawing.FontStyle]::Bold)
    $btnSearch.BackColor=$script:Theme.Primary; $btnSearch.ForeColor=$script:Theme.White
    $btnSearch.Location=[System.Drawing.Point]::new(330,10)
    [void]$flt.Controls.Add($btnSearch)

    # ── log box ─────────────────────────────────────────────────────────────
    $scroll            = [System.Windows.Forms.Panel]::new()
    $scroll.Dock       = 'Fill'; $scroll.BackColor=$script:Theme.White
    $scroll.Padding    = [System.Windows.Forms.Padding]::new(10)
    $scroll.AutoScroll = $true
    [void]$root.Controls.Add($scroll,0,2)

    $txtLogs           = [System.Windows.Forms.TextBox]::new()
    $txtLogs.Dock      = 'Fill'; $txtLogs.Multiline=$true; $txtLogs.ReadOnly=$true
    $txtLogs.ScrollBars= 'Vertical'
    $txtLogs.BackColor = $script:Theme.White; $txtLogs.ForeColor=$script:Theme.PrimaryDark
    $txtLogs.Font      = [System.Drawing.Font]::new('Segoe UI',10)
    [void]$scroll.Controls.Add($txtLogs)

    # ── buttons row ─────────────────────────────────────────────────────────
    $btnRefresh        = [System.Windows.Forms.Button]::new()
    $btnRefresh.Text   = 'REFRESH'; $btnRefresh.Width=120; $btnRefresh.Height=35
    $btnRefresh.Font   = [System.Drawing.Font]::new('Segoe UI',10,[System.Drawing.FontStyle]::Bold)
    $btnRefresh.BackColor=$script:Theme.Primary; $btnRefresh.ForeColor=$script:Theme.White

    $btnClear          = [System.Windows.Forms.Button]::new()
    $btnClear.Text     = 'CLEAR';  $btnClear.Width=120; $btnClear.Height=35
    $btnClear.Font     = [System.Drawing.Font]::new('Segoe UI',10,[System.Drawing.FontStyle]::Bold)
    $btnClear.BackColor=$script:Theme.LightGray; $btnClear.ForeColor=$script:Theme.PrimaryDark

    $ctrls             = [System.Windows.Forms.FlowLayoutPanel]::new()
    $ctrls.Dock        = 'Fill'; $ctrls.Height=50; $ctrls.Padding=[System.Windows.Forms.Padding]::new(10)
    [void]$ctrls.Controls.AddRange(@($btnRefresh,$btnClear))
    [void]$root.Controls.Add($ctrls,0,3)

    [void]$ContentPanel.ResumeLayout($true)

    return @{
        LogTextBox    = $txtLogs
        SearchBox     = $txtFind
        SearchButton  = $btnSearch
        RefreshButton = $btnRefresh
        ClearButton   = $btnClear
        OriginalLines = @()                    # cache for filter restore
        ContentPanel  = $ContentPanel          # needed for Refresh handler
    }
}



# ---------------------------------------------------------------------------
function Update-LogsWithData {
<#
.SYNOPSIS
    Populates the log box and wires SEARCH / CLEAR / REFRESH buttons.
#>
    [CmdletBinding()]
    param([hashtable]$UiRefs, [hashtable]$Data)

    # Store the original lines in the script scope
    $script:OriginalLogLines = foreach ($ev in $Data.Events) {
        $ts = $ev.CreatedTime.ToString('G')
        $usr = if ($ev.UserName) { $ev.UserName } else { 'N/A' }
        "[$ts] ($usr) $($ev.FullFormattedMessage)"
    }

    $UiRefs.LogTextBox.Text = $script:OriginalLogLines -join "`r`n"

    # ---------- SEARCH -------------------------------------------------------
    $UiRefs.SearchButton.Add_Click({
        try {
            $term = $script:LogsUiRefs.SearchBox.Text.Trim()
            if ($term) {
                $filteredLines = $script:OriginalLogLines | Where-Object { $_ -match [regex]::Escape($term) }
                $script:LogsUiRefs.LogTextBox.Text = $filteredLines -join "`r`n"
            }
            else {
                $script:LogsUiRefs.LogTextBox.Text = $script:OriginalLogLines -join "`r`n"
            }
        }
        catch { 
            # Error handling
            [System.Windows.Forms.MessageBox]::Show(
                "Search error: $_",
                "Error",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
        }
    })

    # ---------- CLEAR --------------------------------------------------------
    $UiRefs.ClearButton.Add_Click({
        $script:LogsUiRefs.SearchBox.Clear()
        $script:LogsUiRefs.LogTextBox.Text = $script:OriginalLogLines -join "`r`n"
    })

   # ---------- REFRESH (rebuilds entire view) ------------------------------
    $UiRefs.RefreshButton.Add_Click({
    # Dot-source the script to reload the function definitions
    . $PSScriptRoot\LogsView.ps1
    
    # Use the stored content panel reference
    if ($script:LogsContentPanel) {
        Show-LogsView -ContentPanel $script:LogsContentPanel
    } else {
        # Error handling in case the reference is lost
        [System.Windows.Forms.MessageBox]::Show(
            "Content panel reference was lost. Please navigate back to this view.",
            "Refresh Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
    }
})
}



# ---------------------------------------------------------------------------
function global:Show-LogsView {
<#
.SYNOPSIS
    Entry point: draw or refresh the Logs view.
#>
    [CmdletBinding()]
    param([Parameter(Mandatory)][System.Windows.Forms.Panel]$ContentPanel)

    # Store references in script scope
    $script:LogsContentPanel = $ContentPanel
    $script:LogsUiRefs = New-LogsLayout -ContentPanel $ContentPanel
    $data = Get-LogsData

    if ($data) {
        Update-LogsWithData -UiRefs $script:LogsUiRefs -Data $data
    }
    else {
        $script:LogsUiRefs.LogTextBox.Text = 'No log data available or not connected.'
    }
}
