# Written By Jesus Rodriguez
# 4/27/2025
# The purpose of this script is to provide a login functionality.

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Create the login form
$loginForm = New-Object System.Windows.Forms.Form
$loginForm.Text = "Login"
$loginForm.Size = New-Object System.Drawing.Size(1100, 800)
$loginForm.StartPosition = "CenterScreen"

# Add cwu logo image
$logo = New-Object System.Windows.Forms.PictureBox
$logo.Location = New-Object System.Drawing.Point(430, 50)
$logo.Size = New-Object System.Drawing.Size(250, 200)
$logo.SizeMode = "Zoom"
$logo.Image = [System.Drawing.Image]::FromFile("$PSScriptRoot\login.png")
$loginForm.Controls.Add($logo)

$loginForm.BackColor = [System.Drawing.Color]::DarkGray

# Create the email and textbox label
$emailLabel = New-Object System.Windows.Forms.Label
$emailLabel.Text = "Email:"
$emailLabel.Location = New-Object System.Drawing.Point(460, 250)
$emailLabel.AutoSize = $true
$emailLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$loginForm.Controls.Add($emailLabel)

$emailTextBox = New-Object System.Windows.Forms.TextBox
$emailTextBox.Location = New-Object System.Drawing.Point(460, 275)
$emailTextBox.Width = 200
$emailTextBox.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$loginForm.Controls.Add($emailTextBox)

# Create the password and textbox label
$passwordLabel = New-Object System.Windows.Forms.Label
$passwordLabel.Text = "Password:"
$passwordLabel.Location = New-Object System.Drawing.Point(460, 320)
$passwordLabel.AutoSize = $true
$passwordLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$loginForm.Controls.Add($passwordLabel)

$passwordTextBox = New-Object System.Windows.Forms.TextBox
$passwordTextBox.Location = New-Object System.Drawing.Point(460, 345)
$passwordTextBox.Width = 200
$passwordTextBox.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$passwordTextBox.UseSystemPasswordChar = $true
$loginForm.Controls.Add($passwordTextBox)

# Create the login button
$loginButton = New-Object System.Windows.Forms.Button
$loginButton.Text = "Sign in"
$loginButton.Location = New-Object System.Drawing.Point(505, 390)
$loginButton.Width = 100
$loginButton.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$loginForm.Controls.Add($loginButton)

function Auth-User {
    param (
        [string]$Email,
        [string]$Password
    )

    if ($Email -eq "admin@cwu.edu" -and $Password -eq "Wildcatway") {
        return $true
    } else {
        return $false
    }
}

$loginButton.Add_Click({
    $email = $emailTextBox.Text
    $password = $passwordTextBox.Text

    if (Auth-User -Email $email -Password $password) {
        $loginForm.Hide()
        Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$PSScriptRoot\powershell-GUI.ps1`""
        $loginForm.Close()

    } else {
        [System.Windows.Forms.MessageBox]::Show("Invalid email or password.", "Login Failed", 'OK', 'Error')
    }
})

# Run the form
$loginForm.ShowDialog()