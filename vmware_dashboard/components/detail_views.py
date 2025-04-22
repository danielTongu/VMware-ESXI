"""
detail_views.py
------------------
Dialogs for detailed management of Classes, Students, and VMs.
Supports both mock and production modes via the USE_MOCK flag.
Includes:
  - ClassEditDialog: add/edit a class, configure VMs, run advanced operations
  - StudentDetailView: view/edit/delete a student
  - VMDetailView: view/edit/delete/toggle-power a VM
"""

import tkinter as tk
import customtkinter as ctk
from vmware_dashboard.utils.config import USE_MOCK
from vmware_dashboard.powershell_service import run_powershell_script

if USE_MOCK:
    from vmware_dashboard.utils.mock_data import (
        get_mock_templates,
        get_mock_datastores,
        get_mock_adapters
    )

# Pixel width threshold for responsive layout
RESPONSIVE_THRESHOLD = 700


class ClassEditDialog(ctk.CTkToplevel):
    """
    Dialog for adding or editing a class.
    - Dynamic title: "Edit Class: {name}" when editing, "Add Class" otherwise.
    - Scrollable content with both horizontal and vertical scrollbars.
    - Pre-populates fields when class_object is provided.
    - Buttons to Save, Delete (if editing), and run advanced operations.
    """

    def __init__(self, master, callback, class_object=None):
        """
        Initialize the dialog.

        :param master:       Parent Tk container.
        :param callback:     Function to call with a data dict on Save or Delete.
        :param class_object: Optional existing ClassGroup for editing.
        """
        super().__init__(master)
        # Set window title
        if class_object:
            self.title(f"Edit Class: {class_object.name}")
        else:
            self.title("Add Class")

        self.callback = callback
        self.class_object = class_object
        self.original_name = ""

        # Outer frame to hold canvas and scrollbars
        outer = ctk.CTkFrame(self)
        outer.pack(fill="both", expand=True)

        # Vertical scrollbar
        vbar = tk.Scrollbar(outer, orient="vertical")
        vbar.pack(side="right", fill="y")
        # Horizontal scrollbar
        hbar = tk.Scrollbar(outer, orient="horizontal")
        hbar.pack(side="bottom", fill="x")

        # Canvas for scrollable content
        self._canvas = tk.Canvas(
            outer,
            yscrollcommand=vbar.set,
            xscrollcommand=hbar.set
        )
        self._canvas.pack(side="left", fill="both", expand=True)

        # Configure scrollbars
        vbar.config(command=self._canvas.yview)
        hbar.config(command=self._canvas.xview)

        # Inner frame inside canvas
        self.container = ctk.CTkFrame(self._canvas)
        self._win_id = self._canvas.create_window((0, 0), window=self.container, anchor="nw")

        # Bind to update scroll region and width
        self.container.bind("<Configure>", self._on_frame_configure)
        self._canvas.bind("<Configure>", self._on_canvas_configure)

        # Section frames
        self.basic_frame  = ctk.CTkFrame(self.container, border_width=2, corner_radius=8)
        self.config_frame = ctk.CTkFrame(self.container, border_width=2, corner_radius=8)
        self.adv_frame    = ctk.CTkFrame(self.container, border_width=2, corner_radius=8)
        self.action_frame = ctk.CTkFrame(self.container)

        # Build UI
        self._create_basic_section()
        self._create_config_section()
        self._create_advanced_section()
        self._create_action_buttons()

        # Layout sections
        self._setup_layout()
        self.bind("<Configure>", self._adjust_layout)

        # Prepopulate if editing
        if class_object:
            self._prepopulate_fields()


    def _on_frame_configure(self, event):
        """Update scrollable region when inner frame size changes."""
        self._canvas.configure(scrollregion=self._canvas.bbox("all"))


    def _on_canvas_configure(self, event):
        """Adjust inner frame width to match the canvas width."""
        self._canvas.itemconfig(self._win_id, width=event.width)


    def _create_basic_section(self):
        """Create widgets for basic class information."""
        ctk.CTkLabel(self.basic_frame, text="Basic Info", font=("Segoe UI", 16, "bold")).pack(
            anchor="w", pady=(10,5), padx=5
        )
        self.name_entry = ctk.CTkEntry(self.basic_frame, placeholder_text="Class Name")
        self.name_entry.pack(fill="x", pady=5, padx=5)
        self.quarter_entry = ctk.CTkEntry(self.basic_frame, placeholder_text="Quarter/Semester")
        self.quarter_entry.pack(fill="x", pady=5, padx=5)
        self.course_entry = ctk.CTkEntry(self.basic_frame, placeholder_text="Course Code")
        self.course_entry.pack(fill="x", pady=5, padx=5)

        ctk.CTkLabel(self.basic_frame,
                     text="Student Usernames (one per line)",
                     font=("Segoe UI", 12)
        ).pack(anchor="w", pady=(10,2), padx=5)
        self.students_text = ctk.CTkTextbox(self.basic_frame, height=120, width=400)
        self.students_text.pack(fill="x", pady=5, padx=5)


    def _create_config_section(self):
        """Create widgets for VM template, datastore, and network adapters."""
        ctk.CTkLabel(self.config_frame, text="VM Configuration", font=("Segoe UI", 16, "bold")).grid(
            row=0, column=0, columnspan=2, pady=(10,5), padx=5, sticky="w"
        )

        # Templates dropdown
        if USE_MOCK:
            templates = get_mock_templates()
        else:
            out = run_powershell_script("ListTemplates.ps1")
            templates = out.splitlines()
        ctk.CTkLabel(self.config_frame, text="Template", font=("Segoe UI", 12)).grid(
            row=1, column=0, pady=2, padx=5, sticky="w"
        )
        self.template_var = ctk.StringVar(value=templates[0])
        ctk.CTkOptionMenu(self.config_frame, values=templates, variable=self.template_var).grid(
            row=1, column=1, pady=2, padx=5, sticky="we"
        )

        # Datastore dropdown
        if USE_MOCK:
            datastores = get_mock_datastores()
        else:
            out = run_powershell_script("ListDatastores.ps1")
            datastores = out.splitlines()
        ctk.CTkLabel(self.config_frame, text="Datastore", font=("Segoe UI", 12)).grid(
            row=2, column=0, pady=2, padx=5, sticky="w"
        )
        self.datastore_var = ctk.StringVar(value=datastores[0])
        ctk.CTkOptionMenu(self.config_frame, values=datastores, variable=self.datastore_var).grid(
            row=2, column=1, pady=2, padx=5, sticky="we"
        )

        # Network adapters
        if USE_MOCK:
            adapters = get_mock_adapters()
        else:
            adapters = ["Instructor", "NAT", "Inside"]
        ctk.CTkLabel(self.config_frame, text="Network Adapters", font=("Segoe UI", 12)).grid(
            row=3, column=0, pady=2, padx=5, sticky="w"
        )
        frame = ctk.CTkFrame(self.config_frame)
        frame.grid(row=3, column=1, pady=2, padx=5, sticky="we")
        self.adapter_vars = {}
        for idx, opt in enumerate(adapters):
            var = ctk.BooleanVar()
            ctk.CTkCheckBox(frame, text=opt, variable=var).grid(row=0, column=idx, padx=5)
            self.adapter_vars[opt] = var


    def _create_advanced_section(self):
        """Create widgets for advanced operations (specific student, VM actions)."""
        ctk.CTkLabel(self.adv_frame, text="Advanced Operations", font=("Segoe UI", 16, "bold")).grid(
            row=0, column=0, columnspan=2, pady=(10,5), padx=5, sticky="w"
        )

        ctk.CTkLabel(self.adv_frame, text="Specific Student", font=("Segoe UI", 12)).grid(
            row=1, column=0, pady=2, padx=5, sticky="w"
        )
        self.specific_student_entry = ctk.CTkEntry(self.adv_frame, placeholder_text="Username")
        self.specific_student_entry.grid(row=1, column=1, pady=2, padx=5, sticky="we")

        ctk.CTkLabel(self.adv_frame, text="Target VM Name", font=("Segoe UI", 12)).grid(
            row=2, column=0, pady=2, padx=5, sticky="w"
        )
        self.target_vm_entry = ctk.CTkEntry(self.adv_frame, placeholder_text="VM Name")
        self.target_vm_entry.grid(row=2, column=1, pady=2, padx=5, sticky="we")

        ops = ctk.CTkFrame(self.adv_frame)
        ops.grid(row=3, column=0, columnspan=2, pady=10, padx=5)
        # Advanced operation buttons
        ctk.CTkButton(ops, text="Build All",    command=self.build_all_resources).grid(row=0, column=0, padx=5, pady=5)
        ctk.CTkButton(ops, text="Build Single", command=self.build_single_resource).grid(row=0, column=1, padx=5, pady=5)
        ctk.CTkButton(ops, text="Delete All",   fg_color="red", command=self.delete_all_resources).grid(row=0, column=2, padx=5, pady=5)
        ctk.CTkButton(ops, text="Restart All",  command=self.restart_all_vms).grid(row=1, column=0, padx=5, pady=5)
        ctk.CTkButton(ops, text="Remove VM",    fg_color="red", command=self.remove_specific_vm).grid(row=1, column=1, padx=5, pady=5)
        ctk.CTkButton(ops, text="Power On VM",  command=self.power_on_specific_vm).grid(row=1, column=2, padx=5, pady=5)
        ctk.CTkButton(ops, text="Power Off VM", command=self.power_off_specific_vm).grid(row=2, column=0, padx=5, pady=5)


    def _create_action_buttons(self):
        """Create Save and Delete (if editing) buttons."""
        self.save_btn = ctk.CTkButton(self.action_frame, text="Save", command=self.submit)
        self.save_btn.grid(row=0, column=0, padx=10, pady=10)
        if self.class_object:
            self.delete_btn = ctk.CTkButton(
                self.action_frame, text="Delete", fg_color="red", command=self.delete_class
            )
            self.delete_btn.grid(row=0, column=1, padx=10, pady=10)


    def _setup_layout(self):
        """Configure grid positions for each section frame."""
        self.container.columnconfigure(0, weight=1, uniform="grp")
        self.container.columnconfigure(1, weight=1, uniform="grp")
        self.basic_frame.grid(row=0, column=0, padx=10, pady=10, sticky="nsew")
        self.config_frame.grid(row=0, column=1, padx=10, pady=10, sticky="nsew")
        self.adv_frame.grid(row=1, column=0, columnspan=2, padx=10, pady=10, sticky="nsew")
        self.action_frame.grid(row=2, column=0, columnspan=2, pady=(20,10))


    def _adjust_layout(self, event):
        """Switch between side-by-side and stacked layouts based on width."""
        w = self.winfo_width()
        if w < RESPONSIVE_THRESHOLD:
            self.basic_frame.grid(row=0, column=0)
            self.config_frame.grid(row=1, column=0)
            self.adv_frame.grid(row=2, column=0)
            self.action_frame.grid(row=3, column=0)
        else:
            self.basic_frame.grid(row=0, column=0)
            self.config_frame.grid(row=0, column=1)
            self.adv_frame.grid(row=1, column=0, columnspan=2)
            self.action_frame.grid(row=2, column=0, columnspan=2)


    def _prepopulate_fields(self):
        """Fill all fields with data from class_object when editing."""
        c = self.class_object
        self.name_entry.insert(0, c.name)
        self.quarter_entry.insert(0, c.quarter)
        self.course_entry.insert(0, c.course)
        self.students_text.insert("0.0", "\n".join(c.students))
        self.original_name = c.name

        self.template_var.set(c.template)
        self.datastore_var.set(c.datastore)
        for net in c.network_adapters:
            if net in self.adapter_vars:
                self.adapter_vars[net].set(True)


    def submit(self):
        """
        Collect inputs, validate required fields, and invoke callback with class data dict.
        """
        name     = self.name_entry.get().strip()
        quarter  = self.quarter_entry.get().strip()
        course   = self.course_entry.get().strip()
        students = [s.strip() for s in self.students_text.get("0.0","end").splitlines() if s.strip()]

        if not (name and quarter and students):
            print("Error: Missing class name, quarter, or students.")
            return

        data = {
            "original_name":    self.original_name,
            "name":             name,
            "quarter":          quarter,
            "course":           course,
            "students":         students,
            "template":         self.template_var.get(),
            "datastore":        self.datastore_var.get(),
            "network_adapters": [a for a,v in self.adapter_vars.items() if v.get()],
            "specific_student": self.specific_student_entry.get().strip(),
            "target_vm":        self.target_vm_entry.get().strip()
        }
        self.callback(data)
        self.destroy()


    def delete_class(self):
        """Notify parent to delete this class."""
        self.callback({"original_name": self.original_name, "delete": True})
        self.destroy()


    # --- Advanced Operation Handlers ---

    def build_all_resources(self):
        """
        Build folders, VMs, and networks for all students in the class.
        Calls createStudentFolders.ps1 with appropriate args.
        """
        args = (
            f"-ClassName '{self.class_object.name}' "
            f"-VMTemplate '{self.template_var.get()}' "
            f"-Datastore '{self.datastore_var.get()}' "
            f"-AdapterTypes '{','.join([a for a,v in self.adapter_vars.items() if v.get()])}'"
        )
        result = run_powershell_script("createStudentFolders.ps1", args)
        self.show_message("Build All Resources", result)


    def build_single_resource(self):
        """
        Build folder, VM, and network for a single student.
        Requires specific_student_entry to be filled.
        """
        student = self.specific_student_entry.get().strip()
        if not student:
            self.show_message("Error", "Please enter a student username.")
            return
        args = (
            f"-ClassName '{self.class_object.name}' "
            f"-SingleStudent '{student}' "
            f"-VMTemplate '{self.template_var.get()}' "
            f"-Datastore '{self.datastore_var.get()}' "
            f"-AdapterTypes '{','.join([a for a,v in self.adapter_vars.items() if v.get()])}'"
        )
        result = run_powershell_script("createStudentFolders.ps1", args)
        self.show_message("Build Single Resource", result)


    def delete_all_resources(self):
        """Delete all student folders, VMs, and networks for the class."""
        args   = f"-ClassName '{self.class_object.name}' -DeleteAll $true"
        result = run_powershell_script("createStudentFolders.ps1", args)
        self.show_message("Delete All Resources", result)


    def restart_all_vms(self):
        """Restart all powered-on VMs for the class."""
        args   = f"-ClassName '{self.class_object.name}' -RestartAll $true"
        result = run_powershell_script("VmFunctions.psm1", args)
        self.show_message("Restart All VMs", result)


    def remove_specific_vm(self):
        """Remove a specific VM from all students in the class."""
        vm = self.target_vm_entry.get().strip()
        if not vm:
            self.show_message("Error", "Please enter a VM name to remove.")
            return
        args   = f"-ClassName '{self.class_object.name}' -RemoveVM '{vm}'"
        result = run_powershell_script("VmFunctions.psm1", args)
        self.show_message("Remove Specific VM", result)


    def power_on_specific_vm(self):
        """Power on a specific VM for all students in the class."""
        vm = self.target_vm_entry.get().strip()
        if not vm:
            self.show_message("Error", "Please enter a VM name to power on.")
            return
        args   = f"-ClassName '{self.class_object.name}' -PowerOnVM '{vm}'"
        result = run_powershell_script("VmFunctions.psm1", args)
        self.show_message("Power On Specific VM", result)


    def power_off_specific_vm(self):
        """Power off a specific VM for all students in the class."""
        vm = self.target_vm_entry.get().strip()
        if not vm:
            self.show_message("Error", "Please enter a VM name to power off.")
            return
        args   = f"-ClassName '{self.class_object.name}' -PowerOffVM '{vm}'"
        result = run_powershell_script("VmFunctions.psm1", args)
        self.show_message("Power Off Specific VM", result)


    def show_message(self, title: str, message: str):
        """
        Display a simple message dialog.

        :param title:   Dialog title.
        :param message: Message content.
        """
        win = ctk.CTkToplevel(self)
        win.title(title)
        win.geometry("400x200")
        ctk.CTkLabel(win, text=message, wraplength=380).pack(pady=20)
        ctk.CTkButton(win, text="OK", command=win.destroy).pack(pady=10)


class StudentDetailView(ctk.CTkToplevel):
    """
    Dialog for viewing/editing/deleting a student.
    """

    def __init__(self, master, student_name, edit_callback, delete_callback):
        """
        :param master:          Parent container.
        :param student_name:    Username of the student.
        :param edit_callback:   Function to call for editing.
        :param delete_callback: Function to call for deletion.
        """
        super().__init__(master)
        self.title(f"Student Details: {student_name}")
        self.geometry("350x200")
        self.student_name = student_name
        self.edit_cb = edit_callback
        self.del_cb = delete_callback

        ctk.CTkLabel(self, text=f"Student: {student_name}", font=("Segoe UI", 18)).pack(pady=10)
        frame = ctk.CTkFrame(self)
        frame.pack(pady=20)
        ctk.CTkButton(frame, text="Edit Student", command=self._on_edit).pack(side="left", padx=5)
        ctk.CTkButton(frame, text="Delete Student", command=self._on_delete).pack(side="left", padx=5)

    def _on_edit(self):
        """Invoke edit callback and close."""
        self.edit_cb(self.student_name)
        self.destroy()

    def _on_delete(self):
        """Invoke delete callback and close."""
        self.del_cb(self.student_name)
        self.destroy()


class VMDetailView(ctk.CTkToplevel):
    """
    Dialog for viewing/editing/deleting and toggling power of a VM.
    """

    def __init__(self, master, vm_object, edit_callback, delete_callback, power_callback):
        """
        :param master:          Parent container.
        :param vm_object:       Dict or model containing VM details.
        :param edit_callback:   Function to call for editing.
        :param delete_callback: Function to call for deletion.
        :param power_callback:  Function to call to toggle power.
        """
        super().__init__(master)
        name = vm_object.get("Name", "Unknown")
        state = vm_object.get("PowerState", "Unknown")

        self.title(f"VM Details: {name}")
        self.geometry("400x250")
        self.vm = vm_object
        self.edit_cb = edit_callback
        self.del_cb = delete_callback
        self.pwr_cb = power_callback

        ctk.CTkLabel(self, text=f"VM: {name}", font=("Segoe UI", 18)).pack(pady=10)
        ctk.CTkLabel(self, text=f"State: {state}", font=("Segoe UI", 14)).pack(pady=5)

        frame = ctk.CTkFrame(self)
        frame.pack(pady=20)
        ctk.CTkButton(frame, text="Edit VM", command=self._on_edit).pack(side="left", padx=5)
        ctk.CTkButton(frame, text="Delete VM", command=self._on_delete).pack(side="left", padx=5)
        ctk.CTkButton(frame, text="Toggle Power", command=self._on_power).pack(side="left", padx=5)

    def _on_edit(self):
        """Invoke edit callback and close."""
        self.edit_cb(self.vm)
        self.destroy()

    def _on_delete(self):
        """Invoke delete callback and close."""
        self.del_cb(self.vm)
        self.destroy()

    def _on_power(self):
        """Invoke power-action callback and close."""
        self.pwr_cb(self.vm)
        self.destroy()