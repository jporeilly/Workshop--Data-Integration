# Workshop 5: Text Summarization with LLMs

## Overview

This workshop demonstrates how to use Large Language Models (LLMs) with Pentaho Data Integration (PDI) to automatically summarize long documents into concise, actionable insights. Text summarization is a critical capability for processing large volumes of documentation, extracting key information, and enabling faster decision-making.

**Workshop Duration:** 60-90 minutes

**Difficulty Level:** Intermediate

**Prerequisites:**
- Completed Workshop 1, 2, 3, or 4 (familiarity with LLM integration in PDI)
- Basic understanding of PDI transformations
- Ollama installed with llama3.2:3b model
- Familiarity with JSON format

## What You'll Learn

1. Understanding different summarization approaches and use cases
2. Building effective summarization prompts for LLMs
3. Processing diverse document types (reports, emails, contracts, etc.)
4. Extracting structured summaries with bullet points, key takeaways, and action items
5. Optimizing summarization performance with parallel processing
6. Handling long documents efficiently

## Architecture Overview

```
┌────────────────────────┐
│  Read Documents        │  Read long documents from
│  (CSV Input)           │  various sources
└──────────┬─────────────┘
           │
           ▼
┌────────────────────────┐
│  Build Summarization   │  Create summarization prompt
│  Prompt (JavaScript)   │  with output structure
└──────────┬─────────────┘
           │
           ▼
┌────────────────────────┐
│  Build JSON Request    │  Construct Ollama API request
│  (JavaScript)          │  with summarization parameters
└──────────┬─────────────┘
           │
           ▼
┌────────────────────────┐
│  Call Ollama API       │  Send request to LLM for
│  (REST Client - 4x)    │  summarization
└──────────┬─────────────┘  **PARALLEL: 4 copies**
           │
           ▼
┌────────────────────────┐
│  Parse Summary         │  Extract summary, bullets,
│  Response (JavaScript) │  takeaways, action items
└──────────┬─────────────┘
           │
           ▼
┌────────────────────────┐
│  Write Summaries CSV   │  Output documents with
│  (CSV Output)          │  structured summaries
└────────────────────────┘
```

### Workflow Explanation

1. **Read Documents** - Loads long documents from CSV containing document_id, document_type, title, and full_text (typically 500-3000+ words)
2. **Build Summarization Prompt** - JavaScript step constructs a prompt requesting structured summarization with specific output format: summary (2-3 sentences), bullet_points (key points array), key_takeaways (main insights array), and action_items (actionable tasks array)
3. **Build JSON Request** - Prepares Ollama API request with model (`llama3.2:3b`), prompt, and parameters (temperature: 0.2 for balanced creativity, num_predict: 800 for comprehensive summaries, keep_alive in optimized version)
4. **Call Ollama API (Parallel)** - REST Client sends POST request to `http://localhost:11434/api/generate` using **4 parallel copies** for 3-4x performance improvement. Distributes documents across concurrent streams
5. **Parse Summary Response** - JavaScript extracts structured fields from LLM JSON response: summary string, bullet_points array, key_takeaways array, action_items array (or empty if no actions needed)
6. **Write Summaries CSV** - Outputs final dataset with original document metadata plus all generated summary components

## Part 1: Understanding Text Summarization (15 minutes)

### What is Text Summarization?

Text summarization is the process of condensing long documents into shorter versions while preserving the most important information and key points.

**Example Input (Meeting Notes, 450 words):**
```
Meeting held on February 15, 2025, in Conference Room A. Attendees: Sarah Johnson (CEO), Michael Chen (CTO), Jennifer Williams (VP Product), Robert Smith (VP Sales), and Linda Martinez (VP Marketing). The meeting focused on our Q1 2025 product strategy and roadmap priorities. Sarah opened the meeting by reviewing Q4 2024 performance, noting that revenue exceeded targets by 23% at $45.6 million, driven primarily by enterprise sales in North America. Michael presented the technical roadmap, highlighting three major initiatives...
```

**Example Output (Summarization):**
```json
{
  "summary": "Q1 2025 product strategy meeting covered Q4 performance review (revenue up 23% to $45.6M), technical roadmap with three major initiatives (AI platform, cloud integrations, mobile redesign), customer feedback analysis prioritizing reporting dashboards and collaboration tools, and sales pipeline projecting $38-42M for Q1.",
  "bullet_points": [
    "Q4 2024 revenue exceeded targets by 23% at $45.6 million",
    "Three major technical initiatives: AI analytics platform (March 15), cloud integrations (April), mobile redesign (May)",
    "Top customer requests: advanced reporting, real-time collaboration, API documentation",
    "Q1 sales pipeline: $38-42M projected with 15 major deals totaling $12M",
    "$2.5M marketing budget approved for Q1 campaigns"
  ],
  "key_takeaways": [
    "Strong Q4 performance driven by enterprise North American sales",
    "60% of engineering resources allocated to top customer feature requests",
    "Focus on thought leadership marketing strategy with conferences and webinars"
  ],
  "action_items": [
    "Michael: Finalize API documentation by March 1st",
    "Jennifer: Create customer advisory board by February 28th",
    "Robert: Implement new sales playbook by March 15th",
    "Linda: Launch website redesign by March 30th"
  ]
}
```

### Summarization Types

| Type | Description | Use Case | Length Reduction |
|------|-------------|----------|------------------|
| **Extractive** | Selects key sentences from original | Quick overview, news | 50-70% |
| **Abstractive** | Generates new text capturing meaning | Executive summary, reports | 70-90% |
| **Bullet Points** | Lists key points | Action tracking, presentations | 80-95% |
| **Key Takeaways** | Main insights and conclusions | Decision support | 85-95% |

**LLM-Based Summarization (This Workshop)** uses **abstractive** methods to generate concise, coherent summaries that:
- Rephrase content in clearer language
- Combine related concepts
- Identify and extract action items
- Prioritize most important information
- Adapt to different document types

### Why Use LLMs for Summarization?

Traditional summarization approaches (extractive algorithms, keyword extraction, TF-IDF) have limitations:

**Traditional Approach Challenges:**
- Cannot rephrase or generate new text
- Miss implicit meaning and context
- Struggle with complex document structures
- Limited to sentence selection
- No understanding of priorities or importance

**LLM-Based Summarization Advantages:**
- True abstractive summarization (rewrites in clearer language)
- Understands context and implicit information
- Adapts to different document types automatically
- Can extract different summary formats (bullets, paragraphs, action items)
- Handles technical, business, and conversational text equally well
- Multi-language capable
- Identifies action items and key decisions

### Real-World Use Cases

1. **Executive Reporting** - Summarize weekly status reports, meeting notes, project updates for leadership review
2. **Customer Service** - Condense customer complaint details and email threads for quick agent review
3. **Legal/Compliance** - Extract key terms, obligations, and deadlines from contracts and legal documents
4. **Research & Analysis** - Summarize academic papers, market research, technical documentation
5. **Email Management** - Create brief summaries of long email threads for quick scanning
6. **Content Curation** - Generate summaries for news articles, blog posts, industry reports
7. **Meeting Documentation** - Convert meeting transcripts into summaries with action items
8. **Technical Documentation** - Create executive-friendly summaries of technical specifications

## Part 2: Exploring the Sample Data (10 minutes)

The sample dataset contains 10 diverse long-form documents representing common business document types.

**File Location:** `workshops/workshop-05-text-summarization/data/documents_to_summarize.csv`

### Sample Data Overview

| Document Type | Word Count | Key Elements | Complexity |
|--------------|------------|--------------|------------|
| Meeting Notes | ~450 | Attendees, decisions, action items | Medium |
| Incident Report | ~650 | Timeline, root cause, remediation | High |
| Research Paper | ~800 | Abstract, methodology, results, conclusions | Very High |
| Customer Complaint | ~750 | Issues, sentiment, required actions | High |
| Project Proposal | ~900 | Business case, solution, financials, ROI | Very High |
| Press Release | ~700 | Announcement, quotes, background | Medium |
| Email Thread | ~600 | Multiple messages, blockers, requests | Medium |
| Annual Report | ~850 | Financials, achievements, outlook | High |
| Technical Docs | ~800 | API details, code examples, procedures | Very High |
| Legal Contract | ~900 | Terms, obligations, limitations | Very High |

### Document Characteristics

**Short Documents (300-500 words):**
- Faster to summarize
- Usually single-topic focused
- Clear summary possible in 1-2 sentences

**Medium Documents (500-800 words):**
- Multiple topics or sections
- Requires bullet point breakdown
- Summary needs 2-3 sentences

**Long Documents (800+ words):**
- Complex multi-section content
- Needs hierarchical summarization
- Benefit from key takeaways section

### View Sample Documents

```bash
head -n 3 /home/pentaho/LLM-PDI-Integration/workshops/workshop-05-text-summarization/data/documents_to_summarize.csv | cut -c1-200
```

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
cd /home/pentaho/LLM-PDI-Integration/workshops/workshop-05-text-summarization/transformations

# Open in Spoon (GUI)
/opt/pentaho/data-integration/spoon.sh text_summarization.ktr &

# OR run via command line
/opt/pentaho/data-integration/pan.sh -file=text_summarization.ktr
```

### Step 3: Understand the Transformation Steps

**1. Read Documents (CSV Input)**
- Reads `documents_to_summarize.csv`
- Fields: document_id, document_type, title, full_text
- 10 documents of various types and lengths

**2. Build Summarization Prompt (Modified JavaScript Value)**
```javascript
// Build summarization prompt
var llm_prompt = "Summarize the following document. Return ONLY valid JSON with these fields:\n\n" +
  "{\"summary\":\"2-3 sentence concise summary\",\"bullet_points\":[\"key point 1\",\"key point 2\",...]," +
  "\"key_takeaways\":[\"main insight 1\",\"main insight 2\",...]," +
  "\"action_items\":[\"action 1\",\"action 2\",...] or []}\n\n" +
  "Guidelines:\n" +
  "- Summary: Concise overview in 2-3 sentences capturing main purpose and key outcomes\n" +
  "- Bullet Points: 4-7 most important specific facts, decisions, or details from document\n" +
  "- Key Takeaways: 2-4 main insights, conclusions, or implications\n" +
  "- Action Items: Specific tasks, deadlines, or next steps if mentioned (empty array if none)\n\n" +
  "Document Type: " + document_type + "\n" +
  "Title: " + title + "\n\n" +
  "Full Text:\n" + full_text;
```

**3. Build JSON Request (Modified JavaScript Value)**
```javascript
// Build JSON request body for Ollama API
var model_name = getVariable("MODEL_NAME", "llama3.2:3b");

var requestObj = {
    "model": model_name,
    "prompt": llm_prompt,
    "stream": false,
    "format": "json",
    "options": {
        "temperature": 0.2,
        "num_predict": 800
    }
};

var request_body = JSON.stringify(requestObj);
```

**Key Parameters:**
- `temperature: 0.2` - Low-medium temperature for balanced creativity and consistency
- `num_predict: 800` - Allow up to 800 tokens for comprehensive summaries
- `format: "json"` - Request JSON output from LLM

**4. Call Ollama API (REST Client)**
- URL: `${OLLAMA_URL}/api/generate`
- Method: POST
- Body field: `request_body`
- Returns: `api_response`

**5. Parse Summary Response (Modified JavaScript Value)**
```javascript
// Parse Ollama response and extract summary components
var summary = "";
var bullet_points = "[]";
var key_takeaways = "[]";
var action_items = "[]";
var word_count_original = full_text.split(" ").length;
var word_count_summary = 0;

try {
    var response = JSON.parse(api_response);
    var fullResponse = response.response;

    // Extract JSON from response
    var jsonStart = fullResponse.indexOf("{");
    var jsonEnd = fullResponse.lastIndexOf("}") + 1;

    if (jsonStart >= 0 && jsonEnd > jsonStart) {
        var jsonStr = fullResponse.substring(jsonStart, jsonEnd);
        var data = JSON.parse(jsonStr);

        summary = data.summary || "";
        bullet_points = JSON.stringify(data.bullet_points || []);
        key_takeaways = JSON.stringify(data.key_takeaways || []);
        action_items = JSON.stringify(data.action_items || []);

        word_count_summary = summary.split(" ").length;
    }
} catch(e) {
    summary = "Error: Unable to parse summary";
}

var compression_ratio = Math.round((1 - word_count_summary / word_count_original) * 100);
```

**6. Write Summaries CSV (Text Output)**
- Output file: `data/summaries_YYYYMMDD_HHMMSS.csv`
- Fields: document_id, document_type, title, summary, bullet_points, key_takeaways, action_items, word_count_original, word_count_summary, compression_ratio

### Step 4: Review the Results

```bash
# Find the latest output file
ls -lt /home/pentaho/LLM-PDI-Integration/workshops/workshop-05-text-summarization/data/summaries_*.csv | head -1

# View summaries (first 3 documents)
cat <output_file> | head -4 | cut -d',' -f1,2,4 | column -s',' -t

# View bullet points for document #1
cat <output_file> | grep "^1," | cut -d',' -f5 | jq .

# View action items for meeting notes
cat <output_file> | grep "meeting_notes" | cut -d',' -f7 | jq .
```

**Expected Results:**
- Summary: 40-60 words (85-95% compression)
- Bullet Points: 4-7 items
- Key Takeaways: 2-4 items
- Action Items: 0-6 items (depending on document type)

**Performance:**
- Processing time: ~50-70 seconds for 10 documents (sequential)
- ~5-7 seconds per document
- Longer documents take more time due to increased processing

## Part 4: Running the Optimized Transformation (15 minutes)

The optimized version provides **3-4x performance improvement** through parallel processing and prompt optimization.

### Key Optimizations

1. **Parallel API Calls** - 4 concurrent REST Client copies
2. **Compact Prompt** - 50% shorter while maintaining quality
3. **Keep-Alive** - Model stays in memory between requests

### Step 1: Open the Optimized Transformation

```bash
cd /home/pentaho/LLM-PDI-Integration/workshops/workshop-05-text-summarization/transformations

# Run optimized version
/opt/pentaho/data-integration/pan.sh -file=text_summarization_optimized.ktr
```

### Step 2: Understand the Optimizations

**Optimized Prompt (50% shorter):**
```javascript
// Compact summarization prompt
var llm_prompt = "Summarize as JSON: {\"summary\":\"\",\"bullet_points\":[],\"key_takeaways\":[],\"action_items\":[]}\n" +
  "Summary: 2-3 sentences. Bullets: 4-7 key points. Takeaways: 2-4 insights. Actions: tasks/deadlines or [].\n" +
  "Type:" + document_type + " Title:" + title + "\n" + full_text;
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

| Version | Time (10 docs) | Docs/sec | Speedup |
|---------|----------------|----------|---------|
| Basic | 50-70 seconds | 0.14-0.20 | 1x |
| Optimized | 12-20 seconds | 0.50-0.83 | **3-4x** |

**Time Breakdown (Optimized):**
- Model loading: ~2-3 seconds (first request only, then cached)
- Per-document processing: ~1.0-1.5 seconds (parallelized)
- Total: 12-20 seconds for 10 documents

### Step 4: Verify Results Quality

The optimized version produces equivalent quality summaries despite shorter prompts.

```bash
# Compare compression ratios between basic and optimized
diff <(cat summaries_basic.csv | cut -d',' -f1,11 | sort) \
     <(cat summaries_optimized.csv | cut -d',' -f1,11 | sort)

# Should show similar compression ratios (within 5%)
```

## Part 5: Advanced Summarization Techniques (20 minutes)

### Exercise 1: Multi-Level Summarization

Create summaries at different detail levels.

**Prompt Modification:**
```javascript
var detail_level = "brief"; // or "moderate" or "comprehensive"

var length_guidance;
if (detail_level == "brief") {
    length_guidance = "Summary: 1 sentence. Bullets: 3 key points.";
} else if (detail_level == "moderate") {
    length_guidance = "Summary: 2-3 sentences. Bullets: 5-7 key points.";
} else {
    length_guidance = "Summary: 3-4 sentences. Bullets: 8-10 key points. Include context and background.";
}

var llm_prompt = "Summarize at " + detail_level + " level. " + length_guidance + "...";
```

**Use Cases:**
- Brief: Email previews, quick scans
- Moderate: Daily reports, standard summaries
- Comprehensive: Executive briefings, detailed analysis

### Exercise 2: Domain-Specific Summarization

Tailor prompts to specific document types.

**Meeting Notes Summarization:**
```javascript
var llm_prompt = "Summarize this meeting. Return JSON with:\n" +
  "{\"summary\":\"meeting purpose and outcomes\"," +
  "\"attendees\":[\"list of participants\"]," +
  "\"decisions\":[\"key decisions made\"]," +
  "\"action_items\":[\"task - owner - deadline\"]," +
  "\"next_meeting\":\"date/time if mentioned\"}\n" + full_text;
```

**Technical Document Summarization:**
```javascript
var llm_prompt = "Summarize this technical document. Return JSON with:\n" +
  "{\"summary\":\"technical overview\"," +
  "\"key_features\":[\"main capabilities\"]," +
  "\"requirements\":[\"prerequisites or dependencies\"]," +
  "\"implementation_steps\":[\"high-level steps\"]," +
  "\"limitations\":[\"constraints or issues\"]}\n" + full_text;
```

**Contract Summarization:**
```javascript
var llm_prompt = "Summarize this legal contract. Return JSON with:\n" +
  "{\"summary\":\"agreement overview\"," +
  "\"parties\":[\"involved parties\"]," +
  "\"key_terms\":[\"important clauses and conditions\"]," +
  "\"obligations\":[\"responsibilities of each party\"]," +
  "\"deadlines\":[\"important dates\"]," +
  "\"financial_terms\":[\"amounts, fees, payment terms\"]}\n" + full_text;
```

### Exercise 3: Sentiment-Aware Summarization

Include sentiment analysis in summaries.

**Enhanced Prompt:**
```javascript
var llm_prompt = "Summarize with sentiment analysis. Return JSON:\n" +
  "{\"summary\":\"content summary\"," +
  "\"overall_sentiment\":\"positive/negative/neutral/mixed\"," +
  "\"sentiment_explanation\":\"why this sentiment\",\n" +
  "\"bullet_points\":[],\"key_takeaways\":[],\"action_items\":[]}\n" + full_text;
```

**Use Cases:**
- Customer feedback analysis
- Employee survey summarization
- Social media monitoring
- Brand reputation tracking

### Exercise 4: Comparative Summarization

Summarize multiple related documents with comparison.

**Approach:**
1. Read multiple documents
2. Group by common identifier (project_id, topic, etc.)
3. Combine texts with separator
4. Use comparison prompt

**Prompt:**
```javascript
var llm_prompt = "Compare these " + document_count + " documents on the same topic. Return JSON:\n" +
  "{\"overall_summary\":\"common themes across all documents\"," +
  "\"agreements\":[\"points where documents agree\"]," +
  "\"disagreements\":[\"points where documents differ\"]," +
  "\"unique_points\":[{\"doc\":\"doc_id\",\"point\":\"unique insight\"}]}\n" +
  combined_texts;
```

### Exercise 5: Timeline Extraction

Extract chronological information from documents.

**Timeline Prompt:**
```javascript
var llm_prompt = "Extract timeline from this document. Return JSON:\n" +
  "{\"summary\":\"document summary\"," +
  "\"timeline\":[{\"date\":\"YYYY-MM-DD\",\"event\":\"what happened\"}]," +
  "\"future_dates\":[{\"date\":\"YYYY-MM-DD\",\"description\":\"planned event\"}]}\n" +
  "Sort timeline chronologically.\n" + full_text;
```

**Use Cases:**
- Project status reports
- Incident timelines
- Historical analysis
- Planning and scheduling

## Part 6: Handling Long Documents (15 minutes)

### Challenge: Token Limits

LLMs have context window limits. For very long documents (5000+ words):

**Approach 1: Hierarchical Summarization**

```javascript
// Split document into sections
var sections = full_text.split("\n\n"); // Or use sentence boundaries
var section_summaries = [];

// Summarize each section individually (multiple API calls)
for (var i = 0; i < sections.length; i++) {
    var section_prompt = "Summarize this section in 2-3 sentences:\n" + sections[i];
    // Call API and store section_summaries[i]
}

// Then summarize the section summaries
var final_prompt = "Create final summary from these section summaries:\n" +
                   section_summaries.join("\n");
```

**Approach 2: Sliding Window**

```javascript
// For very long documents, use sliding window
var chunk_size = 2000; // words
var overlap = 200; // words overlap between chunks

var chunks = [];
for (var i = 0; i < words.length; i += (chunk_size - overlap)) {
    chunks.push(words.slice(i, i + chunk_size).join(" "));
}

// Summarize each chunk, then combine summaries
```

**Approach 3: Key Sentence Extraction First**

```javascript
// Use extractive methods to reduce document first
var llm_prompt = "Extract the 20 most important sentences from this document:\n" + full_text;
// Then summarize the extracted sentences
```

### Optimizing num_predict

Balance between summary detail and processing time:

```javascript
// Short documents (< 500 words)
"num_predict": 400  // Brief summaries sufficient

// Medium documents (500-1500 words)
"num_predict": 800  // Standard summaries

// Long documents (1500+ words)
"num_predict": 1200  // Comprehensive summaries needed
```

## Troubleshooting

### Issue 1: Incomplete Summaries

**Symptoms:**
- Summary is truncated mid-sentence
- Missing bullet points or key takeaways
- Response cuts off

**Cause:** `num_predict` too low for document complexity

**Solution:**
```javascript
// Increase token limit
"options": {
    "temperature": 0.2,
    "num_predict": 1200  // Increased from 800
}
```

### Issue 2: Poor Quality Summaries

**Symptoms:**
- Summary misses main points
- Bullet points too generic
- No action items extracted despite document containing them

**Cause:** Prompt not specific enough or temperature too high

**Solution:**
```javascript
// Lower temperature for more focused summaries
"temperature": 0.1  // Instead of 0.2

// Enhance prompt with examples
var llm_prompt = "Summarize with these components:\n" +
  "Example summary: 'Q1 meeting covered financial review, product roadmap, and customer feedback...'\n" +
  "Example bullet: 'Revenue exceeded targets by 23% at $45.6M'\n" +
  "Now summarize:\n" + full_text;
```

### Issue 3: Malformed JSON

**Symptoms:**
- Parsing errors in Parse Summary Response step
- Empty summary fields

**Solution:**
```javascript
// Add JSON validation prompt instruction
var llm_prompt = "CRITICAL: Return ONLY valid JSON, no other text. " +
  "Format: {\"summary\":\"\",\"bullet_points\":[],\"key_takeaways\":[],\"action_items\":[]}\n" +
  "Ensure all strings are properly quoted and escaped.\n" + full_text;

// Robust parsing with fallback
try {
    var jsonStr = fullResponse.substring(jsonStart, jsonEnd);
    // Validate before parsing
    if (jsonStr.indexOf("summary") > 0 && jsonStr.indexOf("bullet_points") > 0) {
        var data = JSON.parse(jsonStr);
        summary = data.summary || "Unable to extract summary";
    }
} catch(e) {
    summary = "JSON parsing error: " + e.message;
}
```

### Issue 4: Slow Performance on Long Documents

**Symptoms:**
- Processing takes 15+ seconds per document
- Timeout errors

**Solution:**
```bash
# Increase Ollama timeout (if needed)
export OLLAMA_REQUEST_TIMEOUT=300  # 5 minutes

# Use optimized version with parallel processing
/opt/pentaho/data-integration/pan.sh -file=text_summarization_optimized.ktr

# Pre-process to reduce document length
# Add a step to truncate to first 2000 words before summarization
```

### Issue 5: Out of Memory Errors

**Symptoms:**
- Ollama crashes during processing
- "out of memory" errors in logs

**Solution:**
```bash
# Check Ollama memory usage
ollama ps

# Reduce keep_alive to free memory faster
# In transformation parameters: KEEP_ALIVE=5m

# Use smaller model if needed
# MODEL_NAME=llama3.2:1b

# Reduce parallel copies if system has limited RAM
# STEP_COPIES=2
```

## Appendix A: Complete Code Reference

### Build Summarization Prompt (Basic)

```javascript
// Build comprehensive summarization prompt
var llm_prompt = "Summarize the following document. Return ONLY valid JSON with these fields:\n\n" +
  "{\"summary\":\"2-3 sentence concise summary\",\"bullet_points\":[\"key point 1\",\"key point 2\",...]," +
  "\"key_takeaways\":[\"main insight 1\",\"main insight 2\",...]," +
  "\"action_items\":[\"action 1\",\"action 2\",...] or []}\n\n" +
  "Guidelines:\n" +
  "- Summary: Concise overview in 2-3 sentences capturing main purpose and key outcomes\n" +
  "- Bullet Points: 4-7 most important specific facts, decisions, or details from document\n" +
  "- Key Takeaways: 2-4 main insights, conclusions, or implications\n" +
  "- Action Items: Specific tasks, deadlines, or next steps if mentioned (empty array if none)\n\n" +
  "Document Type: " + document_type + "\n" +
  "Title: " + title + "\n\n" +
  "Full Text:\n" + full_text;
```

### Build Summarization Prompt (Optimized)

```javascript
// Compact summarization prompt - 50% shorter
var llm_prompt = "Summarize as JSON: {\"summary\":\"\",\"bullet_points\":[],\"key_takeaways\":[],\"action_items\":[]}\n" +
  "Summary: 2-3 sentences. Bullets: 4-7 key points. Takeaways: 2-4 insights. Actions: tasks/deadlines or [].\n" +
  "Type:" + document_type + " Title:" + title + "\n" + full_text;
```

### Build JSON Request (Optimized)

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
        "temperature": 0.2,
        "num_predict": 800,
        "num_thread": 0
    }
};

var request_body = JSON.stringify(requestObj);
```

### Parse Summary Response

```javascript
// Parse Ollama response and extract summary components
var summary = "";
var bullet_points = "[]";
var key_takeaways = "[]";
var action_items = "[]";
var word_count_original = full_text.split(" ").length;
var word_count_summary = 0;

try {
    var response = JSON.parse(api_response);
    var fullResponse = response.response;

    // Extract JSON from response
    var jsonStart = fullResponse.indexOf("{");
    var jsonEnd = fullResponse.lastIndexOf("}") + 1;

    if (jsonStart >= 0 && jsonEnd > jsonStart) {
        var jsonStr = fullResponse.substring(jsonStart, jsonEnd);
        var data = JSON.parse(jsonStr);

        summary = data.summary || "";
        bullet_points = JSON.stringify(data.bullet_points || []);
        key_takeaways = JSON.stringify(data.key_takeaways || []);
        action_items = JSON.stringify(data.action_items || []);

        word_count_summary = summary.split(" ").length;
    }
} catch(e) {
    summary = "Error: Unable to parse summary";
}

var compression_ratio = Math.round((1 - word_count_summary / word_count_original) * 100);
```

## Appendix B: Summarization Best Practices

### Prompt Engineering Tips

1. **Be Specific About Length** - "2-3 sentences" better than "brief summary"
2. **Request Structure** - JSON format ensures consistent parsing
3. **Provide Examples** - Show desired output format in prompt
4. **Set Context** - Include document type for better summarization
5. **Prioritize Information** - Explicitly request "most important" points

### Temperature Settings

| Temperature | Use Case | Summary Characteristics |
|------------|----------|-------------------------|
| 0.0-0.1 | Technical docs, contracts | Factual, conservative, sticks to source |
| 0.2-0.3 | General business docs | Balanced, natural phrasing |
| 0.4-0.5 | Creative content | More interpretive, engaging |

### Output Length Guidelines

| Document Length | Summary Length | Bullet Points | Compression |
|----------------|----------------|---------------|-------------|
| 300-500 words | 30-50 words | 3-4 bullets | 85-90% |
| 500-1000 words | 50-80 words | 5-7 bullets | 90-92% |
| 1000-2000 words | 80-120 words | 7-10 bullets | 92-94% |
| 2000+ words | 120-150 words | 10-12 bullets | 94-96% |

## Summary

In this workshop, you learned:

1. Text summarization fundamentals and different approaches (extractive vs abstractive)
2. Building effective summarization prompts for LLMs
3. Processing diverse document types with structured output (summaries, bullet points, key takeaways, action items)
4. Optimizing summarization performance with parallel processing (3-4x speedup)
5. Handling long documents and managing token limits
6. Domain-specific summarization techniques
7. Advanced topics: multi-level summaries, sentiment-aware summaries, timeline extraction

**Next Steps:**
1. Apply summarization to your own document collections
2. Customize prompts for your specific document types
3. Build summarization into document processing pipelines
4. Explore hierarchical summarization for very long documents
5. Integrate summaries with search and retrieval systems

**Additional Resources:**
- Workshop 1: Sentiment Analysis
- Workshop 2: Data Quality
- Workshop 3: Data Enrichment
- Workshop 4: Named Entity Recognition
- Ollama Documentation: https://ollama.com/docs
- LLM Prompt Engineering Guide
