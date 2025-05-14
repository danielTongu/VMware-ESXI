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
    $credPath = "$env:APPDATA\VMwareManagement\credentials.xml"

    # Create the login form
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "VMware Management System - Login"
    $form.Size = New-Object System.Drawing.Size(1100, 800)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.BackColor = [System.Drawing.Color]::DarkGray
    $form.TopMost = $true

    # Logo
    $logo = New-Object System.Windows.Forms.PictureBox
    $logo.Location = New-Object System.Drawing.Point(425, 50)
    $logo.Size = New-Object System.Drawing.Size(250, 200)
    $logo.SizeMode = "Zoom"
    try {
        $logo.Image = [System.Drawing.Image]::FromFile("$PSScriptRoot\..\images\login.png")
    } catch {
        Write-Warning "Failed to load login image from $PSScriptRoot\..\images\login.png"
    }
    $form.Controls.Add($logo)

    # Email
    $lblEmail = New-Object System.Windows.Forms.Label
    $lblEmail.Text = "Email:"
    $lblEmail.Location = New-Object System.Drawing.Point(400, 250)
    $lblEmail.AutoSize = $true
    $lblEmail.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $form.Controls.Add($lblEmail)

    $txtEmail = New-Object System.Windows.Forms.TextBox
    $txtEmail.Location = New-Object System.Drawing.Point(400, 275)
    $txtEmail.Width = 300
    $txtEmail.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $form.Controls.Add($txtEmail)

    # Password
    $lblPass = New-Object System.Windows.Forms.Label
    $lblPass.Text = "Password:"
    $lblPass.Location = New-Object System.Drawing.Point(400, 320)
    $lblPass.AutoSize = $true
    $lblPass.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $form.Controls.Add($lblPass)

    $txtPass = New-Object System.Windows.Forms.TextBox
    $txtPass.Location = New-Object System.Drawing.Point(400, 345)
    $txtPass.Width = 300
    $txtPass.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $txtPass.UseSystemPasswordChar = $true
    $form.Controls.Add($txtPass)

    # Remember Me
    $chkRemember = New-Object System.Windows.Forms.CheckBox
    $chkRemember.Text = "Remember my credentials"
    $chkRemember.Location = New-Object System.Drawing.Point(400, 380)
    $chkRemember.AutoSize = $true
    $form.Controls.Add($chkRemember)

    # Status
    $lblStatus = New-Object System.Windows.Forms.Label
    $lblStatus.Location = New-Object System.Drawing.Point(400, 420)
    $lblStatus.Size = New-Object System.Drawing.Size(500, 30)
    $lblStatus.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Italic)
    $form.Controls.Add($lblStatus)

    # Buttons
    $btnLogin = New-Object System.Windows.Forms.Button
    $btnLogin.Text = "Sign In"
    $btnLogin.Location = New-Object System.Drawing.Point(430, 470)
    $btnLogin.Size = New-Object System.Drawing.Size(100, 30)
    $btnLogin.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $form.Controls.Add($btnLogin)

    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = "Cancel"
    $btnCancel.Location = New-Object System.Drawing.Point(570, 470)
    $btnCancel.Size = New-Object System.Drawing.Size(100, 30)
    $btnCancel.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $form.Controls.Add($btnCancel)

    $btnOffline = New-Object System.Windows.Forms.Button
    $btnOffline.Text = "Continue Offline"
    $btnOffline.Location = New-Object System.Drawing.Point(475, 510)
    $btnOffline.Size = New-Object System.Drawing.Size(150, 30)
    $btnOffline.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $btnOffline.BackColor = [System.Drawing.Color]::LightGray
    $btnOffline.Visible = $false
    $form.Controls.Add($btnOffline)

    # Load remembered credentials
    if (Test-Path $credPath) {
        try {
            $psCred = Import-Clixml -Path $credPath
            $txtEmail.Text = $psCred.GetNetworkCredential().UserName
            $txtPass.Text  = $psCred.GetNetworkCredential().Password
            $chkRemember.Checked = $true
        } catch {
            Write-Warning "Failed to load credentials: $_"
        }
    }

    # Login handler
    $btnLogin.Add_Click({
        # Validate input
        if ([string]::IsNullOrWhiteSpace($txtEmail.Text) -or [string]::IsNullOrWhiteSpace($txtPass.Text)) {
            $lblStatus.Text = "Please enter both email and password."
            $lblStatus.ForeColor = [System.Drawing.Color]::Red
            return
        }
    
        if (-not $global:VMwareConfig.Server) {
            $lblStatus.Text = "VMware server address is not configured."
            $lblStatus.ForeColor = [System.Drawing.Color]::Red
            return
        }
    
        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        $lblStatus.Text = "Connecting..."
        $lblStatus.ForeColor = [System.Drawing.Color]::Blue
        $form.Refresh()
    
        try {
            $securePwd = ConvertTo-SecureString $txtPass.Text -AsPlainText -Force
            $psCred = New-Object System.Management.Automation.PSCredential($txtEmail.Text, $securePwd)    
            $viConnection = Connect-VIServer -Server $global:VMwareConfig.Server -Credential $psCred -ErrorAction Stop
            $global:VMwareConfig.Connection = $viConnection
            $global:VMwareConfig.User = $psCred.GetNetworkCredential().UserName
            $global:IsLoggedIn = $true
    
            if ($chkRemember.Checked) {
                $folder = Split-Path $credPath -Parent
                if (-not (Test-Path $folder)) { New-Item -ItemType Directory -Path $folder | Out-Null }
                $psCred | Export-Clixml -Path $credPath -Force
            } elseif (Test-Path $credPath) {
                Remove-Item $credPath -ErrorAction SilentlyContinue
            }
    
            [VMServerConnection]::GetInstance().SetCredentials($psCred)
            $script:LoginResult = $true
            $form.Close()
        }
        catch {
            $lblStatus.Text = "Login failed: $($_.Exception.Message)"
            $lblStatus.ForeColor = [System.Drawing.Color]::Red
            $btnOffline.Visible = $true
        }
        finally {
            $form.Cursor = [System.Windows.Forms.Cursors]::Default
        }
    })
    
    $btnCancel.Add_Click({
        $script:LoginResult = $false
        $form.Close()
    })

    $btnOffline.Add_Click({
        $global:VMwareConfig.OfflineMode = $true
        $global:IsLoggedIn = $false
        $script:LoginResult = $true
        $form.Close()
    })

    $form.ShowDialog() | Out-Null
    return $script:LoginResult
}

# Call the login view
Show-LoginView
