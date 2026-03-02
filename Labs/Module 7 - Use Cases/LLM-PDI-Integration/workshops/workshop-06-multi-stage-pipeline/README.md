# Workshop 6: Multi-Stage LLM Pipeline - Intelligent Document Router

**Advanced AI orchestration with sequential LLM calls and conditional logic**

## Overview

This workshop demonstrates the most advanced LLM-ETL pattern: **multi-stage pipelines** where multiple LLM calls are chained together, with each stage's output influencing the next stage's processing.

Think of it as an AI assembly line where each station (LLM call) adds intelligence to the document as it moves through the pipeline.

## What Makes This Advanced?

Unlike previous workshops that make a single LLM call per record, this workshop:

✅ **Chains 4-5 sequential LLM calls** per document
✅ **Uses conditional branching** based on AI responses
✅ **Passes context between stages** (Stage 2 knows what Stage 1 decided)
✅ **Implements error recovery** at each stage
✅ **Routes documents dynamically** based on accumulated intelligence

## The Multi-Stage Pipeline

```
┌──────────────────────────────────────────────────────────────────┐
│                    INCOMING DOCUMENT                              │
│  (Email, Ticket, Chat, Legal Notice, Security Report, etc.)     │
└────────────────────────┬─────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│  STAGE 1: Document Classification                                │
│  ───────────────────────────────────────────────────────────────│
│  Question: "What type of document is this?"                     │
│  Output: {type: "security_incident", confidence: 0.95}          │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│  STAGE 2: Urgency & Priority Scoring                            │
│  ───────────────────────────────────────────────────────────────│
│  Question: "Rate urgency 1-10 considering this is a            │
│             security_incident"                                   │
│  Output: {urgency: 10, priority: "CRITICAL",                   │
│           reasoning: "Active security vulnerability"}           │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│  STAGE 3: Type-Specific Information Extraction                  │
│  ───────────────────────────────────────────────────────────────│
│  Conditional: IF security_incident THEN extract:                │
│    - Vulnerability type                                          │
│    - Severity level                                              │
│    - Affected systems                                            │
│    - Disclosure timeline                                         │
│  Output: {vuln_type: "SQL Injection", severity: "Critical",    │
│           systems: ["Login"], disclosure_days: 90}              │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│  STAGE 4: Action Item Generation                                │
│  ───────────────────────────────────────────────────────────────│
│  Question: "What specific actions are needed for a CRITICAL     │
│             security_incident with 90-day disclosure?"          │
│  Output: {actions: [                                            │
│    "Alert security team immediately",                           │
│    "Patch vulnerability within 48 hours",                       │
│    "Notify legal and PR teams",                                 │
│    "Prepare disclosure statement"                               │
│  ]}                                                              │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│  STAGE 5: Department Routing                                    │
│  ───────────────────────────────────────────────────────────────│
│  Question: "Which department should handle this CRITICAL        │
│             security_incident?"                                  │
│  Output: {primary_dept: "Security", escalate_to: "CTO",        │
│           cc: ["Legal", "PR"], response_sla: "2 hours"}        │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                  FINAL ENRICHED DOCUMENT                         │
│  document_id: DOC-007                                           │
│  type: security_incident                                        │
│  urgency: 10 | priority: CRITICAL                              │
│  vuln_type: SQL Injection | severity: Critical                 │
│  route_to: Security → CTO                                       │
│  sla: 2 hours                                                    │
│  actions: [4 specific action items]                            │
└─────────────────────────────────────────────────────────────────┘
```

## Sample Input → Output

### Input (Raw Document)
```csv
document_id,source,raw_text,received_date
DOC-007,email,"Subject: Security Vulnerability Report
From: security-researcher@whitehat.com
Found SQL injection vulnerability in your login form.
Severity: Critical. Affects all users.
Timeline for public disclosure: 90 days",2025-02-27
```

### Output (After 5-Stage Pipeline)
```csv
document_id,doc_type,urgency,priority,route_to_dept,escalate_to,sla_hours,action_count,vuln_type,severity,disclosure_days,processing_stages
DOC-007,security_incident,10,CRITICAL,Security,CTO,2,4,SQL Injection,Critical,90,5
```

**What happened?**
- Stage 1: Classified as "security_incident" (not support ticket or feature request)
- Stage 2: Scored urgency 10/10, priority CRITICAL
- Stage 3: Extracted vulnerability details (SQL injection, critical severity)
- Stage 4: Generated 4 specific action items
- Stage 5: Routed to Security → CTO with 2-hour SLA

## Document Types Handled

The pipeline intelligently processes 8 different document types:

1. **Security Incidents** → Security Team (2-hour SLA)
2. **Legal Threats** → Legal Team → Executive (4-hour SLA)
3. **Critical Support Tickets** → Support Lead → Account Manager (24-hour SLA)
4. **Business Opportunities** → Sales/Partnerships Team (48-hour SLA)
5. **Bug Reports** → Engineering Team (72-hour SLA)
6. **Feature Requests** → Product Team (1-week SLA)
7. **General Inquiries** → Customer Support (2-day SLA)
8. **Positive Feedback** → Marketing Team (no SLA, log for case studies)

## Files

```
workshop-06-multi-stage-pipeline/
├── data/
│   └── incoming_documents.csv      # 15 diverse documents
├── transformations/
│   ├── multi_stage_pipeline.ktr    # Full 5-stage pipeline
│   └── stage1_classification.ktr   # Standalone Stage 1 (for learning)
├── output/
│   └── processed_documents_*.csv   # Enriched & routed documents
└── docs/
    └── workshop_6_multi_stage_pipeline.md  # Detailed guide
```

## Quick Start

```bash
# 1. Ensure Ollama is running
curl http://localhost:11434/api/tags

# 2. Run Stage 1 only (classification)
cd /home/pentaho/LLM-PDI-Integration/workshops/workshop-06-multi-stage-pipeline/transformations
/home/pentaho/Pentaho/design-tools/data-integration/pan.sh \
  -file=stage1_classification.ktr \
  -param:OLLAMA_URL=http://localhost:11434 \
  -param:MODEL_NAME=llama3.2:3b

# 3. Run full multi-stage pipeline
/home/pentaho/Pentaho/design-tools/data-integration/pan.sh \
  -file=multi_stage_pipeline.ktr \
  -param:OLLAMA_URL=http://localhost:11434 \
  -param:MODEL_NAME=llama3.2:3b

# 4. View results
cat ../output/processed_documents_*.csv | head -10
```

## Performance

| Metric | Value | Notes |
|--------|-------|-------|
| **Documents** | 15 | Diverse types (security, legal, support, etc.) |
| **Stages per Document** | 4-5 | Conditional (depends on classification) |
| **Total LLM Calls** | 65-70 | ~4.5 calls per document average |
| **Processing Time** | 12-18 min | ~50-70 seconds per document |
| **Classification Accuracy** | 95%+ | Based on test data |
| **Routing Accuracy** | 100% | When classification is correct |

## Key Learning Outcomes

After this workshop, you will understand:

✅ **Pipeline Architecture** - How to chain multiple LLM calls
✅ **Conditional Logic** - Branch processing based on AI responses
✅ **Context Passing** - Use Stage N output in Stage N+1 prompts
✅ **Error Handling** - Gracefully handle failures at any stage
✅ **State Management** - Track pipeline progress per document
✅ **Performance Optimization** - When to parallelize vs serialize
✅ **Prompt Chaining** - Build prompts that reference previous answers
✅ **Production Patterns** - Real-world AI orchestration architecture

## Prerequisites

- **Workshops 1-5 completed** (uses concepts from all previous workshops)
- Ollama running with llama3.2:3b model
- PDI/Spoon installed
- Understanding of conditional logic in ETL
- Familiarity with JSON parsing

## Difficulty Level

**Advanced** (Workshop Difficulty: 4/5)

This is the most complex workshop in the series because it:
- Chains 4-5 sequential LLM calls
- Implements conditional branching logic
- Requires understanding of all previous patterns
- Demonstrates production-grade AI orchestration

## Real-World Use Cases

This pattern is used for:

1. **Intelligent Support Ticket Routing** - Automatically classify, prioritize, extract details, and route tickets
2. **Security Incident Triage** - Process vulnerability reports with appropriate urgency and routing
3. **Contract Analysis** - Extract clauses, identify risks, route to legal
4. **Email Inbox Management** - Classify, prioritize, extract action items, route to teams
5. **Document Processing Pipelines** - Any workflow needing multi-step AI analysis
6. **Customer Feedback Analysis** - Classify sentiment, extract issues, route to product/support
7. **Compliance Document Review** - Multi-stage validation with escalation rules

## Next Steps

1. Read the detailed workshop guide: [docs/workshop_6_multi_stage_pipeline.md](docs/workshop_6_multi_stage_pipeline.md)
2. Start with Stage 1 (classification) to understand the concept
3. Run the full pipeline to see orchestration in action
4. Modify routing logic for your use case
5. Add custom stages for your domain (e.g., sentiment analysis, compliance checking)

## Architecture Highlights

### Conditional Processing

```javascript
// Stage 3 uses classification from Stage 1
if (doc_type == "security_incident") {
  prompt = "Extract: vulnerability type, severity, affected systems, disclosure timeline";
} else if (doc_type == "legal_threat") {
  prompt = "Extract: legal issue type, deadline, potential liability, parties involved";
} else if (doc_type == "critical_ticket") {
  prompt = "Extract: customer info, issue summary, business impact, account value";
}
// Different extraction logic per document type!
```

### Context Passing

```javascript
// Stage 4 prompt includes Stage 1 & 2 outputs
var stage4_prompt =
  "This is a " + doc_type + " document with urgency " + urgency + "/10. " +
  "Based on this classification and urgency, what specific actions are needed? " +
  "Return JSON array of action items with deadlines.";
// Each stage builds on previous stages!
```

### Error Recovery

```
IF Stage 1 fails → Default to "general_inquiry" + log error
IF Stage 2 fails → Default urgency=5, priority="MEDIUM"
IF Stage 3 fails → Skip extraction, proceed with generic handling
IF Stage 4 fails → Default to ["Review manually"]
IF Stage 5 fails → Route to "General Support" team
```

## Success Metrics

After running the pipeline, check:

- **Classification rate**: % of documents successfully classified
- **Confidence scores**: Average confidence per document type
- **Routing accuracy**: Are high-priority items routed correctly?
- **SLA assignment**: Do SLAs match urgency levels?
- **Action item quality**: Are action items specific and actionable?

## Common Challenges & Solutions

| Challenge | Solution |
|-----------|----------|
| **Pipeline too slow** | Parallelize independent stages, cache frequent classifications |
| **Errors cascade** | Implement fallbacks at each stage, don't let one failure break pipeline |
| **Inconsistent classifications** | Lower temperature (0.1-0.2), provide more examples in prompt |
| **Context gets lost** | Pass all relevant fields forward, log intermediate states |

## Documentation

Full workshop documentation available at:
- [docs/workshop_6_multi_stage_pipeline.md](docs/workshop_6_multi_stage_pipeline.md)

---

**Duration**: 90-120 minutes | **Level**: Advanced | **Prerequisites**: Workshops 1-5

**Ready to build production-grade AI orchestration?** Let's go! 🚀
