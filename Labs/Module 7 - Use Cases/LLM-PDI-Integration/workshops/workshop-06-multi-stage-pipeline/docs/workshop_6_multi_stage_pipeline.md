# Workshop 6: Multi-Stage LLM Pipeline - Complete Guide

**Advanced AI Orchestration with Sequential LLM Calls**

## Table of Contents

1. [Introduction](#introduction)
2. [Learning Objectives](#learning-objectives)
3. [Prerequisites](#prerequisites)
4. [Part 1: Understanding Multi-Stage LLM Pipelines](#part-1-understanding-multi-stage-llm-pipelines-20-minutes)
5. [Architecture Overview](#architecture-overview)
6. [The 5-Stage Pipeline](#the-5-stage-pipeline)
7. [Step-by-Step Implementation](#step-by-step-implementation)
8. [Running the Transformation](#running-the-transformation)
9. [Analyzing Results](#analyzing-results)
10. [Advanced Concepts](#advanced-concepts)
11. [Troubleshooting](#troubleshooting)
12. [Production Considerations](#production-considerations)

---

## Introduction

This workshop teaches the most advanced LLM-ETL pattern: **multi-stage pipelines** where multiple LLM calls are chained sequentially, with each stage building on the outputs of previous stages.

### Why Multi-Stage Pipelines?

Single LLM calls are powerful, but real-world AI systems often require:
- **Context accumulation**: Each stage adds intelligence
- **Conditional logic**: Different processing based on classification
- **Specialized prompts**: Each stage focuses on one task
- **Error isolation**: Failures in one stage don't break entire pipeline
- **Auditability**: Track decisions at each stage

### Real-World Example

Think of processing a customer support ticket:
1. **Classify** → Is this a bug, feature request, or complaint?
2. **Prioritize** → How urgent is this (1-10)?
3. **Extract** → Pull out customer details, issue summary, account value
4. **Generate Actions** → What specific steps should we take?
5. **Route** → Which team handles this? Who gets escalated to?

Each stage uses information from previous stages to make better decisions.

---

## Learning Objectives

By the end of this workshop, you will be able to:

✅ Design and implement multi-stage LLM pipelines
✅ Chain sequential AI calls with context passing
✅ Implement conditional logic based on LLM responses
✅ Handle errors gracefully at each pipeline stage
✅ Build production-ready intelligent routing systems
✅ Optimize performance across multiple LLM calls
✅ Apply these patterns to real-world business problems

---

## Prerequisites

### Required Workshops
- Workshop 1: Sentiment Analysis (basic LLM integration)
- Workshop 2: Data Quality (prompt engineering)
- Workshop 3: Data Enrichment (field extraction)
- Workshop 4: Named Entity Recognition (JSON parsing)
- Workshop 5: Text Summarization (structured output)

### Technical Requirements
- Ubuntu 24.04 or similar Linux distribution
- Pentaho Data Integration (PDI) 9.x or later
- Ollama installed and running
- llama3.2:3b model downloaded
- At least 8GB RAM (for model + processing)
- Basic understanding of JavaScript for PDI scripting

### Knowledge Requirements
- Comfortable with PDI/Spoon interface
- Understanding of REST API calls
- JSON parsing experience
- Basic prompt engineering concepts
- Familiarity with conditional logic in ETL

---

## Part 1: Understanding Multi-Stage LLM Pipelines (20 minutes)

### What is a Multi-Stage Pipeline?

A **multi-stage pipeline** is an AI orchestration pattern where multiple LLM calls are chained together sequentially, with each stage performing a focused task and passing enriched data to the next stage.

Think of it like an assembly line in a factory:
- **Stage 1**: Worker identifies the type of product (Classification)
- **Stage 2**: Worker assesses quality and priority (Scoring)
- **Stage 3**: Worker extracts specific components based on type (Conditional Extraction)
- **Stage 4**: Worker creates assembly instructions (Action Generation)
- **Stage 5**: Worker routes to appropriate department (Routing)

Each worker (LLM call) specializes in ONE task and has ALL the information gathered by previous workers.

### Real-World Example: Intelligent Support Ticket Routing

**Scenario**: Your company receives 1,000 support tickets per day via email, chat, and web forms. You need to:
1. Categorize each ticket (bug report, feature request, billing issue, etc.)
2. Determine urgency (critical issues need immediate attention)
3. Extract relevant details (customer info, account value, issue description)
4. Generate action items for the assigned team
5. Route to the correct department with proper escalation

**Single-Stage Approach** (❌ What NOT to do):
```
Prompt: "Analyze this support ticket and provide:
- Category (bug/feature/billing/complaint)
- Urgency score 1-10
- Customer name, account value, issue summary
- Action items to resolve
- Department to route to
- Escalation path
All in JSON format."
```

**Problems:**
- ❌ 200+ token prompt (expensive and slow)
- ❌ LLM tries to do 6 different tasks at once (lower accuracy)
- ❌ Can't handle conditional logic (different ticket types need different extraction)
- ❌ If extraction fails, you lose everything
- ❌ No intermediate validation
- ❌ Difficult to debug which part failed

**Multi-Stage Approach** (✅ What we'll build):
```
Stage 1: "What category is this ticket?" → "bug_report"
Stage 2: "Rate urgency for a bug_report" → urgency: 8, priority: HIGH
Stage 3: "Extract bug-specific details" → {error_message, steps_to_reproduce, ...}
Stage 4: "Generate actions for HIGH priority bug" → ["Assign to senior engineer", "Contact customer within 2h"]
Stage 5: "Route HIGH priority bug" → Engineering Team, escalate to VP Engineering
```

**Advantages:**
- ✅ Focused prompts (40-80 tokens each, faster & cheaper)
- ✅ Higher accuracy (each LLM call does ONE thing well)
- ✅ Conditional logic (Stage 3 adapts based on Stage 1 result)
- ✅ Graceful degradation (if Stage 3 fails, you still have Stages 1-2)
- ✅ Auditable (see decision at each stage)
- ✅ Easy to debug (know exactly which stage failed)

### Core Principles of Multi-Stage Pipelines

#### 1. **Single Responsibility Per Stage**

Each stage has ONE job:
- **Stage 1**: Classification ONLY
- **Stage 2**: Priority scoring ONLY
- **Stage 3**: Information extraction ONLY
- **Stage 4**: Action generation ONLY
- **Stage 5**: Routing ONLY

**Why?** Focused prompts produce better results than complex multi-task prompts.

#### 2. **Sequential Execution with Context Passing**

Stages run in order, and each stage receives:
- Original input data
- ALL outputs from previous stages

**Example Context Flow:**
```
After Stage 1: {doc_type: "security_incident"}
After Stage 2: {doc_type: "security_incident", urgency: 10, priority: "CRITICAL"}
After Stage 3: {doc_type: "security_incident", urgency: 10, priority: "CRITICAL",
                vuln_type: "SQL injection", severity: "Critical"}
After Stage 4: {... all previous ..., actions: ["Alert security team", "Patch within 48h"]}
After Stage 5: {... all previous ..., route_to: "Security", escalate_to: "CTO"}
```

**Why?** Each stage makes BETTER decisions with full context from previous stages.

#### 3. **Conditional Branching**

Different document types require different processing:

```javascript
// Stage 3: Type-Specific Extraction (CONDITIONAL LOGIC)
if (doc_type == "security_incident") {
  prompt = "Extract: vulnerability type, severity, affected systems, disclosure timeline";

} else if (doc_type == "legal_threat") {
  prompt = "Extract: legal issue, deadline, potential liability, threatening party";

} else if (doc_type == "critical_ticket") {
  prompt = "Extract: customer name, account value, business impact, issue summary";

} else {
  prompt = "Extract: generic summary and key points";
}
```

**Why?** A security incident needs different information than a billing complaint.

#### 4. **Error Isolation & Recovery**

Each stage has fallback logic:

```javascript
try {
  doc_type = parseStage1Response(response);
} catch (error) {
  doc_type = "general_inquiry"; // Safe default
  log("Stage 1 classification failed, defaulting to general_inquiry");
}
// Pipeline continues with default value!
```

**Why?** One stage failure doesn't break the entire pipeline.

### Comparison: Single-Stage vs Multi-Stage

| Aspect | Single-Stage | Multi-Stage |
|--------|-------------|-------------|
| **Prompt Length** | 200+ tokens | 40-80 tokens per stage |
| **Accuracy** | 65-75% (trying to do too much) | 85-95% (focused tasks) |
| **Processing Time** | 60-90 seconds | 50-70 seconds (5 calls @ 10-14s each) |
| **Cost per Document** | High (long prompt) | Lower (multiple short prompts) |
| **Conditional Logic** | ❌ Not possible | ✅ Full support |
| **Error Handling** | ❌ All-or-nothing | ✅ Per-stage recovery |
| **Debugging** | ❌ Hard to isolate issues | ✅ Know exactly which stage failed |
| **Auditability** | ❌ Black box decision | ✅ Track reasoning at each stage |
| **Extensibility** | ❌ Hard to add features | ✅ Easy to add new stages |

### When to Use Multi-Stage Pipelines

**Use Multi-Stage Pipelines When:**
- ✅ You need conditional processing (different types → different handling)
- ✅ You need to make sequential decisions (Stage 2 depends on Stage 1)
- ✅ You need auditability (track decision-making process)
- ✅ You need high accuracy (focused prompts perform better)
- ✅ You're building production systems (error isolation critical)
- ✅ Documents vary significantly in type/structure

**Use Single-Stage When:**
- ✅ Task is simple and uniform (all documents processed identically)
- ✅ Minimal conditional logic needed
- ✅ Low-stakes application (errors acceptable)
- ✅ Prototyping/testing (faster to build initially)

### The 5-Stage Intelligent Document Router

This workshop builds a production-grade document routing system with 5 stages:

**Stage 1: Document Classification** (10-15 seconds)
- Input: Raw document text
- Output: `doc_type` (security_incident, legal_threat, critical_ticket, etc.), `confidence`
- Purpose: Identify what we're dealing with

**Stage 2: Priority Scoring** (10-15 seconds)
- Input: Raw text + `doc_type` from Stage 1
- Output: `urgency` (1-10), `priority` (LOW/MEDIUM/HIGH/CRITICAL)
- Purpose: Determine how quickly we need to act
- Uses Stage 1 context: "Rate urgency for a **security_incident**" (more accurate!)

**Stage 3: Type-Specific Extraction** (10-15 seconds)
- Input: Raw text + `doc_type` + `urgency`
- Output: `extracted_details` (JSON, varies by type)
- Purpose: Pull out relevant information based on document type
- **Conditional**: Different extraction for security vs legal vs support tickets

**Stage 4: Action Item Generation** (10-15 seconds)
- Input: All previous context
- Output: `actions[]`, `action_count`, `requires_escalation`
- Purpose: Create specific, actionable tasks
- Uses full context: "For a **CRITICAL security_incident** with **urgency 10**, what actions?"

**Stage 5: Department Routing** (10-15 seconds)
- Input: All previous context
- Output: `primary_dept`, `escalate_to`, `cc_depts`, `sla_hours`
- Purpose: Determine who handles this and escalation path
- Uses full context: "Route a **CRITICAL security_incident** requiring **escalation** to appropriate team"

**Total Processing**: 50-75 seconds per document (5 sequential LLM calls)

### How Context Accumulation Works

Let's trace a real document through the pipeline:

**Input Document:**
```
Subject: Security Vulnerability Report
From: security-researcher@whitehat.com

Found SQL injection vulnerability in your login form.
Severity: Critical. Affects all users. Can extract password hashes.
Timeline for public disclosure: 90 days from today.
```

**Stage 1 Output:**
```json
{
  "doc_type": "security_incident",
  "confidence": 0.95,
  "reasoning": "Document reports a security vulnerability with severity and disclosure timeline"
}
```

**Stage 2 Output** (knows it's a security_incident):
```json
{
  "urgency": 10,
  "priority": "CRITICAL",
  "reasoning": "Critical severity vulnerability affecting all users with 90-day disclosure deadline"
}
```

**Stage 3 Output** (conditional extraction for security_incident):
```json
{
  "vuln_type": "SQL injection",
  "severity": "Critical",
  "affected_systems": "login form",
  "disclosure_days": 90
}
```

**Stage 4 Output** (knows: security + critical + SQL injection + 90 days):
```json
{
  "actions": [
    "Alert security team immediately",
    "Patch SQL injection vulnerability within 48 hours",
    "Notify legal and PR teams of upcoming disclosure",
    "Prepare disclosure statement for responsible disclosure"
  ],
  "action_count": 4,
  "requires_escalation": true
}
```

**Stage 5 Output** (knows: critical security incident requiring escalation):
```json
{
  "primary_dept": "Security",
  "escalate_to": "CTO",
  "cc_depts": ["Legal", "PR"],
  "sla_hours": 2
}
```

**Final Enriched Document** has ALL this intelligence:
- Original text preserved
- Classified as security_incident (95% confidence)
- Rated CRITICAL with urgency 10/10
- SQL injection in login form, 90-day disclosure
- 4 specific action items generated
- Routed to Security → CTO, CC Legal & PR, 2-hour SLA

**Total Time**: ~55 seconds (5 LLM calls)

### Key Benefits Demonstrated

1. **Contextual Intelligence**: Stage 2 knows it's a security_incident (from Stage 1), so it applies appropriate urgency heuristics
2. **Conditional Processing**: Stage 3 extracts vulnerability-specific details because Stage 1 identified it as security_incident
3. **Compound Context**: Stage 4 generates security-specific actions because it knows type + urgency + vulnerability details
4. **Intelligent Routing**: Stage 5 routes to Security + CTO because it knows: CRITICAL + security + requires_escalation

**Without multi-stage?** You'd get generic results. With multi-stage? You get specialized, context-aware intelligence at every step.

### Common Multi-Stage Patterns

**Pattern 1: Classification → Conditional Processing**
```
Classify document → IF legal THEN extract legal details
                  → IF technical THEN extract tech details
```

**Pattern 2: Scoring → Priority-Based Routing**
```
Score urgency → IF urgent >= 9 THEN escalate to executives
              → IF urgent < 5 THEN route to junior team
```

**Pattern 3: Extract → Validate → Enrich**
```
Extract fields → Validate completeness → IF incomplete THEN request more info
                                       → IF complete THEN enrich with external data
```

**Pattern 4: Analyze → Recommend → Execute**
```
Analyze problem → Generate recommendations → Auto-execute low-risk actions
                                           → Route high-risk to human approval
```

### Real-World Applications

**1. Customer Support Automation**
- Classify ticket type
- Score urgency based on type
- Extract customer info & issue
- Generate resolution steps
- Route to appropriate team with SLA

**2. Contract Review Pipeline**
```
Classify contract type → Score risk level → Extract key terms (conditional) →
Identify red flags → Route to legal review (if risky)
```

**3. Content Moderation**
```
Detect content type → Score toxicity → Extract violations (if toxic) →
Generate moderation action → Route to human review (if borderline)
```

**4. Resume Screening**
```
Extract candidate info → Score qualifications → Assess culture fit →
Generate interview questions → Route to hiring manager (if qualified)
```

**5. Financial Document Processing**
```
Classify doc type (invoice/receipt/PO) → Extract amounts & dates →
Validate against rules → Flag anomalies → Route to AP/AR/Audit
```

### Performance Considerations

**Sequential Processing Tradeoff:**
- **Pro**: Each stage makes better decisions with accumulated context
- **Con**: Slower than single-stage (5 calls vs 1 call)
- **Mitigation**: Each call is faster (shorter prompts), net time comparable

**Optimal Pipeline Length:**
- **3-5 stages**: Sweet spot for most use cases
- **2 stages**: Usually better as single-stage
- **6+ stages**: Consider if all are necessary (diminishing returns)

**When to Parallelize:**
- Parallel processing WITHIN stages (4 copies of Stage 1 for 4 documents)
- NOT between stages (Stage 2 needs Stage 1 output)

### Key Takeaways

1. **Multi-stage pipelines chain LLM calls** where each stage builds on previous outputs
2. **Context accumulation** enables smarter decisions at each stage
3. **Conditional logic** allows different processing paths for different document types
4. **Error isolation** prevents cascade failures
5. **Single responsibility** per stage improves accuracy
6. **Production-grade** pattern used by companies processing millions of documents
7. **Auditability** tracks decision-making at every step

**You're about to build a system that:**
- Processes 15 diverse document types
- Makes 5 intelligent decisions per document
- Routes to correct departments automatically
- Handles errors gracefully
- Scales to thousands of documents

Let's get started!

---

## Architecture Overview

### High-Level Flow

```
┌─────────────────────────────────────────────────────────────────┐
│  INPUT: Raw incoming documents (15 diverse types)               │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│  STAGE 1: Classification                                        │
│  ├─ Build prompt: "What type of document is this?"             │
│  ├─ Call LLM                                                    │
│  └─ Parse: doc_type, confidence, reasoning                     │
└────────────────────┬────────────────────────────────────────────┘
                     │ doc_type passed forward →
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│  STAGE 2: Priority Scoring                                      │
│  ├─ Build prompt: "Rate urgency for this {doc_type}"          │
│  ├─ Call LLM                                                    │
│  └─ Parse: urgency (1-10), priority (LOW/MED/HIGH/CRIT)       │
└────────────────────┬────────────────────────────────────────────┘
                     │ doc_type + urgency passed forward →
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│  STAGE 3: Type-Specific Extraction (CONDITIONAL)                │
│  ├─ IF security_incident: Extract vuln type, severity          │
│  ├─ IF legal_threat: Extract issue, deadline, liability        │
│  ├─ IF critical_ticket: Extract customer, impact, value        │
│  └─ Parse: extracted_details (JSON)                            │
└────────────────────┬────────────────────────────────────────────┘
                     │ All previous fields passed forward →
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│  STAGE 4: Action Item Generation                                │
│  ├─ Build prompt: "Generate actions for {doc_type} with        │
│  │                  {priority} priority"                        │
│  ├─ Call LLM                                                    │
│  └─ Parse: actions[], action_count, requires_escalation        │
└────────────────────┬────────────────────────────────────────────┘
                     │ Full context passed forward →
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│  STAGE 5: Department Routing                                    │
│  ├─ Build prompt: "Route {doc_type} with {urgency} to dept"   │
│  ├─ Call LLM                                                    │
│  └─ Parse: primary_dept, escalate_to, cc_depts, sla_hours     │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│  OUTPUT: Fully processed & routed documents                     │
│  ├─ Classification: type, confidence                           │
│  ├─ Priority: urgency, priority level                          │
│  ├─ Extraction: type-specific details                          │
│  ├─ Actions: specific tasks to complete                        │
│  └─ Routing: department, escalation, SLA                       │
└─────────────────────────────────────────────────────────────────┘
```

### Key Architectural Decisions

1. **Sequential Processing**: Stages run one after another (not parallel)
   - Why: Each stage needs previous stage outputs
   - Trade-off: Slower but more intelligent

2. **Context Passing**: All fields flow forward through pipeline
   - Why: Later stages make better decisions with full context
   - Implementation: PDI automatically carries fields forward

3. **Conditional Logic**: Stage 3 branches based on doc_type
   - Why: Security incidents need different extraction than bug reports
   - Implementation: JavaScript if/else in prompt building

4. **Error Handling**: Each stage has fallback defaults
   - Why: One failure shouldn't break entire pipeline
   - Implementation: try/catch with sensible defaults

5. **JSON Output**: LLM returns structured data at each stage
   - Why: Easy to parse and validate
   - Implementation: `"format": "json"` in Ollama request

---

## The 5-Stage Pipeline

### Stage 1: Document Classification

**Purpose**: Identify what type of document this is

**Input**: Raw document text
**Output**: `doc_type`, `classification_confidence`, `classification_reasoning`

**Document Types**:
- `security_incident` - Vulnerability reports, breach notifications
- `legal_threat` - Cease & desist, trademark claims
- `critical_ticket` - High-value customer issues, billing errors
- `business_opportunity` - Partnership offers, sales leads
- `bug_report` - Software defects, crashes
- `feature_request` - Enhancement requests
- `general_inquiry` - Questions, basic support
- `positive_feedback` - Praise, testimonials

**Prompt Strategy**:
```javascript
"Classify the following document and return ONLY valid JSON:
{
  \"doc_type\": \"one of: security_incident, legal_threat, ...\",
  \"confidence\": 0.0 to 1.0,
  \"reasoning\": \"brief explanation\"
}

Classification Guidelines:
- security_incident: Vulnerability reports, breach notifications
- legal_threat: Cease & desist, trademark claims
...

Rules:
- Return ONLY valid JSON
- Choose the MOST SPECIFIC type
- Confidence > 0.8 means very sure

DOCUMENT:
{raw_text}"
```

**Success Criteria**:
- Confidence > 0.8 for clear cases
- Reasonable fallback to `general_inquiry` for ambiguous cases
- Reasoning provides clear justification

---

### Stage 2: Priority Scoring

**Purpose**: Determine urgency and priority level

**Input**: Raw text + `doc_type` from Stage 1
**Output**: `urgency` (1-10), `priority` (LOW/MEDIUM/HIGH/CRITICAL), `priority_reasoning`

**Priority Guidelines**:
- **CRITICAL** (Urgency 9-10): Immediate action required
- **HIGH** (Urgency 7-8): Action needed within hours
- **MEDIUM** (Urgency 4-6): Action within days
- **LOW** (Urgency 1-3): Can wait

**Type-Specific Urgency Ranges**:
- `security_incident`: Usually 8-10 (immediate threat)
- `legal_threat`: Usually 7-9 (legal deadlines matter)
- `critical_ticket`: 6-9 (depends on customer value & impact)
- `business_opportunity`: 5-7 (time-sensitive but not emergency)
- `bug_report`: 4-8 (depends on severity & user impact)
- `feature_request`: 2-5 (enhancement, not urgent)
- `general_inquiry`: 1-4 (routine support)
- `positive_feedback`: 1-2 (no urgency)

**Prompt Strategy**:
```javascript
"This document has been classified as: {doc_type}

Rate the urgency and assign priority. Return ONLY valid JSON:
{
  \"urgency\": 1-10 integer,
  \"priority\": \"LOW, MEDIUM, HIGH, or CRITICAL\",
  \"reasoning\": \"brief explanation\"
}

Urgency Guidelines by Type:
- security_incident: Usually 8-10 (immediate threat)
- legal_threat: Usually 7-9 (legal deadlines matter)
...

Consider:
- Business impact
- Time sensitivity
- Legal/compliance implications
- Customer value

DOCUMENT:
{raw_text}"
```

**Key Insight**: By telling the LLM what type of document this is (from Stage 1), it can apply type-specific urgency heuristics for better accuracy.

---

### Stage 3: Type-Specific Information Extraction (CONDITIONAL)

**Purpose**: Extract relevant details based on document type

**Input**: Raw text + `doc_type` + `urgency` from previous stages
**Output**: `extracted_details` (JSON string, structure varies by type)

**Extraction Logic** (Conditional):

**For `security_incident`**:
```json
{
  "vuln_type": "SQL injection, XSS, etc.",
  "severity": "Low, Medium, High, Critical",
  "affected_systems": "which systems",
  "disclosure_days": 90
}
```

**For `legal_threat`**:
```json
{
  "legal_issue": "trademark, copyright, etc.",
  "deadline_days": 10,
  "potential_liability": "$50,000+",
  "parties": "BrandProtect Legal Team"
}
```

**For `critical_ticket`**:
```json
{
  "customer_name": "GlobalMart Inc",
  "issue_summary": "Invoice discrepancy",
  "business_impact": "$144k/year account at risk",
  "account_value": "$144,000"
}
```

**For `business_opportunity`**:
```json
{
  "partner_name": "BigCorp",
  "opportunity_type": "White-label partnership",
  "deal_value": "$5M annually",
  "contact_person": "Jennifer Chen, VP BD"
}
```

**For other types** (generic):
```json
{
  "summary": "One sentence summary",
  "key_points": ["point 1", "point 2"],
  "mentions_deadline": false
}
```

**Implementation** (JavaScript):
```javascript
var extraction_prompt = "";

if (doc_type == "security_incident") {
  extraction_prompt = "Extract security incident details...";
} else if (doc_type == "legal_threat") {
  extraction_prompt = "Extract legal threat details...";
} else if (doc_type == "critical_ticket") {
  extraction_prompt = "Extract customer support details...";
} else {
  extraction_prompt = "Extract key details (generic)...";
}
```

**Key Insight**: Different document types require different information. Conditional extraction ensures we get relevant details for each case.

---

### Stage 4: Action Item Generation

**Purpose**: Generate specific, actionable tasks based on all previous context

**Input**: Raw text + `doc_type` + `urgency` + `priority` + `extracted_details`
**Output**: `actions_json` (array), `action_count`, `requires_escalation`

**Action Guidelines by Type**:

**security_incident**:
- Alert security team immediately
- Patch vulnerability within 48h
- Notify affected users
- Prepare disclosure statement

**legal_threat**:
- Forward to legal counsel
- Gather evidence/documentation
- Prepare response within deadline
- Brief executive team

**critical_ticket**:
- Assign to senior engineer
- Contact customer within 2h
- Investigate root cause
- Offer service credits if needed

**Prompt Strategy**:
```javascript
"This is a {doc_type} document with {priority} priority (urgency {urgency}/10).

Generate specific action items. Return ONLY valid JSON:
{
  \"actions\": [\"action 1\", \"action 2\", \"action 3\"],
  \"action_count\": integer,
  \"requires_escalation\": true or false
}

Action Guidelines:
- Be specific and actionable
- Include who should do what
- Mention timeframes if urgent
- CRITICAL/HIGH priority: immediate actions

Examples for {doc_type}:
{type-specific examples}

DOCUMENT:
{raw_text}"
```

**Key Insight**: Actions depend on type, urgency, AND extracted details. The LLM has full context to generate smart, specific actions.

---

### Stage 5: Department Routing

**Purpose**: Determine which team handles this and escalation path

**Input**: ALL previous stage outputs
**Output**: `primary_dept`, `escalate_to`, `cc_depts`, `sla_hours`

**Routing Rules by Type**:
- `security_incident` → Security (2-4h SLA), escalate to CTO if CRITICAL
- `legal_threat` → Legal (4-8h SLA), escalate to CEO if high liability
- `critical_ticket` → Support → Account Manager (4-24h SLA)
- `business_opportunity` → Sales/Partnerships (24-48h SLA)
- `bug_report` → Engineering (24-72h SLA)
- `feature_request` → Product (1-2 week SLA)
- `general_inquiry` → Support (1-2 day SLA)
- `positive_feedback` → Marketing (no SLA, log for testimonials)

**Escalation Triggers**:
- Urgency >= 9: Always escalate to executive
- Legal/Security CRITICAL: Escalate to C-level
- High account value (>$100k): CC account manager

**Prompt Strategy**:
```javascript
"Route this document to the appropriate department.

CONTEXT FROM PREVIOUS ANALYSIS:
- Document Type: {doc_type}
- Priority: {priority} (urgency {urgency}/10)
- Actions Required: {action_count} action items
- Requires Escalation: {requires_escalation}

Return ONLY valid JSON:
{
  \"primary_dept\": \"Security, Legal, Support, Engineering, Product, Sales, Marketing\",
  \"escalate_to\": \"CEO, CTO, CFO, VP or null\",
  \"cc_depts\": [\"dept1\", \"dept2\"] or [],
  \"sla_hours\": integer
}

Routing Rules:
- security_incident → Security (2-4h), CTO if CRITICAL
- legal_threat → Legal (4-8h), CEO if high liability
...

Escalation Triggers:
- Urgency >= 9: Escalate to executive
- Legal/Security CRITICAL: C-level
...

DOCUMENT:
{raw_text}"
```

**Key Insight**: With full context from 4 previous stages, the LLM makes intelligent routing decisions considering type, urgency, impact, and business rules.

---

## Step-by-Step Implementation

### Overview of Transformation Steps

The transformation contains **16 steps** organized into **5 stages**:

1. **Read Documents** (1 step)
2. **Stage 1** (3 steps): Build Prompt → Call LLM → Parse
3. **Stage 2** (3 steps): Build Prompt → Call LLM → Parse
4. **Stage 3** (3 steps): Build Prompt → Call LLM → Parse
5. **Stage 4** (3 steps): Build Prompt → Call LLM → Parse
6. **Stage 5** (3 steps): Build Prompt → Call LLM → Parse
7. **Write Output** (1 step)

Let's examine each stage in detail.

---

### Step 1: Read Documents

**Step Type**: CSV Input
**Purpose**: Read incoming documents

**Configuration**:
```
File path: ${Internal.Transformation.Filename.Directory}/../data/incoming_documents.csv
Separator: ,
Enclosure: "
Header: Yes
Encoding: UTF-8
```

**Fields**:
- `document_id` (String, 50)
- `source` (String, 100)
- `raw_text` (String, 50000)
- `received_date` (String, 20)

**Output**: 15 rows read

---

### Stage 1: Classification (Steps 2-4)

#### Step 2: Build Classification Prompt

**Step Type**: Modified JavaScript Value
**Purpose**: Create classification prompt

**JavaScript Code**:
```javascript
// STAGE 1: Document Classification
var stage1_prompt = "Classify the following document and return ONLY a valid JSON object:\n\n" +
  "{\n" +
  "  \"doc_type\": \"one of: security_incident, legal_threat, critical_ticket, business_opportunity, bug_report, feature_request, general_inquiry, positive_feedback\",\n" +
  "  \"confidence\": 0.0 to 1.0,\n" +
  "  \"reasoning\": \"brief explanation\"\n" +
  "}\n\n" +
  "Classification Guidelines:\n" +
  "- security_incident: Vulnerability reports, breach notifications\n" +
  "- legal_threat: Cease & desist, trademark claims\n" +
  "...\n\n" +
  "DOCUMENT SOURCE: " + source + "\n" +
  "DOCUMENT TEXT:\n" + raw_text;

var model_name = getVariable("MODEL_NAME", "llama3.2:3b");

var stage1_request = JSON.stringify({
  "model": model_name,
  "prompt": stage1_prompt,
  "stream": false,
  "format": "json",
  "options": {
    "temperature": 0.1,  // Low temperature for consistent classification
    "num_predict": 200
  }
});
```

**Output Field**: `stage1_request` (JSON string)

**Key Points**:
- Uses `getVariable()` to read MODEL_NAME parameter
- Temperature 0.1 for consistent, deterministic classification
- Short num_predict (200 tokens) since JSON output is small

#### Step 3: Call Ollama API - Classification

**Step Type**: REST Client
**Purpose**: Send classification request to LLM

**Configuration**:
```
URL: ${OLLAMA_URL}/api/generate
Method: POST
Body field: stage1_request
Result field: stage1_response
Status code field: stage1_code
Response time field: stage1_time
```

**Output Fields**:
- `stage1_response` (JSON string containing LLM response)
- `stage1_code` (200 if successful)
- `stage1_time` (milliseconds)

#### Step 4: Parse Classification Response

**Step Type**: Modified JavaScript Value
**Purpose**: Extract classification from LLM response

**JavaScript Code**:
```javascript
var doc_type = "general_inquiry"; // default fallback
var classification_confidence = 0.0;
var classification_reasoning = "";

try {
  var response = JSON.parse(stage1_response);
  var llmOutput = response.response;

  // Extract JSON from response
  var jsonStart = llmOutput.indexOf("{");
  var jsonEnd = llmOutput.lastIndexOf("}") + 1;

  if (jsonStart >= 0 && jsonEnd > jsonStart) {
    var jsonStr = llmOutput.substring(jsonStart, jsonEnd);
    var classResult = JSON.parse(jsonStr);

    doc_type = classResult.doc_type || "general_inquiry";
    classification_confidence = classResult.confidence || 0.0;
    classification_reasoning = classResult.reasoning || "";
  }
} catch(e) {
  doc_type = "general_inquiry";
  classification_confidence = 0.0;
  classification_reasoning = "Error parsing: " + e.message;
}
```

**Output Fields**:
- `doc_type` (String)
- `classification_confidence` (Number)
- `classification_reasoning` (String)

**Error Handling**: Defaults to `general_inquiry` if parsing fails

---

### Stage 2: Priority Scoring (Steps 5-7)

#### Step 5: Build Priority Prompt

**Key Difference from Stage 1**: Uses `doc_type` from Stage 1!

**JavaScript Code Snippet**:
```javascript
var stage2_prompt = "This document has been classified as: " + doc_type + "\n\n" +
  "Rate the urgency and assign priority. Return ONLY valid JSON:\n\n" +
  "{\n" +
  "  \"urgency\": 1-10 integer,\n" +
  "  \"priority\": \"LOW, MEDIUM, HIGH, or CRITICAL\",\n" +
  "  \"reasoning\": \"brief explanation\"\n" +
  "}\n\n" +
  "Urgency Guidelines by Type:\n" +
  "- security_incident: Usually 8-10 (immediate threat)\n" +
  "- legal_threat: Usually 7-9 (legal deadlines matter)\n" +
  "...\n\n" +
  "DOCUMENT TEXT:\n" + raw_text;

var stage2_request = JSON.stringify({
  "model": model_name,
  "prompt": stage2_prompt,
  "stream": false,
  "format": "json",
  "options": {
    "temperature": 0.2,  // Slightly higher for reasoning
    "num_predict": 200
  }
});
```

**Context Passing**: Notice how `doc_type` from Stage 1 is used in the prompt!

#### Steps 6-7: Call LLM & Parse (Similar Pattern)

Follows same pattern as Stage 1:
- Call REST API
- Parse response
- Extract fields: `urgency`, `priority`, `priority_reasoning`
- Default to urgency=5, priority="MEDIUM" on error

---

### Stage 3: Type-Specific Extraction (Steps 8-10)

#### Step 8: Build Extraction Prompt (CONDITIONAL)

**Key Feature**: Different prompts based on `doc_type`!

**JavaScript Code**:
```javascript
var extraction_prompt = "";

// CONDITIONAL LOGIC
if (doc_type == "security_incident") {
  extraction_prompt = "Extract security incident details. Return ONLY valid JSON:\n\n" +
    "{\n" +
    "  \"vuln_type\": \"SQL injection, XSS, etc.\",\n" +
    "  \"severity\": \"Low, Medium, High, Critical\",\n" +
    "  \"affected_systems\": \"which systems\",\n" +
    "  \"disclosure_days\": integer or null\n" +
    "}\n\n" +
    "DOCUMENT:\n" + raw_text;

} else if (doc_type == "legal_threat") {
  extraction_prompt = "Extract legal threat details. Return ONLY valid JSON:\n\n" +
    "{\n" +
    "  \"legal_issue\": \"trademark, copyright, etc.\",\n" +
    "  \"deadline_days\": integer or null,\n" +
    "  \"potential_liability\": \"brief estimate\",\n" +
    "  \"parties\": \"who is threatening us\"\n" +
    "}\n\n" +
    "DOCUMENT:\n" + raw_text;

} else if (doc_type == "critical_ticket") {
  extraction_prompt = "Extract customer support details. Return ONLY valid JSON:\n\n" +
    "{\n" +
    "  \"customer_name\": \"company or person\",\n" +
    "  \"issue_summary\": \"brief description\",\n" +
    "  \"business_impact\": \"revenue risk, etc.\",\n" +
    "  \"account_value\": \"$ amount if mentioned\"\n" +
    "}\n\n" +
    "DOCUMENT:\n" + raw_text;

} else {
  // Generic extraction for other types
  extraction_prompt = "Extract key details. Return ONLY valid JSON:\n\n" +
    "{\n" +
    "  \"summary\": \"one sentence summary\",\n" +
    "  \"key_points\": [\"point 1\", \"point 2\"],\n" +
    "  \"mentions_deadline\": true or false\n" +
    "}\n\n" +
    "DOCUMENT:\n" + raw_text;
}

var stage3_request = JSON.stringify({
  "model": model_name,
  "prompt": extraction_prompt,
  "stream": false,
  "format": "json",
  "options": {
    "temperature": 0.2,
    "num_predict": 300
  }
});
```

**This is the core of conditional multi-stage processing!**

#### Step 10: Parse Extraction

**Output**: `extracted_details` (JSON string)

Because the structure varies by type, we store as a JSON string rather than parsing into individual fields. Applications can parse as needed.

---

### Stage 4: Action Generation (Steps 11-13)

#### Step 11: Build Actions Prompt

**Context Used**: `doc_type`, `urgency`, `priority` from previous stages

**JavaScript Code Snippet**:
```javascript
var stage4_prompt = "This is a " + doc_type + " document with " + priority + " priority (urgency " + urgency + "/10).\n\n" +
  "Generate specific action items. Return ONLY valid JSON:\n\n" +
  "{\n" +
  "  \"actions\": [\"action 1\", \"action 2\", \"action 3\"],\n" +
  "  \"action_count\": integer,\n" +
  "  \"requires_escalation\": true or false\n" +
  "}\n\n" +
  "Action Guidelines:\n" +
  "- Be specific and actionable\n" +
  "- Include who should do what\n" +
  "- Mention timeframes if urgent\n\n";

// Type-specific examples
if (doc_type == "security_incident") {
  stage4_prompt += "Examples:\n" +
    "- Alert security team immediately\n" +
    "- Patch vulnerability within 48h\n" +
    "- Notify affected users\n\n";
}
// ... more type-specific examples

stage4_prompt += "DOCUMENT:\n" + raw_text;
```

**Temperature**: 0.3 (slightly creative for varied actions)

#### Step 13: Parse Actions

**Output Fields**:
- `actions_json` (JSON array of action strings)
- `action_count` (integer)
- `requires_escalation` (boolean)

---

### Stage 5: Routing (Steps 14-16)

#### Step 14: Build Routing Prompt

**Context Used**: ALL previous stages!

**JavaScript Code Snippet**:
```javascript
var stage5_prompt = "Route this document to the appropriate department.\n\n" +
  "CONTEXT FROM PREVIOUS ANALYSIS:\n" +
  "- Document Type: " + doc_type + "\n" +
  "- Priority: " + priority + " (urgency " + urgency + "/10)\n" +
  "- Actions Required: " + action_count + " action items\n" +
  "- Requires Escalation: " + requires_escalation + "\n\n" +
  "Return ONLY valid JSON:\n\n" +
  "{\n" +
  "  \"primary_dept\": \"Security, Legal, Support, Engineering, Product, Sales, Marketing\",\n" +
  "  \"escalate_to\": \"CEO, CTO, CFO, VP or null\",\n" +
  "  \"cc_depts\": [\"dept1\", \"dept2\"] or [],\n" +
  "  \"sla_hours\": integer\n" +
  "}\n\n" +
  "Routing Rules:\n" +
  "- security_incident → Security (2-4h), CTO if CRITICAL\n" +
  "...\n\n" +
  "Escalation Triggers:\n" +
  "- Urgency >= 9: Escalate to executive\n" +
  "...\n\n" +
  "DOCUMENT:\n" + raw_text;
```

**This is the payoff!** The LLM has complete context to make smart routing decisions.

#### Step 16: Parse Routing

**Output Fields**:
- `primary_dept` (String)
- `escalate_to` (String or empty)
- `cc_depts` (JSON array)
- `sla_hours` (Integer)
- `total_processing_time` (Sum of all stage response times)
- `stages_completed` (Always 5 for successful runs)

---

### Step 17: Write Processed Documents

**Step Type**: Text File Output
**Purpose**: Save fully enriched documents

**Output File**: `output/processed_documents_{date}_{time}.csv`

**Fields Written** (16 total):
1. `document_id`
2. `source`
3. `doc_type`
4. `classification_confidence`
5. `urgency`
6. `priority`
7. `extracted_details` (JSON)
8. `action_count`
9. `actions_json` (JSON array)
10. `requires_escalation`
11. `primary_dept`
12. `escalate_to`
13. `cc_depts` (JSON array)
14. `sla_hours`
15. `stages_completed`
16. `total_processing_time` (milliseconds)

---

## Running the Transformation

### Method 1: Command Line (Recommended)

```bash
cd /home/pentaho/LLM-PDI-Integration/workshops/workshop-06-multi-stage-pipeline/transformations

/home/pentaho/Pentaho/design-tools/data-integration/pan.sh \
  -file=multi_stage_pipeline.ktr \
  -param:OLLAMA_URL=http://localhost:11434 \
  -param:MODEL_NAME=llama3.2:3b \
  -level=Basic
```

**Expected Duration**: 12-18 minutes for 15 documents
- ~50-70 seconds per document
- 5 LLM calls per document
- ~10-14 seconds per LLM call

### Method 2: Spoon GUI

1. Open Spoon
2. File → Open → `multi_stage_pipeline.ktr`
3. Set parameters in Transformation Settings:
   - `OLLAMA_URL`: http://localhost:11434
   - `MODEL_NAME`: llama3.2:3b
4. Click Run (green play button)
5. Monitor progress in execution log

### Monitoring Progress

Watch the log for stage completions:
```
2025-02-28 16:00:00 - Read Documents.0 - Finished processing (I=16, O=0, R=0, W=15, U=0, E=0)
2025-02-28 16:00:05 - Stage 1: Parse Classification.0 - Finished processing (I=0, O=0, R=15, W=15, U=0, E=0)
2025-02-28 16:00:10 - Stage 2: Parse Priority.0 - Finished processing (I=0, O=0, R=15, W=15, U=0, E=0)
...
```

**Key Metrics**:
- `I`: Input rows
- `R`: Read (rows passed through)
- `W`: Written (rows output)
- `E`: Errors (should be 0)

---

## Analyzing Results

### Sample Output

**Input Document** (DOC-007):
```csv
document_id,source,raw_text
DOC-007,email,"Subject: Security Vulnerability Report
From: security-researcher@whitehat.com
Found SQL injection vulnerability in your login form.
Severity: Critical. Affects all users.
Timeline for public disclosure: 90 days"
```

**Output After Pipeline**:
```csv
document_id,source,doc_type,classification_confidence,urgency,priority,extracted_details,action_count,actions_json,requires_escalation,primary_dept,escalate_to,cc_depts,sla_hours,stages_completed,total_processing_time
DOC-007,email,security_incident,0.95,10,CRITICAL,"{\"vuln_type\":\"SQL injection\",\"severity\":\"Critical\",\"affected_systems\":\"login form\",\"disclosure_days\":90}",4,"[\"Alert security team immediately\",\"Patch SQL injection vulnerability within 48 hours\",\"Notify legal and PR teams\",\"Prepare disclosure statement\"]",true,Security,CTO,"[\"Legal\",\"PR\"]",2,5,67284
```

**What Happened**:
1. **Stage 1**: Classified as `security_incident` (confidence 0.95)
2. **Stage 2**: Urgency 10/10, CRITICAL priority
3. **Stage 3**: Extracted SQL injection details, 90-day disclosure
4. **Stage 4**: Generated 4 specific actions, flagged for escalation
5. **Stage 5**: Routed to Security → CTO, CC Legal & PR, 2-hour SLA
6. **Total Time**: 67 seconds (5 LLM calls)

### Key Insights from Results

#### Classification Accuracy

Examine `classification_confidence`:
- **> 0.9**: Very confident, usually correct
- **0.7 - 0.9**: Confident, review reasoning
- **< 0.7**: Uncertain, may need manual review

Check `classification_reasoning` for ambiguous cases.

#### Priority Distribution

Expected distribution:
- CRITICAL: ~10-15% (security, legal, high-value issues)
- HIGH: ~20-25% (urgent tickets, opportunities)
- MEDIUM: ~40-50% (bugs, requests)
- LOW: ~20-25% (inquiries, feedback)

If distribution is skewed, adjust urgency guidelines in Stage 2 prompt.

#### Routing Effectiveness

**Check**:
- Are security incidents routed to Security dept? ✓
- Are legal threats routed to Legal dept? ✓
- Are CRITICAL items escalated to executives? ✓
- Are SLAs appropriate for urgency levels? ✓

**Common Issues**:
- If everything routes to "Support", prompts are too generic
- If SLAs don't match urgency, adjust routing rules
- If escalations are too frequent, raise urgency threshold

#### Action Item Quality

Review `actions_json` for:
- **Specificity**: "Alert security team" is better than "Handle this"
- **Actionability**: "Patch within 48h" is better than "Fix the issue"
- **Ownership**: "CTO to brief board" is better than "Someone handle it"

If actions are too generic:
- Add more examples to Stage 4 prompt
- Increase temperature to 0.4 for more creative actions
- Include more context in prompt

---

## Advanced Concepts

### 1. Context Accumulation

Each stage adds information:
```
After Stage 1: We know TYPE
After Stage 2: We know TYPE + URGENCY
After Stage 3: We know TYPE + URGENCY + DETAILS
After Stage 4: We know TYPE + URGENCY + DETAILS + ACTIONS
After Stage 5: We know EVERYTHING
```

This is more powerful than a single LLM call because:
- Focused prompts → better results
- Each stage validates/builds on previous
- Errors isolated to one stage
- Auditable decision trail

### 2. Conditional Branching

Stage 3 demonstrates conditional logic:
```javascript
if (doc_type == "security_incident") {
  // Extract vulnerability details
} else if (doc_type == "legal_threat") {
  // Extract legal details
} else {
  // Generic extraction
}
```

**Extension Ideas**:
- Add more document types with specific extraction
- Branch on urgency (different actions for CRITICAL vs LOW)
- Branch on extracted details (high account value gets special handling)

### 3. Error Recovery Strategy

**Graceful Degradation**:
```javascript
try {
  // Parse LLM response
  doc_type = parseResult.doc_type;
} catch(e) {
  // Fallback to safe default
  doc_type = "general_inquiry";
  // Log error but continue processing
}
```

**Progressive Fallbacks**:
- Stage 1 fails → Default to "general_inquiry", continue
- Stage 2 fails → Default urgency=5, priority="MEDIUM", continue
- Stage 3 fails → Skip extraction, use "{}", continue
- Stage 4 fails → Default actions=["Review manually"], continue
- Stage 5 fails → Route to "Support", no escalation

**Result**: Even with multiple failures, pipeline produces useful output

### 4. Performance Optimization

**Current Performance**: ~50-70 seconds/document (5 sequential LLM calls)

**Optimization Strategies**:

**Strategy 1: Reduce LLM Calls**
- Combine Stages 1+2 into single call (classification + priority)
- Combine Stages 4+5 into single call (actions + routing)
- Result: 3 calls instead of 5 (40% faster)

**Strategy 2: Cache Common Classifications**
- If 50% of docs are "general_inquiry", detect with regex before LLM
- Only call LLM for ambiguous cases
- Result: 50% fewer documents need processing

**Strategy 3: Parallel Processing (Advanced)**
- Process multiple documents in parallel (increase step copies)
- Requires adequate RAM and model capacity
- Result: Higher throughput

**Strategy 4: Model Selection**
- Use smaller/faster model (e.g., phi-2) for simple stages (classification)
- Use larger model only for complex extraction
- Result: Faster simple stages

**Example: Optimized 3-Stage Pipeline**
```
Stage 1: Classify + Priority (combined)
Stage 2: Extract + Actions (combined, conditional)
Stage 3: Route

Result: ~25-30 seconds per document (60% faster!)
```

### 5. Extending the Pipeline

**Add Stage 6: Sentiment Analysis**
- Analyze tone (angry, frustrated, happy)
- Adjust routing/SLA based on sentiment
- Example: Angry customer with critical ticket → faster SLA

**Add Stage 7: Similar Document Matching**
- Find similar past documents
- Suggest solutions based on history
- Example: "This looks like ticket #45782 from last month"

**Add Stage 8: Auto-Response Generation**
- Draft response email
- Personalize based on extracted details
- Example: "Dear {customer_name}, regarding {issue_summary}..."

**The beauty of multi-stage**: Easy to add stages without rewriting everything!

---

## Troubleshooting

### Issue 1: Classification Always Returns "general_inquiry"

**Symptoms**:
- 90%+ of documents classified as `general_inquiry`
- Confidence scores are low (<0.6)

**Causes**:
- Classification guidelines too vague
- Not enough examples in prompt
- Model not understanding domain

**Fixes**:
1. Add more specific examples to Stage 1 prompt
2. Include sample documents for each type
3. Lower temperature to 0.05 for more deterministic classification
4. Try a larger model (llama3:8b)

**Test**:
```javascript
// Add this to Stage 1 prompt
"Examples:
- Security incident: 'Found SQL injection in login form'
- Legal threat: 'Cease use of our trademark immediately'
- Critical ticket: 'Your service cost us $50k in downtime'
"
```

### Issue 2: All Documents Get Same Priority

**Symptoms**:
- Everything is MEDIUM priority
- Urgency scores cluster around 5

**Causes**:
- Stage 2 not using doc_type context
- Priority guidelines too conservative
- Model playing it safe

**Fixes**:
1. Verify `doc_type` is being passed to Stage 2 prompt
2. Adjust urgency ranges (make them more distinct)
3. Add real examples with urgency scores
4. Increase temperature to 0.3 for more variation

**Verification**:
Check Stage 2 prompt includes:
```javascript
"This document has been classified as: " + doc_type
```

### Issue 3: Extraction Returns Empty JSON

**Symptoms**:
- `extracted_details` is `{}`
- Stage 3 response parsing fails

**Causes**:
- LLM returning malformed JSON
- Extraction prompt unclear
- Model hallucinating non-JSON responses

**Fixes**:
1. Add stricter JSON format requirement
2. Use `"format": "json"` in Ollama request (already included)
3. Add JSON schema to prompt
4. Increase num_predict to 400 (more room for output)

**Debug**:
Add logging to see raw `stage3_response`:
```javascript
print("Stage 3 raw response: " + stage3_response);
```

### Issue 4: Actions Are Too Generic

**Symptoms**:
- Actions like "Handle this", "Fix it", "Follow up"
- No specific timeframes or owners

**Causes**:
- Not enough context in Stage 4 prompt
- Missing type-specific examples
- Temperature too low (not creative enough)

**Fixes**:
1. Include extracted_details in Stage 4 prompt
2. Add detailed action examples for each type
3. Increase temperature to 0.4
4. Explicitly ask for specifics: "Include who, what, when"

**Enhanced Prompt**:
```javascript
"Generate SPECIFIC actions. Each action should include:
- WHO: Which team/person
- WHAT: Specific task
- WHEN: Deadline or timeframe

Bad example: 'Fix the issue'
Good example: 'Security team to patch SQL injection within 48 hours'
"
```

### Issue 5: Routing Sends Everything to "Support"

**Symptoms**:
- 100% of documents route to Support dept
- No escalations even for CRITICAL items

**Causes**:
- Stage 5 not receiving previous stage data
- Routing rules not clear enough
- Model defaulting to safest option

**Fixes**:
1. Verify all context variables are populated
2. Make routing rules more explicit
3. Add penalty for wrong routing:
   ```
   "Important: Routing to Support when it should go to Security/Legal
    will cause delays and customer dissatisfaction."
   ```
4. Include consequences in prompt

**Verification**:
Check Stage 5 prompt includes ALL context:
```javascript
"CONTEXT:
- Document Type: " + doc_type + "
- Priority: " + priority + "
- Urgency: " + urgency + "
- Actions Required: " + action_count + "
- Requires Escalation: " + requires_escalation
```

### Issue 6: Pipeline is Too Slow

**Symptoms**:
- 15 documents take 20+ minutes
- >80 seconds per document

**Causes**:
- Model not cached (cold starts)
- num_predict too high
- Ollama not configured optimally

**Fixes**:
1. Keep model loaded: `ollama run llama3.2:3b` (leave running)
2. Reduce num_predict:
   - Stage 1/2/5: 150 tokens
   - Stage 3/4: 300 tokens
3. Use GPU if available
4. Process fewer documents in test runs

**Benchmark**:
```bash
# Test single document performance
time curl -X POST http://localhost:11434/api/generate \
  -d '{"model":"llama3.2:3b","prompt":"Classify this: Hello world","stream":false}'

# Should be < 5 seconds for simple prompts
```

### Issue 7: Transformation Fails to Start

**Symptoms**:
- Error: "step copies does not resolve to positive value"
- XML parsing errors

**Causes**:
- Missing `<copies>` element in step definition
- Malformed XML

**Fixes**:
1. Validate XML:
   ```bash
   python3 -c "import xml.etree.ElementTree as ET; \
     ET.parse('multi_stage_pipeline.ktr'); \
     print('XML valid')"
   ```
2. Check each `<step>` has `<copies>1</copies>`
3. Verify special characters are escaped (`&` → `&amp;`, `<` → `&lt;`, `>` → `&gt;`)

---

## Production Considerations

### 1. Scalability

**Current**: Sequential processing, ~50-70 sec/document

**For Production**:

**High Volume (1000+ docs/day)**:
- Use step copies for parallel processing
- Cache model in memory
- Consider distributed PDI cluster
- Use faster model for simple stages

**Configuration**:
```xml
<copies>4</copies>  <!-- Process 4 documents in parallel -->
```

**Monitoring**:
- Track average processing time
- Alert if queue backs up
- Monitor Ollama CPU/RAM usage

### 2. Error Handling

**Current**: Try/catch with fallbacks

**For Production**:

**Add Error Logging**:
```javascript
if (classification_confidence < 0.5) {
  writeLog("Low confidence classification: " + document_id, "WARN");
}
```

**Add Error Output**:
- Create separate output for failed documents
- Route to manual review queue
- Track error rates by stage

**Example**:
```xml
<!-- Add Filter Values step after each stage -->
<step>
  <name>Check Stage 1 Errors</name>
  <type>FilterRows</type>
  <send_true_to>Stage 2: Build Priority Prompt</send_true_to>
  <send_false_to>Error Output</send_false_to>
  <condition>
    <field>classification_confidence</field>
    <condition>&gt;=</condition>
    <value>0.5</value>
  </condition>
</step>
```

### 3. Monitoring & Alerting

**Metrics to Track**:
- Documents processed per hour
- Average processing time per stage
- Error rate by stage
- Classification distribution
- Priority distribution
- SLA compliance

**Alerting Thresholds**:
- Processing time > 90 seconds/doc → Alert
- Error rate > 5% → Alert
- Classification confidence < 0.6 for >20% docs → Alert
- CRITICAL documents not processed within SLA → Page on-call

**Implementation**:
- Log metrics to database
- Create dashboard (Grafana, etc.)
- Set up email/Slack alerts

### 4. Model Management

**Model Versioning**:
- Pin to specific model version
- Test new models before deploying
- Keep fallback to previous version

**Example**:
```bash
# Production uses pinned version
OLLAMA_MODEL=llama3.2:3b@sha256:abc123...

# Test new version in staging first
OLLAMA_MODEL=llama3.2:3b@sha256:def456...
```

**Model Updates**:
- Schedule during low-traffic windows
- A/B test with small percentage of traffic
- Monitor quality metrics after update

### 5. Security

**Sensitive Data Handling**:
- Sanitize PII before logging
- Encrypt data at rest
- Use secure Ollama deployment (not exposed to internet)
- Audit document access

**Example Sanitization**:
```javascript
var sanitized_text = raw_text.replace(/\b\d{3}-\d{2}-\d{4}\b/g, "[SSN]");
// Remove SSNs before logging
```

**Access Control**:
- Restrict who can modify transformations
- Audit trail for routing decisions
- Separate environments (dev/staging/prod)

### 6. Cost Optimization

**Current Cost**: Free (local Ollama)

**For Scale**:

**Option 1: Scale Local**
- Add GPUs for faster inference
- Use model quantization (4-bit, 8-bit)
- Cache frequent classifications

**Option 2: Cloud API (OpenAI, Anthropic)**
- Pay per token
- Faster inference
- No infrastructure management
- Cost: $0.01 - $0.10 per document

**Cost Comparison**:
```
Local Ollama:
- Hardware: $2000 GPU one-time
- Power: $50/month
- Cost per doc: ~$0.001

Cloud API:
- No upfront cost
- Pay per use: $0.05/doc average
- Cost at 1000 docs/day: $1500/month
```

**Recommendation**: Start local, move to cloud if >10K docs/day

### 7. Quality Assurance

**Testing Strategy**:

**Unit Tests** (per stage):
- Stage 1: Classification accuracy on labeled test set
- Stage 2: Priority assignment correctness
- Stage 3: Extraction completeness
- Stage 4: Action relevance
- Stage 5: Routing accuracy

**Integration Tests**:
- End-to-end pipeline with known inputs
- Verify all fields populated
- Check processing time within SLA

**Regression Tests**:
- Test set of 100 documents
- Run after any prompt changes
- Compare results to baseline

**Example Test**:
```bash
# Run transformation on test data
pan.sh -file=multi_stage_pipeline.ktr \
  -param:INPUT_FILE=test_documents.csv \
  -param:OUTPUT_FILE=test_results.csv

# Verify results
python3 validate_results.py test_results.csv expected_results.csv
```

### 8. Documentation

**For Production**:

**Document These**:
- Prompt templates (all 5 stages)
- Classification types and criteria
- Routing rules and SLAs
- Error handling procedures
- Escalation paths
- Model version and configuration

**Runbooks**:
- How to restart pipeline
- How to handle backlog
- How to update prompts
- How to investigate errors

**Example Runbook Entry**:
```markdown
## Issue: Documents Stuck in Pipeline

Symptoms: No new documents processed in 10+ minutes

Diagnosis:
1. Check Ollama status: `systemctl status ollama`
2. Check PDI transformation logs
3. Check for resource exhaustion (RAM/CPU)

Resolution:
1. If Ollama stopped: `sudo systemctl restart ollama`
2. If PDI hung: Kill and restart transformation
3. If resource issue: Add more workers or reduce load
```

---

## Summary

Congratulations! You've learned to build advanced **multi-stage LLM pipelines** that:

✅ Chain 5 sequential AI calls together
✅ Pass context between stages for better decisions
✅ Implement conditional logic based on classifications
✅ Handle errors gracefully with fallbacks
✅ Process documents 50-70 seconds each
✅ Route intelligently to appropriate teams
✅ Generate specific, actionable items

**Key Takeaways**:

1. **Multi-stage > Single-stage**: Focused prompts beat complex ones
2. **Context Accumulation**: Each stage adds value
3. **Conditional Processing**: Different types need different handling
4. **Graceful Degradation**: Defaults keep pipeline running
5. **Production-Ready**: Patterns scale to thousands of documents

**Next Steps**:

1. **Extend the Pipeline**: Add sentiment, auto-response, similarity matching
2. **Optimize Performance**: Combine stages, cache results, parallel processing
3. **Apply to Your Domain**: Adapt for contracts, resumes, support tickets, etc.
4. **Integrate with Systems**: Connect to ticketing, CRM, alerting tools
5. **Build Feedback Loop**: Track outcomes, refine prompts, improve accuracy

This pattern is used in production by companies processing millions of documents. You now have the skills to build similar systems!

---

**Workshop Duration**: 90-120 minutes
**Difficulty**: Advanced (4/5)
**Prerequisites**: Workshops 1-5

**Questions or Issues?**
Review the Troubleshooting section or consult the main README.

Happy pipeline building! 🚀
