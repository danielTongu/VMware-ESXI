"""
dashboard.py
-------------
Displays a welcome dashboard and general instructions.
"""

import customtkinter as ctk

class Dashboard(ctk.CTkFrame):
    def __init__(self, master):
        super().__init__(master)
        self.pack(fill="both", expand=True)
        ctk.CTkLabel(self, text="Welcome to the VMware ESXi GUI", font=("Segoe UI", 24)).pack(pady=20)
        instructions = (
            "This GUI facilitates the management of classes, students, and VMs on a central ESXi server.\n\n"
            "Use the sidebar to:\n"
            "  - Build or delete student folders, VMs, and networks (per class)\n"
            "  - Manage individual VMs (power on/off, restart)\n"
            "  - View all powered on VMs with IP addresses\n"
            "  - Remove specific VMs from a class\n\n"
            "Ensure that the required scripts and server prerequisites are in place."
        )
        ctk.CTkLabel(self, text=instructions, font=("Segoe UI", 14), justify="left").pack(pady=10)