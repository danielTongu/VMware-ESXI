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
        Initializes the Logs UI and populates it with the latest log data.
    #>

    [CmdletBinding()]
    param([Parameter(Mandatory)][System.Windows.Forms.Panel]$ContentPanel)

    # logsUiRefs return the content panel too
    $script:LogsUiRefs = New-LogsLayout -ContentPanel $ContentPanel
    $data = Get-LogsData

    if ($data) {
        Update-LogsWithData -UiRefs $script:LogsUiRefs -Data $data
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
    $hdr.Height = 60
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

    $btnSearch = New-FormButton -Name 'btnSearch' -Text 'SEARCH' -Size (New-Object System.Drawing.Size(100, 30))
    $btnSearch.Location = [System.Drawing.Point]::new(330, 10)
    $flt.Controls.Add($btnSearch)

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

    # ── buttons row ─────────────────────────────────────────────────────────
    $btnRefresh = New-FormButton -Name 'btnRefresh' -Text 'REFRESH'
    $btnClear = New-FormButton -Name 'btnClear' -Text 'CLEAR'

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
    $statusLabel.AutoSize = $true
    $statusLabel.Name = 'StatusLabel'
    $statusLabel.Text = 'Ready'
    $statusLabel.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
    $statusLabel.ForeColor = $script:Theme.PrimaryDarker
    $footer.Controls.Add($statusLabel)

    return @{
        ContentPanel  = $ContentPanel          # needed for Refresh handler
        LogTextBox    = $txtLogs
        SearchBox     = $txtFind
        SearchButton  = $btnSearch
        RefreshButton = $btnRefresh
        ClearButton   = $btnClear
        OriginalLines = @()                    # cache for filter restore
        StatusLabel   = $statusLabel
    }
}


function Get-LogsData {
    <#
    .SYNOPSIS
        Retrieves the 100 most recent vCenter events.
    .OUTPUTS
        Hashtable: @{ Events = <array>; LastUpdated = <DateTime> } or $null if unavailable.
    #>

    [CmdletBinding()] param()

    Set-StatusMessage -UiRefs $script:LogsUiRefs -Message "Getting events..." -Type Error

    $events = $null

    if (-not $script:Connection) { 
        Set-StatusMessage -UiRefs $script:LogsUiRefs -Message "No Connection" -Type 'Error'
    } else {
        try {
            $events = Get-VIEvent -Server $script:Connection -MaxSamples 100 -ErrorAction Stop
        } catch {
            Write-Verbose "LogsView: $($_.Exception.Message)"
        }
    }
    
    return @{ Events = $events; LastUpdated = Get-Date }
}

function Update-LogsWithData {
    <#
    .SYNOPSIS
        Populates the log box and wires SEARCH / CLEAR / REFRESH buttons.
    .DESCRIPTION
        Updates the log display with new data and sets up event handlers for search, clear, and refresh actions.
    #>

    [CmdletBinding()]
    param([psobject]$UiRefs, [hashtable]$Data)

    Set-StatusMessage -UiRefs $UiRefs -Message "Populating logs..." -Type 'Success'

    # ---------- Store the original lines in the script scope ------
    $script:OriginalLogLines = foreach ($ev in $Data.Events) {
        $ts = $ev.CreatedTime.ToString('G')
        $usr = if ($ev.UserName) { $ev.UserName } else { 'N/A' }
        "[$ts] ($usr) $($ev.FullFormattedMessage)"
    }

    # ---------- Populate the textbox with the lines ----------------
    $UiRefs.LogTextBox.Text = $script:OriginalLogLines -join "`r`n"
    Set-StatusMessage -UiRefs $UiRefs -Message "" -Type 'Success'


    # ---------- Wire User Interface Events -------------------------
    $UiRefs.SearchButton.Add_Click({
        . $PSScriptRoot\LogsView.ps1
        try {
            $term = $script:LogsUiRefs.SearchBox.Text.Trim()
            if ($term) {
                Set-StatusMessage -UiRefs $script:LogsUiRefs -Message "Showing $($term)" -Type 'Success'
                $filteredLines = $script:OriginalLogLines | Where-Object { $_ -match [regex]::Escape($term) }
                $script:LogsUiRefs.LogTextBox.Text = $filteredLines -join "`r`n"
            }
            else {
                $script:LogsUiRefs.LogTextBox.Text = $script:OriginalLogLines -join "`r`n"
                Set-StatusMessage -UiRefs $script:LogsUiRefs -Message "" -Type 'Success'
            }
        }
        catch { 
            Set-StatusMessage -UiRefs $script:LogsUiRefs -Message "Search error: $_" -Type 'Error'
        }
    })

    
    $UiRefs.ClearButton.Add_Click({
        . $PSScriptRoot\LogsView.ps1
        Set-StatusMessage -UiRefs $script:LogsUiRefs -Message "Cleared field" -Type 'Success'
        $script:LogsUiRefs.SearchBox.Clear()
        $script:LogsUiRefs.LogTextBox.Text = $script:OriginalLogLines -join "`r`n"
    })

    
    $UiRefs.RefreshButton.Add_Click({
        . $PSScriptRoot\LogsView.ps1 # Dot-source the script to reload the function definitions
        Show-LogsView -ContentPanel $script:LogsUiRefs.ContentPanel
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
        [Parameter(Mandatory)]
        [psobject] $UiRefs,
        [string] $Message,
        [ValidateSet('Success','Warning','Error','Info')]
        [string] $Type = 'Info'
    )
    
    $UiRefs.StatusLabel.Text = $Message

    $UiRefs.StatusLabel.ForeColor = switch ($Type) {
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