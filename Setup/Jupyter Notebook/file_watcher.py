# =============================================================================
# FILE WATCHER - PDI Output Monitor (Cross-Platform: Windows & Linux)
# =============================================================================
#
# Purpose:
#   Monitors the pdi-output/ directory on the HOST machine for new CSV files
#   produced by Pentaho Data Integration (PDI) transformations. When a file
#   matching the pattern "sales_*.csv" is detected, the script notifies the
#   user that new data is available and suggests running the analysis notebook.
#
# How it fits into the PDI-to-Jupyter workflow:
#
#   1. PDI runs a transformation that processes sales_data.csv
#   2. The transformation outputs sales_detailed_<timestamp>.csv into pdi-output/
#   3. This file_watcher.py script detects the new file (via filesystem events)
#   4. The user is notified to open/run sales_analysis.ipynb in Jupyter Lab
#   5. The notebook loads the new CSV, generates charts and an Excel report
#
# Platform support:
#   The script auto-detects the operating system and uses the correct paths:
#     Windows : C:\Jupyter-Notebook\pdi-output   and  C:\Jupyter-Notebook\notebooks\...
#     Linux   : ~/Jupyter-Notebook/pdi-output     and  ~/Jupyter-Notebook/notebooks/...
#
# Prerequisites:
#   - Python 3.6 or later
#   - The 'watchdog' library:  pip install watchdog
#   - The Jupyter environment set up by copy-jupyter.sh (Linux) or
#     copy-jupyter.ps1 (Windows)
#
# Usage:
#   python file_watcher.py
#
#   Then leave the script running in a terminal. When PDI writes a new CSV
#   file into pdi-output/, the script prints a notification.
#   Press Ctrl+C to stop.
#
# Notes:
#   - The script runs on the HOST machine (not inside the Docker container).
#   - Each detected file is only processed once (tracked via a set).
#   - A 2-second delay is added after file creation to ensure the file has
#     been fully written before processing.
# =============================================================================

import os
import sys
import platform
import time
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler
import subprocess
import logging


# =============================================================================
# CLASS: PDIOutputHandler
# =============================================================================
# Custom filesystem event handler that inherits from watchdog's
# FileSystemEventHandler. It listens for new files and triggers analysis
# when a matching CSV file is detected.
# =============================================================================
class PDIOutputHandler(FileSystemEventHandler):
    def __init__(self, notebook_path):
        """
        Initialise the handler with the path to the analysis notebook.

        Args:
            notebook_path (str): Full path to the sales_analysis.ipynb file
                                 on the host filesystem.
        """
        self.notebook_path = notebook_path
        # Keep track of files that have already been processed so we don't
        # trigger duplicate notifications for the same file.
        self.processed_files = set()

    def on_created(self, event):
        """
        Called by the watchdog observer whenever a new file or directory is
        created in the watched folder.

        The method filters for:
          - Files only (ignores directories)
          - Files ending with .csv
          - Filenames containing 'sales_' (matches PDI output pattern
            like sales_detailed_20240118.csv)

        A 2-second delay ensures the file has been completely written before
        we process it (PDI may still be flushing data to disk).
        """
        if event.is_directory:
            return

        if event.src_path.endswith('.csv') and 'sales_' in event.src_path:
            time.sleep(2)  # Wait for file to be fully written

            if event.src_path not in self.processed_files:
                self.processed_files.add(event.src_path)
                self.trigger_analysis(event.src_path)

    def trigger_analysis(self, file_path):
        """
        Called when a new sales CSV is detected. Attempts to auto-execute
        the sales_analysis.ipynb notebook inside the Docker container using
        'docker exec' and 'jupyter nbconvert --execute'. If auto-execution
        fails (e.g. Docker not running, container not found), falls back to
        printing a manual instruction.

        Args:
            file_path (str): Full path to the newly detected CSV file.
        """
        try:
            print(f"\n{'='*60}")
            print(f"New sales data detected: {os.path.basename(file_path)}")
            print(f"Full path: {file_path}")
            print(f"{'='*60}")

            # Attempt to auto-execute the notebook inside the Docker container.
            # 'jupyter nbconvert --execute' runs all cells and overwrites the
            # notebook in place so results are visible when the user opens it
            # in the Jupyter Lab browser.
            print("Auto-executing sales_analysis.ipynb in the Docker container...")
            result = subprocess.run(
                [
                    "docker", "exec", "jupyter-datascience",
                    "jupyter", "nbconvert",
                    "--to", "notebook",
                    "--execute",
                    "--inplace",
                    "/home/jovyan/notebooks/sales_analysis.ipynb"
                ],
                capture_output=True,
                text=True,
                timeout=120  # 2-minute timeout for notebook execution
            )

            if result.returncode == 0:
                print("Notebook executed successfully!")
                print("Check ~/Jupyter-Notebook/reports/ for the new Excel report.")
                print("Open http://localhost:8888 to view the updated notebook.")
            else:
                print(f"Notebook execution returned exit code {result.returncode}")
                if result.stderr:
                    # Show only the last few lines of stderr for readability
                    stderr_lines = result.stderr.strip().split('\n')
                    for line in stderr_lines[-5:]:
                        print(f"  {line}")
                print("\nYou can still run it manually in Jupyter Lab.")

        except subprocess.TimeoutExpired:
            print("Notebook execution timed out after 120 seconds.")
            print("The notebook may still be running. Check Jupyter Lab.")
        except FileNotFoundError:
            # Docker CLI not found on the system
            print("Docker CLI not found on this system.")
            print("Please run the notebook manually in Jupyter Lab:")
            print("  1. Open http://localhost:8888")
            print("  2. Navigate to notebooks/sales_analysis.ipynb")
            print("  3. Run All Cells (Kernel > Restart & Run All)")
        except Exception as e:
            logging.error(f"Error triggering analysis: {e}")
            print("Please run the sales_analysis.ipynb notebook manually.")


# =============================================================================
# FUNCTION: get_paths
# =============================================================================
# Determines the correct filesystem paths based on the host operating system.
#
# Returns:
#   tuple: (watch_folder, notebook_path)
#     watch_folder  - Directory to monitor for new CSV files from PDI
#     notebook_path - Path to the sales_analysis.ipynb notebook file
# =============================================================================
def get_paths():
    """Return the watch folder and notebook path based on the current OS."""
    if platform.system() == "Windows":
        # Windows: use the standard C:\Jupyter-Notebook location
        base = r"C:\Jupyter-Notebook"
    else:
        # Linux / macOS: use the home directory ~/Jupyter-Notebook location
        base = os.path.expanduser("~/Jupyter-Notebook")

    watch_folder = os.path.join(base, "pdi-output")
    notebook_path = os.path.join(base, "notebooks", "sales_analysis.ipynb")
    return watch_folder, notebook_path


# =============================================================================
# FUNCTION: main
# =============================================================================
# Entry point. Sets up logging, resolves platform-specific paths, validates
# the watch folder exists, then starts the filesystem observer loop.
# =============================================================================
def main():
    logging.basicConfig(level=logging.INFO)

    # Determine the correct paths for this operating system
    watch_folder, notebook_path = get_paths()

    # Validate that the watch folder exists before starting
    if not os.path.isdir(watch_folder):
        print(f"Error: Watch folder does not exist: {watch_folder}")
        print("Run the copy-jupyter setup script first to create the environment.")
        sys.exit(1)

    # Create the event handler and filesystem observer
    event_handler = PDIOutputHandler(notebook_path)
    observer = Observer()

    # Schedule the observer to watch the pdi-output directory.
    # recursive=False means we only watch the top-level directory,
    # not any sub-directories within it.
    observer.schedule(event_handler, watch_folder, recursive=False)

    # Start the observer thread (runs in the background)
    observer.start()
    print(f"Watching folder: {watch_folder}")
    print("Press Ctrl+C to stop...")

    # Keep the main thread alive; the observer runs in a daemon thread.
    # Ctrl+C triggers KeyboardInterrupt which cleanly stops the observer.
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
        print("File watcher stopped")

    # Wait for the observer thread to fully terminate before exiting
    observer.join()


# =============================================================================
# SCRIPT ENTRY POINT
# =============================================================================
if __name__ == "__main__":
    main()
