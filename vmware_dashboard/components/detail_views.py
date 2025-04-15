"""
detail_views.py
------------------
Contains detailed dialog windows for managing entities such as Classes.
Below is the ClassEditDialog, which is used to add or edit a class. This dialog collects:
  - Basic Information (Class Name, Quarter/Semester, Course Code, Student Usernames)
  - Configuration (VM Template, Datastore, and multiple Network Adapter selections)
  - Advanced operations parameters (specific student username and target VM name)
It includes a Save button as well as a Delete button (when in edit mode) to indicate that the
class should be deleted.
All widgets are arranged in a responsive, scrollable layout.
"""

import customtkinter as ctk
from vmware_dashboard.powershell_service import run_powershell_script

RESPONSIVE_THRESHOLD = 700  # Pixel width threshold for switching layout


class ClassEditDialog(ctk.CTkToplevel):
    def __init__(self, master, callback, class_object=None):
        """
        Initializes the ClassEditDialog.

        Args:
            master: The parent container.
            callback: Function to call with a dictionary of class data when saving.
                      The dictionary should include:
                        - 'original_name', 'name', 'quarter', 'course', 'students',
                          'template', 'datastore', 'network_adapters',
                          'specific_student', 'target_vm'
                        - Additionally, a key 'delete' may be present and set to True if the
                          class is to be deleted.
            class_object (optional): An existing class object (e.g., a ClassGroup instance)
                                      for editing; if provided, dialog fields are pre-populated.
        """
        super().__init__(master)
        self.callback = callback
        self.class_object = class_object
        self.title("Edit Class" if class_object else "Add Class")
        self.geometry("550x800")

        # Create a scrollable frame for all content.
        self.scroll_frame = ctk.CTkScrollableFrame(self, width=530, height=750)
        self.scroll_frame.pack(padx=10, pady=10, fill="both", expand=True)

        # Main container for organizing sections responsively.
        self.container = ctk.CTkFrame(self.scroll_frame)
        self.container.pack(fill="both", expand=True)

        # Section containers.
        self.basic_frame = ctk.CTkFrame(self.container, border_width=2, corner_radius=8)
        self.config_frame = ctk.CTkFrame(self.container, border_width=2, corner_radius=8)
        self.adv_frame = ctk.CTkFrame(self.container, border_width=2, corner_radius=8)

        self._create_basic_section()
        self._create_config_section()
        self._create_advanced_ops_section()

        # Action buttons frame.
        self.action_frame = ctk.CTkFrame(self.container)
        self.save_button = ctk.CTkButton(self.action_frame, text="Save", command=self.submit)
        self.save_button.grid(row=0, column=0, padx=10, pady=10)

        # If editing (class_object provided), include a Delete button.
        if class_object:
            self.delete_button = ctk.CTkButton(self.action_frame, text="Delete Class", fg_color="red",command=self.delete_class)
            self.delete_button.grid(row=0, column=1, padx=10, pady=10)

        # Set initial layout.
        self._setup_layout()
        self.bind("<Configure>", self._adjust_layout)

        self.original_name = ""
        if self.class_object:
            self._prepopulate_fields()

    def _create_basic_section(self):
        """Creates the Basic Information section."""
        header = ctk.CTkLabel(self.basic_frame, text="Basic Info", font=("Segoe UI", 16, "bold"))
        header.pack(anchor="w", pady=(10, 5), padx=5)

        self.name_entry = ctk.CTkEntry(self.basic_frame, placeholder_text="Class Name (e.g., CS101 - Intro)")
        self.name_entry.pack(fill="x", pady=5, padx=5)

        self.quarter_entry = ctk.CTkEntry(self.basic_frame, placeholder_text="Quarter (e.g., Fall 2024)")
        self.quarter_entry.pack(fill="x", pady=5, padx=5)

        self.course_entry = ctk.CTkEntry(self.basic_frame, placeholder_text="Course Code/Title (e.g., CS101)")
        self.course_entry.pack(fill="x", pady=5, padx=5)

        ctk.CTkLabel(self.basic_frame,text="Student Usernames (one per line)",font=("Segoe UI", 12)).pack(anchor="w",pady=(10, 2),padx=5)

        self.students_text = ctk.CTkTextbox(self.basic_frame, height=120, width=380)
        self.students_text.pack(pady=5, padx=5, fill="x")

    def _create_config_section(self):
        """Creates the Configuration section (VM Template, Datastore, Network Adapters)."""
        header = ctk.CTkLabel(self.config_frame, text="VM Configuration", font=("Segoe UI", 16, "bold"))
        header.grid(row=0, column=0, columnspan=2, pady=(10, 5), padx=5, sticky="w")

        ctk.CTkLabel(self.config_frame, text="VM Template", font=("Segoe UI", 12)).grid(row=1, column=0, pady=2, padx=5, sticky="w")

        self.template_options = ["Template A", "Template B", "Template C"]
        self.template_var = ctk.StringVar(value=self.template_options[0])
        self.template_menu = ctk.CTkOptionMenu(self.config_frame, values=self.template_options, variable=self.template_var)
        self.template_menu.grid(row=1, column=1, pady=2, padx=5, sticky="we")

        ctk.CTkLabel(self.config_frame, text="Datastore", font=("Segoe UI", 12)).grid(row=2, column=0, pady=2, padx=5, sticky="w")

        self.datastore_options = ["Datastore1", "Datastore2", "Datastore3"]
        self.datastore_var = ctk.StringVar(value=self.datastore_options[0])
        self.datastore_menu = ctk.CTkOptionMenu(self.config_frame, values=self.datastore_options, variable=self.datastore_var)
        self.datastore_menu.grid(row=2, column=1, pady=2, padx=5, sticky="we")

        ctk.CTkLabel(self.config_frame, text="Network Adapters", font=("Segoe UI", 12)).grid(row=3, column=0, pady=2, padx=5, sticky="w")

        self.adapter_opts = ["Instructor", "NAT", "Inside"]
        self.adapter_vars = {}
        adapter_frame = ctk.CTkFrame(self.config_frame)
        adapter_frame.grid(row=3, column=1, pady=2, padx=5, sticky="we")

        for idx, opt in enumerate(self.adapter_opts):
            var = ctk.BooleanVar(value=False)
            chk = ctk.CTkCheckBox(adapter_frame, text=opt, variable=var)
            chk.grid(row=0, column=idx, padx=5)
            self.adapter_vars[opt] = var

    def _create_advanced_ops_section(self):
        """Creates the Advanced Resource Operations section."""
        header = ctk.CTkLabel(self.adv_frame, text="Advanced Operations", font=("Segoe UI", 16, "bold"))
        header.grid(row=0, column=0, columnspan=2, pady=(10, 5), padx=5, sticky="w")

        ctk.CTkLabel(self.adv_frame, text="Specific Student Username", font=("Segoe UI", 12)).grid(row=1, column=0, pady=2, padx=5, sticky="w")

        self.specific_student_entry = ctk.CTkEntry(self.adv_frame, placeholder_text="e.g., student123")
        self.specific_student_entry.grid(row=1, column=1, pady=2, padx=5, sticky="we")

        ctk.CTkLabel(self.adv_frame, text="Target VM Name", font=("Segoe UI", 12)).grid(row=2, column=0, pady=2, padx=5, sticky="w")

        self.target_vm_entry = ctk.CTkEntry(self.adv_frame, placeholder_text="e.g., VM_Test")
        self.target_vm_entry.grid(row=2, column=1, pady=2, padx=5, sticky="we")

        # Create a sub-frame for operation buttons.
        ops_frame = ctk.CTkFrame(self.adv_frame)
        ops_frame.grid(row=3, column=0, columnspan=2, pady=10, padx=5, sticky="we")

        self.btn_build_all = ctk.CTkButton(ops_frame, text="Build All", command=self.build_all_resources)
        self.btn_build_all.grid(row=0, column=0, padx=5, pady=5)
        self.btn_build_single = ctk.CTkButton(ops_frame, text="Build Single", command=self.build_single_resource)
        self.btn_build_single.grid(row=0, column=1, padx=5, pady=5)
        self.btn_delete_all = ctk.CTkButton(ops_frame, text="Delete All", fg_color="red", command=self.delete_all_resources)
        self.btn_delete_all.grid(row=0, column=2, padx=5, pady=5)
        self.btn_restart_all = ctk.CTkButton(ops_frame, text="Restart All", command=self.restart_all_vms)
        self.btn_restart_all.grid(row=1, column=0, padx=5, pady=5)
        self.btn_remove_vm = ctk.CTkButton(ops_frame, text="Remove VM", fg_color="red", command=self.remove_specific_vm)
        self.btn_remove_vm.grid(row=1, column=1, padx=5, pady=5)
        self.btn_power_on_vm = ctk.CTkButton(ops_frame, text="Power On VM", command=self.power_on_specific_vm)
        self.btn_power_on_vm.grid(row=1, column=2, padx=5, pady=5)
        self.btn_power_off_vm = ctk.CTkButton(ops_frame, text="Power Off VM", command=self.power_off_specific_vm)
        self.btn_power_off_vm.grid(row=2, column=0, padx=5, pady=5)

    def _setup_layout(self):
        """
        Sets up the grid layout for the container.
        By default, Basic Info and Configuration are side by side (row 0),
        Advanced Operations are on row 1, and the action buttons on row 2.
        """
        self.container.columnconfigure(0, weight=1, uniform="group1")
        self.container.columnconfigure(1, weight=1, uniform="group1")
        self.basic_frame.grid(row=0, column=0, padx=10, pady=10, sticky="nsew")
        self.config_frame.grid(row=0, column=1, padx=10, pady=10, sticky="nsew")
        self.adv_frame.grid(row=1, column=0, columnspan=2, padx=10, pady=10, sticky="nsew")
        self.action_frame.grid(row=2, column=0, columnspan=2, pady=(20, 10))

    def _adjust_layout(self, event):
        """
        Adjusts the layout based on the current width.
        If the width is below RESPONSIVE_THRESHOLD, sections stack vertically.
        Otherwise, Basic and Configuration appear side by side.
        """
        current_width = self.winfo_width()

        if current_width < RESPONSIVE_THRESHOLD:
            self.container.columnconfigure(0, weight=1)
            self.basic_frame.grid_configure(row=0, column=0)
            self.config_frame.grid_configure(row=1, column=0)
            self.adv_frame.grid_configure(row=2, column=0)
            self.action_frame.grid_configure(row=3, column=0)
        else:
            self.container.columnconfigure(0, weight=1, uniform="group1")
            self.container.columnconfigure(1, weight=1, uniform="group1")
            self.basic_frame.grid_configure(row=0, column=0)
            self.config_frame.grid_configure(row=0, column=1)
            self.adv_frame.grid_configure(row=1, column=0, columnspan=2)
            self.action_frame.grid_configure(row=2, column=0, columnspan=2)

    def _prepopulate_fields(self):
        """
        Pre-fills fields using the provided class_object, if editing an existing class.
        """
        self.name_entry.insert("0", self.class_object.name)
        self.quarter_entry.insert("0", self.class_object.quarter)
        self.course_entry.insert("0", self.class_object.course)
        self.students_text.insert("0.0", "\n".join(self.class_object.students))

        if self.class_object.template in self.template_options:
            self.template_var.set(self.class_object.template)

        if self.class_object.datastore in self.datastore_options:
            self.datastore_var.set(self.class_object.datastore)

        if self.class_object.network_adapters:
            for adapter, var in self.adapter_vars.items():
                if adapter in self.class_object.network_adapters:
                    var.set(True)

        self.original_name = self.class_object.name

    def submit(self):
        """
        Collects input values, validates required fields, and calls the callback with a data dictionary.
        The dictionary includes keys: 'original_name', 'name', 'quarter', 'course', 'students',
        'template', 'datastore', 'network_adapters', 'specific_student', and 'target_vm'.
        """
        name = self.name_entry.get().strip()
        quarter = self.quarter_entry.get().strip()
        course = self.course_entry.get().strip()
        students = [line.strip() for line in self.students_text.get("0.0", "end").splitlines() if line.strip()]

        if not name or not quarter or not students:
            print("Error: Class Name, Quarter, and at least one student are required.")
            return

        template = self.template_var.get().strip()
        datastore = self.datastore_var.get().strip()
        selected_adapters = [adapter for adapter, var in self.adapter_vars.items() if var.get()]
        specific_student = self.specific_student_entry.get().strip()
        target_vm = self.target_vm_entry.get().strip()

        data = {
            'original_name': self.original_name,
            'name': name,
            'quarter': quarter,
            'course': course,
            'students': students,
            'template': template,
            'datastore': datastore,
            'network_adapters': selected_adapters,
            'specific_student': specific_student,
            'target_vm': target_vm
        }
        self.callback(data)
        self.destroy()

    # --- Delete Functionality ---
    def delete_class(self):
        """
        Informs the parent via the callback that the class should be deleted
        by including a 'delete' flag, then closes the dialog.
        """
        data = {
            'original_name': self.original_name,
            'delete': True,
        }
        self.callback(data)
        self.destroy()

    # --- Advanced Operations Handlers ---

    def build_all_resources(self):
        """Builds all resources for the class by calling a PowerShell script."""
        args = (
            f"-ClassName '{self.class_object.name}' "
            f"-VMTemplate '{self.template_var.get()}' "
            f"-Datastore '{self.datastore_var.get()}' "
            f"-AdapterTypes '{','.join([a for a, var in self.adapter_vars.items() if var.get()])}' "
        )

        result = run_powershell_script("createStudentFolders.ps1", args)
        self.show_message("Build All Resources", result)

    def build_single_resource(self):
        """Builds resources for a single student using the specified student username."""
        student = self.specific_student_entry.get().strip()
        if not student:
            self.show_message("Error", "Please enter a specific student username.")
            return

        args = (
            f"-ClassName '{self.class_object.name}' "
            f"-SingleStudent '{student}' "
            f"-VMTemplate '{self.template_var.get()}' "
            f"-Datastore '{self.datastore_var.get()}' "
            f"-AdapterTypes '{','.join([a for a, var in self.adapter_vars.items() if var.get()])}' "
        )

        result = run_powershell_script("createStudentFolders.ps1", args)
        self.show_message("Build Single Resource", result)

    def delete_all_resources(self):
        """Deletes all resources for the class."""
        args = f"-ClassName '{self.class_object.name}' -DeleteAll $true"
        result = run_powershell_script("createStudentFolders.ps1", args)
        self.show_message("Delete All Resources", result)

    def restart_all_vms(self):
        """Restarts all powered-on VMs for the class."""
        args = f"-ClassName '{self.class_object.name}' -RestartAll $true"
        result = run_powershell_script("VmFunctions.psm1", args)
        self.show_message("Restart All VMs", result)

    def remove_specific_vm(self):
        """Removes a specific VM (by name) from all students in the class."""
        target_vm = self.target_vm_entry.get().strip()
        if not target_vm:
            self.show_message("Error", "Enter a target VM name to remove.")
            return

        args = f"-ClassName '{self.class_object.name}' -RemoveVM '{target_vm}'"
        result = run_powershell_script("VmFunctions.psm1", args)
        self.show_message("Remove Specific VM", result)

    def power_on_specific_vm(self):
        """Powers on a specific VM (by name) for all students in the class."""
        target_vm = self.target_vm_entry.get().strip()
        if not target_vm:
            self.show_message("Error", "Enter a target VM name to power on.")
            return

        args = f"-ClassName '{self.class_object.name}' -PowerOnVM '{target_vm}'"
        result = run_powershell_script("VmFunctions.psm1", args)
        self.show_message("Power On Specific VM", result)

    def power_off_specific_vm(self):
        """Powers off a specific VM (by name) for all students in the class."""
        target_vm = self.target_vm_entry.get().strip()
        if not target_vm:
            self.show_message("Error", "Enter a target VM name to power off.")
            return

        args = f"-ClassName '{self.class_object.name}' -PowerOffVM '{target_vm}'"
        result = run_powershell_script("VmFunctions.psm1", args)
        self.show_message("Power Off Specific VM", result)

    def show_message(self, title: str, message: str):
        """
        Opens a message dialog displaying the provided message.

        Args:
            title (str): The title of the dialog.
            message (str): The message content to display.
        """
        msg_window = ctk.CTkToplevel(self)
        msg_window.title(title)
        msg_window.geometry("400x200")
        ctk.CTkLabel(msg_window, text=message, wraplength=380).pack(pady=20)
        ctk.CTkButton(msg_window, text="OK", command=msg_window.destroy).pack(pady=10)