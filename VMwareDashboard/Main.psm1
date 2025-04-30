function Start-VMwareDashboard {
    [CmdletBinding()] param()

    # 1) Load views
    $viewsDir = Join-Path $PSScriptRoot 'Views'
    Get-ChildItem $viewsDir -Filter '*.ps1' | ForEach-Object { . $_.FullName }

    # 2) WinForms assemblies
    Add-Type -AssemblyName System.Windows.Forms, System.Drawing

    # 3) Create controls
    $form        = [Windows.Forms.Form]::new()
    $split       = [Windows.Forms.SplitContainer]::new()
    $statusStrip = [Windows.Forms.StatusStrip]::new()
    $statusLabel = [Windows.Forms.ToolStripStatusLabel]::new()

    # 4) Configure form
    $form.Text          = 'VMware Dashboard'
    $form.Size          = [Drawing.Size]::new(1100,800)
    $form.StartPosition = 'CenterScreen'
    $form.MinimumSize   = [Drawing.Size]::new(800,600)

    # 5) Configure SplitContainer (only one panel1!)
    $split.Dock               = 'Fill'
    $split.FixedPanel         = 'Panel1'
    $split.IsSplitterFixed    = $true
    $split.SplitterDistance   = 400    # ← force 400px width
    $split.Panel1MinSize      = 400    # ← never shrink below 400px
    $split.Panel1.BackColor   = [Drawing.Color]::LightGray
    $split.Panel2.BackColor   = [Drawing.Color]::White

    # 6) Configure StatusStrip
    $statusLabel.Text = 'Ready'
    $statusStrip.Items.Add($statusLabel) | Out-Null
    $statusStrip.Dock = 'Bottom'

    # 7) Helpers for menu buttons
    function Set-ActiveMenuButton {
        param([Windows.Forms.Button]$btn)
        $split.Panel1.Controls | Where-Object { $_ -is [Windows.Forms.Button] } |
            ForEach-Object { $_.BackColor = if ($_ -eq $btn) { [Drawing.Color]::DarkGray } else { [Drawing.Color]::LightGray } }
    }
    function Add-MenuButton {
        param($text, $y, $view)

        $b = New-Object System.Windows.Forms.Button
        $b.Text     = $text
        $b.Size     = [System.Drawing.Size]::new(180,40)
        $b.Location = [System.Drawing.Point]::new(10,$y)
        $b.FlatStyle = 'System'
        $b.Add_Click({
            Set-ActiveMenuButton $b
            & $view $split.Panel2
            $statusLabel.Text = "Viewing: $text"
        })
        $split.Panel1.Controls.Add($b)
        return $b
    }

    # 8) Build menu in Panel1
    Add-MenuButton 'Dashboard'        20  { Show-DashboardView   }
    Add-MenuButton 'Classes'          70  { Show-ClassesView     }
    Add-MenuButton 'Virtual Machines' 120 { Show-VMsView         }
    Add-MenuButton 'Networks'         170 { Show-NetworksView    }
    Add-MenuButton 'Logs'             220 { Show-LogsView        }
    Add-MenuButton 'Exit'             700 { $form.Close()        }

    # 9) Assemble the form (only split + statusStrip)
    $form.Controls.AddRange(@($split, $statusStrip))

    # 10) Initial view
    $first = $split.Panel1.Controls | Where-Object { $_.Text -eq 'Vir' }
    Set-ActiveMenuButton $first
    Show-DashboardView $split.Panel2
    $statusLabel.Text = 'Viewing: Dashboard'

    # 11) Run
    [Windows.Forms.Application]::EnableVisualStyles()
    [Windows.Forms.Application]::Run($form)
}

Export-ModuleMember -Function Start-VMwareDashboard