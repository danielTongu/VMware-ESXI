"""
main.py
---------
Entry point for the VMware ESXi GUI application.
Creates the main window with a sidebar for navigation to:
  - Dashboard
  - Classes (for adding, editing, and deleting classes and their resource operations)
  - VMs (for managing virtual machine lifecycle)
  - Logs (for viewing VM and operation logs)
"""

import customtkinter as ctk

from vmware_dashboard.views.dashboard import Dashboard
from vmware_dashboard.views.classes_view import ClassesView
from vmware_dashboard.views.vms_view import VMsView
from vmware_dashboard.views.logs_view import LogsView

# Set appearance and theme.
ctk.set_appearance_mode("light")       # Options: "light", "dark", "system"
ctk.set_default_color_theme("blue")    # Options: "blue", "green", "dark-blue", etc.

class VMwareESXiApp(ctk.CTk):
    def __init__(self):
        super().__init__()
        self.title("VMware ESXi GUI")
        self.geometry("1000x600")

        # Sidebar for navigation.
        self.sidebar = ctk.CTkFrame(self, width=200)
        self.sidebar.pack(side="left", fill="y")

        ctk.CTkLabel(self.sidebar, text="Menu", font=("Segoe UI", 20)).pack(pady=20)
        ctk.CTkButton(self.sidebar, text="Dashboard", command=self.show_dashboard).pack(pady=10, padx=20)
        ctk.CTkButton(self.sidebar, text="Classes", command=self.show_classes).pack(pady=10, padx=20)
        ctk.CTkButton(self.sidebar, text="VMs", command=self.show_vms).pack(pady=10, padx=20)
        ctk.CTkButton(self.sidebar, text="Logs", command=self.show_logs).pack(pady=10, padx=20)
        ctk.CTkButton(self.sidebar, text="Exit", command=self.quit).pack(side="bottom", pady=20, padx=20)

        # Main frame to load views.
        self.main_frame = ctk.CTkFrame(self)
        self.main_frame.pack(side="left", fill="both", expand=True)
        self.active_view = None
        self.show_dashboard()  # Start with the Dashboard.

    def clear_view(self):
        """Destroys the currently active view."""
        if self.active_view:
            self.active_view.destroy()

    def show_dashboard(self):
        """Loads the Dashboard view."""
        self.clear_view()
        self.active_view = Dashboard(self.main_frame)

    def show_classes(self):
        """Loads the Classes view."""
        self.clear_view()
        self.active_view = ClassesView(self.main_frame)

    def show_vms(self):
        """Loads the VMs view."""
        self.clear_view()
        self.active_view = VMsView(self.main_frame)

    def show_logs(self):
        """Loads the Logs view."""
        self.clear_view()
        self.active_view = LogsView(self.main_frame)

if __name__ == "__main__":
    app = VMwareESXiApp()
    app.mainloop()