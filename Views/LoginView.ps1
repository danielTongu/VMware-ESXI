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
    $form = New-Object System.Windows.Forms.Form
    $form.Text            = 'VMware Management System'
    $form.StartPosition   = 'CenterScreen'
    $form.ClientSize      = [System.Drawing.Size]::new(300,455)
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox     = $false
    $form.MinimizeBox     = $false
    $form.BackColor       = $script:Theme.White
    $form.Font            = [System.Drawing.Font]::new('Segoe UI',10)
    $form.AutoScaleMode   = 'Font'

    # Shared logo/icon positioning and sizing
    $logoSize     = [System.Drawing.Size]::new(100,100)
    $logoLocation = [System.Drawing.Point]::new(([int](($form.ClientSize.Width - $logoSize.Width)/2)), 0)

    # Logo (optional)
    try {
        $logo = New-Object System.Windows.Forms.PictureBox
        $logo.SizeMode = 'Zoom'
        $logo.Size     = $logoSize
        $logo.Location = $logoLocation
        $logo.Image = [System.Drawing.Image]::FromFile("$PSScriptRoot\..\Images\login.png")
        $form.Controls.Add($logo)
    } catch {
        if ($logo) { $logo.Dispose() }
        $icon = New-Object System.Windows.Forms.Label
        $icon.Text = [char]0xE77B  # Unicode for "Contact" (person) icon in Segoe MDL2 Assets
        $icon.Font = New-Object System.Drawing.Font('Segoe MDL2 Assets', 50, [System.Drawing.FontStyle]::Regular)
        $icon.ForeColor = $script:Theme.PrimaryDarker
        $icon.TextAlign = 'MiddleCenter'
        $icon.Size      = $logoSize
        $icon.Location  = $logoLocation
        $form.Controls.Add($icon)
    }
    
    # Header label
    $lblHeader = New-Object System.Windows.Forms.Label
    $lblHeader.Text      = 'Sign In'
    $lblHeader.Font      = [System.Drawing.Font]::new('Segoe UI',25,[System.Drawing.FontStyle]::Bold)
    $lblHeader.ForeColor = $script:Theme.Primary
    $lblHeader.AutoSize  = $true
    $lblHeader.Location  = [System.Drawing.Point]::new(([int](($form.ClientSize.Width - $lblHeader.PreferredWidth)/2)), 100)

    $form.Controls.Add($lblHeader)

    # Server selection
    $lblServer = New-Object System.Windows.Forms.Label
    $lblServer.Text     = 'vCenter Server'
    $lblServer.Location = [System.Drawing.Point]::new(20,150)

    $cmbServer = New-Object System.Windows.Forms.ComboBox
    $cmbServer.Items.AddRange(@($script:Server,'vcenter2.cs.cwu.edu','Other'))
    $cmbServer.SelectedItem  = $script:Server
    $cmbServer.DropDownStyle = 'DropDownList'
    $cmbServer.Location      = [System.Drawing.Point]::new(20,175)
    $cmbServer.Size          = [System.Drawing.Size]::new(260,35)
    $cmbServer.Anchor        = 'Top,Left,Right'

    $form.Controls.AddRange(@($lblServer,$cmbServer))

    # Username field
    $lblUser = New-Object System.Windows.Forms.Label
    $lblUser.Text = 'Username'
    $lblUser.Location = [System.Drawing.Point]::new(20,210)

    $txtUser = New-Object System.Windows.Forms.TextBox
    $txtUser.Text     = $script:Username
    $txtUser.Location = [System.Drawing.Point]::new(20,240)
    $txtUser.Size     = [System.Drawing.Size]::new(260,35)
    $txtUser.Anchor   = 'Top,Left,Right'

    $form.Controls.AddRange(@($lblUser,$txtUser))

    # Password field
    $lblPass = New-Object System.Windows.Forms.Label
    $lblPass.Text = 'Password'
    $lblPass.Location = [System.Drawing.Point]::new(20,270)

    $txtPass = New-Object System.Windows.Forms.TextBox
    $txtPass.UseSystemPasswordChar = $true
    $txtPass.MaxLength = 100
    $txtPass.Location = [System.Drawing.Point]::new(20,300)
    $txtPass.Size = [System.Drawing.Size]::new(260,35)
    $txtPass.Anchor = 'Top,Left,Right'

    # Toggle button with checkbox
    $chkShowPass = New-Object System.Windows.Forms.CheckBox
    $chkShowPass.Text      = "Show Password"
    $chkShowPass.Location  = [System.Drawing.Point]::new(20, 330)
    $chkShowPass.Size      = [System.Drawing.Size]::new(120, 20)
    $chkShowPass.ForeColor = $script:Theme.PrimaryDark
    $chkShowPass.Add_CheckedChanged({ $txtPass.UseSystemPasswordChar = -not $chkShowPass.Checked })
    $form.Controls.AddRange(@($lblPass, $txtPass, $chkShowPass))

    # Create buttons
    $btnLogin  = New-StyledButton -Text 'LOGIN'  -Location ([System.Drawing.Point]::new(20,360))  -BackColor $script:Theme.Primary     -ForeColor $script:Theme.White -Width 120 -Height 40
    $btnCancel = New-StyledButton -Text 'CANCEL' -Location ([System.Drawing.Point]::new(160,360)) -BackColor $script:Theme.PrimaryDark -ForeColor $script:Theme.White -Width 120 -Height 40
    $form.Controls.AddRange(@($btnLogin,$btnCancel))
    $form.AcceptButton = $btnLogin
    $form.CancelButton = $btnCancel

    # Status label
    $lblStatus = New-Object System.Windows.Forms.TextBox
    $lblStatus.Location  = [System.Drawing.Point]::new(20,410)
    $lblStatus.Size      = [System.Drawing.Size]::new(260,30)
    $lblStatus.ForeColor = $script:Theme.Error
    $lblStatus.BackColor = $form.BackColor
    $lblStatus.Multiline = $true
    $lblStatus.ScrollBars = 'Vertical'
    $lblStatus.ReadOnly  = $true
    $lblStatus.BorderStyle = 'None'
    $lblStatus.WordWrap  = $true
    $lblStatus.TextAlign = 'Center'
    $form.Controls.Add($lblStatus)

    # Button event handlers
    $btnLogin.Add_Click({
        $server = if ($cmbServer.Text -eq 'Other') {
            [Microsoft.VisualBasic.Interaction]::InputBox('Enter vCenter Server Address:','Custom Server',$cmbServer.Items[0])
        } else { $cmbServer.Text }
        
        Handle-Login -Form $form -LoginButton $btnLogin -StatusLabel $lblStatus -UserBox $txtUser -PassBox $txtPass -Server $server
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
    $btn.Font      = [System.Drawing.Font]::new('Segoe UI',10,[System.Drawing.FontStyle]::Bold)
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

function Handle-Login {
    <#
    .SYNOPSIS
        Authenticates and stores the vCenter connection on success.
    #>

    [CmdletBinding()]
    param(
        [System.Windows.Forms.Form]    $Form,
        [System.Windows.Forms.Button]  $LoginButton,
        [System.Windows.Forms.TextBox]   $StatusLabel,
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
    $Form.Cursor         = [System.Windows.Forms.Cursors]::WaitCursor
    $StatusLabel.Text    = 'Authenticating...'
    $Form.Refresh()

    try {
        # Build credentials and connect
        $securePwd          = ConvertTo-SecureString $PassBox.Text -AsPlainText -Force
        $psCred             = New-Object System.Management.Automation.PSCredential($UserBox.Text,$securePwd)
        $LoginButton.Text   = 'CONNECTING...'
        $LoginButton.Refresh()

        # Temporarily suppress all PowerCLI output
        $oldPref = $global:ErrorActionPreference
        $global:ErrorActionPreference = 'SilentlyContinue'

        $script:Username   = $UserBox.Text
        $script:Server     = $Server
        $script:Connection = Connect-VIServer -Server $Server -Credential $psCred
        
        # Restore error handling
        $global:ErrorActionPreference = $oldPref
        # Check if connection succeeded
        if (-not $script:Connection) {
            throw "Login failed: Invalid credentials or server unavailable"
        }

        $script:LoginResult = $true
        $Form.Close()
    }
    catch {
        $StatusLabel.Text = $_.Exception.Message
    }
    finally {
        # Restore UI
        $LoginButton.Text    = 'LOGIN'
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
