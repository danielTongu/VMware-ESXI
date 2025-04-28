# Script to delete a network switch and portgroup
# Written by Nathan White
# 12/19/2017
# The purpose of this script is to delete a standard switch and its associated port group.

# there are three input parameters:
#     The number of the first student network to remove
#     The number of the last student network to remove
#     The course number
param(
    [int]$startStudents,
    [int]$endStudents,
    [string]$courseNumber
)


BEGIN{}
PROCESS{
    # import common functions
    Import-Module $HOME'\Google Drive\VMware Scripts\VmFunctions.psm1'

    ConnectTo-VMServer

    # Get the VM host name
    $vmHost = Get-VMHost 
        
    # loop through each student
    for ($i=$startStudents; $i -le $endStudents; $i++) {
        # set the adapter name
        $adapterName = $courseNumber+'_S'+$i
        # remove the port group
        Get-VirtualPortGroup -VMHost $vmHost -Name $adapterName | Remove-VirtualPortGroup  -Confirm:$false
    
        # remove the switch
        Get-VirtualSwitch -Name $adapterName | Remove-VirtualSwitch -Confirm:$false
    } # for ($i=$startStudents; $i -le $endStudents; $i++)
} # PROCESS{
END{}

