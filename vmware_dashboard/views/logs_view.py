"""
logs_view.py
-------------
Displays VM logs or powered-on VMs with IPs,
mock or via script.
"""

import customtkinter as ctk
from vmware_dashboard.utils.config import USE_MOCK
from vmware_dashboard.powershell_service import run_powershell_script

class LogsView(ctk.CTkFrame):
    def __init__(self, master):
        super().__init__(master)
        self.pack(fill="both", expand=True, padx=20, pady=20)
        ctk.CTkLabel(self, text="Logs / VM Info", font=("Segoe UI", 20)).pack(pady=10)
        self.box = ctk.CTkTextbox(self, height=400)
        self.box.pack(fill="both", expand=True)
        if USE_MOCK:
            text = "MOCK: VM1 - 192.168.1.10\nVM2 - 192.168.1.11"
        else:
            text = run_powershell_script("ShowAllPoweredOnVMs.ps1")
        self.box.insert("0.0", text)