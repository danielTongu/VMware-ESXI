# VMware ESXi Dashboard

A modular PowerShell WinForms GUI for managing VMware ESXi resources in a classroom environment.  
It wraps your existing ESXi scripts (class/VM/network operations, power actions, reporting) in an MVC-style interface.

---

## Repository Structure

```text
VMwareDashboard/
├── Main.ps1
├── Main.psm1
├── Modules/
│   └── VMwareScripts.psm1
└── Views/
    ├── DashboardView.ps1
    ├── ClassesView.ps1
    ├── VMsView.ps1
    ├── NetworksView.ps1
    └── LogsView.ps1
```

> **Note:**  
> The `ESXi_Scripts/` folder (with all your backend `.ps1`/`.psm1` files) lives alongside this project but is **ignored** by Git.  
> Copy your real scripts into `ESXi_Scripts/` before running the GUI.

---

## Setup

1. **Clone** this repository:
   ```powershell
   git clone https://github.com/your-org/VMware-ESXI.git
   cd VMware-ESXI/VMwareDashboard
   ```
2. **Populate** your ESXi scripts (outside this folder):
   ```text
   VMware-ESXI/
   └── ESXi_Scripts/
         ├── createStudentFolders.ps1
         ├── GetCredential.ps1
         ├── VmFunctions.psm1
         │
         └── GenericScripts/
             ├── AllUserLoginTimes.csv
             ├── addNetwork.ps1
             ├── addNetworks.ps1
             ├── deleteNetwork.ps1
             ├── deleteNetworks.ps1
             ├── DeleteOphanFilesFromDatastore.ps1
             ├── ShowAllPoweredOnVMs.ps1
             ├── RestartAllPoweredOnVMs.ps1
             ├── PowerOffAllVMs.ps1
             ├── PowerOffClassVMs.ps1
             ├── PowerOffSpecificClassVMs.ps1
             ├── PowerOnSpecificClassVMs.ps1
             ├── removeHosts.ps1
             ├── Remove-CourseFolderVMs.ps1
             │
             └── …your existing scripts…
   ```
3. **Unblock** all scripts (Windows security):
   ```powershell
   Get-ChildItem -Recurse ../ESXi_Scripts | Unblock-File
   Get-ChildItem -Recurse . | Unblock-File
   ```
4. **(Optional)** install Pester for testing:
   ```powershell
   Install-Module Pester -Scope CurrentUser
   ```

---

## Usage

### CLI Scripts

Run your existing ESXi scripts directly:
```powershell
cd ../ESXi_Scripts/GenericScripts
.\addNetwork.ps1 -NetworkName "Instructor"
```

### WinForms GUI

```powershell
cd VMwareDashboard
.\Main.ps1
```

Use the left-hand menu to switch screens:

- **Dashboard** – welcome screen  
- **Classes** – manage classes, students & VMs  
- **Virtual Machines** – list, power on/off, restart, report  
- **Networks** – add/delete single or bulk networks, clean orphans  
- **Logs** – view GUI or script output  

---

## Extending & Testing

- **Add new backend scripts**: place them in `ESXi_Scripts/…`, then add a wrapper in `Modules/VMwareScripts.psm1`.  
- **Add new UI screens**: create `Views/YourView.ps1` exporting `Show-YourView`, and wire it in `Main.psm1`.  
- **Unit tests**: Pester-test `Modules/VMwareScripts.psm1` by mocking `Invoke-Script`, and call individual `Show-*View` functions with a dummy `Panel`.

---

## Contributing

1. **Fork** the repository and create a feature branch.  
2. **Write tests** for any new model functions (Pester).  
3. **Add or update** view scripts in the `Views/` folder.  
4. **Submit** a pull request with a clear description of your changes.

---

## License

This project is licensed under the [MIT License](LICENSE).
