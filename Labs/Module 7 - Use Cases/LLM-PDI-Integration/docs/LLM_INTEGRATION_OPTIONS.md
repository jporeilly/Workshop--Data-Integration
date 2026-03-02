# LLM Integration Options for PDI

This guide covers all the ways you can integrate Large Language Models with Pentaho Data Integration, not just Ollama.

## Comparison Matrix

| Method | Cost | Performance | Privacy | Ease of Use | Best For |
|--------|------|-------------|---------|-------------|----------|
| **Ollama (Local)** | Free | Fast (local) | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | **Current workshops, sensitive data** |
| **OpenAI API** | Pay per use | Very fast | ⭐⭐ | ⭐⭐⭐⭐⭐ | Production, best quality |
| **Azure OpenAI** | Pay per use | Very fast | ⭐⭐⭐ | ⭐⭐⭐⭐ | Enterprise, compliance |
| **Anthropic Claude** | Pay per use | Very fast | ⭐⭐ | ⭐⭐⭐⭐⭐ | Long context needs |
| **AWS Bedrock** | Pay per use | Fast | ⭐⭐⭐ | ⭐⭐⭐ | AWS infrastructure |
| **Google Vertex AI** | Pay per use | Fast | ⭐⭐⭐ | ⭐⭐⭐ | GCP infrastructure |
| **HuggingFace** | Free/Paid | Variable | ⭐⭐⭐⭐ | ⭐⭐ | Custom models |
| **vLLM (Self-hosted)** | Free | Very fast | ⭐⭐⭐⭐⭐ | ⭐⭐ | High throughput |
| **LM Studio** | Free | Fast (local) | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | Desktop, prototyping |

## Method 1: Ollama (Current Implementation) ⭐

### Overview
Local LLM runtime that runs models on your infrastructure.

### Pros
✅ **Free** - No API costs
✅ **Private** - Data never leaves your network
✅ **Fast** - Local inference (no network latency)
✅ **Simple** - Easy setup and API
✅ **Offline** - Works without internet

### Cons
❌ Requires local compute resources
❌ Limited to open-source models
❌ No guaranteed SLA

### PDI Integration
```xml
<!-- HTTP Client Step -->
URL: http://localhost:11434/api/generate
Method: POST
Body: {"model":"llama3.2:3b","prompt":"...","stream":false}
```

### Use When
- Data privacy is critical
- Processing sensitive information
- Want to avoid API costs
- Need offline operation
- Have adequate local hardware

### Covered in Workshops
✅ Workshop 1 uses Ollama

---

## Method 2: OpenAI API (GPT-4, GPT-3.5)

### Overview
Industry-leading commercial API with best-in-class models.

### Pros
✅ **Highest quality** - Best available models
✅ **Reliable** - 99.9% uptime SLA
✅ **Fast** - Optimized infrastructure
✅ **Simple API** - Easy integration
✅ **Function calling** - Structured outputs

### Cons
❌ **Expensive** - $0.002-$0.06 per 1K tokens
❌ **Data privacy** - Sent to OpenAI
❌ **Rate limits** - Throttling on heavy use
❌ **Requires internet**

### PDI Integration

#### Configuration
```javascript
// In "Build Prompt" step
var json_payload = JSON.stringify({
    "model": "gpt-3.5-turbo",
    "messages": [
        {"role": "system", "content": "You are a sentiment analyzer."},
        {"role": "user", "content": "Analyze: " + review_text}
    ],
    "temperature": 0.3,
    "response_format": { "type": "json_object" }
});
```

#### HTTP Client Step
```xml
URL: https://api.openai.com/v1/chat/completions
Method: POST
Headers:
  - Authorization: Bearer ${OPENAI_API_KEY}
  - Content-Type: application/json
Body Field: json_payload
Result Field: openai_response
Socket Timeout: 60000
```

#### Parse Response
```javascript
// Extract from OpenAI format
var response_json = JSON.parse(openai_response);
var message_content = response_json.choices[0].message.content;
```

### Cost Estimation
- **GPT-3.5-turbo**: $0.002 per 1K tokens (~$0.0002 per review)
- **GPT-4**: $0.03 per 1K tokens (~$0.003 per review)
- **100,000 reviews/day**: $20-300/day

### Use When
- Need highest accuracy
- Have budget for API costs
- Data privacy is less critical
- Want guaranteed reliability
- Need advanced capabilities

---

## Method 3: Azure OpenAI Service

### Overview
OpenAI models hosted on Microsoft Azure with enterprise features.

### Pros
✅ **Enterprise SLA** - 99.9% uptime guarantee
✅ **Compliance** - SOC2, HIPAA, etc.
✅ **Private endpoints** - VNet integration
✅ **Data residency** - Regional deployments
✅ **Same quality** - OpenAI models

### Cons
❌ More expensive than OpenAI direct
❌ More complex setup
❌ Requires Azure subscription

### PDI Integration

```javascript
// Build payload (similar to OpenAI)
var json_payload = JSON.stringify({
    "messages": [
        {"role": "system", "content": "Analyze sentiment..."},
        {"role": "user", "content": review_text}
    ],
    "temperature": 0.3
});
```

```xml
<!-- HTTP Client -->
URL: https://<resource-name>.openai.azure.com/openai/deployments/<deployment-name>/chat/completions?api-version=2024-02-15-preview
Method: POST
Headers:
  - api-key: ${AZURE_OPENAI_KEY}
  - Content-Type: application/json
```

### Use When
- Enterprise customer with compliance needs
- Already on Azure
- Need data residency guarantees
- Want private networking
- Need audit trails and governance

---

## Method 4: Anthropic Claude

### Overview
Advanced LLM with 200K context window and strong reasoning.

### Pros
✅ **Long context** - 200K tokens (100K+ words)
✅ **High quality** - Excellent reasoning
✅ **Function calling** - Tool use
✅ **Fast** - Quick responses
✅ **Ethical AI** - Safety focus

### Cons
❌ More expensive than GPT-3.5
❌ Newer API (less mature)
❌ Limited model options

### PDI Integration

```javascript
var json_payload = JSON.stringify({
    "model": "claude-3-5-sonnet-20241022",
    "max_tokens": 1024,
    "messages": [
        {
            "role": "user",
            "content": "Analyze sentiment in JSON: " + review_text
        }
    ]
});
```

```xml
<!-- HTTP Client -->
URL: https://api.anthropic.com/v1/messages
Method: POST
Headers:
  - x-api-key: ${ANTHROPIC_API_KEY}
  - anthropic-version: 2023-06-01
  - content-type: application/json
```

### Cost
- Claude 3.5 Sonnet: $0.003/1K input, $0.015/1K output
- Claude 3 Haiku: $0.00025/1K input, $0.00125/1K output (cheaper)

### Use When
- Need very long context (large documents)
- Want high quality reasoning
- Processing complex documents
- Need strong safety features

---

## Method 5: AWS Bedrock

### Overview
Managed LLM service offering multiple model providers.

### Pros
✅ **Multiple models** - Anthropic, Meta, AI21, etc.
✅ **AWS integration** - Native AWS services
✅ **Private** - VPC endpoints available
✅ **Flexible** - Choose model per use case

### Cons
❌ More complex setup
❌ Requires AWS account
❌ Regional availability varies

### PDI Integration

```javascript
// Bedrock uses AWS Signature V4 - more complex auth
// Recommended: Use AWS SDK via User Defined Java Class

// Or use REST with pre-signed URLs
var json_payload = JSON.stringify({
    "inputText": "Analyze: " + review_text,
    "textGenerationConfig": {
        "maxTokenCount": 512,
        "temperature": 0.3
    }
});
```

```xml
<!-- HTTP Client with AWS SigV4 -->
URL: https://bedrock-runtime.<region>.amazonaws.com/model/<model-id>/invoke
Method: POST
Headers:
  - Authorization: AWS4-HMAC-SHA256... (complex)
  - Content-Type: application/json
```

**Note:** AWS Signature V4 authentication is complex. Consider using:
1. PDI AWS steps (if available)
2. User Defined Java Class with AWS SDK
3. Lambda function as proxy

### Use When
- Already on AWS
- Want choice of models
- Need AWS service integration
- Have compliance requirements
- Want private endpoints

---

## Method 6: Google Vertex AI

### Overview
Google Cloud's managed AI platform with multiple models.

### Pros
✅ **Multiple models** - PaLM, Gemini, etc.
✅ **GCP integration** - Native Google services
✅ **Multimodal** - Text, image, video
✅ **Enterprise** - SLA and support

### Cons
❌ Complex auth (GCP service accounts)
❌ Requires GCP account
❌ Less documentation

### PDI Integration

```javascript
// Simplified - actual requires GCP auth token
var json_payload = JSON.stringify({
    "instances": [
        {
            "content": "Analyze sentiment: " + review_text
        }
    ],
    "parameters": {
        "temperature": 0.3,
        "maxOutputTokens": 256
    }
});
```

```xml
<!-- HTTP Client -->
URL: https://<region>-aiplatform.googleapis.com/v1/projects/<project>/locations/<region>/publishers/google/models/<model>:predict
Method: POST
Headers:
  - Authorization: Bearer <gcp-token>
  - Content-Type: application/json
```

### Use When
- Already on Google Cloud
- Need multimodal capabilities
- Want Google's latest models (Gemini)
- Have GCP infrastructure

---

## Method 7: HuggingFace Inference API

### Overview
Access thousands of open-source models via API.

### Pros
✅ **Many models** - Thousands of options
✅ **Free tier** - Limited free usage
✅ **Open source** - Community models
✅ **Flexible** - Custom models possible

### Cons
❌ Slower (shared infrastructure)
❌ Rate limits on free tier
❌ Variable quality
❌ Less reliable than commercial APIs

### PDI Integration

```javascript
var json_payload = JSON.stringify({
    "inputs": review_text,
    "parameters": {
        "max_length": 100,
        "temperature": 0.7
    }
});
```

```xml
<!-- HTTP Client -->
URL: https://api-inference.huggingface.co/models/<model-name>
Method: POST
Headers:
  - Authorization: Bearer ${HF_API_KEY}
  - Content-Type: application/json
```

### Use When
- Experimenting with different models
- Need specific open-source model
- Limited budget
- Non-critical workloads

---

## Method 8: vLLM (Self-Hosted High Performance)

### Overview
High-performance inference server for self-hosting open-source models.

### Pros
✅ **Very fast** - Optimized serving
✅ **Private** - On your infrastructure
✅ **Free** - No API costs
✅ **High throughput** - Batch processing
✅ **OpenAI compatible** - Easy migration

### Cons
❌ Requires GPU (NVIDIA recommended)
❌ Complex setup
❌ Need DevOps knowledge

### Setup

```bash
# Install vLLM
pip install vllm

# Start server (OpenAI-compatible)
python -m vllm.entrypoints.openai.api_server \
    --model meta-llama/Llama-2-7b-chat-hf \
    --port 8000
```

### PDI Integration
Same as OpenAI API (compatible endpoint):

```xml
URL: http://localhost:8000/v1/chat/completions
Method: POST
Body: OpenAI format
```

### Use When
- Have GPU infrastructure
- Need maximum throughput
- High-volume processing
- Want Ollama-like privacy with more performance

---

## Method 9: LM Studio (Desktop GUI)

### Overview
User-friendly desktop app for running LLMs locally.

### Pros
✅ **Very easy** - GUI interface
✅ **Free** - No costs
✅ **Private** - Local models
✅ **OpenAI API** - Compatible endpoint
✅ **Cross-platform** - Windows, Mac, Linux

### Cons
❌ Desktop only (not for production)
❌ Manual management
❌ No clustering/scaling

### Setup
1. Download LM Studio
2. Download models via GUI
3. Start local server (OpenAI-compatible)

### PDI Integration
Same as OpenAI:

```xml
URL: http://localhost:1234/v1/chat/completions
```

### Use When
- Prototyping
- Desktop development
- Learning and testing
- Want GUI for model management

---

## Hybrid Approach

### Strategy: Use Multiple Methods

```javascript
// In PDI, choose LLM based on requirements
var llm_provider = getVariable("LLM_PROVIDER"); // ollama, openai, claude

if (llm_provider == "ollama") {
    api_url = "http://localhost:11434/api/generate";
    // Ollama format
} else if (llm_provider == "openai") {
    api_url = "https://api.openai.com/v1/chat/completions";
    // OpenAI format
} else if (llm_provider == "claude") {
    api_url = "https://api.anthropic.com/v1/messages";
    // Claude format
}
```

### Use Cases
- **Development**: Ollama (free, fast)
- **Production (sensitive data)**: Ollama or vLLM
- **Production (quality priority)**: OpenAI/Claude
- **Enterprise**: Azure OpenAI/AWS Bedrock
- **High volume**: vLLM with GPU

---

## Cost Comparison (100,000 reviews/day)

| Method | Monthly Cost | Notes |
|--------|-------------|-------|
| **Ollama** | $0 (+ hardware) | One-time hardware investment |
| **vLLM** | $0 (+ GPU server) | ~$500-1000/month for GPU VM |
| **GPT-3.5-turbo** | $600 | ~$0.0002 per review |
| **GPT-4** | $9,000 | ~$0.003 per review |
| **Claude 3 Haiku** | $375 | Cheapest cloud option |
| **Claude 3.5 Sonnet** | $1,800 | Mid-range quality |
| **Azure OpenAI** | $700-10,000 | + enterprise fees |

**Break-even analysis:**
- Ollama/vLLM: Hardware cost recovers in 1-3 months vs cloud APIs

---

## Recommendation by Use Case

### Workshops & Learning
✅ **Ollama** - Free, simple, private

### Startups & Small Business
✅ **OpenAI GPT-3.5** - Good quality, reasonable cost

### Enterprise (Sensitive Data)
✅ **Ollama or vLLM** - Keep data in-house

### Enterprise (Commercial)
✅ **Azure OpenAI** - SLA, compliance, support

### High Volume (100K+/day)
✅ **vLLM with GPU** - Best ROI at scale

### Maximum Quality
✅ **GPT-4 or Claude 3.5** - Best available models

---

## Migration Guide

### From Ollama to OpenAI

```javascript
// OLD (Ollama)
var payload = JSON.stringify({
    "model": "llama3.2:3b",
    "prompt": prompt_text,
    "stream": false
});

// NEW (OpenAI)
var payload = JSON.stringify({
    "model": "gpt-3.5-turbo",
    "messages": [
        {"role": "system", "content": "You are a helpful assistant."},
        {"role": "user", "content": prompt_text}
    ],
    "temperature": 0.3
});

// Response extraction
// OLD: response = json.response
// NEW: response = json.choices[0].message.content
```

### From Ollama to Claude

```javascript
// NEW (Claude)
var payload = JSON.stringify({
    "model": "claude-3-5-sonnet-20241022",
    "max_tokens": 1024,
    "messages": [
        {"role": "user", "content": prompt_text}
    ]
});

// Response extraction
// NEW: response = json.content[0].text
```

---

## Future Workshops

We may add workshops covering:
- **Workshop X**: OpenAI Integration
- **Workshop Y**: Azure OpenAI for Enterprise
- **Workshop Z**: Multi-Provider Strategy

---

## Quick Decision Tree

```
Need maximum privacy?
├─ Yes → Ollama or vLLM
└─ No
    ├─ High volume (>100K/day)?
    │   ├─ Yes → vLLM (GPU) or OpenAI
    │   └─ No
    │       ├─ Need enterprise features?
    │       │   ├─ Yes → Azure OpenAI or AWS Bedrock
    │       │   └─ No
    │       │       ├─ Best quality needed?
    │       │       │   ├─ Yes → GPT-4 or Claude 3.5
    │       │       │   └─ No → OpenAI GPT-3.5 or Ollama
```

---

**Current Workshops Use:** Ollama (free, private, good for learning)

**For Production:** Evaluate based on your specific requirements using this guide.
