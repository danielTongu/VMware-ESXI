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

    $script:LoginResult = $false
    $form = [System.Windows.Forms.Form]::new()
    $form.Text             = 'VMware Management System - Login'
    $form.Size             = [System.Drawing.Size]::new(1100, 800)
    $form.BackColor        = [System.Drawing.Color]::DarkGray
    $form.StartPosition    = 'CenterScreen'
    $form.FormBorderStyle  = 'FixedDialog'
    $form.MaximizeBox      = $false
    $form.MinimizeBox      = $false
    # -- Logo --
    $logo = [System.Windows.Forms.PictureBox]::new()
    $logo.Size = [System.Drawing.Size]::new(250, 270)
    $logo.Location = [System.Drawing.Point]::new(($form.Width - $logo.Width)/2, 20)
    try { $logo.Image = [System.Drawing.Image]::FromFile("$PSScriptRoot\..\Images\login.png") } catch {}
    $logo.SizeMode = 'Zoom'
    $form.Controls.Add($logo)

    # Main container panel
    $container = [System.Windows.Forms.Panel]::new()
    $container.Size = [System.Drawing.Size]::new(450, 400)
    $container.Location = [System.Drawing.Point]::new(($form.ClientSize.Width - $container.Width)/2, ($form.ClientSize.Height - $container.Height)/2)
    #$container.BackColor = [System.Drawing.Color]::White
    $container.BorderStyle = 'FixedSingle'
    $form.Controls.Add($container)

   

    # -- Username --
    $lblUser = [System.Windows.Forms.Label]::new()
    $lblUser.Text = 'Username:'
    $lblUser.Location = [System.Drawing.Point]::new(50, 100)
    $lblUser.AutoSize = $true
    $lblUser.Font = [System.Drawing.Font]::new('Segoe UI', 12)
    
    $txtUser = [System.Windows.Forms.TextBox]::new()
    $txtUser.Location = [System.Drawing.Point]::new(50, 125)
    $txtUser.Size = [System.Drawing.Size]::new(350, 30)
    $txtUser.Font = [System.Drawing.Font]::new('Segoe UI', 12)
    
    $container.Controls.AddRange(@($lblUser, $txtUser))

    # -- Password --
    $lblPass = [System.Windows.Forms.Label]::new()
    $lblPass.Text = 'Password:'
    $lblPass.Location = [System.Drawing.Point]::new(50, 165)
    $lblPass.AutoSize = $true
    $lblPass.Font = [System.Drawing.Font]::new('Segoe UI', 12)

    $txtPass = [System.Windows.Forms.TextBox]::new()
    $txtPass.Location = [System.Drawing.Point]::new(50, 190)
    $txtPass.Size = [System.Drawing.Size]::new(350, 30)
    $txtPass.Font = [System.Drawing.Font]::new('Segoe UI', 12)
    $txtPass.UseSystemPasswordChar = $true

    $container.Controls.AddRange(@($lblPass, $txtPass))

    # -- Remember Me --
    $chkRemember = [System.Windows.Forms.CheckBox]::new()
    $chkRemember.Text = 'Remember my credentials'
    $chkRemember.Location = [System.Drawing.Point]::new(50, 230)
    $chkRemember.AutoSize = $true
    $chkRemember.Font = [System.Drawing.Font]::new('Segoe UI', 12)  # Added size 12 font
    $container.Controls.Add($chkRemember)

    # -- Login and Cancel Buttons (left and right) --
    $btnLogin = [System.Windows.Forms.Button]::new()
    $btnLogin.Text = 'Login'
    $btnLogin.Size = [System.Drawing.Size]::new(100, 35)
    $btnLogin.Location = [System.Drawing.Point]::new(50, 270)
    $btnLogin.Font = [System.Drawing.Font]::new('Segoe UI', 12, [System.Drawing.FontStyle]::Bold)
    $form.AcceptButton = $btnLogin
    
    $btnCancel = [System.Windows.Forms.Button]::new()
    $btnCancel.Text = 'Cancel'
    $btnCancel.Size = [System.Drawing.Size]::new(100, 35)
    $btnCancel.Location = [System.Drawing.Point]::new(300, 270)
    $btnCancel.Font = [System.Drawing.Font]::new('Segoe UI', 12)
    $form.CancelButton = $btnCancel
    
    $container.Controls.AddRange(@($btnLogin, $btnCancel))

    # -- Continue Offline Button (bottom center) --
    $btnOffline = [System.Windows.Forms.Button]::new()
    $btnOffline.Text = 'Continue Offline'
    $btnOffline.Size = [System.Drawing.Size]::new(150, 35)
    $btnOffline.Location = [System.Drawing.Point]::new(($container.Width - $btnOffline.Width)/2, 330)
    $btnOffline.Font = [System.Drawing.Font]::new('Segoe UI', 12)
    $btnOffline.BackColor = [System.Drawing.Color]::LightGray
    $btnOffline.Visible = $false
    $container.Controls.Add($btnOffline)

    # -- Status Label --
    $lblStatus = [System.Windows.Forms.Label]::new()
    $lblStatus.Text = ''
    $lblStatus.Size = [System.Drawing.Size]::new($form.Width - 100, 20)  # Set fixed width for centering
    $lblStatus.Location = [System.Drawing.Point]::new(($form.Width - $lblStatus.Width)/2, $form.ClientSize.Height - 100)
    $lblStatus.TextAlign = [System.Windows.Forms.HorizontalAlignment]::Center  # Center align text
    $lblStatus.Font = [System.Drawing.Font]::new('Segoe UI', 10, [System.Drawing.FontStyle]::Italic)
    $form.Controls.Add($lblStatus)

    # -- Load remembered creds --
    $credPath = "$env:APPDATA\VMwareManagement\credentials.xml"
    if (Test-Path $credPath) {
        try {
            $secureString = Import-Clixml -Path $credPath
            $psCred = New-Object System.Management.Automation.PSCredential('dummy', $secureString)
            $txtUser.Text = $psCred.GetNetworkCredential().UserName
            $txtPass.Text = $psCred.GetNetworkCredential().Password
            $chkRemember.Checked = $true
        } catch { Write-Warning "Credential load failed: $_" }
    }

    # -- Login handler --
    $btnLogin.Add_Click({
        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        $lblStatus.Text = 'Connecting...'; 
        $lblStatus.ForeColor = [System.Drawing.Color]::Blue; 
        $form.Refresh()

        try {
            $securePwd = ConvertTo-SecureString $txtPass.Text -AsPlainText -Force
            $psCred = New-Object System.Management.Automation.PSCredential($txtUser.Text, $securePwd)
            # Capture the VI connection
            $viConnection = Connect-VIServer -Server $global:VMwareConfig.Server -Credential $psCred -ErrorAction Stop
            # Persist to global state
            $global:VMwareConfig.Connection = $viConnection
            $global:VMwareConfig.User = $psCred.UserName
            $global:IsLoggedIn = $true
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
        }
        catch {
            $lblStatus.Text = "Login failed: $($_.Exception.Message)"; 
            $lblStatus.ForeColor = [System.Drawing.Color]::Red
            $btnOffline.Visible = $true
            $container.Height = 420
            $form.Refresh()
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
    $form.Dispose()
    
    return $script:LoginResult
}