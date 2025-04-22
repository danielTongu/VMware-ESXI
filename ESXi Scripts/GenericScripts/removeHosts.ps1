# Clean up script
# Written by Nathan White
# 12/19/2017
# The purpose of this script is to delete student VM from the IT466 class. Each student folder will be created under the IT466 class folder. Each student will have a user account, IT463_Sx, where x is the student number. 

# there are three input parameter, the starting student number, the ending student number, and the host name
param (
    [int]$startStudents = 1,
    [int]$endStudents = 1,
    [string]$classFolder,
    [string]$hostName
)

if (!$classFolder) {
    Write-Host 'Error: You must provide a class folder'
    Exit
}

if (!$hostName) {
    Write-Host 'Error: You must provide a host name'
    Exit
}

# import common functions
Import-Module $HOME'\Google Drive\VMware Scripts\VmFunctions.psm1'

ConnectTo-VMServer

Remove-Host $classFolder $hostName $startStudents $endStudents


