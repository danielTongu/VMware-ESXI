"""
main.py
--------
Application entry point. Starts with login (mock or real),
then displays the Dashboard.
"""

import customtkinter as ctk
from vmware_dashboard.views.login_view import LoginView
from vmware_dashboard.dashboard import Dashboard
from vmware_dashboard.utils.config import USE_MOCK

class MainApp(ctk.CTk):
    def __init__(self):
        super(MainApp, self).__init__()
        self.geometry("1000x700")
        self.title("VMware ESXi Management Dashboard")
        self.current_frame = None
        # In production you might skip login if USE_MOCK is False and credentials are cached.
        self.show_login()

    def show_login(self):
        """Show login screen; passes callback to go to dashboard."""
        self.switch_frame(LoginView, on_login=self.show_dashboard)

    def show_dashboard(self, username=None):
        """Show the main Dashboard after login."""
        self.switch_frame(Dashboard)

    def switch_frame(self, FrameClass, **kwargs):
        """Destroy current frame and load a new one."""
        if self.current_frame is not None:
            self.current_frame.destroy()
        self.current_frame = FrameClass(self, **kwargs)
        self.current_frame.pack(fill="both", expand=True)

if __name__ == "__main__":
    ctk.set_appearance_mode("light")
    ctk.set_default_color_theme("blue")
    app = MainApp()
    app.mainloop()