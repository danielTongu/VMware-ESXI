<#
.SYNOPSIS
    Displays a WinForms login dialog and returns whether authentication succeeded.

.DESCRIPTION
    Presents Email and Password fields with Sign In / Cancel buttons.
    Validates credentials directly within this script (no AuthModel required).
    Returns $true on success, $false on failure or cancel.

.EXAMPLE
    if (Show-LoginView) {
        "Login succeeded" | Write-Host
    } else {
        "Login failed or cancelled" | Write-Host
    }
#>

function Show-LoginView {
    [CmdletBinding()]
    param()

    # Load WinForms assemblies
    Add-Type -AssemblyName 'System.Windows.Forms'
    Add-Type -AssemblyName 'System.Drawing'

    # -----------------------------
    # Create the login form window
    # -----------------------------
    $form = New-Object System.Windows.Forms.Form
    $form.Text            = 'Please Sign In'
    $form.Size            = [System.Drawing.Size]::new(400, 300)
    $form.StartPosition   = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox     = $false
    $form.MinimizeBox     = $false
    $form.Topmost         = $true

    # -----------------------------
    # Email label and textbox
    # -----------------------------
    $lblEmail = New-Object System.Windows.Forms.Label
    $lblEmail.Text     = 'Email:'
    $lblEmail.Location = [System.Drawing.Point]::new(50, 50)
    $lblEmail.AutoSize = $true
    $lblEmail.Font     = [System.Drawing.Font]::new('Segoe UI', 10)
    $form.Controls.Add($lblEmail)

    $txtEmail = New-Object System.Windows.Forms.TextBox
    $txtEmail.Location = [System.Drawing.Point]::new(50, 75)
    $txtEmail.Width    = 300
    $txtEmail.Font     = [System.Drawing.Font]::new('Segoe UI', 10)
    $form.Controls.Add($txtEmail)

    # -----------------------------
    # Password label and textbox
    # -----------------------------
    $lblPass = New-Object System.Windows.Forms.Label
    $lblPass.Text     = 'Password:'
    $lblPass.Location = [System.Drawing.Point]::new(50, 115)
    $lblPass.AutoSize = $true
    $lblPass.Font     = [System.Drawing.Font]::new('Segoe UI', 10)
    $form.Controls.Add($lblPass)

    $txtPass = New-Object System.Windows.Forms.TextBox
    $txtPass.Location              = [System.Drawing.Point]::new(50, 140)
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
    $btnOK.Location = [System.Drawing.Point]::new(80, 200)
    $btnOK.Font     = [System.Drawing.Font]::new('Segoe UI', 10)
    $form.Controls.Add($btnOK)

    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text     = 'Cancel'
    $btnCancel.Size     = [System.Drawing.Size]::new(100, 30)
    $btnCancel.Location = [System.Drawing.Point]::new(220, 200)
    $btnCancel.Font     = [System.Drawing.Font]::new('Segoe UI', 10)
    $form.Controls.Add($btnCancel)

    # -----------------------------
    # Result flag
    # -----------------------------
    $script:Success = $false

    # -----------------------------
    # Sign In click handler
    # -----------------------------
    $btnOK.Add_Click({
        $email    = $txtEmail.Text.Trim()
        $password = $txtPass.Text

        # Simple hardcoded validation
        if ($email -eq 'admin@example.com' -and $password -eq 'admin123') {
            $script:Success = $true
            $form.Close()
        } else {
            [System.Windows.Forms.MessageBox]::Show(
                'Invalid email or password.',
                'Login Failed',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            ) | Out-Null
        }
    })

    # Cancel click handler
    $btnCancel.Add_Click({
        $form.Close()
    })

    # -----------------------------
    # Show the form modally
    # -----------------------------
    $form.ShowDialog() | Out-Null
    return $script:Success
}

Export-ModuleMember -Function Show-LoginView