# PDI Transformation Templates

This directory contains Pentaho Data Integration transformation templates for the Kafka EE workshop.
This is the **single source of truth** for configuring and running workshop transformations.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Available Templates](#available-templates)
- [Setup Guide](#setup-guide)
  - [Step 1: Start MySQL Database](#step-1-start-mysql-database)
  - [Step 2: Create PDI Database Connection](#step-2-create-pdi-database-connection)
  - [Step 3: Deploy Kafka Connectors](#step-3-deploy-kafka-connectors)
  - [Step 4: Open and Configure Templates](#step-4-open-and-configure-templates)
  - [Step 5: Run Transformation](#step-5-run-transformation)
  - [Step 6: Verify Data in MySQL](#step-6-verify-data-in-mysql)
- [Transformation Configuration Guide](#transformation-configuration-guide)
- [Database Connection Reference](#database-connection-reference)
- [Customization Tips](#customization-tips)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

Before using the transformation templates, ensure:

1. **Kafka cluster is running** — `make start` or `docker compose up -d` from the Kafka-Docker directory
2. **Datagen connectors are deployed** — `make deploy-connectors` or `./connectors/deploy-connectors.sh`
3. **MySQL database is running** — `make mysql-setup` or see [Step 1](#step-1-start-mysql-database)
4. **PDI (Spoon) 9.4+** is installed with the Kafka EE plugin

---

## Available Templates

### Included Templates

| Template | Files | Kafka Topic | Database Table |
|----------|-------|-------------|----------------|
| **users-to-database** | `users-to-db-parent.ktr`, `users-to-db-child.ktr` | `pdi-users` | `user_events` |

### Planned Templates (Build in Workshop)

These templates are listed for reference. Build them as part of the workshop exercises:

| Template | Kafka Topic | Database Table | Pattern |
|----------|-------------|----------------|---------|
| stocktrades-to-database | `pdi-stocktrades` | `stock_trades` | Basic consumer → DB |
| purchases-to-database | `pdi-purchases` | `purchases` | Basic consumer → DB |
| staged-load | Any topic | `kafka_staging` → target table | Two-stage ETL with staging |
| error-handling | Any topic | `kafka_errors` | DLQ and error table pattern |

---

## Setup Guide

### Step 1: Start MySQL Database

The workshop uses a MySQL 8.0 Docker container with pre-created tables.

```bash
# From the Kafka workshop directory
make mysql-setup

# Or manually:
docker compose -f docker-compose-mysql.yml up -d
```

**Default credentials** (set via `docker-compose-mysql.yml`):

| Setting | Value |
|---------|-------|
| Host | `localhost` |
| Port | `3306` |
| Database | `kafka_warehouse` |
| User | `kafka_user` |
| Password | `kafka_password` |
| Root Password | `rootpassword` |

The init script `sql/01-create-database-mysql-docker.sql` is mounted into the container at `/docker-entrypoint-initdb.d/` and runs automatically on **first start** (when the data volume is empty). It creates all tables, views, and stored procedures.

> **Important**: Docker only runs init scripts when the data volume is fresh. If you need to re-initialize the database (e.g., to pick up schema changes), run `make mysql-clean` first to remove the volume, then `make mysql-setup` again.

**Verify MySQL is ready**:

```bash
make mysql-verify

# Or manually:
docker exec kafka-workshop-mysql mysql -u kafka_user -pkafka_password kafka_warehouse -e "SHOW TABLES;"
```

Expected tables: `user_events`, `stock_trades`, `purchases`, `pageviews`, `kafka_staging`, `kafka_errors`, `user_activity_hourly`, `stock_trades_summary`.

### Step 2: Create PDI Database Connection

1. Open Spoon (PDI)
2. Go to **View → Database connections**
3. Click **New** and configure:

```
Connection Name: warehouse_db
Connection Type: MySQL
Access: Native (JDBC)

Settings:
  Host Name:     localhost
  Database Name: kafka_warehouse
  Port Number:   3306
  User Name:     kafka_user
  Password:      kafka_password
```

4. Click **Test** to verify the connection
5. Click **OK** to save

**Advanced Options** (recommended for better write performance):

In the **Options** tab, add these parameters:

| Parameter | Value | Purpose |
|-----------|-------|---------|
| `useServerPrepStmts` | `false` | Faster batch inserts |
| `rewriteBatchedStatements` | `true` | Rewrite INSERTs into multi-row format |
| `cachePrepStmts` | `true` | Cache prepared statements |
| `prepStmtCacheSize` | `250` | Number of cached statements |
| `useCompression` | `true` | Compress network traffic |

This produces the JDBC URL:
```
jdbc:mysql://localhost:3306/kafka_warehouse?useServerPrepStmts=false&rewriteBatchedStatements=true&cachePrepStmts=true&useSSL=false
```

### Step 3: Deploy Kafka Connectors

Ensure the datagen connectors are running so data flows into the Kafka topics:

```bash
make deploy-connectors

# Or manually:
cd connectors && ./deploy-connectors.sh
```

Verify data is flowing:

```bash
make consume-users

# Or manually:
docker exec kafka-1 kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic pdi-users \
  --from-beginning \
  --max-messages 3
```

### Step 4: Open and Configure Templates

1. Open a parent transformation in Spoon (e.g., `users-to-db-parent.ktr`)
2. Double-click the **Kafka Consumer** step and verify:
   - **Bootstrap servers**: `localhost:9092`
   - **Topic**: `pdi-users`
   - **Consumer group**: `pdi-warehouse-users`
3. Update the **Sub-transformation** path to point to the child transformation on your filesystem
   - Example: `/home/pentaho/Workshop.../transformations/users-to-db-child.ktr`
   - Use the **Browse** button to select the file
4. Double-click the child transformation's **Insert/Update** or **Table output** step and verify:
   - **Connection**: `warehouse_db` (created in Step 2)
   - **Target table**: `user_events`
5. Save the transformation

### Step 5: Run Transformation

1. With the **parent** transformation open in Spoon, click **Run** (play button)
2. In the Run dialog, click **Run**
3. Monitor the **Logging** tab for progress — you should see batch processing messages
4. Check the **Metrics** tab for throughput numbers

The transformation runs continuously. To stop it, click **Stop** (stop button) in Spoon.

### Step 6: Verify Data in MySQL

```sql
-- Check record count
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

Or from the command line:

```bash
make mysql-shell
# Then run the queries above
```

---

## Transformation Configuration Guide

### Architecture

```
Parent Transformation (Kafka Consumer Step)
    ↓ (batches of records)
Child Transformation (Get records from stream → Processing Steps → Database Output)
```

The parent transformation contains the Kafka Consumer step that reads messages and sends them in batches to the child transformation. The child transformation processes each batch independently.

### Parent Transformation Settings

Double-click the **Kafka Consumer** step to access the configuration tabs.

#### Setup Tab

| Setting | Value | Notes |
|---------|-------|-------|
| Connection | Direct | |
| Bootstrap Servers | `localhost:9092` | External Kafka broker address |
| Topics | `pdi-users` | One or more topic names |
| Consumer Group | `pdi-warehouse-users` | Unique per transformation |
| Sub-transformation | `[path-to-child.ktr]` | Absolute or relative path |

#### Batch Tab

| Setting | Value | Notes |
|---------|-------|-------|
| Duration (ms) | `5000` | Collect records for 5 seconds |
| Number of records | `100` | Or until 100 records arrive |
| Maximum concurrent batches | `1` | Start with 1, increase for throughput |
| Offset commit | When batch completes | At-least-once delivery (recommended) |

**How batching works**: Whichever threshold is reached first (duration or record count) triggers the batch. Setting either to `0` disables that threshold.

#### Fields Tab

Use the defaults — these fields are automatically provided by the Kafka Consumer:

| Field | Type | Description |
|-------|------|-------------|
| `key` | String | Message key |
| `message` | String | Message payload (JSON) |
| `topic` | String | Topic name |
| `partition` | Integer | Partition number |
| `offset` | Integer | Message offset |
| `timestamp` | Integer | Message timestamp (epoch ms) |

#### Options Tab

| Property | Value | Notes |
|----------|-------|-------|
| `auto.offset.reset` | `earliest` | Read from beginning on first run |
| `enable.auto.commit` | `false` | Let PDI manage offsets |
| `max.poll.records` | `500` | Max records per poll (default) |

### Child Transformation Steps

The child transformation receives a batch of records and processes them.

**Typical flow for `users-to-db-child.ktr`**:

1. **Get records from stream** — Receive batched records from the parent
2. **JSON Input** — Parse the `message` field
   - Source is a field: checked
   - Get source from field: `message`
   - Ignore missing path: Yes
   - Default path leaf to null: Yes
   - Fields:

   | Name | JSONPath | Type |
   |------|----------|------|
   | `userid` | `$.userid` | String |
   | `regionid` | `$.regionid` | String |
   | `gender` | `$.gender` | String |
   | `registertime` | `$.registertime` | Integer |

   > **Note**: The `.ktr` template leaves `<path/>` empty for each field. When the path is empty, PDI's JSON Input step defaults to matching by field name (equivalent to `$.fieldname`). This works because the datagen connector produces flat JSON:
   > ```json
   > {"registertime":1493899960000,"userid":"User_1","regionid":"Region_9","gender":"MALE"}
   > ```
   > If your JSON has nested fields, you must set explicit paths (e.g., `$.data.userid`).
3. **Select values** — Rename fields to match database columns:
   - `userid` → `user_id`
   - `regionid` → `region_id`
   - `registertime` → `register_time_epoch`
   - `topic` → `kafka_topic`
   - `partition` → `kafka_partition`
   - `offset` → `kafka_offset`
4. **Formula** — Convert epoch milliseconds to timestamp:
   - The datagen connector produces `registertime` as epoch milliseconds (e.g., `1493899960000`). Divide by 1000 to get epoch seconds:
   - Formula: `[register_time_epoch] / 1000`
   - New field: `register_time_seconds` (Integer)

   > **Why Formula instead of Calculator?** The Calculator step requires both operands to be existing stream fields — you cannot enter a literal constant like `1000` as Field B. The Formula step supports inline constants in expressions, making it the better choice here.
   >
   > **Alternative**: If you prefer the Calculator step, add an **Add constants** step before it with a field `divisor` = `1000` (Integer), then use Calculator with `A / B` where A = `register_time_epoch` and B = `divisor`.
5. **Insert/Update** (or Table output) — Write to database:
   - Connection: `warehouse_db`
   - Target table: `user_events`
   - Commit size: `1000`
   - Keys: `kafka_topic`, `kafka_partition`, `kafka_offset`

#### Insert/Update Settings (Recommended)

Use Insert/Update for idempotent processing (safe to re-run without duplicates):

```
Connection: warehouse_db
Target table: user_events
Commit size: 1000
Update fields (keys):
  - kafka_topic
  - kafka_partition
  - kafka_offset
Don't perform any updates: Yes (insert only, skip duplicates)
```

#### Table Output Settings (Alternative)

Simpler but may create duplicates unless the UNIQUE constraint on `(kafka_topic, kafka_partition, kafka_offset)` is in place:

```
Connection: warehouse_db
Target schema: (leave blank for MySQL)
Target table: user_events
Commit size: 1000
Use batch updates: Yes
Specify database fields: Yes
Ignore insert errors: Yes (skips duplicates when unique constraint exists)
```

---

## Database Connection Reference

### MySQL (Workshop Default)

```
Connection Name:  warehouse_db
Connection Type:  MySQL
Access:           Native (JDBC)
Host Name:        localhost
Database Name:    kafka_warehouse
Port Number:      3306
User Name:        kafka_user
Password:         kafka_password
```

### PostgreSQL (Alternative)

```
Connection Name:  warehouse_db
Connection Type:  PostgreSQL
Access:           Native (JDBC)
Host Name:        localhost
Database Name:    kafka_warehouse
Port Number:      5432
User Name:        warehouse_user
Password:         [your password]
```

### SQL Server (Alternative)

```
Connection Name:  warehouse_db
Connection Type:  MS SQL Server
Access:           Native (JDBC)
Host Name:        localhost
Database Name:    kafka_warehouse
Port Number:      1433
User Name:        warehouse_user
Password:         [your password]
Instance Name:    MSSQLSERVER
```

### Database Tables Reference

All tables are created automatically by `sql/01-create-database-mysql-docker.sql`. Key tables:

| Table | Source Topic | Description |
|-------|-------------|-------------|
| `user_events` | `pdi-users` | User registration events |
| `stock_trades` | `pdi-stocktrades` | Stock trading transactions |
| `purchases` | `pdi-purchases` | E-commerce purchase transactions |
| `pageviews` | `pdi-pageviews` | Website pageview events |
| `kafka_staging` | Any | Generic staging for raw Kafka messages |
| `kafka_errors` | Any | Error tracking and dead-letter queue |

All tables include a `UNIQUE KEY` on `(kafka_topic, kafka_partition, kafka_offset)` to prevent duplicates.

---

## Customization Tips

### Change Batch Size

Edit Kafka Consumer → Batch Tab:
- **Smaller batches** (lower latency): Duration 1000ms, Records 50
- **Larger batches** (higher throughput): Duration 10000ms, Records 5000

### Add Data Transformations

Insert steps between JSON Input and Table Output:
- **Filter rows**: Remove invalid records
- **Calculator**: Compute derived fields
- **Value Mapper**: Map codes to descriptions
- **Database lookup**: Enrich with reference data
- **Modified Java Script Value**: Complex logic

### Enable Error Handling

Wrap processing steps in Try/Catch:
1. Right-click on steps
2. Select "Error handling"
3. Route errors to error table or DLQ topic

### Optimize Performance

**For high throughput**:
- Increase commit size to 5000-10000
- Use batch updates
- Increase concurrent batches to 2-4
- Disable safe mode in transformation settings
- Set `max.poll.records: 5000` in Options tab
- Set `fetch.min.bytes: 1048576` in Options tab

**For low latency**:
- Decrease batch duration to 1000ms
- Reduce commit size
- Keep concurrent batches at 1

---

## Testing

### Test with Small Data Set

1. Set Kafka Consumer options:
   ```
   auto.offset.reset: earliest
   max.poll.records: 10
   ```
2. Add `Sample rows` step (limit to 10)
3. Replace `Table output` with `Dummy` or `Write to log`
4. Run and verify data parsing

### Verify Database Inserts

After running transformation:

```sql
-- Check record count
SELECT COUNT(*) FROM user_events;

-- View recent records
SELECT * FROM user_events
ORDER BY ingestion_timestamp DESC
LIMIT 10;

-- Check for duplicates
SELECT kafka_topic, kafka_partition, kafka_offset, COUNT(*)
FROM user_events
GROUP BY kafka_topic, kafka_partition, kafka_offset
HAVING COUNT(*) > 1;
```

---

## Troubleshooting

### No data appearing in database

**Check**:
1. Kafka Consumer is receiving messages (check Logging tab)
2. JSON Input step is parsing correctly (check Step Metrics)
3. Database connection `warehouse_db` is valid (test in View → Database connections)
4. Table exists with correct schema — run `SHOW CREATE TABLE user_events;`
5. Field mapping matches between Select Values and database columns

### Duplicate records

**Solution**:
- Ensure `UNIQUE KEY uq_kafka_offset (kafka_topic, kafka_partition, kafka_offset)` exists on the table
- Use **Insert/Update** step instead of Table output
- If using Table output, enable "Ignore insert errors"

### Transformation hangs or no batches processed

**Causes**:
1. Child transformation missing the "Get records from stream" step
2. Both Duration and Records set to 0 in Batch tab
3. Sub-transformation path is incorrect
4. Kafka cluster is not running

**Solution**:
- Verify child transformation starts with "Get records from stream"
- Set at least one batch trigger > 0
- Verify the sub-transformation path resolves correctly
- Run `make status` to check the Kafka cluster

### Performance issues

**Solutions**:
- Increase batch size (Duration and Records)
- Increase commit size in Table output
- Enable batch updates
- Add indexes to database tables
- Increase database connection pool size (Advanced tab → Pooling)

### Consumer group not making progress

**Check offset lag**:
```bash
make consumers

# Or:
docker exec kafka-1 sh -c "unset KAFKA_OPTS; kafka-consumer-groups \
  --bootstrap-server kafka-1:19094 \
  --group pdi-warehouse-users \
  --describe"
```

If lag keeps increasing, the transformation is processing slower than the data arrival rate. Increase concurrent batches or optimize the child transformation.

---

## Example Workflows

### Workflow 1: Continuous Real-time Loading

```
[Run continuously]
Kafka Consumer (batch every 5 seconds)
  ↓
Parse JSON
  ↓
Insert to database (commit every 1000 rows)
```

### Workflow 2: Scheduled Batch Processing

```
[Job runs every 15 minutes]
1. Set consumer offset to last processed
2. Kafka Consumer (bounded by timestamp)
3. Load to staging table
4. Process staging table
5. Load to warehouse
6. Update checkpoint
```

### Workflow 3: Lambda Architecture

```
Real-time path (continuous):
  Kafka → Aggregate → Summary tables

Batch path (hourly):
  Kafka → Full transform → Historical tables
```

---

## Related Documentation

- [Main Workshop README](../README.md) — Workshop overview and quick start
- [Workshop Guide](../docs/WORKSHOP-GUIDE.md) — Complete guide (scenarios, configuration, troubleshooting)
- [SQL Reference](../sql/README.md) — Database setup scripts and maintenance
- SQL setup script: `../sql/01-create-database-mysql-docker.sql`

---

**Template Version**: 2.0
**Last Updated**: 2026-02-22
**Compatible with**: PDI 9.4+ with Kafka EE Plugin
