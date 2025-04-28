# Clean up script
# Written by Nathan White
# 3/18/19
# The purpose of this script is to delete the folders and VMs for a course. Networks need to be deleted separately
# with the deleteNetworks.ps1 script
#
# there are three parameters: the class number,the starting student number, and ending student number
#


param (
    [string]$classFolder,
    [int]$startStudents = 1,
    [int]$endStudents = 1
)

# import common functions
Import-Module $HOME'\Google Drive\VMware Scripts\VmFunctions.psm1'

ConnectTo-VMServer

if (Get-Folder $classFolder -ErrorAction:Ignore ) {
    # Loop through for the number of students in the class
    Remove-VMs $classFolder $startStudents $endStudents
}
else {
    Write-Host 'Bad class folder'
}