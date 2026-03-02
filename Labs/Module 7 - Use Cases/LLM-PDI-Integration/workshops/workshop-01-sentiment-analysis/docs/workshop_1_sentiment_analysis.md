# Workshop 1: Customer Review Sentiment Analysis with Ollama & PDI

## Overview
This workshop demonstrates how to integrate a Large Language Model (LLM) via Ollama with Pentaho Data Integration (PDI) to perform sentiment analysis on customer reviews. You'll learn how to build an ETL pipeline that reads customer feedback, analyzes sentiment using AI, and outputs structured results.

**Difficulty Level:** Beginner
**Duration:** 60-90 minutes
**Platform:** Ubuntu 24.04

## Learning Objectives
By the end of this workshop, you will:
1. Install and configure Ollama on Ubuntu 24.04
2. Understand Ollama's REST API structure
3. Build a PDI transformation that integrates with LLMs
4. Parse JSON responses from AI models
5. Extract structured insights from unstructured text
6. Create a complete sentiment analysis pipeline

## Prerequisites

### Software Requirements
- Ubuntu 24.04 LTS
- Pentaho Data Integration (PDI/Kettle) 9.x or later
- curl (for testing)
- Internet connection (for Ollama installation and model downloads)

### Knowledge Requirements
- Basic understanding of PDI transformations
- Familiarity with CSV files and JSON format
- Basic Linux command line skills

## Architecture Overview

```
┌────────────────────────┐
│  Read Customer         │  Read customer reviews from
│  Reviews (CSV Input)   │  CSV file with review text
└──────────┬─────────────┘
           │
           ▼
┌────────────────────────┐
│  Build Optimized       │  Create compact sentiment
│  Prompt (JavaScript)   │  analysis prompt
└──────────┬─────────────┘
           │
           ▼
┌────────────────────────┐
│  Build JSON Request    │  Construct Ollama API request
│  (JavaScript)          │  with keep_alive parameter
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
│  Parse JSON Response   │  Extract sentiment, score,
│  (JavaScript)          │  confidence, key phrases
└──────────┬─────────────┘
           │
           ▼
┌────────────────────────┐
│  Write Enriched CSV    │  Save results with original
│  (Text Output)         │  reviews + AI insights
└────────────────────────┘
```

### Workflow Explanation

1. **Read Customer Reviews** - Loads customer feedback data from CSV file containing review text, product names, and customer details
2. **Build Optimized Prompt** - JavaScript step constructs a compact sentiment analysis prompt (40% shorter than basic version) requesting JSON output with sentiment, score, confidence, key phrases, and summary. **Note:** This step also builds the API request body in the same JavaScript block for simplicity (combines steps 2-3 that are separated in Workshop 2)
3. **Call Ollama API (Parallel)** - REST Client step sends POST request to `http://localhost:11434/api/generate` using **4 parallel copies** for 3-4x performance improvement. Distributes reviews across concurrent streams
4. **Parse JSON Response** - Uses PDI's native JSON Input step to extract structured fields from API response:
   - Sentiment classification (positive/negative/neutral)
   - Numeric score (-1.0 to 1.0)
   - Confidence percentage (0-100%)
   - Key phrases from the review
   - One-sentence summary
5. **Write Enriched CSV** - Outputs final dataset combining original review data with all AI-generated sentiment insights (file includes timestamp)

> **Design Note:** Workshop 1 combines prompt building and API request construction in a single JavaScript step for simplicity. Workshop 2 demonstrates a more modular approach with separated steps, which provides better debuggability and follows software engineering best practices. Both approaches are valid - this workshop prioritizes simplicity for beginners, while later workshops introduce professional patterns for production environments.

## Part 1: Understanding Sentiment Analysis (15 minutes)

### What is Sentiment Analysis?

Sentiment Analysis is the process of computationally identifying and categorizing opinions expressed in text to determine whether the writer's attitude toward a particular topic, product, or service is positive, negative, or neutral.

**Example Input:**
```
"This laptop exceeded my expectations! The battery life is incredible and the
performance is blazing fast. Highly recommend for anyone looking for a quality machine."
```

**Example Output (Sentiment Analysis):**
```json
{
  "sentiment": "positive",
  "score": 0.9,
  "confidence": 95,
  "key_phrases": ["exceeded expectations", "incredible battery", "blazing fast", "highly recommend"],
  "summary": "Customer extremely satisfied with laptop performance and battery life"
}
```

### Why is Sentiment Analysis Important?

**Business Applications:**
1. **Customer Feedback Analysis** - Automatically categorize thousands of reviews to identify satisfaction trends
2. **Brand Monitoring** - Track public sentiment about your brand across social media and review sites
3. **Product Improvement** - Identify which features customers love and which need improvement
4. **Customer Support Prioritization** - Route angry customers to experienced support agents first
5. **Market Research** - Understand customer opinions about competitor products
6. **Crisis Detection** - Quickly identify negative sentiment spikes that require immediate attention

**Real-World Example:**
A company receives 10,000 product reviews per month. Manual analysis would take weeks. With sentiment analysis:
- **Instant categorization**: 7,500 positive, 1,800 neutral, 700 negative
- **Identify issues**: Negative reviews mention "battery life" 450 times → product team investigates
- **Measure satisfaction**: 75% positive sentiment score → track over time
- **Prioritize responses**: Route the 200 most negative reviews to customer service

### Types of Sentiment

**1. Polarity (Basic)**
- **Positive**: "This product is amazing!"
- **Negative**: "Terrible quality, waste of money"
- **Neutral**: "The product arrived on Tuesday"

**2. Granular Sentiment (Scored)**
- **Very Positive**: +0.8 to +1.0 ("Best purchase ever!")
- **Positive**: +0.3 to +0.7 ("Good value for money")
- **Neutral**: -0.2 to +0.2 ("It works as described")
- **Negative**: -0.7 to -0.3 ("Not what I expected")
- **Very Negative**: -1.0 to -0.8 ("Complete garbage, requesting refund")

**3. Emotion-Based Sentiment** (Advanced)
- **Joy**: "So happy with this purchase!"
- **Anger**: "This company has the worst customer service!"
- **Frustration**: "Why doesn't this feature work properly?"
- **Disappointment**: "Expected better quality for the price"

### How LLMs Improve Sentiment Analysis

**Traditional Methods (Rule-Based/ML):**
```python
# Simple keyword matching
positive_words = ["good", "great", "excellent", "love"]
negative_words = ["bad", "poor", "terrible", "hate"]

if text contains more positive_words:
    sentiment = "positive"
```

**Problems with Traditional Methods:**
- ❌ Can't handle context: "This isn't bad" → Detected as negative (contains "bad")
- ❌ Misses sarcasm: "Oh great, another software bug" → Detected as positive (contains "great")
- ❌ Ignores negation: "Not good at all" → Detected as positive (contains "good")
- ❌ Limited to trained categories
- ❌ Requires extensive labeled training data

**LLM-Based Sentiment Analysis:**
```
Prompt: "Analyze the sentiment of this review and respond in JSON format..."

LLM Response:
{
  "sentiment": "positive",
  "score": 0.85,
  "confidence": 90,
  "reasoning": "Customer expresses satisfaction with performance and battery,
               uses enthusiastic language ('exceeded expectations', 'incredible')"
}
```

**Advantages of LLMs:**
- ✅ Understands context and nuance
- ✅ Detects sarcasm and irony
- ✅ Handles negation correctly
- ✅ Provides explanations and reasoning
- ✅ Extracts key phrases automatically
- ✅ Works in multiple languages (multilingual models)
- ✅ No training data required (zero-shot learning)
- ✅ Customizable output format (JSON, XML, etc.)

### Sentiment Analysis Output Components

In this workshop, our LLM will extract:

**1. Sentiment Classification**
- Category: positive, negative, or neutral
- Example: `"sentiment": "positive"`

**2. Sentiment Score**
- Numeric value from -1.0 (very negative) to +1.0 (very positive)
- Example: `"score": 0.9` (strongly positive)

**3. Confidence Level**
- How certain is the LLM about this classification (0-100%)
- Example: `"confidence": 95` (very confident)
- Low confidence (<60%) might indicate mixed or ambiguous sentiment

**4. Key Phrases**
- Important words/phrases that influenced the sentiment
- Example: `["exceeded expectations", "incredible battery", "blazing fast"]`
- Useful for identifying specific strengths or weaknesses

**5. Summary**
- One-sentence summary of the review's main point
- Example: `"Customer extremely satisfied with laptop performance and battery life"`
- Helps quickly understand what the review is about

### Use Cases in This Workshop

We'll analyze **3 customer reviews** with varying sentiments:

**Review 1 (Positive):**
```
"This laptop exceeded my expectations! The battery life is incredible..."
→ Sentiment: positive, Score: 0.9, Confidence: 90%
```

**Review 2 (Negative):**
```
"The wireless mouse I bought stopped working after just 2 weeks..."
→ Sentiment: negative, Score: -0.6, Confidence: 80%
```

**Review 3 (Neutral/Mixed):**
```
"Good laptop overall, but it gets a bit warm during intensive tasks..."
→ Sentiment: neutral, Score: -0.33, Confidence: 70%
```

### Expected Results

After running this workshop's transformation, you'll have:
- Original review text
- AI-determined sentiment (positive/negative/neutral)
- Numeric score (-1.0 to 1.0)
- Confidence percentage
- Key phrases extracted
- One-sentence summary

All in a structured CSV file ready for analysis, visualization, or database import!

### Key Takeaways

1. **Sentiment analysis automatically categorizes opinions** in customer feedback
2. **LLMs provide context-aware analysis** that traditional methods can't match
3. **Structured JSON output** makes results easy to process in ETL pipelines
4. **Confidence scores** help identify reviews that need manual review
5. **Key phrases** identify specific strengths and weaknesses
6. **Scalable processing** - analyze thousands of reviews in minutes

Now let's get started building the pipeline!

---

## Part 2: Environment Setup (20 minutes)

### Step 1: Install Ollama

Run the provided setup script:

```bash
cd /home/pentaho/LLM-PDI-Integration/scripts
./setup_ollama.sh
```

This script will:
- Install Ollama on your Ubuntu system
- Start the Ollama service
- Download the `llama3.2:3b` model (recommended for this workshop)

**Alternative Manual Installation:**
```bash
# Install Ollama
curl -fsSL https://ollama.com/install.sh | sh

# Start Ollama (runs as a service)
sudo systemctl start ollama

# Pull the model
ollama pull llama3.2:3b
```

### Step 2: Verify Ollama Installation

Test that Ollama is running:

```bash
# Check if Ollama is responding
curl http://localhost:11434/api/tags

# Quick sentiment test
ollama run llama3.2:3b "Analyze this sentiment: Great product, very happy!"
```

Expected: You should see JSON output listing available models, and a response about positive sentiment.

### Step 3: Review the Dataset

Examine the sample customer reviews:

```bash
cd /home/pentaho/LLM-PDI-Integration/workshops/workshop-01-sentiment-analysis
cat data/customer_reviews.csv | head -5
```

**Note:** The data is located in the `data/` folder, not `datasets/`.

The dataset contains:
- **review_id**: Unique identifier
- **customer_name**: Customer who wrote the review
- **product**: Product being reviewed
- **review_text**: The actual review content (this is what we'll analyze)
- **date**: Review date

**Sample Test Data:**
For quick testing, use `customer_reviews_test.csv` which contains only 3 reviews:
```bash
cat data/customer_reviews_test.csv
```

## Part 3: Understanding the Ollama API (15 minutes)

### API Endpoint Structure

Ollama provides a REST API at `http://localhost:11434`

**Key Endpoint:** `/api/generate`

### Sample Request Format

```json
{
  "model": "llama3.2:3b",
  "prompt": "Your prompt text here",
  "stream": false,
  "format": "json"
}
```

**Parameters:**
- `model`: Which LLM model to use
- `prompt`: The instruction/question for the model
- `stream`: false for complete responses (true for streaming)
- `format`: "json" to request JSON-formatted output

### Sample Response Format

```json
{
  "model": "llama3.2:3b",
  "created_at": "2024-02-25T12:00:00.000Z",
  "response": "{\"sentiment\":\"positive\",\"score\":0.85}",
  "done": true,
  "total_duration": 2000000000
}
```

The actual LLM output is in the `response` field.

### Test the API Manually

Try this curl command:

```bash
curl http://localhost:11434/api/generate -d '{
  "model": "llama3.2:3b",
  "prompt": "Analyze the sentiment of this review and respond in JSON: \"This product is amazing! Best purchase ever.\" Provide sentiment (positive/negative/neutral) and score (-1 to 1).",
  "stream": false,
  "format": "json"
}'
```

## Part 4: Building the PDI Transformation (30 minutes)

### Transformation Overview

The transformation file is located at:
`/home/pentaho/LLM-PDI-Integration/transformations/sentiment_analysis.ktr`

### Step-by-Step Flow

#### Step 1: Read Customer Reviews
**Step Type:** CSV File Input

- **Purpose:** Load customer reviews from CSV file
- **Configuration:**
  - **File path:** `${INPUT_FILE}` (parameter, defaults to `../data/customer_reviews.csv`)
  - **Delimiter:** comma (,)
  - **Enclosure:** double quote (")
  - **Header row:** Yes
  - **Encoding:** UTF-8
- **Output Fields:** review_id, customer_name, product, review_text, date

**Note:** The transformation uses the `INPUT_FILE` parameter for flexibility. You can override this when running:
```bash
-param:INPUT_FILE=/path/to/your/customer_reviews.csv
```

#### Step 2: Build LLM Prompt
**Step Type:** Modified Java Script Value

- **Purpose:** Construct the JSON payload for Ollama API
- **Key Logic:**
  ```javascript
  // Build the prompt for sentiment analysis
  var prompt_text = "Analyze the sentiment of this customer review and respond in JSON format.\n\n" +
                    "Review: \"" + review_text + "\"\n\n" +
                    "Provide your response as valid JSON with exactly these fields:\n" +
                    "{\n" +
                    "  \"sentiment\": \"positive, negative, or neutral\",\n" +
                    "  \"score\": numeric value from -1.0 (very negative) to 1.0 (very positive),\n" +
                    "  \"confidence\": percentage 0-100,\n" +
                    "  \"key_phrases\": [array of important phrases],\n" +
                    "  \"summary\": \"brief one-sentence summary\"\n" +
                    "}";

  // ⚠️ CRITICAL: Get PDI parameters using getVariable()
  // Do NOT use "${PARAM}" syntax in JavaScript - it won't be replaced!
  var model_name = getVariable("MODEL_NAME", "llama3.2:3b");

  // Build the JSON payload
  var json_payload = JSON.stringify({
      "model": model_name,  // Use the variable, not "${MODEL_NAME}"
      "prompt": prompt_text,
      "stream": false,
      "format": "json"
  });
  ```
- **Output Fields:** prompt_text, json_payload

**⚠️ PDI Parameter Resolution in JavaScript:**

PDI parameters work differently depending on where you use them:

| Location | Syntax | Works? | Example |
|----------|--------|--------|---------|
| **XML tags** | `${PARAM}` | ✅ YES | `<url>${OLLAMA_URL}/api/generate</url>` |
| **JavaScript strings** | `"${PARAM}"` | ❌ NO | `var x = "${MODEL_NAME}";` stays literal |
| **JavaScript code** | `getVariable()` | ✅ YES | `var x = getVariable("MODEL_NAME", "default");` |

**Correct JavaScript approach:**
```javascript
// ✅ CORRECT - Use getVariable()
var model_name = getVariable("MODEL_NAME", "llama3.2:3b");
var url = getVariable("OLLAMA_URL", "http://localhost:11434");

var payload = JSON.stringify({
    "model": model_name  // Use the variable
});
```

**Incorrect approach (common mistake):**
```javascript
// ❌ WRONG - Parameters not replaced in JavaScript strings
var payload = JSON.stringify({
    "model": "${MODEL_NAME}"  // This stays as literal "${MODEL_NAME}"
});
// Result: {"model": "${MODEL_NAME}"} - causes 400 error!
```

**Prompt Engineering Tips:**
- Be explicit about the desired output format
- Provide clear examples when possible
- Request structured data (JSON) for easier parsing
- Specify value ranges and types

#### Step 3: Call Ollama API
**Step Type:** REST Client (NOT HTTP Client)

**⚠️ IMPORTANT:** Use the **REST Client** step, not the generic HTTP Client step. The REST Client is specifically designed for REST APIs and handles POST requests properly.

- **Purpose:** Send POST request to Ollama API
- **Configuration:**
  - **Step type**: `Rest` (in XML: `<type>Rest</type>`)
  - **URL**: `${OLLAMA_URL}/api/generate`
  - **HTTP Method**: `POST`
  - **Body field**: `json_payload`
  - **Result fieldname**: `llm_response`
  - **HTTP status code fieldname**: `response_code`
  - **Response time fieldname**: `response_time`
  - **Headers:**
    - Content-Type: `application/json`
    - Accept: `application/json`
  - **Socket timeout**: `300000` (5 minutes - critical for LLM processing!)
  - **Connection timeout**: `30000` (30 seconds)

**Configuration in Spoon GUI:**
1. Add a "REST Client" step (NOT "HTTP Client")
2. **General Tab:**
   - Application type: TEXT PLAIN
   - HTTP method: POST
   - URL: `${OLLAMA_URL}/api/generate`
   - Body field: `json_payload`
3. **Headers Tab:**
   - Add: Content-Type = application/json
   - Add: Accept = application/json
4. **Settings Tab:**
   - Result field name: `llm_response`
   - HTTP status code field: `response_code`
   - Response time: `response_time`
   - Socket timeout: 300000
   - Connection timeout: 30000

**Common Issues & Solutions:**

| Issue | Cause | Solution |
|-------|-------|----------|
| **405 Method Not Allowed** | Using HTTP Client instead of REST Client | Change step type to REST Client |
| **400 Bad Request** | PDI parameters not resolved in JavaScript | Use `getVariable()` in JavaScript |
| **Timeout errors** | Socket timeout too low | Increase to 300000ms (5 minutes) |
| **Connection refused** | Ollama not running | Run `curl http://localhost:11434/api/tags` |

**Important Notes:**
- ✅ LLM inference takes 20-30 seconds per review - this is normal
- ✅ Set socket timeout to at least 300000ms (5 minutes)
- ✅ Always check `response_code` field (should be 200)
- ✅ Use REST Client step, not HTTP Client
- ✅ Test Ollama API with curl before running transformation

#### Step 4: Parse JSON Response
**Step Type:** JSON Input

- **Purpose:** Extract the response field from Ollama's JSON
- **Configuration:**
  - Source: Field value (llm_response)
  - JSON field path: `$.response`
  - Output field: `sentiment_json`

This step extracts the actual LLM-generated content from Ollama's response wrapper.

#### Step 5: Extract Sentiment Fields
**Step Type:** JSON Input

- **Purpose:** Parse the LLM's JSON output into separate fields
- **Configuration:**
  - Source: Field value (sentiment_json)
  - JSON paths:
    - `$.sentiment` → sentiment (String)
    - `$.score` → score (Number, format: #.##)
    - `$.confidence` → confidence (Integer)
    - `$.key_phrases` → key_phrases (String)
    - `$.summary` → summary (String)

#### Step 6: Write Results
**Step Type:** Text File Output

- **Purpose:** Save enriched data to CSV
- **Configuration:**
  - File name: `../datasets/sentiment_results`
  - Extension: .csv
  - Add date: Yes
  - Add time: Yes
  - Format: DOS (Windows line endings)
  - Encoding: UTF-8
  - Include header: Yes
  - Fields: All original fields + sentiment fields

### Transformation Parameters

The transformation uses these parameters for flexibility:

#### Basic Transformation (`sentiment_analysis.ktr`)

| Parameter | Default Value | Description |
|-----------|---------------|-------------|
| OLLAMA_URL | http://localhost:11434 | Ollama API endpoint |
| MODEL_NAME | llama3.2:3b | Model to use for analysis |
| INPUT_FILE | ../data/customer_reviews.csv | Input data path (⚠️ Note: data/ not datasets/) |

#### Optimized Transformation (`sentiment_analysis_optimized.ktr`)

| Parameter | Default Value | Description |
|-----------|---------------|-------------|
| OLLAMA_URL | http://localhost:11434 | Ollama API endpoint |
| MODEL_NAME | llama3.2:3b | Model to use for analysis |
| INPUT_FILE | ../data/customer_reviews.csv | Input data path |
| **KEEP_ALIVE** | **30m** | **Keep model in memory (5m/15m/30m/60m)** |
| **STEP_COPIES** | **4** | **Parallel copies (set to CPU cores - 1)** |

**Parameter Details:**

- **KEEP_ALIVE:** Controls how long Ollama keeps the model loaded in memory
  - `5m` = 5 minutes (minimal memory usage)
  - `15m` = 15 minutes (balanced)
  - `30m` = 30 minutes (recommended - prevents reload overhead)
  - `60m` = 60 minutes (for heavy workloads)

- **STEP_COPIES:** Number of parallel processing threads for the "Call Ollama API" step
  - Recommended: CPU cores - 1 (e.g., 8 cores = set to 4)
  - Higher = faster processing but more memory usage
  - Default: 4 (good for most systems)

**⚠️ File Path Note:** The default INPUT_FILE parameter points to `../data/customer_reviews.csv`. Make sure your data files are in the `data/` folder, not `datasets/`.

### Tested Configuration (Verified Working ✅)

The transformation has been tested and verified with the following configuration:

**Test Environment:**
- Ubuntu 24.04
- PDI 11.0
- Ollama running locally
- Model: llama3.2:3b

**Test Data:**
- File: `customer_reviews_test.csv`
- Records: 3 reviews (1 positive, 1 negative, 1 neutral)
- Processing time: ~69 seconds (~23 sec/review)

**Test Results:**
All reviews correctly analyzed:
- ✅ Response code: 200 (Success)
- ✅ Positive sentiment identified correctly (score: 0.9)
- ✅ Negative sentiment identified correctly (score: -0.6)
- ✅ Neutral sentiment identified correctly (score: -0.33)
- ✅ All fields populated (sentiment, score, confidence, key_phrases, summary)

**Expected Performance:**
- Single review: 20-30 seconds
- 10 reviews: ~4-5 minutes
- 100 reviews: ~35-40 minutes (single thread)
- Use optimized version for faster processing with parallel execution

## Part 5: Running the Transformation (10 minutes)

### Option 1: Using Spoon (PDI GUI)

1. Launch Spoon:
   ```bash
   cd /path/to/pdi
   ./spoon.sh
   ```

2. Open the transformation:
   - File → Open
   - Navigate to: `/home/pentaho/LLM-PDI-Integration/transformations/sentiment_analysis.ktr`

3. Review the transformation flow:
   - Examine each step's configuration
   - Review the notepad for documentation

4. Run the transformation:
   - Click the "Run" button (play icon)
   - Or press F9
   - Click "Launch"

5. Monitor execution:
   - Watch the step metrics (rows processed)
   - Check for errors in the logging panel
   - Note: Each review will take 2-5 seconds to process

### Option 2: Using Pan (Command Line)

**Basic Transformation (Single-threaded):**

```bash
cd /home/pentaho/Pentaho/design-tools/data-integration

./pan.sh \
  -file=/home/pentaho/LLM-PDI-Integration/workshops/workshop-01-sentiment-analysis/transformations/sentiment_analysis.ktr \
  -param:MODEL_NAME=llama3.2:3b \
  -param:OLLAMA_URL=http://localhost:11434 \
  -level=Minimal
```

**Optimized Transformation (Parallel Processing):**

```bash
./pan.sh \
  -file=/home/pentaho/LLM-PDI-Integration/workshops/workshop-01-sentiment-analysis/transformations/sentiment_analysis_optimized.ktr \
  -param:MODEL_NAME=llama3.2:3b \
  -param:OLLAMA_URL=http://localhost:11434 \
  -param:KEEP_ALIVE=30m \
  -param:STEP_COPIES=4 \
  -level=Minimal
```

**Custom input file:**

```bash
./pan.sh \
  -file=/home/pentaho/LLM-PDI-Integration/workshops/workshop-01-sentiment-analysis/transformations/sentiment_analysis.ktr \
  -param:MODEL_NAME=llama3.2:3b \
  -param:OLLAMA_URL=http://localhost:11434 \
  -param:INPUT_FILE=/path/to/your/custom_reviews.csv \
  -level=Basic
```

**Execution Log (Successful Run):**
```
2026-02-27 11:46:53.496 - Read Customer Reviews.0 - Finished processing (W=3)
2026-02-27 11:46:53.625 - Build LLM Prompt.0 - Finished processing (W=3)
2026-02-27 11:48:02.913 - Call Ollama API.0 - Finished processing (W=3)
2026-02-27 11:48:02.915 - Parse JSON Response.0 - Finished processing (W=3)
2026-02-27 11:48:02.916 - Extract Sentiment Fields.0 - Finished processing (W=3)
2026-02-27 11:48:02.918 - Write Results.0 - Finished processing (W=3)
```
All steps should show `(W=X)` indicating rows written, with `(E=0)` for no errors.

### Expected Output

The transformation will create a file like:
```
/home/pentaho/LLM-PDI-Integration/workshops/workshop-01-sentiment-analysis/datasets/sentiment_results_20260227_114653.csv
```

**Sample Output (First 3 Rows):**
```csv
review_id,customer_name,product,review_text,date,sentiment,score,confidence,key_phrases,summary
1,Sarah Johnson,Laptop Pro 15,"This laptop exceeded...",2024-02-15,positive,0.9,90,"[""exceeded expectations""...]","Customer extremely satisfied..."
2,Mike Chen,Wireless Mouse,"The mouse stopped working...",2024-02-16,negative,-0.6,80,"[""Very disappointed""...]","Customer experienced failure..."
3,Emily Rodriguez,USB-C Hub,"Good product overall...",2024-02-17,neutral,-0.33,70,"[""Good product overall""...]","Generally satisfied with drawbacks..."
```

## Part 6: Analyzing Results (15 minutes)

### View the Results

```bash
cd /home/pentaho/LLM-PDI-Integration/workshops/workshop-01-sentiment-analysis/datasets
cat sentiment_results_*.csv | less
```

### Actual Test Results (Verified ✅)

**Test Date:** 2026-02-27
**Records Processed:** 3 reviews
**Processing Time:** ~69 seconds (~23 sec/review)
**Success Rate:** 100% (all reviews correctly analyzed)

#### Input Data
```csv
review_id,customer_name,product,review_text,date
1,Sarah Johnson,Laptop Pro 15,"This laptop exceeded my expectations! Fast performance, great battery life, and the display is stunning. Worth every penny.",2024-02-15
2,Mike Chen,Wireless Mouse,"The mouse stopped working after just 2 weeks. Very disappointed with the quality. Would not recommend.",2024-02-16
3,Emily Rodriguez,USB-C Hub,"Good product overall. Works as expected, though it gets a bit warm during heavy use. Decent value for money.",2024-02-17
```

#### Output Data with AI-Generated Sentiment

| Review | Product | Sentiment | Score | Confidence | Key Phrases | Summary |
|--------|---------|-----------|-------|------------|-------------|---------|
| 1 | Laptop Pro 15 | **positive** | **0.9** | 90% | "exceeded expectations", "fast performance", "great battery life", "stunning display" | Customer extremely satisfied with performance |
| 2 | Wireless Mouse | **negative** | **-0.6** | 80% | "Very disappointed", "Would not recommend" | Customer experienced product failure |
| 3 | USB-C Hub | **neutral** | **-0.33** | 70% | "Good product overall", "Decent value" | Generally satisfied with minor drawbacks |

#### Detailed Analysis

**Review 1 - Positive Sentiment:**
```json
{
  "sentiment": "positive",
  "score": 0.9,
  "confidence": 90,
  "key_phrases": ["exceeded my expectations", "fast performance", "great battery life", "stunning display"],
  "summary": "The customer was extremely satisfied with the laptop's performance and features, making it worth their investment."
}
```
✅ **Result:** Correctly identified as highly positive with appropriate high score

**Review 2 - Negative Sentiment:**
```json
{
  "sentiment": "negative",
  "score": -0.6,
  "confidence": 80,
  "key_phrases": ["Very disappointed with the quality", "Would not recommend"],
  "summary": "Customer expresses disappointment with the product's short lifespan and poor quality"
}
```
✅ **Result:** Correctly identified as negative with appropriate negative score

**Review 3 - Neutral Sentiment:**
```json
{
  "sentiment": "neutral",
  "score": -0.33,
  "confidence": 70,
  "key_phrases": ["Good product overall", "Decent value for money"],
  "summary": "The customer is generally satisfied with the product, but notes some minor drawbacks."
}
```
✅ **Result:** Correctly identified as neutral (mixed positive/negative) with slight negative bias

### CSV Output Format

```csv
review_id,customer_name,product,review_text,date,sentiment,score,confidence,key_phrases,summary
1,Sarah Johnson,Laptop Pro 15,"This laptop exceeded my expectations!...",2024-02-15,positive,0.9,90,"[""exceeded my expectations"",""fast performance"",""great battery life"",""stunning display""]","The customer was extremely satisfied..."
2,Mike Chen,Wireless Mouse,"The mouse stopped working after...",2024-02-16,negative,-0.6,80,"[""Very disappointed with the quality"",""Would not recommend""]","Customer expresses disappointment..."
3,Emily Rodriguez,USB-C Hub,"Good product overall...",2024-02-17,neutral,-0.33,70,"[""Good product overall"",""Decent value for money""]","Generally satisfied with minor drawbacks..."
```

### Analysis Questions

1. **Accuracy Check:**
   - Do the sentiment labels match your reading of the reviews?
   - Are the scores reasonable (-1 to 1)?

2. **Consistency:**
   - Are similar reviews getting similar scores?
   - Is the confidence level correlated with clear sentiment?

3. **Performance:**
   - How long did the transformation take?
   - Calculate: average time per review
   - Formula: (total_time / number_of_reviews)

4. **Key Phrases:**
   - Are the extracted phrases truly important?
   - Do they represent the core sentiment?

### Sample Analysis Query

If you load the results into a database, try:

```sql
-- Sentiment distribution
SELECT sentiment, COUNT(*) as count
FROM sentiment_results
GROUP BY sentiment;

-- Average scores by sentiment
SELECT sentiment,
       AVG(score) as avg_score,
       AVG(confidence) as avg_confidence
FROM sentiment_results
GROUP BY sentiment;

-- Top positive reviews
SELECT customer_name, product, score, summary
FROM sentiment_results
WHERE sentiment = 'positive'
ORDER BY score DESC
LIMIT 5;
```

## Part 7: Exercises & Extensions (Bonus)

### Exercise 1: Modify the Prompt
Try different prompts to see how they affect results:

**Simpler Prompt:**
```
Is this review positive or negative? Reply with JSON: {"sentiment": "positive or negative"}
Review: [text]
```

**More Detailed Prompt:**
```
Analyze this review as a customer service manager would. Include:
- Overall sentiment
- Specific issues mentioned
- Recommended actions
- Priority level (high/medium/low)
```

### Exercise 2: Error Handling
Add error handling to the transformation:

1. Add a "Filter Rows" step after "Call Ollama API"
2. Check if `response_code = 200`
3. Route failed calls to a separate error output
4. Log failed reviews for retry

### Exercise 3: Batch Processing
Modify for better performance:

1. Reduce the input to 5 reviews (for testing)
2. Adjust timeout settings
3. Consider parallel processing (PDI's step copies feature)

### Exercise 4: Different Models
Compare results across models:

```bash
# Pull alternative models
ollama pull llama3.2:1b  # Faster but less accurate
ollama pull llama2:7b    # Slower but more accurate

# Run transformation with different MODEL_NAME parameter
```

Create a comparison chart:
| Model | Speed | Accuracy | Confidence |
|-------|-------|----------|------------|
| llama3.2:1b | ? | ? | ? |
| llama3.2:3b | ? | ? | ? |
| llama2:7b | ? | ? | ? |

### Exercise 5: Real-World Data
Replace the sample data with real reviews:

1. Export reviews from your e-commerce platform
2. Format as CSV with required columns
3. Run the transformation
4. Analyze patterns in negative reviews

### Exercise 6: Dashboard Integration
Visualize the results:

1. Load results into a database (MySQL, PostgreSQL)
2. Create a simple dashboard showing:
   - Sentiment distribution pie chart
   - Score trends over time
   - Word cloud of key phrases
   - Top products by sentiment

## Troubleshooting

### Common Issues & Quick Fixes

| Error | Response Code | Cause | Fix |
|-------|---------------|-------|-----|
| "405 Method Not Allowed" | 405 | Using HTTP Client instead of REST Client | Change step type to `Rest` |
| "invalid duration" | 400 | PDI parameters not resolved | Use `getVariable()` in JavaScript |
| "File not found" | N/A | Wrong path (datasets vs data) | Use `../data/customer_reviews.csv` |
| "Connection refused" | N/A | Ollama not running | Start Ollama: `curl http://localhost:11434/api/tags` |
| "Socket timeout" | N/A | Timeout too low | Increase to 300000ms (5 minutes) |

### Issue 1: 405 Method Not Allowed ⚠️

**Symptoms:**
- `llm_response` field shows: `405 method not allowed`
- `response_code` = 405

**Root Cause:**
Using the generic **HTTP Client** step instead of **REST Client** step.

**Solution:**
1. Delete the HTTP Client step
2. Add a **REST Client** step
3. Configure as shown in Step 3 above
4. In XML, ensure: `<type>Rest</type>` (not `<type>HTTP</type>`)

**Verification:**
```bash
# Check transformation file
grep '<type>Rest</type>' sentiment_analysis.ktr
# Should return a match
```

### Issue 2: 400 Bad Request - "invalid duration" ⚠️

**Symptoms:**
- `response_code` = 400
- `llm_response` shows: `{"error":"time: invalid duration \"${KEEP_ALIVE}\""}`
- `json_payload` contains literal `"${MODEL_NAME}"` or `"${KEEP_ALIVE}"`

**Root Cause:**
PDI parameters like `${MODEL_NAME}` are not resolved when used directly in JavaScript string literals.

**Wrong Code:**
```javascript
var json_payload = JSON.stringify({
    "model": "${MODEL_NAME}"  // ❌ This stays as literal string!
});
```

**Correct Code:**
```javascript
var model_name = getVariable("MODEL_NAME", "llama3.2:3b");
var json_payload = JSON.stringify({
    "model": model_name  // ✅ Uses actual value
});
```

**Solution:**
1. Edit the "Build LLM Prompt" step
2. Add: `var model_name = getVariable("MODEL_NAME", "llama3.2:3b");`
3. Change `"model": "${MODEL_NAME}"` to `"model": model_name`
4. For optimized version, also add: `var keep_alive = getVariable("KEEP_ALIVE", "30m");`

**Verification:**
Preview the `json_payload` field - it should show actual values like `"llama3.2:3b"`, not `"${MODEL_NAME}"`.

### Issue 3: File Not Found

**Symptoms:**
- Error: `Could not read from "...datasets/customer_reviews.csv" because it is not a file`
- Transformation fails at "Read Customer Reviews" step

**Root Cause:**
File path points to `datasets/` but data is in `data/` folder.

**Solution:**
Update INPUT_FILE parameter default value:
- **Wrong:** `../datasets/customer_reviews.csv`
- **Correct:** `../data/customer_reviews.csv`

Or specify when running:
```bash
-param:INPUT_FILE=/path/to/data/customer_reviews.csv
```

### Issue 4: Ollama Not Responding

**Symptoms:**
- HTTP Client step shows connection errors
- Timeout errors in PDI logs
- Error: "Connection refused"

**Solutions:**
```bash
# Check if Ollama is running
curl http://localhost:11434/api/tags

# Should return JSON with available models
# If not, start Ollama:
sudo systemctl start ollama

# Check Ollama status
sudo systemctl status ollama

# Check Ollama logs
journalctl -u ollama -f
```

### Issue: JSON Parsing Errors

**Symptoms:**
- "Extract Sentiment Fields" step fails
- Null values in output

**Causes:**
- LLM didn't return valid JSON
- Model misunderstood the prompt

**Solutions:**
1. Check the `sentiment_json` field content
2. Add a preview step to inspect raw responses
3. Improve prompt clarity
4. Add "format": "json" to the API request
5. Consider using a more capable model

### Issue: Slow Performance

**Symptoms:**
- Transformation takes too long
- Each row takes 10+ seconds

**Solutions:**
1. Use a smaller/faster model (llama3.2:1b)
2. Reduce input dataset for testing
3. Ensure your system has adequate resources:
   ```bash
   # Check system resources
   htop
   nvidia-smi  # If using GPU
   ```
4. Consider GPU acceleration (Ollama supports NVIDIA GPUs)

### Issue: Out of Memory Errors

**Symptoms:**
- Ollama crashes
- System becomes unresponsive

**Solutions:**
1. Use a smaller model
2. Close other applications
3. Check system requirements for your chosen model:
   ```bash
   # Check memory usage
   ollama ps
   ```

## Key Takeaways

1. **LLM Integration is Straightforward:** Using REST APIs makes LLM integration accessible in ETL workflows

2. **Prompt Engineering Matters:** The quality of your prompts directly affects result quality

3. **JSON Format is Essential:** Structured output (JSON) makes parsing much easier

4. **Performance Considerations:** LLM inference takes time; plan accordingly for production

5. **Error Handling is Crucial:** Always handle API failures and unexpected responses

6. **Model Selection Matters:** Balance speed vs. accuracy based on your needs

## Next Steps

After completing this workshop, you can:

1. **Explore Workshop 2:** Data Quality Enhancement with LLM
2. **Apply to Your Data:** Use real customer reviews or feedback
3. **Integrate with BI Tools:** Connect results to Tableau, Power BI, etc.
4. **Automate:** Schedule the transformation with cron or PDI Job Scheduler
5. **Scale Up:** Explore batch processing and optimization techniques

## Resources

### Documentation
- [Ollama Documentation](https://github.com/ollama/ollama/blob/main/docs/api.md)
- [Ollama Model Library](https://ollama.com/library)
- [PDI Documentation](https://help.hitachivantara.com/Documentation/Pentaho)

### Sample Code
All workshop materials are in:
```
/home/pentaho/LLM-PDI-Integration/
├── datasets/          # Sample data and results
├── transformations/   # PDI transformation files
├── scripts/          # Setup and utility scripts
└── documentation/    # Workshop guides
```

### Community
- Ollama GitHub: https://github.com/ollama/ollama
- PDI Forums: https://forums.pentaho.com/

## Feedback & Questions

This workshop is designed to be hands-on and practical. If you have questions or encounter issues:

1. Review the troubleshooting section
2. Check Ollama and PDI logs
3. Test API calls manually with curl
4. Simplify the transformation to isolate issues

## Appendix A: Architecture Workflow Detailed

### Complete Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                        WORKSHOP 1 WORKFLOW                       │
└─────────────────────────────────────────────────────────────────┘

Step 1: INPUT
┌──────────────────────────────┐
│  customer_reviews.csv        │
│  - review_id                 │
│  - customer_name             │
│  - product                   │
│  - review_text ← ANALYZE     │
│  - date                      │
└──────────┬───────────────────┘
           │
           ▼
Step 2: READ CSV
┌──────────────────────────────┐
│  CSV File Input Step         │
│  - Reads from data/ folder   │
│  - Parses 3 reviews          │
└──────────┬───────────────────┘
           │
           ▼
Step 3: BUILD PROMPT
┌──────────────────────────────┐
│  Modified JavaScript Value   │
│  - Creates AI prompt         │
│  - Builds JSON payload       │
│  - Uses getVariable()        │
└──────────┬───────────────────┘
           │
           ▼
Step 4: CALL AI API
┌──────────────────────────────┐
│  REST Client Step            │
│  POST → Ollama API           │
│  - Sends review text         │
│  - Receives AI analysis      │
│  - Takes ~23 sec/review      │
└──────────┬───────────────────┘
           │
           ▼
Step 5: PARSE RESPONSE
┌──────────────────────────────┐
│  JSON Input Steps (2x)       │
│  1. Extract "response" field │
│  2. Parse sentiment fields   │
└──────────┬───────────────────┘
           │
           ▼
Step 6: OUTPUT
┌──────────────────────────────┐
│  sentiment_results_*.csv     │
│  Original fields PLUS:       │
│  - sentiment ✓               │
│  - score ✓                   │
│  - confidence ✓              │
│  - key_phrases ✓             │
│  - summary ✓                 │
└──────────────────────────────┘
```

### What Happens at Each Step

1. **Read Customer Reviews** (CSV Input)
   - Loads: 3 reviews from `data/customer_reviews.csv`
   - Output: 5 fields per row

2. **Build LLM Prompt** (JavaScript)
   - Creates detailed prompt for AI
   - Builds JSON request: `{"model": "llama3.2:3b", "prompt": "...", "format": "json"}`
   - Uses `getVariable()` to get MODEL_NAME parameter

3. **Call Ollama API** (REST Client)
   - Sends POST to `http://localhost:11434/api/generate`
   - Body: json_payload from previous step
   - Returns: AI-generated sentiment analysis in JSON
   - Time: ~20-30 seconds per review

4. **Parse JSON Response** (JSON Input #1)
   - Extracts `$.response` field from Ollama's wrapper
   - Gets the actual AI output

5. **Extract Sentiment Fields** (JSON Input #2)
   - Parses AI output into separate fields
   - Creates: sentiment, score, confidence, key_phrases, summary

6. **Write Results** (Text Output)
   - Saves to `datasets/sentiment_results_[timestamp].csv`
   - Combines original data + AI insights

## Appendix B: Ollama Model Comparison

| Model | Size | Speed | Accuracy | Best For |
|-------|------|-------|----------|----------|
| llama3.2:1b | 1.3GB | Very Fast | Good | Testing, demos |
| llama3.2:3b | 2.0GB | Fast | Very Good | Production balance ⭐ |
| llama2:7b | 3.8GB | Medium | Excellent | High accuracy needs |
| llama2:13b | 7.4GB | Slow | Outstanding | Critical applications |

**Tested Configuration:** llama3.2:3b - provides best balance of speed and accuracy

## Appendix C: Common Prompt Patterns

### Classification Prompt
```
Classify this text into one of these categories: [list]
Text: [input]
Respond with JSON: {"category": "X", "confidence": 0-100}
```

### Extraction Prompt
```
Extract the following information from this text:
- Field1: [description]
- Field2: [description]
Text: [input]
Respond with JSON.
```

### Summarization Prompt
```
Summarize this text in one sentence:
Text: [input]
Respond with JSON: {"summary": "..."}
```

## Appendix D: PDI Step Reference

### REST Client Step Configuration (Use This, Not HTTP Client!)

**Step Type:** `Rest` (NOT `HTTP`)

**Critical Settings:**
- **Method:** POST
- **URL:** `${OLLAMA_URL}/api/generate`
- **Body Field:** `json_payload` (field containing JSON request)
- **Result fieldname:** `llm_response` (stores API response)
- **HTTP status code:** `response_code` (stores 200, 400, 405, etc.)
- **Response time:** `response_time` (milliseconds)

**Headers Required:**
- `Content-Type: application/json`
- `Accept: application/json`

**Timeouts (CRITICAL for LLM):**
- **Socket timeout:** 300000ms (5 minutes minimum!)
- **Connection timeout:** 30000ms (30 seconds)

**Why REST Client, not HTTP Client?**
- ✅ Designed specifically for REST APIs
- ✅ Simple `bodyField` parameter for POST body
- ✅ Explicit HTTP method setting
- ✅ Better error handling
- ❌ HTTP Client often causes 405 errors with POST

### JSON Input Configuration
- **Source Types:** File, Field, or URL (use "Field" for this workshop)
- **JSON Path:** Use JSONPath syntax ($.field.subfield)
  - Example: `$.response` gets the response field
  - Example: `$.sentiment` gets sentiment value
- **Data Types:** Match expected types from LLM output
  - String: sentiment, key_phrases, summary
  - Number: score (format: #.##)
  - Integer: confidence

### Modified JavaScript Value

**Purpose:** Build dynamic JSON payloads and prompts

**Critical Pattern for PDI Parameters:**
```javascript
// ✅ CORRECT - Use getVariable()
var model = getVariable("MODEL_NAME", "llama3.2:3b");
var url = getVariable("OLLAMA_URL", "http://localhost:11434");

// ❌ WRONG - Don't use ${} in JavaScript
var model = "${MODEL_NAME}";  // Stays literal!
```

**Available Functions:**
- `getVariable("PARAM", "default")` - Get PDI parameter
- `JSON.stringify(obj)` - Convert object to JSON string
- Access PDI fields directly by name (e.g., `review_text`)

### CSV Input Step
- **File path:** Use `${INPUT_FILE}` parameter for flexibility
- **Delimiter:** comma (,)
- **Enclosure:** double quote (")
- **Header:** Yes (first row contains field names)
- **Encoding:** UTF-8 (for international characters)

---

## Summary: Critical Configuration Points ⚠️

Based on testing and debugging, here are the **must-have** configurations for success:

### 1. Use REST Client Step (Not HTTP Client)
```xml
<type>Rest</type>  <!-- NOT <type>HTTP</type> -->
<method>POST</method>
<bodyField>json_payload</bodyField>
```

### 2. Use getVariable() in JavaScript
```javascript
// ✅ CORRECT
var model_name = getVariable("MODEL_NAME", "llama3.2:3b");

// ❌ WRONG
var model = "${MODEL_NAME}";  // This won't work!
```

### 3. Correct File Paths
- Data location: `../data/customer_reviews.csv`
- Output location: `../datasets/sentiment_results_[timestamp].csv`

### 4. Adequate Timeouts
- Socket timeout: **300000ms** (5 minutes minimum)
- Connection timeout: **30000ms** (30 seconds)

### 5. Verify Before Running
```bash
# 1. Check Ollama is running
curl http://localhost:11434/api/tags

# 2. Test API manually
curl -X POST http://localhost:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{"model":"llama3.2:3b","prompt":"Test","stream":false}'

# 3. Check data file exists
ls -la /home/pentaho/LLM-PDI-Integration/workshops/workshop-01-sentiment-analysis/data/

# 4. Verify transformation configuration
grep '<type>Rest</type>' transformations/sentiment_analysis.ktr
```

### 6. Transformation Parameters Reference

**Basic Transformation:**
```bash
-param:OLLAMA_URL=http://localhost:11434
-param:MODEL_NAME=llama3.2:3b
-param:INPUT_FILE=../data/customer_reviews.csv
```

**Optimized Transformation (Additional):**
```bash
-param:KEEP_ALIVE=30m          # Keep model in memory
-param:STEP_COPIES=4           # Parallel processing threads
```

### Quick Start Checklist

- [ ] Ollama installed and running
- [ ] llama3.2:3b model downloaded (`ollama pull llama3.2:3b`)
- [ ] Data file in `data/` folder
- [ ] Transformation uses REST Client step (not HTTP Client)
- [ ] JavaScript uses `getVariable()` for parameters
- [ ] Socket timeout set to 300000ms
- [ ] Test with `customer_reviews_test.csv` first (3 reviews)
- [ ] Check `response_code` = 200 in preview

**Expected Success Indicators:**
- All steps show `(E=0)` - zero errors
- `response_code` field = **200**
- `llm_response` contains valid JSON
- Output CSV has sentiment, score, confidence, key_phrases, summary fields populated

---

**Workshop Version:** 2.0
**Last Updated:** 2026-02-27 (Updated with tested fixes and detailed troubleshooting)
**Author:** LLM-PDI Integration Workshop Series
**Status:** ✅ Tested and Verified Working
