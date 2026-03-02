# LLM-PDI Integration Workshops

Hands-on workshops for integrating Large Language Models with Pentaho Data Integration on Ubuntu 24.04.

## 🚀 Quick Start

```bash
# Install & configure
cd scripts
./install_ollama.sh
./configure_intel_cpu.sh
./test_ollama_api.sh

# Start Workshop 1
cd ../workshops/workshop-01-sentiment-analysis
# Open transformations/sentiment_analysis_optimized.ktr in PDI
```

## 📁 Project Structure

```
LLM-PDI-Integration/
├── scripts/          # Installation & testing (5 scripts)
├── docs/             # All documentation (6 guides)
└── workshops/        # Individual workshops
    ├── workshop-01-sentiment-analysis/
    │   ├── data/                        # Sample data
    │   ├── transformations/             # PDI files
    │   └── docs/                        # Tutorial
    └── workshop-02-data-quality/
        ├── data/                        # Sample data with quality issues
        ├── transformations/             # PDI files
        └── docs/                        # Tutorial
```

**Simple. Clean. Just 3 folders.**

## 🎓 Workshop 1: Sentiment Analysis

**Level:** Beginner | **Time:** 60-90 min | **Status:** ✅ Ready

Build an AI-powered sentiment analysis pipeline for customer reviews.

**Location:** `workshops/workshop-01-sentiment-analysis/`

**Files:**
- `data/customer_reviews.csv` - 20 sample reviews
- `transformations/sentiment_analysis.ktr` - Basic version (learning)
- `transformations/sentiment_analysis_optimized.ktr` - Optimized (production)
- `docs/workshop_1_sentiment_analysis.md` - Full tutorial

**To run:**
1. Open `transformations/sentiment_analysis_optimized.ktr` in PDI
2. Press F9 to run
3. Results saved to `data/sentiment_results_*.csv`

**Performance:**
- Basic: ~50 seconds for 20 reviews
- Optimized: ~14 seconds (**3.5x faster**)

## 🎓 Workshop 2: Data Quality Enhancement

**Level:** Beginner to Intermediate | **Time:** 60-90 min | **Status:** ✅ Ready

Use AI to automatically clean and standardize messy customer data.

**Location:** `workshops/workshop-02-data-quality/`

**Files:**
- `data/customer_data_raw.csv` - 20 records with quality issues
- `transformations/data_quality_enhancement.ktr` - Basic version (learning)
- `transformations/data_quality_enhancement_optimized.ktr` - Optimized (production)
- `docs/workshop_2_data_quality.md` - Full tutorial

**What it fixes:**
- Name formatting (john smith → John Smith)
- Email validation (james@ → INVALID)
- Phone standardization (555.123.4567 → +1-555-123-4567)
- Address formatting (inconsistent → Street, City, State ZIP)
- Company name cleaning (acme corp → Acme Corp)

**To run:**
1. Open `transformations/data_quality_enhancement_optimized.ktr` in PDI
2. Press F9 to run
3. Results saved to `data/customer_data_enhanced_*.csv`

**Performance:**
- Basic: ~60-80 seconds for 20 records
- Optimized: ~15-20 seconds (**3-4x faster**)

## 🎓 Workshop 3: Data Enrichment

**Level:** Intermediate | **Time:** 60-90 min | **Status:** ✅ Ready

Use AI to intelligently infer missing data fields from available context.

**Location:** `workshops/workshop-03-data-enrichment/`

**Files:**
- `data/customer_data_incomplete.csv` - 20 records with missing fields
- `transformations/data_enrichment.ktr` - Basic version (learning)
- `transformations/data_enrichment_optimized.ktr` - Optimized (production)
- `docs/workshop_3_data_enrichment.md` - Full tutorial

**What it infers:**
- Missing contact information (phone, email, website)
- Missing address components (city, state, country)
- Industry classification (Technology, Finance, Healthcare, etc.)
- Company size estimation (1-10, 11-50, 51-200, etc.)
- Contextual data completion from partial information

**To run:**
1. Open `transformations/data_enrichment_optimized.ktr` in PDI
2. Press F9 to run
3. Results saved to `data/customer_data_enriched_*.csv`

**Performance:**
- Basic: ~60-80 seconds for 20 records
- Optimized: ~15-25 seconds (**3-4x faster**)

## 🎓 Workshop 4: Named Entity Recognition

**Level:** Intermediate | **Time:** 60-90 min | **Status:** ✅ Ready

Extract and classify named entities from unstructured text using AI.

**Location:** `workshops/workshop-04-named-entity-recognition/`

**Files:**
- `data/unstructured_text.csv` - 20 diverse documents (emails, contracts, reports)
- `transformations/named_entity_recognition.ktr` - Basic version (learning)
- `transformations/named_entity_recognition_optimized.ktr` - Optimized (production)
- `docs/workshop_4_named_entity_recognition.md` - Full tutorial

**Entity types extracted (10):**
- PERSON - Names of people (Sarah Johnson, Dr. Michael Chen)
- ORGANIZATION - Companies, institutions (Acme Corp, Stanford University)
- LOCATION - Cities, addresses (San Francisco, 123 Main St)
- DATE - Dates and times (December 15th 2024, 10:30 AM PST)
- PRODUCT - Product names (iPhone 16, UltraBook Pro X1)
- MONEY - Currency amounts ($125,000, £250,000 GBP)
- CONTACT - Emails, phones (user@company.com, 555-123-4567)
- ID - Identifiers (CUST-98765, INV-2024-0089)
- TECHNOLOGY - Software, platforms (AWS, Python, TensorFlow)
- POSITION - Job titles (CEO, Project Manager, CFO)

**To run:**
1. Open `transformations/named_entity_recognition_optimized.ktr` in PDI
2. Press F9 to run
3. Results saved to `data/entities_extracted_*.csv`

**Performance:**
- Basic: ~60-80 seconds for 20 documents
- Optimized: ~15-25 seconds (**3-4x faster**)

## 🎓 Workshop 5: Text Summarization

**Level:** Intermediate | **Time:** 60-90 min | **Status:** ✅ Ready

Automatically summarize long documents into concise summaries with structured insights.

**Location:** `workshops/workshop-05-text-summarization/`

**Files:**
- `data/documents_to_summarize.csv` - 10 diverse long documents (300-900 words each)
- `transformations/text_summarization.ktr` - Basic version (learning)
- `transformations/text_summarization_optimized.ktr` - Optimized (production)
- `docs/workshop_5_text_summarization.md` - Full tutorial

**What it generates:**
- Summary - Concise 2-3 sentence overview
- Bullet Points - 4-7 key facts and decisions
- Key Takeaways - 2-4 main insights and implications
- Action Items - Specific tasks and deadlines (when applicable)

**Document types processed (10):**
- Meeting notes, incident reports, research papers, customer complaints
- Project proposals, press releases, email threads, annual reports
- Technical documentation, legal contracts

**To run:**
1. Open `transformations/text_summarization_optimized.ktr` in PDI
2. Press F9 to run
3. Results saved to `data/summaries_*.csv`

**Performance:**
- Basic: ~50-70 seconds for 10 documents
- Optimized: ~12-20 seconds (**3-4x faster**)
- Compression ratio: 85-95% (from full document to summary)

## 🛠️ Scripts

All in `scripts/` directory:

| Script | Purpose |
|--------|---------|
| `install_ollama.sh` | Install Ollama + download models |
| `configure_intel_cpu.sh` | Auto-configure for your Intel CPU |
| `test_ollama_api.sh` | Test API connectivity |
| `benchmark_ollama.sh` | Performance benchmarking |

## 📖 Documentation

All in `docs/` directory:

- **[QUICKSTART_INTEL_CPU.md](docs/QUICKSTART_INTEL_CPU.md)** - Fast setup guide
- **[performance_optimization_guide.md](docs/performance_optimization_guide.md)** - 9 optimization methods
- **[intel_cpu_optimization.md](docs/intel_cpu_optimization.md)** - Intel CPU tuning
- **[LLM_INTEGRATION_OPTIONS.md](docs/LLM_INTEGRATION_OPTIONS.md)** - OpenAI, Claude, Azure, etc.
- **[sample_prompts.md](docs/sample_prompts.md)** - Prompt engineering examples
- **[DOCKER_VS_NATIVE.md](docs/DOCKER_VS_NATIVE.md)** - Docker vs native performance

## ⚡ Performance

Optimized transformations are **3.5x faster**:
- Uses parallel processing (4-8 step copies)
- Optimized prompts (60% shorter)
- Intel CPU tuning (AVX2/AVX512)
- Connection keep-alive
- Model persistence

**Typical performance:**
- 4-core CPU: ~2 minutes for 100 reviews
- 8-core CPU: ~1.5 minutes for 100 reviews

## 📋 Requirements

- **OS:** Ubuntu 24.04 LTS
- **Software:** PDI/Kettle 9.x+
- **Hardware:** 8GB RAM minimum (16GB recommended), Intel CPU with AVX2
- **Knowledge:** Basic PDI experience, familiar with CSV and JSON

## 🎯 What You'll Learn

✅ How to call LLM APIs from PDI transformations
✅ Building effective prompts for structured output
✅ Parsing and structuring LLM responses
✅ Performance optimization techniques
✅ Production-ready error handling
✅ Intel CPU-specific tuning

## 🔧 Installation

### Automated (Recommended)

```bash
cd scripts
./install_ollama.sh          # Installs Ollama, downloads models
./configure_intel_cpu.sh     # Detects CPU, optimizes settings
```

### Manual

See [docs/QUICKSTART_INTEL_CPU.md](docs/QUICKSTART_INTEL_CPU.md)

## 🧪 Testing

```bash
cd scripts

# Quick API test
./test_ollama_api.sh

# Full benchmark
./benchmark_ollama.sh
```

## 💡 LLM Options

While workshops use **Ollama** (free, local, private), you can also use:

- **OpenAI** (GPT-3.5, GPT-4) - Best quality, paid
- **Azure OpenAI** - Enterprise with SLA
- **Anthropic Claude** - Long context (200K tokens)
- **AWS Bedrock** - Multi-provider
- **Google Vertex AI** - GCP integration
- **vLLM** - High-performance self-hosted

See [docs/LLM_INTEGRATION_OPTIONS.md](docs/LLM_INTEGRATION_OPTIONS.md) for integration details.

## 🎨 Models

Included models (auto-selected based on your CPU):

| Model | Size | Speed | Quality | Best For |
|-------|------|-------|---------|----------|
| llama3.2:1b | 1.3GB | ⚡⚡⚡⚡⚡ | ⭐⭐⭐ | 4-core CPUs, testing |
| llama3.2:3b | 2.0GB | ⚡⚡⚡⚡ | ⭐⭐⭐⭐ | **Recommended** |
| llama2:7b | 3.8GB | ⚡⚡⚡ | ⭐⭐⭐⭐⭐ | High accuracy needs |

## 🔧 Troubleshooting

### Ollama won't start
```bash
sudo systemctl status ollama
journalctl -u ollama -n 50
```

### Slow performance
```bash
cd scripts
./benchmark_ollama.sh  # See recommendations
```

### Connection errors
```bash
curl http://localhost:11434/api/tags
# Should return list of models
```

### Out of memory
Use smaller model: Change `MODEL_NAME` parameter to `llama3.2:1b`

## 🤝 Contributing

Want to add a workshop?

1. Create folder: `workshops/workshop-XX-name/`
2. Add structure: `data/`, `transformations/`, `docs/`
3. Include: Basic + optimized transformations
4. Test on fresh Ubuntu 24.04 install

## 📝 License

Educational material. Free to use, modify, and distribute for learning.

## 🙏 Credits

- **Ollama** - Local LLM runtime
- **Meta AI** - Llama models
- **Hitachi Vantara** - Pentaho Data Integration

---

**Get Started:** `cd scripts && ./install_ollama.sh`

**Need Help?** Check [docs/](docs/) directory for guides
