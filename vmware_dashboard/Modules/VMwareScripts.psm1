<#
.SYNOPSIS
    Wraps all of your existing VMware‐related scripts.
.DESCRIPTION
    Each function here simply calls the real script in ../Scripts/.
    This module can be unit-tested by mocking Invoke‐Script if necessary.
#>

function Invoke-Script {
    <#
    .SYNOPSIS
        Executes a PowerShell script from the Scripts\ folder.
    .PARAMETER ScriptName
        The filename of the script (e.g. 'createStudentFolders.ps1').
    .PARAMETER Args
        The argument string to pass.
    .OUTPUTS
        System.String — the combined stdout/stderr.
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)][string]$ScriptName,
        [Parameter()][string]$Args = ''
    )
    $path = Join-Path $PSScriptRoot "..\Scripts\$ScriptName"
    if (-not (Test-Path $path)) {
        Throw "Script not found: $path"
    }
    & $path $Args 2>&1
}

function Invoke-CreateStudentFolders { Param([string]$Args) Invoke-Script 'createStudentFolders.ps1' $Args }
function Invoke-GetCredentials      { Param([string]$Args) Invoke-Script 'GetCredentials.ps1'      $Args }
function Invoke-AddNetwork          { Param([string]$Args) Invoke-Script 'addNetwork.ps1'          $Args }
function Invoke-AddNetworks         { Param([string]$Args) Invoke-Script 'addNetworks.ps1'         $Args }
function Invoke-DeleteNetwork       { Param([string]$Args) Invoke-Script 'deleteNetwork.ps1'       $Args }
function Invoke-DeleteNetworks      { Param([string]$Args) Invoke-Script 'deleteNetworks.ps1'      $Args }
function Invoke-DeleteOrphanFiles   { Param([string]$Args) Invoke-Script 'DeleteOrphanFilesFromDatastore.ps1' $Args }
function Invoke-PowerOffAllVMs      { Param([string]$Args) Invoke-Script 'PowerOffAllVMs.ps1'      $Args }
function Invoke-PowerOffClassVMs    { Param([string]$Args) Invoke-Script 'PowerOffClassVMs.ps1'    $Args }
function Invoke-PowerOffSpecificVMs { Param([string]$Args) Invoke-Script 'PowerOffSpecificClassVMs.ps1' $Args }
function Invoke-AllUserLoginTimes   { Param([string]$Args) Invoke-Script 'AllUserLoginTimes.ps1'   $Args }
function Invoke-ShowPoweredOnVMs    { Param([string]$Args) Invoke-Script 'ShowPoweredOnVMs.ps1'    $Args }
function Invoke-RestartAllVMs       { Param([string]$Args) Invoke-Script 'RestartAllPoweredOnVMs.ps1' $Args }

Export-ModuleMember -Function Invoke-*