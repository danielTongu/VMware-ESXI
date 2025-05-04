<#
.SYNOPSIS
    Resilient VMware ESXi Dashboard with Offline Support
.DESCRIPTION
    Displays comprehensive overview with:
    - Online/offline mode detection
    - Graceful degradation when disconnected
    - Cached data display options
    - Enhanced error handling
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms.DataVisualization

function Show-DashboardView {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Forms.Panel]$ContentPanel
    )

    # Clear previous content
    $ContentPanel.Controls.Clear()

    # Create main container with scrolling
    $mainPanel = New-Object System.Windows.Forms.Panel
    $mainPanel.Dock = 'Fill'
    $mainPanel.AutoScroll = $true
    $mainPanel.BackColor = [System.Drawing.Color]::White
    $ContentPanel.Controls.Add($mainPanel)

    # -----------------------------
    # Dashboard Header
    # -----------------------------
    $yPos = 20
    $offlineMode = $global:VMwareConfig.OfflineMode

    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Text = "VMware ESXi Dashboard" + $(if ($offlineMode) { " [OFFLINE MODE]" })
    $lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
    $lblTitle.Location = New-Object System.Drawing.Point(20, $yPos)
    $lblTitle.AutoSize = $true
    $lblTitle.ForeColor = if ($offlineMode) { [System.Drawing.Color]::Gray } else { [System.Drawing.Color]::Black }
    $mainPanel.Controls.Add($lblTitle)

    $yPos += 40

    # Connection status label
    $lblConnectionStatus = New-Object System.Windows.Forms.Label
    $lblConnectionStatus.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $lblConnectionStatus.Location = New-Object System.Drawing.Point(20, $yPos)
    $lblConnectionStatus.AutoSize = $true
    $mainPanel.Controls.Add($lblConnectionStatus)

    $yPos += 30

    $lblLastRefresh = New-Object System.Windows.Forms.Label
    $lblLastRefresh.Text = "Last refresh: $(Get-Date -Format 'G')"
    $lblLastRefresh.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Italic)
    $lblLastRefresh.Location = New-Object System.Drawing.Point(20, $yPos)
    $lblLastRefresh.AutoSize = $true
    $mainPanel.Controls.Add($lblLastRefresh)

    $yPos += 40

    # -----------------------------
    # Data Collection
    # -----------------------------
    $data = @{
        HostInfo    = $null
        VMs         = $null
        Datastores  = $null
        Events      = $null
        Alarms      = $null
    }

    if (-not $offlineMode) {
        try {
            $conn = [VMServerConnection]::GetInstance().GetConnection()
            $data.HostInfo = Get-VMHost -Server $conn -ErrorAction Stop
            $data.VMs = Get-VM -Server $conn -ErrorAction Stop
            $data.Datastores = Get-Datastore -Server $conn -ErrorAction Stop
            $data.Events = Get-VIEvent -Server $conn -MaxSamples 10 -ErrorAction SilentlyContinue
            $data.Alarms = Get-AlarmDefinition -Server $conn -ErrorAction SilentlyContinue
            
            $lblConnectionStatus.Text = "Connected to: $($data.HostInfo.Name) | Version: $($data.HostInfo.Version)"
            $lblConnectionStatus.ForeColor = [System.Drawing.Color]::DarkGreen
        }
        catch {
            $offlineMode = $true
            $global:VMwareConfig.OfflineMode = $true
            $lblTitle.Text += " [OFFLINE MODE]"
            $lblTitle.ForeColor = [System.Drawing.Color]::Gray
            
            $lblConnectionStatus.Text = "Connection Error: $($_.Exception.Message)"
            $lblConnectionStatus.ForeColor = [System.Drawing.Color]::Red
        }
    }
    else {
        $lblConnectionStatus.Text = "Working in offline mode - displaying cached data"
        $lblConnectionStatus.ForeColor = [System.Drawing.Color]::Orange
    }

    # -----------------------------
    # Quick Stats Cards (Works in offline mode)
    # -----------------------------
    $statsPanel = New-Object System.Windows.Forms.Panel
    $statsPanel.Location = New-Object System.Drawing.Point(20, $yPos)
    $statsPanel.Size = New-Object System.Drawing.Size(900, 120)
    $statsPanel.BorderStyle = 'FixedSingle'
    $mainPanel.Controls.Add($statsPanel)

    $statCards = @(
        @{ 
            Title = "Total VMs" 
            Value = if ($data.VMs) { $data.VMs.Count } else { "N/A" }
            Icon = "🖥️" 
        },
        @{ 
            Title = "Running VMs" 
            Value = if ($data.VMs) { 
                $running = ($data.VMs | Where-Object { $_.PowerState -eq 'PoweredOn' }).Count
                "$running ($([math]::Round(($running/$data.VMs.Count)*100))%)"
            } else { "N/A" }
            Icon = "⚡" 
        },
        @{ 
            Title = "CPU Usage" 
            Value = if ($data.HostInfo) { 
                $cpu = [math]::Round(($data.HostInfo.CpuUsageMhz / $data.HostInfo.CpuTotalMhz) * 100, 1)
                "$cpu%"
            } else { "N/A" }
            Icon = "⏱️"
            Warning = $cpu -gt 80 -and $data.HostInfo
        },
        @{ 
            Title = "Memory Usage" 
            Value = if ($data.HostInfo) { 
                $mem = [math]::Round(($data.HostInfo.MemoryUsageGB / $data.HostInfo.MemoryTotalGB) * 100, 1)
                "$mem%"
            } else { "N/A" }
            Icon = "🧠"
            Warning = $mem -gt 80 -and $data.HostInfo
        },
        @{ 
            Title = "Datastores" 
            Value = if ($data.Datastores) { $data.Datastores.Count } else { "N/A" }
            Icon = "💾"
        }
    )

    $xCard = 10
    foreach ($card in $statCards) {
        $cardPanel = New-Object System.Windows.Forms.Panel
        $cardPanel.Location = New-Object System.Drawing.Point($xCard, 10)
        $cardPanel.Size = New-Object System.Drawing.Size(160, 100)
        $cardPanel.BackColor = if ($card.Warning) { [System.Drawing.Color]::LightPink } else { [System.Drawing.Color]::White }
        $cardPanel.BorderStyle = 'FixedSingle'

        $lblIcon = New-Object System.Windows.Forms.Label
        $lblIcon.Text = $card.Icon
        $lblIcon.Font = New-Object System.Drawing.Font("Segoe UI", 24)
        $lblIcon.Location = New-Object System.Drawing.Point(10, 10)
        $lblIcon.AutoSize = $true
        $cardPanel.Controls.Add($lblIcon)

        $lblTitle = New-Object System.Windows.Forms.Label
        $lblTitle.Text = $card.Title
        $lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 10)
        $lblTitle.Location = New-Object System.Drawing.Point(60, 15)
        $lblTitle.AutoSize = $true
        $cardPanel.Controls.Add($lblTitle)

        $lblValue = New-Object System.Windows.Forms.Label
        $lblValue.Text = $card.Value
        $lblValue.Font = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
        $lblValue.Location = New-Object System.Drawing.Point(60, 40)
        $lblValue.AutoSize = $true
        $cardPanel.Controls.Add($lblValue)

        $statsPanel.Controls.Add($cardPanel)
        $xCard += 170
    }

    $yPos += 140

    # -----------------------------
    # Resource Utilization (Only in online mode)
    # -----------------------------
    if (-not $offlineMode -and $data.HostInfo) {
        $lblResources = New-Object System.Windows.Forms.Label
        $lblResources.Text = "Resource Utilization"
        $lblResources.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
        $lblResources.Location = New-Object System.Drawing.Point(20, $yPos)
        $lblResources.AutoSize = $true
        $mainPanel.Controls.Add($lblResources)

        $yPos += 30

        # CPU Usage Chart
        $cpuChart = New-Object System.Windows.Forms.DataVisualization.Charting.Chart
        $cpuChart.Location = New-Object System.Drawing.Point(20, $yPos)
        $cpuChart.Size = New-Object System.Drawing.Size(430, 200)
        
        $cpuChartArea = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea
        $cpuChart.ChartAreas.Add($cpuChartArea)
        
        $cpuSeries = New-Object System.Windows.Forms.DataVisualization.Charting.Series
        $cpuSeries.ChartType = 'Column'
        $cpuSeries.Points.AddXY("Used", $data.HostInfo.CpuUsageMhz)
        $cpuSeries.Points.AddXY("Available", ($data.HostInfo.CpuTotalMhz - $data.HostInfo.CpuUsageMhz))
        $cpuChart.Series.Add($cpuSeries)
        
        $cpuChart.Titles.Add("CPU Usage (MHz)") | Out-Null
        $mainPanel.Controls.Add($cpuChart)

        # Memory Usage Chart
        $memChart = New-Object System.Windows.Forms.DataVisualization.Charting.Chart
        $memChart.Location = New-Object System.Drawing.Point(470, $yPos)
        $memChart.Size = New-Object System.Drawing.Size(430, 200)
        
        $memChartArea = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea
        $memChart.ChartAreas.Add($memChartArea)
        
        $memSeries = New-Object System.Windows.Forms.DataVisualization.Charting.Series
        $memSeries.ChartType = 'Column'
        $memSeries.Points.AddXY("Used", $data.HostInfo.MemoryUsageGB)
        $memSeries.Points.AddXY("Available", ($data.HostInfo.MemoryTotalGB - $data.HostInfo.MemoryUsageGB))
        $memChart.Series.Add($memSeries)
        
        $memChart.Titles.Add("Memory Usage (GB)") | Out-Null
        $mainPanel.Controls.Add($memChart)

        $yPos += 230
    }
    else {
        $lblNoResources = New-Object System.Windows.Forms.Label
        $lblNoResources.Text = "Resource data unavailable in offline mode"
        $lblNoResources.Font = New-Object System.Drawing.Font("Segoe UI", 12)
        $lblNoResources.ForeColor = [System.Drawing.Color]::Gray
        $lblNoResources.Location = New-Object System.Drawing.Point(20, $yPos)
        $lblNoResources.AutoSize = $true
        $mainPanel.Controls.Add($lblNoResources)
        $yPos += 50
    }

    # -----------------------------
    # Recent Alerts (Works with cached data)
    # -----------------------------
    $lblAlerts = New-Object System.Windows.Forms.Label
    $lblAlerts.Text = "Recent Alerts and Events"
    $lblAlerts.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $lblAlerts.Location = New-Object System.Drawing.Point(20, $yPos)
    $lblAlerts.AutoSize = $true
    $mainPanel.Controls.Add($lblAlerts)

    $yPos += 30

    $dgvEvents = New-Object System.Windows.Forms.DataGridView
    $dgvEvents.Location = New-Object System.Drawing.Point(20, $yPos)
    $dgvEvents.Size = New-Object System.Drawing.Size(880, 200)
    $dgvEvents.AutoSizeColumnsMode = 'Fill'
    $dgvEvents.SelectionMode = 'FullRowSelect'
    $dgvEvents.ReadOnly = $true
    $dgvEvents.RowHeadersVisible = $false
    $dgvEvents.BackgroundColor = if ($offlineMode) { [System.Drawing.Color]::WhiteSmoke } else { [System.Drawing.Color]::White }

    # Add columns
    $columns = @(
        @{ Name = "Time"; HeaderText = "Time" },
        @{ Name = "Type"; HeaderText = "Type" },
        @{ Name = "Message"; HeaderText = "Message" },
        @{ Name = "Object"; HeaderText = "Object" }
    )

    foreach ($col in $columns) {
        $column = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
        $column.Name = $col.Name
        $column.HeaderText = $col.HeaderText
        $dgvEvents.Columns.Add($column)
    }

    # Add event data or placeholder
    if ($data.Events -and $data.Events.Count -gt 0) {
        foreach ($event in $data.Events) {
            $dgvEvents.Rows.Add(
                $event.CreatedTime,
                $event.GetType().Name,
                $event.FullFormattedMessage,
                $event.ObjectName
            ) | Out-Null
        }
    }
    else {
        $dgvEvents.Rows.Add(
            [DateTime]::Now,
            "Information",
            "No recent events available",
            "System"
        ) | Out-Null
        $dgvEvents.Rows[0].DefaultCellStyle.ForeColor = [System.Drawing.Color]::Gray
    }

    $mainPanel.Controls.Add($dgvEvents)
    $yPos += 220

    # -----------------------------
    # Storage Overview (Works with cached data)
    # -----------------------------
    $lblStorage = New-Object System.Windows.Forms.Label
    $lblStorage.Text = "Storage Overview"
    $lblStorage.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $lblStorage.Location = New-Object System.Drawing.Point(20, $yPos)
    $lblStorage.AutoSize = $true
    $mainPanel.Controls.Add($lblStorage)

    $yPos += 30

    $dgvStorage = New-Object System.Windows.Forms.DataGridView
    $dgvStorage.Location = New-Object System.Drawing.Point(20, $yPos)
    $dgvStorage.Size = New-Object System.Drawing.Size(880, 150)
    $dgvStorage.AutoSizeColumnsMode = 'Fill'
    $dgvStorage.SelectionMode = 'FullRowSelect'
    $dgvStorage.ReadOnly = $true
    $dgvStorage.RowHeadersVisible = $false
    $dgvStorage.BackgroundColor = if ($offlineMode) { [System.Drawing.Color]::WhiteSmoke } else { [System.Drawing.Color]::White }

    # Add columns
    $storageColumns = @(
        @{ Name = "Name"; HeaderText = "Datastore" },
        @{ Name = "CapacityGB"; HeaderText = "Capacity (GB)" },
        @{ Name = "FreeSpaceGB"; HeaderText = "Free (GB)" },
        @{ Name = "PercentFree"; HeaderText = "% Free" }
    )

    foreach ($col in $storageColumns) {
        $column = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
        $column.Name = $col.Name
        $column.HeaderText = $col.HeaderText
        $dgvStorage.Columns.Add($column)
    }

    # Add storage data or placeholder
    if ($data.Datastores -and $data.Datastores.Count -gt 0) {
        foreach ($ds in $data.Datastores) {
            $percentFree = [math]::Round(($ds.FreeSpaceGB / $ds.CapacityGB) * 100, 1)
            $dgvStorage.Rows.Add(
                $ds.Name,
                [math]::Round($ds.CapacityGB, 1),
                [math]::Round($ds.FreeSpaceGB, 1),
                "$percentFree%"
            ) | Out-Null
        }
    }
    else {
        $dgvStorage.Rows.Add(
            "No storage data",
            "N/A",
            "N/A",
            "N/A"
        ) | Out-Null
        $dgvStorage.Rows[0].DefaultCellStyle.ForeColor = [System.Drawing.Color]::Gray
    }

    $mainPanel.Controls.Add($dgvStorage)
    $yPos += 170

    # -----------------------------
    # Action Buttons
    # -----------------------------
    $btnPanel = New-Object System.Windows.Forms.Panel
    $btnPanel.Location = New-Object System.Drawing.Point(20, $yPos)
    $btnPanel.Size = New-Object System.Drawing.Size(880, 50)
    $mainPanel.Controls.Add($btnPanel)

    # Refresh button
    $btnRefresh = New-Object System.Windows.Forms.Button
    $btnRefresh.Text = "Refresh Data"
    $btnRefresh.Size = New-Object System.Drawing.Size(120, 40)
    $btnRefresh.Location = New-Object System.Drawing.Point(0, 0)
    $btnRefresh.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $btnRefresh.Add_Click({
        $global:VMwareConfig.OfflineMode = $false
        Show-DashboardView -ContentPanel $ContentPanel
    })
    $btnPanel.Controls.Add($btnRefresh)

    # Offline mode toggle
    $btnOffline = New-Object System.Windows.Forms.Button
    $btnOffline.Text = if ($offlineMode) { "Go Online" } else { "Work Offline" }
    $btnOffline.Size = New-Object System.Drawing.Size(120, 40)
    $btnOffline.Location = New-Object System.Drawing.Point(130, 0)
    $btnOffline.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $btnOffline.Add_Click({
        $global:VMwareConfig.OfflineMode = -not $global:VMwareConfig.OfflineMode
        Show-DashboardView -ContentPanel $ContentPanel
    })
    $btnPanel.Controls.Add($btnOffline)
}