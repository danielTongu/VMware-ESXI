# Script to add a network switch and port group
# Written by Nathan White
# 12/19/2017
# The purpose of this script is to add a standard switch and port group


# there are three input parameters:
#     The course number
#     The number of the first student network to remove
#     The number of the last student network to remove
param(
    [string]$courseNumber,
    [int]$startStudents,
    [int]$endStudents
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
        $adapterName=$courseNumber+"_S"+$i
        if (Get-VirtualSwitch -Name $adapterName 2> $null) {
            Write-Host 'adapter exists'
        } 
        else {
            # create the virtual switch for this user
            $vSwitch = New-VirtualSwitch -Name $adapterName -VMHost $vmHost
            # create the virtual port group for this user
            $vPortGroup = New-VirtualPortGroup -Name $adapterName -VirtualSwitch $vSwitch 
        }  # if (Get-VirtualSwitch -Name $adapterName 2> $null) {
    } # for ($i=$startStudents; $i -le $endStudents; $i++)
} # PROCESS{
END{}
