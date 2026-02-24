# Scenario 5: Multi-Topic Consumer with Kafka Producer

**Business Use Case**: Consume user registration and purchase events from two separate Kafka topics, enrich purchase records with user data in real-time, and produce the enriched results to a new output topic for downstream consumers.

**Difficulty**: Advanced | **Duration**: 60-90 minutes

## Learning Objectives

- Subscribe to multiple Kafka topics using comma-separated topic names
- Use the `topic` field from Kafka Consumer to identify message origin
- Route messages by topic name using the Switch/Case step
- Cache user data with Combination lookup/update for stream enrichment
- Enrich purchase records with user data using Stream lookup
- Serialize enriched records to JSON using JSON Output step
- Configure a Kafka Producer step to publish enriched messages to an output topic
- Verify end-to-end pipeline by consuming from the output topic

## Prerequisites

Before starting this scenario:

1. Workshop environment is running — `make workshop-start`
2. MySQL is running with tables created — `make mysql-verify`
3. Data is flowing into `pdi-users` topic — `make consume-users`
4. Data is flowing into `pdi-purchases` topic — verify with:
   ```bash
   docker exec kafka-1 kafka-console-consumer \
     --bootstrap-server localhost:9092 \
     --topic pdi-purchases --from-beginning --max-messages 5
   ```
5. PDI (Spoon) is open with Kafka EE plugin installed
6. `warehouse_db` database connection is configured in Spoon (see [Scenario 1, Step 2](scenario-1-user-activity.md#step-2-create-database-connection-in-spoon))
7. Familiarity with Scenarios 1-4 is strongly recommended — this scenario builds on all prior concepts

## Architecture

```
Parent Transformation (Kafka Consumer Step)
    | (batches from BOTH pdi-users AND pdi-purchases)
    v
Child Transformation
    Get records from stream
        |
    JSON Input (parse message field — works for both schemas)
        |
    Switch / Case (route by "topic" field)
       /                          \
      v                            v
  [pdi-users branch]          [pdi-purchases branch]
  JSON Input (user fields)    JSON Input (purchase fields)
      |                            |
  Combination lookup/update   Stream lookup (enrich with user data)
  (cache user data)                |
                              JSON Output (serialize enriched record)
                                   |
                              Kafka Producer (write to pdi-enriched-purchases)
```

> **Why two JSON Input steps?** The messages from `pdi-users` and `pdi-purchases` have completely different JSON schemas. The first JSON Input extracts a common field for routing. The branch-specific JSON Input steps parse the full schema for each topic. Alternatively, you can parse all fields from both schemas in a single JSON Input with "Ignore missing path" enabled — fields not present in a message will be null.

## Data Sources

This scenario consumes from **two** topics simultaneously.

### Topic 1: `pdi-users`

User registration events at ~1 message/second.

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
| `gender` | String | Gender (`MALE`, `FEMALE`, or `OTHER`) |

### Topic 2: `pdi-purchases`

E-commerce purchase events at ~2 messages/second.

**Sample message**:
```json
{"order_id":1000,"product_id":"Product_42","price":125.99,"quantity":2,"customer_id":"Customer_123","timestamp":1708538400000}
```

**Field descriptions**:

| JSON Field | Type | Description |
|-----------|------|-------------|
| `order_id` | Long | Order identifier |
| `product_id` | String | Product identifier (e.g., `Product_42`) |
| `price` | Number | Unit price |
| `quantity` | Integer | Quantity purchased |
| `customer_id` | String | Customer identifier (e.g., `Customer_123`) |
| `timestamp` | Long | Purchase timestamp (epoch milliseconds) |

### Output Topic: `pdi-enriched-purchases`

This topic does not exist yet. The Kafka Producer step will auto-create it (if `auto.create.topics.enable` is true on the broker), or you can create it manually:

```bash
docker exec kafka-1 kafka-topics \
  --bootstrap-server localhost:9092 \
  --create --topic pdi-enriched-purchases \
  --partitions 3 --replication-factor 3
```

**Enriched message** (what we will produce):
```json
{
  "order_id": 1000,
  "product_id": "Product_42",
  "price": 125.99,
  "quantity": 2,
  "total_amount": 251.98,
  "customer_id": "Customer_123",
  "customer_region": "Region_9",
  "customer_gender": "MALE",
  "purchase_timestamp": 1708538400000
}
```

---

## Step-by-Step Instructions

### Step 1: Verify Data is Flowing on Both Topics

```bash
make consume-users
```

You should see JSON user registration messages. Then verify purchases:

```bash
docker exec kafka-1 kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic pdi-purchases --from-beginning --max-messages 5
```

You should see JSON purchase messages. If either topic is empty, deploy connectors first: `make deploy-connectors`

### Step 2: Create the Output Topic

Create the `pdi-enriched-purchases` topic before running the pipeline. While auto-creation may work, explicitly creating the topic gives you control over partition count and replication:

```bash
docker exec kafka-1 kafka-topics \
  --bootstrap-server localhost:9092 \
  --create --topic pdi-enriched-purchases \
  --partitions 3 --replication-factor 3
```

Verify the topic was created:

```bash
docker exec kafka-1 kafka-topics \
  --bootstrap-server localhost:9092 \
  --describe --topic pdi-enriched-purchases
```

### Step 3: Create Parent Transformation

1. **File -> New -> Transformation**
2. Save as `enrichment-pipeline-parent.ktr` in the `transformations/` directory

#### Add Kafka Consumer Step

1. From the **Design** panel, expand **Input** -> drag **Kafka Consumer** onto the canvas
2. Double-click the Kafka Consumer step to configure:

#### Setup Tab

| Setting | Value | Notes |
|---------|-------|-------|
| Connection | Direct | |
| Bootstrap Servers | `localhost:9092` | External Kafka broker address |
| Topics | `pdi-users,pdi-purchases` | **Comma-separated** — both topics |
| Consumer Group | `pdi-enrichment-pipeline` | Unique name for this transformation |
| Sub-transformation | `[path]/transformations/enrichment-pipeline-child.ktr` | Use Browse button to select |

> **Multi-topic subscription**: Enter topic names separated by commas with **no spaces**: `pdi-users,pdi-purchases`. PDI will consume from both topics into the same stream. Each message carries a `topic` field that tells you which topic it came from — this is how you route messages in the child transformation.

#### Batch Tab

| Setting | Value | Notes |
|---------|-------|-------|
| Duration (ms) | `5000` | Collect records for 5 seconds |
| Number of records | `200` | Or until 200 records arrive |
| Maximum concurrent batches | `1` | Start with 1 for this scenario |
| Message prefetch limit | `100000` | Default is fine |
| Offset commit | When batch completes | At-least-once delivery (recommended) |

> **Why 200 records?** With two topics producing ~3 messages/second combined (`pdi-users` at ~1/sec and `pdi-purchases` at ~2/sec), the 5-second duration will usually trigger first, sending ~15 records per batch. The 200-record limit is a safety cap for bursts.

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

> **The `topic` field is critical** in this scenario. When consuming from multiple topics, this field contains the topic name (e.g., `pdi-users` or `pdi-purchases`) for each message. You will use this field in the Switch/Case step to route messages to the correct processing branch.

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
2. Save as `enrichment-pipeline-child.ktr` in the `transformations/` directory

This child transformation is significantly more complex than previous scenarios. It contains two processing branches that converge at the Kafka Producer. Build it step by step, testing as you go.

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

#### Step 4b: Switch / Case (Route by Topic)

1. From **Design -> Flow**, drag **Switch / Case** onto the canvas
2. Draw a hop from **Get records from stream** -> **Switch / Case**
3. Double-click Switch / Case to configure:

**Main settings**:

| Setting | Value |
|---------|-------|
| Field name | `topic` |
| Use string contains comparison | No |
| Case value data type | String |

**Case values** — add two rows:

| Value | Target step |
|-------|-------------|
| `pdi-users` | `JSON Input - Users` |
| `pdi-purchases` | `JSON Input - Purchases` |

**Default target step**: *(leave blank or set to a Dummy step)*

> **How Switch/Case works**: For each incoming row, PDI reads the value of the `topic` field and routes the entire row to the matching target step. Messages from `pdi-users` go to the Users branch; messages from `pdi-purchases` go to the Purchases branch. Any messages from unexpected topics go to the default target (if configured).

> **Important**: You need to create the target steps (JSON Input - Users and JSON Input - Purchases) **before** you can select them here. You can either create the steps first and come back to configure Switch/Case, or type the step names manually and create matching steps afterward.

---

#### Step 4c: JSON Input - Users (Branch 1)

1. From **Design -> Input**, drag **JSON Input** onto the canvas
2. Rename it to `JSON Input - Users` (right-click -> Edit step name, or double-click and change the Step name field)
3. Draw a hop from **Switch / Case** -> **JSON Input - Users**
   - When PDI asks "Is this the main path?", click **Yes**
4. Double-click JSON Input - Users to configure:

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

---

#### Step 4d: Combination Lookup/Update (Cache User Data)

The Combination lookup/update step is used here to **cache user data** in a MySQL dimension table so that the purchases branch can look up user information. Each user record is inserted (or looked up) in the database, creating a persistent store of user-to-region/gender mappings.

1. From **Design -> Data Warehouse**, drag **Combination lookup/update** onto the canvas
2. Draw a hop from **JSON Input - Users** -> **Combination lookup/update**
3. Double-click to configure:

| Setting | Value | Notes |
|---------|-------|-------|
| Connection | `warehouse_db` | The MySQL connection |
| Target schema | *(leave blank)* | Do not set for MySQL |
| Target table | `dim_user_cache` | We will create this table |
| Technical key field | `user_key` | Auto-generated surrogate key |
| Technical key creation | Use auto increment field | |
| Replace fields in table | Yes | Update region/gender if changed |

**Key Fields** (used to look up existing records):

| Field | Lookup | |
|-------|--------|-|
| `userid` | `user_id` | |

**Fields to update** (stored alongside the key):

| Field | Lookup |
|-------|--------|
| `regionid` | `region_id` |
| `gender` | `gender` |

> **Why Combination lookup/update?** This step acts as a mini dimension table. When a user record arrives, it checks if `userid` already exists in `dim_user_cache`. If yes, it returns the existing `user_key` and optionally updates the region/gender. If no, it inserts a new row. This creates a persistent cache that the purchases branch can query.

**Create the cache table first**. Connect to MySQL and run:

```bash
make mysql-shell
```

```sql
CREATE TABLE IF NOT EXISTS dim_user_cache (
    user_key BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id VARCHAR(100) NOT NULL,
    region_id VARCHAR(100),
    gender VARCHAR(20),
    UNIQUE KEY uq_user_id (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='User dimension cache for stream enrichment';
```

> **Alternative approach — Memory Group By**: Instead of a database table, you can use a **Memory Group By** step to cache user data in memory. This is faster but volatile — if you restart the transformation, the cache is empty until user records arrive again. The database approach is more resilient because the cache persists across restarts.

---

#### Step 4e: JSON Input - Purchases (Branch 2)

1. From **Design -> Input**, drag another **JSON Input** onto the canvas
2. Rename it to `JSON Input - Purchases`
3. Draw a hop from **Switch / Case** -> **JSON Input - Purchases**
   - When PDI asks "Is this the main path?", click **Yes**
4. Double-click JSON Input - Purchases to configure:

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
| `order_id` | `$.order_id` | Integer | | -1 | -1 | none |
| `product_id` | `$.product_id` | String | | -1 | -1 | none |
| `price` | `$.price` | Number | | -1 | 2 | none |
| `quantity` | `$.quantity` | Integer | | -1 | -1 | none |
| `customer_id` | `$.customer_id` | String | | -1 | -1 | none |
| `purchase_timestamp` | `$.timestamp` | Integer | | -1 | -1 | none |

> **Note**: The JSON field is named `timestamp` but we rename it to `purchase_timestamp` in the Name column to avoid collision with the Kafka metadata `timestamp` field already in the stream.

---

#### Step 4f: Calculator (Compute Total Amount)

1. From **Design -> Transform**, drag **Calculator** onto the canvas
2. Draw a hop from **JSON Input - Purchases** -> **Calculator**
3. Double-click to configure:

| New field | Calculation | Field A | Field B | Value type | Length | Precision | Remove |
|-----------|------------|---------|---------|------------|--------|-----------|--------|
| `total_amount` | A * B | `price` | `quantity` | Number | -1 | 2 | No |

> **Why Calculator works here**: Both `price` and `quantity` are existing stream fields, so Calculator can multiply them directly. Unlike the Formula step (which supports inline constants), Calculator requires both operands to be stream fields — and they are.

---

#### Step 4g: Database Lookup (Enrich with User Data)

This step looks up the user's region and gender from the `dim_user_cache` table based on the `customer_id` from the purchase record.

1. From **Design -> Lookup**, drag **Database lookup** onto the canvas
2. Draw a hop from **Calculator** -> **Database lookup**
3. Double-click to configure:

| Setting | Value | Notes |
|---------|-------|-------|
| Connection | `warehouse_db` | |
| Lookup schema | *(leave blank)* | Do not set for MySQL |
| Lookup table | `dim_user_cache` | The table populated by the Users branch |
| Enable cache | Yes | Cache lookups in memory for performance |
| Cache size (rows) | `5000` | Adjust based on expected unique users |
| Fail on multiple results | No | |

**Keys** (how to find the matching user):

| Stream Field | Comparator | Table Field |
|-------------|------------|-------------|
| `customer_id` | `=` | `user_id` |

**Return values** (what to retrieve):

| Field | Rename to | Default | Type |
|-------|-----------|---------|------|
| `region_id` | `customer_region` | *(blank)* | String |
| `gender` | `customer_gender` | *(blank)* | String |

> **Timing consideration**: The `customer_id` in purchase messages (e.g., `Customer_123`) may not match any `userid` from the users topic (e.g., `User_1`) because the datagen connectors generate independent data. In a real scenario, these would share a common identifier. For this workshop exercise, the lookup will return null for unmatched records, and that is expected behavior. The purpose is to learn the enrichment pattern.
>
> **To see matched results**: You can manually insert matching records into `dim_user_cache`:
> ```sql
> INSERT IGNORE INTO dim_user_cache (user_id, region_id, gender)
> VALUES ('Customer_123', 'Region_5', 'MALE'),
>        ('Customer_456', 'Region_2', 'FEMALE'),
>        ('Customer_789', 'Region_7', 'OTHER');
> ```

---

#### Step 4h: Select Values (Prepare Output Fields)

1. From **Design -> Transform**, drag **Select values** onto the canvas
2. Draw a hop from **Database lookup** -> **Select values**
3. Double-click to configure:

##### Select & Alter Tab

Select only the fields to include in the enriched output message:

| Fieldname | Rename to | Length | Precision |
|-----------|-----------|--------|-----------|
| `order_id` | | | |
| `product_id` | | | |
| `price` | | | |
| `quantity` | | | |
| `total_amount` | | | |
| `customer_id` | | | |
| `customer_region` | | | |
| `customer_gender` | | | |
| `purchase_timestamp` | | | |

> Leave "Rename to" blank to keep the original name. This step also **removes** all fields not listed (like `key`, `message`, `topic`, `partition`, `offset`, `timestamp`) which are Kafka metadata fields we do not want in the output JSON.

##### Meta-data Tab

| Fieldname | Type | Length | Precision |
|-----------|------|--------|-----------|
| `order_id` | Integer | 15 | |
| `product_id` | String | 100 | |
| `price` | Number | 10 | 2 |
| `quantity` | Integer | 9 | |
| `total_amount` | Number | 10 | 2 |
| `customer_id` | String | 100 | |
| `customer_region` | String | 100 | |
| `customer_gender` | String | 20 | |
| `purchase_timestamp` | Integer | 15 | |

---

#### Step 4i: JSON Output (Serialize Enriched Record)

1. From **Design -> Output**, drag **JSON Output** onto the canvas
2. Draw a hop from **Select values** -> **JSON Output**
3. Double-click to configure:

**General tab**:

| Setting | Value | Notes |
|---------|-------|-------|
| Operation | Output value | Outputs JSON to a field (not a file) |
| Output Value | `json_output` | Name of the field that will contain the JSON string |
| Nr. rows in a block | `1` | One JSON object per row |
| JSON Bloc name | *(leave blank)* | No wrapper element |

> **Operation: "Output value"** is the key setting. This tells the JSON Output step to write the serialized JSON into a new stream field called `json_output` rather than writing to a file on disk. The Kafka Producer will then read from this field.

**Fields tab** — click **Get Fields** to auto-populate, or manually add:

| Fieldname | Element name |
|-----------|-------------|
| `order_id` | `order_id` |
| `product_id` | `product_id` |
| `price` | `price` |
| `quantity` | `quantity` |
| `total_amount` | `total_amount` |
| `customer_id` | `customer_id` |
| `customer_region` | `customer_region` |
| `customer_gender` | `customer_gender` |
| `purchase_timestamp` | `purchase_timestamp` |

> The **Element name** column controls the JSON key names. If you want different key names in the JSON output (e.g., `customerId` instead of `customer_id`), change the Element name.

---

#### Step 4j: Kafka Producer (Write to Output Topic)

1. From **Design -> Output**, drag **Kafka Producer** onto the canvas
2. Draw a hop from **JSON Output** -> **Kafka Producer**
3. Double-click the Kafka Producer step to configure:

##### Setup Tab

| Setting | Value | Notes |
|---------|-------|-------|
| Connection | Direct | |
| Bootstrap Servers | `localhost:9092` | Same Kafka cluster |
| Client ID | `pdi-enrichment-producer` | Descriptive identifier for monitoring |
| Topic | `pdi-enriched-purchases` | Destination topic |

> **Client ID** appears in Kafka broker logs, consumer group descriptions, and Control Center. Use a descriptive name so you can identify this producer when monitoring.

##### Fields Tab

| Setting | Value | Notes |
|---------|-------|-------|
| Message field | `json_output` | The field from JSON Output step |
| Key field | `customer_id` | Partitions by customer for ordering |

> **Key field**: Setting `customer_id` as the message key means all purchases for the same customer will be sent to the same partition. This guarantees ordering per customer — downstream consumers will see all of Customer_123's enriched purchases in order. If ordering does not matter, leave the key field blank for round-robin distribution.

##### Options Tab

Click **+** to add each property:

| Property | Value | Notes |
|----------|-------|-------|
| `acks` | `all` | Wait for all in-sync replicas to acknowledge |
| `enable.idempotence` | `true` | Prevent duplicate messages on retry |
| `compression.type` | `snappy` | Good balance of speed and compression |

> **Why these settings?**
> - `acks=all`: Ensures the message is durably written to all in-sync replicas before the producer considers it successful. This is the safest setting for data that should not be lost.
> - `enable.idempotence=true`: The producer assigns a sequence number to each message. If a network error causes a retry, Kafka deduplicates based on the sequence number. Requires `acks=all`.
> - `compression.type=snappy`: Compresses message batches before sending. Snappy is fast with moderate compression — ideal for JSON payloads that compress well.

4. Click **OK** to save the step configuration

---

### Step 5: Verify Hops and Flow

Before running, review the complete child transformation flow:

```
Get records from stream
    |
Switch / Case (route by topic)
   /                          \
  v                            v
JSON Input - Users        JSON Input - Purchases
  |                            |
Combination lookup/update  Calculator (price * quantity)
                               |
                           Database lookup (enrich with user data)
                               |
                           Select values (pick output fields)
                               |
                           JSON Output (serialize to json_output field)
                               |
                           Kafka Producer (write to pdi-enriched-purchases)
```

Check that:
- All hops (arrows between steps) are **solid lines**, not dashed grey
- The Switch/Case step has two outgoing hops — one to each branch
- The Users branch terminates at the Combination lookup/update step (no further output needed)
- The Purchases branch flows all the way through to the Kafka Producer

If any hop is dashed:
- Right-click the hop -> **Enable hop**
- Or hold **Shift** and click the hop

### Step 6: Run the Transformation

1. Switch to the **parent** transformation (`enrichment-pipeline-parent.ktr`)
2. Click **Run** (play button) or press **F9**
3. In the Run dialog, click **Run**
4. Monitor the **Logging** tab:
   - You should see batch processing messages from both topics
   - "Finished processing" messages with `W=N` (rows written) > 0
   - Watch for any error messages — address them before continuing
5. Check the **Step Metrics** tab:
   - **Get records from stream**: Should show rows being read (I > 0)
   - **Switch / Case**: Should show rows being distributed to both branches
   - **JSON Input - Users**: Should show user records being parsed
   - **JSON Input - Purchases**: Should show purchase records being parsed
   - **Kafka Producer**: Should show rows written (W > 0)

The transformation runs continuously. Let it run for at least 30 seconds to populate the user cache and produce enriched messages.

> **If you see "Error in sub-transformation"**: Check the Logging tab for the actual error. Common causes:
> - Missing `dim_user_cache` table (Step 4d)
> - Disabled hops (Step 5)
> - Missing `warehouse_db` connection
> - Incorrect sub-transformation path (Step 3)
> - `pdi-enriched-purchases` topic does not exist and auto-creation is disabled (Step 2)

### Step 7: Verify Enriched Messages on Output Topic

While the parent transformation is still running (or after stopping it), consume from the output topic to see the enriched messages:

```bash
docker exec kafka-1 kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic pdi-enriched-purchases \
  --from-beginning --max-messages 10
```

You should see enriched JSON messages like:

```json
{"order_id":1042,"product_id":"Product_18","price":49.95,"quantity":3,"total_amount":149.85,"customer_id":"Customer_456","customer_region":"Region_2","customer_gender":"FEMALE","purchase_timestamp":1708538460000}
```

> **If `customer_region` and `customer_gender` are null**: This is expected if the `customer_id` values in purchase messages do not match any `userid` values from the users topic. See the note in Step 4g about inserting test data into `dim_user_cache`. In a production system, users and purchases would share a common customer identifier.

### Step 8: Verify User Cache in MySQL

```bash
make mysql-shell
```

Then run these queries:

```sql
-- Check that user records are being cached
SELECT COUNT(*) FROM dim_user_cache;

-- View cached users
SELECT * FROM dim_user_cache
ORDER BY user_key DESC
LIMIT 10;

-- Check for a specific user
SELECT * FROM dim_user_cache WHERE user_id = 'User_1';
```

### Step 9: Monitor the Pipeline in Control Center

Open http://localhost:9021 in your browser:

1. Navigate to **Topics** -> `pdi-enriched-purchases`
   - Check the **Messages** tab to see enriched records flowing in
   - Check the **Partitions** tab to see message distribution across partitions
2. Navigate to **Consumers** -> `pdi-enrichment-pipeline`
   - Check **Consumer lag** — this should stay low if the pipeline is keeping up
   - You should see the consumer subscribed to both `pdi-users` and `pdi-purchases`

### Step 10: Advanced Verification Queries

Consume enriched messages with keys visible to verify partitioning:

```bash
docker exec kafka-1 kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic pdi-enriched-purchases \
  --from-beginning --max-messages 10 \
  --property print.key=true \
  --property key.separator=" | "
```

You should see output like:
```
Customer_123 | {"order_id":1000,"product_id":"Product_42",...}
Customer_456 | {"order_id":1001,"product_id":"Product_18",...}
```

Check the consumer group lag:

```bash
docker exec kafka-1 kafka-consumer-groups \
  --bootstrap-server localhost:9092 \
  --group pdi-enrichment-pipeline \
  --describe
```

This shows the current offset, log-end offset, and lag for each partition of both input topics.

---

## Debugging

### Debug the Child Transformation Step by Step

Because this is a complex transformation with two branches, you may want to test each branch independently before connecting them.

#### Test the Users Branch Only

1. In the Switch/Case step, temporarily remove the `pdi-purchases` case (or disable the hop to JSON Input - Purchases)
2. Change the parent's Topics field to `pdi-users` only
3. Run the transformation and verify that `dim_user_cache` is being populated
4. Restore the full configuration

#### Test the Purchases Branch Only

1. Ensure `dim_user_cache` has some records (from the Users branch test or manual inserts)
2. In the Switch/Case step, temporarily remove the `pdi-users` case (or disable the hop to JSON Input - Users)
3. Change the parent's Topics field to `pdi-purchases` only
4. Add a temporary **Text file output** step after Select values to inspect the enriched data before it reaches the Kafka Producer
5. Run and check the output file
6. Restore the full configuration

#### Inspect Stream Data with Dummy Steps

You can add **Dummy (do nothing)** steps at any point in the flow and use PDI's **Preview** feature:

1. Right-click a Dummy step -> **Preview rows**
2. This shows you exactly what data is flowing through that point

### Common Errors and Fixes

#### "Error in sub-transformation"

This generic error wraps the actual child transformation failure. Check the Logging tab for the real cause:

| Root Cause | How to Identify | Fix |
|-----------|----------------|-----|
| Missing dim_user_cache table | "Table doesn't exist" | Run the CREATE TABLE SQL from Step 4d |
| Disabled hops | Steps show 0 rows written | Right-click hop -> Enable hop |
| Missing connection | "Unknown database connection" | Create `warehouse_db` in parent transformation |
| Wrong sub-transformation path | "Unable to load transformation" | Use Browse button to set correct path |
| Missing output topic | Kafka Producer error in logs | Create topic manually (Step 2) |

#### Switch/Case Not Routing Correctly

If all messages go to the default target or one branch gets no data:

1. Check the **Field name** is set to `topic` (not `message` or `key`)
2. Check the **Case values** match exactly: `pdi-users` and `pdi-purchases` (case-sensitive, no spaces)
3. Check the **Case value data type** is set to `String`
4. Verify data is flowing from both topics by checking the parent's Logging tab

#### JSON Input Parse Errors

If JSON Input shows errors but the step still processes some rows:

1. Check that each branch's JSON Input only parses fields from its own schema
2. Enable **Ignore missing path** in the Source tab
3. Ensure the `message` field is being passed through (check Get records from stream)

#### Kafka Producer Errors

| Error | Cause | Fix |
|-------|-------|-----|
| "Topic not found" | Output topic does not exist | Create it manually (Step 2) |
| "TimeoutException" | Cannot reach broker | Verify `localhost:9092` is accessible |
| "RecordTooLargeException" | Message exceeds max size | Check JSON Output is producing single objects, not arrays |
| No rows written | No data reaching Kafka Producer | Check all upstream hops are enabled and carrying data |

#### Combination Lookup Errors

| Error | Cause | Fix |
|-------|-------|-----|
| "Table doesn't exist" | dim_user_cache not created | Run the CREATE TABLE SQL from Step 4d |
| "Duplicate entry" | Concurrent inserts | Ensure UNIQUE KEY is on `user_id` |
| Schema field set | Table qualified incorrectly | Clear Target schema (leave blank) |

#### No Data Written (W=0) on Kafka Producer

1. Check that the Purchases branch is receiving data: Step Metrics for JSON Input - Purchases should show I > 0
2. Check Calculator is producing output: Step Metrics should show W > 0
3. Check Database lookup is not erroring: Look for error rows in Step Metrics
4. Check Select values is passing all required fields
5. Check JSON Output is producing the `json_output` field
6. Check Kafka Producer has the correct message field name (`json_output`)

---

## Database Table Reference

The `dim_user_cache` table (created manually in Step 4d):

```sql
CREATE TABLE IF NOT EXISTS dim_user_cache (
    user_key BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id VARCHAR(100) NOT NULL,
    region_id VARCHAR(100),
    gender VARCHAR(20),
    UNIQUE KEY uq_user_id (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='User dimension cache for stream enrichment';
```

The `purchases` table (already exists from `sql/01-create-database-mysql-docker.sql`):

```sql
CREATE TABLE IF NOT EXISTS purchases (
    purchase_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    order_id BIGINT,
    product_id VARCHAR(100),
    customer_id VARCHAR(100),
    price DECIMAL(10,2),
    quantity INT,
    total_amount DECIMAL(10,2),
    purchase_timestamp TIMESTAMP NULL,
    kafka_topic VARCHAR(255),
    kafka_partition INT,
    kafka_offset BIGINT,
    ingestion_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_customer_id (customer_id),
    INDEX idx_product_id (product_id),
    INDEX idx_purchase_timestamp (purchase_timestamp),
    INDEX idx_order_id (order_id),
    UNIQUE KEY uq_kafka_offset (kafka_topic, kafka_partition, kafka_offset)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

---

## Key Concepts Introduced

### Multi-Topic Consumption

When you enter comma-separated topics in the Kafka Consumer's Topics field (`pdi-users,pdi-purchases`), PDI subscribes to all listed topics under a single consumer group. Messages from all topics arrive interleaved in the same stream. The `topic` field in each message tells you the source topic.

**Ordering guarantee**: Kafka guarantees ordering within a partition, not across topics. Messages from `pdi-users` partition 0 will be in order relative to each other, but not relative to messages from `pdi-purchases` partition 0.

### Stream Enrichment Pattern

This scenario implements a common stream processing pattern:

1. **Ingest** reference data (users) and cache it
2. **Enrich** transactional data (purchases) by looking up the cached reference data
3. **Produce** the enriched result to a new topic for downstream consumers

This is analogous to a dimension lookup in batch ETL, but operating on streaming data.

### Kafka Consumer + Producer Pipeline

Combining a Kafka Consumer (input) and Kafka Producer (output) in the same transformation creates a **stream processing pipeline**. The input topics are consumed, data is transformed, and results are written to a new topic — all in real-time. Downstream systems can then consume from the enriched topic without needing to know about the original data sources or the enrichment logic.

---

## Summary

After completing this scenario, you have:

- A parent transformation consuming from two topics simultaneously (`pdi-users` and `pdi-purchases`)
- A child transformation that routes messages by topic using Switch/Case
- A Users branch that caches user data in a MySQL dimension table via Combination lookup/update
- A Purchases branch that enriches purchase records with user data via Database lookup
- A Kafka Producer that writes enriched, serialized JSON messages to `pdi-enriched-purchases`
- A complete, real-time stream enrichment pipeline — the most complex pattern in this workshop

**Previous**: [Scenario 4: Time-Bounded Data Retrieval](scenario-4-time-bounded.md)

**Next**: [Scenario 6: Security Implementation (SSL/SASL)](scenario-6-security.md)

---

**Related Documentation**:
- [Transformations README](../../transformations/README.md) — Template configuration details
- [Workshop Guide — PDI Kafka Consumer Configuration](../WORKSHOP-GUIDE.md#pdi-kafka-consumer-configuration) — All 6 configuration tabs
- [Workshop Guide — PDI Kafka Producer Configuration](../WORKSHOP-GUIDE.md#pdi-kafka-producer-configuration) — Producer setup and options
- [Workshop Guide — Kafka to Data Warehouse](../WORKSHOP-GUIDE.md#kafka-to-data-warehouse) — Architecture patterns
