# VMware ESXi Dashboard

A modular, testable PowerShell WinForms GUI for managing VMware ESXi resources in a classroom setting.  
It wraps your existing ESXi scripts (folder/VM/network operations, power actions, reporting) and presents them in a clean, MVC-style Windows Forms interface.

---

## Table of Contents

1. [Features](#features)  
2. [Prerequisites](#prerequisites)  
3. [Repository Structure](#repository-structure)  
4. [Installation](#installation)  
5. [Usage](#usage)  
   - [CLI Scripts](#cli-scripts)  
   - [WinForms GUI](#winforms-gui)  
6. [Extending & Testing](#extending--testing)  
7. [Contributing](#contributing)  
8. [License](#license)  

---

## Features

- **Class Management**: create, edit, delete classes; assign students; configure VM templates, datastores, networks.  
- **VM Operations**: list powered-on VMs, power on/off, restart, remove specific VMs for a class.  
- **Network Administration**: add/delete single or bulk networks, clean up orphaned datastores.  
- **Reporting**: show user login times from CSV, export VM tables to CSV.  
- **MVC Structure**:  
  - **Model**: `VMwareScripts.psm1` wraps all ESXi backend scripts.  
  - **Views**: one PS1 per screen (`DashboardView.ps1`, `ClassesView.ps1`, etc.).  
  - **Controller**: `Main.psm1` wires UI events to model calls.  
- **Modular & Testable**: no inline mocks, easily Pester-testable modules.

---

## Prerequisites

- **Windows** with PowerShell 5.1+  
- `.NET Framework` (for WinForms)  
- Execution policy set to allow local scripts:  
  ```powershell
  Set-ExecutionPolicy RemoteSigned -Scope CurrentUser