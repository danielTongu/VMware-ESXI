# VMware ESXi Dashboard

A modular **PowerShell WinForms GUI** for managing VMware ESXi resources in a classroom or training lab.
It wraps your existing ESXi automation scripts (VMs, classes, networks, orphan cleaner, logs) into a unified, interactive interface with login and dynamic navigation.

---

## 🗂️ Project Structure

```text
VMware-ESXI/
├── Images/                    # UI assets
│   ├── login.png              # Login dialog background
│   └── ... 
├── Models/                    # Core automation scripts
│   ├── ConnectTo-VMServer.ps1 # Connect and maintain vCenter connection
│   ├── CourseManager.ps1      # Create and manage class VMs
│   ├── OrphanCleaner.ps1      # Find orphaned VM files
│   ├── SessionReporter.ps1    # Generate session reports and logs
│   ├── VMwareNetwork.ps1      # Network port group automation
│   └── VMwareVM.ps1           # VM power, clone, and remove operations
├── Views/                     # PowerShell WinForms UI views
│   ├── MainView.ps1           # Shell: navigation menu + content panel
│   ├── LoginView.ps1          # Login dialog
│   ├── DashboardView.ps1      # Host, VM, and network summary stats
│   ├── ClassManagerView.ps1   # UI for managing class VMs
│   ├── VMsView.ps1            # Grid: list, filter, power on/off, remove VMs
│   ├── NetworkManagerView.ps1 # Add/remove port groups (bulk & single)
│   ├── OrphanCleanerView.ps1  # Discover & delete orphaned VM files
│   └── LogsView.ps1           # View and refresh VMware event logs
├── .gitignore                 # Exclude IDE and temp files
├── Main.ps1                   # Entry point: shows LoginView then MainShell
└── README.md                  # This documentation
```

---

## ⚙️ Setup Instructions

### 1. Clone the Repository

```powershell
git clone https://github.com/danielTongu/VMware-ESXI.git
cd VMware-ESXI
```

### 2. Unblock Scripts (Windows SmartScreen)

```powershell
Get-ChildItem -Recurse . | Unblock-File
```

### 3. (Optional) Install Pester for Unit Testing

```powershell
Install-Module Pester -Scope CurrentUser -Force
```

---

## 🚀 Usage

### 🖥️ Run the GUI

```powershell
cd VMware-ESXI
.\Main.ps1
```

* Sign in via the login screen.
* Navigate using the **left-hand menu**.
* Views are loaded into the **main content panel**.
* Use **Logout** to return to login and switch user.

---

## 🧱 Included Views

| View                 | Purpose                                        |
| -------------------- | ---------------------------------------------- |
| **Dashboard**        | Show host, VM, and network summary stats       |
| **Classes**          | Create/delete student VMs for a course         |
| **Virtual Machines** | Filterable grid: power, restart, remove VMs    |
| **Networks**         | Add/remove port groups (single or bulk)        |
| **Orphan Cleaner**   | Find and delete orphaned VM files on datastore |
| **Logs**             | View and refresh the latest VMware events      |
| **Logout**           | Signs out user and returns to login screen     |

---

## 🧩 Extending the App

### ➕ Add Backend Logic

1. Write your logic inside `VMwareModels.psm1`.
2. Keep functions clean and testable.

### ➕ Add a New View

1. Create `Views/YourFeatureView.ps1`.
2. Export a `Show-YourFeatureView -ContentPanel $panel` function.
3. Wire it into `MainView.ps1` navigation buttons and `Load-ViewIntoPanel` command list.

---

## 🧪 Testing

Unit-test logic in `VMwareModels.psm1` using Pester:

```powershell
Invoke-Pester -Script .\Tests\VMwareModels.Tests.ps1
```

For views, mock the WinForms `Panel` and verify controls/layout in Pester.

---

## 🤝 Contributing

1. Fork the repo and create a feature branch.
2. Write clear, commented code with Javadoc-style summaries.
3. Add or modify views and model logic as needed.
4. Submit a PR with a description and UI screenshots (if applicable).

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
