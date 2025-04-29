Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Create the main window
$form = New-Object System.Windows.Forms.Form
$form.Text = "VMware Sample GUI"
$form.Size = New-Object System.Drawing.Size(1100, 800)
$form.StartPosition = "CenterScreen"

# Create the menu panel (left side)
$menuPanel = New-Object System.Windows.Forms.Panel
$menuPanel.Size = New-Object System.Drawing.Size(200, 600)
$menuPanel.BackColor = [System.Drawing.Color]::LightGray
$menuPanel.Dock = "Left"
$form.Controls.Add($menuPanel)

# Create a panel for content display (right side)
$contentPanel = New-Object System.Windows.Forms.Panel
$contentPanel.Size = New-Object System.Drawing.Size(900, 800)
$contentPanel.Location = New-Object System.Drawing.Point(200, 0)
$contentPanel.BackColor = [System.Drawing.Color]::White
$form.Controls.Add($contentPanel)

# Create a label to show the content title
$contentLabel = New-Object System.Windows.Forms.Label
$contentLabel.Text = "Welcome!"
$contentLabel.Font = New-Object System.Drawing.Font("Arial", 20, [System.Drawing.FontStyle]::Bold)
$contentLabel.AutoSize = $true
$contentLabel.Location = New-Object System.Drawing.Point(30, 30)
$contentPanel.Controls.Add($contentLabel)

# --- CLASS SECTION CONTROLS ---

$newClassButton = New-Object System.Windows.Forms.Button
$newClassButton.Text = "New Class"
$newClassButton.Size = New-Object System.Drawing.Size(150, 30)
$newClassButton.Location = New-Object System.Drawing.Point(30, 700)
$newClassButton.Visible = $false
$contentPanel.Controls.Add($newClassButton)

$saveClassButton = New-Object System.Windows.Forms.Button
$saveClassButton.Text = "Save"
$saveClassButton.Size = New-Object System.Drawing.Size(150, 30)
$saveClassButton.Location = New-Object System.Drawing.Point(190, 700)
$saveClassButton.Visible = $false
$contentPanel.Controls.Add($saveClassButton)

# Section labels for "New Class"
$basicLabel = New-Object System.Windows.Forms.Label
$basicLabel.Text = "Basic Info"
$basicLabel.Font = New-Object System.Drawing.Font("Arial", 14, [System.Drawing.FontStyle]::Bold)
$basicLabel.Location = New-Object System.Drawing.Point(30, 100)
$basicLabel.AutoSize = $true
$basicLabel.Visible = $false
$contentPanel.Controls.Add($basicLabel)

$vmConfigLabel = New-Object System.Windows.Forms.Label
$vmConfigLabel.Text = "VM Configuration"
$vmConfigLabel.Font = New-Object System.Drawing.Font("Arial", 14, [System.Drawing.FontStyle]::Bold)
$vmConfigLabel.Location = New-Object System.Drawing.Point(30, 250)
$vmConfigLabel.AutoSize = $true
$vmConfigLabel.Visible = $false
$contentPanel.Controls.Add($vmConfigLabel)

$advancedLabel = New-Object System.Windows.Forms.Label
$advancedLabel.Text = "Advanced Configuration"
$advancedLabel.Font = New-Object System.Drawing.Font("Arial", 14, [System.Drawing.FontStyle]::Bold)
$advancedLabel.Location = New-Object System.Drawing.Point(30, 400)
$advancedLabel.AutoSize = $true
$advancedLabel.Visible = $false
$contentPanel.Controls.Add($advancedLabel)

# --- VIRTUAL MACHINE SECTION BUTTONS ---

$refreshVMsButton = New-Object System.Windows.Forms.Button
$refreshVMsButton.Text = "Refresh"
$refreshVMsButton.Size = New-Object System.Drawing.Size(150, 30)
$refreshVMsButton.Location = New-Object System.Drawing.Point(540, 700)
$refreshVMsButton.Visible = $false
$contentPanel.Controls.Add($refreshVMsButton)

$powerOnAllButton = New-Object System.Windows.Forms.Button
$powerOnAllButton.Text = "Power On All"
$powerOnAllButton.Size = New-Object System.Drawing.Size(150, 30)
$powerOnAllButton.Location = New-Object System.Drawing.Point(30, 700)
$powerOnAllButton.Visible = $false
$contentPanel.Controls.Add($powerOnAllButton)

$powerOffAllButton = New-Object System.Windows.Forms.Button
$powerOffAllButton.Text = "Power Off All"
$powerOffAllButton.Size = New-Object System.Drawing.Size(150, 30)
$powerOffAllButton.Location = New-Object System.Drawing.Point(200, 700)
$powerOffAllButton.Visible = $false
$contentPanel.Controls.Add($powerOffAllButton)

$restartAllButton = New-Object System.Windows.Forms.Button
$restartAllButton.Text = "Restart All"
$restartAllButton.Size = New-Object System.Drawing.Size(150, 30)
$restartAllButton.Location = New-Object System.Drawing.Point(370, 700)
$restartAllButton.Visible = $false
$contentPanel.Controls.Add($restartAllButton)

# --- LOGS SECTION BUTTONS ---

$deleteOrphanFilesButton = New-Object System.Windows.Forms.Button
$deleteOrphanFilesButton.Text = "Delete Orphan Files"
$deleteOrphanFilesButton.Size = New-Object System.Drawing.Size(150, 30)
$deleteOrphanFilesButton.Location = New-Object System.Drawing.Point(30, 700)
$deleteOrphanFilesButton.Visible = $false
$contentPanel.Controls.Add($deleteOrphanFilesButton)

$retrieveUserLogsButton = New-Object System.Windows.Forms.Button
$retrieveUserLogsButton.Text = "Retrieve User Logs"
$retrieveUserLogsButton.Size = New-Object System.Drawing.Size(150, 30)
$retrieveUserLogsButton.Location = New-Object System.Drawing.Point(200, 700)
$retrieveUserLogsButton.Visible = $false
$contentPanel.Controls.Add($retrieveUserLogsButton)

$showActiveVMsButton = New-Object System.Windows.Forms.Button
$showActiveVMsButton.Text = "Show Active VMs"
$showActiveVMsButton.Size = New-Object System.Drawing.Size(150, 30)
$showActiveVMsButton.Location = New-Object System.Drawing.Point(370, 700)
$showActiveVMsButton.Visible = $false
$contentPanel.Controls.Add($showActiveVMsButton)

# Function to clear/hide section-specific controls
function Hide-AllExtras {
    # Hide class section
    $newClassButton.Visible = $false
    $saveClassButton.Visible = $false
    $basicLabel.Visible = $false
    $vmConfigLabel.Visible = $false
    $advancedLabel.Visible = $false

    # Hide VM section
    $refreshVMsButton.Visible = $false
    $powerOnAllButton.Visible = $false
    $powerOffAllButton.Visible = $false
    $restartAllButton.Visible = $false

    # Hide Logs Section
    $deleteOrphanFilesButton.Visible = $false
    $retrieveUserLogsButton.Visible = $false
    $showActiveVMsButton.Visible = $false
}

# Function to update the content area
function Set-Content {
    param ([string]$title)

    $contentLabel.Text = $title
    Hide-AllExtras

    if ($title -eq "Classes") {
        $newClassButton.Visible = $true
        $saveClassButton.Visible = $true
    } elseif ($title -eq "Virtual Machines") {
        $refreshVMsButton.Visible = $true
        $powerOnAllButton.Visible = $true
        $powerOffAllButton.Visible = $true
        $restartAllButton.Visible = $true
    } elseif ($title -eq "Logs") {
        $deleteOrphanFilesButton.Visible = $true
        $retrieveUserLogsButton.Visible = $true
        $showActiveVMsButton.Visible = $true
    }
}

# Add New Class buttons
$newClassButton.Add_Click({
    $basicLabel.Visible = $true
    $vmConfigLabel.Visible = $true
    $advancedLabel.Visible = $true
})

# Function to add a menu button
function Add-MenuButton {
    param (
        [string]$text,
        [int]$top,
        [ScriptBlock]$onClick
    )
    $button = New-Object System.Windows.Forms.Button
    $button.Text = $text
    $button.Size = New-Object System.Drawing.Size(180, 40)
    $button.Location = New-Object System.Drawing.Point(10, $top)
    $button.Add_Click($onClick)
    $menuPanel.Controls.Add($button)
}

# Add the menu buttons
Add-MenuButton "Dashboard" 20 { Set-Content "Dashboard" }
Add-MenuButton "Classes" 70 { Set-Content "Classes" }
Add-MenuButton "Virtual Machines" 120 { Set-Content "Virtual Machines" }
Add-MenuButton "Logs" 170 { Set-Content "Logs" }
Add-MenuButton "Exit" 700 { $form.Close() }

# Run the form
[System.Windows.Forms.Application]::Run($form)
