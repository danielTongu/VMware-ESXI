<#
.SYNOPSIS
    Renders the "Virtual Machines" screen with full VM administration controls.

.DESCRIPTION
    This function builds the VM Tasks view by:
      1. Clearing any existing controls from the content panel.
      2. Declaring all UI components (labels, textboxes, buttons, grid).
      3. Configuring each component’s properties (text, size, location, behavior).
      4. Wiring event handlers for:
         - Refreshing the VM list
         - Powering on/off all VMs
         - Restarting all VMs
         - Powering on/off a specific VM by name
      5. Adding all components to the panel in the correct order.

.PARAMETER ContentPanel
    The System.Windows.Forms.Panel into which the VM Tasks controls are placed.
#>
function Show-VMsView {
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
    # Static text and input
    $labelTitle               = New-Object System.Windows.Forms.Label
    $labelVMName              = New-Object System.Windows.Forms.Label
    $textboxVMName            = New-Object System.Windows.Forms.TextBox

    # Buttons for VM operations
    $buttonRefresh            = New-Object System.Windows.Forms.Button
    $buttonPowerOnAll         = New-Object System.Windows.Forms.Button
    $buttonPowerOffAll        = New-Object System.Windows.Forms.Button
    $buttonRestartAll         = New-Object System.Windows.Forms.Button
    $buttonPowerOnSpecific    = New-Object System.Windows.Forms.Button
    $buttonPowerOffSpecific   = New-Object System.Windows.Forms.Button

    # Data grid to list VMs
    $dataGridVMs              = New-Object System.Windows.Forms.DataGridView

    # -------------------------------------------------------------------------
    # 2) Configure component properties
    # -------------------------------------------------------------------------

    ## 2.1 Title Label
    $labelTitle.Text     = 'Virtual Machines'
    $labelTitle.Font     = [System.Drawing.Font]::new('Segoe UI',20,[System.Drawing.FontStyle]::Bold)
    $labelTitle.AutoSize = $true
    $labelTitle.Location = [System.Drawing.Point]::new(30,20)

    ## 2.2 VM Name filter label and textbox
    $labelVMName.Text     = 'VM Name:'
    $labelVMName.AutoSize = $true
    $labelVMName.Location = [System.Drawing.Point]::new(170,85)

    $textboxVMName.Size     = [System.Drawing.Size]::new(200,22)
    $textboxVMName.Location = [System.Drawing.Point]::new(240,82)

    ## 2.3 Refresh Button
    $buttonRefresh.Text     = 'Refresh'
    $buttonRefresh.Size     = [System.Drawing.Size]::new(120,30)
    $buttonRefresh.Location = [System.Drawing.Point]::new(30,80)

    ## 2.4 Power On / Off All Buttons
    $buttonPowerOnAll.Text     = 'Power On All'
    $buttonPowerOnAll.Size     = [System.Drawing.Size]::new(120,30)
    $buttonPowerOnAll.Location = [System.Drawing.Point]::new(460,80)

    $buttonPowerOffAll.Text     = 'Power Off All'
    $buttonPowerOffAll.Size     = [System.Drawing.Size]::new(120,30)
    $buttonPowerOffAll.Location = [System.Drawing.Point]::new(590,80)

    ## 2.5 Restart All Button
    $buttonRestartAll.Text     = 'Restart All'
    $buttonRestartAll.Size     = [System.Drawing.Size]::new(120,30)
    $buttonRestartAll.Location = [System.Drawing.Point]::new(720,80)

    ## 2.6 Power On / Off Specific Buttons
    $buttonPowerOnSpecific.Text     = 'Power On VM'
    $buttonPowerOnSpecific.Size     = [System.Drawing.Size]::new(120,30)
    $buttonPowerOnSpecific.Location = [System.Drawing.Point]::new(30,120)

    $buttonPowerOffSpecific.Text     = 'Power Off VM'
    $buttonPowerOffSpecific.Size     = [System.Drawing.Size]::new(120,30)
    $buttonPowerOffSpecific.Location = [System.Drawing.Point]::new(170,120)

    ## 2.7 DataGridView for VM listing
    $dataGridVMs.Location              = [System.Drawing.Point]::new(30,170)
    $dataGridVMs.Size                  = [System.Drawing.Size]::new(820,400)
    $dataGridVMs.AutoSizeColumnsMode   = 'Fill'
    $dataGridVMs.ReadOnly              = $true
    $dataGridVMs.SelectionMode         = 'FullRowSelect'
    $dataGridVMs.AllowUserToAddRows    = $false
    $dataGridVMs.AllowUserToDeleteRows = $false
    $dataGridVMs.RowHeadersVisible     = $false
    foreach ($colName in 'Class','Student','Name','State','IP','CPU','MemoryMB') {
        $col = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
        $col.Name             = $colName
        $col.HeaderText       = $colName
        $col.DataPropertyName = $colName
        $dataGridVMs.Columns.Add($col) | Out-Null
    }
    $dataGridVMs.Tag = 'VMGrid'

    # -------------------------------------------------------------------------
    # 3) Wire event handlers
    # -------------------------------------------------------------------------
    # Refresh VM list from backend
    $buttonRefresh.Add_Click({
        On-RefreshVMsClick
    })

    # Power on all VMs
    $buttonPowerOnAll.Add_Click({
        $result = Invoke-PowerOnAllVMs ''
        [System.Windows.Forms.MessageBox]::Show($result,'Power On All VMs')
        On-RefreshVMsClick
    })

    # Power off all VMs
    $buttonPowerOffAll.Add_Click({
        $result = Invoke-PowerOffAllVMs ''
        [System.Windows.Forms.MessageBox]::Show($result,'Power Off All VMs')
        On-RefreshVMsClick
    })

    # Restart all VMs
    $buttonRestartAll.Add_Click({
        $result = Invoke-RestartAllVMs ''
        [System.Windows.Forms.MessageBox]::Show($result,'Restart All VMs')
        On-RefreshVMsClick
    })

    # Power on specific VM by name
    $buttonPowerOnSpecific.Add_Click({
        $vmName = $textboxVMName.Text.Trim()
        if (-not $vmName) {
            [System.Windows.Forms.MessageBox]::Show('Please enter a VM name.','Error')
            return
        }
        $args = "-VMName '$vmName'"
        $result = Invoke-PowerOnSpecificClassVMs $args
        [System.Windows.Forms.MessageBox]::Show($result,'Power On VM')
        On-RefreshVMsClick
    })

    # Power off specific VM by name
    $buttonPowerOffSpecific.Add_Click({
        $vmName = $textboxVMName.Text.Trim()
        if (-not $vmName) {
            [System.Windows.Forms.MessageBox]::Show('Please enter a VM name.','Error')
            return
        }
        $args = "-VMName '$vmName'"
        $result = Invoke-PowerOffSpecificClassVMs $args
        [System.Windows.Forms.MessageBox]::Show($result,'Power Off VM')
        On-RefreshVMsClick
    })

    # -------------------------------------------------------------------------
    # 4) Add components to the panel
    # -------------------------------------------------------------------------
    $ContentPanel.Controls.AddRange(@(
        $labelTitle,
        $buttonRefresh,
        $labelVMName,
        $textboxVMName,
        $buttonPowerOnAll,
        $buttonPowerOffAll,
        $buttonRestartAll,
        $buttonPowerOnSpecific,
        $buttonPowerOffSpecific,
        $dataGridVMs
    ))
}

Export-ModuleMember -Function Show-VMsView