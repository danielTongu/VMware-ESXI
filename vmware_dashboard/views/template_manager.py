"""
template_manager.py
-------------------
Displays VM templates via mock_data or a PowerShell script.
"""

import customtkinter as ctk
from vmware_dashboard.utils.config import USE_MOCK
from vmware_dashboard.utils.mock_data import get_mock_templates
from vmware_dashboard.powershell_service import run_powershell_script

class TemplateManagerView(ctk.CTkFrame):
    def __init__(self, master):
        super().__init__(master)
        self.pack(fill="both", expand=True, padx=20, pady=20)
        ctk.CTkLabel(self, text="Template Manager", font=("Segoe UI", 20)).pack(pady=10)
        if USE_MOCK:
            self.templates = get_mock_templates()
        else:
            out = run_powershell_script("ListTemplates.ps1")
            self.templates = out.splitlines()
        for tpl in self.templates:
            ctk.CTkLabel(self, text=tpl, font=("Segoe UI", 14)).pack(pady=4)