"""
vm_info.py
------------
Represents a single Virtual Machine’s details such as Name and PowerState.
"""

class VMInfo:
    def __init__(self, name: str, power_state: str = "PoweredOff"):
        self.name = name
        self.power_state = power_state

    def __str__(self):
        return f"{self.name} [{self.power_state}]"