<#
.SYNOPSIS
    Renders the Classes management screen.
#>
function Show-ClassesView {
    Param(
        [Parameter(Mandatory)][System.Windows.Forms.Panel]$ContentPanel
    )
    $ContentPanel.Controls.Clear()

    # Title
    $title = [System.Windows.Forms.Label]::new()
    $title.Text     = 'Classes'
    $title.Font     = [System.Drawing.Font]::new('Segoe UI',20,[System.Drawing.FontStyle]::Bold)
    $title.AutoSize = $true
    $title.Location = [System.Drawing.Point]::new(30,20)
    $ContentPanel.Controls.Add($title)

    # Basic Info Group
    $gbBasic = [System.Windows.Forms.GroupBox]::new()
    $gbBasic.Text     = 'Basic Info'
    $gbBasic.Size     = [System.Drawing.Size]::new(480,200)
    $gbBasic.Location = [System.Drawing.Point]::new(30,60)
    $ContentPanel.Controls.Add($gbBasic)

    # Class Name
    $lblName = [System.Windows.Forms.Label]::new(Text='Class Name:',Location=[System.Drawing.Point]::new(10,30))
    $txtName = [System.Windows.Forms.TextBox]::new(Location=[System.Drawing.Point]::new(120,26),Size=[System.Drawing.Size]::new(340,22))
    $gbBasic.Controls.AddRange(@($lblName,$txtName))

    # Quarter
    $lblQuarter = [System.Windows.Forms.Label]::new(Text='Quarter:',Location=[System.Drawing.Point]::new(10,70))
    $txtQuarter = [System.Windows.Forms.TextBox]::new(Location=[System.Drawing.Point]::new(120,66),Size=[System.Drawing.Size]::new(200,22))
    $gbBasic.Controls.AddRange(@($lblQuarter,$txtQuarter))

    # Course Code
    $lblCourse = [System.Windows.Forms.Label]::new(Text='Course Code:',Location=[System.Drawing.Point]::new(10,110))
    $txtCourse = [System.Windows.Forms.TextBox]::new(Location=[System.Drawing.Point]::new(120,106),Size=[System.Drawing.Size]::new(200,22))
    $gbBasic.Controls.AddRange(@($lblCourse,$txtCourse))

    # Students textbox
    $lblStud = [System.Windows.Forms.Label]::new(Text='Students (one per line):',Location=[System.Drawing.Point]::new(10,150))
    $txtStud = [System.Windows.Forms.TextBox]::new(
        Multiline  = $true,
        ScrollBars = 'Vertical',
        Location   = [System.Drawing.Point]::new(10,170),
        Size       = [System.Drawing.Size]::new(450,80)
    )
    $gbBasic.Controls.AddRange(@($lblStud,$txtStud))

    # VM Configuration Group
    $gbConfig = [System.Windows.Forms.GroupBox]::new(Text='VM Configuration')
    $gbConfig.Size     = [System.Drawing.Size]::new(480,200)
    $gbConfig.Location = [System.Drawing.Point]::new(530,60)
    $ContentPanel.Controls.Add($gbConfig)

    # Template dropdown
    $lblTmpl = [System.Windows.Forms.Label]::new(Text='VM Template:',Location=[System.Drawing.Point]::new(10,30))
    $cbTmpl  = [System.Windows.Forms.ComboBox]::new(DropDownStyle='DropDownList',Location=[System.Drawing.Point]::new(120,26),Size=[System.Drawing.Size]::new(200,22))
    $cbTmpl.Items.AddRange(@('Template A','Template B','Template C'))
    $gbConfig.Controls.AddRange(@($lblTmpl,$cbTmpl))

    # Datastore dropdown
    $lblDs = [System.Windows.Forms.Label]::new(Text='Datastore:',Location=[System.Drawing.Point]::new(10,70))
    $cbDs  = [System.Windows.Forms.ComboBox]::new(DropDownStyle='DropDownList',Location=[System.Drawing.Point]::new(120,66),Size=[System.Drawing.Size]::new(200,22))
    $cbDs.Items.AddRange(@('Datastore1','Datastore2','Datastore3'))
    $gbConfig.Controls.AddRange(@($lblDs,$cbDs))

    # Network adapters
    $lblNet = [System.Windows.Forms.Label]::new(Text='Network Adapters:',Location=[System.Drawing.Point]::new(10,110))
    $clbNet = [System.Windows.Forms.CheckedListBox]::new(
        Location=[System.Drawing.Point]::new(120,106),
        Size    =[System.Drawing.Size]::new(300,60)
    )
    $clbNet.Items.AddRange(@('Instructor','NAT','Inside'))
    $gbConfig.Controls.AddRange(@($lblNet,$clbNet))

    # Advanced Ops Group
    $gbAdv = [System.Windows.Forms.GroupBox]::new(Text='Advanced Operations')
    $gbAdv.Size     = [System.Drawing.Size]::new(1020,140)
    $gbAdv.Location = [System.Drawing.Point]::new(30,270)
    $ContentPanel.Controls.Add($gbAdv)

    # Single Student
    $lblSingle = [System.Windows.Forms.Label]::new(Text='Single Student:',Location=[System.Drawing.Point]::new(10,30))
    $txtSingle = [System.Windows.Forms.TextBox]::new(Location=[System.Drawing.Point]::new(120,26),Size=[System.Drawing.Size]::new(200,22))
    $gbAdv.Controls.AddRange(@($lblSingle,$txtSingle))

    # Target VM
    $lblTarget = [System.Windows.Forms.Label]::new(Text='Target VM:',Location=[System.Drawing.Point]::new(350,30))
    $txtTarget = [System.Windows.Forms.TextBox]::new(Location=[System.Drawing.Point]::new(430,26),Size=[System.Drawing.Size]::new(200,22))
    $gbAdv.Controls.AddRange(@($lblTarget,$txtTarget))

    # Action Buttons
    $buttons = @(
        @{ Text='Build All';     X=10;  Handler={ On-BuildAllClassClick $txtName $cbTmpl $cbDs $clbNet } },
        @{ Text='Build Single';  X=120; Handler={ On-BuildSingleClassClick $txtName $txtSingle $cbTmpl $cbDs $clbNet } },
        @{ Text='Delete All';    X=230; Handler={ On-DeleteAllClassClick $txtName } },
        @{ Text='Remove VM';     X=340; Handler={ On-RemoveVMClick $txtName $txtTarget } },
        @{ Text='Power On VM';   X=450; Handler={ On-PowerOnClassVMClick $txtName $txtTarget } },
        @{ Text='Power Off VM';  X=560; Handler={ On-PowerOffClassVMClick $txtName $txtTarget } },
        @{ Text='Restart All';   X=670; Handler={ On-RestartClassVMsClick $txtName } }
    )
    foreach ($btnSpec in $buttons) {
        $btn = [System.Windows.Forms.Button]::new(
            Text     = $btnSpec.Text,
            Location = [System.Drawing.Point]::new($btnSpec.X,70),
            Size     = [System.Drawing.Size]::new(100,30)
        )
        $btn.Add_Click($btnSpec.Handler)
        $gbAdv.Controls.Add($btn)
    }
}

Export-ModuleMember -Function Show-ClassesView