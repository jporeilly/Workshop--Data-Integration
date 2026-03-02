# Workshop 1: Customer Review Sentiment Analysis

## Quick Start Guide

### 📚 Main Documentation
**Primary document:** [`docs/workshop_1_sentiment_analysis.md`](docs/workshop_1_sentiment_analysis.md)

**Status:** ✅ Tested, Verified, and Working (Version 2.0)

### 🎯 What This Workshop Teaches

Build an ETL pipeline that uses AI to analyze customer sentiment:
- Read customer reviews from CSV
- Send reviews to local LLM (Ollama) for analysis
- Extract structured sentiment data (positive/negative/neutral)
- Save enriched results with scores, confidence, and insights

### ⚡ Quick Test (3 reviews in ~1 minute)

```bash
# 1. Make sure Ollama is running
curl http://localhost:11434/api/tags

# 2. Run the transformation
cd /home/pentaho/Pentaho/design-tools/data-integration

./pan.sh \
  -file=/home/pentaho/LLM-PDI-Integration/workshops/workshop-01-sentiment-analysis/transformations/sentiment_analysis.ktr \
  -param:MODEL_NAME=llama3.2:3b \
  -param:OLLAMA_URL=http://localhost:11434 \
  -level=Minimal

# 3. Check results
ls -lth datasets/sentiment_results_*.csv | head -1
```

### 📁 Workshop Structure

```
workshop-01-sentiment-analysis/
├── data/
│   └── customer_reviews.csv          # INPUT: 3 sample reviews
├── datasets/
│   └── sentiment_results_*.csv       # OUTPUT: Results with AI insights
├── docs/
│   ├── workshop_1_sentiment_analysis.md  # ⭐ MAIN DOCUMENTATION
│   └── CONSOLIDATED_CHANGES.md       # What's new in v2.0
└── transformations/
    ├── sentiment_analysis.ktr        # Basic transformation
    └── sentiment_analysis_optimized.ktr  # Parallel processing version
```

### ✅ What Works (Verified)

- **Input:** 3 customer reviews (1 positive, 1 negative, 1 neutral)
- **Processing:** ~23 seconds per review
- **Output:** All sentiment fields correctly populated
- **Accuracy:** 100% - all reviews correctly classified
- **Response codes:** All 200 (success)

### 🔑 Critical Configuration Points

1. **Use REST Client step** (NOT HTTP Client)
2. **File paths:** Input from `data/`, output to `datasets/`
3. **JavaScript:** Use `getVariable("PARAM", "default")` for parameters
4. **Timeouts:** Socket timeout 300000ms (5 minutes)
5. **Headers:** Content-Type: application/json

### 📊 Sample Results

| Review | Sentiment | Score | Confidence |
|--------|-----------|-------|------------|
| "This laptop exceeded my expectations!" | positive | 0.9 | 90% |
| "The mouse stopped working after 2 weeks" | negative | -0.6 | 80% |
| "Good product overall, gets a bit warm" | neutral | -0.33 | 70% |

### 🐛 Common Issues & Quick Fixes

| Error | Fix |
|-------|-----|
| **405 Method Not Allowed** | Change to REST Client step |
| **400 Bad Request** | Use `getVariable()` in JavaScript |
| **File Not Found** | Check path: `data/customer_reviews.csv` |
| **Connection Refused** | Start Ollama: `sudo systemctl start ollama` |

### 📖 Documentation Sections

The main workshop document includes:

1. **Architecture Overview** - Complete workflow explanation
2. **Environment Setup** - Install Ollama and verify
3. **Understanding Ollama API** - How the API works
4. **Building the Transformation** - Step-by-step guide
5. **Running & Testing** - Execute with real data
6. **Analyzing Results** - Verified test results
7. **Troubleshooting** - Solutions for all common errors
8. **Appendices** - Workflow details, models, prompts, step reference

### 🎓 Learning Outcomes

After completing this workshop, you will:

✅ Understand how to integrate LLMs into ETL pipelines
✅ Know how to use REST APIs from PDI
✅ Master prompt engineering for structured output
✅ Parse JSON responses effectively
✅ Handle LLM-specific challenges (timeouts, parameters)
✅ Build production-ready sentiment analysis workflows

### 🚀 Next Steps

1. **Start here:** Read [`docs/workshop_1_sentiment_analysis.md`](docs/workshop_1_sentiment_analysis.md)
2. **Test with sample data:** 3 reviews (~69 seconds)
3. **Try your own data:** Export customer reviews
4. **Explore optimization:** Use `sentiment_analysis_optimized.ktr`
5. **Move to Workshop 2:** Data quality enhancement with LLMs

### 📝 Prerequisites

- Ubuntu 24.04
- Pentaho Data Integration (PDI) 9.x or later
- Ollama installed with llama3.2:3b model
- Basic PDI knowledge

### 💡 Key Takeaways

- **LLM integration is straightforward** with REST APIs
- **Prompt engineering matters** - be specific and structured
- **JSON format is essential** for parsing AI outputs
- **Performance varies** - 20-30 seconds per review is normal
- **Error handling is crucial** - always check response codes

### 📞 Support

**Issues?**
1. Check the Troubleshooting section in main docs
2. Verify configuration matches the checklist
3. Test Ollama API directly with curl
4. Review logs in PDI execution output

### 📅 Version Information

- **Workshop Version:** 2.0
- **Last Updated:** 2026-02-27
- **Status:** ✅ Tested and Verified Working
- **Test Environment:** Ubuntu 24.04, PDI 11.0, Ollama llama3.2:3b

---

**Ready to start?** Open [`docs/workshop_1_sentiment_analysis.md`](docs/workshop_1_sentiment_analysis.md) and follow the step-by-step guide!
