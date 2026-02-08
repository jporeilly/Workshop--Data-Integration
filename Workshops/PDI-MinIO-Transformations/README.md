# PDI Transformation Workshop: MinIO Data Integration

This workshop provides hands-on exercises for building intermediate-to-advanced Pentaho Data Integration (PDI) transformations using sample data stored in MinIO object storage.

## Workshop Overview

| Exercise | Difficulty | Duration | Key Skills |
|----------|------------|----------|------------|
| 1. Sales Performance Dashboard | Beginner-Intermediate | 30-45 min | Joins, lookups, aggregations |
| 2. Inventory Reconciliation | Intermediate | 45-60 min | XML parsing, outer joins, variance |
| 3. Customer 360 View | Intermediate | 60-75 min | Multi-source, JSONL, calculations |
| 4. Clickstream Funnel Analysis | Intermediate-Advanced | 60-90 min | Sessionization, pivoting |
| 5. Log Parsing & Anomaly Detection | Advanced | 75-90 min | Regex, time-series analysis |
| 6. Multi-Format Data Lake Ingestion | Advanced | 60-75 min | Schema normalization, validation |

## Prerequisites

### 1. Software Requirements

- **Pentaho Data Integration (PDI)** 9.x or 10.x installed
- **MinIO** running with sample data populated
- **Java 11** or higher (for PDI)

### 2. MinIO Setup Verification

Before starting, verify MinIO is running and populated:

```bash
# Check MinIO is running
curl -sf http://localhost:9000/minio/health/live && echo "MinIO OK" || echo "MinIO not running"

# Verify data exists (using mc client)
mc ls minio-local/raw-data --recursive
```

Expected buckets:
- `raw-data` - Source files (CSV, JSON, XML, Parquet)
- `staging` - Intermediate processing
- `curated` - Final processed data
- `logs` - Log files

### 3. PDI S3/MinIO Connection Setup

Before creating transformations, configure PDI to connect to MinIO:

#### Option A: Using VFS Browser (Recommended)

1. Open PDI (Spoon)
2. Go to **Tools** > **Options** > **General**
3. Under **Virtual File System**, add S3 configuration

#### Option B: Using Connection Properties

Create a shared connection that all transformations can use:

1. In PDI, go to **View** > **Database Connections**
2. Right-click > **New**
3. Configure as follows:

| Property | Value |
|----------|-------|
| Connection Type | Generic database |
| Custom connection string | (see S3 Input step configuration) |

#### S3 Configuration for Steps

When configuring S3 Input/Output steps, use these settings:

| Setting | Value |
|---------|-------|
| Access Key | `minioadmin` |
| Secret Key | `minioadmin` |
| Endpoint | `http://localhost:9000` |
| Path Style Access | `true` (required for MinIO) |
| Region | `us-east-1` |

#### VFS-Compatible Steps

Not all PDI steps support VFS (Virtual File System) for S3/MinIO access. Use the correct step:

| Task | DO Use (VFS-Compatible) | DON'T Use (No VFS Support) |
|------|-------------------------|---------------------------|
| Read CSV | **Text file input** | ~~CSV file input~~ |
| Read JSON | **JSON input** | - |
| Read XML | **Get data from XML** | - |
| Read Parquet | **Parquet input** | - |
| Write CSV | **Text file output** | - |
| Write JSON | **JSON output** | - |
| Write Parquet | **Parquet output** | - |

> **Key Point:** Always use **"Text file input"** for reading CSV files from S3/MinIO, not "CSV file input".

### 4. Sample Data Reference

Refer to the [README-POPULATE.md](../../Setup/MinIO/README-POPULATE.md) for complete data schemas.

**Quick Reference:**

| File | Location | Records | Key Fields |
|------|----------|---------|------------|
| customers.csv | raw-data/csv/ | 12 | customer_id, email, country, status |
| products.csv | raw-data/csv/ | 12 | product_id, category, price, stock_quantity |
| sales.csv | raw-data/csv/ | 15 | sale_id, customer_id, product_id, sale_amount |
| api_response.json | raw-data/json/ | 2 orders | Nested order/customer/items structure |
| user_events.json | raw-data/json/ | 8 events | JSONL format, event_type, session_id |
| inventory.xml | raw-data/xml/ | 4 items | sku, quantity, location |
| employees.xml | raw-data/xml/ | 4 employees | Nested department/employee structure |

---

## Exercise 1: Sales Performance Dashboard ETL

**Objective:** Create a denormalized fact table combining sales, products, and customers for BI reporting.

**Skills:** Text File Input (VFS), Stream Lookup, Select Values, Calculator, Group By

> **Important:** The "CSV file input" step does NOT support VFS (S3/MinIO). Use **"Text file input"** instead for reading CSV files from object storage.

### Step 1: Create New Transformation

1. Open PDI (Spoon)
2. **File** > **New** > **Transformation**
3. Save as `sales_dashboard_etl.ktr` in your workshop folder

### Step 2: Add Text File Input Steps (3 parallel inputs)

We'll read all three CSV files in parallel for efficiency.

> **Note:** We use "Text file input" (not "CSV file input") because it supports VFS/S3 paths.

#### 2.1 Customers Input

1. From the **Design** palette, drag **Text file input** to the canvas
2. Double-click to configure:

**File Tab:**

| Setting | Value |
|---------|-------|
| Step name | `Read Customers` |
| File/Directory | `pvfs://MinIO/raw-data/csv/customers.csv` |

3. Click **Add** to add the file to the list

**Content Tab:**

| Setting | Value |
|---------|-------|
| Separator | `,` |
| Enclosure | `"` |
| Header | `Yes` |
| Nr header lines | `1` |

**Fields Tab:**

4. Click **Get Fields** to auto-detect columns
5. Verify fields:
   - `customer_id` (Integer)
   - `first_name` (String)
   - `last_name` (String)
   - `email` (String)
   - `country` (String)
   - `status` (String)

#### 2.2 Products Input

1. Drag another **Text file input** to the canvas
2. Configure:

**File Tab:**

| Setting | Value |
|---------|-------|
| Step name | `Read Products` |
| File/Directory | `pvfs://MinIO/raw-data/csv/products.csv` |

**Content Tab:** Same as above (comma separator, header row)

**Fields Tab:**

3. Click **Get Fields**
4. Key fields: `product_id`, `product_name`, `category`, `price`

#### 2.3 Sales Input

1. Drag a third **Text file input**
2. Configure:

| Setting | Value |
|---------|-------|
| Step name | `Read Sales` |
| Filename | `pvfs://MinIO/raw-data/csv/sales.csv` |

3. Click **Get Fields**
4. Key fields: `sale_id`, `customer_id`, `product_id`, `quantity`, `sale_amount`, `status`

### Step 3: Enrich Sales with Product Data

1. Drag **Stream lookup** step to the canvas
2. Connect `Read Sales` to `Stream lookup`
3. Connect `Read Products` to `Stream lookup` (lookup stream)
4. Double-click to configure:

| Tab | Setting | Value |
|-----|---------|-------|
| General | Step name | `Lookup Product Details` |
| General | Lookup step | `Read Products` |
| Keys | Field (from Sales) | `product_id` |
| Keys | Field (from Products) | `product_id` |

5. In **Values to retrieve**, add:
   - `product_name` (rename to `product_name`)
   - `category` (rename to `product_category`)
   - `price` (rename to `unit_price`)

### Step 4: Enrich with Customer Data

1. Drag another **Stream lookup** step
2. Connect from `Lookup Product Details`
3. Connect `Read Customers` as lookup stream
4. Configure:

| Setting | Value |
|---------|-------|
| Step name | `Lookup Customer Details` |
| Lookup step | `Read Customers` |
| Key field (stream) | `customer_id` |
| Key field (lookup) | `customer_id` |

5. Values to retrieve:
   - `first_name`
   - `last_name`
   - `country` (rename to `customer_country`)
   - `status` (rename to `customer_status`)

### Step 5: Add Calculated Fields

1. Drag **Calculator** step to the canvas
2. Connect from `Lookup Customer Details`
3. Configure calculations:

| New field | Calculation | Field A | Field B | Value type |
|-----------|-------------|---------|---------|------------|
| `customer_full_name` | A + B | first_name | last_name | String |
| `line_total` | A * B | quantity | unit_price | Number |
| `profit_margin` | A - B | sale_amount | line_total | Number |

4. Add another **Calculator** or **Formula** step for:

```
is_high_value = IF(sale_amount > 500, "Yes", "No")
```

### Step 6: Add Metadata

1. Drag **Add constants** step
2. Connect from Calculator
3. Add fields:

| Name | Type | Value |
|------|------|-------|
| `etl_timestamp` | Timestamp | (use system date) |
| `data_source` | String | `minio_workshop` |

### Step 7: Select and Reorder Fields

1. Drag **Select values** step
2. Connect from Add constants
3. On **Select & Alter** tab, choose fields in order:
   - sale_id
   - sale_date
   - customer_id
   - customer_full_name
   - customer_country
   - customer_status
   - product_id
   - product_name
   - product_category
   - quantity
   - unit_price
   - sale_amount
   - line_total
   - profit_margin
   - is_high_value
   - payment_method
   - status (rename to `sale_status`)
   - etl_timestamp
   - data_source

### Step 8: Output to Staging

1. Drag **Text file output** step
2. Connect from Select values
3. Configure:

| Setting | Value |
|---------|-------|
| Step name | `Write to Staging` |
| Filename | `pvfs://MinIO/staging/dashboard/sales_fact` |
| Extension | `csv` |
| Include date in filename | `Yes` |
| Separator | `,` |
| Add header | `Yes` |

### Step 9: Run and Verify

1. Click **Run** (play button) or press F9
2. Select **Launch**
3. Monitor the execution:
   - Check row counts at each step
   - Verify no errors in log

4. Verify output in MinIO:

```bash
mc ls minio-local/staging/dashboard/
mc cat minio-local/staging/dashboard/sales_fact_20240123.csv | head -5
```

### Final Transformation Diagram

```
[Read Customers]─────────────────────────────────────┐
                                                     │
[Read Products]──────────────────────────────┐       │
                                             │       │
[Read Sales]──>[Lookup Product Details]──>[Lookup Customer Details]
                                                     │
                                          [Calculator]
                                                     │
                                         [Add constants]
                                                     │
                                         [Select values]
                                                     │
                                       [Write to Staging]
```

### Exercise 1 Checklist

- [ ] Three Text file inputs configured (reading CSV from S3)
- [ ] Product lookup working (no null product names)
- [ ] Customer lookup working (no null countries)
- [ ] Calculations producing correct values
- [ ] Output file created in staging bucket
- [ ] All 15 sales records processed

---

## Exercise 2: Inventory Reconciliation (XML + CSV)

**Objective:** Compare warehouse inventory (XML) with product catalog (CSV) to identify discrepancies.

**Skills:** XML Input, Merge Join, Filter Rows, Switch/Case

### Step 1: Create New Transformation

1. **File** > **New** > **Transformation**
2. Save as `inventory_reconciliation.ktr`

### Step 2: Read XML Inventory Data

1. Drag **Get data from XML** step to canvas
2. Configure:

| Tab | Setting | Value |
|-----|---------|-------|
| File | Filename | `pvfs://MinIO/raw-data/xml/inventory.xml` |
| Content | Loop XPath | `/inventory/items/item` |

3. On **Fields** tab, click **Get XPath nodes** then define:

| Name | XPath | Type |
|------|-------|------|
| sku | `sku` | String |
| item_name | `name` | String |
| warehouse_qty | `quantity` | Integer |
| location | `location` | String |
| last_checked | `last_checked` | Date |

4. Click **Preview** to verify data extraction

### Step 3: Read Product Catalog

1. Drag **Text file input** step (supports VFS/S3)
2. Configure:

**File Tab:**

| Setting | Value |
|---------|-------|
| Step name | `Read Product Catalog` |
| File/Directory | `pvfs://MinIO/raw-data/csv/products.csv` |

**Content Tab:** Separator: `,`, Header: Yes

**Fields Tab:**

3. Get fields, key columns: `product_id`, `product_name`, `stock_quantity`

### Step 4: Prepare Keys for Join

The XML uses `sku` while CSV uses `product_id`. We need to align them.

1. After XML input, add **Select values** step
2. On **Meta-data** tab, rename:
   - `sku` → `product_id`
   - `warehouse_qty` → `warehouse_quantity`

3. After CSV input, add **Select values** step
4. Rename `stock_quantity` → `catalog_quantity`

### Step 5: Sort Both Streams

Merge Join requires sorted input.

1. Add **Sort rows** step after XML Select values
   - Sort by: `product_id` (Ascending)

2. Add **Sort rows** step after CSV Select values
   - Sort by: `product_id` (Ascending)

### Step 6: Full Outer Join

1. Drag **Merge join** step
2. Connect both sorted streams
3. Configure:

| Setting | Value |
|---------|-------|
| Step name | `Full Outer Join` |
| First step | (XML sorted stream) |
| Second step | (CSV sorted stream) |
| Join type | `FULL OUTER` |
| Key field 1 | `product_id` |
| Key field 2 | `product_id` |

### Step 7: Business Logic & Calculations (Modified JavaScript)

Use **Modified JavaScript Value** step to consolidate all business logic, calculations, and metadata in one place.

1. Drag **Modified JavaScript Value** step to the canvas (under Scripting category)
2. Connect from `Full Outer Join` → `Modified JavaScript Value`
3. Double-click to configure
4. In the script editor, add the following JavaScript:

```javascript
// ===================================================================
// INVENTORY RECONCILIATION BUSINESS LOGIC
// ===================================================================
// This script performs variance calculations, status classification,
// priority routing, financial impact analysis, and audit trail creation
// ===================================================================

// Initialize output variables
var match_status = "";
var severity = "";
var action_required = "";
var variance_pct = 0;
var quantity_variance = 0;
var abs_variance = 0;

// Step 1: Calculate basic variance
if (warehouse_quantity != null && catalog_quantity != null) {
    quantity_variance = warehouse_quantity - catalog_quantity;
    abs_variance = Math.abs(quantity_variance);
}

// Step 2: Determine status based on null checks and variance
if (warehouse_quantity == null || warehouse_quantity == 0) {
    match_status = "MISSING_IN_WAREHOUSE";
    severity = "HIGH";
    action_required = "Physical inventory check required";

} else if (catalog_quantity == null || catalog_quantity == 0) {
    match_status = "MISSING_IN_CATALOG";
    severity = "MEDIUM";
    action_required = "Add to ERP or remove from warehouse";

} else {
    // Both systems have the item - classify based on variance

    // Calculate variance percentage
    if (catalog_quantity > 0) {
        variance_pct = Math.abs((quantity_variance / catalog_quantity) * 100);
    }

    // Classify using tolerance threshold (±2 units = acceptable)
    if (Math.abs(quantity_variance) <= 2) {
        match_status = "MATCH";
        severity = "NONE";
        action_required = "No action - within tolerance";

    } else if (quantity_variance > 0) {
        // Overstock scenarios
        match_status = "OVERSTOCK";
        severity = variance_pct > 20 ? "HIGH" : "MEDIUM";
        action_required = "Update ERP quantity or investigate recent receiving";

    } else {
        // Understock scenarios
        match_status = "UNDERSTOCK";
        severity = variance_pct > 20 ? "HIGH" : "MEDIUM";
        action_required = "Update ERP quantity or investigate shrinkage";
    }
}

// Step 3: Determine priority for work queue routing
var priority;
if (severity == "HIGH") {
    priority = 1;
} else if (severity == "MEDIUM") {
    priority = 2;
} else {
    priority = 3;
}

// Step 4: Financial Impact Analysis
// Requires price field from catalog
var financial_impact = abs_variance * price;

// Step 5: Calculate carrying cost of excess inventory (20% annually)
var excess_carrying_cost = 0;
if (match_status == "OVERSTOCK") {
    excess_carrying_cost = (quantity_variance * price * 0.20) / 365 * 30; // Monthly cost
}

// Step 6: Calculate lost sales risk from understocked items
var lost_sales_risk = 0;
if (match_status == "UNDERSTOCK") {
    lost_sales_risk = quantity_variance * price * -1; // Convert to positive value
}

// Step 7: Add Audit Trail & Metadata
var reconciliation_timestamp = new Date();
var reconciliation_date = new Date();
reconciliation_date.setHours(0, 0, 0, 0); // Remove time component for date grouping

var tolerance_threshold = 2;
var data_source_warehouse = "WMS-XML-Export";
var data_source_erp = "ERP-CSV-Extract";
```

5. **Configure Output Fields** - Click the **Get Variables** button to auto-populate fields, then verify:

| Field Name | Type | Purpose |
|------------|------|---------|
| quantity_variance | Number | warehouse_qty - catalog_qty |
| abs_variance | Number | Absolute value of variance |
| match_status | String | MATCH, OVERSTOCK, UNDERSTOCK, MISSING_* |
| severity | String | HIGH, MEDIUM, NONE |
| action_required | String | Guidance for operations team |
| variance_pct | Number | Percentage variance |
| priority | Integer | 1=High, 2=Medium, 3=Low |
| financial_impact | Number | Dollar value of discrepancy |
| excess_carrying_cost | Number | Monthly carrying cost (overstock) |
| lost_sales_risk | Number | Potential lost revenue (understock) |
| reconciliation_timestamp | Date | Exact processing time |
| reconciliation_date | Date | Processing date (no time) |
| tolerance_threshold | Integer | Acceptable variance (±2) |
| data_source_warehouse | String | Source system identifier |
| data_source_erp | String | Source system identifier |

> **Benefits of this approach:**
> - **Single step** replaces Calculator + Formula + Add Constants
> - **Business logic documented** in one place
> - **Financial calculations** included (carrying cost, lost sales)
> - **Audit trail** automatically added
> - **Easy to modify** - change thresholds, add rules, etc.

### Step 8: Priority-Based Routing (Optional)

Use **Switch/Case** step to route items based on priority for different processing workflows:

1. Drag **Switch/Case** step (under Flow category)
2. Connect from `Modified JavaScript Value` → `Switch/Case`
3. Configure cases based on `priority` field:

| Case Value | Description | Target Step |
|------------|-------------|-------------|
| 1 | HIGH Priority | Urgent Action Queue |
| 2 | MEDIUM Priority | Standard Review Queue |
| 3 | LOW/NONE Priority | Monitoring Queue |
| default | Catch-all | Full Report |

**Alternative: Simple Filter**

If you just want to separate matches from discrepancies:

1. Add **Filter rows** step
2. Condition: `match_status != "MATCH"`
3. Routes:
   - True → Discrepancies Output
   - False → Matches Output (archive)

### Step 9: Output Results with Financial Data

Now that we have rich calculated fields, create meaningful outputs:

#### Output 1: High Priority Action Queue

1. Add **Filter rows** step: `priority = 1`
2. Add **Text file output**:
   - **Filename**: `pvfs://MinIO/staging/reconciliation/urgent_actions`
   - **Fields to include**: product_id, product_name, match_status, severity, quantity_variance, variance_pct, financial_impact, lost_sales_risk, excess_carrying_cost, action_required

#### Output 2: Full Reconciliation Report

1. Add **Select values** step to order fields logically:
   - Identifiers: product_id, product_name, category
   - Quantities: warehouse_quantity, catalog_quantity, quantity_variance, abs_variance, variance_pct
   - Classification: match_status, severity, priority
   - Financial: price, financial_impact, excess_carrying_cost, lost_sales_risk
   - Action: action_required
   - Audit: reconciliation_date, reconciliation_timestamp, data_source_warehouse, data_source_erp, tolerance_threshold

2. Add **Text file output**:
   - **Filename**: `pvfs://MinIO/curated/reports/inventory_reconciliation`
   - **Extension**: csv
   - **Include date in filename**: Yes
   - **Include time in filename**: Yes

#### Output 3: Financial Summary (Aggregated)

1. Add **Group by** step:
   - Group field: match_status
   - Aggregates:
     - Sum of financial_impact → total_financial_impact
     - Sum of excess_carrying_cost → total_carrying_cost
     - Sum of lost_sales_risk → total_lost_sales
     - Count of product_id → item_count

2. Add **Text file output**:
   - **Filename**: `pvfs://MinIO/curated/reports/reconciliation_financial_summary`

### Step 10: Run and Analyze

**Expected Results with Enhanced JavaScript Logic:**

- **16 items** from XML inventory (warehouse)
- **18 items** from CSV catalog
- **19 unique products** total after Full Outer Join
- **16 items with calculated variance** (89% - both warehouse & catalog data)
- **3 items with nulls** (P011, P012 missing in warehouse; P099 orphan)

**Status Distribution:**
- 3 MATCH (P001, P004, P017)
- 3 OVERSTOCK_MINOR (P010, P013, P016)
- 2 OVERSTOCK_MAJOR (P002, P006)
- 3 UNDERSTOCK_MINOR (P008, P014, P015)
- 3 UNDERSTOCK_MAJOR (P003, P007, P009)
- 2 UNDERSTOCK_CRITICAL (P005, P018)
- 2 MISSING_IN_WAREHOUSE (P011, P012)
- 1 MISSING_IN_CATALOG (P099)

**Financial Metrics Calculated:**
- Total financial impact (sum of all discrepancies × price)
- Carrying costs for overstock items (~20% annual rate)
- Lost sales risk for understock items

```bash
# View urgent actions (priority=1 only)
mc cat minio-local/staging/reconciliation/urgent_actions.csv

# View full reconciliation report
mc cat minio-local/curated/reports/inventory_reconciliation_20240204_143530.csv

# View financial summary by status
mc cat minio-local/curated/reports/reconciliation_financial_summary.csv
```

### Final Transformation Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              DATA INPUT LAYER                                        │
└─────────────────────────────────────────────────────────────────────────────────────┘

    ┌─────────────────────────┐                    ┌─────────────────────────┐
    │ Get XML Inventory       │                    │ Read CSV Catalog        │
    │ pvfs://MinIO/           │                    │ pvfs://MinIO/           │
    │ raw-data/xml/           │                    │ raw-data/csv/           │
    │ inventory.xml           │                    │ products.csv            │
    │                         │                    │                         │
    │ 16 warehouse items      │                    │ 18 catalog items        │
    └───────────┬─────────────┘                    └───────────┬─────────────┘
                │                                              │
                │                                              │
    ┌───────────▼─────────────┐                    ┌───────────▼─────────────┐
    │ Select Values           │                    │ Select Values           │
    │ • sku → product_id      │                    │ • Rename:               │
    │ • quantity →            │                    │   stock_quantity →      │
    │   warehouse_quantity    │                    │   catalog_quantity      │
    └───────────┬─────────────┘                    └───────────┬─────────────┘
                │                                              │
                │                                              │
    ┌───────────▼─────────────┐                    ┌───────────▼─────────────┐
    │ Sort Rows               │                    │ Sort Rows               │
    │ Key: product_id (ASC)   │                    │ Key: product_id (ASC)   │
    └───────────┬─────────────┘                    └───────────┬─────────────┘
                │                                              │
                └──────────────────┬───────────────────────────┘
                                   │
┌──────────────────────────────────▼──────────────────────────────────────────────────┐
│                          INTEGRATION & BUSINESS LOGIC LAYER                          │
└──────────────────────────────────────────────────────────────────────────────────────┘
                                   │
                    ┌──────────────▼──────────────┐
                    │ Merge Join (FULL OUTER)     │
                    │ Key: product_id             │
                    │ Result: 19 unique products  │
                    │ • 16 with both sources      │
                    │ • 2 catalog-only (P011,P012)│
                    │ • 1 warehouse-only (P099)   │
                    └──────────────┬──────────────┘
                                   │
                    ┌──────────────▼──────────────────────────────────────┐
                    │ Modified JavaScript Value                           │
                    │ ─────────────────────────────────────────────────   │
                    │ CALCULATIONS:                                       │
                    │  ✓ quantity_variance (warehouse - catalog)          │
                    │  ✓ abs_variance (absolute value)                    │
                    │  ✓ variance_pct (percentage)                        │
                    │                                                     │
                    │ CLASSIFICATION:                                     │
                    │  ✓ match_status (8 categories)                      │
                    │  ✓ severity (HIGH/MEDIUM/NONE)                      │
                    │  ✓ priority (1/2/3)                                 │
                    │  ✓ action_required (guidance text)                  │
                    │                                                     │
                    │ FINANCIAL ANALYSIS:                                 │
                    │  ✓ financial_impact (variance × price)              │
                    │  ✓ excess_carrying_cost (20% annual)                │
                    │  ✓ lost_sales_risk (understock impact)              │
                    │                                                     │
                    │ AUDIT TRAIL:                                        │
                    │  ✓ reconciliation_timestamp                         │
                    │  ✓ reconciliation_date                              │
                    │  ✓ data_source_warehouse / _erp                     │
                    │  ✓ tolerance_threshold (±2)                         │
                    │                                                     │
                    │ Total: 15 new calculated fields                     │
                    └──────────────┬──────────────────────────────────────┘
                                   │
┌──────────────────────────────────▼──────────────────────────────────────────────────┐
│                            OUTPUT & ROUTING LAYER                                    │
└──────────────────────────────────────────────────────────────────────────────────────┘
                                   │
              ┌────────────────────┼────────────────────┐
              │                    │                    │
    ┌─────────▼──────────┐ ┌──────▼───────┐ ┌─────────▼──────────┐
    │ Route A:           │ │ Route B:     │ │ Route C:           │
    │ URGENT ACTIONS     │ │ AGGREGATION  │ │ FULL REPORT        │
    └─────────┬──────────┘ └──────┬───────┘ └─────────┬──────────┘
              │                    │                    │
    ┌─────────▼──────────┐ ┌──────▼───────┐ ┌─────────▼──────────┐
    │ Filter Rows        │ │ Group By     │ │ Select Values      │
    │ priority = 1       │ │ Key: status  │ │ Order 20+ fields:  │
    │ (4 HIGH items)     │ │ Aggregates:  │ │ • Identifiers      │
    └─────────┬──────────┘ │ • SUM($)     │ │ • Quantities       │
              │             │ • COUNT(*)   │ │ • Classification   │
    ┌─────────▼──────────┐ └──────┬───────┘ │ • Financial        │
    │ Text File Output   │        │         │ • Audit            │
    │ urgent_actions.csv │ ┌──────▼───────┐ └─────────┬──────────┘
    │                    │ │ Text Output  │           │
    │ Fields:            │ │ financial_   │ ┌─────────▼──────────┐
    │ • product_id       │ │ summary.csv  │ │ Text File Output   │
    │ • match_status     │ │              │ │ inventory_         │
    │ • severity         │ │ By Status:   │ │ reconciliation_    │
    │ • variance         │ │ • Total $    │ │ 20240204_1430.csv  │
    │ • variance_pct     │ │ • Carrying   │ │                    │
    │ • financial_impact │ │ • Lost sales │ │ All 19 items       │
    │ • lost_sales_risk  │ │ • Count      │ │ All 20+ fields     │
    │ • carrying_cost    │ └──────────────┘ │ Timestamped        │
    │ • action_required  │                  └────────────────────┘
    └────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────────┐
│                                  DATA FLOW SUMMARY                                   │
├─────────────────────────────────────────────────────────────────────────────────────┤
│  INPUT:  16 warehouse (XML) + 18 catalog (CSV) = 19 unique after join               │
│  LOGIC:  1 JavaScript step = 15 calculated fields (replaces 4+ traditional steps)   │
│  OUTPUT: 3 reports (Urgent, Full, Summary) for different audiences                  │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

**Legend:**
- **┌─┐ │ └─┘** : Step boundaries
- **→ ─ │** : Data flow direction
- **▼ ┬ ┴** : Flow connectors
- **✓** : Feature included

**Key Improvements Over Traditional Approach:**
- ✅ Single JavaScript step replaces 3-4 separate steps (Calculator + Formula + Add Constants)
- ✅ Business logic centralized and documented
- ✅ Financial calculations built-in (carrying cost, lost sales risk)
- ✅ Flexible priority-based routing
- ✅ Multiple output formats for different audiences

### Troubleshooting: Modified JavaScript Step

**Common Issues:**

1. **Field Name Mismatches**
   - Error: `ReferenceError: catalog_quantity is not defined`
   - Solution: Check your CSV field names - if your catalog uses `stock_quantity` instead of `catalog_quantity`, update the JavaScript variable names OR add a Select Values step to rename fields before the JavaScript step

2. **Null Pointer Exceptions**
   - Error: `TypeError: Cannot read property of null`
   - Solution: Script already handles nulls correctly - ensure all fields are defined in **Get Variables** button output

3. **Type Conversion Issues**
   - Error: Math operations return NaN
   - Solution: Ensure quantity fields are Numbers, not Strings. Add a **Select Values** step before JavaScript to convert types if needed

4. **Missing Output Fields**
   - Error: Fields don't appear in subsequent steps
   - Solution: Click **Get Variables** button in the JavaScript step to auto-populate the field list

5. **Division by Zero**
   - Error: `variance_pct = Infinity`
   - Solution: Script already checks `if (catalog_quantity > 0)` before division

**Performance Tips:**
- ✅ JavaScript step is very efficient for row-by-row calculations
- ✅ Avoid loops within JavaScript for large datasets
- ✅ For aggregations, use Group By step instead of accumulating in JavaScript

**Testing the Script:**
1. Add a **Preview** after JavaScript step (right-click → Preview rows)
2. Check that all 15 fields are populated
3. Verify formulas with known test cases:
   - P001: variance=0, status=MATCH, priority=3, severity=NONE
   - P005: variance=-80, status=UNDERSTOCK, priority=1, variance_pct=87%
   - P099: status=MISSING_IN_CATALOG, priority=2, severity=MEDIUM

---

## Exercise 3: Customer 360 View

**Objective:** Create unified customer profiles combining demographic data, purchase history, and behavioral events.

**Skills:** Multiple joins, JSONL parsing, aggregations, calculated metrics

### Step 1: Create Transformation

Save as `customer_360.ktr`

### Step 2: Read and Aggregate Sales Data

1. **Text file input**: Read `pvfs://MinIO/raw-data/csv/sales.csv`

**Configuration:**
- **File** tab: `pvfs://MinIO/raw-data/csv/sales.csv`
- **Content** tab:
  - Separator: `,`
  - Enclosure: `"`
  - Header: Yes (1 header line)
- **Fields** tab: Click **Get Fields** to auto-detect

**Verify:** Preview should show **15 rows** (sales transactions)

2. **Memory Group by** step - Aggregate per customer:

**IMPORTANT:** Use **"Memory Group by"** (not regular "Group by") for better reliability with small datasets.

**Group by tab:**
- **Group field**: Check ONLY `customer_id`

**Aggregates tab:**

| Name | Subject | Type | Description |
|------|---------|------|-------------|
| total_orders | sale_id | Number of Values (N) | Count of transactions |
| total_spent | sale_amount | Sum | Total lifetime spend |
| first_purchase | sale_date | Minimum | Earliest purchase date |
| last_purchase | sale_date | Maximum | Most recent purchase date |
| avg_order_value | sale_amount | Average (Mean) | Average order value |

**Configuration Tips:**
- Click "Get Fields" button to see available fields
- For total_orders: Use "Number of Values (N)" - NOT "Number of Distinct Values"
- Ensure ONLY `customer_id` is in Group fields (nothing else!)

**CRITICAL - Verify Your Results:**

After the Group By step, click **Preview** and verify:
- **12 rows** (one per customer)
- Customer 1001 should have:
  - `total_orders` = 2
  - `first_purchase` = 2025-11-15
  - `last_purchase` = 2026-01-28
- Customer 1004 should have:
  - `total_orders` = 1
  - `first_purchase` = `last_purchase` = 2026-01-15

**Troubleshooting:**

If `first_purchase` = `last_purchase` for ALL customers (even 1001, 1002, 1003):

1. **Check Text File Input Preview**: Do you see all 15 sales records?
   - If NO → Check file path is correct
   - If YES but Group By only shows 12 rows each with 1 order → Continue to step 2

2. **Check Group By configuration**:
   - The **Group field** MUST be `customer_id` (not `sale_id`)
   - Aggregates MUST reference the correct field names from sales.csv

3. **Common Issue - Incorrect Sort Before Group By**:
   - If you added a Sort step before Group By, ensure it's sorting by `customer_id` ASC
   - PDI's Group By doesn't require pre-sorting (it has built-in sorting)

4. **Check Data Types**:
   - Ensure `sale_date` is String or Date type (both work)
   - MIN/MAX work on both strings (alphabetical) and dates

### Step 3: Parse JSONL Events

The `user_events.json` file is in **JSONL format** (JSON Lines - one JSON object per line, not an array). PDI's JSON Input step requires special configuration to read this format.

#### Method 1: Text Input + JSON Input (Two-Step Approach)

**Step 3a: Read Lines with Text File Input**

1. Add **Text file input** step
2. **File** tab:
   - Filename: `pvfs://MinIO/raw-data/json/user_events.json`
3. **Content** tab:
   - **File type**: CSV
   - **Separator**: `${NEVER_EXISTS}` or use a character that will NEVER appear in your data (e.g., `§` or `¶`)
     - **CRITICAL**: The separator must be a character that doesn't exist in JSON (not comma, not colon, not quote)
     - Alternative: Use a multi-character separator like `|||DELIM|||`
   - **Enclosure**: leave blank (or set to a character that doesn't exist like `§`)
   - **Header**: No (unchecked)
   - **Format**: Unix
   - **Row number in output**: Optional - can help with debugging
4. **Fields** tab:
   - Name: `json_line`
   - Type: String
   - Length: 2000 (increase if your JSON lines are longer)
   - Format: leave blank
   - Precision: leave blank

**IMPORTANT**: By using a separator that doesn't exist in the file, Text File Input will read each entire line as a single field without trying to split it.

**Test it**: Click "Preview rows" - you should see 46 rows, each with the `json_line` field containing a complete JSON object like:
```
{"event_id":"evt_001","user_id":1001,"event_type":"page_view",...}
```

**Step 3b: Parse JSON with JSON Input**

1. Add **JSON Input** step (connect from Text file input)
2. **File** tab:
   - **Source is from a previous step**: ✓ (checked)
   - **Read source from field**: `json_line`
3. **Content** tab:
   - **Ignore empty file**: No
   - **Do not raise an error if no files**: No
   - **Limit**: 0
4. **Fields** tab - Define the JSON structure:

| Name | Path | Type |
|------|------|------|
| event_id | $.event_id | String |
| user_id | $.user_id | Integer |
| event_type | $.event_type | String |
| timestamp | $.timestamp | String |
| product_id | $.product_id | String |
| rating | $.rating | Integer |
| page | $.page | String |
| query | $.query | String |
| order_id | $.order_id | String |
| amount | $.amount | Number |
| cart_value | $.cart_value | Number |
| session_id | $.session_id | String |
| topic | $.topic | String |

5. Click **Preview** to verify all 46 events are read

**Why This Works:**
- Text file input reads JSONL line-by-line (46 rows, each containing a JSON string)
- JSON Input parses each JSON string into structured fields
- Result: 46 rows with parsed JSON fields

#### Method 2: Using Modified JavaScript to Split and Parse (Alternative)

If the Text File Input approach is giving you issues, try this JavaScript approach:

1. **Get File Names** step:
   - File or directory: `pvfs://MinIO/raw-data/json/user_events.json`
2. **Text file input**:
   - Accept filenames from previous step: ✓
   - Content tab → Row separator: leave as default (newline)
   - Fields tab → Single field `json_line` (String, 2000 length)
3. **Modified JavaScript Value**:
   ```javascript
   // Parse the JSON line
   var parsed = JSON.parse(json_line);
   var event_id = parsed.event_id;
   var user_id = parsed.user_id;
   var event_type = parsed.event_type;
   var timestamp = parsed.timestamp;
   var product_id = parsed.product_id || null;
   var rating = parsed.rating || null;
   var page = parsed.page || null;
   var query = parsed.query || null;
   var session_id = parsed.session_id || null;
   ```
4. Click "Get Variables" to add all output fields

This approach uses JavaScript's native JSON.parse() which is very reliable.

#### Method 3: Best Solution - Convert JSONL to JSON Array

The cleanest solution might be to modify the populate script to generate a proper JSON array instead of JSONL.

However, if you want to keep JSONL format (which is standard for event streams), **Method 1 (Text Input with impossible delimiter + JSON Input)** is the industry-standard approach.

**Troubleshooting Method 1:**

If you're still seeing issues with Text File Input:

1. **Check Preview after Text File Input step** - Do you see 46 rows with complete JSON in `json_line` field?
   - If YES → Problem is in JSON Input configuration
   - If NO → Text File Input separator is splitting the JSON

2. **Try these separators in order:**
   - `¶` (paragraph symbol - Ctrl+Shift+U then 00B6)
   - `§` (section symbol)
   - `|||NEVER|||` (multi-character that won't appear)
   - `\x01` (ASCII character 1 - rarely used)

3. **Verify Enclosure is blank or impossible character**
   - If enclosure is `"` it will break JSON parsing!

### Step 4: Aggregate Event Metrics

**Objective:** Count different event types per user to understand engagement patterns.

**Approach:** We'll use **Modified JavaScript Value** step to create conditional counts in a single pass (more efficient than multiple filter branches).

#### Configuration Steps:

1. Add **Modified JavaScript Value** step after the JSON Input step

2. Click **Get Variables** to populate available fields (event_id, user_id, event_type, timestamp)

3. In the script editor, add this code:

```javascript
// Initialize counters (these will accumulate per row, so we'll aggregate later)
var is_page_view = (event_type == "page_view") ? 1 : 0;
var is_add_to_cart = (event_type == "add_to_cart") ? 1 : 0;
var is_purchase = (event_type == "purchase") ? 1 : 0;
var is_checkout = (event_type == "checkout") ? 1 : 0;
var is_search = (event_type == "search") ? 1 : 0;
var is_product_view = (event_type == "product_view") ? 1 : 0;
```

4. Click **Get Variables** button to populate the output fields table with these 6 new fields (all type: Integer)

5. Add **Group by** step:

**Group by tab:**
- Group field: `user_id`

**Aggregates tab:**

| Field | Subject | Type | New field name |
|-------|---------|------|----------------|
| event_id | event_id | COUNT | total_events |
| is_page_view | is_page_view | SUM | page_views |
| is_add_to_cart | is_add_to_cart | SUM | cart_additions |
| is_purchase | is_purchase | SUM | purchases |
| is_checkout | is_checkout | SUM | checkouts |
| is_search | is_search | SUM | searches |
| is_product_view | is_product_view | SUM | product_views |

6. Click **Get lookup fields** to auto-populate

**Alternative Approach (Without JavaScript):**

If you prefer not to use JavaScript, use the **Filter rows** pattern:

1. After JSON Input, add **Copy rows to result** step (or use the event stream directly)
2. Create 6 parallel branches with **Filter rows**:
   - Branch 1: `event_type = "page_view"` → Group by user_id → COUNT as page_views
   - Branch 2: `event_type = "add_to_cart"` → Group by user_id → COUNT as cart_additions
   - Branch 3: `event_type = "purchase"` → Group by user_id → COUNT as purchases
   - Branch 4: `event_type = "checkout"` → Group by user_id → COUNT as checkouts
   - Branch 5: `event_type = "search"` → Group by user_id → COUNT as searches
   - Branch 6: `event_type = "product_view"` → Group by user_id → COUNT as product_views
3. Add **Merge Join** steps (FULL OUTER on user_id) to combine all 6 branches
4. Use **If field value is null** step to convert nulls to 0

**Note:** The JavaScript approach is more efficient (single pass vs. 6 filter branches), but the filter approach is easier to visualize and debug.

**Expected Event Aggregation Results** (sample from 46 events across 12 users):

| user_id | total_events | page_views | add_to_cart | checkout | purchase | searches | Segment |
|---------|--------------|------------|-------------|----------|----------|----------|---------|
| 1001 | 8 | 4 | 1 | 1 | 1 | 1 | High Converter |
| 1002 | 4 | 3 | 1 | 0 | 0 | 0 | Window Shopper |
| 1003 | 4 | 0 | 0 | 0 | 0 | 1 | Researcher |
| 1004 | 3 | 1 | 0 | 0 | 0 | 0 | Engaged User |
| 1005 | 6 | 1 | 1 | 1 | 1 | 1 | High Converter |
| 1006 | 3 | 1 | 1 | 0 | 0 | 0 | Window Shopper |
| 1007 | 3 | 0 | 0 | 0 | 0 | 1 | Researcher |
| 1008 | 3 | 2 | 0 | 0 | 0 | 0 | Engaged User |
| 1009 | 6 | 1 | 2 | 1 | 1 | 0 | High Converter |
| 1010 | 3 | 1 | 1 | 0 | 0 | 0 | Window Shopper |
| 1011 | 1 | 1 | 0 | 0 | 0 | 0 | Low Activity |
| 1012 | 1 | 1 | 0 | 0 | 0 | 0 | Low Activity |

**Key Insights from this Data:**
- **3 High Converters** (1001, 1005, 1009): Complete funnel from page_view → search → add_to_cart → checkout → purchase
- **3 Window Shoppers** (1002, 1006, 1010): Add items to cart but don't checkout (abandoned cart recovery opportunity)
- **2 Researchers** (1003, 1007): High engagement with search/reviews but no cart activity
- **2 Engaged Users** (1004, 1008): Use support/wishlist features showing brand engagement
- **2 Low Activity** (1011, 1012): Single page view only (acquisition or bounce issue)

### Step 5: Join All Data Sources

1. **Text file input**: Read `pvfs://MinIO/raw-data/csv/customers.csv`

2. **Sort rows** - All streams by customer_id/user_id

3. First **Merge join**: Customers + Sales aggregates
   - Join type: LEFT OUTER (keep all customers)
   - Key: customer_id

4. Second **Merge join**: Result + Event aggregates
   - Join type: LEFT OUTER
   - Key: customer_id = user_id

### Step 6: Calculate Customer Metrics

This step creates derived metrics to measure customer recency, tenure, engagement, and value segmentation.

#### Part A: Calculator Step - Date-Based Metrics

1. Add **Calculator** step (under Transform category)
2. Connect from the second Merge Join step
3. Configure calculations:

**Click "New Calculation" and configure:**

| # | New field name | Calculation type | Field A | Field B | Value Type | Remove |
|---|----------------|------------------|---------|---------|------------|--------|
| 1 | days_since_last_purchase | Date A - Date B (days) | System date (A) | last_purchase | Integer | No |
| 2 | days_as_customer | Date A - Date B (days) | last_purchase (A) | first_purchase (B) | Integer | No |

**Detailed Configuration for Calculation 1:**
- **Field Name**: `days_since_last_purchase`
- **Calculation**: `Date A - Date B (days)` ← Select from dropdown
- **Field A**: `System date` ← Use special field (current date)
  - If "System date" not available, use `Get System Info` step first to create a `today` field
- **Field B**: `last_purchase`
- **Value Type**: `Integer`
- **Conversion Mask**: Leave blank
- **Decimal Symbol**: Leave blank
- **Grouping Symbol**: Leave blank
- **Remove**: `N` (No - keep both original fields)

**Detailed Configuration for Calculation 2:**
- **Field Name**: `days_as_customer`
- **Calculation**: `Date A - Date B (days)`
- **Field A**: `last_purchase`
- **Field B**: `first_purchase`
- **Value Type**: `Integer`
- **Remove**: `N`

**Important Notes:**
- Ensure your date fields (`last_purchase`, `first_purchase`) are in Date format (not String)
- If they're strings, add a **Select values** step before Calculator to convert them:
  - Meta-data tab → Field: `last_purchase`, Type: `Date`, Format: `yyyy-MM-dd` (or your date format)
  - Same for `first_purchase`

**Expected Results with Sample Data:**

The sales.csv data spans recent dates (last 90 days from Feb 2026):
- Oldest purchase: 2025-11-15 (Customer 1001, ~81 days ago)
- Most recent: 2026-02-02 (Customer 1003, ~2 days ago)

| Customer | First Purchase | Last Purchase | days_as_customer | days_since_last_purchase |
|----------|----------------|---------------|------------------|--------------------------|
| 1001 | 2025-11-15 | 2026-01-28 | 74 | 7 |
| 1002 | 2025-12-01 | 2026-02-01 | 62 | 3 |
| 1003 | 2025-12-10 | 2026-02-02 | 54 | 2 |
| 1004 | 2026-01-15 | 2026-01-15 | 0 | 20 |
| 1005 | 2026-01-20 | 2026-01-20 | 0 | 15 |

**Note:**
- **Repeat customers** (1001, 1002, 1003) have 2 purchases each → `days_as_customer` > 0
- **First-time buyers** (1004, 1005, etc.) have 1 purchase → `days_as_customer` = 0
- **Recent purchasers** (1003: 2 days ago) have low `days_since_last_purchase` (high recency)
- **Older purchasers** (1004: 20 days ago) have higher `days_since_last_purchase` (lower recency)

---

**TROUBLESHOOTING: days_as_customer Returns 0 for All Customers**

If `days_as_customer` = 0 for ALL customers (including repeat customers 1001, 1002, 1003), the problem is in **Step 2 (Group By aggregation)**, NOT in the Calculator step.

**Diagnosis Steps:**

1. **Preview after Group By step** (Step 2) - Check these values:

| customer_id | total_orders | first_purchase | last_purchase | Issue? |
|-------------|--------------|----------------|---------------|--------|
| 1001 | 2 | 2025-11-15 | 2026-01-28 | ✅ Correct - should give 74 days |
| 1001 | 2 | 2026-01-28 | 2026-01-28 | ❌ WRONG - only showing last purchase |
| 1001 | 1 | 2025-11-15 | 2025-11-15 | ❌ WRONG - only 1 sale showing |

2. **If first_purchase = last_purchase for customer 1001:**

   **Root Cause:** Group By aggregation is only seeing ONE sale per customer instead of all sales.

   **Fix:** Check your **Text File Input** step (Step 2, part 1):
   - Preview the Text File Input - Do you see **15 rows**?
   - If you only see **12 rows** (one per customer), the issue is here

   **Solution:**
   - Remove any filters or limits on Text File Input
   - Ensure **Limit** setting is 0 (unlimited)
   - Check **Content** tab → NR rows to skip = 0
   - Verify file path: `pvfs://MinIO/raw-data/csv/sales.csv`

3. **If Text Input shows 15 rows but Group By shows duplicate dates:**

   **Root Cause:** Group By might be configured incorrectly

   **Solution:**
   - Double-check **Group field** is `customer_id` (not sale_id)
   - Aggregates tab: MIN and MAX are both using `sale_date` field (not sale_id)
   - Remove any Sort steps between Text Input and Group By (they can interfere)

4. **If first_purchase ≠ last_purchase but days_as_customer still = 0:**

   **Root Cause:** Calculator date subtraction issue

   **Solution:**
   - Check date fields are in **Date** format, not String
   - Add **Select Values** step before Calculator:
     - Meta-data tab → `first_purchase`: Type = Date, Format = yyyy-MM-dd
     - Meta-data tab → `last_purchase`: Type = Date, Format = yyyy-MM-dd

5. **Quick Test:**

   Run this check on customer 1001 after Calculator:
   ```
   first_purchase = 2025-11-15
   last_purchase = 2026-01-28
   days_as_customer = 74 (if correct) or 0 (if broken)
   ```

   If you see 0, add a **Filter Rows** step before Calculator:
   - Condition: `customer_id = 1001`
   - Preview to isolate the issue

**Most Common Root Cause:**

90% of the time, the issue is that **Text File Input is only reading 12 rows instead of 15 rows**, meaning each customer only has one sale visible to the Group By step. Check this FIRST!

#### Part B: Formula Step - Engagement Score

1. Add **Formula** step (under Scripting category)
2. Connect from Calculator step
3. Click **New field** button
4. Configure:

**Field name**: `engagement_score`

**Formula**:
```
[total_events]*0.3 + [cart_additions]*0.5 + [total_orders]*0.2
```

**Value type**: `Number`

**Explanation:**
- Events weighted at 30% (shows interest)
- Cart additions weighted at 50% (shows intent)
- Orders weighted at 20% (already converted)
- Higher weight on cart additions captures "about to buy" behavior

**Test values:**
- High engager: 10 events, 5 cart adds, 3 orders = 3.0 + 2.5 + 0.6 = **6.1**
- Window shopper: 5 events, 2 cart adds, 0 orders = 1.5 + 1.0 + 0.0 = **2.5**
- Browser: 8 events, 0 cart adds, 0 orders = 2.4 + 0.0 + 0.0 = **2.4**

#### Part C: Modified JavaScript or Value Mapper - Customer Segmentation

**Option 1: Modified JavaScript** (Recommended - More Flexible)

1. Add **Modified JavaScript Value** step
2. Connect from Formula step
3. Add this script:

```javascript
// Classify customer based on total lifetime spend
var customer_segment = "";

if (total_spent == null || total_spent == 0) {
    customer_segment = "Prospect";
} else if (total_spent >= 1000) {
    customer_segment = "High Value";
} else if (total_spent >= 500) {
    customer_segment = "Medium Value";
} else if (total_spent > 0) {
    customer_segment = "Low Value";
}
```

4. Click **Get Variables** to add `customer_segment` field (Type: String)

**Option 2: Value Mapper** (Simpler - Fixed Rules)

**Note:** Value Mapper works best with discrete values, not ranges. For range-based logic, use JavaScript above.

If you want to use Value Mapper anyway:

1. First add **Modified JavaScript** to create a category field:
```javascript
var spend_category = "";
if (total_spent >= 1000) spend_category = "1000+";
else if (total_spent >= 500) spend_category = "500-999";
else if (total_spent > 0) spend_category = "1-499";
else spend_category = "0";
```

2. Then add **Value Mapper** step:

| Source field | Target field | Source value | Target value |
|--------------|--------------|--------------|--------------|
| spend_category | customer_segment | 1000+ | High Value |
| spend_category | customer_segment | 500-999 | Medium Value |
| spend_category | customer_segment | 1-499 | Low Value |
| spend_category | customer_segment | 0 | Prospect |

- **Default value**: `Prospect`
- **Non-matching value**: `Unknown`

**Recommendation:** Use **Modified JavaScript (Option 1)** for cleaner implementation.

### Step 7: Handle Nulls

1. **If field value is null** step or **Replace nulls** step:

| Field | Replace with |
|-------|--------------|
| total_orders | 0 |
| total_spent | 0 |
| total_events | 0 |
| engagement_score | 0 |

### Step 8: Output Customer 360

1. **Select values** - Choose final fields:
   - customer_id
   - first_name, last_name, email
   - country, status
   - registration_date
   - total_orders
   - total_spent
   - avg_order_value
   - first_purchase, last_purchase
   - days_since_last_purchase
   - total_events
   - page_views
   - cart_additions
   - engagement_score
   - customer_segment

2. **Text file output**:
   - Filename: `pvfs://MinIO/curated/customer/customer_360`
   - Format: CSV

---

### Transformation Flow Diagram

This diagram shows the complete flow of Exercise 3: Customer 360 View transformation.

```
═══════════════════════════════════════════════════════════════════════════════
                        PHASE 1: DATA INPUT & PARSING
═══════════════════════════════════════════════════════════════════════════════

BRANCH A: SALES DATA          BRANCH B: EVENT DATA         BRANCH C: CUSTOMER DATA
─────────────────────         ─────────────────────        ────────────────────

┌─────────────────┐           ┌─────────────────┐          ┌─────────────────┐
│ Text Input      │           │ Text Input      │          │ Text Input      │
│ sales.csv       │           │ user_events.json│          │ customers.csv   │
│                 │           │ Separator: ¶    │          │                 │
│ Fields:         │           │ (impossible     │          │ Fields:         │
│ • sale_id       │           │  delimiter)     │          │ • customer_id   │
│ • customer_id   │           │ Fields:         │          │ • first_name    │
│ • product_id    │           │ • json_line     │          │ • last_name     │
│ • sale_amount   │           │                 │          │ • email         │
│ • sale_date     │           │ 46 lines read   │          │ • country       │
│                 │           │ each as single  │          │                 │
│ 15 rows         │           │ string field    │          │ 12 rows         │
└────────┬────────┘           └────────┬────────┘          └────────┬────────┘
         │                             │                            │
         │                             │                            │
         │                    ┌────────▼────────┐                   │
         │                    │ JSON Input      │                   │
         │                    │ Source: from    │                   │
         │                    │ previous step   │                   │
         │                    │ Field: json_line│                   │
         │                    │                 │                   │
         │                    │ Parse each line │                   │
         │                    │ into fields:    │                   │
         │                    │ • event_id      │                   │
         │                    │ • user_id       │                   │
         │                    │ • event_type    │                   │
         │                    │ • timestamp     │                   │
         │                    │ • product_id    │                   │
         │                    │ • session_id    │                   │
         │                    │ (+ 7 more)      │                   │
         │                    │                 │                   │
         │                    │ 46 rows         │                   │
         │                    └────────┬────────┘                   │
         │                             │                            │
         │                             │                            │
═══════════════════════════════════════════════════════════════════════════════
                     PHASE 2: EVENT PROCESSING & AGGREGATION
═══════════════════════════════════════════════════════════════════════════════
         │                             │                            │
         │                    ┌────────▼────────┐                   │
         │                    │ Modified JS     │                   │
         │                    │                 │                   │
         │                    │ Create binary   │                   │
         │                    │ indicators:     │                   │
         │                    │                 │                   │
         │                    │ var is_page_view│                   │
         │                    │  = (event_type  │                   │
         │                    │   == "page_view"│                   │
         │                    │   ) ? 1 : 0     │                   │
         │                    │                 │                   │
         │                    │ Same for:       │                   │
         │                    │ • is_add_to_cart│                   │
         │                    │ • is_purchase   │                   │
         │                    │ • is_checkout   │                   │
         │                    │ • is_search     │                   │
         │                    │ • is_product_   │                   │
         │                    │   view          │                   │
         │                    │                 │                   │
         │                    │ Still 46 rows   │                   │
         │                    └────────┬────────┘                   │
         │                             │                            │
         │                             │                            │
┌────────▼────────┐           ┌────────▼────────┐                   │
│ Group By        │           │ Group By        │                   │
│                 │           │                 │                   │
│ Group: customer │           │ Group: user_id  │                   │
│ _id             │           │                 │                   │
│                 │           │ Aggregates:     │                   │
│ Aggregates:     │           │ • COUNT(event_  │                   │
│ • COUNT(sale_id)│           │   id) → total_  │                   │
│   → total_orders│           │   events        │                   │
│ • SUM(sale_     │           │ • SUM(is_page_  │                   │
│   amount) →     │           │   view) →       │                   │
│   total_spent   │           │   page_views    │                   │
│ • AVG(sale_     │           │ • SUM(is_add_to │                   │
│   amount) →     │           │   _cart) →      │                   │
│   avg_order_    │           │   cart_additions│                   │
│   value         │           │ • SUM(is_       │                   │
│ • MIN(sale_date)│           │   purchase) →   │                   │
│   → first_      │           │   purchases     │                   │
│   purchase      │           │ • SUM(is_       │                   │
│ • MAX(sale_date)│           │   checkout) →   │                   │
│   → last_       │           │   checkouts     │                   │
│   purchase      │           │ • SUM(is_search)│                   │
│                 │           │   → searches    │                   │
│ 12 rows         │           │                 │                   │
│ (1 per customer)│           │ 12 rows         │                   │
│                 │           │ (1 per user)    │                   │
└────────┬────────┘           └────────┬────────┘                   │
         │                             │                            │
         │                             │                            │
═══════════════════════════════════════════════════════════════════════════════
                       PHASE 3: SORTING FOR MERGE JOINS
═══════════════════════════════════════════════════════════════════════════════
         │                             │                            │
    ┌────▼─────┐                 ┌─────▼─────┐              ┌──────▼──────┐
    │Sort Rows │                 │Sort Rows  │              │ Sort Rows   │
    │Key:      │                 │Key:       │              │ Key:        │
    │customer_ │                 │user_id    │              │ customer_id │
    │id (ASC)  │                 │(ASC)      │              │ (ASC)       │
    └────┬─────┘                 └─────┬─────┘              └──────┬──────┘
         │                             │                            │
         │                             │                            │
═══════════════════════════════════════════════════════════════════════════════
                          PHASE 4: JOINING DATA SOURCES
═══════════════════════════════════════════════════════════════════════════════
         │                             │                            │
         └─────────────────┬───────────┘                            │
                           │                                        │
                  ┌────────▼─────────┐                              │
                  │ Merge Join       │                              │
                  │ Type: INNER      │                              │
                  │                  │                              │
                  │ Left: Sales      │                              │
                  │ Right: Events    │                              │
                  │ Key: customer_id │                              │
                  │      = user_id   │                              │
                  │                  │                              │
                  │ Result: Combined │                              │
                  │ sales + event    │                              │
                  │ metrics          │                              │
                  │                  │                              │
                  │ ~12 rows         │                              │
                  └────────┬─────────┘                              │
                           │                                        │
                           └────────────────┬───────────────────────┘
                                            │
                                   ┌────────▼─────────┐
                                   │ Merge Join       │
                                   │ Type: LEFT OUTER │
                                   │                  │
                                   │ Left: Sales+     │
                                   │       Events     │
                                   │ Right: Customers │
                                   │ Key: customer_id │
                                   │                  │
                                   │ Result: All 3    │
                                   │ sources combined │
                                   │                  │
                                   │ Fields (20+):    │
                                   │ • Demographics   │
                                   │ • Sales metrics  │
                                   │ • Event metrics  │
                                   │                  │
                                   │ 12 rows          │
                                   └────────┬─────────┘
                                            │
                                            │
═══════════════════════════════════════════════════════════════════════════════
                    PHASE 5: BUSINESS LOGIC & ENRICHMENT
═══════════════════════════════════════════════════════════════════════════════
                                            │
                                 ┌──────────▼──────────┐
                                 │ Calculator          │
                                 │ Step 6              │
                                 │                     │
                                 │ Create date-based   │
                                 │ metrics:            │
                                 │                     │
                                 │ days_since_last_    │
                                 │ purchase =          │
                                 │   Today -           │
                                 │   last_purchase     │
                                 │                     │
                                 │ days_as_customer =  │
                                 │   last_purchase -   │
                                 │   first_purchase    │
                                 │                     │
                                 │ 12 rows             │
                                 └──────────┬──────────┘
                                            │
                                 ┌──────────▼──────────┐
                                 │ Formula             │
                                 │ Step 6 (continued)  │
                                 │                     │
                                 │ Calculate composite │
                                 │ engagement score:   │
                                 │                     │
                                 │ engagement_score =  │
                                 │  (total_events*0.3) │
                                 │  + (cart_additions  │
                                 │     * 0.5)          │
                                 │  + (total_orders    │
                                 │     * 0.2)          │
                                 │                     │
                                 │ Higher score =      │
                                 │ More engaged        │
                                 │                     │
                                 │ 12 rows             │
                                 └──────────┬──────────┘
                                            │
                                 ┌──────────▼──────────┐
                                 │ Value Mapper or     │
                                 │ Modified JavaScript │
                                 │ Step 6 (continued)  │
                                 │                     │
                                 │ Classify customer   │
                                 │ segment based on    │
                                 │ total_spent:        │
                                 │                     │
                                 │ IF total_spent      │
                                 │    >= 1000          │
                                 │  → "High Value"     │
                                 │ ELSE IF >= 500      │
                                 │  → "Medium Value"   │
                                 │ ELSE IF > 0         │
                                 │  → "Low Value"      │
                                 │ ELSE                │
                                 │  → "Prospect"       │
                                 │                     │
                                 │ 12 rows             │
                                 └──────────┬──────────┘
                                            │
                                 ┌──────────▼──────────┐
                                 │ If Field Value is   │
                                 │ Null (Step 7)       │
                                 │                     │
                                 │ Handle nulls for    │
                                 │ customers with no   │
                                 │ sales or events:    │
                                 │                     │
                                 │ • total_orders → 0  │
                                 │ • total_spent → 0   │
                                 │ • total_events → 0  │
                                 │ • engagement_       │
                                 │   score → 0         │
                                 │                     │
                                 │ Ensures all numeric │
                                 │ fields have values  │
                                 │                     │
                                 │ 12 rows             │
                                 └──────────┬──────────┘
                                            │
═══════════════════════════════════════════════════════════════════════════════
                            PHASE 6: OUTPUT PREPARATION
═══════════════════════════════════════════════════════════════════════════════
                                            │
                                 ┌──────────▼──────────┐
                                 │ Select Values       │
                                 │ Step 8              │
                                 │                     │
                                 │ Order and select    │
                                 │ final fields:       │
                                 │                     │
                                 │ DEMOGRAPHICS (6):   │
                                 │ • customer_id       │
                                 │ • first_name        │
                                 │ • last_name         │
                                 │ • email             │
                                 │ • country           │
                                 │ • registration_date │
                                 │                     │
                                 │ SALES METRICS (5):  │
                                 │ • total_orders      │
                                 │ • total_spent       │
                                 │ • avg_order_value   │
                                 │ • first_purchase    │
                                 │ • last_purchase     │
                                 │                     │
                                 │ EVENT METRICS (7):  │
                                 │ • total_events      │
                                 │ • page_views        │
                                 │ • cart_additions    │
                                 │ • purchases         │
                                 │ • checkouts         │
                                 │ • searches          │
                                 │ • product_views     │
                                 │                     │
                                 │ CALCULATED (3):     │
                                 │ • days_since_last   │
                                 │ • engagement_score  │
                                 │ • customer_segment  │
                                 │                     │
                                 │ TOTAL: 21 fields    │
                                 │ 12 rows             │
                                 └──────────┬──────────┘
                                            │
                                 ┌──────────▼──────────┐
                                 │ Text File Output    │
                                 │ Step 8 (final)      │
                                 │                     │
                                 │ Destination:        │
                                 │ pvfs://MinIO/       │
                                 │ curated/customer/   │
                                 │ customer_360.csv    │
                                 │                     │
                                 │ Format: CSV         │
                                 │ Header: Yes         │
                                 │ Separator: ,        │
                                 │                     │
                                 │ Output: 12 customer │
                                 │ records with        │
                                 │ complete 360-degree │
                                 │ view combining:     │
                                 │ • Who they are      │
                                 │ • What they bought  │
                                 │ • How they engage   │
                                 │ • Their value tier  │
                                 │                     │
                                 └─────────────────────┘

═══════════════════════════════════════════════════════════════════════════════
                            DATA FLOW SUMMARY
═══════════════════════════════════════════════════════════════════════════════

PHASE 1: DATA INPUT & PARSING
  • 3 parallel branches read source data
  • Sales: 15 rows → Group By → 12 customers
  • Events: 46 rows (JSONL) → Text Input (impossible delimiter ¶)
           → JSON Input (parse json_line) → 46 structured rows
  • Customers: 12 rows (pass through for demographics)

PHASE 2: EVENT PROCESSING
  • Modified JavaScript creates 6 binary flags (is_page_view, is_add_to_cart, etc.)
  • Group By aggregates 46 events → 12 users with event counts

PHASE 3: SORTING
  • All 3 streams sorted by customer_id/user_id for merge joins

PHASE 4: JOINING
  • Merge Join 1 (INNER): Sales + Events on customer_id = user_id
  • Merge Join 2 (LEFT): Result + Customers on customer_id
  • Output: 12 rows with all data combined

PHASE 5: ENRICHMENT
  • Calculator: Add date-based metrics (days_since_last_purchase, days_as_customer)
  • Formula: Compute engagement_score = (events*0.3) + (cart*0.5) + (orders*0.2)
  • Value Mapper: Classify customer_segment based on total_spent thresholds
  • If Field Null: Replace nulls with 0 for numeric fields

PHASE 6: OUTPUT
  • Select Values: Order 21 final fields (demographics + sales + events + calculated)
  • Text File Output: Write customer_360.csv to MinIO curated bucket
  • Result: 12 customer records with complete 360-degree view

═══════════════════════════════════════════════════════════════════════════════
                                KEY CONCEPTS
═══════════════════════════════════════════════════════════════════════════════

JSONL PARSING TRICK:
  Text Input with "impossible delimiter" (¶ or §) treats each line as single field
  → JSON Input parses each field individually → All 46 events read correctly

BINARY FLAGS PATTERN:
  var is_page_view = (event_type == "page_view") ? 1 : 0
  → Group By with SUM → Count of each event type per user

TWO-STAGE AGGREGATION:
  1. Group By on sales.csv (customer_id) → transaction metrics
  2. Group By on events (user_id) → behavioral metrics
  → Merge Join combines both → Complete customer profile

CUSTOMER 360 = Who + What + How:
  • WHO: Demographics (name, email, country)
  • WHAT: Sales metrics (orders, spend, recency)
  • HOW: Behavioral metrics (events, engagement, actions)

═══════════════════════════════════════════════════════════════════════════════
```

---

### Expected Output Sample

The final Customer 360 view will combine demographics, purchase history, and behavioral events:

```csv
customer_id,first_name,last_name,email,country,total_orders,total_spent,avg_order_value,total_events,page_views,cart_additions,purchases,engagement_score,customer_segment,behavior_type
1001,John,Smith,john.smith@email.com,USA,2,1759.98,879.99,8,4,1,1,4.5,High Value,High Converter
1002,Maria,Garcia,maria.garcia@email.com,Spain,2,839.94,419.97,4,3,1,0,3.2,Medium Value,Window Shopper
1003,Wei,Chen,wei.chen@email.com,China,2,1329.98,664.99,4,0,0,0,2.8,High Value,Researcher
1004,Ahmed,Hassan,ahmed.hassan@email.com,UAE,1,599.99,599.99,3,1,0,0,2.1,Medium Value,Engaged User
1005,Sophie,Martin,sophie.martin@email.com,France,0,0.00,0.00,6,1,1,1,3.8,Prospect,High Converter
1011,Lucy,Brown,lucy.brown@email.com,UK,0,0.00,0.00,1,1,0,0,0.3,Prospect,Low Activity
```

**Key Fields Explained:**
- **total_orders, total_spent** - From sales.csv aggregation
- **total_events, page_views, cart_additions, purchases** - From user_events.json aggregation
- **engagement_score** - Calculated: `(total_events * 0.3) + (cart_additions * 0.5) + (total_orders * 0.2)`
- **customer_segment** - Based on total_spent thresholds (High Value ≥ $1000, Medium Value ≥ $500, etc.)
- **behavior_type** - Derived from event patterns (High Converter, Window Shopper, Researcher, etc.)

**Business Insights:**
- **Customer 1001** - High value with strong digital engagement (8 events), completed purchase funnel
- **Customer 1002** - Added to cart but didn't checkout (abandoned cart - send recovery email!)
- **Customer 1003** - Purchases offline/phone but researches online (omnichannel behavior)
- **Customer 1005** - New prospect with high conversion potential (6 events, 1 purchase in event stream)
- **Customer 1011** - Low engagement risk (only 1 page view, needs re-engagement campaign)

---

## Exercise 4: Clickstream Funnel Analysis

**Objective:** Build a conversion funnel from user events showing drop-off at each stage.

**Skills:** JSONL parsing, sessionization, pivoting, funnel calculations

### Step 1: Parse Event Stream

Same as Exercise 3, Step 3 - parse `user_events.json` JSONL format.

### Step 2: Define Funnel Stages

Create a mapping of event_type to funnel_stage:

1. Add **Value Mapper** step:

| Source (event_type) | Target (funnel_stage) | Order |
|---------------------|----------------------|-------|
| page_view | 1_View | 1 |
| search | 2_Search | 2 |
| product_view | 3_Product | 3 |
| add_to_cart | 4_Cart | 4 |
| checkout | 5_Checkout | 5 |

### Step 3: Find Furthest Stage per Session

Each session should count only once at their furthest stage.

1. **Sort rows** by: session_id, funnel_stage (DESC)

2. **Group by**:
   - Group by: session_id
   - Aggregate: FIRST (funnel_stage) → max_stage

3. This gives the furthest stage each session reached.

### Step 4: Count Sessions at Each Stage

1. **Group by** on max_stage:
   - Group by: max_stage
   - Aggregate: COUNT → session_count

### Step 5: Calculate Cumulative Funnel

Users who reached stage 5 also passed stages 1-4. We need cumulative counts.

1. **Sort rows** by stage order (descending: 5, 4, 3, 2, 1)

2. **Analytic Query** step (or JavaScript):
   - Running total of session_count

Alternative using **Calculator** with constants:

| Stage | Reached | Cumulative |
|-------|---------|------------|
| 5_Checkout | 1 | 1 |
| 4_Cart | 2 | 3 (2+1) |
| 3_Product | 1 | 4 (1+3) |
| 2_Search | 1 | 5 (1+4) |
| 1_View | 3 | 8 (3+5) |

### Step 6: Calculate Conversion Rates

1. **Formula** step:

```
conversion_rate = sessions_at_stage / total_sessions * 100
drop_off_rate = (previous_stage_sessions - sessions_at_stage) / previous_stage_sessions * 100
```

### Step 7: Output Funnel Report

Final output format:

```csv
stage_order,stage_name,sessions,cumulative_sessions,conversion_rate,drop_off_rate
1,View,8,8,100.0,0.0
2,Search,5,5,62.5,37.5
3,Product,4,4,50.0,20.0
4,Cart,3,3,37.5,25.0
5,Checkout,1,1,12.5,66.7
```

---

## Exercise 5: Log Parsing and Anomaly Detection

**Objective:** Parse application logs, extract metrics, and detect anomalies.

**Skills:** Regex, timestamp parsing, time-series analysis, conditional logic

**Scenario:** Application logs from hours 08:00-11:59 show a database outage at hour 10 (10:00-10:19) causing an ERROR spike. The transformation should detect this anomaly using rolling averages.

### Step 1: Read Log File

**Objective:** Read log file line-by-line as a single text field for parsing.

Log files are typically unstructured text where each line contains a complete log entry. We need to read each line as a single string field, then parse it with regex in the next step.

#### Configuration:

1. Add **Text file input** step

2. **File tab:**
   - **Filename**: `pvfs://MinIO/logs/app/application.log`
   - Click **Add** button to add the file to the list

3. **Content tab:**
   - **File type**: CSV (**IMPORTANT:** Must be CSV, not FIXED)
   - **Separator**: Use an impossible delimiter like `¶` or `§` (so it reads whole lines)
     - **Why?** This forces PDI to treat each entire line as a single field
     - Alternative: Use `${NEVER_EXISTS}` or `|||DELIM|||`
   - **Enclosure**: **Leave completely blank** (do NOT use quotes `"`)
     - **CRITICAL:** If you get error "Range [-1, -2) out of bounds", your Enclosure field has a character in it - clear it completely!
   - **Header**: No (unchecked)
   - **Format**: Unix
   - **Encoding**: UTF-8
   - **Limit**: 0 (unlimited)

4. **Fields tab:**
   - Click **Clear** to remove any auto-detected fields
   - Click **Add** to add a new field manually:

| Name | Type | Format | Length | Precision | Trim type |
|------|------|--------|--------|-----------|-----------|
| log_line | String | | 5000 | | both |

**Why Length = 5000?**
- Log lines can be very long (stack traces, JSON payloads, etc.)
- 5000 characters handles most log entries
- Increase if your logs have longer lines

5. **Preview** to verify:

You should see output like this:
```
log_line
2024-01-23 08:15:32 INFO  [DataService] Processing batch 1234
2024-01-23 08:15:33 ERROR [DatabaseConnection] Connection timeout after 30s
2024-01-23 08:15:34 WARN  [CacheManager] Cache miss rate exceeds 50%
2024-01-23 08:15:35 INFO  [APIController] Request completed in 245ms
```

Each line is a complete string in the `log_line` field.

**Troubleshooting:**

- **Error: "Range [-1, -2) out of bounds for length XX"**
  - **Cause:** Enclosure field contains a character (usually `"`)
  - **Solution:** Go to Content tab and completely clear the Enclosure field (make it blank)
  - This is the most common error when reading log files

- **Error: "Error converting line: java.lang.StringIndexOutOfBoundsException"**
  - **Cause:** File type is set to FIXED instead of CSV
  - **Solution:** Change File type from FIXED to CSV in Content tab

- **If you see columns being split by spaces:**
  - Your separator is wrong (probably space or tab)
  - Change to an impossible delimiter like `¶`

- **If you see empty fields or truncated lines:**
  - Increase the Length to 10000 or more
  - Check Encoding is UTF-8

- **If the file can't be found:**
  - Verify MinIO is running
  - Check VFS connection is configured
  - Verify the populate script created the log file

### Step 2: Parse Log Lines with Regex

**Objective:** Extract structured fields from unstructured log lines using regex pattern matching.

**Sample Log Format:**
```
2024-01-23 08:00:01 INFO  [main] Application started successfully
2024-01-23 08:20:30 ERROR [api] Failed to process request: Connection timeout
```

#### Configuration:

1. Add **Regex Evaluation** step (connect from Text File Input)

2. **Main Configuration tab:**

   - **Field to evaluate**: `log_line` (the field containing each log line)
   - **Result field name**: Leave blank (we'll create multiple fields from capture groups)

3. **Regular Expression:**

   In the main configuration area, enter this regex pattern:

   ```regex
   ^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\s+(\w+)\s+\[([^\]]+)\]\s+(.*)$
   ```

   **IMPORTANT:** Note the `\s+` (flexible whitespace) is used to handle variable spacing in log format.

   **Regex Pattern Breakdown:**

   | Pattern Component | Description | Matches |
   |-------------------|-------------|---------|
   | `^` | Start of line | (anchor) |
   | `(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})` | **Capture Group 1:** Timestamp | `2024-01-23 08:00:01` |
   | `\s+` | One or more whitespace (flexible) | (space) |
   | `(\w+)` | **Capture Group 2:** Log level (word chars) | `INFO`, `ERROR`, `WARN` |
   | `\s+` | One or more whitespace (handles 2 spaces after log level) | (spaces) |
   | `\[` | Literal opening bracket | `[` |
   | `([^\]]+)` | **Capture Group 3:** Component (any non-bracket chars) | `main`, `api` |
   | `\]` | Literal closing bracket | `]` |
   | `\s+` | One or more whitespace | (space) |
   | `(.*)` | **Capture Group 4:** Message (rest of line) | `Application started successfully` |
   | `$` | End of line | (anchor) |

4. **CRITICAL: Capture groups tab (or "Fields" tab):**

   **This step is REQUIRED - without it, you'll get `<null>` for all fields!**

   Click on the **"Capture groups"** tab (or **"Fields"** tab depending on PDI version).

   Configure field extraction for each capture group:

   | Capture Group # | Field Name | Type | Format | Length | Trim | Description |
   |-----------------|------------|------|--------|--------|------|-------------|
   | 1 | timestamp_str | String | | 20 | both | Raw timestamp string |
   | 2 | log_level | String | | 10 | both | Severity level |
   | 3 | component | String | | 50 | both | Component/module name |
   | 4 | message | String | | 2000 | both | Log message content |

   **In PDI Interface:**
   - Click **"Add"** or **"Add field"** button 4 times to create 4 rows
   - For each row, set:
     - **Capture Group #** (or **Group**): 1, 2, 3, 4
     - **Field name**: timestamp_str, log_level, component, message
     - **Type**: String for all
     - **Length**: 20, 10, 50, 2000

   **WITHOUT THIS TAB CONFIGURED, THE REGEX WON'T EXTRACT FIELDS - THIS IS THE MOST COMMON MISTAKE!**

5. **Options:**
   - **Create fields for non-matching lines**: Unchecked
     - **Why?** We want to skip malformed log lines
   - **Include rows that don't match**: Unchecked
     - **Why?** Only process valid log entries

#### Expected Output:

After regex parsing, each log line becomes 4 structured fields:

**Input (log_line):**
```
2024-01-23 08:00:01 INFO  [main] Application started successfully
```

**Output (parsed fields):**

| timestamp_str | log_level | component | message |
|---------------|-----------|-----------|---------|
| 2024-01-23 08:00:01 | INFO | main | Application started successfully |
| 2024-01-23 08:20:30 | ERROR | api | Failed to process request: Connection timeout |
| 2024-01-23 09:15:22 | WARN | database | Connection pool near capacity (90%) |

**Row Count:** 46 log entries → 46 parsed rows

#### Troubleshooting:

**Problem: Fields showing null for all rows (result = 'N')**

**Cause 1: Capture groups tab NOT configured (MOST COMMON!)**
- **Symptoms:** All fields show `<null>`, result column shows `N` for "No match"
- **Solution:**
  1. Open Regex Evaluation step
  2. Click on **"Capture groups"** or **"Fields"** tab
  3. Add 4 capture group entries with the field names (timestamp_str, log_level, component, message)
  4. **Without this tab configured, PDI will only tell you if the pattern matched (Y/N) but won't extract the fields!**

**Cause 2: Regex pattern doesn't match log format**
- **Solution:** Preview the `log_line` field in Step 1 output
- Verify the pattern matches your actual log format exactly
- Common issues:
  - Extra spaces in log format (use `\s+` for flexible whitespace)
  - Different bracket types (parentheses vs square brackets)
  - Different date format

**Cause 3: Wrong field name in "Field to evaluate"**
- **Solution:** Verify the field from Step 1 is named `log_line` (not `log_text` or `line`)

**Problem: Some rows missing (fewer than 46 output rows)**

**Cause:** Log lines that don't match the pattern are filtered out
- **Solution:** Enable "Include rows that don't match" temporarily to see which lines fail
- Check for:
  - Multi-line stack traces
  - Different log format for certain components
  - Malformed timestamp entries

**Problem: Message field truncated**

**Cause:** Length too short (some messages exceed 2000 chars with stack traces)
- **Solution:** Increase message field Length to 5000 or 10000

**Testing Your Regex:**

Before running the transformation, test your regex pattern:
1. Copy a sample log line from your Text Input preview
2. Test at https://regex101.com/ (select "PCRE" flavor)
3. Verify all 4 capture groups match correctly
4. Adjust pattern if needed

**Common Regex Modifications:**

If your log format is slightly different:

- **No brackets around component:**
  ```regex
  ^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}) (\w+)\s+(\w+) (.*)$
  ```

- **Different timestamp format (ISO 8601):**
  ```regex
  ^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z) (\w+)\s+\[([^\]]+)\] (.*)$
  ```

- **Component with spaces (use quotes):**
  ```regex
  ^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}) (\w+)\s+\["([^"]+)"\] (.*)$
  ```

### Step 3: Parse Timestamp

1. **Select values** step > **Meta-data** tab:
   - Change timestamp_str format: String → Date
   - Format mask: `yyyy-MM-dd HH:mm:ss`

Or use **String to Date** step.

### Step 4: Extract Hour for Aggregation

1. **Calculator** step:
   - **Field name**: `log_hour`
   - **Calculation**: Hour of day
   - **Field A**: `timestamp` (the Date field from Step 3)
   - **Value Type**: Integer
   - **Result**: Integer value 0-23 representing the hour

### Step 5: Count Errors per Hour

1. **Filter rows**: `log_level = 'ERROR' OR log_level = 'WARN'`

2. **Memory Group by**:

   **Group by tab:**
   - **Group field**: `log_hour`

   **Aggregates tab:**

   Add TWO aggregates:

   | Name | Subject | Type | Separator (if applicable) | Description |
   |------|---------|------|---------------------------|-------------|
   | error_count | (any field) | Number of Values (N) | | Count of errors/warnings |
   | error_messages | message | Concatenate strings separated by | `; ` | All error messages concatenated |

   **How to add "Concatenate strings" aggregate:**
   - Click **"Add"** to create second aggregate
   - **Name**: `error_messages`
   - **Subject**: `message` (the field containing error messages)
   - **Type**: Select **"Concatenate strings separated by"**
   - **Separator**: Enter `; ` (semicolon + space)

   **Why this is important:**
   - Captures ALL error messages from the hour
   - CRITICAL and WARNING alerts will include what errors occurred
   - Essential for debugging and root cause analysis

**Expected Output (with error messages):**

| log_hour | error_count | error_messages |
|----------|-------------|----------------|
| 8 | 2 | "Failed to process request: Connection timeout; Connection pool usage at 60%" |
| 9 | 5 | "Cache eviction failure for key: product_catalog; Connection pool approaching limit: 75% utilization; Slow query detected: duration 3.2s; Response time degraded: average 850ms (threshold: 500ms); High memory usage detected: 85% of heap used" |
| 10 | 50 | "Connection timeout: host db.example.com unreachable; Failed to process request: Database connection error; [... 48 more errors showing database outage, connection failures, service degradation ...]; SLA breach: contractual penalties triggered" |
| 11 | 1 | "Processing backlog: 50 queued requests" |

**Total:** 58 ERROR/WARN entries across 4 hours

**Note:** Hour 10's error_messages field will be very long (50 concatenated messages). This is intentional to show the severity of the outage.

### Step 6: Calculate Rolling Average

**Objective:** Calculate a 3-hour moving average of error counts to establish a baseline for anomaly detection.

A rolling (moving) average smooths out short-term fluctuations and helps identify when the current value significantly deviates from recent trends.

**Note:** PDI doesn't have a built-in rolling average step. We'll use **Modified JavaScript Value** to manually calculate it using previous row values.

#### Configuration:

1. Add **Modified JavaScript Value** step (connect from Memory Group by)

2. In the JavaScript editor, enter this script:

```javascript
// Calculate 3-hour rolling average using global variables
var rowNum = getProcessCount('r');

if (typeof prev_error_1 == 'undefined') {
    prev_error_1 = 0;
    prev_error_2 = 0;
}

if (rowNum == 1) {
    // First row: no history, use current value
    rolling_avg_errors = error_count;
    prev_error_1 = error_count;
    prev_error_2 = 0;
} else if (rowNum == 2) {
    // Second row: average of 2 values
    rolling_avg_errors = (prev_error_1 + error_count) / 2.0;
    prev_error_2 = prev_error_1;
    prev_error_1 = error_count;
} else {
    // Third row onwards: average of current + 2 previous
    rolling_avg_errors = (prev_error_2 + prev_error_1 + error_count) / 3.0;
    prev_error_2 = prev_error_1;
    prev_error_1 = error_count;
}
```

3. **Manually add the output field** in the fields table at the bottom:
   - Click **"Add"** button (or type directly in the table)
   - Configure the field:

   | Fieldname | Rename to | Type | Length | Precision |
   |-----------|-----------|------|--------|-----------|
   | rolling_avg_errors | (blank) | Number | 15 | 2 |

   **Note:** If you click "Get variables", it may incorrectly detect `rowNum` as an output field. Just **delete the `rowNum` row** and keep only `rolling_avg_errors`.

**How the Script Works:**

- **Row 1 (rowNum = 1):** No previous rows exist, so use current value as baseline
- **Row 2 (rowNum = 2):** Average of 2 values (previous + current)
- **Row 3+ (rowNum ≥ 3):** True 3-hour rolling average (2 previous + current) / 3
- Uses **global JavaScript variables** (`prev_error_1`, `prev_error_2`) to "remember" previous values
- Variables persist across rows within the Modified JavaScript Value step
- The `typeof` check initializes variables on first execution
- **IMPORTANT:** `getProcessCount('r')` is **1-indexed** (first row = 1, not 0)

**Expected Rolling Average Calculation:**

| Row | log_hour | error_count | Rolling Average Calculation | rolling_avg_errors |
|-----|----------|-------------|----------------------------|-------------------|
| 1 | 8 | 2 | 2 (first row, no history) | 2.0 |
| 2 | 9 | 9 | (2 + 9) / 2 | 5.5 |
| 3 | 10 | 46 | (2 + 9 + 46) / 3 | 19.0 |
| 4 | 11 | 1 | (9 + 46 + 1) / 3 | 18.67 |

**Why 3 hours?**
- Balances responsiveness vs. stability
- Too small (1-2 hours): Too sensitive to noise
- Too large (5+ hours): Slow to detect anomalies
- 3 hours: Good balance for hourly data

**Important:**
- Data must be sorted by `log_hour` (which it is from Memory Group by step)
- Variables persist across the transformation, allowing us to "look back" at previous rows

### Step 7: Detect Anomalies

**Objective:** Flag hours with error counts significantly higher than the rolling average.

#### Configuration:

1. Add **Formula** step (connect from Modified JavaScript Value)

2. Click **"Add"** to create two new formulas:

**Formula 1: is_anomaly**
- **Field name**: `is_anomaly`
- **Formula**:
  ```
  IF([error_count] > ([rolling_avg_errors] * 1.2); "YES"; "NO")
  ```
- **Value type**: String
- **Note:** Uses same 1.2× threshold as WARNING to flag any anomaly

**Formula 2: anomaly_severity**
- **Field name**: `anomaly_severity`
- **Formula**:
  ```
  IF([error_count] > ([rolling_avg_errors] * 1.5); "CRITICAL"; IF([error_count] > ([rolling_avg_errors] * 1.2); "WARNING"; "NORMAL"))
  ```
- **Value type**: String

**Threshold Explanation:**
- **CRITICAL**: error_count > rolling_avg × **1.5** (50% above baseline = severe anomaly)
- **WARNING**: error_count > rolling_avg × **1.2** (20% above baseline = moderate anomaly)
- **NORMAL**: error_count ≤ rolling_avg × 1.2

**Why these multipliers? (Demo-friendly thresholds)**
- **For demos/learning**, we use lower thresholds so students see all severity levels
- **1.5×**: Error rate 50% higher than baseline = CRITICAL
- **1.2×**: Error rate 20% higher than baseline = WARNING
- **In production**, you'd typically use higher thresholds (2.5× and 2.0×) to reduce false positives

**Troubleshooting: Hour 10 showing WARNING instead of CRITICAL**

If hour 10 is showing WARNING instead of CRITICAL, add these debug formulas:

1. Add a **Calculator** step after Step 6 (before Formula step):
   - **Field A**: `rolling_avg_errors`
   - **Calculation**: A × 2.5
   - **New field**: `critical_threshold`
   - **Value Type**: Number

2. Add another calculation:
   - **Field A**: `error_count`
   - **Field B**: `critical_threshold`
   - **Calculation**: A > B
   - **New field**: `should_be_critical`
   - **Value Type**: Boolean

3. Preview the data - you should see:
   - `error_count`: 40
   - `rolling_avg_errors`: 15.0 (or close to it)
   - `critical_threshold`: 37.5
   - `should_be_critical`: true

**If rolling_avg_errors is NOT 15.0:**
- Check Step 5: Are you getting exactly 40 errors for hour 10?
- Check Step 6: Is the JavaScript working correctly? Preview after Step 6.
- The rolling_avg should be: (2 + 3 + 40) / 3 = 15.0

**Alternative Fix: Use simpler threshold**
If still not working, change the formula to use absolute threshold:

```
IF([error_count] > 35; "CRITICAL"; IF([error_count] > 20; "WARNING"; "NORMAL"))
```

This uses fixed thresholds: >35 = CRITICAL, >20 = WARNING

**Formula Syntax Notes:**
- PDI Formula uses `IF(condition; true_value; false_value)` with semicolons
- Field references use square brackets: `[field_name]`
- Nested IF statements for multiple conditions
- NOT JavaScript ternary `? :` syntax!

**Expected Output (with anomaly detection):**

| log_hour | error_count | rolling_avg_errors | is_anomaly | anomaly_severity | Explanation |
|----------|-------------|-------------------|------------|------------------|-------------|
| 8 | 2 | 2.0 | NO | NORMAL | Baseline (1 ERROR, 1 WARN) |
| 9 | 5 | 3.5 | YES | **WARNING** | 5 > (3.5 × 1.2 = 4.2) → Performance degradation! |
| 10 | 50 | 19.0 | YES | **CRITICAL** | 50 > (19.0 × 1.5 = 28.5) → Database outage! |
| 11 | 1 | 18.67 | NO | NORMAL | Recovery (1 WARN) |

**Anomaly Detection Logic:**

**For Hour 8** (baseline):
- error_count = 2 (1 ERROR + 1 WARN)
- rolling_avg = 2.0 (first row, no history)
- WARNING threshold: 2.0 × 1.2 = **2.4**
- 2 > 2.4? **NO** → is_anomaly = "NO", severity = "NORMAL" ✓

**For Hour 9** (early warning signs - degraded performance):
- error_count = 5 (1 ERROR + 4 WARNs)
- rolling_avg = (2 + 5) / 2 = **3.5**
- WARNING threshold: 3.5 × 1.2 = **4.2**
- CRITICAL threshold: 3.5 × 1.5 = **5.25**
- 5 > 4.2? **YES → is_anomaly = "YES"**
- 5 > 5.25? **NO** → severity = **"WARNING"** ✓
- **Issues**: Cache failures, slow queries, connection pool at 75%, high memory usage

**For Hour 10** (database outage - catastrophic):
- error_count = 50 (44 ERRORs + 6 WARNs)
- rolling_avg = (2 + 5 + 50) / 3 = **19.0**
- WARNING threshold: 19.0 × 1.2 = **22.8**
- CRITICAL threshold: 19.0 × 1.5 = **28.5**
- 50 > 22.8? **YES → is_anomaly = "YES"**
- 50 > 28.5? **YES → severity = "CRITICAL"** ✓
- **Issues**: Database offline, connection pool exhausted, all services down, total service outage

**For Hour 11** (recovery):
- error_count = 1 (1 WARN)
- rolling_avg = (5 + 50 + 1) / 3 = **18.67**
- WARNING threshold: 18.67 × 1.2 = **22.4**
- 1 > 22.4? **NO** → is_anomaly = "NO", severity = "NORMAL" ✓

**Escalation Pattern (realistic incident timeline):**
- **Hour 8**: NORMAL - System healthy (baseline)
- **Hour 9**: **WARNING** - Performance degrading (ops team should investigate)
- **Hour 10**: **CRITICAL** - Complete system failure (immediate action required!)
- **Hour 11**: NORMAL - Recovery after database restart

**Threshold Tuning:**
- **CRITICAL (1.5×)**: Error rate **50% above** baseline = severe issue requiring immediate attention
- **WARNING (1.2×)**: Error rate **20% above** baseline = moderate anomaly worth investigating
- **Demo-friendly:** These lower thresholds ensure students see all severity levels with our sample data
- In production, these multipliers would be tuned based on:
  - Historical data patterns
  - False positive rate tolerance
  - Business impact of missing vs. over-alerting

### Step 8: Output and Alert

**Objective:** Route anomalies to appropriate outputs with error messages for debugging.

**Note:** If you followed Step 5 correctly with the `error_messages` aggregate, your data already includes all error messages!

#### Configuration:

1. Add **Switch/Case** step (connect from Formula step)
   - **Field name to switch**: `anomaly_severity`
   - **Default target step**: Leave blank or connect to a "Dummy" step

2. **Add cases:**
   - **Value**: `CRITICAL` → **Target step**: "Critical Alerts Output"
   - **Value**: `WARNING` → **Target step**: "Warning Alerts Output"
   - **Value**: `NORMAL` → **Target step**: "Normal Metrics Output"

3. Add **Text file output** steps for each case:

   **Critical Alerts Output:**
   - **Filename**: `pvfs://MinIO/logs/alerts/critical_alerts.csv`
   - **Fields to output**: log_hour, error_count, rolling_avg_errors, anomaly_severity, **error_messages**

   **Warning Alerts Output:**
   - **Filename**: `pvfs://MinIO/logs/alerts/warning_alerts.csv`
   - **Fields to output**: log_hour, error_count, rolling_avg_errors, anomaly_severity, **error_messages**

   **Normal Metrics Output:**
   - **Filename**: `pvfs://MinIO/logs/metrics/hourly_metrics.csv`
   - **Fields to output**: log_hour, error_count, rolling_avg_errors (optional: exclude error_messages for normal operations)

#### Expected Outputs:

**critical_alerts.csv** (Hour 10 - CRITICAL):
```csv
log_hour,error_count,rolling_avg_errors,anomaly_severity,error_messages
10,40,15.0,CRITICAL,"Connection timeout: host db.example.com unreachable; Failed to process request: Database connection error; Failed to process request: Database connection error; ETL job failed: Cannot connect to database; Request queue backing up: 25 pending requests; Connection pool exhausted: all connections timed out; Failed to process request: No database connections available; Failed to process request: No database connections available; Failed to execute job: DatabaseBackupJob; Request queue critical: 50 pending requests; Connection attempt 1 failed: Connection refused; Failed to process request: Connection refused; Failed to process request: Connection refused; Cache write failure: Backend unavailable; System health check failed: database unreachable; Connection attempt 2 failed: Connection refused; Failed to process request: Service unavailable; ETL job timeout: DailyCustomerSync exceeded 5 minute limit; Enabling circuit breaker for database calls; Request failed: Cannot reach backend services; Connection pool completely drained; HTTP 503 Service Unavailable returned to client; Unable to execute scheduled jobs: no database connection; Redis connection lost: timeout after 10s; Multiple service failures detected; All ETL pipelines suspended due to database failure; Alerting system: CRITICAL database outage; Service degradation: 0% success rate; Automatic failover failed: no replica available; Client requests timing out across all endpoints; Job queue blocked: 127 jobs pending; Data pipeline failure: no writes in 15 minutes; Load balancer reporting all backends down; Unable to write metrics: storage backend offline; Request rejection rate: 100%; Recovery process failed: corruption detected; Critical: Data loss risk detected; System unresponsive: manual intervention required; Backup system also failing: cascading failure; Emergency shutdown initiated for data protection; All data ingestion halted; Alert delivery failed: notification system down; Total service outage: 0 requests processed; Database cluster completely offline; Customer-facing services: all unavailable"
```

**Key Information in Alert:**
- **Hour 10** experienced CRITICAL database outage
- **40 errors** detected (baseline: 2-3 errors)
- **Root cause visible**: "Connection timeout: host db.example.com unreachable" (first error)
- **Cascading failures**: Database → API → ETL → Monitoring
- **Impact**: "Total service outage: 0 requests processed; Customer-facing services: all unavailable"

#### Optional: Email Alerts

1. Add **Mail** step after Critical/Warning outputs (requires SMTP configuration):
   - **Destination address**: `ops-team@example.com`
   - **Subject**: `[${anomaly_severity}] Hour ${log_hour}: ${error_count} errors detected`
   - **Body**:
     ```
     ALERT: Anomaly detected in application logs

     Time: Hour ${log_hour}:00
     Error Count: ${error_count} errors/warnings
     Baseline (Rolling Avg): ${rolling_avg_errors}
     Severity: ${anomaly_severity}

     ERROR MESSAGES:
     ${error_messages}

     ACTION REQUIRED: Please investigate immediately.
     Review full logs at: pvfs://MinIO/logs/app/application.log
     ```

**Sample Email for Hour 10 CRITICAL Alert:**
```
Subject: [CRITICAL] Hour 10: 40 errors detected

ALERT: Anomaly detected in application logs

Time: Hour 10:00
Error Count: 40 errors/warnings
Baseline (Rolling Avg): 15.0
Severity: CRITICAL

ERROR MESSAGES:
Connection timeout: host db.example.com unreachable; Failed to process request: Database connection error; Failed to process request: Database connection error; ETL job failed: Cannot connect to database; Request queue backing up: 25 pending requests; Connection pool exhausted: all connections timed out; Failed to process request: No database connections available; Failed to process request: No database connections available; Failed to execute job: DatabaseBackupJob; Request queue critical: 50 pending requests; Connection attempt 1 failed: Connection refused; Failed to process request: Connection refused; Failed to process request: Connection refused; Cache write failure: Backend unavailable; System health check failed: database unreachable; Connection attempt 2 failed: Connection refused; Failed to process request: Service unavailable; ETL job timeout: DailyCustomerSync exceeded 5 minute limit; Enabling circuit breaker for database calls; Request failed: Cannot reach backend services; Connection pool completely drained; HTTP 503 Service Unavailable returned to client; Unable to execute scheduled jobs: no database connection; Redis connection lost: timeout after 10s; Multiple service failures detected; All ETL pipelines suspended due to database failure; Alerting system: CRITICAL database outage; Service degradation: 0% success rate; Automatic failover failed: no replica available; Client requests timing out across all endpoints; Job queue blocked: 127 jobs pending; Data pipeline failure: no writes in 15 minutes; Load balancer reporting all backends down; Unable to write metrics: storage backend offline; Request rejection rate: 100%; Recovery process failed: corruption detected; Critical: Data loss risk detected; System unresponsive: manual intervention required; Backup system also failing: cascading failure; Emergency shutdown initiated for data protection; All data ingestion halted; Alert delivery failed: notification system down; Total service outage: 0 requests processed; Database cluster completely offline; Customer-facing services: all unavailable

ACTION REQUIRED: Please investigate immediately.
Review full logs at: pvfs://MinIO/logs/app/application.log
```

**Note:** SMTP configuration requires setting server, port, and authentication credentials in the Mail step.

### Access Log Parsing (Bonus)

Pattern for access.log (Apache/Nginx combined format):
```regex
^(\S+) - (\S+) \[([^\]]+)\] "(\w+) ([^"]+)" (\d+) (\d+)
```

Fields: ip, user, timestamp, method, path, status_code, bytes

---

### Troubleshooting Common Issues

#### Issue 1: Rolling Average Showing Incorrect Values

**Symptom:** Hour 8 shows rolling_avg = 1.0 instead of 2.0

**Cause:** PDI's `getProcessCount('r')` is **1-indexed** (first row = 1, not 0)

**Solution:** Ensure JavaScript uses correct row number checks:
```javascript
if (rowNum == 1) {        // First row (NOT rowNum == 0)
    rolling_avg_errors = error_count;
}
```

#### Issue 2: is_anomaly Shows "YES" but Severity is "NORMAL"

**Symptom:**
```
log_hour  error_count  rolling_avg_errors  is_anomaly  anomaly_severity
8         2            2.0                 YES         NORMAL
```

**Cause:** Formula step has mismatched thresholds between is_anomaly and anomaly_severity

**Solution:** Both formulas must use same threshold (1.2×):
- **is_anomaly**: `IF([error_count] > ([rolling_avg_errors] * 1.2); "YES"; "NO")`
- **anomaly_severity**: Check 1.5× first (CRITICAL), then 1.2× (WARNING)

#### Issue 3: Hour 9 Showing CRITICAL Instead of WARNING

**Symptom:** Both hour 9 and hour 10 show CRITICAL severity (no WARNING data)

**Cause:** Floating point precision or boundary condition - if error_count equals threshold exactly (e.g., 6.0 > 6.0), it may unexpectedly trigger

**Expected Values:**
- Hour 9: **5 errors** → WARNING (5 > 3.5 × 1.2 = 4.2, but 5 < 3.5 × 1.5 = 5.25)
- Hour 10: 50 errors → CRITICAL (50 > 19.0 × 1.5 = 28.5)

**Solution:**
1. Verify error counts using preview after Step 5 - should be 2, 5, 50, 1
2. If hour 9 shows 6+ errors, regenerate data:
   ```bash
   cd /path/to/Setup/MinIO/linux
   ./populate-minio.sh
   ```
3. Ensure hour 9 has exactly 5 errors (1 ERROR + 4 WARNs) to safely stay below CRITICAL threshold

#### Issue 4: No Data in WARNING or CRITICAL Outputs

**Symptom:** warning_alerts.csv or critical_alerts.csv files are empty

**Possible Causes:**

1. **Thresholds too high**: Lower thresholds to 1.2× (WARNING) and 1.5× (CRITICAL)

2. **Missing data regeneration**: Re-run populate script:
   ```bash
   cd /path/to/Setup/MinIO/linux
   ./populate-minio.sh
   ```

3. **Filter step issue**: Verify Switch/Filter Values step routes correctly

**Debug Steps:**
1. Preview data after Step 7 (Formula) - verify anomaly_severity values
2. Check Filter/Switch step configuration - ensure cases match exactly ("CRITICAL", not "Critical")
3. Verify output file paths are correct and writable

#### Issue 5: Regex Extraction Returns All Nulls

**Symptom:** All extracted fields show `<null>`, result column shows 'N'

**Cause:** Capture Groups tab not configured in Regex Evaluation step

**Solution:**
1. Open Regex Evaluation step
2. Go to "Capture groups" tab (or "Fields" tab)
3. Add all 4 field mappings:
   - Capture Group 1 → timestamp_str
   - Capture Group 2 → log_level
   - Capture Group 3 → component
   - Capture Group 4 → message

#### Issue 6: Formula Syntax Error with '?' Character

**Symptom:**
```
FormulaParseException: Extra content: '?'
```

**Cause:** Used JavaScript ternary syntax instead of PDI Formula syntax

**Wrong:**
```javascript
error_count > threshold ? "YES" : "NO"
```

**Correct:**
```
IF([error_count] > [threshold]; "YES"; "NO")
```

**Remember:** PDI Formula uses:
- `IF(condition; true_value; false_value)` with **semicolons**
- Field references with **square brackets**: `[field_name]`

---

## Exercise 6: Multi-Format Data Lake Ingestion

**Objective:** Combine data from CSV, JSON, and XML into a unified product schema.

**Skills:** Multi-format parsing, schema normalization, data validation, deduplication

**Business Context:** Modern data lakes often receive the same entities (products, customers, orders) from multiple sources in different formats. This exercise demonstrates how to ingest, normalize, validate, and deduplicate multi-format data into a unified schema - a common data engineering pattern.

**What You'll Learn:**
- Reading CSV, JSON, and XML files from S3/MinIO
- Mapping different source schemas to a unified target schema
- Handling nested JSON structures
- XPath queries for XML data extraction
- Data validation and error handling
- Deduplication strategies
- Writing curated data back to the data lake

---

### Step 0: Schema Discovery & Analysis

**Objective:** Understand source data structures BEFORE designing target schema.

**Why Important:** You can't design a unified schema without first understanding what data exists in each source. This is the discovery phase - like a detective investigating the data landscape.

#### Step 0.1: Inspect Each Source

**CSV Source Analysis:**

First, let's examine the actual CSV file:

```bash
mc cat minio-local/raw-data/csv/products.csv | head -5
```

**Output:**
```csv
product_id,product_name,category,price,stock_quantity
PROD-001,Laptop Pro 15,Electronics,999.99,50
PROD-002,Office Chair,Furniture,299.99,100
PROD-003,Coffee Maker,Appliances,79.99,200
```

**Observations:**
- ✅ Has `product_id` (unique identifier)
- ✅ Has `product_name` (display name)
- ✅ Has `category` (classification)
- ✅ Has `price` (numeric, 2 decimals)
- ✅ Has `stock_quantity` (integer)
- **Data completeness:** 100% - all fields populated
- **Data quality:** Clean, consistent format

---

**JSON Source Analysis:**

```bash
mc cat minio-local/raw-data/json/api_response.json | jq '.data.orders[0].items[0]'
```

**Output:**
```json
{
  "product_id": "PROD-001",
  "product_name": "Laptop Pro 15",
  "unit_price": 999.99,
  "quantity": 2
}
```

**Observations:**
- ✅ Has `product_id` (matches CSV!)
- ✅ Has `product_name` (matches CSV!)
- ✅ Has `unit_price` (same as CSV's `price`, different name)
- ✅ Has `quantity` (order quantity, NOT stock quantity)
- ❌ **Missing:** category field
- **Data completeness:** 80% - missing category
- **Data structure:** Nested in `$.data.orders[*].items[*]`

---

**XML Source Analysis:**

```bash
mc cat minio-local/raw-data/xml/inventory.xml | grep -A 4 "<item>"
```

**Output:**
```xml
<item>
  <sku>PROD-001</sku>
  <name>Laptop Pro 15</name>
  <category>Electronics</category>
  <quantity>50</quantity>
  <location>A-15</location>
</item>
```

**Observations:**
- ✅ Has `sku` (same as product_id, different name)
- ✅ Has `name` (same as product_name, different name)
- ✅ Has `category` (matches CSV!)
- ✅ Has `quantity` (warehouse stock)
- ❌ **Missing:** price field (warehouses don't track retail prices)
- ➕ **Extra field:** location (warehouse location, not needed for products)
- **Data completeness:** 80% - missing price
- **Data quality:** Clean, but different field naming conventions

---

#### Step 0.2: Create Field Mapping Matrix

Now create a comparison matrix to see which fields exist in which sources:

| Unified Field | CSV | JSON | XML | Notes |
|---------------|-----|------|-----|-------|
| **Identifier** | product_id | product_id | **sku** ⚠️ | Same data, different name in XML |
| **Name** | product_name | product_name | **name** ⚠️ | Same data, different name in XML |
| **Category** | category | ❌ **Missing** | category | JSON doesn't have - need default |
| **Price** | price | **unit_price** ⚠️ | ❌ **Missing** | Different name in JSON, missing in XML |
| **Stock Qty** | stock_quantity | quantity ⚠️ | quantity | CSV uses "stock_", others don't |

**Key Findings:**
1. **Common identifier:** All sources have a product identifier (product_id/sku)
2. **Name variations:** Same semantic field, different column names
3. **Missing data:** JSON missing category, XML missing price
4. **Semantic differences:** JSON's `quantity` means "order quantity", not "stock quantity"

---

#### Step 0.3: Schema Design Decisions

Based on analysis, make design decisions:

**Decision 1: Field Names**
- **Question:** Use CSV names (product_id), XML names (sku), or create new names?
- **Decision:** Use CSV names - they're most descriptive
- **Rationale:** "product_id" is clearer than "sku"; "product_name" is clearer than "name"

**Decision 2: Missing Category (JSON)**
- **Question:** How to handle JSON's missing category?
- **Options:**
  1. Leave NULL
  2. Derive from another field
  3. Set default value
- **Decision:** Set default "E-commerce" (since JSON comes from order API)
- **Rationale:** NULL categories break analytics; "E-commerce" indicates the data source

**Decision 3: Missing Price (XML)**
- **Question:** How to handle XML's missing price?
- **Options:**
  1. Leave NULL ✅
  2. Set default $0.00 ❌
  3. Lookup from CSV ⚠️ (complex)
- **Decision:** Leave NULL
- **Rationale:** NULL means "unknown"; $0.00 would be misleading; lookup adds complexity

**Decision 4: Data Types**
- `product_id`: String (contains "PROD-" prefix, not purely numeric)
- `product_name`: String (200 chars should handle longest name)
- `category`: String (100 chars sufficient)
- `price`: Decimal(15,2) - supports up to $999,999,999,999.99
- `quantity`: Integer - whole numbers only

**Decision 5: Metadata Fields**
- Add `source_system`: Track which source each record came from (important for debugging)
- Add `ingestion_time`: Track when data was loaded (important for auditing)

---

#### Step 0.4: Handle Duplicates Strategy

**Question:** What if PROD-001 appears in all three sources with different data?

**Analysis:**
```
CSV:  PROD-001, Laptop Pro 15, price=$999.99, quantity=50,  category=Electronics
JSON: PROD-001, Laptop Pro 15, price=$999.99, quantity=2,   category=NULL
XML:  PROD-001, Laptop Pro 15, price=NULL,    quantity=50,  category=Electronics
```

**Decision:** Prioritize by completeness:
1. **CSV** (most complete: has price, category, stock)
2. **JSON** (has price but missing category, quantity is order qty not stock)
3. **XML** (missing price, has category and stock)

**Implementation:** Use `source_priority` field (CSV=1, JSON=2, XML=3) for deduplication

---

#### Step 0.5: Schema Derivation Methodology Summary

**The Complete Process:**

```
1. DISCOVER
   ├── Inspect each source file
   ├── Document available fields
   ├── Note data types and formats
   └── Assess data completeness

2. COMPARE
   ├── Create field mapping matrix
   ├── Identify common fields across sources
   ├── Identify naming variations
   └── Identify missing/extra fields

3. DECIDE
   ├── Choose standard field names
   ├── Define data types
   ├── Decide how to handle missing data (NULL vs default vs derive)
   ├── Decide how to handle duplicates (prioritization)
   └── Add metadata fields for lineage tracking

4. DOCUMENT
   ├── Create target schema specification
   ├── Document mapping from each source
   ├── Document transformation rules
   └── Document data quality decisions
```

**Key Principles:**
- ✅ **Discover before design** - Never design schema without examining actual data
- ✅ **Prioritize completeness** - Choose naming from most complete source
- ✅ **Explicit over implicit** - Document every decision (defaults, NULLs, priorities)
- ✅ **Add lineage metadata** - Always track source_system and ingestion_time
- ✅ **Think about duplicates** - Plan deduplication strategy upfront
- ✅ **Nullable fields** - Use NULL for truly missing data, not fake defaults like "0" or "N/A"

**Why This Matters:**
- 🚫 **Without this process:** Schema designed in vacuum → doesn't fit data → lots of errors and rework
- ✅ **With this process:** Schema fits data perfectly → smooth ingestion → clean curated data

---

### Step 1: Define Target Schema

**Objective:** Design a unified schema based on source analysis from Step 0.

**Why Important:** Before ingesting data, you need a clear target schema. This ensures consistency across all sources and makes downstream analytics easier.

**Schema Derivation Summary:**
- ✅ Analyzed 3 sources (CSV, JSON, XML)
- ✅ Identified common fields (product_id, product_name)
- ✅ Identified naming variations (sku→product_id, name→product_name, unit_price→price)
- ✅ Identified missing data (JSON: no category, XML: no price)
- ✅ Decided on handling strategies (defaults, NULLs, prioritization)
- ✅ Added metadata fields (source_system, ingestion_time)

#### Unified Product Schema:

| Field | Type | Length | Description | Source Mapping |
|-------|------|--------|-------------|----------------|
| product_id | String | 50 | Unique product identifier | CSV: product_id<br>JSON: product_id<br>XML: sku |
| product_name | String | 200 | Product display name | CSV: product_name<br>JSON: product_name<br>XML: name |
| category | String | 100 | Product category | CSV: category<br>JSON: (derived from order type)<br>XML: category |
| price | Number | 15,2 | Unit price in USD | CSV: price<br>JSON: unit_price<br>XML: null (not available) |
| quantity | Integer | 10 | Available stock quantity | CSV: stock_quantity<br>JSON: quantity<br>XML: quantity |
| source_system | String | 10 | Origin system identifier | Constant: 'csv', 'json', or 'xml' |
| ingestion_time | Timestamp | - | When record was ingested | System timestamp |

#### Source Data Overview:

**CSV Products (`products.csv`):**
- 12 retail products with full details (price, stock, category)
- Clean, structured data
- Direct field mapping

**JSON Products (`api_response.json`):**
- Nested in order items: `$.data.orders[*].items[*]`
- Contains product_id, product_name, unit_price, quantity
- Category must be derived or set to default

**XML Products (`inventory.xml`):**
- Warehouse inventory with SKU (product_id), name, category, quantity
- No price information (warehouse doesn't track prices)
- Uses different field names (sku → product_id, name → product_name)

### Step 2: Ingest CSV Products

**Objective:** Read CSV products and map to target schema.

**Why CSV First:** CSV is the simplest format and requires minimal transformation - good for testing your target schema.

#### Configuration:

1. **Add Text file input step**
   - **Name**: "Read CSV Products"
   - **File/directory**: `pvfs://MinIO/raw-data/csv/products.csv`
   - **Separator**: Comma (,)
   - **Enclosure**: " (double quote)
   - **Header**: ☑ Header row present

2. **Fields tab** (click "Get Fields"):

   | Name | Type | Format | Length | Precision |
   |------|------|--------|--------|-----------|
   | product_id | String | | 50 | |
   | product_name | String | | 200 | |
   | category | String | | 100 | |
   | price | Number | #.## | 15 | 2 |
   | stock_quantity | Integer | | 10 | |

3. **Add Select values step**
   - **Name**: "Map CSV to Target Schema"

4. **Select & Alter tab** - Rename fields to match target:

   | Fieldname (from previous) | Rename to | Type | Length | Precision |
   |---------------------------|-----------|------|--------|-----------|
   | product_id | product_id | String | 50 | |
   | product_name | product_name | String | 200 | |
   | category | category | String | 100 | |
   | price | price | Number | 15 | 2 |
   | stock_quantity | quantity | Integer | 10 | |

5. **Add Add constants step**
   - **Name**: "Add CSV Metadata"

6. **Fields tab**:

   | Field name | Type | Value |
   |------------|------|-------|
   | source_system | String | csv |

7. **Add Get System Info step**
   - **Name**: "Add Ingestion Timestamp"

8. **Fields tab**:

   | Name | Type |
   |------|------|
   | ingestion_time | system date (variable) |

**Expected Output (Preview):**
```
product_id   product_name      category      price   quantity  source_system  ingestion_time
PROD-001     Laptop Pro 15     Electronics   999.99  50        csv            2024-01-23 10:30:45
PROD-002     Office Chair      Furniture     299.99  100       csv            2024-01-23 10:30:45
PROD-003     Coffee Maker      Appliances    79.99   200       csv            2024-01-23 10:30:45
```

**Row Count:** 12 products from CSV

### Step 3: Ingest JSON Products

**Objective:** Extract product data from nested JSON structure.

**Why More Complex:** JSON often contains nested structures. You need to use JSONPath to navigate to the data you want.

#### JSON Structure Overview:

```json
{
  "data": {
    "orders": [
      {
        "order_id": "ORD-001",
        "items": [
          {
            "product_id": "PROD-001",
            "product_name": "Laptop Pro 15",
            "unit_price": 999.99,
            "quantity": 2
          }
        ]
      }
    ]
  }
}
```

**JSONPath:** `$.data.orders[*].items[*]` extracts all items from all orders.

#### Configuration:

1. **Add JSON Input step**
   - **Name**: "Read JSON Products"
   - **File tab**:
     - **File or directory**: `pvfs://MinIO/raw-data/json/api_response.json`
     - **Include subfolders**: ☐ No

2. **Content tab**:
   - **Source is defined in a field**: ☐ No
   - **Source is a URL**: ☐ No
   - **Ignore empty file**: ☑ Yes
   - **Do not raise error if no files**: ☐ No
   - **Limit**: 0 (no limit)

3. **Fields tab**:

   Click **"Add"** to add fields manually with these settings:

   | Name | Path | Type | Format | Length | Precision | Trim type | Repeat |
   |------|------|------|--------|--------|-----------|-----------|--------|
   | product_id | $..data..items[*].product_id | String | **(blank)** | 50 | | none | N |
   | name | $..data..items[*].name | String | **(blank)** | 200 | | none | N |
   | quantity | $..data..items[*].quantity | Integer | **(blank)** | 10 | | none | N |
   | unit_price | $..data..items[*].unit_price | Number | **(blank)** | 15 | 2 | none | N |

   **JSONPath Explanation:**
   - `$` = Root element
   - `..` = Recursive descent (search anywhere in tree)
   - `data` = The data object
   - `items[*]` = All items in any items array
   - `.product_id` = The product_id field

   **Alternative Explicit Path:** `$.data.orders[*].items[*].product_id` (more explicit, same result)

   ⚠️ **CRITICAL:** Leave the **Format** column **completely blank** for all fields! If you see format codes like `0000000000`, delete them. This prevents leading zeros in numbers (e.g., `0000000001` instead of `1`).

   **Expected Preview Output:**
   ```
   product_id   name              quantity   unit_price
   P001         Laptop Pro 15     1          1299.99
   P003         Office Chair...   2          349.99
   ```

   **Row Count:** 2 product records from JSON orders

4. **Add Select values step**
   - **Name**: "Map JSON to Target Schema"

5. **Select & Alter tab** - Rename fields to match target schema:

   | Fieldname (from JSON) | Rename to | Type | Length | Precision |
   |----------------------|-----------|------|--------|-----------|
   | product_id | product_id | String | 50 | |
   | name | **product_name** | String | 200 | |
   | unit_price | **price** | Number | 15 | 2 |
   | quantity | quantity | Integer | 10 | |

   **Important Renames:**
   - `name` → `product_name` (to match CSV field name)
   - `unit_price` → `price` (to match CSV field name)

6. **Add Add constants step**
   - **Name**: "Add JSON Metadata"

7. **Fields tab** - Add missing fields that JSON doesn't have:

   | Field name | Type | Value |
   |------------|------|-------|
   | source_system | String | json |
   | category | String | E-commerce |
   | supplier | String | **(leave empty for NULL)** |
   | last_updated | String | **(leave empty for NULL)** |

   **Note:** JSON doesn't have category, supplier, or last_updated, so we add defaults/nulls

8. **Add Get System Info step**
   - **Name**: "Add JSON Ingestion Timestamp"

9. **Fields tab**:

   | Name | Type |
   |------|------|
   | ingestion_time | system date (variable) |

**Expected Output After All Transformations (Preview):**
```
product_id   product_name          category      price     quantity  supplier  last_updated  source_system  ingestion_time
P001         Laptop Pro 15         E-commerce    1299.99   1         null      null          json           2026-02-06 17:00:00
P003         Office Chair Deluxe   E-commerce    349.99    2         null      null          json           2026-02-06 17:00:00
```

**Row Count:** 2 product records from JSON

**Key Observations:**
- ✅ Product IDs: P001, P003 (match CSV products - these are duplicates!)
- ✅ Schema now matches CSV exactly (same field names and types)
- ⚠️ `quantity` values (1, 2) are **order quantities**, not stock quantities
- ⚠️ `supplier` and `last_updated` are NULL (not available in JSON)

---

#### JSONPath Troubleshooting

**Problem: Leading zeros in numbers** (e.g., `0000000001` instead of `1`)
- **Cause:** Format field has padding codes
- **Fix:** Clear the **Format** column completely for all numeric fields

**Problem: No data returned**
- **Cause:** Incorrect JSONPath
- **Fix:** Test path with: `mc cat minio-local/raw-data/json/api_response.json | jq '.data.orders[].items[]'`
- Verify structure matches your path

**Problem: Duplicate field names**
- **Cause:** Two fields named "name" or "product_id"
- **Fix:** Each field name must be unique

**JSONPath Syntax Quick Reference:**
```
$                           Root
.fieldname                  Direct child
..fieldname                 Recursive search (anywhere in tree)
[*]                         All array elements
[0]                         First array element
['field-name']              Field with special chars
```

---

### Step 4: Ingest XML Products

**Objective:** Extract product data from XML using XPath.

**Why Different:** XML uses hierarchical structure with tags. XPath (like SQL for XML) lets you query specific elements.

#### XML Structure Overview:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<inventory>
  <warehouse>Warehouse A</warehouse>
  <items>
    <item>
      <sku>PROD-001</sku>
      <name>Laptop Pro 15</name>
      <category>Electronics</category>
      <quantity>50</quantity>
      <location>A-15</location>
    </item>
    <item>
      <sku>PROD-002</sku>
      <name>Office Chair</name>
      <category>Furniture</category>
      <quantity>100</quantity>
      <location>B-23</location>
    </item>
  </items>
</inventory>
```

**XPath:** `/inventory/items/item` selects all `<item>` nodes

#### Configuration:

1. **Add Get data from XML step**
   - **Name**: "Read XML Products"

2. **File tab**:
   - **File or directory**: `pvfs://MinIO/raw-data/xml/inventory.xml`
   - **Include subfolders**: ☐ No

3. **Content tab**:
   - **Loop XPath**: `/inventory/items/item`
   - **Encoding**: UTF-8
   - **Namespace aware**: ☐ No (unless XML has namespaces)
   - **Ignore comments**: ☑ Yes
   - **Validate**: ☐ No

4. **Fields tab** - Define fields to extract:

   | Name | XPath | Element type | Type | Length | Format |
   |------|-------|--------------|------|--------|--------|
   | sku | sku | Element | String | 50 | |
   | name | name | Element | String | 200 | |
   | category | category | Element | String | 100 | |
   | quantity | quantity | Element | Integer | 10 | |

   **XPath Tips:**
   - Use relative paths from the Loop XPath
   - `sku` means "look for `<sku>` child element"
   - For attributes, use `@attribute_name`
   - For nested elements, use `parent/child`

5. **Add Select values step**
   - **Name**: "Map XML to Target Schema"

6. **Select & Alter tab**:

   | Fieldname | Rename to | Type | Length | Precision |
   |-----------|-----------|------|--------|-----------|
   | sku | product_id | String | 50 | |
   | name | product_name | String | 200 | |
   | category | category | String | 100 | |
   | quantity | quantity | Integer | 10 | |

7. **Add Add constants step**
   - **Name**: "Add XML Metadata"

8. **Fields tab**:

   | Field name | Type | Value |
   |------------|------|-------|
   | source_system | String | xml |

   **Note:** Only add source_system here. We'll add NULL fields in the next step.

9. **Add Formula step** (for NULL fields)
   - **Name**: "Add Missing Fields as NULL"

10. **Add these formulas:**

    **Formula 1: price**
    ```
    NULL()
    ```
    - New field: `price`
    - Value type: Number
    - Length: 15, Precision: 2

    **Formula 2: supplier**
    ```
    NULL()
    ```
    - New field: `supplier`
    - Value type: String
    - Length: 200

    **Formula 3: last_updated**
    ```
    NULL()
    ```
    - New field: `last_updated`
    - Value type: Date
    - Format: `yyyy-MM-dd`

    ⚠️ **Why Formula instead of Add constants?** PDI's Add constants step doesn't accept "null" as a literal value. Use Formula with `NULL()` function to create true NULL values.

11. **Add Get System Info step**
    - **Name**: "Add XML Ingestion Timestamp"
    - Add field: `ingestion_time` → Type: `system date (variable)`

**Expected Output After All Transformations (Preview):**
```
product_id   product_name          category      price   quantity  supplier  last_updated  source_system  ingestion_time
P001         Laptop Pro 15         Electronics   null    45        null      null          xml            2026-02-06 18:00:00
P002         Wireless Mouse        Electronics   null    250       null      null          xml            2026-02-06 18:00:00
P003         Office Chair Deluxe   Furniture     null    60        null      null          xml            2026-02-06 18:00:00
...
P099         Legacy Tablet         Electronics   null    12        null      null          xml            2026-02-06 18:00:00
```

**Row Count:** 17 warehouse inventory items

**Key Observations:**
- ✅ Product IDs: P001-P018, plus P099 (discontinued product only in warehouse)
- ✅ All fields present (price, supplier, last_updated are NULL)
- ✅ Quantities may differ from CSV (warehouse counts vs retail stock)
- ⚠️ P099 is unique to XML - will survive deduplication!

**Common XML Troubleshooting:**
- If no rows returned: Check Loop XPath is correct
- If empty values: Verify field XPaths match element names (case-sensitive)
- If namespace errors: Try checking "Ignore namespace" option

### Step 5: Combine Streams

**Objective:** Merge all three data streams (CSV, JSON, XML) into one unified stream.

**Why Combine:** This step stacks all rows from different sources vertically - like a SQL UNION ALL.

#### Configuration:

**Option A: Use "Append streams" step** (if available in your PDI version)

1. **Add Append streams step**
   - **Name**: "Combine All Products"
   - Found under: **Flow** category

2. **Connect all three streams** to this step

---

**Option B: Use "Dummy (do nothing)" step** (works in ALL PDI versions)

1. **Add "Dummy (do nothing)" step**
   - **Name**: "Combine All Products"
   - Found under: **Flow** → **Dummy (do nothing)**

2. **Connect all three streams TO this step:**
   - CSV final step → Dummy step
   - JSON final step → Dummy step
   - XML final step → Dummy step

   **Visual:**
   ```
   CSV (18 rows) ────┐
                     │
   JSON (2 rows) ────┼──→ Dummy (do nothing) ──→ 37 rows combined
                     │
   XML (17 rows) ────┘
   ```

3. **The Dummy step does nothing** - it just passes all incoming rows through unchanged. This effectively combines the streams!

---

**Important Schema Requirements:**

All three input streams MUST have the **exact same fields** in the **same order**:

| Field Name | Type | Notes |
|------------|------|-------|
| product_id | String | |
| product_name | String | |
| category | String | |
| price | Number | Can be NULL |
| quantity | Integer | |
| supplier | String | Can be NULL |
| last_updated | Date | Can be NULL |
| source_system | String | 'csv', 'json', or 'xml' |
| ingestion_time | Timestamp | |

**If you get schema mismatch errors:** Add **Select values** step before combining to ensure all streams have identical field names, types, and order.

---

**Expected Output:**
- **Row count:** 37 rows total (18 CSV + 2 JSON + 17 XML)
- All products from all sources combined
- Many products appear **multiple times** (duplicates to be handled in Step 7)

**Preview Check:**
```
product_id   product_name          category      price     quantity  source_system
P001         Laptop Pro 15         Electronics   1299.99   45        csv
P002         Wireless Mouse        Electronics   29.99     230       csv
P003         Office Chair Deluxe   Furniture     349.99    78        csv
...
P018         Laptop Stand          Furniture     54.99     85        csv
P001         Laptop Pro 15         Electronics   null      45        xml           ← Duplicate!
P002         Wireless Mouse        Electronics   null      250       xml           ← Duplicate!
P003         Office Chair Deluxe   Furniture     null      60        xml           ← Duplicate!
...
P099         Legacy Tablet         Electronics   null      12        xml           ← Unique to XML!
P001         Laptop Pro 15         E-commerce    1299.99   1         json          ← Duplicate!
P003         Office Chair Deluxe   E-commerce    349.99    2         json          ← Duplicate!
```

**Key Observations:**
- ✅ **35 rows total** (18 CSV + 17 XML + 2 JSON, but CSV has P001-P018, XML has P001-P018 + P099)
- ✅ **P001** appears **3 times** (CSV, JSON, XML) - will deduplicate to CSV version
- ✅ **P003** appears **3 times** (CSV, JSON, XML) - will deduplicate to CSV version
- ✅ **P002-P018** (except P003) appear **2 times** (CSV, XML) - will deduplicate to CSV version
- ✅ **P099** appears **1 time** (XML only) - will survive deduplication!
- ⚠️ Category differences: CSV/XML use actual categories, JSON uses "E-commerce" default

---

### Step 6: Data Validation

**Objective:** Validate data quality and route bad records to error handling.

**Why Important:** Multi-source data often has quality issues. Better to catch and handle them explicitly than have them cause downstream failures.

#### Configuration:

1. **Add Data Validator step**
   - **Name**: "Validate Product Data"

2. **Validations tab** - Add validation rules:

   | Fieldname | Validation Type | Configuration | Error Message |
   |-----------|----------------|---------------|---------------|
   | product_id | NOT NULL | | Product ID is required |
   | product_id | NOT EMPTY STRING | | Product ID cannot be empty |
   | product_name | NOT NULL | | Product name is required |
   | product_name | NOT EMPTY STRING | | Product name cannot be empty |
   | price | NUMERIC RANGE | Min: 0, Max: 999999 | Price must be >= 0 (if present) |
   | quantity | NUMERIC RANGE | Min: 0, Max: 999999 | Quantity must be >= 0 |

3. **Options tab**:
   - ☑ **Concatenate errors**: Shows all validation errors for a row
   - **Separator**: `, ` (comma-space)
   - ☑ **Output all errors as one field**: `validation_errors`

4. **Add Filter rows step** after Data Validator
   - **Name**: "Route Valid vs Invalid"

5. **Condition**:
   ```
   validation_errors IS NULL
   ```
   - **True** (valid records) → Continue to deduplication
   - **False** (invalid records) → Error output

6. **Add Text file output for errors** (connect from False branch):
   - **Name**: "Write Error Records"
   - **Filename**: `pvfs://MinIO/curated/products/errors/validation_errors_${Internal.Job.Start.Date.yyyyMMdd}.csv`
   - **Include date in filename**: Helps track when errors occurred
   - **Fields to output**: All fields + `validation_errors`

**Expected Output:**
- Valid records: ~95-100% should pass (25-35 rows)
- Invalid records: 0-5% to error file (0-2 rows)

**Common Validation Failures:**
- Empty product_id or product_name
- Negative price or quantity values
- Non-numeric values in numeric fields

---

### Step 7: Deduplicate

**Objective:** Remove duplicate products, keeping the most complete record.

**Why Important:** Same products appear in multiple sources. We want one canonical record per product_id.

**Strategy:** Prioritize sources with more complete data:
1. **CSV** - Most complete (has price, full details)
2. **JSON** - Has price, limited details
3. **XML** - Missing price data

#### Configuration:

**Option A: Sort + Unique Rows (Recommended)**

1. **Add Sort rows step**
   - **Name**: "Sort for Deduplication"

2. **Fields to sort**:

   | Fieldname | Sort ascending | Case sensitive | Presorted |
   |-----------|----------------|----------------|-----------|
   | product_id | Yes | Yes | No |
   | source_system | No (descending) | Yes | No |

   **Why descending on source_system?**
   - Alphabetically: "csv" < "json" < "xml"
   - Descending puts XML first, but we want CSV first
   - **Better approach**: Add a priority field first!

3. **Add Formula step BEFORE Sort rows**
   - **Name**: "Add Source Priority"

4. **Formula**:
   ```
   IF([source_system]="csv"; 1;
      IF([source_system]="json"; 2;
         IF([source_system]="xml"; 3; 99)))
   ```
   - **New field**: `source_priority` (Integer)
   - **Logic**: Lower number = higher priority

5. **Update Sort rows** to sort by:
   - `product_id` (ascending)
   - `source_priority` (ascending) ← Now CSV (1) comes before JSON (2) before XML (3)

6. **Add Unique rows step**
   - **Name**: "Keep First Occurrence"

7. **Fields tab**:
   - **Compare fields**: `product_id`
   - This keeps the FIRST row for each product_id (which is CSV if available, otherwise JSON, otherwise XML)

**Expected Output:**
- **Row count:** 19 unique products
  - P001-P018: From CSV (most complete data)
  - P099: From XML (unique product - discontinued tablet in warehouse)
- Duplicates removed (P001-P018 appeared in 2-3 sources each)
- CSV records preferred when product appears in multiple sources

**Example of Deduplication:**
```
Before (P001 appears 3 times):
P001, Laptop Pro 15, Electronics, 1299.99, 45,  csv       ← KEPT (priority 1)
P001, Laptop Pro 15, E-commerce, 1299.99, 1,   json      ← REMOVED (priority 2)
P001, Laptop Pro 15, Electronics, null,    45,  xml       ← REMOVED (priority 3)

After:
P001, Laptop Pro 15, Electronics, 1299.99, 45,  csv       ← Only CSV version kept
```

**Option B: Group By with Prioritization (Alternative)**

1. Sort by product_id and source_priority (as above)
2. Use **Group by** step:
   - **Group by**: `product_id`
   - **Aggregates**: Use "FIRST" for all other fields
   - Result: First record for each product_id (which is the highest priority source)

---

### Step 8: Output to Curated Zone

**Objective:** Write unified, validated, deduplicated product data to the curated zone.

**Why Curated:** Raw zone has unprocessed multi-format data. Curated zone has clean, unified, analytics-ready data.

#### Configuration:

**Option A: CSV Output (Simple)**

1. **Add Text file output step**
   - **Name**: "Write Unified Products CSV"

2. **File tab**:
   - **Filename**: `pvfs://MinIO/curated/products/unified_products.csv`
   - **Append**: ☐ No (overwrite)
   - **Include stepnr in filename**: ☐ No
   - **Include partition nr**: ☐ No
   - **Include date in filename**: ☑ Yes (optional - use `${Internal.Job.Start.Date.yyyyMMdd}`)
   - **Include time in filename**: ☐ No
   - **Create parent folder**: ☑ Yes

3. **Content tab**:
   - **Separator**: `,`
   - **Enclosure**: `"`
   - **Header**: ☑ Yes
   - **Footer**: ☐ No
   - **Format**: DOS or Unix
   - **Encoding**: UTF-8

4. **Fields tab**: Select all fields to output:
   - product_id
   - product_name
   - category
   - price
   - quantity
   - source_system
   - ingestion_time

**Option B: Parquet Output (Better for Analytics)**

1. **Add Parquet output step** (if available in your PDI version)
   - **Name**: "Write Unified Products Parquet"
   - **Filename**: `pvfs://MinIO/curated/products/unified_products.parquet`
   - **Compression**: Snappy (good balance of speed and compression)
   - **Fields**: Select all

**Benefits of Parquet:**
- ✅ Columnar format - faster for analytics
- ✅ Built-in compression (smaller files)
- ✅ Schema embedded in file
- ✅ Compatible with Spark, Hive, Athena, etc.

**Expected Final Output:**
```
product_id   product_name      category      price   quantity  source_system  ingestion_time
PROD-001     Laptop Pro 15     Electronics   999.99  50        csv            2024-01-23 10:30:45
PROD-002     Office Chair      Furniture     299.99  100       csv            2024-01-23 10:30:45
PROD-003     Coffee Maker      Appliances    79.99   200       csv            2024-01-23 10:30:45
PROD-004     Monitor 27"       Electronics   null    75        xml            2024-01-23 10:30:47
PROD-005     Desk Lamp         E-commerce    45.00   3         json           2024-01-23 10:30:46
```

**File Location:** `s3a://curated/products/unified_products.csv`

**Success Metrics:**
- ✅ 12-15 unique products
- ✅ No validation errors
- ✅ All sources represented
- ✅ CSV data preferred when duplicates exist
- ✅ File successfully written to curated zone

---

## Troubleshooting Guide

### Common Issues

#### S3/MinIO Connection Errors

**Error:** `Unable to connect to S3`

**Solutions:**
1. Verify MinIO is running: `curl http://localhost:9000/minio/health/live`
2. Check endpoint URL (use `http://localhost:9000`, not `https`)
3. Enable "Path Style Access" in S3 configuration
4. Verify credentials: minioadmin/minioadmin

#### XML Parsing Issues

**Error:** `No rows returned from XML`

**Solutions:**
1. Verify XPath expression with XML validator
2. Check namespace handling (may need to ignore namespaces)
3. Preview XML content: `mc cat minio-local/raw-data/xml/inventory.xml`

#### Merge Join Errors

**Error:** `Input must be sorted`

**Solutions:**
1. Add Sort rows step before each Merge join input
2. Ensure sort field names match exactly (case-sensitive)
3. Sort in same direction (both ASC or both DESC)

#### Memory Issues

**Error:** `Java heap space`

**Solutions:**
1. Increase PDI memory: Edit `spoon.sh` or `Spoon.bat`
   - Change `-Xmx2g` to `-Xmx4g`
2. Use database-based lookup instead of Stream lookup for large datasets
3. Process data in batches

#### Date Parsing Errors

**Error:** `Unparseable date`

**Solutions:**
1. Verify date format matches data: `yyyy-MM-dd` vs `dd/MM/yyyy`
2. Check for null or empty values before conversion
3. Use lenient parsing if format varies

### Performance Tips

1. **Parallelize where possible**: Multiple Text file inputs can run simultaneously
2. **Use Stream lookup for small lookups**: < 100K rows
3. **Use Database lookup for large lookups**: > 100K rows
4. **Sort only when necessary**: Sorting is expensive
5. **Filter early**: Remove unnecessary rows as early as possible

---

## Exercise 7: Financial Transaction Processing & Fraud Detection

**Objective:** Process credit card transactions, enrich with account and merchant data, calculate transaction metrics, and detect suspicious patterns using rule-based fraud detection.

**Skills:** Financial data processing, multi-table joins, running totals, rule-based fraud detection, transaction velocity analysis

**Business Context:** A payment processor needs to analyze transaction data in real-time to detect potentially fraudulent activity before authorizing transactions. The system must flag high-risk transactions based on amount thresholds, unusual merchant activity, account balance checks, and transaction velocity patterns.

### Dataset Overview

**Financial Data Structure:**

1. **transactions.csv** - Credit card transactions
   - transaction_id, account_id, merchant_id, amount, currency, transaction_date, status

2. **accounts.csv** - Customer account information
   - account_id, customer_name, account_type, balance, credit_limit, open_date, risk_rating

3. **merchants.csv** - Merchant information
   - merchant_id, merchant_name, merchant_category, country, risk_level

**Important: Understanding Account Balances**

**CREDIT Cards:**
- `balance` = **Available credit** (how much they can still spend)
- `credit_limit` = Maximum they can borrow
- Example: balance=$2500, credit_limit=$5000 means they've already spent $2500, have $2500 available
- **After spending $45.99:** balance_after_transaction = $2500 - $45.99 = $2454.01 (still positive = good)
- **Overlimit scenario:** If balance_after_transaction < 0, they exceeded their available credit

**DEBIT Cards:**
- `balance` = **Cash in account** (actual money they have)
- `credit_limit` = 0 (no borrowing allowed)
- Example: balance=$5420.75 means they have $5,420.75 cash
- **After spending $23.50:** balance_after_transaction = $5420.75 - $23.50 = $5397.25 (still positive = good)
- **Overdraft scenario:** If balance_after_transaction < 0, insufficient funds (transaction should be declined)

### Transformation Flow Diagram

```
┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│ Read             │     │ Read             │     │ Read             │
│ transactions.csv │     │ accounts.csv     │     │ merchants.csv    │
└────────┬─────────┘     └────────┬─────────┘     └────────┬─────────┘
         │                        │                        │
         │                        │                        │
         └────────────┬───────────┴────────────────────────┘
                      │
                      ▼
           ┌──────────────────────┐
           │ Merge Join:          │
           │ Add Account Info     │
           └──────────┬───────────┘
                      │
                      ▼
           ┌──────────────────────┐
           │ Merge Join:          │
           │ Add Merchant Info    │
           └──────────┬───────────┘
                      │
                      ▼
           ┌──────────────────────┐
           │ Calculate:           │
           │ - Balance After      │
           │ - Credit Utilization │
           │ - Amount in USD      │
           └──────────┬───────────┘
                      │
                      ▼
           ┌──────────────────────┐
           │ Group by Account:    │
           │ - Daily Transaction  │
           │   Count              │
           │ - Daily Total Amount │
           └──────────┬───────────┘
                      │
                      ▼
           ┌──────────────────────┐
           │ Fraud Detection:     │
           │ - High Amount        │
           │ - Overlimit          │
           │ - Velocity           │
           │ - High-Risk Merchant │
           └──────────┬───────────┘
                      │
                      ▼
           ┌──────────────────────┐
           │ Calculate:           │
           │ Fraud Risk Score     │
           └──────────┬───────────┘
                      │
            ┌─────────┴──────────┐
            │                    │
            ▼                    ▼
  ┌─────────────────┐  ┌─────────────────┐
  │ High Risk       │  │ Normal          │
  │ Transactions    │  │ Transactions    │
  │ (Score ≥ 50)    │  │ (Score < 50)    │
  └─────────────────┘  └─────────────────┘
```

### Step 1: Read Transaction Data

**Objective:** Load credit card transaction data from MinIO.

#### Configuration:

1. Add **Text file input** step
   - **Name**: "Read Transactions"
   - **Files tab**:
     - **File/directory**: `pvfs://MinIO/raw-data/finance/transactions.csv`

2. **Content tab**:
   - **Separator**: `,`
   - **Enclosure**: `"`
   - **Header**: Yes (check "Header row")

3. **Fields tab** (click "Get Fields"):

   | Name | Type | Format | Length | Precision |
   |------|------|--------|--------|-----------|
   | transaction_id | String | | 50 | |
   | account_id | String | | 20 | |
   | merchant_id | String | | 20 | |
   | amount | Number | #.## | 15 | 2 |
   | currency | String | | 3 | |
   | transaction_date | Date | yyyy-MM-dd HH:mm:ss | | |
   | status | String | | 20 | |

**Preview Output:**
```
transaction_id    account_id  merchant_id  amount    currency  transaction_date      status
TXN-2024-001      ACC-1001    MER-5001     45.99     USD       2024-01-23 09:15:22   APPROVED
TXN-2024-002      ACC-1002    MER-5002     1250.00   USD       2024-01-23 09:18:45   APPROVED
TXN-2024-003      ACC-1003    MER-5003     23.50     USD       2024-01-23 09:22:10   APPROVED
```

### Step 2: Read Account Data

**Objective:** Load customer account information.

#### Configuration:

1. Add **Text file input** step
   - **Name**: "Read Accounts"
   - **File/directory**: `pvfs://MinIO/raw-data/finance/accounts.csv`

2. **Fields tab**:

   | Name | Type | Format | Length | Precision |
   |------|------|--------|--------|-----------|
   | account_id | String | | 20 | |
   | customer_name | String | | 100 | |
   | account_type | String | | 20 | |
   | balance | Number | #.## | 15 | 2 |
   | credit_limit | Number | #.## | 15 | 2 |
   | open_date | Date | yyyy-MM-dd | | |
   | risk_rating | String | | 10 | |

**Preview Output:**
```
account_id  customer_name    account_type  balance    credit_limit  open_date   risk_rating
ACC-1001    John Smith       CREDIT        2500.00    5000.00       2020-03-15  LOW
ACC-1002    Jane Doe         CREDIT        150.00     3000.00       2019-07-22  MEDIUM
ACC-1003    Bob Johnson      DEBIT         5420.75    0.00          2021-01-10  LOW
```

### Step 3: Read Merchant Data

**Objective:** Load merchant information including risk levels.

#### Configuration:

1. Add **Text file input** step
   - **Name**: "Read Merchants"
   - **File/directory**: `pvfs://MinIO/raw-data/finance/merchants.csv`

2. **Fields tab**:

   | Name | Type | Format | Length | Precision |
   |------|------|--------|--------|-----------|
   | merchant_id | String | | 20 | |
   | merchant_name | String | | 100 | |
   | merchant_category | String | | 50 | |
   | country | String | | 50 | |
   | risk_level | String | | 10 | |

**Preview Output:**
```
merchant_id  merchant_name         merchant_category  country        risk_level
MER-5001     Amazon.com            RETAIL             United States  LOW
MER-5002     Luxury Watches Inc    JEWELRY            Switzerland    HIGH
MER-5003     Joe's Coffee Shop     RESTAURANT         United States  LOW
```

### Step 4: Enrich with Account Information

**Objective:** Join transaction data with account details using Stream Lookup.

**Why Stream Lookup?** Unlike Merge Join, Stream Lookup doesn't require sorted data and works like a database lookup - perfect for small reference tables like accounts (13 rows).

#### Configuration:

1. Add **Stream Lookup** step
   - **Name**: "Lookup Account Info"
   - Connect "Read Transactions" → "Lookup Account Info"
   - Connect "Read Accounts" → "Lookup Account Info" (this becomes the lookup reference)

2. **Lookup step**: Select "Read Accounts" (the reference data)

3. **Keys to lookup** (Lookup tab):

   | Stream field | Comparator | Lookup table field |
   |--------------|------------|--------------------|
   | account_id   | =          | account_id         |

4. **Retrieved fields** tab - Add all account fields:

   | Retrieve field | New name (optional) | Default value |
   |----------------|---------------------|---------------|
   | customer_name  | customer_name       | Unknown       |
   | account_type   | account_type        |               |
   | balance        | balance             | 0             |
   | credit_limit   | credit_limit        | 0             |
   | open_date      | open_date           |               |
   | risk_rating    | risk_rating         | UNKNOWN       |

5. **Settings tab** (optional):
   - ☐ Do not pass the row if lookup fails (uncheck to keep all transactions)
   - ☑ Use memory to cache lookup values

**Result:** Each of the 63 transactions now has customer name, balance, credit limit, and risk rating.

**Expected Row Count:** 63 rows (all transactions preserved with account info added)

---

### Step 5: Enrich with Merchant Information

**Objective:** Add merchant details to each transaction using Stream Lookup.

#### Configuration:

1. Add **Stream Lookup** step
   - **Name**: "Lookup Merchant Info"
   - Connect "Lookup Account Info" → "Lookup Merchant Info"
   - Connect "Read Merchants" → "Lookup Merchant Info" (this becomes the lookup reference)

2. **Lookup step**: Select "Read Merchants"

3. **Keys to lookup** (Lookup tab):

   | Stream field | Comparator | Lookup table field |
   |--------------|------------|--------------------|
   | merchant_id  | =          | merchant_id        |

4. **Retrieved fields** tab:

   | Retrieve field    | New name (optional) | Default value |
   |-------------------|---------------------|---------------|
   | merchant_name     | merchant_name       | Unknown       |
   | merchant_category | merchant_category   |               |
   | country           | country             |               |
   | risk_level        | risk_level          | LOW           |

**Result:** Fully enriched transactions with account + merchant data (63 rows).

**Expected Row Count:** 63 rows with all enrichment complete

---

**⚠️ IMPORTANT NOTE:** If you prefer to use **Merge Join** instead of Stream Lookup:
- You MUST add **Sort rows** steps before each Merge Join
- Sort both inputs by the join key (`account_id` or `merchant_id`)
- Merge Join requires sorted data, while Stream Lookup does not

### Step 6: Calculate Financial Metrics

**Objective:** Calculate derived fields for fraud analysis with correct financial logic.

#### Configuration:

1. Add **Formula** step (not Calculator - we need conditional logic)
   - **Name**: "Calculate Metrics"

2. **Add formulas** (click "Add" for each):

**Formula 1: days_since_account_open**
- **Field name**: `days_since_account_open`
- **Formula**:
  ```
  DAYS([open_date]; [transaction_date])
  ```
- **Value type**: Integer
- **CRITICAL:** Date order matters! `DAYS(start_date; end_date)` calculates days going FORWARD
  - ✓ **Correct**: `DAYS([open_date]; [transaction_date])` = **+1409** days
  - ✗ **Wrong**: `DAYS([transaction_date]; [open_date])` = **-1409** days (backwards!)

**Formula 2: balance_after_transaction**
- **Field name**: `balance_after_transaction`
- **Formula**:
  ```
  IF([account_type]="CREDIT";
     [balance] - [amount];
     [balance] - [amount])
  ```
- **Value type**: Number
- **Length**: 15, **Precision**: 2
- **Note:** For both CREDIT and DEBIT, subtract amount from balance
  - **CREDIT cards**: Start with available credit (positive), spend reduces it
  - **DEBIT cards**: Start with cash balance (positive), spend reduces it

**Formula 3: credit_utilization**
- **Field name**: `credit_utilization`
- **Formula**:
  ```
  IF([credit_limit] > 0;
     ([amount] / [credit_limit]) * 100;
     0)
  ```
- **Value type**: Number
- **Length**: 15, **Precision**: 2
- **Note:** Percentage of credit limit this transaction uses (only for CREDIT accounts)

**Formula 4: amount_usd** (convert all currencies to USD)
- **Field name**: `amount_usd`
- **Formula**:
  ```
  IF([currency]="USD"; [amount];
     IF([currency]="EUR"; [amount]*1.08;
        IF([currency]="GBP"; [amount]*1.27; [amount])))
  ```
- **Value type**: Number
- **Length**: 15, **Precision**: 2
- **Note:** Normalizes all transaction amounts to USD for comparison

**Expected Output Fields Added:**
- `days_since_account_open` - **Positive** number of days since account opened (e.g., 1409 days)
- `balance_after_transaction` - Account balance after deducting transaction (always starts positive)
- `credit_utilization` - Percentage of credit limit this transaction uses (0-100%)
- `amount_usd` - Transaction amount normalized to USD

**Example Calculations:**

**Transaction 1 - John Smith (CREDIT card):**
- balance: 2500 (available credit)
- amount: 45.99
- credit_limit: 5000
- balance_after_transaction: 2500 - 45.99 = **2454.01** (still positive, good)
- credit_utilization: (45.99 / 5000) × 100 = **0.92%** (very low)
- days_since_account_open: DAYS(2024-01-23, 2020-03-15) = **1409 days**

**Transaction 2 - Bob Johnson (DEBIT card):**
- balance: 5420.75 (cash in account)
- amount: 23.50
- credit_limit: 0 (debit accounts don't have credit limits)
- balance_after_transaction: 5420.75 - 23.50 = **5397.25** (still positive)
- credit_utilization: **0%** (no credit limit for debit cards)
- days_since_account_open: DAYS(2024-01-23, 2021-01-10) = **1108 days**

### Step 7: Calculate Transaction Velocity

**Objective:** Calculate daily transaction count and total per account (velocity analysis).

**Why Important:** Sudden spikes in transaction frequency or daily totals often indicate fraud.

#### IMPORTANT: Extract Date Without Timestamp First

⚠️ **CRITICAL STEP**: The `transaction_date` field contains timestamps (e.g., `2024-01-23 09:15:22`). If you group by this field directly, each transaction will be its own group because timestamps are unique!

**Add this step BEFORE the Group By:**

**Option A: Use Formula Step (Recommended)**
1. Add **Formula** step
   - **Name**: "Extract Date Only"

2. **Create Formula: transaction_date_only**
```
TRUNC([transaction_date])
```
- **Value type**: Date
- **Format**: `yyyy-MM-dd`

**Option B: Use Select Values Step**
1. Add **Select values** step
   - **Name**: "Extract Date Only"
2. **Meta-data tab**:
   - Find field: `transaction_date`
   - Change **Format** to: `yyyy-MM-dd` (removes time)

---

#### Group By Configuration:

1. Add **Group by** step (or **Memory Group by** for smaller datasets)
   - **Name**: "Daily Velocity by Account"

2. **Group by tab**:
   - Add grouping field: `account_id`
   - Add grouping field: `transaction_date_only` (if using Formula) OR `transaction_date` (if you changed format in Select values)

3. **Aggregates tab**:

   | Name | Subject | Type |
   |------|---------|------|
   | daily_txn_count | transaction_id | Number of Values (N) |
   | daily_total_amount | amount | Sum |
   | avg_transaction_size | amount | Average (Mean) |

**Expected Output (Multi-Date Data):**
```
account_id  transaction_date  daily_txn_count  daily_total_amount  avg_transaction_size
ACC-1001    2024-01-23        5                987.73              197.55
ACC-1001    2024-01-24        1                89.50               89.50
ACC-1001    2024-01-25        1                52.30               52.30
ACC-1002    2024-01-23        6                7586.10             1264.35
ACC-1002    2024-01-24        8                11125.00            1390.63  ⚠️ SUSPICIOUS!
(ACC-1002 has 0 transactions on Jan 25 - account likely frozen)
ACC-1003    2024-01-23        3                895.45              298.48
ACC-1003    2024-01-24        1                67.80               67.80
ACC-1003    2024-01-25        2                433.20              216.60
```

**Key Observations:**
- **Normal Pattern (ACC-1001)**: 5 transactions on day 1, then 1 per day = normal usage
- **Fraud Pattern (ACC-1002)**: 6 transactions on day 1, **8 on day 2** (7 declined high-value transactions in 1 hour), then 0 on day 3 = classic fraud velocity spike
- **Normal Pattern (ACC-1003)**: Distributed activity across 3 days with reasonable amounts

**What makes ACC-1002 suspicious on 2024-01-24:**
- 7 transactions in **1 hour** (13:15-14:15)
- All **DECLINED** (overlimit/insufficient funds)
- All at **high-risk merchants** (Luxury Watches, Electronics, Casino)
- Total attempted: **$11,125** in one day
- This pattern should trigger: `high_amount_flag`, `high_risk_merchant_flag`, `velocity_flag`

⚠️ **IMPORTANT WORKFLOW NOTE:**

The Group By step creates **aggregated data** (one row per account per day), which loses transaction-level details. You have two workflow options:

**Option A: Transaction-Level Fraud Detection (Recommended for this exercise)**
- Skip the Group By for now
- Go directly to Step 8 (Fraud Rule Detection) to flag individual transactions
- Later, you can add velocity analysis using **Analytic Query** step (adds velocity metrics to each transaction without aggregating)

**Option B: Aggregate-Level Analysis**
- Use Group By as shown above for velocity reporting
- Create separate transformation for transaction-level fraud detection
- This is better for reporting/dashboards but not for real-time fraud detection

**For this exercise, we'll use Option A - proceed to Step 8 without the Group By.**

---

### Step 7A (Alternative): Add Velocity Metrics Without Aggregating

Instead of Group By, use **Analytic Query** to add velocity counts to each transaction:

1. Add **Analytic Query** step
   - **Name**: "Add Daily Transaction Count"

2. **Group By**: `account_id`, `transaction_date_only`

3. **Aggregates**:
   - **New field**: `daily_txn_count`
   - **Subject**: `transaction_id`
   - **Type**: `Number of values`

**Result:** Each transaction now has a `daily_txn_count` field showing how many transactions that account had that day, **without losing transaction-level detail**.

---

### Step 8: Fraud Rule Detection

**Objective:** Flag transactions based on fraud indicators using business rules.

**⚠️ PREREQUISITE:** This step works on **transaction-level data** (63 rows).
- If you did Step 7 (Group By), go back and either:
  - Skip Step 7 and come directly here from Step 6, OR
  - Use Step 7A (Analytic Query) instead to preserve transaction details

#### Configuration:

1. Add **Formula** step to create fraud flags
   - **Name**: "Fraud Detection Rules"
   - Connect from: "Calculate Metrics" (Step 6) OR "Add Daily Transaction Count" (Step 7A if you used Analytic Query)

2. **Create fraud indicator fields using Formula step:**

**Formula 1: high_amount_flag**
```
IF([amount] > 1000; 1; 0)
```
- **Description:** Transactions over $1000 are higher risk

**Formula 2: overlimit_flag**
```
IF(AND([account_type]="CREDIT"; [balance_after_transaction] < 0); 1; 0)
```
- **Description:** Transaction would exceed available credit (balance goes negative)
- **Logic**: For credit cards, balance represents available credit. If balance_after_transaction < 0, they've exceeded their limit.

**Formula 3: high_risk_merchant_flag**
```
IF([risk_level]="HIGH"; 1; 0)
```
- **Description:** Merchant is in high-risk category (e.g., gambling, offshore)

**Formula 4: velocity_flag**
```
IF([daily_txn_count] > 7; 1; 0)
```
- **Description:** More than 7 transactions in one day
- **Note:** Only works if you used Step 7A (Analytic Query) to add `daily_txn_count` field
- **Alternative:** If you don't have `daily_txn_count`, skip this formula or set threshold based on `status` field: `IF([status]="DECLINED"; 1; 0)` to flag declined transactions

**Formula 5: new_account_flag**
```
IF([days_since_account_open] < 30; 1; 0)
```
- **Description:** Account opened less than 30 days ago

**Formula 6: high_utilization_flag**
```
IF([credit_utilization] > 80; 1; 0)
```
- **Description:** Single transaction uses >80% of credit limit

### Step 9: Calculate Fraud Risk Score

**Objective:** Combine fraud indicators into a weighted risk score.

#### Configuration:

1. Add **Calculator** or **Formula** step
   - **Name**: "Calculate Fraud Score"

2. **Fraud Risk Score Formula:**

```
([high_amount_flag] * 20) +
([overlimit_flag] * 30) +
([high_risk_merchant_flag] * 25) +
([velocity_flag] * 15) +
([new_account_flag] * 5) +
([high_utilization_flag] * 15)
```

**Score Breakdown:**
- **0-19**: Low Risk (Approve automatically)
- **20-49**: Medium Risk (Approve with monitoring)
- **50-79**: High Risk (Request additional verification)
- **80-110**: Critical Risk (Decline transaction)

**Example Calculations:**

**Transaction 1 - Normal Purchase:**
- high_amount_flag: 0 × 20 = 0
- overlimit_flag: 0 × 30 = 0
- high_risk_merchant_flag: 0 × 25 = 0
- velocity_flag: 0 × 15 = 0
- new_account_flag: 0 × 5 = 0
- high_utilization_flag: 0 × 15 = 0
- **Total Score: 0 (Low Risk)**

**Transaction 2 - Suspicious:**
- high_amount_flag: 1 × 20 = 20
- overlimit_flag: 0 × 30 = 0
- high_risk_merchant_flag: 1 × 25 = 25
- velocity_flag: 1 × 15 = 15
- new_account_flag: 0 × 5 = 0
- high_utilization_flag: 0 × 15 = 0
- **Total Score: 60 (High Risk)**

### Step 10: Route Transactions by Risk Level

**Objective:** Split transactions into different output files based on risk score.

#### Configuration:

1. Add **Filter rows** or **Switch / Case** step
   - **Name**: "Route by Risk Score"

**Option A: Filter rows (for 2-way split):**
- **Condition**: `fraud_risk_score >= 50`
- **Send 'true' data to step**: "High Risk Output"
- **Send 'false' data to step**: "Normal Output"

**Option B: Multiple Filter Rows (for multi-way split) - RECOMMENDED:**

⚠️ **Note:** Switch/Case only supports exact value matching, NOT comparison operators like `>=`. For range-based routing, use cascading Filter rows:

1. **First Filter rows**: "Critical Risk Filter"
   - Condition: `fraud_risk_score >= 80`
   - True → "Critical Risk - Decline" output
   - False → Goes to next filter

2. **Second Filter rows**: "High Risk Filter"
   - Condition: `fraud_risk_score >= 50`
   - True → "High Risk - Review" output
   - False → Goes to next filter

3. **Third Filter rows**: "Medium Risk Filter"
   - Condition: `fraud_risk_score >= 20`
   - True → "Medium Risk - Monitor" output
   - False → "Low Risk - Approve" output

**Visual Flow:**
```
Fraud Score Calculation
  ↓
[Critical Risk Filter] (>= 80) → Critical Output
  ↓ (False)
[High Risk Filter] (>= 50) → High Risk Output
  ↓ (False)
[Medium Risk Filter] (>= 20) → Medium Risk Output
  ↓ (False)
Low Risk Output
```

**Option C: Create Risk Category Field, then use Switch/Case:**

1. Add **Formula** step to create risk category:
```
IF([fraud_risk_score] >= 80; "CRITICAL";
   IF([fraud_risk_score] >= 50; "HIGH";
      IF([fraud_risk_score] >= 20; "MEDIUM"; "LOW")))
```

2. Then use **Switch/Case** step:
   - Field to switch: `risk_category`
   - Cases:
     - Value: `CRITICAL` → Target: "Critical Risk Output"
     - Value: `HIGH` → Target: "High Risk Output"
     - Value: `MEDIUM` → Target: "Medium Risk Output"
     - Default → "Low Risk Output"

### Step 11: Output Fraud Alerts

**Objective:** Write high-risk transactions to separate file for review.

#### Configuration:

1. Add **Text file output** step (for high risk)
   - **Name**: "High Risk Output"
   - **Filename**: `pvfs://MinIO/finance/alerts/high_risk_transactions.csv`
   - **Fields to output**:
     - transaction_id
     - account_id
     - customer_name
     - merchant_name
     - amount
     - currency
     - fraud_risk_score
     - high_amount_flag
     - overlimit_flag
     - high_risk_merchant_flag
     - velocity_flag
     - transaction_date

2. Add **Text file output** step (for normal transactions)
   - **Name**: "Normal Output"
   - **Filename**: `pvfs://MinIO/finance/processed/approved_transactions.csv`
   - **Fields to output**: (same as above, or all fields)

### Expected Results

**high_risk_transactions.csv:**
```csv
transaction_id,account_id,customer_name,merchant_name,amount,currency,fraud_risk_score,transaction_date
TXN-2024-015,ACC-1002,Jane Doe,Luxury Watches Inc,3500.00,USD,85,2024-01-23 14:22:10
TXN-2024-023,ACC-1005,Mike Wilson,Offshore Casino Ltd,2200.00,USD,60,2024-01-23 16:45:33
TXN-2024-031,ACC-1002,Jane Doe,Electronics Warehouse,1800.00,USD,50,2024-01-23 18:12:05
```

**Fraud Patterns Detected:**
- **TXN-2024-015**: High amount (20) + Overlimit (30) + High-risk merchant (25) + High utilization (15) = **90**
- **TXN-2024-023**: High amount (20) + High-risk merchant (25) + High utilization (15) = **60**
- **TXN-2024-031**: High amount (20) + High-risk merchant (25) + New account (5) = **50**

### Advanced: Real-Time Scoring with Database Lookup

For production fraud detection, you'd typically:

1. **Store account history in database** (PostgreSQL, MySQL)
2. **Use Database Lookup** step to get:
   - Last 24-hour transaction count
   - Average transaction amount (last 30 days)
   - Countries transacted in (last 7 days)
3. **Compare current transaction** against historical patterns
4. **Flag anomalies** (e.g., transaction from new country, amount 10× average)

**Example Database Lookup Query:**
```sql
SELECT
  COUNT(*) as txn_last_24h,
  AVG(amount) as avg_amount_30d,
  COUNT(DISTINCT country) as countries_7d
FROM transactions
WHERE account_id = ?
  AND transaction_date >= CURRENT_DATE - INTERVAL '30 days'
```

### Monitoring & Alerts

**Key Metrics to Track:**

1. **Fraud Detection Rate**: % of transactions flagged as high-risk
2. **False Positive Rate**: % of flagged transactions that were legitimate
3. **Average Risk Score**: Trend over time
4. **High-Risk Merchant Volume**: Transactions from risky merchants

**Sample Summary Report:**
```
Date: 2024-01-23
Total Transactions: 1,250
High Risk Flagged: 45 (3.6%)
Critical Risk: 8 (0.64%)
Total Amount Blocked: $87,450.00
Top Risk Factor: High Amount (67%)
```

### Production Considerations

1. **Performance:**
   - Index join keys (account_id, merchant_id) if using database
   - Use Memory Group by for < 100K rows
   - Consider streaming for real-time processing

2. **Data Quality:**
   - Handle missing merchant_id (use default risk level)
   - Validate currency codes
   - Check for duplicate transaction_ids

3. **Rule Maintenance:**
   - Store fraud rules in configuration table
   - Allow business users to adjust thresholds
   - A/B test rule changes

4. **Regulatory Compliance:**
   - Log all fraud decisions (audit trail)
   - Encrypt sensitive customer data
   - Implement data retention policies (GDPR, PCI-DSS)

---

## Next Steps

After completing these exercises, try:

1. **Add error handling**: Use Abort step for critical errors
2. **Add logging**: Use Write to Log step for debugging
3. **Create jobs**: Orchestrate transformations with PDI jobs
4. **Schedule execution**: Use Kitchen command line or scheduler
5. **Add parameters**: Make file paths and credentials configurable

## Resources

- [Pentaho Documentation](https://help.hitachivantara.com/Documentation/Pentaho)
- [MinIO Documentation](https://min.io/docs/)
- [PDI Step Reference](https://help.hitachivantara.com/Documentation/Pentaho/Data_Integration_and_Analytics)

---

**Workshop Version:** 1.0
**Last Updated:** January 2026
**Compatible with:** PDI 9.x, 10.x, 11.0.x | MinIO RELEASE.2024-01-01
