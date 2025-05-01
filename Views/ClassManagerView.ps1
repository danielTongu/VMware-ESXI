<#
.SYNOPSIS
    Class creation & administration view.
.DESCRIPTION
    - Create new class folders and student subfolders.
    - View and select existing classes.
    - Specify VM Template, Datastore, and Networks via dropdowns.
    - Batch-create VMs for a class.
    - Delete all VMs/folders for a class.
    - Scrollable, admin-oriented layout.

    Depends on VMwareModels.psm1 and PowerCLI.
#>

# Load WinForms UI types
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Ensure core VMware functions are loaded
if (-not (Get-Command ConnectTo-VMServer -ErrorAction SilentlyContinue)) {
    Import-Module "$PSScriptRoot\..\VMwareModels.psm1" -ErrorAction Stop
}

# -------------------------------------------------------------------
# Helper to add a labeled control to a panel
# -------------------------------------------------------------------
function New-LabeledControl {
    param (
        [System.Windows.Forms.Panel]$Panel,
        [string]                 $LabelText,
        [int]                    $Top,
        [Type]                   $ControlType,
        [Hashtable]              $Params
    )

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text     = $LabelText
    $lbl.Location = New-Object System.Drawing.Point(20, $Top)
    $lbl.AutoSize = $true
    $Panel.Controls.Add($lbl)

    $ctrl = New-Object $ControlType
    foreach ($k in $Params.Keys) {
        $ctrl.$k = $Params[$k]
    }
    $Panel.Controls.Add($ctrl)
    return $ctrl
}

# -------------------------------------------------------------------
# Entry point: Renders this view into the passed-in panel
# -------------------------------------------------------------------
function Show-View {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Forms.Panel]$ParentPanel
    )

    # Clear and add a scrollable sub-panel
    $ParentPanel.Controls.Clear()
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Dock       = 'Fill'
    $panel.AutoScroll = $true
    $ParentPanel.Controls.Add($panel)

    # Connect & fetch resources
    ConnectTo-VMServer
    $classes    = [CourseManager]::ListClasses()
    $templates  = (Get-Template | Select-Object -ExpandProperty Name)
    $datastores = (Get-Datastore | Select-Object -ExpandProperty Name)
    $networks   = [VMwareNetwork]::ListNetworks()

    # Title
    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Text     = "Class Manager"
    $lblTitle.Font     = New-Object System.Drawing.Font("Segoe UI",16,[System.Drawing.FontStyle]::Bold)
    $lblTitle.AutoSize = $true
    $lblTitle.Location = New-Object System.Drawing.Point(20,20)
    $panel.Controls.Add($lblTitle)

    $y = 70

    # Existing class dropdown
    $cmbClass = New-LabeledControl -Panel $panel -LabelText "Select Class:" `
        -Top $y -ControlType ([System.Windows.Forms.ComboBox]) -Params @{
            Location      = New-Object System.Drawing.Point(130,$y)
            Size          = New-Object System.Drawing.Size(200,22)
            DropDownStyle = 'DropDownList'
        }
    $cmbClass.Items.AddRange($classes)
    $y += 40

    # New class name + student list
    $txtNewClass  = New-LabeledControl -Panel $panel -LabelText "New Class Name:" `
        -Top $y -ControlType ([System.Windows.Forms.TextBox]) -Params @{
            Location = New-Object System.Drawing.Point(130,$y)
            Size     = New-Object System.Drawing.Size(200,22)
        }
    $y += 30

    $txtStudents = New-LabeledControl -Panel $panel -LabelText "Students (one per line):" `
        -Top $y -ControlType ([System.Windows.Forms.TextBox]) -Params @{
            Location   = New-Object System.Drawing.Point(130,$y)
            Size       = New-Object System.Drawing.Size(200,80)
            Multiline  = $true
            ScrollBars = 'Vertical'
        }
    $y += 100

    # Template dropdown
    $cmbTemplate = New-LabeledControl -Panel $panel -LabelText "Template:" `
        -Top $y -ControlType ([System.Windows.Forms.ComboBox]) -Params @{
            Location      = New-Object System.Drawing.Point(130,$y)
            Size          = New-Object System.Drawing.Size(200,22)
            DropDownStyle = 'DropDownList'
        }
    $cmbTemplate.Items.AddRange($templates)
    $y += 40

    # Datastore dropdown
    $cmbDatastore = New-LabeledControl -Panel $panel -LabelText "Datastore:" `
        -Top $y -ControlType ([System.Windows.Forms.ComboBox]) -Params @{
            Location      = New-Object System.Drawing.Point(130,$y)
            Size          = New-Object System.Drawing.Size(200,22)
            DropDownStyle = 'DropDownList'
        }
    $cmbDatastore.Items.AddRange($datastores)
    $y += 40

    # Networks checked list
    $chkNetworks = New-LabeledControl -Panel $panel -LabelText "Networks:" `
        -Top $y -ControlType ([System.Windows.Forms.CheckedListBox]) -Params @{
            Location     = New-Object System.Drawing.Point(130,$y)
            Size         = New-Object System.Drawing.Size(200,80)
            CheckOnClick = $true
        }
    $chkNetworks.Items.AddRange($networks)
    $y += 100

    # Buttons
    $btnCreateClass = New-Object System.Windows.Forms.Button
    $btnCreateClass.Text     = "Create Class"
    $btnCreateClass.Size     = New-Object System.Drawing.Size(120,30)
    $btnCreateClass.Location = New-Object System.Drawing.Point(20,$y)
    $panel.Controls.Add($btnCreateClass)

    $btnCreateVMs = New-Object System.Windows.Forms.Button
    $btnCreateVMs.Text     = "Create VMs"
    $btnCreateVMs.Size     = New-Object System.Drawing.Size(120,30)
    $btnCreateVMs.Location = New-Object System.Drawing.Point(160,$y)
    $panel.Controls.Add($btnCreateVMs)

    $btnDeleteClass = New-Object System.Windows.Forms.Button
    $btnDeleteClass.Text     = "Delete Class"
    $btnDeleteClass.Size     = New-Object System.Drawing.Size(120,30)
    $btnDeleteClass.Location = New-Object System.Drawing.Point(300,$y)
    $panel.Controls.Add($btnDeleteClass)

    # -------------------------------------------------------------------
    # Event Handlers
    # -------------------------------------------------------------------

    # Create class folder + student subfolders
    $btnCreateClass.Add_Click({
        $cf       = $txtNewClass.Text.Trim()
        $students = $txtStudents.Lines | Where-Object { $_.Trim() }
        if (-not $cf) {
            [System.Windows.Forms.MessageBox]::Show("Enter a class name.","Validation")
            return
        }
        if (-not $students) {
            [System.Windows.Forms.MessageBox]::Show("Enter at least one student.","Validation")
            return
        }
        ConnectTo-VMServer
        $root = Get-Folder -Name 'vm'
        if (-not (Get-Folder -Name $cf -ErrorAction SilentlyContinue)) {
            New-Folder -Name $cf -Location $root | Out-Null
        }
        $parent = Get-Folder -Name $cf
        foreach ($s in $students) {
            $folderName = "$cf`_$s"
            if (-not (Get-Folder -Name $folderName -ErrorAction SilentlyContinue)) {
                New-Folder -Name $folderName -Location $parent | Out-Null
            }
        }
        if (-not $cmbClass.Items.Contains($cf)) { $cmbClass.Items.Add($cf) }
        $cmbClass.SelectedItem = $cf
        [System.Windows.Forms.MessageBox]::Show("Class '$cf' created.","Success")
    })

    # Create VMs for class
    $btnCreateVMs.Add_Click({
        $cf = $cmbClass.Text
        if (-not $cf) {
            [System.Windows.Forms.MessageBox]::Show("Select a class.","Validation")
            return
        }
        $info = [PSCustomObject]@{
            classFolder = $cf
            students    = $txtStudents.Lines | Where-Object { $_.Trim() }
            servers     = @(@{
                template = $cmbTemplate.Text
                adapters = $chkNetworks.CheckedItems | ForEach-Object { $_.ToString() }
            })
            dataStore   = $cmbDatastore.Text
        }
        [CourseManager]::NewCourseVMs($info)
        [System.Windows.Forms.MessageBox]::Show("VMs created for class.","Success")
    })

    # Delete all VMs for class
    $btnDeleteClass.Add_Click({
        $cf = $cmbClass.Text
        if (-not $cf) {
            [System.Windows.Forms.MessageBox]::Show("Select a class.","Validation")
            return
        }
        if ([System.Windows.Forms.MessageBox]::Show("Delete ALL VMs in '$cf'?","Confirm",[System.Windows.Forms.MessageBoxButtons]::YesNo) -eq 'Yes') {
            [CourseManager]::RemoveCourseVMs($cf,1,100)
            [System.Windows.Forms.MessageBox]::Show("Class deleted.","Success")
        }
    })
}