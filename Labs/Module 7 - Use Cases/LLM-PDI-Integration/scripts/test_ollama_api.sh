#!/bin/bash
# Test script for Ollama API - Workshop 1
# This script helps verify your Ollama installation and test prompts

set -e

OLLAMA_URL="${OLLAMA_URL:-http://localhost:11434}"
MODEL="${MODEL:-llama3.2:3b}"

echo "=========================================="
echo "Ollama API Test Script"
echo "=========================================="
echo "URL: $OLLAMA_URL"
echo "Model: $MODEL"
echo ""

# Test 1: Check if Ollama is running
echo "Test 1: Checking Ollama service..."
if curl -s "$OLLAMA_URL/api/tags" > /dev/null; then
    echo "✓ Ollama is running"
else
    echo "✗ Ollama is not responding"
    echo "  Start it with: sudo systemctl start ollama"
    exit 1
fi

echo ""

# Test 2: List available models
echo "Test 2: Available models..."
curl -s "$OLLAMA_URL/api/tags" | grep -o '"name":"[^"]*"' | cut -d'"' -f4 || echo "No models found"

echo ""
echo ""

# Test 3: Simple sentiment analysis
echo "Test 3: Simple sentiment analysis..."
echo "Prompt: 'This product is amazing! Best purchase ever.'"
echo ""

RESPONSE=$(curl -s "$OLLAMA_URL/api/generate" -d "{
  \"model\": \"$MODEL\",
  \"prompt\": \"Analyze the sentiment of this review and respond ONLY with valid JSON (no other text): 'This product is amazing! Best purchase ever.' Format: {\\\"sentiment\\\": \\\"positive/negative/neutral\\\", \\\"score\\\": -1.0 to 1.0}\",
  \"stream\": false,
  \"format\": \"json\"
}")

echo "Raw response:"
echo "$RESPONSE" | jq '.'
echo ""

SENTIMENT_JSON=$(echo "$RESPONSE" | jq -r '.response')
echo "Extracted sentiment JSON:"
echo "$SENTIMENT_JSON" | jq '.'

echo ""
echo ""

# Test 4: Negative sentiment
echo "Test 4: Negative sentiment analysis..."
echo "Prompt: 'Terrible product. Broke after one day. Waste of money.'"
echo ""

RESPONSE=$(curl -s "$OLLAMA_URL/api/generate" -d "{
  \"model\": \"$MODEL\",
  \"prompt\": \"Analyze the sentiment of this review and respond ONLY with valid JSON (no other text): 'Terrible product. Broke after one day. Waste of money.' Format: {\\\"sentiment\\\": \\\"positive/negative/neutral\\\", \\\"score\\\": -1.0 to 1.0}\",
  \"stream\": false,
  \"format\": \"json\"
}")

echo "Raw response:"
echo "$RESPONSE" | jq '.'
echo ""

SENTIMENT_JSON=$(echo "$RESPONSE" | jq -r '.response')
echo "Extracted sentiment JSON:"
echo "$SENTIMENT_JSON" | jq '.'

echo ""
echo ""

# Test 5: Full workshop prompt structure
echo "Test 5: Full workshop-style prompt..."
echo ""

REVIEW_TEXT="Good product overall. Works as expected, though it gets a bit warm during heavy use. Decent value for money."

PROMPT="Analyze the sentiment of this customer review and respond in JSON format.

Review: \"$REVIEW_TEXT\"

Provide your response as valid JSON with exactly these fields:
{
  \"sentiment\": \"positive, negative, or neutral\",
  \"score\": numeric value from -1.0 (very negative) to 1.0 (very positive),
  \"confidence\": percentage 0-100,
  \"key_phrases\": [array of important phrases],
  \"summary\": \"brief one-sentence summary\"
}"

RESPONSE=$(curl -s "$OLLAMA_URL/api/generate" -d "{
  \"model\": \"$MODEL\",
  \"prompt\": $(echo "$PROMPT" | jq -Rs .),
  \"stream\": false,
  \"format\": \"json\"
}")

echo "Review: $REVIEW_TEXT"
echo ""
echo "Response:"
echo "$RESPONSE" | jq -r '.response' | jq '.'

echo ""
echo "=========================================="
echo "Testing complete!"
echo "=========================================="
echo ""
echo "If all tests passed, your Ollama setup is ready for the workshop."
echo ""
