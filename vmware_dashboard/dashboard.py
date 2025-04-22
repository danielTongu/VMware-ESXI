"""
dashboard.py
-------------
Sidebar navigation and dynamic content area.
Switches between Classes, Templates, Students, and VM Tasks.
"""

import customtkinter as ctk
from vmware_dashboard.views.classes_view import ClassesView
from vmware_dashboard.views.template_manager import TemplateManagerView
from vmware_dashboard.views.student_folders import StudentFoldersView
from vmware_dashboard.views.vm_tasks import VMTasksView

class Dashboard(ctk.CTkFrame):
    def __init__(self, master):
        super().__init__(master)
        self.pack(fill="both", expand=True)
        # Sidebar
        self.sidebar = ctk.CTkFrame(self, width=200)
        self.sidebar.pack(side="left", fill="y")
        # Content area
        self.content_area = ctk.CTkFrame(self)
        self.content_area.pack(side="right", fill="both", expand=True)
        # Sidebar title
        ctk.CTkLabel(self.sidebar, text="VMware Tools", font=("Segoe UI", 18)).pack(pady=20)
        # Nav items
        nav_items = [
            ("Classes", ClassesView),
            ("Templates", TemplateManagerView),
            ("Students", StudentFoldersView),
            ("VM Tasks", VMTasksView),
        ]
        for label, ViewClass in nav_items:
            ctk.CTkButton(self.sidebar, text=label,
                          command=lambda v=ViewClass: self.show_view(v)
                         ).pack(pady=5, padx=10)
        self.current_view = None
        self.show_view(ClassesView)

    def show_view(self, ViewClass):
        if self.current_view:
            self.current_view.destroy()
        self.current_view = ViewClass(self.content_area)
        self.current_view.pack(fill="both", expand=True)