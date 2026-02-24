# PDI to Jupyter Notebook Workshop Guide (Linux)

## Overview

This workshop demonstrates how to create a **Pentaho Data Integration (PDI)** pipeline that processes sales data and automatically triggers analysis in **Jupyter Notebook** when the output file is saved.

### What you will build

```
  ┌─────────────────────┐     ┌──────────────────┐     ┌────────────────────────┐
  │  PDI Transformation │────>│   pdi-output/     │────>│  Jupyter Notebook      │
  │  (Spoon on Host)    │     │  sales_detailed_  │     │  sales_analysis.ipynb  │
  │                     │     │  *.csv            │     │                        │
  │  - CSV Input        │     │                   │     │  - Load CSV            │
  │  - Replace String   │     │  (file_watcher.py │     │  - Analyse & Visualise │
  │  - Calculator       │     │   auto-executes   │     │  - Export Excel report  │
  │  - Sort Rows        │     │   notebook)       │     │  -> reports/           │
  │  - Text Output      │     │                   │     │                        │
  └─────────────────────┘     └──────────────────┘     └────────────────────────┘
        HOST (Linux)              HOST (shared)         DOCKER CONTAINER (Jupyter)
```

### Pipeline workflow

1. Execute a PDI pipeline with sample `sales_data.csv` from the datasets folder
2. The file output to the `pdi-output/` folder triggers the Jupyter Notebook
3. Load the data from `pdi-output/`, analyse and visualise the results
4. Export the results to the `reports/` folder

---

## Prerequisites

Before starting this workshop, ensure you have the following installed:

| Requirement | How to check | Install guide |
|---|---|---|
| **Linux OS** | Ubuntu 20.04+, Debian 11+, RHEL 8+, or similar | - |
| **Docker Engine** | `docker --version` | [docs.docker.com/engine/install](https://docs.docker.com/engine/install/) |
| **Docker Compose** | `docker compose version` | Included with Docker Engine 20.10+ |
| **Pentaho Data Integration** | `~/Pentaho/design-tools/data-integration/spoon.sh` | [Pentaho Community Edition](https://www.hitachivantara.com/en-us/products/pentaho-plus-platform/data-integration-analytics/pentaho-community-edition.html) |
| **Workshop Repository** | `ls ~/Workshop--Data-Integration/` | Clone from the provided repository |
| **Java (for PDI)** | `java -version` | OpenJDK 11 or later |

---

## Part 1: Environment Setup

### Step 1.1 - Run the Setup Script

The setup script creates the `~/Jupyter-Notebook` directory structure and copies all required files.

```bash
# Navigate to the Linux setup scripts
cd ~/Workshop--Data-Integration/Setup/Jupyter\ Notebook/linux/

# Make the script executable (if not already)
chmod +x copy-jupyter.sh

# Run the setup script
./copy-jupyter.sh
```

**What the script does:**

1. Creates `~/Jupyter-Notebook/` with sub-directories: `datasets/`, `notebooks/`, `pdi-output/`, `reports/`, `scripts/`, `transformations/`, `workshop-data/`
2. Copies `sales_data.csv` and `orders.csv` into `datasets/`
3. Copies `sales_analysis.ipynb` and `welcome.ipynb` into `notebooks/`
4. Copies `docker-compose.yml`, `run-docker-jupyter.sh`, `file_watcher.py`, and `post-start.sh` into `scripts/`
5. Creates a `README.md` inside `pdi-output/`
6. Sets correct file permissions (755 for scripts, 644 for data)

**Expected output:**

```
=== Jupyter Notebook Setup Script (Linux) ===
Source Path:      /home/<user>/Workshop--Data-Integration/Setup/Jupyter Notebook/linux
Destination Path: /home/<user>/Jupyter-Notebook

1. Creating destination directory...
  Created: /home/<user>/Jupyter-Notebook
2. Creating Docker volume directories...
  Created: /home/<user>/Jupyter-Notebook/workshop-data
  Created: /home/<user>/Jupyter-Notebook/pdi-output
  ...
3. Copying files...
  Copied sales_data.csv to /home/<user>/Jupyter-Notebook/datasets/
  ...
Setup Complete! Your Jupyter Notebook environment is ready.
```

### Step 1.2 - Verify the Directory Structure

```bash
# Check the created structure
ls -la ~/Jupyter-Notebook/
ls -la ~/Jupyter-Notebook/datasets/
ls -la ~/Jupyter-Notebook/notebooks/
ls -la ~/Jupyter-Notebook/scripts/
```

You should see:

```
~/Jupyter-Notebook/
├── datasets/
│   ├── orders.csv
│   └── sales_data.csv
├── notebooks/
│   ├── sales_analysis.ipynb
│   └── welcome.ipynb
├── pdi-output/
│   └── README.md
├── reports/
├── scripts/
│   ├── docker-compose.yml
│   ├── file_watcher.py
│   ├── post-start.sh
│   └── run-docker-jupyter.sh
├── transformations/
└── workshop-data/
```

---

## Part 2: Start the Jupyter Docker Container

### Step 2.1 - Start the Container

```bash
# Navigate to the scripts directory
cd ~/Jupyter-Notebook/scripts/

# Make the run script executable (if needed)
chmod +x run-docker-jupyter.sh

# Start the Jupyter container
./run-docker-jupyter.sh start
```

**What happens:**
- Docker pulls the `jupyter/scipy-notebook:latest` image (first time only, ~3 GB)
- Creates and starts a container named `jupyter-datascience`
- Maps port 8888 on the host to port 8888 in the container
- Bind-mounts the host directories into the container

### Step 2.2 - Verify the Container is Running

```bash
# Check container status
./run-docker-jupyter.sh status

# Or use Docker directly
docker ps --filter name=jupyter-datascience
```

You should see the container listed with status `Up` and port `0.0.0.0:8888->8888/tcp`.

### Step 2.3 - Access Jupyter Lab

Open your web browser and navigate to:

```
http://localhost:8888
```

When prompted:
- **Token:** `datascience`
- **Password:** Set a password of your choice (optional)

You should see the Jupyter Lab interface with the mounted directories visible in the file browser sidebar.

---

## Part 3: Quick Setup Verification

Before building the PDI pipeline, verify everything works by running the sample notebook.

### Step 3.1 - Verify Python Packages are Installed

Python packages (`watchdog`, `xlsxwriter`) are **automatically installed** when the container starts via the `post-start.sh` startup script. You can verify this:

```bash
# Check that packages were auto-installed
docker exec jupyter-datascience pip list | grep -E "watchdog|xlsxwriter"
# Expected: watchdog x.x.x  and  XlsxWriter x.x.x
```

> **Note:** If packages are missing, check the container logs: `docker logs jupyter-datascience`

### Step 3.2 - Verify Files Exist (Inside the Container)

```bash
# Check datasets are visible inside the container
docker exec jupyter-datascience ls /home/jovyan/datasets
# Expected: orders.csv  sales_data.csv

# Check notebooks are visible inside the container
docker exec jupyter-datascience ls /home/jovyan/notebooks
# Expected: sales_analysis.ipynb  welcome.ipynb
```

### Step 3.3 - Run the Sales Analysis Notebook

1. In Jupyter Lab, navigate to **notebooks/** in the file browser
2. Open **sales_analysis.ipynb**
3. Run each cell in order (Shift+Enter or use the Run menu)
4. The notebook will:
   - Load `sales_data.csv` from `/home/jovyan/datasets/`
   - Generate a 4-panel Sales Analysis Dashboard
   - Calculate Key Metrics (revenue, average order value, profit margin)
   - Export an Excel report to `/home/jovyan/reports/`

### Step 3.4 - Check the Output Report

```bash
# On the host machine, check for the generated report
ls ~/Jupyter-Notebook/reports/
# Expected: sales_analysis_<timestamp>.xlsx
```

Open the Excel file and verify it has two sheets:
- **Summary** - Key metrics (Total Revenue, Average Order Value, etc.)
- **Detailed Data** - Full processed dataset

---

## Part 4: Build the PDI Pipeline

### Step 4.1 - Start Pentaho Data Integration (Spoon)

```bash
# Navigate to the PDI installation
cd ~/Pentaho/design-tools/data-integration

# Launch Spoon (the PDI graphical designer)
./spoon.sh
```

### Step 4.2 - Create a New Transformation

In Spoon:
1. **File > New > Transformation** (or Ctrl+N)
2. Save the transformation as `~/Jupyter-Notebook/transformations/sales_pipeline.ktr`

### Step 4.3 - Build the Pipeline Steps

Add the following steps to your transformation by dragging them from the Design palette:

> **About the dataset:** The `sales_data.csv` file contains 250 rows of sales orders with 8 columns (`order_id`, `customer_id`, `product_name`, `product_category`, `quantity`, `unit_price`, `cost`, `order_date`). The data intentionally has **inconsistent casing** in the `product_category` column (e.g., `Electronics` vs `electronics`, `Home` vs `home`) — this gives the Replace in String step real work to do.

#### A. CSV File Input
- **Step type:** Input > CSV file input
- **Purpose:** Reads the source sales data
- **Configuration:**
  1. Drag a **CSV file input** step onto the canvas
  2. Double-click to configure:
     - **Filename:** `~/Jupyter-Notebook/datasets/sales_data.csv`
     - **Delimiter:** `,`
     - **Header row present:** checked
  3. Click **Get Fields** to auto-detect the 8 columns
  4. Verify the field types: `order_id` (Integer), `customer_id` (Integer), `product_name` (String), `product_category` (String), `quantity` (Integer), `unit_price` (Number), `cost` (Number), `order_date` (String)
  5. Click **Preview** to verify data loads correctly (should show 250 rows)

#### B. Data Validator (optional)
- **Step type:** Validation > Data Validator
- **Purpose:** Validates input data quality
- **Configuration:**
  1. Add a **Data Validator** step and connect it from CSV file input
  2. Add validations:
     - `quantity`: Data type = Integer, Minimum value = 1
     - `unit_price`: Data type = BigNumber, Minimum value = 0.01
  3. Create an **error handling hop** (red hop) to a **Dummy** step for invalid records

#### C. Replace in String
- **Step type:** Transform > Replace in String
- **Purpose:** Normalise the inconsistent `product_category` casing
- **Configuration:**
  1. Add a **Replace in String** step
  2. Add rows to fix each category (the dataset has mixed case like `electronics` / `Electronics`):
     | In stream field | Search | Replace with | Use RegEx |
     |---|---|---|---|
     | product_category | `electronics` | `Electronics` | no |
     | product_category | `clothing` | `Clothing` | no |
     | product_category | `home` | `Home` | no |
     | product_category | `sports` | `Sports` | no |
     | product_category | `books` | `Books` | no |
  3. Set **Case sensitive** to `no` for each row to catch all variations

#### D. Calculator
- **Step type:** Transform > Calculator
- **Purpose:** Compute derived fields
- **Configuration:**
  1. Add a **Calculator** step
  2. Add two calculations:
     | New field | Calculation | Field A | Field B |
     |---|---|---|---|
     | `total_amount` | A * B | `quantity` | `unit_price` |
     | `total_cost` | A * B | `quantity` | `cost` |
  3. To compute profit margin, add a **User Defined Java Expression** step (or a second Calculator step) after this one:
     - `profit_margin` = `(total_amount - total_cost) / total_amount`

#### E. Sort Rows
- **Step type:** Transform > Sort rows
- **Purpose:** Sort data before output (required if you add a Group By step)
- **Configuration:**
  1. Add a **Sort rows** step
  2. Sort by `product_category` (ascending)

#### F. Text File Output
- **Step type:** Output > Text file output
- **Purpose:** Write the processed data to the pdi-output folder
- **Configuration:**
  1. Add a **Text file output** step
  2. Configure the File tab:
     - **Filename:** `~/Jupyter-Notebook/pdi-output/sales_detailed`
     - **Extension:** `csv`
     - **Include date in filename:** Yes
     - **Date time format:** `yyyyMMdd_HHmmss` (produces `sales_detailed_20250218_143022.csv`)
  3. Configure the Content tab:
     - **Separator:** `,`
     - **Header:** Yes
  4. Click **Get Fields** to populate the output field list

### Step 4.4 - Connect the Steps

Create hops (connections) between steps in this order:

```
CSV File Input -> Data Validator -> Replace in String -> Calculator -> Sort Rows -> Text File Output
```

### Step 4.5 - Run the Transformation

1. Click the **Run** button (green play icon) or press F9
2. Watch the execution in the Step Metrics tab
3. Verify the output file was created:

```bash
ls ~/Jupyter-Notebook/pdi-output/
# Expected: sales_detailed_<date>.csv  README.md
```

---

## Part 5: Run the File Watcher (Automated Pipeline)

The file watcher monitors the `pdi-output/` directory and **automatically executes** the analysis notebook inside the Docker container when PDI writes a new file.

### Step 5.1 - Start the File Watcher

Open a **new terminal** (separate from PDI):

```bash
# Navigate to the scripts directory
cd ~/Jupyter-Notebook/scripts/

# Create a Python virtual environment and install watchdog
# (Modern Linux distros block system-wide pip installs - PEP 668)
python3 -m venv .venv
.venv/bin/pip install watchdog

# Start the file watcher using the venv Python
.venv/bin/python3 file_watcher.py
```

**Expected output:**

```
Watching folder: /home/<user>/Jupyter-Notebook/pdi-output
Press Ctrl+C to stop...
```

### Step 5.2 - Trigger the Watcher

Re-run the PDI transformation (Step 4.5). The file watcher detects the new CSV and **auto-executes** the notebook:

```
============================================================
New sales data detected: sales_detailed_20250218.csv
Full path: /home/<user>/Jupyter-Notebook/pdi-output/sales_detailed_20250218.csv
============================================================
Auto-executing sales_analysis.ipynb in the Docker container...
Notebook executed successfully!
Check ~/Jupyter-Notebook/reports/ for the new Excel report.
Open http://localhost:8888 to view the updated notebook.
```

The file watcher uses `docker exec` to run `jupyter nbconvert --execute` inside the container, so the notebook runs automatically without you having to open Jupyter Lab.

### Step 5.3 - Verify the Results

```bash
# Check for the auto-generated report
ls ~/Jupyter-Notebook/reports/
# Expected: sales_analysis_<timestamp>.xlsx
```

You can also open Jupyter Lab at `http://localhost:8888` to see the notebook with updated charts and results already rendered.

> **Fallback:** If auto-execution fails (e.g., container not running), the watcher prints instructions for running the notebook manually.

---

## Part 6: Container Management

### Common Commands

```bash
# All commands from ~/Jupyter-Notebook/scripts/

# Start the container
./run-docker-jupyter.sh start

# Stop the container
./run-docker-jupyter.sh stop

# Restart the container
./run-docker-jupyter.sh restart

# Check status
./run-docker-jupyter.sh status

# View logs
./run-docker-jupyter.sh logs

# Follow logs in real time
./run-docker-jupyter.sh follow

# Open a shell inside the container
./run-docker-jupyter.sh shell

# Full cleanup (remove containers, images, and volumes)
./run-docker-jupyter.sh cleanup

# Show help
./run-docker-jupyter.sh help
```

---

## Troubleshooting

### Container won't start

```bash
# Check if port 8888 is already in use
ss -tlnp | grep 8888

# Check Docker logs for errors
docker logs jupyter-datascience

# Ensure Docker is running
systemctl status docker
```

### Permission denied on mounted directories

```bash
# Ensure directories have correct permissions
chmod 755 ~/Jupyter-Notebook/*/

# If running Docker without sudo, ensure your user is in the docker group
sudo usermod -aG docker $USER
# Then log out and log back in
```

### Notebook can't find data files

Inside the container, files are at these paths:
- Datasets: `/home/jovyan/datasets/`
- PDI output: `/home/jovyan/pdi-output/`
- Reports: `/home/jovyan/reports/`

Check the bind mounts:
```bash
docker inspect jupyter-datascience --format '{{json .Mounts}}' | python3 -m json.tool
```

### PDI can't write to pdi-output

Ensure the directory exists and has write permissions:
```bash
ls -la ~/Jupyter-Notebook/pdi-output/
chmod 755 ~/Jupyter-Notebook/pdi-output/
```

---

## Directory & File Reference

| Host Path | Container Path | Purpose |
|---|---|---|
| `~/Jupyter-Notebook/datasets/` | `/home/jovyan/datasets/` | Source CSV data files |
| `~/Jupyter-Notebook/notebooks/` | `/home/jovyan/notebooks/` | Jupyter notebook files |
| `~/Jupyter-Notebook/pdi-output/` | `/home/jovyan/pdi-output/` | PDI transformation output (landing zone) |
| `~/Jupyter-Notebook/reports/` | `/home/jovyan/reports/` | Generated analysis reports |
| `~/Jupyter-Notebook/workshop-data/` | `/home/jovyan/work/` | General workspace |
| `~/Jupyter-Notebook/scripts/` | *(host only)* | Docker Compose, run script, file watcher |
| `~/Jupyter-Notebook/transformations/` | *(host only)* | PDI transformation files (.ktr) |

---

## Scripts Reference

| Script | Purpose | Location |
|---|---|---|
| `copy-jupyter.sh` | One-time setup: creates directories and copies files | `Setup/Jupyter Notebook/linux/` |
| `run-docker-jupyter.sh` | Manages the Docker container (start/stop/logs/etc.) | `~/Jupyter-Notebook/scripts/` |
| `docker-compose.yml` | Defines the Jupyter container, ports, and volumes | `~/Jupyter-Notebook/scripts/` |
| `post-start.sh` | Container startup script: auto-installs Python packages | `~/Jupyter-Notebook/scripts/` |
| `file_watcher.py` | Monitors pdi-output/ for new CSV files, auto-executes notebook | `~/Jupyter-Notebook/scripts/` |
| `sales_analysis.ipynb` | Main analysis notebook (runs inside container) | `~/Jupyter-Notebook/notebooks/` |
