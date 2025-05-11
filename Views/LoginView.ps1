
# Import required .NET assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing


<#
.SYNOPSIS
    Displays a login form for VMware Management System.
.DESCRIPTION
    This script creates a login form using Windows Forms, allowing users to enter their VMware credentials.
    It includes options for saving credentials and handling offline mode.
.PARAMETER None
    This script does not take any parameters. It is designed to be called directly from the main application.

#>
function Show-LoginView {
    [CmdletBinding()]
    param()

    # Initialize global variables
    $script:LoginResult = $false

    # Main form setup
    $mainForm = [System.Windows.Forms.Form]::new()
    $mainForm.Text = 'VMware Management System'
    $mainForm.StartPosition = 'CenterScreen'
    $mainForm.TopMost = $true
    $mainForm.Size = [System.Drawing.Size]::new(800, 200)
    $mainForm.BackColor = $global:theme.Background
    $mainForm.StartPosition = 'CenterScreen'
    $mainForm.FormBorderStyle = 'FixedDialog'
    $mainForm.MaximizeBox = $false
    $mainForm.MinimizeBox = $false

    # Main container panel with shadow effect
    $container = [System.Windows.Forms.Panel]::new()
    $container.Size = [System.Drawing.Size]::new(400, 400)
    $container.Location = [System.Drawing.Point]::new(($mainForm.ClientSize.Width - $container.Width) / 2, 135)
    $container.BackColor = $global:theme.CardBackground
    $container.BorderStyle = 'FixedSingle'
    $mainForm.Controls.Add($container)

    # Add subtle shadow effect
    $shadow = [System.Windows.Forms.Panel]::new()
    $shadow.Size = [System.Drawing.Size]::new($container.Width + 6, $container.Height + 6)
    $shadow.Location = [System.Drawing.Point]::new($container.Left - 3, $container.Top - 3)
    $shadow.BackColor = [System.Drawing.Color]::FromArgb(30, 0, 0, 0)
    $shadow.SendToBack()
    $mainForm.Controls.Add($shadow)

    # Application logo
    $logo = [System.Windows.Forms.PictureBox]::new()
    $logo.Size = [System.Drawing.Size]::new(130, 130)
    $logo.Location = [System.Drawing.Point]::new(($mainForm.Width - $logo.Width) / 2, 0)
    try {
        $logo.Image = [System.Drawing.Image]::FromFile("$PSScriptRoot\..\Images\login.png")
    } catch {
        # Handle missing logo image gracefully
    }
    $logo.SizeMode = 'Zoom'
    $mainForm.Controls.Add($logo)

    # Login header
    $lblHeader = [System.Windows.Forms.Label]::new()
    $lblHeader.Text = 'Sign In'
    $lblHeader.Font = [System.Drawing.Font]::new('Segoe UI', 20, [System.Drawing.FontStyle]::Bold)
    $lblHeader.ForeColor = $global:theme.Primary  # Burgundy color
    $lblHeader.Location = [System.Drawing.Point]::new(($container.Width - $lblHeader.PreferredWidth) / 2, 5)
    $lblHeader.AutoSize = $true
    $container.Controls.Add($lblHeader)

    # Input field styling
    $fieldStyle = @{
        Font = [System.Drawing.Font]::new('Segoe UI', 11)
        BorderStyle = 'FixedSingle'
        BackColor = [System.Drawing.Color]::White
        ForeColor = $global:theme.TextPrimary
    }

    $labelStyle = @{
        Font = [System.Drawing.Font]::new('Segoe UI', 10)
        ForeColor = $global:theme.TextSecondary
        AutoSize = $true
    }

    # Username Field
    $lblUser = [System.Windows.Forms.Label]::new()
    $lblUser.Text = 'Username'
    $lblUser.Location = [System.Drawing.Point]::new(40, 50)

    foreach ($prop in $labelStyle.GetEnumerator()) {
        $lblUser.$($prop.Key) = $prop.Value
    }

    $container.Controls.Add($lblUser)

    $txtUser = [System.Windows.Forms.TextBox]::new()
    $txtUser.Location = [System.Drawing.Point]::new(40, 74)
    $txtUser.Size = [System.Drawing.Size]::new(340, 35)

    foreach ($prop in $fieldStyle.GetEnumerator()) {
        $txtUser.$($prop.Key) = $prop.Value
    }

    $container.Controls.Add($txtUser)

    # Password Field
    $lblPass = [System.Windows.Forms.Label]::new()
    $lblPass.Text = 'Password'
    $lblPass.Location = [System.Drawing.Point]::new(40, 110)

    foreach ($prop in $labelStyle.GetEnumerator()) {
        $lblPass.$($prop.Key) = $prop.Value
    }

    $container.Controls.Add($lblPass)

    $txtPass = [System.Windows.Forms.TextBox]::new()
    $txtPass.Location = [System.Drawing.Point]::new(40, 134)
    $txtPass.PasswordChar = '*'
    $txtPass.MaxLength = 100
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
    $chkRemember.ForeColor = $global:theme.TextSecondary
    $chkRemember.Location = [System.Drawing.Point]::new(40, 180)
    $chkRemember.Size = [System.Drawing.Size]::new(200, 20)
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

    # Login Button - Burgundy color
    $btnLogin = [System.Windows.Forms.Button]::new()
    $btnLogin.Text = 'LOGIN'
    $btnLogin.Location = [System.Drawing.Point]::new(40, 220)
    $btnLogin.BackColor = $global:theme.Primary  # Burgundy
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

    $mainForm.AcceptButton = $btnLogin
    $container.Controls.Add($btnLogin)

    # Cancel Button - Light gray
    $btnCancel = [System.Windows.Forms.Button]::new()
    $btnCancel.Text = 'CANCEL'
    $btnCancel.Location = [System.Drawing.Point]::new(230, 220)
    $btnCancel.BackColor = [System.Drawing.Color]::FromArgb(230, 230, 230)
    $btnCancel.ForeColor = $global:theme.TextPrimary

    foreach ($prop in $buttonStyle.GetEnumerator()) {
        if ($prop.Key -eq 'FlatAppearance') {
            foreach ($subProp in $prop.Value.GetEnumerator()) {
                $btnCancel.FlatAppearance.$($subProp.Key) = $subProp.Value
            }
        } else {
            $btnCancel.$($prop.Key) = $prop.Value
        }
    }

    $mainForm.CancelButton = $btnCancel
    $container.Controls.Add($btnCancel)

    # Status Label
    $lblStatus = [System.Windows.Forms.Label]::new()
    $lblStatus.Text = ''
    $lblStatus.Size = [System.Drawing.Size]::new($container.Width - 80, 40)
    $lblStatus.Location = [System.Drawing.Point]::new(40, 310)
    $lblStatus.TextAlign = [System.Windows.Forms.HorizontalAlignment]::Center
    $lblStatus.Font = [System.Drawing.Font]::new('Segoe UI', 10)
    $lblStatus.ForeColor = $global:theme.TextSecondary
    $container.Controls.Add($lblStatus)

    # Continue Offline Button - Outlined burgundy
    $btnOffline = [System.Windows.Forms.Button]::new()
    $btnOffline.Text = 'CONTINUE OFFLINE'
    $btnOffline.Font = [System.Drawing.Font]::new('Segoe UI', 10)
    $btnOffline.Size = [System.Drawing.Size]::new(340, 35)
    $btnOffline.Location = [System.Drawing.Point]::new(40, 270)
    $btnOffline.FlatStyle = 'Flat'
    $btnOffline.FlatAppearance.BorderSize = 1
    $btnOffline.FlatAppearance.BorderColor = $global:theme.Primary  # Burgundy border
    $btnOffline.BackColor = [System.Drawing.Color]::White
    $btnOffline.ForeColor = $global:theme.Primary  # Burgundy text
    $btnOffline.Visible = $false
    $container.Controls.Add($btnOffline)

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
            Write-Host "[CREDENTIAL LOAD ERROR] $_" -ForegroundColor Red
            $lblStatus.Text = "Warning: Could not load saved credentials"
            $lblStatus.ForeColor = $global:theme.Warning
        }
    }    

    # Login handler
    $btnLogin.Add_Click({
        $mainForm.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        $lblStatus.Text = 'Authenticating...'
        $mainForm.Refresh()

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
            $mainForm.Close()
        } catch {
            $lblStatus.Text = "Login failed: $($_.Exception.Message)"
            $lblStatus.ForeColor = $global:theme.Error
            $btnOffline.Visible = $true
            $container.Height = $container.GetPreferredSize([System.Drawing.Size]::new(0, 0)).Height + 50
            $mainForm.Height = $mainForm.GetPreferredSize([System.Drawing.Size]::new(0, 0)).Height + 50
            $mainForm.Refresh()
            $btnLogin.Text = 'LOGIN'
        } finally {
            $mainForm.Cursor = [System.Windows.Forms.Cursors]::Default
        }
    })

    # Continue offline handler
    $btnOffline.Add_Click({
        $global:VMwareConfig.OfflineMode = $true
        $global:IsLoggedIn = $false
        $script:LoginResult = $true
        $mainForm.Close()
    })

    # Cancel handler
    $btnCancel.Add_Click({
        $script:LoginResult = $false
        $mainForm.Close()
    })

    # Form shown event for animations
    $mainForm.Add_Shown({
        $mainForm.Opacity = 0
        while ($mainForm.Opacity -lt 1) {
            $mainForm.Opacity += 0.05
            [System.Threading.Thread]::Sleep(10)
            $mainForm.Refresh()
        }
    })

    # Show the form and return the result
    $container.Height = $container.GetPreferredSize([System.Drawing.Size]::new(0, 0)).Height + 50
    $mainForm.Height = $mainForm.GetPreferredSize([System.Drawing.Size]::new(0, 0)).Height + 50
    $mainForm.Refresh()
    $result = $mainForm.ShowDialog()
    $mainForm.Dispose()
    return $script:LoginResult
}
