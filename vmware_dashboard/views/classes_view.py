"""
classes_view.py
----------------
Provides the interface to manage classes.
Allows:
  - Loading classes from storage
  - Displaying classes as clickable entries
  - Adding a new class via a dialog (ClassEditDialog)
  - Editing an existing class (opens the same dialog pre-populated)
  - Saving the current classes to persistent storage
Duplicate class names are rejected.
"""


import customtkinter as ctk


from vmware_dashboard.models.classgroup import ClassGroup
from vmware_dashboard.utils.storage import load_classes, save_classes
from vmware_dashboard.components.detail_views import ClassEditDialog


class ClassesView(ctk.CTkFrame):
    def __init__(self, master):
        super().__init__(master)
        self.pack(fill="both", expand=True)

        ctk.CTkLabel(self, text="Classes", font=("Segoe UI", 24)).pack(pady=10)

        self.list_frame = ctk.CTkFrame(self)
        self.list_frame.pack(fill="both", expand=True, pady=10)

        self.control_frame = ctk.CTkFrame(self)
        self.control_frame.pack(pady=10)
        ctk.CTkButton(self.control_frame, text="Add New Class", command=self.open_add_class_dialog).pack(side="left",
                                                                                                         padx=5)
        ctk.CTkButton(self.control_frame, text="Save Classes", command=self.save_data).pack(side="left", padx=5)

        self.class_objects = load_classes() or []
        self.refresh_list()



    def refresh_list(self):
        """Clears and repopulates the class list as clickable buttons."""
        for widget in self.list_frame.winfo_children():
            widget.destroy()
        for idx, cls_obj in enumerate(self.class_objects):
            btn = ctk.CTkButton(self.list_frame, text=str(cls_obj),
                                command=lambda i=idx: self.open_edit_class_dialog(i))
            btn.pack(fill="x", padx=10, pady=2)



    def open_add_class_dialog(self):
        """Opens the dialog for adding a new class."""
        ClassEditDialog(self, callback=self.add_class)



    def add_class(self, class_data: dict):
        """
        Callback for adding a new class.

        Args:
            class_data (dict): Contains 'name', 'quarter', 'course', 'students', 'template',
                               'datastore', 'network_adapters'
        """
        new_name = class_data['name']
        for existing in self.class_objects:
            if existing.name.lower() == new_name.lower():
                print("Duplicate class name detected; class not added.")
                return
        new_class = ClassGroup(
            name=new_name,
            quarter=class_data['quarter'],
            course=class_data['course'],
            students=class_data['students'],
            template=class_data['template'],
            datastore=class_data['datastore'],
            network_adapters=class_data['network_adapters']
        )
        self.class_objects.append(new_class)
        self.refresh_list()



    def open_edit_class_dialog(self, index: int):
        """Opens the dialog to edit an existing class."""
        selected = self.class_objects[index]
        ClassEditDialog(self, callback=self.update_class, class_object=selected)



    def update_class(self, class_data: dict):
        """
        Callback for updating an existing class.

        Args:
            class_data (dict): Contains updated data with an 'original_name' key.
        """
        old_name = class_data['original_name']
        new_name = class_data['name']
        target = None
        for cls in self.class_objects:
            if cls.name == old_name:
                target = cls
                break
        if target is None:
            print("Error: Class not found; update aborted.")
            return
        if old_name.lower() != new_name.lower():
            for cls in self.class_objects:
                if cls != target and cls.name.lower() == new_name.lower():
                    print("Duplicate class name; update aborted.")
                    return
        target.name = new_name
        target.quarter = class_data['quarter']
        target.course = class_data['course']
        target.template = class_data['template']
        target.datastore = class_data['datastore']
        target.network_adapters = class_data['network_adapters']
        target.students = class_data['students']
        self.refresh_list()



    def save_data(self):
        """Saves current classes to disk."""
        save_classes(self.class_objects)
        ctk.CTkLabel(self, text="✅ Classes saved successfully!", font=("Segoe UI", 14)).pack(pady=5)