import os
import time
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler
import subprocess
import logging

class PDIOutputHandler(FileSystemEventHandler):
    def __init__(self, notebook_path):
        self.notebook_path = notebook_path
        self.processed_files = set()
        
    def on_created(self, event):
        if event.is_directory:
            return
            
        if event.src_path.endswith('.csv') and 'sales_' in event.src_path:
            time.sleep(2)  # Wait for file to be fully written
            
            if event.src_path not in self.processed_files:
                self.processed_files.add(event.src_path)
                self.trigger_analysis(event.src_path)
    
    def trigger_analysis(self, file_path):
        """Trigger Jupyter notebook execution"""
        try:
            # Simple approach - just open the notebook
            print(f"New sales data detected: {file_path}")
            print("Please run the sales_analysis.ipynb notebook manually")
            print("Or use: jupyter nbconvert --to notebook --execute sales_analysis.ipynb")
            
        except Exception as e:
            logging.error(f"Error: {e}")

def main():
    logging.basicConfig(level=logging.INFO)
    
    watch_folder = r"C:\Jupyter-Notebook\pdi-output"
    notebook_path = r"C:\Jupyter-Notebook\notebooks\sales_analysis.ipynb"
    
    event_handler = PDIOutputHandler(notebook_path)
    observer = Observer()
    observer.schedule(event_handler, watch_folder, recursive=False)
    
    observer.start()
    print(f"Watching folder: {watch_folder}")
    print("Press Ctrl+C to stop...")
    
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
        print("File watcher stopped")
    
    observer.join()

if __name__ == "__main__":
    main()