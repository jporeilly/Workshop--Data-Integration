# Workshop 5: Text Summarization

Automatically generate concise summaries, bullet points, key takeaways, and action items from long documents using LLMs and Pentaho Data Integration.

## Quick Start

```bash
# 1. Ensure Ollama is running
curl http://localhost:11434/api/tags

# 2. Run basic transformation
cd /home/pentaho/LLM-PDI-Integration/workshops/workshop-05-text-summarization/transformations
/opt/pentaho/data-integration/pan.sh -file=text_summarization.ktr

# 3. Run optimized version (3-4x faster)
/opt/pentaho/data-integration/pan.sh -file=text_summarization_optimized.ktr

# 4. View results
ls -lt ../data/summaries_*.csv | head -1
cat <latest_file> | head -5
```

## What This Workshop Covers

- Summarize 10 document types: meeting notes, incident reports, research papers, customer complaints, project proposals, press releases, email threads, annual reports, technical docs, legal contracts
- Generate structured summaries with 4 output components
- Build effective summarization prompts for consistent results
- Optimize performance with parallel processing (3-4x speedup)
- Achieve 85-95% compression ratio while preserving key information

## Sample Input

```csv
document_id,document_type,title,full_text
1,meeting_notes,Q1 2025 Product Strategy Meeting,"Meeting held on February 15, 2025, in Conference Room A. Attendees: Sarah Johnson (CEO), Michael Chen (CTO)... [2,487 characters]"
```

## Sample Output

```csv
document_id,document_type,title,summary,bullet_points,key_takeaways,action_items,original_length,summary_length,compression_ratio
1,meeting_notes,Q1 2025 Product Strategy Meeting,"Q1 2025 product strategy meeting focused on roadmap priorities...",["Revenue exceeded Q4 targets by 23%","AI analytics platform launching March 15th",...],["Focus on enterprise customer feature requests","$2.5M marketing budget approved"],["Michael to finalize API docs by March 1st","Jennifer to create customer advisory board by Feb 28th",...],2487,312,0.87
```

## Output Components

Each document summary includes four structured components:

1. **Summary** - Concise 2-3 sentence overview capturing main purpose and key outcomes
2. **Bullet Points** - 4-7 important facts, decisions, or findings from the document
3. **Key Takeaways** - 2-4 critical insights or conclusions that matter most
4. **Action Items** - 0-6 specific tasks, deadlines, or follow-up actions (if applicable)

## Files

- `data/documents_to_summarize.csv` - 10 sample documents across diverse types
- `transformations/text_summarization.ktr` - Basic summarization transformation
- `transformations/text_summarization_optimized.ktr` - Optimized version with parallel processing
- `docs/workshop_5_text_summarization.md` - Complete workshop guide

## Performance

| Version | Time (10 docs) | Speedup | Compression Ratio |
|---------|----------------|---------|-------------------|
| Basic | 50-70 seconds | 1x | 85-95% |
| Optimized | 12-20 seconds | **3-4x** | 85-95% |

## Document Types Processed

1. **Meeting Notes** - Discussions, decisions, action items
2. **Incident Reports** - Technical issues, root cause, resolution
3. **Research Papers** - Studies, findings, conclusions
4. **Customer Complaints** - Issues, impact, required actions
5. **Project Proposals** - Goals, approach, budget, timeline
6. **Press Releases** - Announcements, partnerships, achievements
7. **Email Threads** - Communications, blockers, requests
8. **Annual Reports** - Financial results, achievements, strategy
9. **Technical Documentation** - Guides, APIs, procedures
10. **Legal Contracts** - Terms, obligations, rights

## Use Cases

- Executive briefings: Summarize lengthy reports for quick decision-making
- Customer service: Extract key issues and action items from complaints
- Knowledge management: Create searchable summaries of documentation
- Email processing: Automatically summarize long email threads
- Research synthesis: Condense papers and articles into digestible insights
- Meeting follow-up: Generate action item lists from meeting notes

## Documentation

See [docs/workshop_5_text_summarization.md](docs/workshop_5_text_summarization.md) for:
- Detailed workshop guide (60-90 minutes)
- Understanding text summarization techniques
- Step-by-step transformation building
- Advanced techniques (multi-document, hierarchical summaries)
- Performance tuning and troubleshooting
- Integration patterns and best practices

## Parameters

**Basic Transformation:**
- `OLLAMA_URL` - Ollama API endpoint (default: http://localhost:11434/api/generate)
- `MODEL_NAME` - LLM model (default: llama3.2:3b)

**Optimized Transformation:**
- `OLLAMA_URL` - Ollama API endpoint
- `MODEL_NAME` - LLM model
- `KEEP_ALIVE` - Keep model in memory (default: 15m)
- `STEP_COPIES` - Parallel API calls (default: 4)

**Model Parameters:**
- `temperature` - 0.2 (consistent, focused summaries)
- `num_predict` - 800 (sufficient for structured output)

## Next Steps

1. Review complete workshop guide: `docs/workshop_5_text_summarization.md`
2. Run basic transformation to understand the workflow
3. Run optimized version to see performance improvements
4. Customize output components for your use case
5. Build summarization into your document processing pipelines
