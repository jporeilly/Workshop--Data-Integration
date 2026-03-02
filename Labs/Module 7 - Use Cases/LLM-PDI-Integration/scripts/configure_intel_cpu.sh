#!/bin/bash
# Intel CPU Optimization Script for Ollama
# Automatically configures optimal settings for your Intel CPU

set -e

echo "=========================================="
echo "Intel CPU Optimization for Ollama"
echo "=========================================="
echo ""

# Detect CPU info
CPU_MODEL=$(lscpu | grep "Model name" | cut -d':' -f2 | xargs)
CPU_CORES=$(nproc)
CPU_THREADS=$(lscpu | grep "^CPU(s):" | awk '{print $2}')
THREADS_PER_CORE=$(lscpu | grep "Thread(s) per core" | awk '{print $4}')

echo "Detected CPU:"
echo "  Model: $CPU_MODEL"
echo "  Cores: $CPU_CORES"
echo "  Threads: $CPU_THREADS"
echo "  Threads per core: $THREADS_PER_CORE"
echo ""

# Check for AVX support
AVX2=$(lscpu | grep -o "avx2" || echo "")
AVX512=$(lscpu | grep -o "avx512" || echo "")

if [ -n "$AVX512" ]; then
    echo "✓ AVX-512 supported (best performance)"
    LLM_LIBRARY="cpu_avx512"
elif [ -n "$AVX2" ]; then
    echo "✓ AVX2 supported (good performance)"
    LLM_LIBRARY="cpu_avx2"
else
    echo "⚠ No AVX2/AVX512 detected (basic performance)"
    LLM_LIBRARY="cpu"
fi
echo ""

# Calculate optimal settings
RECOMMENDED_COPIES=$((CPU_CORES - 1))
if [ $RECOMMENDED_COPIES -lt 2 ]; then
    RECOMMENDED_COPIES=2
fi

# Recommend model based on cores
if [ $CPU_CORES -le 4 ]; then
    RECOMMENDED_MODEL="llama3.2:1b"
    RECOMMENDED_KEEP_ALIVE="15m"
elif [ $CPU_CORES -le 8 ]; then
    RECOMMENDED_MODEL="llama3.2:3b"
    RECOMMENDED_KEEP_ALIVE="30m"
else
    RECOMMENDED_MODEL="llama2:7b"
    RECOMMENDED_KEEP_ALIVE="60m"
fi

echo "Recommended Configuration:"
echo "  Model: $RECOMMENDED_MODEL"
echo "  PDI Step Copies: $RECOMMENDED_COPIES"
echo "  Keep Alive: $RECOMMENDED_KEEP_ALIVE"
echo ""

# Check if Ollama is installed
if ! command -v ollama &> /dev/null; then
    echo "Error: Ollama is not installed."
    echo "Run ./setup_ollama.sh first"
    exit 1
fi

echo "Step 1: Configuring Ollama service..."

# Create systemd override directory
sudo mkdir -p /etc/systemd/system/ollama.service.d/

# Create override configuration
cat << EOF | sudo tee /etc/systemd/system/ollama.service.d/override.conf
[Service]
# Intel CPU optimizations
Environment="OLLAMA_NUM_PARALLEL=$RECOMMENDED_COPIES"
Environment="OLLAMA_MAX_LOADED_MODELS=1"
Environment="OLLAMA_KEEP_ALIVE=$RECOMMENDED_KEEP_ALIVE"
Environment="OLLAMA_LLM_LIBRARY=$LLM_LIBRARY"

# Process priority
Nice=-10
EOF

echo "✓ Ollama configuration created"
echo ""

# Reload systemd and restart Ollama
echo "Step 2: Restarting Ollama service..."
sudo systemctl daemon-reload
sudo systemctl restart ollama

# Wait for Ollama to start
sleep 3

if sudo systemctl is-active --quiet ollama; then
    echo "✓ Ollama restarted successfully"
else
    echo "✗ Ollama failed to start. Check logs with: journalctl -u ollama -n 50"
    exit 1
fi
echo ""

# Check if recommended model is installed
echo "Step 3: Checking model availability..."
if ollama list | grep -q "$RECOMMENDED_MODEL"; then
    echo "✓ Model $RECOMMENDED_MODEL is already installed"
else
    echo "Installing recommended model: $RECOMMENDED_MODEL"
    echo "This may take several minutes..."
    ollama pull $RECOMMENDED_MODEL
    echo "✓ Model installed"
fi
echo ""

# Optimize CPU governor
echo "Step 4: Setting CPU governor to performance mode..."
if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then
    CURRENT_GOVERNOR=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)
    echo "  Current governor: $CURRENT_GOVERNOR"

    if [ "$CURRENT_GOVERNOR" != "performance" ]; then
        read -p "Set CPU governor to 'performance' for better LLM inference? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor > /dev/null
            echo "✓ CPU governor set to performance"
            echo "  Note: This is temporary. For permanent:"
            echo "  sudo apt-get install cpufrequtils"
            echo '  echo GOVERNOR="performance" | sudo tee /etc/default/cpufrequtils'
        fi
    else
        echo "✓ Already set to performance"
    fi
else
    echo "⚠ CPU frequency scaling not available (VM or laptop?)"
fi
echo ""

# Optimize memory swappiness
echo "Step 5: Checking memory configuration..."
CURRENT_SWAPPINESS=$(cat /proc/sys/vm/swappiness)
echo "  Current swappiness: $CURRENT_SWAPPINESS"

if [ $CURRENT_SWAPPINESS -gt 10 ]; then
    read -p "Lower swappiness to 10 for better LLM performance? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo 10 | sudo tee /proc/sys/vm/swappiness > /dev/null
        echo "✓ Swappiness set to 10 (temporary)"
        echo "  For permanent, add to /etc/sysctl.conf:"
        echo "  echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf"
    fi
else
    echo "✓ Already optimized"
fi
echo ""

# Test the setup
echo "Step 6: Testing configuration..."
echo "Running quick inference test..."

TEST_START=$(date +%s%N)
TEST_RESULT=$(curl -s http://localhost:11434/api/generate -d "{
    \"model\": \"$RECOMMENDED_MODEL\",
    \"prompt\": \"Test: What is 2+2?\",
    \"stream\": false
}" || echo "ERROR")
TEST_END=$(date +%s%N)

if [ "$TEST_RESULT" != "ERROR" ]; then
    TEST_TIME=$(( ($TEST_END - $TEST_START) / 1000000 ))
    TOKENS=$(echo "$TEST_RESULT" | jq -r '.eval_count // 0')
    DURATION=$(echo "$TEST_RESULT" | jq -r '.eval_duration // 1')

    if [ "$TOKENS" != "0" ] && [ "$DURATION" != "null" ]; then
        TOK_PER_SEC=$(echo "scale=1; $TOKENS * 1000000000 / $DURATION" | bc)
        echo "✓ Test successful!"
        echo "  Response time: ${TEST_TIME}ms"
        echo "  Tokens generated: $TOKENS"
        echo "  Speed: $TOK_PER_SEC tokens/sec"
    else
        echo "✓ Test completed (metrics unavailable)"
    fi
else
    echo "✗ Test failed. Check Ollama status: sudo systemctl status ollama"
fi
echo ""

# Create configuration summary file
SUMMARY_FILE="/home/pentaho/LLM-PDI-Integration/intel_cpu_config.txt"
cat > "$SUMMARY_FILE" << EOF
Intel CPU Configuration Summary
Generated: $(date)

Hardware:
  CPU Model: $CPU_MODEL
  CPU Cores: $CPU_CORES
  AVX Support: $LLM_LIBRARY

Recommended Settings:
  Model: $RECOMMENDED_MODEL
  PDI STEP_COPIES: $RECOMMENDED_COPIES
  Keep Alive: $RECOMMENDED_KEEP_ALIVE

Ollama Configuration:
  Location: /etc/systemd/system/ollama.service.d/override.conf
  Status: $(sudo systemctl is-active ollama)

Performance Test:
  Response Time: ${TEST_TIME:-N/A}ms
  Tokens/Second: ${TOK_PER_SEC:-N/A}

Next Steps:
1. Open PDI transformation:
   /home/pentaho/LLM-PDI-Integration/transformations/sentiment_analysis_optimized.ktr

2. Set parameters:
   MODEL_NAME = $RECOMMENDED_MODEL
   STEP_COPIES = $RECOMMENDED_COPIES
   KEEP_ALIVE = $RECOMMENDED_KEEP_ALIVE

3. Run the transformation!

For benchmarking:
   cd /home/pentaho/LLM-PDI-Integration/examples
   ./benchmark_ollama.sh
EOF

echo "=========================================="
echo "Configuration Complete!"
echo "=========================================="
echo ""
echo "Configuration summary saved to:"
echo "  $SUMMARY_FILE"
echo ""
echo "Your optimized settings:"
echo "┌────────────────────────────────────────┐"
echo "│ MODEL_NAME    = $RECOMMENDED_MODEL"
echo "│ STEP_COPIES   = $RECOMMENDED_COPIES"
echo "│ KEEP_ALIVE    = $RECOMMENDED_KEEP_ALIVE"
echo "└────────────────────────────────────────┘"
echo ""
echo "Next steps:"
echo "1. Open the optimized transformation in PDI:"
echo "   transformations/sentiment_analysis_optimized.ktr"
echo ""
echo "2. Verify parameters match the settings above"
echo ""
echo "3. Run a benchmark test:"
echo "   cd examples && ./benchmark_ollama.sh"
echo ""
echo "4. Start processing your data!"
echo ""
echo "For detailed optimization info, see:"
echo "  documentation/intel_cpu_optimization.md"
echo ""
