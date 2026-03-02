# Intel CPU Optimization Guide for Ollama + PDI

This guide provides specific optimizations for running Ollama with PDI on Intel CPUs (without GPU acceleration).

## Quick Setup for Intel CPUs

### Step 1: Determine Your CPU Cores

```bash
# Check number of CPU cores
lscpu | grep "^CPU(s):"

# Check CPU model
lscpu | grep "Model name"

# Example output:
# CPU(s):              8
# Model name:          Intel(R) Core(TM) i7-9700K CPU @ 3.60GHz
```

### Step 2: Configure Ollama for Intel CPU

Create or edit Ollama's environment configuration:

```bash
sudo mkdir -p /etc/systemd/system/ollama.service.d/
sudo nano /etc/systemd/system/ollama.service.d/override.conf
```

Add these Intel-specific optimizations:

```ini
[Service]
# Intel CPU optimizations
Environment="OLLAMA_NUM_PARALLEL=4"
Environment="OLLAMA_MAX_LOADED_MODELS=1"
Environment="OLLAMA_KEEP_ALIVE=30m"

# Intel-specific flags (if using newer CPUs with AVX512)
Environment="OLLAMA_LLM_LIBRARY=cpu_avx2"
```

**For Intel CPUs with AVX-512 support** (10th gen+):
```ini
Environment="OLLAMA_LLM_LIBRARY=cpu_avx512"
```

Reload and restart:
```bash
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

### Step 3: Use the Optimized Transformation

```bash
# Open in Spoon
cd /path/to/pdi
./spoon.sh

# Open:
/home/pentaho/LLM-PDI-Integration/transformations/sentiment_analysis_optimized.ktr
```

## Intel CPU Performance Matrix

| Intel CPU Generation | Cores | Recommended Model | Expected Speed | STEP_COPIES |
|---------------------|-------|-------------------|----------------|-------------|
| 6th-7th Gen (Skylake/Kaby Lake) | 4 | llama3.2:1b | ~40 tok/s | 3 |
| 8th-9th Gen (Coffee Lake) | 6-8 | llama3.2:3b | ~30-40 tok/s | 5-7 |
| 10th-11th Gen (Comet/Rocket Lake) | 8-10 | llama3.2:3b | ~40-50 tok/s | 7-9 |
| 12th+ Gen (Alder/Raptor Lake) | 12-16 | llama3.2:3b | ~50-60 tok/s | 10-14 |
| Xeon (Server) | 16+ | llama2:7b | ~35-45 tok/s | 14-30 |

**Notes:**
- tok/s = tokens per second (inference speed)
- STEP_COPIES should be set to: `CPU cores - 1` (leave 1 core for Ollama)

## Model Selection for Intel CPUs

### Recommended Models by CPU Capability

#### Budget Intel CPUs (4 cores or less)
```bash
# Use the smallest model
ollama pull llama3.2:1b

# Set in transformation:
MODEL_NAME=llama3.2:1b
STEP_COPIES=3
```

**Performance:**
- Processing time: ~1.5s per review
- 100 reviews: ~2 minutes
- Accuracy: Good (85-90%)

#### Mid-range Intel CPUs (6-8 cores)
```bash
# Balanced model (Recommended)
ollama pull llama3.2:3b

# Set in transformation:
MODEL_NAME=llama3.2:3b
STEP_COPIES=5
```

**Performance:**
- Processing time: ~2.5s per review
- 100 reviews: ~2.5 minutes
- Accuracy: Very Good (90-95%)

#### High-end Intel CPUs (10+ cores)
```bash
# Can handle larger models
ollama pull llama2:7b

# Set in transformation:
MODEL_NAME=llama2:7b
STEP_COPIES=8
```

**Performance:**
- Processing time: ~3.5s per review
- 100 reviews: ~3 minutes
- Accuracy: Excellent (95%+)

## Optimal Parameter Settings

### PDI Transformation Parameters

Edit these in the optimized transformation:

| Parameter | Budget CPU | Mid-range CPU | High-end CPU |
|-----------|-----------|---------------|--------------|
| MODEL_NAME | llama3.2:1b | llama3.2:3b | llama2:7b |
| STEP_COPIES | 3 | 5-7 | 8-14 |
| KEEP_ALIVE | 15m | 30m | 60m |

### Finding Your Optimal STEP_COPIES

Run this test script:

```bash
#!/bin/bash
# Save as: test_step_copies.sh

CORES=$(nproc)
echo "CPU Cores: $CORES"
echo "Testing different STEP_COPIES values..."

for copies in 2 4 6 8; do
    if [ $copies -ge $CORES ]; then
        break
    fi

    echo ""
    echo "Testing with $copies copies..."

    # Simulate by running parallel requests
    start=$(date +%s)
    for i in $(seq 1 $copies); do
        curl -s http://localhost:11434/api/generate -d '{
            "model": "llama3.2:3b",
            "prompt": "Quick test",
            "stream": false
        }' > /dev/null &
    done
    wait
    end=$(date +%s)

    time=$((end - start))
    echo "Time: ${time}s"
    echo "Throughput: $(echo "scale=2; $copies / $time" | bc) requests/sec"
done
```

Run it:
```bash
chmod +x test_step_copies.sh
./test_step_copies.sh
```

Use the STEP_COPIES value that gives the best throughput.

## Intel-Specific Optimizations

### 1. Enable AVX2/AVX512

Check if your CPU supports AVX2 or AVX512:

```bash
lscpu | grep -E "avx2|avx512"
```

If you see `avx512`, configure Ollama:
```bash
sudo systemctl edit ollama
```

Add:
```ini
[Service]
Environment="OLLAMA_LLM_LIBRARY=cpu_avx512"
```

**Performance impact:** 20-30% faster inference

### 2. CPU Governor Settings

Set CPU to performance mode for consistent speeds:

```bash
# Check current governor
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

# Set to performance (temporary)
echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

# Make permanent
sudo apt-get install cpufrequtils
echo 'GOVERNOR="performance"' | sudo tee /etc/default/cpufrequtils
sudo systemctl restart cpufrequtils
```

**Performance impact:** 10-15% faster, more consistent timing

### 3. Disable Hyper-Threading (Optional)

For workloads like LLM inference, disabling Hyper-Threading can improve performance:

```bash
# Check if HT is enabled
lscpu | grep "Thread(s) per core"

# If output is 2, HT is enabled
# To disable (requires reboot):
echo off | sudo tee /sys/devices/system/cpu/smt/control
```

**When to disable:**
- Server CPUs with 16+ cores
- Running only LLM workloads
- Need consistent latency

**Performance impact:** Variable (test your specific workload)

### 4. Memory Configuration

Ensure adequate RAM:

```bash
# Check available memory
free -h

# Rule of thumb:
# llama3.2:1b needs: 2GB RAM minimum
# llama3.2:3b needs: 4GB RAM minimum
# llama2:7b needs:   8GB RAM minimum

# Plus 2GB per PDI step copy
```

Optimize swappiness for LLM workloads:

```bash
# Check current swappiness
cat /proc/sys/vm/swappiness

# Set to lower value (prefer RAM over swap)
echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

### 5. Process Priority

Give Ollama higher CPU priority:

```bash
sudo systemctl edit ollama
```

Add:
```ini
[Service]
Nice=-10
CPUSchedulingPolicy=fifo
CPUSchedulingPriority=50
```

Restart:
```bash
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

**Performance impact:** 5-10% faster, especially under system load

## Benchmarking Your Setup

### Quick Benchmark

```bash
cd /home/pentaho/LLM-PDI-Integration/examples
./benchmark_ollama.sh
```

This will test your specific hardware and provide:
- Model comparison
- Optimal prompt length
- Expected throughput
- Recommendations

### Expected Results (Intel CPUs)

**Intel i5-8400 (6 cores @ 2.8GHz):**
```
llama3.2:1b: ~1200ms per request, ~60 tok/s
llama3.2:3b: ~2000ms per request, ~35 tok/s
llama2:7b:   ~3500ms per request, ~20 tok/s
```

**Intel i7-9700K (8 cores @ 3.6GHz):**
```
llama3.2:1b: ~900ms per request, ~75 tok/s
llama3.2:3b: ~1500ms per request, ~45 tok/s
llama2:7b:   ~2800ms per request, ~25 tok/s
```

**Intel i9-12900K (16 cores @ 3.2GHz):**
```
llama3.2:1b: ~650ms per request, ~95 tok/s
llama3.2:3b: ~1100ms per request, ~60 tok/s
llama2:7b:   ~2200ms per request, ~32 tok/s
```

## Troubleshooting Intel CPU Performance

### Issue: Slow Performance (< 20 tok/s)

**Check 1: CPU throttling**
```bash
# Monitor CPU frequency while running
watch -n 1 "grep MHz /proc/cpuinfo | head -5"

# Should stay near max frequency
```

**Solution:** Check thermal throttling
```bash
sudo apt-get install lm-sensors
sensors

# If CPU temp > 85°C, improve cooling
```

**Check 2: Memory pressure**
```bash
free -h
# Ensure "available" is > model size + 2GB
```

**Solution:** Close unnecessary applications or use smaller model

**Check 3: Wrong model**
```bash
ollama list
# Verify you're using the intended model
```

### Issue: High CPU Usage (100% constant)

This is normal! LLM inference is CPU-intensive.

**If system becomes unresponsive:**

1. Reduce STEP_COPIES:
   ```
   # In transformation parameters
   STEP_COPIES=2  # Reduce from 4 or higher
   ```

2. Lower process priority:
   ```bash
   # Run PDI with lower priority
   nice -n 10 ./spoon.sh
   ```

3. Use cgroups to limit CPU:
   ```bash
   sudo apt-get install cgroup-tools

   # Limit Ollama to 80% CPU
   sudo cgcreate -g cpu:/ollama
   sudo cgset -r cpu.cfs_quota_us=800000 ollama
   sudo cgclassify -g cpu:ollama $(pgrep ollama)
   ```

### Issue: Inconsistent Response Times

**Cause:** CPU frequency scaling

**Solution:** Set performance governor (see above)

**Alternative:** Use `cpupower`:
```bash
sudo apt-get install linux-tools-generic
sudo cpupower frequency-set -g performance
```

## Production Deployment Tips

### 1. Dedicated Ollama Server

For large-scale processing, run Ollama on a separate machine:

```
┌──────────────┐         ┌──────────────┐
│  PDI Server  │────────>│ Ollama Server│
│  (8 cores)   │  LAN    │  (16 cores)  │
└──────────────┘         └──────────────┘
```

**Benefits:**
- PDI doesn't compete for CPU
- Can use larger models
- Better scalability

**Setup:**
```bash
# On Ollama server, allow remote connections
sudo systemctl edit ollama
```

Add:
```ini
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
```

**In PDI:**
```
OLLAMA_URL=http://ollama-server-ip:11434
```

### 2. Load Balancing Multiple Ollama Instances

For very high throughput:

```
┌──────────────┐     ┌──────────────┐
│  PDI Server  │────>│   HAProxy    │
└──────────────┘     └──────┬───────┘
                            │
              ┌─────────────┼─────────────┐
              │             │             │
              v             v             v
         ┌────────┐    ┌────────┐    ┌────────┐
         │Ollama 1│    │Ollama 2│    │Ollama 3│
         └────────┘    └────────┘    └────────┘
```

**HAProxy config:**
```
frontend ollama_frontend
    bind *:11434
    default_backend ollama_backend

backend ollama_backend
    balance roundrobin
    server ollama1 192.168.1.10:11434 check
    server ollama2 192.168.1.11:11434 check
    server ollama3 192.168.1.12:11434 check
```

### 3. Monitoring & Metrics

Track performance over time:

```bash
# CPU usage
top -b -n 1 | grep ollama

# Memory usage
ps aux | grep ollama | awk '{print $6/1024 " MB"}'

# Request timing (add to transformation)
# Already included in optimized version - check response_time field
```

Create a monitoring dashboard:
```sql
-- If logging to database
SELECT
    DATE(processing_timestamp) as date,
    AVG(response_time) as avg_ms,
    MIN(response_time) as min_ms,
    MAX(response_time) as max_ms,
    COUNT(*) as requests
FROM sentiment_results
GROUP BY DATE(processing_timestamp)
ORDER BY date DESC;
```

## Cost Analysis

### Hardware ROI for Intel CPU

**Scenario:** Processing 10,000 reviews/day

| Setup | Hardware Cost | Processing Time | Monthly Cost (electricity) |
|-------|--------------|-----------------|---------------------------|
| Intel i5 (6 cores) | $200 | ~8 hours | ~$15 |
| Intel i7 (8 cores) | $350 | ~5 hours | ~$18 |
| Intel i9 (16 cores) | $600 | ~3 hours | ~$25 |
| Intel Xeon (32 cores) | $1500 | ~1.5 hours | ~$40 |

**vs Cloud LLM API:**
- OpenAI GPT-3.5: ~$0.002 per request = $20/day = $600/month
- Break-even point: 1 month with mid-range Intel CPU

## Quick Reference Commands

```bash
# Check CPU info
lscpu

# Check Ollama status
sudo systemctl status ollama

# View Ollama logs
journalctl -u ollama -f

# Test inference speed
time ollama run llama3.2:3b "Quick test"

# Monitor CPU during processing
htop

# Check model memory usage
ollama ps

# Restart Ollama with new config
sudo systemctl restart ollama

# List running models
ollama list

# Remove unused model
ollama rm model_name

# Pull specific model version
ollama pull llama3.2:3b-q4_0
```

## Summary: Best Configuration for Intel CPU

```bash
# 1. Install optimized model
ollama pull llama3.2:3b

# 2. Configure Ollama
sudo systemctl edit ollama
```

Add:
```ini
[Service]
Environment="OLLAMA_NUM_PARALLEL=4"
Environment="OLLAMA_KEEP_ALIVE=30m"
Environment="OLLAMA_MAX_LOADED_MODELS=1"
Nice=-10
```

```bash
# 3. Set CPU governor
echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

# 4. Use optimized transformation
# Open: sentiment_analysis_optimized.ktr

# 5. Set parameters based on your CPU cores:
# STEP_COPIES = (CPU cores - 1)
# MODEL_NAME = llama3.2:3b
# KEEP_ALIVE = 30m

# 6. Run benchmark
cd /home/pentaho/LLM-PDI-Integration/examples
./benchmark_ollama.sh

# 7. Start processing!
```

**Expected performance:**
- **4-core Intel CPU:** ~100 reviews in 5-6 minutes
- **8-core Intel CPU:** ~100 reviews in 2-3 minutes
- **16-core Intel CPU:** ~100 reviews in 1-2 minutes

---

For GPU acceleration options, see the separate GPU optimization guide.
