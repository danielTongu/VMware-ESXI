<#
.SYNOPSIS
    Renders the "Logs" screen in the WinForms GUI with enhanced functionality.

.DESCRIPTION
    Builds the Logs view by:
      1. Clearing existing controls from the content panel.
      2. Declaring UI components (title, buttons, textbox).
      3. Configuring component properties (text, size, location, behavior).
      4. Wiring event handlers for:
         - Refreshing the log display
         - Clearing the log file
      5. Adding all components to the panel and performing an initial load.

.PARAMETER ContentPanel
    The System.Windows.Forms.Panel into which the Logs controls are placed.

.NOTES
    - Adjust `$logFilePath` to point to your actual log file.
    - Clearing the log will truncate the file on disk.
#>
function Show-LogsView {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Forms.Panel] $ContentPanel
    )

    # -------------------------------------------------------------------------
    # 0) Clear existing controls
    # -------------------------------------------------------------------------
    $ContentPanel.Controls.Clear()

    # -------------------------------------------------------------------------
    # 1) Declare UI components
    # -------------------------------------------------------------------------
    $labelTitle      = New-Object System.Windows.Forms.Label
    $buttonRefresh   = New-Object System.Windows.Forms.Button
    $buttonClear     = New-Object System.Windows.Forms.Button
    $textBoxLogs     = New-Object System.Windows.Forms.TextBox

    # -------------------------------------------------------------------------
    # 2) Configure component properties
    # -------------------------------------------------------------------------

    ## Title label
    $labelTitle.Text     = 'Logs'
    $labelTitle.Font     = [System.Drawing.Font]::new('Segoe UI',20,[System.Drawing.FontStyle]::Bold)
    $labelTitle.AutoSize = $true
    $labelTitle.Location = [System.Drawing.Point]::new(30,20)

    ## Refresh button
    $buttonRefresh.Text     = 'Refresh'
    $buttonRefresh.Size     = [System.Drawing.Size]::new(100,30)
    $buttonRefresh.Location = [System.Drawing.Point]::new(360,22)

    ## Clear button
    $buttonClear.Text     = 'Clear Log'
    $buttonClear.Size     = [System.Drawing.Size]::new(100,30)
    $buttonClear.Location = [System.Drawing.Point]::new(480,22)

    ## Logs textbox
    $textBoxLogs.Multiline       = $true
    $textBoxLogs.ScrollBars      = 'Both'
    $textBoxLogs.WordWrap        = $false
    $textBoxLogs.ReadOnly        = $true
    $textBoxLogs.Font            = [System.Drawing.Font]::new('Consolas',9)
    $textBoxLogs.Location        = [System.Drawing.Point]::new(30,70)
    $textBoxLogs.Size            = [System.Drawing.Size]::new(820,500)
    $textBoxLogs.Anchor          = [System.Windows.Forms.AnchorStyles]::Top `
                                 -bor [System.Windows.Forms.AnchorStyles]::Bottom `
                                 -bor [System.Windows.Forms.AnchorStyles]::Left `
                                 -bor [System.Windows.Forms.AnchorStyles]::Right

    # Path to the log file (adjust as needed)
    $scriptDir    = Split-Path -Parent $MyInvocation.MyCommand.Path
    $logFilePath  = Join-Path $scriptDir '..\..\vmware_dashboard.log'

    # -------------------------------------------------------------------------
    # 3) Wire event handlers
    # -------------------------------------------------------------------------

    # Refresh handler: read and display log file contents
    $buttonRefresh.Add_Click({
        if (Test-Path $logFilePath) {
            try {
                $content = Get-Content -Path $logFilePath -Raw
                $textBoxLogs.Text = $content
            }
            catch {
                $textBoxLogs.Text = "Error reading log: $($_.Exception.Message)"
            }
        }
        else {
            $textBoxLogs.Text = "Log file not found:`n$logFilePath"
        }
    })

    # Clear handler: truncate the log file
    $buttonClear.Add_Click({
        if (Test-Path $logFilePath) {
            try {
                Clear-Content -Path $logFilePath
                $textBoxLogs.Text = ''
            }
            catch {
                [System.Windows.Forms.MessageBox]::Show("Error clearing log: $($_.Exception.Message)", 'Error')
            }
        }
        else {
            [System.Windows.Forms.MessageBox]::Show("Log file not found:`n$logFilePath", 'Error')
        }
    })

    # -------------------------------------------------------------------------
    # 4) Add components to the panel
    # -------------------------------------------------------------------------
    $ContentPanel.Controls.AddRange(@(
        $labelTitle,
        $buttonRefresh,
        $buttonClear,
        $textBoxLogs
    ))

    # -------------------------------------------------------------------------
    # 5) Initial load of log contents
    # -------------------------------------------------------------------------
    $buttonRefresh.PerformClick()
}

Export-ModuleMember -Function Show-LogsView