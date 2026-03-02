# Workshop 2: Data Quality Enhancement with Ollama & PDI

**Duration:** 60-90 minutes
**Level:** Beginner to Intermediate
**Prerequisites:** Workshop 1 completed, Ollama installed and configured

## Overview

Learn how to use Large Language Models (LLMs) to automatically clean, standardize, and enhance data quality in your ETL pipelines. This workshop demonstrates using Ollama with Pentaho Data Integration (PDI) to fix common data quality issues like inconsistent formatting, invalid data, and missing information.

**What You'll Build:** An automated data quality pipeline that transforms messy customer data into clean, standardized records using AI-powered intelligence.

## Learning Objectives

By the end of this workshop, you will be able to:

- ✅ Use LLMs for data standardization and cleaning
- ✅ Handle inconsistent data formats (names, emails, phones, addresses)
- ✅ Build effective prompts for data quality tasks
- ✅ Implement parallel processing for 3-4x performance gains
- ✅ Handle errors and edge cases gracefully
- ✅ Deploy production-ready data quality pipelines

## Prerequisites

### Software Requirements

- Pentaho Data Integration (PDI/Spoon) 9.x or 11.x
- Ollama installed and running
- Model `llama3.2:3b` downloaded
- **Completed Workshop 1** (understanding of REST Client, JSON parsing)

### Knowledge Requirements

- Basic PDI transformation development
- Understanding of REST APIs and JSON
- Familiarity with data quality concepts
- JavaScript basics (for prompt construction)

## Architecture Overview

```
┌────────────────────────┐
│  Read Customer Data    │  Read raw CSV with quality issues
│  (CSV Input)           │
└──────────┬─────────────┘
           │
           ▼
┌────────────────────────┐
│  Build Optimized       │  Create compact LLM prompt with
│  Prompt (JavaScript)   │  data cleaning instructions
└──────────┬─────────────┘
           │
           ▼
┌────────────────────────┐
│  Build JSON Request    │  Construct Ollama API request
│  (JavaScript)          │  with model parameters
└──────────┬─────────────┘
           │
           ▼
┌────────────────────────┐
│  Call Ollama API       │  Send request to LLM
│  (REST Client - 4x)    │  **PARALLEL: 4 copies**
└──────────┬─────────────┘
           │
           ▼
┌────────────────────────┐
│  Parse JSON Response   │  Extract cleaned fields from
│  (JavaScript)          │  LLM response with error handling
└──────────┬─────────────┘
           │
           ▼
┌────────────────────────┐
│  Error Handling        │  Filter successful records,
│  (Filter Rows)         │  fallback to original on errors
└──────────┬─────────────┘
           │
           ▼
┌────────────────────────┐
│  Write Enhanced Data   │  Output cleaned data to CSV
│  (CSV Output)          │
└────────────────────────┘
```

### Workflow Explanation

1. **Read Customer Data**: Load raw customer records from CSV with common quality issues
2. **Build Optimized Prompt**: Create compact instructions for the LLM to clean and standardize each field
3. **Build JSON Request**: Construct the Ollama API request with model name and parameters
4. **Call Ollama API (Parallel)**: Send 4 simultaneous requests to the LLM for 3-4x performance
5. **Parse JSON Response**: Extract cleaned fields (name, email, phone, address, company) from LLM output
6. **Error Handling**: Check parsing success, fall back to original values if cleaning fails
7. **Write Enhanced Data**: Save cleaned records to timestamped CSV file

## Part 1: Understanding Data Quality Challenges (15 minutes)

### Step 1: Examine the Raw Data

Navigate to the workshop folder and review the sample data:

```bash
cd /home/pentaho/LLM-PDI-Integration/workshops/workshop-02-data-quality
cat data/customer_data_raw.csv | head -5
```

**Sample Records:**
```csv
customer_id,name,email,phone,address,company_name
1001,john smith,JSMITH@GMAIL.COM,555.123.4567,"123 main st apt 5, new york, ny","acme corp"
1002,SARAH JOHNSON,sarah.j@company,+1-555-987-6543,"456 oak avenue, los angeles, ca 90001",TechStart Inc
1005,JAMES WILSON,james@,555-999-8888,"PO Box 456, Seattle WA 98101","Cloud Services, Inc."
1010,Bob O'Brien,bob.obrien@tech.co,(555) 111-2222,"789 pine street suite 100, san francisco, ca 94102","AI Solutions LLC"
```

**Data Quality Issues Identified:**

| Customer | Name Issue | Email Issue | Phone Issue | Address Issue | Company Issue |
|----------|-----------|-------------|-------------|---------------|---------------|
| 1001 | Lowercase | Mixed case | Dots separator | Lowercase, abbreviations | Lowercase |
| 1002 | All caps | Incomplete domain | Valid format | Good | Mixed case |
| 1005 | Good | Missing domain | Dashes | Abbreviations | Good |
| 1010 | Good | Valid | Parentheses | Lowercase | Good |

### Step 2: Define Quality Standards

Our target output standards:

| Field | Standard Format | Example |
|-------|----------------|---------|
| **Name** | Title Case | `John Smith` |
| **Email** | lowercase@domain.com or `INVALID` | `jsmith@gmail.com` |
| **Phone** | +1-555-123-4567 | `+1-555-123-4567` |
| **Address** | Street, City, State ZIP | `123 Main St Apt 5, New York, NY` |
| **Company** | Proper Business Name | `Acme Corp` |

### Step 3: Traditional vs LLM Approach

**Common Data Quality Problems:**
- Inconsistent name formatting (john smith vs JOHN SMITH vs John Smith)
- Invalid or malformed email addresses
- Multiple phone number formats (+1-555-123-4567 vs 555.123.4567 vs (555) 123-4567)
- Incomplete or inconsistent addresses
- Company name variations (ACME CORP vs Acme Corp vs acme corp)

**Solution Comparison:**

| Approach | Pros | Cons | Example |
|----------|------|------|---------|
| **Regex/Rules** | Fast, deterministic | Brittle, requires constant updates for edge cases | `phone.replace(/[^\d]/g, '')` |
| **Data Quality Tools** | Comprehensive features | Expensive ($20K-$50K+), complex setup (weeks) | Informatica, Talend DQ |
| **Manual Cleaning** | 100% accurate | Doesn't scale, labor intensive | Excel find/replace |
| **LLM Approach** | Flexible, intelligent, handles edge cases | Requires LLM infrastructure | `"Clean and standardize this data..."` |

## Part 2: Understanding the Ollama API (10 minutes)

### API Endpoint Structure

Workshop 2 uses the same Ollama `/api/generate` endpoint as Workshop 1:

```
POST http://localhost:11434/api/generate
```

### Sample Request Format

```json
{
  "model": "llama3.2:3b",
  "prompt": "Clean this data. Return JSON: {\"name\":\"Title Case\",\"email\":\"valid@format\",\"phone\":\"+1-555-123-4567\",\"address\":\"St,City,ST ZIP\",\"company_name\":\"Proper Name\"}\nName:john smith\nEmail:JSMITH@GMAIL.COM\nPhone:555.123.4567\nAddr:123 main st apt 5, new york, ny\nCo:acme corp",
  "stream": false,
  "keep_alive": "5m",
  "options": {
    "temperature": 0.1,
    "num_predict": 300
  }
}
```

**Key Parameters:**
- `model`: `llama3.2:3b` - Smaller, faster model optimized for structured tasks
- `prompt`: Compact instructions with example format
- `stream`: `false` - Get complete response at once
- `keep_alive`: `"5m"` - Keep model loaded for 5 minutes (faster subsequent requests)
- `temperature`: `0.1` - Low randomness for consistent formatting
- `num_predict`: `300` - Limit output tokens

### Sample Response Format

```json
{
  "model": "llama3.2:3b",
  "created_at": "2026-02-27T14:00:00.000Z",
  "response": "{\"name\":\"John Smith\",\"email\":\"jsmith@gmail.com\",\"phone\":\"+1-555-123-4567\",\"address\":\"123 Main St Apt 5, New York, NY\",\"company_name\":\"Acme Corp\"}",
  "done": true,
  "total_duration": 1500000000,
  "load_duration": 100000000,
  "prompt_eval_count": 85,
  "prompt_eval_duration": 200000000,
  "eval_count": 45,
  "eval_duration": 1200000000
}
```

**Response Fields:**
- `response`: Contains the cleaned JSON data (as a string)
- `done`: `true` when generation is complete
- `prompt_eval_count`: Input tokens processed (85 tokens)
- `eval_count`: Output tokens generated (45 tokens)
- Total tokens: 130 tokens per record

### Test the API Manually

Test with a single messy record:

```bash
curl http://localhost:11434/api/generate -d '{
  "model": "llama3.2:3b",
  "prompt": "Clean this data. Return JSON: {\"name\":\"Title Case\",\"email\":\"valid@format\",\"phone\":\"+1-555-123-4567\",\"address\":\"St,City,ST ZIP\",\"company_name\":\"Proper Name\"}\nName:SARAH JOHNSON\nEmail:sarah.j@company\nPhone:+1-555-987-6543\nAddr:456 oak avenue, los angeles, ca 90001\nCo:TechStart Inc",
  "stream": false
}'
```

**Expected Response:**
```json
{
  "response": "{\"name\":\"Sarah Johnson\",\"email\":\"INVALID\",\"phone\":\"+1-555-987-6543\",\"address\":\"456 Oak Avenue, Los Angeles, CA 90001\",\"company_name\":\"TechStart Inc\"}"
}
```

Notice:
- Name converted to Title Case
- Email marked as `INVALID` (incomplete domain `@company`)
- Phone already in correct format
- Address capitalized and formatted
- Company name preserved (already correct)

## Part 3: Building the PDI Transformation (30 minutes)

### Transformation Overview

This workshop includes two transformation files:

| File | Purpose | Performance | Use Case |
|------|---------|-------------|----------|
| `data_quality_enhancement.ktr` | **Basic (Learning)** | ~60-80s for 20 records | Understanding the flow |
| `data_quality_enhancement_optimized.ktr` | **Optimized (Production)** | ~15-20s for 20 records | Real-world deployment |

**Key Differences:**
- Optimized version uses 4 parallel API calls (3-4x faster)
- Optimized prompts are 50% shorter
- Connection keep-alive reduces latency
- Enhanced error handling with fallbacks

### Step-by-Step Flow

Open the optimized transformation in Spoon:

```bash
cd /home/pentaho/LLM-PDI-Integration/workshops/workshop-02-data-quality
# Launch Spoon and open:
transformations/data_quality_enhancement_optimized.ktr
```

**Step 1: Read Customer Data (CSV Input)**

Configuration:
- **File**: `${INPUT_FILE}` parameter → `../data/customer_data_raw.csv`
- **Fields**: `customer_id`, `name`, `email`, `phone`, `address`, `company_name`
- **Separator**: `,` (comma)
- **Enclosure**: `"` (quotes)

**Step 2: Build Optimized Prompt (Modified Java Script Value)**

JavaScript code:
```javascript
// Optimized short prompt - 50% shorter than basic version
var llm_prompt = "Clean this data. Return JSON: {\"name\":\"Title Case\",\"email\":\"valid@format\",\"phone\":\"+1-555-123-4567\",\"address\":\"St,City,ST ZIP\",\"company_name\":\"Proper Name\"}\nName:" + name + "\nEmail:" + email + "\nPhone:" + phone + "\nAddr:" + address + "\nCo:" + company_name;
```

**Prompt Optimization Techniques:**
- ❌ Removed: Verbose explanations ("Clean and standardize this customer record...")
- ❌ Removed: Detailed field descriptions ("Full Name in Title Case")
- ✅ Kept: Clear format example in JSON
- ✅ Kept: Abbreviated field labels to reduce tokens
- **Result**: 50% shorter → 50% faster processing

**Step 3: Build JSON Request (Modified Java Script Value)**

**⚠️ CRITICAL: Use `getVariable()` for Parameters**

```javascript
// Build JSON request body with keep_alive
var model_name = getVariable("MODEL_NAME", "llama3.2:3b");
var keep_alive = getVariable("KEEP_ALIVE", "5m");

var requestObj = {
    "model": model_name,
    "prompt": llm_prompt,
    "stream": false,
    "keep_alive": keep_alive,
    "options": {
        "temperature": 0.1,
        "num_predict": 300
    }
};

var request_body = JSON.stringify(requestObj);
```

**Why `getVariable()`?**
- `"${MODEL_NAME}"` → **DOES NOT WORK** in JavaScript strings (stays literal)
- `getVariable("MODEL_NAME", "llama3.2:3b")` → **WORKS** (resolves to actual value)

**Step 4: Call Ollama API (Parallel) - REST Client**

**⚠️ IMPORTANT: Use REST Client, NOT HTTP Client!**

Configuration:
- **Step Type**: `REST Client` (Rest)
- **Method**: `POST`
- **URL**: `${OLLAMA_URL}/api/generate`
- **Body Field**: `request_body`
- **Result Fields**:
  - Name: `api_response`
  - Code: `result_code`
  - Response time: `response_time`
- **Headers**: *(leave empty - REST Client auto-adds Content-Type)*
- **Step Copies**: `${STEP_COPIES}` → Default: 4 (parallel processing)

**Step 5: Parse JSON Response (Modified Java Script Value)**

```javascript
// Parse the Ollama response with robust error handling
var enhanced_name = name;
var enhanced_email = email;
var enhanced_phone = phone;
var enhanced_address = address;
var enhanced_company = company_name;
var parsing_error = "N";
var error_message = "";

try {
    var response = JSON.parse(api_response);
    var fullResponse = response.response;

    // Extract JSON from response (handles various formats)
    var jsonStart = fullResponse.indexOf("{");
    var jsonEnd = fullResponse.lastIndexOf("}") + 1;

    if (jsonStart >= 0 && jsonEnd > jsonStart) {
        var jsonStr = fullResponse.substring(jsonStart, jsonEnd);
        var data = JSON.parse(jsonStr);

        enhanced_name = data.name || name;
        enhanced_email = data.email || email;
        enhanced_phone = data.phone || phone;
        enhanced_address = data.address || address;
        enhanced_company = data.company_name || company_name;
    } else {
        parsing_error = "Y";
        error_message = "No JSON found in response";
    }
} catch(e) {
    parsing_error = "Y";
    error_message = e.message || "Parse error";
}
```

**Error Handling Strategy:**
1. Start with original values as fallback
2. Try to parse Ollama JSON response
3. Extract JSON object from response text (handles markdown code blocks)
4. Parse individual fields with fallback to original
5. Set `parsing_error = "Y"` if anything fails
6. Keep original values on error

**Step 6: Error Handling (Filter Rows)**

Filter condition: `parsing_error = "N"`

- **Send TRUE to**: "Write Enhanced Data" (successfully cleaned records)
- **Send FALSE to**: *(nowhere - discard failed records or log separately)*

**Step 7: Write Enhanced Data (Text File Output)**

Configuration:
- **Filename**: `../data/customer_data_enhanced_optimized`
- **Extension**: `.csv`
- **Add date**: `Y` (adds `_20260227`)
- **Add time**: `Y` (adds `_134529`)
- **Result**: `customer_data_enhanced_optimized_20260227_134529.csv`
- **Fields**: `customer_id`, `enhanced_name`, `enhanced_email`, `enhanced_phone`, `enhanced_address`, `enhanced_company`

### Transformation Parameters

#### Basic Transformation (`data_quality_enhancement.ktr`)

| Parameter | Default Value | Description |
|-----------|---------------|-------------|
| OLLAMA_URL | http://localhost:11434 | Ollama API endpoint |
| MODEL_NAME | llama3.2:3b | Model to use for data cleaning |
| INPUT_FILE | ../data/customer_data_raw.csv | Input data path |

#### Optimized Transformation (`data_quality_enhancement_optimized.ktr`)

| Parameter | Default Value | Description |
|-----------|---------------|-------------|
| OLLAMA_URL | http://localhost:11434 | Ollama API endpoint |
| MODEL_NAME | llama3.2:3b | Model to use (llama3.2:3b recommended) |
| INPUT_FILE | ../data/customer_data_raw.csv | Input data path |
| **KEEP_ALIVE** | **5m** | **Keep model in memory (5m/15m/30m/60m)** |
| **STEP_COPIES** | **4** | **Parallel API calls (set to CPU cores - 1)** |

**Parameter Tuning Guide:**

| CPU Cores | STEP_COPIES | Expected Throughput |
|-----------|-------------|---------------------|
| 4 cores | 4 | 1.0-1.2 rec/sec |
| 8 cores | 6-8 | 1.5-2.0 rec/sec |
| 16 cores | 12-14 | 2.5-3.5 rec/sec |

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
STEP_COPIES=4
KEEP_ALIVE=5m
INPUT_FILE=../data/customer_data_raw.csv
```

## Part 4: Running the Transformation (10 minutes)

### Option 1: Using Spoon (PDI GUI)

1. Open Spoon
2. File → Open → Navigate to:
   ```
   /home/pentaho/LLM-PDI-Integration/workshops/workshop-02-data-quality/transformations/data_quality_enhancement_optimized.ktr
   ```
3. Press **F9** or click **Run** (▶ button)
4. Leave parameters at default (or customize):
   - OLLAMA_URL: `http://localhost:11434`
   - MODEL_NAME: `llama3.2:3b`
   - STEP_COPIES: `4`
   - KEEP_ALIVE: `5m`
   - INPUT_FILE: `../data/customer_data_raw.csv`
5. Click **Launch**
6. Monitor progress in the execution log
7. Wait for completion (~15-20 seconds for 20 records)

### Option 2: Using Pan (Command Line)

Navigate to the transformation directory and run:

```bash
cd /home/pentaho/LLM-PDI-Integration/workshops/workshop-02-data-quality/transformations

# Run with default parameters
~/Pentaho/design-tools/data-integration/pan.sh \
  -file=data_quality_enhancement_optimized.ktr \
  -param:OLLAMA_URL=http://localhost:11434 \
  -param:MODEL_NAME=llama3.2:3b \
  -param:STEP_COPIES=4 \
  -param:KEEP_ALIVE=5m
```

**Custom parameters example:**

```bash
# Use more parallelism on 8-core CPU
~/Pentaho/design-tools/data-integration/pan.sh \
  -file=data_quality_enhancement_optimized.ktr \
  -param:OLLAMA_URL=http://localhost:11434 \
  -param:MODEL_NAME=llama3.2:3b \
  -param:STEP_COPIES=8 \
  -param:KEEP_ALIVE=15m
```

### Expected Output

```
2026-02-27 14:00:05.590 - data_quality_enhancement_optimized - Starting Transformation
2026-02-27 14:00:05.601 - Read Customer Data.0 - Finished processing (I=21, O=0, R=0, W=20, U=0, E=0)
2026-02-27 14:00:05.631 - Build Optimized Prompt.0 - Finished processing (I=0, O=0, R=20, W=20, U=0, E=0)
2026-02-27 14:00:05.711 - Build JSON Request.0 - Finished processing (I=0, O=0, R=20, W=20, U=0, E=0)
2026-02-27 14:00:12.417 - Call Ollama API (Parallel).0 - Finished processing (I=0, O=0, R=5, W=5, U=0, E=0)
2026-02-27 14:00:12.417 - Call Ollama API (Parallel).1 - Finished processing (I=0, O=0, R=5, W=5, U=0, E=0)
2026-02-27 14:00:12.417 - Call Ollama API (Parallel).2 - Finished processing (I=0, O=0, R=5, W=5, U=0, E=0)
2026-02-27 14:00:12.417 - Call Ollama API (Parallel).3 - Finished processing (I=0, O=0, R=5, W=5, U=0, E=0)
2026-02-27 14:00:12.425 - Parse JSON Response.0 - Finished processing (I=0, O=0, R=20, W=20, U=0, E=0)
2026-02-27 14:00:12.426 - Error Handling.0 - Finished processing (I=0, O=0, R=20, W=20, U=0, E=0)
2026-02-27 14:00:12.450 - Write Enhanced Data.0 - Finished processing (I=0, O=0, R=0, W=20, U=0, E=0)
```

**Performance Metrics:**
- **Total Time**: ~15-20 seconds
- **Records Processed**: 20 (from 21 rows including header)
- **Throughput**: ~1.0-1.3 records/second
- **Parallel Efficiency**: Each copy processed 5 records (20 ÷ 4 = 5)

## Part 5: Analyzing Results (15 minutes)

### View the Results

Navigate to the output directory and find the latest file:

```bash
cd /home/pentaho/LLM-PDI-Integration/workshops/workshop-02-data-quality/data
ls -lt customer_data_enhanced_optimized_*.csv | head -1
```

View the cleaned data:

```bash
cat customer_data_enhanced_optimized_20260227_*.csv | head -10
```

### Sample Output Comparison

**Before (Raw Data):**
```csv
customer_id,name,email,phone,address,company_name
1001,john smith,JSMITH@GMAIL.COM,555.123.4567,"123 main st apt 5, new york, ny","acme corp"
1002,SARAH JOHNSON,sarah.j@company,+1-555-987-6543,"456 oak avenue, los angeles, ca 90001",TechStart Inc
1005,JAMES WILSON,james@,555-999-8888,"PO Box 456, Seattle WA 98101","Cloud Services, Inc."
```

**After (Enhanced Data):**
```csv
customer_id,enhanced_name,enhanced_email,enhanced_phone,enhanced_address,enhanced_company
1001,John Smith,jsmith@gmail.com,+1-555-123-4567,"123 Main St Apt 5, New York, NY",Acme Corp
1002,Sarah Johnson,INVALID,+1-555-987-6543,"456 Oak Avenue, Los Angeles, CA 90001",TechStart Inc
1005,James Wilson,INVALID,+1-555-999-8888,"PO Box 456, Seattle, WA 98101",Cloud Services Inc
```

### CSV Output Format

| Field | Description | Example |
|-------|-------------|---------|
| customer_id | Original customer ID (unchanged) | 1001 |
| enhanced_name | Title Case formatted name | John Smith |
| enhanced_email | Validated email or INVALID | jsmith@gmail.com |
| enhanced_phone | Standardized phone format | +1-555-123-4567 |
| enhanced_address | Properly formatted address | 123 Main St Apt 5, New York, NY |
| enhanced_company | Cleaned company name | Acme Corp |

### Analysis Questions

1. **Name Cleaning Effectiveness**: How many names were changed from all-caps or all-lowercase?
2. **Email Validation**: How many emails were marked as INVALID?
3. **Phone Standardization**: Were all phone formats converted to `+1-555-123-4567`?
4. **Address Formatting**: Did addresses get proper capitalization and state abbreviations?
5. **Company Consistency**: Were company names standardized?

### Sample Analysis Query

Count validation results:

```bash
# Count INVALID emails
grep -c "INVALID" customer_data_enhanced_optimized_*.csv

# Show all INVALID email records
grep "INVALID" customer_data_enhanced_optimized_*.csv

# Compare original vs enhanced names
paste -d',' <(tail -n +2 customer_data_raw.csv | cut -d',' -f2) \
             <(tail -n +2 customer_data_enhanced_optimized_*.csv | cut -d',' -f2) \
  | awk -F',' '$1 != $2 {print "Changed: " $1 " → " $2}'
```

## Part 6: Exercises & Extensions (Bonus)

### Exercise 1: Add ZIP Code Validation

**Task**: Enhance the prompt to validate and format ZIP codes separately

**Hints:**
- Modify the prompt JSON to include: `"zip":"12345 or 12345-6789"`
- Parse ZIP from address field first
- Add validation step after LLM parsing

**Solution:**
```javascript
var llm_prompt = "Clean this data. Return JSON: {\"name\":\"Title Case\",\"email\":\"valid@format\",\"phone\":\"+1-555-123-4567\",\"address\":\"St,City,ST\",\"zip\":\"12345 or 12345-6789\",\"company_name\":\"Proper Name\"}\nName:" + name + "\nEmail:" + email + "\nPhone:" + phone + "\nAddr:" + address + "\nCo:" + company_name;
```

### Exercise 2: Confidence Scoring

**Task**: Ask LLM to provide confidence scores for each cleaned field

**Hints:**
- Add `_confidence` fields to the prompt
- Parse confidence scores (0-100)
- Flag low-confidence records for manual review

**Solution:**
```javascript
var llm_prompt = "Clean this data and rate confidence 0-100. Return JSON: {\"name\":\"Title Case\",\"name_confidence\":95,\"email\":\"valid@format\",\"email_confidence\":80,\"phone\":\"+1-555-123-4567\",\"phone_confidence\":100,...}\nName:" + name + "...";
```

### Exercise 3: Selective Processing

**Task**: Only send records to LLM if they need cleaning

**Hints:**
- Add a "Filter Rows" step before "Build Optimized Prompt"
- Check if name is all-caps, all-lowercase, or email missing '@'
- Skip LLM call for already-clean records

**Solution:**
```javascript
// In Filter Rows step
var needsCleaning = (
    name !== name.replace(/^[A-Z]+$/, '') ||  // All caps
    name !== name.replace(/^[a-z]+$/, '') ||  // All lowercase
    email.indexOf("@") === -1 ||               // No @ symbol
    phone.length < 10                          // Too short
);

// Send to LLM only if needsCleaning == true
```

### Exercise 4: Different Models

Test with different Ollama models to compare quality and speed:

```bash
# Pull alternative models
ollama pull llama3.2:1b    # Smaller, faster
ollama pull llama2:7b      # Larger, more capable

# Run transformation with different MODEL_NAME parameter
~/Pentaho/design-tools/data-integration/pan.sh \
  -file=data_quality_enhancement_optimized.ktr \
  -param:MODEL_NAME=llama3.2:1b \
  -param:STEP_COPIES=4
```

Compare results:
- **llama3.2:1b**: 2x faster, slightly lower quality
- **llama3.2:3b**: Balanced (recommended)
- **llama2:7b**: Slower, highest quality

### Exercise 5: Batch Processing

**Task**: Process records in batches of 5 to reduce API calls

**Hints:**
- Use "Group by" or "Row denormalizer" to combine 5 records
- Modify prompt to handle multiple records at once
- Parse batch response and split back into individual records

### Exercise 6: Dashboard Integration

**Task**: Create a quality metrics dashboard

**Hints:**
- Add steps to count: total records, invalid emails, changed names, etc.
- Write metrics to a summary table
- Use PDI's table output to send to database
- Visualize with Grafana, Superset, or Pentaho CDE

## Troubleshooting

### Common Issues & Quick Fixes

| Issue | Symptom | Quick Fix |
|-------|---------|-----------|
| 405 Method Not Allowed | REST error in log | Use REST Client (not HTTP Client) |
| 400 Bad Request | "invalid duration" error | Use `getVariable()` instead of `"${VAR}"` |
| Empty output file | 0 bytes written | Check `parsing_error` field - all records failed parsing |
| Slow performance | 60+ seconds for 20 records | Increase STEP_COPIES or use smaller model |
| Out of memory | Ollama crashes | Reduce STEP_COPIES or use llama3.2:1b |

### Issue 1: Empty Output File (0 bytes) ⚠️

**Symptoms:**
```bash
ls -lh data/customer_data_enhanced_optimized_*.csv
# -rw-rw-r-- 1 pentaho pentaho 0 Feb 27 13:45 customer_data_enhanced_optimized_20260227_134529.csv
```

**Cause:** All records have `parsing_error = "Y"` and are filtered out

**Debug Steps:**

1. **Check if LLM is responding:**
```bash
curl -s http://localhost:11434/api/generate -d '{"model":"llama3.2:3b","prompt":"Test","stream":false}' | jq .
```

2. **Add a "Write to log" step after "Parse JSON Response":**
   - Log fields: `customer_id`, `parsing_error`, `error_message`
   - Check what errors are occurring

3. **Common causes:**
   - LLM returning text instead of JSON (fix prompt to be more explicit)
   - JavaScript parsing error (check for typos in field names)
   - API timeout (increase `keep_alive` or reduce `STEP_COPIES`)

**Solution:**
```javascript
// Make prompt more explicit
var llm_prompt = "CRITICAL: Return ONLY valid JSON, no other text. Format: {\"name\":\"...\",\"email\":\"...\",\"phone\":\"...\",\"address\":\"...\",\"company_name\":\"...\"}\nClean this data:\nName:" + name + "...";
```

### Issue 2: Slow Performance

**Symptoms**: Taking 60+ seconds for 20 records

**Solutions:**

1. **Check Ollama status:**
```bash
systemctl status ollama
# Should show "active (running)"
```

2. **Verify CPU optimization:**
```bash
cat /etc/systemd/system/ollama.service.d/override.conf
# Should have: OLLAMA_NUM_PARALLEL=4
```

3. **Use smaller model:**
```bash
# Pull 1B model (2x faster)
ollama pull llama3.2:1b

# Run transformation
pan.sh -file=data_quality_enhancement_optimized.ktr -param:MODEL_NAME=llama3.2:1b
```

4. **Increase parallelism:**
```bash
# For 8-core CPU
pan.sh -file=data_quality_enhancement_optimized.ktr -param:STEP_COPIES=8
```

### Issue 3: Ollama Not Responding

**Symptoms**: Connection refused or timeout errors

**Solutions:**

```bash
# Check if Ollama is running
curl http://localhost:11434/api/tags
# Should return JSON with available models

# If not, start Ollama
sudo systemctl start ollama

# Check Ollama status
sudo systemctl status ollama

# Check Ollama logs
sudo journalctl -u ollama -f
```

### Issue 4: Inconsistent Output Format

**Symptoms**: JSON parsing errors, fields missing

**Solutions:**

1. **Make prompt more explicit:**
```javascript
var llm_prompt = "CRITICAL: Return ONLY valid JSON, no markdown, no explanations. " +
  "Format: {\"name\":\"...\",\"email\":\"...\",\"phone\":\"...\",\"address\":\"...\",\"company_name\":\"...\"}\n" +
  "Clean this data:\nName:" + name + "...";
```

2. **Add format examples:**
```javascript
var llm_prompt = "Return JSON like this example: {\"name\":\"John Smith\",\"email\":\"john@example.com\",\"phone\":\"+1-555-123-4567\",\"address\":\"123 Main St, City, ST 12345\",\"company_name\":\"Example Corp\"}\n" +
  "Now clean this data:\nName:" + name + "...";
```

3. **Use JSON mode (if model supports):**
```javascript
var requestObj = {
    "model": model_name,
    "prompt": llm_prompt,
    "format": "json",  // Enforce JSON output
    "stream": false
};
```

### Issue 5: Out of Memory Errors

**Symptoms**: Ollama crashes, system slowdown, OOM killer messages

**Solutions:**

1. **Monitor memory usage:**
```bash
watch -n 1 free -h
```

2. **Use smaller model:**
```bash
ollama pull llama3.2:1b  # Uses ~2GB RAM vs 3.2GB for 3b
```

3. **Reduce parallelism:**
```bash
pan.sh -file=data_quality_enhancement_optimized.ktr -param:STEP_COPIES=2
```

4. **Increase system memory or add swap:**
```bash
# Add 4GB swap
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

## Key Takeaways

✅ **LLMs excel at context-aware data cleaning** that would require complex rules
✅ **Parallel processing is critical** for acceptable performance (3-4x speedup)
✅ **Prompt optimization** can dramatically improve speed and quality (50% token reduction)
✅ **Error handling and fallbacks** are essential for production use
✅ **Local deployment (Ollama)** provides privacy and cost benefits

**Performance Comparison:**

| Version | 20 Records | 100 Records | Throughput | Speedup |
|---------|-----------|-------------|------------|---------|
| Basic | ~60-80s | ~300-400s | 0.25 rec/sec | 1x |
| Optimized | ~15-20s | ~60-80s | 1.0-1.5 rec/sec | **4-6x** |

**Quality Improvements Achieved:**
- Names: 100% converted to Title Case
- Emails: Validated, incomplete marked as INVALID
- Phones: 100% standardized to +1-555-123-4567 format
- Addresses: Properly capitalized and formatted
- Companies: Consistent business name formatting

## Next Steps

### Continue Learning

1. **Workshop 3**: Data Enrichment (coming soon)
   - Add missing information
   - Lookup company details
   - Geocode addresses

2. **Workshop 4**: Named Entity Recognition (coming soon)
   - Extract people, places, organizations
   - Categorize unstructured text
   - Build knowledge graphs

### Production Deployment

1. **Schedule with PDI Kitchen:**
```bash
# Create job (.kjb file) that runs transformation
# Schedule with cron
0 2 * * * /opt/pentaho/kitchen.sh -file=/path/to/data_quality_job.kjb >> /var/log/pdi/quality.log 2>&1
```

2. **Scale Up:**
   - Deploy multiple PDI instances
   - Use PDI clustering for very large datasets
   - Consider vLLM or LM Studio for higher throughput

3. **Monitor Quality:**
   - Track enhancement success rate
   - Monitor API performance and response times
   - Log errors and retries for troubleshooting
   - Create quality metrics dashboard

## Resources

### Documentation

- [PDI Documentation](https://help.hitachivantara.com/Documentation/Pentaho)
- [Ollama API Reference](https://github.com/ollama/ollama/blob/main/docs/api.md)
- [Workshop 1: Sentiment Analysis](../../workshop-01-sentiment-analysis/docs/workshop_1_sentiment_analysis.md)

### Sample Code

- [PARAMETERS_REFERENCE.md](./PARAMETERS_REFERENCE.md) - Detailed parameter guide
- [Workshop 2 Transformations](../transformations/) - Basic and optimized versions

### Community

- [PDI Community Forums](https://forums.pentaho.com/)
- [Ollama Discord](https://discord.gg/ollama)

## Feedback & Questions

Found an issue? Have suggestions? Please report at:
- GitHub Issues: https://github.com/anthropics/LLM-PDI-Integration/issues
- Email: [your-email@example.com]

## Appendix A: Architecture Workflow Detailed

### Complete Data Flow

```
1. Read Customer Data (CSV Input)
   ├─ Input: customer_data_raw.csv (20 records)
   ├─ Fields: customer_id, name, email, phone, address, company_name
   └─ Output: 20 rows → "Build Optimized Prompt"

2. Build Optimized Prompt (JavaScript)
   ├─ Input: Raw customer fields
   ├─ Logic: Concatenate compact prompt with format example
   ├─ Example: "Clean this data. Return JSON: {...}\nName:john smith\nEmail:..."
   └─ Output: llm_prompt field → "Build JSON Request"

3. Build JSON Request (JavaScript)
   ├─ Input: llm_prompt
   ├─ Logic: Build Ollama API JSON request body
   ├─ Parameters: model_name (from getVariable), keep_alive, temperature
   └─ Output: request_body field → "Call Ollama API (Parallel)"

4. Call Ollama API (Parallel) - REST Client
   ├─ Input: request_body (JSON string)
   ├─ Method: POST to ${OLLAMA_URL}/api/generate
   ├─ Parallelism: 4 step copies (processes 5 records each)
   ├─ Processing: Each copy makes sequential API calls for its 5 records
   └─ Output: api_response, result_code → "Parse JSON Response"

5. Parse JSON Response (JavaScript)
   ├─ Input: api_response (Ollama JSON)
   ├─ Logic: Extract response.response field, parse JSON, handle errors
   ├─ Fallback: On error, use original values + set parsing_error="Y"
   └─ Output: enhanced_* fields, parsing_error, error_message → "Error Handling"

6. Error Handling (Filter Rows)
   ├─ Input: All enhanced fields + parsing_error
   ├─ Condition: parsing_error = "N"
   ├─ TRUE → "Write Enhanced Data"
   └─ FALSE → (discard or log)

7. Write Enhanced Data (CSV Output)
   ├─ Input: Successfully enhanced records
   ├─ Output: customer_data_enhanced_optimized_[timestamp].csv
   └─ Fields: customer_id, enhanced_name, enhanced_email, enhanced_phone, enhanced_address, enhanced_company
```

### What Happens at Each Step

**Step 1: Read Customer Data**
- Reads CSV file from `${INPUT_FILE}` parameter
- Skips header row
- Loads 20 records into memory
- Each record becomes a row in the data stream

**Step 2: Build Optimized Prompt**
- For each row, concatenates a compact prompt string
- Includes JSON format example for the LLM
- Provides raw data values to be cleaned
- Optimized to use 50% fewer tokens than verbose prompts

**Step 3: Build JSON Request**
- **CRITICAL**: Uses `getVariable("MODEL_NAME")` to resolve parameter
- Constructs Ollama API request JSON
- Sets `keep_alive` to keep model loaded between requests
- Sets `temperature: 0.1` for consistent, deterministic formatting

**Step 4: Call Ollama API (Parallel)**
- **4 parallel copies** process records simultaneously
- Each copy handles 5 records (20 total ÷ 4 = 5 per copy)
- Sends POST request to Ollama
- Waits for LLM to generate cleaned JSON
- Returns `api_response` with LLM output

**Step 5: Parse JSON Response**
- Parses Ollama's JSON wrapper
- Extracts `response.response` field (contains cleaned data)
- Handles markdown code blocks: `{"name":"..."}` or ` ```json\n{...}\n``` `
- Parses cleaned JSON into individual fields
- **Error handling**: If anything fails, keeps original values and sets `parsing_error="Y"`

**Step 6: Error Handling**
- Filters rows based on `parsing_error` field
- Successfully cleaned records (parsing_error="N") → Write Enhanced Data
- Failed records (parsing_error="Y") → Discarded or logged

**Step 7: Write Enhanced Data**
- Writes cleaned records to CSV
- Adds timestamp to filename for versioning
- Outputs enhanced fields (prefixed with `enhanced_`)

## Appendix B: Ollama Model Comparison

| Model | Size | RAM Required | Speed | Quality | Best For |
|-------|------|--------------|-------|---------|----------|
| llama3.2:1b | 1.3GB | 2GB | **Fastest** (2x) | Good | High-volume, simple cleaning |
| **llama3.2:3b** | **2.0GB** | **3GB** | **Fast** | **Very Good** | **Recommended for most use cases** |
| llama2:7b | 3.8GB | 6GB | Slower | Excellent | Complex cleaning, high accuracy needs |
| mistral:7b | 4.1GB | 6GB | Slower | Excellent | Technical data, code formatting |

**Recommendation:** Use `llama3.2:3b` for the best balance of speed, quality, and resource usage.

**Switching Models:**
```bash
# Pull alternative model
ollama pull llama3.2:1b

# Run transformation with different model
pan.sh -file=data_quality_enhancement_optimized.ktr -param:MODEL_NAME=llama3.2:1b
```

## Appendix C: Common Prompt Patterns

### Data Cleaning Prompt (Workshop 2)

```javascript
var llm_prompt = "Clean this data. Return JSON: {\"name\":\"Title Case\",\"email\":\"valid@format\",\"phone\":\"+1-555-123-4567\",\"address\":\"St,City,ST ZIP\",\"company_name\":\"Proper Name\"}\nName:" + name + "\nEmail:" + email + "\nPhone:" + phone + "\nAddr:" + address + "\nCo:" + company_name;
```

### Classification Prompt

```javascript
var llm_prompt = "Classify this customer record. Return JSON: {\"category\":\"Enterprise|SMB|Startup\",\"confidence\":0-100}\nCompany:" + company_name + "\nRevenue:" + revenue + "\nEmployees:" + employee_count;
```

### Extraction Prompt

```javascript
var llm_prompt = "Extract structured data. Return JSON: {\"person_name\":\"...\",\"organization\":\"...\",\"location\":\"...\",\"date\":\"YYYY-MM-DD\"}\nText:" + unstructured_text;
```

### Summarization Prompt

```javascript
var llm_prompt = "Summarize in 50 words. Return JSON: {\"summary\":\"...\"}\nText:" + long_description;
```

## Appendix D: PDI Step Reference

### REST Client Step Configuration (Use This, Not HTTP Client!)

**Basic Settings:**
- **Step name**: Call Ollama API (Parallel)
- **Step type**: REST Client (`Rest`)

**Connection:**
- **Method**: `POST`
- **URL**: `${OLLAMA_URL}/api/generate`
- **Body field**: `request_body` (contains JSON string)

**Result:**
- **Result fieldname**: `api_response`
- **Status code fieldname**: `result_code`
- **Response time (ms) fieldname**: `response_time`

**Headers:**
- *(Leave empty - REST Client auto-adds Content-Type: application/json)*

**Performance:**
- **Number of copies to start**: `${STEP_COPIES}` (typically 4)
- **Distribute**: ✅ Yes

**Why REST Client vs HTTP Client?**
- REST Client automatically adds proper headers
- Better JSON handling
- Supports bodyField parameter
- More reliable for API integrations

### Modified Java Script Value Configuration

**For Building Prompts:**

```javascript
// Field: llm_prompt (String)
var llm_prompt = "Clean this data. Return JSON: {...}\nName:" + name + "...";
```

**For Building Requests:**

```javascript
// Field: request_body (String)
var model_name = getVariable("MODEL_NAME", "llama3.2:3b");
var keep_alive = getVariable("KEEP_ALIVE", "5m");

var requestObj = {
    "model": model_name,
    "prompt": llm_prompt,
    "stream": false,
    "keep_alive": keep_alive
};

var request_body = JSON.stringify(requestObj);
```

**For Parsing Responses:**

```javascript
// Fields: enhanced_name, enhanced_email, etc. (String)
var enhanced_name = name; // Start with fallback

try {
    var response = JSON.parse(api_response);
    var jsonStr = response.response.substring(
        response.response.indexOf("{"),
        response.response.lastIndexOf("}") + 1
    );
    var data = JSON.parse(jsonStr);
    enhanced_name = data.name || name;
} catch(e) {
    // Keep fallback value
}
```

---

**🎉 Congratulations! You've completed Workshop 2!**

You now know how to build production-ready data quality pipelines using LLMs and PDI. Ready for Workshop 3? Explore data enrichment techniques! 🚀
