# Workshop 5: Multi-Topic Consumer with Kafka Producer

| | |
|---|---|
| **Scenario** | Stream Enrichment Pipeline — Consume, Enrich, Produce |
| **Difficulty** | Advanced |
| **Duration** | 60–90 minutes |
| **Input Topics** | `pdi-users`, `pdi-purchases` |
| **Output Topic** | `pdi-enriched-purchases` |
| **Target Table** | `dim_user_cache` (MySQL cache) |
| **PDI Steps** | Kafka Consumer, Get records from stream, Switch/Case, JSON Input (x2), Combination lookup/update, Calculator, Database lookup, Select values, JSON Output, Kafka Producer |

---

## Business Context

Your data platform needs a real-time enrichment pipeline. Purchase transactions arrive on one Kafka topic, and user registration events arrive on another. You need to:

1. Cache user profile data (region, gender) as it arrives
2. Enrich each purchase with the customer's profile data
3. Produce the enriched record to a new output topic for downstream analytics

This is a common **stream enrichment pattern** — analogous to a dimension lookup in batch ETL, but operating in real-time on streaming data.

---

## Learning Objectives

By the end of this workshop, you will be able to:

1. Subscribe to multiple Kafka topics using comma-separated names
2. Route messages by topic using the Switch/Case step
3. Cache reference data in MySQL with Combination lookup/update
4. Enrich transactional data with cached data using Database lookup
5. Serialize enriched records to JSON using JSON Output step
6. Configure a Kafka Producer step to publish to an output topic
7. Verify end-to-end pipeline by consuming from the output topic

---

## Prerequisites

| Requirement | Verification Command | Expected Result |
|---|---|---|
| Kafka cluster | `make verify` | All services green |
| MySQL database | `make mysql-verify` | Tables listed |
| Data on `pdi-users` | `make consume-users` | JSON messages |
| Data on `pdi-purchases` | See Step 1 | JSON/Avro messages |
| PDI (Spoon) 9.4+ | Launch Spoon | Application opens |
| `warehouse_db` connection | Test in Spoon | "Connection successful" |
| Workshops 1–4 complete | Familiarity with all prior concepts | Recommended |

---

## Architecture Overview

```
┌──────────────────────────────────────────────────────┐
│  PARENT TRANSFORMATION (enrichment-pipeline-parent)  │
│                                                      │
│  ┌──────────────────────────────────┐                │
│  │    Kafka Consumer                │                │
│  │    Topics: pdi-users,            │                │
│  │            pdi-purchases         │                │
│  │    (comma-separated, no spaces)  │──── batches ──►│
│  └──────────────────────────────────┘                │
└──────────────────────────────────────────────────────┘
                    │
                    ▼
┌──────────────────────────────────────────────────────┐
│  CHILD TRANSFORMATION (enrichment-pipeline-child)    │
│                                                      │
│  Get records from stream                             │
│       │                                              │
│  Switch / Case (route by "topic" field)              │
│      /                              \                │
│     v                                v               │
│  [pdi-users]                   [pdi-purchases]       │
│  JSON Input (users)            JSON Input (purchases)│
│     │                                │               │
│  Combination                   Calculator            │
│  lookup/update                 (price × quantity)    │
│  (→ dim_user_cache)                  │               │
│                                Database lookup       │
│                                (enrich with user)    │
│                                      │               │
│                                Select values         │
│                                      │               │
│                                JSON Output           │
│                                      │               │
│                                Kafka Producer        │
│                                (→ pdi-enriched-      │
│                                   purchases)         │
└──────────────────────────────────────────────────────┘
```

---

## Data Sources

### Input Topic 1: `pdi-users` (~1 msg/sec)

```json
{"registertime":1493899960000,"userid":"User_1","regionid":"Region_9","gender":"MALE"}
```

### Input Topic 2: `pdi-purchases` (~2 msg/sec)

```json
{"order_id":1000,"product_id":"Product_42","price":125.99,"quantity":2,"customer_id":"Customer_123","timestamp":1708538400000}
```

### Output Topic: `pdi-enriched-purchases` (produced by this pipeline)

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

### Step 1: Verify Data on Both Topics

```bash
make consume-users
```

Then:
```bash
docker exec kafka-1 kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic pdi-purchases --from-beginning --max-messages 5
```

If either is empty: `make deploy-connectors`

---

### Step 2: Create the Output Topic

```bash
docker exec kafka-1 kafka-topics \
  --bootstrap-server localhost:9092 \
  --create --topic pdi-enriched-purchases \
  --partitions 3 --replication-factor 3
```

Verify:
```bash
docker exec kafka-1 kafka-topics \
  --bootstrap-server localhost:9092 \
  --describe --topic pdi-enriched-purchases
```

---

### Step 3: Create the User Cache Table

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

---

### Step 4: Create Parent Transformation

1. **File → New → Transformation**
2. Save as `enrichment-pipeline-parent.ktr`

#### Setup Tab

| Setting | Value | Notes |
|---|---|---|
| Connection | Direct | |
| Bootstrap Servers | `localhost:9092` | |
| Topics | `pdi-users,pdi-purchases` | **Comma-separated, no spaces** |
| Consumer Group | `pdi-enrichment-pipeline` | |
| Sub-transformation | `[path]/transformations/enrichment-pipeline-child.ktr` | |

> **Multi-topic**: Enter topics with commas, no spaces. PDI consumes from both into the same stream. The `topic` field identifies the source.

#### Batch Tab

| Setting | Value |
|---|---|
| Duration (ms) | `5000` |
| Number of records | `200` |
| Concurrent batches | `1` |
| Message prefetch limit | `100000` |
| Offset commit | When batch completes |

#### Fields Tab

| Name | Type |
|---|---|
| `key` | String |
| `message` | String |
| `topic` | String |
| `partition` | Integer |
| `offset` | Integer |
| `timestamp` | Integer |

> The `topic` field is **critical** — it tells you which topic each message came from.

#### Options Tab

| Property | Value |
|---|---|
| `auto.offset.reset` | `earliest` |
| `enable.auto.commit` | `false` |

Save the transformation.

---

### Step 5: Create Child Transformation

Save as `enrichment-pipeline-child.ktr`. This is significantly more complex — two processing branches that handle different message types.

---

#### Step 5a: Get Records from Stream

| Name | Type | Length | Precision |
|---|---|---|---|
| `key` | String | -1 | -1 |
| `message` | String | -1 | -1 |
| `topic` | String | -1 | -1 |
| `partition` | Integer | -1 | -1 |
| `offset` | Integer | -1 | -1 |
| `timestamp` | Integer | -1 | -1 |

---

#### Step 5b: Switch / Case (Route by Topic)

1. From **Design → Flow**, drag **Switch / Case** onto the canvas
2. Draw hop from **Get records from stream** → **Switch / Case**
3. Configure:

| Setting | Value |
|---|---|
| Field name | `topic` |
| Use string contains comparison | No |
| Case value data type | String |

**Case values**:

| Value | Target step |
|---|---|
| `pdi-users` | `JSON Input - Users` |
| `pdi-purchases` | `JSON Input - Purchases` |

> **Create the target steps first** (Steps 5c and 5e), then come back to select them here. Or type the step names manually — PDI will link them when you create the matching steps.

---

#### Step 5c: JSON Input - Users (Branch 1)

1. Drag **JSON Input** → rename to `JSON Input - Users`
2. Draw hop from **Switch / Case** → **JSON Input - Users**

**Source tab**:

| Setting | Value |
|---|---|
| Source is a field | Checked |
| Get source from field | `message` |
| Ignore missing path | Yes |
| Default path leaf to null | Yes |

**Fields tab**:

| Name | Path | Type |
|---|---|---|
| `userid` | `$.userid` | String |
| `regionid` | `$.regionid` | String |
| `gender` | `$.gender` | String |
| `registertime` | `$.registertime` | Integer |

---

#### Step 5d: Combination Lookup/Update (Cache Users)

1. From **Design → Data Warehouse**, drag **Combination lookup/update**
2. Draw hop from **JSON Input - Users** → **Combination lookup/update**
3. Configure:

| Setting | Value |
|---|---|
| Connection | `warehouse_db` |
| Target schema | *(leave blank)* |
| Target table | `dim_user_cache` |
| Technical key field | `user_key` |
| Technical key creation | Use auto increment field |
| Replace fields in table | Yes |

**Key Fields** (lookup key):

| Field | Lookup |
|---|---|
| `userid` | `user_id` |

**Fields to update**:

| Field | Lookup |
|---|---|
| `regionid` | `region_id` |
| `gender` | `gender` |

> This step acts as a mini dimension table. When a user arrives, it either inserts a new row or updates the existing one. The purchases branch queries this table for enrichment.

> **The Users branch terminates here** — no further output needed.

---

#### Step 5e: JSON Input - Purchases (Branch 2)

1. Drag another **JSON Input** → rename to `JSON Input - Purchases`
2. Draw hop from **Switch / Case** → **JSON Input - Purchases**

**Source tab**:

| Setting | Value |
|---|---|
| Source is a field | Checked |
| Get source from field | `message` |
| Ignore missing path | Yes |
| Default path leaf to null | Yes |

**Fields tab**:

| Name | Path | Type | Precision |
|---|---|---|---|
| `order_id` | `$.order_id` | Integer | |
| `product_id` | `$.product_id` | String | |
| `price` | `$.price` | Number | 2 |
| `quantity` | `$.quantity` | Integer | |
| `customer_id` | `$.customer_id` | String | |
| `purchase_timestamp` | `$.timestamp` | Integer | |

> **Note**: JSON field `timestamp` is renamed to `purchase_timestamp` to avoid collision with Kafka metadata.

---

#### Step 5f: Calculator (Compute Total Amount)

1. From **Design → Transform**, drag **Calculator**
2. Draw hop from **JSON Input - Purchases** → **Calculator**

| New field | Calculation | Field A | Field B | Value type | Precision | Remove |
|---|---|---|---|---|---|---|
| `total_amount` | A * B | `price` | `quantity` | Number | 2 | No |

---

#### Step 5g: Database Lookup (Enrich with User Data)

1. From **Design → Lookup**, drag **Database lookup**
2. Draw hop from **Calculator** → **Database lookup**

| Setting | Value |
|---|---|
| Connection | `warehouse_db` |
| Lookup schema | *(leave blank)* |
| Lookup table | `dim_user_cache` |
| Enable cache | Yes |
| Cache size (rows) | `5000` |

**Keys**:

| Stream Field | Comparator | Table Field |
|---|---|---|
| `customer_id` | `=` | `user_id` |

**Return values**:

| Field | Rename to | Default | Type |
|---|---|---|---|
| `region_id` | `customer_region` | *(blank)* | String |
| `gender` | `customer_gender` | *(blank)* | String |

> **Expected behavior**: The `customer_id` in purchases (e.g., `Customer_123`) may not match `userid` from the users topic (e.g., `User_1`). Unmatched lookups return null — this is expected with the datagen's independent data. The purpose is to learn the enrichment pattern.
>
> **To see matched results**, manually insert test data:
> ```sql
> INSERT IGNORE INTO dim_user_cache (user_id, region_id, gender)
> VALUES ('Customer_123', 'Region_5', 'MALE'),
>        ('Customer_456', 'Region_2', 'FEMALE');
> ```

---

#### Step 5h: Select Values (Prepare Output)

1. Draw hop from **Database lookup** → **Select values**

##### Select & Alter Tab

Select only the fields for the enriched output:

| Fieldname |
|---|
| `order_id` |
| `product_id` |
| `price` |
| `quantity` |
| `total_amount` |
| `customer_id` |
| `customer_region` |
| `customer_gender` |
| `purchase_timestamp` |

> This removes Kafka metadata fields (`key`, `message`, `topic`, `partition`, `offset`, `timestamp`) from the output.

##### Meta-data Tab

| Fieldname | Type | Length | Precision |
|---|---|---|---|
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

#### Step 5i: JSON Output (Serialize to Field)

1. From **Design → Output**, drag **JSON Output**
2. Draw hop from **Select values** → **JSON Output**

**General tab**:

| Setting | Value | Notes |
|---|---|---|
| Operation | Output value | Outputs JSON to a field, not a file |
| Output Value | `json_output` | Field name for the JSON string |
| Nr. rows in a block | `1` | One JSON object per row |
| JSON Bloc name | *(leave blank)* | No wrapper element |

**Fields tab** — click **Get Fields** or manually add all 9 fields with matching element names.

---

#### Step 5j: Kafka Producer (Write to Output Topic)

1. From **Design → Output**, drag **Kafka Producer**
2. Draw hop from **JSON Output** → **Kafka Producer**

##### Setup Tab

| Setting | Value |
|---|---|
| Connection | Direct |
| Bootstrap Servers | `localhost:9092` |
| Client ID | `pdi-enrichment-producer` |
| Topic | `pdi-enriched-purchases` |

##### Fields Tab

| Setting | Value | Notes |
|---|---|---|
| Message field | `json_output` | From JSON Output step |
| Key field | `customer_id` | Partitions by customer for ordering |

##### Options Tab

| Property | Value | Purpose |
|---|---|---|
| `acks` | `all` | Wait for all replicas to acknowledge |
| `enable.idempotence` | `true` | Prevent duplicates on retry |
| `compression.type` | `snappy` | Compress JSON payloads |

---

### Step 6: Verify the Complete Flow

```
Get records from stream
    │
Switch / Case (route by topic)
   /                              \
  v                                v
JSON Input - Users            JSON Input - Purchases
  │                                │
Combination lookup/update     Calculator
                                   │
                              Database lookup
                                   │
                              Select values
                                   │
                              JSON Output
                                   │
                              Kafka Producer
```

Check:
- All hops are **solid lines**
- Switch/Case has **two outgoing hops**
- Users branch **terminates** at Combination lookup/update
- Purchases branch flows through to Kafka Producer

---

### Step 7: Run the Transformation

1. Open `enrichment-pipeline-parent.ktr`
2. Click **Run** (▶)
3. Let it run for at least **30 seconds** to populate the user cache
4. Monitor Step Metrics:
   - **Switch / Case**: Rows distributed to both branches
   - **JSON Input - Users**: User records parsed
   - **Kafka Producer**: Rows written (W > 0)

---

### Step 8: Verify Enriched Messages

```bash
docker exec kafka-1 kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic pdi-enriched-purchases \
  --from-beginning --max-messages 10
```

With keys visible:
```bash
docker exec kafka-1 kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic pdi-enriched-purchases \
  --from-beginning --max-messages 10 \
  --property print.key=true --property key.separator=" | "
```

---

### Step 9: Verify User Cache

```bash
make mysql-shell
```

```sql
-- Check user cache is being populated
SELECT COUNT(*) FROM dim_user_cache;

-- View cached users
SELECT * FROM dim_user_cache ORDER BY user_key DESC LIMIT 10;
```

---

### Step 10: Monitor in Control Center

Open http://localhost:9021:

1. **Topics** → `pdi-enriched-purchases` → check Messages tab
2. **Consumers** → `pdi-enrichment-pipeline` → check consumer lag

Check consumer group lag from CLI:
```bash
docker exec kafka-1 kafka-consumer-groups \
  --bootstrap-server localhost:9092 \
  --group pdi-enrichment-pipeline --describe
```

---

## Debugging

### Testing Branches Independently

**Users branch only**:
1. Change parent Topics to `pdi-users` only
2. Disable hop to JSON Input - Purchases
3. Run → verify `dim_user_cache` is populated

**Purchases branch only**:
1. Ensure `dim_user_cache` has records
2. Change parent Topics to `pdi-purchases` only
3. Add temporary Text file output after Select values
4. Run → inspect output file

### Common Errors

| Error | Cause | Fix |
|---|---|---|
| Missing `dim_user_cache` | Table not created | Run CREATE TABLE SQL (Step 3) |
| Switch/Case not routing | Wrong field name or values | Verify `topic` field, case-sensitive values |
| Kafka Producer errors | Topic doesn't exist | Create topic (Step 2) |
| No enrichment data | `customer_id` doesn't match users | Expected — insert test data in `dim_user_cache` |
| "Error in sub-transformation" | Multiple causes | Check Logging tab for actual error |

---

## Key Concepts

### Multi-Topic Consumption

Comma-separated topics in the Setup tab → interleaved messages from all topics → use `topic` field to route.

**Ordering**: Kafka guarantees order within a partition, not across topics.

### Stream Enrichment Pattern

1. **Ingest** reference data → cache it
2. **Enrich** transactional data → lookup cached data
3. **Produce** enriched result → output topic

### Consumer + Producer Pipeline

Input topics → Transform → Output topic. Downstream systems consume the enriched topic without knowing about the source topics or enrichment logic.

---

## Knowledge Check

1. **How do you route messages from different topics?** Use the `topic` field with a Switch/Case step to send each message to the appropriate processing branch.

2. **Why cache user data in a database table?** The cache persists across transformation restarts. An in-memory cache would be empty on restart until user records arrive again.

3. **Why set `customer_id` as the Kafka Producer key field?** All purchases for the same customer go to the same partition, guaranteeing per-customer ordering for downstream consumers.

4. **What does `enable.idempotence=true` do on the producer?** Assigns sequence numbers to messages. If a retry occurs, Kafka deduplicates based on the sequence number.

---

## Challenge Exercises

1. **Add a dead-letter branch**: Route messages that fail enrichment (null customer_region) to a `pdi-failed-enrichments` topic
2. **Add a database sink**: Also write enriched purchases to the `purchases` table with the enrichment fields filled in
3. **Real-time dashboard**: Write a SQL query against `dim_user_cache` that shows user count by region, updated in real-time

---

## Summary

After completing this workshop, you have:

- A multi-topic consumer reading from `pdi-users` and `pdi-purchases` simultaneously
- Message routing by topic using Switch/Case
- A user cache in MySQL populated by the users branch
- Purchase enrichment via Database lookup
- JSON serialization and Kafka Producer writing to `pdi-enriched-purchases`
- The most complex pattern in this workshop: a complete stream enrichment pipeline

**Previous**: [Workshop 4: Time-Bounded Data Retrieval](workshop-4-time-bounded.md)
