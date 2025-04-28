# Script to add a network switch and port group
# Written by Nathan White
# 12/19/2017
# The purpose of this script is to add a standard switch and port group

# there is one input parameter, the number of students in the class.
param (
    [string]$networkName
)

# import common functions
# Import-Module $HOME'\My Drive (nawhite60@gmail.com)\VMware Scripts\VmFunctions.psm1'
Import-Module $HOME'\Google Drive\VMware Scripts\VmFunctions.psm1'

ConnectTo-VMServer

# Get the VM host name
$vmHost = Get-VMHost 

# create the virtual switch for this user
$vSwitch = New-VirtualSwitch -Name $networkName -VMHost $vmHost

# create the virtual port group for this user
$vPortGroup = New-VirtualPortGroup -Name $networkName -VirtualSwitch $vSwitch 