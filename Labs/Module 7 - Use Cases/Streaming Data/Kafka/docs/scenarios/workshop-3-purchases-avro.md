# Workshop 3: E-Commerce Purchases — Avro Format with Schema Registry

| | |
|---|---|
| **Scenario** | E-Commerce Purchases — Avro Deserialization via Schema Registry |
| **Difficulty** | Intermediate |
| **Duration** | 45–60 minutes |
| **Topics** | `pdi-purchases` (Avro-encoded) |
| **Target Table** | `purchases` |
| **PDI Steps** | Kafka Consumer, Get records from stream, JSON Input, Select values, Table output |

---

## Business Context

Your e-commerce platform publishes purchase transactions to Kafka using **Avro serialization** with a schema managed by Confluent Schema Registry. Avro provides schema enforcement at the producer — incompatible schema changes are rejected before data enters the pipeline, unlike raw JSON where structural issues are only discovered at parse time.

Your task is to configure the PDI Kafka Consumer to deserialize Avro messages, extract nested JSON fields (the `address` object), and load purchase data into MySQL.

---

## Learning Objectives

By the end of this workshop, you will be able to:

1. Configure the Kafka Consumer Options tab for Avro deserialization via Schema Registry
2. Set `value.converter`, `value.converter.schema.registry.url`, and `key.converter` properties
3. Parse nested JSON objects using JSONPath dot notation (`$.address.city`)
4. Understand the Avro → JSON conversion performed by the Kafka EE plugin
5. Understand schema evolution and its impact on consumers

---

## Prerequisites

| Requirement | Verification Command | Expected Result |
|---|---|---|
| Kafka cluster | `make verify` | All services green |
| Schema Registry | `curl http://localhost:8081/subjects` | JSON list of subjects |
| MySQL database | `make mysql-verify` | Tables listed including `purchases` |
| Data on `pdi-purchases` topic | See Step 1 below | Avro messages (binary) |
| PDI (Spoon) 9.4+ | Launch Spoon | Application opens |
| `warehouse_db` connection | Test in Spoon | "Connection successful" |

If `warehouse_db` doesn't exist, see [Workshop 1, Step 2](workshop-1-user-activity.md#step-2-create-database-connection-in-spoon).

---

## Architecture Overview

```
┌──────────────────────────────────────────────────┐
│  PARENT TRANSFORMATION (purchases-avro-parent)   │
│                                                  │
│  ┌──────────────────────────────┐                │
│  │    Kafka Consumer            │                │
│  │    Topic: pdi-purchases      │                │
│  │    Avro → JSON via Schema    │                │
│  │    Registry (Options tab)    │──── batches ──►│
│  └──────────────────────────────┘                │
└──────────────────────────────────────────────────┘
                    │
                    ▼
┌──────────────────────────────────────────────────┐
│  CHILD TRANSFORMATION (purchases-avro-child)     │
│                                                  │
│  Get records from stream                         │
│       │                                          │
│  JSON Input (parse flat + nested fields)         │
│       │  $.orderid, $.itemid, $.orderunits       │
│       │  $.address.city, $.address.state,        │
│       │  $.address.zipcode                       │
│       │                                          │
│  Select values (rename + set metadata)           │
│       │                                          │
│  Table output (→ purchases)                      │
└──────────────────────────────────────────────────┘
```

**Key difference from Workshops 1 & 2**: The Options tab includes Avro converter properties that tell the Kafka EE plugin to deserialize binary Avro messages into JSON using Schema Registry. The child transformation then processes this JSON exactly as in previous workshops.

---

## Data Source

**Topic**: `pdi-purchases` — ~2 messages/second, **Avro-encoded**

**Sample message** (after Avro deserialization to JSON):
```json
{
  "orderid": 5,
  "itemid": "Item_249",
  "orderunits": 7.569441,
  "address": {
    "city": "City_35",
    "state": "State_45",
    "zipcode": 66413
  }
}
```

| JSON Field | Type | Description |
|---|---|---|
| `orderid` | Long | Order identifier |
| `itemid` | String | Product/item identifier (e.g., `Item_249`) |
| `orderunits` | Double | Number of units ordered (can be fractional) |
| `address` | Object | **Nested** address object |
| `address.city` | String | City name (e.g., `City_35`) |
| `address.state` | String | State name (e.g., `State_45`) |
| `address.zipcode` | Integer | ZIP code (e.g., `66413`) |

---

## Step-by-Step Instructions

### Step 1: Verify Data and Schema Registry

Verify the Schema Registry is accessible:
```bash
make test-connection
```

Check the schema is registered:
```bash
curl -s http://localhost:8081/subjects | python3 -m json.tool
```
Look for `pdi-purchases-value` in the list.

Inspect the Avro schema:
```bash
curl -s http://localhost:8081/subjects/pdi-purchases-value/versions/latest | python3 -m json.tool
```

Verify messages exist on the topic:
```bash
docker exec kafka-1 kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic pdi-purchases \
  --from-beginning --max-messages 5
```

> The console output will appear garbled/binary — this is expected for Avro-encoded messages. The Kafka EE plugin will deserialize them properly.

---

### Step 2: Create Parent Transformation

1. **File → New → Transformation**
2. Save as `purchases-avro-parent.ktr` in `transformations/`

#### Setup Tab

| Setting | Value |
|---|---|
| Connection | Direct |
| Bootstrap Servers | `localhost:9092` |
| Topics | `pdi-purchases` |
| Consumer Group | `pdi-purchases-consumer` |
| Sub-transformation | `[path]/transformations/purchases-avro-child.ktr` |

#### Batch Tab

| Setting | Value |
|---|---|
| Duration (ms) | `5000` |
| Number of records | `100` |
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

#### Options Tab — Critical for Avro

This is the key tab. Click **+** to add each property:

| Property | Value | Purpose |
|---|---|---|
| `auto.offset.reset` | `earliest` | Read from beginning on first run |
| `enable.auto.commit` | `false` | Let PDI manage offsets |
| `value.converter` | `io.confluent.connect.avro.AvroConverter` | Deserialize Avro values |
| `value.converter.schema.registry.url` | `http://localhost:8081` | Schema Registry endpoint |
| `key.converter` | `org.apache.kafka.connect.storage.StringConverter` | Keys are plain strings |

> **Why these converter settings?**
>
> - **`value.converter`**: The AvroConverter reads the schema ID from each message (first 5 bytes), fetches the schema from the Registry, and deserializes the Avro binary into a JSON string. This JSON appears in the `message` field.
>
> - **`value.converter.schema.registry.url`**: Points the AvroConverter to the Schema Registry.
>
> - **`key.converter`**: Message keys are plain strings (not Avro), so we use StringConverter.
>
> **Without these settings**: The `message` field contains raw Avro binary, and JSON Input will fail.

Save the transformation.

---

### Step 3: Create Child Transformation

1. **File → New → Transformation**
2. Save as `purchases-avro-child.ktr`

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

#### Step 3b: JSON Input — Including Nested Fields

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
| `orderid` | `$.orderid` | Integer | | -1 | -1 | none |
| `itemid` | `$.itemid` | String | | -1 | -1 | none |
| `orderunits` | `$.orderunits` | Number | | -1 | -1 | none |
| `city` | `$.address.city` | String | | -1 | -1 | none |
| `state` | `$.address.state` | String | | -1 | -1 | none |
| `zipcode` | `$.address.zipcode` | Integer | | -1 | -1 | none |

> **Handling nested JSON**: Use JSONPath dot notation to reach into the `address` object:
> - `$.address.city` extracts `city` from within `address`
> - `$.address.state` extracts `state`
> - `$.address.zipcode` extracts `zipcode`
>
> This is more efficient than extracting `$.address` as a string and re-parsing. PDI supports arbitrary nesting depth: `$.level1.level2.level3`.

---

#### Step 3c: Select Values

##### Select & Alter Tab

| Fieldname | Rename to |
|---|---|
| `key` | `customer_id` |
| `message` | |
| `topic` | `kafka_topic` |
| `partition` | `kafka_partition` |
| `offset` | `kafka_offset` |
| `timestamp` | `purchase_timestamp` |
| `orderid` | `order_id` |
| `itemid` | `product_id` |
| `orderunits` | `quantity` |
| `city` | |
| `state` | |
| `zipcode` | |

> **Field mapping notes**:
> - `key` → `customer_id`: Kafka message key is the customer identifier
> - `orderid` → `order_id`: Match database naming convention
> - `itemid` → `product_id`: Maps item to product column
> - `orderunits` → `quantity`: Maps units to quantity column

##### Meta-data Tab

| Fieldname | Type | Length | Precision |
|---|---|---|---|
| `customer_id` | String | 100 | |
| `order_id` | Integer | 15 | |
| `product_id` | String | 100 | |
| `quantity` | Integer | 9 | |
| `city` | String | 100 | |
| `state` | String | 100 | |
| `zipcode` | Integer | 9 | |
| `kafka_topic` | String | 255 | |
| `kafka_partition` | Integer | 9 | |
| `kafka_offset` | Integer | 15 | |
| `purchase_timestamp` | Integer | 15 | |
| `message` | String | 5000 | |

---

#### Step 3d: Table Output

##### Main Settings

| Setting | Value |
|---|---|
| Connection | `warehouse_db` |
| Target schema | *(leave blank)* |
| Target table | `purchases` |
| Commit size | `1000` |
| Truncate table | No |
| Ignore insert errors | No |
| Use batch updates | Yes |
| Specify database fields | Yes |

##### Database Fields

| Database Column | Stream Field |
|---|---|
| `order_id` | `order_id` |
| `product_id` | `product_id` |
| `customer_id` | `customer_id` |
| `quantity` | `quantity` |
| `purchase_timestamp` | `purchase_timestamp` |
| `kafka_topic` | `kafka_topic` |
| `kafka_partition` | `kafka_partition` |
| `kafka_offset` | `kafka_offset` |

> **Do NOT map**: `purchase_id`, `price`, `total_amount`, `ingestion_timestamp`
>
> **Note on `price` and `total_amount`**: The datagen schema doesn't include per-unit price. These columns will be NULL. In production, you'd enrich with a product catalog lookup (covered in Workshop 5).

---

### Step 4: Verify Hops

```
Get records from stream → JSON Input → Select values → Table output
```

All hops must be solid lines.

---

### Step 5: Run the Transformation

1. Open `purchases-avro-parent.ktr`
2. Click **Run** (▶)
3. Monitor the Logging tab

> **If you see garbled data in JSON Input**: The Avro converter settings are missing. Go back to the Options tab and verify all three converter properties.

---

### Step 6: Verify Data in MySQL

```bash
make mysql-shell
```

```sql
-- Check record count
SELECT COUNT(*) FROM purchases;

-- View recent records
SELECT * FROM purchases ORDER BY ingestion_timestamp DESC LIMIT 10;

-- Check for duplicates
SELECT kafka_topic, kafka_partition, kafka_offset, COUNT(*)
FROM purchases
GROUP BY kafka_topic, kafka_partition, kafka_offset
HAVING COUNT(*) > 1;

-- Top products by order count
SELECT
    product_id,
    COUNT(*) AS order_count,
    SUM(quantity) AS total_units
FROM purchases
GROUP BY product_id
ORDER BY order_count DESC
LIMIT 10;

-- Purchases by customer
SELECT
    customer_id,
    COUNT(*) AS total_orders,
    SUM(quantity) AS total_units
FROM purchases
GROUP BY customer_id
ORDER BY total_orders DESC
LIMIT 10;
```

---

## Schema Evolution

A key advantage of Avro + Schema Registry is **schema evolution** — changing the data schema over time without breaking consumers.

### How It Works

1. Schema Registry stores versions — every schema change gets a new version ID
2. Each Avro message carries the schema ID used to serialize it (first 5 bytes)
3. The Registry enforces compatibility rules (default: `BACKWARD`)

### Impact on Your Transformation

| Schema Change | Impact | Action |
|---|---|---|
| New optional field added | No impact — ignored unless you add it to JSON Input | Add field to JSON Input if needed |
| Field removed (with default) | No impact — AvroConverter provides default | None |
| Field type changed | May cause JSON Input parse errors | Update Type in JSON Input |
| Field renamed | Old path returns null | Update Path in JSON Input |

### Check Schema Versions

```bash
# List versions
curl -s http://localhost:8081/subjects/pdi-purchases-value/versions | python3 -m json.tool

# View latest
curl -s http://localhost:8081/subjects/pdi-purchases-value/versions/latest | python3 -m json.tool

# Check compatibility mode
curl -s http://localhost:8081/config/pdi-purchases-value | python3 -m json.tool
```

---

## Debugging

### Common Errors

| Error | Cause | Fix |
|---|---|---|
| Garbled/binary data in message field | Avro converter not configured | Add `value.converter` and `value.converter.schema.registry.url` in Options tab |
| Schema Registry unreachable | Connection refused on 8081 | Verify: `curl http://localhost:8081` |
| Nested fields return null | Wrong JSONPath | Use `$.address.city` not `$.city` |
| "BLOB/TEXT column used in key specification" | Missing string lengths | Set lengths in Meta-data tab |
| "Error in sub-transformation" | Multiple causes | Check Logging tab for actual error |

---

## Database Table Reference

```sql
CREATE TABLE purchases (
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
    UNIQUE KEY uq_kafka_offset (kafka_topic, kafka_partition, kafka_offset)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

---

## Knowledge Check

1. **What happens if you omit the Avro converter properties?** The `message` field contains raw Avro binary. JSON Input fails to parse it.

2. **How does Schema Registry improve reliability vs. raw JSON?** Incompatible schema changes are rejected at the producer, preventing data corruption. With JSON, structural issues are only discovered at parse time in the consumer.

3. **How do you extract nested JSON fields?** Use JSONPath dot notation: `$.address.city` reaches into the `address` object directly.

4. **Do you need different child transformation logic for Avro vs. JSON?** No. The Kafka EE plugin converts Avro to JSON before passing it to the child. The child processes JSON identically in both cases.

---

## Challenge Exercises

1. **Extract all address fields**: Also map `city`, `state`, `zipcode` to the database (add columns to `purchases` or create a separate `purchase_addresses` table)
2. **Schema exploration**: Use the Schema Registry API to view the full Avro schema and identify which fields are optional vs. required
3. **Simulate schema evolution**: Register a new schema version with an additional optional field and verify your transformation handles it gracefully

---

## Summary

After completing this workshop, you have:

- A parent transformation reading Avro-encoded messages with Schema Registry integration
- Avro converter properties configured in the Options tab
- A child transformation parsing deserialized JSON including nested address fields
- Understanding of Avro, Schema Registry, and schema evolution
- Idempotent processing via UNIQUE KEY on Kafka coordinates

**Previous**: [Workshop 2: High-Frequency Stock Trades](workshop-2-stock-trades.md)

**Next**: [Workshop 4: Time-Bounded Data Retrieval](workshop-4-time-bounded.md)
