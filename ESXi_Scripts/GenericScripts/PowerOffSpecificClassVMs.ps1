# Clean up script
# Written by Nathan White
# 10/9/2020
# The purpose of this script is to power off a VM for all students in a class.  

param (
    [int]$startStudents = 1,
    [int]$endStudents = 1,
    [string]$classFolder,
    [string]$serverName
)

# import common functions
Import-Module $HOME'\Google Drive\VMware Scripts\VmFunctions.psm1'

ConnectTo-VMServer

# Loop through for the number of students in the class
for ($i=$startStudents; $i -le $endStudents; $i++) {
    # set the folder name
    $folderName = $classFolder+'_S'+$i
    
    # get the VM
    $MyVM = Get-VM -Location $folderName -Name $serverName 2> $null 

    # power off the VMs
    If ($MyVM.PowerState -eq "PoweredOn") {
            Stop-VM -VM $MyVM -Confirm:$false > $null 2>&1
    }
 
    # write messsage
    Write-Host $folderName " " $serverName " powered off"

} # for ($i=$startStudents; $i -le $endStudents; $i++)
