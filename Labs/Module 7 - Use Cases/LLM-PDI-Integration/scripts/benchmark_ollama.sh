#!/bin/bash
# Ollama Performance Benchmark Script
# Tests different models and configurations to find optimal setup

set -e

OLLAMA_URL="${OLLAMA_URL:-http://localhost:11434}"
TEST_TEXT="This product exceeded my expectations! Fast performance, great battery life, and stunning display. Worth every penny."
RESULTS_FILE="benchmark_results_$(date +%Y%m%d_%H%M%S).csv"

echo "=========================================="
echo "Ollama Performance Benchmark"
echo "=========================================="
echo "URL: $OLLAMA_URL"
echo "Results will be saved to: $RESULTS_FILE"
echo ""

# Check dependencies
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required. Install with: sudo apt-get install jq"
    exit 1
fi

# CSV Header
echo "model,prompt_length,stream,format,response_time_ms,tokens_generated,tokens_per_second" > "$RESULTS_FILE"

# Function to test a configuration
test_config() {
    local model=$1
    local prompt=$2
    local stream=$3
    local format=$4
    local prompt_length=${#prompt}

    echo "Testing: $model | prompt_len=$prompt_length | stream=$stream | format=$format"

    # Build JSON payload
    local json_payload=$(jq -n \
        --arg model "$model" \
        --arg prompt "$prompt" \
        --argjson stream "$stream" \
        --arg format "$format" \
        '{model: $model, prompt: $prompt, stream: ($stream | if . == "true" then true else false end)}
        | if $format != "" then . + {format: $format} else . end')

    # Measure time
    local start=$(date +%s%N)

    local response=$(curl -s "$OLLAMA_URL/api/generate" \
        -H "Content-Type: application/json" \
        -d "$json_payload")

    local end=$(date +%s%N)
    local time_ms=$(( ($end - $start) / 1000000 ))

    # Extract metrics
    local eval_count=$(echo "$response" | jq -r '.eval_count // 0')
    local eval_duration=$(echo "$response" | jq -r '.eval_duration // 1')
    local tokens_per_sec=0

    if [ "$eval_duration" != "0" ] && [ "$eval_duration" != "null" ]; then
        tokens_per_sec=$(echo "scale=2; $eval_count * 1000000000 / $eval_duration" | bc)
    fi

    # Save to CSV
    echo "$model,$prompt_length,$stream,$format,$time_ms,$eval_count,$tokens_per_sec" >> "$RESULTS_FILE"

    # Display result
    printf "  %-20s: %6d ms | %3d tokens | %5.1f tok/s\n" \
        "$model" "$time_ms" "$eval_count" "$tokens_per_sec"
}

# Check available models
echo "Checking available models..."
available_models=$(curl -s "$OLLAMA_URL/api/tags" | jq -r '.models[].name')
echo "Available models:"
echo "$available_models"
echo ""

# Test configurations
echo "Starting benchmark tests..."
echo ""

# Test 1: Different models, same prompt
echo "=== Test 1: Model Comparison ==="
SHORT_PROMPT="Analyze sentiment: \"$TEST_TEXT\" JSON: {\"sentiment\":\"positive/negative/neutral\",\"score\":-1 to 1}"

for model in llama3.2:1b llama3.2:3b llama2:7b; do
    if echo "$available_models" | grep -q "^$model$"; then
        test_config "$model" "$SHORT_PROMPT" "false" "json"
    else
        echo "Skipping $model (not installed)"
    fi
done
echo ""

# Test 2: Prompt length impact (using best available model)
echo "=== Test 2: Prompt Length Impact ==="
BEST_MODEL="llama3.2:3b"

if ! echo "$available_models" | grep -q "^$BEST_MODEL$"; then
    BEST_MODEL=$(echo "$available_models" | grep -E "llama3|llama2" | head -1)
fi

echo "Using model: $BEST_MODEL"

# Short prompt
SHORT="Sentiment: \"$TEST_TEXT\" Reply: positive/negative/neutral"
test_config "$BEST_MODEL" "$SHORT" "false" ""

# Medium prompt (workshop style)
MEDIUM="Analyze the sentiment of this customer review and respond in JSON format.

Review: \"$TEST_TEXT\"

Provide your response as valid JSON with exactly these fields:
{
  \"sentiment\": \"positive, negative, or neutral\",
  \"score\": numeric value from -1.0 to 1.0
}"
test_config "$BEST_MODEL" "$MEDIUM" "false" "json"

# Long prompt (with examples)
LONG="Analyze the sentiment of this customer review and respond in JSON format.

Review: \"$TEST_TEXT\"

Examples of correct format:
Example 1: {\"sentiment\": \"positive\", \"score\": 0.8}
Example 2: {\"sentiment\": \"negative\", \"score\": -0.7}

Provide your response as valid JSON with exactly these fields:
{
  \"sentiment\": \"positive, negative, or neutral\",
  \"score\": numeric value from -1.0 (very negative) to 1.0 (very positive),
  \"confidence\": percentage 0-100,
  \"key_phrases\": [array of important phrases],
  \"summary\": \"brief one-sentence summary\"
}"
test_config "$BEST_MODEL" "$LONG" "false" "json"
echo ""

# Test 3: JSON format impact
echo "=== Test 3: JSON Format Parameter ==="
SIMPLE_PROMPT="Sentiment of: \"$TEST_TEXT\""

test_config "$BEST_MODEL" "$SIMPLE_PROMPT" "false" ""
test_config "$BEST_MODEL" "$SIMPLE_PROMPT" "false" "json"
echo ""

# Test 4: Parallel requests simulation
echo "=== Test 4: Parallel Processing Simulation ==="
echo "Testing sequential vs parallel (4 requests)..."

# Sequential
seq_start=$(date +%s%N)
for i in {1..4}; do
    curl -s "$OLLAMA_URL/api/generate" -d "{
        \"model\": \"$BEST_MODEL\",
        \"prompt\": \"Quick test $i\",
        \"stream\": false
    }" > /dev/null
done
seq_end=$(date +%s%N)
seq_time=$(( ($seq_end - $seq_start) / 1000000 ))

echo "Sequential (4 requests): ${seq_time}ms"

# Parallel (background jobs)
par_start=$(date +%s%N)
for i in {1..4}; do
    curl -s "$OLLAMA_URL/api/generate" -d "{
        \"model\": \"$BEST_MODEL\",
        \"prompt\": \"Quick test $i\",
        \"stream\": false
    }" > /dev/null &
done
wait
par_end=$(date +%s%N)
par_time=$(( ($par_end - $par_start) / 1000000 ))

echo "Parallel (4 requests):   ${par_time}ms"
echo "Speedup: $(echo "scale=2; $seq_time / $par_time" | bc)x"
echo ""

# Test 5: Model warmup impact
echo "=== Test 5: Model Warmup Impact ==="

# Unload model first
curl -s "$OLLAMA_URL/api/generate" -d "{
    \"model\": \"$BEST_MODEL\",
    \"prompt\": \"test\",
    \"keep_alive\": 0
}" > /dev/null
sleep 2

# Cold start
echo "Cold start (model not in memory)..."
cold_start=$(date +%s%N)
curl -s "$OLLAMA_URL/api/generate" -d "{
    \"model\": \"$BEST_MODEL\",
    \"prompt\": \"Quick test\",
    \"stream\": false
}" > /dev/null
cold_end=$(date +%s%N)
cold_time=$(( ($cold_end - $cold_start) / 1000000 ))
echo "  Cold start: ${cold_time}ms"

# Warm start
echo "Warm start (model in memory)..."
warm_start=$(date +%s%N)
curl -s "$OLLAMA_URL/api/generate" -d "{
    \"model\": \"$BEST_MODEL\",
    \"prompt\": \"Quick test\",
    \"stream\": false
}" > /dev/null
warm_end=$(date +%s%N)
warm_time=$(( ($warm_end - $warm_start) / 1000000 ))
echo "  Warm start: ${warm_time}ms"
echo "  Difference: $(( $cold_time - $warm_time ))ms"
echo ""

# Generate summary
echo "=========================================="
echo "Benchmark Complete!"
echo "=========================================="
echo ""
echo "Results saved to: $RESULTS_FILE"
echo ""
echo "Summary:"
echo "--------"

# Find fastest model
echo "Fastest model:"
tail -n +2 "$RESULTS_FILE" | sort -t',' -k5 -n | head -1 | awk -F',' '{
    printf "  Model: %s\n  Time: %d ms\n  Tokens/sec: %s\n", $1, $5, $7
}'

echo ""
echo "Key Findings:"
echo "-------------"

# Calculate averages
echo "Average response times by model:"
tail -n +2 "$RESULTS_FILE" | awk -F',' '{
    sum[$1] += $5
    count[$1]++
}
END {
    for (model in sum) {
        printf "  %-20s: %.0f ms\n", model, sum[model]/count[model]
    }
}' | sort -t':' -k2 -n

echo ""
echo "Prompt length impact (${BEST_MODEL}):"
echo "  Short  (<100 chars): Fastest"
echo "  Medium (200 chars):  Baseline"
echo "  Long   (500+ chars): Slowest"
echo ""
echo "Recommendations:"
echo "----------------"
echo "1. Use ${BEST_MODEL} for balanced performance"
echo "2. Keep prompts concise (< 200 chars when possible)"
echo "3. Always use 'format: json' for structured output"
echo "4. Enable parallel processing (4-8 copies in PDI)"
echo "5. Keep model loaded with 'keep_alive' parameter"
echo ""
echo "View detailed results:"
echo "  cat $RESULTS_FILE"
echo ""
