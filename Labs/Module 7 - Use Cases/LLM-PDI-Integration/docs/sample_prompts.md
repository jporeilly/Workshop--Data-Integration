# Sample Prompts for Sentiment Analysis Workshop

This document contains various prompt templates you can use with the workshop transformation. Experimenting with different prompts helps you understand how prompt engineering affects LLM output quality.

## Basic Prompts

### Minimal Prompt
```
Classify sentiment: [review_text]
Response: positive, negative, or neutral
```

**Pros:** Fast, simple
**Cons:** No structure, inconsistent format, no confidence scores

### Simple JSON Prompt
```
Analyze sentiment of: "[review_text]"
Respond with JSON: {"sentiment": "positive/negative/neutral", "score": -1.0 to 1.0}
```

**Pros:** Fast, structured output
**Cons:** No reasoning, limited detail

## Intermediate Prompts

### Workshop Default Prompt
```
Analyze the sentiment of this customer review and respond in JSON format.

Review: "[review_text]"

Provide your response as valid JSON with exactly these fields:
{
  "sentiment": "positive, negative, or neutral",
  "score": numeric value from -1.0 (very negative) to 1.0 (very positive),
  "confidence": percentage 0-100,
  "key_phrases": [array of important phrases],
  "summary": "brief one-sentence summary"
}
```

**Pros:** Structured, detailed, includes confidence
**Cons:** Longer processing time

### E-commerce Focused Prompt
```
As an e-commerce analyst, evaluate this product review:

Review: "[review_text]"

Provide JSON analysis:
{
  "sentiment": "positive/negative/neutral",
  "score": -1.0 to 1.0,
  "purchase_recommendation": "would_buy/unsure/would_not_buy",
  "product_quality_mentioned": true/false,
  "service_quality_mentioned": true/false,
  "price_sentiment": "good_value/overpriced/fair/not_mentioned",
  "key_issues": ["array of problems mentioned"],
  "key_benefits": ["array of benefits mentioned"]
}
```

**Pros:** Business-focused, actionable insights
**Cons:** More complex, slower

## Advanced Prompts

### Customer Service Priority Prompt
```
You are a customer service manager analyzing feedback. For this review:

"[review_text]"

Determine:
1. Sentiment (positive/negative/neutral)
2. Urgency level (low/medium/high/critical)
3. Category (product_quality/shipping/service/pricing/other)
4. Requires_followup (yes/no)
5. Suggested_response (brief guidance)

Respond in JSON format:
{
  "sentiment": "",
  "urgency": "",
  "category": "",
  "requires_followup": boolean,
  "suggested_response": "",
  "estimated_resolution_time": "hours/days/weeks"
}
```

**Use Case:** Prioritizing customer support tickets
**Pros:** Actionable, helps routing
**Cons:** Complex, requires larger model

### Detailed Analysis Prompt
```
Perform a comprehensive sentiment analysis on this review:

Review: "[review_text]"

Analyze:
- Overall sentiment and granular emotion (joy, frustration, disappointment, satisfaction, etc.)
- Specific aspects mentioned (quality, price, service, features, usability)
- Implicit vs explicit sentiment
- Comparative statements (better/worse than alternatives)
- Actionable feedback for product team

Return detailed JSON:
{
  "overall_sentiment": "positive/negative/neutral",
  "overall_score": -1.0 to 1.0,
  "emotions": {
    "primary": "",
    "secondary": [""],
    "intensity": 1-10
  },
  "aspects": [
    {
      "aspect": "quality/price/service/features/usability",
      "sentiment": "positive/negative/neutral",
      "score": -1.0 to 1.0,
      "quote": "relevant text excerpt"
    }
  ],
  "comparison_mentioned": boolean,
  "actionable_feedback": [""],
  "risk_level": "customer_churn/neutral/advocacy"
}
```

**Use Case:** Deep product insights, product development
**Pros:** Comprehensive, multi-dimensional
**Cons:** Slow, requires powerful model (7B+)

## Specialized Prompts

### Multi-language Support
```
Analyze sentiment of this review (may be in any language):

"[review_text]"

Detect language, analyze sentiment, respond in English JSON:
{
  "detected_language": "en/es/fr/de/etc",
  "sentiment": "positive/negative/neutral",
  "score": -1.0 to 1.0,
  "english_summary": "if not English, translate summary"
}
```

### Aspect-Based Sentiment
```
Perform aspect-based sentiment analysis on:

"[review_text]"

Identify sentiments for these aspects (if mentioned):
- Product Quality
- Customer Service
- Shipping/Delivery
- Price/Value
- User Experience

JSON format:
{
  "overall_sentiment": "",
  "overall_score": -1.0 to 1.0,
  "aspects": {
    "product_quality": {"mentioned": boolean, "sentiment": "", "score": 0.0},
    "customer_service": {"mentioned": boolean, "sentiment": "", "score": 0.0},
    "shipping": {"mentioned": boolean, "sentiment": "", "score": 0.0},
    "price_value": {"mentioned": boolean, "sentiment": "", "score": 0.0},
    "user_experience": {"mentioned": boolean, "sentiment": "", "score": 0.0}
  }
}
```

### Sarcasm & Irony Detection
```
Analyze this review, paying special attention to sarcasm, irony, or indirect criticism:

"[review_text]"

JSON response:
{
  "literal_sentiment": "what the words say",
  "actual_sentiment": "what the customer means",
  "contains_sarcasm": boolean,
  "confidence": 0-100,
  "explanation": "brief reasoning"
}
```

## Prompt Engineering Best Practices

### 1. Be Explicit About Format
✓ Good: "Respond with JSON: {\"sentiment\": \"value\"}"
✗ Bad: "Tell me the sentiment"

### 2. Provide Value Constraints
✓ Good: "score from -1.0 to 1.0"
✗ Bad: "give a score"

### 3. Use Examples (Few-Shot Learning)
```
Analyze sentiment like these examples:

Example 1:
Review: "Great product!"
Response: {"sentiment": "positive", "score": 0.8}

Example 2:
Review: "Broke immediately."
Response: {"sentiment": "negative", "score": -0.9}

Now analyze:
Review: "[review_text]"
```

### 4. Set Context/Role
✓ "As a customer service expert, analyze..."
✓ "You are an e-commerce analyst..."
This helps the model understand perspective.

### 5. Request Confidence Scores
Including confidence helps you:
- Filter low-confidence results for manual review
- Calibrate model performance
- Improve trust in automated decisions

## Testing Your Prompts

### Quick Test Template
```bash
curl http://localhost:11434/api/generate -d '{
  "model": "llama3.2:3b",
  "prompt": "YOUR_PROMPT_HERE",
  "stream": false,
  "format": "json"
}'
```

### Test Checklist
- [ ] Does the LLM consistently return valid JSON?
- [ ] Are field names spelled correctly?
- [ ] Are value types correct (string vs number)?
- [ ] Does it handle edge cases (very short/long reviews)?
- [ ] Is performance acceptable (time per request)?

## Prompt Modification for PDI

To use these prompts in the workshop transformation:

1. Open the transformation in Spoon
2. Double-click the "Build LLM Prompt" step
3. Find the JavaScript code section
4. Replace the `prompt_text` variable content
5. Ensure the JSON parsing steps match your new fields
6. Test with a small dataset first

### Example Modification

**Original (in JavaScript):**
```javascript
var prompt_text = "Analyze the sentiment...";
```

**Modified:**
```javascript
var prompt_text = "As a customer service manager, analyze this review:\n\n" +
                  "Review: \"" + review_text + "\"\n\n" +
                  "Provide JSON with: sentiment, urgency, category";
```

Remember to update downstream parsing steps to match your new JSON structure!

## Model-Specific Considerations

### Small Models (1B-3B parameters)
- Use simpler prompts
- Request fewer fields
- Avoid complex reasoning tasks
- Examples: llama3.2:1b, llama3.2:3b

### Medium Models (7B-13B parameters)
- Can handle detailed prompts
- Good for multi-aspect analysis
- Reliable JSON formatting
- Examples: llama2:7b, llama3:8b

### Large Models (13B+ parameters)
- Complex reasoning
- Multi-step analysis
- Nuanced understanding
- Examples: llama2:13b, llama3:70b

## Common Issues & Solutions

### Issue: Inconsistent JSON Format
**Solution:** Add "format": "json" to API call and be very explicit in prompt

### Issue: Missing Fields in Response
**Solution:** Explicitly list required fields: "You MUST include all these fields: ..."

### Issue: Incorrect Value Types
**Solution:** Specify types: "score should be a number between -1.0 and 1.0 (not a string)"

### Issue: Too Verbose / Extra Text
**Solution:** Start prompt with "Respond ONLY with JSON, no other text or explanation."

## Experimentation Ideas

1. **A/B Test Prompts:** Run same data through different prompts, compare accuracy
2. **Progressive Detail:** Start simple, add fields one at a time, measure impact
3. **Domain Adaptation:** Customize prompt vocabulary for your industry
4. **Chain of Thought:** Ask model to "explain your reasoning" for better accuracy
5. **Temperature Tuning:** Adjust creativity (add "temperature": 0.1-2.0 to API call)

## Resources

- [OpenAI Prompt Engineering Guide](https://platform.openai.com/docs/guides/prompt-engineering)
- [Anthropic Prompt Engineering](https://docs.anthropic.com/claude/docs/prompt-engineering)
- [Llama Prompting Guide](https://llama.meta.com/docs/how-to-guides/prompting)

---

**Remember:** Prompt engineering is iterative. Test, measure, refine, repeat!
