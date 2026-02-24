-- ============================================
-- Pentaho Kafka Workshop - MySQL Docker Setup
-- ============================================
-- This script runs automatically when MySQL container starts for the first time
-- Database and user are created by docker-compose environment variables

USE kafka_warehouse;

-- ============================================
-- CREATE TABLES
-- ============================================

-- --------------------------------------------
-- User Events Table
-- Stores user registration events from pdi-users topic
-- --------------------------------------------
CREATE TABLE IF NOT EXISTS user_events (
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
    INDEX idx_ingestion_timestamp (ingestion_timestamp),
    UNIQUE KEY uq_kafka_offset (kafka_topic, kafka_partition, kafka_offset)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='User registration events from Kafka';

-- --------------------------------------------
-- Stock Trades Table
-- Stores stock trading transactions from pdi-stocktrades topic
-- --------------------------------------------
CREATE TABLE IF NOT EXISTS stock_trades (
    trade_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    symbol VARCHAR(20) NOT NULL,
    side VARCHAR(10) COMMENT 'BUY or SELL',
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
    INDEX idx_user_id (user_id),
    INDEX idx_symbol_timestamp (symbol, trade_timestamp),
    UNIQUE KEY uq_kafka_offset (kafka_topic, kafka_partition, kafka_offset)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Stock trading transactions from Kafka';

-- --------------------------------------------
-- Purchases Table
-- Stores e-commerce purchase transactions from pdi-purchases topic
-- --------------------------------------------
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Purchase transactions from Kafka';

-- --------------------------------------------
-- Pageviews Table
-- Stores website pageview events from pdi-pageviews topic
-- --------------------------------------------
CREATE TABLE IF NOT EXISTS pageviews (
    pageview_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id VARCHAR(100),
    page_url VARCHAR(500),
    referrer VARCHAR(500),
    session_id VARCHAR(100),
    ip_address VARCHAR(45),
    user_agent TEXT,
    pageview_timestamp TIMESTAMP NULL,
    kafka_topic VARCHAR(255),
    kafka_partition INT,
    kafka_offset BIGINT,
    ingestion_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_user_id (user_id),
    INDEX idx_session_id (session_id),
    INDEX idx_pageview_timestamp (pageview_timestamp),
    INDEX idx_page_url (page_url(255)),
    UNIQUE KEY uq_kafka_offset (kafka_topic, kafka_partition, kafka_offset)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Website pageview events from Kafka';

-- --------------------------------------------
-- Kafka Staging Table
-- Generic staging table for raw Kafka messages
-- Used in staged ETL pattern
-- --------------------------------------------
CREATE TABLE IF NOT EXISTS kafka_staging (
    staging_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    topic VARCHAR(255),
    partition INT,
    offset BIGINT,
    message_key TEXT,
    message_value TEXT,
    timestamp TIMESTAMP NULL,
    processed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    processed_at TIMESTAMP NULL,
    INDEX idx_processed (processed),
    INDEX idx_topic (topic),
    INDEX idx_created_at (created_at),
    INDEX idx_topic_processed (topic, processed),
    UNIQUE KEY uq_staging_offset (topic, partition, offset)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Staging table for raw Kafka messages';

-- --------------------------------------------
-- Kafka Errors Table
-- Stores processing errors and failed messages
-- Used for error tracking and dead-letter queue pattern
-- --------------------------------------------
CREATE TABLE IF NOT EXISTS kafka_errors (
    error_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    topic VARCHAR(255),
    partition INT,
    offset BIGINT,
    error_message TEXT,
    error_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    raw_message TEXT,
    retry_count INT DEFAULT 0,
    last_retry_timestamp TIMESTAMP NULL,
    resolved BOOLEAN DEFAULT FALSE,
    INDEX idx_topic (topic),
    INDEX idx_error_timestamp (error_timestamp),
    INDEX idx_resolved (resolved),
    INDEX idx_retry_count (retry_count)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Error tracking for failed Kafka message processing';

-- ============================================
-- CREATE SUMMARY/AGGREGATION TABLES
-- ============================================

-- --------------------------------------------
-- User Activity Summary (Hourly)
-- Aggregated user activity metrics
-- --------------------------------------------
CREATE TABLE IF NOT EXISTS user_activity_hourly (
    summary_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    hour_timestamp TIMESTAMP,
    user_id VARCHAR(100),
    region_id VARCHAR(100),
    activity_count INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_hour_timestamp (hour_timestamp),
    INDEX idx_user_id (user_id),
    UNIQUE KEY uq_user_hour (hour_timestamp, user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Hourly aggregated user activity';

-- --------------------------------------------
-- Stock Trading Summary (Per Symbol, Per Minute)
-- Aggregated trading metrics
-- --------------------------------------------
CREATE TABLE IF NOT EXISTS stock_trades_summary (
    summary_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    minute_timestamp TIMESTAMP,
    symbol VARCHAR(20),
    trade_count INT DEFAULT 0,
    total_volume BIGINT DEFAULT 0,
    avg_price DECIMAL(10,2),
    min_price DECIMAL(10,2),
    max_price DECIMAL(10,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_minute_timestamp (minute_timestamp),
    INDEX idx_symbol (symbol),
    INDEX idx_symbol_timestamp (symbol, minute_timestamp),
    UNIQUE KEY uq_symbol_minute (minute_timestamp, symbol)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Per-minute trading summary by symbol';

-- ============================================
-- CREATE VIEWS
-- ============================================

-- Recent user events (last 24 hours)
CREATE OR REPLACE VIEW v_recent_user_events AS
SELECT
    event_id,
    user_id,
    region_id,
    gender,
    register_time,
    kafka_topic,
    kafka_partition,
    kafka_offset,
    ingestion_timestamp,
    TIMESTAMPDIFF(SECOND, register_time, ingestion_timestamp) as processing_lag_seconds
FROM user_events
WHERE ingestion_timestamp >= DATE_SUB(NOW(), INTERVAL 24 HOUR);

-- Recent stock trades with metrics
CREATE OR REPLACE VIEW v_recent_stock_trades AS
SELECT
    trade_id,
    symbol,
    side,
    quantity,
    price,
    quantity * price as trade_value,
    account,
    user_id,
    trade_timestamp,
    kafka_topic,
    kafka_partition,
    kafka_offset
FROM stock_trades
WHERE trade_timestamp >= DATE_SUB(NOW(), INTERVAL 1 HOUR);

-- Error summary
CREATE OR REPLACE VIEW v_error_summary AS
SELECT
    topic,
    DATE_FORMAT(error_timestamp, '%Y-%m-%d %H:00:00') as error_hour,
    COUNT(*) as error_count,
    SUM(CASE WHEN resolved = TRUE THEN 1 ELSE 0 END) as resolved_count,
    SUM(CASE WHEN resolved = FALSE THEN 1 ELSE 0 END) as unresolved_count,
    AVG(retry_count) as avg_retry_count
FROM kafka_errors
WHERE error_timestamp >= DATE_SUB(NOW(), INTERVAL 7 DAY)
GROUP BY topic, error_hour;

-- ============================================
-- CREATE STORED PROCEDURES
-- ============================================

DELIMITER $$

-- Procedure to cleanup old staging records
CREATE PROCEDURE IF NOT EXISTS sp_cleanup_old_staging(IN retention_hours INT)
BEGIN
    DELETE FROM kafka_staging
    WHERE processed = TRUE
    AND created_at < DATE_SUB(NOW(), INTERVAL retention_hours HOUR);

    SELECT ROW_COUNT() as deleted_rows;
END$$

-- Procedure to retry failed messages
CREATE PROCEDURE IF NOT EXISTS sp_retry_failed_messages(IN max_retry_count INT)
BEGIN
    UPDATE kafka_errors
    SET retry_count = retry_count + 1,
        last_retry_timestamp = NOW()
    WHERE resolved = FALSE
    AND retry_count < max_retry_count;

    SELECT ROW_COUNT() as updated_rows;
END$$

-- Procedure to check data ingestion health
CREATE PROCEDURE IF NOT EXISTS sp_check_ingestion_health()
BEGIN
    SELECT
        kafka_topic,
        COUNT(*) as record_count,
        MAX(ingestion_timestamp) as last_ingestion,
        TIMESTAMPDIFF(SECOND, MAX(ingestion_timestamp), NOW()) as seconds_since_last_ingestion
    FROM user_events
    WHERE ingestion_timestamp > DATE_SUB(NOW(), INTERVAL 1 HOUR)
    GROUP BY kafka_topic

    UNION ALL

    SELECT
        kafka_topic,
        COUNT(*) as record_count,
        MAX(ingestion_timestamp) as last_ingestion,
        TIMESTAMPDIFF(SECOND, MAX(ingestion_timestamp), NOW()) as seconds_since_last_ingestion
    FROM stock_trades
    WHERE trade_timestamp > DATE_SUB(NOW(), INTERVAL 1 HOUR)
    GROUP BY kafka_topic;
END$$

DELIMITER ;

-- ============================================
-- VERIFY SETUP
-- ============================================

SELECT 'Database initialization complete!' as Status;
SELECT COUNT(*) as TableCount FROM information_schema.tables WHERE table_schema = 'kafka_warehouse';
