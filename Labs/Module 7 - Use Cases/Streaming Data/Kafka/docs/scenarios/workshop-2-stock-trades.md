# Workshop 2: High-Frequency Stock Trades

| | |
|---|---|
| **Scenario** | High-Frequency Stock Trades — Tuning for Throughput |
| **Difficulty** | Intermediate |
| **Duration** | 45–60 minutes |
| **Topics** | `pdi-stocktrades` |
| **Target Table** | `stock_trades` (and optionally `stock_trades_summary`) |
| **PDI Steps** | Kafka Consumer, Get records from stream, JSON Input, Select values, Table output, (optional) Group By |

---

## Business Context

Your trading platform publishes stock trade events at high frequency (~10 messages/second) to a Kafka topic. You need to ingest this data into a MySQL data warehouse in near real-time for compliance reporting and market analysis. Unlike Workshop 1's low-volume user events, this scenario requires tuning batch settings for throughput — including shorter batch windows, higher record limits, and concurrent batch processing.

---

## Learning Objectives

By the end of this workshop, you will be able to:

1. Configure a Kafka Consumer step for high-frequency data (10x Workshop 1's volume)
2. Tune batch settings: duration, record count, and concurrent batches for higher throughput
3. Understand when epoch conversion is NOT needed (database-generated timestamps)
4. Build a simpler pipeline (no Formula step) compared to Workshop 1
5. (Optional) Aggregate streaming data per stock symbol using the Group By step

---

## Prerequisites

| Requirement | Verification Command | Expected Result |
|---|---|---|
| Kafka cluster | `make verify` | All services green |
| MySQL database | `make mysql-verify` | Tables listed including `stock_trades` |
| Data flowing into `pdi-stocktrades` | `make consume-trades` | JSON messages at ~10/sec |
| PDI (Spoon) 9.4+ | Launch Spoon | Application opens |
| `warehouse_db` connection | Test in Spoon | "Connection successful" |

If you haven't created the `warehouse_db` connection, follow [Workshop 1, Step 2](workshop-1-user-activity.md#step-2-create-database-connection-in-spoon).

---

## Architecture Overview

```
┌──────────────────────────────────────────────────┐
│  PARENT TRANSFORMATION (stocktrades-to-db-parent)│
│                                                  │
│  ┌──────────────────────────────┐                │
│  │    Kafka Consumer            │                │
│  │    Topic: pdi-stocktrades    │                │
│  │    Batch: 1s / 50 rec       │                │
│  │    Concurrent batches: 2    │──── batches ──► │
│  └──────────────────────────────┘                │
└──────────────────────────────────────────────────┘
                    │
                    ▼
┌──────────────────────────────────────────────────┐
│  CHILD TRANSFORMATION (stocktrades-to-db-child)  │
│                                                  │
│  Get records from stream                         │
│       │                                          │
│  JSON Input (parse $.symbol, $.side, $.quantity,  │
│              $.price, $.account, $.userid)        │
│       │                                          │
│  Select values (rename userid→user_id + metadata)│
│       │                                          │
│  Table output (→ stock_trades)                   │
└──────────────────────────────────────────────────┘
```

**Key difference from Workshop 1**: No Formula step. The stock trades JSON has no timestamp field — the database column `trade_timestamp` uses `DEFAULT CURRENT_TIMESTAMP` to record insertion time.

---

## Data Source

**Topic**: `pdi-stocktrades` — ~10 messages/second from the datagen connector

**Sample message**:
```json
{"side":"BUY","quantity":2269,"symbol":"ZVZZT","price":558,"account":"LMN456","userid":"User_5"}
```

| JSON Field | Type | Description |
|---|---|---|
| `symbol` | String | Stock ticker symbol (e.g., `ZVZZT`) |
| `side` | String | Trade direction (`BUY` or `SELL`) |
| `quantity` | Integer | Number of shares traded |
| `price` | Integer | Trade price per share |
| `account` | String | Trading account (e.g., `LMN456`) |
| `userid` | String | User identifier (e.g., `User_5`) |

> **No timestamp field**: Unlike Workshop 1's `registertime`, stock trades rely on MySQL's `DEFAULT CURRENT_TIMESTAMP` for timestamping.

---

## Step-by-Step Instructions

### Step 1: Verify Data is Flowing

```bash
make consume-trades
```

Notice the volume — messages arrive much faster than `pdi-users`. This is why different batch settings are needed.

---

### Step 2: Verify Database Connection

If you completed Workshop 1, `warehouse_db` should exist. Verify it:

1. **View** panel → **Database connections** → double-click `warehouse_db` → **Test**

Connection details (for reference):

| Setting | Value |
|---|---|
| Connection Name | `warehouse_db` |
| Connection Type | MySQL |
| Host Name | `localhost` |
| Database Name | `kafka_warehouse` |
| Port | `3306` |
| User Name | `kafka_user` |
| Password | `kafka_password` |

---

### Step 3: Create Parent Transformation

1. **File → New → Transformation**
2. Save as `stocktrades-to-db-parent.ktr` in the `transformations/` directory

#### Setup Tab

| Setting | Value | Notes |
|---|---|---|
| Connection | Direct | |
| Bootstrap Servers | `localhost:9092` | |
| Topics | `pdi-stocktrades` | |
| Consumer Group | `pdi-stocktrades-consumer` | Unique per transformation |
| Sub-transformation | `[path]/transformations/stocktrades-to-db-child.ktr` | Use **Browse** |

#### Batch Tab — Tuned for High Throughput

| Setting | Value | Workshop 1 Value | Why Different |
|---|---|---|---|
| Duration (ms) | `1000` | 5000 | Lower latency — data reaches DB within ~1 sec |
| Number of records | `50` | 100 | Fires on bursts before duration elapses |
| Concurrent batches | `2` | 1 | Overlapping batches while DB writes complete |
| Message prefetch limit | `100000` | 100000 | Same |
| Offset commit | When batch completes | Same | At-least-once delivery |

> **Why these settings?** At ~10 msg/sec, a 1-second window captures ~10 messages per batch. With 2 concurrent batches, a second batch can start while the first is still writing to MySQL. The record count of 50 handles bursts.

#### Fields Tab

| Name | Type |
|---|---|
| `key` | String |
| `message` | String |
| `topic` | String |
| `partition` | Integer |
| `offset` | Integer |
| `timestamp` | Integer |

#### Options Tab

| Property | Value |
|---|---|
| `auto.offset.reset` | `earliest` |
| `enable.auto.commit` | `false` |

Save the transformation (**Ctrl+S**).

---

### Step 4: Create Child Transformation

1. **File → New → Transformation**
2. Save as `stocktrades-to-db-child.ktr`

---

#### Step 4a: Get Records from Stream

| Name | Type | Length | Precision |
|---|---|---|---|
| `key` | String | -1 | -1 |
| `message` | String | -1 | -1 |
| `topic` | String | -1 | -1 |
| `partition` | Integer | -1 | -1 |
| `offset` | Integer | -1 | -1 |
| `timestamp` | Integer | -1 | -1 |

---

#### Step 4b: JSON Input

**Source tab**:

| Setting | Value |
|---|---|
| Source is a field | Checked |
| Get source from field | `message` |
| Ignore missing path | Yes |
| Default path leaf to null | Yes |

**Fields tab**:

| Name | Path | Type | Format | Length | Precision | Trim |
|---|---|---|---|---|---|---|
| `symbol` | `$.symbol` | String | | -1 | -1 | none |
| `side` | `$.side` | String | | -1 | -1 | none |
| `quantity` | `$.quantity` | Integer | | -1 | -1 | none |
| `price` | `$.price` | Number | | -1 | -1 | none |
| `account` | `$.account` | String | | -1 | -1 | none |
| `userid` | `$.userid` | String | | -1 | -1 | none |

> **Price type**: Extracted as `Number` to map to `DECIMAL(10,2)` in MySQL.

---

#### Step 4c: Select Values

##### Select & Alter Tab

| Fieldname | Rename to |
|---|---|
| `key` | |
| `message` | |
| `topic` | `kafka_topic` |
| `partition` | `kafka_partition` |
| `offset` | `kafka_offset` |
| `timestamp` | |
| `symbol` | |
| `side` | |
| `quantity` | |
| `price` | |
| `account` | |
| `userid` | `user_id` |

> **Only one rename** needed: `userid` → `user_id`. Other JSON fields already match database columns.

##### Meta-data Tab

| Fieldname | Type | Length | Precision |
|---|---|---|---|
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

---

#### Step 4d: Table Output

> **No Formula step** — go directly from Select values to Table output.

##### Main Settings

| Setting | Value |
|---|---|
| Connection | `warehouse_db` |
| Target schema | *(leave blank)* |
| Target table | `stock_trades` |
| Commit size | `1000` |
| Truncate table | No |
| Ignore insert errors | No |
| Use batch updates | Yes |
| Specify database fields | Yes |

##### Database Fields

| Database Column | Stream Field |
|---|---|
| `symbol` | `symbol` |
| `side` | `side` |
| `quantity` | `quantity` |
| `price` | `price` |
| `account` | `account` |
| `user_id` | `user_id` |
| `kafka_topic` | `kafka_topic` |
| `kafka_partition` | `kafka_partition` |
| `kafka_offset` | `kafka_offset` |

> **Do NOT map**: `trade_id` (AUTO_INCREMENT) or `trade_timestamp` (DEFAULT CURRENT_TIMESTAMP).

---

### Step 5: Verify Hops

Complete flow (shorter than Workshop 1 — no Formula):
```
Get records from stream → JSON Input → Select values → Table output
```

All hops must be solid lines.

---

### Step 6: Run the Transformation

1. Open `stocktrades-to-db-parent.ktr`
2. Click **Run** (▶) or **F9**
3. Monitor — batches fire more frequently than Workshop 1 (~every 1 second)

> **Expected throughput**: ~10 rows/sec. Step Metrics show cumulative counts increasing rapidly.

---

### Step 7: Verify Data in MySQL

```bash
make mysql-shell
```

```sql
-- Check record count (should increase rapidly — ~10/sec)
SELECT COUNT(*) FROM stock_trades;

-- View recent records
SELECT * FROM stock_trades ORDER BY trade_timestamp DESC LIMIT 10;

-- Check for duplicates (should return 0 rows)
SELECT kafka_topic, kafka_partition, kafka_offset, COUNT(*)
FROM stock_trades
GROUP BY kafka_topic, kafka_partition, kafka_offset
HAVING COUNT(*) > 1;

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

-- Monitor ingestion rate per minute (expect ~600 records/min)
SELECT
    DATE_FORMAT(trade_timestamp, '%Y-%m-%d %H:%i:00') AS minute,
    COUNT(*) AS records_ingested
FROM stock_trades
WHERE trade_timestamp >= DATE_SUB(NOW(), INTERVAL 1 HOUR)
GROUP BY minute
ORDER BY minute DESC;

-- Use the built-in view
SELECT * FROM v_recent_stock_trades ORDER BY trade_timestamp DESC LIMIT 10;
```

---

## Optional Exercise: Per-Symbol Aggregation with Group By

Add a **Group By** step between Select values and Table output to calculate metrics per stock symbol within each batch.

### Add Group By

1. Delete hop from Select values → Table output
2. Add **Group by** step (Design → Statistics)
3. Draw hops: **Select values** → **Group by** → **Table output**

**Group field**: `symbol`

**Aggregates**:

| Name | Subject | Type |
|---|---|---|
| `avg_price` | `price` | Average |
| `total_quantity` | `quantity` | Sum |
| `trade_count` | `symbol` | Count of rows |
| `min_price` | `price` | Minimum |
| `max_price` | `price` | Maximum |

**Include all rows**: No (one row per symbol per batch)

### Update Table Output

| Setting | Value |
|---|---|
| Target table | `stock_trades_summary` |

| Database Column | Stream Field |
|---|---|
| `symbol` | `symbol` |
| `trade_count` | `trade_count` |
| `total_volume` | `total_quantity` |
| `avg_price` | `avg_price` |
| `min_price` | `min_price` |
| `max_price` | `max_price` |

### Verify

```sql
SELECT * FROM stock_trades_summary ORDER BY created_at DESC LIMIT 20;
```

---

## Debugging

### Common Errors

| Error | Cause | Fix |
|---|---|---|
| "Error in sub-transformation" | Disabled hops, missing connection, wrong path | Check Logging tab |
| "BLOB/TEXT column used in key specification" | String fields missing lengths | Set lengths in Meta-data tab |
| Batches backing up / slow writes | Database writes too slow | Increase Commit size; verify `rewriteBatchedStatements=true` |
| No data written (W=0) | Consumer not receiving or hops disabled | Verify `I=N > 0`; check hops |

---

## Comparison: Workshop 1 vs Workshop 2

| Aspect | Workshop 1 (Users) | Workshop 2 (Stock Trades) |
|---|---|---|
| Message rate | ~1/sec | ~10/sec |
| Batch duration | 5000ms | 1000ms |
| Record count | 100 | 50 |
| Concurrent batches | 1 | 2 |
| Epoch conversion | Yes (Formula step) | No (DB default timestamp) |
| Pipeline steps | 5 | 4 |
| Target table | `user_events` | `stock_trades` |

---

## Database Table Reference

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

---

## Knowledge Check

1. **Why reduce batch duration from 5000ms to 1000ms?** Lower latency — at 10 msg/sec, waiting 5 seconds accumulates ~50 records before writing. A 1-second window gets data to the database faster.

2. **Why increase concurrent batches to 2?** While one batch is writing to MySQL (I/O bound), a second batch can be prepared. This overlapping improves throughput.

3. **Why is there no Formula step?** The stock trades JSON has no timestamp field. The database uses `DEFAULT CURRENT_TIMESTAMP` to record when each row is inserted.

---

## Challenge Exercises

1. **Dual output**: Keep both raw trades AND aggregated summaries by splitting the flow after Select values
2. **Price alerting**: Add a Filter rows step to flag trades where `price > 800` and write those to a separate alert table
3. **Performance tuning**: Experiment with different batch settings (500ms duration, 3 concurrent batches) and measure throughput differences

---

## Summary

After completing this workshop, you have:

- A parent transformation reading from `pdi-stocktrades` with tuned batch settings
- A child transformation optimized for high-frequency data (no unnecessary steps)
- Batch settings tuned for 10 msg/sec throughput
- (Optional) Per-symbol aggregation using Group By
- Understanding of how message rate drives batch configuration choices

**Previous**: [Workshop 1: Real-time User Activity Stream](workshop-1-user-activity.md)

**Next**: [Workshop 3: E-Commerce Purchases with Avro](workshop-3-purchases-avro.md)
