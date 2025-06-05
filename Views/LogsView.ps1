# ---------------------------------------------------------------------------
# Load WinForms assemblies
# ---------------------------------------------------------------------------
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing


function global:Show-LogsView {
    <#
    .SYNOPSIS
        Entry point for displaying or refreshing the Logs view.

    .DESCRIPTION
        Builds (or rebuilds) the Logs UI, directly retrieves the latest
        vCenter events, and sends them to the view. 
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Forms.Panel] $ContentPanel
    )

    # Re/-create the UI and store references.
    $script:Refs = New-LogsLayout -ContentPanel $ContentPanel

    # Tell the user we are working.
    Set-StatusMessage -Message 'Loading event logs...' -Type 'Info'
    [System.Windows.Forms.Application]::DoEvents()   # flush UI

    # ── Retrieve the 100 most recent vCenter events ────────────────────────
    $script:eventCount = 100
    $events = $null
    if (-not $script:Connection) {
        Set-StatusMessage -Message 'No connection to vCenter.' -Type 'Error'
    } else {
        $events = Get-VIEvent -Server $script:Connection -MaxSamples $eventCount -ErrorAction Stop
        Set-StatusMessage -Message "Loaded first $script:eventCount events." -Type 'Success'
    }

    # ── Display the logs ───────────────────────────────────────────────────
    if ($events) {
        Update-LogsWithData -Events $events
    } else {
        Set-StatusMessage -Message 'Weird, we have no events.' -Type 'Error'
    }
}


function New-LogsLayout {
    <#
    .SYNOPSIS
        Builds the EVENT LOGS UI and returns all control references.
    .OUTPUTS
        Hashtable containing references to all relevant UI controls.
    #>

    [CmdletBinding()]
    param([Parameter(Mandatory)][System.Windows.Forms.Panel]$ContentPanel)

    $ContentPanel.Controls.Clear()
    $ContentPanel.BackColor = $script:Theme.LightGray
    $Refs = @{ ContentPanel = $ContentPanel }

    # ── root ────────────────────────────────────────────────────────────────
    $root = [System.Windows.Forms.TableLayoutPanel]::new()
    $root.Dock = 'Fill'
    $root.ColumnCount = 1
    $root.RowCount = 5
    $root.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::AutoSize))
    $root.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::AutoSize))
    $root.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Percent, 100))
    $root.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::AutoSize))
    $root.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::AutoSize))
    $ContentPanel.Controls.Add($root)

    # ── header ──────────────────────────────────────────────────────────────
    $hdr = [System.Windows.Forms.Panel]::new()
    $hdr.Height = 80
    $hdr.BackColor = $script:Theme.Primary
    $hdr.Dock = 'Fill'
    $root.Controls.Add($hdr, 0, 0)

    $title = [System.Windows.Forms.Label]::new()
    $title.Text = 'EVENT LOGS'
    $title.Font = [System.Drawing.Font]::new('Segoe UI', 18, [System.Drawing.FontStyle]::Bold)
    $title.ForeColor = $script:Theme.White
    $title.AutoSize = $true
    $title.Location = [System.Drawing.Point]::new(20, 15)
    $hdr.Controls.Add($title)

    # refresh label
    $lblRefresh = New-Object System.Windows.Forms.Label
    $lblRefresh.Name = 'LastRefreshLabel'
    $lblRefresh.Text = "Last refresh: $(Get-Date -Format 'HH:mm:ss tt')"
    $lblRefresh.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $lblRefresh.ForeColor = $script:Theme.White
    $lblRefresh.Location = [System.Drawing.Point]::new(20,50)
    $lblRefresh.AutoSize = $true
    $hdr.Controls.Add($lblRefresh)
    $Refs['LastRefreshLabel'] = $lblRefresh

    # ── filter row ──────────────────────────────────────────────────────────
    $flt = [System.Windows.Forms.Panel]::new()
    $flt.Height = 50
    $flt.BackColor = $script:Theme.LightGray
    $flt.Dock = 'Fill'
    $root.Controls.Add($flt, 0, 1)

    $txtFind = [System.Windows.Forms.TextBox]::new()
    $txtFind.Width = 300
    $txtFind.Height = 30
    $txtFind.Location = [System.Drawing.Point]::new(20, 10)
    $txtFind.Font = [System.Drawing.Font]::new('Segoe UI', 10)
    $txtFind.BackColor = $script:Theme.White
    $txtFind.ForeColor = $script:Theme.PrimaryDark
    $flt.Controls.Add($txtFind)
    $Refs['SearchBox'] = $txtFind

    $btnSearch = New-FormButton -Name 'btnSearch' -Text 'SEARCH' -Size (New-Object System.Drawing.Size(100, 30))
    $btnSearch.Location = [System.Drawing.Point]::new(330, 10)
    $flt.Controls.Add($btnSearch)
    $Refs['SearchButton'] = $btnSearch

    # ── log box ─────────────────────────────────────────────────────────────
    $scroll = [System.Windows.Forms.Panel]::new()
    $scroll.Dock = 'Fill'
    $scroll.BackColor = $script:Theme.White
    $scroll.Padding = [System.Windows.Forms.Padding]::new(10)
    $scroll.AutoScroll = $true
    $root.Controls.Add($scroll, 0, 2)

    $txtLogs = [System.Windows.Forms.TextBox]::new()
    $txtLogs.Dock = 'Fill'
    $txtLogs.Multiline = $true
    $txtLogs.ReadOnly = $true
    $txtLogs.ScrollBars = 'Vertical'
    $txtLogs.BackColor = $script:Theme.White
    $txtLogs.ForeColor = $script:Theme.PrimaryDark
    $txtLogs.Font = [System.Drawing.Font]::new('Segoe UI', 10)
    $scroll.Controls.Add($txtLogs)
    $Refs['LogTextBox'] = $txtLogs

    # ── buttons row ─────────────────────────────────────────────────────────
    $btnRefresh = New-FormButton -Name 'btnRefresh' -Text 'REFRESH'
    $Refs['RefreshButton'] = $btnRefresh

    $btnClear = New-FormButton -Name 'btnClear' -Text 'CLEAR'
    $Refs['ClearButton'] = $btnClear

    $ctrls = [System.Windows.Forms.FlowLayoutPanel]::new()
    $ctrls.Dock = 'Fill'
    $ctrls.Autosize = $true
    $ctrls.Padding = [System.Windows.Forms.Padding]::new(10)
    $ctrls.Controls.AddRange(@($btnRefresh, $btnClear))
    $root.Controls.Add($ctrls, 0, 3)

    # ── Footer status label  ──────────────────────────────────────────────────
    $footer = New-Object System.Windows.Forms.Panel
    $footer.Dock = 'Fill'
    $footer.Autosize = $true
    $footer.AutoScroll = $true
    $root.Controls.Add($footer, 0, 5)

    $statusLabel = New-Object System.Windows.Forms.Label
    $statusLabel.Dock = 'Fill'
    $statusLabel.AutoSize = $true
    $statusLabel.Name = 'StatusLabel'
    $statusLabel.Text = 'Ready'
    $statusLabel.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
    $statusLabel.ForeColor = $script:Theme.PrimaryDarker
    $footer.Controls.Add($statusLabel)
    $Refs['StatusLabel'] =  $statusLabel

    return $Refs
}


function Update-LogsWithData {
    <#
    .SYNOPSIS
        Populates the Logs view and wires SEARCH / CLEAR / REFRESH buttons.

    .DESCRIPTION
        Accepts an **array of vCenter event objects** and:
        1. Formats them into readable text lines.
        2. Displays the lines in the multiline textbox.
        3. Updates the “Last refresh” label.
        4. Connects the three UI buttons (Search, Clear, Refresh).

    .PARAMETER Events
        The event objects to display (output of `Get-VIEvent`).
    #>

    [CmdletBinding()]
    param([Parameter(Mandatory)][array]$Events)

    # ── Header timestamp ───────────────────────────────────────────────────
    $script:Refs.LastRefreshLabel.Text = "Last refresh: $(Get-Date -Format 'HH:mm:ss tt')"

    # ── Build and cache the original log text ──────────────────────────────
    $script:OriginalLogLines = foreach ($ev in $Events) {
        $ts  = $ev.CreatedTime.ToString('G')
        $usr = if ($ev.UserName) { $ev.UserName } else { 'N/A' }
        "[$ts] ($usr) $($ev.FullFormattedMessage)"
    }

    $script:Refs.LogTextBox.Text = $script:OriginalLogLines -join "`r`n"

    # ───────────────────── Button Event Handlers ───────────────────────────

    # When the user presses Enter while the cursor is in the Search textbox,
    # run the SEARCH button’s click handler (and suppress the default beep).
    $script:Refs.SearchBox.Add_KeyDown({
        param($sender, $e)                 # $e = KeyEventArgs
        . $PSScriptRoot\LogsView.ps1       # bring helpers into scope

        if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
            $e.SuppressKeyPress = $true    # stop the ding sound
            $script:Refs.SearchButton.PerformClick()
        }
    })

    # SEARCH
    $script:Refs.SearchButton.Add_Click({
        . $PSScriptRoot\LogsView.ps1
        try {
            $term = $script:Refs.SearchBox.Text.Trim()
            if ($term) {
                # Build a regex that always ignores case
                $pattern = [regex]::Escape($term)
                $regex   = [regex]::new( $pattern,[System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
                $filteredLines = $script:OriginalLogLines | Where-Object { $regex.IsMatch($_) }
                $script:Refs.LogTextBox.Text = $filteredLines -join "`r`n"
                Set-StatusMessage -Message "Showing '$term'" -Type 'Success'
            } else {
                # Empty search string → restore full list
                $script:Refs.LogTextBox.Text = $script:OriginalLogLines -join "`r`n"
                Set-StatusMessage -Message "Loaded first $script:eventCount events." -Type 'Success'
            }
        }
        catch {
            Set-StatusMessage -Message "Search error: $_" -Type 'Error'
        }
    })


    # CLEAR
    $script:Refs.ClearButton.Add_Click({
        . $PSScriptRoot\LogsView.ps1
        Set-StatusMessage -Message 'Cleared field' -Type 'Success'
        $script:Refs.SearchBox.Clear()
        $script:Refs.LogTextBox.Text =
            $script:OriginalLogLines -join "`r`n"
    })

    # REFRESH
    $script:Refs.RefreshButton.Add_Click({
        . $PSScriptRoot\LogsView.ps1
        # Update timestamp immediately for UI feedback
        $script:Refs.Header.LastRefreshLabel.Text =
            "Last refresh: $(Get-Date -Format 'HH:mm:ss tt')"
        Show-LogsView -ContentPanel $script:Refs.ContentPanel
    })
}


# ------------------ Helper Functions ------------------------------------------


function Set-StatusMessage {
    <#
    .SYNOPSIS
        Sets the status message on the UI with color based on message type.
    .DESCRIPTION
        Updates the StatusLabel control in the UI references with the provided message and color.
    #>

    param(
        [Parameter(Mandatory)][string] $Message,
        [ValidateSet('Success','Warning','Error','Info')][string] $Type = 'Info'
    )
    
    $script:Refs.StatusLabel.Text = $Message

    $script:Refs.StatusLabel.ForeColor = switch ($Type) {
        'Success' { $script:Theme.Success }
        'Warning' { $script:Theme.Warning }
        'Error'   { $script:Theme.Error }
        default   { $script:Theme.PrimaryDarker }
    }
}


function New-FormButton {
    <#
    .SYNOPSIS
        Creates a consistently styled form button.
    .DESCRIPTION
        Returns a Windows Forms Button with standardized styling using the application theme.
    .OUTPUTS
        System.Windows.Forms.Button
    #>

    param(
        [Parameter(Mandatory)][string] $Name,
        [Parameter(Mandatory)][string] $Text,
        [System.Drawing.Size] $Size,
        [System.Windows.Forms.Padding] $Margin,
        [System.Drawing.Font] $Font = $null
    )

    $button = New-Object System.Windows.Forms.Button
    $button.Name = $Name
    $button.Text = $Text
    $button.FlatStyle = 'Flat'
    
    if ($Size) { $button.Size = $Size } 
    else { $button.Size = New-Object System.Drawing.Size(120, 35) }
    
    if ($Margin) { $button.Margin = $Margin }
    else { $button.Margin = New-Object System.Windows.Forms.Padding(5) }
    
    if ($Font) { $button.Font = $Font } 
    else { $button.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold) }
    
    $button.BackColor = $script:Theme.Primary
    $button.ForeColor = $script:Theme.White
    
    return $button
}