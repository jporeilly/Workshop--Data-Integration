# Pentaho Kafka Workshop - Complete Guide

Comprehensive reference for the PDI Kafka Enterprise Edition workshop. Covers environment setup, all 6 workshop scenarios, PDI configuration, data warehouse integration, MySQL Docker setup, and troubleshooting.

## Table of Contents

- [Getting Started](#getting-started)
- [Workshop Scenarios](#workshop-scenarios)
- [PDI Kafka Consumer Configuration](#pdi-kafka-consumer-configuration)
- [PDI Kafka Producer Configuration](#pdi-kafka-producer-configuration)
- [Kafka to Data Warehouse](#kafka-to-data-warehouse)
- [MySQL Docker Setup](#mysql-docker-setup)
- [Quick Reference](#quick-reference)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)
- [Workshop Exercises](#workshop-exercises)
- [Additional Resources](#additional-resources)

---

## Getting Started

### Step 1: Navigate to Workshop Directory

```bash
cd ~/Workshop--Data-Integration/Labs/Module\ 7\ -\ Use\ Cases/Streaming\ Data/Kafka
```

### Step 2: Start the Workshop Environment

```bash
# Complete setup in one command
make workshop-start
```

This will:
- Generate Kafka cluster configuration (if not exists)
- Start all Kafka services (brokers, controllers, connect, schema registry, control center)
- Deploy workshop data generators
- Start MySQL database

**Expected output:**
```
========================================
  Workshop Environment Started!
========================================

Services available at:
  - Control Center:  http://localhost:9021
  - Kafka Connect:   http://localhost:8083
  - Schema Registry: http://localhost:8081
  - MySQL:           localhost:3306
```

### Step 3: Verify Everything is Working

```bash
make verify
```

This checks Docker environment, Kafka cluster components, service endpoints, connectors, and topics.

### Step 4: Verify MySQL Database

```bash
make mysql-verify
```

Expected tables: `user_events`, `stock_trades`, `purchases`, `pageviews`, `kafka_staging`, `kafka_errors`, `user_activity_hourly`, `stock_trades_summary`.

### Step 5: Access the Services

| Service | URL | Description |
|---------|-----|-------------|
| Control Center | http://localhost:9021 | Kafka cluster management UI |
| Kafka Connect | http://localhost:8083 | Connect REST API |
| Schema Registry | http://localhost:8081 | Schema management |
| Prometheus | http://localhost:9090 | Metrics collection |

### Step 6: Test Data is Flowing

```bash
make consume-users    # View sample user messages
make consume-trades   # View sample stock trade messages
make topics           # List all topics
```

### Step 7: Open Pentaho Spoon

Launch PDI and start the workshop exercises:

```bash
cd /path/to/pentaho/data-integration
./spoon.sh
```

### What's Running?

After `make workshop-start`:

| Service | Count | Purpose |
|---------|-------|---------|
| Kafka Brokers | 3 | Message storage and distribution |
| KRaft Controllers | 3 | Cluster coordination (no ZooKeeper) |
| Kafka Connect | 2 | Data integration framework |
| Schema Registry | 1 | Avro schema management |
| Control Center | 1 | Web UI for monitoring |
| Prometheus | 1 | Metrics collection |
| MySQL | 1 | Data warehouse |

**Total Containers**: ~12

**Topics Created Automatically** (by datagen connectors):

| Topic | Message Rate | Schema | Use Case |
|-------|--------------|--------|----------|
| pdi-users | 1/sec | users | User registrations |
| pdi-stocktrades | 10/sec | Stock_Trades | Stock trading |
| pdi-purchases | 2/sec | purchases | E-commerce |
| pdi-pageviews | 5/sec | pageviews | Web analytics |

### Post-Deployment: Build Your First Transformation

After the environment is running:

1. **Configure MySQL connection in Spoon**:
   - Go to **View -> Database Connections -> New**
   - Connection Name: `warehouse_db`, Type: MySQL, Host: `localhost`, Database: `kafka_warehouse`, Port: `3306`, User: `kafka_user`, Password: `kafka_password`
   - Click **Test** then **OK**

2. **Open a template transformation** from `transformations/` or build from scratch:
   - Add a **Kafka Consumer** step (topic: `pdi-users`, group: `pdi-consumer-group`)
   - Create a child transformation with: Get records from stream -> JSON Input -> Select values -> Table output
   - Run the parent transformation and watch data flow to MySQL

3. **Verify data in MySQL**:
   ```bash
   make mysql-shell
   # Then: SELECT COUNT(*) FROM user_events;
   ```

4. **Monitor in Control Center**: http://localhost:9021
   - Check **Topics** for message rates
   - Check **Consumers** for lag and consumption rate

See [transformations/README.md](../transformations/README.md) for detailed template configuration.

### Stop the Workshop

```bash
make workshop-stop     # Stop everything (keeps data)
make clean             # Stop and remove everything (data lost)
```

---

## Workshop Scenarios

### Scenario 1: Basic Kafka Consumer - Real-time User Activity Stream

**Business Use Case**: Process user registration and activity events in real-time

**Learning Objectives**:
- Configure a basic Kafka Consumer step
- Set up batch processing parameters
- Read streaming JSON data
- Process records with a child transformation

**Data Source**: User registration events (username, email, region, registration time)

**Parent Transformation**:
1. **Kafka Consumer** step
   - Connection: `localhost:9092`
   - Topic: `pdi-users`
   - Consumer Group: `pdi-warehouse-users`
   - Batch Duration: 5000ms
   - Number of Records: 100
   - Sub-transformation: `users-to-db-child.ktr`

**Kafka Consumer Configuration**:
```
Setup Tab:
  Connection: Direct
  Bootstrap Servers: localhost:9092
  Topics: pdi-users
  Consumer Group: pdi-warehouse-users

Batch Tab:
  Duration (ms): 5000
  Number of records: 100
  Maximum concurrent batches: 1
  Offset commit: When batch completes

Fields Tab:
  key (String)
  message (String)
  topic (String)
  partition (Integer)
  offset (Integer)
  timestamp (Integer)

Options Tab:
  auto.offset.reset: earliest
  enable.auto.commit: false
```

**Child Transformation** (`users-to-db-child.ktr`):
1. **Get records from stream** - Receive batched records
2. **JSON Input** - Parse JSON message
   - Source is a field: checked
   - Get source from field: `message`
   - Fields: `registertime`, `userid`, `regionid`, `gender`
3. **Select values** - Map and rename fields to match database columns
4. **Formula** - Convert epoch milliseconds to seconds (`[register_time_epoch] / 1000`)
5. **Table output** - Write to `user_events` table (connection: `warehouse_db`)
   - Specify database fields: Yes
   - Use batch updates: Yes
   - Commit size: 1000
   - Field mapping:

   | Stream Field | Database Column | Type | Source |
   |---|---|---|---|
   | `user_id` | `user_id` | VARCHAR(100) | JSON → Select values rename |
   | `region_id` | `region_id` | VARCHAR(100) | JSON → Select values rename |
   | `gender` | `gender` | VARCHAR(20) | JSON field |
   | `register_time_seconds` | `register_time` | TIMESTAMP | Formula (epoch ms / 1000) |
   | `kafka_topic` | `kafka_topic` | VARCHAR(255) | Kafka Consumer field |
   | `kafka_partition` | `kafka_partition` | INT | Kafka Consumer field |
   | `kafka_offset` | `kafka_offset` | BIGINT | Kafka Consumer field |

   > `event_id` (auto-increment) and `ingestion_timestamp` (defaults to `CURRENT_TIMESTAMP`) are handled automatically by MySQL — do not map these.

---

### Scenario 2: High-Frequency Stock Trades

**Business Use Case**: Process real-time stock trades for analysis and alerting

**Learning Objectives**:
- Handle high-frequency data streams
- Work with smaller batch intervals
- Implement data transformations
- Calculate moving averages and aggregates

**Data Source**: Stock trade events (symbol, price, quantity, timestamp)

**PDI Configuration**:
- **Duration**: 1000ms (1 second)
- **Number of records**: 50 records
- **Max concurrent batches**: 2
- **Format**: JSON
- **Consumer Group**: `pdi-stocktrades-consumer`

**Parent Transformation**:
1. **Kafka Consumer** step
   - Topic: `pdi-stocktrades`
   - Batch Duration: 1000ms
   - Max Concurrent Batches: 2

**Child Transformation**:
1. **Get records from stream**
2. **JSON Input** - Parse trade data
3. **Group by** - Aggregate by symbol (avg price, total quantity)
4. **Calculator** - Compute metrics
5. **Text file output** or **Table output** - Write to CSV or database

---

### Scenario 3: E-Commerce Purchases - Avro Format

**Business Use Case**: Process purchase transactions with schema evolution support

**Learning Objectives**:
- Work with Avro-formatted messages
- Use Schema Registry integration
- Handle schema evolution
- Implement data validation

**Data Source**: Purchase transactions (order_id, product, amount, customer_id)

**PDI Configuration**:
- **Format**: Avro with Schema Registry
- **Schema Registry URL**: http://localhost:8081
- **Consumer Group**: `pdi-purchases-consumer`

**Options Tab (Kafka Consumer)**:
```
value.converter: io.confluent.connect.avro.AvroConverter
value.converter.schema.registry.url: http://localhost:8081
key.converter: org.apache.kafka.connect.storage.StringConverter
```

---

### Scenario 4: Time-Bounded Data Retrieval

**Business Use Case**: Retrieve and process historical data within a specific time range

**Learning Objectives**:
- Use offset timestamp management
- Implement start and end timestamps
- Read bounded data sets
- Stop processing at specific time

**Data Source**: Pageview events

**Offset Settings Tab**:
```
Offset timestamp: ${END_TIMESTAMP}
Timestamp format: yyyy-MM-dd HH:mm:ss
```

**Transformation Logic**:
1. **Set Variables** - Define START_TIMESTAMP and END_TIMESTAMP
2. **Kafka Consumer** with offset settings
3. **Filter rows** - Additional time filtering if needed
4. **Abort** - Stop when offset timestamp reached

---

### Scenario 5: Multi-Topic Consumer with Kafka Producer

**Business Use Case**: Consume from multiple topics, transform, and produce to new topics

**Learning Objectives**:
- Subscribe to multiple topics
- Transform streaming data
- Produce results to output topics
- Implement stream processing pipeline

**Data Sources**: Users + Purchases topics

**Parent Transformation**:
1. **Kafka Consumer** - Subscribe to both `pdi-users` and `pdi-purchases`
   - Topics: `pdi-users,pdi-purchases` (comma-separated)

**Child Transformation**:
1. **Get records from stream**
2. **Switch / Case** - Route by topic name
3. **Branch 1** (Users): Store in Combination lookup
4. **Branch 2** (Purchases): Lookup user data and enrich
5. **JSON Output**
6. **Kafka Producer** - Write to `pdi-enriched-purchases`

---

### Scenario 6: Security Implementation (SSL/SASL)

**Business Use Case**: Secure Kafka communication in enterprise environments

**Learning Objectives**:
- Configure SSL encryption
- Implement SASL authentication
- Use encrypted credentials
- Work with security protocols

**SSL Encryption** (Options Tab):
```
security.protocol: SSL
ssl.truststore.location: /path/to/kafka.client.truststore.jks
ssl.truststore.password: Encrypted [password]
ssl.keystore.location: /path/to/kafka.client.keystore.jks
ssl.keystore.password: Encrypted [password]
ssl.key.password: Encrypted [password]
```

**SASL/PLAIN**:
```
security.protocol: SASL_SSL
sasl.mechanism: PLAIN
sasl.jaas.config: org.apache.kafka.common.security.plain.PlainLoginModule required \
  username="producer-user" \
  password="Encrypted [password]";
```

---

## PDI Kafka Consumer Configuration

### Architecture

```
Parent Transformation (Kafka Consumer Step)
    | (batches of records)
Child Transformation (Get records from stream -> Processing Steps)
```

### Configuration Tabs

#### 1. Setup Tab

**Connection Settings**:

| Setting | Value | Notes |
|---------|-------|-------|
| Connection Type | Direct | For this workshop |
| Bootstrap Servers | `localhost:9092` | External Kafka broker address |
| Topics | `pdi-users` | Single topic, or comma-separated, or regex `pdi-.*` |
| Consumer Group | `pdi-users-consumer` | Unique per transformation |
| Sub-transformation | `[path-to-child.ktr]` | Must start with "Get records from stream" |

**Cluster Connection** (for Hadoop environments):
```
Connection Type: Cluster
Cluster Name: [Your cluster configuration]
```

**Consumer Group behavior**:
- Same consumer group across instances = load balancing (partitions split)
- Different consumer groups = each gets all messages

**Sub-transformation path** - supports variables:
```
${Internal.Transformation.Filename.Directory}/child-consumer.ktr
```

#### 2. Batch Tab

| Setting | Value | Notes |
|---------|-------|-------|
| Duration (ms) | `5000` | Time to collect records (0 = disabled) |
| Number of records | `100` | Record count threshold (0 = disabled) |
| Maximum concurrent batches | `1` | Start with 1, increase for throughput |
| Message prefetch limit | `100000` | Queue size for buffering messages |
| Offset commit | When batch completes | At-least-once delivery (recommended) |

**Batch triggering**: Whichever threshold is reached first triggers the batch.

**Batch size examples**:

| Pattern | Duration | Records | Use Case |
|---------|----------|---------|----------|
| Time-based | 5000 | 0 | Regular interval processing |
| Count-based | 0 | 100 | Process when enough records arrive |
| Hybrid | 5000 | 100 | Either threshold (recommended) |

**Concurrent batches**: Higher concurrency = higher throughput but more memory. Monitor consumer lag and increase if falling behind.

**Prefetch limit**: Lower for large messages or memory constraints. Higher for small messages and high throughput.

**Offset commit strategies**:
- **Commit when record read**: Faster, at-most-once semantics, potential message loss on failure
- **Commit when batch completes**: Safer, at-least-once semantics (recommended)

#### 3. Fields Tab

Default fields from Kafka:

| Field | Type | Description |
|-------|------|-------------|
| `key` | String | Message key (used for partitioning) |
| `message` | String | Message payload |
| `topic` | String | Topic name (useful for multi-topic consumers) |
| `partition` | Integer | Partition number |
| `offset` | Integer | Message offset within partition |
| `timestamp` | Integer | Message timestamp (epoch ms) |

#### 4. Result Fields Tab

Returns fields from child transformation back to parent:

**When to use**:
- Parent needs processed results from child
- Building multi-stage pipelines
- Aggregating batch results

**Configuration**:
```
Transformation: child-consumer.ktr
Step name: [Select step that outputs final results]
Fields: [Select which fields to return]
```

#### 5. Options Tab

| Property | Value | Notes |
|----------|-------|-------|
| `auto.offset.reset` | `earliest` | `earliest`/`latest`/`none` |
| `enable.auto.commit` | `false` | Let PDI manage offsets (recommended) |
| `max.poll.records` | `500` | Records per poll (higher = better throughput) |
| `session.timeout.ms` | `10000` | Consumer heartbeat timeout |
| `request.timeout.ms` | `30000` | Request completion timeout |

**Variable substitution** - use PDI variables:
```
${KAFKA_BOOTSTRAP_SERVERS}
${CONSUMER_GROUP_ID}
```

**Encrypt sensitive values**:
```
ssl.keystore.password: Encrypted [encrypted_value]
```

#### 6. Offset Settings Tab (EE Plugin Feature)

For time-bounded data retrieval:

| Setting | Value | Notes |
|---------|-------|-------|
| Offset timestamp | `2026-02-21 18:00:00` | Stop consuming at this time |
| Timestamp format | `yyyy-MM-dd HH:mm:ss` | Leave blank for epoch values |

**Use cases**:
- **Process last hour**: Set offset timestamp to end of period
- **Historical range**: Use Kafka Offset Job Entry to reset to start time, then consumer with end timestamp
- **Dynamic stop**: `${END_TIME_VAR}` set by business logic

### Security Configuration

#### SSL Encryption

```
security.protocol: SSL
ssl.truststore.location: /path/to/kafka.client.truststore.jks
ssl.truststore.password: Encrypted [password]
ssl.keystore.location: /path/to/kafka.client.keystore.jks
ssl.keystore.password: Encrypted [password]
ssl.key.password: Encrypted [password]
```

#### SASL Authentication

**Kerberos (SASL_PLAINTEXT)**:
```
security.protocol: SASL_PLAINTEXT
sasl.mechanism: GSSAPI
sasl.kerberos.service.name: kafka
sasl.jaas.config: com.sun.security.auth.module.Krb5LoginModule required \
  useKeyTab=true \
  keyTab="/path/to/kafka.keytab" \
  principal="user@REALM";
```

**SASL/SCRAM**:
```
security.protocol: SASL_SSL
sasl.mechanism: SCRAM-SHA-256
sasl.jaas.config: org.apache.kafka.common.security.scram.ScramLoginModule required \
  username="kafka-user" \
  password="Encrypted [password]";
```

**SASL/PLAIN over SSL**:
```
security.protocol: SASL_SSL
sasl.mechanism: PLAIN
ssl.truststore.location: /path/to/truststore.jks
ssl.truststore.password: Encrypted [password]
sasl.jaas.config: org.apache.kafka.common.security.plain.PlainLoginModule required \
  username="user" \
  password="Encrypted [password]";
```

### Common Consumer Patterns

#### Pattern 1: Simple Stream Processing

```
Parent: Kafka Consumer
  +-- Duration: 5000ms
  +-- Records: 100
  +-- Child: Process Records
       +-- Get records from stream
       +-- JSON Input
       +-- Filter rows
       +-- Text file output
```

#### Pattern 2: Stream Aggregation

```
Parent: Kafka Consumer
  +-- Duration: 10000ms
  +-- Child: Aggregate Batch
       +-- Get records from stream
       +-- JSON Input
       +-- Group by (aggregate)
       +-- Calculator
       +-- Table output (results back to parent via Result Fields)

Parent continues:
  +-- Write aggregated results to DB
```

#### Pattern 3: Stream Joining (Multi-Topic)

```
Parent: Kafka Consumer (Topics: users,purchases)
  +-- Child: Join Streams
       +-- Get records from stream
       +-- Switch/Case (route by topic)
       +-- Branch 1: Users -> Memory Group by
       +-- Branch 2: Purchases -> Stream lookup
       +-- Kafka Producer (enriched output)
```

#### Pattern 4: Time-Bounded Processing

```
Job:
  +-- Set Variables (START_TIME, END_TIME)
  +-- Kafka Offset Job Entry (reset to START_TIME)
  +-- Transformation: Kafka Consumer
       +-- Offset timestamp: ${END_TIME}
       +-- Child: Process bounded data
```

---

## PDI Kafka Producer Configuration

### Architecture

```
Input Step -> Transformation Logic -> Kafka Producer -> Kafka Topic
```

### Configuration Tabs

#### 1. Setup Tab

| Setting | Value | Notes |
|---------|-------|-------|
| Connection Type | Direct | |
| Bootstrap Servers | `localhost:9092` | |
| Client ID | `pdi-producer-enriched` | Unique, descriptive identifier |
| Topic | `pdi-purchases-enriched` | Destination topic |

**Client ID naming convention**: `pdi-{project}-{purpose}`
- Example: `pdi-ecommerce-order-publisher`, `pdi-prod-orders-enrichment`

**Dynamic Topics**: Check "Get topic from field" to route to different topics per row.

#### 2. Fields Tab

| Setting | Value | Notes |
|---------|-------|-------|
| Message field | `json_output` | Field containing the message payload |
| Key field | `customer_id` | Field used for partition assignment |

**Key selection strategies**:

| Key | Effect | Use Case |
|-----|--------|----------|
| Customer/User ID | All messages for one customer in order | Order history |
| Product ID | Product-related events grouped | Inventory |
| Region/Location | Geographic grouping | Regional analytics |
| *(empty/null)* | Round-robin distribution | Maximum throughput |

#### 3. Options Tab

**Acknowledgements**:

| Setting | Value | Notes |
|---------|-------|-------|
| `acks` | `all` | `0` = fire-and-forget, `1` = leader only, `all` = all replicas |
| `enable.idempotence` | `true` | Prevent duplicate messages (requires acks=all) |

**Compression**:

| Type | Characteristics | Recommendation |
|------|----------------|----------------|
| none | No compression | Default |
| snappy | Balanced performance/compression | General purpose |
| lz4 | Fast, good for high throughput | High volume |
| gzip | High compression ratio, more CPU | Bandwidth-constrained |
| zstd | Best compression, moderate CPU | Kafka 2.1+ |

**Batching and Performance**:

| Property | Value | Notes |
|----------|-------|-------|
| `batch.size` | `16384` | Bytes per batch (16KB default, range 16KB-1MB) |
| `linger.ms` | `10` | Wait time before sending (0 = immediate) |
| `buffer.memory` | `33554432` | Total buffer (32MB default) |
| `retries` | `2147483647` | Retry attempts (MAX_INT = infinite) |
| `retry.backoff.ms` | `100` | Wait between retries |
| `max.block.ms` | `60000` | Max time send() can block |
| `request.timeout.ms` | `30000` | Request completion timeout |

### Data Format Configurations

**JSON** (most common):
```
value.serializer: org.apache.kafka.common.serialization.StringSerializer
```
Steps: Select values -> JSON Output -> Kafka Producer (message field: `json_output`)

**Avro with Schema Registry**:
```
value.serializer: io.confluent.kafka.serializers.KafkaAvroSerializer
schema.registry.url: http://localhost:8081
```
Steps: Select values -> Avro Encode -> Kafka Producer (message field: `encoded_avro`)

**String**:
```
value.serializer: org.apache.kafka.common.serialization.StringSerializer
```

**Binary**:
```
value.serializer: org.apache.kafka.common.serialization.ByteArraySerializer
```

### Common Producer Patterns

#### Pattern 1: Simple Stream Publishing

```
Input -> Transform -> JSON Output -> Kafka Producer
```

#### Pattern 2: Stream Enrichment Pipeline

```
Kafka Consumer -> Database Lookup (enrich) -> JSON Output -> Kafka Producer
```

#### Pattern 3: Multi-Topic Publishing

```
Input -> Switch/Case (by record type) -> Multiple Kafka Producers (different topics)
```

#### Pattern 4: Dynamic Topic Routing

```
Input -> Calculator (topic = "region-" + region_code) -> Kafka Producer (get topic from field)
```

#### Pattern 5: Dead Letter Queue

```
Main Pipeline:
  Try:  -> Process -> Kafka Producer (main topic)
  Catch: -> Add Error Info -> Kafka Producer (DLQ topic)
```

---

## Kafka to Data Warehouse

### Architecture Patterns

#### Pattern 1: Direct Load (Real-time)

```
Kafka Topic -> Kafka Consumer -> Transform -> Database Table
```

**Best for**: Low-to-medium volume, real-time dashboards. Simple architecture but higher database load.

#### Pattern 2: Micro-Batch Load (Near Real-time)

```
Kafka Topic -> Kafka Consumer (batches) -> Transform -> Bulk Insert -> Database
```

**Best for**: Medium-to-high volume. Batches every 5-60 seconds for better throughput.

#### Pattern 3: Staged Load (ETL Pipeline)

```
Kafka -> Consumer -> Transform -> Staging Table -> ETL Job -> Dimension/Fact Tables
```

**Best for**: High volume, complex transformations. Supports data quality checks.

#### Pattern 4: Lambda Architecture (Hybrid)

```
Kafka -> Consumer -> {
    Path 1: Real-time -> Summary Tables (hot data)
    Path 2: Batch -> Full History Tables (cold data)
}
```

**Best for**: Mixed requirements (real-time + batch). More complex to maintain.

### Database Schema Design

#### User Events Table

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
);
```

#### Stock Trades Table

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
);
```

#### Purchases Table

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
    UNIQUE KEY uq_kafka_offset (kafka_topic, kafka_partition, kafka_offset)
);
```

#### Staging Table (for Batch Processing)

```sql
CREATE TABLE kafka_staging (
    staging_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    topic VARCHAR(255),
    partition INT,
    offset BIGINT,
    message_key TEXT,
    message_value TEXT,
    timestamp TIMESTAMP NULL,
    processed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_processed (processed),
    UNIQUE KEY uq_staging_offset (topic, partition, offset)
);
```

### Transformation Examples

#### Basic Kafka to MySQL (Users)

**Child Transformation Steps**:

1. **Get records from stream** - Receive batched records
2. **JSON Input** - Parse `message` field: `userid`, `regionid`, `gender`, `registertime`
3. **Select values** - Rename: `userid` -> `user_id`, `regionid` -> `region_id`, etc.
4. **Formula** - Convert epoch: `[register_time_epoch] / 1000` -> `register_time_seconds`
5. **Insert/Update** - Connection: `warehouse_db`, Table: `user_events`, Keys: `kafka_topic`, `kafka_partition`, `kafka_offset`

#### Staged Load with ETL Job

**Job Steps**:

1. **Transformation**: Kafka Consumer -> JSON Input -> Table Output (`kafka_staging`)
2. **Transformation**: Table Input (`SELECT * FROM kafka_staging WHERE processed = FALSE`) -> Transformations -> Insert/Update (fact tables)
3. **SQL**: `UPDATE kafka_staging SET processed = TRUE WHERE processed = FALSE`
4. **SQL**: Cleanup old staging records

#### Star Schema (Dimensional Model)

```sql
-- Dimension: User (SCD Type 2)
CREATE TABLE dim_user (
    user_key SERIAL PRIMARY KEY,
    user_id VARCHAR(100) UNIQUE,
    region_id VARCHAR(100),
    gender VARCHAR(20),
    register_date DATE,
    current_flag BOOLEAN DEFAULT TRUE,
    effective_date DATE,
    expiration_date DATE
);

-- Fact: User Activity
CREATE TABLE fact_user_activity (
    activity_key BIGSERIAL PRIMARY KEY,
    date_key INTEGER REFERENCES dim_date(date_key),
    user_key INTEGER REFERENCES dim_user(user_key),
    activity_type VARCHAR(50),
    activity_count INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**ETL Process**: Load date dimension (one-time) -> Load user dimension (SCD Type 2) -> Load fact table (lookup keys, aggregate, insert).

### Error Handling Patterns

#### Dead Letter Queue (DLQ)

```
Main pipeline:
  Try:  -> JSON Input -> Table Output
  Catch: -> Add error info -> JSON Output -> Kafka Producer (dlq-user-events)
```

#### Error Table

Route processing errors to `kafka_errors` table with error details, raw message, and retry count.

#### Retry Logic

Job: Process Kafka -> Check error count -> If errors > threshold -> Sleep -> Retry transformation -> Update retry count.

### Performance Tuning

**High Throughput Consumer Settings**:
```
Batch Tab:
  Duration (ms): 2000-5000
  Number of records: 1000-5000
  Maximum concurrent batches: 2-4

Options Tab:
  max.poll.records: 5000
  fetch.min.bytes: 1048576
```

**Database Optimization**:
```
Table Output:
  Commit size: 5000-10000
  Use batch updates: Yes

Connection Pool:
  Initial pool size: 5
  Maximum pool size: 20
```

**PDI Transformation Tuning**:
```
Transformation settings:
  Number of rows in rowset: 10000
  Enable safe mode: No (for production)
```

### Monitoring Queries

```sql
-- Check recent ingestion
SELECT kafka_topic, COUNT(*) as records,
    MAX(ingestion_timestamp) as last_ingestion,
    TIMESTAMPDIFF(SECOND, MAX(ingestion_timestamp), NOW()) as lag_seconds
FROM user_events
WHERE ingestion_timestamp > DATE_SUB(NOW(), INTERVAL 1 HOUR)
GROUP BY kafka_topic;

-- Check for gaps in offsets
SELECT kafka_partition, kafka_offset,
    kafka_offset - LAG(kafka_offset) OVER (
        PARTITION BY kafka_partition ORDER BY kafka_offset
    ) as offset_gap
FROM user_events
WHERE kafka_topic = 'pdi-users'
ORDER BY kafka_partition, kafka_offset;

-- Ingestion health
CALL sp_check_ingestion_health();
```

---

## MySQL Docker Setup

### Start MySQL

```bash
make mysql-setup    # Start container + verify tables

# Or step-by-step:
make mysql-start    # Start MySQL container
make mysql-verify   # Verify tables are created
```

**Default credentials** (from `docker-compose-mysql.yml`):

| Setting | Value |
|---------|-------|
| Host | `localhost` |
| Port | `3306` |
| Database | `kafka_warehouse` |
| User | `kafka_user` |
| Password | `kafka_password` |
| Root Password | `rootpassword` |

Override with environment variables:
```bash
MYSQL_PASSWORD=my_secret MYSQL_ROOT_PASSWORD=my_root_secret make mysql-start
```

Or create a `.env` file with `MYSQL_PASSWORD=...` and `MYSQL_ROOT_PASSWORD=...`.

### How Initialization Works

The init script `sql/01-create-database-mysql-docker.sql` is mounted at `/docker-entrypoint-initdb.d/`. Docker runs it automatically on **first start** only (when the data volume is empty). To re-initialize: `make mysql-clean` then `make mysql-setup`.

### Database Contents

**Tables**: `user_events`, `stock_trades`, `purchases`, `pageviews`, `kafka_staging`, `kafka_errors`, `user_activity_hourly`, `stock_trades_summary`

**Views**: `v_recent_user_events` (last 24h), `v_recent_stock_trades` (last 1h), `v_error_summary` (hourly errors)

**Stored Procedures**: `sp_cleanup_old_staging(hours)`, `sp_retry_failed_messages(max_count)`, `sp_check_ingestion_health()`

### Container Management

```bash
make mysql-start       # Start container
make mysql-stop        # Stop container
make mysql-restart     # Restart container
make mysql-shell       # Connect as kafka_user
make mysql-shell-root  # Connect as root
make mysql-logs        # View MySQL logs
make mysql-verify      # Show tables and statistics
make mysql-clean       # Remove container and ALL data
```

### PDI Connection Settings

```
Connection Name: warehouse_db
Connection Type: MySQL
Access: Native (JDBC)
Host: localhost
Database: kafka_warehouse
Port: 3306
User: kafka_user
Password: kafka_password
```

**JDBC URL**: `jdbc:mysql://localhost:3306/kafka_warehouse?useSSL=false&allowPublicKeyRetrieval=true`

**Recommended Options** (for write performance): `useServerPrepStmts=false`, `rewriteBatchedStatements=true`, `cachePrepStmts=true`, `useCompression=true`

### Data Persistence

Data is stored in Docker volume `kafka-workshop-mysql-data`. Data survives `mysql-stop` + `mysql-start`. Only `mysql-clean` removes it.

```bash
docker volume ls | grep kafka-workshop-mysql-data    # View volume
docker volume inspect kafka-workshop-mysql-data       # Inspect details
```

### MySQL Configuration

The file `mysql/my.cnf` contains optimizations:
- InnoDB buffer pool: 2GB
- Log file size: 512MB
- Flush method: O_DIRECT
- Character set: UTF8MB4
- Max connections: 200

### Backup and Restore

```bash
# Backup
docker exec kafka-workshop-mysql mysqldump -u kafka_user -pkafka_password kafka_warehouse > backup.sql

# Backup with compression
docker exec kafka-workshop-mysql mysqldump -u kafka_user -pkafka_password kafka_warehouse | gzip > backup.sql.gz

# Restore
docker exec -i kafka-workshop-mysql mysql -u kafka_user -pkafka_password kafka_warehouse < backup.sql
```

### Advanced

**Run custom SQL on startup**: Add files like `sql/02-custom-tables.sql` and mount in `docker-compose-mysql.yml`:
```yaml
- ./sql/02-custom-tables.sql:/docker-entrypoint-initdb.d/02-custom.sql:ro
```

**Change MySQL version**: Edit `docker-compose-mysql.yml` image tag, then `make mysql-clean && make mysql-start`.

**Python connection**:
```python
import mysql.connector
conn = mysql.connector.connect(
    host="localhost", port=3306, user="kafka_user",
    password="kafka_password", database="kafka_warehouse"
)
```

---

## Quick Reference

### Container Names and Ports

| Container | Name | External Port |
|-----------|------|---------------|
| Kafka Brokers | `kafka-1`, `kafka-2`, `kafka-3` | 9092 |
| Controllers | `controller-1`, `controller-2`, `controller-3` | - |
| Kafka Connect | `kafka-connect-1`, `kafka-connect-2` | 8083 |
| Schema Registry | `schema-registry-1` | 8081 |
| Control Center | `control-center` | 9021 |
| MySQL | `kafka-workshop-mysql` | 3306 |

**Important**: Container names are `kafka-1` (NOT `broker1`). External port is `9092` (NOT `19094`).

### Make Commands

#### Workshop Management
```bash
make workshop-start    # Complete setup: Kafka + MySQL + Connectors
make workshop-stop     # Stop everything
make workshop-restart  # Restart everything
make verify           # Verify environment health
make monitor          # Show monitoring dashboard
```

#### Kafka Cluster
```bash
make start            # Start Kafka cluster only
make stop             # Stop Kafka cluster only
make restart          # Restart Kafka cluster
make status           # Show container status
make logs             # View logs (tail -f)
```

#### Data & Connectors
```bash
make deploy-connectors  # Deploy data generators
make topics            # List all topics
make consumers         # List consumer groups
make consume-users     # View sample user messages
make consume-trades    # View sample trade messages
make connectors-status # Check connector health
```

#### MySQL Database
```bash
make mysql-setup       # Start MySQL and verify tables
make mysql-start       # Start MySQL container
make mysql-stop        # Stop MySQL container
make mysql-shell       # Connect to MySQL
make mysql-verify      # Verify tables and data
make mysql-logs        # View MySQL logs
make mysql-clean       # Remove container and data
```

#### Utilities
```bash
make test-connection   # Test all connections
make kafka-shell       # Open Kafka broker shell
make clean            # Remove everything (with confirmation)
make clean-force      # Force remove everything
make help             # Show all commands
```

### Manual Kafka Commands

```bash
# List topics
docker exec kafka-1 kafka-topics --bootstrap-server localhost:9092 --list

# Describe topic
docker exec kafka-1 kafka-topics --bootstrap-server localhost:9092 --describe --topic pdi-users

# Create topic
docker exec kafka-1 kafka-topics --bootstrap-server localhost:9092 --create --topic my-topic --partitions 3 --replication-factor 3

# Delete topic
docker exec kafka-1 kafka-topics --bootstrap-server localhost:9092 --delete --topic my-topic

# Consume messages
docker exec kafka-1 kafka-console-consumer --bootstrap-server localhost:9092 --topic pdi-users --from-beginning --max-messages 10

# Produce message
echo '{"test": "message"}' | docker exec -i kafka-1 kafka-console-producer --bootstrap-server localhost:9092 --topic test-topic

# List consumer groups
docker exec kafka-1 kafka-consumer-groups --bootstrap-server localhost:9092 --list

# Describe consumer group
docker exec kafka-1 kafka-consumer-groups --bootstrap-server localhost:9092 --group pdi-users-consumer --describe

# Reset offsets to earliest
docker exec kafka-1 kafka-consumer-groups --bootstrap-server localhost:9092 --group pdi-users-consumer --topic pdi-users --reset-offsets --to-earliest --execute
```

### Kafka Connect REST API

```bash
curl http://localhost:8083/connectors | jq                                  # List connectors
curl http://localhost:8083/connectors/pdi-users-datagen/status | jq         # Check status
curl -X POST http://localhost:8083/connectors/pdi-users-datagen/restart     # Restart
curl -X DELETE http://localhost:8083/connectors/pdi-users-datagen           # Delete
curl -X POST http://localhost:8083/connectors -H "Content-Type: application/json" -d @connectors/pdi-users-datagen.json  # Deploy
```

### View Live Data from All Topics

```bash
docker exec kafka-1 kafka-console-consumer --bootstrap-server localhost:9092 --topic pdi-users --from-beginning --max-messages 3
docker exec kafka-1 kafka-console-consumer --bootstrap-server localhost:9092 --topic pdi-stocktrades --from-beginning --max-messages 3
docker exec kafka-1 kafka-console-consumer --bootstrap-server localhost:9092 --topic pdi-purchases --from-beginning --max-messages 3
docker exec kafka-1 kafka-console-consumer --bootstrap-server localhost:9092 --topic pdi-pageviews --from-beginning --max-messages 3
```

### Common MySQL Queries

```sql
SHOW TABLES;
SELECT COUNT(*) FROM user_events;
SELECT * FROM user_events ORDER BY ingestion_timestamp DESC LIMIT 10;
CALL sp_check_ingestion_health();

-- Table statistics
SELECT table_name, table_rows, ROUND(data_length / 1024 / 1024, 2) as data_mb
FROM information_schema.tables WHERE table_schema = 'kafka_warehouse';
```

### PDI Connection Summary

| Setting | Kafka Consumer | Kafka Producer | MySQL |
|---------|---------------|---------------|-------|
| Server | `localhost:9092` | `localhost:9092` | `localhost:3306` |
| User | - | - | `kafka_user` |
| Password | - | - | `kafka_password` |
| Database | - | - | `kafka_warehouse` |

### Emergency Commands

```bash
make clean-force           # Force stop and remove everything
make workshop-start        # Start fresh
docker system df           # Check disk space
docker system prune -a     # Clean all Docker (caution!)
```

---

## Troubleshooting

### Prometheus JMX Exporter Errors

**Symptom**: Kafka CLI commands show:
```
java.net.BindException: Address already in use
...jmx_prometheus_javaagent...
```

**Root Cause**: The `KAFKA_OPTS` environment variable loads a Prometheus JMX agent that binds to port 8091. The Kafka broker already uses this port. When CLI tools (kafka-topics, etc.) run inside the container, they inherit `KAFKA_OPTS` and try to start the agent on the same port.

**Additional Issue**: Inside the container, Kafka listens on `kafka-1:19094` (internal listener), not `localhost:9092`. External clients use `localhost:9092`, but commands inside the container need the internal address.

**Solution**: Use the wrapper scripts in `scripts/` that automatically unset `KAFKA_OPTS` and translate addresses:

```bash
# Instead of: docker exec kafka-1 kafka-topics --bootstrap-server localhost:9092 --list
./scripts/kafka-topics.sh --bootstrap-server localhost:9092 --list
./scripts/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic pdi-users --from-beginning --max-messages 5
./scripts/kafka-consumer-groups.sh --bootstrap-server localhost:9092 --list
```

Or use Makefile commands (`make topics`, `make consumers`, `make consume-users`) which use the wrappers automatically.

**How the wrappers work**: They execute `unset KAFKA_OPTS` before running the Kafka command and translate `localhost:9092` to `kafka-1:19094` (the internal listener address).

| User Provides | Translated To | Why |
|--------------|---------------|-----|
| `localhost:9092` | `kafka-1:19094` | Internal container address |
| `kafka-1:19094` | `kafka-1:19094` | Already correct |

### Kafka Cluster Issues

**Containers not starting**:
```bash
make status              # Check container status
docker stats             # Check resources (need 8GB+ RAM)
make logs                # View error logs
sudo systemctl restart docker  # Restart Docker if needed
```

**"docker-compose.yml not found"**:
```bash
make setup               # Generate configuration
```

**Port conflicts**:
```bash
netstat -an | grep -E "9092|8083|9021|8081"
```

**Complete reset**:
```bash
make clean-force         # Stop and remove everything
make workshop-start      # Start fresh
```

### Data Generator Issues

**No data in topics**:
```bash
make connectors-status                                                    # Check health
curl http://localhost:8083/connectors/pdi-users-datagen/status | jq       # Detailed status
curl -X POST http://localhost:8083/connectors/pdi-users-datagen/restart   # Restart connector
```

**Topics marked "unavailable" in Control Center**:

Cause: `min.insync.replicas=2` but `replication-factor=1`. Fix:
```bash
for topic in pdi-users pdi-pageviews pdi-purchases pdi-stocktrades; do
  docker exec kafka-1 sh -c "unset KAFKA_OPTS; kafka-configs \
    --bootstrap-server kafka-1:19094 \
    --entity-type topics --entity-name $topic \
    --alter --add-config min.insync.replicas=1"
done
```

The `deploy-connectors.sh` script now applies this fix automatically.

### PDI Connection Issues

**Can't connect to Kafka**:
- Verify bootstrap servers: `localhost:9092` (NOT `19094`)
- Check containers: `docker ps`
- Test: `make test-connection`

**Consumer not receiving messages**:
1. Topic exists and has data: `make consume-users`
2. Bootstrap servers correct
3. Consumer group has access
4. Offset reset: set `auto.offset.reset: earliest`

**Transformation hangs**:
- Child missing "Get records from stream" step
- Both Duration and Records set to 0
- Sub-transformation path is incorrect

### MySQL Issues

**Container won't start** (port 3306 in use):
```bash
sudo netstat -tlnp | grep 3306
sudo systemctl stop mysql    # Stop local MySQL
```

**Can't connect from PDI**:
```bash
docker exec kafka-workshop-mysql mysql -u kafka_user -pkafka_password -e "SELECT 1;"
make mysql-verify
```

**Tables not created** (init script didn't run):
```bash
docker logs kafka-workshop-mysql | grep "Database initialization complete"
# If not found, manually run:
docker exec -i kafka-workshop-mysql mysql -u root -prootpassword kafka_warehouse < sql/01-create-database-mysql-docker.sql
```

**No data appearing in database**:
1. Check Kafka Consumer is receiving messages (Logging tab)
2. Check JSON Input step is parsing correctly (Step Metrics)
3. Check database connection is valid (test in Spoon)
4. Check table schema: `SHOW CREATE TABLE user_events;`
5. Check field mapping in Select Values step

**Duplicate records**:
- Ensure `UNIQUE KEY` on `(kafka_topic, kafka_partition, kafka_offset)`
- Use Insert/Update step instead of Table output
- If using Table output, enable "Ignore insert errors"

---

## Best Practices

### Reliability

1. **Enable Idempotence** (Producer): `enable.idempotence: true`, `acks: all`
2. **Appropriate acks**: Critical data = `all`, logs/metrics = `1`, loss-tolerant = `0`
3. **Error Handling**: Use error handling in transformations, route failures to DLQ
4. **Offset Management**: Use "Commit when batch completes", implement idempotent processing

### Performance

1. **Optimize Batching** (Producer): `batch.size: 32768`, `linger.ms: 10`, `compression.type: snappy`
2. **Tune Consumer Batches**: Small = lower latency, Large = higher throughput. Monitor consumer lag.
3. **Database Bulk Operations**: Use batch updates, appropriate commit sizes, connection pooling, table partitioning

### Monitoring

1. **Descriptive Client IDs**: `client.id: pdi-${PROJECT_NAME}-${TRANSFORMATION_NAME}`
2. **Track Metrics**: Consumer lag, batch processing time, records per batch, error rates
3. **Use Control Center**: http://localhost:9021 for consumer groups, lag, throughput, topic health

### Security

1. **SSL Encryption**: Encrypt data in transit
2. **SASL Authentication**: Authenticate clients
3. **Encrypt Credentials**: Use PDI's encrypted fields
4. **Least Privilege**: Grant minimal required permissions

---

## Workshop Exercises

### Exercise 1: Basic Consumer
1. Deploy the `pdi-users-datagen` connector
2. Create a PDI transformation with Kafka Consumer
3. Read 100 user records
4. Log the results

### Exercise 2: Data Transformation
1. Consume stock trade data
2. Filter trades above $100
3. Calculate running average price per symbol
4. Write results to CSV file

### Exercise 3: Producer Pipeline
1. Consume purchase data
2. Add calculated fields (tax calculation)
3. Produce enriched data to new topic
4. Verify in Confluent Control Center

### Exercise 4: Time-Range Processing
1. Set up time-bounded consumer
2. Process last 1 hour of pageview data
3. Aggregate by page URL
4. Stop when timestamp reached

### Exercise 5: Multi-Topic Processing
1. Subscribe to users and purchases topics
2. Implement stream join
3. Enrich purchases with user data
4. Produce to enriched topic

### Exercise 6: Data Warehouse Load (MySQL)
1. Set up MySQL database using `make mysql-setup`
2. Create PDI connection `warehouse_db`
3. Build transformation to load from Kafka to `user_events` table
4. Use Insert/Update step for idempotency
5. Verify data integrity and no duplicates
6. Monitor ingestion health with provided SQL queries

---

## Additional Resources

### Documentation

- [Pentaho Kafka Consumer Documentation](https://docs.pentaho.com/pdia-data-integration/pdi-transformation-steps-reference-overview/kafka-consumer)
- [Pentaho EE Marketplace Plugins](https://docs.pentaho.com/pentaho-data-integration-and-analytics/pentaho-ee-marketplace-plugins-release-notes)
- [Apache Kafka Documentation](https://kafka.apache.org/documentation/)
- [Confluent Platform Documentation](https://docs.confluent.io/)
- [Kafka Connect Datagen](https://github.com/confluentinc/kafka-connect-datagen)

### Community

- [Pentaho Community Forums](https://community.hitachivantara.com/s/topic/0TO1J000000MdvTWAS/pentaho)
- [Apache Kafka Users Mailing List](https://kafka.apache.org/contact)
- [Confluent Community](https://www.confluent.io/community/)

### Related Workshop Files

- [../README.md](../README.md) - Workshop overview and quick start
- [../transformations/README.md](../transformations/README.md) - PDI transformation template configuration
- [../sql/README.md](../sql/README.md) - SQL script reference and table details

---

**Workshop Version**: 2.0
**Last Updated**: 2026-02-23
**Kafka Version**: 3.4.0
**PDI Version**: 9.4+ with Kafka EE Plugin
**Consolidated from**: GETTING-STARTED, NEXT-STEPS, PDI-KAFKA-CONSUMER-CONFIGURATION, PDI-KAFKA-PRODUCER-CONFIGURATION, KAFKA-TO-DATAWAREHOUSE, MYSQL-DOCKER-GUIDE, QUICK-REFERENCE, CORRECT-COMMANDS, PROMETHEUS-FIX
