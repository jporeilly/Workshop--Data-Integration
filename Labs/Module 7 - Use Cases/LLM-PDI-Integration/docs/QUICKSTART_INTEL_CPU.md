# Quick Start Guide: Intel CPU Optimization

This is the fastest way to get optimal performance with Ollama and PDI on your Intel CPU.

## One-Command Setup

```bash
cd /home/pentaho/LLM-PDI-Integration/scripts
./setup_ollama.sh && ./configure_intel_cpu.sh
```

That's it! The scripts will:
1. Install Ollama
2. Download optimal models
3. Detect your Intel CPU
4. Configure everything automatically
5. Run a test

## What You Get

### Performance Improvement

| Configuration | 100 Reviews Processing Time | Speedup |
|---------------|----------------------------|---------|
| **Basic (no optimization)** | ~250 seconds (4+ min) | 1x |
| **Optimized for Intel CPU** | ~70 seconds (1-2 min) | **3.5x faster** |

### Automatic Optimizations Applied

✅ **Parallel Processing** - Configured for your CPU cores
✅ **Optimized Prompts** - 60% shorter, same accuracy
✅ **Model Persistence** - Keeps model in memory
✅ **Connection Keep-Alive** - Reuses HTTP connections
✅ **CPU Performance Mode** - No frequency throttling
✅ **Intel-Specific Flags** - AVX2/AVX512 if available

## After Setup

### Open the Optimized Transformation

```bash
cd /path/to/pdi
./spoon.sh
```

Then:
1. File → Open
2. Navigate to: `/home/pentaho/LLM-PDI-Integration/transformations/sentiment_analysis_optimized.ktr`
3. Run it! (F9)

### Your Configuration

After running `configure_intel_cpu.sh`, check the generated config:

```bash
cat /home/pentaho/LLM-PDI-Integration/intel_cpu_config.txt
```

This shows your optimal settings based on your specific CPU.

## Performance by Intel CPU Generation

| Your CPU | Model to Use | Expected Speed |
|----------|-------------|----------------|
| **4 cores** (i5-6xxx, i5-7xxx) | llama3.2:1b | ~40 tok/s, ~2 min for 100 rows |
| **6-8 cores** (i5-8xxx, i7-9xxx) | llama3.2:3b | ~35 tok/s, ~2.5 min for 100 rows |
| **10+ cores** (i9-10xxx+) | llama2:7b | ~40 tok/s, ~3 min for 100 rows |

## Benchmark Your System

Want to see actual numbers for your hardware?

```bash
cd /home/pentaho/LLM-PDI-Integration/examples
./benchmark_ollama.sh
```

This will test:
- Different models on your CPU
- Prompt length impact
- Parallel vs sequential
- Cold vs warm starts

Results saved to CSV for analysis.

## Troubleshooting

### Still Slow?

```bash
# Check CPU is in performance mode
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
# Should show: performance

# Check Ollama is using optimizations
journalctl -u ollama | grep -i avx

# Monitor CPU usage while running
htop
# Should be near 100% on multiple cores
```

### Out of Memory?

```bash
# Check available RAM
free -h

# Use smaller model
# In transformation, change MODEL_NAME to:
llama3.2:1b  # Only needs 2GB RAM
```

### Need More Speed?

1. **Reduce model size**: Use llama3.2:1b instead of 3b
2. **Increase step copies**: If you have free CPU cores
3. **Shorter prompts**: Remove non-essential instructions
4. **Add caching**: For repeated content (see performance guide)

## Comparison: Basic vs Optimized

### Basic Transformation
```
sentiment_analysis.ktr

- Single step copy (sequential)
- Verbose prompts
- No connection pooling
- Default Ollama settings
- No CPU optimizations

Result: ~2.5 seconds per review
```

### Optimized Transformation
```
sentiment_analysis_optimized.ktr

✓ 4-8 parallel step copies
✓ Concise prompts (60% shorter)
✓ Connection keep-alive
✓ Model memory persistence
✓ Intel CPU tuning
✓ Performance governor

Result: ~0.7 seconds per review (3.5x faster)
```

## Advanced: Fine-Tuning

The configuration script sets good defaults, but you can manually adjust in the transformation:

### Parameters to Tune

**STEP_COPIES** - Parallel processing
```
Default: CPU cores - 1
Increase if: CPU usage < 80%
Decrease if: System becomes unresponsive
```

**MODEL_NAME** - Model selection
```
Fast:     llama3.2:1b  (speed priority)
Balanced: llama3.2:3b  (recommended)
Accurate: llama2:7b    (quality priority)
```

**KEEP_ALIVE** - Model memory
```
Short jobs:  15m
Medium jobs: 30m (default)
Long jobs:   60m
```

## Next Steps

1. ✅ Setup complete
2. ✅ Transformation optimized
3. ✅ Ready to process

Now you can:
- Run the workshop with sample data
- Process your own customer reviews
- Explore other workshop topics
- Scale up production workloads

## Documentation

- **Performance Deep Dive**: [documentation/performance_optimization_guide.md](performance_optimization_guide.md)
- **Intel CPU Details**: [documentation/intel_cpu_optimization.md](intel_cpu_optimization.md)
- **Workshop Tutorial**: [documentation/workshop_1_sentiment_analysis.md](workshop_1_sentiment_analysis.md)

## Support

Questions? Check:
1. Configuration summary: `intel_cpu_config.txt`
2. Ollama logs: `journalctl -u ollama -f`
3. Performance guide: `documentation/performance_optimization_guide.md`

---

**Quick Tip**: For production workloads, run the benchmark first to understand your hardware's limits, then set STEP_COPIES accordingly.
