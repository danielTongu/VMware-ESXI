<#
.SYNOPSIS
    VMware Management — Login UI.
.DESCRIPTION
    Provides a WinForms-based login dialog for vCenter Server authentication.
#>


# Load Required Assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName 'Microsoft.VisualBasic'


function Show-LoginView {
    <#
    .SYNOPSIS
        Renders and shows the VMware Management System login dialog.
    .OUTPUTS
        [bool]  True if login succeeded; False otherwise.
    #>

    [CmdletBinding()]
    param()

    # Initialize result
    $script:LoginResult = $false

    # Create and configure the form
    $form = New-Object System.Windows.Forms.Form -Property @{
        Text            = 'VMware Management System'
        StartPosition   = 'CenterScreen'
        ClientSize      = [System.Drawing.Size]::new(400,500)
        FormBorderStyle = 'FixedDialog'
        MaximizeBox     = $false
        MinimizeBox     = $false
        BackColor       = $script:Theme.White
        Font            = [System.Drawing.Font]::new('Segoe UI',10)
        AutoScaleMode   = 'Font'
    }

    # Logo (optional)
    $logo = New-Object System.Windows.Forms.PictureBox
    $logo.SizeMode = 'Zoom'
    $logo.Size     = [System.Drawing.Size]::new(130,130)
    $logo.Location = [System.Drawing.Point]::new(135,10)
    try { $logo.Image = [System.Drawing.Image]::FromFile("$PSScriptRoot\..\Images\login.png") } catch {}
    $form.Controls.Add($logo)

    # Header label
    $lblHeader = New-Object System.Windows.Forms.Label
    $lblHeader.Text      = 'Sign In'
    $lblHeader.Font      = [System.Drawing.Font]::new('Segoe UI',20,[System.Drawing.FontStyle]::Bold)
    $lblHeader.ForeColor = $script:Theme.Primary
    $lblHeader.AutoSize  = $true
    $lblHeader.Location  = [System.Drawing.Point]::new(150,150)
    
    $form.Controls.Add($lblHeader)

    # Server selection
    $lblServer = New-Object System.Windows.Forms.Label -Property @{ Text='vCenter Server'; Location=[System.Drawing.Point]::new(30,200) }
    $cmbServer = New-Object System.Windows.Forms.ComboBox
    $cmbServer.Items.AddRange(@($script:Server,'vcenter2.cs.cwu.edu','Other'))
    $cmbServer.SelectedItem  = $script:Server
    $cmbServer.DropDownStyle = 'DropDownList'
    $cmbServer.Location      = [System.Drawing.Point]::new(30,224)
    $cmbServer.Size          = [System.Drawing.Size]::new(340,35)
    $cmbServer.Anchor        = 'Top,Left,Right'

    $form.Controls.AddRange(@($lblServer,$cmbServer))

    # Username field
    $lblUser = New-Object System.Windows.Forms.Label -Property @{ 
        Text = 'Username'
        Location = [System.Drawing.Point]::new(30,270) 
    }

    $txtUser = New-Object System.Windows.Forms.TextBox -Property @{
        Text     = $script:username
        Location = [System.Drawing.Point]::new(30,294)
        Size     = [System.Drawing.Size]::new(340,35)
        Anchor   = 'Top,Left,Right'
    }

    $form.Controls.AddRange(@($lblUser,$txtUser))

    # Password field
    $lblPass = New-Object System.Windows.Forms.Label -Property @{ 
        Text = 'Password' 
        Location=[System.Drawing.Point]::new(30,330) 
    }

    $txtPass = New-Object System.Windows.Forms.TextBox -Property @{
        Text                    = $script:password
        UseSystemPasswordChar   = $true
        MaxLength               = 100
        Location                = [System.Drawing.Point]::new(30,354)
        Size                    = [System.Drawing.Size]::new(340,35) 
        Anchor                  = 'Top,Left,Right'
    }

    # Eye toggle button with checkbox
    $chkShowPass = New-Object System.Windows.Forms.CheckBox -Property @{
    Text     = "Show Password"
    Location = [System.Drawing.Point]::new(30, 390)  # Adjust Y position as needed
    Size     = [System.Drawing.Size]::new(150, 20)
    ForeColor = $script:Theme.PrimaryDark
    }
    $chkShowPass.Add_CheckedChanged({
        $txtPass.UseSystemPasswordChar = -not $chkShowPass.Checked
    })
    $form.Controls.AddRange(@($lblPass, $txtPass, $chkShowPass))

    # Status label
    $lblStatus = New-Object System.Windows.Forms.Label -Property @{
        Location  = [System.Drawing.Point]::new(30,400)
        Size      = [System.Drawing.Size]::new(340,30)
        ForeColor = $script:Theme.Error
        TextAlign = 'MiddleCenter'
    }
    $form.Controls.Add($lblStatus)

    # Helper: create styled button
    function New-StyledButton {
        [CmdletBinding()]
        param(
            [string]                $Text,
            [System.Drawing.Point]  $Location,
            [System.Drawing.Color]  $BackColor,
            [System.Drawing.Color]  $ForeColor,
            [int]                   $Width = 150,
            [int]                   $Height = 40
        )

        $btn = New-Object System.Windows.Forms.Button
        $btn.Text      = $Text
        $btn.Location  = $Location
        $btn.Size      = [System.Drawing.Size]::new($Width,$Height)
        $btn.Font      = [System.Drawing.Font]::new('Segoe UI',11,[System.Drawing.FontStyle]::Bold)
        $btn.FlatStyle = 'Flat'
        $btn.FlatAppearance.BorderSize = 0
        $btn.BackColor = $BackColor
        $btn.ForeColor = $ForeColor
        $btn.FlatAppearance.MouseOverBackColor = $BackColor
        $btn.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::FromArgb(
            [int]($BackColor.R * 0.7), [int]($BackColor.G * 0.7), [int]($BackColor.B * 0.7)
        )

        return $btn
    }

    # Create buttons
    $btnLogin  = New-StyledButton -Text 'LOGIN'  -Location ([System.Drawing.Point]::new(30,440))  -BackColor $script:Theme.Primary     -ForeColor $script:Theme.White
    $btnCancel = New-StyledButton -Text 'CANCEL' -Location ([System.Drawing.Point]::new(220,440)) -BackColor $script:Theme.PrimaryDark -ForeColor $script:Theme.White
    $form.Controls.AddRange(@($btnLogin,$btnCancel))
    $form.AcceptButton = $btnLogin
    $form.CancelButton = $btnCancel

    # Button event handlers
    $btnLogin.Add_Click({
        $server = if ($cmbServer.Text -eq 'Other') {
            [Microsoft.VisualBasic.Interaction]::InputBox('Enter vCenter Server Address:','Custom Server',$cmbServer.Items[0])
        } else { $cmbServer.Text }
        
        Handle-Login -Form $form -LoginButton $btnLogin -CancelButton $btnCancel -StatusLabel $lblStatus -UserBox $txtUser -PassBox $txtPass -Server $server
    })
    $btnCancel.Add_Click({ Handle-Cancel -Form $form })

    # Show the dialog
    try {
        $form.ShowDialog() | Out-Null
    } finally {
        $logo.Dispose()
        $form.Dispose()
    }

    return $script:LoginResult
}




function Handle-Login {
    <#
    .SYNOPSIS
        Authenticates and stores the vCenter connection on success.
    #>

    [CmdletBinding()]
    param(
        [System.Windows.Forms.Form]    $Form,
        [System.Windows.Forms.Button]  $LoginButton,
        [System.Windows.Forms.Button]  $CancelButton,
        [System.Windows.Forms.Label]   $StatusLabel,
        [System.Windows.Forms.TextBox] $UserBox,
        [System.Windows.Forms.TextBox] $PassBox,
        [string]                       $Server
    )

    # Input validation
    if ([string]::IsNullOrWhiteSpace($UserBox.Text) -or [string]::IsNullOrWhiteSpace($PassBox.Text)) {
        $StatusLabel.Text = "Username and password are required"
        return
    }

    # Disable UI
    $LoginButton.Enabled = $false
    $CancelButton.Enabled = $false
    $Form.Cursor         = [System.Windows.Forms.Cursors]::WaitCursor
    $StatusLabel.Text    = 'Authenticating...'
    $Form.Refresh()

    try {
        # Build credentials and connect
        $securePwd          = ConvertTo-SecureString $PassBox.Text -AsPlainText -Force
        $psCred             = New-Object System.Management.Automation.PSCredential($UserBox.Text,$securePwd)
        $LoginButton.Text   = 'CONNECTING...'
        $LoginButton.Refresh()

        $script:username   = $UserBox.Text
        $script:Server     = $Server
        $script:Connection = Connect-VIServer -Server $Server -Credential $psCred -ErrorAction Stop
        $script:LoginResult = $true
        
        $Form.Close()
    }
    catch {
        $StatusLabel.Text = "Login failed: $($_.Exception.Message)"
    }
    finally {
        # Restore UI
        $LoginButton.Text    = 'LOGIN'
        $LoginButton.Enabled = $true
        $CancelButton.Enabled= $true
        $Form.Cursor         = [System.Windows.Forms.Cursors]::Default
    }
}




function Handle-Cancel {
    <#
        .SYNOPSIS
            Cancels login and closes the form.
    #>

    [CmdletBinding()] param(
        [System.Windows.Forms.Form] $Form
    )
    $script:LoginResult = $false
    $script:Connection  = $null
    $Form.Close()
}
