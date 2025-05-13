# Required assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing



<#
    .SYNOPSIS
        Displays the logs view in the application.

    .DESCRIPTION
        Initializes the logs view layout and populates it with VMware log data.
    .PARAMETER ContentPanel
        The Windows.Forms.Panel where this view is rendered.
#>
function Show-LogsView {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Forms.Panel]$ContentPanel
    )

    try {
        # Build UI skeleton
        $uiRefs = New-LogsLayout -ContentPanel $ContentPanel

        # Populate with data if connected
        $data = Get-LogsData
        if ($data) {
            Update-LogsWithData -UiRefs $uiRefs -Data $data
        } else {
            $uiRefs.LogTextBox.Text = 'No log data available or not connected.'
        }
    } catch {
        Write-Verbose "Logs view initialization failed: $_"
    }
}



<#
    .SYNOPSIS
        Creates the layout for the logs view.
    .DESCRIPTION
        Builds header, filter, log box, and control buttons using CWU theme colors.
    .PARAMETER ContentPanel
        The Panel where the logs view is rendered.
    .OUTPUTS
        Hashtable of UI references.
#>
function New-LogsLayout {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Forms.Panel]$ContentPanel
    )

    try {
        $ContentPanel.SuspendLayout()
        $ContentPanel.Controls.Clear()
        $ContentPanel.BackColor = $global:Theme.LightGray

        # Root layout
        $root = [System.Windows.Forms.TableLayoutPanel]::new()
        $root.Dock = 'Fill'; 
        $root.ColumnCount = 1; 
        $root.RowCount = 4
        $root.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::AutoSize))   # Header
        $root.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::AutoSize))   # Filter
        $root.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Percent,100)) # Log box
        $root.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::AutoSize))   # Controls
        
        $ContentPanel.Controls.Add($root)

        # Header
        $header = [System.Windows.Forms.Panel]::new()
        $header.Dock = 'Fill'; 
        $header.Height = 60
        $header.BackColor = $global:Theme.Primary

        $root.Controls.Add($header,0,0)

        $titleLabel = [System.Windows.Forms.Label]::new()
        $titleLabel.Text = 'EVENT LOGS'
        $titleLabel.Font = [System.Drawing.Font]::new('Segoe UI',18,[System.Drawing.FontStyle]::Bold)
        $titleLabel.ForeColor = $global:Theme.White
        $titleLabel.Location = [System.Drawing.Point]::new(20,15)
        $titleLabel.AutoSize = $true
        
        $header.Controls.Add($titleLabel)

        # Filter row
        $filterPanel = [System.Windows.Forms.Panel]::new()
        $filterPanel.Dock = 'Fill'; 
        $filterPanel.Height = 50
        $filterPanel.BackColor = $global:Theme.LightGray

        $root.Controls.Add($filterPanel,0,1)

        # Search box
        $searchBox = [System.Windows.Forms.TextBox]::new()
        $searchBox.Name = 'txtFilter'
        $searchBox.Width = 300; $searchBox.Height = 30
        $searchBox.Location = [System.Drawing.Point]::new(20,10)
        $searchBox.Font = [System.Drawing.Font]::new('Segoe UI',10)
        $searchBox.BackColor = $global:Theme.White 
        $searchBox.ForeColor = $global:Theme.PrimaryDark

        $filterPanel.Controls.Add($searchBox)

        # Search button
        $searchBtn = [System.Windows.Forms.Button]::new()
        $searchBtn.Name = 'btnSearch'
        $searchBtn.Text = 'SEARCH'
        $searchBtn.Width = 100 
        $searchBtn.Height = 30
        $searchBtn.Location = [System.Drawing.Point]::new(330,10)
        $searchBtn.Font = [System.Drawing.Font]::new('Segoe UI',10,[System.Drawing.FontStyle]::Bold)
        $searchBtn.BackColor = $global:Theme.Primary; 
        $searchBtn.ForeColor = $global:Theme.White

        $filterPanel.Controls.Add($searchBtn)

        # Log textbox
        $logPanel = [System.Windows.Forms.TextBox]::new()
        $logPanel.Name = 'txtLogs'
        $logPanel.Dock = 'Fill'
        $logPanel.Multiline = $true
        $logPanel.ScrollBars = 'Vertical' 
        $logPanel.ReadOnly = $true
        $logPanel.BackColor = $global:Theme.White
        $logPanel.ForeColor = $global:Theme.PrimaryDark
        $logPanel.Font = [System.Drawing.Font]::new('Segoe UI',10)

        $root.Controls.Add($logPanel,0,2)

        # Control buttons
        $controlsPanel = [System.Windows.Forms.FlowLayoutPanel]::new()
        $controlsPanel.Dock = 'Fill'
        $controlsPanel.Height = 50
        $controlsPanel.FlowDirection = 'LeftToRight'
        $controlsPanel.Padding = [System.Windows.Forms.Padding]::new(10)
        $controlsPanel.BackColor = $global:Theme.LightGray

        $root.Controls.Add($controlsPanel,0,3)

        # Refresh button
        $btnRefresh = [System.Windows.Forms.Button]::new()
        $btnRefresh.Name = 'btnRefresh'
        $btnRefresh.Text = 'REFRESH'
        $btnRefresh.Width = 120
        $btnRefresh.Height = 35
        $btnRefresh.Font = [System.Drawing.Font]::new('Segoe UI',10,[System.Drawing.FontStyle]::Bold)
        $btnRefresh.BackColor = $global:Theme.Primary
        $btnRefresh.ForeColor = $global:Theme.White

        $controlsPanel.Controls.Add($btnRefresh)

        # Clear button
        $btnClear = [System.Windows.Forms.Button]::new()
        $btnClear.Name = 'btnClear'
        $btnClear.Text = 'CLEAR'
        $btnClear.Width = 120
        $btnClear.Height = 35
        $btnClear.Font = [System.Drawing.Font]::new('Segoe UI',10,[System.Drawing.FontStyle]::Bold)
        $btnClear.BackColor = $global:Theme.LightGray
        $btnClear.ForeColor = $global:Theme.PrimaryDark

        $controlsPanel.Controls.Add($btnClear)

        # Return refs
        return @{ 
            LogTextBox = $logPanel
            SearchBox = $searchBox
            SearchButton = $searchBtn
            RefreshButton = $btnRefresh
            ClearButton = $btnClear 
        }
    } finally {
        $ContentPanel.ResumeLayout($true)
    }
}



<#
    .SYNOPSIS
        Fetches logs data from the VMware environment.
    .DESCRIPTION
            Retrieves recent events if connected and logged in.
    .OUTPUTS
        Hashtable with Events and LastUpdated.
#>
function Get-LogsData {
    [CmdletBinding()]
    param()

    try {
        if (-not $global:IsLoggedIn) { return $null }

        $conn = $global:AppState.VMware.Connection
        if (-not $conn) { return $null }

        $events = Get-VIEvent -Server $conn -MaxSamples 100 -ErrorAction Stop

        return @{ 
            Events = $events; 
            LastUpdated = Get-Date 
        }

    } catch {
        Write-Verbose "Failed to load logs: $_"
        return $null
    }
}



<#
    .SYNOPSIS
        Updates the logs view with new data.
    .DESCRIPTION
            Populates the log textbox and wires search/refresh/clear handlers.
    .PARAMETER UiRefs
        Hashtable of UI element references.
    .PARAMETER Data
        Hashtable containing events and timestamp.
#>
function Update-LogsWithData {
    [CmdletBinding()]
    param([hashtable]$UiRefs, [hashtable]$Data)
    
    try {
        $UiRefs.LogTextBox.Clear()

        if (-not $Data.Events) { 
            $UiRefs.LogTextBox.Text = 'No log data available or not connected.'; 
            return 
        }

        foreach ($ev in $Data.Events) {
            $ts = $ev.CreatedTime.ToString('G'); 
            $user = if ($ev.UserName) { $ev.UserName } else { 'N/A' }
            $msg = $($ev.FullFormattedMessage)
            $UiRefs.LogTextBox.AppendText("[$ts] ($user) $message`r`n")
        }

        # Event handlers
        $UiRefs.SearchButton.Add_Click({
            $f = $UiRefs.SearchBox.Text.Trim()

            if ($f) {
                $lines = $UiRefs.LogTextBox.Text -split "`r`n"
                $filteredLines = $lines | Where-Object { $_ -match $filterText }
                $UiRefs.LogTextBox.Text = $filteredLines -join "`r`n"
            }
        })

        $UiRefs.RefreshButton.Add_Click({
            $d = Get-LogsData; 
            if ($d) { Update-LogsWithData -UiRefs $UiRefs -Data $d }
        })

        $UiRefs.ClearButton.Add_Click({ $UiRefs.LogTextBox.Clear() })

        $UiRefs.SearchBox.Add_KeyDown({ 
            if ($_.KeyCode -eq [System.Windows.Forms.Keys]::Enter) { 
                $UiRefs.SearchButton.PerformClick(); 
                $_.SuppressKeyPress=$true 
            } 
        })
    } catch {
        Write-Verbose "Failed to update logs view: $_"
        $UiRefs.LogTextBox.AppendText('Error loading logs. Please try again.`r`n')
    }
}
