<#
.SYNOPSIS
    Class creation and management view.
.DESCRIPTION
    Provides GUI for:
    - Listing course folders
    - Inputting student usernames
    - Creating VMs for a class
    - Deleting all VMs for a course

    Must be run after VMwareModels.psm1 is loaded.
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Import VMwareModels if not already loaded
if (-not (Get-Command ConnectTo-VMServer -ErrorAction SilentlyContinue)) {
    Import-Module "$PSScriptRoot\..\VMwareModels.psm1" -ErrorAction Stop
}

# -------------------------------------------------------------------
# Helper: Adds a label + textbox to a panel
# -------------------------------------------------------------------
function New-LabeledInput {
    param (
        [System.Windows.Forms.Panel]$Panel,
        [string]$LabelText,
        [int]$Top
    )

    $label = New-Object Windows.Forms.Label
    $label.Text = $LabelText
    $label.Location = New-Object Drawing.Point(20, $Top)
    $label.Size = New-Object Drawing.Size(100, 20)
    $Panel.Controls.Add($label)

    $textbox = New-Object Windows.Forms.TextBox
    $textbox.Location = New-Object Drawing.Point(130, $Top)
    $textbox.Size = New-Object Drawing.Size(220, 20)
    $Panel.Controls.Add($textbox)

    return $textbox
}

# -------------------------------------------------------------------
# Entry point: shows the Class Manager view inside given panel
# -------------------------------------------------------------------
function Show-View {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [System.Windows.Forms.Panel]$ParentPanel
    )

    # Clear previous UI
    $ParentPanel.Controls.Clear()

    # Connect to VMware and load class folders
    ConnectTo-VMServer
    $classFolders = [CourseManager]::ListClasses()

    # --- Title ---
    $lblTitle = New-Object Windows.Forms.Label
    $lblTitle.Text = "Class Manager"
    $lblTitle.Font = New-Object Drawing.Font("Segoe UI", 14, [Drawing.FontStyle]::Bold)
    $lblTitle.Location = New-Object Drawing.Point(20, 20)
    $lblTitle.AutoSize = $true
    $ParentPanel.Controls.Add($lblTitle)

    # --- Class folder dropdown ---
    $lblClass = New-Object Windows.Forms.Label
    $lblClass.Text = "Class Folder:"
    $lblClass.Location = New-Object Drawing.Point(20, 60)
    $lblClass.Size = New-Object Drawing.Size(100, 20)
    $ParentPanel.Controls.Add($lblClass)

    $comboClass = New-Object Windows.Forms.ComboBox
    $comboClass.Location = New-Object Drawing.Point(130, 60)
    $comboClass.Size = New-Object Drawing.Size(220, 20)
    $comboClass.DropDownStyle = 'DropDownList'
    $comboClass.Items.AddRange($classFolders)
    $ParentPanel.Controls.Add($comboClass)

    # --- Input fields ---
    $txtStudents  = New-LabeledInput -Panel $ParentPanel -LabelText "Students (comma):" -Top 100
    $txtTemplate  = New-LabeledInput -Panel $ParentPanel -LabelText "Template:"           -Top 140
    $txtDatastore = New-LabeledInput -Panel $ParentPanel -LabelText "Datastore:"          -Top 180
    $txtNetworks  = New-LabeledInput -Panel $ParentPanel -LabelText "Networks (comma):"   -Top 220

    # --- Create VMs button ---
    $btnCreate = New-Object Windows.Forms.Button
    $btnCreate.Text = "Create VMs"
    $btnCreate.Size = New-Object Drawing.Size(100,30)
    $btnCreate.Location = New-Object Drawing.Point(50, 270)
    $btnCreate.Add_Click({
        try {
            $info = [PSCustomObject]@{
                classFolder = $comboClass.Text
                students    = $txtStudents.Text -split ',' | ForEach-Object { $_.Trim() }
                servers     = @(@{
                    template = $txtTemplate.Text
                    adapters = $txtNetworks.Text -split ',' | ForEach-Object { $_.Trim() }
                })
                dataStore   = $txtDatastore.Text
            }

            [CourseManager]::NewCourseVMs($info)
            [Windows.Forms.MessageBox]::Show("VMs created successfully.","Success",[Windows.Forms.MessageBoxButtons]::OK)
        } catch {
            [Windows.Forms.MessageBox]::Show("Error: $_","Error",[Windows.Forms.MessageBoxButtons]::OK)
        }
    })
    $ParentPanel.Controls.Add($btnCreate)

    # --- Delete Class button ---
    $btnDelete = New-Object Windows.Forms.Button
    $btnDelete.Text = "Delete Class"
    $btnDelete.Size = New-Object Drawing.Size(100,30)
    $btnDelete.Location = New-Object Drawing.Point(200, 270)
    $btnDelete.Add_Click({
        try {
            $cf = $comboClass.Text
            $confirm = [Windows.Forms.MessageBox]::Show("Delete all student VMs from class $cf?","Confirm",[Windows.Forms.MessageBoxButtons]::YesNo)
            if ($confirm -eq [Windows.Forms.DialogResult]::Yes) {
                [CourseManager]::RemoveCourseVMs($cf, 1, 50)  # Assumes S1–S50
                [Windows.Forms.MessageBox]::Show("Class VMs deleted.","Done",[Windows.Forms.MessageBoxButtons]::OK)
            }
        } catch {
            [Windows.Forms.MessageBox]::Show("Error: $_","Error",[Windows.Forms.MessageBoxButtons]::OK)
        }
    })
    $ParentPanel.Controls.Add($btnDelete)
}

Export-ModuleMember -Function Show-View