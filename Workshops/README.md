# Pentaho Data Integration Workshops

This directory contains hands-on workshop materials for learning Pentaho Data Integration (PDI).

## Available Workshops

| Workshop | Description | Prerequisites | Duration |
|----------|-------------|---------------|----------|
| [PDI-MinIO-Transformations](PDI-MinIO-Transformations/README.md) | Build intermediate-to-advanced transformations using MinIO sample data | MinIO running, PDI installed | 4-6 hours |

## Getting Started

### 1. Environment Setup

Before starting any workshop, ensure you have:

1. **Pentaho Data Integration** installed
   - Download from [Hitachi Vantara](https://www.hitachivantara.com/en-us/products/pentaho-platform/data-integration-analytics.html)
   - Or use community edition from [SourceForge](https://sourceforge.net/projects/pentaho/)

2. **Java 11+** installed and configured
   ```bash
   java -version
   ```

3. **MinIO** running with sample data (for MinIO workshops)
   ```bash
   # Start MinIO
   sudo /opt/minio/run-docker-minio.sh

   # Populate sample data
   /opt/minio/populate-minio.sh

   # Verify
   curl -sf http://localhost:9000/minio/health/live && echo "OK"
   ```

### 2. Workshop Structure

Each workshop follows this structure:

```
Workshop-Name/
├── README.md           # Main workshop instructions
├── solutions/          # Completed transformation files (.ktr, .kjb)
├── data/              # Additional sample data (if any)
└── resources/         # Supporting materials
```

### 3. Difficulty Levels

- **Beginner**: Basic steps, single data sources
- **Intermediate**: Multiple sources, joins, aggregations
- **Advanced**: Complex transformations, error handling, optimization

## Workshop Quick Links

### PDI-MinIO-Transformations

| Exercise | Difficulty | Key Concepts |
|----------|------------|--------------|
| [Sales Dashboard ETL](PDI-MinIO-Transformations/README.md#exercise-1-sales-performance-dashboard-etl) | Beginner-Intermediate | CSV input, lookups, joins |
| [Inventory Reconciliation](PDI-MinIO-Transformations/README.md#exercise-2-inventory-reconciliation-xml--csv) | Intermediate | XML parsing, outer joins |
| [Customer 360](PDI-MinIO-Transformations/README.md#exercise-3-customer-360-view) | Intermediate | Multi-source, JSONL, aggregations |
| [Clickstream Funnel](PDI-MinIO-Transformations/README.md#exercise-4-clickstream-funnel-analysis) | Intermediate-Advanced | Sessionization, pivoting |
| [Log Parsing](PDI-MinIO-Transformations/README.md#exercise-5-log-parsing-and-anomaly-detection) | Advanced | Regex, anomaly detection |
| [Multi-Format Ingestion](PDI-MinIO-Transformations/README.md#exercise-6-multi-format-data-lake-ingestion) | Advanced | Schema normalization |

## Contributing

To add a new workshop:

1. Create a new directory under `Workshops/`
2. Include a comprehensive `README.md` with step-by-step instructions
3. Provide solution files for reference
4. Update this index file

## Support

- **PDI Documentation**: [Hitachi Vantara Help](https://help.hitachivantara.com/Documentation/Pentaho)
- **Community Forums**: [Hitachi Vantara Community](https://community.hitachivantara.com/)
- **MinIO Issues**: See [MinIO README-POPULATE.md](../Setup/MinIO/README-POPULATE.md)
