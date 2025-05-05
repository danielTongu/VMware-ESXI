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

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Show-LoginView {
    [CmdletBinding()]
    param()

    # Initialize global variables
    $script:LoginResult = $false
    $form = [System.Windows.Forms.Form]::new()
    $form.Text = 'VMware Management System'
    $form.Size = [System.Drawing.Size]::new(800, 800)
    $form.BackColor = $global:theme.Background
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false

    # Main container panel with shadow effect
    $container = [System.Windows.Forms.Panel]::new()
    $container.Size = [System.Drawing.Size]::new(400, 400)
    $container.Location = [System.Drawing.Point]::new(($form.ClientSize.Width - $container.Width) / 2, 200)
    $container.BackColor = $global:theme.CardBackground
    $container.BorderStyle = 'FixedSingle'
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
    $logo.Size     = [System.Drawing.Size]::new(200,60)
    $logo.Location = [System.Drawing.Point]::new(($form.ClientSize.Width - $logo.Width)/2,20)
    try { $logo.Image = [System.Drawing.Image]::FromFile("$PSScriptRoot\..\Images\logo.png") } catch {}
    $logo.SizeMode = 'Zoom'
    $form.Controls.Add($logo)

    # Login header
    $lblHeader = [System.Windows.Forms.Label]::new()
    $lblHeader.Text = 'Sign In'
    $lblHeader.Font = [System.Drawing.Font]::new('Segoe UI', 20, [System.Drawing.FontStyle]::Bold)
    $lblHeader.ForeColor = $global:theme.Primary  # Burgundy color
    $lblHeader.Location = [System.Drawing.Point]::new(($container.Width - $lblHeader.PreferredWidth) / 2, 30)
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
    $chkRemember.ForeColor = $global:theme.TextSecondary
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

    # Login Button - Burgundy color
    $btnLogin = [System.Windows.Forms.Button]::new()
    $btnLogin.Text = 'LOGIN'
    $btnLogin.Location = [System.Drawing.Point]::new(40, 310)
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

    $form.AcceptButton = $btnLogin
    $container.Controls.Add($btnLogin)

    # Cancel Button - Light gray
    $btnCancel = [System.Windows.Forms.Button]::new()
    $btnCancel.Text = 'CANCEL'
    $btnCancel.Location = [System.Drawing.Point]::new(230, 310)
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

    $form.CancelButton = $btnCancel
    $container.Controls.Add($btnCancel)

    # Continue Offline Button - Outlined burgundy
    $btnOffline = [System.Windows.Forms.Button]::new()
    $btnOffline.Text = 'CONTINUE OFFLINE'
    $btnOffline.Font = [System.Drawing.Font]::new('Segoe UI', 10)
    $btnOffline.Size = [System.Drawing.Size]::new(340, 35)
    $btnOffline.Location = [System.Drawing.Point]::new(40, 370)
    $btnOffline.FlatStyle = 'Flat'
    $btnOffline.FlatAppearance.BorderSize = 1
    $btnOffline.FlatAppearance.BorderColor = $global:theme.Primary  # Burgundy border
    $btnOffline.BackColor = [System.Drawing.Color]::White
    $btnOffline.ForeColor = $global:theme.Primary  # Burgundy text
    $btnOffline.Visible = $false
    $container.Controls.Add($btnOffline)

    # -- Status Label --
    $lblStatus=[System.Windows.Forms.Label]::new(); $lblStatus.Text=''; $lblStatus.Location=[System.Drawing.Point]::new(50,360); $lblStatus.AutoSize=$true; $lblStatus.Font=[System.Drawing.Font]::new('Segoe UI',9,[System.Drawing.FontStyle]::Italic)
    $form.Controls.Add($lblStatus)

    # -- Load remembered creds --
    $credPath = "$env:APPDATA\VMwareManagement\credentials.xml"
    if (Test-Path $credPath) {
        try {
            $secureString = Import-Clixml -Path $credPath
            $psCred = New-Object System.Management.Automation.PSCredential('dummy',$secureString)
            $txtUser.Text = $psCred.GetNetworkCredential().UserName
            $txtPass.Text = $psCred.GetNetworkCredential().Password
            $chkRemember.Checked = $true
        } catch {
            Write-Warning "Credential load failed: $_"
            $lblStatus.Text = "Warning: Could not load saved credentials"
            $lblStatus.ForeColor = $global:theme.Warning
        }
    }

    # -- Login handler --
    $btnLogin.Add_Click({
        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        $lblStatus.Text = 'Authenticating...'
        $lblStatus.ForeColor = $global:theme.TextSecondary
        $form.Refresh()

        try {
            $securePwd = ConvertTo-SecureString $txtPass.Text -AsPlainText -Force
            $psCred = New-Object System.Management.Automation.PSCredential($txtUser.Text,$securePwd)
            # Capture the VI connection
            $viConnection = Connect-VIServer -Server $global:VMwareConfig.Server -Credential $psCred -ErrorAction Stop
            # Persist to global state
            $global:VMwareConfig.Connection = $viConnection
            $global:VMwareConfig.User       = $psCred.UserName
            $global:IsLoggedIn              = $true
            if ($chkRemember.Checked) {
                $folder = Split-Path $credPath -Parent
                if (-not (Test-Path $folder)) { New-Item -ItemType Directory -Path $folder | Out-Null }
                $securePwd | Export-Clixml -Path $credPath -Force
            } elseif (Test-Path $credPath) {
                Remove-Item $credPath -ErrorAction SilentlyContinue
            }
            # Also inform our singleton model
            [VMServerConnection]::GetInstance().SetConnection($viConnection)
            [VMServerConnection]::GetInstance().SetCredentials($psCred)
            $script:LoginResult = $true
            $form.Close()
        } catch {
            $lblStatus.Text = "Login failed: $($_.Exception.Message)"
            $lblStatus.ForeColor = $global:theme.Error
            $btnOffline.Visible = $true
            $form.Size = [System.Drawing.Size]::new($form.Width,420)
        }
        finally { $form.Cursor = [System.Windows.Forms.Cursors]::Default }
    })

    # -- Continue offline handler --
    $btnOffline.Add_Click({
        $global:VMwareConfig.OfflineMode = $true
        $global:IsLoggedIn = $false
        $script:LoginResult = $true    # proceed into shell in offline mode
        $form.Close()
    })

    # -- Cancel handler --
    $btnCancel.Add_Click({
        $script:LoginResult = $false
        $form.Close()
    })

    $form.ShowDialog() | Out-Null
    return $script:LoginResult
}