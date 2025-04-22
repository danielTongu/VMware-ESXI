"""
login_view.py
-------------
Prompt for CWU credentials. In mock mode, simply prints them.
"""

import customtkinter as ctk
from vmware_dashboard.utils.config import USE_MOCK
from vmware_dashboard.powershell_service import run_powershell_script

class LoginView(ctk.CTkFrame):
    def __init__(self, master, on_login):
        super().__init__(master)
        self.pack(padx=20, pady=20, fill="both", expand=True)
        ctk.CTkLabel(self, text="CWU Login", font=("Segoe UI", 18)).pack(pady=10)
        self.username = ctk.CTkEntry(self, placeholder_text="CWU\\username")
        self.username.pack(pady=5)
        self.password = ctk.CTkEntry(self, placeholder_text="Password", show="*")
        self.password.pack(pady=5)
        ctk.CTkButton(self, text="Login", command=lambda: self.attempt_login(on_login)).pack(pady=10)

    def attempt_login(self, on_login):
        user = self.username.get().strip()
        pwd  = self.password.get().strip()
        if not user or not pwd:
            print("Error: credentials required.")
            return
        if USE_MOCK:
            print(f"[MOCK] Logged in as {user}")
        else:
            # Real authentication via PowerShell
            out = run_powershell_script("GetCredentials.ps1", f"-Username '{user}' -Password '{pwd}'")
            print(out.strip())
        on_login(user)