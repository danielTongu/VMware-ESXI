Add-Type -AssemblyName 'System.Windows.Forms'
Add-Type -AssemblyName 'System.Drawing'



# ────────────────────────────────────────────────────────────────────────────
#                           Views/LogsView.ps1
# ────────────────────────────────────────────────────────────────────────────



<#
    .SYNOPSIS
        Displays the logs view in the application.

    .DESCRIPTION
        This function initializes the logs view, sets up the UI layout, and populates it with data from the VMware environment.

    .PARAMETER ContentPanel
        The panel where the logs view will be displayed.

    .EXAMPLE
        Show-LogsView -ContentPanel $mainPanel
#>
function Show-LogsView {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Forms.Panel]$ContentPanel
    )

    try {
        # Build UI (empty)
        $uiRefs = New-LogsLayout -ContentPanel $ContentPanel

        # Populate with data if connected
        $data = Get-LogsData
        if ($data) {
            Update-LogsWithData -UiRefs $uiRefs -Data $data
        } else {
            $uiRefs.LogTextBox.Text = "No log data available or not connected."
        }
    } catch { 
        Write-Verbose "Logs view initialization failed: $_" 
    }
}




<#
    .SYNOPSIS
        Creates the layout for the logs view.

    .DESCRIPTION
        This function sets up the layout for the logs view, including header, filter controls, log content area, and control buttons.

    .PARAMETER ContentPanel
        The panel where the logs view will be displayed.

    .EXAMPLE
        $layout = New-LogsLayout -ContentPanel $mainPanel
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
        $ContentPanel.BackColor = $global:theme.Background

        # ── ROOT LAYOUT ─────────────────────────────────────────────────
        $root = New-Object System.Windows.Forms.TableLayoutPanel
        $root.Dock = 'Fill'
        $root.ColumnCount = 1
        $root.RowCount = 4
        $root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))   # Header
        $root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))   # Filter
        $root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent,100))) # Content
        $root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))   # Controls
        $ContentPanel.Controls.Add($root)



        #===== Row [1] HEADER ============================================
        $header = New-Object System.Windows.Forms.Panel
        $header.Dock = 'Fill'
        $header.Height = 60
        $header.BackColor = $global:theme.Primary
        $root.Controls.Add($header, 0, 0)

        $titleLabel = New-Object System.Windows.Forms.Label
        $titleLabel.Text = 'EVENT LOGS'
        $titleLabel.Font = New-Object System.Drawing.Font('Segoe UI', 18, [System.Drawing.FontStyle]::Bold)
        $titleLabel.ForeColor = [System.Drawing.Color]::White
        $titleLabel.Location = New-Object System.Drawing.Point(20, 15)
        $titleLabel.AutoSize = $true
        $header.Controls.Add($titleLabel)



        #===== Row [2] FILTER CONTROLS =====================================
        $filterPanel = New-Object System.Windows.Forms.Panel
        $filterPanel.Dock = 'Fill'
        $filterPanel.Height = 50
        $filterPanel.BackColor = $global:theme.Background
        $root.Controls.Add($filterPanel, 0, 1)

        # Search field
        $searchBox = New-Object System.Windows.Forms.TextBox
        $searchBox.Name = 'txtFilter'
        $searchBox.Width = 300
        $searchBox.Height = 30
        $searchBox.Location = New-Object System.Drawing.Point(20, 10)
        $searchBox.Font = New-Object System.Drawing.Font('Segoe UI', 10)
        $searchBox.BackColor = $global:theme.CardBackground
        $searchBox.ForeColor = $global:theme.TextPrimary
        $filterPanel.Controls.Add($searchBox)

        # Search button
        $searchBtn = New-Object System.Windows.Forms.Button
        $searchBtn.Name = 'btnSearch'
        $searchBtn.Text = "SEARCH"
        $searchBtn.Width = 100
        $searchBtn.Height = 30
        $searchBtn.Location = New-Object System.Drawing.Point(330, 10)
        $searchBtn.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
        $searchBtn.BackColor = $global:theme.Primary
        $searchBtn.ForeColor = [System.Drawing.Color]::White
        $filterPanel.Controls.Add($searchBtn)



        #===== Row [3] LOG CONTENT =========================================
        $logPanel = New-Object System.Windows.Forms.TextBox
        $logPanel.Name = 'txtLogs'
        $logPanel.Dock = 'Fill'
        $logPanel.Multiline = $true
        $logPanel.ScrollBars = 'Vertical'
        $logPanel.ReadOnly = $true
        $logPanel.BackColor = $global:theme.CardBackground
        $logPanel.ForeColor = $global:theme.TextPrimary
        $logPanel.Font = New-Object System.Drawing.Font('Segoe UI', 10)
        $root.Controls.Add($logPanel, 0, 2)


        
        #===== Row [4] CONTROL BUTTONS ====================================
        $controlsPanel = New-Object System.Windows.Forms.FlowLayoutPanel
        $controlsPanel.Dock = 'Fill'
        $controlsPanel.Height = 50
        $controlsPanel.FlowDirection = 'LeftToRight'
        $controlsPanel.Padding = New-Object System.Windows.Forms.Padding(10)
        $controlsPanel.BackColor = $global:theme.Background
        $root.Controls.Add($controlsPanel, 0, 3)

        # Refresh button
        $btnRefresh = New-Object System.Windows.Forms.Button
        $btnRefresh.Name = 'btnRefresh'
        $btnRefresh.Text = 'REFRESH'
        $btnRefresh.Width = 120
        $btnRefresh.Height = 35
        $btnRefresh.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
        $btnRefresh.BackColor = $global:theme.Primary
        $btnRefresh.ForeColor = [System.Drawing.Color]::White
        $controlsPanel.Controls.Add($btnRefresh)

        # Clear button
        $btnClear = New-Object System.Windows.Forms.Button
        $btnClear.Name = 'btnClear'
        $btnClear.Text = 'CLEAR'
        $btnClear.Width = 120
        $btnClear.Height = 35
        $btnClear.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
        $btnClear.BackColor = $global:theme.Secondary
        $btnClear.ForeColor = [System.Drawing.Color]::White
        $controlsPanel.Controls.Add($btnClear)

        # Return references to UI elements
        $refs = @{
            LogTextBox = $logPanel
            SearchBox = $searchBox
            SearchButton = $searchBtn
            RefreshButton = $btnRefresh
            ClearButton = $btnClear
        }

        return $refs
    }
    finally {
        $ContentPanel.ResumeLayout($true)
    }
}




<#
    .SYNOPSIS
        Fetches logs data from the VMware environment.

    .DESCRIPTION
        This function retrieves the latest logs from the VMware environment and returns them in a structured format.

    .EXAMPLE
        $logsData = Get-LogsData
        # This will fetch the logs data and store it in $logsData variable.
#>
function Get-LogsData {
    [CmdletBinding()]
    param()

    try {
        if (-not $global:IsLoggedIn) {
            Write-Verbose "Not logged in - cannot load logs"
            return $null
        }
        if ($global:VMwareConfig.OfflineMode -or -not $global:VMwareConfig.Connection) {
            Write-Verbose "Offline mode or no connection available"
            return $null
        }

        $conn = $global:VMwareConfig.Connection
        $events = Get-VIEvent -Server $conn -MaxSamples 100 -ErrorAction Stop
        
        return @{
            Events = $events
            LastUpdated = (Get-Date)
        }
    }
    catch {
        Write-Verbose "Failed to load logs: $_"
        return $null
    }
}




<#
    .SYNOPSIS
        Updates the logs view with new data.

    .DESCRIPTION
        This function takes the logs data and updates the logs view with the latest information.

    .PARAMETER UiRefs
        A hashtable containing references to UI elements.

    .PARAMETER Data
        The logs data to be displayed in the logs view.

    .EXAMPLE
        Update-LogsWithData -UiRefs $uiRefs -Data $logsData
        # This will update the logs view with the provided data.
#>
function Update-LogsWithData {
    [CmdletBinding()]
    param(
        [hashtable]$UiRefs,
        [hashtable]$Data
    )

    try {
        $UiRefs.LogTextBox.Clear()

        if (-not $Data.Events) {
            $UiRefs.LogTextBox.Text = "No log data available or not connected."
            return
        }

        foreach ($ev in $Data.Events) {
            $timestamp = $ev.CreatedTime.ToString('G')
            $user = if ($ev.UserName) { $ev.UserName } else { 'N/A' }
            $message = $ev.FullFormattedMessage
            $UiRefs.LogTextBox.AppendText("[$timestamp] ($user) $message`r`n")
        }

        # Add event handlers for search functionality
        $UiRefs.SearchButton.Add_Click({
            $filterText = $UiRefs.SearchBox.Text.Trim()
            if ([string]::IsNullOrEmpty($filterText)) {
                return
            }

            $currentText = $UiRefs.LogTextBox.Text
            $lines = $currentText -split "`r`n"
            $filteredLines = $lines | Where-Object { $_ -match $filterText }
            $UiRefs.LogTextBox.Text = $filteredLines -join "`r`n"
        })

        $UiRefs.RefreshButton.Add_Click({
            $data = Get-LogsData
            if ($data) {
                Update-LogsWithData -UiRefs $UiRefs -Data $data
            }
        })

        $UiRefs.ClearButton.Add_Click({
            $UiRefs.LogTextBox.Clear()
        })

        # Enable search on Enter key
        $UiRefs.SearchBox.Add_KeyDown({
            if ($_.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
                $UiRefs.SearchButton.PerformClick()
                $_.SuppressKeyPress = $true
            }
        })
    }
    catch {
        Write-Verbose "Failed to update logs view: $_"
        $UiRefs.LogTextBox.AppendText("Error loading logs. Please try again.`r`n")
    }
}