# Clean up script
# Written by Nathan White
# 7/31/2018
# The purpose of this script is to power off all VMs on the server.  

# there are no input parameters

# import common functions
Import-Module $HOME'\Google Drive\VMware Scripts\VmFunctions.psm1'

ConnectTo-VMServer
exit

$MyVMs = Get-VM 
ForEach ($MyVM in $MyVMs) {
    If ($MyVM.PowerState -eq "PoweredOn") {
        Stop-VM -VM $MyVM -Confirm:$false
    }
} # ForEach ($MyVM in $MyVMs)
    