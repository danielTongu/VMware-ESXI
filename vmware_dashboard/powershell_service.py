"""
powershell_service.py
----------------------
Provides a helper function to execute PowerShell scripts (PowerCLI) using PowerShell Core (pwsh).
Adjust the SCRIPT_DIR variable to point to the folder containing your PowerShell scripts.
"""

import subprocess
import os

# Path to the folder where PowerShell scripts reside.
SCRIPT_DIR = os.path.join(os.path.dirname(__file__), "ESXi_Scripts")

def run_powershell_script(script_name: str, args: str = "") -> str:
    """
    Executes a PowerShell script with the given arguments.

    Args:
        script_name (str): The script file name (relative to SCRIPT_DIR).
        args (str, optional): Additional arguments to pass to the script.

    Returns:
        str: The output from the script, or an error message.
    """
    script_path = os.path.join(SCRIPT_DIR, script_name)
    script_abs = os.path.abspath(script_path)
    command = f'pwsh -File "{script_abs}" {args}'
    try:
        output = subprocess.check_output(command, shell=True, text=True)
        return output
    except subprocess.CalledProcessError as e:
        return f"ERROR executing {script_abs}: {e.output}"