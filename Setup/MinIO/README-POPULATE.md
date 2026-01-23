# MinIO Data Population Scripts

This directory contains scripts to populate MinIO with sample data sources suitable for Pentaho Data Integration (PDI) onboarding, testing, and training.

## Overview

The population scripts create realistic datasets in multiple formats commonly used in data integration workflows:

### Data Sources Created

1. **CSV Files** - Structured tabular data
   - `customers.csv` - Customer records (12 entries)
   - `products.csv` - Product catalog (12 entries)
   - `sales.csv` - Sales transactions (15 entries)

2. **JSON Files** - API responses and configuration
   - `api_response.json` - Nested API response with orders
   - `user_events.json` - Event stream (JSONL format)
   - `config.json` - Application configuration

3. **XML Files** - Legacy system exports
   - `inventory.xml` - Warehouse inventory data
   - `employees.xml` - HR employee records

4. **Log Files** - Application and system logs
   - `application.log` - Structured application logs
   - `access.log` - Web server access logs
   - `error.log` - Error and warning logs

5. **Parquet Files** (Optional - requires Python)
   - `transactions.parquet` - Big data format for analytics

### Buckets Created

- **raw-data** - Landing zone for raw source files
- **staging** - Intermediate processing area
- **curated** - Clean, processed data ready for consumption
- **logs** - Application and process logs
- **archive** - Historical data archives

## Prerequisites

### Common Requirements

- MinIO running and accessible (default: http://localhost:9000)
- MinIO Client (mc) installed
- MinIO credentials (default: minioadmin/minioadmin)

### Linux-Specific

```bash
# Install MinIO Client
wget https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x mc
sudo mv mc /usr/local/bin/

# Optional: Install Python packages for Parquet generation
pip3 install pandas pyarrow

# Optional: Install utilities
sudo apt install curl jq
```

### Windows-Specific

```powershell
# Download MinIO Client
# From: https://dl.min.io/client/mc/release/windows-amd64/mc.exe
# Place in PATH (e.g., C:\Windows\System32)

# Optional: Install Python packages for Parquet generation
pip install pandas pyarrow
```

## Usage

### Linux

```bash
# Navigate to the Linux directory
cd /path/to/Setup/MinIO/linux

# Make script executable
chmod +x populate-minio.sh

# Run the script
./populate-minio.sh

# With custom MinIO settings (optional)
MINIO_ENDPOINT=http://minio-server:9000 \
MINIO_USER=admin \
MINIO_PASSWORD=password123 \
./populate-minio.sh
```

### Windows

```powershell
# Navigate to the Windows directory
cd C:\Path\To\Setup\MinIO\windows

# Run the script
.\populate-minio.ps1

# With custom MinIO settings (optional)
.\populate-minio.ps1 `
  -MinIOEndpoint "http://minio-server:9000" `
  -MinIOUser "admin" `
  -MinIOPassword "password123" `
  -MinIOAlias "my-minio"
```

## What the Script Does

1. **Checks Dependencies** - Verifies MinIO Client (mc) is installed
2. **Tests Connectivity** - Ensures MinIO is running and accessible
3. **Configures Client** - Sets up MinIO Client alias
4. **Creates Buckets** - Creates organizational buckets
5. **Generates CSV Files** - Creates customer, product, and sales data
6. **Generates JSON Files** - Creates API responses and configuration
7. **Generates XML Files** - Creates inventory and employee data
8. **Generates Log Files** - Creates realistic application logs
9. **Uploads to MinIO** - Copies all files to appropriate buckets

## Output

After successful execution, you'll see:

```
========================================
Data Population Complete!
========================================

Buckets created:
  ✓ raw-data - Raw data landing zone
  ✓ staging - Staging area for transformations
  ✓ curated - Curated, processed data
  ✓ logs - Application and process logs
  ✓ archive - Historical data archives

Data files uploaded:
  CSV Files:
    - customers.csv (12 records)
    - products.csv (12 records)
    - sales.csv (15 records)

  JSON Files:
    - api_response.json (nested API response)
    - user_events.json (event stream, JSONL format)
    - config.json (configuration data)

  XML Files:
    - inventory.xml (warehouse inventory)
    - employees.xml (HR data)

  Log Files:
    - application.log (application logs)
    - access.log (web access logs)
    - error.log (error logs)
```

## Accessing the Data

### Via MinIO Console

```
URL: http://localhost:9002
Username: minioadmin
Password: minioadmin
```

Navigate to buckets and browse uploaded files.

### Via MinIO Client

```bash
# List all buckets
mc ls minio-local

# List files in raw-data bucket
mc ls minio-local/raw-data --recursive

# Download a file
mc cp minio-local/raw-data/csv/customers.csv ./

# View file contents
mc cat minio-local/raw-data/csv/customers.csv
```

### Via AWS CLI

```bash
# Configure AWS CLI for MinIO
aws configure --profile minio
# Access Key: minioadmin
# Secret Key: minioadmin
# Region: us-east-1

# List buckets
aws --profile minio --endpoint-url http://localhost:9000 s3 ls

# List files
aws --profile minio --endpoint-url http://localhost:9000 s3 ls s3://raw-data/csv/

# Download file
aws --profile minio --endpoint-url http://localhost:9000 s3 cp s3://raw-data/csv/customers.csv ./
```

## Using with Pentaho Data Integration

### Configure S3 Connection

1. Open Pentaho Data Integration (Spoon)
2. Create a new transformation or job
3. Configure S3 VFS connection:
   - **Connection Type**: S3
   - **Endpoint**: http://localhost:9000
   - **Access Key**: minioadmin
   - **Secret Key**: minioadmin
   - **Region**: us-east-1

### S3 Path Format

Use the following path format in PDI steps:

```
s3a://raw-data/csv/customers.csv
s3a://raw-data/json/api_response.json
s3a://raw-data/xml/inventory.xml
s3a://logs/app/application.log
```

### Example PDI Transformations

#### Read CSV from MinIO

1. **CSV Input Step**
   - Filename: `s3a://raw-data/csv/customers.csv`
   - Configure columns: customer_id, first_name, last_name, email, etc.

2. **Select Values** (optional transformations)

3. **Table Output** (write to database)

#### Read JSON from MinIO

1. **JSON Input Step**
   - Filename: `s3a://raw-data/json/api_response.json`
   - Path: `$.data.orders[*]`

2. **JSON Output Fields**
   - Map JSON fields to stream fields

3. **Process as needed**

#### Read XML from MinIO

1. **Get Data from XML Step**
   - Filename: `s3a://raw-data/xml/inventory.xml`
   - Loop XPath: `/inventory/items/item`

2. **Define XML Output Fields**
   - sku: `/inventory/items/item/sku`
   - name: `/inventory/items/item/name`
   - quantity: `/inventory/items/item/quantity`

3. **Process as needed**

#### Process Log Files

1. **Text File Input Step**
   - Filename: `s3a://logs/app/application.log`
   - Content type: Text
   - Use regex to parse log format

2. **Filter Rows** (e.g., only ERROR level)

3. **Log to database or alert system**

## Sample Data Details

### customers.csv

```csv
customer_id,first_name,last_name,email,phone,country,registration_date,status
1001,John,Smith,john.smith@example.com,555-0101,USA,2023-01-15,active
...
```

**Use Cases:**
- Customer dimension tables
- ETL practice with standard CSV format
- Data quality validation
- Deduplication exercises

### products.csv

```csv
product_id,product_name,category,price,stock_quantity,supplier,last_updated
P001,Laptop Pro 15,Electronics,1299.99,45,TechSupply Inc,2024-01-15
...
```

**Use Cases:**
- Product master data
- Inventory management
- Price list updates
- Supplier analysis

### sales.csv

```csv
sale_id,customer_id,product_id,quantity,sale_date,sale_amount,payment_method,status
S001,1001,P001,1,2024-01-20,1299.99,credit_card,completed
...
```

**Use Cases:**
- Fact table population
- Sales analytics
- Customer purchase history
- Revenue calculations

### api_response.json

Nested JSON structure with orders, customer details, and pagination.

**Use Cases:**
- JSON parsing practice
- Nested structure flattening
- API data integration
- Complex data extraction

### user_events.json

JSONL (JSON Lines) format with one event per line.

**Use Cases:**
- Event stream processing
- User behavior analysis
- Clickstream data
- Time-series analysis

### inventory.xml

Hierarchical XML with metadata and items.

**Use Cases:**
- XML to relational mapping
- Legacy system integration
- Namespace handling
- XPath practice

### employees.xml

Nested department/employee structure.

**Use Cases:**
- Hierarchical data processing
- HR system integration
- Department-level aggregations
- XML attribute handling

### Log Files

Structured and unstructured log data.

**Use Cases:**
- Log parsing and analysis
- Error detection and alerting
- Access pattern analysis
- Regex pattern matching

## Customization

### Modify Data Content

Edit the scripts to customize the sample data:

**Linux:** `populate-minio.sh`
**Windows:** `populate-minio.ps1`

Example modifications:
- Add more rows to CSV files
- Create additional JSON event types
- Add more XML elements
- Generate larger datasets

### Add New File Types

Extend the scripts to generate additional formats:

1. **Avro Files** - Add Avro generation function
2. **ORC Files** - Add ORC generation function
3. **Excel Files** - Add Excel generation (requires libraries)
4. **Protobuf** - Add Protobuf serialization

### Create Custom Buckets

Modify the bucket arrays in the scripts:

```bash
# Linux
BUCKET_RAW="raw-data"
BUCKET_STAGING="staging"
# Add your custom bucket
BUCKET_CUSTOM="my-custom-bucket"
```

```powershell
# Windows
$BUCKET_CUSTOM = "my-custom-bucket"
```

Then add bucket creation in the `create_buckets` function.

## Troubleshooting

### MinIO Client Not Found

**Linux:**
```bash
# Check if mc is installed
which mc

# If not, install:
wget https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x mc
sudo mv mc /usr/local/bin/
```

**Windows:**
```powershell
# Check if mc is in PATH
where.exe mc

# If not, download and add to PATH
# Or place mc.exe in C:\Windows\System32
```

### Cannot Connect to MinIO

```bash
# Check if MinIO is running
curl http://localhost:9000/minio/health/live

# Start MinIO if not running
# Linux:
sudo /opt/minio/run-docker-minio.sh

# Windows:
.\run-docker-minio.ps1
```

### Permission Denied Errors

**Linux:**
```bash
# Ensure script is executable
chmod +x populate-minio.sh

# Check MinIO connectivity
curl http://localhost:9000/minio/health/live
```

**Windows:**
```powershell
# Check PowerShell execution policy
Get-ExecutionPolicy

# Set if needed
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Files Not Appearing in MinIO

```bash
# Verify upload with MinIO Client
mc ls minio-local/raw-data --recursive

# Check MinIO logs
docker logs minio

# Verify bucket exists
mc ls minio-local
```

## Data Cleanup

To remove all populated data:

```bash
# Remove all data from buckets
mc rm --recursive --force minio-local/raw-data
mc rm --recursive --force minio-local/staging
mc rm --recursive --force minio-local/curated
mc rm --recursive --force minio-local/logs
mc rm --recursive --force minio-local/archive

# Or remove buckets entirely
mc rb --force minio-local/raw-data
mc rb --force minio-local/staging
mc rb --force minio-local/curated
mc rb --force minio-local/logs
mc rb --force minio-local/archive
```

## Re-running the Script

The script is idempotent and can be safely re-run:
- Existing buckets are detected and skipped
- Files are overwritten with fresh data
- No cleanup required before re-running

## Integration with PDI Projects

### Suggested Workflow

1. **Initial Setup**
   - Run populate script to create sample data
   - Configure PDI S3 connection to MinIO

2. **Development Phase**
   - Create transformations reading from `raw-data` bucket
   - Write transformed data to `staging` bucket
   - Test and validate transformations

3. **Production Simulation**
   - Move validated data to `curated` bucket
   - Archive processed files to `archive` bucket
   - Log processing results to `logs` bucket

4. **Monitoring**
   - Read logs from `logs` bucket
   - Create monitoring dashboards
   - Set up alerts for errors

## Additional Resources

### MinIO Documentation
- MinIO Client: https://min.io/docs/minio/linux/reference/minio-mc.html
- S3 API: https://docs.aws.amazon.com/s3/

### Pentaho Documentation
- PDI VFS: https://help.hitachivantara.com/Documentation/Pentaho
- S3 Configuration: https://help.hitachivantara.com/Documentation/Pentaho/Data_Integration

### Sample Transformations
- Located in: `/path/to/pentaho/samples/transformations/`
- Search for: "S3", "VFS", "cloud storage"

## Support

For issues with:
- **Scripts**: Review script output for error messages
- **MinIO**: Check MinIO console and logs
- **Pentaho**: Consult PDI logs and documentation

## Version History

- **v1.0** (2024-01-23)
  - Initial release
  - Support for CSV, JSON, XML, and log files
  - Optional Parquet support
  - Both Linux and Windows versions

---

**Quick Start:**

```bash
# Linux
./populate-minio.sh

# Windows
.\populate-minio.ps1
```

Then access http://localhost:9002 to view your data in MinIO Console!
