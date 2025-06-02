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
    $form.Text = 'VMware Management System'
    $form.StartPosition = 'CenterScreen'
    $form.ClientSize = New-Object System.Drawing.Size(300,500)
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.BackColor = $script:Theme.White
    $form.Font = New-Object System.Drawing.Font('Segoe UI',10)
    $form.AutoScaleMode = 'Font'
    $form.Padding = New-Object System.Windows.Forms.Padding(20, 0, 20, 20)

    # Create table layout panel
    $tableLayout = New-Object System.Windows.Forms.TableLayoutPanel
    $tableLayout.Dock = 'Fill'
    $tableLayout.AutoSize = $true
    $tableLayout.ColumnCount = 2
    $tableLayout.RowCount = 11
    $tableLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 50)))
    $tableLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 50)))
    $form.Controls.Add($tableLayout)

    # Logo
    try {
        $logo = New-Object System.Windows.Forms.PictureBox
        $logo.Dock      = 'Fill'
        $logo.Size      = New-Object System.Drawing.Size(70,70)
        $logo.SizeMode  = 'Zoom'
        $logo.Image = [System.Drawing.Image]::FromFile("$PSScriptRoot\..\Images\login.png")
        $logo.Padding   = New-Object System.Windows.Forms.Padding(1)
    } catch {
        # Use Segoe MDL2 Assets person icon if image not found
        if ($logo) { $logo.Dispose() }
        $logo = New-Object System.Windows.Forms.Label
        $logo.Text = [char]0xE77B  # Unicode for "Contact" (person) icon in Segoe MDL2 Assets
        $logo.Font = New-Object System.Drawing.Font('Segoe MDL2 Assets', 48, [System.Drawing.FontStyle]::Regular)
        $logo.ForeColor = $script:Theme.PrimaryDarker
        $logo.TextAlign = 'MiddleCenter'
        $logo.Dock = 'Fill'
        $logo.AutoSize = $true
    } finally {
        $tableLayout.Controls.Add($logo, 0, 0)
        $tableLayout.SetColumnSpan($logo, 2)
    }

    $labelFont = New-Object System.Drawing.Font('Segoe UI',10,[System.Drawing.FontStyle]::Bold)
    $labelMargin = New-Object System.Windows.Forms.Padding(0, 10, 0, 0)

    # Header label
    $lblHeader = New-Object System.Windows.Forms.Label
    $lblHeader.Dock = 'Fill'
    $lblHeader.Autosize = $true
    $lblHeader.TextAlign = 'MiddleCenter'
    $lblHeader.Text = 'Sign In'
    $lblHeader.Font = New-Object System.Drawing.Font('Segoe UI',25,[System.Drawing.FontStyle]::Bold)
    $lblHeader.ForeColor = $script:Theme.Primary

    $tableLayout.Controls.Add($lblHeader, 0,1)
    $tableLayout.SetColumnSpan($lblHeader, 2)

    # Server selection
    $lblServer = New-Object System.Windows.Forms.Label
    $lblServer.Margin = $labelMargin
    $lblServer.Font = $labelFont
    $lblServer.Dock = 'Fill'
    $lblServer.Text = 'vCenter Server'
    $lblServer.AutoSize = $true
    $tableLayout.Controls.Add($lblServer, 0, 2)

    $cmbServer = New-Object System.Windows.Forms.ComboBox
    $cmbServer.Dock = 'Fill'
    $cmbServer.DropDownStyle = 'DropDownList'
    $cmbServer.Items.AddRange(@($script:Server,'vcenter2.cs.cwu.edu','Other'))
    $cmbServer.SelectedItem = $script:Server
    $tableLayout.Controls.Add($cmbServer, 0, 3)
    $tableLayout.SetColumnSpan($cmbServer, 2)

    # Username field
    $lblUser = New-Object System.Windows.Forms.Label
    $lblUser.Margin = $labelMargin
    $lblUser.Font = $labelFont
    $lblUser.Text = 'Username'
    $lblUser.AutoSize = $true
    $tableLayout.Controls.Add($lblUser, 0, 4)

    $txtUser = New-Object System.Windows.Forms.TextBox
    $txtUser.Dock = 'Fill'
    $txtUser.Text = $script:username
    $tableLayout.Controls.Add($txtUser, 0, 5)
    $tableLayout.SetColumnSpan($txtUser, 2)

    # Password field
    $lblPass = New-Object System.Windows.Forms.Label
    $lblPass.Margin =$labelMargin
    $lblPass.Font = $labelFont
    $lblPass.Text = 'Password'
    $lblPass.AutoSize = $true
    $tableLayout.Controls.Add($lblPass, 0, 6)

    $txtPass = New-Object System.Windows.Forms.TextBox
    $txtPass.Dock = 'Fill'
    $txtPass.Text = $script:password
    $txtPass.UseSystemPasswordChar = $true
    $txtPass.MaxLength = 100
    $tableLayout.Controls.Add($txtPass, 0, 7)
    $tableLayout.SetColumnSpan($txtPass, 2)

    # Show password checkbox
    $chkShowPass = New-Object System.Windows.Forms.CheckBox
    $chkShowPass.Text = "Show Password"
    $chkShowPass.AutoSize = $true
    $chkShowPass.ForeColor = $script:Theme.PrimaryDark
    $chkShowPass.Add_CheckedChanged({
        $txtPass.UseSystemPasswordChar = -not $chkShowPass.Checked
    })
    $tableLayout.Controls.Add($chkShowPass, 0, 8)
    $tableLayout.SetColumnSpan($chkShowPass, 2)

    # Create buttons
    $btnLogin = New-StyledButton -Text 'LOGIN' -BackColor $script:Theme.Primary -ForeColor $script:Theme.White
    $btnCancel = New-StyledButton -Text 'CANCEL' -BackColor $script:Theme.PrimaryDark -ForeColor $script:Theme.White
    
    $tableLayout.Controls.Add($btnLogin, 0, 9)
    $tableLayout.Controls.Add($btnCancel, 1, 9)
    
    $form.AcceptButton = $btnLogin
    $form.CancelButton = $btnCancel

    # Status label inside a scrollable panel
    $pnlStatus = New-Object System.Windows.Forms.Panel
    $pnlStatus.Dock = 'Fill'
    $pnlStatus.AutoScroll = $true
    $pnlStatus.Height = 60

    $lblStatus = New-Object System.Windows.Forms.Label
    $lblStatus.ForeColor = $script:Theme.Error
    $lblStatus.AutoSize = $true
    $lblStatus.MaximumSize = New-Object System.Drawing.Size(260, 0) # wrap text
    $lblStatus.Text = ''

    $pnlStatus.Controls.Add($lblStatus)
    $tableLayout.Controls.Add($pnlStatus, 0, 10)
    $tableLayout.SetColumnSpan($pnlStatus, 2)

    # Button event handlers
    $btnLogin.Add_Click({
        $server = if ($cmbServer.Text -eq 'Other') {
            [Microsoft.VisualBasic.Interaction]::InputBox('Enter vCenter Server Address:','Custom Server',$cmbServer.Items[0])
        } else { $cmbServer.Text }
        
        Handle-Login -Form $form -LoginButton $btnLogin -StatusLabel $lblStatus -UserBox $txtUser -PassBox $txtPass -Server $server
    })

    $btnCancel.Add_Click({
        $script:LoginResult = $false
        $script:Connection = $null
        $script:username = '';
        $Form.Close()
    })

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
        [System.Drawing.Color]  $BackColor,
        [System.Drawing.Color]  $ForeColor
    )

    $btn = New-Object System.Windows.Forms.Button
    $btn.Dock = 'Fill'
    $btn.AutoSize = $true
    $btn.Text = $Text
    $btn.Font = New-Object System.Drawing.Font('Segoe UI',11,[System.Drawing.FontStyle]::Bold)
    $btn.FlatStyle = 'Flat'
    $btn.FlatAppearance.BorderSize = 0
    $btn.BackColor = $BackColor
    $btn.ForeColor = $ForeColor
    $btn.Padding   = New-Object System.Windows.Forms.Padding(7)
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
    $Form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
    $StatusLabel.Text = 'Authenticating...'
    $Form.Refresh()

    try {
        # Build credentials and connect
        $securePwd = ConvertTo-SecureString $PassBox.Text -AsPlainText -Force
        $psCred = New-Object System.Management.Automation.PSCredential($UserBox.Text,$securePwd)
        $LoginButton.Text = 'CONNECTING...'
        $LoginButton.Refresh()

        # Temporarily suppress all PowerCLI output
        $oldPref = $global:ErrorActionPreference
        $global:ErrorActionPreference = 'SilentlyContinue'

        $script:username = $UserBox.Text
        $script:Server = $Server
        $script:Connection = Connect-VIServer -Server $Server -Credential $psCred
        
        # Restore error handling
        $global:ErrorActionPreference = $oldPref
        # Check if connection succeeded
        if (-not $script:Connection) {
            throw "Login failed: Invalid credentials or server unavailable Login failed: Invalid credentials or server unavailableLogin failed: Invalid credentials or server unavailableLogin failed: Invalid credentials or server unavailableLogin failed: Invalid credentials or server unavailableLogin failed: Invalid credentials or server unavailableLogin failed: Invalid credentials or server unavailableLogin failed: Invalid credentials or server unavailableLogin failed: Invalid credentials or server unavailableLogin failed: Invalid credentials or server unavailableLogin failed: Invalid credentials or server unavailableLogin failed: Invalid credentials or server unavailableLogin failed: Invalid credentials or server unavailable"
        }

        $script:LoginResult = $true
        $Form.Close()
    }
    catch {
        $StatusLabel.Text = $_.Exception.Message
    }
    finally {
        # Restore UI
        $LoginButton.Text = 'LOGIN'
        $Form.Cursor = [System.Windows.Forms.Cursors]::Default
    }
}