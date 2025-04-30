<#
.SYNOPSIS
    Renders the "Classes" management screen in the WinForms GUI.

.DESCRIPTION
    - Left pane: scrollable ListBox of existing classes.
    - Right pane: the same "Add/Edit Class" form you had, pre-filled when a class is selected.
    - Buttons to invoke your build/delete/power scripts.
    - Fully commented and PS 5.1–compatible (no named ctor parameters).

.PARAMETER ContentPanel
    The WinForms Panel into which all controls are injected.

.EXAMPLE
    Show-ClassesView -ContentPanel $mySplitContainer.Panel2
#>
function Show-ClassesView {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Forms.Panel] $ContentPanel
    )

    # -------------------------------------------------------------------------
    # 0) Clear existing controls & enable scrolling if needed
    # -------------------------------------------------------------------------
    $ContentPanel.Controls.Clear()
    $ContentPanel.AutoScroll = $true

    # -------------------------------------------------------------------------
    # 1) Declare all UI components
    # -------------------------------------------------------------------------
    # Title
    $lblTitle      = New-Object System.Windows.Forms.Label

    # Left: class list
    $panelList     = New-Object System.Windows.Forms.Panel
    $lstClasses    = New-Object System.Windows.Forms.ListBox
    $btnRefresh    = New-Object System.Windows.Forms.Button

    # Right: Basic Info group + fields
    $groupBasic      = New-Object System.Windows.Forms.GroupBox
    $lblName         = New-Object System.Windows.Forms.Label
    $txtName         = New-Object System.Windows.Forms.TextBox
    $lblQuarter      = New-Object System.Windows.Forms.Label
    $txtQuarter      = New-Object System.Windows.Forms.TextBox
    $lblCourse       = New-Object System.Windows.Forms.Label
    $txtCourse       = New-Object System.Windows.Forms.TextBox
    $lblStudents     = New-Object System.Windows.Forms.Label
    $txtStudents     = New-Object System.Windows.Forms.TextBox

    # Right: VM Config group + fields
    $groupConfig     = New-Object System.Windows.Forms.GroupBox
    $lblTemplate     = New-Object System.Windows.Forms.Label
    $cmbTemplate     = New-Object System.Windows.Forms.ComboBox
    $lblDatastore    = New-Object System.Windows.Forms.Label
    $cmbDatastore    = New-Object System.Windows.Forms.ComboBox
    $lblAdapters     = New-Object System.Windows.Forms.Label
    $clbAdapters     = New-Object System.Windows.Forms.CheckedListBox

    # Right: Advanced Ops group + fields/buttons
    $groupAdv        = New-Object System.Windows.Forms.GroupBox
    $lblSingle       = New-Object System.Windows.Forms.Label
    $txtSingle       = New-Object System.Windows.Forms.TextBox
    $lblTargetVM     = New-Object System.Windows.Forms.Label
    $txtTargetVM     = New-Object System.Windows.Forms.TextBox
    $btnBuildAll     = New-Object System.Windows.Forms.Button
    $btnBuildSingle  = New-Object System.Windows.Forms.Button
    $btnDeleteAll    = New-Object System.Windows.Forms.Button
    $btnRemoveVM     = New-Object System.Windows.Forms.Button
    $btnPowerOnVM    = New-Object System.Windows.Forms.Button
    $btnPowerOffVM   = New-Object System.Windows.Forms.Button
    $btnRestartAll   = New-Object System.Windows.Forms.Button

    # -------------------------------------------------------------------------
    # 2) Configure properties (text, size, location, behaviors)
    # -------------------------------------------------------------------------

    ## Title
    $lblTitle.Text     = 'Classes Management'
    $lblTitle.Font     = [System.Drawing.Font]::new('Segoe UI',18,[System.Drawing.FontStyle]::Bold)
    $lblTitle.AutoSize = $true
    $lblTitle.Location = [System.Drawing.Point]::new(20,20)

    ## Refresh
    $btnRefresh.Text      = 'Refresh List'
    $btnRefresh.Size      = [System.Drawing.Size]::new(100,30)
    $btnRefresh.Location  = [System.Drawing.Point]::new(340,18)

    ## Class list panel
    $panelList.Location   = [System.Drawing.Point]::new(20,60)
    $panelList.Size       = [System.Drawing.Size]::new(300,550)
    $panelList.AutoScroll = $true
    # ListBox
    $lstClasses.Location  = [System.Drawing.Point]::new(0,0)
    $lstClasses.Size      = [System.Drawing.Size]::new(280,530)
    $lstClasses.ScrollAlwaysVisible = $true

    ## Basic Info group
    $groupBasic.Text     = 'Basic Info'
    $groupBasic.Font     = [System.Drawing.Font]::new('Segoe UI',10,[System.Drawing.FontStyle]::Bold)
    $groupBasic.Size     = [System.Drawing.Size]::new(600,200)
    $groupBasic.Location = [System.Drawing.Point]::new(340,60)
    # Name
    $lblName.Text      = 'Class Name:'
    $lblName.AutoSize  = $true
    $lblName.Location  = [System.Drawing.Point]::new(10,30)
    $txtName.Size      = [System.Drawing.Size]::new(400,22)
    $txtName.Location  = [System.Drawing.Point]::new(120,28)
    # Quarter
    $lblQuarter.Text     = 'Quarter:'
    $lblQuarter.AutoSize = $true
    $lblQuarter.Location = [System.Drawing.Point]::new(10,70)
    $txtQuarter.Size    = [System.Drawing.Size]::new(200,22)
    $txtQuarter.Location= [System.Drawing.Point]::new(120,68)
    # Course
    $lblCourse.Text     = 'Course Code:'
    $lblCourse.AutoSize = $true
    $lblCourse.Location = [System.Drawing.Point]::new(10,110)
    $txtCourse.Size     = [System.Drawing.Size]::new(200,22)
    $txtCourse.Location = [System.Drawing.Point]::new(120,108)
    # Students
    $lblStudents.Text      = 'Students (one/line):'
    $lblStudents.AutoSize  = $true
    $lblStudents.Location  = [System.Drawing.Point]::new(10,150)
    $txtStudents.Multiline   = $true
    $txtStudents.ScrollBars  = 'Vertical'
    $txtStudents.Size        = [System.Drawing.Size]::new(530,40)
    $txtStudents.Location    = [System.Drawing.Point]::new(10,170)

    ## VM Config group
    $groupConfig.Text     = 'VM Configuration'
    $groupConfig.Font     = [System.Drawing.Font]::new('Segoe UI',10,[System.Drawing.FontStyle]::Bold)
    $groupConfig.Size     = [System.Drawing.Size]::new(600,140)
    $groupConfig.Location = [System.Drawing.Point]::new(340,270)
    # Template
    $lblTemplate.Text       = 'Template:'
    $lblTemplate.AutoSize   = $true
    $lblTemplate.Location   = [System.Drawing.Point]::new(10,30)
    $cmbTemplate.DropDownStyle = 'DropDownList'
    $cmbTemplate.Size          = [System.Drawing.Size]::new(200,22)
    $cmbTemplate.Location      = [System.Drawing.Point]::new(120,28)
    $cmbTemplate.Items.AddRange(@('Template A','Template B','Template C'))
    # Datastore
    $lblDatastore.Text      = 'Datastore:'
    $lblDatastore.AutoSize  = $true
    $lblDatastore.Location  = [System.Drawing.Point]::new(10,70)
    $cmbDatastore.DropDownStyle = 'DropDownList'
    $cmbDatastore.Size          = [System.Drawing.Size]::new(200,22)
    $cmbDatastore.Location      = [System.Drawing.Point]::new(120,68)
    $cmbDatastore.Items.AddRange(@('Datastore1','Datastore2','Datastore3'))
    # Adapters
    $lblAdapters.Text      = 'Adapters:'
    $lblAdapters.AutoSize  = $true
    $lblAdapters.Location  = [System.Drawing.Point]::new(10,110)
    $clbAdapters.Size      = [System.Drawing.Size]::new(300,20)
    $clbAdapters.Location  = [System.Drawing.Point]::new(120,108)
    $clbAdapters.Items.AddRange(@('Instructor','NAT','Inside'))

    ## Advanced Ops group
    $groupAdv.Text     = 'Advanced Operations'
    $groupAdv.Font     = [System.Drawing.Font]::new('Segoe UI',10,[System.Drawing.FontStyle]::Bold)
    $groupAdv.Size     = [System.Drawing.Size]::new(600,100)
    $groupAdv.Location = [System.Drawing.Point]::new(340,420)
    # Single student
    $lblSingle.Text      = 'Single Student:'
    $lblSingle.AutoSize  = $true
    $lblSingle.Location  = [System.Drawing.Point]::new(10,30)
    $txtSingle.Size      = [System.Drawing.Size]::new(200,22)
    $txtSingle.Location  = [System.Drawing.Point]::new(120,28)
    # Target VM
    $lblTargetVM.Text     = 'Target VM:'
    $lblTargetVM.AutoSize = $true
    $lblTargetVM.Location = [System.Drawing.Point]::new(350,30)
    $txtTargetVM.Size     = [System.Drawing.Size]::new(200,22)
    $txtTargetVM.Location = [System.Drawing.Point]::new(430,28)

    # Action buttons row
    $actions = @(
      @{Btn=$btnBuildAll;    Text='Build All';     X=10},
      @{Btn=$btnBuildSingle; Text='Build Single';  X=120},
      @{Btn=$btnDeleteAll;   Text='Delete All';    X=230},
      @{Btn=$btnRemoveVM;    Text='Remove VM';     X=340},
      @{Btn=$btnPowerOnVM;   Text='Power On VM';   X=450},
      @{Btn=$btnPowerOffVM;  Text='Power Off VM';  X=560},
      @{Btn=$btnRestartAll;  Text='Restart All';   X=670}
    )
    foreach ($spec in $actions) {
        $b = $spec.Btn
        $b.Text     = $spec.Text
        $b.Size     = [System.Drawing.Size]::new(100,30)
        $b.Location = [System.Drawing.Point]::new($spec.X,60)
    }

    # -------------------------------------------------------------------------
    # 3) Wire event handlers
    # -------------------------------------------------------------------------
    # Refresh list of classes
    $btnRefresh.Add_Click({
        $lstClasses.Items.Clear()
        $raw = Invoke-Script -ScriptName 'ListClasses.ps1' -Args '' -ErrorAction SilentlyContinue
        foreach ($line in $raw -split "`n" | Where-Object{ $_.Trim() }) {
            $lstClasses.Items.Add($line.Split(',')[0]) | Out-Null
        }
    })

    # When a class is selected, load its details into the right-hand form
    $lstClasses.Add_SelectedIndexChanged({
        $sel = $lstClasses.SelectedItem
        if ($sel) {
            # fetch full info: Name,Quarter,Course
            $info = Invoke-Script -ScriptName 'GetClassInfo.ps1' -Args "-Name '$sel'" -ErrorAction SilentlyContinue
            $parts = $info.Split(',')
            $txtName.Text    = $parts[0]
            $txtQuarter.Text = $parts[1]
            $txtCourse.Text  = $parts[2]

            # fetch student list
            $stuRaw = Invoke-Script -ScriptName 'GetClassStudents.ps1' -Args "-Name '$sel'"
            $txtStudents.Text = ($stuRaw -split "`n") -join [Environment]::NewLine

            # fetch config
            $cfg = Invoke-Script -ScriptName 'GetClassConfig.ps1' -Args "-Name '$sel'"
            $cfgParts = $cfg.Split(',')
            $cmbTemplate.SelectedItem  = $cfgParts[0]
            $cmbDatastore.SelectedItem = $cfgParts[1]
            $clbAdapters.Items | ForEach-Object { $clbAdapters.SetItemChecked($_, $false) }
            foreach ($ad in $cfgParts[2].Split(';')) {
                $idx = $clbAdapters.Items.IndexOf($ad)
                if ($idx -ge 0) { $clbAdapters.SetItemChecked($idx,$true) }
            }
        }
    })

    # Hook up your Build/Delete/Power button script-caller functions below:
    $btnBuildAll.Add_Click({ On-BuildAllClassClick    $txtName $cmbTemplate $cmbDatastore $clbAdapters })
    $btnBuildSingle.Add_Click({ On-BuildSingleClassClick $txtName $txtSingle $cmbTemplate $cmbDatastore $clbAdapters })
    $btnDeleteAll.Add_Click({ On-DeleteAllClassClick   $txtName })
    $btnRemoveVM.Add_Click({ On-RemoveVMClick          $txtName $txtTargetVM })
    $btnPowerOnVM.Add_Click({ On-PowerOnClassVMClick   $txtName $txtTargetVM })
    $btnPowerOffVM.Add_Click({ On-PowerOffClassVMClick  $txtName $txtTargetVM })
    $btnRestartAll.Add_Click({ On-RestartClassVMsClick  $txtName })

    # -------------------------------------------------------------------------
    # 4) Layout: assemble everything
    # -------------------------------------------------------------------------
    $ContentPanel.Controls.Add($lblTitle)
    $ContentPanel.Controls.Add($btnRefresh)

    $panelList.Controls.Add($lstClasses)
    $ContentPanel.Controls.Add($panelList)

    $groupBasic.Controls.AddRange(@(
        $lblName, $txtName,
        $lblQuarter, $txtQuarter,
        $lblCourse, $txtCourse,
        $lblStudents, $txtStudents
    ))
    $ContentPanel.Controls.Add($groupBasic)

    $groupConfig.Controls.AddRange(@(
        $lblTemplate, $cmbTemplate,
        $lblDatastore, $cmbDatastore,
        $lblAdapters, $clbAdapters
    ))
    $ContentPanel.Controls.Add($groupConfig)

    $groupAdv.Controls.AddRange(@(
        $lblSingle, $txtSingle,
        $lblTargetVM, $txtTargetVM
    ))
    foreach ($spec in $actions) { $groupAdv.Controls.Add($spec.Btn) }
    $ContentPanel.Controls.Add($groupAdv)

    # -------------------------------------------------------------------------
    # 5) Initial load
    # -------------------------------------------------------------------------
    $btnRefresh.PerformClick()
}

Export-ModuleMember -Function Show-ClassesView