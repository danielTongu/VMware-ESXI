<#
.SYNOPSIS
    Modern VMware Management System Login
.DESCRIPTION
    Enhanced authentication interface featuring:
    - Sleek modern UI design
    - Responsive layout with visual feedback
    - Secure credential management
    - Online/offline mode switching
#>

# Import required .NET assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Show-LoginView {
    [CmdletBinding()]
    param()

    # UI Theme Configuration
    $theme = @{
        Background     = [System.Drawing.Color]::FromArgb(240, 240, 240)
        Primary        = [System.Drawing.Color]::FromArgb(0, 120, 215)
        Secondary      = [System.Drawing.Color]::FromArgb(100, 160, 220)
        TextPrimary    = [System.Drawing.Color]::FromArgb(50, 50, 50)
        TextSecondary  = [System.Drawing.Color]::FromArgb(120, 120, 120)
        Success        = [System.Drawing.Color]::FromArgb(50, 160, 80)
        Warning        = [System.Drawing.Color]::FromArgb(220, 150, 0)
        Error          = [System.Drawing.Color]::FromArgb(220, 80, 80)
        CardBackground = [System.Drawing.Color]::White
    }

    # Initialize global variables
    $script:LoginResult = $false

    # Main form setup
    $form = [System.Windows.Forms.Form]::new()
    $form.Text = 'VMware Management System'
    $form.Size = [System.Drawing.Size]::new(800, 800)
    $form.BackColor = $theme.Background
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false

    # Main container panel with shadow effect
    $container = [System.Windows.Forms.Panel]::new()
    $container.Size = [System.Drawing.Size]::new(400, 400)
    $container.Location = [System.Drawing.Point]::new(($form.ClientSize.Width - $container.Width) / 2, 200)
    $container.BackColor = $theme.CardBackground
    $container.BorderStyle = 'None'
    $container.Margin = [System.Windows.Forms.Padding]::new(10)
    $form.Controls.Add($container)

    # Add subtle shadow effect
    $shadow = [System.Windows.Forms.Panel]::new()
    $shadow.Size = [System.Drawing.Size]::new($container.Width + 6, $container.Height + 6)
    $shadow.Location = [System.Drawing.Point]::new($container.Left - 3, $container.Top - 3)
    $shadow.BackColor = [System.Drawing.Color]::FromArgb(30, 0, 0, 0)
    $shadow.SendToBack()
    $form.Controls.Add($shadow)

    # Application logo
    $logo = [System.Windows.Forms.PictureBox]::new()
    $logo.Size = [System.Drawing.Size]::new(300, 190)
    $logo.Location = [System.Drawing.Point]::new(($form.Width - $logo.Width) / 2, 15)
    try {
        $logo.Image = [System.Drawing.Image]::FromFile("$PSScriptRoot\..\Images\login.png")
    } catch {
        # Handle missing logo image gracefully
    }
    $logo.SizeMode = 'Zoom'
    $form.Controls.Add($logo)

    # Login header
    $lblHeader = [System.Windows.Forms.Label]::new()
    $lblHeader.Text = 'Sign In'
    $lblHeader.Font = [System.Drawing.Font]::new('Segoe UI', 20, [System.Drawing.FontStyle]::Bold)
    $lblHeader.ForeColor = $theme.Primary
    $lblHeader.Location = [System.Drawing.Point]::new(($container.Width - $lblHeader.PreferredWidth) / 2, 30)
    $lblHeader.AutoSize = $true
    $container.Controls.Add($lblHeader)

    # Input field styling
    $fieldStyle = @{
        Font = [System.Drawing.Font]::new('Segoe UI', 11)
        BorderStyle = 'FixedSingle'
        BackColor = [System.Drawing.Color]::White
        ForeColor = $theme.TextPrimary
    }

    $labelStyle = @{
        Font = [System.Drawing.Font]::new('Segoe UI', 10)
        ForeColor = $theme.TextSecondary
        AutoSize = $true
    }

    # Username Field
    $lblUser = [System.Windows.Forms.Label]::new()
    $lblUser.Text = 'Username'
    $lblUser.Location = [System.Drawing.Point]::new(40, 100)

    foreach ($prop in $labelStyle.GetEnumerator()) {
        $lblUser.$($prop.Key) = $prop.Value
    }

    $container.Controls.Add($lblUser)

    $txtUser = [System.Windows.Forms.TextBox]::new()
    $txtUser.Location = [System.Drawing.Point]::new(40, 125)
    $txtUser.Size = [System.Drawing.Size]::new(340, 35)

    foreach ($prop in $fieldStyle.GetEnumerator()) {
        $txtUser.$($prop.Key) = $prop.Value
    }

    $container.Controls.Add($txtUser)

    # Password Field
    $lblPass = [System.Windows.Forms.Label]::new()
    $lblPass.Text = 'Password'
    $lblPass.Location = [System.Drawing.Point]::new(40, 180)

    foreach ($prop in $labelStyle.GetEnumerator()) {
        $lblPass.$($prop.Key) = $prop.Value
    }

    $container.Controls.Add($lblPass)

    $txtPass = [System.Windows.Forms.TextBox]::new()
    $txtPass.Location = [System.Drawing.Point]::new(40, 205)
    $txtPass.Size = [System.Drawing.Size]::new(340, 35)
    $txtPass.UseSystemPasswordChar = $true

    foreach ($prop in $fieldStyle.GetEnumerator()) {
        $txtPass.$($prop.Key) = $prop.Value
    }

    $container.Controls.Add($txtPass)

    # Remember Me Checkbox
    $chkRemember = [System.Windows.Forms.CheckBox]::new()
    $chkRemember.Text = 'Remember credentials'
    $chkRemember.Font = [System.Drawing.Font]::new('Segoe UI', 10)
    $chkRemember.ForeColor = $theme.TextSecondary
    $chkRemember.Location = [System.Drawing.Point]::new(40, 260)
    $chkRemember.AutoSize = $true
    $container.Controls.Add($chkRemember)

    # Action Buttons
    $buttonStyle = @{
        Font = [System.Drawing.Font]::new('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)
        Size = [System.Drawing.Size]::new(150, 40)
        FlatStyle = 'Flat'
        FlatAppearance = @{
            BorderSize = 0
            MouseOverBackColor = [System.Drawing.Color]::FromArgb(230, 230, 230)
        }
    }

    # Login Button
    $btnLogin = [System.Windows.Forms.Button]::new()
    $btnLogin.Text = 'LOGIN'
    $btnLogin.Location = [System.Drawing.Point]::new(40, 310)
    $btnLogin.BackColor = $theme.Primary
    $btnLogin.ForeColor = [System.Drawing.Color]::White

    foreach ($prop in $buttonStyle.GetEnumerator()) {
        if ($prop.Key -eq 'FlatAppearance') {
            foreach ($subProp in $prop.Value.GetEnumerator()) {
                $btnLogin.FlatAppearance.$($subProp.Key) = $subProp.Value
            }
        } else {
            $btnLogin.$($prop.Key) = $prop.Value
        }
    }

    $form.AcceptButton = $btnLogin
    $container.Controls.Add($btnLogin)

    # Cancel Button
    $btnCancel = [System.Windows.Forms.Button]::new()
    $btnCancel.Text = 'CANCEL'
    $btnCancel.Location = [System.Drawing.Point]::new(230, 310)
    $btnCancel.BackColor = [System.Drawing.Color]::FromArgb(230, 230, 230)
    $btnCancel.ForeColor = $theme.TextPrimary

    foreach ($prop in $buttonStyle.GetEnumerator()) {
        if ($prop.Key -eq 'FlatAppearance') {
            foreach ($subProp in $prop.Value.GetEnumerator()) {
                $btnCancel.FlatAppearance.$($subProp.Key) = $subProp.Value
            }
        } else {
            $btnCancel.$($prop.Key) = $prop.Value
        }
    }

    $form.CancelButton = $btnCancel
    $container.Controls.Add($btnCancel)

    # Continue Offline Button
    $btnOffline = [System.Windows.Forms.Button]::new()
    $btnOffline.Text = 'CONTINUE OFFLINE'
    $btnOffline.Font = [System.Drawing.Font]::new('Segoe UI', 10)
    $btnOffline.Size = [System.Drawing.Size]::new(340, 35)
    $btnOffline.Location = [System.Drawing.Point]::new(40, 370)
    $btnOffline.FlatStyle = 'Flat'
    $btnOffline.FlatAppearance.BorderSize = 1
    $btnOffline.FlatAppearance.BorderColor = $theme.Primary
    $btnOffline.BackColor = [System.Drawing.Color]::White
    $btnOffline.ForeColor = $theme.Primary
    $btnOffline.Visible = $false
    $container.Controls.Add($btnOffline)

    # Status Label
    $lblStatus = [System.Windows.Forms.Label]::new()
    $lblStatus.Text = ''
    $lblStatus.Size = [System.Drawing.Size]::new($container.Width - 80, 40)
    $lblStatus.Location = [System.Drawing.Point]::new(40, 420)
    $lblStatus.TextAlign = [System.Windows.Forms.HorizontalAlignment]::Center
    $lblStatus.Font = [System.Drawing.Font]::new('Segoe UI', 10)
    $container.Controls.Add($lblStatus)

    # Load remembered credentials
    $credPath = "$env:APPDATA\VMwareManagement\credentials.xml"
    
    if (Test-Path $credPath) {
        try {
            $secureString = Import-Clixml -Path $credPath
            $psCred = New-Object System.Management.Automation.PSCredential('dummy', $secureString)
            $txtUser.Text = $psCred.GetNetworkCredential().UserName
            $txtPass.Text = $psCred.GetNetworkCredential().Password
            $chkRemember.Checked = $true
        } catch {
            Write-Warning "Credential load failed: $_"
            $lblStatus.Text = "Warning: Could not load saved credentials"
            $lblStatus.ForeColor = $theme.Warning
        }
    }

    # Login handler
    $btnLogin.Add_Click({
        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        $lblStatus.Text = 'Authenticating...'
        $lblStatus.ForeColor = $theme.TextSecondary
        $form.Refresh()

        try {
            $securePwd = ConvertTo-SecureString $txtPass.Text -AsPlainText -Force
            $psCred = New-Object System.Management.Automation.PSCredential($txtUser.Text, $securePwd)

            # Visual feedback during connection
            $btnLogin.Text = 'CONNECTING...'
            $btnLogin.Refresh()

            $viConnection = Connect-VIServer -Server $global:VMwareConfig.Server -Credential $psCred -ErrorAction Stop

            # Update global state
            $global:VMwareConfig.Connection = $viConnection
            $global:VMwareConfig.User = $psCred.UserName
            $global:IsLoggedIn = $true

            # Handle credential persistence
            if ($chkRemember.Checked) {
                $folder = Split-Path $credPath -Parent
                if (-not (Test-Path $folder)) {
                    New-Item -ItemType Directory -Path $folder -Force | Out-Null
                }
                $securePwd | Export-Clixml -Path $credPath -Force
            } elseif (Test-Path $credPath) {
                Remove-Item $credPath -ErrorAction SilentlyContinue
            }

            # Update connection model
            [VMServerConnection]::GetInstance().SetConnection($viConnection)
            [VMServerConnection]::GetInstance().SetCredentials($psCred)

            $script:LoginResult = $true
            $form.Close()
        } catch {
            $lblStatus.Text = "Login failed: $($_.Exception.Message)"
            $lblStatus.ForeColor = $theme.Error
            $btnOffline.Visible = $true
            $container.Height = 460
            $form.Height = 710
            $btnLogin.Text = 'LOGIN'
        } finally {
            $form.Cursor = [System.Windows.Forms.Cursors]::Default
        }
    })

    # Continue offline handler
    $btnOffline.Add_Click({
        $global:VMwareConfig.OfflineMode = $true
        $global:IsLoggedIn = $false
        $script:LoginResult = $true
        $form.Close()
    })

    # Cancel handler
    $btnCancel.Add_Click({
        $script:LoginResult = $false
        $form.Close()
    })

    # Form shown event for animations
    $form.Add_Shown({
        $form.Opacity = 0
        while ($form.Opacity -lt 1) {
            $form.Opacity += 0.05
            [System.Threading.Thread]::Sleep(10)
            $form.Refresh()
        }
    })

    # Show the form and return the result
    $result = $form.ShowDialog()
    $form.Dispose()
    return $script:LoginResult
}
