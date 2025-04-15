"""
logs_view.py
-------------
Displays logs and output from PowerShell scripts.
For demonstration, a placeholder log is shown.
In production, this view may execute a script to gather current VM IP addresses or other info.
"""

import customtkinter as ctk

class LogsView(ctk.CTkFrame):
    def __init__(self, master):
        super().__init__(master)
        self.pack(fill="both", expand=True)
        ctk.CTkLabel(self, text="Logs / VM Info", font=("Segoe UI", 24)).pack(pady=10)
        self.log_text = ctk.CTkTextbox(self, height=400, width=800)
        self.log_text.pack(pady=10)
        # Placeholder log text.
        placeholder = (
            "----- Active VMs -----\n"
            "VM1 - IP: 192.168.1.101\n"
            "VM2 - IP: 192.168.1.102\n"
            "----------------------\n"
            "No errors encountered."
        )
        self.log_text.insert("0.0", placeholder)