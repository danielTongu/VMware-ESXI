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

    $script:LoginResult = $false
    $form = [System.Windows.Forms.Form]::new()
    $form.Text             = 'VMware Management System - Login'
    $form.Size             = [System.Drawing.Size]::new(450,380)
    $form.StartPosition    = 'CenterScreen'
    $form.FormBorderStyle  = 'FixedDialog'
    $form.MaximizeBox      = $false
    $form.MinimizeBox      = $false

<<<<<<< HEAD
    # -----------------------------
    # Create the login form window
    # -----------------------------
    $form = New-Object System.Windows.Forms.Form
    $form.Text            = 'Please Sign In'
    $form.Size            = [System.Drawing.Size]::new(1100, 800)
    $loginForm.BackColor  = [System.Drawing.Color]::DarkGray
    $form.StartPosition   = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox     = $false
    $form.MinimizeBox     = $false
    $form.Topmost         = $true

    # -----------------------------
    # Add cwu logo image
    # -----------------------------
    $logo = New-Object System.Windows.Forms.PictureBox
    $logo.Location = New-Object System.Drawing.Point(430, 50)
    $logo.Size = New-Object System.Drawing.Size(250, 200)
    $logo.SizeMode = "Zoom"
    $logo.Image = [System.Drawing.Image]::FromFile("$PSScriptRoot\login.png")

    $form.Controls.Add($logo)

    # -----------------------------
    # Email label and textbox
    # -----------------------------
    $lblEmail = New-Object System.Windows.Forms.Label
    $lblEmail.Text     = 'Email:'
    $lblEmail.Location = [System.Drawing.Point]::new(460, 250)
    $lblEmail.AutoSize = $true
    $lblEmail.Font     = [System.Drawing.Font]::new('Segoe UI', 10)

    $form.Controls.Add($lblEmail)

    $txtEmail = New-Object System.Windows.Forms.TextBox
    $txtEmail.Location = [System.Drawing.Point]::new(460, 275)
    $txtEmail.Width    = 300
    $txtEmail.Font     = [System.Drawing.Font]::new('Segoe UI', 10)

    $form.Controls.Add($txtEmail)

    # -----------------------------
    # Password label and textbox
    # -----------------------------
    $lblPass = New-Object System.Windows.Forms.Label
    $lblPass.Text     = 'Password:'
    $lblPass.Location = [System.Drawing.Point]::new(460, 320)
    $lblPass.AutoSize = $true
    $lblPass.Font     = [System.Drawing.Font]::new('Segoe UI', 10)

    $form.Controls.Add($lblPass)

    $txtPass = New-Object System.Windows.Forms.TextBox
    $txtPass.Location              = [System.Drawing.Point]::new(460, 320)
    $txtPass.Width                 = 300
    $txtPass.UseSystemPasswordChar = $true
    $txtPass.Font                  = [System.Drawing.Font]::new('Segoe UI', 10)

    $form.Controls.Add($txtPass)

    # -----------------------------
    # Sign In and Cancel buttons
    # -----------------------------
    $btnOK = New-Object System.Windows.Forms.Button
    $btnOK.Text     = 'Sign In'
    $btnOK.Size     = [System.Drawing.Size]::new(100, 30)
    $btnOK.Location = [System.Drawing.Point]::new(505, 390)
    $btnOK.Font     = [System.Drawing.Font]::new('Segoe UI', 10)

    $form.Controls.Add($btnOK)

    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text     = 'Cancel'
    $btnCancel.Size     = [System.Drawing.Size]::new(100, 30)
    $btnCancel.Location = [System.Drawing.Point]::new(645, 390)
    $btnCancel.Font     = [System.Drawing.Font]::new('Segoe UI', 10)

    $form.Controls.Add($btnCancel)
=======
    # -- Logo --
    $logo = [System.Windows.Forms.PictureBox]::new()
    $logo.Size     = [System.Drawing.Size]::new(200,60)
    $logo.Location = [System.Drawing.Point]::new(($form.ClientSize.Width - $logo.Width)/2,20)
    try { $logo.Image = [System.Drawing.Image]::FromFile("$PSScriptRoot\..\Images\logo.png") } catch {}
    $logo.SizeMode = 'Zoom'
    $form.Controls.Add($logo)

    # -- Username --
    $lblUser = [System.Windows.Forms.Label]::new(); $lblUser.Text='Username:'; $lblUser.Location=[System.Drawing.Point]::new(50,100); $lblUser.AutoSize=$true; $lblUser.Font=[System.Drawing.Font]::new('Segoe UI',10)
    $txtUser = [System.Windows.Forms.TextBox]::new(); $txtUser.Location=[System.Drawing.Point]::new(50,125); $txtUser.Size=[System.Drawing.Size]::new(350,30); $txtUser.Font=[System.Drawing.Font]::new('Segoe UI',10)
    $form.Controls.AddRange(@($lblUser,$txtUser))

    # -- Password --
    $lblPass = [System.Windows.Forms.Label]::new(); $lblPass.Text='Password:'; $lblPass.Location=[System.Drawing.Point]::new(50,165); $lblPass.AutoSize=$true; $lblPass.Font=[System.Drawing.Font]::new('Segoe UI',10)
    $txtPass = [System.Windows.Forms.TextBox]::new(); $txtPass.Location=[System.Drawing.Point]::new(50,190); $txtPass.Size=[System.Drawing.Size]::new(350,30); $txtPass.Font=[System.Drawing.Font]::new('Segoe UI',10); $txtPass.UseSystemPasswordChar=$true
    $form.Controls.AddRange(@($lblPass,$txtPass))

    # -- Remember Me --
    $chkRemember = [System.Windows.Forms.CheckBox]::new(); $chkRemember.Text='Remember my credentials'; $chkRemember.Location=[System.Drawing.Point]::new(50,230); $chkRemember.AutoSize=$true
    $form.Controls.Add($chkRemember)

    # -- Buttons --
    $btnLogin = [System.Windows.Forms.Button]::new(); $btnLogin.Text='Login'; $btnLogin.Size=[System.Drawing.Size]::new(100,35); $btnLogin.Location=[System.Drawing.Point]::new(50,270); $btnLogin.Font=[System.Drawing.Font]::new('Segoe UI',10,[System.Drawing.FontStyle]::Bold); $form.AcceptButton=$btnLogin
    $btnCancel= [System.Windows.Forms.Button]::new(); $btnCancel.Text='Cancel';$btnCancel.Size=[System.Drawing.Size]::new(100,35); $btnCancel.Location=[System.Drawing.Point]::new(200,270); $btnCancel.Font=[System.Drawing.Font]::new('Segoe UI',10); $form.CancelButton=$btnCancel
    $btnOffline=[System.Windows.Forms.Button]::new(); $btnOffline.Text='Continue Offline';$btnOffline.Size=[System.Drawing.Size]::new(150,35); $btnOffline.Location=[System.Drawing.Point]::new(50,315); $btnOffline.Font=[System.Drawing.Font]::new('Segoe UI',10); $btnOffline.BackColor=[System.Drawing.Color]::LightGray; $btnOffline.Visible=$false
    $form.Controls.AddRange(@($btnLogin,$btnCancel,$btnOffline))

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
        } catch { Write-Warning "Credential load failed: $_" }
    }
>>>>>>> 0c3c925 (view updated)

    # -- Login handler --
    $btnLogin.Add_Click({
        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        $lblStatus.Text = 'Connecting...'; $lblStatus.ForeColor=[System.Drawing.Color]::Blue; $form.Refresh()
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
        }
        catch {
            $lblStatus.Text = "Login failed: $($_.Exception.Message)"; $lblStatus.ForeColor=[System.Drawing.Color]::Red
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