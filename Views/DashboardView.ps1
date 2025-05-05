<#
.SYNOPSIS
    Modern VMware ESXi Dashboard with Enhanced UI/UX
.DESCRIPTION
    Professional dashboard featuring:
    - Real-time monitoring with graceful offline fallback
    - Interactive resource utilization charts
    - Responsive card-based statistics
    - Comprehensive alert and storage overview
    - Dark/light mode support
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

    # UI Theme Configuration
    $theme = @{
        Background     = [System.Drawing.Color]::FromArgb(240, 240, 240)
        CardBackground = [System.Drawing.Color]::White
        TextPrimary    = [System.Drawing.Color]::FromArgb(50, 50, 50)
        TextSecondary  = [System.Drawing.Color]::FromArgb(120, 120, 120)
        Accent         = [System.Drawing.Color]::FromArgb(0, 120, 215)
        Warning        = [System.Drawing.Color]::FromArgb(220, 80, 80)
        Success        = [System.Drawing.Color]::FromArgb(50, 160, 80)
    }

    # Clear previous content
    $ContentPanel.Controls.Clear()
    $ContentPanel.BackColor = $theme.Background

    # Create main container with scrolling
    $mainPanel = New-Object System.Windows.Forms.Panel
    $mainPanel.Dock = 'Fill'
    $mainPanel.AutoScroll = $true
    $mainPanel.BackColor = $theme.Background
    $ContentPanel.Controls.Add($mainPanel)

    # -----------------------------
    # Dashboard Header
    # -----------------------------
    $yPos = 20
    $offlineMode = $global:VMwareConfig.OfflineMode

    # Title with icon
    $titlePanel = New-Object System.Windows.Forms.Panel
    $titlePanel.Location = New-Object System.Drawing.Point(20, $yPos)
    $titlePanel.Size = New-Object System.Drawing.Size(900, 40)
    $titlePanel.BackColor = $theme.Background
    $mainPanel.Controls.Add($titlePanel)

    $picIcon = New-Object System.Windows.Forms.PictureBox
    try {
        $picIcon.Image = [System.Drawing.Image]::FromFile("$PSScriptRoot\..\Images\vmware-icon.png")
    }
    catch {
        # Do nothing if the image file does not exist
    }
    $picIcon.SizeMode = 'Zoom'
    $picIcon.Size = New-Object System.Drawing.Size(32, 32)
    $picIcon.Location = New-Object System.Drawing.Point(0, 0)
    $titlePanel.Controls.Add($picIcon)

    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Text = "ESXi DASHBOARD"
    $lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
    $lblTitle.Location = New-Object System.Drawing.Point(40, 0)
    $lblTitle.AutoSize = $true
    $lblTitle.ForeColor = $theme.Accent
    $titlePanel.Controls.Add($lblTitle)

    $lblStatus = New-Object System.Windows.Forms.Label
    $lblStatus.Text = if ($offlineMode) { "OFFLINE MODE" } else { "CONNECTED" }
    $lblStatus.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $lblStatus.Location = New-Object System.Drawing.Point(250, 8)
    $lblStatus.AutoSize = $true
    $lblStatus.ForeColor = if ($offlineMode) { $theme.Warning } else { $theme.Success }
    $titlePanel.Controls.Add($lblStatus)

    $yPos += 50

    # Connection status bar
    $statusBar = New-Object System.Windows.Forms.Panel
    $statusBar.Location = New-Object System.Drawing.Point(20, $yPos)
    $statusBar.Size = New-Object System.Drawing.Size(900, 30)
    $statusBar.BackColor = if ($offlineMode) { [System.Drawing.Color]::LightGoldenrodYellow } else { [System.Drawing.Color]::LightGreen }
    $mainPanel.Controls.Add($statusBar)

    $lblConnectionInfo = New-Object System.Windows.Forms.Label
    $lblConnectionInfo.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $lblConnectionInfo.Location = New-Object System.Drawing.Point(10, 5)
    $lblConnectionInfo.AutoSize = $true
    $statusBar.Controls.Add($lblConnectionInfo)

    $yPos += 40

    # Last refresh label
    $lblLastRefresh = New-Object System.Windows.Forms.Label
    $lblLastRefresh.Text = "Last refresh: $(Get-Date -Format 'HH:mm:ss')"
    $lblLastRefresh.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $lblLastRefresh.ForeColor = $theme.TextSecondary
    $lblLastRefresh.Location = New-Object System.Drawing.Point(20, $yPos)
    $lblLastRefresh.AutoSize = $true
    $mainPanel.Controls.Add($lblLastRefresh)

    $yPos += 30

    # -----------------------------
    # Data Collection
    # -----------------------------
    $data = @{
        HostInfo    = $null
        VMs         = $null
        Datastores  = $null
        Events      = $null
        Alarms      = $null
        Performance = $null
    }

    if (-not $offlineMode) {
        try {
            $conn = [VMServerConnection]::GetInstance().GetConnection()
            $data.HostInfo = Get-VMHost -Server $conn -ErrorAction Stop | Select-Object Name, Version, 
                CpuTotalMhz, CpuUsageMhz, MemoryTotalGB, MemoryUsageGB, 
                @{Name='CpuUsagePercent';Expression={[math]::Round(($_.CpuUsageMhz/$_.CpuTotalMhz)*100,1)}},
                @{Name='MemoryUsagePercent';Expression={[math]::Round(($_.MemoryUsageGB/$_.MemoryTotalGB)*100,1)}}
            
            $data.VMs = Get-VM -Server $conn -ErrorAction Stop | 
                Select-Object Name, PowerState, NumCpu, MemoryGB, @{Name='MemoryGBFormatted';Expression={[math]::Round($_.MemoryGB,1)}}
            
            $data.Datastores = Get-Datastore -Server $conn -ErrorAction Stop | 
                Select-Object Name, FreeSpaceGB, CapacityGB, 
                @{Name='UsedGB';Expression={[math]::Round($_.CapacityGB - $_.FreeSpaceGB,1)}},
                @{Name='PercentFree';Expression={[math]::Round(($_.FreeSpaceGB/$_.CapacityGB)*100,1)}}
            
            $data.Events = Get-VIEvent -Server $conn -MaxSamples 10 -ErrorAction SilentlyContinue | 
                Select-Object CreatedTime, @{Name='Type';Expression={$_.GetType().Name}}, FullFormattedMessage, ObjectName
            
            $lblConnectionInfo.Text = "Connected to: $($data.HostInfo.Name) | vSphere $($data.HostInfo.Version)"
        }
        catch {
            $offlineMode = $true
            $global:VMwareConfig.OfflineMode = $true
            $lblStatus.Text = "OFFLINE MODE"
            $lblStatus.ForeColor = $theme.Warning
            $statusBar.BackColor = [System.Drawing.Color]::LightGoldenrodYellow
            $lblConnectionInfo.Text = "Connection Error: $($_.Exception.Message.Split("`n")[0])"
        }
    }
    else {
        $lblConnectionInfo.Text = "Working with cached data - last online: $(Get-Date -Format 'g')"
    }

    # -----------------------------
    # Quick Stats Cards
    # -----------------------------
    $statsPanel = New-Object System.Windows.Forms.Panel
    $statsPanel.Location = New-Object System.Drawing.Point(20, $yPos)
    $statsPanel.Size = New-Object System.Drawing.Size(900, 120)
    $mainPanel.Controls.Add($statsPanel)

    $statCards = @(
        @{ 
            Title = "TOTAL VMS" 
            Value = if ($data.VMs) { $data.VMs.Count } else { "-" }
            Icon = "&#128250;"
            Trend = if ($data.VMs) { "+2" } else { $null }
        },
        @{ 
            Title = "RUNNING VMS" 
            Value = if ($data.VMs) { 
                $running = ($data.VMs | Where-Object { $_.PowerState -eq 'PoweredOn' }).Count
                "$running ($([math]::Round(($running/$data.VMs.Count)*100))%"
            } else { "-" }
            Icon = "⚡"
            Trend = if ($data.VMs) { "-1" } else { $null }
        },
        @{ 
            Title = "CPU USAGE" 
            Value = if ($data.HostInfo) { "$($data.HostInfo.CpuUsagePercent)%" } else { "-" }
            Icon = "⏱️"
            Warning = $data.HostInfo -and $data.HostInfo.CpuUsagePercent -gt 80
            Trend = if ($data.HostInfo) { "+5%" } else { $null }
        },
        @{ 
            Title = "MEMORY USAGE" 
            Value = if ($data.HostInfo) { "$($data.HostInfo.MemoryUsagePercent)%" } else { "-" }
            Icon = "🧠"
            Warning = $data.HostInfo -and $data.HostInfo.MemoryUsagePercent -gt 80
            Trend = if ($data.HostInfo) { "+3%" } else { $null }
        },
        @{ 
            Title = "DATASTORES" 
            Value = if ($data.Datastores) { $data.Datastores.Count } else { "-" }
            Icon = "💾"
            Warning = $data.Datastores -and ($data.Datastores | Where-Object { $_.PercentFree -lt 15 }).Count -gt 0
        }
    )

    $xCard = 0
    foreach ($card in $statCards) {
        $cardPanel = New-Object System.Windows.Forms.Panel
        $cardPanel.Location = New-Object System.Drawing.Point($xCard, 0)
        $cardPanel.Size = New-Object System.Drawing.Size(170, 110)
        $cardPanel.BackColor = $theme.CardBackground
        $cardPanel.BorderStyle = 'FixedSingle'

        # Card header
        $lblCardTitle = New-Object System.Windows.Forms.Label
        $lblCardTitle.Text = $card.Title
        $lblCardTitle.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
        $lblCardTitle.ForeColor = $theme.TextSecondary
        $lblCardTitle.Location = New-Object System.Drawing.Point(10, 10)
        $lblCardTitle.AutoSize = $true
        $cardPanel.Controls.Add($lblCardTitle)

        # Card value
        $lblCardValue = New-Object System.Windows.Forms.Label
        $lblCardValue.Text = $card.Value
        $lblCardValue.Font = New-Object System.Drawing.Font("Segoe UI", 24, [System.Drawing.FontStyle]::Bold)
        $lblCardValue.ForeColor = if ($card.Warning) { $theme.Warning } else { $theme.Accent }
        $lblCardValue.Location = New-Object System.Drawing.Point(10, 30)
        $lblCardValue.AutoSize = $true
        $cardPanel.Controls.Add($lblCardValue)

        # Card footer
        $footerPanel = New-Object System.Windows.Forms.Panel
        $footerPanel.Location = New-Object System.Drawing.Point(0, 80)
        $footerPanel.Size = New-Object System.Drawing.Size(168, 30)
        $footerPanel.BackColor = [System.Drawing.Color]::FromArgb(245, 245, 245)
        $cardPanel.Controls.Add($footerPanel)

        # Icon
        $lblIcon = New-Object System.Windows.Forms.Label
        $lblIcon.Text = $card.Icon
        $lblIcon.Font = New-Object System.Drawing.Font("Segoe UI", 12)
        $lblIcon.Location = New-Object System.Drawing.Point(10, 5)
        $lblIcon.AutoSize = $true
        $footerPanel.Controls.Add($lblIcon)

        # Trend indicator if available
        if ($card.Trend) {
            $lblTrend = New-Object System.Windows.Forms.Label
            $lblTrend.Text = $card.Trend
            $lblTrend.Font = New-Object System.Drawing.Font("Segoe UI", 9)
            $lblTrend.ForeColor = if ($card.Trend -match "\+") { $theme.Warning } else { $theme.Success }
            $lblTrend.Location = New-Object System.Drawing.Point(120, 5)
            $lblTrend.AutoSize = $true
            $footerPanel.Controls.Add($lblTrend)
        }

        $statsPanel.Controls.Add($cardPanel)
        $xCard += 180
    }

    $yPos += 130

    # -----------------------------
    # Resource Utilization Section
    # -----------------------------
    $sectionHeader = New-Object System.Windows.Forms.Label
    $sectionHeader.Text = "RESOURCE UTILIZATION"
    $sectionHeader.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $sectionHeader.ForeColor = $theme.Accent
    $sectionHeader.Location = New-Object System.Drawing.Point(20, $yPos)
    $sectionHeader.AutoSize = $true
    $mainPanel.Controls.Add($sectionHeader)

    $yPos += 30

    if (-not $offlineMode -and $data.HostInfo) {
        # Create a panel for charts
        $chartsPanel = New-Object System.Windows.Forms.Panel
        $chartsPanel.Location = New-Object System.Drawing.Point(20, $yPos)
        $chartsPanel.Size = New-Object System.Drawing.Size(900, 250)
        $mainPanel.Controls.Add($chartsPanel)

        # CPU Usage Gauge
        $cpuGauge = New-Object System.Windows.Forms.DataVisualization.Charting.Chart
        $cpuGauge.Location = New-Object System.Drawing.Point(0, 0)
        $cpuGauge.Size = New-Object System.Drawing.Size(430, 250)
        $cpuGauge.BackColor = $theme.CardBackground
        $cpuGauge.BorderlineColor = [System.Drawing.Color]::LightGray
        $cpuGauge.BorderlineDashStyle = 'Solid'
        $cpuGauge.BorderlineWidth = 1
        
        $cpuArea = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea
        $cpuArea.AxisX.MajorGrid.Enabled = $false
        $cpuArea.AxisY.MajorGrid.Enabled = $false
        $cpuArea.AxisY.Maximum = 100
        $cpuArea.AxisY.Minimum = 0
        $cpuGauge.ChartAreas.Add($cpuArea)
        
        $cpuSeries = New-Object System.Windows.Forms.DataVisualization.Charting.Series
        $cpuSeries.ChartType = 'Gauge'
        $cpuSeries.Points.AddXY("CPU", $data.HostInfo.CpuUsagePercent)
        $cpuSeries["CircularLabelsStyle"] = "Auto"
        $cpuGauge.Series.Add($cpuSeries)
        
        $cpuGauge.Titles.Add("CPU USAGE") | Out-Null
        $chartsPanel.Controls.Add($cpuGauge)

        # Memory Usage Gauge
        $memGauge = New-Object System.Windows.Forms.DataVisualization.Charting.Chart
        $memGauge.Location = New-Object System.Drawing.Point(450, 0)
        $memGauge.Size = New-Object System.Drawing.Size(430, 250)
        $memGauge.BackColor = $theme.CardBackground
        $memGauge.BorderlineColor = [System.Drawing.Color]::LightGray
        $memGauge.BorderlineDashStyle = 'Solid'
        $memGauge.BorderlineWidth = 1
        
        $memArea = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea
        $memArea.AxisX.MajorGrid.Enabled = $false
        $memArea.AxisY.MajorGrid.Enabled = $false
        $memArea.AxisY.Maximum = 100
        $memArea.AxisY.Minimum = 0
        $memGauge.ChartAreas.Add($memArea)
        
        $memSeries = New-Object System.Windows.Forms.DataVisualization.Charting.Series
        $memSeries.ChartType = 'Gauge'
        $memSeries.Points.AddXY("Memory", $data.HostInfo.MemoryUsagePercent)
        $memSeries["CircularLabelsStyle"] = "Auto"
        $memGauge.Series.Add($memSeries)
        
        $memGauge.Titles.Add("MEMORY USAGE") | Out-Null
        $chartsPanel.Controls.Add($memGauge)

        $yPos += 260
    }
    else {
        $offlinePanel = New-Object System.Windows.Forms.Panel
        $offlinePanel.Location = New-Object System.Drawing.Point(20, $yPos)
        $offlinePanel.Size = New-Object System.Drawing.Size(900, 100)
        $offlinePanel.BackColor = $theme.CardBackground
        $offlinePanel.BorderStyle = 'FixedSingle'
        $mainPanel.Controls.Add($offlinePanel)

        $lblOfflineMsg = New-Object System.Windows.Forms.Label
        $lblOfflineMsg.Text = "Resource monitoring requires an active connection to vCenter"
        $lblOfflineMsg.Font = New-Object System.Drawing.Font("Segoe UI", 12)
        $lblOfflineMsg.ForeColor = $theme.TextSecondary
        $lblOfflineMsg.Location = New-Object System.Drawing.Point(20, 40)
        $lblOfflineMsg.AutoSize = $true
        $offlinePanel.Controls.Add($lblOfflineMsg)

        $yPos += 120
    }

    # -----------------------------
    # Recent Alerts Section
    # -----------------------------
    $sectionHeader = New-Object System.Windows.Forms.Label
    $sectionHeader.Text = "RECENT ALERTS"
    $sectionHeader.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $sectionHeader.ForeColor = $theme.Accent
    $sectionHeader.Location = New-Object System.Drawing.Point(20, $yPos)
    $sectionHeader.AutoSize = $true
    $mainPanel.Controls.Add($sectionHeader)

    $yPos += 30

    # Create alerts table
    $alertsTable = New-Object System.Windows.Forms.DataGridView
    $alertsTable.Location = New-Object System.Drawing.Point(20, $yPos)
    $alertsTable.Size = New-Object System.Drawing.Size(900, 200)
    $alertsTable.BackgroundColor = $theme.CardBackground
    $alertsTable.BorderStyle = 'FixedSingle'
    $alertsTable.RowHeadersVisible = $false
    $alertsTable.AutoSizeColumnsMode = 'Fill'
    $alertsTable.SelectionMode = 'FullRowSelect'
    $alertsTable.ReadOnly = $true
    $alertsTable.ColumnHeadersDefaultCellStyle = @{
        Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
        BackColor = [System.Drawing.Color]::FromArgb(230, 230, 230)
    }
    $alertsTable.AlternatingRowsDefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(245, 245, 245)

    # Add columns
    $columns = @(
        @{ Name = "Time"; HeaderText = "TIME" },
        @{ Name = "Severity"; HeaderText = "SEVERITY" },
        @{ Name = "Message"; HeaderText = "MESSAGE" },
        @{ Name = "Object"; HeaderText = "OBJECT" }
    )

    foreach ($col in $columns) {
        $column = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
        $column.Name = $col.Name
        $column.HeaderText = $col.HeaderText
        $alertsTable.Columns.Add($column)
    }

    # Add sample data or placeholder
    if ($data.Events -and $data.Events.Count -gt 0) {
        foreach ($event in $data.Events) {
            $row = New-Object System.Windows.Forms.DataGridViewRow
            $row.CreateCells($alertsTable)
            $row.Cells[0].Value = $event.CreatedTime.ToString("g")
            $row.Cells[1].Value = $event.GetType().Name
            $row.Cells[2].Value = $event.FullFormattedMessage
            $row.Cells[3].Value = $event.ObjectName
            $alertsTable.Rows.Add($row)
        }
    }
    else {
        $row = New-Object System.Windows.Forms.DataGridViewRow
        $row.CreateCells($alertsTable)
        $row.Cells[0].Value = Get-Date -Format "g"
        $row.Cells[1].Value = "Information"
        $row.Cells[2].Value = "No recent alerts found"
        $row.Cells[3].Value = "System"
        $row.DefaultCellStyle.ForeColor = $theme.TextSecondary
        $alertsTable.Rows.Add($row)
    }

    $mainPanel.Controls.Add($alertsTable)
    $yPos += 210

    # -----------------------------
    # Storage Overview Section
    # -----------------------------
    $sectionHeader = New-Object System.Windows.Forms.Label
    $sectionHeader.Text = "STORAGE OVERVIEW"
    $sectionHeader.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $sectionHeader.ForeColor = $theme.Accent
    $sectionHeader.Location = New-Object System.Drawing.Point(20, $yPos)
    $sectionHeader.AutoSize = $true
    $mainPanel.Controls.Add($sectionHeader)

    $yPos += 30

    # Create storage table
    $storageTable = New-Object System.Windows.Forms.DataGridView
    $storageTable.Location = New-Object System.Drawing.Point(20, $yPos)
    $storageTable.Size = New-Object System.Drawing.Size(900, 200)
    $storageTable.BackgroundColor = $theme.CardBackground
    $storageTable.BorderStyle = 'FixedSingle'
    $storageTable.RowHeadersVisible = $false
    $storageTable.AutoSizeColumnsMode = 'Fill'
    $storageTable.SelectionMode = 'FullRowSelect'
    $storageTable.ReadOnly = $true
    $storageTable.ColumnHeadersDefaultCellStyle = @{
        Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
        BackColor = [System.Drawing.Color]::FromArgb(230, 230, 230)
    }
    $storageTable.AlternatingRowsDefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(245, 245, 245)

    # Add columns with progress bars
    $storageColumns = @(
        @{ Name = "Name"; HeaderText = "DATASTORE" },
        @{ Name = "Capacity"; HeaderText = "CAPACITY (GB)" },
        @{ Name = "Used"; HeaderText = "USED (GB)" },
        @{ Name = "Free"; HeaderText = "FREE (GB)" },
        @{ Name = "Usage"; HeaderText = "USAGE" }
    )

    foreach ($col in $storageColumns) {
        $column = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
        $column.Name = $col.Name
        $column.HeaderText = $col.HeaderText
        $storageTable.Columns.Add($column)
    }

    # Add storage data or placeholder
    if ($data.Datastores -and $data.Datastores.Count -gt 0) {
        foreach ($ds in $data.Datastores) {
            $usagePercent = 100 - $ds.PercentFree
            $row = New-Object System.Windows.Forms.DataGridViewRow
            $row.CreateCells($storageTable)
            $row.Cells[0].Value = $ds.Name
            $row.Cells[1].Value = [math]::Round($ds.CapacityGB, 1)
            $row.Cells[2].Value = [math]::Round($ds.CapacityGB - $ds.FreeSpaceGB, 1)
            $row.Cells[3].Value = [math]::Round($ds.FreeSpaceGB, 1)
            $row.Cells[4].Value = "$usagePercent%"
            
            # Highlight low space datastores
            if ($ds.PercentFree -lt 15) {
                $row.Cells[4].Style.ForeColor = $theme.Warning
                $row.Cells[4].Style.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
            }
            
            $storageTable.Rows.Add($row)
        }
    }
    else {
        $row = New-Object System.Windows.Forms.DataGridViewRow
        $row.CreateCells($storageTable)
        $row.Cells[0].Value = "No storage data available"
        $row.Cells[1].Value = "-"
        $row.Cells[2].Value = "-"
        $row.Cells[3].Value = "-"
        $row.Cells[4].Value = "-"
        $row.DefaultCellStyle.ForeColor = $theme.TextSecondary
        $storageTable.Rows.Add($row)
    }

    $mainPanel.Controls.Add($storageTable)
    $yPos += 220

    # -----------------------------
    # Action Buttons
    # -----------------------------
    $actionPanel = New-Object System.Windows.Forms.Panel
    $actionPanel.Location = New-Object System.Drawing.Point(20, $yPos)
    $actionPanel.Size = New-Object System.Drawing.Size(900, 60)
    $mainPanel.Controls.Add($actionPanel)

    # Refresh button
    $btnRefresh = New-Object System.Windows.Forms.Button
    $btnRefresh.Text = "⟳ REFRESH"
    $btnRefresh.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $btnRefresh.Size = New-Object System.Drawing.Size(150, 40)
    $btnRefresh.Location = New-Object System.Drawing.Point(0, 10)
    $btnRefresh.BackColor = $theme.Accent
    $btnRefresh.ForeColor = [System.Drawing.Color]::White
    $btnRefresh.FlatStyle = 'Flat'
    $btnRefresh.FlatAppearance.BorderSize = 0
    $btnRefresh.Add_Click({
        $global:VMwareConfig.OfflineMode = $false
        Show-DashboardView -ContentPanel $ContentPanel
    })
    $actionPanel.Controls.Add($btnRefresh)

    # Offline mode toggle
    $btnOffline = New-Object System.Windows.Forms.Button
    $btnOffline.Text = if ($offlineMode) { "↻ GO ONLINE" } else { "⚡ WORK OFFLINE" }
    $btnOffline.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $btnOffline.Size = New-Object System.Drawing.Size(150, 40)
    $btnOffline.Location = New-Object System.Drawing.Point(160, 10)
    $btnOffline.BackColor = if ($offlineMode) { $theme.Success } else { [System.Drawing.Color]::Goldenrod }
    $btnOffline.ForeColor = [System.Drawing.Color]::White
    $btnOffline.FlatStyle = 'Flat'
    $btnOffline.FlatAppearance.BorderSize = 0
    $btnOffline.Add_Click({
        $global:VMwareConfig.OfflineMode = -not $global:VMwareConfig.OfflineMode
        Show-DashboardView -ContentPanel $ContentPanel
    })
    $actionPanel.Controls.Add($btnOffline)

    # Add some breathing room at bottom
    $yPos += 80
}