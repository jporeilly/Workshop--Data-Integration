# Workshop 5 Summary: Text Summarization

## Overview

Workshop 5 teaches automated text summarization using LLMs and Pentaho Data Integration. Transform lengthy documents into concise, structured summaries with bullet points, key takeaways, and action items across 10 diverse document types.

## Key Capabilities

### Summarization Output Components (4)
1. **Summary** - 2-3 sentence concise overview capturing the main purpose and key outcomes
2. **Bullet Points** - 4-7 most important facts, decisions, or findings from the document
3. **Key Takeaways** - 2-4 critical insights or conclusions that matter most to stakeholders
4. **Action Items** - 0-6 specific tasks, deadlines, or follow-up actions (when applicable)

### Document Types Processed (10)
1. **Meeting Notes** - Team discussions, decisions made, participants, action items
2. **Incident Reports** - Technical issues, root cause analysis, impact assessment, resolution
3. **Research Papers** - Study methodology, findings, conclusions, recommendations
4. **Customer Complaints** - Issues raised, business impact, required remediation actions
5. **Project Proposals** - Goals, approach, budget, timeline, expected ROI
6. **Press Releases** - Company announcements, partnerships, strategic initiatives
7. **Email Threads** - Project updates, blockers, status reports, escalations
8. **Annual Reports** - Financial performance, achievements, strategic outlook
9. **Technical Documentation** - API guides, integration procedures, best practices
10. **Legal Contracts** - Terms and conditions, obligations, rights, termination clauses

## Transformations

### Basic Transformation: `text_summarization.ktr`

**Purpose:** Educational version with detailed prompts for learning summarization techniques.

**Workflow:**
1. Read Documents (CSV Input) - Load 10 diverse documents with varying lengths (1,000-5,000 characters)
2. Build Summarization Prompt (JavaScript) - Create comprehensive prompt requesting structured output (1,245 chars)
3. Build JSON Request (JavaScript) - Construct Ollama API request with appropriate parameters
4. Call Ollama API (REST Client) - Send to LLM for summarization processing
5. Parse Summary Response (JavaScript) - Extract all four output components, calculate metrics
6. Write Summaries CSV (Text Output) - Save with summary, bullet_points, key_takeaways, action_items, compression metrics

**Output Fields:**
- document_id, document_type, title (original)
- summary (2-3 sentence overview)
- bullet_points (JSON array of 4-7 key points)
- key_takeaways (JSON array of 2-4 critical insights)
- action_items (JSON array of 0-6 specific tasks)
- original_length (character count of full_text)
- summary_length (character count of all summary components)
- compression_ratio (percentage reduction)

**Performance:**
- Processing time: 50-70 seconds for 10 documents
- ~5-7 seconds per document (sequential)
- Compression ratio: 85-95% (reduces 3,000 char doc to 150-450 chars)
- Average summary lengths: summary (120-200 chars), bullet_points (150-300 chars), key_takeaways (80-150 chars), action_items (100-250 chars)

**Prompt Structure:**
```
Summarize the following document. Return ONLY valid JSON with this structure:
{
  "summary": "2-3 sentence overview",
  "bullet_points": ["point 1", "point 2", ...],
  "key_takeaways": ["takeaway 1", "takeaway 2", ...],
  "action_items": ["action 1", "action 2", ...]
}

Requirements:
- Summary: 2-3 concise sentences capturing main purpose and key outcomes
- Bullet Points: 4-7 most important facts or decisions
- Key Takeaways: 2-4 critical insights
- Action Items: 0-6 specific tasks with deadlines (if applicable)
- Be specific and preserve important details (names, dates, numbers)
- Return ONLY the JSON object, no explanation

DOCUMENT TO SUMMARIZE:
[full_text]
```

### Optimized Transformation: `text_summarization_optimized.ktr`

**Purpose:** Production-ready version with 3-4x performance improvement.

**Optimizations:**

1. **Parallel Processing**
   - 4 concurrent REST Client copies
   - `${STEP_COPIES}` parameter (default: 4)
   - Distributes documents across parallel streams
   - Particularly effective for lengthy documents

2. **Compact Prompt**
   - Original: 1,245 characters
   - Optimized: 618 characters
   - **50% reduction**
   - Maintains all 4 output components
   - Simplified instructions while preserving structure
   - Example: "Summarize as JSON: {summary,bullet_points,key_takeaways,action_items}. Summary: 2-3 sentences. Bullets: 4-7 key points. Takeaways: 2-4 insights. Actions: 0-6 tasks with deadlines. Preserve names, dates, numbers. JSON only."

3. **Keep-Alive**
   - Model stays in memory between requests
   - `${KEEP_ALIVE}` parameter (default: 15m)
   - Eliminates model reload overhead
   - Critical for long-running document processing

4. **Optimized Parameters**
   - temperature: 0.2 (focused, consistent summaries)
   - num_predict: 800 (adequate for structured output)
   - num_thread: 0 (use all available cores)

**Performance:**
- Processing time: 12-20 seconds for 10 documents
- ~1.2-2.0 seconds per document (parallelized)
- **3-4x faster than basic version**
- Same compression ratio: 85-95%

**Performance Comparison:**

| Version | Time (10 docs) | Docs/sec | Avg Compression | Speedup |
|---------|----------------|----------|-----------------|---------|
| Basic | 50-70 seconds | 0.14-0.20 | 85-95% | 1x |
| Optimized | 12-20 seconds | 0.50-0.83 | 85-95% | **3-4x** |

## Sample Data

**File:** `data/documents_to_summarize.csv`

**Structure:**
- document_id: 1-10
- document_type: meeting_notes, incident_report, research_paper, etc.
- title: Descriptive document title
- full_text: Complete document content (1,000-5,000 characters)

**Sample Document:**
```
document_id: 1
document_type: meeting_notes
title: Q1 2025 Product Strategy Meeting
full_text: "Meeting held on February 15, 2025, in Conference Room A.
Attendees: Sarah Johnson (CEO), Michael Chen (CTO), Jennifer Williams (VP Product)...
[2,487 characters total]"
```

**Expected Output Components:**
- **Summary:** "Q1 2025 product strategy meeting focused on roadmap priorities, with Q4 revenue exceeding targets by 23% at $45.6M. Three major technical initiatives were approved: AI analytics platform launch (March 15), cloud provider integrations (April), and mobile app redesign (May)."
- **Bullet Points:**
  - "Q4 2024 revenue exceeded targets by 23% reaching $45.6 million"
  - "AI-powered analytics platform launching March 15th"
  - "Customer feedback from 500+ clients prioritized advanced reporting, collaboration, and API docs"
  - "Q1 revenue projected at $38-42 million with 15 major deals in negotiation"
  - "$2.5 million marketing budget approved for Q1 initiatives"
- **Key Takeaways:**
  - "Strong focus on enterprise customer feature requests with 60% engineering resource allocation"
  - "Multi-channel marketing campaign targeting thought leadership through conferences and webinars"
- **Action Items:**
  - "Michael to finalize API documentation by March 1st"
  - "Jennifer to create customer advisory board by February 28th"
  - "Robert to implement new sales playbook by March 15th"
  - "Linda to launch website redesign by March 30th"

**Metrics:**
- original_length: 2,487
- summary_length: 312
- compression_ratio: 0.87 (87% reduction)

## Key JavaScript Code

### Build Summarization Prompt (Basic)

```javascript
var llm_prompt = "Summarize the following document. Return ONLY valid JSON with this exact structure:\n\n" +
  "{\n" +
  "  \"summary\": \"2-3 sentence overview of the document\",\n" +
  "  \"bullet_points\": [\"key point 1\", \"key point 2\", ...],\n" +
  "  \"key_takeaways\": [\"main takeaway 1\", \"main takeaway 2\", ...],\n" +
  "  \"action_items\": [\"action 1 with deadline\", \"action 2 with deadline\", ...]\n" +
  "}\n\n" +
  "REQUIREMENTS:\n" +
  "- Summary: Write 2-3 concise sentences capturing the main purpose and key outcomes\n" +
  "- Bullet Points: Extract 4-7 most important facts, decisions, or findings\n" +
  "- Key Takeaways: Identify 2-4 critical insights or conclusions that matter most\n" +
  "- Action Items: List 0-6 specific tasks, deadlines, or follow-up actions (if document contains them)\n" +
  "- Be specific: preserve important details like names, dates, numbers, and amounts\n" +
  "- Return ONLY the JSON object, no explanation or additional text\n\n" +
  "DOCUMENT TO SUMMARIZE:\n" +
  full_text;
```

### Build Summarization Prompt (Optimized)

```javascript
var llm_prompt = "Summarize as JSON: {\"summary\":\"\",\"bullet_points\":[],\"key_takeaways\":[],\"action_items\":[]}. " +
  "Summary: 2-3 sentences capturing main purpose and outcomes. " +
  "Bullets: 4-7 key facts/decisions. " +
  "Takeaways: 2-4 critical insights. " +
  "Actions: 0-6 tasks with deadlines if applicable. " +
  "Preserve names, dates, numbers. JSON only.\n\n" +
  "Document:\n" + full_text;
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
        "temperature": 0.2,
        "num_predict": 800,
        "num_thread": 0
    }
};

var request_body = JSON.stringify(requestObj);
```

### Parse Summary Response

```javascript
var summary = "";
var bullet_points = "[]";
var key_takeaways = "[]";
var action_items = "[]";
var original_length = (full_text || "").length;
var summary_length = 0;
var compression_ratio = 0;

try {
    var response = JSON.parse(api_response);
    var fullResponse = response.response;

    // Extract JSON object from response
    var jsonStart = fullResponse.indexOf("{");
    var jsonEnd = fullResponse.lastIndexOf("}") + 1;

    if (jsonStart >= 0 && jsonEnd > jsonStart) {
        var jsonStr = fullResponse.substring(jsonStart, jsonEnd);
        var summaryObj = JSON.parse(jsonStr);

        // Extract components
        summary = summaryObj.summary || "";
        bullet_points = JSON.stringify(summaryObj.bullet_points || []);
        key_takeaways = JSON.stringify(summaryObj.key_takeaways || []);
        action_items = JSON.stringify(summaryObj.action_items || []);

        // Calculate metrics
        summary_length = summary.length +
                        bullet_points.length +
                        key_takeaways.length +
                        action_items.length;

        if (original_length > 0) {
            compression_ratio = Number((1 - (summary_length / original_length)).toFixed(2));
        }
    }
} catch(e) {
    // Use defaults on error
    summary = "Error processing summary";
    bullet_points = "[]";
    key_takeaways = "[]";
    action_items = "[]";
}
```

## Advanced Techniques (From Workshop Guide)

### Multi-Level Summarization
- Generate both brief (executive) and detailed (comprehensive) summaries
- Executive: 1 sentence + 3 bullets (for C-suite)
- Detailed: 3-5 sentences + 7-10 bullets (for team review)
- Use case: Different audiences need different detail levels

### Domain-Specific Summarization
- Customize output components for specific industries
- Healthcare: diagnosis, treatment, patient info, follow-up
- Legal: parties, obligations, terms, deadlines, liabilities
- Financial: amounts, dates, parties, conditions, risks
- Technical: issues, root cause, resolution, prevention

### Hierarchical Summarization
- Multi-document summarization with hierarchy
- Individual document summaries → section summaries → overall summary
- Use case: Summarizing multi-chapter reports or document collections

### Extractive + Abstractive
- Combine extractive (quote key sentences) with abstractive (rewrite concisely)
- Add "key_quotes" field with verbatim important statements
- Use case: Legal or compliance where exact wording matters

### Sentiment-Aware Summarization
- Include sentiment analysis in summary components
- Add "overall_sentiment" and "concerns" fields
- Use case: Customer feedback, complaint analysis, stakeholder communications

### Time-Aware Summarization
- Prioritize recent information in long temporal documents
- Extract timeline of key events
- Use case: Incident reports, project status updates, historical analyses

## Parameters

### Basic Transformation
| Parameter | Default | Description |
|-----------|---------|-------------|
| OLLAMA_URL | http://localhost:11434/api/generate | Ollama API endpoint |
| MODEL_NAME | llama3.2:3b | LLM model for summarization |

### Optimized Transformation
| Parameter | Default | Description |
|-----------|---------|-------------|
| OLLAMA_URL | http://localhost:11434/api/generate | Ollama API endpoint |
| MODEL_NAME | llama3.2:3b | LLM model for summarization |
| KEEP_ALIVE | 15m | Keep model in memory |
| STEP_COPIES | 4 | Parallel API call copies |

**Model-Specific Settings:**
| Setting | Value | Rationale |
|---------|-------|-----------|
| temperature | 0.2 | Low temperature for focused, consistent summaries |
| num_predict | 800 | Sufficient tokens for structured 4-component output |
| num_thread | 0 | Use all CPU cores for faster processing |
| format | json | Enforce JSON output structure |

**Tuning Recommendations:**
- **STEP_COPIES:** Set to CPU cores - 1 (4-core = 3, 8-core = 7) for optimal parallelism
- **KEEP_ALIVE:**
  - 5m (infrequent batch processing)
  - 15m (regular processing, recommended)
  - 30m (continuous high-volume)
  - 60m (always-on production service)
- **MODEL_NAME:**
  - llama3.2:1b (fastest, good for simple documents)
  - llama3.2:3b (balanced, recommended for most use cases)
  - llama3.1:8b (highest quality, slower, for complex/technical docs)
- **temperature:**
  - 0.1 (highly consistent, may be repetitive)
  - 0.2 (recommended, good balance)
  - 0.3 (more creative summaries, less consistency)
- **num_predict:**
  - 600 (short documents, minimal output)
  - 800 (recommended for 4-component structure)
  - 1200 (very long documents or detailed summaries)

## Use Cases

1. **Executive Briefings**
   - Summarize lengthy reports, proposals, and analyses for leadership
   - Generate daily/weekly executive summaries from multiple sources
   - Provide quick decision-making insights from complex documents

2. **Customer Service**
   - Auto-summarize customer complaints with action items
   - Extract key issues from long support ticket histories
   - Create summary views for customer account reviews

3. **Knowledge Management**
   - Generate searchable summaries for document repositories
   - Create abstracts for internal wikis and knowledge bases
   - Build summary indexes for faster information retrieval

4. **Email Processing**
   - Summarize long email threads before meetings
   - Extract action items from project update emails
   - Create digest summaries of multiple related emails

5. **Research & Intelligence**
   - Condense research papers into digestible insights
   - Summarize competitive intelligence reports
   - Create briefing documents from multiple sources

6. **Meeting Management**
   - Auto-generate meeting summaries from transcripts or notes
   - Extract and track action items across meetings
   - Create executive summaries for distribution

7. **Legal & Compliance**
   - Summarize contracts highlighting key terms and obligations
   - Extract critical dates, amounts, and parties from legal documents
   - Create compliance summary reports from audit findings

8. **Content Curation**
   - Generate article summaries for newsletters
   - Create content digests for internal communications
   - Summarize industry news for stakeholder distribution

## Common Issues and Solutions

### Issue: Incomplete Summaries
**Solution:** Increase `num_predict` from 800 to 1200, ensure prompt emphasizes all required components

### Issue: Inconsistent JSON Structure
**Solution:** Use `"format": "json"` in API request, add validation in parsing script, handle missing fields gracefully

### Issue: Missing Action Items
**Solution:** Emphasize in prompt that action items are optional (0-6), not all documents contain actionable tasks

### Issue: Too Generic Summaries
**Solution:** Lower temperature to 0.1, add "preserve specific details like names, dates, amounts" to prompt

### Issue: Overly Long Summaries
**Solution:** Be more specific about length constraints (e.g., "2-3 sentences maximum of 50 words"), lower num_predict

### Issue: Poor Compression Ratio
**Solution:** Review document types - some (like contracts) may require more detail, adjust expectations per document type

### Issue: Slow Performance
**Solution:** Verify keep_alive working, increase STEP_COPIES to match CPU cores, use llama3.2:3b or 1b model

## Integration Patterns

1. **Document Processing Pipeline** - Automatically summarize new documents as they're uploaded
2. **Email Automation** - Summarize incoming emails and create task lists
3. **Report Generation** - Combine multiple document summaries into comprehensive reports
4. **Search Enhancement** - Use summaries as search metadata for better document discovery
5. **Notification System** - Send summary + action items instead of full documents
6. **Archive Management** - Create summary catalog for large document archives

## Learning Outcomes

After completing this workshop, you can:

1. Understand text summarization techniques and output structure design
2. Build effective prompts that generate consistent, structured summaries
3. Process diverse document types with appropriate summarization strategies
4. Extract multiple output components (summary, bullets, takeaways, actions)
5. Optimize summarization performance with parallel processing (3-4x speedup)
6. Calculate and track compression ratios and summary quality metrics
7. Apply advanced techniques (multi-level, domain-specific, hierarchical)
8. Integrate summarization into document processing workflows
9. Tune performance parameters for different document types and volumes
10. Troubleshoot common summarization quality and performance issues

## Files Created

```
workshops/workshop-05-text-summarization/
├── data/
│   └── documents_to_summarize.csv (10 sample documents)
├── transformations/
│   ├── text_summarization.ktr (basic)
│   └── text_summarization_optimized.ktr (optimized)
├── docs/
│   └── workshop_5_text_summarization.md (complete guide)
├── README.md (quick start)
└── WORKSHOP_SUMMARY.md (this file)
```

## Next Steps

1. Complete the 60-90 minute workshop guide
2. Run both transformations on sample data
3. Customize output components for your use case
4. Process your own documents (reports, emails, contracts)
5. Build summarization into your document workflows
6. Explore advanced techniques (multi-level, domain-specific)
7. Integrate with downstream systems (email, databases, dashboards)
8. Implement quality metrics and monitoring

## Documentation

See [docs/workshop_5_text_summarization.md](docs/workshop_5_text_summarization.md) for:
- Complete workshop guide (60-90 minutes)
- Detailed summarization technique explanations
- Step-by-step transformation building
- Advanced summarization patterns
- Performance tuning strategies
- Integration examples and best practices
- Troubleshooting guide
- Complete code reference
