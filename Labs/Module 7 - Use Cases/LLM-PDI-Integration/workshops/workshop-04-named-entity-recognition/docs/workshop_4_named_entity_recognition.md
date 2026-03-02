# Workshop 4: Named Entity Recognition with LLMs

## Overview

This workshop demonstrates how to use Large Language Models (LLMs) with Pentaho Data Integration (PDI) to extract and classify **named entities** from unstructured text. Named Entity Recognition (NER) is a critical NLP task that identifies and categorizes entities like people, organizations, locations, dates, and more.

**Workshop Duration:** 60-90 minutes

**Difficulty Level:** Intermediate

**Prerequisites:**
- Completed Workshop 1, 2, or 3 (familiarity with LLM integration in PDI)
- Basic understanding of PDI transformations
- Ollama installed with llama3.2:3b model
- Familiarity with JSON format

## What You'll Learn

1. Understanding Named Entity Recognition and its applications
2. Building NER prompts for LLM extraction
3. Processing diverse document types (emails, contracts, reports, etc.)
4. Extracting 10+ entity types with contextual information
5. Optimizing NER performance with parallel processing
6. Counting and analyzing entity distributions

## Architecture Overview

```
┌────────────────────────┐
│  Read Unstructured     │  Read documents with
│  Text (CSV Input)      │  various text formats
└──────────┬─────────────┘
           │
           ▼
┌────────────────────────┐
│  Build NER Prompt      │  Create entity extraction
│  (JavaScript)          │  prompt with 10 types
└──────────┬─────────────┘
           │
           ▼
┌────────────────────────┐
│  Build JSON Request    │  Construct Ollama API request
│  (JavaScript)          │  with NER parameters
└──────────┬─────────────┘
           │
           ▼
┌────────────────────────┐
│  Call Ollama API       │  Send request to LLM for
│  (REST Client - 4x)    │  entity extraction
└──────────┬─────────────┘  **PARALLEL: 4 copies**
           │
           ▼
┌────────────────────────┐
│  Parse NER Response    │  Extract entities array,
│  (JavaScript)          │  count by type
└──────────┬─────────────┘
           │
           ▼
┌────────────────────────┐
│  Pivot Entities to     │  Convert JSON array to
│  Columns (Python)      │  separate entity columns
└──────────┬─────────────┘  **NEW: Wide format output**
           │
           ▼
┌────────────────────────┐
│  Write Entities CSV    │  Output with entity_1,
│  (CSV Output)          │  entity_type_1, etc.
└────────────────────────┘
```

### Workflow Explanation

1. **Read Unstructured Text** - Loads documents from CSV containing diverse text formats: emails, contracts, support tickets, reports, etc.
2. **Build NER Prompt** - JavaScript step constructs optimized extraction prompt specifying 10 entity types (PERSON, ORGANIZATION, LOCATION, DATE, PRODUCT, MONEY, CONTACT, ID, TECHNOLOGY, POSITION)
3. **Build JSON Request** - Prepares Ollama API request with model (`llama3.2:3b`), prompt, keep-alive parameter, JSON format requirement, and temperature 0.1 for consistent extraction
4. **Call Ollama API (Parallel)** - REST Client sends POST request to `http://localhost:11434/api/generate` using 4 parallel copies for 3-4x performance improvement
5. **Parse NER Response** - JavaScript extracts entity array from LLM JSON response, counts total entities and breaks down by type (person_count, org_count, location_count, date_count)
6. **Pivot Entities to Columns** - Python Script step converts the JSON array into separate columns (entity_1, entity_type_1, entity_2, entity_type_2, etc.) for easy analysis in Excel and databases
7. **Write Entities CSV** - Outputs final dataset with original document fields plus 30 entity columns (up to 15 entities per document) in wide format for easy filtering and analysis

## Part 1: Understanding Named Entity Recognition (15 minutes)

### What is Named Entity Recognition?

Named Entity Recognition (NER) is the process of identifying and classifying named entities in unstructured text into predefined categories.

**Example Input:**
```
"Hi, this is Sarah Johnson from Acme Corporation. I'm writing about the order
I placed on December 15th, 2024. Please contact me at sarah.johnson@acmecorp.com"
```

**Example Output (Extracted Entities):**
```json
[
  {"entity": "Sarah Johnson", "type": "PERSON", "context": "this is Sarah Johnson from"},
  {"entity": "Acme Corporation", "type": "ORGANIZATION", "context": "Sarah Johnson from Acme Corporation"},
  {"entity": "December 15th, 2024", "type": "DATE", "context": "order I placed on December 15th"},
  {"entity": "sarah.johnson@acmecorp.com", "type": "CONTACT", "context": "contact me at sarah.johnson@acmecorp.com"}
]
```

### Entity Types in This Workshop

| Entity Type | Description | Examples |
|------------|-------------|----------|
| **PERSON** | Names of people | Sarah Johnson, Dr. Michael Chen, CEO Richard Davis |
| **ORGANIZATION** | Companies, institutions | Acme Corp, Stanford University, FBI |
| **LOCATION** | Cities, addresses, buildings | San Francisco, 123 Main St, Room 405 |
| **DATE** | Dates and times | December 15th 2024, Feb 1st, 10:30 AM PST |
| **PRODUCT** | Product names/models | iPhone 16, UltraBook Pro X1, Widget X-200 |
| **MONEY** | Currency amounts | $125,000, £250,000 GBP, $1,899.99 |
| **CONTACT** | Emails, phone numbers | user@company.com, 555-123-4567, ext. 4521 |
| **ID** | Identifiers, tracking codes | CUST-98765, INV-2024-0089, ORD-2025-5678 |
| **TECHNOLOGY** | Software, platforms | AWS, Python, TensorFlow, Docker |
| **POSITION** | Job titles, roles | CEO, Project Manager, CFO, VP of Engineering |

### Why Use LLMs for NER?

Traditional NER approaches (rule-based, statistical models, pre-trained NER models) have limitations:

**Traditional Approach Challenges:**
- Requires extensive labeled training data
- Struggles with domain-specific entities
- Fixed entity type schemas
- Poor performance on new/rare entity types
- Cannot adapt to context easily

**LLM-Based NER Advantages:**
- Zero-shot extraction (no training data needed)
- Flexible entity type definitions
- Handles multiple domains simultaneously
- Contextual understanding (disambiguates entities)
- Easy to add new entity types via prompt engineering
- Extracts relationships and context

### Real-World Use Cases

1. **Customer Service** - Extract customer names, IDs, product references, dates from support tickets
2. **Legal/Compliance** - Identify parties, dates, amounts, locations in contracts
3. **Log Analysis** - Extract usernames, IP addresses, error codes, timestamps
4. **Business Intelligence** - Pull company names, products, revenue figures from reports
5. **Healthcare** - Extract patient names, medications, dates, doctors from medical records
6. **Email Processing** - Identify senders, recipients, dates, action items, referenced documents

## Part 2: Exploring the Sample Data (10 minutes)

The sample dataset contains 20 diverse documents representing common business text formats.

**File Location:** `workshops/workshop-04-named-entity-recognition/data/unstructured_text.csv`

### Sample Data Overview

| Document Type | Count | Entity Richness |
|--------------|-------|-----------------|
| Customer Emails | 2 | Names, companies, dates, contacts |
| Support Tickets | 2 | Employees, IDs, timestamps, modules |
| Sales Notes | 1 | Executives, locations, money, products |
| Contracts | 1 | Organizations, addresses, amounts, people |
| Security Incidents | 1 | IPs, timestamps, IDs, regions, people |
| Meeting Notes | 1 | Attendees, dates, locations, positions |
| Press Releases | 1 | Companies, money, dates, people, locations |
| Product Reviews | 1 | Products, stores, people, money, companies |
| Legal Notices | 1 | Organizations, addresses, dates, IDs |
| HR Memos | 1 | People, dates, locations, contacts |
| Financial Reports | 1 | Money, companies, people, dates, regions |
| Shipping Manifests | 1 | IDs, addresses, dates, companies, products |
| Blog Posts | 1 | Authors, companies, publications, dates |
| Invoices | 1 | IDs, companies, addresses, money, people |
| Research Abstracts | 1 | Researchers, institutions, IDs, dates |
| Social Media | 1 | Companies, products, money, dates, people |
| Email Threads | 1 | People, contacts, dates, technologies |
| Warranty Claims | 1 | People, products, IDs, dates, money, locations |
| Job Postings | 1 | Positions, companies, locations, money, contacts |
| Medical Records | 1 | People, dates, doctors, IDs, products, locations |

### View Sample Documents

```bash
head -n 5 /home/pentaho/LLM-PDI-Integration/workshops/workshop-04-named-entity-recognition/data/unstructured_text.csv
```

**Example Document #1 (Customer Email):**
```
document_id: 1
source: customer_email
text: "Hi, this is Sarah Johnson from Acme Corporation. I'm writing to inquire
about the order I placed on December 15th, 2024. My customer ID is CUST-98765.
Please contact me at sarah.johnson@acmecorp.com or call 555-123-4567. Our
office is located at 123 Main Street, San Francisco, CA 94102."
```

**Expected Entities:**
- PERSON: Sarah Johnson
- ORGANIZATION: Acme Corporation
- DATE: December 15th, 2024
- ID: CUST-98765
- CONTACT: sarah.johnson@acmecorp.com, 555-123-4567
- LOCATION: 123 Main Street, San Francisco, CA 94102

## Part 3: Running the Basic Transformation (15 minutes)

### Step 1: Ensure Ollama is Running

```bash
# Check if Ollama is running
curl http://localhost:11434/api/tags

# If not running, start it
systemctl start ollama

# Verify model is available
ollama list | grep llama3.2:3b
```

### Step 2: Open the Transformation

```bash
cd /home/pentaho/LLM-PDI-Integration/workshops/workshop-04-named-entity-recognition/transformations

# Open in Spoon (GUI)
/opt/pentaho/data-integration/spoon.sh named_entity_recognition.ktr &

# OR run via command line
/opt/pentaho/data-integration/pan.sh -file=named_entity_recognition.ktr
```

### Step 3: Understand the Transformation Steps

**1. Read Unstructured Text (CSV Input)**
- Reads `unstructured_text.csv`
- Fields: document_id, source, text
- 20 documents of various types

**2. Build NER Prompt (JavaScript)**
```javascript
// Build Named Entity Recognition prompt
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

**3. Build JSON Request (JavaScript)**
```javascript
// Build JSON request body for Ollama API
var model_name = getVariable("MODEL_NAME", "llama3.2:3b");

var requestObj = {
    "model": model_name,
    "prompt": llm_prompt,
    "stream": false,
    "format": "json",
    "options": {
        "temperature": 0.1,
        "num_predict": 1000
    }
};

var request_body = JSON.stringify(requestObj);
```

**Key Parameters:**
- `temperature: 0.1` - Low temperature for consistent, factual extraction
- `num_predict: 1000` - Allow up to 1000 tokens for entity-rich documents
- `format: "json"` - Request JSON output from LLM

**4. Call Ollama API (REST Client)**
- URL: `${OLLAMA_URL}` (http://localhost:11434/api/generate)
- Method: POST
- Body field: `request_body`
- Returns: `api_response`

**5. Parse NER Response (JavaScript)**
```javascript
// Parse Ollama response and extract entities as JSON string
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

**6. Write Entities CSV (Text Output)**
- Output file: `data/entities_extracted_YYYYMMDD_HHMMSS.csv`
- Fields: document_id, source, text, entity_count, person_count, org_count, location_count, date_count, entities_json

### Step 4: Review the Results

```bash
# Find the latest output file
ls -lt /home/pentaho/LLM-PDI-Integration/workshops/workshop-04-named-entity-recognition/data/entities_extracted_*.csv | head -1

# View results (showing counts)
cat <output_file> | cut -d',' -f1,4,5,6,7,8 | head -10

# View full entities for document #1
cat <output_file> | grep "^1," | cut -d',' -f9 | jq .
```

**Expected Results (Document #1):**
```json
[
  {"entity": "Sarah Johnson", "type": "PERSON", "context": "this is Sarah Johnson from"},
  {"entity": "Acme Corporation", "type": "ORGANIZATION", "context": "Sarah Johnson from Acme Corporation"},
  {"entity": "December 15th, 2024", "type": "DATE", "context": "order I placed on December 15th"},
  {"entity": "CUST-98765", "type": "ID", "context": "customer ID is CUST-98765"},
  {"entity": "sarah.johnson@acmecorp.com", "type": "CONTACT", "context": "contact me at sarah.johnson@acmecorp.com"},
  {"entity": "555-123-4567", "type": "CONTACT", "context": "or call 555-123-4567"},
  {"entity": "123 Main Street, San Francisco, CA 94102", "type": "LOCATION", "context": "office is located at 123 Main Street"}
]
```

**Performance:**
- Processing time: ~60-80 seconds for 20 documents (sequential)
- ~3-4 seconds per document
- Total entities extracted: 200-300+ across all documents

## Part 4: Running the Optimized Transformation (15 minutes)

The optimized version provides **3-4x performance improvement** through parallel processing and prompt optimization.

### Key Optimizations

1. **Parallel API Calls** - 4 concurrent REST Client copies
2. **Compact Prompt** - 77% shorter (229 vs 1,019 characters)
3. **Keep-Alive** - Model stays in memory between requests

### Step 1: Open the Optimized Transformation

```bash
cd /home/pentaho/LLM-PDI-Integration/workshops/workshop-04-named-entity-recognition/transformations

# Run optimized version
/opt/pentaho/data-integration/pan.sh -file=named_entity_recognition_optimized.ktr
```

### Step 2: Understand the Optimizations

**Optimized Prompt (229 characters vs 1,019):**
```javascript
// Compact NER prompt - 77% shorter
var llm_prompt = "Extract entities as JSON: [{\"entity\":\"\",\"type\":\"\",\"context\":\"\"}]. " +
  "Types: PERSON,ORGANIZATION,LOCATION,DATE,PRODUCT,MONEY,CONTACT,ID,TECHNOLOGY,POSITION. " +
  "Rules: Extract all. Include context. Exact text. JSON only.\nText: " + text;
```

**Parallel Processing Configuration:**
```xml
<step>
  <name>Call Ollama API (Parallel)</name>
  <copies>${STEP_COPIES}</copies>  <!-- 4 parallel copies -->
  <distribute>Y</distribute>
  ...
</step>
```

**Keep-Alive Parameter:**
```javascript
var keep_alive = getVariable("KEEP_ALIVE", "15m");

var requestObj = {
    "model": model_name,
    "prompt": llm_prompt,
    "keep_alive": keep_alive,  // Model stays in memory
    ...
};
```

### Step 3: Performance Comparison

| Version | Time (20 docs) | Docs/sec | Speedup |
|---------|----------------|----------|---------|
| Basic | 60-80 seconds | 0.25-0.33 | 1x |
| Optimized | 15-25 seconds | 0.80-1.33 | **3-4x** |

**Time Breakdown (Optimized):**
- Model loading: ~2-3 seconds (first request only, then cached)
- Per-document processing: ~0.5-0.8 seconds (parallelized)
- Total: 15-25 seconds for 20 documents

### Step 4: Verify Results

The optimized version produces the same entity extraction results as the basic version, just faster.

```bash
# Compare entity counts between basic and optimized
diff <(cat entities_extracted_basic.csv | cut -d',' -f1,4 | sort) \
     <(cat entities_extracted_optimized.csv | cut -d',' -f1,4 | sort)

# Should show minimal differences (LLM may occasionally vary slightly)
```

## Part 4.5: Understanding Wide Format Output (10 minutes)

### What is Wide Format Output?

The optimized transformation includes a **Python Script step** that converts the JSON array of entities into separate columns for each entity. This makes the output much easier to work with in Excel, databases, and analytics tools.

### Output Format Comparison

**Original Format (JSON Array):**
```csv
document_id,source,entity_count,entities_json
1,email,7,"[{\"entity\":\"Sarah Johnson\",\"type\":\"PERSON\"},{\"entity\":\"Acme Corporation\",\"type\":\"ORGANIZATION\"},{\"entity\":\"December 15th, 2024\",\"type\":\"DATE\"}...]"
```

**Wide Format (Separate Columns):**
```csv
document_id,source,entity_count,entities_json,entity_1,entity_type_1,entity_2,entity_type_2,entity_3,entity_type_3,...
1,email,7,"[...]",Sarah Johnson,PERSON,Acme Corporation,ORGANIZATION,December 15th 2024,DATE,...
```

### Benefits of Wide Format

1. **Excel-Friendly** - Open directly in spreadsheets without JSON parsing
2. **Database-Ready** - Fixed schema, easy to load into SQL tables
3. **Easy Filtering** - Filter by specific entity types or values
4. **Pivot Table Compatible** - Create summaries and cross-tabs in Excel/Tableau
5. **No Code Required** - Analysts can work with data without programming

### Python Script Step Details

The transformation includes a **"Pivot Entities to Columns"** Python Script step that runs between "Parse NER Response" and "Write Entities CSV".

**Python Code:**
```python
import json

# Get the entities_json field
entities_json_str = get("entities_json") or "[]"

# Initialize entity columns (15 max)
for i in range(1, 16):
    set(f"entity_{i}", "")
    set(f"entity_type_{i}", "")

try:
    # Parse JSON
    entities = json.loads(entities_json_str)

    # Handle both formats: {"entities": [...]} and [...]
    if isinstance(entities, dict) and 'entities' in entities:
        entities = entities['entities']

    # Populate columns
    for i, entity in enumerate(entities[:15], 1):
        set(f"entity_{i}", entity.get('entity', ''))
        set(f"entity_type_{i}", entity.get('type', ''))

except Exception as e:
    # Keep empty values on error
    pass
```

**How It Works:**
1. Reads the `entities_json` field containing the JSON array
2. Initializes 30 empty columns: entity_1, entity_type_1, entity_2, entity_type_2, ... entity_15, entity_type_15
3. Parses the JSON array
4. Populates the columns with the first 15 entities (most documents have < 15 entities)
5. If there are fewer than 15 entities, remaining columns stay empty
6. If there are more than 15 entities, only the first 15 are included in columns (full JSON array is still preserved in `entities_json`)

### Output Columns

The final CSV output includes:

**Original Columns:**
- document_id
- source
- text
- llm_prompt
- api_response
- result_code
- response_time
- entities_json
- entity_count
- person_count
- org_count
- location_count
- date_count

**New Entity Columns (30 total):**
- entity_1, entity_type_1
- entity_2, entity_type_2
- entity_3, entity_type_3
- ... (continues to entity_15, entity_type_15)

### Sample Wide Format Output

**Document 1 (Customer Email - 7 entities):**
```
entity_1: "Sarah Johnson"
entity_type_1: "PERSON"
entity_2: "Acme Corporation"
entity_type_2: "ORGANIZATION"
entity_3: "December 15th, 2024"
entity_type_3: "DATE"
entity_4: "CUST-98765"
entity_type_4: "ID"
entity_5: "sarah.johnson@acmecorp.com"
entity_type_5: "CONTACT"
entity_6: "555-123-4567"
entity_type_6: "CONTACT"
entity_7: "123 Main Street, San Francisco, CA 94102"
entity_type_7: "LOCATION"
entity_8: ""
entity_type_8: ""
... (entity_9 through entity_15 are empty)
```

### Analyzing Wide Format Data in Excel

**Example 1: Filter by Entity Type**
1. Open the CSV in Excel
2. Apply AutoFilter
3. Filter `entity_type_1` to show only "PERSON"
4. See all documents with person names in the first entity position

**Example 2: Count Documents by Organization**
1. Create PivotTable
2. Rows: entity_2 (if organizations typically appear second)
3. Values: Count of document_id
4. See which organizations appear most frequently

**Example 3: Find All Person Names**
```
=TEXTJOIN(", ", TRUE, entity_1, entity_2, entity_3, ...)
```
Filter by entity_type columns to find all PERSON entities across all positions.

### Modifying the Number of Entity Columns

If your documents have more (or fewer) entities, you can adjust the Python Script step:

**To Support 25 Entities (50 columns):**
1. Edit the "Pivot Entities to Columns" step
2. Change `range(1, 16)` to `range(1, 26)`
3. Change `entities[:15]` to `entities[:25]`
4. Add field definitions for entity_16 through entity_25 in the step's Fields tab
5. Add the same fields to the "Write Entities CSV" step

**To Support Only 10 Entities (20 columns):**
1. Change `range(1, 16)` to `range(1, 11)`
2. Change `entities[:15]` to `entities[:10]`
3. Remove field definitions for entity_11 through entity_15
4. Remove the same fields from the CSV output step

### Alternative: Standalone Python Script

If you prefer to process the CSV files **after** the transformation runs (or if the Python Script step doesn't work in your PDI version), use the standalone script:

**Location:** [scripts/pivot_entities_simple.py](../scripts/pivot_entities_simple.py)

**Usage:**
```bash
# Navigate to data directory
cd /home/pentaho/LLM-PDI-Integration/workshops/workshop-04-named-entity-recognition/data

# Run the pivot script
python3 ../scripts/pivot_entities_simple.py entities_extracted_20260228_143116.csv entities_wide.csv
```

**Output:**
```
Reading: entities_extracted_20260228_143116.csv
Original columns: 12
Rows: 10

Expanding entities into 30 columns...

Writing: entities_wide.csv
✓ Success! Created entities_wide.csv
New columns: 42

Entity statistics:
  Min entities per doc: 6
  Max entities per doc: 13
  Avg entities per doc: 9.5
  Total entities: 95
```

**Advantages of Standalone Script:**
- No dependencies (uses only standard Python libraries)
- Can process multiple files in batch
- Can be run on any machine (doesn't require PDI)
- Useful for post-processing existing output files

**See:** [scripts/README.md](../scripts/README.md) for full documentation.

### Troubleshooting Python Script Step

**Issue: Python Script step shows errors**

If you see errors like "Python Script step failed" or "Python interpreter not found":

**Solution 1: Check Python Configuration**
```bash
# Verify Python is installed
python3 --version

# Check if PDI can find Python
which python3
```

In PDI, go to Edit > Settings > Python and configure the Python executable path.

**Solution 2: Use JavaScript Instead**

You can implement the same logic in JavaScript (though it's more verbose):

```javascript
// Parse entities_json
var entities_json_str = entities_json || "[]";
var entity_1 = "", entity_type_1 = "", entity_2 = "", entity_type_2 = "";
// ... initialize entity_3 through entity_15

try {
    var entities = JSON.parse(entities_json_str);

    if (entities.length > 0) {
        entity_1 = entities[0].entity || "";
        entity_type_1 = entities[0].type || "";
    }
    if (entities.length > 1) {
        entity_2 = entities[1].entity || "";
        entity_type_2 = entities[1].type || "";
    }
    // ... continue for entity_3 through entity_15

} catch(e) {
    // Keep empty values
}
```

**Solution 3: Use Standalone Script (Recommended if PDI Python issues persist)**

Run the transformation without the Python Script step, then use the standalone script to post-process the CSV:

```bash
# Run transformation (outputs JSON format)
/opt/pentaho/data-integration/pan.sh -file=named_entity_recognition_optimized.ktr

# Post-process with Python script (creates wide format)
python3 scripts/pivot_entities_simple.py data/entities_extracted_*.csv data/entities_wide.csv
```

## Part 5: Building Your Own NER Transformation (20 minutes)

Now build a transformation from scratch to solidify your understanding.

### Exercise 1: Create a Simple NER Transformation

**Objective:** Extract only PERSON and ORGANIZATION entities from customer emails.

**Steps:**
1. Create new transformation: `my_simple_ner.ktr`
2. Add CSV Input step (read `unstructured_text.csv`)
3. Add JavaScript step to build simplified prompt:
```javascript
var llm_prompt = "Extract person names and organization names from this text. " +
  "Return JSON: [{\"entity\":\"text\",\"type\":\"PERSON or ORGANIZATION\"}]\n" +
  text;
```
4. Add JavaScript step to build API request
5. Add REST Client step to call Ollama
6. Add JavaScript step to parse and count entities
7. Add Text Output step to save results

**Bonus:** Filter to process only `customer_email` and `support_ticket` document types.

### Exercise 2: Extract Specific Entity Patterns

**Objective:** Create specialized extractors for specific entity patterns.

**Email Extractor:**
```javascript
var llm_prompt = "Extract all email addresses from this text. " +
  "Return JSON array: [{\"email\":\"address\",\"context\":\"surrounding text\"}]\n" + text;
```

**Phone Number Extractor:**
```javascript
var llm_prompt = "Extract all phone numbers from this text. " +
  "Return JSON array: [{\"phone\":\"number\",\"format\":\"original format\"}]\n" + text;
```

**Money/Amount Extractor:**
```javascript
var llm_prompt = "Extract all monetary amounts and currency from this text. " +
  "Return JSON: [{\"amount\":\"$125,000\",\"currency\":\"USD\",\"context\":\"\"}]\n" + text;
```

### Exercise 3: Add Entity Relationship Extraction

**Objective:** Not just extract entities, but extract relationships between them.

**Enhanced Prompt:**
```javascript
var llm_prompt = "Extract entities AND their relationships from this text.\n" +
  "Return JSON: {\"entities\":[{\"entity\":\"\",\"type\":\"\"}]," +
  "\"relationships\":[{\"subject\":\"\",\"predicate\":\"\",\"object\":\"\"}]}\n" +
  "Example: {\"entities\":[{\"entity\":\"Sarah Johnson\",\"type\":\"PERSON\"}," +
  "{\"entity\":\"Acme Corp\",\"type\":\"ORGANIZATION\"}]," +
  "\"relationships\":[{\"subject\":\"Sarah Johnson\",\"predicate\":\"works_at\"," +
  "\"object\":\"Acme Corp\"}]}\n\n" + text;
```

**Use Cases:**
- Who works at which company?
- Which products are mentioned in which context?
- What dates are associated with which events?

### Exercise 4: Domain-Specific Entity Extraction

**Objective:** Extract entities specific to your domain.

**Healthcare Example:**
```javascript
var llm_prompt = "Extract medical entities from this text.\n" +
  "Types: PATIENT, DOCTOR, DIAGNOSIS, MEDICATION, DOSAGE, PROCEDURE, DATE\n" +
  "Return JSON array with entity, type, and context.\n" + text;
```

**Financial Example:**
```javascript
var llm_prompt = "Extract financial entities from this text.\n" +
  "Types: COMPANY, TICKER_SYMBOL, AMOUNT, PERCENTAGE, QUARTER, METRIC\n" +
  "Return JSON array with entity, type, and context.\n" + text;
```

**Technology Example:**
```javascript
var llm_prompt = "Extract technology stack entities from this text.\n" +
  "Types: LANGUAGE, FRAMEWORK, DATABASE, CLOUD_PROVIDER, TOOL, VERSION\n" +
  "Return JSON array with entity, type, and context.\n" + text;
```

## Part 6: Advanced NER Techniques (20 minutes)

### Entity Disambiguation

Sometimes the same entity text can refer to different things based on context.

**Challenge:** "Apple" could be:
- The fruit
- Apple Inc. (company)
- Apple Records (music label)

**Solution - Context-Aware Prompt:**
```javascript
var llm_prompt = "Extract entities and disambiguate based on context.\n" +
  "For ambiguous entities, add 'disambiguation' field explaining the choice.\n" +
  "Example: {\"entity\":\"Apple\",\"type\":\"ORGANIZATION\"," +
  "\"disambiguation\":\"Referring to Apple Inc. based on context of technology products\"}\n" +
  text;
```

### Entity Normalization

Extract entities in standardized format.

**Date Normalization:**
```javascript
var llm_prompt = "Extract dates and normalize to ISO 8601 format (YYYY-MM-DD).\n" +
  "Example: {\"entity\":\"December 15th, 2024\",\"normalized\":\"2024-12-15\",\"type\":\"DATE\"}\n" +
  text;
```

**Phone Number Normalization:**
```javascript
var llm_prompt = "Extract phone numbers and normalize to E.164 format (+1XXXXXXXXXX).\n" +
  "Example: {\"entity\":\"555-123-4567\",\"normalized\":\"+15551234567\",\"type\":\"CONTACT\"}\n" +
  text;
```

### Entity Confidence Scores

Add confidence scoring to entity extractions.

**Confidence Prompt:**
```javascript
var llm_prompt = "Extract entities and provide confidence score (0-100%) for each.\n" +
  "Format: [{\"entity\":\"\",\"type\":\"\",\"confidence\":95,\"reasoning\":\"\"}]\n" +
  "Base confidence on: clarity of context, unambiguous reference, standard format.\n" +
  text;
```

**Use Case:** Filter out low-confidence entities (< 70%) for high-precision applications.

### Multi-Language NER

Extract entities from text in multiple languages.

**Multi-Language Prompt:**
```javascript
var llm_prompt = "Extract entities from this text (may be in English, Spanish, or French).\n" +
  "Format: [{\"entity\":\"\",\"type\":\"\",\"language\":\"en/es/fr\",\"translation_en\":\"\"}]\n" +
  "Detect language, extract entity, provide English translation if needed.\n" + text;
```

### Hierarchical Entity Extraction

Extract entities with hierarchical relationships.

**Location Hierarchy:**
```json
{
  "entity": "San Francisco",
  "type": "LOCATION",
  "hierarchy": {
    "city": "San Francisco",
    "state": "California",
    "country": "United States",
    "continent": "North America"
  }
}
```

**Organization Hierarchy:**
```json
{
  "entity": "Google Cloud Platform",
  "type": "TECHNOLOGY",
  "hierarchy": {
    "product": "Google Cloud Platform",
    "division": "Google Cloud",
    "parent_company": "Alphabet Inc."
  }
}
```

## Troubleshooting

### Issue 1: No Entities Extracted (entities_json = "[]")

**Symptoms:**
- All documents show 0 entity_count
- entities_json field contains empty array

**Possible Causes:**
1. LLM not returning JSON format
2. JSON parsing failing in Parse NER Response step
3. Temperature too high (model being creative with format)

**Solutions:**
```bash
# Test Ollama directly
curl -X POST http://localhost:11434/api/generate -d '{
  "model": "llama3.2:3b",
  "prompt": "Extract person names from: John Smith met Mary Johnson. Return JSON: [{\"entity\":\"\",\"type\":\"\"}]",
  "format": "json",
  "stream": false
}'

# Check response format
# Should return valid JSON array

# Fix: Ensure "format": "json" is set in API request
# Fix: Lower temperature to 0.0 or 0.1 for strict format adherence
```

### Issue 2: Partial Entity Extraction

**Symptoms:**
- Some entities extracted, but many obvious ones missing
- Inconsistent extraction across similar documents

**Possible Causes:**
1. num_predict too low (response truncated)
2. Prompt not clear enough about "extract ALL"
3. Model struggling with certain entity types

**Solutions:**
```javascript
// Increase token limit
"options": {
    "temperature": 0.1,
    "num_predict": 2000  // Increase from 1000
}

// Emphasize completeness in prompt
var llm_prompt = "Extract EVERY SINGLE named entity from this text. " +
  "Do not skip any entities, even if there are many. " +
  "Return complete JSON array with ALL entities.\n" + text;
```

### Issue 3: Incorrect Entity Types

**Symptoms:**
- "CEO Richard Davis" classified as ORGANIZATION instead of PERSON
- "Microsoft Corporation" classified as LOCATION

**Solutions:**
```javascript
// Provide more examples in prompt
var llm_prompt = "Extract entities with correct types.\n" +
  "PERSON examples: Dr. Sarah Johnson, CEO Richard Davis, Michael Chen\n" +
  "ORGANIZATION examples: Microsoft Corporation, FBI, Stanford University\n" +
  "LOCATION examples: San Francisco (city), 123 Main St (address)\n" +
  "Be precise with types. A person's title (CEO) doesn't make them an organization.\n" +
  text;
```

### Issue 4: Malformed JSON Responses

**Symptoms:**
- JSON parsing errors in Parse NER Response step
- entities_json contains text instead of valid JSON

**Solutions:**
```javascript
// Add more robust JSON extraction
var entities_json = "[]";
try {
    var response = JSON.parse(api_response);
    var fullResponse = response.response;

    // Method 1: Find array brackets
    var jsonStart = fullResponse.indexOf("[");
    var jsonEnd = fullResponse.lastIndexOf("]") + 1;

    if (jsonStart >= 0 && jsonEnd > jsonStart) {
        var jsonStr = fullResponse.substring(jsonStart, jsonEnd);

        // Validate before storing
        JSON.parse(jsonStr);  // Will throw if invalid
        entities_json = jsonStr;
    } else {
        // Method 2: Try finding JSON code block
        var codeBlockMatch = fullResponse.match(/```json\s*([\s\S]*?)\s*```/);
        if (codeBlockMatch) {
            entities_json = codeBlockMatch[1];
        }
    }
} catch(e) {
    // Log the error for debugging
    writeToLog("e", "JSON parsing failed: " + e.message);
    entities_json = "[]";
}
```

### Issue 5: Slow Performance (Even Optimized Version)

**Symptoms:**
- Optimized version taking > 40 seconds for 20 documents
- High CPU usage during processing

**Solutions:**
```bash
# Check if model is being reloaded
# Watch Ollama logs
journalctl -u ollama -f

# Ensure keep_alive is working
# Should see "model kept alive for 15m" in logs

# Increase keep_alive
# In transformation parameters, set KEEP_ALIVE=30m

# Check CPU allocation
# Ollama should use most CPU cores
ollama show llama3.2:3b --modelfile | grep num_thread

# Increase parallel copies if you have more cores
# Set STEP_COPIES=8 (for 8+ core systems)
```

## Appendix A: Complete Code Reference

### Build NER Prompt (JavaScript)

```javascript
// Build Named Entity Recognition prompt
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

### Build JSON Request (JavaScript)

```javascript
// Build JSON request body for Ollama API
var model_name = getVariable("MODEL_NAME", "llama3.2:3b");

var requestObj = {
    "model": model_name,
    "prompt": llm_prompt,
    "stream": false,
    "format": "json",
    "options": {
        "temperature": 0.1,
        "num_predict": 1000
    }
};

var request_body = JSON.stringify(requestObj);
```

### Build JSON Request - Optimized (JavaScript)

```javascript
// Build JSON request body with keep_alive
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

### Parse NER Response (JavaScript)

```javascript
// Parse Ollama response and extract entities as JSON string
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

## Appendix B: Entity Type Reference

### Detailed Entity Type Specifications

**PERSON**
- Individual human names
- Includes titles (Dr., CEO, etc.)
- First + Last name combinations
- Single names in clear person context
- Examples: Sarah Johnson, Dr. Michael Chen, CEO Richard Davis

**ORGANIZATION**
- Companies (Acme Corp, Microsoft)
- Institutions (Stanford University, FBI)
- Agencies (USPTO, NOAA)
- Divisions (Google Cloud, Apple Park)
- Non-profits, government bodies

**LOCATION**
- Cities (San Francisco, Austin)
- States/Provinces (California, Texas)
- Countries (United States, UK)
- Addresses (123 Main Street, Building 3)
- Regions (Silicon Valley, North America)
- Rooms/Buildings (Room 405, Conference Room B)

**DATE**
- Full dates (December 15th, 2024)
- Partial dates (Feb 1st, Q1 2025)
- Times (10:30 AM PST, 02:45 UTC)
- Relative dates (Monday, next Friday)
- Date ranges (Jan 2025)

**PRODUCT**
- Software products (iPhone 16, UltraBook Pro)
- Product models (Widget X-200, Galaxy S24)
- Services (Google Cloud Platform)
- Product names with versions (TensorFlow, version 3.5.2)

**MONEY**
- Currency amounts ($125,000, £250,000)
- Revenue figures ($45.6 million USD)
- Prices ($1,899.99)
- Ranges ($140K-$180K)

**CONTACT**
- Email addresses (user@company.com)
- Phone numbers (555-123-4567, +15551234567)
- Extensions (ext. 4521)
- Fax numbers

**ID**
- Customer IDs (CUST-98765)
- Order numbers (ORD-2025-5678)
- Invoice numbers (INV-2025-001234)
- Tracking codes (1Z999AA10123456784)
- Application numbers (88/123456)
- Employee IDs (EMP-12345)

**TECHNOLOGY**
- Programming languages (Python, JavaScript)
- Frameworks (TensorFlow, Apache Spark)
- Platforms (AWS, Docker)
- Databases (RDS, DB-PROD-01)
- Cloud services (AWS region us-east-1)

**POSITION**
- Job titles (CEO, CFO, CTO)
- Roles (Project Manager, Developer)
- Professional designations (Dr., Esq.)
- Functional titles (VP of Engineering)

## Appendix C: Performance Tuning

### Optimization Strategies

**1. Prompt Length Optimization**

| Prompt Length | Pros | Cons |
|--------------|------|------|
| Detailed (1000+ chars) | Clear instructions, better accuracy | Slower, more tokens |
| Compact (200-300 chars) | Fast, efficient | May miss edge cases |

**Recommendation:** Use detailed prompts for initial development, compact for production.

**2. Parallel Processing Tuning**

```bash
# Find optimal STEP_COPIES for your system
# Rule of thumb: CPU cores - 1

# For 4-core system
STEP_COPIES=3

# For 8-core system
STEP_COPIES=7

# For 16-core system
STEP_COPIES=12

# Test different values
for copies in 2 4 6 8; do
  echo "Testing STEP_COPIES=$copies"
  time pan.sh -file=named_entity_recognition_optimized.ktr -param:STEP_COPIES=$copies
done
```

**3. Model Selection**

| Model | Speed | Accuracy | Use Case |
|-------|-------|----------|----------|
| llama3.2:1b | Fastest | Good | High-volume, simple entities |
| llama3.2:3b | Fast | Very Good | Balanced (recommended) |
| llama3.1:8b | Slow | Excellent | Complex, ambiguous entities |

**4. Token Limit Tuning**

```javascript
// Adjust based on document complexity
"num_predict": 500   // Simple documents (emails, tickets)
"num_predict": 1000  // Medium documents (reports, contracts)
"num_predict": 2000  // Complex documents (legal, technical)
```

**5. Keep-Alive Optimization**

| keep_alive | Memory Usage | Best For |
|-----------|--------------|----------|
| 5m | Low | Infrequent processing |
| 15m | Medium | Regular batches |
| 30m | High | Continuous processing |
| 60m | Very High | Always-on services |

## Appendix D: Integration Patterns

### Pattern 1: Real-Time Entity Extraction API

Build a REST service that accepts text and returns entities.

**Architecture:**
1. HTTP request with text payload
2. PDI transformation extracts entities
3. Return JSON response

**Implementation:**
- Use Carte server to expose transformation as web service
- Client POSTs text
- Returns entities_json

### Pattern 2: Batch Document Processing

Process large document repositories.

**Architecture:**
1. Read documents from database/file system
2. Extract entities in parallel batches
3. Store entities in structured database
4. Index for search

**Benefits:**
- Process thousands of documents overnight
- Build searchable entity database
- Enable entity-based document retrieval

### Pattern 3: Streaming Entity Extraction

Process documents as they arrive.

**Architecture:**
1. Watch directory for new files
2. Auto-trigger transformation on new file
3. Extract entities
4. Publish to message queue (Kafka, RabbitMQ)
5. Downstream consumers use entities

**Use Case:**
- Email ingestion systems
- Support ticket processing
- Real-time log analysis

### Pattern 4: Entity Database Population

Extract entities to populate a structured database.

**Tables:**
- `documents` (id, source, text, created_at)
- `entities` (id, document_id, entity_text, entity_type, context)
- `entity_counts` (document_id, person_count, org_count, ...)

**Benefits:**
- SQL queries on entities
- Entity relationship analysis
- Historical entity tracking

## Summary

In this workshop, you learned:

1. Named Entity Recognition fundamentals and 10 entity types
2. Building NER prompts for LLM extraction
3. Processing diverse document types with PDI
4. Optimizing NER performance with parallel processing (3-4x speedup)
5. Extracting structured data from unstructured text
6. Advanced techniques: disambiguation, normalization, confidence scoring

**Next Steps:**
1. Apply NER to your own document types
2. Customize entity types for your domain
3. Build entity databases and search systems
4. Explore entity relationship extraction
5. Integrate NER into document processing pipelines

**Additional Resources:**
- Workshop 1: Sentiment Analysis
- Workshop 2: Data Quality
- Workshop 3: Data Enrichment
- Ollama Documentation: https://ollama.com/docs
- LLM Prompt Engineering Guide
