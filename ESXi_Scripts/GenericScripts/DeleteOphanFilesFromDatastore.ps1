# Written by Nathan White
# 8/12/2020
#
# script to seach a datastore for orphaned files and delete them
#

param (
    [string]$datastoreName
)

# import common functions
Import-Module $HOME'\Google Drive\VMware Scripts\VmFunctions.psm1'

ConnectTo-VMServer

# Get orphaned files on a datastore
Get-Datastore -Name $datastoreName | Get-VmwOrphan 
