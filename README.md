# VMware ESXi Dashboard (PowerShell WinForms)

## Structure

- **ESXi Scripts/** – all your backend scripts
- **vmware_dashboard/** – the GUI project
  - **Main.ps1 / Main.psm1** – bootstrap GUI
  - **Modules/VMwareScripts.psm1** – wrappers around every backend script
  - **Views/** – one `.ps1` per screen (Dashboard, Classes, VMs, Networks, Logs)

## Prerequisites

- Windows PowerShell 5.1+  
- ExecutionPolicy: `Set-ExecutionPolicy RemoteSigned`  
- .NET Framework (WinForms)

## Running

```powershell
cd vmware_dashboard
.\Main.ps1