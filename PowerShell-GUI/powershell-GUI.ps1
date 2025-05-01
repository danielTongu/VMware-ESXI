Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Main window
$form = New-Object System.Windows.Forms.Form
$form.Text = "VMware Sample GUI"
$form.Size = New-Object System.Drawing.Size(1100, 800)
$form.StartPosition = "CenterScreen"

# Panels
$menuPanel = New-Object System.Windows.Forms.Panel
$menuPanel.Size = New-Object System.Drawing.Size(200, 800)
$menuPanel.BackColor = [System.Drawing.Color]::LightGray
$menuPanel.Dock = "Left"
$form.Controls.Add($menuPanel)

$contentPanel = New-Object System.Windows.Forms.Panel
$contentPanel.Size = New-Object System.Drawing.Size(900, 800)
$contentPanel.Location = New-Object System.Drawing.Point(200, 0)
$contentPanel.BackColor = [System.Drawing.Color]::White
$form.Controls.Add($contentPanel)

# Content title
$contentLabel = New-Object System.Windows.Forms.Label
$contentLabel.Text = "Welcome!"
$contentLabel.Font = New-Object System.Drawing.Font("Arial", 20, [System.Drawing.FontStyle]::Bold)
$contentLabel.AutoSize = $true
$contentLabel.Location = New-Object System.Drawing.Point(30, 30)
$contentPanel.Controls.Add($contentLabel)

# Buttons
$newClassButton = New-Object System.Windows.Forms.Button
$newClassButton.Text = "New Class"
$newClassButton.Size = New-Object System.Drawing.Size(150, 30)
$newClassButton.Location = New-Object System.Drawing.Point(30, 700)
$newClassButton.Visible = $false
$contentPanel.Controls.Add($newClassButton)

# Function to show the pop-up window for new class
function Show-NewClassWindow {
    $popup = New-Object System.Windows.Forms.Form
    $popup.Text = "New Class"
    $popup.Size = New-Object System.Drawing.Size(550, 550)
    $popup.StartPosition = "CenterParent"
    $popup.FormBorderStyle = 'FixedDialog'
    $popup.MaximizeBox = $false
    $popup.MinimizeBox = $false

    $tabControl = New-Object System.Windows.Forms.TabControl
    $tabControl.Size = New-Object System.Drawing.Size(510, 420)
    $tabControl.Location = New-Object System.Drawing.Point(10, 10)

    # Basic Tab
    $basicTab = New-Object System.Windows.Forms.TabPage
    $basicTab.Text = "Basic"

    $label1 = New-Object System.Windows.Forms.Label
    $label1.Text = "Class Name"
    $label1.Location = New-Object System.Drawing.Point(10, 20)
    $label1.Size = New-Object System.Drawing.Size(100, 20)
    $basicTab.Controls.Add($label1)

    $classNameBox = New-Object System.Windows.Forms.TextBox
    $classNameBox.Location = New-Object System.Drawing.Point(10, 45)
    $classNameBox.Size = New-Object System.Drawing.Size(470, 20)
    $basicTab.Controls.Add($classNameBox)

    $label2 = New-Object System.Windows.Forms.Label
    $label2.Text = "Student names (Last, First)"
    $label2.Location = New-Object System.Drawing.Point(10, 80)
    $label2.Size = New-Object System.Drawing.Size(300, 20)
    $basicTab.Controls.Add($label2)

    $studentsBox = New-Object System.Windows.Forms.TextBox
    $studentsBox.Location = New-Object System.Drawing.Point(10, 105)
    $studentsBox.Size = New-Object System.Drawing.Size(470, 250)
    $studentsBox.Multiline = $true
    $studentsBox.ScrollBars = "Vertical"
    $basicTab.Controls.Add($studentsBox)

    # VM Configuration Tab
    $vmTab = New-Object System.Windows.Forms.TabPage
    $vmTab.Text = "VM Configuration"

    # Template Label
    $templateLabel = New-Object System.Windows.Forms.Label
    $templateLabel.Text = "Template:"
    $templateLabel.Location = New-Object System.Drawing.Point(10, 20)
    $templateLabel.Size = New-Object System.Drawing.Size(100, 20)
    $vmTab.Controls.Add($templateLabel)

    # Template ComboBox
    $templateBox = New-Object System.Windows.Forms.ComboBox
    $templateBox.Location = New-Object System.Drawing.Point(120, 18)
    $templateBox.Size = New-Object System.Drawing.Size(200, 20)
    $templateBox.DropDownStyle = 'DropDownList'
    $templateBox.Items.Add("Template A") | Out-Null
    $templateBox.Items.Add("Template B") | Out-Null
    $templateBox.SelectedIndex = 0
    $vmTab.Controls.Add($templateBox)

    # Datastore Label
    $datastoreLabel = New-Object System.Windows.Forms.Label
    $datastoreLabel.Text = "Datastore:"
    $datastoreLabel.Location = New-Object System.Drawing.Point(10, 60)
    $datastoreLabel.Size = New-Object System.Drawing.Size(100, 20)
    $vmTab.Controls.Add($datastoreLabel)

    # Datastore ComboBox
    $datastoreBox = New-Object System.Windows.Forms.ComboBox
    $datastoreBox.Location = New-Object System.Drawing.Point(120, 58)
    $datastoreBox.Size = New-Object System.Drawing.Size(200, 20)
    $datastoreBox.DropDownStyle = 'DropDownList'
    $datastoreBox.Items.Add("datstr1") | Out-Null
    $datastoreBox.Items.Add("datstr2") | Out-Null
    $datastoreBox.SelectedIndex = 0
    $vmTab.Controls.Add($datastoreBox)

     # Adapter Label
    $adapterLabel = New-Object System.Windows.Forms.Label
    $adapterLabel.Text = "Adapter:"
    $adapterLabel.Location = New-Object System.Drawing.Point(10, 100)
    $adapterLabel.Size = New-Object System.Drawing.Size(100, 20)
    $vmTab.Controls.Add($adapterLabel)

    # Adapter ComboBox
    $adapterBox = New-Object System.Windows.Forms.ComboBox
    $adapterBox.Location = New-Object System.Drawing.Point(120, 98)
    $adapterBox.Size = New-Object System.Drawing.Size(200, 20)
    $adapterBox.DropDownStyle = 'DropDownList'
    $adapterBox.Items.Add("NAT") | Out-Null
    $adapterBox.SelectedIndex = 0
    $vmTab.Controls.Add($adapterBox)

    # Advanced Tab
    $advTab = New-Object System.Windows.Forms.TabPage
    $advTab.Text = "Advanced"

    $advLabel = New-Object System.Windows.Forms.Label
    $advLabel.Text = "Advanced options will appear here."
    $advLabel.Location = New-Object System.Drawing.Point(10, 20)
    $advLabel.Size = New-Object System.Drawing.Size(400, 20)
    $advTab.Controls.Add($advLabel)

    $tabControl.TabPages.AddRange(@($basicTab, $vmTab, $advTab))
    $popup.Controls.Add($tabControl)

    # Save and Cancel Buttons
    $saveButton = New-Object System.Windows.Forms.Button
    $saveButton.Text = "Save"
    $saveButton.Size = New-Object System.Drawing.Size(100, 30)
    $saveButton.Location = New-Object System.Drawing.Point(280, 440)
    $popup.Controls.Add($saveButton)

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Text = "Cancel"
    $cancelButton.Size = New-Object System.Drawing.Size(100, 30)
    $cancelButton.Location = New-Object System.Drawing.Point(390, 440)
    $popup.Controls.Add($cancelButton)

    $saveButton.Add_Click({
        $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
        $folderBrowser.Description = "Select the directory to save the class folder"
        if ($folderBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $className = $classNameBox.Text.Trim()
            if ($className -eq "") {
                [System.Windows.Forms.MessageBox]::Show("Class name cannot be empty.", "Error")
                return
            }

            $classPath = Join-Path $folderBrowser.SelectedPath $className
            if (-not (Test-Path $classPath)) {
                New-Item -Path $classPath -ItemType Directory | Out-Null
            }

            $studentNames = $studentsBox.Text -split "`r`n"
            foreach ($student in $studentNames) {
                $studentName = $student.Trim()
                if ($studentName -ne "" -and $studentName.Contains(",")) {
                    $parts = $studentName -split ",\s*"
                    $lastName = $parts[0]
                    $firstName = $parts[1]
                    $folderName = "${className}_${firstName}${lastName}"
                    $studentFolderPath = Join-Path $classPath $folderName
                    if (-not (Test-Path $studentFolderPath)) {
                        New-Item -Path $studentFolderPath -ItemType Directory | Out-Null
                    }
                }
            }

            [System.Windows.Forms.MessageBox]::Show("Class and student folders created.", "Success")
            $popup.Close()
        }
    })

    $cancelButton.Add_Click({ $popup.Close() })

    $popup.ShowDialog()
}

# Menu function helpers
function Hide-AllExtras {
    $newClassButton.Visible = $false
}

function Set-Content {
    param ([string]$title)
    $contentLabel.Text = $title
    Hide-AllExtras

    if ($title -eq "Classes") {
        $newClassButton.Visible = $true
    }
}

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

# Button Events
$newClassButton.Add_Click({ Show-NewClassWindow })

# Menu setup
Add-MenuButton "Dashboard" 20 { Set-Content "Dashboard" }
Add-MenuButton "Classes" 70 { Set-Content "Classes" }
Add-MenuButton "Virtual Machines" 120 { Set-Content "Virtual Machines" }
Add-MenuButton "Logs" 170 { Set-Content "Logs" }
Add-MenuButton "Exit" 700 { $form.Close() }

# Run GUI
[System.Windows.Forms.Application]::Run($form)
