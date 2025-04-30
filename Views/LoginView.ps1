<#
Views/LoginView.ps1

.SYNOPSIS
    Displays a WinForms login dialog and returns whether authentication succeeded.

.DESCRIPTION
    Presents Email and Password fields along with Sign In / Cancel buttons.
    Uses AuthModel.ValidateUser to check credentials.
    If the user clicks Cancel or closes the window, returns $false.
    On successful sign-in returns $true.

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

    #------------------------------------------------------------------------
    # 1) Create the form
    #------------------------------------------------------------------------
    $form = New-Object System.Windows.Forms.Form
    $form.Text            = 'Please Sign In'
    $form.Size            = [System.Drawing.Size]::new(400,300)
    $form.StartPosition   = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox     = $false
    $form.MinimizeBox     = $false
    $form.Topmost         = $true

    #------------------------------------------------------------------------
    # 2) Email label & textbox
    #------------------------------------------------------------------------
    $lblEmail = New-Object System.Windows.Forms.Label
    $lblEmail.Text     = 'Email:'
    $lblEmail.Location = [System.Drawing.Point]::new(50,50)
    $lblEmail.AutoSize = $true
    $lblEmail.Font     = [System.Drawing.Font]::new('Segoe UI',10)
    $form.Controls.Add($lblEmail)

    $txtEmail = New-Object System.Windows.Forms.TextBox
    $txtEmail.Location = [System.Drawing.Point]::new(50,75)
    $txtEmail.Width    = 300
    $txtEmail.Font     = [System.Drawing.Font]::new('Segoe UI',10)
    $form.Controls.Add($txtEmail)

    #------------------------------------------------------------------------
    # 3) Password label & textbox
    #------------------------------------------------------------------------
    $lblPass = New-Object System.Windows.Forms.Label
    $lblPass.Text     = 'Password:'
    $lblPass.Location = [System.Drawing.Point]::new(50,115)
    $lblPass.AutoSize = $true
    $lblPass.Font     = [System.Drawing.Font]::new('Segoe UI',10)
    $form.Controls.Add($lblPass)

    $txtPass = New-Object System.Windows.Forms.TextBox
    $txtPass.Location               = [System.Drawing.Point]::new(50,140)
    $txtPass.Width                  = 300
    $txtPass.UseSystemPasswordChar  = $true
    $txtPass.Font                   = [System.Drawing.Font]::new('Segoe UI',10)
    $form.Controls.Add($txtPass)

    #------------------------------------------------------------------------
    # 4) Sign In and Cancel buttons
    #------------------------------------------------------------------------
    $btnOK = New-Object System.Windows.Forms.Button
    $btnOK.Text     = 'Sign In'
    $btnOK.Size     = [System.Drawing.Size]::new(100,30)
    $btnOK.Location = [System.Drawing.Point]::new(80,200)
    $btnOK.Font     = [System.Drawing.Font]::new('Segoe UI',10)
    $form.Controls.Add($btnOK)

    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text     = 'Cancel'
    $btnCancel.Size     = [System.Drawing.Size]::new(100,30)
    $btnCancel.Location = [System.Drawing.Point]::new(220,200)
    $btnCancel.Font     = [System.Drawing.Font]::new('Segoe UI',10)
    $form.Controls.Add($btnCancel)

    #------------------------------------------------------------------------
    # 5) Result flag
    #------------------------------------------------------------------------
    $script:Success = $false

    #------------------------------------------------------------------------
    # 6) Wire up button clicks
    #------------------------------------------------------------------------
    $btnOK.Add_Click({
        if ([AuthModel]::ValidateUser($txtEmail.Text, $txtPass.Text)) {
            $script:Success = $true
            $form.Close()
        }
        else {
            [System.Windows.Forms.MessageBox]::Show(
                'Invalid email or password.',
                'Login Failed',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            ) | Out-Null
        }
    })

    $btnCancel.Add_Click({
        $form.Close()
    })

    #------------------------------------------------------------------------
    # 7) Display dialog
    #------------------------------------------------------------------------
    $form.ShowDialog() | Out-Null

    return $script:Success
}

Export-ModuleMember -Function Show-LoginView