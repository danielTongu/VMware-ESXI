# Clean up script
# Written by Nathan White
# 1/7/2020
# The purpose of this script is to restart all powered on VMs.  

# there are no input parameters

# import common functions
Import-Module $HOME'\Google Drive\VMware Scripts\VmFunctions.psm1'

ConnectTo-VMServer

$MyVMs = Get-VM 
ForEach ($MyVM in $MyVMs) {
    If ($MyVM.PowerState -eq "PoweredOn" -and $MyVM.name -ne 'ITAMvCenter') {
        Stop-VM -VM $MyVM -Confirm:$false
        Start-VM -VM $MyVM -Confirm:$false
    }
} # ForEach ($MyVM in $MyVMs)
    