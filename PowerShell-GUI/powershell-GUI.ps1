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

$saveClassButton = New-Object System.Windows.Forms.Button
$saveClassButton.Text = "Save"
$saveClassButton.Size = New-Object System.Drawing.Size(150, 30)
$saveClassButton.Location = New-Object System.Drawing.Point(30, 700)
$saveClassButton.Visible = $false
$contentPanel.Controls.Add($saveClassButton)

$cancelButton = New-Object System.Windows.Forms.Button
$cancelButton.Text = "Return"
$cancelButton.Size = New-Object System.Drawing.Size(150, 30)
$cancelButton.Location = New-Object System.Drawing.Point(200, 700)
$cancelButton.Visible = $false
$contentPanel.Controls.Add($cancelButton)

# Labels and TextBoxes
$classLabel = New-Object System.Windows.Forms.Label
$classLabel.Text = "Class name:"
$classLabel.Location = New-Object System.Drawing.Point(30, 80)
$classLabel.AutoSize = $true
$classLabel.Visible = $false
$contentPanel.Controls.Add($classLabel)

$classNameTextBox = New-Object System.Windows.Forms.TextBox
$classNameTextBox.Size = New-Object System.Drawing.Size(200, 30)
$classNameTextBox.Location = New-Object System.Drawing.Point(30, 100)
$classNameTextBox.Visible = $false
$contentPanel.Controls.Add($classNameTextBox)

$studentsLabel = New-Object System.Windows.Forms.Label
$studentsLabel.Text = "Student names (Last, First - one per line):"
$studentsLabel.Location = New-Object System.Drawing.Point(30, 140)
$studentsLabel.AutoSize = $true
$studentsLabel.Visible = $false
$contentPanel.Controls.Add($studentsLabel)

$studentNamesTextBox = New-Object System.Windows.Forms.TextBox
$studentNamesTextBox.Multiline = $true
$studentNamesTextBox.ScrollBars = "Vertical"
$studentNamesTextBox.Size = New-Object System.Drawing.Size(400, 200)
$studentNamesTextBox.Location = New-Object System.Drawing.Point(30, 160)
$studentNamesTextBox.Visible = $false
$contentPanel.Controls.Add($studentNamesTextBox)

# Function to clear all extras
function Hide-AllExtras {
    $newClassButton.Visible = $false
    $saveClassButton.Visible = $false
    $cancelButton.Visible = $false
    $classNameTextBox.Visible = $false
    $studentNamesTextBox.Visible = $false
    $classLabel.Visible = $false
    $studentsLabel.Visible = $false
}

# Set content view
function Set-Content {
    param ([string]$title)
    $contentLabel.Text = $title
    Hide-AllExtras

    if ($title -eq "Classes") {
        $newClassButton.Visible = $true
    } elseif ($title -eq "Add Class") {
        $classNameTextBox.Visible = $true
        $studentNamesTextBox.Visible = $true
        $classLabel.Visible = $true
        $studentsLabel.Visible = $true
        $saveClassButton.Visible = $true
        $cancelButton.Visible = $true
    }
}

# Menu button
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

# Create class folders
function Create-ClassFolders {
    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderBrowser.Description = "Select the directory to save the class folder"
    if ($folderBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $classDirectory = $folderBrowser.SelectedPath
        $className = $classNameTextBox.Text.Trim()
        if ($className -eq "") {
            [System.Windows.Forms.MessageBox]::Show("Class name cannot be empty.", "Error")
            return
        }

        $classPath = Join-Path $classDirectory $className
        if (-not (Test-Path $classPath)) {
            New-Item -Path $classPath -ItemType Directory | Out-Null
        }

        $studentNames = $studentNamesTextBox.Text -split "`r`n"
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

        # Clear input fields
        $classNameTextBox.Text = ""
        $studentNamesTextBox.Text = ""
    }
}

# Events
$newClassButton.Add_Click({ Set-Content "Add Class" })
$cancelButton.Add_Click({ Set-Content "Classes" })
$saveClassButton.Add_Click({ Create-ClassFolders })

# Menu setup
Add-MenuButton "Dashboard" 20 { Set-Content "Dashboard" }
Add-MenuButton "Classes" 70 { Set-Content "Classes" }
Add-MenuButton "Virtual Machines" 120 { Set-Content "Virtual Machines" }
Add-MenuButton "Logs" 170 { Set-Content "Logs" }
Add-MenuButton "Exit" 700 { $form.Close() }

# Run GUI
[System.Windows.Forms.Application]::Run($form)
