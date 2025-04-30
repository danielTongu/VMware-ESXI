<#
.SYNOPSIS
    Class creation and management view.
.DESCRIPTION
    Provides GUI for:
    - Listing existing course folders
    - Viewing student usernames
    - Creating VMs for all students in a course
    - Deleting all VMs for a selected course

    Depends on: VMwareModels.psm1
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Import the core VMware module with class management functionality
Import-Module "$PSScriptRoot\..\VMwareModels.psm1" -ErrorAction Stop

# -------------------------------------------------------------------
# Helper: Create input field with label
# -------------------------------------------------------------------
function New-LabeledTextBox {
    param (
        [string]$labelText,
        [int]$top,
        [System.Windows.Forms.Form]$form
    )

    $label = New-Object Windows.Forms.Label
    $label.Text = $labelText
    $label.Location = New-Object Drawing.Point(20, $top)
    $label.Size = New-Object Drawing.Size(100, 20)
    $form.Controls.Add($label)

    $textbox = New-Object Windows.Forms.TextBox
    $textbox.Location = New-Object Drawing.Point(130, $top)
    $textbox.Size = New-Object Drawing.Size(200, 20)
    $form.Controls.Add($textbox)

    return $textbox
}

# -------------------------------------------------------------------
# Main Function: Show class manager UI
# -------------------------------------------------------------------
function Show-ClassManagerView {
    <#
    .SYNOPSIS
        Displays the class management view.
    .DESCRIPTION
        Allows user to:
        - View existing class folders
        - Enter student list
        - Create or remove VMs for a class
    #>

    # Fetch list of class folders from vSphere
    ConnectTo-VMServer
    $classFolders = [CourseManager]::ListClasses()

    # Create main window
    $form = New-Object Windows.Forms.Form
    $form.Text = "Class Manager"
    $form.Size = New-Object Drawing.Size(400, 400)
    $form.StartPosition = "CenterScreen"

    # Dropdown for selecting course folder
    $classLabel = New-Object Windows.Forms.Label
    $classLabel.Text = "Class Folder:"
    $classLabel.Location = New-Object Drawing.Point(20, 20)
    $classLabel.Size = New-Object Drawing.Size(100, 20)
    $form.Controls.Add($classLabel)

    $classDropdown = New-Object Windows.Forms.ComboBox
    $classDropdown.Location = New-Object Drawing.Point(130, 20)
    $classDropdown.Size = New-Object Drawing.Size(200, 20)
    $classDropdown.DropDownStyle = 'DropDownList'
    $classDropdown.Items.AddRange($classFolders)
    $form.Controls.Add($classDropdown)

    # Input: comma-separated student usernames
    $studentBox = New-LabeledTextBox -labelText "Students:" -top 60 -form $form

    # Input: Template VM name
    $templateBox = New-LabeledTextBox -labelText "Template:" -top 100 -form $form

    # Input: Datastore name
    $datastoreBox = New-LabeledTextBox -labelText "Datastore:" -top 140 -form $form

    # Input: Network adapters (comma-separated)
    $networkBox = New-LabeledTextBox -labelText "Networks:" -top 180 -form $form

    # Button: Create class VMs
    $createButton = New-Object Windows.Forms.Button
    $createButton.Text = "Create VMs"
    $createButton.Size = New-Object Drawing.Size(100, 30)
    $createButton.Location = New-Object Drawing.Point(50, 230)
    $createButton.Add_Click({
        try {
            $info = [PSCustomObject]@{
                classFolder = $classDropdown.Text
                students    = $studentBox.Text -split ',' | ForEach-Object { $_.Trim() }
                servers     = @(@{
                    template = $templateBox.Text
                    adapters = $networkBox.Text -split ',' | ForEach-Object { $_.Trim() }
                })
                dataStore   = $datastoreBox.Text
            }

            [CourseManager]::NewCourseVMs($info)

            [Windows.Forms.MessageBox]::Show("VMs created successfully.","Success",[Windows.Forms.MessageBoxButtons]::OK)
        } catch {
            [Windows.Forms.MessageBox]::Show("Error: $_","Error",[Windows.Forms.MessageBoxButtons]::OK)
        }
    })
    $form.Controls.Add($createButton)

    # Button: Delete VMs for class
    $deleteButton = New-Object Windows.Forms.Button
    $deleteButton.Text = "Delete Class"
    $deleteButton.Size = New-Object Drawing.Size(100, 30)
    $deleteButton.Location = New-Object Drawing.Point(200, 230)
    $deleteButton.Add_Click({
        try {
            $cf = $classDropdown.Text
            $start = [Windows.Forms.MessageBox]::Show("Delete all student VMs from class $cf?","Confirm",[Windows.Forms.MessageBoxButtons]::YesNo)
            if ($start -eq [Windows.Forms.DialogResult]::Yes) {
                [CourseManager]::RemoveCourseVMs($cf, 1, 50)  # Assumes students are numbered S1 to S50
                [Windows.Forms.MessageBox]::Show("Class VMs deleted.","Done",[Windows.Forms.MessageBoxButtons]::OK)
            }
        } catch {
            [Windows.Forms.MessageBox]::Show("Error: $_","Error",[Windows.Forms.MessageBoxButtons]::OK)
        }
    })
    $form.Controls.Add($deleteButton)

    # Show the form
    $form.Topmost = $true
    $form.Add_Shown({ $form.Activate() })
    $form.ShowDialog()
}

# Show the class management UI
Show-ClassManagerView