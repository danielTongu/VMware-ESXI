<#
Views/NetworkManagerView.ps1

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

# Import core VMware module for network management
Import-Module "$PSScriptRoot\..\VMwareModels.psm1" -ErrorAction Stop

# -------------------------------------------------------------------
# Function: Show-NetworkManagerView
# Purpose : Build and display the network management UI
# -------------------------------------------------------------------
function Show-NetworkManagerView {
    <#
    .SYNOPSIS
        Displays the VMware network manager GUI.
    .DESCRIPTION
        Lists all networks and provides input fields to add/delete single
        or bulk networks using VMwareNetwork class methods.
    #>

    # Create form
    $form = New-Object Windows.Forms.Form
    $form.Text = "Network Manager"
    $form.Size = New-Object Drawing.Size(450, 450)
    $form.StartPosition = "CenterScreen"

    # Header label
    $header = New-Object Windows.Forms.Label
    $header.Text = "Existing Networks"
    $header.Location = New-Object Drawing.Point(20, 20)
    $header.Size = New-Object Drawing.Size(200, 20)
    $header.Font = New-Object Drawing.Font("Segoe UI", 10, [Drawing.FontStyle]::Bold)
    $form.Controls.Add($header)

    # ListBox: existing networks
    $networkList = New-Object Windows.Forms.ListBox
    $networkList.Location = New-Object Drawing.Point(20, 50)
    $networkList.Size = New-Object Drawing.Size(380, 100)
    $form.Controls.Add($networkList)

    # Load existing port groups
    $networkNames = [VMwareNetwork]::ListNetworks()
    $networkList.Items.AddRange($networkNames)

    # Input: network name (for single add/remove)
    $netLabel = New-Object Windows.Forms.Label
    $netLabel.Text = "Network Name:"
    $netLabel.Location = New-Object Drawing.Point(20, 170)
    $netLabel.Size = New-Object Drawing.Size(100, 20)
    $form.Controls.Add($netLabel)

    $netBox = New-Object Windows.Forms.TextBox
    $netBox.Location = New-Object Drawing.Point(130, 170)
    $netBox.Size = New-Object Drawing.Size(200, 20)
    $form.Controls.Add($netBox)

    # Button: Add network
    $addButton = New-Object Windows.Forms.Button
    $addButton.Text = "Add Network"
    $addButton.Size = New-Object Drawing.Size(120, 30)
    $addButton.Location = New-Object Drawing.Point(20, 200)
    $addButton.Add_Click({
        try {
            $instance = [VMwareNetwork]::GetInstance()
            $instance.AddNetwork($netBox.Text)
            $networkList.Items.Add($netBox.Text)
            [Windows.Forms.MessageBox]::Show("Network added successfully.","Success")
        } catch {
            [Windows.Forms.MessageBox]::Show("Failed to add network.`n$_","Error")
        }
    })
    $form.Controls.Add($addButton)

    # Button: Remove network
    $removeButton = New-Object Windows.Forms.Button
    $removeButton.Text = "Remove Network"
    $removeButton.Size = New-Object Drawing.Size(120, 30)
    $removeButton.Location = New-Object Drawing.Point(160, 200)
    $removeButton.Add_Click({
        try {
            $instance = [VMwareNetwork]::GetInstance()
            $instance.RemoveNetwork($netBox.Text)
            $networkList.Items.Remove($netBox.Text)
            [Windows.Forms.MessageBox]::Show("Network removed.","Deleted")
        } catch {
            [Windows.Forms.MessageBox]::Show("Failed to remove network.`n$_","Error")
        }
    })
    $form.Controls.Add($removeButton)

    # -----------------------------
    # Section: Bulk network actions
    # -----------------------------

    $bulkLabel = New-Object Windows.Forms.Label
    $bulkLabel.Text = "Bulk Actions"
    $bulkLabel.Font = New-Object Drawing.Font("Segoe UI", 9, [Drawing.FontStyle]::Bold)
    $bulkLabel.Location = New-Object Drawing.Point(20, 250)
    $bulkLabel.Size = New-Object Drawing.Size(150, 20)
    $form.Controls.Add($bulkLabel)

    # Course Number
    $courseLabel = New-Object Windows.Forms.Label
    $courseLabel.Text = "Course:"
    $courseLabel.Location = New-Object Drawing.Point(20, 280)
    $courseLabel.Size = New-Object Drawing.Size(100, 20)
    $form.Controls.Add($courseLabel)

    $courseBox = New-Object Windows.Forms.TextBox
    $courseBox.Location = New-Object Drawing.Point(130, 280)
    $courseBox.Size = New-Object Drawing.Size(200, 20)
    $form.Controls.Add($courseBox)

    # Start #
    $startLabel = New-Object Windows.Forms.Label
    $startLabel.Text = "Start:"
    $startLabel.Location = New-Object Drawing.Point(20, 310)
    $startLabel.Size = New-Object Drawing.Size(100, 20)
    $form.Controls.Add($startLabel)

    $startBox = New-Object Windows.Forms.TextBox
    $startBox.Location = New-Object Drawing.Point(130, 310)
    $startBox.Size = New-Object Drawing.Size(80, 20)
    $form.Controls.Add($startBox)

    # End #
    $endLabel = New-Object Windows.Forms.Label
    $endLabel.Text = "End:"
    $endLabel.Location = New-Object Drawing.Point(220, 310)
    $endLabel.Size = New-Object Drawing.Size(40, 20)
    $form.Controls.Add($endLabel)

    $endBox = New-Object Windows.Forms.TextBox
    $endBox.Location = New-Object Drawing.Point(270, 310)
    $endBox.Size = New-Object Drawing.Size(80, 20)
    $form.Controls.Add($endBox)

    # Button: Bulk Add
    $bulkAdd = New-Object Windows.Forms.Button
    $bulkAdd.Text = "Bulk Add"
    $bulkAdd.Size = New-Object Drawing.Size(100, 30)
    $bulkAdd.Location = New-Object Drawing.Point(20, 340)
    $bulkAdd.Add_Click({
        try {
            $instance = [VMwareNetwork]::GetInstance()
            $instance.BulkAddNetworks($courseBox.Text, [int]$startBox.Text, [int]$endBox.Text)
            [Windows.Forms.MessageBox]::Show("Bulk networks added.","Success")
        } catch {
            [Windows.Forms.MessageBox]::Show("Bulk add failed.`n$_","Error")
        }
    })
    $form.Controls.Add($bulkAdd)

    # Button: Bulk Remove
    $bulkRemove = New-Object Windows.Forms.Button
    $bulkRemove.Text = "Bulk Remove"
    $bulkRemove.Size = New-Object Drawing.Size(100, 30)
    $bulkRemove.Location = New-Object Drawing.Point(140, 340)
    $bulkRemove.Add_Click({
        try {
            $instance = [VMwareNetwork]::GetInstance()
            $instance.BulkRemoveNetworks([int]$startBox.Text, [int]$endBox.Text, $courseBox.Text)
            [Windows.Forms.MessageBox]::Show("Bulk networks removed.","Success")
        } catch {
            [Windows.Forms.MessageBox]::Show("Bulk remove failed.`n$_","Error")
        }
    })
    $form.Controls.Add($bulkRemove)

    # Display the form
    $form.Topmost = $true
    $form.Add_Shown({ $form.Activate() })
    $form.ShowDialog()
}

# Run the network manager view
Show-NetworkManagerView