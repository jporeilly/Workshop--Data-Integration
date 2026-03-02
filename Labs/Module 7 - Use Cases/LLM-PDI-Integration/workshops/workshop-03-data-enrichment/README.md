# Workshop 3: Data Enrichment with LLM

Intelligent data enrichment using Ollama and Pentaho Data Integration.

## Quick Start

```bash
cd /home/pentaho/LLM-PDI-Integration/workshops/workshop-03-data-enrichment/transformations

# Run basic enrichment
~/Pentaho/design-tools/data-integration/pan.sh \
  -file=data_enrichment.ktr \
  -param:OLLAMA_URL=http://localhost:11434 \
  -param:MODEL_NAME=llama3.2:3b
```

## What You'll Learn

- ✅ Infer missing data from context (websites, phones, addresses)
- ✅ Classify companies by industry automatically
- ✅ Estimate company size from available information
- ✅ Enrich 20 incomplete customer records in ~60 seconds

## Workshop Structure

```
workshop-03-data-enrichment/
├── data/
│   └── customer_data_incomplete.csv    # 20 records with missing fields
├── transformations/
│   ├── data_enrichment.ktr             # Basic version
│   └── data_enrichment_optimized.ktr   # Optimized (parallel)
└── docs/
    └── workshop_3_data_enrichment.md   # Complete guide
```

## Sample Input → Output

**Input (Incomplete):**
```csv
customer_id,company_name,website,contact_name,phone,address,city,state,country
1001,Acme Corp,acmecorp.com,John Smith,,,,"CA",
1002,TechStart Inc,,,555-9876,123 Oak Ave,Los Angeles,,USA
```

**Output (Enriched):**
```csv
customer_id,enriched_company,enriched_website,enriched_contact,enriched_phone,enriched_address,enriched_city,enriched_state,enriched_country,industry,employee_range
1001,Acme Corp,www.acmecorp.com,John Smith,+1-415-555-ACME,UNKNOWN,San Francisco,CA,USA,Manufacturing,201-500
1002,TechStart Inc,www.techstart.com,UNKNOWN,+1-310-555-9876,123 Oak Ave,Los Angeles,CA,USA,Technology,11-50
```

**Enrichment Added:**
- 8 websites inferred (40%)
- 10 phone area codes added (50%)
- 6 cities inferred from state (30%)
- **20 industry classifications (100% new field)**
- **20 employee range estimates (100% new field)**

## Prerequisites

- Workshops 1 & 2 completed
- Ollama running with llama3.2:3b model
- PDI/Spoon installed

## Common Issues

| Issue | Solution |
|-------|----------|
| Too many UNKNOWN values | Increase temperature to 0.4-0.5 |
| Inaccurate industry | Add industry examples to prompt |
| Slow processing | Use optimized version with STEP_COPIES=4 |

## Next Steps

- Read [Complete Workshop Guide](docs/workshop_3_data_enrichment.md)
- Run transformations with your own data
- Explore [Workshop 4: Named Entity Recognition](#) (coming soon)

---

**Duration**: 75-90 minutes | **Level**: Intermediate | **Prerequisites**: Workshops 1 & 2
