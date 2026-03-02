# Workshop 1 - Transformation Parameters Reference

## Quick Reference

### sentiment_analysis.ktr (Basic Transformation)

**Parameters:** 3

| Parameter | Default | Type | Description |
|-----------|---------|------|-------------|
| `OLLAMA_URL` | `http://localhost:11434` | String | Ollama API endpoint URL |
| `MODEL_NAME` | `llama3.2:3b` | String | LLM model name |
| `INPUT_FILE` | `../data/customer_reviews.csv` | String | Path to input CSV file |

### sentiment_analysis_optimized.ktr (Optimized Transformation)

**Parameters:** 5

| Parameter | Default | Type | Description |
|-----------|---------|------|-------------|
| `OLLAMA_URL` | `http://localhost:11434` | String | Ollama API endpoint URL |
| `MODEL_NAME` | `llama3.2:3b` | String | LLM model name |
| `INPUT_FILE` | `../data/customer_reviews.csv` | String | Path to input CSV file |
| **`KEEP_ALIVE`** | **`30m`** | **String** | **How long to keep model in memory** |
| **`STEP_COPIES`** | **`4`** | **Integer** | **Number of parallel processing threads** |

## Detailed Parameter Descriptions

### OLLAMA_URL
- **Purpose:** Specifies the Ollama API endpoint
- **Default:** `http://localhost:11434`
- **Valid Values:** Any valid HTTP URL
- **Example Usage:**
  ```bash
  -param:OLLAMA_URL=http://localhost:11434
  -param:OLLAMA_URL=http://192.168.1.100:11434  # Remote Ollama server
  ```

### MODEL_NAME
- **Purpose:** Specifies which LLM model to use
- **Default:** `llama3.2:3b`
- **Valid Values:** Any model installed in Ollama
- **Recommended Options:**
  - `llama3.2:1b` - Fastest, good for testing
  - `llama3.2:3b` - Best balance (recommended)
  - `llama2:7b` - More accurate, slower
- **Example Usage:**
  ```bash
  -param:MODEL_NAME=llama3.2:3b
  -param:MODEL_NAME=llama2:7b  # Higher accuracy
  ```
- **Note:** Model must be downloaded first: `ollama pull llama3.2:3b`

### INPUT_FILE
- **Purpose:** Path to the CSV file containing customer reviews
- **Default:** `../data/customer_reviews.csv`
- **Valid Values:** Any valid file path (relative or absolute)
- **File Format Required:**
  - CSV format with headers
  - Fields: review_id, customer_name, product, review_text, date
- **Example Usage:**
  ```bash
  -param:INPUT_FILE=../data/customer_reviews.csv
  -param:INPUT_FILE=/home/user/my_reviews.csv  # Absolute path
  ```

### KEEP_ALIVE (Optimized Only)
- **Purpose:** Controls how long Ollama keeps the model loaded in memory
- **Default:** `30m` (30 minutes)
- **Valid Values:**
  - `5m` - 5 minutes (minimal memory usage)
  - `15m` - 15 minutes (balanced)
  - `30m` - 30 minutes (recommended - prevents reload overhead)
  - `60m` - 60 minutes (for heavy workloads)
  - `0` - Unload immediately after each request
- **Impact:**
  - Longer = faster processing (no model reload)
  - Longer = more memory usage
  - Shorter = less memory, slower first request after timeout
- **Example Usage:**
  ```bash
  -param:KEEP_ALIVE=30m   # Keep in memory for 30 minutes
  -param:KEEP_ALIVE=60m   # For long-running jobs
  ```
- **When to Adjust:**
  - Large dataset: Increase to `60m`
  - Limited memory: Decrease to `15m` or `5m`
  - Single test: Use `0` to free memory immediately

### STEP_COPIES (Optimized Only)
- **Purpose:** Number of parallel threads for the "Call Ollama API" step
- **Default:** `4`
- **Valid Values:** Integer 1-16 (practical limit based on CPU cores)
- **Recommended:** CPU cores - 1
  - 4 core CPU → `STEP_COPIES=3`
  - 8 core CPU → `STEP_COPIES=7`
  - 16 core CPU → `STEP_COPIES=15`
- **Impact:**
  - Higher = faster processing (parallel API calls)
  - Higher = more memory and CPU usage
  - Too high = system overload
- **Example Usage:**
  ```bash
  -param:STEP_COPIES=4    # 4 parallel threads
  -param:STEP_COPIES=1    # Single-threaded (testing)
  ```
- **Performance Example:**
  - 100 reviews, single-threaded: ~40 minutes
  - 100 reviews, 4 threads: ~10-12 minutes (3-4x faster)

## Command Line Examples

### Basic Transformation - All Defaults
```bash
./pan.sh \
  -file=sentiment_analysis.ktr \
  -level=Minimal
```

### Basic Transformation - Custom Model
```bash
./pan.sh \
  -file=sentiment_analysis.ktr \
  -param:MODEL_NAME=llama2:7b \
  -level=Minimal
```

### Basic Transformation - Custom Input File
```bash
./pan.sh \
  -file=sentiment_analysis.ktr \
  -param:INPUT_FILE=/path/to/my_reviews.csv \
  -level=Minimal
```

### Optimized Transformation - All Defaults
```bash
./pan.sh \
  -file=sentiment_analysis_optimized.ktr \
  -level=Minimal
```

### Optimized Transformation - Maximum Performance
```bash
./pan.sh \
  -file=sentiment_analysis_optimized.ktr \
  -param:STEP_COPIES=8 \
  -param:KEEP_ALIVE=60m \
  -level=Minimal
```

### Optimized Transformation - Memory Constrained
```bash
./pan.sh \
  -file=sentiment_analysis_optimized.ktr \
  -param:STEP_COPIES=2 \
  -param:KEEP_ALIVE=15m \
  -level=Minimal
```

### Optimized Transformation - All Custom
```bash
./pan.sh \
  -file=sentiment_analysis_optimized.ktr \
  -param:MODEL_NAME=llama3.2:3b \
  -param:OLLAMA_URL=http://localhost:11434 \
  -param:INPUT_FILE=/data/production_reviews.csv \
  -param:KEEP_ALIVE=30m \
  -param:STEP_COPIES=4 \
  -level=Basic
```

## Parameter Usage in JavaScript (getVariable)

Inside the transformation's JavaScript code, parameters are accessed using `getVariable()`:

```javascript
// Get parameters (with defaults if not set)
var model_name = getVariable("MODEL_NAME", "llama3.2:3b");
var keep_alive = getVariable("KEEP_ALIVE", "30m");
var url = getVariable("OLLAMA_URL", "http://localhost:11434");

// Use in JSON payload
var json_payload = JSON.stringify({
    "model": model_name,
    "keep_alive": keep_alive,
    // ...
});
```

**❌ WRONG - Don't do this:**
```javascript
// This does NOT work - stays as literal string!
var model = "${MODEL_NAME}";
```

## Performance Tuning Guide

### For Testing (Fast, Low Resource)
```bash
-param:MODEL_NAME=llama3.2:1b
-param:STEP_COPIES=1
-param:KEEP_ALIVE=5m
```

### For Production (Balanced)
```bash
-param:MODEL_NAME=llama3.2:3b
-param:STEP_COPIES=4
-param:KEEP_ALIVE=30m
```

### For High Accuracy (Slower, More Memory)
```bash
-param:MODEL_NAME=llama2:7b
-param:STEP_COPIES=2
-param:KEEP_ALIVE=60m
```

### For Maximum Speed (High CPU/Memory)
```bash
-param:MODEL_NAME=llama3.2:3b
-param:STEP_COPIES=8
-param:KEEP_ALIVE=60m
```

## Troubleshooting Parameter Issues

### "invalid duration" error (400)
- **Cause:** KEEP_ALIVE parameter not resolved
- **Fix:** Use `getVariable("KEEP_ALIVE", "30m")` in JavaScript

### "Model not found" error
- **Cause:** MODEL_NAME refers to a model not downloaded
- **Fix:** Run `ollama pull <model-name>` first

### "File not found" error
- **Cause:** INPUT_FILE path is incorrect
- **Fix:** Verify file exists at the specified path

### Slow performance
- **Cause:** STEP_COPIES too low
- **Fix:** Increase STEP_COPIES (recommended: CPU cores - 1)

### Out of memory
- **Cause:** Too many parallel copies or long KEEP_ALIVE
- **Fix:** Reduce STEP_COPIES and/or KEEP_ALIVE duration

## Summary

| Transformation | Parameters | Best For |
|----------------|------------|----------|
| **sentiment_analysis.ktr** | 3 basic params | Learning, small datasets, single-threaded |
| **sentiment_analysis_optimized.ktr** | 5 params (adds KEEP_ALIVE, STEP_COPIES) | Production, large datasets, performance |

**Key Differences:**
- Basic: Simple, fewer parameters, single-threaded
- Optimized: Parallel processing, model memory management, 3-4x faster

---

**Last Updated:** 2026-02-27
**Version:** 2.0
