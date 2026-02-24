# Scenario 2: High-Frequency Stock Trades

**Business Use Case**: Process real-time stock trade events at high frequency, loading them into a MySQL data warehouse for analysis and alerting.

**Difficulty**: Intermediate | **Duration**: 45-60 minutes

## Learning Objectives

- Configure a Kafka Consumer step for high-frequency data (10 messages/sec)
- Tune batch settings for higher throughput (smaller duration, larger record count, concurrent batches)
- Parse streaming JSON data using JSON Input step
- Rename and type fields using Select values (including Meta-data tab)
- Write to MySQL using Table output with correct field mapping
- Understand when epoch conversion is NOT needed (database-generated timestamps)
- (Optional) Aggregate streaming data using Group By step

## Prerequisites

Before starting this scenario:

1. Workshop environment is running -- `make workshop-start`
2. MySQL is running with tables created -- `make mysql-verify`
3. Data is flowing into `pdi-stocktrades` topic -- `make consume-trades`
4. PDI (Spoon) is open with Kafka EE plugin installed
5. `warehouse_db` database connection is configured in Spoon (see [Scenario 1, Step 2](scenario-1-user-activity.md#step-2-create-database-connection-in-spoon))

## Architecture

```
Parent Transformation (Kafka Consumer Step)
    | (batches of records every 1 second or 50 records, up to 2 concurrent batches)
    v
Child Transformation
    Get records from stream
        |
    JSON Input (parse message field)
        |
    Select values (rename + set metadata/types)
        |
    Table output (write to stock_trades)
```

> **Key difference from Scenario 1**: There is no Formula step. The `pdi-stocktrades` JSON does not include a timestamp field -- the database column `trade_timestamp` uses `DEFAULT CURRENT_TIMESTAMP` to record when each row is inserted. This simplifies the transformation pipeline.

## Data Source

The `pdi-stocktrades` topic receives stock trade events at ~10 messages/second from the datagen connector. This is 10x the rate of `pdi-users`, which makes batch tuning critical.

**Sample message**:
```json
{"side":"BUY","quantity":2269,"symbol":"ZVZZT","price":558,"account":"LMN456","userid":"User_5"}
```

**Field descriptions**:

| JSON Field | Type | Description |
|-----------|------|-------------|
| `symbol` | String | Stock ticker symbol (e.g., `ZVZZT`) |
| `side` | String | Trade direction (`BUY` or `SELL`) |
| `quantity` | Integer | Number of shares traded |
| `price` | Integer | Trade price per share |
| `account` | String | Trading account identifier (e.g., `LMN456`) |
| `userid` | String | User identifier (e.g., `User_5`) |

> **Note**: There is no timestamp in the JSON payload. Unlike Scenario 1's `registertime` epoch field, stock trades rely on the database's `DEFAULT CURRENT_TIMESTAMP` to record when the row was inserted. This means no epoch conversion step is needed.

---

## Step-by-Step Instructions

### Step 1: Verify Data is Flowing

```bash
make consume-trades
```

You should see JSON messages with stock trade data. If not, deploy connectors first: `make deploy-connectors`

Observe the volume -- messages arrive much faster than the `pdi-users` topic. This high frequency is why we need different batch settings.

### Step 2: Verify Database Connection in Spoon

If you completed Scenario 1, the `warehouse_db` connection should already exist. Verify it:

1. Open Spoon (PDI)
2. Go to **View** panel (left side) -> **Database connections**
3. If `warehouse_db` is listed, double-click it and click **Test** to confirm connectivity
4. If it is NOT listed, create it following the instructions in [Scenario 1, Step 2](scenario-1-user-activity.md#step-2-create-database-connection-in-spoon)

**Connection details** (for reference):

| Setting | Value |
|---------|-------|
| Connection Name | `warehouse_db` |
| Connection Type | MySQL |
| Access | Native (JDBC) |
| Host Name | `localhost` |
| Database Name | `kafka_warehouse` |
| Port Number | `3306` |
| User Name | `kafka_user` |
| Password | `kafka_password` |

### Step 3: Create Parent Transformation

1. **File -> New -> Transformation**
2. Save as `stocktrades-to-db-parent.ktr` in the `transformations/` directory

#### Add Kafka Consumer Step

1. From the **Design** panel, expand **Input** -> drag **Kafka Consumer** onto the canvas
2. Double-click the Kafka Consumer step to configure:

#### Setup Tab

| Setting | Value | Notes |
|---------|-------|-------|
| Connection | Direct | |
| Bootstrap Servers | `localhost:9092` | External Kafka broker address |
| Topics | `pdi-stocktrades` | |
| Consumer Group | `pdi-stocktrades-consumer` | Unique name for this transformation |
| Sub-transformation | `[path]/transformations/stocktrades-to-db-child.ktr` | Use Browse button to select |

> **Tip**: Use the **Browse** button for the sub-transformation path. An incorrect path is a common source of "Error in sub-transformation" errors.

#### Batch Tab

| Setting | Value | Notes |
|---------|-------|-------|
| Duration (ms) | `1000` | Collect records for 1 second (not 5 like Scenario 1) |
| Number of records | `50` | Or until 50 records arrive |
| Maximum concurrent batches | `2` | Handle higher throughput (was 1 in Scenario 1) |
| Message prefetch limit | `100000` | Default is fine |
| Offset commit | When batch completes | At-least-once delivery (recommended) |

> **Why these batch settings?** With `pdi-stocktrades` producing ~10 msg/sec, a 5-second batch window would accumulate ~50 records before triggering. By reducing the duration to 1000ms and allowing 2 concurrent batches, we get lower latency (data reaches the database within ~1 second) and can process overlapping batches while the previous one is still writing to MySQL. The record count of 50 acts as a secondary trigger -- if a burst of messages arrives, the batch fires at 50 records even before the 1-second window elapses.

#### Fields Tab

Click **Get Fields** or manually add these (these are the default Kafka Consumer output fields):

| Name | Type |
|------|------|
| `key` | String |
| `message` | String |
| `topic` | String |
| `partition` | Integer |
| `offset` | Integer |
| `timestamp` | Integer |

#### Options Tab

Click **+** to add each property:

| Property | Value | Notes |
|----------|-------|-------|
| `auto.offset.reset` | `earliest` | Read from beginning on first run |
| `enable.auto.commit` | `false` | Let PDI manage offsets |

3. Click **OK** to save the step configuration
4. Save the transformation (**Ctrl+S**)

### Step 4: Create Child Transformation

1. **File -> New -> Transformation**
2. Save as `stocktrades-to-db-child.ktr` in the `transformations/` directory

---

#### Step 4a: Get Records from Stream

1. From **Design -> Input**, drag **Get records from stream** onto the canvas
2. Double-click to configure the fields:

| Name | Type | Length | Precision |
|------|------|--------|-----------|
| `key` | String | -1 | -1 |
| `message` | String | -1 | -1 |
| `topic` | String | -1 | -1 |
| `partition` | Integer | -1 | -1 |
| `offset` | Integer | -1 | -1 |
| `timestamp` | Integer | -1 | -1 |

> These fields must match the Fields tab in the parent's Kafka Consumer step exactly.

---

#### Step 4b: JSON Input

1. From **Design -> Input**, drag **JSON Input** onto the canvas
2. Draw a hop from **Get records from stream** -> **JSON Input**
3. Double-click JSON Input to configure:

**Source tab** (main settings):

| Setting | Value |
|---------|-------|
| Source is a field | Checked |
| Get source from field | `message` |
| Ignore missing path | Yes |
| Default path leaf to null | Yes |

**Fields tab** -- click **+** to add each field:

| Name | Path | Type | Format | Length | Precision | Trim |
|------|------|------|--------|--------|-----------|------|
| `symbol` | `$.symbol` | String | | -1 | -1 | none |
| `side` | `$.side` | String | | -1 | -1 | none |
| `quantity` | `$.quantity` | Integer | | -1 | -1 | none |
| `price` | `$.price` | Number | | -1 | -1 | none |
| `account` | `$.account` | String | | -1 | -1 | none |
| `userid` | `$.userid` | String | | -1 | -1 | none |

> **Note on JSON paths**: The `$.fieldname` syntax is standard JSONPath. Since the datagen produces flat JSON, the path is simply `$.` followed by the field name. For nested JSON (e.g., `{"data":{"symbol":"..."}}`), you would use `$.data.symbol`.
>
> **Price type**: The `price` field is extracted as `Number` type so PDI can map it to the `DECIMAL(10,2)` column in MySQL. If you extract it as `Integer`, PDI will truncate any decimal values (although the sample data shows integer prices, the schema allows decimals).

---

#### Step 4c: Select Values

1. From **Design -> Transform**, drag **Select values** onto the canvas
2. Draw a hop from **JSON Input** -> **Select values**
3. Double-click to configure:

##### Select & Alter Tab

This tab selects which fields to pass through and renames them to match database column names.

| Fieldname | Rename to | Length | Precision |
|-----------|-----------|--------|-----------|
| `key` | | | |
| `message` | | | |
| `topic` | `kafka_topic` | | |
| `partition` | `kafka_partition` | | |
| `offset` | `kafka_offset` | | |
| `timestamp` | | | |
| `symbol` | | | |
| `side` | | | |
| `quantity` | | | |
| `price` | | | |
| `account` | | | |
| `userid` | `user_id` | | |

> **Only one rename needed**: Unlike Scenario 1 (which renamed `userid`, `regionid`, and `registertime`), only `userid` needs renaming to `user_id` here. The other JSON field names (`symbol`, `side`, `quantity`, `price`, `account`) already match the database column names. The Kafka metadata fields (`topic`, `partition`, `offset`) are renamed as before.
>
> Leave "Rename to" blank to keep the original name. Leave Length and Precision blank in this tab.

##### Meta-data Tab

This tab sets the data type and length metadata for each field. **This is critical for MySQL** -- without explicit lengths, PDI maps String fields to `TINYTEXT`, which breaks MySQL indexes and causes errors like:
```
BLOB/TEXT column 'symbol' used in key specification without a key length
```

| Fieldname | Type | Length | Precision |
|-----------|------|--------|-----------|
| `symbol` | String | 20 | |
| `side` | String | 10 | |
| `quantity` | Integer | 9 | |
| `price` | Number | 10 | 2 |
| `account` | String | 100 | |
| `user_id` | String | 100 | |
| `kafka_topic` | String | 255 | |
| `kafka_partition` | Integer | 9 | |
| `kafka_offset` | Integer | 15 | |
| `key` | String | 100 | |
| `message` | String | 5000 | |
| `timestamp` | Integer | 15 | |

> **Why these lengths?** They match the MySQL table column definitions: `symbol VARCHAR(20)`, `side VARCHAR(10)`, `account VARCHAR(100)`, `user_id VARCHAR(100)`, `kafka_topic VARCHAR(255)`. Setting the correct lengths ensures PDI generates `VARCHAR` instead of `TINYTEXT`.
>
> **Price precision**: The `price` field is set to `Number` with Length 10 and Precision 2 to match the `DECIMAL(10,2)` column in MySQL.

---

#### Step 4d: Table Output

1. From **Design -> Output**, drag **Table output** onto the canvas
2. Draw a hop from **Select values** -> **Table output**
3. Double-click to configure:

> **No Formula step**: Unlike Scenario 1, there is no Formula step between Select values and Table output. The stock trades JSON does not contain a timestamp field that needs epoch conversion. The `trade_timestamp` column in MySQL uses `DEFAULT CURRENT_TIMESTAMP` to automatically record the insertion time.

##### Main Settings

| Setting | Value | Notes |
|---------|-------|-------|
| Connection | `warehouse_db` | The MySQL connection from Step 2 |
| Target schema | *(leave blank)* | **Important**: Do NOT set this for MySQL |
| Target table | `stock_trades` | |
| Commit size | `1000` | |
| Truncate table | No | |
| Ignore insert errors | No | |
| Use batch updates | Yes | |
| Specify database fields | Yes | **Must be Yes** to control field mapping |

> **Critical: Leave Target schema blank.** MySQL uses the database name from the connection, not a separate schema. Setting it to `kafka_warehouse` causes PDI to qualify the table as `kafka_warehouse.stock_trades` which can fail or cause unexpected behavior.

##### Database Fields

Click **Specify database fields: Yes**, then configure the field mapping:

| Database Column | Stream Field |
|-----------------|-------------|
| `symbol` | `symbol` |
| `side` | `side` |
| `quantity` | `quantity` |
| `price` | `price` |
| `account` | `account` |
| `user_id` | `user_id` |
| `kafka_topic` | `kafka_topic` |
| `kafka_partition` | `kafka_partition` |
| `kafka_offset` | `kafka_offset` |

> **Do NOT map these columns** -- MySQL handles them automatically:
> - `trade_id` -- AUTO_INCREMENT primary key
> - `trade_timestamp` -- DEFAULT CURRENT_TIMESTAMP

> **Tip**: You can use **Get Fields** button to auto-populate, then remove `trade_id` and `trade_timestamp` from the list. Since no field renaming happened for most columns (except `userid` -> `user_id`), the auto-populated mapping should be mostly correct.

##### SQL Button

When you click **SQL** in the Table output dialog, PDI may suggest ALTER TABLE statements. **Click Close without executing** -- the table already has the correct schema from the Docker init script.

If PDI suggests:
```sql
ALTER TABLE stock_trades MODIFY symbol TINYTEXT
```
This means the Meta-data tab in Select values doesn't have the string lengths set. Go back and set them (Step 4c).

---

### Step 5: Verify Hops Are Enabled

Before running, check that all hops (arrows between steps) are **solid lines**, not dashed grey. Dashed hops are disabled.

If any hop is dashed:
- Right-click the hop -> **Enable hop**
- Or hold **Shift** and click the hop

The complete flow should be:
```
Get records from stream -> JSON input -> Select values -> Table output
```

All hops must show as solid lines with arrows.

### Step 6: Run the Transformation

1. Switch to the **parent** transformation (`stocktrades-to-db-parent.ktr`)
2. Click **Run** (play button) or press **F9**
3. In the Run dialog, click **Run**
4. Monitor the **Logging** tab:
   - You should see batch processing messages
   - "Finished processing" messages with `W=N` (rows written) > 0
   - Batches will fire more frequently than Scenario 1 (every ~1 second vs every ~5 seconds)
5. Check the **Step Metrics** tab for throughput numbers

The transformation runs continuously. Click **Stop** to end it.

> **Expected throughput**: With 10 messages/sec and 1-second batch windows with 2 concurrent batches, you should see roughly 10 rows written per second. The Step Metrics tab will show cumulative counts increasing rapidly.

> **If you see "Error in sub-transformation"**: Check the Logging tab for the actual error. Common causes:
> - Disabled hops (Step 5)
> - Missing `warehouse_db` connection (Step 2)
> - Incorrect sub-transformation path (Step 3)
> - Schema field set in Table output (Step 4d)

### Step 7: Verify Data in MySQL

```bash
make mysql-shell
```

Then run these queries:

```sql
-- Check record count (should increase rapidly -- ~10 records/sec)
SELECT COUNT(*) FROM stock_trades;

-- View recent records
SELECT * FROM stock_trades
ORDER BY trade_timestamp DESC
LIMIT 10;

-- Check for duplicates (should return 0 rows)
SELECT kafka_topic, kafka_partition, kafka_offset, COUNT(*)
FROM stock_trades
GROUP BY kafka_topic, kafka_partition, kafka_offset
HAVING COUNT(*) > 1;

-- Check ingestion health (uses built-in stored procedure)
CALL sp_check_ingestion_health();

-- Monitor ingestion rate per minute (expect ~600 records/minute)
SELECT
    DATE_FORMAT(trade_timestamp, '%Y-%m-%d %H:%i:00') AS minute,
    COUNT(*) AS records_ingested
FROM stock_trades
WHERE trade_timestamp >= DATE_SUB(NOW(), INTERVAL 1 HOUR)
GROUP BY minute
ORDER BY minute DESC;

-- Check offset progress by partition
SELECT
    kafka_partition,
    MIN(kafka_offset) AS min_offset,
    MAX(kafka_offset) AS max_offset,
    COUNT(*) AS record_count
FROM stock_trades
GROUP BY kafka_partition
ORDER BY kafka_partition;

-- Trade breakdown by symbol
SELECT
    symbol,
    COUNT(*) AS trade_count,
    SUM(CASE WHEN side = 'BUY' THEN 1 ELSE 0 END) AS buys,
    SUM(CASE WHEN side = 'SELL' THEN 1 ELSE 0 END) AS sells,
    ROUND(AVG(price), 2) AS avg_price,
    SUM(quantity) AS total_volume
FROM stock_trades
GROUP BY symbol
ORDER BY trade_count DESC;

-- Recent trade value analysis (price * quantity)
SELECT
    symbol,
    side,
    quantity,
    price,
    quantity * price AS trade_value,
    trade_timestamp
FROM stock_trades
ORDER BY trade_timestamp DESC
LIMIT 20;

-- Use the built-in view for recent trades
SELECT * FROM v_recent_stock_trades
ORDER BY trade_timestamp DESC
LIMIT 10;
```

---

## Optional Exercise: Per-Symbol Aggregation with Group By

This exercise adds a **Group By** step to the child transformation to calculate aggregate metrics per stock symbol within each batch. This is useful for building summary tables, dashboards, or alerting pipelines.

### Why Group By?

In a high-frequency stream like stock trades, individual records are often less useful than aggregated views. Questions like "What is the average price of ZVZZT in the last minute?" or "What is the total trading volume by symbol?" require aggregation. The Group By step performs this aggregation within each batch before writing to the database.

### Add Group By to the Child Transformation

1. Open the child transformation (`stocktrades-to-db-child.ktr`)
2. From **Design -> Statistics**, drag **Group by** onto the canvas
3. **Rearrange the hops**: The Group By step goes between **Select values** and **Table output**:
   - Delete the hop from Select values -> Table output (right-click the hop -> Delete)
   - Draw a hop from **Select values** -> **Group by**
   - Draw a hop from **Group by** -> **Table output**

#### Group By Configuration

Double-click the Group by step:

**Group field** (the field to group by):

| Fieldname |
|-----------|
| `symbol` |

**Aggregates**:

| Name | Subject | Type |
|------|---------|------|
| `avg_price` | `price` | Average |
| `total_quantity` | `quantity` | Sum |
| `trade_count` | `symbol` | Count of rows |
| `min_price` | `price` | Minimum |
| `max_price` | `price` | Maximum |

> **Important**: Check the box **Include all rows?** = No. When unchecked, the Group By step outputs one row per unique `symbol` value in the batch. This is what we want for a summary table.

#### Update Table Output for Aggregated Data

If you are writing aggregated data, you should target the `stock_trades_summary` table instead of `stock_trades`. Update the Table output step:

| Setting | Value |
|---------|-------|
| Target table | `stock_trades_summary` |

**Database Fields** for `stock_trades_summary`:

| Database Column | Stream Field |
|-----------------|-------------|
| `symbol` | `symbol` |
| `trade_count` | `trade_count` |
| `total_volume` | `total_quantity` |
| `avg_price` | `avg_price` |
| `min_price` | `min_price` |
| `max_price` | `max_price` |

> **Note**: The `minute_timestamp` and `summary_id` columns are not mapped -- `summary_id` is AUTO_INCREMENT and `minute_timestamp` can be set using a **Get system info** step (Current date -> `minute_timestamp`) if needed, or left NULL for batch-level aggregation.

#### Alternative: Keep Both Outputs

Instead of replacing the Table output, you can keep both:
1. After **Select values**, add a **Copy rows to result** step or use a **Dummy** step to split the flow
2. One branch goes to the original **Table output** (writing individual trades to `stock_trades`)
3. The other branch goes through **Group by** -> second **Table output** (writing summaries to `stock_trades_summary`)

This approach stores both raw trades and aggregated summaries simultaneously.

#### Verify Aggregated Data

```sql
-- Check the summary table
SELECT * FROM stock_trades_summary
ORDER BY created_at DESC
LIMIT 20;

-- Compare raw vs aggregated counts
SELECT
    (SELECT COUNT(*) FROM stock_trades) AS raw_trades,
    (SELECT SUM(trade_count) FROM stock_trades_summary) AS aggregated_count;
```

---

## Debugging

### Debug Child Transformation (JSON Output)

To debug the child transformation without writing to the database, temporarily replace the Table output step with a text file output:

1. Open the **child** transformation (`stocktrades-to-db-child.ktr`)
2. Disable the hop to **Table output** (right-click the hop -> **Disable hop**)
3. From **Design -> Output**, drag **Text file output** onto the canvas
4. Draw a hop from **Select values** -> **Text file output**
5. Configure the Text file output:
   - **Filename**: `[path]/transformations/debug-output-stocktrades`
   - **Extension**: `json` (or `csv`)
   - On the **Content** tab, set the separator and format as desired
   - On the **Fields** tab, click **Get Fields** to auto-populate
6. Run the parent transformation
7. Check the output file: `transformations/debug-output-stocktrades.json`

> Remember to re-enable the Table output hop and disable/remove the debug step when done.

### Inspect Stream Data with Preview

1. In the **child** transformation, right-click any step -> **Preview**
2. Run the **parent** transformation
3. The Preview dialog shows the data flowing through that step in real time
4. This is useful for verifying JSON parsing, field renames, and type conversions

### Common Errors and Fixes

#### "Error in sub-transformation"

This generic error wraps the actual child transformation failure. Check the Logging tab for the real cause:

| Root Cause | How to Identify | Fix |
|-----------|----------------|-----|
| Disabled hops | Steps show 0 rows written | Right-click hop -> Enable hop |
| Missing connection | "Unknown database connection" | Create `warehouse_db` in parent transformation |
| Wrong sub-transformation path | "Unable to load transformation" | Use Browse button to set correct path |
| Schema field set | `kafka_warehouse.stock_trades` in error | Clear Target schema in Table output |

#### "BLOB/TEXT column used in key specification without a key length"

PDI is trying to ALTER the table with `TINYTEXT` columns. This happens when string fields don't have lengths set.

**Fix**: Set field lengths in the Select values **Meta-data** tab (see [Step 4c](#step-4c-select-values)).

**Workaround**: When PDI shows the SQL editor dialog, click **Close** without executing.

#### "Table not found" or wrong table qualification

If the error references `kafka_warehouse.stock_trades` instead of just `stock_trades`:

**Fix**: Clear the **Target schema** field in Table output (leave it blank).

#### No data written (W=0)

1. Check consumer is receiving messages: `I=N` should be > 0
2. Check JSON Input is parsing: Step Metrics should show rows flowing through
3. Check Table output connection is valid: test `warehouse_db` connection
4. Check all hops are enabled (solid lines, not dashed)

#### Duplicate records

The `stock_trades` table has a `UNIQUE KEY` on `(kafka_topic, kafka_partition, kafka_offset)`. If you see duplicate key errors:

1. Table output with "Ignore insert errors: No" will fail on duplicates -- set to Yes, or
2. Use **Insert/Update** step instead (recommended for idempotency):
   - Keys: `kafka_topic`, `kafka_partition`, `kafka_offset`
   - Don't perform any updates: Yes

#### Batches backing up / slow writes

With 10 messages/sec and 2 concurrent batches, slow database writes can cause batch backlog. Signs include:
- Increasing memory usage
- Step Metrics showing input rows much higher than output rows
- "Buffer full" warnings in logs

**Fixes**:
1. Increase `Commit size` in Table output (try 5000)
2. Verify MySQL connection options include `rewriteBatchedStatements=true`
3. Reduce `Number of records` per batch (try 25)
4. Check MySQL performance: `SHOW PROCESSLIST;` in MySQL shell

---

## Comparison: Scenario 1 vs Scenario 2

| Aspect | Scenario 1 (Users) | Scenario 2 (Stock Trades) |
|--------|-------------------|--------------------------|
| Topic | `pdi-users` | `pdi-stocktrades` |
| Message rate | ~1/sec | ~10/sec |
| Batch duration | 5000ms | 1000ms |
| Record count | 100 | 50 |
| Concurrent batches | 1 | 2 |
| Consumer group | `pdi-warehouse-users` | `pdi-stocktrades-consumer` |
| Target table | `user_events` | `stock_trades` |
| Epoch conversion | Yes (Formula step) | No (DB default timestamp) |
| JSON fields | 4 | 6 |
| Renames needed | userid, regionid, registertime | userid only |
| Pipeline steps | 5 (Get -> JSON -> Select -> Formula -> Table) | 4 (Get -> JSON -> Select -> Table) |

---

## Database Table Reference

The `stock_trades` table (created by `sql/01-create-database-mysql-docker.sql`):

```sql
CREATE TABLE stock_trades (
    trade_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    symbol VARCHAR(20) NOT NULL,
    side VARCHAR(10),
    quantity INT,
    price DECIMAL(10,2),
    account VARCHAR(100),
    user_id VARCHAR(100),
    trade_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    kafka_topic VARCHAR(255),
    kafka_partition INT,
    kafka_offset BIGINT,
    INDEX idx_symbol (symbol),
    INDEX idx_trade_timestamp (trade_timestamp),
    UNIQUE KEY uq_kafka_offset (kafka_topic, kafka_partition, kafka_offset)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

The optional `stock_trades_summary` table (for the Group By exercise):

```sql
CREATE TABLE stock_trades_summary (
    summary_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    minute_timestamp TIMESTAMP,
    symbol VARCHAR(20),
    trade_count INT DEFAULT 0,
    total_volume BIGINT DEFAULT 0,
    avg_price DECIMAL(10,2),
    min_price DECIMAL(10,2),
    max_price DECIMAL(10,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_minute_timestamp (minute_timestamp),
    INDEX idx_symbol (symbol),
    UNIQUE KEY uq_symbol_minute (minute_timestamp, symbol)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

---

## Summary

After completing this scenario, you have:

- A parent transformation reading from `pdi-stocktrades` topic with tuned batch settings for high-frequency data
- A child transformation that parses JSON, renames fields, sets metadata types, and writes to MySQL
- Batch settings optimized for 10 messages/sec throughput (1-second duration, 50 records, 2 concurrent batches)
- No epoch conversion needed -- the database handles timestamping automatically
- Idempotent processing via the UNIQUE KEY on Kafka coordinates
- (Optional) Per-symbol aggregation using Group By step writing to `stock_trades_summary`
- Continuous streaming data flowing from Kafka to your data warehouse

**Previous**: [Scenario 1: Basic Kafka Consumer - Real-time User Activity Stream](scenario-1-user-activity.md)

**Next**: [Scenario 3: E-Commerce Purchases - Avro Format](scenario-3-purchases.md)

---

**Related Documentation**:
- [Transformations README](../../transformations/README.md) -- Template configuration details
- [Workshop Guide -- PDI Kafka Consumer Configuration](../WORKSHOP-GUIDE.md#pdi-kafka-consumer-configuration) -- All 6 configuration tabs
- [Workshop Guide -- Kafka to Data Warehouse](../WORKSHOP-GUIDE.md#kafka-to-data-warehouse) -- Architecture patterns
- [Scenario 1: User Activity](scenario-1-user-activity.md) -- Beginner scenario with epoch conversion
