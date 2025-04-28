Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Create the main window
$form = New-Object System.Windows.Forms.Form
$form.Text = "VMware Class Manager"
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
# Tree View for class/student/VM
$classTreeView = New-Object System.Windows.Forms.TreeView
$classTreeView.Size = New-Object System.Drawing.Size(950, 550)
$classTreeView.Location = New-Object System.Drawing.Point(30, 100)
$classTreeView.Font = New-Object System.Drawing.Font("Segoe UI", 12)
$classTreeView.Visible = $false
$contentPanel.Controls.Add($classTreeView)

# Section labels (when creating a new class)
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

# New Class Button
$newClassButton = New-Object System.Windows.Forms.Button
$newClassButton.Text = "New Class"
$newClassButton.Size = New-Object System.Drawing.Size(150, 35)
$newClassButton.Location = New-Object System.Drawing.Point(30, 700)
$newClassButton.Visible = $false
$newClassButton.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$newClassButton.ForeColor = [System.Drawing.Color]::White 
$newClassButton.BackColor = [System.Drawing.Color]::RoyalBlue
$contentPanel.Controls.Add($newClassButton)

# Delete Class Button
$deleteClassButton = New-Object System.Windows.Forms.Button
$deleteClassButton.Text = "Delete Class"
$deleteClassButton.Size = New-Object System.Drawing.Size(150, 35)
$deleteClassButton.Location = New-Object System.Drawing.Point(190, 700)
$deleteClassButton.Visible = $false
$deleteClassButton.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$deleteClassButton.ForeColor = [System.Drawing.Color]::White 
$deleteClassButton.BackColor = [System.Drawing.Color]::RoyalBlue
$contentPanel.Controls.Add($deleteClassButton)

# --- VIRTUAL MACHINE SECTION BUTTONS ---
# Refresh Button
$refreshVMsButton = New-Object System.Windows.Forms.Button
$refreshVMsButton.Text = "Refresh"
$refreshVMsButton.Size = New-Object System.Drawing.Size(150, 35)
$refreshVMsButton.Location = New-Object System.Drawing.Point(540, 700)
$refreshVMsButton.Visible = $false
$contentPanel.Controls.Add($refreshVMsButton)

# PowerOn Button
$powerOnAllButton = New-Object System.Windows.Forms.Button
$powerOnAllButton.Text = "Power On All"
$powerOnAllButton.Size = New-Object System.Drawing.Size(150, 35)
$powerOnAllButton.Location = New-Object System.Drawing.Point(30, 700)
$powerOnAllButton.Visible = $false
$contentPanel.Controls.Add($powerOnAllButton)

# PowerOff Button
$powerOffAllButton = New-Object System.Windows.Forms.Button
$powerOffAllButton.Text = "Power Off All"
$powerOffAllButton.Size = New-Object System.Drawing.Size(150, 35)
$powerOffAllButton.Location = New-Object System.Drawing.Point(200, 700)
$powerOffAllButton.Visible = $false
$contentPanel.Controls.Add($powerOffAllButton)

# Restart Button
$restartAllButton = New-Object System.Windows.Forms.Button
$restartAllButton.Text = "Restart All"
$restartAllButton.Size = New-Object System.Drawing.Size(150, 35)
$restartAllButton.Location = New-Object System.Drawing.Point(370, 700)
$restartAllButton.Visible = $false
$contentPanel.Controls.Add($restartAllButton)

# Hardcoded sample data for visualization
function Initialize-SampleData {
    $sampleClass = $classTreeView.Nodes.Add("CS101")
    $sampleStudent = $sampleClass.Nodes.Add("John Doe")
    $sampleStudent.Nodes.AddRange(@("Windows VM", "Linux VM", "Ubuntu VM"))
    
    $sampleClass = $classTreeView.Nodes.Add("CS201")
    $sampleStudent = $sampleClass.Nodes.Add("Jane Doe")
    $sampleStudent.Nodes.AddRange(@("Windows VM", "Ubuntu VM"))
}

# Delete Dialog (Displays confirmation dialog for deleting a class)
function Show-DeleteClassDialog {
    $deleteForm = New-Object System.Windows.Forms.Form
    $deleteForm.Text = "Delete Class"
    $deleteForm.Size = New-Object System.Drawing.Size(300, 150)
    $deleteForm.StartPosition = "CenterParent"

    $label = New-Object System.Windows.Forms.Label
    $label.Text = "Select Class to Delete:"
    $label.Location = New-Object System.Drawing.Point(10, 20)
    $label.Size = New-Object System.Drawing.Size(200, 20)
    $deleteForm.Controls.Add($label)

    $comboBox = New-Object System.Windows.Forms.ComboBox
    $comboBox.Location = New-Object System.Drawing.Point(10, 50)
    $comboBox.Size = New-Object System.Drawing.Size(260, 30)
    $comboBox.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    
	# Populate dropdown with the existing classes
    foreach ($node in $classTreeView.Nodes) {
        $comboBox.Items.Add($node.Text) | Out-Null
    }
    
    $deleteForm.Controls.Add($comboBox)

	# Confirmation Button
    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Text = "Delete"
    $okButton.Location = New-Object System.Drawing.Point(100, 80)
    $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $deleteForm.AcceptButton = $okButton
    $deleteForm.Controls.Add($okButton)
	
	# Confirmation Dialog
    $result = $deleteForm.ShowDialog()
    
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        $selectedClass = $classTreeView.Nodes | Where-Object { $_.Text -eq $comboBox.Text }
        if ($selectedClass) {
            $classTreeView.Nodes.Remove($selectedClass)
        }
    }
}

# Function to clear/hide section-specific controls
function Hide-AllExtras {
    $classTreeView.Visible = $false
    $newClassButton.Visible = $false
    $deleteClassButton.Visible = $false
    $basicLabel.Visible = $false
    $vmConfigLabel.Visible = $false
    $advancedLabel.Visible = $false
	
	# Hide VM Section
    $refreshVMsButton.Visible = $false
    $powerOnAllButton.Visible = $false
    $powerOffAllButton.Visible = $false
    $restartAllButton.Visible = $false
}


# Function to update the content area
function Set-Content {
    param ([string]$title)
    $contentLabel.Text = $title
    Hide-AllExtras

    if ($title -eq "Classes") {
        $classTreeView.Visible = $true
        $newClassButton.Visible = $true
        $deleteClassButton.Visible = $true
        Initialize-SampleData
    }
    elseif ($title -eq "Virtual Machines") {
        $refreshVMsButton.Visible = $true
        $powerOnAllButton.Visible = $true
        $powerOffAllButton.Visible = $true
        $restartAllButton.Visible = $true
    }
}

# New Clas
$newClassButton.Add_Click({
    $className = [Microsoft.VisualBasic.Interaction]::InputBox("Enter class name:", "New Class")
    if ($className) {
        $classTreeView.Nodes.Add($className) | Out-Null
        $basicLabel.Visible = $true
        $vmConfigLabel.Visible = $true
        $advancedLabel.Visible = $true
    }
})

$deleteClassButton.Add_Click({
    Show-DeleteClassDialog
})

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