<#
.SYNOPSIS
    VMware Network Management View.
.DESCRIPTION
    GUI for managing vSwitches and port groups:
    - View existing port groups
    - Add/remove single network
    - Bulk-add or bulk-remove student networks

    Depends on: VMwareModels.psm1
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Load core module if not already loaded
if (-not (Get-Command ConnectTo-VMServer -ErrorAction SilentlyContinue)) {
    Import-Module "$PSScriptRoot\..\VMwareModels.psm1" -ErrorAction Stop
}

# -------------------------------------------------------------------
# Entry Point: Renders view into a given panel
# -------------------------------------------------------------------
function Show-View {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [System.Windows.Forms.Panel]$ParentPanel
    )

    # Clear previous content
    $ParentPanel.Controls.Clear()

    # -----------------------------
    # Section: Header + Network list
    # -----------------------------

    $lblHeader = New-Object Windows.Forms.Label
    $lblHeader.Text = "Existing Networks"
    $lblHeader.Font = New-Object Drawing.Font("Segoe UI", 12, [Drawing.FontStyle]::Bold)
    $lblHeader.Location = New-Object Drawing.Point(10, 10)
    $lblHeader.AutoSize = $true
    $ParentPanel.Controls.Add($lblHeader)

    $networkList = New-Object Windows.Forms.ListBox
    $networkList.Location = New-Object Drawing.Point(10, 40)
    $networkList.Size = New-Object Drawing.Size(400, 100)
    $ParentPanel.Controls.Add($networkList)

    try {
        ConnectTo-VMServer
        $networkList.Items.AddRange([VMwareNetwork]::ListNetworks())
    } catch {
        $networkList.Items.Add("Error loading networks: $_")
    }

    # -----------------------------
    # Section: Single network entry
    # -----------------------------

    $lblSingle = New-Object Windows.Forms.Label
    $lblSingle.Text = "Network Name:"
    $lblSingle.Location = New-Object Drawing.Point(10, 150)
    $lblSingle.Size = New-Object Drawing.Size(100, 20)
    $ParentPanel.Controls.Add($lblSingle)

    $txtSingle = New-Object Windows.Forms.TextBox
    $txtSingle.Location = New-Object Drawing.Point(120, 150)
    $txtSingle.Size = New-Object Drawing.Size(200, 20)
    $ParentPanel.Controls.Add($txtSingle)

    $btnAdd = New-Object Windows.Forms.Button
    $btnAdd.Text = "Add"
    $btnAdd.Size = New-Object Drawing.Size(80, 28)
    $btnAdd.Location = New-Object Drawing.Point(330, 146)
    $btnAdd.Add_Click({
        try {
            $instance = [VMwareNetwork]::GetInstance()
            $instance.AddNetwork($txtSingle.Text)
            $networkList.Items.Add($txtSingle.Text)
            [Windows.Forms.MessageBox]::Show("Network added successfully.","Success")
        } catch {
            [Windows.Forms.MessageBox]::Show("Add failed: $_","Error")
        }
    })
    $ParentPanel.Controls.Add($btnAdd)

    $btnRemove = New-Object Windows.Forms.Button
    $btnRemove.Text = "Remove"
    $btnRemove.Size = New-Object Drawing.Size(80, 28)
    $btnRemove.Location = New-Object Drawing.Point(330, 180)
    $btnRemove.Add_Click({
        try {
            $instance = [VMwareNetwork]::GetInstance()
            $instance.RemoveNetwork($txtSingle.Text)
            $networkList.Items.Remove($txtSingle.Text)
            [Windows.Forms.MessageBox]::Show("Network removed.","Deleted")
        } catch {
            [Windows.Forms.MessageBox]::Show("Remove failed: $_","Error")
        }
    })
    $ParentPanel.Controls.Add($btnRemove)

    # -----------------------------
    # Section: Bulk controls
    # -----------------------------

    $lblBulk = New-Object Windows.Forms.Label
    $lblBulk.Text = "Bulk Network Actions"
    $lblBulk.Font = New-Object Drawing.Font("Segoe UI", 10, [Drawing.FontStyle]::Bold)
    $lblBulk.Location = New-Object Drawing.Point(10, 220)
    $lblBulk.AutoSize = $true
    $ParentPanel.Controls.Add($lblBulk)

    # Course
    $lblCourse = New-Object Windows.Forms.Label
    $lblCourse.Text = "Course:"
    $lblCourse.Location = New-Object Drawing.Point(10, 250)
    $ParentPanel.Controls.Add($lblCourse)

    $txtCourse = New-Object Windows.Forms.TextBox
    $txtCourse.Location = New-Object Drawing.Point(120, 250)
    $txtCourse.Size = New-Object Drawing.Size(120, 20)
    $ParentPanel.Controls.Add($txtCourse)

    # Start
    $lblStart = New-Object Windows.Forms.Label
    $lblStart.Text = "Start:"
    $lblStart.Location = New-Object Drawing.Point(10, 280)
    $ParentPanel.Controls.Add($lblStart)

    $txtStart = New-Object Windows.Forms.TextBox
    $txtStart.Location = New-Object Drawing.Point(120, 280)
    $txtStart.Size = New-Object Drawing.Size(60, 20)
    $ParentPanel.Controls.Add($txtStart)

    # End
    $lblEnd = New-Object Windows.Forms.Label
    $lblEnd.Text = "End:"
    $lblEnd.Location = New-Object Drawing.Point(200, 280)
    $ParentPanel.Controls.Add($lblEnd)

    $txtEnd = New-Object Windows.Forms.TextBox
    $txtEnd.Location = New-Object Drawing.Point(250, 280)
    $txtEnd.Size = New-Object Drawing.Size(60, 20)
    $ParentPanel.Controls.Add($txtEnd)

    # Bulk Add
    $btnBulkAdd = New-Object Windows.Forms.Button
    $btnBulkAdd.Text = "Bulk Add"
    $btnBulkAdd.Location = New-Object Drawing.Point(10, 320)
    $btnBulkAdd.Size = New-Object Drawing.Size(100, 30)
    $btnBulkAdd.Add_Click({
        try {
            $instance = [VMwareNetwork]::GetInstance()
            $instance.BulkAddNetworks($txtCourse.Text, [int]$txtStart.Text, [int]$txtEnd.Text)
            [Windows.Forms.MessageBox]::Show("Bulk networks added.","Success")
        } catch {
            [Windows.Forms.MessageBox]::Show("Bulk add failed: $_","Error")
        }
    })
    $ParentPanel.Controls.Add($btnBulkAdd)

    # Bulk Remove
    $btnBulkRemove = New-Object Windows.Forms.Button
    $btnBulkRemove.Text = "Bulk Remove"
    $btnBulkRemove.Location = New-Object Drawing.Point(130, 320)
    $btnBulkRemove.Size = New-Object Drawing.Size(100, 30)
    $btnBulkRemove.Add_Click({
        try {
            $instance = [VMwareNetwork]::GetInstance()
            $instance.BulkRemoveNetworks([int]$txtStart.Text, [int]$txtEnd.Text, $txtCourse.Text)
            [Windows.Forms.MessageBox]::Show("Bulk networks removed.","Success")
        } catch {
            [Windows.Forms.MessageBox]::Show("Bulk remove failed: $_","Error")
        }
    })
    $ParentPanel.Controls.Add($btnBulkRemove)
}

Export-ModuleMember -Function Show-View