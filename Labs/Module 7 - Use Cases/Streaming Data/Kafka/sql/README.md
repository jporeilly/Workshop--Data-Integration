# SQL Scripts for Kafka Workshop

This directory contains SQL scripts for setting up the data warehouse database.

## MySQL Setup

### Quick Start

```bash
# 1. Install MySQL (if not already installed)
# Ubuntu/Debian:
sudo apt-get update
sudo apt-get install mysql-server

# macOS (with Homebrew):
brew install mysql
brew services start mysql

# 2. Secure MySQL installation
sudo mysql_secure_installation

# 3. Create database and tables
mysql -u root -p < 01-create-database-mysql.sql

# 4. Verify setup
mysql -u kafka_user -p kafka_warehouse -e "SHOW TABLES;"
```

### What's Created

The `01-create-database-mysql.sql` script creates:

#### Database and User
- Database: `kafka_warehouse`
- User: `kafka_user` with password `your_password` (change this!)
- Grants: All privileges on `kafka_warehouse.*`

#### Tables Created

1. **user_events** - User registration events from `pdi-users` topic
   - Primary key: `event_id` (auto-increment)
   - Unique constraint: `(kafka_topic, kafka_partition, kafka_offset)`
   - Indexes: user_id, register_time, ingestion_timestamp

2. **stock_trades** - Stock trading transactions from `pdi-stocktrades` topic
   - Primary key: `trade_id` (auto-increment)
   - Unique constraint: `(kafka_topic, kafka_partition, kafka_offset)`
   - Indexes: symbol, trade_timestamp, user_id

3. **purchases** - E-commerce purchases from `pdi-purchases` topic
   - Primary key: `purchase_id` (auto-increment)
   - Unique constraint: `(kafka_topic, kafka_partition, kafka_offset)`
   - Indexes: customer_id, product_id, purchase_timestamp

4. **pageviews** - Website pageviews from `pdi-pageviews` topic
   - Primary key: `pageview_id` (auto-increment)
   - Unique constraint: `(kafka_topic, kafka_partition, kafka_offset)`
   - Indexes: user_id, session_id, pageview_timestamp

5. **kafka_staging** - Generic staging table for ETL patterns
   - Primary key: `staging_id` (auto-increment)
   - Unique constraint: `(topic, partition, offset)`
   - Indexes: processed, topic, created_at

6. **kafka_errors** - Error tracking and dead-letter queue
   - Primary key: `error_id` (auto-increment)
   - Indexes: topic, error_timestamp, resolved

7. **user_activity_hourly** - Aggregated user activity metrics
   - Unique constraint: `(hour_timestamp, user_id)`

8. **stock_trades_summary** - Per-minute trading summary by symbol
   - Unique constraint: `(minute_timestamp, symbol)`

#### Views Created

1. **v_recent_user_events** - User events from last 24 hours with lag metrics
2. **v_recent_stock_trades** - Stock trades from last hour with calculated values
3. **v_error_summary** - Hourly error summary by topic

#### Stored Procedures

1. **sp_cleanup_old_staging(retention_hours)** - Delete old processed staging records
2. **sp_retry_failed_messages(max_retry_count)** - Retry failed messages
3. **sp_check_ingestion_health()** - Check data ingestion health across topics

### MySQL Configuration

For optimal performance with streaming data, update your MySQL configuration:

**Linux**: `/etc/mysql/my.cnf` or `/etc/my.cnf`
**macOS**: `/usr/local/etc/my.cnf`
**Windows**: `C:\ProgramData\MySQL\MySQL Server X.X\my.ini`

```ini
[mysqld]
# InnoDB Settings
innodb_buffer_pool_size = 2G
innodb_log_file_size = 512M
innodb_flush_log_at_trx_commit = 2
innodb_flush_method = O_DIRECT

# Connection Settings
max_connections = 200
wait_timeout = 28800

# Disable query cache for write-heavy workloads
query_cache_type = 0
```

Restart MySQL after changes:
```bash
# Linux
sudo systemctl restart mysql

# macOS
brew services restart mysql

# Windows (as Administrator)
net stop MySQL
net start MySQL
```

### Security Best Practices

1. **Change the default password** in the script before running:
   ```sql
   CREATE USER IF NOT EXISTS 'kafka_user'@'%' IDENTIFIED BY 'YOUR_STRONG_PASSWORD';
   ```

2. **Restrict access by host** (optional):
   ```sql
   -- Instead of '%', use specific host
   CREATE USER 'kafka_user'@'localhost' IDENTIFIED BY 'password';
   CREATE USER 'kafka_user'@'192.168.1.%' IDENTIFIED BY 'password';
   ```

3. **Use SSL for connections** (recommended for production):
   ```sql
   REQUIRE SSL;
   ```

### Common Operations

#### View Table Statistics

```sql
USE kafka_warehouse;

SELECT
    table_name,
    table_rows,
    ROUND(data_length / 1024 / 1024, 2) as data_mb,
    ROUND(index_length / 1024 / 1024, 2) as index_mb,
    engine,
    create_time,
    update_time
FROM information_schema.tables
WHERE table_schema = 'kafka_warehouse'
ORDER BY data_length DESC;
```

#### Check Ingestion Health

```sql
CALL sp_check_ingestion_health();
```

#### Monitor Recent Activity

```sql
-- User events in last hour
SELECT COUNT(*) as user_events_count
FROM user_events
WHERE ingestion_timestamp >= DATE_SUB(NOW(), INTERVAL 1 HOUR);

-- Stock trades in last hour
SELECT COUNT(*) as stock_trades_count
FROM stock_trades
WHERE trade_timestamp >= DATE_SUB(NOW(), INTERVAL 1 HOUR);
```

#### Cleanup Old Staging Data

```sql
-- Delete staging records older than 24 hours
CALL sp_cleanup_old_staging(24);
```

#### Check for Errors

```sql
SELECT * FROM v_error_summary
ORDER BY error_hour DESC;
```

### Troubleshooting

#### Connection Refused

```bash
# Check if MySQL is running
sudo systemctl status mysql   # Linux
brew services list            # macOS

# Check if port 3306 is listening
netstat -an | grep 3306
```

#### Access Denied

```sql
-- Check user privileges
SHOW GRANTS FOR 'kafka_user'@'%';

-- Reset user password
ALTER USER 'kafka_user'@'%' IDENTIFIED BY 'new_password';
FLUSH PRIVILEGES;
```

#### Table Doesn't Exist

```bash
# Verify you're in the correct database
mysql -u kafka_user -p -e "USE kafka_warehouse; SHOW TABLES;"
```

#### Slow Inserts

```sql
-- Check index usage
SHOW INDEX FROM user_events;

-- Analyze table
ANALYZE TABLE user_events;

-- Check for locks
SHOW ENGINE INNODB STATUS\G
```

### Maintenance

#### Regular Maintenance Tasks

```sql
-- Optimize tables (run during low-usage periods)
OPTIMIZE TABLE user_events;
OPTIMIZE TABLE stock_trades;
OPTIMIZE TABLE purchases;

-- Update statistics
ANALYZE TABLE user_events;
ANALYZE TABLE stock_trades;
ANALYZE TABLE purchases;

-- Check table integrity
CHECK TABLE user_events;
```

#### Backup Database

```bash
# Full backup
mysqldump -u kafka_user -p kafka_warehouse > kafka_warehouse_backup.sql

# Backup with compression
mysqldump -u kafka_user -p kafka_warehouse | gzip > kafka_warehouse_backup.sql.gz

# Restore from backup
mysql -u kafka_user -p kafka_warehouse < kafka_warehouse_backup.sql
```

### Docker MySQL (Alternative)

If you prefer using Docker:

```bash
# Run MySQL in Docker
docker run -d \
  --name kafka-mysql \
  -e MYSQL_ROOT_PASSWORD=rootpassword \
  -e MYSQL_DATABASE=kafka_warehouse \
  -e MYSQL_USER=kafka_user \
  -e MYSQL_PASSWORD=your_password \
  -p 3306:3306 \
  -v mysql-data:/var/lib/mysql \
  mysql:8.0

# Wait for MySQL to start
sleep 10

# Execute setup script
docker exec -i kafka-mysql mysql -u kafka_user -pyour_password kafka_warehouse < 01-create-database-mysql.sql

# Connect to MySQL
docker exec -it kafka-mysql mysql -u kafka_user -p kafka_warehouse
```

### Next Steps

1. Verify all tables are created: `SHOW TABLES;`
2. Configure PDI connection to MySQL — see [Transformations Guide](../transformations/README.md#step-2-create-pdi-database-connection)
3. Deploy Kafka connectors — `make deploy-connectors`
4. Run PDI transformations — see [Transformations Guide](../transformations/README.md#step-5-run-transformation)
5. Monitor ingestion with provided queries and procedures

## Related Documentation

- [Main Workshop README](../README.md) — Workshop overview and quick start
- [Workshop Guide](../docs/WORKSHOP-GUIDE.md) — Complete guide (scenarios, configuration, troubleshooting)
- [Transformations Guide](../transformations/README.md) — PDI template configuration

---

**Script Version**: 1.0
**Last Updated**: 2026-02-23
**Compatible with**: MySQL 5.7+, MySQL 8.0+
