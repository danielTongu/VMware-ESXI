"""
classes_view.py
----------------
List/Add/Edit/Delete ClassGroup entries, toggling mock vs real storage.
"""

import customtkinter as ctk
from vmware_dashboard.utils.config import USE_MOCK
from vmware_dashboard.utils.storage import load_classes, save_classes
from vmware_dashboard.components.detail_views import ClassEditDialog

class ClassesView(ctk.CTkFrame):
    def __init__(self, master):
        super().__init__(master)
        self.pack(fill="both", expand=True, padx=20, pady=20)
        ctk.CTkLabel(self, text="Classes", font=("Segoe UI", 20)).pack(pady=10)
        self.class_list = load_classes()
        self.buttons = []
        self._render()
        ctk.CTkButton(self, text="Add New Class", command=self._add).pack(pady=10)
        ctk.CTkButton(self, text="Save Classes", command=self._save).pack(pady=5)

    def _render(self):
        for b in self.buttons:
            b.destroy()
        self.buttons.clear()
        for idx, cls in enumerate(self.class_list):
            b = ctk.CTkButton(self, text=f"{cls.name} ({len(cls.students)} students)",
                              command=lambda i=idx: self._edit(i))
            b.pack(pady=4)
            self.buttons.append(b)

    def _add(self):
        ClassEditDialog(self, callback=self._save_new)

    def _save_new(self, data):
        if 'delete' in data: return
        from vmware_dashboard.models.classgroup import ClassGroup
        cg = ClassGroup(
            name=data['name'],
            quarter=data['quarter'],
            course=data['course'],
            students=[s for s in data['students']],
            template=data['template'],
            datastore=data['datastore'],
            network_adapters=data['network_adapters']
        )
        self.class_list.append(cg)
        self._render()

    def _edit(self, idx):
        ClassEditDialog(self,
                        callback=lambda d: self._update(d, idx),
                        class_object=self.class_list[idx])

    def _update(self, data, idx):
        # Handle delete
        if data.get('delete'):
            del self.class_list[idx]
        else:
            cls = self.class_list[idx]
            cls.name = data['name']
            cls.quarter = data['quarter']
            cls.course = data['course']
            cls.students = data['students']
            cls.template = data['template']
            cls.datastore = data['datastore']
            cls.network_adapters = data['network_adapters']
        self._render()

    def _save(self):
        save_classes(self.class_list)