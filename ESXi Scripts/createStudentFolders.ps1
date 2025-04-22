# Written by Nathan White
# 3/28/25
# The purpose of this script is build the courseInfo object for CS 370
# to New-CourseVMs. The courseInfo object is defined as:
#       startStudents          int              starting student number
#       endStudents            int              ending student number
#       classFolder            string           folder for the class VMs
#       dataStore              string           which datastore to build the VMs on
#       servers                custom object    collection of servers to build
#             servername       string           name of the server
#             template         string           name of the template
#             customiszation   string           customization script
#             adapters         custom object    collection of network adapters for the server
#                  adapter     string           name of the network adapter
#       students               array of strings names of students in class
#
# 



# The student will have the ability to start, stop, and view the console of these VMs.

# there are three input parameters for the start student number, ending student number,
# and the datastore to use
param (
    [int]$startStudents = 1,
    [int]$endStudents = 1,
    [string]$datastoreName
)

# import common functions
Import-Module $HOME'\My Drive (nawhite60@gmail.com)\VMware Scripts\VmFunctions.psm1'

ConnectTo-VMServer

# Class we are working on
[string]$classFolder = 'CS361'  

# get the datastore name if not supplied as a parameter ********** Commenting out temporarily
# if (!$datastoreName) {
#     $datastoreName = Read-Host -Prompt 'Enter datastore to build VMs on: ' -
#}

# get the datastore ---- below is old code form ITAM's server
# $dataStore = (Get-Datastore -Name $datastoreName -ErrorAction:Ignore)
# if (!$dataStore) {
#     Write-Host 'Error: The datastore you entered is not valid'
#     Exit
# }
$datastore = "me-vmfs01"       # This should turn into a drop-down list

#     ***************************************************************************
#     ***************************************************************************
#     ***************************************************************************
# The following code should be the only code that ever is changed. The following code specifies
# the servers to build, the templates to use for the build, and the network(s) that each server
# should connect to.
#
# The $servers object contains the server name, template name, and an adapters object. The
# adapters object contains a list of the adapters that the machine will use. The adapters
# should either be the VM Network or the individual student network
$servers = @(
    [PSCustomObject]@{serverName='Ubuntu';template='CS361_Template';customization=$null;adapters=@('NATswitch')}
)

$studentList = Get-Content -Path .\CS361\studentList.txt


# This is the object to pass to New-CourseVMs
$courseInfo = [PSCustomObject]@{
    startStudents=$startStudents;
    endStudents=$endStudents;
    classFolder=$classFolder;
    dataStore=$dataStore;
    servers=$servers;
    students=$studentList
}

# Call New-CourseVMs to create the VMs
New-CourseVMs $courseInfo
