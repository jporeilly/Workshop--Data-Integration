# Workshop 4: Named Entity Recognition

Extract and classify named entities from unstructured text using LLMs and Pentaho Data Integration.

## Quick Start

```bash
# 1. Ensure Ollama is running
curl http://localhost:11434/api/tags

# 2. Run basic transformation
cd /home/pentaho/LLM-PDI-Integration/workshops/workshop-04-named-entity-recognition/transformations
/opt/pentaho/data-integration/pan.sh -file=named_entity_recognition.ktr

# 3. Run optimized version (3-4x faster)
/opt/pentaho/data-integration/pan.sh -file=named_entity_recognition_optimized.ktr

# 4. View results
ls -lt ../data/entities_extracted_*.csv | head -1
cat <latest_file> | head -5
```

## What This Workshop Covers

- Extract 10 entity types: PERSON, ORGANIZATION, LOCATION, DATE, PRODUCT, MONEY, CONTACT, ID, TECHNOLOGY, POSITION
- Process 20 diverse document types: emails, contracts, tickets, reports, invoices, etc.
- Build NER prompts for accurate entity extraction
- Optimize performance with parallel processing
- Count and analyze entity distributions

## Sample Input

```csv
document_id,source,text
1,customer_email,"Hi, this is Sarah Johnson from Acme Corporation. I'm writing about the order I placed on December 15th, 2024. My customer ID is CUST-98765. Please contact me at sarah.johnson@acmecorp.com or call 555-123-4567."
```

## Sample Output

```csv
document_id,entity_count,person_count,org_count,location_count,date_count,entities_json
1,7,1,1,1,1,"[{\"entity\":\"Sarah Johnson\",\"type\":\"PERSON\",\"context\":\"this is Sarah Johnson from\"},{\"entity\":\"Acme Corporation\",\"type\":\"ORGANIZATION\",\"context\":\"Sarah Johnson from Acme Corporation\"}...]"
```

## Extracted Entity Example

```json
[
  {"entity": "Sarah Johnson", "type": "PERSON", "context": "this is Sarah Johnson from"},
  {"entity": "Acme Corporation", "type": "ORGANIZATION", "context": "Sarah Johnson from Acme Corporation"},
  {"entity": "December 15th, 2024", "type": "DATE", "context": "order I placed on December 15th"},
  {"entity": "CUST-98765", "type": "ID", "context": "customer ID is CUST-98765"},
  {"entity": "sarah.johnson@acmecorp.com", "type": "CONTACT", "context": "contact me at sarah.johnson@acmecorp.com"},
  {"entity": "555-123-4567", "type": "CONTACT", "context": "or call 555-123-4567"},
  {"entity": "123 Main Street, San Francisco, CA 94102", "type": "LOCATION", "context": "located at 123 Main Street"}
]
```

## Files

- `data/unstructured_text.csv` - 20 sample documents of various types
- `transformations/named_entity_recognition.ktr` - Basic NER transformation
- `transformations/named_entity_recognition_optimized.ktr` - Optimized version with parallel processing
- `docs/workshop_4_named_entity_recognition.md` - Complete workshop guide

## Performance

| Version | Time (20 docs) | Speedup |
|---------|----------------|---------|
| Basic | 60-80 seconds | 1x |
| Optimized | 15-25 seconds | **3-4x** |

## Entity Types Extracted

1. **PERSON** - Names of people (Sarah Johnson, Dr. Michael Chen)
2. **ORGANIZATION** - Companies, institutions (Acme Corp, Stanford University)
3. **LOCATION** - Cities, addresses (San Francisco, 123 Main St)
4. **DATE** - Dates and times (December 15th 2024, 10:30 AM PST)
5. **PRODUCT** - Product names (iPhone 16, UltraBook Pro X1)
6. **MONEY** - Currency amounts ($125,000, £250,000 GBP)
7. **CONTACT** - Emails, phones (user@company.com, 555-123-4567)
8. **ID** - Identifiers (CUST-98765, INV-2024-0089)
9. **TECHNOLOGY** - Software, platforms (AWS, Python, TensorFlow)
10. **POSITION** - Job titles (CEO, Project Manager, CFO)

## Use Cases

- Customer service: Extract names, IDs, products from support tickets
- Legal/Compliance: Identify parties, dates, amounts in contracts
- Log analysis: Extract usernames, IPs, error codes, timestamps
- Business intelligence: Pull companies, products, revenue from reports
- Document processing: Auto-tag and categorize documents by entities

## Documentation

See [docs/workshop_4_named_entity_recognition.md](docs/workshop_4_named_entity_recognition.md) for:
- Detailed workshop guide (60-90 minutes)
- Understanding NER and entity types
- Step-by-step transformation building
- Advanced techniques (disambiguation, normalization, relationships)
- Performance tuning and troubleshooting
- Integration patterns and best practices

## Parameters

**Basic Transformation:**
- `OLLAMA_URL` - Ollama API endpoint (default: http://localhost:11434/api/generate)
- `MODEL_NAME` - LLM model (default: llama3.2:3b)

**Optimized Transformation:**
- `OLLAMA_URL` - Ollama API endpoint
- `MODEL_NAME` - LLM model
- `KEEP_ALIVE` - Keep model in memory (default: 15m)
- `STEP_COPIES` - Parallel API calls (default: 4)

## Next Steps

1. Review complete workshop guide: `docs/workshop_4_named_entity_recognition.md`
2. Run basic transformation to understand the workflow
3. Run optimized version to see performance improvements
4. Customize entity types for your domain
5. Build entity extraction into your document processing pipelines
