# Clean up script
# Written by Nathan White
# 12/11/2019
# The purpose of this script is to power off all VMs for a class.  

param (
    [string]$classFolder
)

# import common functions
Import-Module $HOME'\Google Drive\VMware Scripts\VmFunctions.psm1'

ConnectTo-VMServer

$MyVMs = Get-VM -Location $classFolder 2> $null | Sort-Object -Property Folder
ForEach ($MyVM in $MyVMs) {
    If ($MyVM.PowerState -eq "PoweredOn") {
        Write-Host "Stopping " $MyVM.Folder   $MyVM.Name
        Stop-VM -VM $MyVM -Confirm:$false > $null 2>&1
    }
} # ForEach ($MyVM in $MyVMs)
    