<#
.SYNOPSIS
    Wraps all ESXi_Scripts for use in the GUI.
#>

function Invoke-Script {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ScriptName,
        [string]$Args = ''
    )
    # Determine script path
    $root        = Split-Path -Parent $PSScriptRoot    # ...\VMwareDashboard\Modules
    $esxi        = Join-Path $root '..\..\ESXi_Scripts'
    $generic     = Join-Path $esxi 'GenericScripts'
    $candidates  = @(
        Join-Path $esxi $ScriptName,
        Join-Path $generic $ScriptName
    )
    $path = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $path) {
        Throw "Script not found: $ScriptName"
    }
    & $path $Args 2>&1
}

function Invoke-CreateStudentFolders  { param([string]$Args) Invoke-Script 'createStudentFolders.ps1' $Args }
function Invoke-GetCredential         { param([string]$Args) Invoke-Script 'GetCredential.ps1'        $Args }
function Invoke-VmFunctions           { param([string]$Args) Invoke-Script 'VmFunctions.psm1'         $Args }
function Invoke-AllUserLoginTimes     { param([string]$Args) Invoke-Script 'AllUserLoginTimes.ps1'   $Args }
function Invoke-AddNetwork            { param([string]$Args) Invoke-Script 'addNetwork.ps1'          $Args }
function Invoke-AddNetworks           { param([string]$Args) Invoke-Script 'addNetworks.ps1'         $Args }
function Invoke-DeleteNetwork         { param([string]$Args) Invoke-Script 'deleteNetwork.ps1'       $Args }
function Invoke-DeleteNetworks        { param([string]$Args) Invoke-Script 'deleteNetworks.ps1'      $Args }
function Invoke-DeleteOrphanFiles     { param([string]$Args) Invoke-Script 'DeleteOphanFilesFromDatastore.ps1' $Args }
function Invoke-ShowAllPoweredOnVMs   { param([string]$Args) Invoke-Script 'ShowAllPoweredOnVMs.ps1' $Args }
function Invoke-RestartAllVMs         { param([string]$Args) Invoke-Script 'RestartAllPoweredOnVMs.ps1' $Args }
function Invoke-PowerOffAllVMs        { param([string]$Args) Invoke-Script 'PowerOffAllVMs.ps1'      $Args }
function Invoke-PowerOffClassVMs      { param([string]$Args) Invoke-Script 'PowerOffClassVMs.ps1'    $Args }
function Invoke-PowerOffSpecificVMs   { param([string]$Args) Invoke-Script 'PowerOffSpecificClassVMs.ps1' $Args }
function Invoke-PowerOnSpecificVMs    { param([string]$Args) Invoke-Script 'PowerOnSpecificClassVMs.ps1'  $Args }
function Invoke-RemoveHosts           { param([string]$Args) Invoke-Script 'removeHosts.ps1'         $Args }
function Invoke-RemoveCourseFolderVMs { param([string]$Args) Invoke-Script 'Remove-CourseFolderVMs.ps1' $Args }

Export-ModuleMember -Function Invoke-*