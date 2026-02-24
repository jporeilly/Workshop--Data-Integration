# Scenario 3: E-Commerce Purchases - Avro Format with Schema Registry

**Business Use Case**: Process e-commerce purchase transactions encoded in Avro format, leveraging Schema Registry for schema management, and load them into a MySQL data warehouse.

**Difficulty**: Intermediate | **Duration**: 45-60 minutes

## Learning Objectives

- Configure a Kafka Consumer step to deserialize Avro messages via Schema Registry
- Set Options tab properties for Avro converter and Schema Registry URL
- Parse Avro-deserialized JSON data using JSON Input step (including nested objects)
- Use JSONPath syntax for nested fields (e.g., `$.address.city`)
- Set field metadata with Select values (Meta-data tab) for all string fields
- Map fields to MySQL `purchases` table using Table output
- Understand schema evolution and its impact on consumers
- Verify data integrity in the database

## Prerequisites

Before starting this scenario:

1. Workshop environment is running -- `make workshop-start`
2. MySQL is running with tables created -- `make mysql-verify`
3. Data is flowing into `pdi-purchases` topic -- verify with the command in [Step 1](#step-1-verify-data-is-flowing)
4. PDI (Spoon) is open with Kafka EE plugin installed
5. `warehouse_db` database connection is configured in Spoon (see [Scenario 1, Step 2](scenario-1-user-activity.md#step-2-create-database-connection-in-spoon))
6. Schema Registry is running at http://localhost:8081

## Architecture

```
Parent Transformation (Kafka Consumer Step)
    | Avro messages deserialized via Schema Registry
    | (batches of records every 5 seconds or 100 records)
    v
Child Transformation
    Get records from stream
        |
    JSON Input (parse message field -- Avro converted to JSON by EE plugin)
        |  extracts flat fields + nested address.city, address.state, address.zipcode
        |
    Select values (rename + set metadata/types)
        |
    Table output (write to purchases)
```

## Data Source

The `pdi-purchases` topic receives e-commerce purchase events at ~2 messages/second from the datagen connector.

**Important -- Avro format**: Unlike the JSON-based topics in Scenarios 1 and 2, this topic uses **Avro serialization** with schemas registered in the Confluent Schema Registry. The Kafka EE plugin in PDI handles Avro deserialization automatically when the correct converter properties are set in the Options tab. The deserialized data appears as JSON in the `message` field, so the child transformation processes it the same way as JSON data.

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

**Field descriptions**:

| JSON Field | Type | Description |
|-----------|------|-------------|
| `orderid` | Long | Order identifier |
| `itemid` | String | Product/item identifier (e.g., `Item_249`) |
| `orderunits` | Double | Number of units ordered (can be fractional) |
| `address` | Object | Nested address object |
| `address.city` | String | City name (e.g., `City_35`) |
| `address.state` | String | State name (e.g., `State_45`) |
| `address.zipcode` | Integer | ZIP code (e.g., `66413`) |

---

## Step-by-Step Instructions

### Step 1: Verify Data is Flowing

First, verify the Schema Registry is accessible:

```bash
make test-connection
```

Check that Schema Registry (8081) shows OK.

Then verify the `pdi-purchases` topic has data by consuming a few messages:

```bash
docker exec kafka-1 kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic pdi-purchases \
  --from-beginning \
  --max-messages 5
```

> **Note**: Since the topic uses Avro encoding, the console consumer output may appear garbled or contain binary characters. This is expected -- Avro is a binary format. The Kafka EE plugin in PDI will deserialize it properly using the Schema Registry.

You can also verify the schema is registered:

```bash
curl -s http://localhost:8081/subjects | python3 -m json.tool
```

Look for `pdi-purchases-value` in the list of subjects. To inspect the schema:

```bash
curl -s http://localhost:8081/subjects/pdi-purchases-value/versions/latest | python3 -m json.tool
```

If data is not flowing, deploy connectors first: `make deploy-connectors`

### Step 2: Create Database Connection in Spoon

If you completed Scenario 1 or 2 and already have the `warehouse_db` connection configured, skip this step.

Otherwise, follow the instructions in [Scenario 1, Step 2](scenario-1-user-activity.md#step-2-create-database-connection-in-spoon) to create the `warehouse_db` connection with these settings:

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
2. Save as `purchases-avro-parent.ktr` in the `transformations/` directory

#### Add Kafka Consumer Step

1. From the **Design** panel, expand **Input** -> drag **Kafka Consumer** onto the canvas
2. Double-click the Kafka Consumer step to configure:

#### Setup Tab

| Setting | Value | Notes |
|---------|-------|-------|
| Connection | Direct | |
| Bootstrap Servers | `localhost:9092` | External Kafka broker address |
| Topics | `pdi-purchases` | |
| Consumer Group | `pdi-purchases-consumer` | Unique name for this transformation |
| Sub-transformation | `[path]/transformations/purchases-avro-child.ktr` | Use Browse button to select |

> **Tip**: Use the **Browse** button for the sub-transformation path. An incorrect path is a common source of "Error in sub-transformation" errors.

#### Batch Tab

| Setting | Value | Notes |
|---------|-------|-------|
| Duration (ms) | `5000` | Collect records for 5 seconds |
| Number of records | `100` | Or until 100 records arrive |
| Maximum concurrent batches | `1` | Start with 1 |
| Message prefetch limit | `100000` | Default is fine |
| Offset commit | When batch completes | At-least-once delivery (recommended) |

> **How batching works**: With `pdi-purchases` producing ~2 msg/sec, the 5-second duration will usually trigger first, sending ~10 records per batch.

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

This is the critical tab for Avro support. Click **+** to add each property:

| Property | Value | Notes |
|----------|-------|-------|
| `auto.offset.reset` | `earliest` | Read from beginning on first run |
| `enable.auto.commit` | `false` | Let PDI manage offsets |
| `value.converter` | `io.confluent.connect.avro.AvroConverter` | **Key setting** -- tells the EE plugin to deserialize Avro values |
| `value.converter.schema.registry.url` | `http://localhost:8081` | Schema Registry endpoint for value schemas |
| `key.converter` | `org.apache.kafka.connect.storage.StringConverter` | Keys are plain strings, not Avro |

> **Why these converter settings?**
>
> - **`value.converter`**: The datagen connector produces purchase messages serialized in Avro format. The `AvroConverter` reads the schema ID embedded in each message (first 5 bytes), fetches the corresponding schema from the Schema Registry, and deserializes the binary Avro payload into a JSON string. This JSON string appears in the `message` field of the Kafka Consumer output.
>
> - **`value.converter.schema.registry.url`**: The AvroConverter needs to know where to fetch schemas. This points to the Schema Registry running in the workshop Docker environment.
>
> - **`key.converter`**: The message keys for this topic are simple strings (not Avro-encoded), so we use `StringConverter`. If keys were also Avro-encoded, you would set `key.converter` to `AvroConverter` and add a `key.converter.schema.registry.url` property.
>
> **What happens without these settings?** If you omit the Avro converter properties, the `message` field will contain raw Avro binary data (garbled text), and the JSON Input step will fail to parse it.

3. Click **OK** to save the step configuration
4. Save the transformation (**Ctrl+S**)

### Step 4: Create Child Transformation

1. **File -> New -> Transformation**
2. Save as `purchases-avro-child.ktr` in the `transformations/` directory

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

Even though the source data is Avro, the Kafka EE plugin converts it to JSON before passing it to the child transformation. So the JSON Input step is used here just like in the JSON-based scenarios.

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
| `orderid` | `$.orderid` | Integer | | -1 | -1 | none |
| `itemid` | `$.itemid` | String | | -1 | -1 | none |
| `orderunits` | `$.orderunits` | Number | | -1 | -1 | none |
| `city` | `$.address.city` | String | | -1 | -1 | none |
| `state` | `$.address.state` | String | | -1 | -1 | none |
| `zipcode` | `$.address.zipcode` | Integer | | -1 | -1 | none |

> **Handling nested JSON**: The `address` field is a nested JSON object. Instead of extracting the entire object and parsing it separately, use JSONPath dot notation to reach into the nested structure directly:
> - `$.address.city` extracts the `city` value from within the `address` object
> - `$.address.state` extracts the `state` value
> - `$.address.zipcode` extracts the `zipcode` value
>
> This is more efficient than a two-pass approach (extract `$.address` as a string, then parse again). PDI's JSON Input step supports arbitrary nesting depth with `$.level1.level2.level3` syntax.
>
> **Why not extract `$.address` as a whole?** If you extract `$.address` as a String, you get `{"city":"City_35","state":"State_45","zipcode":66413}` which would require a second JSON Input step to parse. Direct path extraction avoids this overhead.

---

#### Step 4c: Select Values

1. From **Design -> Transform**, drag **Select values** onto the canvas
2. Draw a hop from **JSON Input** -> **Select values**
3. Double-click to configure:

##### Select & Alter Tab

This tab selects which fields to pass through and renames them to match database column names.

| Fieldname | Rename to | Length | Precision |
|-----------|-----------|--------|-----------|
| `key` | `customer_id` | | |
| `message` | | | |
| `topic` | `kafka_topic` | | |
| `partition` | `kafka_partition` | | |
| `offset` | `kafka_offset` | | |
| `timestamp` | `purchase_timestamp` | | |
| `orderid` | `order_id` | | |
| `itemid` | `product_id` | | |
| `orderunits` | `quantity` | | |
| `city` | | | |
| `state` | | | |
| `zipcode` | | | |

> **Field mapping notes**:
> - `key` -> `customer_id`: The Kafka message key for purchase events is the customer identifier.
> - `orderid` -> `order_id`: Rename to match database column naming convention.
> - `itemid` -> `product_id`: Maps the item identifier to the `product_id` column.
> - `orderunits` -> `quantity`: Maps the number of units to the `quantity` column.
> - `timestamp` -> `purchase_timestamp`: The Kafka timestamp becomes the purchase timestamp.
> - Leave "Rename to" blank to keep the original name. Leave Length and Precision blank in this tab.

##### Meta-data Tab

This tab sets the data type and length metadata for each field. **This is critical for MySQL** -- without explicit lengths, PDI maps String fields to `TINYTEXT`, which breaks MySQL indexes and causes errors like:
```
BLOB/TEXT column 'customer_id' used in key specification without a key length
```

| Fieldname | Type | Length | Precision |
|-----------|------|--------|-----------|
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

> **Why these lengths?** They match the MySQL table column definitions: `customer_id VARCHAR(100)`, `product_id VARCHAR(100)`, `kafka_topic VARCHAR(255)`. Setting the correct lengths ensures PDI generates `VARCHAR` instead of `TINYTEXT`.

---

#### Step 4d: Table Output

1. From **Design -> Output**, drag **Table output** onto the canvas
2. Draw a hop from **Select values** -> **Table output**
3. Double-click to configure:

##### Main Settings

| Setting | Value | Notes |
|---------|-------|-------|
| Connection | `warehouse_db` | The MySQL connection from Step 2 |
| Target schema | *(leave blank)* | **Important**: Do NOT set this for MySQL |
| Target table | `purchases` | |
| Commit size | `1000` | |
| Truncate table | No | |
| Ignore insert errors | No | |
| Use batch updates | Yes | |
| Specify database fields | Yes | **Must be Yes** to control field mapping |

> **Critical: Leave Target schema blank.** MySQL uses the database name from the connection, not a separate schema. Setting it to `kafka_warehouse` causes PDI to qualify the table as `kafka_warehouse.purchases` which can fail or cause unexpected behavior.

##### Database Fields

Click **Specify database fields: Yes**, then configure the field mapping:

| Database Column | Stream Field |
|-----------------|-------------|
| `order_id` | `order_id` |
| `product_id` | `product_id` |
| `customer_id` | `customer_id` |
| `quantity` | `quantity` |
| `purchase_timestamp` | `purchase_timestamp` |
| `kafka_topic` | `kafka_topic` |
| `kafka_partition` | `kafka_partition` |
| `kafka_offset` | `kafka_offset` |

> **Do NOT map these columns** -- MySQL handles them automatically:
> - `purchase_id` -- AUTO_INCREMENT primary key
> - `price` -- Not available in the source data (see note below)
> - `total_amount` -- Not available in the source data (see note below)
> - `ingestion_timestamp` -- DEFAULT CURRENT_TIMESTAMP

> **Note on `price` and `total_amount`**: The datagen `purchases` schema does not include a per-unit price field. The `orderunits` field represents quantity. The `price` and `total_amount` database columns will remain NULL for this basic scenario. In a production environment, you would enrich this data by looking up prices from a product catalog (using a Database lookup or Stream lookup step) and calculating `total_amount = price * quantity`. This enrichment pattern is covered in Scenario 5.

> **Tip**: You can use **Get Fields** button to auto-populate, then remove `purchase_id`, `price`, `total_amount`, and `ingestion_timestamp`, and verify all remaining mappings are correct.

##### SQL Button

When you click **SQL** in the Table output dialog, PDI may suggest ALTER TABLE statements. **Click Close without executing** -- the table already has the correct schema from the Docker init script.

If PDI suggests:
```sql
ALTER TABLE purchases MODIFY customer_id TINYTEXT
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
Get records from stream -> JSON Input -> Select values -> Table output
```

All hops must show as solid lines with arrows.

### Step 6: Run the Transformation

1. Switch to the **parent** transformation (`purchases-avro-parent.ktr`)
2. Click **Run** (play button) or press **F9**
3. In the Run dialog, click **Run**
4. Monitor the **Logging** tab:
   - You should see batch processing messages
   - "Finished processing" messages with `W=N` (rows written) > 0
5. Check the **Step Metrics** tab for throughput numbers

The transformation runs continuously. Click **Stop** to end it.

> **If you see "Error in sub-transformation"**: Check the Logging tab for the actual error. Common causes:
> - Missing Avro converter properties in Options tab (Step 3)
> - Incorrect Schema Registry URL
> - Disabled hops (Step 5)
> - Missing `warehouse_db` connection (Step 2)
> - Incorrect sub-transformation path (Step 3)
> - Schema field set in Table output (Step 4d)

> **If you see garbled data in JSON Input**: The Avro converter settings are missing or incorrect. Go back to the parent transformation's Kafka Consumer -> Options tab and verify all three converter properties are set exactly as shown in [Step 3, Options Tab](#options-tab).

### Step 7: Verify Data in MySQL

```bash
make mysql-shell
```

Then run these queries:

```sql
-- Check record count (should increase over time)
SELECT COUNT(*) FROM purchases;

-- View recent records
SELECT * FROM purchases
ORDER BY ingestion_timestamp DESC
LIMIT 10;

-- Check for duplicates (should return 0 rows)
SELECT kafka_topic, kafka_partition, kafka_offset, COUNT(*)
FROM purchases
GROUP BY kafka_topic, kafka_partition, kafka_offset
HAVING COUNT(*) > 1;

-- Check ingestion health (uses built-in stored procedure)
CALL sp_check_ingestion_health();

-- View purchases by product (top 10 most ordered items)
SELECT
    product_id,
    COUNT(*) AS order_count,
    SUM(quantity) AS total_units
FROM purchases
GROUP BY product_id
ORDER BY order_count DESC
LIMIT 10;

-- Monitor ingestion rate per minute
SELECT
    DATE_FORMAT(ingestion_timestamp, '%Y-%m-%d %H:%i:00') AS minute,
    COUNT(*) AS records_ingested
FROM purchases
WHERE ingestion_timestamp >= DATE_SUB(NOW(), INTERVAL 1 HOUR)
GROUP BY minute
ORDER BY minute DESC;

-- Check offset progress by partition
SELECT
    kafka_partition,
    MIN(kafka_offset) AS min_offset,
    MAX(kafka_offset) AS max_offset,
    COUNT(*) AS record_count
FROM purchases
GROUP BY kafka_partition
ORDER BY kafka_partition;

-- View purchases by customer
SELECT
    customer_id,
    COUNT(*) AS total_orders,
    SUM(quantity) AS total_units_ordered
FROM purchases
GROUP BY customer_id
ORDER BY total_orders DESC
LIMIT 10;
```

---

## Schema Evolution

One of the key advantages of using Avro with Schema Registry is **schema evolution** -- the ability to change the data schema over time without breaking consumers.

### How Schema Evolution Works

1. **Schema Registry stores versions**: Every time the Avro schema for `pdi-purchases` changes, a new version is registered. The Schema Registry assigns each version an ID.

2. **Messages carry schema IDs**: Each Avro message includes a 5-byte header containing the schema ID used to serialize it. The AvroConverter uses this ID to fetch the correct schema for deserialization.

3. **Compatibility checks**: The Schema Registry enforces compatibility rules (by default, `BACKWARD` compatibility), meaning new schemas can add optional fields or remove fields with defaults, but cannot make breaking changes.

### What Happens When the Schema Changes

| Schema Change | Impact on Your Transformation | Action Required |
|---------------|-------------------------------|-----------------|
| New optional field added | No impact -- the new field is ignored by JSON Input unless you add it | Add a new field row in JSON Input if you want to capture it |
| Field removed (with default) | No impact -- the AvroConverter provides the default value | None |
| Field type changed | May cause JSON Input parsing errors | Update the field Type in JSON Input |
| Field renamed | Old field path returns null | Update the Path in JSON Input |

### Checking Schema Versions

To view all versions of the purchases schema:

```bash
# List all versions
curl -s http://localhost:8081/subjects/pdi-purchases-value/versions | python3 -m json.tool

# View specific version
curl -s http://localhost:8081/subjects/pdi-purchases-value/versions/1 | python3 -m json.tool

# Check compatibility mode
curl -s http://localhost:8081/config/pdi-purchases-value | python3 -m json.tool
```

> **Schema evolution vs. JSON**: With plain JSON topics (Scenarios 1 and 2), there is no schema enforcement -- producers can change the message structure at any time, and consumers discover issues only at parse time. With Avro + Schema Registry, incompatible changes are rejected at the producer, preventing data corruption downstream.

---

## Debugging

### Debug Child Transformation (JSON Output)

To inspect the Avro-deserialized data without writing to the database:

1. Create a copy of the child transformation
2. Replace the **Table output** step with a **Text file output** or **JSON Output** step
3. Configure it to write to a file (e.g., `transformations/debug-output-purchases.json`)
4. Update the parent transformation's sub-transformation path to point to the debug version
5. Run the parent and inspect the output file

This is especially useful for verifying that the Avro deserialization is working correctly and that nested fields are being extracted properly.

> Remember to switch back to the original child transformation when done debugging.

### Common Errors and Fixes

#### "Error in sub-transformation"

This generic error wraps the actual child transformation failure. Check the Logging tab for the real cause:

| Root Cause | How to Identify | Fix |
|-----------|----------------|-----|
| Missing Avro converter | Binary/garbled data in message field | Add `value.converter` and `value.converter.schema.registry.url` in Options tab |
| Schema Registry unreachable | Connection refused to port 8081 | Verify Schema Registry is running: `curl http://localhost:8081` |
| Disabled hops | Steps show 0 rows written | Right-click hop -> Enable hop |
| Missing connection | "Unknown database connection" | Create `warehouse_db` in parent transformation |
| Wrong sub-transformation path | "Unable to load transformation" | Use Browse button to set correct path |
| Schema field set | `kafka_warehouse.purchases` in error | Clear Target schema in Table output |

#### Garbled or Binary Data in Message Field

If the `message` field contains binary/garbled characters instead of readable JSON:

**Cause**: The Avro converter properties are not set in the Kafka Consumer Options tab.

**Fix**: Add these three properties in the parent transformation's Kafka Consumer -> Options tab:
```
value.converter = io.confluent.connect.avro.AvroConverter
value.converter.schema.registry.url = http://localhost:8081
key.converter = org.apache.kafka.connect.storage.StringConverter
```

#### "BLOB/TEXT column used in key specification without a key length"

PDI is trying to ALTER the table with `TINYTEXT` columns. This happens when string fields don't have lengths set.

**Fix**: Set field lengths in the Select values **Meta-data** tab (see [Step 4c](#step-4c-select-values)).

**Workaround**: When PDI shows the SQL editor dialog, click **Close** without executing.

#### "Table not found" or wrong table qualification

If the error references `kafka_warehouse.purchases` instead of just `purchases`:

**Fix**: Clear the **Target schema** field in Table output (leave it blank).

#### JSON Input Returns Null for Nested Fields

If `city`, `state`, or `zipcode` come through as null:

1. **Check the path syntax**: Ensure you used `$.address.city`, not `$.city` or `$['address']['city']`
2. **Check "Ignore missing path"** is set to Yes -- this prevents errors but fields will be null if the path is wrong
3. **Preview the message field**: Add a temporary **Write to log** step after Get records from stream to see the raw JSON. Verify the `address` object exists in the message.

#### No Data Written (W=0)

1. Check consumer is receiving messages: `I=N` should be > 0
2. Check JSON Input is parsing: Step Metrics should show rows flowing through
3. Check the Avro converter is working: If `I > 0` but JSON Input shows 0 output, the message field likely contains binary Avro (see "Garbled Data" above)
4. Check Table output connection is valid: test `warehouse_db` connection
5. Check all hops are enabled (solid lines, not dashed)

#### Duplicate Records

The `purchases` table has a `UNIQUE KEY` on `(kafka_topic, kafka_partition, kafka_offset)`. If you see duplicate key errors:

1. Table output with "Ignore insert errors: No" will fail on duplicates -- set to Yes, or
2. Use **Insert/Update** step instead (recommended for idempotency):
   - Keys: `kafka_topic`, `kafka_partition`, `kafka_offset`
   - Don't perform any updates: Yes

---

## Database Table Reference

The `purchases` table (created by `sql/01-create-database-mysql-docker.sql`):

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

## Summary

After completing this scenario, you have:

- A parent transformation reading Avro-encoded messages from `pdi-purchases` topic
- Avro deserialization configured via Schema Registry in the Kafka Consumer Options tab
- A child transformation that parses the deserialized JSON (including nested address fields), renames fields, sets metadata, and writes to MySQL
- Idempotent processing via the UNIQUE KEY on Kafka coordinates
- Understanding of schema evolution and how Avro + Schema Registry protects data integrity
- Continuous streaming data flowing from Kafka to your data warehouse

**Previous**: [Scenario 2: High-Frequency Stock Trades](scenario-2-stock-trades.md) -- Higher-volume data with aggregation.

**Next**: [Scenario 4: Time-Bounded Data Retrieval](scenario-4-time-bounded.md) -- Retrieve and process historical data within a specific time range.

---

**Related Documentation**:
- [Transformations README](../../transformations/README.md) -- Template configuration details
- [Workshop Guide -- Scenario 3 Overview](../WORKSHOP-GUIDE.md#scenario-3-e-commerce-purchases---avro-format) -- Summary and configuration reference
- [Workshop Guide -- PDI Kafka Consumer Configuration](../WORKSHOP-GUIDE.md#pdi-kafka-consumer-configuration) -- All 6 configuration tabs
- [Workshop Guide -- Kafka to Data Warehouse](../WORKSHOP-GUIDE.md#kafka-to-data-warehouse) -- Architecture patterns
