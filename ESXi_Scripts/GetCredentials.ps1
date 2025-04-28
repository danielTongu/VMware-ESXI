# Get Credential Script
# Written by Nathan White
# 03/18/19
# The purpose of this script is store a VMware server credential object for use in our scripts.
# The object will be stored in $HOME'\Google Drive\VMware Scripts'
#
# there one parameter, the username
param (
    [string]$userName
)

$creds = Get-Credential -Message "vSphere Id and Password"


# $creds | Export-CliXml -Path $HOME'\My Drive (nawhite60@gmail.com)\VMware Scripts\creds.xml'
$creds | Export-CliXml -Path $HOME'\Google Drive\VMware Scripts\creds.xml'
