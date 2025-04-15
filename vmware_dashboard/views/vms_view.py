"""
vms_view.py
------------
Provides the interface for managing Virtual Machines.
Allows:
  - Listing VMs (fetched from PowerShell via run_powershell_script)
  - Powering on/off VMs
  - Restarting all VMs
  - Removing a specific VM from all students in a class
  - Power on/off specific VMs for a class
In a production system, VM information would be retrieved with PowerCLI.
"""

import customtkinter as ctk
from vmware_dashboard.models.vm_info import VMInfo
from vmware_dashboard.powershell_service import run_powershell_script

class VMsView(ctk.CTkFrame):
    def __init__(self, master):
        super().__init__(master)
        self.pack(fill="both", expand=True)
        ctk.CTkLabel(self, text="Virtual Machines", font=("Segoe UI", 24)).pack(pady=10)

        # For demonstration, use a static list. Replace with call to PowerShell script.
        self.vm_list = [
            VMInfo("VM1", "PoweredOff"),
            VMInfo("VM2", "PoweredOn"),
        ]

        self.vm_frame = ctk.CTkFrame(self)
        self.vm_frame.pack(fill="both", expand=True, pady=10)

        # Controls for VM operations.
        action_frame = ctk.CTkFrame(self)
        action_frame.pack(pady=10)
        ctk.CTkButton(action_frame, text="Refresh VMs", command=self.refresh_vms).pack(side="left", padx=5)
        ctk.CTkButton(action_frame, text="Power On All", command=self.power_on_all).pack(side="left", padx=5)
        ctk.CTkButton(action_frame, text="Power Off All", command=self.power_off_all).pack(side="left", padx=5)
        ctk.CTkButton(action_frame, text="Restart All", command=self.restart_all_vms).pack(side="left", padx=5)

        self.refresh_vms()

    def refresh_vms(self):
        """
        Refreshes the VM list. In production, this would call a script (e.g., Get-VM).
        """
        for widget in self.vm_frame.winfo_children():
            widget.destroy()
        for idx, vm in enumerate(self.vm_list):
            btn_text = f"{vm.name} [{vm.power_state}]"
            btn = ctk.CTkButton(self.vm_frame, text=btn_text, command=lambda i=idx: self.toggle_vm(i))
            btn.pack(fill="x", padx=10, pady=2)

    def toggle_vm(self, index: int):
        """Toggles the power state of a VM; simulate via local change, or call a script."""
        vm = self.vm_list[index]

        if vm.power_state == "PoweredOn":
            self._stop_vm(vm)
        else:
            self._start_vm(vm)

        self.refresh_vms()

    def power_on_all(self):
        for vm in self.vm_list:
            self._start_vm(vm)

        self.refresh_vms()

    def power_off_all(self):
        for vm in self.vm_list:
            self._stop_vm(vm)

        self.refresh_vms()

    def restart_all_vms(self):
        """
        Simulates restarting all VMs. In production, call the restart script.
        """
        for vm in self.vm_list:
            self._stop_vm(vm)
            self._start_vm(vm)

        self.refresh_vms()

    def _start_vm(self, vm_obj: VMInfo):
        # In production, call: run_powershell_script("VmFunctions.psm1", f"-Start '{vm_obj.name}'")
        vm_obj.power_state = "PoweredOn"

    def _stop_vm(self, vm_obj: VMInfo):
        # In production, call: run_powershell_script("VmFunctions.psm1", f"-Stop '{vm_obj.name}'")
        vm_obj.power_state = "PoweredOff"