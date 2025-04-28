<#
.SYNOPSIS
    Renders the "Classes" management screen in the WinForms GUI.

.DESCRIPTION
    Builds the Classes view by:
      1. Clearing existing controls from the content panel.
      2. Declaring all UI components (labels, textboxes, groupboxes, buttons).
      3. Configuring each component’s properties (text, size, location, behavior).
      4. Wiring event handlers for:
         - Building all student resources
         - Building resources for a single student
         - Deleting all student resources
         - Removing a specific VM
         - Powering on/off a specific VM
         - Restarting all VMs for the class
      5. Adding all components to the panel in logical order.

.PARAMETER ContentPanel
    The System.Windows.Forms.Panel into which the Classes controls are placed.

.EXAMPLE
    # Assuming $panel is a valid WinForms Panel:
    Show-ClassesView -ContentPanel $panel
#>
function Show-ClassesView {
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
    # Title
    $labelTitle       = New-Object System.Windows.Forms.Label

    # Basic Info group and fields
    $groupBasic       = New-Object System.Windows.Forms.GroupBox
    $labelName        = New-Object System.Windows.Forms.Label
    $textboxName      = New-Object System.Windows.Forms.TextBox
    $labelQuarter     = New-Object System.Windows.Forms.Label
    $textboxQuarter   = New-Object System.Windows.Forms.TextBox
    $labelCourse      = New-Object System.Windows.Forms.Label
    $textboxCourse    = New-Object System.Windows.Forms.TextBox
    $labelStudents    = New-Object System.Windows.Forms.Label
    $textboxStudents  = New-Object System.Windows.Forms.TextBox

    # VM Configuration group and fields
    $groupConfig      = New-Object System.Windows.Forms.GroupBox
    $labelTemplate    = New-Object System.Windows.Forms.Label
    $comboTemplate    = New-Object System.Windows.Forms.ComboBox
    $labelDatastore   = New-Object System.Windows.Forms.Label
    $comboDatastore   = New-Object System.Windows.Forms.ComboBox
    $labelAdapters    = New-Object System.Windows.Forms.Label
    $checkedAdapters  = New-Object System.Windows.Forms.CheckedListBox

    # Advanced Operations group and fields
    $groupAdvanced    = New-Object System.Windows.Forms.GroupBox
    $labelSingle      = New-Object System.Windows.Forms.Label
    $textboxSingle    = New-Object System.Windows.Forms.TextBox
    $labelTargetVM    = New-Object System.Windows.Forms.Label
    $textboxTargetVM  = New-Object System.Windows.Forms.TextBox

    # Action buttons
    $buttonBuildAll    = New-Object System.Windows.Forms.Button
    $buttonBuildSingle = New-Object System.Windows.Forms.Button
    $buttonDeleteAll   = New-Object System.Windows.Forms.Button
    $buttonRemoveVM    = New-Object System.Windows.Forms.Button
    $buttonPowerOnVM   = New-Object System.Windows.Forms.Button
    $buttonPowerOffVM  = New-Object System.Windows.Forms.Button
    $buttonRestartAll  = New-Object System.Windows.Forms.Button

    # -------------------------------------------------------------------------
    # 2) Configure component properties
    # -------------------------------------------------------------------------

    ## 2.1 Title label
    $labelTitle.Text     = 'Classes'
    $labelTitle.Font     = [System.Drawing.Font]::new('Segoe UI',20,[System.Drawing.FontStyle]::Bold)
    $labelTitle.AutoSize = $true
    $labelTitle.Location = [System.Drawing.Point]::new(30,20)

    ## 2.2 Basic Info group
    $groupBasic.Text     = 'Basic Info'
    $groupBasic.Size     = [System.Drawing.Size]::new(480,200)
    $groupBasic.Location = [System.Drawing.Point]::new(30,60)

    # Class Name
    $labelName.Text      = 'Class Name:'
    $labelName.AutoSize  = $true
    $labelName.Location  = [System.Drawing.Point]::new(10,30)
    $textboxName.Size    = [System.Drawing.Size]::new(340,22)
    $textboxName.Location= [System.Drawing.Point]::new(120,26)

    # Quarter
    $labelQuarter.Text     = 'Quarter:'
    $labelQuarter.AutoSize = $true
    $labelQuarter.Location = [System.Drawing.Point]::new(10,70)
    $textboxQuarter.Size   = [System.Drawing.Size]::new(200,22)
    $textboxQuarter.Location = [System.Drawing.Point]::new(120,66)

    # Course Code
    $labelCourse.Text       = 'Course Code:'
    $labelCourse.AutoSize   = $true
    $labelCourse.Location   = [System.Drawing.Point]::new(10,110)
    $textboxCourse.Size     = [System.Drawing.Size]::new(200,22)
    $textboxCourse.Location = [System.Drawing.Point]::new(120,106)

    # Students textbox
    $labelStudents.Text      = 'Students (one per line):'
    $labelStudents.AutoSize  = $true
    $labelStudents.Location  = [System.Drawing.Point]::new(10,150)
    $textboxStudents.Multiline  = $true
    $textboxStudents.ScrollBars = 'Vertical'
    $textboxStudents.Size      = [System.Drawing.Size]::new(450,80)
    $textboxStudents.Location  = [System.Drawing.Point]::new(10,170)

    ## 2.3 VM Configuration group
    $groupConfig.Text     = 'VM Configuration'
    $groupConfig.Size     = [System.Drawing.Size]::new(480,200)
    $groupConfig.Location = [System.Drawing.Point]::new(530,60)

    # Template dropdown
    $labelTemplate.Text       = 'VM Template:'
    $labelTemplate.AutoSize   = $true
    $labelTemplate.Location   = [System.Drawing.Point]::new(10,30)
    $comboTemplate.DropDownStyle = 'DropDownList'
    $comboTemplate.Location      = [System.Drawing.Point]::new(120,26)
    $comboTemplate.Size          = [System.Drawing.Size]::new(200,22)
    $comboTemplate.Items.AddRange(@('Template A','Template B','Template C'))

    # Datastore dropdown
    $labelDatastore.Text      = 'Datastore:'
    $labelDatastore.AutoSize  = $true
    $labelDatastore.Location  = [System.Drawing.Point]::new(10,70)
    $comboDatastore.DropDownStyle = 'DropDownList'
    $comboDatastore.Location      = [System.Drawing.Point]::new(120,66)
    $comboDatastore.Size          = [System.Drawing.Size]::new(200,22)
    $comboDatastore.Items.AddRange(@('Datastore1','Datastore2','Datastore3'))

    # Network adapters
    $labelAdapters.Text       = 'Adapters:'
    $labelAdapters.AutoSize   = $true
    $labelAdapters.Location   = [System.Drawing.Point]::new(10,110)
    $checkedAdapters.Location = [System.Drawing.Point]::new(120,106)
    $checkedAdapters.Size     = [System.Drawing.Size]::new(300,60)
    $checkedAdapters.Items.AddRange(@('Instructor','NAT','Inside'))

    ## 2.4 Advanced Operations group
    $groupAdvanced.Text     = 'Advanced Operations'
    $groupAdvanced.Size     = [System.Drawing.Size]::new(1020,140)
    $groupAdvanced.Location = [System.Drawing.Point]::new(30,270)

    # Single student
    $labelSingle.Text       = 'Single Student:'
    $labelSingle.AutoSize   = $true
    $labelSingle.Location   = [System.Drawing.Point]::new(10,30)
    $textboxSingle.Size     = [System.Drawing.Size]::new(200,22)
    $textboxSingle.Location = [System.Drawing.Point]::new(120,26)

    # Target VM
    $labelTargetVM.Text       = 'Target VM:'
    $labelTargetVM.AutoSize   = $true
    $labelTargetVM.Location   = [System.Drawing.Point]::new(350,30)
    $textboxTargetVM.Size     = [System.Drawing.Size]::new(200,22)
    $textboxTargetVM.Location = [System.Drawing.Point]::new(430,26)

    ## 2.5 Action buttons
    # Build All
    $buttonBuildAll.Text      = 'Build All'
    $buttonBuildAll.Size      = [System.Drawing.Size]::new(100,30)
    $buttonBuildAll.Location  = [System.Drawing.Point]::new(10,70)

    # Build Single
    $buttonBuildSingle.Text   = 'Build Single'
    $buttonBuildSingle.Size   = [System.Drawing.Size]::new(100,30)
    $buttonBuildSingle.Location = [System.Drawing.Point]::new(120,70)

    # Delete All
    $buttonDeleteAll.Text     = 'Delete All'
    $buttonDeleteAll.Size     = [System.Drawing.Size]::new(100,30)
    $buttonDeleteAll.Location = [System.Drawing.Point]::new(230,70)

    # Remove VM
    $buttonRemoveVM.Text      = 'Remove VM'
    $buttonRemoveVM.Size      = [System.Drawing.Size]::new(100,30)
    $buttonRemoveVM.Location  = [System.Drawing.Point]::new(340,70)

    # Power On VM
    $buttonPowerOnVM.Text     = 'Power On VM'
    $buttonPowerOnVM.Size     = [System.Drawing.Size]::new(100,30)
    $buttonPowerOnVM.Location = [System.Drawing.Point]::new(450,70)

    # Power Off VM
    $buttonPowerOffVM.Text    = 'Power Off VM'
    $buttonPowerOffVM.Size    = [System.Drawing.Size]::new(100,30)
    $buttonPowerOffVM.Location= [System.Drawing.Point]::new(560,70)

    # Restart All
    $buttonRestartAll.Text    = 'Restart All'
    $buttonRestartAll.Size    = [System.Drawing.Size]::new(100,30)
    $buttonRestartAll.Location= [System.Drawing.Point]::new(670,70)

    # -------------------------------------------------------------------------
    # 3) Wire event handlers
    # -------------------------------------------------------------------------
    $buttonBuildAll.Add_Click({
        On-BuildAllClassClick $textboxName $comboTemplate $comboDatastore $checkedAdapters
    })
    $buttonBuildSingle.Add_Click({
        On-BuildSingleClassClick $textboxName $textboxSingle $comboTemplate $comboDatastore $checkedAdapters
    })
    $buttonDeleteAll.Add_Click({
        On-DeleteAllClassClick $textboxName
    })
    $buttonRemoveVM.Add_Click({
        On-RemoveVMClick $textboxName $textboxTargetVM
    })
    $buttonPowerOnVM.Add_Click({
        On-PowerOnClassVMClick $textboxName $textboxTargetVM
    })
    $buttonPowerOffVM.Add_Click({
        On-PowerOffClassVMClick $textboxName $textboxTargetVM
    })
    $buttonRestartAll.Add_Click({
        On-RestartClassVMsClick $textboxName
    })

    # -------------------------------------------------------------------------
    # 4) Add components to the panel
    # -------------------------------------------------------------------------
    # Title
    $ContentPanel.Controls.Add($labelTitle)

    # Basic Info group
    $groupBasic.Controls.AddRange(@(
        $labelName, $textboxName,
        $labelQuarter, $textboxQuarter,
        $labelCourse, $textboxCourse,
        $labelStudents, $textboxStudents
    ))
    $ContentPanel.Controls.Add($groupBasic)

    # VM Configuration group
    $groupConfig.Controls.AddRange(@(
        $labelTemplate, $comboTemplate,
        $labelDatastore, $comboDatastore,
        $labelAdapters, $checkedAdapters
    ))
    $ContentPanel.Controls.Add($groupConfig)

    # Advanced Operations group
    $groupAdvanced.Controls.AddRange(@(
        $labelSingle, $textboxSingle,
        $labelTargetVM, $textboxTargetVM,
        $buttonBuildAll, $buttonBuildSingle,
        $buttonDeleteAll, $buttonRemoveVM,
        $buttonPowerOnVM, $buttonPowerOffVM,
        $buttonRestartAll
    ))
    $ContentPanel.Controls.Add($groupAdvanced)
}

Export-ModuleMember -Function Show-ClassesView