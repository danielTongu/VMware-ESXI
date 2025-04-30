# VMware ESXi Dashboard

A modular **PowerShell WinForms GUI** for managing VMware ESXi resources in a classroom or training lab.  
It wraps your existing ESXi automation scripts (VMs, classes, networks, reports) into a unified, interactive interface with login and dynamic navigation.

---

## 🗂️ Project Structure

```text
VMware-ESXI/
├── Main.ps1                  # Entry point: shows login, then main UI
├── VMwareModels.psm1         # Core classes, helpers (VMwareVM, CourseManager, etc.)
├── Views/
│   ├── MainView.ps1          # UI shell: navigation, content panel, logout
│   ├── LoginView.ps1         # Login dialog
│   ├── DashboardView.ps1     # Welcome screen + host/VM/network stats
│   ├── ClassManagerView.ps1  # Create/delete class VMs
│   ├── NetworkManagerView.ps1# Add/remove port groups (bulk + single)
│   ├── VMsView.ps1           # Grid: list, filter, power on/off, remove VMs
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

- Sign in via the login screen.
- Navigate using the **left-hand menu**.
- Views are loaded into the **main content panel**.
- Use **Logout** to return to login and switch user.

---

## 🧱 Included Views

| View              | Purpose                                        |
|-------------------|------------------------------------------------|
| **Dashboard**      | Show host, VM, and network summary stats       |
| **Classes**        | Create/delete student VMs for a course         |
| **Virtual Machines** | Filterable grid: power, restart, remove VMs  |
| **Networks**       | Add/remove port groups (single or bulk)        |
| **Logout**         | Signs out user and returns to login screen     |

---

## 🧩 Extending the App

### ➕ Add Backend Logic

1. Write your logic inside `VMwareModels.psm1`.
2. Keep functions clean and testable.

### ➕ Add a New View

1. Create `Views/NewFeatureView.ps1`.
2. It must export a `Show-View -ParentPanel $panel` function.
3. Wire it into `Views/MainView.ps1` navigation.

---

## 🧪 Testing

You can unit-test logic in `VMwareModels.psm1` using Pester:

```powershell
Invoke-Pester -Script .\Tests\VMwareModels.Tests.ps1
```

For views, use a mock WinForms `Panel` object and test control creation/layout if needed.

---

## 🤝 Contributing

1. Fork the repo and create a feature branch.
2. Write clear, commented code with Javadoc-style summaries.
3. Add or modify views and model logic as needed.
4. Submit a PR with a description and screenshots (if UI-related).

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
