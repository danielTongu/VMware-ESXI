function ConnectTo-VMServer {
    BEGIN{}
    PROCESS{
#        $creds = Import-CliXml -Path $HOME'\My Drive (nawhite60@gmail.com)\VMware Scripts\creds.xml' 2> $null
        $creds = Import-CliXml -Path $HOME'\Google Drive\VMware Scripts\creds.xml' 
        Connect-VIServer -Server csvcsa.cs.cwu.edu -Credential $creds -Verbose > $null 2>&1
    }
    END{}
}



function New-CourseVMs {
# the courseInfo object is defined as:
#       startStudents          int              starting student number
#       endStudents            int              ending student number
#       classFolder            string           folder for the class VMs
#       dataStore              string           which datastore to build the VMs on
#       servers                custom object    collection of servers to build
#             servername       string           name of the server
#             template         string           name of the template
#             customization    string           name of customization script
#             adapters         custom object    collection of network adapters for the server
#                  adapter     string           name of the network adapter
#       students               array of strings names of students in class
#
    param(
        [PSCustomObject]$courseInfo
    )
    BEGIN{}
    PROCESS{
        # import common functions

        # connect to the server
        ConnectTo-VMServer

        # Get the VM host name
        $vmHost = Get-VMHost 2> $null
        
        # Loop through for the number of students in the class
        ForEach ($student in $courseInfo.students) {

#        for ($i=$courseInfo.startStudents; $i -le $courseInfo.endStudents; $i++) {
            # set the user account
            $userAccount = $classFolder + "_" + $student
    
            # see if the student folder exists
			If (Get-Folder -Name $userAccount 2> $null) {
                # folder exists
				Write-Host "Folder for " $userAccount " exists"
                $studentFolder = Get-Folder -Name $userAccount 2> $null
			}
			else {
				# create the student folder
                Write-Host "Creating folder for " $userAccount
				$studentFolder = New-Folder -Name $userAccount -Location (Get-Folder -Name $courseInfo.classFolder) 2> $null 
		
                # Disabling New-VIPermission until I can figure out to get it to work with domain accounts
				# give the student "StudentUser" privileges to the folder
                #				$account = Get-VIAccount -Name ad.cwu.edu\$userAccount 2> $null
                #				$role = Get-VIRole -Name StudentUser 2> $null 

                #				New-VIPermission -Entity $studentFolder -Principal $account -Role $role > $null 2>&1
			}
			
            # create the servers
            foreach ($server in $courseInfo.servers) {
                # create the server -- with or without a customization script
                Write-Host "Building " $server.serverName
                if ($server.customization) {
                    New-VM -Name $server.serverName -Datastore $courseInfo.dataStore -VMHost $vmHost  -Template $server.template -Location $studentFolder -OSCustomizationSpec $server.customization > $null 2>&1
                }
                else {
                    New-VM -Name $server.serverName -Datastore $courseInfo.dataStore -VMHost $vmHost  -Template $server.template -Location $studentFolder > $null 2>&1
                }

                # set the adapters
                $adapterNumber = 1
                foreach ($adapter in $server.adapters) {
                    $networkAdapter = 'Network Adapter '+$adapterNumber
                    if ($adapter -eq 'Instructor') {
                        $adapterName=$courseInfo.ClassFolder+'_In'
                    } elseif ($adapter -eq 'NATswitch') {
                        $adapterName=$adapter
                    } elseif ($adapter -eq 'inside') {
                        $adapterName=$adapter
                    } else {
                        $adapterName=$adapter+$i
                        if (Get-VirtualSwitch -Name $adapterName 2> $null) {
                            Write-Host $adapterName " exists"
                        } 
                        else {
                            Write-Host "Creating network adapter " $adapterName
                            # create the virtual switch for this user
                            $vSwitch = New-VirtualSwitch -Name $adapterName -VMHost $vmHost 2> $null 
                            # create the virtual port group for this user
                            $vPortGroup = New-VirtualPortGroup -Name $adapterName -VirtualSwitch $vSwitch 2> $null 
                        }  # if (Get-VirtualSwitch -Name $adapterName 2> $null) {

                    } # if ($adapter -eq 'Instructor') {

                    Write-Host "Connecting to " $adapterName

                    Get-VM -Name $server.serverName -Location $studentFolder | 
                        Get-NetworkAdapter -Name $networkAdapter | 
                        Set-NetworkAdapter -PortGroup $adapterName -Confirm:$false > $null 2>&1
                    $adapterNumber++
                } # end foreach ($adapter in $server.adapters)

                # start the VM
                Write-Host "Powering on`n"
                Get-VM -Name $server.serverName -Location $studentFolder | Start-VM -Confirm:$false > $null 2>&1
            } # end foreach ($server in $servers)


            Write-Host "`n"
        } # ForEach ($student in $courseInfo.students)
    } # PROCESS{
    END{}
}

function Remove-Host {
# This function removes a host from student folders
    param(
        [string]$classFolder,
        [string]$hostName,
        [int]$startStudents,
        [int]$endStudents
    )
    BEGIN{}
    PROCESS{
        # Loop through for the number of students in the class
        for ($i=$startStudents; $i -le $endStudents; $i++) {
            $userAccount = $classFolder+'_S'+$i
    
            # set the folder name
            $folderName = $classFolder+'_S'+$i

            $MyVM = Get-VM -Location $folderName -Name $hostName
            If ($MyVM.PowerState -eq "PoweredOn") {
                Stop-VM -VM $MyVM -Confirm:$false
            }
            
            Remove-VM -DeletePermanently -VM $MyVM -Confirm:$false

        } # for ($i=$startStudents; $i -le $endStudents; $i++)

    }
    END{}
}

function Remove-VMs {
    param(
        [string]$classFolder,
        [int]$startStudents,
        [int]$endStudents
    )
    BEGIN{}
    PROCESS{
        # Loop through for the number of students in the class
        for ($i=$startStudents; $i -le $endStudents; $i++) {
            $userAccount = $classFolder+'_S'+$i

    
            # set the folder name
            $folderName = $classFolder+'_S'+$i
    
            # power off the VMs
            Stop-VMs  $foldername 
    
            # remove the student folder
            Get-Folder -Name $folderName | Remove-Folder -Confirm:$false -DeletePermanently

            # write messsage
            Write-Host $folderName " removed"

        } # for ($i=$startStudents; $i -le $endStudents; $i++)
    }
    END{}
}

function Stop-VMs {
    param(
        [string]$location
    )
    BEGIN{}
    PROCESS{
        $MyVMs = Get-VM -Location $location 
        ForEach ($MyVM in $MyVMs) {
            If ($MyVM.PowerState -eq "PoweredOn") {
                Stop-VM -VM $MyVM -Confirm:$false
            }
        } # ForEach ($MyVM in $MyVMs)
    }
    END{}
}


function Get-VmwOrphan {
<#
    .SYNOPSIS
    Find orphaned files on a datastore
    .DESCRIPTION
    This function will scan the complete content of a datastore.
    It will then verify all registered VMs and Templates on that
    datastore, and compare those files with the datastore list.
    Files that are not present in a VM or Template are considered
    orphaned
    .NOTES
    Author:  Luc Dekens
    .PARAMETER Datastore
    The datastore that needs to be scanned
    .EXAMPLE
    PS> Get-VmwOrphan -Datastore DS1
    .EXAMPLE
    PS> Get-Datastore -Name DS* | Get-VmwOrphan
#>
[CmdletBinding()]
param(
    [parameter(Mandatory=$true,ValueFromPipeline=$true)]
    [PSObject[]]$Datastore
)
Begin{
    $flags = New-Object VMware.Vim.FileQueryFlags
    $flags.FileOwner = $true
    $flags.FileSize = $true
    $flags.FileType = $true
    $flags.Modification = $true
    $qFloppy = New-Object VMware.Vim.FloppyImageFileQuery
    $qFolder = New-Object VMware.Vim.FolderFileQuery
    $qISO = New-Object VMware.Vim.IsoImageFileQuery
    $qConfig = New-Object VMware.Vim.VmConfigFileQuery
    $qConfig.Details = New-Object VMware.Vim.VmConfigFileQueryFlags
    $qConfig.Details.ConfigVersion = $true
    $qTemplate = New-Object VMware.Vim.TemplateConfigFileQuery
    $qTemplate.Details = New-Object VMware.Vim.VmConfigFileQueryFlags
    $qTemplate.Details.ConfigVersion = $true
    $qDisk = New-Object VMware.Vim.VmDiskFileQuery
    $qDisk.Details = New-Object VMware.Vim.VmDiskFileQueryFlags
    $qDisk.Details.CapacityKB = $true
    $qDisk.Details.DiskExtents = $true
    $qDisk.Details.DiskType = $true
    $qDisk.Details.HardwareVersion = $true
    $qDisk.Details.Thin = $true
    $qLog = New-Object VMware.Vim.VmLogFileQuery
    $qRAM = New-Object VMware.Vim.VmNvramFileQuery
    $qSnap = New-Object VMware.Vim.VmSnapshotFileQuery
    $searchSpec = New-Object VMware.Vim.HostDatastoreBrowserSearchSpec
    $searchSpec.details = $flags
    $searchSpec.Query = $qFloppy,$qFolder,$qISO,$qConfig,$qTemplate,$qDisk,$qLog,$qRAM,$qSnap
    $searchSpec.sortFoldersFirst = $true
}

Process{
    foreach($ds in $Datastore){
        if($ds.GetType().Name -eq "String"){
            $ds = Get-Datastore -Name $ds
        }

# Only shared VMFS datastore
        if($ds.Type -eq "VMFS" -and $ds.ExtensionData.Summary.MultipleHostAccess -and $ds.State -eq 'Available'){
            Write-Verbose -Message "$(Get-Date)`t$((Get-PSCallStack)[0].Command)`tLooking at $($ds.Name)"
            # Define file DB
            $fileTab = @{}
# Get datastore files
            $dsBrowser = Get-View -Id $ds.ExtensionData.browser
            $rootPath = "[" + $ds.Name + "]"
            $searchResult = $dsBrowser.SearchDatastoreSubFolders($rootPath, $searchSpec) | Sort-Object -Property {$_.FolderPath.Length}
            foreach($folder in $searchResult){
                foreach ($file in $folder.File){
                    $key = "$($folder.FolderPath)$(if($folder.FolderPath[-1] -eq ']'){' '})$($file.Path)"
                    $fileTab.Add($key,$file)

                    $folderKey = "$($folder.FolderPath.TrimEnd('/'))"
                    if($fileTab.ContainsKey($folderKey)){
                        $fileTab.Remove($folderKey)
                    }
                }
            }

# Get VM inventory
            Get-VM -Datastore $ds | %{
                $_.ExtensionData.LayoutEx.File | %{
                    if($fileTab.ContainsKey($_.Name)){
                        $fileTab.Remove($_.Name)
                    }
                }
            }

# Get Template inventory
            Get-Template | where {$_.DatastoreIdList -contains $ds.Id} | %{
                $_.ExtensionData.LayoutEx.File | %{
                    if($fileTab.ContainsKey($_.Name)){
                        $fileTab.Remove($_.Name)
                    }
                }
            }

# Remove system files & folders from list
            $systemFiles = $fileTab.Keys | where{$_ -match "] \.|vmkdump"}
            $systemFiles | %{
                $fileTab.Remove($_)
            }

# Organise remaining files
            if($fileTab.Count){
                $fileTab.GetEnumerator() | %{
                    $obj = [ordered]@{
                        Name = $_.Value.Path
                        Folder = $_.Name
                        Size = $_.Value.FileSize
                        CapacityKB = $_.Value.CapacityKb
                        Modification = $_.Value.Modification
                        Owner = $_.Value.Owner
                        Thin = $_.Value.Thin
                        Extents = $_.Value.DiskExtents -join ','
                        DiskType = $_.Value.DiskType
                        HWVersion = $_.Value.HardwareVersion
                    }
                    New-Object PSObject -Property $obj
                }
                Write-Verbose -Message "$(Get-Date)`t$((Get-PSCallStack)[0].Command)`tFound orphaned files on $($ds.Name)!"
            }
            else{
                Write-Verbose -Message "$(Get-Date)`t$((Get-PSCallStack)[0].Command)`tNo orphaned files found on $($ds.Name)."
            }
            }
        }
    }
}