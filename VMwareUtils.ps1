<#
.SYNOPSIS
    VMware Management Utility Functions
.DESCRIPTION
    Contains helper functions for VMware PowerCLI management
#>

# Load required .NET assemblies for UI
Add-Type -AssemblyName System.Windows.Forms   # For Windows Forms UI
Add-Type -AssemblyName System.Drawing         # For drawing UI elements
Add-Type -AssemblyName Microsoft.VisualBasic  # For additional dialogs


function Show-LoadingDialog {
    <#
    .SYNOPSIS
        Shows a loading dialog with a marquee progress bar.
    .DESCRIPTION
        Displays a modal Windows Form with a customizable message and a marquee progress bar to indicate a loading or processing state.
    #>

    param(
        [string]$Message = "Loading...",
        [string]$Title = "Loading"
    )
    
    # Create the form
    $form = New-Object System.Windows.Forms.Form
    $form.Text = $Title
    $form.Size = New-Object System.Drawing.Size(400, 150)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $form.MinimizeBox = $false
    $form.MaximizeBox = $false
    $form.ControlBox = $false

    # Add a label for the message
    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Message
    $label.Location = New-Object System.Drawing.Point(20, 20)
    $label.Width = 360
    $label.Height = 40
    $form.Controls.Add($label)

    # Add a marquee progress bar
    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Style = [System.Windows.Forms.ProgressBarStyle]::Marquee
    $progressBar.Location = New-Object System.Drawing.Point(20, 70)
    $progressBar.Width = 360
    $form.Controls.Add($progressBar)

    # Show the form
    $form.Add_Shown({ $form.Activate() })
    $form.Show() | Out-Null
    $form.Refresh()

    return $form
}




function Show-Message {
    <#
    .SYNOPSIS
        Shows a message box with customizable title, message, icon, and buttons.
    .DESCRIPTION
        Displays a Windows Forms message box with the specified title, message, icon type (Info, Question, Warning, Error), and button options (OK, YesNo).
    #>

    param(
        [string]$Title,
        [string]$Message,
        [ValidateSet("Info","Question","Warning","Error")][string]$Type = "Info",
        [ValidateSet("OK","YesNo")][string]$Buttons = "OK"
    )

    # Set the icon based on type
    $icon = [System.Windows.Forms.MessageBoxIcon]::Information
    switch ($Type) {
        "Question" { $icon = [System.Windows.Forms.MessageBoxIcon]::Question }
        "Warning"  { $icon = [System.Windows.Forms.MessageBoxIcon]::Warning }
        "Error"    { $icon = [System.Windows.Forms.MessageBoxIcon]::Error }
    }

    # Set the button type
    $buttonsEnum = [System.Windows.Forms.MessageBoxButtons]::OK
    if ($Buttons -eq "YesNo") {
        $buttonsEnum = [System.Windows.Forms.MessageBoxButtons]::YesNo
    }

    # Show the message box
    return [System.Windows.Forms.MessageBox]::Show($Message, $Title, $buttonsEnum, $icon)
}



function Repair-PowerCLIInstallation {
    <#
    .SYNOPSIS
        Repairs the VMware PowerCLI installation.
    .DESCRIPTION
        Removes existing VMware PowerCLI modules and reinstalls them to ensure a clean and functional setup.
    #>

    param(
        [bool]$ForceReinstall = $false
    )

    # Show loading dialog
    $loadingForm = Show-LoadingDialog -Message "Repairing VMware PowerCLI installation..." -Title "Repairing"
    $success = $false

    try {
        # Step 1: Remove existing modules
        Get-Module -Name VMware.* -ErrorAction SilentlyContinue | Remove-Module -Force
        $installed = Get-Module -Name VMware.* -ListAvailable -ErrorAction SilentlyContinue
        if ($installed -or $ForceReinstall) {
            $installed | Uninstall-Module -Force -ErrorAction SilentlyContinue
        }

        # Step 2: Install fresh copy
        Install-Module VMware.PowerCLI -Force -AllowClobber -Scope CurrentUser `
            -SkipPublisherCheck -ErrorAction Stop

        # Step 3: Verify installation
        $requiredModules = @(
            "VMware.VimAutomation.Sdk",
            "VMware.VimAutomation.Common",
            "VMware.VimAutomation.Core"
        )

        $missing = $requiredModules | Where-Object {
            -not (Get-Module -ListAvailable $_ -ErrorAction SilentlyContinue)
        }

        if ($missing) {
            throw "Missing modules after installation: $($missing -join ', ')"
        }

        $success = $true
    }
    catch {
        # Show error message with manual repair steps
        Show-Message -Title "Repair Failed" -Message @"
Failed to repair installation:
$($_.Exception.Message)

Manual repair steps:
1. Open PowerShell as Administrator
2. Run: Install-PackageProvider NuGet -Force
3. Run: Install-Module PowerShellGet -Force -AllowClobber
4. Run: Get-Module VMware.* -ListAvailable | Uninstall-Module -Force
5. Run: Install-Module VMware.PowerCLI -Force -AllowClobber -Scope CurrentUser
"@ -Type Error
    }
    finally {
        # Close loading dialog
        $loadingForm.Close()
    }

    return $success
}



function Initialize-PowerCLI {
    <#
    .SYNOPSIS
        Initializes PowerCLI by ensuring essential modules are loaded or installed.
    .DESCRIPTION
        Checks for required VMware PowerCLI modules, loads them if available, or prompts the user to install them if missing.
    #>

    # Define ONLY the essential modules we need
    $essentialModules = @(
        "VMware.VimAutomation.Sdk",    # Required foundation
        "VMware.VimAutomation.Core"    # Core management functionality
    )

    try {
        # First check if essential modules are already loaded
        $loadedCount = ($essentialModules | Where-Object {
            Get-Module $_ -ErrorAction SilentlyContinue
        }).Count
        
        if ($loadedCount -eq $essentialModules.Count) {
            return $true
        }

        # Check if modules are available (but not loaded)
        $availableCount = ($essentialModules | Where-Object {
            Get-Module -ListAvailable $_ -ErrorAction SilentlyContinue
        }).Count

        # If all essential modules are available, load them
        if ($availableCount -eq $essentialModules.Count) {
            foreach ($module in $essentialModules) {
                Import-Module $module -ErrorAction Stop
            }
            Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false | Out-Null
            return $true
        }

        # Prompt for installation if modules are missing
        $installChoice = [System.Windows.Forms.MessageBox]::Show(
            "Essential VMware modules are missing. Install only the required components?",
            "Install Required",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )

        if ($installChoice -eq "Yes") {
            # Show loading dialog
            $loadingForm = Show-LoadingDialog -Message "Installing essential VMware components..." -Title "Installing"
            
            try {
                # Install ONLY the required modules
                Install-Module VMware.VimAutomation.Sdk -Force -AllowClobber -Scope CurrentUser -SkipPublisherCheck
                Install-Module VMware.VimAutomation.Core -Force -AllowClobber -Scope CurrentUser -SkipPublisherCheck

                # Verify installation
                foreach ($module in $essentialModules) {
                    Import-Module $module -ErrorAction Stop
                }
                return $true
            }
            catch {
                # Show error message if installation fails
                [System.Windows.Forms.MessageBox]::Show(
                    "Failed to install essential modules: $($_.Exception.Message)",
                    "Installation Error",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Error
                )
                return $false
            }
            finally {
                # Close loading dialog
                if ($loadingForm) { $loadingForm.Close() }
            }
        }
        return $false
    }
    catch {
        # Show error message if initialization fails
        [System.Windows.Forms.MessageBox]::Show(
            "Module initialization failed: $($_.Exception.Message)",
            "Initialization Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        return $false
    }
}



function Connect-VMwareServer {
    <#
    .SYNOPSIS
        Connects to a VMware server using provided credentials.
    .DESCRIPTION
        Establishes a connection to a specified VMware vCenter or ESXi server using the given username and password.
    #>

    param(
        [string]$Server,
        [string]$Username,
        [SecureString]$Password
    )

    try {
        # Create credential object directly from SecureString password
        $credential = New-Object System.Management.Automation.PSCredential ($Username, $Password)
        
        # Connect to the VMware server
        $connection = Connect-VIServer -Server $Server -Credential $credential -ErrorAction Stop
        return $connection
    }
    catch {
        # Show error message if connection fails
        Show-Message -Title "Connection Error" -Message "Failed to connect to VMware server: $($_.Exception.Message)" -Type Error
        return $null
    }
}



function Disconnect-VMwareServer {
    <#
    .SYNOPSIS
        Disconnects from a VMware server.
    .DESCRIPTION
        Safely disconnects an active VMware PowerCLI server connection.
    #>

    param(
        [object]$Connection
    )

    if ($Connection) {
        try {
            # Disconnect from the server without confirmation
            Disconnect-VIServer -Server $Connection -Confirm:$false -ErrorAction SilentlyContinue
            return $true
        }
        catch {
            # Show warning if disconnection fails
            Write-Host "Disconnection warning: $_"
            return $false
        }
    }
    return $true
}


