<#
.SYNOPSIS
    Displays a welcome dashboard after successful login.
.DESCRIPTION
    This view summarizes the current vSphere environment:
    - Shows the connected host name.
    - Displays number of total VMs and powered-on VMs.
    - Lists available virtual networks (port groups).

    Must be executed after successful authentication and module import.
#>

# Load required .NET types for building Windows Forms UI
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Import VMware-related functions and classes
# Assumes login has already occurred via LoginView.ps1
Import-Module "$PSScriptRoot\..\VMwareModels.psm1" -ErrorAction Stop

# -------------------------------------------------------------------
# Function: Get-DashboardStats
# Purpose : Gather summary data from vSphere to show on dashboard
# -------------------------------------------------------------------
function Get-DashboardStats {
    <#
    .SYNOPSIS
        Collects VMware environment statistics for display.
    .DESCRIPTION
        Connects to the vSphere server and collects:
        - Host name
        - Total VMs
        - Number of VMs powered on
        - Count of virtual networks (port groups)
    .OUTPUTS
        [PSCustomObject] with Host, TotalVMs, PoweredOn, Networks
    #>

    # Ensure connection to vSphere server
    ConnectTo-VMServer

    # Retrieve host name
    $vmHost = (Get-VMHost).Name

    # Count all virtual machines
    $totalVMs = (Get-VM).Count

    # Count only powered-on virtual machines
    $poweredOnVMs = (Get-VM | Where-Object PowerState -eq 'PoweredOn').Count

    # Count available virtual port groups
    $networks = [VMwareNetwork]::ListNetworks().Count

    # Return structured stats object
    return [PSCustomObject]@{
        Host        = $vmHost
        TotalVMs    = $totalVMs
        PoweredOn   = $poweredOnVMs
        Networks    = $networks
    }
}

# -------------------------------------------------------------------
# Function: Show-DashboardView
# Purpose : Display the welcome dashboard UI using Windows Forms
# -------------------------------------------------------------------
function Show-DashboardView {
    <#
    .SYNOPSIS
        Builds and shows the welcome dashboard window.
    .DESCRIPTION
        Uses Windows Forms to render a graphical summary of VMware stats.
    #>

    # Gather all summary data to display
    $stats = Get-DashboardStats

    # Create the main form
    $form = New-Object Windows.Forms.Form
    $form.Text = "VMware Dashboard"
    $form.Size = New-Object Drawing.Size(400, 300)
    $form.StartPosition = "CenterScreen"

    # Add title label
    $title = New-Object Windows.Forms.Label
    $title.Text = "Welcome to the VMware Management Dashboard"
    $title.Font = New-Object Drawing.Font("Segoe UI", 12, [Drawing.FontStyle]::Bold)
    $title.Size = New-Object Drawing.Size(360, 40)
    $title.Location = New-Object Drawing.Point(20, 20)
    $form.Controls.Add($title)

    # Prepare display content lines from the stats
    $labels = @(
        "Connected Host: $($stats.Host)",
        "Total VMs: $($stats.TotalVMs)",
        "Powered-On VMs: $($stats.PoweredOn)",
        "Available Networks: $($stats.Networks)"
    )

    # Add a label for each stat line
    $y = 80
    foreach ($text in $labels) {
        $label = New-Object Windows.Forms.Label
        $label.Text = $text
        $label.Location = New-Object Drawing.Point(30, $y)
        $label.Size = New-Object Drawing.Size(320, 25)
        $label.Font = New-Object Drawing.Font("Segoe UI", 10)
        $form.Controls.Add($label)
        $y += 30
    }

    # Add an OK button to close the form
    $okButton = New-Object Windows.Forms.Button
    $okButton.Text = "OK"
    $okButton.Size = New-Object Drawing.Size(80, 30)
    $okButton.Location = New-Object Drawing.Point(150, 220)

    # Event handler to close the form when button is clicked
    $okButton.Add_Click({
        $form.Close()
    })

    $form.Controls.Add($okButton)

    # Ensure form appears on top and gains focus
    $form.Topmost = $true
    $form.Add_Shown({ $form.Activate() })

    # Show the form as a modal dialog
    $form.ShowDialog()
}

# -------------------------------------------------------------------
# Start the dashboard view when script is run
# -------------------------------------------------------------------
Show-DashboardView