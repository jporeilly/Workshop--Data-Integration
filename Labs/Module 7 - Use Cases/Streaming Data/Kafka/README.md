# Pentaho Data Integration Kafka Workshop

Complete hands-on workshop for learning Kafka-based streaming data integration with Pentaho Data Integration (PDI) Kafka Enterprise Edition plugin.

## Documentation

| Document | Description |
|----------|-------------|
| **[docs/WORKSHOP-GUIDE.md](docs/WORKSHOP-GUIDE.md)** | Complete workshop guide — scenarios, configuration, troubleshooting |
| **[transformations/README.md](transformations/README.md)** | Transformation templates — setup, configuration, step-by-step |
| **[sql/README.md](sql/README.md)** | SQL scripts — database setup, tables, stored procedures |

---

## Quick Start

```bash
cd ~/Workshop--Data-Integration/Labs/Module\ 7\ -\ Use\ Cases/Streaming\ Data/Kafka
make workshop-start    # Start everything (Kafka + MySQL + connectors)
make verify            # Verify it's working
make help              # See all commands
```

### Prerequisites

- Pentaho Data Integration (Spoon) 9.4+ with Kafka EE plugin
- Docker and Docker Compose
- At least 8GB RAM available
- Ports 8083, 9021, 9090-9093 available

### Setup Options

**Option 1: One-command setup (recommended)**

```bash
make workshop-start    # Starts Kafka cluster, MySQL, and deploys data generators
make verify            # Verify everything is running
```

**Option 2: Step-by-step**

```bash
make setup             # Generate Kafka cluster configuration
make start             # Start Kafka cluster
make deploy-connectors # Deploy datagen connectors
make mysql-setup       # Start MySQL and verify tables
```

See the [Workshop Guide — Getting Started](docs/WORKSHOP-GUIDE.md#getting-started) for detailed setup instructions.

---

## Workshop Overview

This workshop demonstrates the Pentaho Data Integration Kafka EE plugin using real streaming data.

### What You'll Learn

- Configure Kafka Consumer and Producer steps in PDI
- Implement batch processing with configurable durations and record counts
- Work with offset management and timestamp-based data retrieval
- Handle different data formats (JSON, Avro, String)
- Implement security (SSL, SASL)
- Write streaming data to a MySQL data warehouse
- Monitor and manage Kafka consumer groups

### Duration

- **Beginner Path**: 2-3 hours
- **Intermediate Path**: 4-5 hours
- **Advanced Path**: 6+ hours

### Workshop Scenarios

The workshop includes 6 hands-on scenarios. See the [Workshop Guide — Scenarios](docs/WORKSHOP-GUIDE.md#workshop-scenarios) for full details.

| # | Scenario | Topic | Key Skills |
|---|----------|-------|------------|
| 1 | Basic Kafka Consumer | `pdi-users` | Consumer setup, batch processing, JSON parsing |
| 2 | High-Frequency Stock Trades | `pdi-stocktrades` | High-throughput, aggregation, concurrent batches |
| 3 | E-Commerce Purchases (Avro) | `pdi-purchases` | Avro format, Schema Registry, schema evolution |
| 4 | Time-Bounded Data Retrieval | `pdi-pageviews` | Offset timestamps, bounded processing |
| 5 | Multi-Topic Consumer + Producer | Multiple | Stream joins, Kafka Producer, enrichment |
| 6 | Security (SSL/SASL) | Any | SSL encryption, SASL authentication |

---

## Folder Structure

```
Kafka/
├── README.md                          # This file (entry point)
├── Makefile                           # Workshop automation commands
├── docker-compose-mysql.yml           # MySQL Docker configuration
├── docs/
│   └── WORKSHOP-GUIDE.md             # Complete workshop guide
├── connectors/                        # Kafka Connect datagen configurations
│   ├── deploy-connectors.sh
│   ├── pdi-users-datagen.json
│   ├── pdi-stocktrades-datagen.json
│   ├── pdi-purchases-datagen.json
│   └── pdi-pageviews-datagen.json
├── data-samples/                      # Sample data for reference
│   ├── sample-users.json
│   ├── sample-stocktrades.json
│   └── sample-purchases.json
├── scripts/                           # Helper scripts
│   ├── verify-workshop-environment.sh
│   ├── kafka-topics.sh
│   ├── kafka-console-consumer.sh
│   └── kafka-consumer-groups.sh
├── sql/                               # Database setup scripts
│   ├── README.md
│   └── 01-create-database-mysql-docker.sql
└── transformations/                   # PDI transformation templates
    ├── README.md
    ├── users-to-db-parent.ktr
    └── users-to-db-child.ktr
```

---

## Access Points

After running `make workshop-start`:

| Service | URL |
|---------|-----|
| Confluent Control Center | http://localhost:9021 |
| Kafka Connect API | http://localhost:8083 |
| Schema Registry | http://localhost:8081 |
| Prometheus | http://localhost:9090 |
| MySQL | `localhost:3306` (user: `kafka_user`, password: `kafka_password`) |

---

## Common Make Commands

```bash
# Workshop lifecycle
make workshop-start     # Start everything
make workshop-stop      # Stop everything
make workshop-restart   # Restart everything

# Kafka
make status             # Container status
make topics             # List topics
make consumers          # List consumer groups
make logs               # Stream logs

# MySQL
make mysql-setup        # Start MySQL + verify tables
make mysql-shell        # Connect to MySQL CLI
make mysql-verify       # Verify tables and data

# Diagnostics
make verify             # Full environment check
make test-connection    # Test all service ports
make monitor            # Monitoring dashboard
make connectors-status  # Check connector health

# Cleanup
make clean              # Stop and remove everything
```

Run `make help` for the complete list.

---

## Additional Resources

- [Pentaho Kafka Consumer Documentation](https://docs.pentaho.com/pdia-data-integration/pdi-transformation-steps-reference-overview/kafka-consumer)
- [Pentaho EE Marketplace Plugins](https://docs.pentaho.com/pentaho-data-integration-and-analytics/pentaho-ee-marketplace-plugins-release-notes)
- [Apache Kafka Documentation](https://kafka.apache.org/documentation/)
- [Confluent Platform Documentation](https://docs.confluent.io/)
- [Kafka Connect Datagen](https://github.com/confluentinc/kafka-connect-datagen)

---

**Workshop Version**: 2.0
**Last Updated**: 2026-02-23
**Kafka Version**: 3.4.0
**PDI Version**: 9.4+ with Kafka EE Plugin
