<#
.SYNOPSIS
    Renders the "Networks" screen in the WinForms GUI with full network management.

.DESCRIPTION
    Builds the Networks view by:
      1. Clearing existing controls.
      2. Declaring all UI components (labels, listbox, buttons, file dialog).
      3. Configuring each component’s properties (text, size, location).
      4. Wiring event handlers for:
         - Listing networks
         - Adding a single network
         - Deleting a single network
         - Bulk adding networks from CSV
         - Bulk deleting networks from CSV
      5. Adding components to the panel.

.PARAMETER ContentPanel
    The System.Windows.Forms.Panel in which to place the network controls.
#>
function Show-NetworksView {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Forms.Panel] $ContentPanel
    )

    # -------------------------------------------------------------------------
    # 0) Clear any existing controls
    # -------------------------------------------------------------------------
    $ContentPanel.Controls.Clear()

    # -------------------------------------------------------------------------
    # 1) Declare UI components
    # -------------------------------------------------------------------------
    $labelTitle       = New-Object System.Windows.Forms.Label
    $listNetworks     = New-Object System.Windows.Forms.ListBox
    $buttonList       = New-Object System.Windows.Forms.Button
    $buttonAdd        = New-Object System.Windows.Forms.Button
    $buttonDelete     = New-Object System.Windows.Forms.Button
    $buttonBulkAdd    = New-Object System.Windows.Forms.Button
    $buttonBulkDelete = New-Object System.Windows.Forms.Button
    $openFileDialog   = New-Object System.Windows.Forms.OpenFileDialog

    # -------------------------------------------------------------------------
    # 2) Configure component properties
    # -------------------------------------------------------------------------

    ## 2.1 Title label
    $labelTitle.Text     = 'Networks'
    $labelTitle.Font     = [System.Drawing.Font]::new('Segoe UI',20,[System.Drawing.FontStyle]::Bold)
    $labelTitle.AutoSize = $true
    $labelTitle.Location = [System.Drawing.Point]::new(30,20)

    ## 2.2 Networks ListBox
    $listNetworks.Location   = [System.Drawing.Point]::new(30,80)
    $listNetworks.Size       = [System.Drawing.Size]::new(300,300)
    $listNetworks.SelectionMode = 'MultiExtended'

    ## 2.3 "List" button to refresh networks
    $buttonList.Text      = 'List Networks'
    $buttonList.Size      = [System.Drawing.Size]::new(120,30)
    $buttonList.Location  = [System.Drawing.Point]::new(360,80)

    ## 2.4 Add Network button
    $buttonAdd.Text       = 'Add Network'
    $buttonAdd.Size       = [System.Drawing.Size]::new(120,30)
    $buttonAdd.Location   = [System.Drawing.Point]::new(360,130)

    ## 2.5 Delete Network button
    $buttonDelete.Text    = 'Delete Network'
    $buttonDelete.Size    = [System.Drawing.Size]::new(120,30)
    $buttonDelete.Location= [System.Drawing.Point]::new(360,180)

    ## 2.6 Bulk Add (CSV) button
    $buttonBulkAdd.Text       = 'Add from CSV'
    $buttonBulkAdd.Size       = [System.Drawing.Size]::new(120,30)
    $buttonBulkAdd.Location   = [System.Drawing.Point]::new(360,230)

    ## 2.7 Bulk Delete (CSV) button
    $buttonBulkDelete.Text    = 'Delete from CSV'
    $buttonBulkDelete.Size    = [System.Drawing.Size]::new(120,30)
    $buttonBulkDelete.Location= [System.Drawing.Point]::new(360,280)

    ## 2.8 OpenFileDialog defaults
    $openFileDialog.Filter    = 'CSV Files (*.csv)|*.csv|All Files (*.*)|*.*'
    $openFileDialog.Title     = 'Select CSV File'

    # -------------------------------------------------------------------------
    # 3) Wire event handlers
    # -------------------------------------------------------------------------

    # 3.1 List/refresh networks
    $buttonList.Add_Click({
        $listNetworks.Items.Clear()
        # Assumes a wrapper Invoke-ListNetworks returns newline-delimited names
        $raw = Invoke-Script -ScriptName 'ListNetworks.ps1' -Args ''
        foreach ($net in $raw -split "`n") {
            if ($net.Trim()) { $listNetworks.Items.Add($net.Trim()) | Out-Null }
        }
    })

    # 3.2 Add a single network
    $buttonAdd.Add_Click({
        $name = Read-Host 'Enter network name to add'
        if (-not $name.Trim()) { return }
        $result = Invoke-AddNetwork "-NetworkName '$name'"
        [System.Windows.Forms.MessageBox]::Show($result,'Add Network')
        $buttonList.PerformClick()
    })

    # 3.3 Delete selected network
    $buttonDelete.Add_Click({
        foreach ($name in $listNetworks.SelectedItems) {
            $res = Invoke-DeleteNetwork "-NetworkName '$name'"
            [System.Windows.Forms.MessageBox]::Show($res,"Delete $name")
        }
        $buttonList.PerformClick()
    })

    # 3.4 Bulk add from CSV
    $buttonBulkAdd.Add_Click({
        if ($openFileDialog.ShowDialog() -eq 'OK') {
            $path = $openFileDialog.FileName
            try {
                $csv = Import-Csv -Path $path
                foreach ($row in $csv) {
                    # assumes CSV has 'NetworkName' column
                    $name = $row.NetworkName
                    $res  = Invoke-AddNetwork "-NetworkName '$name'"
                }
                [System.Windows.Forms.MessageBox]::Show("Bulk add completed.",'Add from CSV')
                $buttonList.PerformClick()
            }
            catch {
                [System.Windows.Forms.MessageBox]::Show($_.Exception.Message,'Error')
            }
        }
    })

    # 3.5 Bulk delete from CSV
    $buttonBulkDelete.Add_Click({
        if ($openFileDialog.ShowDialog() -eq 'OK') {
            $path = $openFileDialog.FileName
            try {
                $csv = Import-Csv -Path $path
                foreach ($row in $csv) {
                    $name = $row.NetworkName
                    $res  = Invoke-DeleteNetwork "-NetworkName '$name'"
                }
                [System.Windows.Forms.MessageBox]::Show("Bulk delete completed.",'Delete from CSV')
                $buttonList.PerformClick()
            }
            catch {
                [System.Windows.Forms.MessageBox]::Show($_.Exception.Message,'Error')
            }
        }
    })

    # -------------------------------------------------------------------------
    # 4) Add components to the panel
    # -------------------------------------------------------------------------
    $ContentPanel.Controls.AddRange(@(
        $labelTitle,
        $listNetworks,
        $buttonList,
        $buttonAdd,
        $buttonDelete,
        $buttonBulkAdd,
        $buttonBulkDelete
    ))
}

Export-ModuleMember -Function Show-NetworksView