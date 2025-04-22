"""
student_folders.py
------------------
Shows student folders with VMs, mock or via script.
"""

import customtkinter as ctk
from vmware_dashboard.utils.config import USE_MOCK
from vmware_dashboard.powershell_service import run_powershell_script
from vmware_dashboard.utils.mock_data import get_mock_classes

class StudentFoldersView(ctk.CTkFrame):
    def __init__(self, master):
        super().__init__(master)
        self.pack(fill="both", expand=True, padx=20, pady=20)
        ctk.CTkLabel(self, text="Student Folders", font=("Segoe UI", 20)).pack(pady=10)
        if USE_MOCK:
            classes = get_mock_classes()
            students = [s for c in classes for s in c['students']]
        else:
            out = run_powershell_script("ListStudentFolders.ps1")
            students = out.splitlines()
        for student in students:
            ctk.CTkLabel(self, text=f"{student} → VM1, VM2", font=("Segoe UI", 14)).pack(pady=4)