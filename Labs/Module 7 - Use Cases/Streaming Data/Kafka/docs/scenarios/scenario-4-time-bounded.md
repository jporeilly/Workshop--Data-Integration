# Scenario 4: Time-Bounded Data Retrieval - Bounded Pageview Processing

**Business Use Case**: Process a specific time window of pageview data from Kafka (e.g., "the last 1 hour"), automatically stopping when the end timestamp is reached, and load the bounded dataset into a MySQL data warehouse.

**Difficulty**: Intermediate | **Duration**: 45-60 minutes

## Learning Objectives

- Configure the Kafka Consumer EE plugin's Offset Settings tab to stop at a specific timestamp
- Use PDI variables (`${END_TIMESTAMP}`) for dynamic time boundaries
- Understand the difference between continuous and bounded Kafka consumption
- Use `auto.offset.reset` and Filter rows for precise time-based windowing
- Configure higher-throughput batch settings for bounded data retrieval
- Rename and type fields using Select values (including Meta-data tab)
- Write bounded results to MySQL using Table output with correct field mapping
- Verify time-bounded data in the database using time-range queries

## Prerequisites

Before starting this scenario:

1. Workshop environment is running --- `make workshop-start`
2. MySQL is running with tables created --- `make mysql-verify`
3. Data is flowing into `pdi-pageviews` topic --- `make consume-pageviews`
4. PDI (Spoon) is open with Kafka EE plugin installed
5. `warehouse_db` database connection is configured in Spoon (see [Scenario 1, Step 2](scenario-1-user-activity.md#step-2-create-database-connection-in-spoon))

## Architecture

```
Parent Transformation (Kafka Consumer Step with Offset Settings)
    | (batches of records every 2 seconds or 200 records)
    | (STOPS automatically when END_TIMESTAMP is reached)
    v
Child Transformation
    Get records from stream
        |
    JSON Input (parse message field)
        |
    Filter rows (optional: additional time filtering)
        |
    Select values (rename + set metadata/types)
        |
    Table output (write to pageviews)
```

## Data Source

The `pdi-pageviews` topic receives pageview events at ~5 messages/second from the datagen connector.

**Sample message**:
```json
{"viewtime":1708000000000,"userid":"User_3","pageid":"Page_42"}
```

**Field descriptions**:

| JSON Field | Type | Description |
|-----------|------|-------------|
| `viewtime` | Long | View timestamp (epoch milliseconds) |
| `userid` | String | User identifier (e.g., `User_3`) |
| `pageid` | String | Page identifier (e.g., `Page_42`) |

---

## Key Concept: Time-Bounded Consumption

In Scenarios 1-3, the Kafka Consumer runs continuously --- it never stops on its own. This is ideal for real-time streaming but not for batch-style use cases such as:

- **"Process the last 1 hour of pageview data"** for an hourly report
- **"Replay data from 2 PM to 3 PM"** to investigate an incident
- **"Backfill yesterday's data"** into the warehouse after an outage

The Kafka Consumer EE plugin's **Offset Settings** tab (tab 6) allows you to specify a timestamp at which the consumer should **stop reading**. When the consumer encounters a message with a Kafka timestamp at or after this value, it stops the transformation automatically.

This turns a streaming transformation into a **bounded batch job** --- it starts, processes a defined window of data, and exits cleanly.

---

## Step-by-Step Instructions

### Step 1: Verify Data is Flowing

```bash
make consume-pageviews
```

You should see JSON messages arriving at ~5/second. If not, deploy connectors first: `make deploy-connectors`

### Step 2: Verify Database Connection

If you completed Scenario 1, you already have the `warehouse_db` connection configured. Verify it:

1. Open Spoon (PDI)
2. Go to **View** panel (left side) --> **Database connections**
3. Double-click `warehouse_db` --> click **Test** --> confirm "Connection successful"

If you do not have this connection, create it by following [Scenario 1, Step 2](scenario-1-user-activity.md#step-2-create-database-connection-in-spoon).

### Step 3: Create Parent Transformation

1. **File --> New --> Transformation**
2. Save as `pageviews-bounded-parent.ktr` in the `transformations/` directory

#### Add Kafka Consumer Step

1. From the **Design** panel, expand **Input** --> drag **Kafka Consumer** onto the canvas
2. Double-click the Kafka Consumer step to configure:

#### Tab 1: Setup Tab

| Setting | Value | Notes |
|---------|-------|-------|
| Connection | Direct | |
| Bootstrap Servers | `localhost:9092` | External Kafka broker address |
| Topics | `pdi-pageviews` | |
| Consumer Group | `pdi-pageviews-bounded` | Unique name for this bounded transformation |
| Sub-transformation | `[path]/transformations/pageviews-bounded-child.ktr` | Use Browse button to select |

> **Tip**: Use the **Browse** button for the sub-transformation path. An incorrect path is a common source of "Error in sub-transformation" errors.

> **Consumer Group naming**: Using `pdi-pageviews-bounded` (separate from any continuous consumer) ensures this bounded job manages its own offsets independently. If you share a consumer group with a continuous consumer, they will compete for partitions.

#### Tab 2: Batch Tab

| Setting | Value | Notes |
|---------|-------|-------|
| Duration (ms) | `2000` | Collect records for 2 seconds |
| Number of records | `200` | Or until 200 records arrive |
| Maximum concurrent batches | `1` | Start with 1 |
| Message prefetch limit | `100000` | Default is fine |
| Offset commit | When batch completes | At-least-once delivery (recommended) |

> **Why 2000ms / 200 records?** Since `pdi-pageviews` produces ~5 messages/second, a 2-second window captures ~10 messages in normal flow. The higher record limit of 200 accommodates bursts and replay scenarios where messages arrive faster than real-time. These settings prioritize throughput over latency, which is appropriate for bounded processing where you want to finish quickly rather than respond immediately.

#### Tab 3: Fields Tab

Click **Get Fields** or manually add these (these are the default Kafka Consumer output fields):

| Name | Type |
|------|------|
| `key` | String |
| `message` | String |
| `topic` | String |
| `partition` | Integer |
| `offset` | Integer |
| `timestamp` | Integer |

#### Tab 4: Options Tab

Click **+** to add each property:

| Property | Value | Notes |
|----------|-------|-------|
| `auto.offset.reset` | `earliest` | Start from the beginning of the topic |
| `enable.auto.commit` | `false` | Let PDI manage offsets |

> **`auto.offset.reset` and bounded processing**: Setting this to `earliest` means the consumer starts from the oldest available message when there is no committed offset for this consumer group. This is critical for bounded retrieval --- you want to start from the beginning (or a known point) and read forward to your end timestamp.
>
> After the first run completes, the consumer group's committed offset will be at the point where it stopped. On the next run, it will resume from that committed offset. To re-read the same window, either:
> - Use a different consumer group name, or
> - Reset offsets using `kafka-consumer-groups.sh --reset-offsets`

#### Tab 5: (Reserved)

This tab may vary by PDI version. No configuration is needed here.

#### Tab 6: Offset Settings Tab

This is the key tab for time-bounded processing.

| Setting | Value | Notes |
|---------|-------|-------|
| Offset timestamp | `${END_TIMESTAMP}` | The timestamp at which to STOP consuming |
| Timestamp format | `yyyy-MM-dd HH:mm:ss` | Format of the timestamp value |

> **How it works**: The Kafka Consumer reads messages sequentially. When it encounters a message whose Kafka timestamp is at or after the value in **Offset timestamp**, it stops the transformation. This is based on the **Kafka broker timestamp** (the time the message was written to Kafka), not any timestamp inside the JSON payload.
>
> **Variable substitution**: Using `${END_TIMESTAMP}` allows you to set this value dynamically. You can set this variable via:
> - A **Set Variables** step in a wrapper transformation
> - The **kettle.properties** file
> - The **Run dialog** --> Parameters tab
> - A command-line argument: `-param:END_TIMESTAMP="2024-02-15 14:00:00"`
>
> **Timestamp format**: If you set the format to `yyyy-MM-dd HH:mm:ss`, provide the timestamp in that format (e.g., `2024-02-15 14:00:00`). If you leave the format **blank**, PDI expects epoch milliseconds (e.g., `1708000000000`).
>
> **No start timestamp?** The Offset Settings tab only controls when to **stop**. The start position is controlled by:
> - The committed offset for the consumer group (if one exists), or
> - The `auto.offset.reset` property (`earliest` or `latest`)
>
> To control the start position precisely, use a **Filter rows** step in the child transformation (see Step 4d).

**Setting the END_TIMESTAMP variable**:

For this exercise, set the variable via the Run dialog:

1. In the parent transformation, go to the **Transformation properties** (right-click canvas --> **Transformation settings**, or **Ctrl+T**)
2. Click the **Parameters** tab
3. Add a parameter:

| Parameter | Default Value | Description |
|-----------|---------------|-------------|
| `END_TIMESTAMP` | *(see below)* | Stop consuming at this timestamp |

For the default value, calculate a timestamp approximately 1 hour from now. For example, if the current time is `2024-02-15 13:00:00`, set the default to `2024-02-15 14:00:00`.

> **For testing**: Set the `END_TIMESTAMP` to a few minutes in the future so the transformation stops relatively quickly. For example, set it to 5 minutes from now. If you set it too far in the future, the transformation will run until that time is reached.
>
> **For production**: In a real scenario, you would use a wrapper job (Kettle Job) that calculates `END_TIMESTAMP` dynamically using a JavaScript step or a SQL query, then passes it to this transformation via Set Variables.

3. Click **OK** to save the step configuration
4. Save the transformation (**Ctrl+S**)

### Step 4: Create Child Transformation

1. **File --> New --> Transformation**
2. Save as `pageviews-bounded-child.ktr` in the `transformations/` directory

---

#### Step 4a: Get Records from Stream

1. From **Design --> Input**, drag **Get records from stream** onto the canvas
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

1. From **Design --> Input**, drag **JSON Input** onto the canvas
2. Draw a hop from **Get records from stream** --> **JSON Input**
3. Double-click JSON Input to configure:

**Source tab** (main settings):

| Setting | Value |
|---------|-------|
| Source is a field | Checked |
| Get source from field | `message` |
| Ignore missing path | Yes |
| Default path leaf to null | Yes |

**Fields tab** --- click **+** to add each field:

| Name | Path | Type | Format | Length | Precision | Trim |
|------|------|------|--------|--------|-----------|------|
| `userid` | `$.userid` | String | | -1 | -1 | none |
| `pageid` | `$.pageid` | String | | -1 | -1 | none |
| `viewtime` | `$.viewtime` | Integer | | -1 | -1 | none |

> **Note on JSON paths**: The `$.fieldname` syntax is standard JSONPath. Since the datagen produces flat JSON, the path is simply `$.` followed by the field name.
>
> **Pageview fields**: Unlike user events (Scenario 1), pageview messages have only three fields: `viewtime`, `userid`, and `pageid`. The `viewtime` field is an epoch millisecond timestamp representing when the page was viewed.

---

#### Step 4c: Filter Rows (Optional Time Filtering)

While the Offset Settings tab handles the **end boundary** at the Kafka level, you may also want to filter by **start time** or by the **payload timestamp** (`viewtime`) rather than the Kafka broker timestamp. This step provides that additional precision.

1. From **Design --> Flow**, drag **Filter rows** onto the canvas
2. Draw a hop from **JSON Input** --> **Filter rows**
3. Double-click to configure:

**Condition**:

| Field | Condition | Value |
|-------|-----------|-------|
| `viewtime` | `>=` | `${START_TIMESTAMP_EPOCH}` |

> **When to use Filter rows**: The Offset Settings tab stops at an end timestamp, but messages near the boundary may have been produced out of order. Filter rows lets you apply precise filtering on the payload's `viewtime` field. It also allows filtering by a **start** time, which the Offset Settings tab does not support.
>
> **This step is optional**: If you trust the Kafka broker timestamps and only need an end boundary, you can skip this step and draw the hop directly from JSON Input to Select values.
>
> **Variable for start time**: If you use this filter, add `START_TIMESTAMP_EPOCH` as another parameter in the transformation properties. Set it to an epoch millisecond value (e.g., `1708000000000`). For "last 1 hour" processing, calculate: `current_epoch_ms - 3600000`.

4. When prompted for the hop type, select:
   - **True** path --> goes to **Select values** (records that pass the filter)
   - Create a second hop for the **False** path --> either discard (add a **Dummy** step) or log

> **Tip**: If you skip the Filter rows step, simply draw a hop from **JSON Input** directly to **Select values**.

---

#### Step 4d: Select Values

1. From **Design --> Transform**, drag **Select values** onto the canvas
2. Draw a hop from **Filter rows** (true path) --> **Select values** (or from **JSON Input** if skipping the filter)
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
| `pageid` | `page_url` | | |
| `viewtime` | `view_timestamp_epoch` | | |

> Leave "Rename to" blank to keep the original name. Leave Length and Precision blank in this tab.
>
> **Why rename `pageid` to `page_url`?** The datagen produces a `pageid` field (e.g., `Page_42`), but the database schema uses `page_url VARCHAR(500)` to accommodate full URLs in production. We map the page identifier into this column.

##### Meta-data Tab

This tab sets the data type and length metadata for each field. **This is critical for MySQL** --- without explicit lengths, PDI maps String fields to `TINYTEXT`, which breaks MySQL indexes and causes errors like:
```
BLOB/TEXT column 'user_id' used in key specification without a key length
```

| Fieldname | Type | Length | Precision |
|-----------|------|--------|-----------|
| `user_id` | String | 100 | |
| `page_url` | String | 500 | |
| `view_timestamp_epoch` | Integer | 15 | |
| `kafka_topic` | String | 255 | |
| `kafka_partition` | Integer | 9 | |
| `kafka_offset` | Integer | 15 | |
| `key` | String | 100 | |
| `message` | String | 5000 | |
| `timestamp` | Integer | 15 | |

> **Why these lengths?** They match the MySQL table column definitions: `user_id VARCHAR(100)`, `page_url VARCHAR(500)`, `kafka_topic VARCHAR(255)`. Setting the correct lengths ensures PDI generates `VARCHAR` instead of `TINYTEXT`.

---

#### Step 4e: Formula

1. From **Design --> Transform**, drag **Formula** onto the canvas
2. Draw a hop from **Select values** --> **Formula**
3. Double-click to configure:

| New field | Formula | Value type | Length | Precision | Replace |
|-----------|---------|------------|--------|-----------|---------|
| `view_timestamp_seconds` | `[view_timestamp_epoch] / 1000` | Integer | -1 | -1 | *(blank)* |

> **What this does**: The datagen produces `viewtime` as epoch milliseconds (e.g., `1708000000000`). MySQL's `TIMESTAMP` column expects epoch seconds, so we divide by 1000 to get `1708000000`.
>
> **Why Formula instead of Calculator?** The Calculator step requires both operands to be existing stream fields --- you cannot enter a literal constant like `1000` as Field B. The Formula step supports inline constants in expressions.

---

#### Step 4f: Generate Session ID (Optional)

The `pageviews` table includes a `session_id` column. Since the datagen does not produce session IDs, you can either leave it NULL or generate one.

To generate a simple session ID:

1. From **Design --> Transform**, drag **Formula** onto the canvas (or add to the existing Formula step)
2. Add a formula row:

| New field | Formula | Value type | Length | Precision | Replace |
|-----------|---------|------------|--------|-----------|---------|
| `session_id` | `[user_id] & "-" & TEXT([view_timestamp_seconds];"0")` | String | -1 | -1 | *(blank)* |

> This creates a session ID like `User_3-1708000000`. In production, session IDs would come from the source system.
>
> **Alternatively**, you can skip this and let the `session_id` column be NULL (the schema allows it).

---

#### Step 4g: Table Output

1. From **Design --> Output**, drag **Table output** onto the canvas
2. Draw a hop from **Formula** --> **Table output**
3. Double-click to configure:

##### Main Settings

| Setting | Value | Notes |
|---------|-------|-------|
| Connection | `warehouse_db` | The MySQL connection from Scenario 1 |
| Target schema | *(leave blank)* | **Important**: Do NOT set this for MySQL |
| Target table | `pageviews` | |
| Commit size | `1000` | |
| Truncate table | No | |
| Ignore insert errors | No | |
| Use batch updates | Yes | |
| Specify database fields | Yes | **Must be Yes** to control field mapping |

> **Critical: Leave Target schema blank.** MySQL uses the database name from the connection, not a separate schema. Setting it causes PDI to qualify the table as `kafka_warehouse.pageviews` which can fail or cause unexpected behavior.

##### Database Fields

Click **Specify database fields: Yes**, then configure the field mapping:

| Database Column | Stream Field |
|-----------------|-------------|
| `user_id` | `user_id` |
| `page_url` | `page_url` |
| `view_timestamp` | `view_timestamp_seconds` |
| `session_id` | `session_id` |
| `kafka_topic` | `kafka_topic` |
| `kafka_partition` | `kafka_partition` |
| `kafka_offset` | `kafka_offset` |

> **Do NOT map these columns** --- MySQL handles them automatically:
> - `pageview_id` --- AUTO_INCREMENT primary key
> - `ingestion_timestamp` --- DEFAULT CURRENT_TIMESTAMP
>
> **If you skipped Step 4f** (session ID generation), remove `session_id` from this mapping or it will insert NULLs (which is acceptable given the schema).

> **Tip**: You can use **Get Fields** button to auto-populate, then remove `pageview_id` and `ingestion_timestamp`, and fix the `view_timestamp` mapping (stream field should be `view_timestamp_seconds`, not `view_timestamp`).

##### SQL Button

When you click **SQL** in the Table output dialog, PDI may suggest ALTER TABLE statements. **Click Close without executing** --- the table already has the correct schema from the Docker init script.

If PDI suggests:
```sql
ALTER TABLE pageviews MODIFY user_id TINYTEXT
```
This means the Meta-data tab in Select values doesn't have the string lengths set. Go back and set them (Step 4d).

---

### Step 5: Verify Hops Are Enabled

Before running, check that all hops (arrows between steps) are **solid lines**, not dashed grey. Dashed hops are disabled.

If any hop is dashed:
- Right-click the hop --> **Enable hop**
- Or hold **Shift** and click the hop

The complete flow should be (with optional Filter rows):
```
Get records from stream --> JSON Input --> Filter rows --> Select values --> Formula --> Table output
```

Or without Filter rows:
```
Get records from stream --> JSON Input --> Select values --> Formula --> Table output
```

All hops must show as solid lines with arrows.

### Step 6: Set the END_TIMESTAMP and Run

1. Switch to the **parent** transformation (`pageviews-bounded-parent.ktr`)
2. Click **Run** (play button) or press **F9**
3. In the Run dialog, click the **Parameters** tab
4. Set the `END_TIMESTAMP` parameter:

| Parameter | Value | Notes |
|-----------|-------|-------|
| `END_TIMESTAMP` | `2024-02-15 14:00:00` | Set to ~5 minutes from now for testing |

> **Calculate the value**: Look at your current time and add 5 minutes. For example, if it is `2024-02-15 13:55:00`, set `END_TIMESTAMP` to `2024-02-15 14:00:00`. The format must match what you configured in the Offset Settings tab (`yyyy-MM-dd HH:mm:ss`).
>
> **Using epoch milliseconds**: If you left the Timestamp format blank in the Offset Settings tab, provide epoch milliseconds instead (e.g., `1708005600000`).

5. Click **Run**
6. Monitor the **Logging** tab:
   - You should see batch processing messages
   - "Finished processing" messages with `W=N` (rows written) > 0
   - **The transformation will stop automatically** when it reaches the `END_TIMESTAMP`
7. Check the **Step Metrics** tab for throughput numbers

> **Expected behavior**: Unlike Scenarios 1-3, this transformation **will stop on its own**. When the Kafka Consumer encounters a message with a timestamp at or after `END_TIMESTAMP`, it stops reading and the transformation finishes cleanly. You will see a "Transformation finished" message in the log.
>
> **If the transformation does not stop**: Check that:
> - The `END_TIMESTAMP` variable is being substituted (look for the value in the log)
> - The timestamp format matches what you configured in the Offset Settings tab
> - The topic has messages with timestamps reaching your `END_TIMESTAMP` (if the topic only has old data, the consumer may exhaust it before reaching the timestamp)

### Step 7: Verify Data in MySQL

```bash
make mysql-shell
```

Then run these queries:

```sql
-- Check total record count (should be a finite number, not continuously growing)
SELECT COUNT(*) AS total_pageviews FROM pageviews;

-- View sample records
SELECT * FROM pageviews
ORDER BY ingestion_timestamp DESC
LIMIT 10;

-- Verify time boundary: check the range of view timestamps
-- The max should be near your END_TIMESTAMP
SELECT
    MIN(view_timestamp) AS earliest_view,
    MAX(view_timestamp) AS latest_view,
    TIMESTAMPDIFF(MINUTE, MIN(view_timestamp), MAX(view_timestamp)) AS window_minutes,
    COUNT(*) AS total_records
FROM pageviews;

-- Check records per minute to understand the data distribution
SELECT
    DATE_FORMAT(view_timestamp, '%Y-%m-%d %H:%i:00') AS minute,
    COUNT(*) AS pageview_count
FROM pageviews
WHERE view_timestamp IS NOT NULL
GROUP BY minute
ORDER BY minute DESC
LIMIT 20;

-- Check page popularity within the time window
SELECT
    page_url,
    COUNT(*) AS view_count,
    COUNT(DISTINCT user_id) AS unique_users
FROM pageviews
GROUP BY page_url
ORDER BY view_count DESC
LIMIT 10;

-- Check user activity within the time window
SELECT
    user_id,
    COUNT(*) AS total_views,
    COUNT(DISTINCT page_url) AS unique_pages,
    MIN(view_timestamp) AS first_view,
    MAX(view_timestamp) AS last_view
FROM pageviews
GROUP BY user_id
ORDER BY total_views DESC
LIMIT 10;

-- Check for duplicates (should return 0 rows)
SELECT kafka_topic, kafka_partition, kafka_offset, COUNT(*)
FROM pageviews
GROUP BY kafka_topic, kafka_partition, kafka_offset
HAVING COUNT(*) > 1;

-- Check offset progress by partition (shows bounded range)
SELECT
    kafka_partition,
    MIN(kafka_offset) AS min_offset,
    MAX(kafka_offset) AS max_offset,
    MAX(kafka_offset) - MIN(kafka_offset) + 1 AS offset_range,
    COUNT(*) AS record_count
FROM pageviews
GROUP BY kafka_partition
ORDER BY kafka_partition;

-- Verify the data window is bounded (not continuously growing)
-- Run this query, wait 30 seconds, run again -- count should NOT increase
SELECT
    COUNT(*) AS total_records,
    MAX(ingestion_timestamp) AS last_ingestion
FROM pageviews;

-- Check ingestion health (uses built-in stored procedure)
CALL sp_check_ingestion_health();
```

> **Key verification**: Run the last query twice with a 30-second gap. Because the transformation has stopped, the count should remain the same. This confirms bounded processing worked correctly.

---

## Advanced: Dynamic Time Windows

### "Process Last 1 Hour" Pattern

In production, you would not hardcode the `END_TIMESTAMP`. Instead, use a wrapper transformation or job to calculate it dynamically.

**Option 1: Kettle Properties File**

Edit `~/.kettle/kettle.properties`:
```properties
END_TIMESTAMP=2024-02-15 14:00:00
START_TIMESTAMP_EPOCH=1708000000000
```

PDI reads these at startup. To update, edit the file and restart Spoon (or use the `Set Variables` approach below).

**Option 2: Set Variables Step in a Wrapper Transformation**

Create a wrapper transformation that:

1. Uses a **Get System Info** step to get the current date/time
2. Uses a **Calculator** step to subtract 1 hour (for start) and use current time (for end)
3. Uses a **Set Variables** step to set `END_TIMESTAMP` and `START_TIMESTAMP_EPOCH`
4. The Kafka Consumer parent transformation reads these variables

**Wrapper flow**:
```
Get System Info --> Calculator (now - 1 hour) --> Set Variables
```

**Set Variables configuration**:

| Field | Variable Name | Variable Scope |
|-------|---------------|----------------|
| `end_time` | `END_TIMESTAMP` | Valid in the Java Virtual Machine |
| `start_epoch` | `START_TIMESTAMP_EPOCH` | Valid in the Java Virtual Machine |

**Option 3: Command-Line Parameters**

Run the transformation from the command line with parameters:
```bash
pan.sh -file=pageviews-bounded-parent.ktr \
  -param:END_TIMESTAMP="$(date -d '+0 hours' '+%Y-%m-%d %H:%M:%S')" \
  -param:START_TIMESTAMP_EPOCH="$(date -d '-1 hour' '+%s')000"
```

> **Scheduling**: Combine Option 3 with cron or a PDI Job scheduler to run bounded retrieval on a schedule (e.g., every hour, processing the previous hour's data).

---

## Debugging

### Common Errors and Fixes

#### Transformation Never Stops

| Possible Cause | How to Identify | Fix |
|---------------|----------------|-----|
| `END_TIMESTAMP` not set | Log shows `${END_TIMESTAMP}` literally | Set the parameter in Run dialog or kettle.properties |
| Wrong timestamp format | Log shows parse errors | Match the format in Offset Settings to your value |
| Topic has no messages at that timestamp | Consumer exhausts topic and waits | Check topic has data: `make consume-pageviews` |
| Timestamp is in the far future | Transformation runs indefinitely | Set a nearer timestamp for testing |

#### Transformation Stops Immediately

| Possible Cause | How to Identify | Fix |
|---------------|----------------|-----|
| `END_TIMESTAMP` is in the past | 0 records processed | Set to a future timestamp |
| `auto.offset.reset` is `latest` | Consumer starts at end, immediately at/past timestamp | Change to `earliest` |
| Consumer group already past the timestamp | Committed offset is beyond end | Use a new consumer group name or reset offsets |

#### "Error in sub-transformation"

This generic error wraps the actual child transformation failure. Check the Logging tab for the real cause:

| Root Cause | How to Identify | Fix |
|-----------|----------------|-----|
| Disabled hops | Steps show 0 rows written | Right-click hop --> Enable hop |
| Missing connection | "Unknown database connection" | Create `warehouse_db` in parent transformation |
| Wrong sub-transformation path | "Unable to load transformation" | Use Browse button to set correct path |
| Schema field set | `kafka_warehouse.pageviews` in error | Clear Target schema in Table output |

#### "BLOB/TEXT column used in key specification without a key length"

PDI is trying to ALTER the table with `TINYTEXT` columns. This happens when string fields don't have lengths set.

**Fix**: Set field lengths in the Select values **Meta-data** tab (see [Step 4d](#step-4d-select-values)).

**Workaround**: When PDI shows the SQL editor dialog, click **Close** without executing.

#### "Table not found" or wrong table qualification

If the error references `kafka_warehouse.pageviews` instead of just `pageviews`:

**Fix**: Clear the **Target schema** field in Table output (leave it blank).

#### No data written (W=0)

1. Check consumer is receiving messages: `I=N` should be > 0
2. Check JSON Input is parsing: Step Metrics should show rows flowing through
3. If using Filter rows, check that the condition is not filtering everything out
4. Check Table output connection is valid: test `warehouse_db` connection
5. Check all hops are enabled (solid lines, not dashed)

#### Duplicate records

The `pageviews` table has a `UNIQUE KEY` on `(kafka_topic, kafka_partition, kafka_offset)`. If you see duplicate key errors:

1. Table output with "Ignore insert errors: No" will fail on duplicates --- set to Yes, or
2. Use **Insert/Update** step instead (recommended for idempotency):
   - Keys: `kafka_topic`, `kafka_partition`, `kafka_offset`
   - Don't perform any updates: Yes

---

## Database Table Reference

The `pageviews` table (created by `sql/01-create-database-mysql-docker.sql`):

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

## Summary

After completing this scenario, you have:

- A parent transformation that reads from `pdi-pageviews` and **stops automatically** at a configurable timestamp
- A child transformation that parses JSON, optionally filters by time, renames fields, converts timestamps, and writes to MySQL
- Understanding of the Kafka Consumer EE Offset Settings tab for time-bounded consumption
- Experience with PDI variables (`${END_TIMESTAMP}`) for dynamic configuration
- Knowledge of three approaches for dynamic time windows (kettle.properties, Set Variables, command-line parameters)
- Idempotent processing via the UNIQUE KEY on Kafka coordinates
- A bounded dataset in your `pageviews` table representing a specific time window

**Previous**: [Scenario 3: Multi-Topic Correlation](scenario-3-multi-topic.md)

**Next**: [Scenario 5: Error Handling and Dead Letter Queues](scenario-5-error-handling.md)

---

**Related Documentation**:
- [Transformations README](../../transformations/README.md) --- Template configuration details
- [Workshop Guide --- PDI Kafka Consumer Configuration](../WORKSHOP-GUIDE.md#pdi-kafka-consumer-configuration) --- All 6 configuration tabs
- [Workshop Guide --- Kafka to Data Warehouse](../WORKSHOP-GUIDE.md#kafka-to-data-warehouse) --- Architecture patterns
- [Scenario 1: User Activity](scenario-1-user-activity.md) --- Basic Kafka Consumer setup and database connection
