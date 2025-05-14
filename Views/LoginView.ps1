# Views/LoginView.ps1
<#
.SYNOPSIS
    VMware Management System Login View with Offline Support
.DESCRIPTION
    Enhanced authentication with:
      - Online login via Connect-VIServer
      - Optional offline mode continuation
      - Connection resilience and visual feedback
      - Credential remember/unremember
#>
Import-Module VMware.PowerCLI
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Show-LoginView {
    [CmdletBinding()]
    param()

    # if the user is logged in, it skips the login form
    # and return true which then redirects to dashboard
    if ($global:IsLoggedIn) { 
        return $true 
    }
    
    $script:LoginResult = $false

    # Main Form
    $mainForm = [System.Windows.Forms.Form]::new()
    $mainForm.Text = 'VMware Management System'
    $mainForm.StartPosition = 'CenterScreen'
    $mainForm.TopMost = $true
    $mainForm.MinimumSize = [System.Drawing.Size]::new(400, 500)
    $mainForm.AutoSize = $true
    $mainForm.BackColor = $global:Theme.White
    $mainForm.FormBorderStyle = 'FixedDialog'
    $mainForm.MaximizeBox = $false
    $mainForm.MinimizeBox = $false
    $mainForm.Padding = [System.Windows.Forms.Padding]::new(20)

    # Logo
    $logo = [System.Windows.Forms.PictureBox]::new()
    $logo.Size = [System.Drawing.Size]::new(130, 130)
    $logo.Location = [System.Drawing.Point]::new(($mainForm.ClientSize.Width - $logo.Width) / 2, 10)
    try { $logo.Image = [System.Drawing.Image]::FromFile("$PSScriptRoot\..\Images\login.png") } catch {}
    $logo.SizeMode = 'Zoom'
    $mainForm.Controls.Add($logo)

    # Header
    $lblHeader = [System.Windows.Forms.Label]::new()
    $lblHeader.Text = 'Sign In'
    $lblHeader.Font = [System.Drawing.Font]::new('Segoe UI', 20, [System.Drawing.FontStyle]::Bold)
    $lblHeader.ForeColor = $global:Theme.Primary
    $lblHeader.Location = [System.Drawing.Point]::new(($mainForm.ClientSize.Width - $lblHeader.PreferredWidth) / 2, 160)
    $lblHeader.AutoSize = $true
    $mainForm.Controls.Add($lblHeader)

    # Styles
    $fieldStyle = @{
        Font = [System.Drawing.Font]::new('Segoe UI', 11)
        BorderStyle = 'FixedSingle'
        BackColor = $global:Theme.White
        ForeColor = $global:Theme.PrimaryDarker
    }

    $labelStyle = @{
        Font = [System.Drawing.Font]::new('Segoe UI', 10)
        ForeColor = $global:Theme.PrimaryDark
        AutoSize = $true
    }

    # Username
    $lblUser = [System.Windows.Forms.Label]::new()
    $lblUser.Text = 'Username'
    $lblUser.Location = [System.Drawing.Point]::new(30, 200)
    foreach ($p in $labelStyle.GetEnumerator()) { $lblUser.($p.Key) = $p.Value }
    $mainForm.Controls.Add($lblUser)

    $txtUser = [System.Windows.Forms.TextBox]::new()
    $txtUser.Location = [System.Drawing.Point]::new(30, 224)
    $txtUser.Size = [System.Drawing.Size]::new(340, 35)
    foreach ($p in $fieldStyle.GetEnumerator()) { $txtUser.($p.Key) = $p.Value }
    $mainForm.Controls.Add($txtUser)

    # Password
    $lblPass = [System.Windows.Forms.Label]::new()
    $lblPass.Text = 'Password'
    $lblPass.Location = [System.Drawing.Point]::new(30, 260)
    foreach ($p in $labelStyle.GetEnumerator()) { $lblPass.($p.Key) = $p.Value }
    $mainForm.Controls.Add($lblPass)

    $txtPass = [System.Windows.Forms.TextBox]::new()
    $txtPass.Location = [System.Drawing.Point]::new(30, 284)
    $txtPass.PasswordChar = '*'
    $txtPass.MaxLength = 100
    $txtPass.UseSystemPasswordChar = $true
    $txtPass.Size = [System.Drawing.Size]::new(340, 35)
    foreach ($p in $fieldStyle.GetEnumerator()) { $txtPass.($p.Key) = $p.Value }
    $mainForm.Controls.Add($txtPass)

    # Remember Me
    $chkRemember = [System.Windows.Forms.CheckBox]::new()
    $chkRemember.Text = 'Remember credentials'
    $chkRemember.Location = [System.Drawing.Point]::new(30, 330)
    $chkRemember.AutoSize = $true
    $chkRemember.Font = [System.Drawing.Font]::new('Segoe UI', 10)
    $chkRemember.ForeColor = $global:Theme.PrimaryDark
    $mainForm.Controls.Add($chkRemember)

    # Buttons
    $btnLogin = New-StyledButton -Text 'LOGIN' -Location ([System.Drawing.Point]::new(30, 370)) `
        -BackColor $global:Theme.Primary -ForeColor $global:Theme.White `
        -MouseOverBackColor $global:Theme.PrimaryDark

    $btnCancel = New-StyledButton -Text 'CANCEL' -Location ([System.Drawing.Point]::new(220, 370)) `
        -BackColor $global:Theme.PrimaryDark -ForeColor $global:Theme.White `
        -MouseOverBackColor $global:Theme.Primary

    $mainForm.AcceptButton = $btnLogin
    $mainForm.CancelButton = $btnCancel
    $mainForm.Controls.Add($btnLogin)
    $mainForm.Controls.Add($btnCancel)

    # Status Label
    $lblStatus = [System.Windows.Forms.Label]::new()
    $lblStatus.Text = ''
    $lblStatus.Size = [System.Drawing.Size]::new(340, 40)
    $lblStatus.Location = [System.Drawing.Point]::new(30, 420)
    $lblStatus.TextAlign = [System.Windows.Forms.HorizontalAlignment]::Center
    $lblStatus.Font = [System.Drawing.Font]::new('Segoe UI', 10)
    $lblStatus.ForeColor = $global:Theme.PrimaryDark
    $mainForm.Controls.Add($lblStatus)

    # Offline Button (Dev only)
    $btnOffline = [System.Windows.Forms.Button]::new()
    $btnOffline.Text = 'TEMP BYPASS - FOR DEV'
    $btnOffline.Font = [System.Drawing.Font]::new('Segoe UI', 10)
    $btnOffline.Size = [System.Drawing.Size]::new(340, 35)
    $btnOffline.Location = [System.Drawing.Point]::new(30, 460)
    $btnOffline.FlatStyle = 'Flat'
    $btnOffline.FlatAppearance.BorderSize = 1
    $btnOffline.FlatAppearance.BorderColor = $global:Theme.Primary
    $btnOffline.BackColor = $global:Theme.White
    $btnOffline.ForeColor = $global:Theme.Primary
    $btnOffline.Visible = $false
    $mainForm.Controls.Add($btnOffline)

    # Load remembered credentials
    if (Test-Path $global:Paths.Credentials) {
        try {
            $secureString = Import-Clixml -Path $global:Paths.Credentials
            $psCred = New-Object System.Management.Automation.PSCredential('dummy', $secureString)
            $txtUser.Text = $psCred.GetNetworkCredential().UserName
            $txtPass.Text = $psCred.GetNetworkCredential().Password
            $chkRemember.Checked = $true
        } catch {
            Write-Host '[CREDENTIAL LOAD ERROR]' $_ -ForegroundColor Red
            $lblStatus.Text = 'Warning: Could not load saved credentials'
            $lblStatus.ForeColor = $global:Theme.Warning
        }
    }

    # Event Handlers
    $btnLogin.Add_Click({
        Handle-Login -mainForm $mainForm -btnLogin $btnLogin -btnCancel $btnCancel -btnOffline $btnOffline `
                     -lblStatus $lblStatus -txtUser $txtUser -txtPass $txtPass -chkRemember $chkRemember
    })

    $btnCancel.Add_Click({ Handle-Cancel -mainForm $mainForm })
    $btnOffline.Add_Click({ Handle-Offline -mainForm $mainForm })

    # Fade-in animation
    $mainForm.Add_Shown({
        $mainForm.Opacity = 0
        while ($mainForm.Opacity -lt 1) {
            $mainForm.Opacity += 0.05
            [System.Threading.Thread]::Sleep(10)
            $mainForm.Refresh()
        }
    })

    $result = $mainForm.ShowDialog()
    $mainForm.Dispose()
    return $script:LoginResult
}



<#
    .SYNOPSIS
        Creates a styled button with optional FlatAppearance settings.
    .DESCRIPTION
        This function returns a Button control with consistent styling applied.
    .PARAMETER Text
        The button text.
    .PARAMETER Location
        The position of the button.
    .PARAMETER BackColor
        The background color of the button.
    .PARAMETER ForeColor
        The text color of the button.
    .PARAMETER Width
        Optional width (default 150).
    .PARAMETER Height
        Optional height (default 40).
    .PARAMETER MouseOverBackColor
        Optional background color on mouse over.
#>
function New-StyledButton {
    param(
        [string]$Text,
        [System.Drawing.Point]$Location,
        [System.Drawing.Color]$BackColor,
        [System.Drawing.Color]$ForeColor,
        [int]$Width = 150,
        [int]$Height = 40,
        [System.Drawing.Color]$MouseOverBackColor
    )

    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $Text
    $btn.Location = $Location
    $btn.Size = New-Object System.Drawing.Size($Width, $Height)
    $btn.Font = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)
    $btn.BackColor = $BackColor
    $btn.ForeColor = $ForeColor
    $btn.FlatStyle = 'Flat'
    $btn.FlatAppearance.BorderSize = 0
    $btn.FlatAppearance.MouseOverBackColor =  $MouseOverBackColor

    return $btn
}



<#
    .SYNOPSIS
        Handles the login button click event.
    .DESCRIPTION
        Authenticates the user with the provided credentials and updates the global state.
#>
function Handle-Login {
    param(
        [System.Windows.Forms.Form]$mainForm,
        [System.Windows.Forms.Button]$btnLogin,
        [System.Windows.Forms.Button]$btnCancel,
        [System.Windows.Forms.Button]$btnOffline,
        [System.Windows.Forms.Label]$lblStatus,
        [System.Windows.Forms.TextBox]$txtUser,
        [System.Windows.Forms.TextBox]$txtPass,
        [System.Windows.Forms.CheckBox]$chkRemember
    )

    # Disable all buttons during processing
    $btnLogin.Enabled = $false
    $btnCancel.Enabled = $false
    $btnOffline.Enabled = $false
    
    $mainForm.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
    $lblStatus.Text = 'Authenticating...'

    $mainForm.Refresh()

    try {
        $securePwd = ConvertTo-SecureString $txtPass.Text -AsPlainText -Force
        $psCred = New-Object System.Management.Automation.PSCredential($txtUser.Text, $securePwd)

        # Visual feedback during connection
        $btnLogin.Text = 'CONNECTING...'
        $btnLogin.Refresh()

        # Connect to VMware server
        $viConnection = Connect-VIServer -Server $global:AppState.VMware.Server -Credential $psCred -ErrorAction Stop

        # Update global state with connection details
        $global:AppState.VMware.Connection = $viConnection
        $global:AppState.VMware.User = $psCred.UserName
        $global:AppState.VMware.Session = $viConnection.SessionId
        $global:AppState.VMware.LastConnection = Get-Date

        # Handle credential persistence
        if ($chkRemember.Checked) {
            $folder = Split-Path $global:Paths.Credentials -Parent
            if (-not (Test-Path $folder)) {
                New-Item -ItemType Directory -Path $folder -Force | Out-Null
            }
            $securePwd | Export-Clixml -Path $global:Paths.Credentials -Force
        } elseif (Test-Path $global:Paths.Credentials) {
            Remove-Item $global:Paths.Credentials -ErrorAction SilentlyContinue
        }

        $script:LoginResult = $true
        $mainForm.Close()
    } catch {
        $lblStatus.Text = "Login failed: $($_.Exception.Message)"
        $lblStatus.ForeColor = $global:Theme.Error
        $btnOffline.Visible = $true
        $mainForm.Height = 550  # Adjust height to show offline button
        $mainForm.Refresh()
    } finally {
        # Restore UI state
        $btnLogin.Text = 'LOGIN'
        $btnLogin.Enabled = $true
        $btnCancel.Enabled = $true
        $btnOffline.Enabled = $true
        $mainForm.Cursor = [System.Windows.Forms.Cursors]::Default
    }
}



<#
    .SYNOPSIS
        Handles the continue offline button click event.
    .DESCRIPTION
        Sets the application to offline mode and closes the login form.
#>
function Handle-Offline {
    param( [System.Windows.Forms.Form]$mainForm )
    $script:LoginResult = $true
    $mainForm.Close()
}



<#
    .SYNOPSIS
        Handles the cancel button click event.
    .DESCRIPTION
        Cancels the login operation and closes the form.
#>
function Handle-Cancel {
    param( [System.Windows.Forms.Form]$mainForm )
    $script:LoginResult = $false
    $mainForm.Close()
}
