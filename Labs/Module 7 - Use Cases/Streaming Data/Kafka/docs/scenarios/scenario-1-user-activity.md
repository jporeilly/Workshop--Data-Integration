# Scenario 1: Basic Kafka Consumer - Real-time User Activity Stream

**Business Use Case**: Process user registration and activity events in real-time, loading them into a MySQL data warehouse.

**Difficulty**: Beginner | **Duration**: 30-45 minutes

## Learning Objectives

- Configure a Kafka Consumer step with parent/child transformation pattern
- Parse streaming JSON data using JSON Input step
- Rename and type fields using Select values (including Meta-data tab)
- Convert epoch timestamps using Formula step
- Write to MySQL using Table output with correct field mapping
- Verify data integrity in the database

## Prerequisites

Before starting this scenario:

1. Workshop environment is running — `make workshop-start`
2. MySQL is running with tables created — `make mysql-verify`
3. Data is flowing into `pdi-users` topic — `make consume-users`
4. PDI (Spoon) is open with Kafka EE plugin installed
5. `warehouse_db` database connection is configured in Spoon (see [Step 2 below](#step-2-create-database-connection-in-spoon))

## Architecture

```
Parent Transformation (Kafka Consumer Step)
    | (batches of records every 5 seconds or 100 records)
    v
Child Transformation
    Get records from stream
        |
    JSON Input (parse message field)
        |
    Select values (rename + set metadata/types)
        |
    Formula (epoch ms / 1000)
        |
    Table output (write to user_events)
```

## Data Source

The `pdi-users` topic receives user registration events at ~1 message/second from the datagen connector.

**Sample message**:
```json
{"registertime":1493899960000,"userid":"User_1","regionid":"Region_9","gender":"MALE"}
```

**Field descriptions**:

| JSON Field | Type | Description |
|-----------|------|-------------|
| `registertime` | Long | Registration timestamp (epoch milliseconds) |
| `userid` | String | User identifier (e.g., `User_1`) |
| `regionid` | String | Region identifier (e.g., `Region_9`) |
| `gender` | String | Gender (`MALE` or `FEMALE`) |

---

## Step-by-Step Instructions

### Step 1: Verify Data is Flowing

```bash
make consume-users
```

You should see JSON messages. If not, deploy connectors first: `make deploy-connectors`

### Step 2: Create Database Connection in Spoon

1. Open Spoon (PDI)
2. Go to **View** panel (left side) → right-click **Database connections** → **New**
3. Configure:

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

4. Click the **Options** tab and add these parameters for better write performance:

| Parameter | Value |
|-----------|-------|
| `useServerPrepStmts` | `false` |
| `rewriteBatchedStatements` | `true` |
| `cachePrepStmts` | `true` |
| `prepStmtCacheSize` | `250` |
| `useCompression` | `true` |

5. Click **Test** — should show "Connection successful"
6. Click **OK** to save

### Step 3: Create Parent Transformation

1. **File → New → Transformation**
2. Save as `users-to-db-parent.ktr` in the `transformations/` directory

Or open the existing template: `transformations/users-to-db-parent.ktr`

#### Add Kafka Consumer Step

1. From the **Design** panel, expand **Input** → drag **Kafka Consumer** onto the canvas
2. Double-click the Kafka Consumer step to configure:

#### Setup Tab

| Setting | Value | Notes |
|---------|-------|-------|
| Connection | Direct | |
| Bootstrap Servers | `localhost:9092` | External Kafka broker address |
| Topics | `pdi-users` | |
| Consumer Group | `pdi-warehouse-users` | Unique name for this transformation |
| Sub-transformation | `[path]/transformations/users-to-db-child.ktr` | Use Browse button to select |

> **Tip**: Use the **Browse** button for the sub-transformation path. An incorrect path is a common source of "Error in sub-transformation" errors.

#### Batch Tab

| Setting | Value | Notes |
|---------|-------|-------|
| Duration (ms) | `5000` | Collect records for 5 seconds |
| Number of records | `100` | Or until 100 records arrive |
| Maximum concurrent batches | `1` | Start with 1 |
| Message prefetch limit | `100000` | Default is fine |
| Offset commit | When batch completes | At-least-once delivery (recommended) |

> **How batching works**: Whichever threshold is reached first (duration or record count) triggers the batch to be sent to the child transformation. With `pdi-users` producing ~1 msg/sec, the 5-second duration will usually trigger first, sending ~5 records per batch.

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

1. **File → New → Transformation**
2. Save as `users-to-db-child.ktr` in the `transformations/` directory

Or open the existing template: `transformations/users-to-db-child.ktr`

---

#### Step 4a: Get Records from Stream

1. From **Design → Input**, drag **Get records from stream** onto the canvas
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

1. From **Design → Input**, drag **JSON Input** onto the canvas
2. Draw a hop from **Get records from stream** → **JSON Input**
3. Double-click JSON Input to configure:

**Source tab** (main settings):

| Setting | Value |
|---------|-------|
| Source is a field | Checked |
| Get source from field | `message` |
| Ignore missing path | Yes |
| Default path leaf to null | Yes |

**Fields tab** — click **+** to add each field:

| Name | Path | Type | Format | Length | Precision | Trim |
|------|------|------|--------|--------|-----------|------|
| `userid` | `$.userid` | String | | -1 | -1 | none |
| `regionid` | `$.regionid` | String | | -1 | -1 | none |
| `gender` | `$.gender` | String | | -1 | -1 | none |
| `registertime` | `$.registertime` | Integer | | -1 | -1 | none |

> **Note on JSON paths**: The `$.fieldname` syntax is standard JSONPath. Since the datagen produces flat JSON, the path is simply `$.` followed by the field name. For nested JSON (e.g., `{"data":{"userid":"..."}}`), you would use `$.data.userid`.
>
> **Empty paths**: If you leave the Path column blank, PDI defaults to matching by field name (equivalent to `$.fieldname`). This works for flat JSON but explicit paths are recommended.

---

#### Step 4c: Select Values

1. From **Design → Transform**, drag **Select values** onto the canvas
2. Draw a hop from **JSON Input** → **Select values**
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
| `userid` | `user_id` | | |
| `regionid` | `region_id` | | |
| `gender` | | | |
| `registertime` | `register_time_epoch` | | |

> Leave "Rename to" blank to keep the original name. Leave Length and Precision blank in this tab.

##### Meta-data Tab

This tab sets the data type and length metadata for each field. **This is critical for MySQL** — without explicit lengths, PDI maps String fields to `TINYTEXT`, which breaks MySQL indexes and causes errors like:
```
BLOB/TEXT column 'user_id' used in key specification without a key length
```

| Fieldname | Type | Length | Precision |
|-----------|------|--------|-----------|
| `user_id` | String | 100 | |
| `region_id` | String | 100 | |
| `gender` | String | 20 | |
| `register_time_epoch` | Integer | 15 | |
| `kafka_topic` | String | 255 | |
| `kafka_partition` | Integer | 9 | |
| `kafka_offset` | Integer | 15 | |
| `key` | String | 100 | |
| `message` | String | 5000 | |
| `timestamp` | Integer | 15 | |

> **Why these lengths?** They match the MySQL table column definitions: `user_id VARCHAR(100)`, `region_id VARCHAR(100)`, `gender VARCHAR(20)`, `kafka_topic VARCHAR(255)`. Setting the correct lengths ensures PDI generates `VARCHAR` instead of `TINYTEXT`.

---

#### Step 4d: Formula

1. From **Design → Transform**, drag **Formula** onto the canvas
2. Draw a hop from **Select values** → **Formula**
3. Double-click to configure:

| New field | Formula | Value type | Length | Precision | Replace |
|-----------|---------|------------|--------|-----------|---------|
| `register_time_seconds` | `[register_time_epoch] / 1000` | Integer | -1 | -1 | *(blank)* |

> **Why Formula instead of Calculator?** The Calculator step requires both operands to be existing stream fields — you cannot enter a literal constant like `1000` as Field B. The Formula step supports inline constants in expressions.
>
> **What this does**: The datagen produces `registertime` as epoch milliseconds (e.g., `1493899960000`). MySQL's `TIMESTAMP` column expects epoch seconds, so we divide by 1000 to get `1493899960`.
>
> **Alternative using Calculator**: Add an **Add constants** step before Calculator with a field `divisor` = `1000` (Integer). Then use Calculator with operation `A / B` where A = `register_time_epoch` and B = `divisor`.

---

#### Step 4e: Table Output

1. From **Design → Output**, drag **Table output** onto the canvas
2. Draw a hop from **Formula** → **Table output**
3. Double-click to configure:

##### Main Settings

| Setting | Value | Notes |
|---------|-------|-------|
| Connection | `warehouse_db` | The MySQL connection from Step 2 |
| Target schema | *(leave blank)* | **Important**: Do NOT set this for MySQL |
| Target table | `user_events` | |
| Commit size | `1000` | |
| Truncate table | No | |
| Ignore insert errors | No | |
| Use batch updates | Yes | |
| Specify database fields | Yes | **Must be Yes** to control field mapping |

> **Critical: Leave Target schema blank.** MySQL uses the database name from the connection, not a separate schema. Setting it to `kafka_warehouse` causes PDI to qualify the table as `kafka_warehouse.user_events` which can fail or cause unexpected behavior.

##### Database Fields

Click **Specify database fields: Yes**, then configure the field mapping:

| Database Column | Stream Field |
|-----------------|-------------|
| `user_id` | `user_id` |
| `region_id` | `region_id` |
| `gender` | `gender` |
| `register_time` | `register_time_seconds` |
| `kafka_topic` | `kafka_topic` |
| `kafka_partition` | `kafka_partition` |
| `kafka_offset` | `kafka_offset` |

> **Do NOT map these columns** — MySQL handles them automatically:
> - `event_id` — AUTO_INCREMENT primary key
> - `ingestion_timestamp` — DEFAULT CURRENT_TIMESTAMP

> **Tip**: You can use **Get Fields** button to auto-populate, then remove `event_id` and `ingestion_timestamp`, and fix the `register_time` mapping (stream field should be `register_time_seconds`, not `register_time`).

##### SQL Button

When you click **SQL** in the Table output dialog, PDI may suggest ALTER TABLE statements. **Click Close without executing** — the table already has the correct schema from the Docker init script.

If PDI suggests:
```sql
ALTER TABLE user_events MODIFY user_id TINYTEXT
```
This means the Meta-data tab in Select values doesn't have the string lengths set. Go back and set them (Step 4c).

---

### Step 5: Verify Hops Are Enabled

Before running, check that all hops (arrows between steps) are **solid lines**, not dashed grey. Dashed hops are disabled.

If any hop is dashed:
- Right-click the hop → **Enable hop**
- Or hold **Shift** and click the hop

The complete flow should be:
```
Get records from stream → JSON input → Select values → Formula → Table output
```

All hops must show as solid lines with arrows.

### Step 6: Run the Transformation

1. Switch to the **parent** transformation (`users-to-db-parent.ktr`)
2. Click **Run** (play button) or press **F9**
3. In the Run dialog, click **Run**
4. Monitor the **Logging** tab:
   - You should see batch processing messages
   - "Finished processing" messages with `W=N` (rows written) > 0
5. Check the **Step Metrics** tab for throughput numbers

The transformation runs continuously. Click **Stop** to end it.

> **If you see "Error in sub-transformation"**: Check the Logging tab for the actual error. Common causes:
> - Disabled hops (Step 5)
> - Missing `warehouse_db` connection (Step 2)
> - Incorrect sub-transformation path (Step 3)
> - Schema field set in Table output (Step 4e)

### Step 7: Verify Data in MySQL

```bash
make mysql-shell
```

Then run these queries:

```sql
-- Check record count (should increase over time)
SELECT COUNT(*) FROM user_events;

-- View recent records
SELECT * FROM user_events
ORDER BY ingestion_timestamp DESC
LIMIT 10;

-- Check for duplicates (should return 0 rows)
SELECT kafka_topic, kafka_partition, kafka_offset, COUNT(*)
FROM user_events
GROUP BY kafka_topic, kafka_partition, kafka_offset
HAVING COUNT(*) > 1;

-- Check ingestion health (uses built-in stored procedure)
CALL sp_check_ingestion_health();

-- Monitor ingestion rate per minute
SELECT
    DATE_FORMAT(ingestion_timestamp, '%Y-%m-%d %H:%i:00') AS minute,
    COUNT(*) AS records_ingested
FROM user_events
WHERE ingestion_timestamp >= DATE_SUB(NOW(), INTERVAL 1 HOUR)
GROUP BY minute
ORDER BY minute DESC;

-- Check offset progress by partition
SELECT
    kafka_partition,
    MIN(kafka_offset) AS min_offset,
    MAX(kafka_offset) AS max_offset,
    COUNT(*) AS record_count
FROM user_events
GROUP BY kafka_partition
ORDER BY kafka_partition;

-- Check ingestion lag
SELECT
    AVG(TIMESTAMPDIFF(SECOND, register_time, ingestion_timestamp)) AS avg_lag_seconds,
    MAX(TIMESTAMPDIFF(SECOND, register_time, ingestion_timestamp)) AS max_lag_seconds
FROM user_events
WHERE ingestion_timestamp >= DATE_SUB(NOW(), INTERVAL 1 HOUR);
```

---

## Debugging

### Debug Child Transformation (JSON Output)

A debug version of the child transformation is available at `transformations/users-to-db-child-debug.ktr`. It writes to a JSON file instead of the database, so you can inspect the processed data.

To use it:

1. Open the **parent** transformation
2. Double-click the Kafka Consumer step
3. Change the **Sub-transformation** path to `users-to-db-child-debug.ktr`
4. Run the parent transformation
5. Check the output file: `transformations/debug-output-users.json`

The debug file includes all fields: `user_id`, `region_id`, `gender`, `register_time_epoch`, `register_time_seconds`, `kafka_topic`, `kafka_partition`, `kafka_offset`, `key`, and the raw `message`.

> Remember to switch back to `users-to-db-child.ktr` when done debugging.

### Common Errors and Fixes

#### "Error in sub-transformation"

This generic error wraps the actual child transformation failure. Check the Logging tab for the real cause:

| Root Cause | How to Identify | Fix |
|-----------|----------------|-----|
| Disabled hops | Steps show 0 rows written | Right-click hop → Enable hop |
| Missing connection | "Unknown database connection" | Create `warehouse_db` in parent transformation |
| Wrong sub-transformation path | "Unable to load transformation" | Use Browse button to set correct path |
| Schema field set | `kafka_warehouse.user_events` in error | Clear Target schema in Table output |

#### "BLOB/TEXT column used in key specification without a key length"

PDI is trying to ALTER the table with `TINYTEXT` columns. This happens when string fields don't have lengths set.

**Fix**: Set field lengths in the Select values **Meta-data** tab (see [Step 4c](#step-4c-select-values)).

**Workaround**: When PDI shows the SQL editor dialog, click **Close** without executing.

#### "Table not found" or wrong table qualification

If the error references `kafka_warehouse.user_events` instead of just `user_events`:

**Fix**: Clear the **Target schema** field in Table output (leave it blank).

#### No data written (W=0)

1. Check consumer is receiving messages: `I=N` should be > 0
2. Check JSON Input is parsing: Step Metrics should show rows flowing through
3. Check Table output connection is valid: test `warehouse_db` connection
4. Check all hops are enabled (solid lines, not dashed)

#### Duplicate records

The `user_events` table has a `UNIQUE KEY` on `(kafka_topic, kafka_partition, kafka_offset)`. If you see duplicate key errors:

1. Table output with "Ignore insert errors: No" will fail on duplicates — set to Yes, or
2. Use **Insert/Update** step instead (recommended for idempotency):
   - Keys: `kafka_topic`, `kafka_partition`, `kafka_offset`
   - Don't perform any updates: Yes

---

## Database Table Reference

The `user_events` table (created by `sql/01-create-database-mysql-docker.sql`):

```sql
CREATE TABLE user_events (
    event_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id VARCHAR(100) NOT NULL,
    region_id VARCHAR(100),
    gender VARCHAR(20),
    register_time TIMESTAMP NULL,
    kafka_topic VARCHAR(255),
    kafka_partition INT,
    kafka_offset BIGINT,
    ingestion_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_user_id (user_id),
    INDEX idx_register_time (register_time),
    UNIQUE KEY uq_kafka_offset (kafka_topic, kafka_partition, kafka_offset)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

---

## Summary

After completing this scenario, you have:

- A parent transformation reading from `pdi-users` topic
- A child transformation that parses JSON, renames fields, converts timestamps, and writes to MySQL
- Idempotent processing via the UNIQUE KEY on Kafka coordinates
- Continuous streaming data flowing from Kafka to your data warehouse

**Next**: Try [Scenario 2: High-Frequency Stock Trades](scenario-2-stock-trades.md) to work with higher-volume data and aggregation.

---

**Related Documentation**:
- [Transformations README](../../transformations/README.md) — Template configuration details
- [Workshop Guide — PDI Kafka Consumer Configuration](../WORKSHOP-GUIDE.md#pdi-kafka-consumer-configuration) — All 6 configuration tabs
- [Workshop Guide — Kafka to Data Warehouse](../WORKSHOP-GUIDE.md#kafka-to-data-warehouse) — Architecture patterns
