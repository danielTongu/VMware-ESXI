"""
vm_tasks.py
------------
UI for VM power operations, toggles mock vs real scripts.
"""

import customtkinter as ctk
from vmware_dashboard.utils.config import USE_MOCK
from vmware_dashboard.powershell_service import run_powershell_script

class VMTasksView(ctk.CTkFrame):
    def __init__(self, master):
        super().__init__(master)
        self.pack(fill="both", expand=True, padx=20, pady=20)
        ctk.CTkLabel(self, text="VM Task Center", font=("Segoe UI", 20)).pack(pady=10)
        ctk.CTkButton(self, text="Power ON all VMs", command=self.power_on).pack(pady=4)
        ctk.CTkButton(self, text="Power OFF all VMs", command=self.power_off).pack(pady=4)
        ctk.CTkButton(self, text="Restart all VMs", command=self.restart).pack(pady=4)

    def power_on(self):
        if USE_MOCK:
            print("[MOCK] Powering on all VMs")
        else:
            print(run_powershell_script("PowerOnAllVMs.ps1"))

    def power_off(self):
        if USE_MOCK:
            print("[MOCK] Powering off all VMs")
        else:
            print(run_powershell_script("PowerOffAllVMs.ps1"))

    def restart(self):
        if USE_MOCK:
            print("[MOCK] Restarting all VMs")
        else:
            print(run_powershell_script("RestartAllVMs.ps1"))