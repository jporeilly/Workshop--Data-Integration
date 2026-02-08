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
WHITE='\033[1;37m'   # Bright white for better contrast
GRAY='\033[0;90m'    # Dark gray (for less important info)
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
        echo -e "  # MinIO Client:"
        echo -e "  ${CYAN}wget https://dl.min.io/client/mc/release/linux-amd64/mc${NC}"
        echo -e "  ${CYAN}chmod +x mc && sudo mv mc /usr/local/bin/${NC}"
        echo -e ""
        echo -e "  # curl, jq:"
        echo -e "  ${CYAN}sudo apt install curl jq${NC}"
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
        echo -e "  ${CYAN}sudo /opt/minio/run-docker-minio.sh${NC}"
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
            echo -e "  ${YELLOW}[EXISTS] Bucket: ${bucket}${NC}"
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
    # Extended with 6 additional products (P013-P018) for enhanced Workshop 2 scenarios
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
P013,External SSD 1TB,Electronics,149.99,120,TechSupply Inc,2024-01-21
P014,Bluetooth Trackpad,Electronics,79.99,95,TechSupply Inc,2024-01-22
P015,Monitor Arm Mount,Furniture,89.99,50,ComfortSeats Ltd,2024-01-23
P016,Cable Management Kit,Furniture,24.99,200,LightWorks Co,2024-01-24
P017,Portable Charger,Electronics,39.99,300,ConnectPro Inc,2024-01-25
P018,Laptop Stand,Furniture,54.99,85,ComfortSeats Ltd,2024-01-26
EOF

    # Create sales.csv
    # REALISTIC SALES DATA - Updated dates for current year with varied purchase patterns
    #
    # Date Strategy: Recent dates (last 90 days) for realistic recency metrics
    # - Mix of first-time buyers and repeat customers
    # - Some customers with multiple purchases to demonstrate tenure
    # - Dates spread across last 3 months for meaningful days_since_last_purchase
    #
    # Purchase Patterns:
    # - Single purchase customers: 1004, 1005, 1006, 1007, 1008, 1009, 1010, 1011, 1012 (9 customers)
    # - Repeat customers: 1001 (2), 1002 (2), 1003 (2) (3 customers with 2 purchases each)
    echo -e "  ${CYAN}Generating sales.csv with current-year dates...${NC}"
    cat > "$TEMP_DIR/sales.csv" <<'EOF'
sale_id,customer_id,product_id,quantity,sale_date,sale_amount,payment_method,status
S001,1001,P001,1,2025-11-15,1299.99,credit_card,completed
S002,1002,P003,2,2025-12-01,699.98,paypal,completed
S003,1003,P002,1,2025-12-10,29.99,credit_card,completed
S004,1001,P005,1,2026-01-28,459.99,credit_card,completed
S005,1004,P006,1,2026-01-15,129.99,debit_card,completed
S006,1005,P008,3,2026-01-20,119.97,paypal,completed
S007,1006,P009,1,2025-12-28,279.99,credit_card,completed
S008,1007,P004,1,2026-01-10,599.99,credit_card,completed
S009,1008,P007,2,2026-01-25,99.98,paypal,completed
S010,1009,P011,1,2026-01-18,89.99,debit_card,completed
S011,1010,P012,1,2025-12-05,199.99,credit_card,completed
S012,1002,P010,4,2026-02-01,139.96,paypal,completed
S013,1003,P001,1,2026-02-02,1299.99,credit_card,completed
S014,1011,P005,2,2026-01-22,919.98,credit_card,completed
S015,1012,P002,3,2025-12-15,89.97,paypal,completed
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
    # ENHANCED EVENT DATA - Comprehensive user behavior for Customer 360 analysis
    #
    # 40+ events across 12 customers demonstrating:
    # - Complete conversion funnels (page_view → add_to_cart → checkout → purchase)
    # - Multiple sessions per user with realistic time gaps
    # - Diverse event types (search, product_view, wishlist, review, support)
    # - Varied engagement levels (high, medium, low, abandoned cart)
    # - Timestamp progression over 7 days
    #
    # User Segments:
    # - High Converters: 1001, 1005, 1009 (full funnel completion, multiple purchases)
    # - Window Shoppers: 1002, 1006, 1010 (browsing, cart adds, no checkout)
    # - Researchers: 1003, 1007 (searches, product views, reviews)
    # - Engaged Users: 1004, 1008 (wishlist, support, moderate activity)
    # - Low Activity: 1011, 1012 (1-2 page views only)
    echo -e "  ${CYAN}Generating user_events.json (40+ events)...${NC}"
    cat > "$TEMP_DIR/user_events.json" <<'EOF'
{"event_id":"evt_001","user_id":1001,"event_type":"page_view","page":"/home","timestamp":"2024-01-20T08:00:00Z","session_id":"sess_1001_a"}
{"event_id":"evt_002","user_id":1001,"event_type":"search","query":"laptop","timestamp":"2024-01-20T08:02:00Z","session_id":"sess_1001_a"}
{"event_id":"evt_003","user_id":1001,"event_type":"page_view","page":"/products/laptops","timestamp":"2024-01-20T08:03:00Z","session_id":"sess_1001_a"}
{"event_id":"evt_004","user_id":1001,"event_type":"product_view","product_id":"P001","timestamp":"2024-01-20T08:05:00Z","session_id":"sess_1001_a"}
{"event_id":"evt_005","user_id":1001,"event_type":"add_to_cart","product_id":"P001","timestamp":"2024-01-20T08:07:00Z","session_id":"sess_1001_a"}
{"event_id":"evt_006","user_id":1001,"event_type":"checkout","cart_value":1299.99,"timestamp":"2024-01-20T08:10:00Z","session_id":"sess_1001_a"}
{"event_id":"evt_007","user_id":1001,"event_type":"purchase","order_id":"ORD-2024-001","amount":1299.99,"timestamp":"2024-01-20T08:12:00Z","session_id":"sess_1001_a"}
{"event_id":"evt_008","user_id":1002,"event_type":"page_view","page":"/home","timestamp":"2024-01-20T09:00:00Z","session_id":"sess_1002_a"}
{"event_id":"evt_009","user_id":1002,"event_type":"page_view","page":"/products","timestamp":"2024-01-20T09:05:00Z","session_id":"sess_1002_a"}
{"event_id":"evt_010","user_id":1002,"event_type":"product_view","product_id":"P003","timestamp":"2024-01-20T09:10:00Z","session_id":"sess_1002_a"}
{"event_id":"evt_011","user_id":1002,"event_type":"add_to_cart","product_id":"P003","timestamp":"2024-01-20T09:12:00Z","session_id":"sess_1002_a"}
{"event_id":"evt_012","user_id":1003,"event_type":"search","query":"wireless mouse","timestamp":"2024-01-20T10:00:00Z","session_id":"sess_1003_a"}
{"event_id":"evt_013","user_id":1003,"event_type":"product_view","product_id":"P002","timestamp":"2024-01-20T10:05:00Z","session_id":"sess_1003_a"}
{"event_id":"evt_014","user_id":1003,"event_type":"product_view","product_id":"P004","timestamp":"2024-01-20T10:08:00Z","session_id":"sess_1003_a"}
{"event_id":"evt_015","user_id":1004,"event_type":"page_view","page":"/products/electronics","timestamp":"2024-01-20T11:00:00Z","session_id":"sess_1004_a"}
{"event_id":"evt_016","user_id":1004,"event_type":"product_view","product_id":"P005","timestamp":"2024-01-20T11:05:00Z","session_id":"sess_1004_a"}
{"event_id":"evt_017","user_id":1004,"event_type":"wishlist_add","product_id":"P005","timestamp":"2024-01-20T11:08:00Z","session_id":"sess_1004_a"}
{"event_id":"evt_018","user_id":1005,"event_type":"page_view","page":"/home","timestamp":"2024-01-21T08:00:00Z","session_id":"sess_1005_a"}
{"event_id":"evt_019","user_id":1005,"event_type":"search","query":"office chair","timestamp":"2024-01-21T08:03:00Z","session_id":"sess_1005_a"}
{"event_id":"evt_020","user_id":1005,"event_type":"product_view","product_id":"P003","timestamp":"2024-01-21T08:05:00Z","session_id":"sess_1005_a"}
{"event_id":"evt_021","user_id":1005,"event_type":"add_to_cart","product_id":"P003","quantity":2,"timestamp":"2024-01-21T08:08:00Z","session_id":"sess_1005_a"}
{"event_id":"evt_022","user_id":1005,"event_type":"checkout","cart_value":699.98,"timestamp":"2024-01-21T08:12:00Z","session_id":"sess_1005_a"}
{"event_id":"evt_023","user_id":1005,"event_type":"purchase","order_id":"ORD-2024-002","amount":699.98,"timestamp":"2024-01-21T08:15:00Z","session_id":"sess_1005_a"}
{"event_id":"evt_024","user_id":1002,"event_type":"page_view","page":"/cart","timestamp":"2024-01-21T14:00:00Z","session_id":"sess_1002_b"}
{"event_id":"evt_025","user_id":1006,"event_type":"page_view","page":"/products","timestamp":"2024-01-22T09:00:00Z","session_id":"sess_1006_a"}
{"event_id":"evt_026","user_id":1006,"event_type":"product_view","product_id":"P006","timestamp":"2024-01-22T09:05:00Z","session_id":"sess_1006_a"}
{"event_id":"evt_027","user_id":1006,"event_type":"add_to_cart","product_id":"P006","timestamp":"2024-01-22T09:08:00Z","session_id":"sess_1006_a"}
{"event_id":"evt_028","user_id":1007,"event_type":"search","query":"monitor 4k","timestamp":"2024-01-22T10:00:00Z","session_id":"sess_1007_a"}
{"event_id":"evt_029","user_id":1007,"event_type":"product_view","product_id":"P007","timestamp":"2024-01-22T10:05:00Z","session_id":"sess_1007_a"}
{"event_id":"evt_030","user_id":1007,"event_type":"review_read","product_id":"P007","timestamp":"2024-01-22T10:10:00Z","session_id":"sess_1007_a"}
{"event_id":"evt_031","user_id":1008,"event_type":"page_view","page":"/support","timestamp":"2024-01-23T08:00:00Z","session_id":"sess_1008_a"}
{"event_id":"evt_032","user_id":1008,"event_type":"support_chat","topic":"shipping","timestamp":"2024-01-23T08:05:00Z","session_id":"sess_1008_a"}
{"event_id":"evt_033","user_id":1008,"event_type":"page_view","page":"/account","timestamp":"2024-01-23T08:15:00Z","session_id":"sess_1008_a"}
{"event_id":"evt_034","user_id":1009,"event_type":"page_view","page":"/products/laptops","timestamp":"2024-01-23T09:00:00Z","session_id":"sess_1009_a"}
{"event_id":"evt_035","user_id":1009,"event_type":"product_view","product_id":"P001","timestamp":"2024-01-23T09:05:00Z","session_id":"sess_1009_a"}
{"event_id":"evt_036","user_id":1009,"event_type":"add_to_cart","product_id":"P001","timestamp":"2024-01-23T09:08:00Z","session_id":"sess_1009_a"}
{"event_id":"evt_037","user_id":1009,"event_type":"add_to_cart","product_id":"P002","timestamp":"2024-01-23T09:12:00Z","session_id":"sess_1009_a"}
{"event_id":"evt_038","user_id":1009,"event_type":"checkout","cart_value":1349.98,"timestamp":"2024-01-23T09:15:00Z","session_id":"sess_1009_a"}
{"event_id":"evt_039","user_id":1009,"event_type":"purchase","order_id":"ORD-2024-003","amount":1349.98,"timestamp":"2024-01-23T09:18:00Z","session_id":"sess_1009_a"}
{"event_id":"evt_040","user_id":1010,"event_type":"page_view","page":"/home","timestamp":"2024-01-24T08:00:00Z","session_id":"sess_1010_a"}
{"event_id":"evt_041","user_id":1010,"event_type":"product_view","product_id":"P008","timestamp":"2024-01-24T08:05:00Z","session_id":"sess_1010_a"}
{"event_id":"evt_042","user_id":1010,"event_type":"add_to_cart","product_id":"P008","timestamp":"2024-01-24T08:08:00Z","session_id":"sess_1010_a"}
{"event_id":"evt_043","user_id":1011,"event_type":"page_view","page":"/home","timestamp":"2024-01-25T10:00:00Z","session_id":"sess_1011_a"}
{"event_id":"evt_044","user_id":1012,"event_type":"page_view","page":"/products","timestamp":"2024-01-26T11:00:00Z","session_id":"sess_1012_a"}
{"event_id":"evt_045","user_id":1001,"event_type":"page_view","page":"/account/orders","timestamp":"2024-01-26T15:00:00Z","session_id":"sess_1001_b"}
{"event_id":"evt_046","user_id":1003,"event_type":"review_write","product_id":"P002","rating":5,"timestamp":"2024-01-26T16:00:00Z","session_id":"sess_1003_b"}
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
    # OPTIMIZED INVENTORY - Focus on variance calculations with minimal nulls
    # 16 warehouse items with full data, only 2 missing scenarios
    #
    # PERFECT MATCHES (3): variance = 0
    # MINOR OVERSTOCK (3): +1 to +10 units
    # MAJOR OVERSTOCK (2): +11 to +50 units
    # MINOR UNDERSTOCK (3): -1 to -10 units
    # MAJOR UNDERSTOCK (3): -11 to -50 units
    # CRITICAL UNDERSTOCK (2): >-50 units or <20% remaining
    # MISSING IN CATALOG (1): orphan item P099
    # MISSING IN WAREHOUSE (2): only P011, P012 missing - REDUCED from 6!
    echo -e "  ${CYAN}Generating inventory.xml...${NC}"
    cat > "$TEMP_DIR/inventory.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<inventory>
    <metadata>
        <export_date>2024-01-23</export_date>
        <warehouse>Main Warehouse</warehouse>
        <location>New York, NY</location>
        <system>WarehouseManagementSystem v2.3</system>
        <last_full_count>2024-01-15</last_full_count>
    </metadata>
    <items>
        <!-- ========== PERFECT MATCHES (3 items) - Variance = 0 ========== -->

        <item>
            <sku>P001</sku>
            <name>Laptop Pro 15</name>
            <category>Electronics</category>
            <quantity>45</quantity>
            <location>A-12-3</location>
            <last_checked>2024-01-20</last_checked>
            <status>PERFECT MATCH - No action needed</status>
        </item>

        <item>
            <sku>P004</sku>
            <name>Standing Desk</name>
            <category>Furniture</category>
            <quantity>34</quantity>
            <location>C-10-2</location>
            <last_checked>2024-01-22</last_checked>
            <status>PERFECT MATCH - No action needed</status>
        </item>

        <item>
            <sku>P017</sku>
            <name>Portable Charger</name>
            <category>Electronics</category>
            <quantity>300</quantity>
            <location>A-20-1</location>
            <last_checked>2024-01-23</last_checked>
            <status>PERFECT MATCH - No action needed</status>
        </item>

        <!-- ========== MINOR OVERSTOCK (3 items) - +1 to +10 units ========== -->

        <item>
            <sku>P013</sku>
            <name>External SSD 1TB</name>
            <category>Electronics</category>
            <quantity>125</quantity>
            <location>A-18-2</location>
            <last_checked>2024-01-21</last_checked>
            <status>MINOR OVERSTOCK +5 units - Low priority, monitor trend</status>
        </item>

        <item>
            <sku>P016</sku>
            <name>Cable Management Kit</name>
            <category>Furniture</category>
            <quantity>205</quantity>
            <location>C-15-3</location>
            <last_checked>2024-01-24</last_checked>
            <status>MINOR OVERSTOCK +5 units - Low priority, monitor trend</status>
        </item>

        <item>
            <sku>P010</sku>
            <name>Ergonomic Footrest</name>
            <category>Furniture</category>
            <quantity>152</quantity>
            <location>C-09-2</location>
            <last_checked>2024-01-20</last_checked>
            <status>MINOR OVERSTOCK +7 units - Low priority, monitor trend</status>
        </item>

        <!-- ========== MAJOR OVERSTOCK (2 items) - +11 to +50 units ========== -->

        <item>
            <sku>P002</sku>
            <name>Wireless Mouse</name>
            <category>Electronics</category>
            <quantity>250</quantity>
            <location>B-05-1</location>
            <last_checked>2024-01-21</last_checked>
            <status>MAJOR OVERSTOCK +20 units - Review ordering patterns</status>
        </item>

        <item>
            <sku>P006</sku>
            <name>Mechanical Keyboard</name>
            <category>Electronics</category>
            <quantity>200</quantity>
            <location>A-15-2</location>
            <last_checked>2024-01-20</last_checked>
            <status>MAJOR OVERSTOCK +44 units - Investigate excess inventory</status>
        </item>

        <!-- ========== MINOR UNDERSTOCK (3 items) - -1 to -10 units ========== -->

        <item>
            <sku>P014</sku>
            <name>Bluetooth Trackpad</name>
            <category>Electronics</category>
            <quantity>90</quantity>
            <location>A-19-1</location>
            <last_checked>2024-01-22</last_checked>
            <status>MINOR UNDERSTOCK -5 units - Monitor closely</status>
        </item>

        <item>
            <sku>P015</sku>
            <name>Monitor Arm Mount</name>
            <category>Furniture</category>
            <quantity>48</quantity>
            <location>C-12-4</location>
            <last_checked>2024-01-23</last_checked>
            <status>MINOR UNDERSTOCK -2 units - Monitor closely</status>
        </item>

        <item>
            <sku>P008</sku>
            <name>Desk Lamp LED</name>
            <category>Furniture</category>
            <quantity>172</quantity>
            <location>C-07-1</location>
            <last_checked>2024-01-19</last_checked>
            <status>MINOR UNDERSTOCK -8 units - Monitor closely</status>
        </item>

        <!-- ========== MAJOR UNDERSTOCK (3 items) - -11 to -50 units ========== -->

        <item>
            <sku>P003</sku>
            <name>Office Chair Deluxe</name>
            <category>Furniture</category>
            <quantity>60</quantity>
            <location>C-08-4</location>
            <last_checked>2024-01-19</last_checked>
            <status>MAJOR UNDERSTOCK -18 units - Reorder soon</status>
        </item>

        <item>
            <sku>P007</sku>
            <name>USB-C Hub</name>
            <category>Electronics</category>
            <quantity>280</quantity>
            <location>B-03-5</location>
            <last_checked>2024-01-22</last_checked>
            <status>MAJOR UNDERSTOCK -30 units - Reorder soon</status>
        </item>

        <item>
            <sku>P009</sku>
            <name>Noise Cancelling Headphones</name>
            <category>Electronics</category>
            <quantity>55</quantity>
            <location>A-14-3</location>
            <last_checked>2024-01-21</last_checked>
            <status>MAJOR UNDERSTOCK -12 units - Reorder soon</status>
        </item>

        <!-- ========== CRITICAL UNDERSTOCK (2 items) - Severe shortage ========== -->

        <item>
            <sku>P018</sku>
            <name>Laptop Stand</name>
            <category>Furniture</category>
            <quantity>15</quantity>
            <location>C-14-2</location>
            <last_checked>2024-01-26</last_checked>
            <status>CRITICAL UNDERSTOCK -70 units (82% shortage!) - URGENT REORDER</status>
        </item>

        <item>
            <sku>P005</sku>
            <name>4K Monitor 27inch</name>
            <category>Electronics</category>
            <quantity>12</quantity>
            <location>A-13-1</location>
            <last_checked>2024-01-18</last_checked>
            <status>CRITICAL UNDERSTOCK -80 units (87% shortage!) - URGENT REORDER</status>
        </item>

        <!-- ========== MISSING IN CATALOG (1 item) - Orphan/Discontinued ========== -->

        <item>
            <sku>P099</sku>
            <name>Legacy Tablet (Discontinued)</name>
            <category>Electronics</category>
            <quantity>12</quantity>
            <location>D-01-1</location>
            <last_checked>2024-01-15</last_checked>
            <status>ORPHAN - Not in catalog, needs clearance</status>
        </item>

        <!-- ONLY 2 MISSING IN WAREHOUSE: P011 (Webcam HD) and P012 (Conference Speakerphone) -->
        <!-- These items are in the catalog but NOT tracked in the warehouse system -->
        <!-- This represents only 11% of catalog items with null warehouse data (was 33%!) -->
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

    # Create application.log with multi-hour data showing anomaly patterns
    # SCENARIO: Normal operation hours 08-09, ERROR SPIKE at hour 10 (anomaly), recovery at hour 11
    echo -e "  ${CYAN}Generating application.log...${NC}"
    cat > "$TEMP_DIR/application.log" <<'EOF'
2024-01-23 08:00:01 INFO  [main] Application started successfully
2024-01-23 08:00:02 INFO  [scheduler] Scheduled job 'DataSync' initialized
2024-01-23 08:00:05 INFO  [database] Database connection pool created (size: 10)
2024-01-23 08:05:10 INFO  [api] Processing request: GET /api/customers?page=1
2024-01-23 08:05:11 INFO  [api] Request completed in 234ms
2024-01-23 08:10:15 INFO  [cache] Cache hit for key: customer_1001
2024-01-23 08:10:16 INFO  [database] Query executed: SELECT * FROM customers WHERE id = 1001
2024-01-23 08:15:20 INFO  [etl] Starting ETL job: DailyCustomerSync
2024-01-23 08:15:21 INFO  [etl] Extracted 1250 records from source
2024-01-23 08:15:45 INFO  [etl] Transformed 1250 records
2024-01-23 08:16:10 INFO  [etl] Loaded 1250 records to target
2024-01-23 08:16:11 INFO  [etl] ETL job completed successfully (duration: 51s)
2024-01-23 08:20:30 ERROR [api] Failed to process request: Connection timeout
2024-01-23 08:20:35 INFO  [api] Request retry successful
2024-01-23 08:25:40 INFO  [scheduler] Executing scheduled job: HourlyReportGeneration
2024-01-23 08:26:15 INFO  [report] Report generated: sales_summary_2024-01-23.pdf
2024-01-23 08:30:00 INFO  [cleanup] Starting cleanup of temporary files
2024-01-23 08:30:05 INFO  [cleanup] Removed 127 temporary files (freed 2.3 GB)
2024-01-23 08:35:12 INFO  [api] Processing request: GET /api/products?category=electronics
2024-01-23 08:35:13 INFO  [api] Request completed in 189ms
2024-01-23 08:40:20 INFO  [scheduler] Scheduled job 'CacheWarmer' initialized
2024-01-23 08:45:30 INFO  [cache] Cache warming completed for 500 keys
2024-01-23 08:50:15 WARN  [database] Connection pool usage at 60%
2024-01-23 08:55:40 INFO  [api] Processing request: POST /api/orders
2024-01-23 08:55:41 INFO  [api] Request completed in 456ms
2024-01-23 09:00:01 INFO  [scheduler] Hourly maintenance task started
2024-01-23 09:00:05 INFO  [database] Maintenance: analyzing tables
2024-01-23 09:05:10 INFO  [api] Processing request: GET /api/customers?page=2
2024-01-23 09:05:11 INFO  [api] Request completed in 201ms
2024-01-23 09:10:15 INFO  [etl] Starting ETL job: HourlyProductSync
2024-01-23 09:10:20 INFO  [etl] Extracted 350 records from source
2024-01-23 09:10:45 INFO  [etl] Transformed 350 records
2024-01-23 09:11:10 INFO  [etl] Loaded 350 records to target
2024-01-23 09:11:15 INFO  [etl] ETL job completed successfully (duration: 55s)
2024-01-23 09:20:30 ERROR [cache] Cache eviction failure for key: product_catalog
2024-01-23 09:23:15 WARN  [database] Connection pool approaching limit: 75% utilization
2024-01-23 09:25:40 INFO  [scheduler] Executing scheduled job: DataBackup
2024-01-23 09:30:00 INFO  [backup] Backup started for database: analytics_db
2024-01-23 09:35:15 INFO  [backup] Backup completed successfully (size: 2.5 GB)
2024-01-23 09:40:20 INFO  [api] Processing request: GET /api/sales/summary
2024-01-23 09:40:21 INFO  [api] Request completed in 312ms
2024-01-23 09:45:30 WARN  [database] Slow query detected: duration 3.2s
2024-01-23 09:50:40 INFO  [api] Processing request: PUT /api/customers/1005
2024-01-23 09:50:41 INFO  [api] Request completed in 178ms
2024-01-23 09:52:20 WARN  [api] Response time degraded: average 850ms (threshold: 500ms)
2024-01-23 09:55:50 INFO  [scheduler] Scheduled job 'HourlyReportGeneration' queued
2024-01-23 09:57:15 WARN  [monitor] High memory usage detected: 85% of heap used
2024-01-23 10:00:01 ERROR [database] Connection timeout: host db.example.com unreachable
2024-01-23 10:00:05 ERROR [api] Failed to process request: Database connection error
2024-01-23 10:00:10 ERROR [api] Failed to process request: Database connection error
2024-01-23 10:00:15 ERROR [etl] ETL job failed: Cannot connect to database
2024-01-23 10:00:20 WARN  [api] Request queue backing up: 25 pending requests
2024-01-23 10:05:01 ERROR [database] Connection pool exhausted: all connections timed out
2024-01-23 10:05:05 ERROR [api] Failed to process request: No database connections available
2024-01-23 10:05:10 ERROR [api] Failed to process request: No database connections available
2024-01-23 10:05:15 ERROR [scheduler] Failed to execute job: DatabaseBackupJob
2024-01-23 10:05:20 WARN  [api] Request queue critical: 50 pending requests
2024-01-23 10:10:01 ERROR [database] Connection attempt 1 failed: Connection refused
2024-01-23 10:10:05 ERROR [api] Failed to process request: Connection refused
2024-01-23 10:10:10 ERROR [api] Failed to process request: Connection refused
2024-01-23 10:10:15 ERROR [cache] Cache write failure: Backend unavailable
2024-01-23 10:10:20 WARN  [monitor] System health check failed: database unreachable
2024-01-23 10:15:01 ERROR [database] Connection attempt 2 failed: Connection refused
2024-01-23 10:15:05 ERROR [api] Failed to process request: Service unavailable
2024-01-23 10:15:10 ERROR [etl] ETL job timeout: DailyCustomerSync exceeded 5 minute limit
2024-01-23 10:15:15 WARN  [api] Enabling circuit breaker for database calls
2024-01-23 10:15:20 ERROR [api] Request failed: Cannot reach backend services
2024-01-23 10:15:25 ERROR [database] Connection pool completely drained
2024-01-23 10:15:30 ERROR [api] HTTP 503 Service Unavailable returned to client
2024-01-23 10:15:35 ERROR [scheduler] Unable to execute scheduled jobs: no database connection
2024-01-23 10:15:40 ERROR [cache] Redis connection lost: timeout after 10s
2024-01-23 10:15:45 ERROR [api] Multiple service failures detected
2024-01-23 10:15:50 ERROR [etl] All ETL pipelines suspended due to database failure
2024-01-23 10:15:55 WARN  [monitor] Alerting system: CRITICAL database outage
2024-01-23 10:16:00 ERROR [api] Service degradation: 0% success rate
2024-01-23 10:16:05 ERROR [database] Automatic failover failed: no replica available
2024-01-23 10:16:10 ERROR [api] Client requests timing out across all endpoints
2024-01-23 10:16:15 ERROR [scheduler] Job queue blocked: 127 jobs pending
2024-01-23 10:16:20 ERROR [etl] Data pipeline failure: no writes in 15 minutes
2024-01-23 10:16:25 ERROR [api] Load balancer reporting all backends down
2024-01-23 10:16:30 ERROR [monitoring] Unable to write metrics: storage backend offline
2024-01-23 10:16:35 ERROR [api] Request rejection rate: 100%
2024-01-23 10:16:40 ERROR [database] Recovery process failed: corruption detected
2024-01-23 10:16:45 ERROR [etl] Critical: Data loss risk detected
2024-01-23 10:16:50 ERROR [api] System unresponsive: manual intervention required
2024-01-23 10:16:55 ERROR [database] Backup system also failing: cascading failure
2024-01-23 10:17:00 ERROR [api] Emergency shutdown initiated for data protection
2024-01-23 10:17:05 ERROR [etl] All data ingestion halted
2024-01-23 10:17:10 ERROR [monitoring] Alert delivery failed: notification system down
2024-01-23 10:17:15 ERROR [api] Total service outage: 0 requests processed
2024-01-23 10:17:20 ERROR [database] Database cluster completely offline
2024-01-23 10:17:25 ERROR [api] Customer-facing services: all unavailable
2024-01-23 10:17:30 ERROR [monitoring] Health check endpoints: all failing
2024-01-23 10:17:35 ERROR [api] Revenue loss estimated: critical business impact
2024-01-23 10:17:40 ERROR [system] Emergency escalation: senior engineers paged
2024-01-23 10:17:45 ERROR [business] SLA breach: contractual penalties triggered
2024-01-23 10:20:01 INFO  [database] Connection retry succeeded: database is back online
2024-01-23 10:20:05 INFO  [api] Circuit breaker opened: allowing requests through
2024-01-23 10:20:10 WARN  [api] Processing backlog: 50 queued requests
2024-01-23 10:25:15 INFO  [api] Backlog cleared: all pending requests processed
2024-01-23 10:30:01 INFO  [database] Connection pool restored to normal operation
2024-01-23 10:35:10 INFO  [scheduler] Resuming scheduled jobs
2024-01-23 10:40:20 INFO  [etl] Restarting failed ETL job: DailyCustomerSync
2024-01-23 10:45:30 INFO  [monitor] System health check passed: all services operational
2024-01-23 10:50:40 INFO  [api] Processing request: GET /api/customers?page=5
2024-01-23 10:50:41 INFO  [api] Request completed in 198ms
2024-01-23 10:55:50 INFO  [etl] ETL job completed successfully (retry): DailyCustomerSync
2024-01-23 11:00:01 INFO  [scheduler] Hourly maintenance task started
2024-01-23 11:05:10 INFO  [api] Processing request: GET /api/products?category=furniture
2024-01-23 11:05:11 INFO  [api] Request completed in 210ms
2024-01-23 11:10:15 INFO  [cache] Cache hit ratio: 85%
2024-01-23 11:15:20 INFO  [database] Query executed: SELECT * FROM orders WHERE date >= '2024-01-20'
2024-01-23 11:20:25 WARN  [cache] Cache miss for key: order_1234
2024-01-23 11:25:30 INFO  [api] Processing request: POST /api/reviews
2024-01-23 11:25:31 INFO  [api] Request completed in 345ms
2024-01-23 11:30:35 INFO  [scheduler] Executing scheduled job: HourlyReportGeneration
2024-01-23 11:35:40 INFO  [report] Report generated: product_analytics_2024-01-23.pdf
2024-01-23 11:40:45 INFO  [api] Processing request: GET /api/dashboard
2024-01-23 11:40:46 INFO  [api] Request completed in 567ms
2024-01-23 11:45:50 INFO  [database] Connection pool usage at 45%
2024-01-23 11:50:55 INFO  [api] Processing request: DELETE /api/cache/customer_1001
2024-01-23 11:50:56 INFO  [cache] Cache entry invalidated: customer_1001
2024-01-23 11:55:58 INFO  [scheduler] All scheduled jobs completed for hour 11
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
        'transaction_date': pd.date_range('2024-01-01', periods=100, freq='h')
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
    PARQUET_GENERATED=false

    # First, try with system Python
    if python3 "$TEMP_DIR/generate_parquet.py" "$TEMP_DIR/transactions.parquet" > /dev/null 2>&1; then
        PARQUET_GENERATED=true
    else
        # System Python failed, check for virtual environment
        # Determine the user's home directory (handle sudo case)
        if [ -n "$SUDO_USER" ]; then
            USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
        else
            USER_HOME="$HOME"
        fi

        VENV_PATH="$USER_HOME/venv"

        if [ -f "$VENV_PATH/bin/python3" ]; then
            echo -e "  ${CYAN}Trying virtual environment at $VENV_PATH...${NC}"

            # Use the venv's Python directly (no need to activate/deactivate)
            VENV_OUTPUT=$("$VENV_PATH/bin/python3" "$TEMP_DIR/generate_parquet.py" "$TEMP_DIR/transactions.parquet" 2>&1)
            if [ $? -eq 0 ]; then
                PARQUET_GENERATED=true
            else
                echo -e "  ${YELLOW}Venv error: $VENV_OUTPUT${NC}"
            fi
        fi
    fi

    # Upload if generated successfully
    if [ "$PARQUET_GENERATED" = true ]; then
        echo -e "  ${CYAN}Uploading Parquet file to MinIO...${NC}"
        mc cp "$TEMP_DIR/transactions.parquet" "${MINIO_ALIAS}/${BUCKET_RAW}/parquet/" > /dev/null 2>&1
        echo -e "${GREEN}  [OK] Parquet file generated and uploaded${NC}"
    else
        echo -e "${YELLOW}  [SKIP] Could not generate Parquet${NC}"
        echo -e "  Create venv: ${CYAN}python3 -m venv ~/venv && source ~/venv/bin/activate && pip install pandas pyarrow${NC}"
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
    echo -e "    - user_events.json (46 events, 12 users, JSONL format)"
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
    echo -e "  ${MAGENTA}Financial Data Files (Exercise 7):${NC}"
    echo -e "    - transactions.csv (63 transactions across 3 days)"
    echo -e "    - accounts.csv (13 customer accounts)"
    echo -e "    - merchants.csv (18 merchant records)"
    echo ""

    echo -e "${CYAN}Access MinIO Console:${NC}"
    echo -e "  URL: ${MINIO_ENDPOINT/9000/9002}"
    echo -e "  User: ${MINIO_USER}"
    echo ""

    echo -e "${CYAN}Next Steps for Pentaho Data Integration:${NC}"
    echo -e "  1. Configure VFS S3 connection in PDI:"
    echo -e "     Endpoint: ${CYAN}${MINIO_ENDPOINT}${NC}"
    echo -e "     Access Key: ${CYAN}${MINIO_USER}${NC}"
    echo -e "     Secret Key: ${CYAN}${MINIO_PASSWORD}${NC}"
    echo ""
    echo -e "  2. Create transformations to read from buckets:"
    echo -e "     ${CYAN}s3a://${BUCKET_RAW}/csv/customers.csv${NC}"
    echo -e "     ${CYAN}s3a://${BUCKET_RAW}/json/api_response.json${NC}"
    echo -e "     ${CYAN}s3a://${BUCKET_RAW}/xml/inventory.xml${NC}"
    echo ""
    echo -e "  3. Explore data using MinIO Client:"
    echo -e "     ${CYAN}mc ls ${MINIO_ALIAS}/${BUCKET_RAW} --recursive${NC}"
    echo ""
}

# ------------------------------------------------------------------------------
# Function: Generate Financial Data Files (Exercise 7)
# ------------------------------------------------------------------------------
generate_financial_files() {
    echo -e "${BLUE}[9/9] Generating financial data files...${NC}"

    # Generate transactions.csv (3 days of data: Jan 23-25, 2024)
    echo -e "  ${CYAN}Generating transactions.csv...${NC}"
    cat > "$TEMP_DIR/transactions.csv" <<'EOF'
transaction_id,account_id,merchant_id,amount,currency,transaction_date,status
TXN-2024-001,ACC-1001,MER-5001,45.99,USD,2024-01-23 09:15:22,APPROVED
TXN-2024-002,ACC-1002,MER-5002,1250.00,USD,2024-01-23 09:18:45,APPROVED
TXN-2024-003,ACC-1003,MER-5003,23.50,USD,2024-01-23 09:22:10,APPROVED
TXN-2024-004,ACC-1004,MER-5004,89.99,USD,2024-01-23 09:35:15,APPROVED
TXN-2024-005,ACC-1005,MER-5005,2200.00,USD,2024-01-23 09:42:30,APPROVED
TXN-2024-006,ACC-1001,MER-5006,156.75,USD,2024-01-23 10:05:45,APPROVED
TXN-2024-007,ACC-1002,MER-5001,67.20,USD,2024-01-23 10:12:18,APPROVED
TXN-2024-008,ACC-1003,MER-5007,420.00,USD,2024-01-23 10:28:33,APPROVED
TXN-2024-009,ACC-1006,MER-5002,3200.00,USD,2024-01-23 10:45:22,APPROVED
TXN-2024-010,ACC-1001,MER-5003,34.99,USD,2024-01-23 11:03:15,APPROVED
TXN-2024-011,ACC-1007,MER-5008,15.50,USD,2024-01-23 11:18:42,APPROVED
TXN-2024-012,ACC-1002,MER-5009,890.00,USD,2024-01-23 11:35:20,APPROVED
TXN-2024-013,ACC-1008,MER-5001,52.30,USD,2024-01-23 12:02:45,APPROVED
TXN-2024-014,ACC-1004,MER-5010,1750.00,USD,2024-01-23 12:20:10,APPROVED
TXN-2024-015,ACC-1002,MER-5002,3500.00,USD,2024-01-23 14:22:10,DECLINED
TXN-2024-016,ACC-1005,MER-5011,125.00,EUR,2024-01-23 14:35:22,APPROVED
TXN-2024-017,ACC-1009,MER-5003,28.75,USD,2024-01-23 14:48:15,APPROVED
TXN-2024-018,ACC-1001,MER-5012,450.00,USD,2024-01-23 15:05:30,APPROVED
TXN-2024-019,ACC-1010,MER-5001,95.50,GBP,2024-01-23 15:22:45,APPROVED
TXN-2024-020,ACC-1003,MER-5004,67.80,USD,2024-01-23 15:40:18,APPROVED
TXN-2024-021,ACC-1006,MER-5013,1450.00,USD,2024-01-23 16:05:22,APPROVED
TXN-2024-022,ACC-1011,MER-5005,180.00,USD,2024-01-23 16:18:45,APPROVED
TXN-2024-023,ACC-1005,MER-5014,2200.00,USD,2024-01-23 16:45:33,DECLINED
TXN-2024-024,ACC-1007,MER-5007,320.00,USD,2024-01-23 17:02:10,APPROVED
TXN-2024-025,ACC-1002,MER-5001,78.90,USD,2024-01-23 17:25:45,APPROVED
TXN-2024-026,ACC-1012,MER-5015,540.00,USD,2024-01-23 17:48:22,APPROVED
TXN-2024-027,ACC-1008,MER-5003,42.50,USD,2024-01-23 18:05:10,APPROVED
TXN-2024-028,ACC-1004,MER-5009,1200.00,USD,2024-01-23 18:22:35,APPROVED
TXN-2024-029,ACC-1009,MER-5016,88.00,USD,2024-01-23 18:45:18,APPROVED
TXN-2024-030,ACC-1001,MER-5006,210.00,USD,2024-01-23 19:05:42,APPROVED
TXN-2024-031,ACC-1002,MER-5017,1800.00,USD,2024-01-23 19:12:05,DECLINED
TXN-2024-032,ACC-1013,MER-5001,65.40,USD,2024-01-23 19:35:22,APPROVED
TXN-2024-033,ACC-1006,MER-5010,950.00,USD,2024-01-23 19:52:45,APPROVED
TXN-2024-034,ACC-1010,MER-5018,145.00,USD,2024-01-23 20:08:10,APPROVED
TXN-2024-035,ACC-1003,MER-5003,38.75,USD,2024-01-23 20:25:33,APPROVED
TXN-2024-036,ACC-1001,MER-5001,89.50,USD,2024-01-24 08:20:15,APPROVED
TXN-2024-037,ACC-1002,MER-5003,45.00,USD,2024-01-24 09:10:30,APPROVED
TXN-2024-038,ACC-1003,MER-5006,125.60,USD,2024-01-24 10:15:45,APPROVED
TXN-2024-039,ACC-1005,MER-5001,210.00,USD,2024-01-24 11:22:10,APPROVED
TXN-2024-040,ACC-1006,MER-5003,32.50,USD,2024-01-24 12:05:20,APPROVED
TXN-2024-041,ACC-1002,MER-5002,2800.00,USD,2024-01-24 13:15:45,DECLINED
TXN-2024-042,ACC-1002,MER-5017,1500.00,USD,2024-01-24 13:25:10,DECLINED
TXN-2024-043,ACC-1002,MER-5014,950.00,USD,2024-01-24 13:35:22,DECLINED
TXN-2024-044,ACC-1002,MER-5002,1200.00,USD,2024-01-24 13:45:50,DECLINED
TXN-2024-045,ACC-1002,MER-5017,880.00,USD,2024-01-24 13:55:15,DECLINED
TXN-2024-046,ACC-1002,MER-5002,1650.00,USD,2024-01-24 14:05:30,DECLINED
TXN-2024-047,ACC-1002,MER-5014,2100.00,USD,2024-01-24 14:15:42,DECLINED
TXN-2024-048,ACC-1008,MER-5003,28.90,USD,2024-01-24 14:30:15,APPROVED
TXN-2024-049,ACC-1009,MER-5001,156.75,USD,2024-01-24 15:10:25,APPROVED
TXN-2024-050,ACC-1010,MER-5016,42.00,USD,2024-01-24 16:20:40,APPROVED
TXN-2024-051,ACC-1004,MER-5004,95.50,USD,2024-01-24 17:05:15,APPROVED
TXN-2024-052,ACC-1007,MER-5008,22.80,USD,2024-01-24 18:12:30,APPROVED
TXN-2024-053,ACC-1011,MER-5005,340.00,USD,2024-01-24 19:08:45,APPROVED
TXN-2024-054,ACC-1001,MER-5003,52.30,USD,2024-01-25 09:05:20,APPROVED
TXN-2024-055,ACC-1003,MER-5001,78.90,USD,2024-01-25 10:20:15,APPROVED
TXN-2024-056,ACC-1005,MER-5005,1800.00,USD,2024-01-25 11:15:30,APPROVED
TXN-2024-057,ACC-1006,MER-5006,105.50,USD,2024-01-25 12:30:45,APPROVED
TXN-2024-058,ACC-1008,MER-5001,34.75,USD,2024-01-25 14:10:20,APPROVED
TXN-2024-059,ACC-1009,MER-5016,67.20,USD,2024-01-25 15:25:10,APPROVED
TXN-2024-060,ACC-1010,MER-5003,29.99,USD,2024-01-25 16:40:35,APPROVED
TXN-2024-061,ACC-1012,MER-5015,420.00,USD,2024-01-25 17:15:50,APPROVED
TXN-2024-062,ACC-1013,MER-5001,88.40,USD,2024-01-25 18:05:25,APPROVED
TXN-2024-063,ACC-1004,MER-5009,650.00,USD,2024-01-25 19:20:15,APPROVED
EOF

    # Generate accounts.csv
    echo -e "  ${CYAN}Generating accounts.csv...${NC}"
    cat > "$TEMP_DIR/accounts.csv" <<'EOF'
account_id,customer_name,account_type,balance,credit_limit,open_date,risk_rating
ACC-1001,John Smith,CREDIT,2500.00,5000.00,2020-03-15,LOW
ACC-1002,Jane Doe,CREDIT,150.00,3000.00,2019-07-22,MEDIUM
ACC-1003,Bob Johnson,DEBIT,5420.75,0.00,2021-01-10,LOW
ACC-1004,Alice Williams,CREDIT,1800.50,7000.00,2018-11-05,LOW
ACC-1005,Charlie Brown,CREDIT,4250.00,10000.00,2024-01-05,HIGH
ACC-1006,Diana Martinez,CREDIT,3100.00,6000.00,2020-08-20,MEDIUM
ACC-1007,Eva Garcia,DEBIT,1250.80,0.00,2022-03-12,LOW
ACC-1008,Frank Miller,CREDIT,800.00,4000.00,2021-06-18,LOW
ACC-1009,Grace Lee,CREDIT,5500.00,8000.00,2019-04-25,LOW
ACC-1010,Henry Davis,DEBIT,3200.45,0.00,2020-12-03,LOW
ACC-1011,Iris Chen,CREDIT,2400.00,5000.00,2021-09-14,MEDIUM
ACC-1012,Jack Wilson,CREDIT,6800.00,12000.00,2018-02-28,LOW
ACC-1013,Karen Taylor,DEBIT,890.25,0.00,2023-05-10,LOW
EOF

    # Generate merchants.csv
    echo -e "  ${CYAN}Generating merchants.csv...${NC}"
    cat > "$TEMP_DIR/merchants.csv" <<'EOF'
merchant_id,merchant_name,merchant_category,country,risk_level
MER-5001,Amazon.com,RETAIL,United States,LOW
MER-5002,Luxury Watches Inc,JEWELRY,Switzerland,HIGH
MER-5003,Joe's Coffee Shop,RESTAURANT,United States,LOW
MER-5004,Target Corporation,RETAIL,United States,LOW
MER-5005,Best Buy Electronics,ELECTRONICS,United States,LOW
MER-5006,Whole Foods Market,GROCERY,United States,LOW
MER-5007,Delta Airlines,TRAVEL,United States,MEDIUM
MER-5008,Shell Gas Station,GAS_STATION,United States,LOW
MER-5009,Apple Store,ELECTRONICS,United States,LOW
MER-5010,Hotels.com,TRAVEL,United States,MEDIUM
MER-5011,Carrefour,RETAIL,France,LOW
MER-5012,Uber Technologies,TRANSPORTATION,United States,LOW
MER-5013,Microsoft Store,SOFTWARE,United States,LOW
MER-5014,Offshore Casino Ltd,GAMBLING,Malta,HIGH
MER-5015,Costco Wholesale,RETAIL,United States,LOW
MER-5016,Starbucks Coffee,RESTAURANT,United States,LOW
MER-5017,Electronics Warehouse,ELECTRONICS,Hong Kong,HIGH
MER-5018,Netflix Inc,ENTERTAINMENT,United States,LOW
EOF

    # Upload financial files to MinIO
    echo -e "  ${CYAN}Uploading financial files to MinIO...${NC}"
    mc cp "$TEMP_DIR/transactions.csv" "${MINIO_ALIAS}/${BUCKET_RAW}/finance/" > /dev/null 2>&1
    mc cp "$TEMP_DIR/accounts.csv" "${MINIO_ALIAS}/${BUCKET_RAW}/finance/" > /dev/null 2>&1
    mc cp "$TEMP_DIR/merchants.csv" "${MINIO_ALIAS}/${BUCKET_RAW}/finance/" > /dev/null 2>&1

    echo -e "${GREEN}  [OK] Financial data files generated and uploaded${NC}"
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

    # Step 9: Generate and upload financial data files
    generate_financial_files
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
