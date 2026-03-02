# Workshop 4 Summary: Named Entity Recognition

## Overview

Workshop 4 teaches Named Entity Recognition (NER) using LLMs and Pentaho Data Integration. Extract and classify 10 entity types from 20 diverse document formats.

## Key Capabilities

### Entity Types (10)
1. **PERSON** - Individual names with titles
2. **ORGANIZATION** - Companies, institutions, agencies
3. **LOCATION** - Cities, addresses, buildings, regions
4. **DATE** - Dates, times, quarters, relative dates
5. **PRODUCT** - Product names, models, versions
6. **MONEY** - Currency amounts, revenue figures
7. **CONTACT** - Email addresses, phone numbers, extensions
8. **ID** - Customer IDs, order numbers, tracking codes
9. **TECHNOLOGY** - Languages, frameworks, platforms, cloud services
10. **POSITION** - Job titles, roles, professional designations

### Document Types Processed (20)
- Customer emails
- Support tickets
- Sales notes
- Contracts
- Security incidents
- Meeting notes
- Press releases
- Product reviews
- Legal notices
- HR memos
- Financial reports
- Shipping manifests
- Blog posts
- Invoices
- Research abstracts
- Social media posts
- Email threads
- Warranty claims
- Job postings
- Medical records

## Transformations

### Basic Transformation: `named_entity_recognition.ktr`

**Purpose:** Educational version with detailed prompts for learning NER concepts.

**Workflow:**
1. Read Unstructured Text (CSV Input) - Load 20 diverse documents
2. Build NER Prompt (JavaScript) - Create detailed extraction prompt (1,019 chars)
3. Build JSON Request (JavaScript) - Construct Ollama API request
4. Call Ollama API (REST Client) - Send to LLM for entity extraction
5. Parse NER Response (JavaScript) - Extract entities array, count by type
6. Write Entities CSV (Text Output) - Save with entity_count, type counts, entities_json

**Output Fields:**
- document_id, source, text (original)
- entity_count (total entities extracted)
- person_count, org_count, location_count, date_count (type breakdowns)
- entities_json (full array: [{entity, type, context},...])

**Performance:**
- Processing time: 60-80 seconds for 20 documents
- ~3-4 seconds per document (sequential)
- Total entities: 200-300+ across all documents

**Prompt Structure:**
```
Extract all named entities. Return JSON: [{entity, type, context}]

Entity Types:
- PERSON: Names with examples
- ORGANIZATION: Companies with examples
- ... (10 types total)

Rules:
- Extract ALL entities
- Include context (words before/after)
- Exact text as appears
- JSON only
```

### Optimized Transformation: `named_entity_recognition_optimized.ktr`

**Purpose:** Production-ready version with 3-4x performance improvement.

**Optimizations:**

1. **Parallel Processing**
   - 4 concurrent REST Client copies
   - `${STEP_COPIES}` parameter (default: 4)
   - Distributes documents across parallel streams

2. **Compact Prompt**
   - Original: 1,019 characters
   - Optimized: 229 characters
   - **77.5% reduction**
   - Maintains all 10 entity types
   - Example: "Extract entities as JSON: [{entity,type,context}]. Types: PERSON,ORGANIZATION,... Rules: Extract all. Include context. Exact text. JSON only."

3. **Keep-Alive**
   - Model stays in memory between requests
   - `${KEEP_ALIVE}` parameter (default: 15m)
   - Eliminates model reload overhead

4. **Optimized Parameters**
   - temperature: 0.1 (consistent extraction)
   - num_predict: 1000 (sufficient for most documents)
   - num_thread: 0 (use all available cores)

**Performance:**
- Processing time: 15-25 seconds for 20 documents
- ~0.5-0.8 seconds per document (parallelized)
- **3-4x faster than basic version**

**Performance Comparison:**

| Version | Time (20 docs) | Docs/sec | Speedup |
|---------|----------------|----------|---------|
| Basic | 60-80 seconds | 0.25-0.33 | 1x |
| Optimized | 15-25 seconds | 0.80-1.33 | **3-4x** |

## Sample Data

**File:** `data/unstructured_text.csv`

**Structure:**
- document_id: 1-20
- source: Document type (customer_email, support_ticket, contract, etc.)
- text: Unstructured text content (50-300 words)

**Sample Document:**
```
document_id: 1
source: customer_email
text: "Hi, this is Sarah Johnson from Acme Corporation. I'm writing to inquire
about the order I placed on December 15th, 2024. My customer ID is CUST-98765.
Please contact me at sarah.johnson@acmecorp.com or call 555-123-4567. Our
office is located at 123 Main Street, San Francisco, CA 94102."
```

**Expected Entities (7):**
- Sarah Johnson (PERSON)
- Acme Corporation (ORGANIZATION)
- December 15th, 2024 (DATE)
- CUST-98765 (ID)
- sarah.johnson@acmecorp.com (CONTACT)
- 555-123-4567 (CONTACT)
- 123 Main Street, San Francisco, CA 94102 (LOCATION)

## Key JavaScript Code

### Build NER Prompt (Basic)

```javascript
var llm_prompt = "Extract all named entities from the following text. Return ONLY a valid JSON array of entities.\n\n" +
  "Format: [{\"entity\":\"entity text\",\"type\":\"ENTITY_TYPE\",\"context\":\"surrounding context\"},...]\n\n" +
  "Entity Types to Extract:\n" +
  "- PERSON: Names of people (e.g., John Smith, Dr. Sarah Johnson)\n" +
  "- ORGANIZATION: Companies, institutions, agencies (e.g., Acme Corp, FBI, Stanford University)\n" +
  "- LOCATION: Cities, countries, addresses, buildings (e.g., San Francisco, 123 Main St, Room 405)\n" +
  "- DATE: Dates and times (e.g., December 15th 2024, Feb 1st, 10:30 AM PST)\n" +
  "- PRODUCT: Product names and models (e.g., iPhone 16, UltraBook Pro X1)\n" +
  "- MONEY: Currency amounts (e.g., $125,000, £250,000 GBP)\n" +
  "- CONTACT: Email addresses and phone numbers (e.g., user@company.com, 555-123-4567)\n" +
  "- ID: Identifiers like customer IDs, order numbers, tracking codes (e.g., CUST-98765, INV-2024-0089)\n" +
  "- TECHNOLOGY: Software, platforms, technical terms (e.g., AWS, Python, TensorFlow)\n" +
  "- POSITION: Job titles and roles (e.g., CEO, Project Manager, CFO)\n\n" +
  "Rules:\n" +
  "- Extract ALL entities you can identify\n" +
  "- Include context: a few words before/after the entity\n" +
  "- Be precise: extract exact text as it appears\n" +
  "- Return ONLY the JSON array, no explanation\n\n" +
  "TEXT TO ANALYZE:\n" +
  text;
```

### Build NER Prompt (Optimized)

```javascript
var llm_prompt = "Extract entities as JSON: [{\"entity\":\"\",\"type\":\"\",\"context\":\"\"}]. " +
  "Types: PERSON,ORGANIZATION,LOCATION,DATE,PRODUCT,MONEY,CONTACT,ID,TECHNOLOGY,POSITION. " +
  "Rules: Extract all. Include context. Exact text. JSON only.\nText: " + text;
```

### Build JSON Request (Optimized)

```javascript
var model_name = getVariable("MODEL_NAME", "llama3.2:3b");
var keep_alive = getVariable("KEEP_ALIVE", "15m");

var requestObj = {
    "model": model_name,
    "prompt": llm_prompt,
    "stream": false,
    "keep_alive": keep_alive,
    "format": "json",
    "options": {
        "temperature": 0.1,
        "num_predict": 1000,
        "num_thread": 0
    }
};

var request_body = JSON.stringify(requestObj);
```

### Parse NER Response

```javascript
var entities_json = "[]";
var entity_count = 0;
var person_count = 0;
var org_count = 0;
var location_count = 0;
var date_count = 0;

try {
    var response = JSON.parse(api_response);
    var fullResponse = response.response;

    // Extract JSON array from response
    var jsonStart = fullResponse.indexOf("[");
    var jsonEnd = fullResponse.lastIndexOf("]") + 1;

    if (jsonStart >= 0 && jsonEnd > jsonStart) {
        var jsonStr = fullResponse.substring(jsonStart, jsonEnd);
        entities_json = jsonStr;

        // Count entities by type
        var entities = JSON.parse(jsonStr);
        entity_count = entities.length;

        for (var i = 0; i < entities.length; i++) {
            var entityType = entities[i].type || "";
            if (entityType == "PERSON") person_count++;
            else if (entityType == "ORGANIZATION") org_count++;
            else if (entityType == "LOCATION") location_count++;
            else if (entityType == "DATE") date_count++;
        }
    }
} catch(e) {
    entities_json = "[]";
    entity_count = 0;
}
```

## Advanced Techniques (From Workshop Guide)

### Entity Disambiguation
- Resolve ambiguous entities based on context
- Example: "Apple" → fruit vs company vs record label
- Add "disambiguation" field explaining the choice

### Entity Normalization
- Standardize entity formats
- Dates → ISO 8601 (YYYY-MM-DD)
- Phone numbers → E.164 (+1XXXXXXXXXX)
- Addresses → standardized format

### Confidence Scoring
- Add confidence percentage to each entity
- Filter low-confidence entities (< 70%)
- Useful for high-precision applications

### Entity Relationships
- Extract not just entities, but relationships between them
- Example: "Sarah Johnson works_at Acme Corp"
- JSON: {subject, predicate, object}

### Multi-Language NER
- Extract entities from multiple languages
- Detect language automatically
- Provide English translations

### Hierarchical Extraction
- Extract nested entity structures
- Location hierarchy: city → state → country → continent
- Organization hierarchy: product → division → parent company

## Parameters

### Basic Transformation
| Parameter | Default | Description |
|-----------|---------|-------------|
| OLLAMA_URL | http://localhost:11434/api/generate | Ollama API endpoint |
| MODEL_NAME | llama3.2:3b | LLM model for NER |

### Optimized Transformation
| Parameter | Default | Description |
|-----------|---------|-------------|
| OLLAMA_URL | http://localhost:11434/api/generate | Ollama API endpoint |
| MODEL_NAME | llama3.2:3b | LLM model for NER |
| KEEP_ALIVE | 15m | Keep model in memory |
| STEP_COPIES | 4 | Parallel API call copies |

**Tuning Recommendations:**
- STEP_COPIES: Set to CPU cores - 1 (4-core = 3, 8-core = 7)
- KEEP_ALIVE: 5m (infrequent), 15m (regular), 30m (continuous), 60m (always-on)
- MODEL_NAME: llama3.2:1b (fastest), llama3.2:3b (balanced), llama3.1:8b (most accurate)

## Use Cases

1. **Customer Service**
   - Extract customer names, IDs, product references from support tickets
   - Auto-categorize tickets by mentioned products/issues
   - Route to appropriate teams based on entity types

2. **Legal/Compliance**
   - Identify parties, dates, amounts in contracts
   - Extract obligations and deadlines
   - Build searchable contract database

3. **Log Analysis**
   - Extract usernames, IP addresses, error codes, timestamps
   - Correlate events by entity mentions
   - Security incident investigation

4. **Business Intelligence**
   - Pull company names, products, revenue figures from reports
   - Track competitor mentions in market research
   - Analyze executive communications

5. **Healthcare**
   - Extract patient names, medications, dates from medical records
   - Identify diagnosis codes, procedures, doctors
   - Ensure HIPAA compliance with entity masking

6. **Email Processing**
   - Identify senders, recipients, mentioned people
   - Extract action items with dates and responsibilities
   - Auto-tag emails by entity content

## Common Issues and Solutions

### Issue: No Entities Extracted
**Solution:** Ensure `"format": "json"` in API request, lower temperature to 0.0-0.1

### Issue: Partial Extraction
**Solution:** Increase `num_predict` from 1000 to 2000, emphasize "extract ALL" in prompt

### Issue: Incorrect Entity Types
**Solution:** Add more examples for each entity type in prompt, clarify type definitions

### Issue: Malformed JSON
**Solution:** Robust JSON extraction (find brackets, handle code blocks, validate before storing)

### Issue: Slow Performance
**Solution:** Verify keep_alive working, increase STEP_COPIES, use llama3.2:1b or llama3.2:3b

## Integration Patterns

1. **Real-Time API** - REST service accepting text, returning entities
2. **Batch Processing** - Process document repositories overnight
3. **Streaming Extraction** - Watch directory, auto-process new files
4. **Entity Database** - Populate structured DB with extracted entities

## Learning Outcomes

After completing this workshop, you can:

1. Understand Named Entity Recognition and its 10 common entity types
2. Build effective NER prompts for LLM extraction
3. Process diverse document types (emails, contracts, reports, etc.)
4. Extract structured entities from unstructured text
5. Optimize NER performance with parallel processing (3-4x speedup)
6. Count and analyze entity distributions
7. Apply advanced techniques (disambiguation, normalization, relationships)
8. Integrate NER into document processing pipelines
9. Tune performance parameters for your use case
10. Troubleshoot common NER issues

## Files Created

```
workshops/workshop-04-named-entity-recognition/
├── data/
│   └── unstructured_text.csv (20 sample documents)
├── transformations/
│   ├── named_entity_recognition.ktr (basic)
│   └── named_entity_recognition_optimized.ktr (optimized)
├── docs/
│   └── workshop_4_named_entity_recognition.md (complete guide)
├── README.md (quick start)
└── WORKSHOP_SUMMARY.md (this file)
```

## Next Steps

1. Complete the 60-90 minute workshop guide
2. Run both transformations on sample data
3. Customize entity types for your domain
4. Process your own documents
5. Build entity extraction into your pipelines
6. Explore advanced techniques (relationships, confidence scoring)
7. Integrate with downstream systems (databases, search engines)

## Documentation

See [docs/workshop_4_named_entity_recognition.md](docs/workshop_4_named_entity_recognition.md) for:
- Complete workshop guide (60-90 minutes)
- Detailed entity type specifications
- Step-by-step transformation building
- Advanced NER techniques
- Performance tuning strategies
- Integration patterns
- Troubleshooting guide
- Complete code reference
