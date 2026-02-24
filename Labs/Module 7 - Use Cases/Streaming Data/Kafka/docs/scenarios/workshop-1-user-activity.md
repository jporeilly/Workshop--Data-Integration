# Workshop 1: Real-time User Activity Stream

| | |
|---|---|
| **Scenario** | Basic Kafka Consumer — Real-time User Activity Stream |
| **Difficulty** | Beginner |
| **Duration** | 30–45 minutes |
| **Topics** | `pdi-users` |
| **Target Table** | `user_events` |
| **PDI Steps** | Kafka Consumer, Get records from stream, JSON Input, Select values, Formula, Table output |

---

## Business Context

Your company tracks user registrations across web and mobile platforms. User registration events are published to a Kafka topic in real-time. Your task is to build a streaming pipeline that continuously reads these events, parses the JSON payload, transforms timestamps, and loads the data into a MySQL data warehouse — enabling real-time dashboards and analytics.

This is the foundational pattern for all Kafka-to-database streaming pipelines in PDI.

---

## Learning Objectives

By the end of this workshop, you will be able to:

1. Configure a Kafka Consumer step with the parent/child transformation pattern
2. Parse streaming JSON data using the JSON Input step
3. Rename and type fields using Select values (including the Meta-data tab)
4. Convert epoch millisecond timestamps to seconds using the Formula step
5. Write to MySQL using Table output with explicit field mapping
6. Verify data integrity and monitor ingestion in the database

---

## Prerequisites

Before starting, ensure the following are running:

| Requirement | Verification Command | Expected Result |
|---|---|---|
| Kafka cluster | `make verify` | All services green |
| MySQL database | `make mysql-verify` | Tables listed including `user_events` |
| Data flowing into `pdi-users` | `make consume-users` | JSON messages visible |
| PDI (Spoon) 9.4+ | Launch Spoon | Application opens |

If any prerequisite is not met:
```bash
# Start everything from scratch
make workshop-start

# Deploy data generators if topics are empty
make deploy-connectors
```

---

## Architecture Overview

This workshop uses PDI's **parent/child transformation pattern** for Kafka streaming:

```
┌──────────────────────────────────────────────┐
│  PARENT TRANSFORMATION (users-to-db-parent)  │
│                                              │
│  ┌────────────────────────┐                  │
│  │    Kafka Consumer      │                  │
│  │    Topic: pdi-users    │                  │
│  │    Batch: 5s / 100 rec │──── batches ───► │
│  └────────────────────────┘                  │
└──────────────────────────────────────────────┘
                    │
                    ▼
┌──────────────────────────────────────────────┐
│  CHILD TRANSFORMATION (users-to-db-child)    │
│                                              │
│  Get records from stream                     │
│       │                                      │
│  JSON Input (parse $.userid, $.regionid,     │
│              $.gender, $.registertime)        │
│       │                                      │
│  Select values (rename + set metadata)       │
│       │                                      │
│  Formula (epoch ms ÷ 1000 → seconds)        │
│       │                                      │
│  Table output (→ user_events)                │
└──────────────────────────────────────────────┘
```

**How it works**: The parent transformation's Kafka Consumer step reads messages in batches (every 5 seconds or 100 records, whichever comes first) and passes each batch to the child transformation for processing. The child transformation parses, transforms, and writes each batch to MySQL.

---

## Data Source

**Topic**: `pdi-users` — ~1 message/second from the datagen connector

**Sample message**:
```json
{"registertime":1493899960000,"userid":"User_1","regionid":"Region_9","gender":"MALE"}
```

| JSON Field | Type | Description |
|---|---|---|
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

You should see JSON messages appearing. Press `Ctrl+C` to stop. If no messages appear:
```bash
make deploy-connectors
```

---

### Step 2: Create Database Connection in Spoon

1. Open Spoon (PDI)
2. Go to **View** panel (left side) → right-click **Database connections** → **New**
3. Configure:

| Setting | Value |
|---|---|
| Connection Name | `warehouse_db` |
| Connection Type | MySQL |
| Access | Native (JDBC) |
| Host Name | `localhost` |
| Database Name | `kafka_warehouse` |
| Port Number | `3306` |
| User Name | `kafka_user` |
| Password | `kafka_password` |

4. Click the **Options** tab and add these parameters:

| Parameter | Value |
|---|---|
| `useServerPrepStmts` | `false` |
| `rewriteBatchedStatements` | `true` |
| `cachePrepStmts` | `true` |
| `prepStmtCacheSize` | `250` |
| `useCompression` | `true` |

5. Click **Test** — should show "Connection successful"
6. Click **OK** to save

---

### Step 3: Create Parent Transformation

1. **File → New → Transformation**
2. Save as `users-to-db-parent.ktr` in the `transformations/` directory

> Or open the existing template: `transformations/users-to-db-parent.ktr`

#### Add Kafka Consumer Step

1. From the **Design** panel, expand **Input** → drag **Kafka Consumer** onto the canvas
2. Double-click the Kafka Consumer step to configure:

#### Setup Tab

| Setting | Value | Notes |
|---|---|---|
| Connection | Direct | |
| Bootstrap Servers | `localhost:9092` | External Kafka broker address |
| Topics | `pdi-users` | |
| Consumer Group | `pdi-warehouse-users` | Unique name for this transformation |
| Sub-transformation | `[path]/transformations/users-to-db-child.ktr` | Use **Browse** button |

> **Tip**: Always use the **Browse** button for the sub-transformation path. Incorrect paths cause "Error in sub-transformation" errors.

#### Batch Tab

| Setting | Value | Notes |
|---|---|---|
| Duration (ms) | `5000` | Collect records for 5 seconds |
| Number of records | `100` | Or until 100 records arrive |
| Maximum concurrent batches | `1` | Start with 1 |
| Message prefetch limit | `100000` | Default is fine |
| Offset commit | When batch completes | At-least-once delivery |

> **How batching works**: Whichever threshold is reached first (duration or record count) triggers the batch. With ~1 msg/sec, the 5-second duration triggers first, sending ~5 records per batch.

#### Fields Tab

Click **Get Fields** or manually add:

| Name | Type |
|---|---|
| `key` | String |
| `message` | String |
| `topic` | String |
| `partition` | Integer |
| `offset` | Integer |
| `timestamp` | Integer |

#### Options Tab

Click **+** to add each property:

| Property | Value | Notes |
|---|---|---|
| `auto.offset.reset` | `earliest` | Read from beginning on first run |
| `enable.auto.commit` | `false` | Let PDI manage offsets |

3. Click **OK** to save
4. Save the transformation (**Ctrl+S**)

---

### Step 4: Create Child Transformation

1. **File → New → Transformation**
2. Save as `users-to-db-child.ktr` in the `transformations/` directory

> Or open the existing template: `transformations/users-to-db-child.ktr`

---

#### Step 4a: Get Records from Stream

1. From **Design → Input**, drag **Get records from stream** onto the canvas
2. Double-click to configure:

| Name | Type | Length | Precision |
|---|---|---|---|
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
3. Double-click to configure:

**Source tab**:

| Setting | Value |
|---|---|
| Source is a field | Checked |
| Get source from field | `message` |
| Ignore missing path | Yes |
| Default path leaf to null | Yes |

**Fields tab** — click **+** to add each field:

| Name | Path | Type | Format | Length | Precision | Trim |
|---|---|---|---|---|---|---|
| `userid` | `$.userid` | String | | -1 | -1 | none |
| `regionid` | `$.regionid` | String | | -1 | -1 | none |
| `gender` | `$.gender` | String | | -1 | -1 | none |
| `registertime` | `$.registertime` | Integer | | -1 | -1 | none |

> The `$.fieldname` syntax is standard JSONPath. For flat JSON, the path is `$.` followed by the field name.

---

#### Step 4c: Select Values

1. From **Design → Transform**, drag **Select values** onto the canvas
2. Draw a hop from **JSON Input** → **Select values**
3. Double-click to configure:

##### Select & Alter Tab

| Fieldname | Rename to |
|---|---|
| `key` | |
| `message` | |
| `topic` | `kafka_topic` |
| `partition` | `kafka_partition` |
| `offset` | `kafka_offset` |
| `timestamp` | |
| `userid` | `user_id` |
| `regionid` | `region_id` |
| `gender` | |
| `registertime` | `register_time_epoch` |

> Leave "Rename to" blank to keep the original name.

##### Meta-data Tab

**This is critical for MySQL.** Without explicit lengths, PDI maps String fields to `TINYTEXT`, which breaks MySQL indexes:
```
BLOB/TEXT column 'user_id' used in key specification without a key length
```

| Fieldname | Type | Length | Precision |
|---|---|---|---|
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

> These lengths match the MySQL column definitions: `user_id VARCHAR(100)`, `region_id VARCHAR(100)`, etc.

---

#### Step 4d: Formula

1. From **Design → Transform**, drag **Formula** onto the canvas
2. Draw a hop from **Select values** → **Formula**
3. Double-click to configure:

| New field | Formula | Value type | Length | Precision | Replace |
|---|---|---|---|---|---|
| `register_time_seconds` | `[register_time_epoch] / 1000` | Integer | -1 | -1 | *(blank)* |

> **Why Formula instead of Calculator?** Calculator requires both operands to be existing stream fields — you cannot enter a literal `1000` as Field B. Formula supports inline constants.
>
> **What this does**: The datagen produces epoch **milliseconds** (e.g., `1493899960000`). MySQL `TIMESTAMP` expects epoch **seconds**, so we divide by 1000.

---

#### Step 4e: Table Output

1. From **Design → Output**, drag **Table output** onto the canvas
2. Draw a hop from **Formula** → **Table output**
3. Double-click to configure:

##### Main Settings

| Setting | Value | Notes |
|---|---|---|
| Connection | `warehouse_db` | From Step 2 |
| Target schema | *(leave blank)* | **Do NOT set this for MySQL** |
| Target table | `user_events` | |
| Commit size | `1000` | |
| Truncate table | No | |
| Ignore insert errors | No | |
| Use batch updates | Yes | |
| Specify database fields | Yes | **Must be Yes** |

> **Critical**: Leave Target schema blank. MySQL uses the database name from the connection. Setting it causes errors.

##### Database Fields

| Database Column | Stream Field |
|---|---|
| `user_id` | `user_id` |
| `region_id` | `region_id` |
| `gender` | `gender` |
| `register_time` | `register_time_seconds` |
| `kafka_topic` | `kafka_topic` |
| `kafka_partition` | `kafka_partition` |
| `kafka_offset` | `kafka_offset` |

> **Do NOT map**: `event_id` (AUTO_INCREMENT) or `ingestion_timestamp` (DEFAULT CURRENT_TIMESTAMP).

> When PDI shows the SQL editor after clicking **SQL**, click **Close** without executing — the table already exists.

---

### Step 5: Verify Hops

Check that all hops are **solid lines** (not dashed grey). If any hop is dashed:
- Right-click the hop → **Enable hop**, or
- Hold **Shift** and click the hop

Complete flow:
```
Get records from stream → JSON Input → Select values → Formula → Table output
```

---

### Step 6: Run the Transformation

1. Switch to the **parent** transformation (`users-to-db-parent.ktr`)
2. Click **Run** (▶) or press **F9**
3. Click **Run** in the dialog
4. Monitor the **Logging** tab — look for `W=N` (rows written) > 0
5. Check **Step Metrics** for throughput

The transformation runs continuously. Click **Stop** to end it.

> **If you see "Error in sub-transformation"**: Check the Logging tab for the real error. Common causes:
> - Disabled hops
> - Missing `warehouse_db` connection
> - Incorrect sub-transformation path
> - Schema field set in Table output

---

### Step 7: Verify Data in MySQL

```bash
make mysql-shell
```

```sql
-- Check record count (should increase over time)
SELECT COUNT(*) FROM user_events;

-- View recent records
SELECT * FROM user_events ORDER BY ingestion_timestamp DESC LIMIT 10;

-- Check for duplicates (should return 0 rows)
SELECT kafka_topic, kafka_partition, kafka_offset, COUNT(*)
FROM user_events
GROUP BY kafka_topic, kafka_partition, kafka_offset
HAVING COUNT(*) > 1;

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

-- Check ingestion health
CALL sp_check_ingestion_health();
```

---

## Debugging

### Debug Version (JSON File Output)

A debug child transformation is available at `transformations/users-to-db-child-debug.ktr`. It writes to a JSON file instead of the database.

1. Open the parent transformation
2. Change the sub-transformation path to `users-to-db-child-debug.ktr`
3. Run and inspect `transformations/debug-output-users.json`
4. Switch back to `users-to-db-child.ktr` when done

### Common Errors

| Error | Cause | Fix |
|---|---|---|
| "Error in sub-transformation" | Disabled hops, missing connection, wrong path | Check Logging tab; enable hops; verify connection and path |
| "BLOB/TEXT column used in key specification" | String fields missing lengths | Set lengths in Select values **Meta-data** tab |
| "Table not found" / wrong qualification | Target schema field set | Clear Target schema in Table output |
| No data written (W=0) | Consumer not receiving or hops disabled | Check `I=N > 0`; verify all hops are solid lines |
| Duplicate records | Re-processing after restart | Use Insert/Update step or set Ignore insert errors: Yes |

---

## Database Table Reference

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

## Knowledge Check

Before moving on, verify you can answer these:

1. **Why do we use a parent/child transformation pattern?** The parent handles Kafka connectivity and batching; the child handles data processing. This separation allows the Kafka Consumer to manage offsets and concurrency independently from the transformation logic.

2. **Why set `enable.auto.commit` to `false`?** PDI manages offset commits at the batch level ("when batch completes"), ensuring at-least-once delivery. Auto-commit would commit offsets on a timer regardless of whether the batch was successfully processed.

3. **Why set string lengths in the Meta-data tab?** Without explicit lengths, PDI maps String fields to `TINYTEXT` in MySQL, which cannot be used in indexes (including the UNIQUE KEY for idempotency).

4. **What provides idempotent processing?** The `UNIQUE KEY` on `(kafka_topic, kafka_partition, kafka_offset)` prevents duplicate records even if a batch is replayed.

---

## Challenge Exercises

1. **Add a filter**: Modify the child transformation to only load users from `Region_1` through `Region_5` using a Filter rows step
2. **Add error handling**: Route Table output errors to a separate error stream and log them
3. **Monitor lag**: Write a SQL query that calculates the average lag between `register_time` and `ingestion_timestamp`

---

## Summary

After completing this workshop, you have built:

- A parent transformation reading from `pdi-users` topic
- A child transformation that parses JSON, renames fields, converts timestamps, and writes to MySQL
- Idempotent processing via UNIQUE KEY on Kafka coordinates
- Continuous streaming data flowing from Kafka to your data warehouse

**Next**: [Workshop 2: High-Frequency Stock Trades](workshop-2-stock-trades.md)
