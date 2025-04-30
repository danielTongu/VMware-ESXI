<#
.SYNOPSIS
    Renders the Dashboard “at-a-glance” overview screen with a scrollable layout.

.DESCRIPTION
    Shows summary panels for Classes, Networks, and VMs:
      - Total counts
      - Lists of items
    Uses a FlowLayoutPanel inside a scrollable container so that if the window is
    resized smaller, scrollbars appear.  Organizes the three summary panels
    side-by-side.

.PARAMETER ContentPanel
    The WinForms Panel into which dashboard controls are injected.
#>
function Show-DashboardView {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Forms.Panel] $ContentPanel
    )

    # -------------------------------------------------------------------------
    # 0) Clear existing controls & enable scrolling
    # -------------------------------------------------------------------------
    $ContentPanel.Controls.Clear()
    $ContentPanel.AutoScroll = $true

    # -------------------------------------------------------------------------
    # 1) Declare UI components
    # -------------------------------------------------------------------------
    $labelTitle        = New-Object System.Windows.Forms.Label
    $buttonRefresh     = New-Object System.Windows.Forms.Button
    $flowPanel         = New-Object System.Windows.Forms.FlowLayoutPanel

    # Summary groups
    $groupClasses      = New-Object System.Windows.Forms.GroupBox
    $labelClassCount   = New-Object System.Windows.Forms.Label
    $listClasses       = New-Object System.Windows.Forms.ListBox

    $groupNetworks     = New-Object System.Windows.Forms.GroupBox
    $labelNetworkCount = New-Object System.Windows.Forms.Label
    $listNetworks      = New-Object System.Windows.Forms.ListBox

    $groupVMs          = New-Object System.Windows.Forms.GroupBox
    $labelVMCount      = New-Object System.Windows.Forms.Label
    $listVMs           = New-Object System.Windows.Forms.ListBox

    # -------------------------------------------------------------------------
    # 2) Configure component properties
    # -------------------------------------------------------------------------

    ## Title
    $labelTitle.Text     = 'Dashboard Overview'
    $labelTitle.Font     = [System.Drawing.Font]::new('Segoe UI',24,[System.Drawing.FontStyle]::Bold)
    $labelTitle.AutoSize = $true
    $labelTitle.Location = [System.Drawing.Point]::new(20,20)

    ## Refresh button
    $buttonRefresh.Text     = 'Refresh'
    $buttonRefresh.Size     = [System.Drawing.Size]::new(100,30)
    $buttonRefresh.Location = [System.Drawing.Point]::new(360,25)

    ## FlowLayoutPanel to hold the three group boxes
    $flowPanel.Location       = [System.Drawing.Point]::new(20,80)
    $flowPanel.Size           = [System.Drawing.Size]::new(960,260)
    $flowPanel.AutoSize       = $false
    $flowPanel.WrapContents   = $false
    $flowPanel.AutoScroll     = $false
    $flowPanel.FlowDirection  = 'LeftToRight'

    ## Classes group
    $groupClasses.Text     = 'Classes'
    $groupClasses.Font     = [System.Drawing.Font]::new('Segoe UI',10,[System.Drawing.FontStyle]::Bold)
    $groupClasses.Size     = [System.Drawing.Size]::new(300,240)
    # Count label
    $labelClassCount.AutoSize = $true
    $labelClassCount.Location = [System.Drawing.Point]::new(10,30)
    # List
    $listClasses.Location   = [System.Drawing.Point]::new(10,60)
    $listClasses.Size       = [System.Drawing.Size]::new(280,160)

    ## Networks group
    $groupNetworks.Text     = 'Networks'
    $groupNetworks.Font     = [System.Drawing.Font]::new('Segoe UI',10,[System.Drawing.FontStyle]::Bold)
    $groupNetworks.Size     = [System.Drawing.Size]::new(300,240)
    $labelNetworkCount.AutoSize = $true
    $labelNetworkCount.Location = [System.Drawing.Point]::new(10,30)
    $listNetworks.Location      = [System.Drawing.Point]::new(10,60)
    $listNetworks.Size          = [System.Drawing.Size]::new(280,160)

    ## VMs group
    $groupVMs.Text        = 'Powered-On VMs'
    $groupVMs.Font        = [System.Drawing.Font]::new('Segoe UI',10,[System.Drawing.FontStyle]::Bold)
    $groupVMs.Size        = [System.Drawing.Size]::new(300,240)
    $labelVMCount.AutoSize      = $true
    $labelVMCount.Location      = [System.Drawing.Point]::new(10,30)
    $listVMs.Location           = [System.Drawing.Point]::new(10,60)
    $listVMs.Size               = [System.Drawing.Size]::new(280,160)

    # -------------------------------------------------------------------------
    # 3) Wire event handlers
    # -------------------------------------------------------------------------
    $buttonRefresh.Add_Click({
        # Classes
        $classes = (Invoke-Script -ScriptName 'ListClasses.ps1' -Args '' -ErrorAction SilentlyContinue) -split "`n" |?{$_}
        $labelClassCount.Text = "$($classes.Count) classes"
        $listClasses.Items.Clear(); $listClasses.Items.AddRange($classes)

        # Networks
        $nets = (Invoke-Script -ScriptName 'ListNetworks.ps1' -Args '' -ErrorAction SilentlyContinue) -split "`n" |?{$_}
        $labelNetworkCount.Text = "$($nets.Count) networks"
        $listNetworks.Items.Clear(); $listNetworks.Items.AddRange($nets)

        # VMs
        $vms = (Invoke-ShowAllPoweredOnVMs -Args '' -ErrorAction SilentlyContinue) -split "`n" |?{$_}
        $labelVMCount.Text = "$($vms.Count) powered-on VMs"
        $listVMs.Items.Clear(); $listVMs.Items.AddRange($vms)
    })

    # -------------------------------------------------------------------------
    # 4) Add controls to their containers
    # -------------------------------------------------------------------------
    $groupClasses.Controls.AddRange(@($labelClassCount, $listClasses))
    $groupNetworks.Controls.AddRange(@($labelNetworkCount, $listNetworks))
    $groupVMs.Controls.AddRange(@($labelVMCount, $listVMs))

    $flowPanel.Controls.AddRange(@($groupClasses, $groupNetworks, $groupVMs))

    $ContentPanel.Controls.AddRange(@(
        $labelTitle,
        $buttonRefresh,
        $flowPanel
    ))

    # -------------------------------------------------------------------------
    # 5) Initial load
    # -------------------------------------------------------------------------
    $buttonRefresh.PerformClick()
}

Export-ModuleMember -Function Show-DashboardView