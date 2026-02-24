# Workshop 4: Time-Bounded Data Retrieval

| | |
|---|---|
| **Scenario** | Bounded Pageview Processing — Process a Specific Time Window |
| **Difficulty** | Intermediate |
| **Duration** | 45–60 minutes |
| **Topics** | `pdi-pageviews` |
| **Target Table** | `pageviews` |
| **PDI Steps** | Kafka Consumer (with Offset Settings), Get records from stream, JSON Input, Filter rows, Select values, Formula, Table output |

---

## Business Context

Your web analytics team needs to generate hourly reports of pageview data. Rather than running a continuous streaming pipeline, they need a **bounded batch job** that processes exactly one hour of data, then stops automatically. This pattern is common for:

- Hourly/daily batch reports from streaming data
- Incident investigation ("replay data from 2 PM to 3 PM")
- Backfill after an outage ("process yesterday's missed data")

The Kafka Consumer EE plugin's **Offset Settings** tab turns a streaming transformation into a bounded batch job.

---

## Learning Objectives

By the end of this workshop, you will be able to:

1. Configure the Kafka Consumer's Offset Settings tab to stop at a specific timestamp
2. Use PDI variables (`${END_TIMESTAMP}`) for dynamic time boundaries
3. Understand bounded vs. continuous Kafka consumption
4. Use Filter rows for optional start-time filtering on the payload timestamp
5. Build a transformation that starts, processes a defined window, and exits cleanly
6. Verify that the result set is truly bounded (not growing)

---

## Prerequisites

| Requirement | Verification Command | Expected Result |
|---|---|---|
| Kafka cluster | `make verify` | All services green |
| MySQL database | `make mysql-verify` | Tables listed including `pageviews` |
| Data flowing into `pdi-pageviews` | `make consume-pageviews` | JSON messages at ~5/sec |
| PDI (Spoon) 9.4+ | Launch Spoon | Application opens |
| `warehouse_db` connection | Test in Spoon | "Connection successful" |

---

## Architecture Overview

```
┌──────────────────────────────────────────────────┐
│  PARENT TRANSFORMATION (pageviews-bounded-parent)│
│                                                  │
│  ┌──────────────────────────────┐                │
│  │    Kafka Consumer            │                │
│  │    Topic: pdi-pageviews      │                │
│  │    Batch: 2s / 200 rec       │                │
│  │    Offset Settings:          │                │
│  │      STOP at ${END_TIMESTAMP}│──── batches ──►│
│  └──────────────────────────────┘                │
└──────────────────────────────────────────────────┘
                    │
                    ▼
┌──────────────────────────────────────────────────┐
│  CHILD TRANSFORMATION (pageviews-bounded-child)  │
│                                                  │
│  Get records from stream                         │
│       │                                          │
│  JSON Input ($.userid, $.pageid, $.viewtime)     │
│       │                                          │
│  Filter rows (optional: viewtime >= start)       │
│       │                                          │
│  Select values (rename + metadata)               │
│       │                                          │
│  Formula (epoch ms ÷ 1000)                       │
│       │                                          │
│  Table output (→ pageviews)                      │
└──────────────────────────────────────────────────┘

     ▲ TRANSFORMATION STOPS AUTOMATICALLY
       when END_TIMESTAMP is reached
```

**Key difference from Workshops 1–3**: The transformation has a defined **end point**. It does not run forever.

---

## Key Concept: Time-Bounded Consumption

| Mode | Workshops 1–3 | This Workshop |
|---|---|---|
| Duration | Runs forever until manually stopped | Stops automatically at END_TIMESTAMP |
| Use case | Real-time continuous ingestion | Batch reports, replay, backfill |
| Controlled by | Nothing (manual stop) | Offset Settings tab (Tab 6) |

**How it works**: The Kafka Consumer reads messages sequentially. When it encounters a message whose **Kafka broker timestamp** is at or after the `END_TIMESTAMP`, it stops the transformation. The Kafka broker timestamp is when the message was written to Kafka (not any field inside the JSON).

---

## Data Source

**Topic**: `pdi-pageviews` — ~5 messages/second from the datagen connector

**Sample message**:
```json
{"viewtime":1708000000000,"userid":"User_3","pageid":"Page_42"}
```

| JSON Field | Type | Description |
|---|---|---|
| `viewtime` | Long | View timestamp (epoch milliseconds) |
| `userid` | String | User identifier (e.g., `User_3`) |
| `pageid` | String | Page identifier (e.g., `Page_42`) |

---

## Step-by-Step Instructions

### Step 1: Verify Data is Flowing

```bash
make consume-pageviews
```

Messages should arrive at ~5/sec. If not: `make deploy-connectors`

---

### Step 2: Create Parent Transformation

1. **File → New → Transformation**
2. Save as `pageviews-bounded-parent.ktr` in `transformations/`

#### Define the END_TIMESTAMP Parameter

Before configuring the Kafka Consumer, add the parameter:

1. Right-click the canvas → **Transformation settings** (or **Ctrl+T**)
2. Click the **Parameters** tab
3. Add:

| Parameter | Default Value | Description |
|---|---|---|
| `END_TIMESTAMP` | *(5 minutes from now, e.g., `2026-02-23 15:05:00`)* | Stop consuming at this timestamp |

4. Click **OK**

#### Add Kafka Consumer Step

#### Tab 1: Setup Tab

| Setting | Value |
|---|---|
| Connection | Direct |
| Bootstrap Servers | `localhost:9092` |
| Topics | `pdi-pageviews` |
| Consumer Group | `pdi-pageviews-bounded` |
| Sub-transformation | `[path]/transformations/pageviews-bounded-child.ktr` |

> **Consumer Group naming**: Use a separate group from any continuous consumer. This bounded job manages its own offsets independently.

#### Tab 2: Batch Tab

| Setting | Value | Notes |
|---|---|---|
| Duration (ms) | `2000` | 2-second window |
| Number of records | `200` | Handle bursts and replay |
| Concurrent batches | `1` | |
| Message prefetch limit | `100000` | |
| Offset commit | When batch completes | |

#### Tab 3: Fields Tab

| Name | Type |
|---|---|
| `key` | String |
| `message` | String |
| `topic` | String |
| `partition` | Integer |
| `offset` | Integer |
| `timestamp` | Integer |

#### Tab 4: Options Tab

| Property | Value |
|---|---|
| `auto.offset.reset` | `earliest` |
| `enable.auto.commit` | `false` |

> **`earliest` is critical for bounded retrieval**: Start from the oldest available message when no committed offset exists. After the first run, the consumer resumes from the committed offset.

#### Tab 6: Offset Settings Tab

This is the key tab for time-bounded processing.

| Setting | Value |
|---|---|
| Offset timestamp | `${END_TIMESTAMP}` |
| Timestamp format | `yyyy-MM-dd HH:mm:ss` |

> **How it works**: When the consumer encounters a message with a Kafka timestamp at or after this value, it stops automatically.
>
> **Variable substitution**: `${END_TIMESTAMP}` is resolved from the parameter you defined. You can override it in the Run dialog, kettle.properties, or command-line.
>
> **No start timestamp**: The Offset Settings tab only controls when to **stop**. The start is controlled by committed offsets or `auto.offset.reset`. For start-time filtering, use Filter rows in the child (Step 3c).

Save the transformation.

---

### Step 3: Create Child Transformation

1. **File → New → Transformation**
2. Save as `pageviews-bounded-child.ktr`

---

#### Step 3a: Get Records from Stream

| Name | Type | Length | Precision |
|---|---|---|---|
| `key` | String | -1 | -1 |
| `message` | String | -1 | -1 |
| `topic` | String | -1 | -1 |
| `partition` | Integer | -1 | -1 |
| `offset` | Integer | -1 | -1 |
| `timestamp` | Integer | -1 | -1 |

---

#### Step 3b: JSON Input

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
| `userid` | `$.userid` | String | | -1 | -1 | none |
| `pageid` | `$.pageid` | String | | -1 | -1 | none |
| `viewtime` | `$.viewtime` | Integer | | -1 | -1 | none |

---

#### Step 3c: Filter Rows (Optional)

This step is **optional** but provides precise start-time filtering on the payload's `viewtime` field.

1. From **Design → Flow**, drag **Filter rows** onto the canvas
2. Draw hop from **JSON Input** → **Filter rows**

**Condition**:

| Field | Condition | Value |
|---|---|---|
| `viewtime` | `>=` | `${START_TIMESTAMP_EPOCH}` |

- **True** path → goes to **Select values**
- **False** path → **Dummy** step (discard)

> **When to use**: The Offset Settings tab stops at an end time, but doesn't control the start. Filter rows lets you filter by a start time based on the payload's `viewtime` field.
>
> **If skipping**: Draw hop directly from **JSON Input** → **Select values**.
>
> **Variable**: Add `START_TIMESTAMP_EPOCH` as another parameter (epoch milliseconds, e.g., `1708000000000`).

---

#### Step 3d: Select Values

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
| `pageid` | `page_url` |
| `viewtime` | `view_timestamp_epoch` |

> **Why `pageid` → `page_url`?** The database schema uses `page_url VARCHAR(500)` to accommodate full URLs in production.

##### Meta-data Tab

| Fieldname | Type | Length | Precision |
|---|---|---|---|
| `user_id` | String | 100 | |
| `page_url` | String | 500 | |
| `view_timestamp_epoch` | Integer | 15 | |
| `kafka_topic` | String | 255 | |
| `kafka_partition` | Integer | 9 | |
| `kafka_offset` | Integer | 15 | |
| `key` | String | 100 | |
| `message` | String | 5000 | |
| `timestamp` | Integer | 15 | |

---

#### Step 3e: Formula

| New field | Formula | Value type | Length | Precision | Replace |
|---|---|---|---|---|---|
| `view_timestamp_seconds` | `[view_timestamp_epoch] / 1000` | Integer | -1 | -1 | *(blank)* |

---

#### Step 3f: Table Output

##### Main Settings

| Setting | Value |
|---|---|
| Connection | `warehouse_db` |
| Target schema | *(leave blank)* |
| Target table | `pageviews` |
| Commit size | `1000` |
| Truncate table | No |
| Ignore insert errors | No |
| Use batch updates | Yes |
| Specify database fields | Yes |

##### Database Fields

| Database Column | Stream Field |
|---|---|
| `user_id` | `user_id` |
| `page_url` | `page_url` |
| `view_timestamp` | `view_timestamp_seconds` |
| `kafka_topic` | `kafka_topic` |
| `kafka_partition` | `kafka_partition` |
| `kafka_offset` | `kafka_offset` |

> **Do NOT map**: `pageview_id`, `session_id` (NULL is OK), `ingestion_timestamp`

---

### Step 4: Verify Hops

With Filter rows:
```
Get records from stream → JSON Input → Filter rows → Select values → Formula → Table output
```

Without Filter rows:
```
Get records from stream → JSON Input → Select values → Formula → Table output
```

---

### Step 5: Set END_TIMESTAMP and Run

1. Open `pageviews-bounded-parent.ktr`
2. Click **Run** (▶)
3. In the Run dialog, click **Parameters** tab
4. Set `END_TIMESTAMP` to ~5 minutes from now (e.g., `2026-02-23 15:10:00`)

> The format must match `yyyy-MM-dd HH:mm:ss` as configured in the Offset Settings tab.

5. Click **Run**
6. Monitor — the transformation **will stop automatically** when it reaches the timestamp

> **Expected behavior**: Unlike Workshops 1–3, you will see "Transformation finished" in the log. The transformation exits cleanly.

---

### Step 6: Verify Bounded Data in MySQL

```bash
make mysql-shell
```

```sql
-- Total record count (should be finite, not growing)
SELECT COUNT(*) AS total_pageviews FROM pageviews;

-- Verify time boundary
SELECT
    MIN(view_timestamp) AS earliest_view,
    MAX(view_timestamp) AS latest_view,
    TIMESTAMPDIFF(MINUTE, MIN(view_timestamp), MAX(view_timestamp)) AS window_minutes,
    COUNT(*) AS total_records
FROM pageviews;

-- Records per minute
SELECT
    DATE_FORMAT(view_timestamp, '%Y-%m-%d %H:%i:00') AS minute,
    COUNT(*) AS pageview_count
FROM pageviews
WHERE view_timestamp IS NOT NULL
GROUP BY minute
ORDER BY minute DESC
LIMIT 20;

-- Page popularity
SELECT
    page_url, COUNT(*) AS view_count,
    COUNT(DISTINCT user_id) AS unique_users
FROM pageviews
GROUP BY page_url
ORDER BY view_count DESC
LIMIT 10;

-- CRITICAL: Verify data is bounded (run twice with 30-sec gap)
-- Count should NOT increase the second time
SELECT COUNT(*) AS total, MAX(ingestion_timestamp) AS last_ingestion FROM pageviews;
```

---

## Advanced: Dynamic Time Windows

### Option 1: Command-Line Parameters

```bash
pan.sh -file=pageviews-bounded-parent.ktr \
  -param:END_TIMESTAMP="$(date -d '+0 hours' '+%Y-%m-%d %H:%M:%S')"
```

### Option 2: kettle.properties

```properties
END_TIMESTAMP=2026-02-23 14:00:00
```

### Option 3: Wrapper Transformation

```
Get System Info → Calculator (now - 1 hour) → Set Variables → [Kafka transformation]
```

### Scheduling

Combine command-line parameters with cron for recurring bounded jobs:
```bash
# Run every hour, processing the previous hour's data
0 * * * * /path/to/pan.sh -file=pageviews-bounded-parent.ktr \
  -param:END_TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"
```

---

## Debugging

### Common Errors

| Error | Cause | Fix |
|---|---|---|
| Transformation never stops | `END_TIMESTAMP` not resolved | Check parameter is set in Run dialog |
| Transformation never stops | Wrong timestamp format | Match Offset Settings format to your value |
| Transformation stops immediately | `END_TIMESTAMP` is in the past | Use a future timestamp |
| Transformation stops immediately | `auto.offset.reset` is `latest` | Change to `earliest` |
| No data (W=0) | Consumer group already past timestamp | Use new consumer group or reset offsets |
| Filter removing all rows | `START_TIMESTAMP_EPOCH` too recent | Check the epoch value |

---

## Database Table Reference

```sql
CREATE TABLE pageviews (
    pageview_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id VARCHAR(100),
    page_url VARCHAR(500),
    view_timestamp TIMESTAMP NULL,
    session_id VARCHAR(100),
    kafka_topic VARCHAR(255),
    kafka_partition INT,
    kafka_offset BIGINT,
    ingestion_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_user_id (user_id),
    INDEX idx_session_id (session_id),
    INDEX idx_pageview_timestamp (view_timestamp),
    UNIQUE KEY uq_kafka_offset (kafka_topic, kafka_partition, kafka_offset)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

---

## Knowledge Check

1. **What controls when the consumer stops?** The Offset Settings tab (Tab 6) — when a message's Kafka broker timestamp reaches `END_TIMESTAMP`, the transformation finishes.

2. **What controls where the consumer starts?** The committed offset for the consumer group, or `auto.offset.reset` if no offset exists.

3. **Why use a separate consumer group for bounded jobs?** Bounded and continuous consumers would compete for partitions if they share a group. Separate groups allow independent offset management.

4. **How do you re-read the same time window?** Either use a different consumer group name, or reset offsets with `kafka-consumer-groups.sh --reset-offsets`.

---

## Challenge Exercises

1. **Dynamic 1-hour window**: Create a wrapper transformation that calculates `END_TIMESTAMP` as the current time and `START_TIMESTAMP_EPOCH` as 1 hour ago, then runs the bounded transformation
2. **Session generation**: Generate a `session_id` using Formula: `[user_id] & "-" & TEXT([view_timestamp_seconds];"0")`
3. **Offset reset**: Use `kafka-consumer-groups.sh` to reset offsets for `pdi-pageviews-bounded` and re-process the same data window

---

## Summary

After completing this workshop, you have:

- A parent transformation that stops automatically at a configurable timestamp
- A child transformation with optional time-based filtering
- Understanding of the Offset Settings tab for bounded consumption
- Experience with PDI variables for dynamic configuration
- Knowledge of three approaches for dynamic time windows
- A bounded dataset in your `pageviews` table representing a specific time window

**Previous**: [Workshop 3: E-Commerce Purchases with Avro](workshop-3-purchases-avro.md)

**Next**: [Workshop 5: Multi-Topic Consumer with Kafka Producer](workshop-5-multi-topic-producer.md)
