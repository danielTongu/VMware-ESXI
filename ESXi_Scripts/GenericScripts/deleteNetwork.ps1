# Script to delete a network switch and portgroup
# Written by Nathan White
# 12/19/2017
# The purpose of this script is to delete a standard switch and its associated port group.

# there is one input parameter, the name of the network to remove.
param (
    [string]$networkName
)


# import common functions
Import-Module $HOME'\Google Drive\VMware Scripts\VmFunctions.psm1'

ConnectTo-VMServer

# remove the port group
Get-VirtualPortGroup -VMHost (Get-VMHost) -Name $networkName     | Remove-VirtualPortGroup  -Confirm:$false
    
# remove the switch
Get-VirtualSwitch -Name $networkName | Remove-VirtualSwitch -Confirm:$false
