"""
powershell_service.py
----------------------
Executes PowerShell scripts via pwsh, or returns mock output if USE_MOCK.
"""

import subprocess
import os
from vmware_dashboard.utils.config import USE_MOCK

# Folder where your .ps1 scripts live (adjust as needed).
SCRIPT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "ESXi_Scripts"))

def run_powershell_script(script_name: str, args: str = "") -> str:
    """
    Runs a PowerShell script with the given args, or returns a mock message.

    @param script_name: Filename of the .ps1 script in SCRIPT_DIR.
    @param args:        Arguments string to pass to the script.
    @return:            Script stdout or mock info.
    """
    if USE_MOCK:
        return f"[MOCK] {script_name} {args}"

    script_path = os.path.join(SCRIPT_DIR, script_name)
    command = f'powershell -NoProfile -ExecutionPolicy Bypass -File "{script_path}" {args}'
    try:
        output = subprocess.check_output(command, shell=True, text=True)
        return output
    except subprocess.CalledProcessError as e:
        return f"ERROR executing {script_path}: {e.output}"