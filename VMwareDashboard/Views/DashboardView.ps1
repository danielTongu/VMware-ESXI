<#
.SYNOPSIS
    Renders the Dashboard “at-a-glance” overview screen.

.DESCRIPTION
    Shows summary panels for Classes, Networks, and VMs:
      - Total counts
      - Lists of items
    Provides a single “Refresh” button to reload all sections.

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
    # 0) Clear existing controls
    # -------------------------------------------------------------------------
    $ContentPanel.Controls.Clear()

    # -------------------------------------------------------------------------
    # 1) Declare UI components
    # -------------------------------------------------------------------------
    # Title and refresh
    $labelTitle           = New-Object System.Windows.Forms.Label
    $buttonRefresh        = New-Object System.Windows.Forms.Button

    # Classes overview group
    $groupClasses         = New-Object System.Windows.Forms.GroupBox
    $labelClassCount      = New-Object System.Windows.Forms.Label
    $listClasses          = New-Object System.Windows.Forms.ListBox

    # Networks overview group
    $groupNetworks        = New-Object System.Windows.Forms.GroupBox
    $labelNetworkCount    = New-Object System.Windows.Forms.Label
    $listNetworks         = New-Object System.Windows.Forms.ListBox

    # VMs overview group
    $groupVMs             = New-Object System.Windows.Forms.GroupBox
    $labelVMCount         = New-Object System.Windows.Forms.Label
    $listVMs              = New-Object System.Windows.Forms.ListBox

    # -------------------------------------------------------------------------
    # 2) Configure component properties
    # -------------------------------------------------------------------------

    ## 2.1 Title label
    $labelTitle.Text     = 'Dashboard Overview'
    $labelTitle.Font     = [System.Drawing.Font]::new('Segoe UI',24,[System.Drawing.FontStyle]::Bold)
    $labelTitle.AutoSize = $true
    $labelTitle.Location = [System.Drawing.Point]::new(30, 20)

    ## 2.2 Refresh button
    $buttonRefresh.Text     = 'Refresh'
    $buttonRefresh.Size     = [System.Drawing.Size]::new(100,30)
    $buttonRefresh.Location = [System.Drawing.Point]::new(360, 25)

    ## 2.3 Classes group
    $groupClasses.Text     = 'Classes'
    $groupClasses.Font     = [System.Drawing.Font]::new('Segoe UI',10,[System.Drawing.FontStyle]::Bold)
    $groupClasses.Size     = [System.Drawing.Size]::new(300,250)
    $groupClasses.Location = [System.Drawing.Point]::new(30, 80)
    # Count label
    $labelClassCount.AutoSize = $true
    $labelClassCount.Location = [System.Drawing.Point]::new(10,30)
    # List of classes
    $listClasses.Location   = [System.Drawing.Point]::new(10,60)
    $listClasses.Size       = [System.Drawing.Size]::new(280,170)

    ## 2.4 Networks group
    $groupNetworks.Text     = 'Networks'
    $groupNetworks.Font     = [System.Drawing.Font]::new('Segoe UI',10,[System.Drawing.FontStyle]::Bold)
    $groupNetworks.Size     = [System.Drawing.Size]::new(300,250)
    $groupNetworks.Location = [System.Drawing.Point]::new(350, 80)
    # Count label
    $labelNetworkCount.AutoSize   = $true
    $labelNetworkCount.Location   = [System.Drawing.Point]::new(10,30)
    # List of networks
    $listNetworks.Location        = [System.Drawing.Point]::new(10,60)
    $listNetworks.Size            = [System.Drawing.Size]::new(280,170)

    ## 2.5 VMs group
    $groupVMs.Text        = 'Powered-On VMs'
    $groupVMs.Font        = [System.Drawing.Font]::new('Segoe UI',10,[System.Drawing.FontStyle]::Bold)
    $groupVMs.Size        = [System.Drawing.Size]::new(300,250)
    $groupVMs.Location    = [System.Drawing.Point]::new(670, 80)
    # Count label
    $labelVMCount.AutoSize      = $true
    $labelVMCount.Location      = [System.Drawing.Point]::new(10,30)
    # List of VMs
    $listVMs.Location           = [System.Drawing.Point]::new(10,60)
    $listVMs.Size               = [System.Drawing.Size]::new(280,170)

    # -------------------------------------------------------------------------
    # 3) Wire event handlers
    # -------------------------------------------------------------------------
    $buttonRefresh.Add_Click({
        # Classes
        try {
            $rawClasses = Invoke-Script -ScriptName 'ListClasses.ps1' -Args ''
            $classes    = $rawClasses -split "`n" | Where-Object { $_.Trim() }
        } catch {
            $classes    = @()
        }
        $labelClassCount.Text = "$($classes.Count) classes"
        $listClasses.Items.Clear()
        $listClasses.Items.AddRange($classes)

        # Networks
        try {
            $rawNets    = Invoke-Script -ScriptName 'ListNetworks.ps1' -Args ''
            $networks   = $rawNets -split "`n" | Where-Object { $_.Trim() }
        } catch {
            $networks   = @()
        }
        $labelNetworkCount.Text = "$($networks.Count) networks"
        $listNetworks.Items.Clear()
        $listNetworks.Items.AddRange($networks)

        # VMs
        try {
            $rawVMs     = Invoke-ShowAllPoweredOnVMs -Args ''
            $vms        = $rawVMs -split "`n" | Where-Object { $_.Trim() }
        } catch {
            $vms        = @()
        }
        $labelVMCount.Text = "$($vms.Count) powered-on VMs"
        $listVMs.Items.Clear()
        $listVMs.Items.AddRange($vms)
    })

    # -------------------------------------------------------------------------
    # 4) Add components to the panel
    # -------------------------------------------------------------------------
    $ContentPanel.Controls.AddRange(@(
        $labelTitle,
        $buttonRefresh,
        # Classes
        $groupClasses,
        $labelClassCount,
        $listClasses,
        # Networks
        $groupNetworks,
        $labelNetworkCount,
        $listNetworks,
        # VMs
        $groupVMs,
        $labelVMCount,
        $listVMs
    ))

    # Trigger an initial load
    $buttonRefresh.PerformClick()
}

Export-ModuleMember -Function Show-DashboardView