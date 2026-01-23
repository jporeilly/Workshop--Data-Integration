#!/bin/bash
# ==============================================================================
# MinIO Data Population Script - Sample Data for Pentaho Data Integration
# ==============================================================================
#
# Purpose:
#   Populates MinIO buckets with sample data sources in various formats
#   suitable for onboarding and testing with Pentaho Data Integration (PDI).
#   Creates realistic datasets for ETL development, testing, and training.
#
# Data Sources Created:
#   1. CSV files - Customer, sales, product data
#   2. JSON files - API responses, nested data structures
#   3. Parquet files - Big data format for analytics
#   4. XML files - Legacy system exports
#   5. Text files - Log files, unstructured data
#   6. Excel files - Business reports (if available)
#
# Buckets Created:
#   - raw-data: Landing zone for raw source files
#   - staging: Intermediate processing area
#   - curated: Clean, processed data ready for consumption
#   - logs: Application and process logs
#   - archive: Historical data archives
#
# Requirements:
#   - MinIO running and accessible (localhost:9000)
#   - MinIO Client (mc) installed
#   - curl, jq (for JSON generation)
#   - Python 3 with pandas, pyarrow (for Parquet generation)
#
# Usage:
#   ./populate-minio.sh
#
# Environment Variables (optional):
#   MINIO_ENDPOINT - MinIO endpoint (default: http://localhost:9000)
#   MINIO_USER - MinIO username (default: minioadmin)
#   MINIO_PASSWORD - MinIO password (default: minioadmin)
#   MINIO_ALIAS - Alias name for mc (default: minio-local)
#
# Exit Codes:
#   0 - Success
#   1 - Error (dependencies missing, MinIO not accessible, etc.)
# ==============================================================================

# ------------------------------------------------------------------------------
# Color Codes for Output
# ------------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------
MINIO_ENDPOINT="${MINIO_ENDPOINT:-http://localhost:9000}"
MINIO_USER="${MINIO_USER:-minioadmin}"
MINIO_PASSWORD="${MINIO_PASSWORD:-minioadmin}"
MINIO_ALIAS="${MINIO_ALIAS:-minio-local}"

# Temporary directory for generating sample files
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Bucket names
BUCKET_RAW="raw-data"
BUCKET_STAGING="staging"
BUCKET_CURATED="curated"
BUCKET_LOGS="logs"
BUCKET_ARCHIVE="archive"

# ------------------------------------------------------------------------------
# Display Script Header
# ------------------------------------------------------------------------------
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}MinIO Data Population Script${NC}"
echo -e "${CYAN}Sample Data for Pentaho Data Integration${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# ------------------------------------------------------------------------------
# Function: Check Dependencies
# ------------------------------------------------------------------------------
check_dependencies() {
    echo -e "${BLUE}[1/8] Checking dependencies...${NC}"

    local missing_deps=()

    # Check for MinIO Client
    if ! command -v mc &> /dev/null; then
        missing_deps+=("mc (MinIO Client)")
    fi

    # Check for curl (for testing connectivity)
    if ! command -v curl &> /dev/null; then
        missing_deps+=("curl")
    fi

    # Check for jq (for JSON manipulation)
    if ! command -v jq &> /dev/null; then
        echo -e "${YELLOW}  [WARNING] jq not found - JSON generation will be limited${NC}"
    fi

    # Check for Python 3
    if ! command -v python3 &> /dev/null; then
        echo -e "${YELLOW}  [WARNING] python3 not found - Parquet files will not be generated${NC}"
    fi

    # Report missing critical dependencies
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "${RED}[ERROR] Missing required dependencies:${NC}"
        for dep in "${missing_deps[@]}"; do
            echo -e "  ${RED}- $dep${NC}"
        done
        echo ""
        echo -e "${YELLOW}Installation instructions:${NC}"
        echo -e "  ${GRAY}# MinIO Client:${NC}"
        echo -e "  ${GRAY}wget https://dl.min.io/client/mc/release/linux-amd64/mc${NC}"
        echo -e "  ${GRAY}chmod +x mc && sudo mv mc /usr/local/bin/${NC}"
        echo -e ""
        echo -e "  ${GRAY}# curl, jq:${NC}"
        echo -e "  ${GRAY}sudo apt install curl jq${NC}"
        return 1
    fi

    echo -e "${GREEN}  [OK] All required dependencies found${NC}"
    return 0
}

# ------------------------------------------------------------------------------
# Function: Check MinIO Connectivity
# ------------------------------------------------------------------------------
check_minio_connectivity() {
    echo -e "${BLUE}[2/8] Checking MinIO connectivity...${NC}"

    # Test MinIO health endpoint
    if ! curl -sf "${MINIO_ENDPOINT}/minio/health/live" > /dev/null 2>&1; then
        echo -e "${RED}  [ERROR] Cannot connect to MinIO at ${MINIO_ENDPOINT}${NC}"
        echo -e "${YELLOW}  Please ensure MinIO is running:${NC}"
        echo -e "  ${GRAY}sudo /opt/minio/run-docker-minio.sh${NC}"
        return 1
    fi

    echo -e "${GREEN}  [OK] MinIO is accessible at ${MINIO_ENDPOINT}${NC}"
    return 0
}

# ------------------------------------------------------------------------------
# Function: Configure MinIO Client
# ------------------------------------------------------------------------------
configure_minio_client() {
    echo -e "${BLUE}[3/8] Configuring MinIO Client...${NC}"

    # Remove existing alias if present
    mc alias remove "$MINIO_ALIAS" 2>/dev/null

    # Set up MinIO alias
    if ! mc alias set "$MINIO_ALIAS" "$MINIO_ENDPOINT" "$MINIO_USER" "$MINIO_PASSWORD" > /dev/null 2>&1; then
        echo -e "${RED}  [ERROR] Failed to configure MinIO Client${NC}"
        echo -e "${YELLOW}  Check credentials and endpoint${NC}"
        return 1
    fi

    echo -e "${GREEN}  [OK] MinIO Client configured with alias: ${MINIO_ALIAS}${NC}"
    return 0
}

# ------------------------------------------------------------------------------
# Function: Create Buckets
# ------------------------------------------------------------------------------
create_buckets() {
    echo -e "${BLUE}[4/8] Creating buckets...${NC}"

    local buckets=("$BUCKET_RAW" "$BUCKET_STAGING" "$BUCKET_CURATED" "$BUCKET_LOGS" "$BUCKET_ARCHIVE")

    for bucket in "${buckets[@]}"; do
        # Check if bucket exists
        if mc ls "${MINIO_ALIAS}/${bucket}" > /dev/null 2>&1; then
            echo -e "  ${GRAY}[EXISTS] Bucket: ${bucket}${NC}"
        else
            # Create bucket
            if mc mb "${MINIO_ALIAS}/${bucket}" > /dev/null 2>&1; then
                echo -e "  ${GREEN}[CREATED] Bucket: ${bucket}${NC}"
            else
                echo -e "  ${RED}[ERROR] Failed to create bucket: ${bucket}${NC}"
                return 1
            fi
        fi
    done

    return 0
}

# ------------------------------------------------------------------------------
# Function: Generate CSV Files
# ------------------------------------------------------------------------------
generate_csv_files() {
    echo -e "${BLUE}[5/8] Generating CSV files...${NC}"

    # Create customers.csv
    echo -e "  ${CYAN}Generating customers.csv...${NC}"
    cat > "$TEMP_DIR/customers.csv" <<'EOF'
customer_id,first_name,last_name,email,phone,country,registration_date,status
1001,John,Smith,john.smith@example.com,555-0101,USA,2023-01-15,active
1002,Maria,Garcia,maria.garcia@example.com,555-0102,Spain,2023-02-20,active
1003,Wei,Chen,wei.chen@example.com,555-0103,China,2023-03-10,active
1004,Sarah,Johnson,sarah.johnson@example.com,555-0104,USA,2023-04-05,active
1005,Mohammed,Ahmed,mohammed.ahmed@example.com,555-0105,UAE,2023-05-12,inactive
1006,Anna,Kowalski,anna.kowalski@example.com,555-0106,Poland,2023-06-18,active
1007,Carlos,Rodriguez,carlos.rodriguez@example.com,555-0107,Mexico,2023-07-22,active
1008,Yuki,Tanaka,yuki.tanaka@example.com,555-0108,Japan,2023-08-30,active
1009,Emma,Brown,emma.brown@example.com,555-0109,UK,2023-09-14,active
1010,Lars,Nielsen,lars.nielsen@example.com,555-0110,Denmark,2023-10-25,active
1011,Priya,Sharma,priya.sharma@example.com,555-0111,India,2023-11-08,inactive
1012,Jean,Dupont,jean.dupont@example.com,555-0112,France,2023-12-03,active
EOF

    # Create products.csv
    echo -e "  ${CYAN}Generating products.csv...${NC}"
    cat > "$TEMP_DIR/products.csv" <<'EOF'
product_id,product_name,category,price,stock_quantity,supplier,last_updated
P001,Laptop Pro 15,Electronics,1299.99,45,TechSupply Inc,2024-01-15
P002,Wireless Mouse,Electronics,29.99,230,TechSupply Inc,2024-01-16
P003,Office Chair Deluxe,Furniture,349.99,78,ComfortSeats Ltd,2024-01-14
P004,Standing Desk,Furniture,599.99,34,ComfortSeats Ltd,2024-01-13
P005,4K Monitor 27inch,Electronics,459.99,92,DisplayTech Corp,2024-01-17
P006,Mechanical Keyboard,Electronics,129.99,156,TechSupply Inc,2024-01-15
P007,USB-C Hub,Electronics,49.99,310,ConnectPro Inc,2024-01-18
P008,Desk Lamp LED,Furniture,39.99,180,LightWorks Co,2024-01-12
P009,Noise Cancelling Headphones,Electronics,279.99,67,AudioMax Ltd,2024-01-19
P010,Ergonomic Footrest,Furniture,34.99,145,ComfortSeats Ltd,2024-01-11
P011,Webcam HD,Electronics,89.99,201,TechSupply Inc,2024-01-20
P012,Conference Speakerphone,Electronics,199.99,54,AudioMax Ltd,2024-01-16
EOF

    # Create sales.csv
    echo -e "  ${CYAN}Generating sales.csv...${NC}"
    cat > "$TEMP_DIR/sales.csv" <<'EOF'
sale_id,customer_id,product_id,quantity,sale_date,sale_amount,payment_method,status
S001,1001,P001,1,2024-01-20,1299.99,credit_card,completed
S002,1002,P003,2,2024-01-21,699.98,paypal,completed
S003,1003,P002,1,2024-01-21,29.99,credit_card,completed
S004,1001,P005,1,2024-01-22,459.99,credit_card,completed
S005,1004,P006,1,2024-01-22,129.99,debit_card,completed
S006,1005,P008,3,2024-01-23,119.97,paypal,pending
S007,1006,P009,1,2024-01-23,279.99,credit_card,completed
S008,1007,P004,1,2024-01-24,599.99,credit_card,completed
S009,1008,P007,2,2024-01-24,99.98,paypal,completed
S010,1009,P011,1,2024-01-25,89.99,debit_card,completed
S011,1010,P012,1,2024-01-25,199.99,credit_card,completed
S012,1002,P010,4,2024-01-26,139.96,paypal,completed
S013,1003,P001,1,2024-01-26,1299.99,credit_card,processing
S014,1011,P005,2,2024-01-27,919.98,credit_card,cancelled
S015,1012,P002,3,2024-01-27,89.97,paypal,completed
EOF

    # Upload CSV files to MinIO
    echo -e "  ${CYAN}Uploading CSV files to MinIO...${NC}"
    mc cp "$TEMP_DIR/customers.csv" "${MINIO_ALIAS}/${BUCKET_RAW}/csv/" > /dev/null 2>&1
    mc cp "$TEMP_DIR/products.csv" "${MINIO_ALIAS}/${BUCKET_RAW}/csv/" > /dev/null 2>&1
    mc cp "$TEMP_DIR/sales.csv" "${MINIO_ALIAS}/${BUCKET_RAW}/csv/" > /dev/null 2>&1

    echo -e "${GREEN}  [OK] CSV files generated and uploaded${NC}"
}

# ------------------------------------------------------------------------------
# Function: Generate JSON Files
# ------------------------------------------------------------------------------
generate_json_files() {
    echo -e "${BLUE}[6/8] Generating JSON files...${NC}"

    # Create api_response.json (simulated API response)
    echo -e "  ${CYAN}Generating api_response.json...${NC}"
    cat > "$TEMP_DIR/api_response.json" <<'EOF'
{
  "status": "success",
  "timestamp": "2024-01-23T10:30:00Z",
  "data": {
    "orders": [
      {
        "order_id": "ORD-2024-001",
        "customer": {
          "id": 1001,
          "name": "John Smith",
          "email": "john.smith@example.com"
        },
        "items": [
          {
            "product_id": "P001",
            "name": "Laptop Pro 15",
            "quantity": 1,
            "unit_price": 1299.99
          }
        ],
        "total": 1299.99,
        "order_date": "2024-01-20T14:30:00Z",
        "shipping_address": {
          "street": "123 Main St",
          "city": "New York",
          "state": "NY",
          "zip": "10001",
          "country": "USA"
        }
      },
      {
        "order_id": "ORD-2024-002",
        "customer": {
          "id": 1002,
          "name": "Maria Garcia",
          "email": "maria.garcia@example.com"
        },
        "items": [
          {
            "product_id": "P003",
            "name": "Office Chair Deluxe",
            "quantity": 2,
            "unit_price": 349.99
          }
        ],
        "total": 699.98,
        "order_date": "2024-01-21T09:15:00Z",
        "shipping_address": {
          "street": "456 Gran Via",
          "city": "Madrid",
          "state": "Madrid",
          "zip": "28013",
          "country": "Spain"
        }
      }
    ],
    "pagination": {
      "page": 1,
      "per_page": 10,
      "total_pages": 1,
      "total_records": 2
    }
  }
}
EOF

    # Create user_events.json (event stream data)
    echo -e "  ${CYAN}Generating user_events.json...${NC}"
    cat > "$TEMP_DIR/user_events.json" <<'EOF'
{"event_id":"evt_001","user_id":1001,"event_type":"page_view","page":"/products","timestamp":"2024-01-23T08:00:00Z","session_id":"sess_abc123"}
{"event_id":"evt_002","user_id":1001,"event_type":"add_to_cart","product_id":"P001","timestamp":"2024-01-23T08:05:00Z","session_id":"sess_abc123"}
{"event_id":"evt_003","user_id":1002,"event_type":"page_view","page":"/home","timestamp":"2024-01-23T08:10:00Z","session_id":"sess_def456"}
{"event_id":"evt_004","user_id":1001,"event_type":"checkout","cart_value":1299.99,"timestamp":"2024-01-23T08:15:00Z","session_id":"sess_abc123"}
{"event_id":"evt_005","user_id":1003,"event_type":"search","query":"wireless mouse","timestamp":"2024-01-23T08:20:00Z","session_id":"sess_ghi789"}
{"event_id":"evt_006","user_id":1002,"event_type":"add_to_cart","product_id":"P003","timestamp":"2024-01-23T08:25:00Z","session_id":"sess_def456"}
{"event_id":"evt_007","user_id":1004,"event_type":"page_view","page":"/products/electronics","timestamp":"2024-01-23T08:30:00Z","session_id":"sess_jkl012"}
{"event_id":"evt_008","user_id":1003,"event_type":"product_view","product_id":"P002","timestamp":"2024-01-23T08:35:00Z","session_id":"sess_ghi789"}
EOF

    # Create config.json (configuration file)
    echo -e "  ${CYAN}Generating config.json...${NC}"
    cat > "$TEMP_DIR/config.json" <<'EOF'
{
  "application": {
    "name": "DataIntegrationPipeline",
    "version": "1.0.0",
    "environment": "production"
  },
  "database": {
    "host": "db.example.com",
    "port": 5432,
    "name": "analytics_db",
    "connection_pool": {
      "min": 5,
      "max": 20,
      "timeout": 30000
    }
  },
  "s3_storage": {
    "endpoint": "http://localhost:9000",
    "buckets": {
      "raw": "raw-data",
      "staging": "staging",
      "curated": "curated"
    }
  },
  "processing": {
    "batch_size": 1000,
    "max_retries": 3,
    "timeout_seconds": 300
  }
}
EOF

    # Upload JSON files to MinIO
    echo -e "  ${CYAN}Uploading JSON files to MinIO...${NC}"
    mc cp "$TEMP_DIR/api_response.json" "${MINIO_ALIAS}/${BUCKET_RAW}/json/" > /dev/null 2>&1
    mc cp "$TEMP_DIR/user_events.json" "${MINIO_ALIAS}/${BUCKET_RAW}/json/" > /dev/null 2>&1
    mc cp "$TEMP_DIR/config.json" "${MINIO_ALIAS}/${BUCKET_RAW}/json/" > /dev/null 2>&1

    echo -e "${GREEN}  [OK] JSON files generated and uploaded${NC}"
}

# ------------------------------------------------------------------------------
# Function: Generate XML Files
# ------------------------------------------------------------------------------
generate_xml_files() {
    echo -e "${BLUE}[7/8] Generating XML files...${NC}"

    # Create inventory.xml
    echo -e "  ${CYAN}Generating inventory.xml...${NC}"
    cat > "$TEMP_DIR/inventory.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<inventory>
    <metadata>
        <export_date>2024-01-23</export_date>
        <warehouse>Main Warehouse</warehouse>
        <location>New York, NY</location>
    </metadata>
    <items>
        <item>
            <sku>P001</sku>
            <name>Laptop Pro 15</name>
            <category>Electronics</category>
            <quantity>45</quantity>
            <location>A-12-3</location>
            <last_checked>2024-01-20</last_checked>
        </item>
        <item>
            <sku>P002</sku>
            <name>Wireless Mouse</name>
            <category>Electronics</category>
            <quantity>230</quantity>
            <location>B-05-1</location>
            <last_checked>2024-01-21</last_checked>
        </item>
        <item>
            <sku>P003</sku>
            <name>Office Chair Deluxe</name>
            <category>Furniture</category>
            <quantity>78</quantity>
            <location>C-08-4</location>
            <last_checked>2024-01-19</last_checked>
        </item>
        <item>
            <sku>P004</sku>
            <name>Standing Desk</name>
            <category>Furniture</category>
            <quantity>34</quantity>
            <location>C-10-2</location>
            <last_checked>2024-01-22</last_checked>
        </item>
    </items>
</inventory>
EOF

    # Create employees.xml
    echo -e "  ${CYAN}Generating employees.xml...${NC}"
    cat > "$TEMP_DIR/employees.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<company>
    <department name="Sales">
        <employee id="E001">
            <name>Alice Johnson</name>
            <position>Sales Manager</position>
            <email>alice.johnson@company.com</email>
            <hire_date>2020-03-15</hire_date>
            <salary currency="USD">85000</salary>
        </employee>
        <employee id="E002">
            <name>Bob Williams</name>
            <position>Sales Representative</position>
            <email>bob.williams@company.com</email>
            <hire_date>2021-06-01</hire_date>
            <salary currency="USD">55000</salary>
        </employee>
    </department>
    <department name="Engineering">
        <employee id="E003">
            <name>Carol Martinez</name>
            <position>Senior Developer</position>
            <email>carol.martinez@company.com</email>
            <hire_date>2019-01-10</hire_date>
            <salary currency="USD">105000</salary>
        </employee>
        <employee id="E004">
            <name>David Lee</name>
            <position>DevOps Engineer</position>
            <email>david.lee@company.com</email>
            <hire_date>2022-08-20</hire_date>
            <salary currency="USD">95000</salary>
        </employee>
    </department>
</company>
EOF

    # Upload XML files to MinIO
    echo -e "  ${CYAN}Uploading XML files to MinIO...${NC}"
    mc cp "$TEMP_DIR/inventory.xml" "${MINIO_ALIAS}/${BUCKET_RAW}/xml/" > /dev/null 2>&1
    mc cp "$TEMP_DIR/employees.xml" "${MINIO_ALIAS}/${BUCKET_RAW}/xml/" > /dev/null 2>&1

    echo -e "${GREEN}  [OK] XML files generated and uploaded${NC}"
}

# ------------------------------------------------------------------------------
# Function: Generate Log Files
# ------------------------------------------------------------------------------
generate_log_files() {
    echo -e "${BLUE}[8/8] Generating log files...${NC}"

    # Create application.log
    echo -e "  ${CYAN}Generating application.log...${NC}"
    cat > "$TEMP_DIR/application.log" <<'EOF'
2024-01-23 08:00:01 INFO  [main] Application started successfully
2024-01-23 08:00:02 INFO  [scheduler] Scheduled job 'DataSync' initialized
2024-01-23 08:00:05 INFO  [database] Database connection pool created (size: 10)
2024-01-23 08:05:10 INFO  [api] Processing request: GET /api/customers?page=1
2024-01-23 08:05:11 INFO  [api] Request completed in 234ms
2024-01-23 08:10:15 WARN  [cache] Cache miss for key: customer_1001
2024-01-23 08:10:16 INFO  [database] Query executed: SELECT * FROM customers WHERE id = 1001
2024-01-23 08:15:20 INFO  [etl] Starting ETL job: DailyCustomerSync
2024-01-23 08:15:21 INFO  [etl] Extracted 1250 records from source
2024-01-23 08:15:45 INFO  [etl] Transformed 1250 records
2024-01-23 08:16:10 INFO  [etl] Loaded 1250 records to target
2024-01-23 08:16:11 INFO  [etl] ETL job completed successfully (duration: 51s)
2024-01-23 08:20:30 ERROR [api] Failed to process request: Connection timeout
2024-01-23 08:20:30 ERROR [api] Stack trace: ConnectionTimeoutException at line 145
2024-01-23 08:20:31 WARN  [api] Retrying request (attempt 1 of 3)
2024-01-23 08:20:35 INFO  [api] Request retry successful
2024-01-23 08:25:40 INFO  [scheduler] Executing scheduled job: HourlyReportGeneration
2024-01-23 08:26:15 INFO  [report] Report generated: sales_summary_2024-01-23.pdf
2024-01-23 08:30:00 INFO  [cleanup] Starting cleanup of temporary files
2024-01-23 08:30:05 INFO  [cleanup] Removed 127 temporary files (freed 2.3 GB)
EOF

    # Create access.log (web server style)
    echo -e "  ${CYAN}Generating access.log...${NC}"
    cat > "$TEMP_DIR/access.log" <<'EOF'
192.168.1.100 - - [23/Jan/2024:08:00:01 +0000] "GET /api/health HTTP/1.1" 200 15 "-" "HealthCheckBot/1.0"
192.168.1.105 - user1 [23/Jan/2024:08:05:10 +0000] "GET /api/customers?page=1 HTTP/1.1" 200 4523 "-" "Mozilla/5.0"
192.168.1.105 - user1 [23/Jan/2024:08:05:45 +0000] "GET /api/products?category=electronics HTTP/1.1" 200 8734 "-" "Mozilla/5.0"
192.168.1.110 - user2 [23/Jan/2024:08:10:20 +0000] "POST /api/orders HTTP/1.1" 201 1245 "-" "Mozilla/5.0"
192.168.1.115 - - [23/Jan/2024:08:15:30 +0000] "GET /api/reports/daily HTTP/1.1" 200 15678 "-" "Python/3.9"
192.168.1.105 - user1 [23/Jan/2024:08:20:15 +0000] "PUT /api/customers/1001 HTTP/1.1" 200 876 "-" "Mozilla/5.0"
192.168.1.120 - admin [23/Jan/2024:08:25:00 +0000] "GET /admin/dashboard HTTP/1.1" 200 23456 "-" "Mozilla/5.0"
192.168.1.125 - - [23/Jan/2024:08:30:10 +0000] "GET /api/invalid-endpoint HTTP/1.1" 404 234 "-" "curl/7.68.0"
192.168.1.110 - user2 [23/Jan/2024:08:35:20 +0000] "DELETE /api/cart/items/123 HTTP/1.1" 204 0 "-" "Mozilla/5.0"
192.168.1.130 - user3 [23/Jan/2024:08:40:30 +0000] "GET /api/products/search?q=laptop HTTP/1.1" 200 5432 "-" "Mozilla/5.0"
EOF

    # Create error.log
    echo -e "  ${CYAN}Generating error.log...${NC}"
    cat > "$TEMP_DIR/error.log" <<'EOF'
[2024-01-23 08:20:30] ERROR: Database connection failed - Connection refused (ECONNREFUSED)
[2024-01-23 08:20:30] Stack: at TCPConnectWrap.afterConnect [as oncomplete] (net.js:1148:16)
[2024-01-23 08:35:45] WARNING: API rate limit exceeded for IP: 192.168.1.150
[2024-01-23 08:42:10] ERROR: File not found - /data/imports/missing_file.csv
[2024-01-23 09:15:20] ERROR: Authentication failed for user: invalid_user
[2024-01-23 09:30:00] WARNING: Disk space low on volume /mnt/data (85% used)
[2024-01-23 09:45:30] ERROR: JSON parse error in file: api_response.json at line 45
[2024-01-23 10:00:15] WARNING: Slow query detected: SELECT * FROM large_table (duration: 15.3s)
EOF

    # Upload log files to MinIO
    echo -e "  ${CYAN}Uploading log files to MinIO...${NC}"
    mc cp "$TEMP_DIR/application.log" "${MINIO_ALIAS}/${BUCKET_LOGS}/app/" > /dev/null 2>&1
    mc cp "$TEMP_DIR/access.log" "${MINIO_ALIAS}/${BUCKET_LOGS}/web/" > /dev/null 2>&1
    mc cp "$TEMP_DIR/error.log" "${MINIO_ALIAS}/${BUCKET_LOGS}/error/" > /dev/null 2>&1

    echo -e "${GREEN}  [OK] Log files generated and uploaded${NC}"
}

# ------------------------------------------------------------------------------
# Function: Generate Parquet Files (if Python available)
# ------------------------------------------------------------------------------
generate_parquet_files() {
    if ! command -v python3 &> /dev/null; then
        echo -e "${YELLOW}[SKIP] Python3 not found - skipping Parquet generation${NC}"
        return 0
    fi

    echo -e "${BLUE}[BONUS] Generating Parquet files...${NC}"

    # Create Python script to generate Parquet file
    cat > "$TEMP_DIR/generate_parquet.py" <<'PYEOF'
import sys
try:
    import pandas as pd
    import pyarrow.parquet as pq

    # Create sample dataframe
    data = {
        'transaction_id': range(1, 101),
        'customer_id': [1000 + (i % 12) for i in range(100)],
        'product_id': [f'P{str(i % 12 + 1).zfill(3)}' for i in range(100)],
        'amount': [round(10 + (i * 3.7) % 1000, 2) for i in range(100)],
        'quantity': [(i % 5) + 1 for i in range(100)],
        'transaction_date': pd.date_range('2024-01-01', periods=100, freq='H')
    }

    df = pd.DataFrame(data)

    # Write to Parquet
    output_file = sys.argv[1]
    df.to_parquet(output_file, engine='pyarrow', compression='snappy')

    print("Parquet file generated successfully")
    sys.exit(0)

except ImportError as e:
    print(f"Missing required library: {e}")
    sys.exit(1)
except Exception as e:
    print(f"Error generating Parquet file: {e}")
    sys.exit(1)
PYEOF

    # Try to generate Parquet file
    if python3 "$TEMP_DIR/generate_parquet.py" "$TEMP_DIR/transactions.parquet" > /dev/null 2>&1; then
        echo -e "  ${CYAN}Uploading Parquet file to MinIO...${NC}"
        mc cp "$TEMP_DIR/transactions.parquet" "${MINIO_ALIAS}/${BUCKET_RAW}/parquet/" > /dev/null 2>&1
        echo -e "${GREEN}  [OK] Parquet file generated and uploaded${NC}"
    else
        echo -e "${YELLOW}  [SKIP] Could not generate Parquet (missing pandas/pyarrow)${NC}"
        echo -e "${GRAY}  Install with: pip3 install pandas pyarrow${NC}"
    fi
}

# ------------------------------------------------------------------------------
# Function: Display Summary
# ------------------------------------------------------------------------------
display_summary() {
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Data Population Complete!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""

    echo -e "${CYAN}Buckets created:${NC}"
    echo -e "  ${GREEN}✓${NC} ${BUCKET_RAW} - Raw data landing zone"
    echo -e "  ${GREEN}✓${NC} ${BUCKET_STAGING} - Staging area for transformations"
    echo -e "  ${GREEN}✓${NC} ${BUCKET_CURATED} - Curated, processed data"
    echo -e "  ${GREEN}✓${NC} ${BUCKET_LOGS} - Application and process logs"
    echo -e "  ${GREEN}✓${NC} ${BUCKET_ARCHIVE} - Historical data archives"
    echo ""

    echo -e "${CYAN}Data files uploaded:${NC}"
    echo -e "  ${MAGENTA}CSV Files:${NC}"
    echo -e "    - customers.csv (12 records)"
    echo -e "    - products.csv (12 records)"
    echo -e "    - sales.csv (15 records)"
    echo ""
    echo -e "  ${MAGENTA}JSON Files:${NC}"
    echo -e "    - api_response.json (nested API response)"
    echo -e "    - user_events.json (event stream, JSONL format)"
    echo -e "    - config.json (configuration data)"
    echo ""
    echo -e "  ${MAGENTA}XML Files:${NC}"
    echo -e "    - inventory.xml (warehouse inventory)"
    echo -e "    - employees.xml (HR data)"
    echo ""
    echo -e "  ${MAGENTA}Log Files:${NC}"
    echo -e "    - application.log (application logs)"
    echo -e "    - access.log (web access logs)"
    echo -e "    - error.log (error logs)"
    echo ""

    echo -e "${CYAN}Access MinIO Console:${NC}"
    echo -e "  URL: ${MINIO_ENDPOINT/9000/9002}"
    echo -e "  User: ${MINIO_USER}"
    echo ""

    echo -e "${CYAN}Next Steps for Pentaho Data Integration:${NC}"
    echo -e "  1. Configure VFS S3 connection in PDI:"
    echo -e "     ${GRAY}Endpoint: ${MINIO_ENDPOINT}${NC}"
    echo -e "     ${GRAY}Access Key: ${MINIO_USER}${NC}"
    echo -e "     ${GRAY}Secret Key: ${MINIO_PASSWORD}${NC}"
    echo ""
    echo -e "  2. Create transformations to read from buckets:"
    echo -e "     ${GRAY}s3a://${BUCKET_RAW}/csv/customers.csv${NC}"
    echo -e "     ${GRAY}s3a://${BUCKET_RAW}/json/api_response.json${NC}"
    echo -e "     ${GRAY}s3a://${BUCKET_RAW}/xml/inventory.xml${NC}"
    echo ""
    echo -e "  3. Explore data using MinIO Client:"
    echo -e "     ${GRAY}mc ls ${MINIO_ALIAS}/${BUCKET_RAW} --recursive${NC}"
    echo ""
}

# ------------------------------------------------------------------------------
# Main Execution
# ------------------------------------------------------------------------------
main() {
    # Step 1: Check dependencies
    if ! check_dependencies; then
        exit 1
    fi
    echo ""

    # Step 2: Check MinIO connectivity
    if ! check_minio_connectivity; then
        exit 1
    fi
    echo ""

    # Step 3: Configure MinIO Client
    if ! configure_minio_client; then
        exit 1
    fi
    echo ""

    # Step 4: Create buckets
    if ! create_buckets; then
        exit 1
    fi
    echo ""

    # Step 5: Generate and upload CSV files
    generate_csv_files
    echo ""

    # Step 6: Generate and upload JSON files
    generate_json_files
    echo ""

    # Step 7: Generate and upload XML files
    generate_xml_files
    echo ""

    # Step 8: Generate and upload log files
    generate_log_files
    echo ""

    # Bonus: Generate Parquet files if Python is available
    generate_parquet_files
    echo ""

    # Display summary
    display_summary

    exit 0
}

# Run main function
main
