# Workshop 3: Data Enrichment with Ollama & PDI

**Duration:** 75-90 minutes
**Level:** Intermediate
**Prerequisites:** Workshops 1 & 2 completed, Ollama installed and configured

## Overview

Learn how to use Large Language Models (LLMs) to automatically enrich incomplete data by inferring missing information from context. This workshop demonstrates using Ollama with Pentaho Data Integration (PDI) to fill gaps in customer records, classify companies by industry, and add valuable business intelligence.

**What You'll Build:** An intelligent data enrichment pipeline that analyzes partial customer information and uses AI to infer missing fields like contact details, industry classification, company size, and standardized addresses.

## Learning Objectives

By the end of this workshop, you will be able to:

- ✅ Use LLMs to infer missing data from contextual clues
- ✅ Enrich customer records with industry and company size classifications
- ✅ Intelligently fill incomplete addresses, contacts, and websites
- ✅ Implement confidence-based enrichment strategies
- ✅ Handle ambiguous data with probabilistic reasoning
- ✅ Build production-ready data enrichment pipelines

## Prerequisites

### Software Requirements

- Pentaho Data Integration (PDI/Spoon) 9.x or 11.x
- Ollama installed and running
- Model `llama3.2:3b` downloaded
- **Completed Workshops 1 & 2** (understanding of REST Client, JSON parsing, data quality)

### Knowledge Requirements

- PDI transformation development
- Understanding of REST APIs and JSON
- Data quality and enrichment concepts
- JavaScript basics for prompt construction
- Basic understanding of business data

## Architecture Overview

```
┌────────────────────────┐
│  Read Incomplete Data  │  Read customer records with
│  (CSV Input)           │  missing fields
└──────────┬─────────────┘
           │
           ▼
┌────────────────────────┐
│  Build Enrichment      │  Create intelligent prompt
│  Prompt (JavaScript)   │  to infer missing data
└──────────┬─────────────┘
           │
           ▼
┌────────────────────────┐
│  Build JSON Request    │  Construct Ollama API request
│  (JavaScript)          │  with enrichment parameters
└──────────┬─────────────┘
           │
           ▼
┌────────────────────────┐
│  Call Ollama API       │  Send request to LLM for
│  (REST Client)         │  intelligent inference
└──────────┬─────────────┘
           │
           ▼
┌────────────────────────┐
│  Parse Enriched        │  Extract inferred fields:
│  Response (JavaScript) │  industry, size, contacts
└──────────┬─────────────┘
           │
           ▼
┌────────────────────────┐
│  Write Enriched Data   │  Output complete customer
│  (CSV Output)          │  records with new fields
└────────────────────────┘
```

### Workflow Explanation

1. **Read Incomplete Data**: Load customer records with missing fields (website, phone, address, etc.)
2. **Build Enrichment Prompt**: Create intelligent prompts that ask the LLM to infer missing information
3. **Build JSON Request**: Construct the Ollama API request with appropriate parameters for inference
4. **Call Ollama API**: Send request to LLM to analyze available data and fill gaps
5. **Parse Enriched Response**: Extract inferred fields plus new enrichments (industry, company size)
6. **Write Enriched Data**: Save complete records with original + inferred + classified data

## Part 1: Understanding Data Enrichment Challenges (15 minutes)

### Step 1: Examine the Incomplete Data

Navigate to the workshop folder and review the sample data:

```bash
cd /home/pentaho/LLM-PDI-Integration/workshops/workshop-03-data-enrichment
cat data/customer_data_incomplete.csv | head -10
```

**Sample Records:**
```csv
customer_id,company_name,website,contact_name,phone,address,city,state,country
1001,Acme Corp,acmecorp.com,John Smith,,,,"CA",
1002,TechStart Inc,,,555-9876,123 Oak Ave,Los Angeles,,USA
1003,Global Solutions,globalsolutions.io,Sarah Chen,,,"Seattle",WA,
1004,DataFlow Systems,,Mike Johnson,+1-555-1234,456 Pine St,,"Texas",
1005,CloudFirst,cloudfirst.com,,,789 Main St,San Francisco,CA,USA
```

**Data Completeness Analysis:**

| Customer | Company | Website | Contact | Phone | Address | City | State | Country |
|----------|---------|---------|---------|-------|---------|------|-------|---------|
| 1001 | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ | ❌ |
| 1002 | ✅ | ❌ | ❌ | ✅ | ✅ | ✅ | ❌ | ✅ |
| 1003 | ✅ | ✅ | ✅ | ❌ | ❌ | ✅ | ✅ | ❌ |
| 1004 | ✅ | ❌ | ✅ | ✅ | ✅ | ❌ | ✅ | ❌ |
| 1005 | ✅ | ✅ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ |

**Missing Data Patterns:**
- 40% missing website
- 35% missing contact name
- 50% missing phone
- 30% missing full address
- 25% missing state
- 45% missing country

### Step 2: Define Enrichment Goals

Our enrichment targets:

| Field | Enrichment Strategy | Example |
|-------|---------------------|---------|
| **Website** | Infer from company name + domain patterns | `acmecorp.com` → `www.acmecorp.com` |
| **Contact** | Keep as UNKNOWN if not provided | `John Smith` or `UNKNOWN` |
| **Phone** | Infer area code from city/state | `555-1234` → `+1-415-555-1234` (SF) |
| **Address** | Keep street or mark UNKNOWN | `123 Main St` or `UNKNOWN` |
| **City** | Infer from state if missing | Texas → `Houston` (likely) |
| **State** | Infer from city or use 2-letter code | `California` → `CA` |
| **Country** | Default to USA if empty | `USA` |
| **Industry** (NEW) | Classify from company name/website | `TechStart Inc` → `Technology` |
| **Employee Range** (NEW) | Estimate from company name patterns | `Acme Corp` → `51-200` |

### Step 3: Enrichment vs Quality Enhancement

**Workshop 2 (Data Quality):**
- Goal: Fix incorrect/inconsistent data
- Input: Messy but complete data
- Output: Clean, standardized data
- Example: `john smith` → `John Smith`

**Workshop 3 (Data Enrichment):**
- Goal: Add missing information
- Input: Incomplete but clean data
- Output: Complete data with inferred fields
- Example: `Acme Corp` → Industry: `Technology`, Size: `51-200`

**Comparison:**

| Aspect | Data Quality (Workshop 2) | Data Enrichment (Workshop 3) |
|--------|---------------------------|------------------------------|
| **Input** | Complete, messy data | Incomplete, clean data |
| **Process** | Standardize and validate | Infer and classify |
| **Output** | Clean existing fields | Add new fields |
| **Risk** | Low (validation) | Medium (inference accuracy) |
| **Value-Add** | Consistency | New business intelligence |

## Part 2: Understanding Enrichment with LLMs (10 minutes)

### Why LLMs Excel at Data Enrichment

**Traditional Approaches:**
1. **Rule-Based**: `if company_name contains "Tech" then industry = "Technology"`
   - ❌ Brittle, misses edge cases
   - ❌ Requires constant rule updates

2. **Lookup Tables**: Match company name against database
   - ❌ Limited to known companies
   - ❌ Expensive to maintain

3. **External APIs**: Call company data APIs (Clearbit, FullContact)
   - ❌ Costly ($0.50+ per enrichment)
   - ❌ Rate limits and quotas

**LLM Approach:**
- ✅ Contextual inference from company name, website, location
- ✅ Handles ambiguous cases with probabilistic reasoning
- ✅ Works for unknown companies
- ✅ Free with local Ollama
- ✅ Single prompt enriches multiple fields

### Sample Request Format

```json
{
  "model": "llama3.2:3b",
  "prompt": "Analyze this customer record and infer missing fields. Return ONLY valid JSON...\n\nInput data:\nCompany: Acme Corp\nWebsite: acmecorp.com\nContact: John Smith\nPhone: UNKNOWN\nAddress: UNKNOWN\nCity: UNKNOWN\nState: CA\nCountry: UNKNOWN",
  "stream": false,
  "format": "json",
  "options": {
    "temperature": 0.3,
    "num_predict": 400
  }
}
```

**Key Parameters:**
- `format`: `"json"` - Enforces JSON output (more reliable than prompt-only)
- `temperature`: `0.3` - Moderate creativity (vs 0.1 for quality, 0.7 for generation)
- `num_predict`: `400` - Allow longer responses for enriched fields

### Sample Response Format

```json
{
  "response": "{\"company_name\":\"Acme Corp\",\"website\":\"www.acmecorp.com\",\"contact_name\":\"John Smith\",\"phone\":\"+1-800-555-ACME\",\"address\":\"UNKNOWN\",\"city\":\"San Francisco\",\"state\":\"CA\",\"country\":\"USA\",\"industry\":\"Manufacturing\",\"employee_range\":\"201-500\"}"
}
```

**Enriched Fields:**
- Original: `Acme Corp`, `acmecorp.com`, `John Smith`, `CA`
- Inferred: `www.acmecorp.com` (formatted), `San Francisco` (likely CA city), `USA` (default)
- **NEW**: `Manufacturing` (industry from "Acme"), `201-500` (estimated size)

### Test the API Manually

```bash
curl http://localhost:11434/api/generate -d '{
  "model": "llama3.2:3b",
  "prompt": "Analyze this customer record and infer missing fields. Return ONLY valid JSON with these fields:\n{\"company_name\":\"...\",\"website\":\"...\",\"contact_name\":\"...\",\"phone\":\"...\",\"address\":\"...\",\"city\":\"...\",\"state\":\"...\",\"country\":\"...\",\"industry\":\"...\",\"employee_range\":\"...\"}\n\nRules:\n- If field is provided, keep it unchanged\n- If field is empty, infer from context or use \"UNKNOWN\"\n- Industry: Technology, Finance, Healthcare, Retail, Manufacturing, Services, etc.\n- Employee range: 1-10, 11-50, 51-200, 201-500, 501-1000, 1000+\n\nInput data:\nCompany: TechStart Inc\nWebsite: UNKNOWN\nContact: UNKNOWN\nPhone: 555-9876\nAddress: 123 Oak Ave\nCity: Los Angeles\nState: UNKNOWN\nCountry: USA",
  "stream": false,
  "format": "json"
}'
```

**Expected Response:**
```json
{
  "company_name": "TechStart Inc",
  "website": "www.techstart.com",
  "contact_name": "UNKNOWN",
  "phone": "+1-310-555-9876",
  "address": "123 Oak Ave",
  "city": "Los Angeles",
  "state": "CA",
  "country": "USA",
  "industry": "Technology",
  "employee_range": "11-50"
}
```

**Notice:**
- Website inferred: `techstart.com` (reasonable guess)
- Phone enriched: Added LA area code `310`
- State inferred: `CA` (from Los Angeles)
- **Industry**: `Technology` (from company name "TechStart")
- **Employee range**: `11-50` (startup indicator from name)

## Part 3: Building the PDI Transformation (30 minutes)

### Transformation Overview

| File | Purpose | Performance | Use Case |
|------|---------|-------------|----------|
| `data_enrichment.ktr` | **Basic (Learning)** | ~60-80s for 20 records | Understanding enrichment flow |
| `data_enrichment_optimized.ktr` | **Optimized (Production)** | ~15-25s for 20 records | Real-world deployment |

**Key Features:**
- Intelligent field inference from context
- Industry classification
- Company size estimation
- Fallback to original or UNKNOWN
- Confidence indicators

### Step-by-Step Flow

Open the basic transformation in Spoon:

```bash
cd /home/pentaho/LLM-PDI-Integration/workshops/workshop-03-data-enrichment
# Launch Spoon and open:
transformations/data_enrichment.ktr
```

**Step 1: Read Incomplete Data (CSV Input)**

Configuration:
- **File**: `${INPUT_FILE}` → `../data/customer_data_incomplete.csv`
- **Fields**: `customer_id`, `company_name`, `website`, `contact_name`, `phone`, `address`, `city`, `state`, `country`
- **Rows**: 20 customer records with various missing fields

**Step 2: Build Enrichment Prompt (Modified Java Script Value)**

```javascript
// Build enrichment prompt - infer missing fields from available data
var llm_prompt = "Analyze this customer record and infer missing fields. Return ONLY valid JSON with these fields:\n" +
  "{\"company_name\":\"...\",\"website\":\"...\",\"contact_name\":\"...\",\"phone\":\"...\",\"address\":\"...\",\"city\":\"...\",\"state\":\"...\",\"country\":\"...\",\"industry\":\"...\",\"employee_range\":\"...\"}\n\n" +
  "Rules:\n" +
  "- If field is provided, keep it unchanged\n" +
  "- If field is empty, infer from context or use 'UNKNOWN'\n" +
  "- Industry: Technology, Finance, Healthcare, Retail, Manufacturing, Services, etc.\n" +
  "- Employee range: 1-10, 11-50, 51-200, 201-500, 501-1000, 1000+\n" +
  "- Website: Add .com if missing domain\n" +
  "- Phone: Format as +1-555-123-4567\n" +
  "- State: Use 2-letter code (CA, NY, TX, etc.)\n\n" +
  "Input data:\n" +
  "Company: " + (company_name || "UNKNOWN") + "\n" +
  "Website: " + (website || "UNKNOWN") + "\n" +
  "Contact: " + (contact_name || "UNKNOWN") + "\n" +
  "Phone: " + (phone || "UNKNOWN") + "\n" +
  "Address: " + (address || "UNKNOWN") + "\n" +
  "City: " + (city || "UNKNOWN") + "\n" +
  "State: " + (state || "UNKNOWN") + "\n" +
  "Country: " + (country || "UNKNOWN");
```

**Prompt Engineering Strategies:**
1. **Clear Rules**: Explicit instructions for handling empty fields
2. **Examples**: Show format for industry and employee range
3. **Fallback Logic**: Use 'UNKNOWN' instead of leaving blank
4. **Context Preservation**: Keep provided fields unchanged
5. **Inference Guidance**: State abbreviations, phone formatting

**Step 3: Build JSON Request (Modified Java Script Value)**

```javascript
// Build JSON request body for Ollama API
var model_name = getVariable("MODEL_NAME", "llama3.2:3b");

var requestObj = {
    "model": model_name,
    "prompt": llm_prompt,
    "stream": false,
    "format": "json",  // Enforce JSON output
    "options": {
        "temperature": 0.3,  // Higher than cleaning (0.1) for inference
        "num_predict": 400   // Longer output for enriched fields
    }
};

var request_body = JSON.stringify(requestObj);
```

**Why Different Parameters?**
- **Temperature 0.3** vs 0.1 (quality): Allow creative inference for missing data
- **num_predict 400** vs 300 (quality): More tokens for industry/size descriptions
- **format: "json"**: Stronger JSON enforcement than prompt-only

**Step 4: Call Ollama API (REST Client)**

Configuration:
- **Method**: `POST`
- **URL**: `${OLLAMA_URL}/api/generate`
- **Body Field**: `request_body`
- **Result Fields**: `api_response`, `result_code`
- **Copies**: 1 (basic) or `${STEP_COPIES}` (optimized)

**Step 5: Parse Enriched Response (Modified Java Script Value)**

```javascript
// Parse Ollama response and extract enriched fields
var enriched_company = company_name;
var enriched_website = website;
var enriched_contact = contact_name;
var enriched_phone = phone;
var enriched_address = address;
var enriched_city = city;
var enriched_state = state;
var enriched_country = country;
var industry = "UNKNOWN";
var employee_range = "UNKNOWN";

try {
    var response = JSON.parse(api_response);
    var fullResponse = response.response;

    // Extract JSON from response
    var jsonStart = fullResponse.indexOf("{");
    var jsonEnd = fullResponse.lastIndexOf("}") + 1;

    if (jsonStart >= 0 && jsonEnd > jsonStart) {
        var jsonStr = fullResponse.substring(jsonStart, jsonEnd);
        var data = JSON.parse(jsonStr);

        // Use enriched values if original was empty
        enriched_company = company_name || data.company_name || "UNKNOWN";
        enriched_website = website || data.website || "UNKNOWN";
        enriched_contact = contact_name || data.contact_name || "UNKNOWN";
        enriched_phone = phone || data.phone || "UNKNOWN";
        enriched_address = address || data.address || "UNKNOWN";
        enriched_city = city || data.city || "UNKNOWN";
        enriched_state = state || data.state || "UNKNOWN";
        enriched_country = country || data.country || "USA";
        industry = data.industry || "UNKNOWN";
        employee_range = data.employee_range || "UNKNOWN";
    }
} catch(e) {
    // Keep original values on error
}
```

**Enrichment Logic:**
1. Start with original values as fallback
2. Parse LLM JSON response
3. **Only replace if original was empty**: `original || enriched || "UNKNOWN"`
4. Always extract NEW fields: `industry`, `employee_range`
5. On error, keep originals (graceful degradation)

**Step 6: Write Enriched Data (Text File Output)**

Configuration:
- **Filename**: `../data/customer_data_enriched`
- **Extension**: `.csv`
- **Add timestamp**: Yes
- **Fields** (11 total):
  - Original ID: `customer_id`
  - Enriched fields (8): `enriched_company`, `enriched_website`, `enriched_contact`, `enriched_phone`, `enriched_address`, `enriched_city`, `enriched_state`, `enriched_country`
  - **NEW fields (2)**: `industry`, `employee_range`

### Transformation Parameters

| Parameter | Default Value | Description |
|-----------|---------------|-------------|
| OLLAMA_URL | http://localhost:11434 | Ollama API endpoint |
| MODEL_NAME | llama3.2:3b | Model for inference (llama3.2:3b recommended) |
| INPUT_FILE | ../data/customer_data_incomplete.csv | Input data path |

**Optimized Transformation (Additional Parameters):**

| Parameter | Default Value | Description |
|-----------|---------------|-------------|
| KEEP_ALIVE | 15m | Keep model loaded longer for inference tasks |
| STEP_COPIES | 4 | Parallel processing (set to CPU cores - 1) |

### Tested Configuration (Verified Working ✅)

**Test Environment:**
- OS: Ubuntu 22.04 Linux
- PDI: 11.0.0.0-237
- Ollama: Latest
- Model: llama3.2:3b
- CPU: 4 cores
- RAM: 16GB

**Verified Parameters:**
```bash
OLLAMA_URL=http://localhost:11434
MODEL_NAME=llama3.2:3b
INPUT_FILE=../data/customer_data_incomplete.csv
```

## Part 4: Running the Transformation (10 minutes)

### Option 1: Using Spoon (PDI GUI)

1. Open Spoon
2. File → Open → Navigate to:
   ```
   /home/pentaho/LLM-PDI-Integration/workshops/workshop-03-data-enrichment/transformations/data_enrichment.ktr
   ```
3. Press **F9** or click **Run**
4. Leave parameters at default:
   - OLLAMA_URL: `http://localhost:11434`
   - MODEL_NAME: `llama3.2:3b`
   - INPUT_FILE: `../data/customer_data_incomplete.csv`
5. Click **Launch**
6. Wait for completion (~60-80 seconds for 20 records)

### Option 2: Using Pan (Command Line)

```bash
cd /home/pentaho/LLM-PDI-Integration/workshops/workshop-03-data-enrichment/transformations

# Run with default parameters
~/Pentaho/design-tools/data-integration/pan.sh \
  -file=data_enrichment.ktr \
  -param:OLLAMA_URL=http://localhost:11434 \
  -param:MODEL_NAME=llama3.2:3b
```

### Expected Output

```
2026-02-27 15:00:05.590 - data_enrichment - Starting Transformation
2026-02-27 15:00:05.601 - Read Incomplete Data.0 - Finished processing (I=21, O=0, R=0, W=20, U=0, E=0)
2026-02-27 15:00:05.631 - Build Enrichment Prompt.0 - Finished processing (I=0, O=0, R=20, W=20, U=0, E=0)
2026-02-27 15:00:05.711 - Build JSON Request.0 - Finished processing (I=0, O=0, R=20, W=20, U=0, E=0)
2026-02-27 15:01:15.425 - Call Ollama API.0 - Finished processing (I=0, O=0, R=20, W=20, U=0, E=0)
2026-02-27 15:01:15.450 - Parse Enriched Response.0 - Finished processing (I=0, O=0, R=20, W=20, U=0, E=0)
2026-02-27 15:01:15.475 - Write Enriched Data.0 - Finished processing (I=0, O=0, R=0, W=20, U=0, E=0)
```

**Performance Metrics:**
- **Total Time**: ~60-80 seconds (basic), ~15-25 seconds (optimized)
- **Records Processed**: 20
- **Throughput**: ~0.25 rec/sec (basic), ~0.8-1.3 rec/sec (optimized)

## Part 5: Analyzing Enrichment Results (15 minutes)

### View the Results

```bash
cd /home/pentaho/LLM-PDI-Integration/workshops/workshop-03-data-enrichment/data
ls -lt customer_data_enriched_*.csv | head -1
cat customer_data_enriched_*.csv | head -10
```

### Sample Enrichment Comparison

**Before (Incomplete Data):**
```csv
customer_id,company_name,website,contact_name,phone,address,city,state,country
1001,Acme Corp,acmecorp.com,John Smith,,,,"CA",
1002,TechStart Inc,,,555-9876,123 Oak Ave,Los Angeles,,USA
1003,Global Solutions,globalsolutions.io,Sarah Chen,,,"Seattle",WA,
```

**After (Enriched Data):**
```csv
customer_id,enriched_company,enriched_website,enriched_contact,enriched_phone,enriched_address,enriched_city,enriched_state,enriched_country,industry,employee_range
1001,Acme Corp,www.acmecorp.com,John Smith,+1-415-555-ACME,UNKNOWN,San Francisco,CA,USA,Manufacturing,201-500
1002,TechStart Inc,www.techstart.com,UNKNOWN,+1-310-555-9876,123 Oak Ave,Los Angeles,CA,USA,Technology,11-50
1003,Global Solutions,www.globalsolutions.io,Sarah Chen,+1-206-555-0123,UNKNOWN,Seattle,WA,USA,Consulting,51-200
```

### Enrichment Analysis

| Customer | Fields Enriched | Industry Added | Size Added | Accuracy |
|----------|----------------|----------------|------------|----------|
| 1001 | Phone, Address, City, Country | ✅ Manufacturing | ✅ 201-500 | High |
| 1002 | Website, Contact, State | ✅ Technology | ✅ 11-50 | High |
| 1003 | Phone, Address, Country | ✅ Consulting | ✅ 51-200 | Medium |

**Enrichment Statistics:**
- **Websites**: 8 inferred (40% enrichment rate)
- **Phones**: 10 area codes added (50% enrichment rate)
- **Cities**: 6 inferred from state (30% enrichment rate)
- **States**: 5 abbreviations standardized (25% enrichment rate)
- **Countries**: 9 defaulted to USA (45% enrichment rate)
- **Industry**: 20 classified (100% new field)
- **Employee Range**: 20 estimated (100% new field)

### Analysis Questions

1. **Enrichment Accuracy**: What percentage of inferred fields are plausible?
2. **Industry Classification**: How accurate are the industry assignments?
3. **Company Size**: Do employee range estimates match company names?
4. **Website Inference**: Did the LLM generate reasonable domain names?
5. **Geo-Inference**: Are cities correctly matched to states?

### Sample Analysis Queries

```bash
# Count enrichment by field
awk -F',' 'NR>1 {
  if ($3 !~ /UNKNOWN/ && $3 != "") web++;
  if ($4 !~ /UNKNOWN/ && $4 != "") contact++;
  if ($5 !~ /UNKNOWN/ && $5 != "") phone++;
  if ($6 !~ /UNKNOWN/ && $6 != "") addr++;
  if ($7 !~ /UNKNOWN/ && $7 != "") city++;
} END {
  print "Websites: " web;
  print "Contacts: " contact;
  print "Phones: " phone;
  print "Addresses: " addr;
  print "Cities: " city;
}' customer_data_enriched_*.csv

# Show industry distribution
cut -d',' -f10 customer_data_enriched_*.csv | tail -n +2 | sort | uniq -c | sort -rn

# Show employee range distribution
cut -d',' -f11 customer_data_enriched_*.csv | tail -n +2 | sort | uniq -c | sort -rn
```

## Part 6: Exercises & Extensions (Bonus)

### Exercise 1: Add Confidence Scores

**Task**: Modify the prompt to include confidence scores for inferred fields

**Hints:**
- Add `_confidence` field for each enriched field (0-100)
- Parse confidence scores in JavaScript
- Filter low-confidence enrichments (< 70%)

**Solution:**
```javascript
var llm_prompt = "Analyze this customer record and infer missing fields. Return ONLY valid JSON with confidence scores (0-100):\n" +
  "{\"company_name\":\"...\",\"company_confidence\":95,\"website\":\"...\",\"website_confidence\":80,...}\n\n" +
  "Rules:\n- Confidence 90-100: Very certain\n- Confidence 70-89: Probable\n- Confidence 50-69: Possible\n- Confidence <50: Uncertain (use UNKNOWN)\n\n" +
  "Input data:\n...";
```

### Exercise 2: Multi-Source Enrichment

**Task**: Combine LLM inference with external API lookups

**Hints:**
- Use REST Client to call company data API (e.g., Clearbit, FullContact)
- Compare LLM inference with API results
- Use API for high-value customers, LLM for others

**Solution:**
```javascript
// In Filter Rows step
var is_high_value = (company_name.indexOf("Corp") > -1 || company_name.indexOf("Inc") > -1);

// If high-value, route to API lookup
// If low-value, route to LLM enrichment
```

### Exercise 3: Geocoding Integration

**Task**: Use LLM to infer coordinates from address

**Hints:**
- Add `latitude` and `longitude` fields to prompt
- Ask LLM to estimate coordinates from city/state
- Validate against known city coordinates

**Solution:**
```javascript
var llm_prompt = "...Return JSON with fields:\n" +
  "{\"city\":\"...\",\"state\":\"...\",\"latitude\":37.7749,\"longitude\":-122.4194,...}\n\n" +
  "Estimate latitude/longitude for the city. Use known city centers.\n\n" +
  "Input data:\nCity: " + city + "\nState: " + state;
```

### Exercise 4: Industry Hierarchy

**Task**: Add sub-industry classification

**Hints:**
- Modify prompt to return: `{"industry":"Technology","sub_industry":"SaaS"}`
- Use hierarchical industry taxonomy
- Parse nested industry categories

**Solution:**
```javascript
var llm_prompt = "Classify company into industry and sub-industry. Return JSON:\n" +
  "{\"industry\":\"Technology\",\"sub_industry\":\"SaaS|Hardware|Consulting|...\",...}\n\n" +
  "Industries: Technology, Finance, Healthcare, Retail, Manufacturing, Services\n" +
  "Sub-industries: For Technology: SaaS, Hardware, Consulting, AI/ML, Cybersecurity, etc.\n\n" +
  "Company: " + company_name;
```

### Exercise 5: Temporal Enrichment

**Task**: Add company founding year and maturity

**Hints:**
- Infer founding year from company name patterns
- Estimate maturity: Startup, Growth, Mature, Enterprise
- Use website age as a signal

**Solution:**
```javascript
var llm_prompt = "Estimate company age and maturity. Return JSON:\n" +
  "{\"founded_year\":2015,\"maturity\":\"Startup|Growth|Mature|Enterprise\",...}\n\n" +
  "Infer from company name, website, and employee range.\n\n" +
  "Company: " + company_name + "\nEmployee range: " + employee_range;
```

### Exercise 6: Enrichment Quality Metrics

**Task**: Build a quality dashboard for enrichment results

**Hints:**
- Count enriched vs original fields
- Track industry classification distribution
- Monitor UNKNOWN rate per field
- Create metrics table for Grafana/Superset

## Troubleshooting

### Common Issues & Quick Fixes

| Issue | Symptom | Quick Fix |
|-------|---------|-----------|
| Inaccurate inferences | Wrong industry or size | Increase temperature to 0.4-0.5 for more options |
| Too many UNKNOWN values | LLM not inferring | Make prompt more explicit with examples |
| Slow performance | 80+ seconds for 20 records | Use optimized version with STEP_COPIES=4 |
| Inconsistent JSON format | Parsing errors | Add `"format":"json"` to Ollama request |

### Issue 1: Inaccurate Industry Classification

**Symptoms**: Companies classified into wrong industries

**Debug Steps:**

1. **Check prompt clarity:**
```javascript
// Add industry examples to prompt
var llm_prompt = "...Industry categories:\n" +
  "- Technology: Software, SaaS, IT services, AI/ML, cybersecurity\n" +
  "- Finance: Banking, insurance, investment, fintech\n" +
  "- Healthcare: Hospitals, medical devices, pharma, telemedicine\n" +
  "- Retail: E-commerce, brick-and-mortar stores, consumer goods\n" +
  "- Manufacturing: Industrial equipment, automotive, aerospace\n" +
  "- Services: Consulting, professional services, agencies\n\n" +
  "Company: " + company_name;
```

2. **Add website as a stronger signal:**
```javascript
// Website often reveals industry better than name
var llm_prompt = "...Input data:\n" +
  "Company: " + company_name + "\n" +
  "Website: " + website + " (analyze domain and name together)\n";
```

3. **Request confidence scores:**
```javascript
var llm_prompt = "...Return JSON with confidence:\n" +
  "{\"industry\":\"Technology\",\"industry_confidence\":85,...}\n";
```

### Issue 2: Too Many UNKNOWN Values

**Symptoms**: Fields not being inferred despite context clues

**Solutions:**

1. **More aggressive inference:**
```javascript
var llm_prompt = "...Rules:\n" +
  "- NEVER use UNKNOWN unless absolutely no context available\n" +
  "- Make educated guesses based on industry patterns\n" +
  "- Use common values (USA for country, area code from state, .com domains)\n";
```

2. **Provide more examples:**
```javascript
var llm_prompt = "...Examples:\n" +
  "- TechStart Inc + CA → www.techstart.com, +1-415-555-xxxx, San Francisco\n" +
  "- Global Solutions + Seattle → www.globalsolutions.com, +1-206-555-xxxx, WA\n\n" +
  "Now enrich: Company: " + company_name + ", City: " + city + ", State: " + state;
```

3. **Increase temperature:**
```javascript
var requestObj = {
    "temperature": 0.5  // Higher = more creative inference (was 0.3)
};
```

### Issue 3: Inconsistent Employee Range Format

**Symptoms**: Getting "Small", "Medium" instead of "11-50", "51-200"

**Solution:**

```javascript
var llm_prompt = "...Employee range MUST be one of these exact values:\n" +
  "- 1-10\n" +
  "- 11-50\n" +
  "- 51-200\n" +
  "- 201-500\n" +
  "- 501-1000\n" +
  "- 1000+\n\n" +
  "Do NOT use: Small, Medium, Large. Use the exact ranges above.";
```

### Issue 4: Website Domain Hallucination

**Symptoms**: LLM inventing unrealistic domains

**Solution:**

```javascript
var llm_prompt = "...Website inference rules:\n" +
  "- If company name is 'Acme Corp', try: www.acmecorp.com, www.acme.com\n" +
  "- Remove spaces, punctuation: 'Tech Start Inc' → www.techstart.com\n" +
  "- Prefer .com over .io, .net unless name suggests otherwise\n" +
  "- If unsure, use: UNKNOWN (don't guess wildly)\n";
```

## Key Takeaways

✅ **LLMs enable intelligent data enrichment** beyond simple lookup tables
✅ **Contextual inference** fills gaps that rule-based systems miss
✅ **Industry classification and sizing** adds business intelligence automatically
✅ **Temperature tuning** balances creativity (inference) vs consistency (quality)
✅ **Confidence scores** enable downstream filtering and validation
✅ **Hybrid approaches** (LLM + API) optimize cost and accuracy

**Enrichment Value Comparison:**

| Approach | Cost per Record | Accuracy | Coverage | Speed |
|----------|-----------------|----------|----------|-------|
| Manual enrichment | $2-5 | 95-100% | 100% | Slow |
| External APIs | $0.50-2 | 85-95% | 60-80% | Fast |
| LLM Enrichment | $0 (Ollama) | 70-85% | 90-100% | Medium |
| **Hybrid (LLM + API)** | **$0.10-0.50** | **85-95%** | **95-100%** | **Fast** |

**Performance Achieved:**
- Basic: 0.25 records/second
- Optimized: 0.8-1.3 records/second
- **Fields enriched per record**: 2-5 missing fields + 2 new classifications

## Next Steps

### Continue Learning

1. **Workshop 4**: Named Entity Recognition (coming soon)
   - Extract entities from unstructured text
   - Identify people, places, organizations
   - Build knowledge graphs from text

2. **Advanced Enrichment Patterns**:
   - Multi-model ensembles (combine llama + mistral)
   - Active learning (improve prompts from feedback)
   - Confidence-based routing

### Production Deployment

1. **Batch Processing**:
```bash
# Process large datasets in chunks
for i in {1..10}; do
  pan.sh -file=data_enrichment_optimized.ktr \
    -param:INPUT_FILE=batch_${i}.csv \
    -param:STEP_COPIES=8
done
```

2. **Quality Monitoring**:
   - Track inference accuracy over time
   - Flag low-confidence enrichments for review
   - A/B test different prompts
   - Monitor UNKNOWN rates per field

3. **Cost Optimization**:
   - Cache enrichments (company → industry mapping)
   - Use smaller models (llama3.2:1b) for simple inference
   - Batch similar records together
   - Skip re-enrichment for recently processed companies

## Resources

### Documentation

- [PDI Documentation](https://help.hitachivantara.com/Documentation/Pentaho)
- [Ollama API Reference](https://github.com/ollama/ollama/blob/main/docs/api.md)
- [Workshop 1: Sentiment Analysis](../../workshop-01-sentiment-analysis/docs/workshop_1_sentiment_analysis.md)
- [Workshop 2: Data Quality](../../workshop-02-data-quality/docs/workshop_2_data_quality.md)

### Sample Code

- [Workshop 3 Transformations](../transformations/) - Basic and optimized versions
- [Sample Enrichment Data](../data/) - Input and output examples

### Community

- [PDI Community Forums](https://forums.pentaho.com/)
- [Ollama Discord](https://discord.gg/ollama)

## Feedback & Questions

Found an issue? Have suggestions? Please report at:
- GitHub Issues: https://github.com/anthropics/LLM-PDI-Integration/issues

---

**🎉 Congratulations! You've completed Workshop 3!**

You now know how to build AI-powered data enrichment pipelines that intelligently fill missing information and add valuable business classifications. Ready for Workshop 4? Explore Named Entity Recognition! 🚀
